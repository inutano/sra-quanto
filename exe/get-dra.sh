#!/bin/bash
#
# get-dra.sh ver 0.1.0 by inutano@gmail.com
# usable only in DDBJ supercomputer system
#
# usage:
#   get-dra <SRA Experiment ID> <Output directory>
#
set -eu

#
# functions
#

connect_dra(){
  files_in_dra=`ssh t347 ls /usr/local/ftp/public/ddbj_database/dra`
  if [[ -z "${files_in_dra}" ]] ; then
    echo "Cannot connect to DRA node: check your ssh configuration"
    exit 1
  fi
}

get_submission_id(){
  local exp_id=${1}

  # retrieve accession table if local file is not found
  if [[ ! -e "/home/`id -nu`/.dra/latest/SRA_Accessions" ]] ; then
    update_accession_table
  fi

  # extract id
  local sub_id=`awk_extract_submission_id`

  # id cannot be found if accession tabel is old: update and try again
  if [[ -z "${sub_id}" ]] ; then
    update_accession_table
    local sub_id=`awk_extract_submission_id`
  fi

  echo "${sub_id}"
}

update_accession_table(){
  # Create directory for SRA Accessiosn table
  local latest_dir="/home/`id -nu`/.dra/latest"
  mkdir -p "${latest_dir}"

  # Move old accesison table
  local accessions="/home/`id -nu`/.dra/latest/SRA_Accessions.tab"
  if [[ -e "${accessions}" ]] ; then
    backup_dir="/home/`id -nu`/.dra/"`date "+%Y%m%d"`
    mkdir -p "${backup_dir}"
    mv "${accessions}" "${backup_dir}"
  fi

  # retrieve from NCBI ftp
  `lftp -c "open ftp.ncbi.nlm.nih.gov:/sra/reports/Metadata && pget -O ${latest_dir}" -n 8 SRA_Accessions.tab`
}

awk_extract_submission_id(){
  cat "/home/`id -nu`/.dra/latest/SRA_Accessions.tab" | awk -F '\t' --assign id="${exp_id}" '$1 == id { print $2 }'
}

get_filepath(){
  local exp_id=${1}

  # try to get path to fastq file
  local fpath=`get_fq_path "${exp_id}"`

  # get path to sra file if fastq file not found
  if [[ -z "${fpath}" ]] ; then
    local fpath=`get_sra_path "${exp_id}"`
  fi

  # return filepath
  echo "${fpath}"
}

get_fq_path(){
  local exp_id=${1}

  # retrieve submission id
  local sub_id=`get_submission_id "${exp_id}"`
  local sub_id_head=`echo ${sub_id:0:6}`

  # path to fastq under ddbj_database/dra directory
  local fq_path="fastq/${sub_id_head}/${sub_id}/${exp_id}"

  # path to ddbj_database/dra on local filesystem
  local dra_path="/usr/local/ftp/public/ddbj_database/dra"

  # check if file is available
  local fq_list=`ssh "${node}" ls -lk "${dra_path}/${fq_path}"`
  if [[ ! -z "${fq_list}" ]] ; then
    echo "${fq_path}"
  fi
}

get_sra_path(){
  local exp_id=${1}
  local sra_path="sralite/ByExp/litesra/${exp_id:0:3}/${exp_id:0:6}/${exp_id}"
  echo "${sra_path}"
}

retrieve(){
  local exp_id=${1}
  local path=${2}
  local outdir=${3}

  # put a file in connection dir to avoid making multiple ftp connections
  queuing_connection "${exp_id}" "${path}"

  # connect to ftp server and change status from waiting to connected, then mirror files
  local ftp_base="ftp.ddbj.nig.ac.jp/ddbj_database/dra"
  lftp -c "open ${ftp_base} && (!mv ${ftp_connection_log_dir}/${exp_id}.waiting ${ftp_connection_log_dir}/${exp_id}.connected) && mirror ${path} ${outdir}"

  # remove file from connection dir
  leave_from_queue
}

queuing_connection(){
  local exp_id=${1}
  local fpath=${2}

  # initialize connection log dir
  local ftp_connection_log_dir="/home/`id -nu`/.dra/ftp/"
  mkdir -p "${ftp_connection_log_dir}"

  # put a file path in connection directory
  echo "${fpath}" > "${ftp_connection_log_dir}/${exp_id}.waiting"

  # avoid making too many connections (default limit is 16)
  local max_ftp_connection=16
  while [ `ls "${ftp_connection_log_dir}" | grep "connected" | wc -l` -gt "${max_ftp_connection}" ] ; do
    sleep 1
  done

  # waint until this item is oldest one in waiting queue
  while [ `ls -t "${ftp_connection_log_dir}" | grep "waiting" | tail -n 1` != "${exp_id}.waiting" ] ; do
    sleep 1
  done
}

leave_from_queue(){
  rm -f "${ftp_connection_log_dir}/${exp_id}.connected"
}

#
# variables
#
experiment_id=${1}
output_directory=${2}

#
# execute
#

# Verify connection to DRA node
connect_dra

# Get Submission ID from Accessions table
submission_id=`get_submission_id "${experiment_id}"`

# Get filepath to available sequence data
fpath=`get_filepath "${experiment_id}"`

# Get data via ftp
retrieve "${experiment_id}" "${fpath}" "${output_directory}"
