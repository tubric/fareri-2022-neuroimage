#!/usr/bin/env bash
# run_L2stats.sh
#
# Run Level-2 (fixed-effects across runs) FEAT models for each participant.
# Designed to be runnable from ANY working directory.
#
# Usage:
#   bash code/run_L2stats.sh
#
# Notes:
# - This script expects Level-1 outputs produced by code/L1stats.sh.
# - On Neurodesk, run this from the FSL terminal, OR let the script load FSL via "ml".

set -euo pipefail

# Resolve repo root relative to THIS script's location
scriptdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
repo_root="$(cd "${scriptdir}/.." && pwd)"

SCRIPTNAME="${repo_root}/code/L2stats.sh"
if [[ ! -f "$SCRIPTNAME" ]]; then
  echo "ERROR: Cannot find L2stats.sh at: $SCRIPTNAME" >&2
  exit 1
fi

# Load FSL once (children inherit the environment)
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

# Concurrency (keep conservative; FEAT can be heavy)
NCORES="${NCORES:-}"
if [[ -z "${NCORES}" && -r /sys/fs/cgroup/cpu.max ]]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [[ "${quota}" != "max" && "${period}" -gt 0 ]]; then
    NCORES=$(( quota / period ))
  fi
fi
NCORES="${NCORES:-4}"
(( NCORES < 1 )) && NCORES=1

# IMPORTANT: these "type" strings must match your Level-1 output folder names.
# (See L1stats.sh output naming.)
TYPES=(
  act
  ppi_seed-vs
  ppi_seed-VMPFCwin
  ppi_seed-VMPFCface
  nppi-dmn
  nppi-ecn
)

# Hard-coded list: "SUBJECT_ID N_RUNS"
SUBJECT_RUNS=(
  "104 5" "105 5" "106 3" "107 5" "108 5" "109 2" "110 2" "111 5" "112 5" "113 5"
  "115 5" "116 5" "117 5" "118 5" "120 5" "121 5" "122 5" "124 5" "125 5" "126 5"
  "127 5" "128 5" "129 5" "130 5" "131 5" "132 5" "133 5" "134 4" "135 5" "136 2"
  "137 5" "138 4" "140 5" "141 4" "142 5" "143 3" "144 2" "145 2" "147 5" "149 4"
  "150 5" "151 5" "152 2" "153 5" "154 2" "155 5" "156 2" "157 5" "158 5" "159 5"
)

for type in "${TYPES[@]}"; do
  echo ""
  echo "========================================"
  echo "Level-2 model type: ${type}"
  echo "========================================"

  for subrun in "${SUBJECT_RUNS[@]}"; do
    set -- $subrun
    sub="$1"
    nruns="$2"

    # Limit the number of concurrent jobs launched by THIS shell
    while (( $(jobs -rp | wc -l) >= NCORES )); do
      sleep 1
    done

    echo "Launching sub-${sub} (nruns=${nruns}) type=${type}"
    bash "$SCRIPTNAME" "$sub" "$nruns" "$type" &
    sleep 0.2
  done
done

wait
echo ""
echo "All Level-2 jobs submitted/completed."
