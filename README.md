# Fareri et al. (2022) NeuroImage — Trust Game fMRI Dataset and Analyses

This repository contains code for preprocessing and analysis of the SRNDNA Trust Game dataset.

**Primary paper (empirical):**  
Fareri, D. S., Hackett, K., Tepfer, L. J., Kelly, V., Henninger, N., Reeck, C., Giovannetti, T., Smith, D. V. (2022). *Age-related differences in ventral striatal and default mode network function during reciprocated trust.* **NeuroImage, 256**, 119267. https://doi.org/10.1016/j.neuroimage.2022.119267

**Data descriptor (dataset):**  
Smith, D. V., Ludwig, R. M., Dennison, J. B., Reeck, C., & Fareri, D. S. (2024). *An fMRI Dataset on Social Reward Processing and Decision Making in Younger and Older Adults.* **Scientific Data, 11**(1), 158. https://doi.org/10.1038/s41597-024-02931-y

**OpenNeuro dataset:** ds003745


---

## Recommended environment: Neurodesk

These instructions assume you are running in **Neurodesk** (Neurodesktop / Neurodesk Play / an institution-hosted Neurodesk hub).

### Where to work (important)

We recommend working in:

- `/neurodesktop-storage/neurodesktop-storage/`

This is the standard “persistent storage” location in Neurodesk.

> fMRIPrep generates many intermediate files. The scripts in `code/` run fMRIPrep with a **work directory in `/tmp`** to avoid filling your persistent storage.


---

## Step 1 — Clone the repo

From your Neurodesk terminal:

```bash
cd /neurodesktop-storage/neurodesktop-storage
git clone https://github.com/tubric/fareri-2022-neuroimage
cd fareri-2022-neuroimage
```


---

## Step 2 — FreeSurfer license (required)

fMRIPrep requires a valid **FreeSurfer** license file.

**You must have a license file at:**
```text
~/.license
```

How to check:
```bash
ls -l ~/.license
```

If it is missing, register (free) and download `license.txt` from the FreeSurfer website, then save it as `~/.license`.

> Do **not** commit your FreeSurfer license to GitHub.


---

## Step 3 — Get the data (populate `bids/`)

This repo expects the OpenNeuro dataset (ds003745) to be present under:

```text
bids/
```

### Option A: DataLad (recommended)
```bash
rm -rf bids
datalad clone https://github.com/OpenNeuroDatasets/ds003745.git bids
datalad get -r bids/sub-*
```

### Option B: Download from OpenNeuro
Download ds003745 from OpenNeuro and place the extracted contents into `bids/`
so that it contains `sub-*/`, `dataset_description.json`, etc.


---


## fMRIPrep version note

The published preprocessing/analyses for this project used **fMRIPrep 20.1.0**.
In Neurodesk, that exact version may not be available, so we use a nearby **20.x** version instead (e.g., **20.2.3**).

Before running the scripts, load fMRIPrep in the Neurodesk terminal:

```bash
ml fmriprep/20.2.3
```

## Step 4 — Run fMRIPrep

Run a single subject:

```bash
bash code/fmriprep.sh 104
```

Run the hard-coded list of subjects (edit the list inside `code/run_fmriprep.sh` if needed):

```bash
bash code/run_fmriprep.sh
```

Outputs will be written under:

```text
derivatives/
```


---

## Step 5 — Confounds + timing files

After fMRIPrep completes:

```bash
python code/MakeConfounds.py --fmriprepDir="derivatives/fmriprep"
bash code/run_gen3colfiles.sh
```


---

## Step 6 — Statistics (FSL FEAT)

```bash
bash code/run_L1stats.sh
bash code/run_L2stats.sh
bash code/run_L3stats.sh
```


---

## Acknowledgments

This work was supported, in part, by grants from the National Institutes of Health (R21-MH113917 and R03-DA046733 to DVS and R15-MH122927 to DSF) and a Pilot Grant from the Scientific Research Network on Decision Neuroscience and Aging [to DVS; Subaward of NIH R24-AG054355 (PI Gregory Samanez-Larkin)]. We thank Elizabeth Beard for assistance with task coding, Dennis Desalme, Ben Muzekari, Isaac Levy, Gemma Goldstein, and Srikar Katta for assistance with participant recruitment and data collection, and Jeffrey Dennison for assistance with data processing. DVS was a Research Fellow of the Public Policy Lab at Temple University during the preparation of the manuscript (2019-2020 academic year).
