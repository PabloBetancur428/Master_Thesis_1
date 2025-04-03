import matplotlib.pyplot as plt

def plot_slices(images, titles, slice_idx=None):
    if slice_idx is None:
        slice_idx = [ img.shape[2]//2 for img in images]
    
    fig, axes = plt.subplots(1, len(images), figsize=(5 * len(images), 5))

    for ax, img, idx, title in zip(axes, images, slice_idx, titles):
        ax.imshow(img[:, :, idx].T, cmap='gray', origin='lower')
        ax.set_title(title)
        ax.axis('off')

    plt.show()

def plot_histograms(data, image_name, bins = 100):
    plt.figure(figsize=(10, 5))
    plt.hist(data.ravel(), bins=bins)
    plt.title(f"Histogram of {image_name}")
    plt.xlabel("Intensity")
    plt.ylabel("Frequency")
    plt.show()