#!/bin/bash

# Script to format a USB drive and make it bootable with iPXE for ThreeFold Grid

# Function to handle exit consistently
handle_exit() {
    echo "Exiting..."
    exit 0
}

# Function to display help information
show_help() {
    cat << EOF
    
==========================
THREEFOLD V3 ZOS BOOTMAKER
==========================

This Bash CLI script can format a USB drive with FAT32 and installs an iPXE bootloader to boot a ThreeFold Grid V3 node.

The ZOS bootstrap image format is EFI FILE for UEFI.

Options:
  help        Display this help message.

Steps:
1. Prompts for a path to unmount (optional).
2. Prompts for the disk to format (e.g., /dev/sdb).  Must be a valid device.
3. Prompts for the network (mainnet, devnet, testnet, qanet).
4. Prompts for the farm ID.
5. Displays the current disk layout.
6. Confirms the formatting operation.
7. Formats the disk with FAT32.
8. Creates a temporary mount point.
9. Mounts the formatted disk.
10. Downloads the iPXE bootloader from the ThreeFold Grid bootstrap server.
11. Copies the iPXE bootloader to the correct location on the USB drive.
12. Unmounts the temporary mount point.
13. Displays the final disk layout.
14. Optionally ejects the USB drive.

Example:
  $0
  $0 help
EOF
}

# Function to display lsblk and allow exit
show_lsblk() {
    echo
    echo "Current disk layout:"
    echo
    lsblk
    echo
    echo "This is your current disk layout. Consider this before proceeding."
    echo

    while true; do
        read -p "Press Enter to continue, or type 'exit' to quit: " response
        case "${response,,}" in  # Convert to lowercase
            exit ) handle_exit;;
            "" ) break;;  # Empty input (Enter key) continues
            * ) echo "Invalid input. Please press Enter or type 'exit'.";;
        esac
    done
}

# Function to display mounted contents
show_mounted_contents() {
    if [[ -d "$temp_mount" ]]; then
        echo
        echo "Contents of the mounted disk ($temp_mount):"
        echo
        if command -v tree &> /dev/null; then
            tree "$temp_mount"
        else
            ls -lR "$temp_mount"
        fi
        echo
    else
        echo "Error: Temporary mount point not found."
    fi
}

# Function to get user confirmation
get_confirmation() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt (y/n/exit): " response
        case "${response,,}" in
            y ) return 0;;
            n ) return 1;;
            exit ) handle_exit;;
            * ) echo "Please answer 'y', 'n', or 'exit'.";;
        esac
    done
}

# Function to get user input with exit option
get_input() {
    local prompt="$1"
    read -p "$prompt (or type 'exit'): " input
    case "${input,,}" in
        exit ) handle_exit;;
        * ) echo "$input";;
    esac
}

# Function to handle unmounting
ask_and_unmount() {
    while true; do
        read -p "Do you want to unmount a disk? (y/n/exit): " response
        case "${response,,}" in
            y ) 
                unmount_path=$(get_input "Enter the path to unmount (e.g., /mnt/usb)")
                if [[ -n "$unmount_path" ]]; then
                    echo "Unmounting $unmount_path..."
                    sudo umount -- "$unmount_path" || {
                        umount_result=$?
                        echo "Error unmounting $unmount_path (exit code: $umount_result)"
                    }
                fi
                break ;;
            n ) break;;
            exit ) handle_exit;;
            * ) echo "Please answer 'y', 'n', or 'exit'.";;
        esac
    done
}

# Check if help is requested
if [[ "$1" == "help" ]]; then
    show_help
    exit 0
fi

# Display initial disk layout
show_lsblk

# Ask if the user wants to unmount and perform unmount if yes
ask_and_unmount

# Get disk to format (with validation and exit option)
while true; do
    read -p "Enter the disk to format (e.g., /dev/sdb) (or type 'exit'): " disk_to_format
    case "${disk_to_format,,}" in
        exit) handle_exit;;
        *)
            if [[ "$disk_to_format" =~ ^/dev/sd[b-z]$ ]] && [[ -b "$disk_to_format" ]]; then
                break
            else
                echo "Error: Invalid disk format or device does not exist. Please enter /dev/sdX (e.g., /dev/sdb)."
            fi
            ;;
    esac
done

# Get network and farm ID (with validation and exit option)
while true; do
    read -p "Enter the network (mainnet, devnet, testnet, qanet) (or type 'exit'): " network
    case "${network,,}" in
        mainnet) network_part="prod"; break;;
        devnet) network_part="dev"; break;;
        testnet) network_part="test"; break;;
        qanet) network_part="qa"; break;;
        exit) handle_exit;;
        *) echo "Invalid network. Please enter mainnet, devnet, testnet, or qanet.";;
    esac
done
while true; do
    read -p "Enter the farm ID (positive integer, or type 'exit'): " farm_id
    case "${farm_id,,}" in  # Convert to lowercase for case-insensitive matching
        exit) handle_exit "Exiting at user request.";;
        *[!0-9]*)  # Check for any non-digit characters
            echo "Invalid farm ID. Please enter a positive integer or 'exit'."
            ;;
        *) # If it's all digits, it's considered valid
            break
            ;;
    esac
done

ipxe_url="https://bootstrap.grid.tf/uefi/${network_part}/${farm_id}"

echo
echo "The URL to download the bootstrap image is the following: $ipxe_url"
echo

# Confirm formatting
if ! get_confirmation "Are you sure you want to format $disk_to_format? This will ERASE ALL DATA"; then
    echo
    echo "Operation cancelled."
    echo
    exit 0
fi

# Format the disk with FAT32
echo
echo "Formatting $disk_to_format with VFAT -I..."
echo
sudo mkfs.vfat -I "$disk_to_format" || {
    echo "Error formatting disk"
    exit 1
}

# Create temporary mount point
temp_mount="/mnt/temp_usb"
sudo mkdir -p "$temp_mount"

# Mount the newly formatted disk
echo
echo "Mounting formatted disk..."
echo
sudo mount "$disk_to_format" "$temp_mount" || {
    echo "Error mounting formatted disk"
    exit 1
}

# Create EFI/BOOT directory and copy file
echo
echo "Creating EFI boot directory..."
echo
sudo mkdir -p "$temp_mount/EFI/BOOT"

# Download and rename the iPXE file
echo
echo "Downloading iPXE file from $ipxe_url..."
echo
sudo curl -L "$ipxe_url" -o "$temp_mount/EFI/BOOT/BOOTX64.EFI" || {
    echo "Error downloading iPXE file"
    sudo umount "$temp_mount"
    exit 1
}

# Show the contents of the mounted disk before unmounting
show_mounted_contents 

# Unmount the temporary mount point
echo
echo "Unmounting temporary mount point..."
echo
sudo umount "$temp_mount"

# State the success of the operation
echo
echo "The ZOS bootstrap image has been copied to the USB key."
echo

# Ask about ejecting
if get_confirmation "Do you want to eject the disk?"; then
    echo
    echo "Ejecting $disk_to_format..."
    echo
    sudo eject "$disk_to_format" || {
        echo "Error ejecting disk"
        exit 1
    }
    echo "Disk ejected successfully"
fi

echo
echo "Operation completed."
echo