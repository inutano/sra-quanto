#
# quanto.sh
#  A library for quanto-core
#
# requirements:
#  lftp, md5sum


#
# Path to binary, fix if necessary
#
PFASTQ_DUMP="${HOME}/local/bin/pfastq-dump -t 16"
VDB_VALIDATE="${HOME}/local/bin/vdb-validate"
FASTQC="${HOME}/local/bin/fastqc -f fastq --quiet --nogroup --noextract --threads 16"

#
# Global variables
#
DDBJ_FTP_BASE="ftp.ddbj.nig.ac.jp/ddbj_database/dra"
NCBI_FTP_BASE="ftp-trace.ncbi.nih.gov/sra/sra-instant/reads/ByExp/sra"

#
# Functions
#

#
# FTP utilities
#

establish_ftp_connection(){
  local exp_id="${1}"
  local ftp_connection_pool="${2}"
  touch "${ftp_connection_pool}/${exp_id}.waiting"
  while [ `ls "${ftp_connection_pool}" | grep "connected" | wc -l` -gt 16 ] && [ `ls -t "${ftp_connection_pool}" | tail -n 1` != "${exp_id}.waiting" ] ; do
    sleep 1
  done
  touch "${ftp_connection_pool}/${exp_id}.connected"
}

close_ftp_connection(){
  local exp_id="${1}"
  local ftp_connection_pool="${2}"
  rm -f "${ftp_connection_pool}/${exp_id}.connected"
}


#
# Step 0. Get filapath and calculate file size
#

get_fileinfo(){
  local acc_id="${1}"
  local exp_id="${2}"
  local ftp_connection_pool="${3}"

  local fq_path=`get_fq_path "${acc_id}" "${exp_id}"`
  local fq_size=`get_filesize "${fq_path}" "${exp_id}" "${ftp_connection_pool}"`
  if [[ ! -z "${fq_size}" ]] ; then
    echo "${fq_path} ${fq_size}"
  else
    local sra_path=`get_sra_path "${exp_id}"`
    local sra_size=`get_filesize "${sra_path}" "${exp_id}" "${ftp_connection_pool}"`
    if [[ ! -z "${sra_size}" ]] ; then
      echo "${sra_path} ${sra_size}"
    fi
  fi
}

get_fq_path(){
  local acc_id="${1}"
  local exp_id="${2}"
  echo "fastq/${acc_id:0:6}/${acc_id}/${exp_id}"
}

get_sra_path(){
  local exp_id="${1}"
  #echo "sralite/ByExp/litesra/${exp_id:0:3}/${exp_id:0:6}/${exp_id}"
  echo "${exp_id:0:3}/${exp_id:0:6}/${exp_id}"
}

get_filesize(){
  local filepath="${1}"
  local exp_id="${2}"
  local ftp_connection_pool="${3}"

  establish_ftp_connection "${exp_id}" "${ftp_connection_pool}"
  if [[ -z `echo ${filepath} | awk '$0 ~ /litesra/'` ]]; then
    local filelist=`lftp -c "set net:max-retries 5; set net:timeout 10; open ${NCBI_FTP_BASE} && (!rm ${ftp_connection_pool}/${exp_id}.waiting) && ls ${filepath}"`
  else
    local filelist=`lftp -c "set net:max-retries 5; set net:timeout 10; open ${NCBI_FTP_BASE} && (!rm ${ftp_connection_pool}/${exp_id}.waiting) && ls ${filepath}/*/*sra"`
  fi
  close_ftp_connection "${exp_id}" "${ftp_connection_pool}"

  if [[ ! -z "${filelist}" ]] ; then
    echo "${filelist}" | awk '{ sum+=$5 }END{ print sum }'
  fi
}


#
# Step 1. Set working directory
#

