#!/bin/sh
set -eu

# Path to directory of _fastqc.zip files: Exit if not passed
TARGET_DIR_PATH="${1}"
TARGET_DIR="$(cd ${TARGET_DIR_PATH} && pwd -P)"

# Get directory path
WORKDIR=$(cd $(dirname "${0}") && pwd -P)
TMPDIR="${WORKDIR}/$(date +%Y%m%d-%H%M)"
mkdir -p "${TMPDIR}"

# Squash
DONE_LIST="${TMPDIR}/done.txt"
LIVE_LIST="${TMPDIR}/live.txt"
UNDONE_LIST="${TMPDIR}/undone.txt"

# Get DONE list
find "${TARGET_DIR}" -name '*_fastqc.zip' |\
  xargs -I{} basename {} |\
  sed -e 's:_fastqc.zip$::g' |\
  sort > "${DONE_LIST}"

# Get LIVE list
curl "ftp://ftp.ncbi.nlm.nih.gov/sra/reports/Metadata/SRA_Run_Members.tab" |\
  awk -F'\t' '$8 == "live" { print $1 }' |\
  sort > "${LIVE_LIST}"

# Get UNDONE list
diff "${DONE_LIST}" "${LIVE_LIST}" | awk '/^>/' > "${UNDONE_LIST}"
