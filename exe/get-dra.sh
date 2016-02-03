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

get_dra_dir(){
  local dra_dir="/home/`id -nu`/.dra"
  echo "${dra_dir}"
}

get_metadata_dir(){
  local dra_dir=`get_dra_dir`
  local metadata_dir="${dra_dir}/metadata"
  echo "${metadata_dir}"
}

get_ftp_connection_log_dir(){
  local dra_dir=`get_dra_dir`
  local ftp_connection_log_dir="${dra_dir}/ftp"
  echo "${ftp_connection_log_dir}"
}

set_output_directory(){
  local outdir_path=${1}
  local query_id=${2}
  local outdir="${outdir_path}/${query_id}"
  mkdir -p "${outdir}"
  echo "${outdir}"
}

connect_dra(){
  files_in_dra=`ssh t347 ls /usr/local/ftp/public/ddbj_database/dra 2> /dev/null` &&:
  if [[ -z "${files_in_dra}" ]] ; then
    echo "==== Error! cannot connect to DRA node: check your ssh configuration ===="
    exit 1
  fi
}

get_experiment_id(){
  local query_id=${1}
  case "${query_id}" in
    *RR* )
      # retrieve accession table if local file is not found
      local metadata_dir=`get_metadata_dir`
      local run_members="${metadata_dir}/latest/SRA_Run_Members.tab"
      retrieve_accession_table

      local exp_id=`cat "${run_members}" | awk -F '\t' --assign id="${query_id}" '$1 ~ id { print $3 }'`
      case "${exp_id}" in
        *RX* )
          echo "${exp_id}"
          ;;
        * )
          exit 1
          ;;
      esac
      ;;
    *RX* )
      echo "${query_id}"
      ;;
  esac
}

get_submission_id(){
  local exp_id=${1}

  # retrieve accession table if local file is not found
  retrieve_accession_table

  # extract id
  local sub_id=`awk_extract_submission_id`

  # id cannot be found if accession tabel is old: update and try again
  if [[ -z "${sub_id}" ]] ; then
    update_accession_table
    local sub_id=`awk_extract_submission_id`
  fi

  echo "${sub_id}"
}

retrieve_accession_table(){
  local metadata_dir=`get_metadata_dir`
  local latest_dir="${metadata_dir}/latest"
  if [[ ! -e  "${latest_dir}" ]] ; then
    update_accession_table
  fi
}

update_accession_table(){
  # Create directory for SRA Accession table
  local metadata_dir=`get_metadata_dir`
  local backup_dir="${metadata_dir}/"`date "+%Y%m%d"`
  mkdir -p "${backup_dir}"

  # retrieve accessions and run members table from NCBI ftp
  `lftp -c "open ftp.ncbi.nlm.nih.gov:/sra/reports/Metadata && pget -O ${backup_dir} -n 8 SRA_Accessions.tab && pget -O ${backup_dir} -n 8 SRA_Run_Members.tab"`

  # retrieve from DDBJ ftp
  `lftp -c "open ftp.ddbj.nig.ac.jp/ddbj_database/dra/meta/list && get -O ${backup_dir} fastqlist && get -O ${backup_dir} sralist"`

  # erase current latest data dir and symlinks, then create new links
  local latest_dir="${metadata_dir}/latest"
  rm -fr "${latest_dir}" && mkdir -p "${latest_dir}"
  ln -s "${backup_dir}/SRA_Accessions.tab" "${latest_dir}/SRA_Accessions.tab"
  ln -s "${backup_dir}/SRA_Run_Members.tab" "${latest_dir}/SRA_Run_Members.tab"
  ln -s "${backup_dir}/fastqlist" "${latest_dir}/fastqlist"
  ln -s "${backup_dir}/sralist" "${latest_dir}/sralist"
}

awk_extract_submission_id(){
  local metadata_dir=`get_metadata_dir`
  cat "${metadata_dir}/latest/SRA_Accessions.tab" | awk -F '\t' --assign id="${exp_id}" '$1 == id { print $2 }'
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
  local ftp_connection_log_dir=`get_ftp_connection_log_dir`

  # put a file in connection dir to avoid making multiple ftp connections
  queuing_connection "${exp_id}" "${path}"

  # connect to ftp server and change status from waiting to connected, then mirror files
  local ftp_base="ftp.ddbj.nig.ac.jp/ddbj_database/dra"
  lftp -c "open ${ftp_base} && (!mv ${ftp_connection_log_dir}/${exp_id}.waiting ${ftp_connection_log_dir}/${exp_id}.connected) && mirror ${path} ${outdir}"

  # put out sra files
  srafile_out "${outdir}"

  # remove file from connection dir
  leave_from_queue
}

srafile_out(){
  local outdir=${1}
  ls -F "${outdir}" | grep '/' | grep 'RR' | while read dir; do
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
  local ftp_connection_log_dir=`get_ftp_connection_log_dir`
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
  ls "${outdir}" | grep '.sra$' | while read fname ; do
    local fpath="${outdir}/${fname}"

    case "${fname}" in
      # in case of fastq file
      *fastq* )
        echo "=> Evaluate ${fname}"
        local md5=`md5sum "${fpath}" | awk '{ print $1 }'`
        local metadata_dir=`get_metadata_dir`
        local fastqlist="${metadata_dir}/latest/fastqlist"
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
output_directory_path=${2}

#
# execute
#
echo "=> Start downloading data for ${query_id} `date`"
output_directory=`set_output_directory "${output_directory_path}" "${query_id}"`

# Verify connection to DRA node
echo "=> Verifying connection to DRA.."
connect_dra

# Get Experiment ID, Run ID, Submission ID from Accessions table
echo "=> Converting IDs.."
experiment_id=`get_experiment_id "${query_id}"`
submission_id=`get_submission_id "${experiment_id}"`

# Get filepath to available sequence data
echo "=> Looking for file location.."
fpath=`get_filepath "${experiment_id}"`

# Get data via ftp
echo "=> Downloading data.."
retrieve "${experiment_id}" "${fpath}" "${output_directory}"

# Validate data
echo "=> Varidating downloaded data.."
validate "${output_directory}"

echo "=> Finished downloading data for ${query_id} `date`"
