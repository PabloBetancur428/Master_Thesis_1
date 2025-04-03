#!/usr/bin/env bash
#
# gather_t1_t2.sh
#
# Purpose:
#   For each patient in a "done_qsm" root directory, find the T1 and T2-FLAIR files
#   (based on substring matches), create a new folder for that patient in a target
#   location, and copy them there.

# 1) Basic Checks and Input Validation
#/home/jbetancur/Desktop/Scripts_QSM/test/done_qsm
#/home/jbetancur/Desktop/codes/python_qsm/exploratory_pipeline/data_automatization/pruebas
###############################################
set -e  # Exit on error
set -u  # Treat unset variables as errors
set -o pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 /path/to/done_qsm /path/to/output_dir"
  exit 1
fi

DONE_QSM_ROOT="$1"
OUTPUT_ROOT="$2"

# Check if DONE_QSM_ROOT is a directory
if [ ! -d "$DONE_QSM_ROOT" ]; then
  echo "Error: $DONE_QSM_ROOT is not a directory."
  exit 1
fi

mkdir -p "$OUTPUT_ROOT"

for patient_dir in "$DONE_QSM_ROOT"/*/; do
    patient_dir="${patient_dir%/}"

    patient_name=$(basename "$patient_dir")

    echo "========================================"
    echo "Processing patient: $patient_name"
    echo "Path: $patient_dir"
    echo "========================================"

    # 2a) Create a folder for this patient in the OUTPUT_ROOT
    patient_output="$OUTPUT_ROOT/$patient_name"
    mkdir -p "$patient_output"

    # Initialize variables
    t1_file=""
    t2_file=""
    mask_file=""

    # 3) Search subfolders for T1 and T1-FLAIR
    t1_search=$(find "$patient_dir" -type f \( -name "*DICOM_3D_T1_MS-P*.nii" -o -name "*DICOM_3D_T1_MS-P*.nii.gz" \))
    t2_search=$(find "$patient_dir" -type f \( -name "*DICOM_3D_FLAIR_MS-P.nii*" -o -name "*DICOM_3D_FLAIR_MS-P*.nii.gz" \))
    mask_zip=$(find "$patient_dir" -type f -path "*RESULTS_xnatLST*" -name "*.zip" | head -n 1)
    

    # 4) Assign variables if the file was found
    # T1
    if [ -n "$t1_search" ]; then
        t1_file=$(echo "$t1_search" | head -n 1)
        echo "Found T1 Candidate: $t1_file"
        # Copy to the new folder, name it T1.nii.gz
        #cp "$t1_file" "$patient_output/T1.nii.gz"
        #echo "Copied T1 -> $patient_output/T1.nii.gz"
    else
        echo "WARNING: No T1 for patient $patient_name"
    fi

    # T2 FLAIR
    if [ -n "$t2_search" ]; then
        t2_file=$(echo "$t2_search" | head -n 1)
        echo "Found T2 Candidate: $t2_file"
        #cp "$t2_file" "$patient_output/T2_FLAIR.nii.gz"
        #echo "Copied T2-FLAIR -> $patient_output/T2_FLAIR.nii.gz"
    else
        echo "WARNING: No T2 for patient $patient_name"
    fi
    
    # Find and extract mask
    if [ -n "$mask_zip" ]; then
        echo "  Found Zip with mask: $mask_zip"

        # Create a temporary directory for unzipping
        tmp_dir=$(mktemp -d)

        # Unzip only files matching "*ples_lga_*.nii*" from the zip
        # -j discards internal paths, -d sets destination
        unzip -j "$mask_zip" "*ples_lga_*.nii*" -d "$tmp_dir" || {
          echo "  No 'ples_lga_' file found inside the zip for $patient_name"
          rm -rf "$tmp_dir"
          continue
        }

        # Identify the extracted mask file (pick first if multiple)
        extracted_mask=$(find "$tmp_dir" -type f -name "*ples_lga_*.nii*" | head -n 1)

        if [ -n "$extracted_mask" ]; then
            echo "  Found mask: $extracted_mask"
            # Keep extension from the original file
            
            extension="${extracted_mask##*.}"  # e.g. "nii.gz" or "nii"
            output_mask="$patient_output/lesion_mask.$extension"
            cp "$extracted_mask" "$output_mask"
            #echo "  Copied mask -> $output_mask"
        else
            echo "  WARNING: Could not find any 'ples_lga_' after unzipping."
        fi

        # Clean up
        rm -rf "$tmp_dir"

    else
        echo "WARNING: No .zip with mask for $patient_name in RESULTS_xnatLST"
    fi


    ######################################## Find the magnitude ########################################
    found_mag_qsm=0
    for year_dir in "$patient_dir"/20*/; do

        #Check dir
        [ -d "$year_dir" ] || continue

        # If we already found first dates, break
        if [ "$found_mag_qsm" -eq 1 ]; then
            break
        fi

        year_folder_name=$(basename "$year_dir")

        echo "Found subfolder: $year_folder_name"

        # Get inside Magnitude folder
        magnitude_dir="$year_dir/Magnitude"
        qsm_dir="$year_dir/QSM"

        mag_path=""
        qsm_path=""

        #Check MAgnitude dir is present
        if [ -d "$magnitude_dir" ]; then
            echo "Found Magnitude folder: $magnitude_dir"

            mag_path="$magnitude_dir/mag0000.nii.gz"

            if [ -f "$mag_path" ]; then
                echo " Found $mag_path"

            else
                echo "WARNING: No Magnitude folder for $patient_name in $year_folder_name"
            fi
        fi

        #Check QSM dir is present
        if [ -d "$qsm_dir" ]; then
            echo "Found QSM folder: $qsm_dir"

            qsm_path="$qsm_dir/QSM_VSHARP_ppm.nii.gz"

            if [ -f "$qsm_path" ]; then
                echo "Found QSM $qsm_path"

            else
                echo "WARNING: No QSM folder for $patient_name in $year_folder_name"
                qsm_path=""
            fi

        else
            echo "WARNING: No QSM folder for $patient_name in $year_folder_name"
            qsm_path=""
        fi

        # If both exist, copy them and mark found
        if [ -n "$mag_path" ] && [ -n "$qsm_path" ]; then
            echo " Copying T1, T2, mask, Magnitude and QSM from first found year: $year_folder_name"
            
            year_output="$patient_output/$year_folder_name"

            if [ -d "$year_output" ]; then
                echo "WARNING: Removing existing folder"
                rm -rf "$year_output"
            fi


            mkdir -p "$year_output"

            if [ -n "$t1_file" ] && [ -f "$t1_file" ]; then
                cp "$t1_file" "$year_output/T1.nii.gz"
                echo "Copied T1 -> $year_output/T1.nii.gz"
            fi

            if [ -n "$t2_file" ] && [ -f "$t2_file" ]; then
                cp "$t2_file" "$year_output/T2_FLAIR.nii.gz"
                echo "Copied T2-FLAIR -> $year_output/T2_FLAIR.nii.gz"
            fi

            if [ -n "$output_mask" ] && [ -f "$output_mask" ]; then
                cp "$output_mask" "$year_output/lesion_mask.nii"
                echo "Copied mask -> $year_output/lesion_mask.nii"
            fi


            cp "$mag_path" "$year_output/mag.nii.gz"
            cp "$qsm_path" "$year_output/QSM.nii.gz"
            #found_mag_qsm=1
            break
        fi

    done # End of year_dir loop

done # End of patient_dir loop

echo "========================================"
echo "Done collecting T1, T2-FLAIR, lesion mask, and first-year Magnitude/QSM for all patients."
echo "Results are in: $OUTPUT_ROOT"
