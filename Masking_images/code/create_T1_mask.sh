#!/bin/bash

# Author: Your Name
# Date: 23/01/2025

# This script generates a brain mask for a single T1 or T2 image.
# It uses robustfov to adjust the field-of-view, BET to extract the brain,
# and FLIRT to register the mask back to the original image space.


# --- Step 1: Input validation ---
set -e
if [ "$#" -ne 1 ]; then # $# is the number of arguments passed to the script
    echo "Usage: $0 <input_image.nii.gz>"
    exit 1
fi

input_image="$1"
work_dir=$(dirname "$input_image")
base_name=$(basename "$input_image" .nii.gz) # Remove the file extension

#--- Step 1.5: Decide the fractional intensity threshold f for BET
f_value="${BET_F:-0.15}"


# --- Step 2:  Adjust Field of View ---

output_rbf="${work_dir}/${base_name}_robustfov.nii.gz"
echo "Running robustfov on $input_image..."
robustfov -i "$input_image" -r "$output_rbf"

# --- Step 3: Brain Extraction ---
# USe BET on robustfov output to extract the brain and mask
# -m flask outputs the mask

brain_output="${work_dir}/${base_name}_brain.nii.gz"
mask_output="${work_dir}/${base_name}_brain_mask.nii.gz"
echo "Running BET on $output_rbf..."
bet "$output_rbf" "$brain_output" -f "$f_value" -g 0 -m #-f threshold is used to decide which voxels are brain tissue. The less, the more flexible it is

# --- Step 4: Register the mask back to the original space ---
transformation_matrix="${work_dir}/${base_name}_reg.mat"
echo "Running FLIRT to compute transformation matrix..."
flirt -in "$output_rbf" -ref "$input_image" -omat "$transformation_matrix" -dof 12 -interp trilinear

# Apply transformation to mask using nn interpolation
final_mask="${work_dir}/${base_name}_mask_reggg.nii.gz"
echo "Registering the brain mask back to the original space..."
flirt -in "$mask_output" -ref "$input_image" -applyxfm -init "$transformation_matrix" -out "$final_mask" -interp nearestneighbour

echo "Brain mask generated:"
echo "$final_mask"