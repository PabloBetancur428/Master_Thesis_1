"""
transform_lesion_labels.py

Purpose:
  1) Iterate over two directories: baseline/ and follow_up/, each containing patient subfolders.
  2) For each patient, find year subfolders starting with "20", locate the transformation matrix
     in "registered/T1_corrected_canonical.nii_toMag_transform.tfm".
  3) Locate the "RESULTS_xnatSpaceMS" folder in the same patient directory, and find the file
     containing "lesion_labels.nii.gz".
  4) Apply the transform to that lesion label file using nearest neighbor interpolation, referencing
     the magnitude image (e.g., "registered/mag.nii.gz").
  5) Save the output in "registered/lesions_MSpace_Mask.nii.gz".

How:
  - We define a helper function "apply_transform_to_mask" that uses SimpleITK.
  - We then walk through each patient and year folder to perform the transformation.

Assumptions:
  - Each patient folder has subfolders named "20*" for the years, plus "RESULTS_xnatSpaceMS".
  - There's exactly one file in RESULTS_xnatSpaceMS containing "lesion_labels.nii.gz".
  - The transform matrix is named "T1_corrected_canonical.nii_toMag_transform.tfm".
  - The reference magnitude image is "mag.nii.gz" (or adapt if you have a different naming).
  - Python environment has SimpleITK installed.
"""

import os
import SimpleITK as sitk

def apply_transform_to_mask(mask_path, magnitude_path, transform_matrix, out_mask=None):
    """
    Apply the T1->magnitude transformation to a mask using nearest-neighbor interpolation.

    Parameters
    ----------
    mask_path : str
        Path to the mask image (e.g., the lesion labels).
    magnitude_path : str
        Path to the magnitude image (fixed/reference space).
    transform_matrix : str
        Path to the transformation matrix from the T1->magnitude registration.
    out_mask : str, optional
        Output path for the resampled mask.

    Returns
    -------
    str
        Path to the resampled mask in the magnitude space.
    """
    if out_mask is None:
        base = os.path.splitext(mask_path)[0]
        out_mask = base + "_toMag.nii.gz"

    # Read the fixed image (reference) and the mask image
    fixed_image = sitk.ReadImage(magnitude_path, sitk.sitkFloat32)
    mask_image = sitk.ReadImage(mask_path, sitk.sitkUInt8)

    # Read the transformation
    transform = sitk.ReadTransform(transform_matrix)

    # Resample the mask using nearest neighbor interpolation
    resampler = sitk.ResampleImageFilter()
    resampler.SetReferenceImage(fixed_image)
    resampler.SetInterpolator(sitk.sitkNearestNeighbor)
    resampler.SetDefaultPixelValue(0)
    resampler.SetTransform(transform)
    resampled_mask = resampler.Execute(mask_image)

    # Save the resampled mask
    sitk.WriteImage(resampled_mask, out_mask)

    print("\n[Mask Resampling Complete]")
    print(f"  Fixed (Magnitude): {magnitude_path}")
    print(f"  Mask:              {mask_path}")
    print(f"  => Resampled Mask: {out_mask}")

    return out_mask

def transform_lesion_labels_in_directory(root_dir):
    """
    Iterate over each patient in 'root_dir', find year folders starting with '20', locate the transform
    file, and apply it to the lesion label file in 'RESULTS_xnatSpaceMS'.

    Parameters
    ----------
    root_dir : str
        Path to either the baseline or follow_up directory.
    """
    # 1) Loop over patient folders
    for patient_id in os.listdir(root_dir):
        patient_path = os.path.join(root_dir, patient_id)
        if not os.path.isdir(patient_path):
            continue

        print(f"\n=== Processing patient: {patient_id} in {root_dir} ===")

        # 2) Locate the RESULTS_xnatSpaceMS folder and find the lesion label file
        results_folder = os.path.join(patient_path, "RESULTS_xnatSpaceMS")
        if not os.path.isdir(results_folder):
            print(f"  No RESULTS_xnatSpaceMS folder found for {patient_id}, skipping.")
            continue

        # Attempt to find the lesion label file
        lesion_label_file = None
        for f in os.listdir(results_folder):
            if "lesion_labels.nii.gz" in f:
                lesion_label_file = os.path.join(results_folder, f)
                break

        if lesion_label_file is None:
            print(f"  No lesion_labels.nii.gz found in {results_folder}, skipping.")
            continue

        # 3) Loop over year folders that start with '20'
        for folder_name in os.listdir(patient_path):
            year_path = os.path.join(patient_path, folder_name)
            if not os.path.isdir(year_path):
                continue
            if not folder_name.startswith("20"):
                # Not a year folder
                continue

            # 4) Look for 'registered' folder
            registered_folder = os.path.join(year_path, "registered")
            if not os.path.isdir(registered_folder):
                print(f"  No 'registered' folder in {year_path}, skipping.")
                continue

            # 5) Identify the transform matrix and magnitude image
            transform_matrix = os.path.join(registered_folder, "T1_corrected_canonical.nii_toMag_transform.tfm")
            if not os.path.isfile(transform_matrix):
                print(f"  Transform matrix not found in {registered_folder}, skipping.")
                continue

            # We assume the magnitude image is "mag.nii.gz" in the same 'registered' folder
            magnitude_path = os.path.join(registered_folder, "mag_canonical.nii.gz")
            if not os.path.isfile(magnitude_path):
                print(f"  Magnitude image not found in {registered_folder}, skipping.")
                continue

            # 6) Apply transform to the lesion label file
            out_mask_path = os.path.join(registered_folder, "lesions_MSpace_Mask.nii.gz")
            print(f"  Applying transform for year folder: {folder_name}")
            apply_transform_to_mask(
                mask_path=lesion_label_file,
                magnitude_path=magnitude_path,
                transform_matrix=transform_matrix,
                out_mask=out_mask_path
            )

def main():
    """
    Main function to process both baseline and follow_up directories.
    Adjust baseline_dir and followup_dir to your actual paths.
    """
    # Adjust to your actual paths
    base_dir = "/home/jbetancur/Desktop/codes/python_qsm/exploratory_pipeline/data_automatization/"
    
    baseline_dir = os.path.join(base_dir, "clean_baseline")
    followup_dir = os.path.join(base_dir, "follow_up_both")

    #Finish follow up weird cases with 3 dates, manually ordered
    #followup_dir_3dates_fixed = os.path.join(base_dir, "follow_up_3_folders_last_registration")
    

    print(f"\n=== Processing baseline directory: {baseline_dir} ===")
    transform_lesion_labels_in_directory(baseline_dir)

    print(f"\n=== Processing follow_up directory: {followup_dir} ===")
    transform_lesion_labels_in_directory(followup_dir)

    #print(f"\n=== Processing follow_up directory: {followup_dir_3dates_fixed} ===")
    #transform_lesion_labels_in_directory(followup_dir_3dates_fixed)

    print("\nAll done.")

if __name__ == "__main__":
    main()

