#!/usr/bin/env bash
#
# Purpose:
#   1) In DONE_QSM_ROOT: For each patient, identify the second year folder (alphabetically).
#      From that folder, copy:
#         - Magnitude/mag0000.nii.gz (if present)
#         - QSM/QSM_VSHARP_ppm.nii.gz (if present)
#   2) In FOLLOW_UP_ROOT: For the same patient, find the subfolder that has exactly 2 sub-subfolders.
#      From there, we find:
#         - T1 file(s) matching "*T1*.nii*"
#         - T2 file(s) matching "*FLAIR*.nii*"
#         - Mask from a .zip inside "*RESULTS_xnatLST*" containing "*ples_lga_*.nii*"
#        We copy them into the final output as well.
#   3) Combine them all in OUTPUT_ROOT/patientName/secondYearFolderName/
#
# Usage:
#   ./gather_second_year_and_followup_mask.sh /path/to/done_qsm /path/to/follow_up /path/to/output

###############################################


#Done QSM: /home/jbetancur/Desktop/Scripts_QSM/test/done_qsm
#FOLLOW_UP_ROOT: /home/jbetancur/Desktop/Quspid_data/Original_data/follow_up_w_mask/jpablo-20250313_133606
#OUTPUT_ROOT: /home/jbetancur/Desktop/codes/python_qsm/exploratory_pipeline/data_automatization/pruebas_follow_up

set -euo pipefail


if [ "$#" -ne 3 ]; then
  echo "Usage: $0 DONE_QSM_ROOT FOLLOW_UP_ROOT OUTPUT_ROOT"
  exit 1
fi

DONE_QSM_ROOT="$1"
FOLLOW_UP_ROOT="$2"
OUTPUT_ROOT="$3"

# Create output dir if it doesn't exist
mkdir -p "$OUTPUT_ROOT"

