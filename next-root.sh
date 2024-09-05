#!/bin/sh

set -o pipefail

die() {
  [ -z "$2" ] || printf "$2\n" >&2
  [ -z "$3" ] && rm /tmp/next-root.lock
  exit $1
}


ask() {
  read -p "$1 [y/N] " ANS
  [ "$ANS" = "y" -o "$ANS" = "Y" ]
}


usage() {
  cat << "EOF"
  next-root
  
  Usage:
    next-root [options] [arguments]
  
  Options:
    create                   Create next root snapshot
    delete                   Delete next root snapshot
    enter                    Chroot into next root
    apply                    Apply next root snapshot
    
EOF
}


init() {
  # $EUID is not available on sh
  id="$(id | cut -d ' ' -f 1 | tr -dc '0-9')"
  [ $id = 0 ] || die 1 "ERROR: 'next-root' should be run as root" --keep-lock
  [ -d "/usr/share/aal" ] || die 1 "ERROR: Missing '/usr/share/aal'" --keep-lock
  [ -f "/usr/share/aal/snapshot-name" ] || die 1 "ERROR: Missing '/usr/share/aal/snapshot-name'" --keep-lock
  [ -f "/tmp/next-root.lock" ] && die 1 "ERROR: An other instance of 'next-root' is running" --keep-lock
  touch /tmp/next-root.lock
  
  SNAPSHOT_PATH="/.system"
  SYSSHOT_PATH="$SNAPSHOT_PATH/snapshots"
  ETCSHOT_PATH="$SNAPSHOT_PATH/etc"
}


next_root_create() {
  NEXT_SNAPSHOT="$(date -u +"%Y-%m-%d_%H:%M:%S")_$(cat /dev/urandom | tr -dc 'a-zA-Z' \
    | fold -w 8 | head -n 1)"
  CURRENT_SNAPSHOT="$(cat /usr/share/aal/snapshot-name)"

  btrfs subv snapshot $SYSSHOT_PATH/$CURRENT_SNAPSHOT $SYSSHOT_PATH/$NEXT_SNAPSHOT || die 1 \
    "ERROR: Creation of subvolume '$SYSSHOT_PATH/$NEXT_SNAPSHOT' failed"
  btrfs subv snapshot $ETCSHOT_PATH/$CURRENT_SNAPSHOT $ETCSHOT_PATH/$NEXT_SNAPSHOT || die 1 \
    "ERROR: Creation of subvolume '$ETCSHOT_PATH/$NEXT_SNAPSHOT' failed"
  #TODO: clean in case of failure
  
  echo $NEXT_SNAPSHOT > /tmp/aal-next-snapshot
  echo $NEXT_SNAPSHOT > $SYSSHOT_PATH/$NEXT_SNAPSHOT/usr/share/aal/snapshot-name
  
  echo "The next snapshot is created"
}


next_root_delete() {
  [ -f "/tmp/aal-next-snapshot" ] || die 1 "ERROR: No next snapshot created"
  NEXT_SNAPSHOT="$(cat /tmp/aal-next-snapshot)"
  
  ask "Do you want to delete next-root subvolume '$NEXT_SNAPSHOT'?" || die 0 "Deletion aborted"

  btrfs subv delete $SYSSHOT_PATH/$NEXT_SNAPSHOT || die 1 \
    "ERROR: Deleting subvolume '$SNAPSHOT_PATH/$NEXT_SNAPSHOT' failed. You should delete manually"
  btrfs subv delete $ETCSHOT_PATH/$NEXT_SNAPSHOT || die 1 \
    "ERROR: Deleting subvolume '$ETCSHOT_PATH/$NEXT_SNAPSHOT' failed. You should delete manually"
}


check_for_umount() {
  if mountpoint -q "$1"; then
    umount "$1" || die 1 "ERROR: Failed to unmount '$1'.\nSystem can be in a broken state"
  fi
}


clean_chroot() {
  check_for_umount $SYSSHOT_PATH/$NEXT_SNAPSHOT/dev
  check_for_umount $SYSSHOT_PATH/$NEXT_SNAPSHOT/dev/pts 
  check_for_umount $SYSSHOT_PATH/$NEXT_SNAPSHOT/sys
  check_for_umount $SYSSHOT_PATH/$NEXT_SNAPSHOT/proc
  check_for_umount $SYSSHOT_PATH/$NEXT_SNAPSHOT/tmp
  check_for_umount $SYSSHOT_PATH/$NEXT_SNAPSHOT/run
  if [ -L $SYSSHOT_PATH/$NEXT_SNAPSHOT/dev/shm ]; then
    check_for_umount $SYSSHOT_PATH/$NEXT_SNAPSHOT/`readlink $SYSSHOT_PATH/$NEXT_SNAPSHOT/dev/shm`
  else
    check_for_umount $SYSSHOT_PATH/$NEXT_SNAPSHOT/dev/shm
  fi
  
  if [ ! -z $3 ]; then
    die $1 "$3"
  elif [ ! -z $2 ]; then
    die $1 "ERROR: Unable to mount '$2' at '$SYSSHOT_PATH/$NEXT_SNAPSHOT/$2'"
  elif [ ! -z $1 ]; then
    die $1
  fi
}


