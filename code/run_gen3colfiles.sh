#!/usr/bin/env bash
# run_gen3colfiles.sh
#
# Run gen3colfiles.sh for a fixed list of subjects and run counts.
# Designed to be runnable from ANY working directory.
#
# Usage:
#   bash code/run_gen3colfiles.sh

set -euo pipefail

# Resolve repo root relative to THIS script's location
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

gen_script="${repo_root}/code/gen3colfiles.sh"

if [[ ! -f "${gen_script}" ]]; then
  echo "ERROR: Cannot find gen3colfiles.sh at:" >&2
  echo "  ${gen_script}" >&2
  exit 1
fi

# Hard-coded list: "SUBJECT_ID N_RUNS"
SUBJECT_RUNS=(
  "104 5" "105 5" "106 3" "107 5" "108 5" "109 2" "110 2" "111 5" "112 5" "113 5"
  "115 5" "116 5" "117 5" "118 5" "120 5" "121 5" "122 5" "124 5" "125 5" "126 5"
  "127 5" "128 5" "129 5" "130 5" "131 5" "132 5" "133 5" "134 4" "135 5" "136 2"
  "137 5" "138 4" "140 5" "141 4" "142 5" "143 3" "144 2" "145 2" "147 5" "149 4"
  "150 5" "151 5" "152 2" "153 5" "154 2" "155 5" "156 2" "157 5" "158 5" "159 5"
)

for pair in "${SUBJECT_RUNS[@]}"; do
  # Split "sub nruns"
  set -- ${pair}
  sub="$1"
  nruns="$2"

  echo ""
  echo "=============================="
  echo "sub-${sub} (${nruns} run(s))"
  echo "=============================="

  bash "${gen_script}" "${sub}" "${nruns}"
done

echo ""
echo "All EV files generated."
