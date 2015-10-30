#!/bin/bash
#$ -o /home/inutano/project/ER/log -S /bin/bash -j y -l mem_req=4G,s_vmem=4G -pe def_slot 4
#
# usage:
#   quanto_core.sh <SRA Accession ID> <SRA Experiment ID>
#
set -eu

#
# Global variables
#

# Node name to access to the sra file system: sra disk attached hostname accessed via ssh
node="sranode"

# Path to tools and arguments
fastq_dump="/home/inutano/local/bin/fastq-dump"
fastqc="/home/inutano/local/bin/fastqc --noextract --threads 4"

# Identifiers
acc_id=${1}
exp_id=${2}
layout=${3}

acc_id_head=`echo ${acc_id} | sed -e 's:...$::'`
exp_id_head=`echo ${exp_id} | sed -e 's:...$::'`
exp_id_center=${exp_id:0:3}

# Path to sra disk filesystem
dra_path="/usr/local/ftp/public/ddbj_database/dra"
ftp_base="ftp.ddbj.nig.ac.jp/ddbj_database/dra"

#
# Functions
#

get_fq_path(){
  local fq_path="fastq/${acc_id_head}/${acc_id}/${exp_id}"
  local fq_list=`ssh "${node}" ls -lk "${dra_path}/${fq_path}"`
  if [[ ! -z "${fq_list}" ]] ; then
    echo "${fq_path}"
  fi
}

get_sra_path(){
  local sra_path="sralite/ByExp/litesra/${exp_id_center}/${exp_id_head}/${exp_id}"
  echo "${sra_path}"
}

get_filepath(){
  local fq_path=`get_fq_path`
  # if [[ ! -z "${fq_path}" ]] ; then
  if [[ -z "${fq_path}" ]] ; then # testing for sra file
    echo "${dra_path}/${fq_path}"
  else
    local sra_path=`get_sra_path`
    echo "${dra_path}/${sra_path}"
  fi
}

get_filepath_ftp(){
  local fq_path=`get_fq_path`
  # if [[ ! -z "${fq_path}" ]] ; then
  if [[ -z "${fq_path}" ]] ; then # testing for sra file
    echo "${fq_path}"
  else
    local sra_path=`get_sra_path`
    echo "${sra_path}"
  fi
}

get_filesize(){
  local fpath=`get_fq_path`
  ssh "${node}" ls -lkR "${dra_path}/${fpath}" | awk '{ sum += $5 }END{ print sum }'
}

set_workdir_base(){ # sum of file size must be provided for the first argument
  local fsize=`get_filesize`
  local ssd_available=`df -k /ssd | awk 'NR == 2 { print $4 }'`
  local rate=`echo "scale=2; ${fsize} / ${ssd_available}" | bc`
  if [[ ! -z "${ssd_available}" && ${rate} < 30 ]] ; then
  # if [[ -z "${ssd_available}" && ${rate} < 30 ]] ; then # for testing on lustre
    ssd_tmp="/ssd/inutano/fq_tmp"
    if [[ ! -e "${ssd_tmp}" ]] ; then
      mkdir -p "${ssd_tmp}"
    fi
    echo "${ssd_tmp}"
  else
    home_tmp="/home/inutano/fq_tmp"
    if [[ ! -e "${home_tmp}" ]] ; then
      mkdir -p "${home_tmp}"
    fi
    echo "${home_tmp}"
  fi
}

retrieve_files(){ # arguments: fpath, workdir
  local path=${1}
  local dir=${2}
  rsync -avr -e ssh "${node}":"${path}"/ "${dir}"/
}

retrieve_files_ftp(){
  local path=${1}
  local dir=${2}
  lftp -c "open ${ftp_base} && mirror ${path} ${dir}"
}

exec_qc(){
  local layout=${1}
  local fpath=${2}
  local workdir=${3}
  if [[ ${layout} == "SINGLE" ]] ; then
    exec_qc_single "${fpath}" "${workdir}"
  elif [[ ${layout} == "PAIRED" ]] ; then
    exec_qc_paired "${fpath}" "${workdir}"
  else
    echo "error: read layout not defined. 'SINGLE' or 'PAIRED' should be provided"
    exit
  fi
}

exec_qc_single(){
  local fpath=${1}
  local workdir=${2}
  local fname_out=`echo ${fpath} | sed -e 's:.sra$:_fastqc.zip:g'`
  ${fastq_dump} --stdout ${fpath} |\
  ${fastqc} --outdir "${workdir}" /dev/stdin
  rename_stdin_fastqc_files "${workdir}" "${fname_out}"
}

exec_qc_single_disk(){
  local fpath=${1}
  local workdir=${2}
  ${fastq_dump} --outdir "${workdir}" ${fpath}
  ls ${workdir}/*fastq |\
  xargs ${fastqc} --outdir "${workdir}"
  rm -f ${workdir}/*html
}

exec_qc_paired(){
  local fpath=${1}
  local workdir=${2}
  local wd_read1="${2}/read1"
  local wd_read2="${2}/read2"
  local fname_out_1=`echo ${fpath} | sed -e 's:.sra$:_1_fastqc.zip:g'`
  local fname_out_2=`echo ${fpath} | sed -e 's:.sra$:_2_fastqc.zip:g'`
  mkdir -p "${wd_read1}"
  mkdir -p "${wd_read2}"
  
  ${fastq_dump} --split-3 --stdout ${fpath} |\
  tee >( awk 'NR%8 ~ /^(1|2|3|4)$/' | ${fastqc} --outdir "${wd_read1}" /dev/stdin ) |\
  awk 'NR%8 ~ /^(5|6|7|0)$/' | ${fastqc} --outdir "${wd_read2}" /dev/stdin
  rename_stdin_fastqc_files "${wd_read1}" "${fname_out_1}"
  rename_stdin_fastqc_files "${wd_read2}" "${fname_out_2}"
  
  rm -fr "${wd_read1}"
  rm -fr "${wd_read2}"
}

exec_qc_paired_disk(){
  local fpath=${1}
  local workdir=${2}
  ${fastq_dump} --split-3 --outdir "${workdir}" ${fpath}
  ls ${workdir}/*fastq |\
  xargs ${fastqc} --outdir "${workdir}"
  rm -f ${workdir}/*html
}

rename_stdin_fastqc_files(){
  local workdir=${1}
  local fname_out=${2}
  mv "${workdir}/stdin_fastqc.zip" "${fname_out}"
  #
  # put something to extract qc stats
  #
  rm -f "${workdir}/stdin_fastqc.html"
}

flush_workdir(){
  local workdir=${1}
  rm -fr ${workdir}/*sra
  rm -fr ${workdir}/*fastq*
}

#
# execute dump/fastqc
#

fpath=`get_filepath`
if [[ -z "${fpath}" ]] ; then
  echo "error"  # error
  exit
fi

fsize=`get_filesize`

# setting working dir
workdir_base=`set_workdir_base`
workdir="${workdir_base}/${exp_id_head}/${exp_id}"
if [[ ! -e "${workdir}" ]] ; then
  mkdir -p "${workdir}"
fi

# retrieve files
ftp_path=`get_filepath_ftp`
retrieve_files_ftp "${ftp_path}" "${workdir}"
exit

# dump sra files and exec fastqc
ls ${workdir}/**/*sra |\
while read f ; do
  run_dir=`echo ${f} | sed -e 's:/[^/]*sra$::g'`
  exec_qc "${layout}" "${f}" "${run_dir}"
done