mount_chroot() {
  CHROOT_PATH="$1"
  # Chroot mounts from Alpine Linux Wiki (https://wiki.alpinelinux.org/wiki/Chroot)
  mount --bind /dev $CHROOT_PATH/dev || clean_chroot 1 "/dev"
  mount -t devpts devpts $CHROOT_PATH/dev/pts -o nosuid,noexec || clean_chroot 1 "dev/pts"
  mount -t sysfs sys $CHROOT_PATH/sys -o nosuid,nodev,noexec,ro || clean_chroot 1 "sys"
  mount -t proc proc $CHROOT_PATH/proc -o nosuid,nodev,noexec || clean_chroot 1 "proc"
  mount -t tmpfs tmp $CHROOT_PATH/tmp -o mode=1777,nosuid,nodev,strictatime || clean_chroot 1 "tmp"
  mount -t tmpfs run $CHROOT_PATH/run -o mode=0755,nosuid,nodev || clean_chroot 1 "run"
  if [ -L $CHROOT_PATH/dev/shm ]; then
    mkdir -p $CHROOT_PATH/`readlink $CHROOT_PATH/dev/shm` || clean_chroot 1 -m \
      "ERROR: Can't create folder '$CHROOT_PATH/`readlink $CHROOT_PATH/dev/shm`'"
    mount -t tmpfs shm $CHROOT_PATH/`readlink $CHROOT_PATH/dev/shm` -o mode=1777,nosuid,nodev || clean_chroot 1 "dev/shm"
  else
    mount -t tmpfs shm $CHROOT_PATH/dev/shm -o mode=1777,nosuid,nodev || clean_chroot 1 "dev/shm"
  fi
  mount -t vfat LABEL=EFI $CHROOT_PATH/efi  #TODO: add options
}


next_root_enter() {
  [ -f "/tmp/aal-next-snapshot" ] || die 1 "ERROR: No next snapshot created"
  NEXT_SNAPSHOT="$(cat /tmp/aal-next-snapshot)"
  
  mount_chroot "$SYSSHOT_PATH/$NEXT_SNAPSHOT"

  chroot $SYSSHOT_PATH/$NEXT_SNAPSHOT /usr/bin/env PS1='chroot [$SHELL] \w# ' /bin/$SHELL

  clean_chroot $? -m "Quitting chroot"
}


next_root_apply() {
  [ -f "/tmp/aal-next-snapshot" ] || die 1 "ERROR: No next snapshot created"
  NEXT_SNAPSHOT="$(cat /tmp/aal-next-snapshot)"
  
  mount_chroot "$SYSSHOT_PATH/$NEXT_SNAPSHOT"
  
  chroot $SYSSHOT_PATH/$NEXT_SNAPSHOT /sbin/apk fix kernel_hooks || clean_chroot 1 -m \
    "ERROR: Failed to run kernel hooks.\nSnapshot '$SYSSHOT_PATH/$NEXT_SNAPSHOT' may be in a broken stage"
  clean_chroot
  
  EFI_UUID="$(blkid | grep LABEL=\"EFI\" | cut -d ' ' -f 3)"
  SYS_UUID="$(blkid | grep LABEL=\"SYS\" | cut -d ' ' -f 3)"
  
  cp /.system/fstab $SYSSHOT_PATH/$NEXT_SNAPSHOT/etc
  sed -i -e s/EFI_UUID/$EFI_UUID/g -e s/SYS_UUID/$SYS_UUID/g -e s/SNAPSHOT_NAME/$NEXT_SNAPSHOT/g \
    $SYSSHOT_PATH/$NEXT_SNAPSHOT/etc/fstab || die 1 \
    "ERROR: Failed to modify ' $SYSSHOT_PATH/$NEXT_SNAPSHOT/etc/fstab'.\nSnapshot may be in a brocken stage"
  #TODO: Remove EFI
  
  btrfs property set -ts $SYSSHOT_PATH/$NEXT_SNAPSHOT ro true || die 1 \
    "ERROR: Unable to set snapshot '$SYSSHOT_PATH/$NEXT_SNAPSHOT' to ro"
  
  echo "All changes have been applied, reboot to get in the new snapshot" 
}


init
echo

[ -z "$@" ] && usage && die 0 ""

for i in "$@"; do
  case $i in

    create) next_root_create;;
    
    delete) next_root_delete;;
    
    enter) next_root_enter;;
    
    apply) next_root_apply;;
    
    -h | --help) usage;;
    
    *) usage; die 1 "\nERROR: Unknown option '$i'";;
    
  esac
done

rm /tmp/next-root.lock
