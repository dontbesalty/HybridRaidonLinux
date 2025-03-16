# RAID/LVM Management Script

## Features
- Interactive menu system
- RAID1 creation with device validation
- RAID5 expansion with health checks
- Safe removal procedure with confirmation
- Color-coded status messages

## Requirements
- Linux environment (tested on Ubuntu 24.04 LTS)
- `mdadm` and `lvm2` packages installed
- Sudo/root access
- Available storage devices

## Installation
```bash
chmod +x raid_lvm_manager.sh
```

## Usage
```bash
sudo ./raid_lvm_manager.sh
```

### Example Workflow
1. Create RAID1:
   - Select option 1
   - Enter first device (e.g. /dev/sdb)
   - (Optional) Add second device
   - Confirm destruction

2. Expand to RAID5:
   - Select option 2 when ready
   - Add third device
   - Monitor expansion progress

3. Remove All:
   - Select option 3
   - Confirm full destruction
   - List devices to wipe

## Safety Features
⚠️ Includes:
- Device existence checks
- RAID health verification
- Double confirmation for destructive ops
- Superblock wiping
