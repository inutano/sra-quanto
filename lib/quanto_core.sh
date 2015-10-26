#!/bin/bash
#
# usage:
#   quanto_core.sh <SRA Accession ID> <SRA Experiment ID>
#
set -e

# node name to access to the sra file system
node="sranode"

# variables
acc_id=${1}
exp_id=${2}

acc_id_head=`echo ${acc_id} | sed -e 's:...$::'`
exp_id_head=`echo ${exp_id} | sed -e 's:...$::'`
exp_id_center=${exp_id:0:3}

# functions

get_filepath(){
  local dra_path="/usr/local/ftp/public/ddbj_database/dra"
  local fq_path="${dra_path}/fastq/${acc_id_head}/${acc_id}/${exp_id}"
  local fq_list=`ssh "${node}" ls -lk "${fq_path}"`
  if [[ ! -z "${fq_list}" ]] ; then
    echo ${fq_path}
  else
    local sra_path="${dra_path}/sralite/ByExp/litesra/${exp_id_center}/${exp_id_head}/${exp_id}"
    echo ${sra_path}
  fi
}

get_filesize(){
  local fpath=${1}
  ssh "${node}" ls -lkR "${fpath}" | awk '{ sum += $5 }END{ print sum }'
}

set_workdir_base(){ # sum of file size must be provided for the first argument
  local fsize=${1}
  local ssd_available=`df -k /ssd | awk 'NR == 2 { print $4 }'`
  local rate=`echo "scale=2; ${fsize} / ${ssd_available}" | bc`
  if [[ ! -z "${ssd_available}" && ${rate} < 30 ]] ; then
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

#
# execute dump/fastqc
#

fpath=`get_filepath`
if [[ -z "${fpath}" ]] ; then
  echo "error"  # error
fi

fsize=`get_filesize "${fpath}"`

# setting working dir
workdir_base=`set_workdir_base ${fsize}`
workdir="${workdir_base}/${exp_id_head}/${exp_id}"
if [[ ! -e "${workdir}" ]] ; then
  mkdir -p "${workdir}"
fi

# retrieve files
retrieve_files "${fpath}" "${workdir}"