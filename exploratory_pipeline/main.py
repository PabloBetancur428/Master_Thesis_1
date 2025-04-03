from exploratory_analysis.data_loader import load_nifti
from exploratory_analysis.check import check_shapes, check_voxel_sizes, check_intensity_stats
from exploratory_analysis.visualization import plot_slices, plot_histograms
import numpy as np
import os

def main():

    # Load images

    base_path_mods = "/home/jbetancur/Desktop/codes/python_qsm/Masking_images/images/reoriented"
    image_list = [
        os.path.join(base_path_mods, "T1_canonical.nii_toMag.nii.gz"),
        os.path.join(base_path_mods, "FLAIR_canonical.nii_toMag.nii.gz"),
        os.path.join(base_path_mods, "lesion_mask_canonical.nii_toMag.nii.gz")
    ]
    #base_folder = "exploratory_pipeline/data/preprocessed"
    T1_data, T1_affine, T1_header = load_nifti(image_list[0])
    T2_data, T2_affine, T2_header = load_nifti(image_list[1])
    mask_data, affine_mask, header_mask = load_nifti(image_list[2])
    #T1_data, T1_affine, T1_header = load_nifti(base_folder + "/T1_canonical.nii_toMag.nii.gz")
    #GRE_data, GRE_affine, GRE_header = load_nifti(base_folder + "/mag0000_canonical.nii.gz")
    #QSM_data, QSM_affine, QSM_header = load_nifti(base_folder + "/QSM_canonical.nii.gz")
    #mask_data, mask_affine, mask_header = load_nifti(base_folder + "/lesion_mask_canonical.nii_toMag.nii.gz")
    #T1_data_converted, T1_affine_converted, T1_header_converted = load_nifti("exploratory_pipeline/data/t1_canonical.nii.gz")
    #QSM_canonical, QSM_affine_canonical, QSM_header_canonical = load_nifti("exploratory_pipeline/data/QSM_canonical.nii.gz")


    # Check shapes and voxel sizes
    check_shapes(T1_data, T2_data, mask_data)
    check_voxel_sizes([T1_header, T2_header, header_mask])

    print("Affine similarity checks:")
    print("T1 vs T2:", np.allclose(T1_affine, T2_affine, atol=1e-5))
    print("T1 vs Mask:", np.allclose(T1_affine, affine_mask, atol=1e-5))
    print("T2 vs Mask:", np.allclose(T2_affine, affine_mask, atol=1e-5))

    print("Affine T1")
    print(T1_affine)
    print("\n")
    print("Affine T2")
    print(T2_affine)
    print("\n")
    print("Affine Mask")
    print(affine_mask)
    print("\n")



    # Check intensity stats
    check_intensity_stats(T1_data, "T1")
    check_intensity_stats(T2_data, "GRE")
    

    # Visualize slices for quick anatomical check

    plot_slices(
        images=[T1_data, T2_data, mask_data],
        titles=["T1", "T2", "Mask"]
    )

    # Plot intensity histograms
    plot_histograms(T1_data, "T1 Image")
    plot_histograms(T2_data, "T2_data")
    plot_histograms(mask_data, "Mask")



if __name__ == "__main__":
    main()


