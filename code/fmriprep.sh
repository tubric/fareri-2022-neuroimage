#!/usr/bin/env bash
# Run fMRIPrep for ONE participant (Neurodesk-friendly).
#
# Usage:
#   bash code/fmriprep.sh <SUBJECT_ID>
# Example:
#   bash code/fmriprep.sh 104
#
# Requirements:
#   - BIDS dataset located at:   <repo>/bids
#   - FreeSurfer license at:    ~/.license
#
# Notes:
#   - This script is intentionally simple (novice-friendly).
#   - fMRIPrep produces a large working directory, so we use /tmp by default.

set -euo pipefail

# Load fMRIPrep in Neurodesk (module system).
# If your system uses Neurodesk modules, this puts the requested fMRIPrep version on PATH.
if command -v ml >/dev/null 2>&1; then
  ml fmriprep/25.2.5
fi


sub="${1:?Usage: $0 <SUBJECT_ID>}"

# Resolve repo root (so the script works no matter where you call it from)
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BIDS_DIR="${repo_root}/bids"
OUT_DIR="${repo_root}/derivatives"

# FreeSurfer license MUST be here
FS_LIC="${HOME}/.license"
if [[ ! -r "${FS_LIC}" ]]; then
  echo "ERROR: FreeSurfer license not found/readable at: ${FS_LIC}" >&2
  echo "Fix: Save your FreeSurfer license file as ~/.license" >&2
  exit 1
fi

# fMRIPrep work directory
WORK_DIR="${repo_root}/scratch"

# Keep FreeSurfer-related outputs in a predictable place
FS_SUBJECTS_DIR="${OUT_DIR}/freesurfer"

mkdir -p "${OUT_DIR}" "${WORK_DIR}" "${FS_SUBJECTS_DIR}"

# Make sure we do not inherit a stale SUBJECTS_DIR from the environment
export SUBJECTS_DIR="${FS_SUBJECTS_DIR}"

echo "== fMRIPrep =="
echo "  Subject:      ${sub}"
echo "  BIDS:         ${BIDS_DIR}"
echo "  OUT:          ${OUT_DIR}"
echo "  WORK:         ${WORK_DIR}"
echo "  FS subjects:  ${FS_SUBJECTS_DIR}"
echo "  License:      ${FS_LIC}"
echo ""

# avoid oversubscribing when running multiple instances of fmriprep
export OMP_NUM_THREADS=1
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1

fmriprep "${BIDS_DIR}" "${OUT_DIR}" participant \
  --participant-label "${sub}" \
  --stop-on-first-crash \
  --fs-license-file "${FS_LIC}" \
  --fs-subjects-dir "${FS_SUBJECTS_DIR}" \
  --fs-no-reconall \
  --skip-bids-validation \
  --nthreads 12 \
  --omp-nthreads 1 \
  --mem-mb 30000 \
  -w "${WORK_DIR}"