set_working_directory(){
  local fsize="${1}"
  local exp_id="${2}"

  # Check if ssd disk is attached
  if [[ ! -z `ls /ssd 2>/dev/null` ]] ; then
    # on ssd attached nodes
    local ssd_tmp="/ssd/`whoami`/fq_tmp"
    local ssd_available=`df -k /ssd | awk 'NR == 2 { print $4 }'`

    # check if disk is reserved
    local reserved="${ssd_tmp}/reserved.txt"
    local reserved_size=`cat ${reserved} 2>/dev/null`

    if [[ -z "${reserved_size}" ]] ; then
      local use="${fsize}"
    else
      local use=`echo "scale=2; ${fsize} + ${reserved_size}" | bc`
    fi

    # check if there's enough space to work
    if [[ `echo "scale=2; ${use} / ${ssd_available}" | bc` < 0.9 ]]; then
      local workdir="${ssd_tmp}/${exp_id:0:6}/${exp_id}"
      mkdir -p "${workdir}"
      echo "${use}" > "${reserved}"
    fi
  fi

  # if $workdir is undefined, create working directory under /home/<username>
  if [[ ! -z "${workdir}" ]]; then
    echo "${workdir}"
  else
    local home_tmp="${HOME}/fq_tmp/${exp_id:0:6}/${exp_id}"
    mkdir -p "${home_tmp}"
    echo "${home_tmp}"
  fi
}

#
# Step 2. Download data
#

download_data(){
  local exp_id="${1}"
  local path="${2}"
  local target_dir="${3}"
  local ftp_connection_pool="${4}"

  establish_ftp_connection "${exp_id}" "${ftp_connection_pool}"
  lftp -c "set net:max-retries 5; set net:timeout 10; open ${NCBI_FTP_BASE} && (!rm ${ftp_connection_pool}/${exp_id}.waiting) && mirror --parallel=8 ${path} ${target_dir}"
  chmod -R a+w ${target_dir}
  close_ftp_connection "${exp_id}" "${ftp_connection_pool}"
}

#
# Step 3. Validate downloaded data
#

validate_downloaded_files(){
  local dir="${1}"
  local logfile="${2}"
  local checksum_table="${3}"
  validate_downloaded_sra_files "${dir}" "${logfile}"
  validate_downloaded_fastq_files "${dir}" "${logfile}" "${checksum_table}"
}

validate_downloaded_sra_files(){
  local dir="${1}"
  local logfile="${2}"
  ls ${dir}/**/*sra 2>/dev/null | while read fpath ; do
    ${VDB_VALIDATE} "${fpath}" 2>> ${logfile}
  done
}

