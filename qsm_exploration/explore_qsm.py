import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt


def main():

    #1 load QSM
    qsm_path = "/home/jbetancur/Desktop/Scripts_QSM/test/scan_2024/QSM/QSM_VSHARP_ppm.nii.gz"
    qsm_img = nib.load(qsm_path)

    #2 Extract data array and the header
    qsm_data = qsm_img.get_fdata()
    qsm_header = qsm_img.header

    #3. Print basic info
    print("Data shape:", qsm_data.shape)
    print("Voxel dimensions (pixdim): ", qsm_header["pixdim"][1:4])
    print("Data type: ", qsm_data.dtype)
    #4 Basic stats
    print("Min value ppm: ", np.min(qsm_data))
    print("Max value ppm: ", np.max(qsm_data))
    print("Mean ppm: ", np.mean(qsm_data))

    #Show middle slice
    slice_index = qsm_data.shape[2] // 2
    plt.imshow( qsm_data[:,:,slice_index], cmap="gray")
    plt.colorbar(label="Susceptibility (ppm)")
    plt.title(f"QSM Slice {slice_index}")
    plt.savefig("qsm_slice.png")

if __name__ == '__main__':
    main()