#!/usr/bin/env bash
# run_L3stats.sh
#
# Wrapper for code/L3stats.sh.
# Loops over a set of group-level analyses and contrasts (copes).
#
# Designed to be runnable from ANY working directory.
#
# Usage:
#   bash code/run_L3stats.sh
#
# Notes:
# - This script expects Level-2 outputs (L2 *.gfeat) to already exist.
# - On Neurodesk, you can run this from the FSL terminal, OR let the script load FSL via "ml".

set -euo pipefail

# Resolve repo root relative to THIS script's location
scriptdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
repo_root="$(cd "${scriptdir}/.." && pwd)"

SCRIPTNAME="${repo_root}/code/L3stats.sh"
if [[ ! -f "$SCRIPTNAME" ]]; then
  echo "ERROR: Cannot find L3stats.sh at: $SCRIPTNAME" >&2
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

# Concurrency: FEAT can be heavy, so keep this modest.
# You can override by running:  NCORES=8 bash code/run_L3stats.sh
NCORES="${NCORES:-}"
if [[ -z "${NCORES}" && -r /sys/fs/cgroup/cpu.max ]]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [[ "${quota}" != "max" && "${period}" -gt 0 ]]; then
    NCORES=$(( quota / period ))
  fi
fi
NCORES="${NCORES:-4}"
(( NCORES < 1 )) && NCORES=1

# -----------------------------------------------------------------------------
# STUDY-SPECIFIC SETTINGS
#
# These "analysis" strings must match the Level-2 output folder names, because
# they become part of the path used inside L3stats.sh (the REPLACEME argument).
#
# If you are not using some analysis types, remove them from this list.
# -----------------------------------------------------------------------------
ANALYSES=(
  act
  ppi_seed-vs
  ppi_seed-VMPFCwin
  ppi_seed-VMPFCface
  nppi-dmn
  nppi-ecn
)

# Contrast list: "COPE_NUMBER COPE_NAME"
# Note: Contrast N for PPI is often "phys" in these models.
COPELIST=(
  "1 c_C" "2 c_F" "3 c_S" "4 C_def" "5 C_rec" "6 F_def" "7 F_rec" "8 S_def" "9 S_rec"
  "10 rec-def" "11 face" "12 rec-def_F-S" "13 F-S" "14 F-C" "15 S-C"
  "16 rec_SocClose" "17 def_SocClose" "18 rec-def_SocClose" "19 phys"
)

for analysis in "${ANALYSES[@]}"; do
  analysistype="type-${analysis}"

  echo ""
  echo "========================================"
  echo "Level-3 analysis: ${analysistype}"
  echo "========================================"

  for copeinfo in "${COPELIST[@]}"; do
    set -- $copeinfo
    copenum="$1"
    copename="$2"

    # Skip phys for activation (if you ever add type-act here)
    if [[ "${analysistype}" == "type-act" && "${copenum}" == "19" ]]; then
      echo "Skipping phys for activation (does not exist for type-act)."
      continue
    fi

    # Cap the number of concurrent jobs launched by THIS shell
    while (( $(jobs -rp | wc -l) >= NCORES )); do
      sleep 1
    done

    echo "Launching: ${analysistype} cope${copenum} (${copename})"
    bash "$SCRIPTNAME" "$copenum" "$copename" "$analysistype" &
    sleep 0.2
  done
done

wait
echo ""
echo "All Level-3 jobs submitted/completed."
