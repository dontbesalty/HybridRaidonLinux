#!/bin/bash

# raid_lvm_manager.sh

# This script helps manage RAID and LVM setup

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to display a message with color
msg() {
  local color="$1"
  local message="$2"
  echo -e "${color}${message}${NC}"
}

# Function to check if a device exists
device_exists() {
  if [[ -b "$1" ]]; then
    return 0 # Device exists
  else
    return 1 # Device does not exist
  fi
}

# Function to list available drives
list_available_drives() {
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT --exclude 7,11,1,2,0,259 | \
  awk 'NR>1 && $3=="disk" && $4=="" {print "/dev/"$1}'
}

# Function to get user confirmation
confirm() {
  read -r -p "${1} [y/N]: " response
  case "$response" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Function to check RAID array health
raid_health() {
  mdadm --detail "$1" | grep "State : clean" > /dev/null
  if [ $? -eq 0 ]; then
    msg "${GREEN}" "RAID array ${1} is healthy."
    return 0
  else
    msg "${RED}" "RAID array ${1} is NOT healthy."
    return 1
  fi
}

# Create RAID1 array
create_raid1() {
  msg "${YELLOW}" "Creating RAID1 array..."

  echo "Available drives:"
  list_available_drives
  available_drives=($(list_available_drives))

  if [ ${#available_drives[@]} -eq 0 ]; then
    msg "${RED}" "No available drives found."
    return 1
  fi

  read -r -p "Enter the first device (e.g., /dev/sdc): " device1
  read -r -p "Enter the second device (e.g., /dev/sdd, or leave blank for single drive): " device2

  # Validate device selection
  valid=0
  for drive in "${available_drives[@]}"; do
    if [ "$device1" = "$drive" ]; then
      valid=1
      break
    fi
  done
  if [ "$valid" -eq 0 ]; then
    msg "${RED}" "Error: Invalid device ${device1}."
    return 1
  fi

  if [ -n "$device2" ]; then
    valid=0
    for drive in "${available_drives[@]}"; do
      if [ "$device2" = "$drive" ]; then
        valid=1
        break
      fi
    done
    if [ "$valid" -eq 0 ]; then
      msg "${RED}" "Error: Invalid device ${device2}."
      return 1
    fi
  fi

  if confirm "This operation will ERASE all data on ${device1} and ${device2} (if provided). Are you sure?"; then
    if [ -n "$device2" ]; then
      mdadm --create /dev/md1 -n2 -l1 "$device1" "$device2" --force
    else
      mdadm --create /dev/md1 -n1 -l1 "$device1" --force
    fi

    if [ $? -eq 0 ]; then
      msg "${GREEN}" "RAID1 array /dev/md1 created successfully."
      return 0
    else
      msg "${RED}" "Error creating RAID1 array."
      return 1
    fi
  else
    msg "${YELLOW}" "RAID1 creation cancelled."
    return 1
  fi
}

# Create LVM structure
create_lvm() {
  msg "${YELLOW}" "Creating LVM structure..."

  if ! device_exists "/dev/md1"; then
    msg "${RED}" "Error: RAID device /dev/md1 does not exist."
    return 1
  fi

  pvcreate /dev/md1
  if [ $? -eq 0 ]; then
    msg "${GREEN}" "Physical volume created on /dev/md1."
  else
    msg "${RED}" "Error creating physical volume."
    return 1
  fi

  vgcreate storage /dev/md1
  if [ $? -eq 0 ]; then
    msg "${GREEN}" "Volume group 'storage' created."
  else
    msg "${RED}" "Error creating volume group."
    return 1
  fi

  lvcreate -n share -l 100%FREE storage
  if [ $? -eq 0 ]; then
    msg "${GREEN}" "Logical volume 'share' created."
  else
    msg "${RED}" "Error creating logical volume."
    return 1
  fi

  mkfs.ext4 /dev/storage/share
  if [ $? -eq 0 ]; then
    msg "${GREEN}" "Filesystem created on /dev/storage/share."
  else
    msg "${RED}" "Error creating filesystem."
    return 1
  fi

  mkdir /mnt/share
  if [ $? -eq 0 ]; then
    msg "${GREEN}" "Mount point /mnt/share created."
  else
    msg "${RED}" "Error creating mount point."
    return 1
  fi

  mount /dev/storage/share /mnt/share
  if [ $? -eq 0 ]; then
    msg "${GREEN}" "Filesystem mounted on /mnt/share."
  else
    msg "${RED}" "Error mounting filesystem."
    return 1
  fi

  msg "${GREEN}" "LVM structure created and mounted successfully!"
  return 0
}

# Expand to RAID5
expand_raid5() {
  msg "${YELLOW}" "Expanding to RAID5..."

  echo "Available drives:"
  list_available_drives
  available_drives=($(list_available_drives))

  if [ ${#available_drives[@]} -eq 0 ]; then
    msg "${RED}" "No available drives found."
    return 1
  fi

  read -r -p "Enter the third device (e.g., /dev/sde): " device3

  # Validate device selection
  valid=0
  for drive in "${available_drives[@]}"; do
    if [ "$device3" = "$drive" ]; then
      valid=1
      break
    fi
  done
  if [ "$valid" -eq 0 ]; then
    msg "${RED}" "Error: Invalid device ${device3}."
    return 1
  fi

  if ! device_exists "/dev/md1"; then
    msg "${RED}" "Error: RAID device /dev/md1 does not exist."
    return 1
  fi

  if raid_health "/dev/md1"; then
    mdadm --grow /dev/md1 -l 5
    if [ $? -eq 0 ]; then
      msg "${GREEN}" "RAID level changed to RAID5."
    else
      msg "${RED}" "Error changing RAID level."
      return 1
    fi

    mdadm /dev/md1 --add-spare "$device3"
    if [ $? -eq 0 ]; then
      msg "${GREEN}" "Added ${device3} to /dev/md1."
    else
      msg "${RED}" "Error adding ${device3}."
      return 1
    fi

    mdadm --grow /dev/md1 -n 3
    if [ $? -eq 0 ]; then
      msg "${GREEN}" "RAID array size grown."
    else
      msg "${RED}" "Error growing RAID array."
      return 1
    fi

    pvresize /dev/md1
    if [ $? -eq 0 ]; then
      msg "${GREEN}" "Physical volume resized."
    else
      msg "${RED}" "Error resizing physical volume."
      return 1
    fi

    vgextend storage /dev/md1
    if [ $? -eq 0 ]; then
      msg "${GREEN}" "Volume group extended."
    else
      msg "${RED}" "Error extending volume group."
      return 1
    fi

    lvextend -l+100%FREE /dev/storage/share
    if [ $? -eq 0 ]; then
      msg "${GREEN}" "Logical volume extended."
    else
      msg "${RED}" "Error extending logical volume."
      return 1
    fi

    resize2fs /dev/mapper/storage-share
    if [ $? -eq 0 ]; then
      msg "${GREEN}" "Filesystem resized."
    else
      msg "${RED}" "Error resizing filesystem."
      return 1
    fi

    msg "${GREEN}" "RAID5 expansion and LVM resize complete!"
    return 0
  else
    return 1
  fi
}

# Remove all
remove_all() {
  msg "${RED}" "Removing all RAID and LVM components..."

  if confirm "This operation is DESTRUCTIVE and will ERASE all data. Are you absolutely sure?"; then
    lvremove /dev/mapper/storage-share
    if [ $? -eq 0 ]; then
      msg "${GREEN}" "Logical volume removed."
    else
      msg "${RED}" "Error removing logical volume."
      return 1
    fi

    mdadm --stop /dev/md1
    if [ $? -eq 0 ]; then
      msg "${GREEN}" "RAID array stopped."
    else
      msg "${RED}" "Error stopping RAID array."
      return 1
    fi

    # Zero superblock on all devices
    echo "Available drives:"
    list_available_drives
    available_drives=($(list_available_drives))

    if [ ${#available_drives[@]} -eq 0 ]; then
      msg "${RED}" "No available drives found."
      return 1
    fi

    read -r -p "Enter the devices to zero superblock (e.g., /dev/sdc /dev/sdd /dev/sde): " devices
    for device in $devices; do
      # Validate device selection
      valid=0
      for drive in "${available_drives[@]}"; do
        if [ "$device" = "$drive" ]; then
          valid=1
          break
        fi
      done
      if [ "$valid" -eq 0 ]; then
        msg "${RED}" "Error: Invalid device ${device}."
        return 1
      fi

      if device_exists "$device"; then
        mdadm --zero-superblock "$device"
        if [ $? -eq 0 ]; then
          msg "${GREEN}" "Superblock zeroed on ${device}."
        else
          msg "${RED}" "Error zeroing superblock on ${device}."
          return 1
        fi
      else
        msg "${RED}" "Error: Device ${device} does not exist."
        return 1
      fi
    done

    msg "${GREEN}" "All RAID and LVM components removed."
    return 0
  else
    msg "${YELLOW}" "Removal cancelled."
    return 1
  fi
}

# Main menu
main_menu() {
  while true; do
    echo ""
    echo "Choose an operation:"
    echo "1) Create RAID1 and LVM"
    echo "2) Expand to RAID5"
    echo "3) Remove All (DESTRUCTIVE)"
    echo "4) Exit"
    read -r -p "Enter your choice: " choice

    case "$choice" in
      1)
        create_raid1
        if [ $? -eq 0 ]; then
          create_lvm
        fi
        ;;
      2)
        expand_raid5
        ;;
      3)
        remove_all
        ;;
      4)
        msg "${GREEN}" "Exiting."
        exit 0
        ;;
      *)
        msg "${RED}" "Invalid choice. Please try again."
        ;;
    esac
  done
}

# Start the main menu
main_menu
