import SimpleITK as sitk
import numpy as np
import matplotlib.pyplot as plt
import sys
import os
import argparse

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))
from exploratory_pipeline.exploratory_analysis.data_loader import load_nifti

def n4_bias_field_correction(input_image, mask_image=None, shrink_factor=4, 
                             convergence_threshold=1e-7, maximum_iterations=[50,50,50,50]):
    """
    Apply N4 bias field correction to an input image using SimpleITK.
    
    Parameters:
      input_image (sitk.Image): The input image to correct.
      mask_image (sitk.Image, optional): A binary mask image of the brain region. 
                                         If None, an Otsu mask will be generated.
      shrink_factor (int, optional): Factor to shrink image for faster correction.
      convergence_threshold (float, optional): Convergence threshold for the algorithm.
      maximum_iterations (list, optional): Maximum iterations at each resolution level.
    
    Returns:
      sitk.Image: The bias-field corrected image at original resolution.
    """


    # 1. Generate a mask if not provided (using Otsu thresholding)
    if mask_image is None:
        mask_image = sitk.OtsuThreshold(input_image, 0, 1, 200)
    
    # 2. Optionally shrink the images to speed up processing.
    if shrink_factor > 1:
        input_image_shrunk = sitk.Shrink(input_image, [shrink_factor]*input_image.GetDimension())
        mask_image_shrunk = sitk.Shrink(mask_image, [shrink_factor]*mask_image.GetDimension())
    else:
        input_image_shrunk = input_image
        mask_image_shrunk = mask_image

    # 3. Set up and run the N4 bias field correction filter.
    corrector = sitk.N4BiasFieldCorrectionImageFilter()
    corrector.SetMaximumNumberOfIterations(maximum_iterations)
    corrector.SetConvergenceThreshold(convergence_threshold)
    
    corrected_shrunk = corrector.Execute(input_image_shrunk, mask_image_shrunk)
    
    # 4. If we shrunk the image, we need to upsample the estimated bias field
    #    and correct the original image.
    if shrink_factor > 1:
        # The log bias field is stored in the filter.
        log_bias_field_shrunk = corrector.GetLogBiasFieldAsImage(input_image_shrunk)
        # Resample the log bias field to the original image resolution using a BSpline interpolator.
        log_bias_field = sitk.Resample(log_bias_field_shrunk, input_image, 
                                       sitk.Transform(), sitk.sitkBSpline)
        # Compute the corrected image at full resolution.
        corrected_image = input_image / sitk.Exp(log_bias_field)
    else:
        corrected_image = corrected_shrunk

    return corrected_image

def display_bias_correction(original, corrected, slice_index=None):
    """
    Display the original and bias-corrected images side by side for visual verification.
    
    Parameters:
      original (sitk.Image): Original image.
      corrected (sitk.Image): Bias-corrected image.
      slice_index (int, optional): Index of the slice to display (if image is 3D).
                                   If None, the middle slice is used.
    """
    # Convert images to numpy arrays
    original_np = sitk.GetArrayFromImage(original)
    corrected_np = sitk.GetArrayFromImage(corrected)
    
    # Determine the slice to show (assuming 3D image, slice dimension first)
    if slice_index is None:
        slice_index = original_np.shape[0] // 2

    # Plot the selected slice from the original and corrected images.
    plt.figure(figsize=(12, 6))
    
    plt.subplot(1,2,1)
    plt.imshow(original_np[slice_index,:,:], cmap='gray')
    plt.title('Original Image (Slice {})'.format(slice_index))
    plt.axis('off')
    
    plt.subplot(1,2,2)
    plt.imshow(corrected_np[slice_index,:,:], cmap='gray')
    plt.title('Bias Corrected Image (Slice {})'.format(slice_index))
    plt.axis('off')
    
    plt.show()


if __name__ == "__main__":


    parser = argparse.ArgumentParser(description='N4 Bias Field Correction')
    parser.add_argument("--input_image", required=True, help="Path to the input image.")
    parser.add_argument("--mask_image", required=True, help="Path to the mask image.")
    parser.add_argument("--output_image", required=True, help="Path to save the corrected image.")
    parser.add_argument("--shrink_factor", type=int, default=4, help="Shrink factor for faster correction. Default 4")
    parser.add_argument("--conv_thresh", type=float, default=1e-7, help="Convergence threshold. Default 1e-7")
    parser.add_argument("--max_iter", nargs='+', type=int, default=[50,50,50,50], help="Max iterations per resolution level. Default 50 50 50 50")

    args = parser.parse_args()

    # 2. Load the input and mask images
    input_image = sitk.ReadImage(args.input_image, sitk.sitkFloat32)
    mask_sitk = sitk.ReadImage(args.mask_image, sitk.sitkUInt8)

    # 4. Run N4

    corrected_sitk = n4_bias_field_correction(
        input_image, 
        mask_sitk, 
        args.shrink_factor, 
        args.conv_thresh, 
        args.max_iter
    )

    sitk.WriteImage(corrected_sitk, args.output_image)
    print(f"[INFO] Bias-corrected image saved at: {args.output_image}")