for patient_dir in "$DONE_QSM_ROOT"/*/; do
    patient_dir="${patient_dir%/}"

    patient_name=$(basename "$patient_dir")

    echo "========================================"
    echo "Processing patient: $patient_name"
    echo "Done QSM path: $patient_dir"
    echo "========================================"


    # (1) Identify the second year folder by picking all of the 20 folders, arrange them by name, and pick the second one
    mapfile -t year_folders < <(find "$patient_dir" -maxdepth 1 -mindepth 1 -type d -name "20*" | sort)
    
    if [ "${#year_folders[@]}" -lt 2 ]; then
        echo "  WARNING: Patient $patient_name does not have at least two year folders. Skipping."
        continue
    fi

    #pick second item in the sorted array
    second_year_folder="${year_folders[1]}"
    second_year_name=$(basename "$second_year_folder")
    echo "========================================"
    echo "  Found second year folder: $second_year_name"
    echo "========================================"

    # Look for the QSM and Magnitude in the second year folder

    mag_path="$second_year_folder/Magnitude/mag0000.nii.gz"
    qsm_path="$second_year_folder/QSM/QSM_VSHARP_ppm.nii.gz"

    if [ ! -f "$mag_path" ]; then
        echo "  WARNING: No Magnitude found in $second_year_name"
        continue
    fi

    if [ ! -f "$qsm_path" ]; then
        echo "  WARNING: No QSM found in $second_year_name"
        continue
    fi

    # 3) Search for T1, T2-FLAIR, and mask in the follow-up folder
    followup_patient_dir="$FOLLOW_UP_ROOT/$patient_name"

    if [ ! -d "$followup_patient_dir" ]; then
        echo "  WARNING: No follow-up folder found for $patient_name in $FOLLOW_UP_ROOT"
        continue
    fi

    #Find the subfolder that has exactly two subfolders (SInce there are patients that contain 3 different acquisiton dates)

    mapfile -t candidate_folders < <(find "$followup_patient_dir" -mindepth 1 -maxdepth 1 -type d | sort)
    chosen_followup_folder=""  # We'll store the folder that has exactly 2 sub-subfolders
    
    for fdir in "${candidate_folders[@]}"; do
        # Count how many subfolders exist inside fdir
        subfolder_count=$(find "$fdir" -mindepth 1 -maxdepth 1 -type d | wc -l)
        if [ "$subfolder_count" -eq 2 ]; then
            chosen_followup_folder="$fdir"
            break
        fi
    done

    if [ -z "$chosen_followup_folder" ]; then
        echo "  WARNING: Could not find any subfolder with exactly 2 sub-subfolders in $followup_patient_dir"
        continue
    else
        echo "  Found follow-up folder with 2 subfolders: $chosen_followup_folder"
    fi

    #Now that we chose a folder, we will search for T1, T2 and mask in the chosen follow-up folder
    t1_file=$(find "$chosen_followup_folder" -type f -name "*DICOM_3D_T1_MPRAGE*.nii*" | head -n 1 || true)
    t2_file=$(find "$chosen_followup_folder" -type f -name "*DICOM_3D_FLAIR_SI_NO_SE_ADMINISTRA_GD*.nii*" | head -n 1 || true)

    echo "    T1 candidate:   $t1_file"
    echo "    T2 candidate:   $t2_file"

    # Look for the mask which is inside a .zip file inside "*RESULTS_xnatLST*"
    mask_zip=$(find "$chosen_followup_folder" -type f -path "*RESULTS_xnatLST*" -name "*.zip" | head -n 1 || true)
    output_mask=""  

    if [ -n "$mask_zip" ]; then
        echo "  Found Zip with mask: $mask_zip"

        # Create a temp dir for unzipping
        tmp_dir=$(mktemp -d)

        # Unzip only files matching "*ples_lga_*.nii*"
        unzip -j "$mask_zip" "*ples_lga_*.nii*" -d "$tmp_dir" || {
        echo "    No 'ples_lga_' file found inside the zip for $patient_name"
        rm -rf "$tmp_dir"
        continue
        }

        # Identify the extracted mask file (pick first if multiple)
        extracted_mask=$(find "$tmp_dir" -type f -name "*ples_lga_*.nii*" | head -n 1)
        if [ -n "$extracted_mask" ]; then
        echo "    Found extracted mask: $extracted_mask"
        # Keep the original extension
        extension="${extracted_mask##*.}"  # e.g. "nii" or "nii.gz"
        output_mask="$chosen_followup_folder/lesion_mask.$extension"

        # Copy from tmp_dir to follow-up folder (or wherever you want to keep it)
        cp "$extracted_mask" "$output_mask"
        echo "    Copied mask -> $output_mask"
        else
        echo "    WARNING: Could not find any 'ples_lga_' after unzipping."
        fi

        # Clean up
        rm -rf "$tmp_dir"
    else
        echo "  WARNING: No mask zip found for $patient_name in $chosen_followup_folder"
    fi


    #Prepare the output dir
    patient_output="$OUTPUT_ROOT/$patient_name/$second_year_name"
    mkdir -p "$patient_output"


    # Copy QSM & Magnitude
    if [ -f "$mag_path" ]; then
        cp "$mag_path" "$patient_output/mag.nii.gz"
        echo "  Copied Magnitude -> $patient_output/mag.nii.gz"
    fi
    
    if [ -f "$qsm_path" ]; then
        cp "$qsm_path" "$patient_output/QSM.nii.gz"
        echo "  Copied QSM -> $patient_output/QSM.nii.gz"
    fi

    # (H) Copy T1
    if [ -n "$t1_file" ] && [ -f "$t1_file" ]; then
        cp "$t1_file" "$patient_output/T1.nii.gz"
        echo "  Copied T1 -> $patient_output/T1.nii.gz"
    else
        echo "  WARNING: T1 not found for $patient_name"
    fi

    # (I) Copy T2
    if [ -n "$t2_file" ] && [ -f "$t2_file" ]; then
        cp "$t2_file" "$patient_output/T2_FLAIR.nii.gz"
        echo "  Copied T2 -> $patient_output/T2_FLAIR.nii.gz"
    else
        echo "  WARNING: T2 not found for $patient_name"
    fi

    # Copy Mask (rename to lesion_mask.nii or .nii.gz as you prefer)
    if [ -n "$output_mask" ] && [ -f "$output_mask" ]; then
        # If you want to unify to .nii, ignoring .nii.gz, do:
        # cp "$output_mask" "$patient_output/lesion_mask.nii"
        #
        # Or if you prefer to keep the extension:
        extension="${output_mask##*.}"  # e.g. "nii" or "gz"
        cp "$output_mask" "$patient_output/lesion_mask.$extension"
        echo "  Copied mask -> $patient_output/lesion_mask.$extension"
    else
        echo "  WARNING: Mask not found or extraction failed for $patient_name"
    fi

done # End of patient_dir loop

echo "========================================"
echo "Done collecting Follow up of T1, T2-FLAIR, lesion mask, and Magnitude/QSM for all patients."
echo "Results are in: $OUTPUT_ROOT"
