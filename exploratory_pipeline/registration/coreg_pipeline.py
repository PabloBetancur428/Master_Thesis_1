import os
import sys
import argparse
import SimpleITK as sitk

def register_t1_to_magnitude(t1_path, magnitude_path, out_matrix=None, out_registered=None, rigid=False):
    """
    Register a T1 image (moving) to a magnitude image (fixed) using SimpleITK registration.

    Parameters
    ----------
    t1_path : str
        Path to the T1 image.
    magnitude_path : str
        Path to the magnitude image.
    out_matrix : str, optional
        Output path for saving the transform.
    out_registered : str, optional
        Output path for saving the registered T1 image.
    rigid : bool
        If True, use a rigid transform (Euler3DTransform); if False, use an affine transform.

    Returns
    -------
    tuple
        (registered_t1_path, transform_matrix_path)
    """
    # Define default output paths if not provided
    if out_registered is None:
        base = os.path.splitext(t1_path)[0]
        out_registered = base + "_toMag.nii.gz"
    if out_matrix is None:
        base = os.path.splitext(t1_path)[0]
        out_matrix = base + "_toMag_transform.tfm"

    # Read the fixed (magnitude) and moving (T1) images
    fixed_image = sitk.ReadImage(magnitude_path, sitk.sitkFloat32)
    moving_image = sitk.ReadImage(t1_path, sitk.sitkFloat32)

    # Initialize transform: rigid (Euler3DTransform) or affine (AffineTransform)
    if rigid:
        initial_transform = sitk.CenteredTransformInitializer(
            fixed_image, moving_image, 
            sitk.Euler3DTransform(), 
            sitk.CenteredTransformInitializerFilter.GEOMETRY
        )
    else:
        initial_transform = sitk.CenteredTransformInitializer(
            fixed_image, moving_image, 
            sitk.AffineTransform(3), 
            sitk.CenteredTransformInitializerFilter.GEOMETRY
        )

    # Set up the registration method
    registration_method = sitk.ImageRegistrationMethod()
    registration_method.SetMetricAsMattesMutualInformation(numberOfHistogramBins=50)
    registration_method.SetMetricSamplingStrategy(registration_method.RANDOM)
    registration_method.SetMetricSamplingPercentage(0.01)
    registration_method.SetInterpolator(sitk.sitkLinear)

    # Optimizer settings
    registration_method.SetOptimizerAsRegularStepGradientDescent(
        learningRate=2.0,
        minStep=1e-4,
        numberOfIterations=200,
        gradientMagnitudeTolerance=1e-8
    )
    registration_method.SetOptimizerScalesFromPhysicalShift()

    # Multi-resolution framework
    registration_method.SetShrinkFactorsPerLevel(shrinkFactors=[4, 2, 1])
    registration_method.SetSmoothingSigmasPerLevel(smoothingSigmas=[2, 1, 0])
    registration_method.SmoothingSigmasAreSpecifiedInPhysicalUnitsOn()

    # Set initial transform
    registration_method.SetInitialTransform(initial_transform, inPlace=False)

    # Execute the registration
    final_transform = registration_method.Execute(fixed_image, moving_image)

    # Resample the moving image using the final transform
    resampler = sitk.ResampleImageFilter()
    resampler.SetReferenceImage(fixed_image)
    resampler.SetInterpolator(sitk.sitkLinear)
    resampler.SetDefaultPixelValue(0)
    resampler.SetTransform(final_transform)
    registered_image = resampler.Execute(moving_image)

    # Save the registered image and the transform
    sitk.WriteImage(registered_image, out_registered)
    sitk.WriteTransform(final_transform, out_matrix)

    print("\n[Registration Complete]")
    print(f"  Fixed (Magnitude): {magnitude_path}")
    print(f"  Moving  (T1):      {t1_path}")
    print(f"  => Registered T1:  {out_registered}")
    print(f"  => Transform:      {out_matrix}")

    return out_registered, out_matrix

