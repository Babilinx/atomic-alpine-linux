#!/bin/ash
# Ash is the default shell on the Live ISO

set -euo pipefail


die() {
  printf "$2\n" >&2
  exit $1
}


[ -d /sys/firmware/efi ] || die 1 "ERROR: Atomic Alpine Linux project relies on EFI boot mode. Detected BIOS."

# Keyboard and netorking are already done as the user have download the script.

# setup apk repo
cat > /etc/apk/repositories << "EOF"
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

apk update
apk upgrade -a

setup-timezone
setup-ntp
passwd

# Install necessary packages

apk add btrfs-progs efibootmgr sfdisk lsblk

# Select install device

echo "Select a device to install Atomic Alpine Linux:"
lsblk
echo
echo "NOTE: Only full device install is supported for now."

read -p "Enter the device path (ex /dev/sda):" INSTALL_DISK

# Partitionning

if [[ "${INSTALL_DISK}" == *"nvme"* ]]; then
	DISK_PARTITIONS="${INSTALL_DISK}p"
else
	DISK_PARTITIONS="${INSTALL_DISK}"
fi

sfdisk "${INSTALL_DISK}" << "EOF"
label: gpt
device: ${INSTALL_DISK}
${DISK_PARTITIONS}1: size=1G,type=uefi
${DISK_PARTITIONS}2: type=linux
EOF

EFI_PART="${DISK_PARTITIONS}1"
SYS_PART="${DISK_PARTITIONS}2"

mkfs.vfat -n "EFI" "${EFI_PART}"
mkfs.btrfs --csum xxhash -L "SYS" "${SYS_PART}"

# Base system layout

mount -t btrfs LABEL=SYS -o noatime /mnt

btrfs subv create /mnt/@aal
btrfs subv create /mnt/@aal/snapshots
btrfs subv create /mnt/@aal/data

btrfs subv create /mnt/@aal/data/var
btrfs subv create /mnt/@aal/data/opt
btrfs subv create /mnt/@aal/data/home

mkdir /mnt/@aal/snapshots/system /mnt/@aal/snapshots/etc /mnt/@aal/snapshots/work-etc

BASE_SNAPSHOT="$(date -u +"%Y-%m-%d_%H:%M:%S")_$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 8 | head -n 1)"
btrfs subv create /mnt/@snapshots/system/$BASE_SNAPSHOT
btrfs subv create /mnt/@snapshots/etc/$BASE_SNAPSHOT

umount /mnt

mount -t btrfs LABEL=SYS -o noatime,compress=zstd:1,subvol=@snapshots/system/$BASE_SNAPSHOT /mnt

mkdir /mnt/var /mnt/opt /mnt/efi /mnt/etc /mnt/home /mnt/.snapshots

mount -t btrfs LABEL=SYS -o noatime,compress=zstd:1,subvol=@data/var /mnt/var
mount -t btrfs LABEL=SYS -o noatime,compress=zstd:1,subvol=@data/opt /mnt/opt
mount -t btrfs LABEL=SYS -o noatime,compress=zstd:3,subvol=@data/home /mnt/home
mount -t btrfs LABEL=SYS -o noatime,compress=zstd:1,subvol=@snapshots /mnt/.snapshots
mount -t vfat LABEL=EFI /mnt/efi

# Remove unneeded packages
apk del sfdisk lsblk

# Installation
BOOTLOADER=none setup-disk /mnt

# Add snapshot details
mkdir -p /mnt/usr/share/aal
echo "${BASE_SNAPSHOT}" > /mnt/usr/share/snapshot-name
