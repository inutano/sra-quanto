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
  files_in_dra=`ssh t347 ls /usr/local/ftp/public/ddbj_database/dra 2> /dev/null` &&:
  if [[ -z "${files_in_dra}" ]] ; then
    echo "Cannot connect to DRA node: check your ssh configuration"
    exit 1
  fi
}

get_submission_id(){
  local exp_id=${1}

  # retrieve accession table if local file is not found
  if [[ ! -e "/home/`id -nu`/.dra/latest/SRA_Accessions.tab" ]] ; then
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
  local homedir="/home/`id -nu`"
  # Create directory for SRA Accession table
  local latest_dir="${homedir}/.dra/latest"
  mkdir -p "${latest_dir}"

  # define required tables
  local accessions="${latest_dir}/SRA_Accessions.tab"
  local fastqlist="${latest_dir}/fastqlist"
  local sralist="${latest_dir}/sralist"

  # Move old accesison tables
  if [[ -e "${accessions}" ]] ; then
    backup_dir="${homedir}/.dra/"`date "+%Y%m%d"`
    mkdir -p "${backup_dir}"
    mv "${accessions}" "${backup_dir}"
    mv "${fastqlist}" "${backup_dir}"
    mv "${sralist}" "${backup_dir}"
  fi

  # retrieve from NCBI ftp
  `lftp -c "open ftp.ncbi.nlm.nih.gov:/sra/reports/Metadata && pget -O ${latest_dir} -n 8 SRA_Accessions.tab"`

  # retrieve from DDBJ ftp
  `lftp -c "open ftp.ddbj.nig.ac.jp/ddbj_database/dra/meta/list && get -O ${latest_dir} fastqlist && get -O ${latest_dir} sralist"`
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
  local fq_list=`ssh t347 ls -lk "${dra_path}/${fq_path}" 2> /dev/null`
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
  local ftp_connection_log_dir="/home/`id -nu`/.dra/ftp"

  # put a file in connection dir to avoid making multiple ftp connections
  queuing_connection "${exp_id}" "${path}"

  # connect to ftp server and change status from waiting to connected, then mirror files
  local ftp_base="ftp.ddbj.nig.ac.jp/ddbj_database/dra"
  lftp -c "open ${ftp_base} && (!mv ${ftp_connection_log_dir}/${exp_id}.waiting ${ftp_connection_log_dir}/${exp_id}.connected) && mirror ${path} ${outdir}"

  # get downloaded files out from directory
  get_file_out "${outdir}"

  # remove file from connection dir
  leave_from_queue
}

get_file_out(){
  local outdir=${1}
  # search directories
  ls -F "${outdir}" | grep '/' | while read dir; do
    ls "${outdir}/${dir}" | while read file; do
      mv "${outdir}/${dir}/${file}" "${outdir}"
    done
    rm -fr "${outdir}/${dir}"
  done
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

validate(){
  local outdir=${1}
  local files=`ls ${outdir}`
  ls "${outdir}" | while read fname ; do
    local fpath="${outdir}/${fname}"
    local md5=`md5sum "${fpath}" | awk '{ print $1 }'`

    local listdir="/home/`id -nu`/.dra/latest"

    # in case of fastq file
    if [[ "${fname}" =~ fastq ]] ; then
      local listpath="${listdir}/fastqlist"
    fi

    # in case of sra compressed file
    if [[ "${fname}" =~ sra$ ]] ; then
      local listpath="${listdir}/sralist"
    fi

    correct=`cat "${listpath}" | grep "${fname}" | cut -f 2`
    if [[ "${correct}" = "${md5}" ]] ; then
      echo "=> downloaded: ${fname}"
    else
      echo "=> wrong md5 checksum, file can be corrupt: ${fname}"
    fi
  done
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
echo "Verifying connection to DRA.."
connect_dra

# Get Submission ID from Accessions table
echo "Converting IDs.."
submission_id=`get_submission_id "${experiment_id}"`

# Get filepath to available sequence data
echo "Looking for file location.."
fpath=`get_filepath "${experiment_id}"`

# Get data via ftp
echo "Downloading data.."
retrieve "${experiment_id}" "${fpath}" "${output_directory}"

# Validate data
echo "Varidating downloaded data.."
validate "${output_directory}"
