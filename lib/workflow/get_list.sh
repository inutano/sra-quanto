#!/bin/sh
set -eu

# Get directory path
WORKDIR=$(cd $(dirname "${0}") && pwd -P)

# Path to directory of _fastqc.zip files
TARGET_DIR="${1}"

# Get DONE list
DONE_LIST="${WORKDIR}/done.txt"
find "${TARGET_DIR}" -name '*_fastqc.zip' |\
  xargs -I{} basename {} |\
  sed -e 's:_fastqc.zip$::g' |\
  sort > "${DONE_LIST}"

# Get LIVE list
LIVE_LIST="${WORKDIR}/live.txt"
curl "ftp://ftp.ncbi.nlm.nih.gov/sra/reports/Metadata/SRA_Run_Members.tab" |\
  awk -F'\t' '$8 == "live" { print $1 }' |\
  sort > "${LIVE_LIST}"

# Get UNDONE list
UNDONE_LIST="${WORKDIR}/undone.txt"
diff "${DONE_LIST}" "${LIVE_LIST}" | awk '/^>/' > "${UNDONE_LIST}"
