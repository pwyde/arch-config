#!/usr/bin/env bash

set -e

exec &> >(tee "configure.log")

print () {
    echo -e "\n\033[1m> $1\033[0m\n"
}

ask () {
    read -p "> $1 " -r
    echo
}

menu () {
    PS3="> Choose a number: "
    select i in "$@"
    do 
        echo "$i"
        break
    done
}

# Tests
tests () {
    ls /sys/firmware/efi/efivars > /dev/null &&   \
        ping archlinux.org -c 1 > /dev/null &&    \
        timedatectl set-ntp true > /dev/null &&   \
        modprobe zfs &&                           \
        print "Tests OK!"
}

# Identify if system is virtual
id_vm () {
    if [[ $(systemd-detect-virt | grep 'kvm') == kvm ]]; then
        DEVPATH="/dev/disk/by-path"
    else
        DEVPATH="/dev/disk/by-id"
    fi
}

select_disk () {
    # Set DISK
    select ENTRY in $(ls "$DEVPATH");
    do
        DISK="$DEVPATH/$ENTRY"
        echo "$DISK" > /tmp/disk
        echo "Installing on $ENTRY."
        break
    done
}

wipe () {
    ask "Do you want to wipe all data on $ENTRY ?"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Clear disk
        dd if=/dev/zero of="$DISK" bs=512 count=1
        wipefs --all --force "$DISK"
        sgdisk --zap-all --clear "$DISK"
    fi
}

partition () {
    # EFI part
    print "Creating EFI partition"
    sgdisk -n1:1M:+1G -t1:EF00 "$DISK"
    EFI="$DISK-part1"
    
    # ZFS part
    print "Creating ZFS partition"
    sgdisk -n2:0:0 -t2:bf00 "$DISK"
    
    # Inform kernel
    partprobe "$DISK"
    
    # Format efi part
    sleep 1
    print "Format EFI partition"
    mkfs.vfat "$EFI"
}

zfs_passphrase () {
    # Generate key
    print "Set ZFS passphrase"
    read -r -p "> ZFS passphrase: " -s pass
    echo
    echo "$pass" > /etc/zfs/zroot.key
    chmod 000 /etc/zfs/zroot.key
}

create_pool () {
    # ZFS part
    ZFS="$DISK-part2"
    
    # Create ZFS pool
    print "Create ZFS pool"
    zpool create -f -o ashift=12                          \
                 -o autotrim=on                           \
                 -O acltype=posixacl                      \
                 -O compression=zstd                      \
                 -O relatime=on                           \
                 -O xattr=sa                              \
                 -O dnodesize=legacy                      \
                 -O encryption=aes-256-gcm                \
                 -O keyformat=passphrase                  \
                 -O keylocation=file:///etc/zfs/zroot.key \
                 -O normalization=formD                   \
                 -O mountpoint=none                       \
                 -O canmount=off                          \
                 -O devices=off                           \
                 -R /mnt                                  \
                 zroot "$ZFS"
}

create_root_dataset () {
    # Slash dataset
    print "Create root dataset"
    zfs create -o mountpoint=none                 zroot/ROOT

    # Set cmdline
    zfs set org.zfsbootmenu:commandline="ro quiet" zroot/ROOT
}

create_system_dataset () {
    print "Create slash dataset"
    zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/"$1"

    print "Create system datasets"
    zfs create -o mountpoint=/var -o canmount=off     zroot/var
    zfs create                                        zroot/var/cache
    zfs create                                        zroot/var/log
    zfs create -o mountpoint=/var/lib -o canmount=off zroot/var/lib
    zfs create                                        zroot/var/lib/libvirt
    

    # Generate zfs hostid
    print "Generate hostid"
    zgenhostid
    
    # Set bootfs 
    print "Set ZFS bootfs"
    zpool set bootfs="zroot/ROOT/$1" zroot

    # Manually mount slash dataset
    #zfs mount zroot/ROOT/"$1"
}

create_home_dataset () {
    print "Create home datasets"
    zfs create -o mountpoint=none   zroot/data
    zfs create -o mountpoint=/home  zroot/data/home
    zfs create -o mountpoint=/root  zroot/data/home/root
}

export_pool () {
    print "Export zpool"
    zpool export zroot
}

import_pool () {
    print "Import zpool"
    zpool import -d "$DEVPATH" -R /mnt zroot -N -f
    zfs load-key zroot
}

mount_system () {
    print "Mount datasets"
    zfs mount zroot/ROOT/"$1"
    zfs mount -a
    
    # Mount EFI part
    print "Mount EFI partition"
    EFI="$DISK-part1"
    mkdir -p /mnt/efi
    mount "$EFI" /mnt/efi
}

copy_zpool_cache () {
    # Copy ZFS cache
    print "Generate and copy ZFS cache"
    mkdir -p /mnt/etc/zfs
    zpool set cachefile=/etc/zfs/zpool.cache zroot
}

# Main
tests
id_vm

print "Is this the first install or a second install to dualboot?"
install_reply=$(menu first dualboot)

select_disk
zfs_passphrase

# If first install
if [[ $install_reply == "first" ]]; then
    # Wipe the disk
    wipe
    # Create partition table
    partition
    # Create ZFS pool
    create_pool
    # Create root dataset
    create_root_dataset
fi

ask "Name of the slash dataset?"
name_reply="$REPLY"
echo "$name_reply" > /tmp/root_dataset

if [[ $install_reply == "dualboot" ]]; then
    import_pool
fi

create_system_dataset "$name_reply"

if [[ $install_reply == "first" ]]; then
    create_home_dataset
fi

export_pool
import_pool
mount_system "$name_reply"
copy_zpool_cache

# Finish
echo -e "\e[32mAll OK!"