def apply_transform_to_mask(mask_path, magnitude_path, transform_matrix, out_mask=None):
    """
    Apply the T1->magnitude transformation to a mask using nearest-neighbor interpolation.

    Parameters
    ----------
    mask_path : str
        Path to the mask image.
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

    # Read the fixed image (for reference) and the mask image
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

def apply_transform_to_flair(flair_path, magnitude_path, transform_matrix, out_flair=None):
    """
    Apply the T1->magnitude transformation to a FLAIR image using linear interpolation.

    Parameters
    ----------
    flair_path : str
        Path to the FLAIR image.
    magnitude_path : str
        Path to the magnitude image (fixed/reference space).
    transform_matrix : str
        Path to the transformation matrix from the T1->magnitude registration.
    out_flair : str, optional
        Output path for the resampled FLAIR image.

    Returns
    -------
    str
        Path to the resampled FLAIR image in the magnitude space.
    """
    if out_flair is None:
        base = os.path.splitext(flair_path)[0]
        out_flair = base + "_toMag.nii.gz"

    # Read the fixed image and the FLAIR image
    fixed_image = sitk.ReadImage(magnitude_path, sitk.sitkFloat32)
    flair_image = sitk.ReadImage(flair_path, sitk.sitkFloat32)

    # Read the transformation computed from T1 registration
    transform = sitk.ReadTransform(transform_matrix)

    # Resample the FLAIR image using linear interpolation
    resampler = sitk.ResampleImageFilter()
    resampler.SetReferenceImage(fixed_image)
    resampler.SetInterpolator(sitk.sitkLinear)
    resampler.SetDefaultPixelValue(0)
    resampler.SetTransform(transform)
    resampled_flair = resampler.Execute(flair_image)

    # Save the resampled FLAIR image
    sitk.WriteImage(resampled_flair, out_flair)

    print("\n[FLAIR Resampling Complete]")
    print(f"  Fixed (Magnitude): {magnitude_path}")
    print(f"  FLAIR:             {flair_path}")
    print(f"  => Resampled FLAIR:{out_flair}")

    return out_flair

def main_registration_pipeline(t1_path, flair, magnitude_path, mask_path):
    """
    Pipeline:
    1) Register T1 image to magnitude image.
    2) Apply the computed transform to the mask.
    """
    registered_t1, transform_matrix = register_t1_to_magnitude(t1_path, magnitude_path, rigid=False)
    transformed_mask = apply_transform_to_mask(mask_path, magnitude_path, transform_matrix)
    registered_flair = apply_transform_to_flair(flair, magnitude_path, transform_matrix)
    return registered_t1, transformed_mask, registered_flair

if __name__ == "__main__":
    # Example usage:
    #base_folder = "exploratory_pipeline/data/preprocessed"
    #t1_img = os.path.join(base_folder, "T1_N4_canonical.nii.gz")
    #flair_img = os.path.join(base_folder, "FLAIR_N4_canonical.nii.gz")
    #magnitude_img = os.path.join(base_folder, "mag0000_canonical.nii.gz")
    #mask_img = os.path.join(base_folder, "N4_mask_canonical.nii.gz")

    #main_registration_pipeline(t1_img, flair_img, magnitude_img, mask_img)
    parser = argparse.ArgumentParser(description="Register T1 to magnitude and apply transform to mask and FLAIR")
    parser.add_argument("--t1", required=True, help="Path to T1 image.")
    parser.add_argument("--flair", required=True, help="Path to FLAIR image.")
    parser.add_argument("--magnitude", required=True, help="Path to magnitude image.")
    parser.add_argument("--mask", required=True, help="Path to mask image.")
    args = parser.parse_args()

    # Call main pipeline
    main_registration_pipeline(
        t1_path=args.t1,
        flair=args.flair,
        magnitude_path=args.magnitude,
        mask_path=args.mask
    )




