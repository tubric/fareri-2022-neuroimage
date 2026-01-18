#!/usr/bin/env bash
# run_L1stats.sh
#
# Run Level-1 FEAT models for a fixed list of subjects/runs.
# Designed to be runnable from ANY working directory.
#
# This script runs three model types via code/L1stats.sh:
#   - 0    = activation (should be run first)
#   - dmn  = network PPI (DMN vs ECN)
#   - ecn  = network PPI (ECN vs DMN)
#
# Usage:
#   bash code/run_L1stats.sh

set -euo pipefail

# ensure paths are correct irrespective of where the user runs the script
scriptdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
basedir="$(dirname "$scriptdir")"
SCRIPTNAME="${basedir}/code/L1stats.sh"

if [[ ! -f "$SCRIPTNAME" ]]; then
  echo "ERROR: Cannot find L1stats.sh at: $SCRIPTNAME" >&2
  exit 1
fi

# Limit the number of concurrent FEAT jobs.

NCORES=20

# Hard-coded list: "SUBJECT_ID N_RUNS"
SUBJECT_RUNS=(
  "104 5" "105 5" "106 3" "107 5" "108 5" "109 2" "110 2" "111 5" "112 5" "113 5"
  "115 5" "116 5" "117 5" "118 5" "120 5" "121 5" "122 5" "124 5" "125 5" "126 5"
  "127 5" "128 5" "129 5" "130 5" "131 5" "132 5" "133 5" "134 4" "135 5" "136 2"
  "137 5" "138 4" "140 5" "141 4" "142 5" "143 3" "144 2" "145 2" "147 5" "149 4"
  "150 5" "151 5" "152 2" "153 5" "154 2" "155 5" "156 2" "157 5" "158 5" "159 5"
)

# Run activation first, then network PPIs
for ppi in 0 VMPFCwin VMPFCface VS dmn ecn; do
  for subrun in "${SUBJECT_RUNS[@]}"; do
    set -- $subrun
    sub="$1"
    nruns="$2"

    for run in $(seq 1 "$nruns"); do
      # Cap number of concurrent jobs
      while [[ $(ps -ef | grep -v grep | grep "$SCRIPTNAME" | wc -l) -ge "$NCORES" ]]; do
        sleep 1s
      done

      bash "$SCRIPTNAME" "$sub" "$run" "$ppi" &
      sleep 1s
    done
  done
done

wait
echo "All Level-1 jobs submitted/completed."
