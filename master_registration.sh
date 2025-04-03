#!/usr/bin/env bash

#Author: Jp
#Date: 19/03/2025

# This script orchestrates the pipeline steps for each patient folder:
#   1) Create T1 Mask (create_T1_mask.sh)
#   2) N4 bias correction (n4_correction.py)
#   3) (Optional) Re-run T1 mask with refined threshold
#   4) Check correction (check_correction.py)
#   5) Reorient (reorient.py)
#   6) Co-registration (coreg_pipeline.py)
#   7) Main check (main.py)

# USAGE:
#   ./master_registration.sh /path/to/patients_root

# The script assumes each patient folder contains:
#   T1.nii.gz
#   T2_FLAIR.nii.gz
#   lesion_mask.nii.gz
#   mag.nii.gz (Magnitude)
#   qsm.nii.gz

set -e # Exit immediately on error
set -u # Treat unset variables as errors
set -o pipefail # Prevent errors in a pipeline from being masked
#set -x # Debug

# Activate python virtual env

source venv/bin/activate


#################################################
#1) Input validation
#################################################

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/patients_root"
  exit 1
fi

PATIENTS_ROOT="$1"

# Check if the directory exists
if [ ! -d "$PATIENTS_ROOT" ]; then
  echo "Error: $PATIENTS_ROOT is not a valid directory."
  exit 1
fi

for patient_dir in "$PATIENTS_ROOT"/*/; do
  # Strip trailing slash for cleanliness
  patient_dir="${patient_dir%/}"
  patient_id=$(basename "$patient_dir")

  echo "===================================================================================================="
  echo "PROCESSING PATIENT: $patient_id"
  echo "FOLDER PATH: $patient_dir"
  echo "===================================================================================================="
  
  for year_dir in "$patient_dir"/20*/; do
  
    #Check dir
    [ -d "$year_dir" ] || continue

    year_folder_name=$(basename "$year_dir")

    echo "Found subfolder: $year_folder_name"

    # Define expected file paths
    T1_IMAGE="$year_dir/T1.nii.gz"
    T2_FLAIR_IMAGE="$year_dir/T2_FLAIR.nii.gz"
    LESION_MASK="$year_dir/lesion_mask.nii"
    MAG_IMAGE="$year_dir/mag.nii.gz"
    QSM_IMAGE="$year_dir/QSM.nii.gz"

    echo "===================================================================================================="
    echo "[INFO] Creating broad T1 mask for $T1_IMAGE..."

    Masking_images/code/create_T1_mask.sh "$T1_IMAGE" 

    echo "[INFO] Done mask creation for patient: $patient_id $year_folder_name"
    echo "===================================================================================================="
    echo ""
    
    # Expected mask path
    base_name=$(basename "$T1_IMAGE" .nii.gz)
    final_mask="$year_dir/${base_name}_mask_reggg.nii.gz"
    
    #Add an if statement just in case the image is not there
    if [ ! -f "$final_mask" ]; then
        echo "ERROR: Could not find the final mask at $final_mask"
        echo "Check create_mask.sh output. Skipping this patient."
        continue
    fi

    

    echo "===================================================================================================="
    echo "[INFO] Running N4 bias correction on $T1_IMAGE..."
    T1_CORRECTED="$year_dir/${base_name}_corrected.nii.gz"

    python3 Masking_images/bias_field/n4_correction.py \
        --input_image "$T1_IMAGE" \
        --mask_image "$final_mask" \
        --output_image "$T1_CORRECTED"

    if [ ! -f "$T1_CORRECTED" ]; then
        echo "ERROR: N4 correction output not found at $T1_CORRECTED"
        continue
    fi

    base_name_flair=$(basename "$T2_FLAIR_IMAGE" .nii.gz)
    FLAIR_CORRECTED="$year_dir/${base_name_flair}_corrected.nii.gz"

    echo "[INFO] Running N4 bias correction on $T2_FLAIR_IMAGE..."

    python3 Masking_images/bias_field/n4_correction.py \
        --input_image "$T2_FLAIR_IMAGE" \
        --mask_image "$final_mask" \
        --output_image "$FLAIR_CORRECTED"

    if [ ! -f "$FLAIR_CORRECTED" ]; then
        echo "ERROR: N4 correction output not found at $FLAIR_CORRECTED"
        continue
    fi
    echo "[INFO] Done bias correction for patient: $patient_id $year_folder_name"
    echo "===================================================================================================="
    echo "[INFO] Re-running T1 mask on corrected image with f=0.3"
    BET_F=0.3 Masking_images/code/create_T1_mask.sh "$T1_CORRECTED"
    echo "===================================================================================================="

    # Reorient images
    echo "===================================================================================================="
    echo "[INFO] Reorienting Images to canonical space"
    
    python3 exploratory_pipeline/preprocessing/reorient.py \
        --input "$T1_CORRECTED" "$FLAIR_CORRECTED" "$LESION_MASK" "$MAG_IMAGE" "$QSM_IMAGE" \
        --output_dir "$year_dir/reoriented"

    echo "===================================================================================================="
    echo "[INFO] Running registration to QSM space"

    # Extract the correct files to work with
    reoriented_dir="$year_dir/reoriented"

    # Initialize variables 
    T1_CANONICAL=""
    FLAIR_CANONICAL=""
    LESION_CANONICAL=""
    MAG_CANONICAL=""
    QSM_CANONICAL=""

    for f in "$reoriented_dir"/*_canonical.nii.gz; do
    filename=$(basename "$f")

    # Match based on substring
    if [[ "$filename" == *"T1"* ]]; then
        T1_CANONICAL="$f"

        echo "T1_CANONICAL: $T1_CANONICAL"
    elif [[ "$filename" == *"T2_FLAIR"* ]]; then
        FLAIR_CANONICAL="$f"
    elif [[ "$filename" == *"lesion_mask"* ]]; then
        LESION_CANONICAL="$f"
    elif [[ "$filename" == *"mag"* ]]; then
        MAG_CANONICAL="$f"
    elif [[ "$filename" == *"QSM"* ]]; then
        QSM_CANONICAL="$f"
    fi
    done


    mkdir -p "$year_dir/registered"
    #Copy or symlink the canonical images
    cp "$T1_CANONICAL"       "$year_dir/registered/"
    cp "$FLAIR_CANONICAL"    "$year_dir/registered/"
    cp "$LESION_CANONICAL"   "$year_dir/registered/"
    cp "$MAG_CANONICAL"      "$year_dir/registered/"
    cp "$QSM_CANONICAL"      "$year_dir/registered/"

    # Now define the new paths in the "registered" folder
    T1_FOR_COREG="$year_dir/registered/$(basename "$T1_CANONICAL")"
    FLAIR_FOR_COREG="$year_dir/registered/$(basename "$FLAIR_CANONICAL")"
    LESION_FOR_COREG="$year_dir/registered/$(basename "$LESION_CANONICAL")"
    MAG_FOR_COREG="$year_dir/registered/$(basename "$MAG_CANONICAL")"
    QSM_FOR_COREG="$year_dir/registered/$(basename "$QSM_CANONICAL")"

    python3 exploratory_pipeline/registration/coreg_pipeline.py \
        --t1 "$T1_FOR_COREG" \
        --flair "$FLAIR_FOR_COREG" \
        --magnitude "$MAG_FOR_COREG" \
        --mask "$LESION_FOR_COREG" \
  
  done # End of year_dir loop

done # End of patient_dir loop
echo "===================================================================================================="
echo "All patients processed successfully."



























