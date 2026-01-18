#!/usr/bin/env bash
# gen3colfiles.sh
#
# Convert BIDS *_events.tsv files into 3-column EV files for FSL FEAT.
# This script is designed to be runnable from ANY working directory.
#
# Expected repo layout:
#   <repo_root>/bids/sub-<ID>/func/*_events.tsv
#   <repo_root>/tools/bidsutils/BIDSto3col/BIDSto3col.sh
#
# Usage:
#   bash code/gen3colfiles.sh <SUBJECT_ID> <N_RUNS>
# Example:
#   bash code/gen3colfiles.sh 104 5

set -euo pipefail

# Resolve repo root relative to THIS script's location (not the current directory)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

sub="${1:?Usage: $0 <SUBJECT_ID> <N_RUNS>}"
nruns="${2:?Usage: $0 <SUBJECT_ID> <N_RUNS>}"

# Location of the BIDSto3col converter (from bidsutils submodule)
bids2col="${repo_root}/tools/bidsutils/BIDSto3col/BIDSto3col.sh"

if [[ ! -f "${bids2col}" ]]; then
  echo "ERROR: Cannot find BIDSto3col.sh at:" >&2
  echo "  ${bids2col}" >&2
  echo "" >&2
  echo "Fix (from repo root):" >&2
  echo "  git submodule update --init --recursive" >&2
  exit 1
fi

# Input BIDS directory
bids_dir="${repo_root}/bids"

if [[ ! -d "${bids_dir}" ]]; then
  echo "ERROR: BIDS directory not found at: ${bids_dir}" >&2
  echo "Make sure the OpenNeuro dataset is present under <repo_root>/bids/." >&2
  exit 1
fi

# Output directory (mirrors your existing structure)
out_base="${repo_root}/derivatives/fsl/EVfiles/sub-${sub}/trust"
mkdir -p "${out_base}"

for run in $(seq 1 "${nruns}"); do
  run_id="$(printf "%02d" "${run}")"

  # Input events file (BIDS naming)
  events_tsv="${bids_dir}/sub-${sub}/func/sub-${sub}_task-trust_run-${run_id}_events.tsv"

  if [[ ! -f "${events_tsv}" ]]; then
    echo "ERROR: Cannot find events file:" >&2
    echo "  ${events_tsv}" >&2
    exit 1
  fi

  # Output prefix for BIDSto3col (it creates multiple files with this prefix)
  out_prefix="${out_base}/run-${run_id}"

  echo "Generating EV files for sub-${sub}, run-${run_id}"
  bash "${bids2col}" "${events_tsv}" "${out_prefix}"
done

echo "Done. EV files written under:"
echo "  ${repo_root}/derivatives/fsl/EVfiles/sub-${sub}/trust/"
