#!/usr/bin/env bash
# L3stats.sh
#
# Run Level-3 (group-level) statistics in FSL FEAT.
#
# This script runs three group analyses for a given cope:
#   1) Two groups (older vs younger)
#   2) Two groups + covariates
#   3) One group average
#
# Optional: This script can also run randomise (permutation-based stats) on
# completed FEAT outputs. By default, randomise only runs for contrasts at or
# above a threshold (see copenum_thresh_randomise).
#
# Designed to be runnable from ANY working directory.
#
# Usage:
#   bash code/L3stats.sh <COPE_NUM> <COPE_NAME> <ANALYSIS_TYPE>
# Example:
#   bash code/L3stats.sh 10 rec-def type-melodic-nppi-dmn

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

# -----------------------------------------------------------------------------
# STUDY-SPECIFIC SETTINGS
# -----------------------------------------------------------------------------
task="trust"
N=48

# Inputs (from run_L3stats.sh)
copenum="${1:?Usage: $0 <COPE_NUM> <COPE_NAME> <ANALYSIS_TYPE>}"
copename="${2:?Usage: $0 <COPE_NUM> <COPE_NAME> <ANALYSIS_TYPE>}"
REPLACEME="${3:?Usage: $0 <COPE_NUM> <COPE_NAME> <ANALYSIS_TYPE>}"

# Randomise settings
copenum_thresh_randomise=10
n_perm=10000
tfce_c=2.6

# Output folder for this study
MAINOUTPUT="${repo_root}/derivatives/fsl/L3_model-01_task-${task}_n${N}_flame1+2_retest"
mkdir -p "$MAINOUTPUT"

# Logs (always written to repo root so they're easy to find)
rerun_log="${repo_root}/re-runL3.log"
skip_log="${repo_root}/skipL3.log"

cnum_pad="$(zeropad "${copenum}" 2)"

maybe_run_randomise () {
  local copefeat_dir="$1"      # .../cope1.feat
  local expected_file="$2"     # e.g., randomise_tfce_corrp_tstat4.nii.gz

  if [[ "${copenum}" -lt "${copenum_thresh_randomise}" ]]; then
    return 0
  fi

  if [[ -e "${copefeat_dir}/${expected_file}" ]]; then
    return 0
  fi

  echo "Running randomise in: ${copefeat_dir}" >> "$rerun_log"
  (
    cd "$copefeat_dir"
    randomise -i filtered_func_data.nii.gz               -o randomise               -d design.mat               -t design.con               -m mask.nii.gz               -T -c "${tfce_c}" -n "${n_perm}"
  )
}

cleanup_feat () {
  local gfeat_dir="$1"
  # Remove a few large files that are not usually needed later.
  # NOTE: We keep filtered_func_data by default because it can be useful for randomise.
  for copefeat in "${gfeat_dir}"/cope*.feat; do
    [[ -d "$copefeat" ]] || continue
    rm -f "${copefeat}/stats/res4d.nii.gz"
    rm -f "${copefeat}/stats/corrections.nii.gz"
    rm -f "${copefeat}/stats/threshac1.nii.gz"
    rm -f "${copefeat}/var_filtered_func_data.nii.gz"
    # rm -f "${copefeat}/filtered_func_data.nii.gz"
  done
}

run_block () {
  local label="$1"              # twogroup | twogroup_wCovs | onegroup_new
  local template="$2"           # path to .fsf template
  local expected_randomise="$3" # expected randomise file (may be empty)

  local OUTPUT="${MAINOUTPUT}/L3_task-${task}_${REPLACEME}_cnum-${cnum_pad}_cname-${copename}_${label}"

  # If FEAT is finished, optionally run randomise (then return)
  if [[ -e "${OUTPUT}.gfeat/cope1.feat/cluster_mask_zstat1.nii.gz" ]]; then
    echo "Skipping existing output: ${OUTPUT}.gfeat" >> "$skip_log"
    if [[ -n "${expected_randomise}" ]]; then
      maybe_run_randomise "${OUTPUT}.gfeat/cope1.feat" "${expected_randomise}"
    fi
    return 0
  fi

  echo "Re-doing: ${OUTPUT}" >> "$rerun_log"
  rm -rf "${OUTPUT}.gfeat"

  if [[ ! -f "$template" ]]; then
    echo "ERROR: Missing template: $template" >&2
    exit 1
  fi

  # Create and run FEAT design
  local OTEMPLATE="${MAINOUTPUT}/L3_task-${task}_${REPLACEME}_copenum-${copenum}_${label}.fsf"

  sed -e "s@OUTPUT@${OUTPUT}@g"       -e "s@COPENUM@${copenum}@g"       -e "s@REPLACEME@${REPLACEME}@g"       -e "s@BASEDIR@${repo_root}@g"       < "$template" > "$OTEMPLATE"

  feat "$OTEMPLATE"

  cleanup_feat "${OUTPUT}.gfeat"
}

# -----------------------------------------------------------------------------
# 1) Two groups
# -----------------------------------------------------------------------------
run_block   "twogroup"   "${repo_root}/templates/L3_template_n${N}_${task}_twogroup.fsf"   "randomise_tfce_corrp_tstat4.nii.gz"

# -----------------------------------------------------------------------------
# 2) Two groups with covariates
# -----------------------------------------------------------------------------
run_block   "twogroup_wCovs"   "${repo_root}/templates/L3_template_n${N}_${task}_twogroup_wCovs.fsf"   "randomise_tfce_corrp_tstat4.nii.gz"

# -----------------------------------------------------------------------------
# 3) One group
# -----------------------------------------------------------------------------
run_block   "onegroup_new"   "${repo_root}/templates/L3_template_n${N}_${task}_onegroup.fsf"   "randomise_tfce_corrp_tstat2.nii.gz"
