import numpy as np

def check_shapes(*args):
    shapes = [img.shape for img in args]
    print(f"Shapes of images: {shapes}")
    return shapes

def check_voxel_sizes(headers):
    voxel_sizes = [hdr.get_zooms() for hdr in headers]
    print(f"Voxel sizes: {voxel_sizes}")
    return voxel_sizes

def check_intensity_stats(data, image_name):
    print(f"\nIntensity statistics for {image_name}:")
    print(f" - Min: {np.min(data)}")
    print(f" - Max: {np.max(data)}")
    print(f" - Mean: {np.mean(data)}")
    print(f" - Std: {np.std(data)}")