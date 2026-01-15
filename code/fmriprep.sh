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
  ml fmriprep/20.2.3
fi

# Confirm fmriprep is available
if ! command -v fmriprep >/dev/null 2>&1; then
  echo "ERROR: fmriprep is not on PATH." >&2
  echo "If you are using Neurodesk modules, run: ml fmriprep/20.2.3" >&2
  exit 1
fi


sub="${1:?Usage: $0 <SUBJECT_ID>}"

# Resolve repo root (so the script works no matter where you call it from)
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BIDS_DIR="${repo_root}/bids"
OUT_DIR="${repo_root}/derivatives"
mkdir -p $OUT_DIR

# FreeSurfer license MUST be here
FS_LIC="${HOME}/.license"
if [[ ! -r "${FS_LIC}" ]]; then
  echo "ERROR: FreeSurfer license not found/readable at: ${FS_LIC}" >&2
  echo "Fix: Save your FreeSurfer license file as ~/.license" >&2
  exit 1
fi

# fMRIPrep work directory (large). Keep it off persistent storage.
WORK_DIR="/tmp/fareri-2022-neuroimage_fmriprep_work"

# Optional: keep FreeSurfer outputs in a predictable place
FS_SUBJECTS_DIR="${OUT_DIR}/freesurfer"

mkdir -p "${OUT_DIR}" "${WORK_DIR}" "${FS_SUBJECTS_DIR}"

# Resource settings (safe defaults). Adjust if needed.
NTHREADS="${NTHREADS:-4}"
OMP_NTHREADS="${OMP_NTHREADS:-2}"
MEM_MB="${MEM_MB:-24000}"

echo "== fMRIPrep =="
echo "  Subject:  ${sub}"
echo "  BIDS:     ${BIDS_DIR}"
echo "  OUT:      ${OUT_DIR}"
echo "  WORK:     ${WORK_DIR}"
echo "  License:  ${FS_LIC}"
echo ""

fmriprep "${BIDS_DIR}" "${OUT_DIR}" participant \
  --participant_label "${sub}" \
  --stop-on-first-crash \
  --fs-license-file "${FS_LIC}" \
  --fs-no-reconall \
  --nthreads "${NTHREADS}" \
  --omp-nthreads "${OMP_NTHREADS}" \
  --mem-mb "${MEM_MB}" \
  -w "${WORK_DIR}"
