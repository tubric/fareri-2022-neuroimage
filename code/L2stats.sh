#!/usr/bin/env bash
# L2stats.sh
#
# Run a single Level-2 (fixed-effects) FEAT analysis for one participant,
# combining runs from Level-1 FEAT outputs.
#
# Designed to be runnable from ANY working directory.
#
# Usage:
#   bash code/L2stats.sh <SUBJECT_ID> <N_RUNS> <TYPE>
# Example:
#   bash code/L2stats.sh 104 5 act

set -euo pipefail

# Resolve repo root relative to THIS script's location
scriptdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
repo_root="$(cd "${scriptdir}/.." && pwd)"

# Load FSL if needed (Neurodesk)
if ! command -v feat >/dev/null 2>&1; then
  if command -v ml >/dev/null 2>&1; then
    ml fsl/6.0.7.16 >/dev/null 2>&1 || ml fsl >/dev/null 2>&1 || true
  fi
fi

if ! command -v feat >/dev/null 2>&1; then
  echo "ERROR: FSL is not available in this shell." >&2
  echo "Fix:" >&2
  echo "  - In Neurodesktop: open the FSL terminal (recommended), OR" >&2
  echo "  - In the base terminal: run  ml fsl/<version>" >&2
  exit 1
fi

sm=6
TASK="trust"

sub="${1:?Usage: $0 <SUBJECT_ID> <N_RUNS> <TYPE>}"
nruns="${2:?Usage: $0 <SUBJECT_ID> <N_RUNS> <TYPE>}"
type="${3:?Usage: $0 <SUBJECT_ID> <N_RUNS> <TYPE>}"

MAINOUTPUT="${repo_root}/derivatives/fsl/sub-${sub}"

# Logs (write to repo root so they appear no matter where you run from)
rerun_log="${repo_root}/re-runL2.log"
skip_log="${repo_root}/skipL2.log"

# Exclusions: participants with bad data
if [[ "$sub" -eq 145 || "$sub" -eq 152 ]]; then
  echo "Skipping sub-${sub} (bad data for task-${TASK})" >> "$skip_log"
  exit 0
fi

# Build the list of run-level FEAT inputs based on study-specific exceptions.
declare -a INPUTS=()

add_input () {
  local run_id="$1"
  local featdir="${MAINOUTPUT}/L1_task-${TASK}_model-01_type-${type}_run-${run_id}_sm-${sm}.feat"
  INPUTS+=("$featdir")
}

# Default: sequential run IDs from 01..N, then override for known bad/missing runs.
if [[ "$sub" -eq 129 || "$sub" -eq 138 ]]; then
  nruns=2
  add_input "01"
  add_input "02"
elif [[ "$sub" -eq 118 ]]; then
  nruns=4
  add_input "01"
  add_input "02"
  add_input "04"
  add_input "05"
elif [[ "$sub" -eq 111 || "$sub" -eq 128 ]]; then
  nruns=4
  add_input "02"
  add_input "03"
  add_input "04"
  add_input "05"
elif [[ "$sub" -eq 150 ]]; then
  nruns=4
  add_input "01"
  add_input "03"
  add_input "04"
  add_input "05"
elif [[ "$sub" -eq 131 ]]; then
  nruns=2
  add_input "01"
  add_input "04"
else
  for r in $(seq 1 "$nruns"); do
    add_input "$(printf "%02d" "$r")"
  done
fi

# Confirm all Level-1 inputs exist before running FEAT
missing=0
for f in "${INPUTS[@]}"; do
  if [[ ! -d "$f" ]]; then
    echo "Missing L1 input: $f" >> "$rerun_log"
    missing=1
  fi
done
if (( missing == 1 )); then
  exit 0
fi

# Choose correct template + number of copes (act vs everything else)
if [[ "$type" == "act" ]]; then
  ITEMPLATE="${repo_root}/templates/L2_task-${TASK}_model-01_type-act_nruns-${nruns}.fsf"
  NCOPES=18
else
  ITEMPLATE="${repo_root}/templates/L2_task-${TASK}_model-01_type-ppi_nruns-${nruns}.fsf"
  NCOPES=19
fi

if [[ ! -f "$ITEMPLATE" ]]; then
  echo "ERROR: Cannot find template: $ITEMPLATE" >&2
  exit 1
fi

# Output folder
OUTPUT="${MAINOUTPUT}/L2_task-${TASK}_model-01_type-${type}_sm-${sm}"

# Skip if output already exists and looks complete
if [[ -e "${OUTPUT}.gfeat/cope${NCOPES}.feat/stats/zstat1.nii.gz" ]]; then
  echo "Skipping existing output: ${OUTPUT}.gfeat" >> "$skip_log"
  exit 0
fi

echo "Re-doing: ${OUTPUT}" >> "$rerun_log"
rm -rf "${OUTPUT}.gfeat"

# Write the output .fsf file into MAINOUTPUT
OTEMPLATE="${MAINOUTPUT}/L2_task-${TASK}_model-01_type-${type}.fsf"

case "$nruns" in
  5)
    sed -e "s@OUTPUT@${OUTPUT}@g"         -e "s@INPUT1@${INPUTS[0]}@g"         -e "s@INPUT2@${INPUTS[1]}@g"         -e "s@INPUT3@${INPUTS[2]}@g"         -e "s@INPUT4@${INPUTS[3]}@g"         -e "s@INPUT5@${INPUTS[4]}@g"         < "$ITEMPLATE" > "$OTEMPLATE"
    ;;
  4)
    sed -e "s@OUTPUT@${OUTPUT}@g"         -e "s@INPUT1@${INPUTS[0]}@g"         -e "s@INPUT2@${INPUTS[1]}@g"         -e "s@INPUT3@${INPUTS[2]}@g"         -e "s@INPUT4@${INPUTS[3]}@g"         < "$ITEMPLATE" > "$OTEMPLATE"
    ;;
  3)
    sed -e "s@OUTPUT@${OUTPUT}@g"         -e "s@INPUT1@${INPUTS[0]}@g"         -e "s@INPUT2@${INPUTS[1]}@g"         -e "s@INPUT3@${INPUTS[2]}@g"         < "$ITEMPLATE" > "$OTEMPLATE"
    ;;
  2)
    sed -e "s@OUTPUT@${OUTPUT}@g"         -e "s@INPUT1@${INPUTS[0]}@g"         -e "s@INPUT2@${INPUTS[1]}@g"         < "$ITEMPLATE" > "$OTEMPLATE"
    ;;
  *)
    echo "ERROR: nruns must be 2, 3, 4, or 5 (got: $nruns)" >&2
    exit 1
    ;;
esac

feat "$OTEMPLATE"

# Delete unused large files to save space
for cope in $(seq 1 "$NCOPES"); do
  rm -f "${OUTPUT}.gfeat/cope${cope}.feat/stats/res4d.nii.gz"
  rm -f "${OUTPUT}.gfeat/cope${cope}.feat/stats/corrections.nii.gz"
  rm -f "${OUTPUT}.gfeat/cope${cope}.feat/stats/threshac1.nii.gz"
  rm -f "${OUTPUT}.gfeat/cope${cope}.feat/filtered_func_data.nii.gz"
  rm -f "${OUTPUT}.gfeat/cope${cope}.feat/var_filtered_func_data.nii.gz"
done
