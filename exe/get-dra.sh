#!/bin/bash
#
# get-dra.sh ver 0.1.2 by inutano@gmail.com
# usable only in DDBJ supercomputer system
#
# usage:
#   get-dra.sh <SRA Experiment ID or SRA Run ID> <Output directory>
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

get_experiment_id(){
  local query_id=${1}
  case "${query_id}" in
    *RX* )
      echo "${query_id}"
      ;;
    *RR* )
      local accessions="/home/`id -nu`/.dra/latest/SRA_Accessions.tab"
      # retrieve accession table if local file is not found
      if [[ ! -e "${accessions}" ]] ; then
        update_accession_table
      fi
      cat "${accessions}" | awk -F '\t' --assign id="${query_id}" '$1 == id { print $11 }'
      ;;
  esac
}

get_run_id(){
  local query_id=${1}
  case "${query_id}" in
    *RX* )
      local run_members="/home/`id -nu`/.dra/latest/SRA_Run_Members.tab"
      # retrieve accession table if local file is not found
      if [[ ! -e "${run_members}" ]] ; then
        update_accession_table
      fi
      cat "${run_members}" | awk -F '\t' --assign id="${query_id}" '$1 == id { print $3 }'
      ;;
    *RR* )
      echo "${query_id}"
      ;;
  esac
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
  local metadata_dir="/home/`id -nu`/.dra/metadata"
  # Create directory for SRA Accession table
  local latest_dir="${metadata_dir}/latest"
  mkdir -p "${latest_dir}"

  # define required tables
  local accessions="${latest_dir}/SRA_Accessions.tab"
  local run_members="${latest_dir}/SRA_Run_Members.tab"
  local fastqlist="${latest_dir}/fastqlist"
  local sralist="${latest_dir}/sralist"

  # Move old accesison tables
  if [[ -e "${accessions}" ]] ; then
    backup_dir="${metadata_dir}/"`date "+%Y%m%d"`
    mkdir -p "${backup_dir}"
    mv "${accessions}" "${backup_dir}"
    mv "${run_members}" "${backup_dir}"
    mv "${fastqlist}" "${backup_dir}"
    mv "${sralist}" "${backup_dir}"
  fi

  # retrieve accessions and run members table from NCBI ftp
  `lftp -c "open ftp.ncbi.nlm.nih.gov:/sra/reports/Metadata && pget -O ${latest_dir} -n 8 SRA_Accessions.tab && pget -O ${latest_dir} -n 8 SRA_Run_Members.tab"`

  # retrieve from DDBJ ftp
  `lftp -c "open ftp.ddbj.nig.ac.jp/ddbj_database/dra/meta/list && get -O ${latest_dir} fastqlist && get -O ${latest_dir} sralist"`
}

awk_extract_submission_id(){
  cat "/home/`id -nu`/.dra/latest/SRA_Accessions.tab" | awk -F '\t' --assign id="${exp_id}" '$1 == id { print $2 }'
}

get_filepath(){
  local exp_id=${1}
  local run_id=${2}

  # try to get path to fastq file
  local fpath=`get_fq_path "${exp_id}"`

  # get path to sra file if fastq file not found
  if [[ -z "${fpath}" ]] ; then
    local fpath=`get_sra_path "${exp_id}" "${run_id}"`
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
  local run_id=${2}
  local sra_path="sralite/ByExp/litesra/${exp_id:0:3}/${exp_id:0:6}/${exp_id}/${run_id}"
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

validate(){
  local outdir=${1}
  local files=`ls ${outdir}`
  ls "${outdir}" | while read fname ; do
    local fpath="${outdir}/${fname}"

    case "${fname}" in
      # in case of fastq file
      *fastq* )
        echo "=> Evaluate ${fname}"
        local md5=`md5sum "${fpath}" | awk '{ print $1 }'`
        local fastqlist="/home/`id -nu`/.dra/latest/fastqlist"
        local correct=`cat ${fastqlist} | grep "${fname}" | cut -f 2`

        echo "=> md5 checksum for downloaded data: ${md5}"
        echo "=> md5 checksum from archived file list: ${correct}"

        if [[ "${correct}" = "${md5}" ]] ; then
          echo "=> downloaded correctly: ${fname}"
        else
          echo "=> wrong md5 checksum, file can be corrupt: ${fname}"
        fi
        ;;
      # in case of sra format file
      *sra )
        echo "=> Evaluate ${fname}"
        local vdb_validate=`which vdb-validate`
        if [[ -z "${vdb_validate}" ]] ; then
          echo "vdb-validate command not found; you'll need sra-toolkit"
          echo "Skipped: ${fname}"
        else
          local validate_cmd=`which vdb-validate | xargs ls -l | awk '{ print $NF }'`
          ${validate_cmd} ${outdir}/${fname} 2>&1 | tail -1
        fi
        ;;
    esac
  done
}

#
# variables
#
query_id=${1}
output_directory=${2}

#
# execute
#
echo "=> Start downloading data for ${query_id} `date`"

# Verify connection to DRA node
echo "=> Verifying connection to DRA.."
connect_dra

# Get Experiment ID, Run ID, Submission ID from Accessions table
echo "=> Converting IDs.."
experiment_id=`get_experiment_id "${query_id}"`
run_id=`get_run_id "${query_id}"`
submission_id=`get_submission_id "${experiment_id}"`

# Get filepath to available sequence data
echo "=> Looking for file location.."
fpath=`get_filepath "${experiment_id}" "${run_id}"`

# Get data via ftp
echo "=> Downloading data.."
retrieve "${experiment_id}" "${fpath}" "${output_directory}"

# Validate data
echo "=> Varidating downloaded data.."
validate "${output_directory}"

echo "=> Finished downloading data for ${query_id} `date`"