validate_downloaded_fastq_files(){
  local dir=${1}
  local logfile="${2}"
  local checksum_table="${3}"
  ls ${workdir}/*fastq* 2>/dev/null | while read fpath ; do
    validate_downloaded_fastq "${fpath}" "${checksum_table}" "${logfile}"
  done
}

validate_downloaded_fastq(){
  local fpath=${1}
  local table=${2}
  local logfile=${3}

  local fname=`echo "${fpath}" | awk -F '/' '{ print $NF }'`
  local checksum=`md5sum "${fpath}" | awk '{ print $1 }'`
  local valid_checksum=`grep "${fname}" "${table}" | awk -F '\t' '{ print $2 }'`

  if [[ ${valid_checksum} != ${checksum} ]] ; then
    echo "Validation Failed: File ${fpath} is inconsistent, skipping.." >> ${logfile}
    echo "Valid checksum is ${valid_checksum}, one of downloaded is ${checksum}" >> ${logfile}
    rm -f "${fpath}"
  else
    echo "Validated: ${fpath} with checksum ${checksum}" >> ${logfile}
  fi
}

#
# Step 4. Execute Fastqdump/FastQC
#

execute_qcalc(){
  local workdir="${1}"
  local read_layout="${2}"
  local logfile="${3}"

  local fq_filelist=`ls ${workdir}/*fastq* 2>/dev/null` &&:
  if [[ ! -z "${fq_filelist}" ]] ; then
    echo "${fq_filelist}" |\
    xargs ${FASTQC} --outdir "${workdir}" 2>>"${logfile}" 1>>"${logfile}"
    ls ${workdir}/*zip | while read f ; do
      local dir=`get_result_dir ${f}`
      mkdir -p "${dir}"
      mv --force ${f} ${dir}
      echo "${dir}"
    done
  fi

  local sra_filelist=`ls ${workdir}/**/*sra 2>/dev/null` &&:
  if [[ ! -z "${sra_filelist}" ]] ; then
    echo "${sra_filelist}" |\
    while read f ; do
      local run_dir=`echo ${f} | sed -e 's:/[^/]*sra$::g'`
      exec_qc_sra "${read_layout}" "${f}" "${run_dir}" "${logfile}"
    done
  fi
}

exec_qc_sra(){
  local layout="${1}"
  local fpath="${2}"
  local workdir="${3}"
  local logfile="${4}"

  if [[ ${layout} == "SINGLE" ]] ; then
    exec_qc_single "${fpath}" "${workdir}" "${logfile}"
  elif [[ ${layout} == "PAIRED" ]] ; then
    exec_qc_paired "${fpath}" "${workdir}" "${logfile}"
  else
    echo "Error: read layout not defined. 'SINGLE' or 'PAIRED' should be provided"
  fi
}

exec_qc_single(){
  local fpath="${1}"
  local workdir="${2}"
  local logfile="${3}"

  local fq_fname=$(basename ${fpath} | sed -e 's:sra$:fastq:')
  local qc_fname=$(echo ${fq_fname} | sed -e 's:\.fastq$:_fastqc.zip:')
  local html_fname=$(echo ${fq_fname} | sed -e 's:\.fastq$:_fastqc.html:')

  ${PFASTQ_DUMP} --outdir "${workdir}" "${fpath}"
  ${FASTQC} --outdir "${workdir}" "${workdir}/${fq_fname}" >>"${logfile}" 2>&1

  rm -f "${workdir}/${fq_fname}"
  rm -f "${workdir}/${html_fname}"
  
  echo "${workdir}/${qc_fname}"
}

exec_qc_paired(){
  local fpath="${1}"
  local workdir="${2}"
  local logfile="${3}"

  local fq1_fname=$(basename ${fpath} | sed -e 's:\.sra$:_1.fastq:')
  local qc1_fname=$(echo ${fq1_fname} | sed -e 's:\.fastq$:_fastqc.zip:')
  local html1_fname=$(echo ${fq1_fname} | sed -e 's:\.fastq$:_fastqc.html:')

  local fq2_fname=$(basename ${fpath} | sed -e 's:\.sra$:_2.fastq:')
  local qc2_fname=$(echo ${fq2_fname} | sed -e 's:\.fastq$:_fastqc.zip:')
  local html2_fname=$(echo ${fq2_fname} | sed -e 's:\.fastq$:_fastqc.html:')

  ${PFASTQ_DUMP} --split-3 --outdir "${workdir}" "${fpath}"

  ${FASTQC} --outdir "${workdir}" "${workdir}/${fq1_fname}" >>"${logfile}" 2>&1
  ${FASTQC} --outdir "${workdir}" "${workdir}/${fq2_fname}" >>"${logfile}" 2>&1

  rm -f "${workdir}/${fq1_fname}"
  rm -f "${workdir}/${fq2_fname}"

  rm -f "${workdir}/${html1_fname}"
  rm -f "${workdir}/${html2_fname}"

  echo "${workdir}/${qc1_fname} ${workdir}/${qc2_fname}"
}

get_result_fname(){
  local filepath=${1} # /path/to/id.fastq.gz or /path/to/id.sra or /path/to/id_fastqc.zip
  local fileid=`echo "${filepath}" | awk -F '/' '{ print $NF }' | sed -e 's:\.fastq.+$::g' -e 's:\.sra$::g' -e 's:_fastqc.zip$::g'`
  local result_dir=`get_result_dir ${filepath}`
  mkdir -p "${result_dir}"
  echo "${result_dir}/${fileid}_fastqc.zip"
}

get_result_dir(){
  local filepath=${1} # /path/to/id.fastq.gz or /path/to/id.sra or /path/to/id_fastqc.zip
  local fileid=`echo "${filepath}" | awk -F '/' '{ print $NF }' | sed -e 's:\.fastq.+$::g' -e 's:\.sra$::g' -e 's:_fastqc.zip$::g'`
  local id=`echo "${fileid}" | sed -e 's:_.$::g'`
  echo "${FASTQC_RESULT_DIR}/${id:0:3}/${id:0:4}/`echo ${id} | sed -e 's:...$::g'`/${id}"
}

rename_stdin_fastqc_files(){
  local workdir=${1}
  local fname_out=${2}
  mv "${workdir}/stdin_fastqc.zip" "${fname_out}"
  rm -f "${workdir}/stdin_fastqc.html"
}

#
# Step 5. Cleaning working directory
#

flush_workdir(){
  local workdir=${1}
  rm -fr ${workdir}/*sra 2>/dev/null
  rm -fr ${workdir}/*fastq* 2>/dev/null
}
