import nibabel as nib

def load_nifti(path):
    image = nib.load(path)
    data = image.get_fdata()
    affine = image.affine
    header = image.header
    return data, affine, header