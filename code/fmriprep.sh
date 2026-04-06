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

s#!/usr/bin/env bash
set -euo pipefail

if command -v ml >/dev/null 2>&1; then
  ml fmriprep/25.2.5
fi

# Neurodesk can inject a stale SUBJECTS_DIR
unset SUBJECTS_DIR

sub="${1:?Usage: $0 <SUBJECT_ID>}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIDS_DIR="${repo_root}/bids"
OUT_DIR="${repo_root}/derivatives/fmriprep"
WORK_DIR="${repo_root}/scratch/sub-${sub}"
FS_SUBJECTS_DIR="${OUT_DIR}/freesurfer"
FS_LIC="${HOME}/.license"

if [[ ! -r "${FS_LIC}" ]]; then
  echo "ERROR: FreeSurfer license not found/readable at: ${FS_LIC}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}" "${WORK_DIR}" "${FS_SUBJECTS_DIR}"

# Extra Neurodesk-compatible fallback:
# if something still reaches for ~/freesurfer-subjects-dir, make it point here.
LEGACY_FS_DIR="${HOME}/freesurfer-subjects-dir"
rm -rf "${LEGACY_FS_DIR}"
ln -s "${FS_SUBJECTS_DIR}" "${LEGACY_FS_DIR}"

export SUBJECTS_DIR="${FS_SUBJECTS_DIR}"
export OMP_NUM_THREADS=1
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1

echo "== fMRIPrep =="
echo "Subject: ${sub}"
echo "BIDS: ${BIDS_DIR}"
echo "OUT: ${OUT_DIR}"
echo "WORK: ${WORK_DIR}"
echo "FS subjects: ${FS_SUBJECTS_DIR}"
echo "SUBJECTS_DIR env: ${SUBJECTS_DIR}"
echo "License: ${FS_LIC}"
echo ""

env SUBJECTS_DIR="${FS_SUBJECTS_DIR}" \
fmriprep "${BIDS_DIR}" "${OUT_DIR}" participant \
  --participant-label "${sub}" \
  --stop-on-first-crash \
  --fs-license-file "${FS_LIC}" \
  --fs-subjects-dir "${FS_SUBJECTS_DIR}" \
  --fs-no-reconall \
  --skip-bids-validation \
  --output-spaces MNI152NLin6Asym \
  --nthreads 12 \
  --omp-nthreads 1 \
  --mem-mb 30000 \
  -w "${WORK_DIR}"

