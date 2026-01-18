#!/usr/bin/env python3
"""MakeConfounds.py

Extract a subset of fMRIPrep confounds and write them in a simple, FSL-friendly
(tab-delimited, no header) format for FEAT.

This version is intentionally simple and (a bit) more robust than the original:
- Works with modern fMRIPrep confounds naming:
    * *_desc-confounds_timeseries.tsv (current)
    * *_desc-confounds_regressors.tsv / *-confounds_regressors.tsv (older)
- Can be run from ANY directory (paths are resolved from --fmriprepDir)
- Avoids crashing if some requested columns are missing (prints a warning)

Example:
  python code/MakeConfounds.py --fmriprepDir derivatives/fmriprep
"""

import argparse
import os
import re
from pathlib import Path

import numpy as np
import pandas as pd


def _find_confound_tsvs(fmriprep_dir: Path):
    """Return a list of confounds TSV files under an fMRIPrep derivatives folder."""
    tsvs = []
    for root, _, files in os.walk(str(fmriprep_dir)):
        for fname in files:
            if (
                fname.endswith("_desc-confounds_timeseries.tsv")
                or fname.endswith("_desc-confounds_regressors.tsv")
                or fname.endswith("-confounds_regressors.tsv")
            ):
                tsvs.append(Path(root) / fname)
    return sorted(tsvs)


def _parse_entities_from_filename(fname: str):
    """Extract sub/task/run from a BIDS-ish confounds filename."""
    # Example:
    # sub-104_task-trust_run-01_desc-confounds_timeseries.tsv
    sub = re.search(r"(sub-[^_]+)", fname)
    task = re.search(r"_task-([^_]+)", fname)
    run = re.search(r"_run-([^_]+)", fname)

    sub = sub.group(1) if sub else "sub-UNKNOWN"
    task = task.group(1) if task else "UNKNOWN"
    run = run.group(1) if run else None

    return sub, task, run


def main():
    parser = argparse.ArgumentParser(
        description="Extract a subset of fMRIPrep confounds for FSL FEAT."
    )
    parser.add_argument(
        "--fmriprepDir",
        required=True,
        type=str,
        help="Full path to the fMRIPrep derivatives directory (e.g., derivatives/fmriprep)",
    )
    args = parser.parse_args()

    fmriprep_dir = Path(args.fmriprepDir).expanduser().resolve()
    if not fmriprep_dir.exists():
        raise FileNotFoundError(f"Cannot find fmriprepDir: {fmriprep_dir}")

    confound_files = _find_confound_tsvs(fmriprep_dir)

    print(f"Found {len(confound_files)} confounds TSV file(s) under {fmriprep_dir}")

    if len(confound_files) == 0:
        print("\nNothing to do. Common causes:")
        print("  1) fMRIPrep has not finished / did not produce confounds yet")
        print("  2) Your files are named differently than expected")
        print("\nQuick check:")
        print(f"  find {fmriprep_dir} -name '*confounds*tsv' | head")
        return

    # Write outputs next to fmriprep, under derivatives/fsl/confounds/
    derivatives_root = fmriprep_dir.parent
    out_root = derivatives_root / "fsl" / "confounds"

    for conf_tsv in confound_files:
        sub, task, run = _parse_entities_from_filename(conf_tsv.name)

        con_regs = pd.read_csv(conf_tsv, sep="\t")

        # Confounds to keep (only those that actually exist will be used)
        cosine = [c for c in con_regs.columns if c.startswith("cosine")]
        nss = [c for c in con_regs.columns if c.startswith("non_steady_state") or c.startswith("non_steady_state_outlier")]
        motion = ["trans_x", "trans_y", "trans_z", "rot_x", "rot_y", "rot_z"]
        acompcor = [c for c in con_regs.columns if c.startswith("a_comp_cor_")][:6]
        fd = ["framewise_displacement"] if "framewise_displacement" in con_regs.columns else []

        requested = list(np.concatenate([cosine, nss, motion, acompcor, fd]))
        available = [c for c in requested if c in con_regs.columns]
        missing = [c for c in requested if c not in con_regs.columns]

        if missing:
            print(f"WARNING ({sub} task-{task}): missing {len(missing)} column(s): {', '.join(missing)}"
                  if len(missing) <= 6 else
                  f"WARNING ({sub} task-{task}): missing {len(missing)} column(s) (showing first 6): {', '.join(missing[:6])} ..."
            )

        df_out = con_regs[available].copy()

        # Replace NA values (FD often has NA in the first row)
        df_out.fillna(0, inplace=True)

        # Output file + folder
        outdir = out_root / sub
        outdir.mkdir(parents=True, exist_ok=True)

        if run is None:
            outfile = f"{sub}_task-{task}_desc-fslConfounds.tsv"
        else:
            outfile = f"{sub}_task-{task}_run-{run}_desc-fslConfounds.tsv"

        outpath = outdir / outfile
        df_out.to_csv(outpath, index=False, sep="\t", header=False)

        print(f"Wrote: {outpath}")


if __name__ == "__main__":
    main()
