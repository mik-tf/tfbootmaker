#!/bin/bash

# Get script information dynamically
SCRIPT_NAME=$(basename "$0")
INSTALL_NAME="${SCRIPT_NAME%.*}"  # Removes the .sh extension if it exists
DISPLAY_NAME="${INSTALL_NAME^^}"  # Convert to uppercase for display
REPO_URL="https://github.com/threefoldtech/${INSTALL_NAME}"

# Display welcome message
display_welcome() {
    echo
    echo "Welcome to ${DISPLAY_NAME}"
    echo
    echo "This utility helps you create a bootable ThreeFold Zero-OS USB drive."
    echo "It will download and write a bootstrap image to your USB device."
    echo
}

# Function to install the script
install() {
    echo
    echo "Installing ${DISPLAY_NAME}..."
    if sudo -v; then
        sudo cp "$0" "/usr/local/bin/${INSTALL_NAME}"
        sudo chown root:root "/usr/local/bin/${INSTALL_NAME}"
        sudo chmod 755 "/usr/local/bin/${INSTALL_NAME}"

        echo
        echo "${DISPLAY_NAME} has been installed successfully."
        echo "You can now use ${INSTALL_NAME} command from anywhere."
        echo
        echo "Use ${INSTALL_NAME} help to see the commands."
        echo
    else
        echo "Error: Failed to obtain sudo privileges. Installation aborted."
        exit 1
    fi
}

# Function to uninstall the script
uninstall() {
    echo
    echo "Uninstalling ${DISPLAY_NAME}..."
    if sudo -v; then
        sudo rm -f "/usr/local/bin/${INSTALL_NAME}"
        echo "${DISPLAY_NAME} has been uninstalled successfully."
        echo
    else
        echo "Error: Failed to obtain sudo privileges. Uninstallation aborted."
        exit 1
    fi
}

# Function to handle exit consistently
handle_exit() {
    echo "Exiting..."
    exit 0
}

# Function to display help information
show_help() {
    cat << EOF
    
==========================
${DISPLAY_NAME}
==========================

This Bash CLI script downloads and copies a ThreeFold Zero-OS bootstrap image to a USB drive to boot a ThreeFold Grid V3 node.

Commands:
  help        Display this help message
  install     Install the script system-wide
  uninstall   Remove the script from the system

Steps:
1. Displays the current disk layout.
2. Shows only removable drives and prompts for selection.
3. Prompts for the network (1=mainnet, 2=testnet, 3=qanet, 4=devnet).
4. Prompts for the farm ID.
5. Confirms the operation.
6. Downloads and directly writes the bootstrap image to the disk.
7. Optionally ejects the USB drive.

Example:
  ${INSTALL_NAME}
  ${INSTALL_NAME} help
  ${INSTALL_NAME} install
  ${INSTALL_NAME} uninstall

Reference: ${REPO_URL}

License: Apache 2.0

EOF
}

# Function to get USB/removable drives
get_removable_drives() {
    # Filter out drives with size 0 (likely ejected)
    lsblk --output NAME,SIZE,MODEL,HOTPLUG --nodeps | grep "1$" | 
    awk '!/0B/ {print "/dev/"$1}'  # Exclude entries with 0B size
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

# Check for arguments
case "$1" in
    "help")
        show_help
        exit 0
        ;;
    "install")
        install
        exit 0
        ;;
    "uninstall")
        uninstall
        exit 0
        ;;
    "")
        # Show welcome message and continue with normal execution
        display_welcome
        ;;
    *)
        echo "Invalid argument. Use '${INSTALL_NAME} help' to see available commands."
        exit 1
        ;;
esac

# Get disk to write image to (with validation and exit option)
while true; do
    echo "Available removable drives:"
    removable_drives=($(get_removable_drives))
    
    if [ ${#removable_drives[@]} -eq 0 ]; then
        echo "No removable drives found. Please insert a USB drive and try again."
        if ! get_confirmation "Would you like to rescan for drives?"; then
            handle_exit
        fi
        continue
    fi
    
    # Display available drives with numbers
    for i in "${!removable_drives[@]}"; do
        drive="${removable_drives[$i]}"
        drive_info=$(lsblk --output SIZE,MODEL --nodeps "${drive}" | tail -n 1)
        echo "$((i+1)). ${drive} - ${drive_info}"
    done
    
    echo
    echo "Type 'exit' to quit at any time"
    echo
    read -p "Enter the number of the drive to use: " drive_selection
    
    if [[ "${drive_selection,,}" == "exit" ]]; then
        handle_exit
    elif [[ "$drive_selection" =~ ^[0-9]+$ ]] && [ "$drive_selection" -le "${#removable_drives[@]}" ] && [ "$drive_selection" -gt 0 ]; then
        disk_to_format="${removable_drives[$((drive_selection-1))]}"
        echo
        echo "You selected: $disk_to_format"
        echo
        echo "Disk information:"
        lsblk -o NAME,SIZE,TYPE,MODEL "$disk_to_format"
        echo
        if get_confirmation "Is this the correct USB device you want to use?"; then
            break
        fi
    else
        echo
        echo "Invalid selection. Please try again."
        echo
    fi
done

# Get network selection with simplified numbered options
echo "Select the network:"
echo "1 = mainnet"
echo "2 = testnet"
echo "3 = qanet"
echo "4 = devnet"

while true; do
    read -p "Enter your choice (1-4) (or type 'exit'): " network_choice
    case "${network_choice,,}" in
        exit) handle_exit;;
        1) network_part="prod"; network_name="mainnet"; break;;
        2) network_part="test"; network_name="testnet"; break;;
        3) network_part="qa"; network_name="qanet"; break;;
        4) network_part="dev"; network_name="devnet"; break;;
        *) echo "Invalid choice. Please enter a number between 1 and 4.";;
    esac
done

while true; do
    read -p "Enter the farm ID (positive integer, or type 'exit'): " farm_id
    case "${farm_id,,}" in  # Convert to lowercase for case-insensitive matching
        exit) handle_exit;;
        *[!0-9]*)  # Check for any non-digit characters
            echo "Invalid farm ID. Please enter a positive integer or 'exit'."
            ;;
        0)  # Explicitly reject zero
            echo "Farm ID cannot be zero. Please enter a positive integer (1 or higher)."
            ;;
        *)  # If it's all digits and not zero, it's considered valid
            break
            ;;
    esac
done

bootstrap_url="https://v3.bootstrap.grid.tf/uefimg/${network_part}/${farm_id}"

echo
echo "Selected network: ${network_name}"
echo "Farm ID: ${farm_id}"
echo "The bootstrap URL is: $bootstrap_url"
echo

# Confirm writing to disk
if ! get_confirmation "Are you sure you want to write the bootstrap image to $disk_to_format? This will ERASE ALL DATA"; then
    echo
    echo "Operation cancelled."
    echo
    exit 0
fi

# Download and write directly to disk with curl and pipe
echo
echo "Downloading and writing bootstrap image to $disk_to_format..."
echo
curl -L "$bootstrap_url" | sudo tee "$disk_to_format" > /dev/null

if [ $? -ne 0 ]; then
    echo "Error downloading or writing bootstrap image"
    exit 1
fi

echo
echo "Bootstrap image has been successfully written to $disk_to_format."
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
echo "Operation completed successfully."
echo