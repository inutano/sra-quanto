#
# quanto.sh
#  A library for quanto-core
#
# requirements:
#  lftp, md5sum


#
# Path to binary, fix if necessary
#
FASTQ_DUMP="${HOME}/local/bin/fastq-dump"
VDB_VALIDATE="${HOME}/local/bin/vdb-validate"
FASTQC="${HOME}/local/bin/fastqc --noextract --threads 4"

#
# Global variables
#
DDBJ_FTP_BASE="ftp.ddbj.nig.ac.jp/ddbj_database/dra"

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
  echo "sralite/ByExp/litesra/${exp_id:0:3}/${exp_id:0:6}/${exp_id}"
}

get_filesize(){
  local filepath="${1}"
  local exp_id="${2}"
  local ftp_connection_pool="${3}"

  establish_ftp_connection "${exp_id}" "${ftp_connection_pool}"
  if [[ -z `echo ${filepath} | awk '$0 ~ /litesra/'` ]]; then
    local filelist=`lftp -c "set net:max-retries 1; open ${DDBJ_FTP_BASE} && (!rm ${ftp_connection_pool}/${exp_id}.waiting) && ls ${filepath}"`
  else
    local filelist=`lftp -c "set net:max-retries 1; open ${DDBJ_FTP_BASE} && (!rm ${ftp_connection_pool}/${exp_id}.waiting) && ls ${filepath}/*/*sra"`
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
  local ssd_available=`df -k /ssd | awk 'NR == 2 { print $4 }' 2>/dev/null`
  local rate=`echo "scale=2; ${fsize} / ${ssd_available}" | bc`
  if [[ ! -z "${ssd_available}" && ${rate} < 30 ]] ; then
    local ssd_tmp="/ssd/`whoami`/fq_tmp/${exp_id:0:6}/${exp_id}"
    if [[ ! -e "${ssd_tmp}" ]] ; then
      mkdir -p "${ssd_tmp}"
    fi
    echo "${ssd_tmp}"
  else
    local home_tmp="${HOME}/fq_tmp/${exp_id:0:6}/${exp_id}"
    if [[ ! -e "${home_tmp}" ]] ; then
      mkdir -p "${home_tmp}"
    fi
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
  lftp -c "open ${DDBJ_FTP_BASE} && (!rm ${ftp_connection_pool}/${exp_id}.waiting) && mirror ${path} ${target_dir}"
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

  local fname_out=`get_result_fname ${fpath}`

  ${FASTQ_DUMP} --stdout ${fpath} |\
  ${FASTQC} --outdir "${workdir}" /dev/stdin 2>>"${logfile}" 1>>"${logfile}"
  rename_stdin_fastqc_files "${workdir}" "${fname_out}"

  echo "${fname_out}"
}

exec_qc_paired(){
  local fpath="${1}"
  local workdir="${2}"
  local logfile="${3}"

  local wd_read1="${workdir}/read1"
  local wd_read2="${workdir}/read2"
  local fname_out=`get_result_fname ${fpath}`
  local fname_out_1=`echo ${fname_out} | sed -e 's:_fastqc:_1_fastqc:g'`
  local fname_out_2=`echo ${fname_out} | sed -e 's:_fastqc:_2_fastqc:g'`

  mkdir -p "${wd_read1}"
  mkdir -p "${wd_read2}"

  ${FASTQ_DUMP} --split-3 --stdout ${fpath} |\
  tee >( awk 'NR%8 ~ /^(1|2|3|4)$/' | ${FASTQC} --outdir "${wd_read1}" /dev/stdin 2>>"${logfile}" 1>>"${logfile}" ) |\
  awk 'NR%8 ~ /^(5|6|7|0)$/' | ${FASTQC} --outdir "${wd_read2}" /dev/stdin 2>>"${logfile}" 1>>"${logfile}"

  rename_stdin_fastqc_files "${wd_read1}" "${fname_out_1}"
  rename_stdin_fastqc_files "${wd_read2}" "${fname_out_2}"

  rm -fr "${wd_read1}"
  rm -fr "${wd_read2}"

  echo "${fname_out_1} ${fname_out_2}"
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
