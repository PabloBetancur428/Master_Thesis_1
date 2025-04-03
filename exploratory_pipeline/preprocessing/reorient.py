"""
reorient.py

Module for reorienting NIfTI images to a canonical orientation.
This is useful when images (e.g., T1, magnitude, mask) from different patients
or modalities are acquired with different orientations. Standardizing the orientation
ensures that downstream tasks (like registration) have a consistent starting point.
"""

import os
import nibabel as nib
import sys
import argparse

def reorient_to_canonical(image_path, output_path=None):
    """
    Reorient a NIfTI image to its closest canonical orientation (typically RAS).

    Why:
      - Medical images acquired from different scanners or protocols may have 
        differing orientations (e.g., T1 may be stored as (176, 240, 256) while 
        others as (232, 256, 176)). Reorienting helps align them in a common space.
      - This function does not resample the image; it only updates the header so that
        the image is viewed in a canonical orientation.

    How:
      - Load the image with nibabel.
      - Use nibabel.as_closest_canonical() to convert the image header to a canonical form.
      - Save the resulting image.

    Parameters:
        image_path (str): File path to the input NIfTI image.
        output_path (str): File path to save the reoriented image. If None, a new filename is created.

    Returns:
        str: File path to the reoriented image.
    """
    # Load the image using nibabel.
    img = nib.load(image_path)
    
    # Reorient the image to the closest canonical orientation.
    canonical_img = nib.as_closest_canonical(img)
    
    # If no output path is provided, construct one based on the input filename.
    if output_path is None:
        base, ext = os.path.splitext(image_path)
        # Check for .nii.gz files:
        if ext == ".gz":
            # Remove the .nii.gz suffix and add _canonical before adding the extension back.
            base = image_path.replace(".nii.gz", "")
            output_path = base + "_canonical.nii.gz"
        else:
            output_path = base + "_canonical" + ext

    # Save the reoriented image.
    nib.save(canonical_img, output_path)
    print(f"Reoriented image saved at: {output_path}")
    return output_path

def batch_reorient(image_paths, output_dir):
    """
    Batch reorient multiple images and save them into a specified output directory.
    
    Parameters:
        image_paths (list of str): List of file paths to the images.
        output_dir (str): Directory to save the reoriented images.
        
    Returns:
        list of str: List of file paths to the reoriented images.
    """
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    reoriented_paths = []
    for img_path in image_paths:
        # Derive a new file name in the output directory.
        base = os.path.basename(img_path).replace(".nii.gz", "").replace(".nii", "")
        output_path = os.path.join(output_dir, f"{base}_canonical.nii.gz")
        reoriented_img_path = reorient_to_canonical(img_path, output_path)
        reoriented_paths.append(reoriented_img_path)
    return reoriented_paths

if __name__ == "__main__":
    # Example usage for a single image
    #sample_image_path = os.path.join("exploratory_pipeline/data", "QSM.nii.gz")
    #output_image_path = os.path.join("exploratory_pipeline/data", "QSM_canonical.nii.gz")
    #reorient_to_canonical(sample_image_path, output_image_path)
    
    # Example usage for batch processing:
    # Suppose you have a list of T1 images for multiple patients.
    #image_list = [
    #    os.path.join("exploratory_pipeline/data", "T1.nii.gz"),
    #    os.path.join("exploratory_pipeline/data", "QSM.nii.gz"),
    #    os.path.join("exploratory_pipeline/data", "mag0000.nii.gz"),
    #    os.path.join("exploratory_pipeline/data", "lesion_mask.nii"),
    #    os.path.join("exploratory_pipeline/data", "FLAIR.nii.gz")
    #    # Add more patient images as needed.
    #]

    #base_path_mods = "/home/jbetancur/Desktop/codes/python_qsm/Masking_images/images"
    #image_list = [
    #    os.path.join(base_path_mods, "corrected_DICOM_3D_T1_MS-P_20230416120628_23.nii.gz"),
    #    os.path.join(base_path_mods, "corrected_DICOM_3D_FLAIR_MS-P_20230416120628_25.nii.gz"),
    #    os.path.join(base_path_mods, "mask.nii")
    #]
    #batch_output_dir = os.path.join(base_path_mods, "reoriented")
    #batch_reorient(image_list, batch_output_dir)


    parser = argparse.ArgumentParser(description="Reorient NIfTI images to canonical orientation.")
    parser.add_argument("--input", nargs="+", required=True, help="One or more paths to NIfTI images. For multiple images, separate with space.")
    parser.add_argument("--output_dir", default=None, help="Directory to save reoriented images if multiple inputs. If not provided, a canonical file is created in place.")
    args = parser.parse_args()


    output_dir = args.output_dir

    batch_reorient(args.input, output_dir)
    
    
