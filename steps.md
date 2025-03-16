pvs && vgs && lvs
lsblk

####  Create RAID1 from single drive
```bash
mdadm --create /dev/md1 -n1 -l1 /dev/sdc --force
```

####  Create Physical Volume
```bash
pvcreate /dev/md1
```

####  Create Volume Group
```bash
vgcreate storage /dev/md1
```

####  Create Logical Volume 
```bash
lvcreate -n share -l 100%FREE share
```

####  Create Filesystem (ext4)
```bash
mkfs.ext4 /dev/storage/share
```

####  Create mount location
```bash
mkdir /mnt/share
```

####  
```bash
pvscan
```

####  
```bash
vgchange -ay
```

####  
```bash
lvscan
```
####  
```bash
mount /dev/storage/share /mnt/share
```

####  



# Expand to 2 drives (mirror)
####  Add 2nd disk
mdadm /dev/md1 --add-spare /dev/sdd

####  Activate 2nd drive
mdadm --grow /dev/md1 -n2


# Expand to 3 drives (RAID5)
####  Change RAID1 to RAID5
mdadm --grow /dev/md1 -l 5

####  Add 3rd disk
mdadm /dev/md1 --add-spare /dev/sde

####  Grow array
mdadm --grow /dev/md1 -n 3



## LVM expand

####  Resize PV
pvresize /dev/md1

####  Extend VG
vgextend share /dev/md1

####  Extend LV
lvextend -l+100%FREE /dev/storage/share

####  Resize Filesystem
resize2fs /dev/mapper/storage-share

####  



---



##  Remove All

mdadm --detail /dev/md1

####  
lvremove /dev/mapper/share

####  
mdadm --stop /dev/md1

####  
mdadm --zero-superblock /dev/sd??

####  

