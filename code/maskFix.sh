# Run this in the same environment where ANTs + TemplateFlow are available
# (for example, your fMRIPrep environment in Neurodesk).

# ensure paths are correct irrespective from where user runs the script
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
maindir="$(dirname "$scriptdir")"

# Reference image: pick an example_func that is already in MNI152NLin6Asym
REF=$maindir/derivatives/fsl/sub-104//L1_task-trust_model-01_type-act_run-01_sm-6.feat/example_func.nii.gz

# Folder for outputs
OUTDIR=$maindir/masks/seed_reslice_MNI2009c_to_MNI6
mkdir -p "$OUTDIR"

# Fetch the two template T1w images from TemplateFlow at 2 mm
SRC_T1=$(python - <<'PY'
import templateflow.api as tflow
print(tflow.get('MNI152NLin2009cAsym', resolution=2, desc=None, suffix='T1w'))
PY
)

TGT_T1=$(python - <<'PY'
import templateflow.api as tflow
print(tflow.get('MNI152NLin6Asym', resolution=2, desc=None, suffix='T1w'))
PY
)

echo "Source template: $SRC_T1"
echo "Target template: $TGT_T1"

# 1) Compute the transform once: moving = 2009cAsym, fixed = NLin6Asym
antsRegistrationSyNQuick.sh \
  -d 3 \
  -f "$TGT_T1" \
  -m "$SRC_T1" \
  -o "$OUTDIR/MNI2009c_to_MNI6_"

# 2) Apply the transform to each seed mask, writing onto the example_func grid
for seed in seed-VMPFCwin_trust.nii.gz seed-VS_trust.nii.gz; do
  base=$(basename "$seed" .nii.gz)

  antsApplyTransforms \
    -d 3 \
    -i "$maindir/masks/$seed" \
    -r "$REF" \
    -o "$OUTDIR/${base}_space-MNI152NLin6Asym_res-2.nii.gz" \
    -n GenericLabel \
    -t "$OUTDIR/MNI2009c_to_MNI6_1Warp.nii.gz" \
    -t "$OUTDIR/MNI2009c_to_MNI6_0GenericAffine.mat"

  # Re-binarize just to be safe
  fslmaths "$OUTDIR/${base}_space-MNI152NLin6Asym_res-2.nii.gz" \
    -thr 0.5 -bin \
    "$OUTDIR/${base}_space-MNI152NLin6Asym_res-2.nii.gz"
done

# 3) Quick QC
fsleyes "$REF" \
  "$OUTDIR/seed-VMPFCwin_trust_space-MNI152NLin6Asym_res-2.nii.gz" \
  "$OUTDIR/seed-VS_trust_space-MNI152NLin6Asym_res-2.nii.gz" &