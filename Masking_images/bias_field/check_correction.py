"""
Code to check the affine matrices of the original image and the bias field corrected image

Input: Two nifti images, one original and one bias field corrected
Output: Prints the affine matrices of the two images and checks if they are similar


"""

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))
from exploratory_pipeline.exploratory_analysis.data_loader import load_nifti
import numpy as np
import SimpleITK as sitk



if __name__ == "__main__":
    # Load the T1 image
    t1_path = "/home/jbetancur/Desktop/codes/python_qsm/Masking_images/images/DICOM_3D_T1_MS-P_20230416120628_23.nii.gz"
    corrected_img_path = "/home/jbetancur/Desktop/codes/python_qsm/Masking_images/images/corrected_DICOM_3D_T1_MS-P_20230416120628_23.nii.gz"
    
    t1_data, t1_affine, t1_header = load_nifti(t1_path)
    t1_corrected_data, t1_corrected_affine, t1_corrected_header = load_nifti(corrected_img_path)



    # Load the corrected_i
    print("Affine similarity checks:")
    print("T1 vs Corrected T1:", np.allclose(t1_affine, t1_corrected_affine, atol=1e-3))