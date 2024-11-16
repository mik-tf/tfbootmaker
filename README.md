<h1> ThreeFold ZOS Boot Image Maker for USB</h1>

<h2> Table of Contents </h2>

- [Introduction](#introduction)
- [Usage](#usage)
- [Options](#options)
- [Steps](#steps)
- [Prerequisites](#prerequisites)
- [Error Handling](#error-handling)
- [Important Notes](#important-notes)
- [License](#license)
- [Contributing](#contributing)

---

## Introduction

This Bash CLI script formats a USB drive with FAT32 and installs an iPXE bootloader to boot a ThreeFold Grid V3 node.

> Note: This script will format your USB disk. Use carefully and at your own risk.

## Usage

You can simply clone the directory and run the script.

```bash
git clone https://github.com/Mik-TF/tfbootmaker
cd tfbootmaker
bash tfboot.sh
```

## Options

* `bash tfboot.sh help`: Display the help message.

## Steps

1. **Unmount (Optional):** Prompts for a path to unmount an existing mount point.
2. **Disk Selection:** Prompts for the disk to format (e.g., `/dev/sdb`). **Must be a valid device.**  Be extremely careful here as selecting the wrong disk can lead to data loss.
3. **Network Selection:** Prompts for the ThreeFold Grid network (mainnet, devnet, testnet, qanet).
4. **Farm ID:** Prompts for the farm ID.
5. **Disk Layout (Before):** Displays the current disk layout using `lsblk`.
6. **Confirmation:** Confirms the formatting operation before proceeding.
7. **Formatting:** Formats the disk with FAT32 using `mkfs.vfat -I`.
8. **Mounting:** Creates a temporary mount point and mounts the formatted disk.
9. **iPXE Download:** Downloads the iPXE bootloader from the appropriate ThreeFold Grid bootstrap server based on the selected network and farm ID.
10. **iPXE Installation:** Copies the downloaded iPXE bootloader to the correct location on the USB drive (`EFI/BOOT/BOOTX64.EFI`).
11. **Unmounting:** Unmounts the temporary mount point.
12. **Disk Layout (After):** Displays the final disk layout using `lsblk`.
13. **Eject (Optional):** Optionally ejects the USB drive.

## Prerequisites

* `bash`: This script requires Bash to run.
* `sudo`:  Administrative privileges are required for formatting and mounting the disk.
* `lsblk`:  Used to display disk information.
* `mkfs.vfat`:  Used to format the disk with FAT32.
* `curl`: Used to download the iPXE bootloader.
* `eject` (Optional): Used to eject the drive.


## Error Handling

The script includes error handling for various scenarios, such as:

* Invalid disk selection.
* Invalid network selection.
* Invalid Farm ID.
* Errors during formatting, mounting, downloading, or ejecting.

The script will exit with an error message if any of these issues occur.

## Important Notes

* **Data Loss:** This script formats the specified disk, which will erase all data on the disk. **Double-check the disk selection to avoid accidental data loss.**
* **Device Permissions:** Ensure you have the necessary permissions to access and modify the specified disk.  This generally requires `sudo`.

## License

The script is under [Apache 2.0 license](./LICENSE).

## Contributing

Contributions are welcome! Please feel free to submit pull requests with improvements or bug fixes.