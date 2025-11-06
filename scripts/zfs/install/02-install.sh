#!/usr/bin/env bash

set -e

exec &> >(tee "install.log")

# Debug
if [[ "$1" == "debug" ]]
then
    set -x
    debug=1
fi

print () {
    echo -e "\n\033[1m> $1\033[0m\n"
    if [[ -n "$debug" ]]
    then
      read -rp "Press enter to continue..."
    fi
}

# Identify if system is virtual
if [[ $(systemd-detect-virt | grep 'kvm') == kvm ]]; then
  DEVPATH="/dev/disk/by-path"
else
  DEVPATH="/dev/disk/by-id"
fi

# Root dataset
root_dataset=$(cat /tmp/root_dataset)

# Sort mirrors
print "Sort mirrors"
systemctl start reflector

# Install
print "Install Arch Linux"
pacstrap /mnt       \
  base              \
  base-devel        \
  linux-lts         \
  linux-lts-headers \
  linux-firmware    \
  man-db            \
  man-pages         \
  efibootmgr        \
  nano              \
  vim               \
  bash-completion   \
  terminus-font     \
  git

# Fix the “warning: directory permissions differ on /mnt/root/ filesystem: 755
# package: 750” message during pacstrap.
chmod 750 /mnt/root
# Fix the "warning: directory permissions differ on /mnt/var/tmp/ filesystem: 755
# package: 1777" message during pacstrap.
chmod 1777 /mnt/var/tmp

# Generate fstab excluding ZFS entries
print "Generate fstab excluding ZFS entries"
echo "# <file system>         <dir>           <type>          <options>                                                                                          <dump> <pass>" > /mnt/etc/fstab
genfstab -U /mnt | grep -v "zroot" | tr -s '\n' | sed 's/\/mnt//'  >> /mnt/etc/fstab

# Set hostname
read -r -p 'Enter hostname: ' hostname
echo "$hostname" > /mnt/etc/hostname

# Configure /etc/hosts
read -r -p 'Enter domain name: ' domainname
print "Configure hosts file"
cat > /mnt/etc/hosts <<EOF
#<ip-address>	<hostname.domain.tld>      <hostname>
127.0.0.1     $hostname.$domainname $hostname
::1           $hostname.$domainname $hostname
EOF

# Prepare locales and keymap
print "Prepare locales and keymap"
cat > /mnt/etc/vconsole.conf <<EOF
KEYMAP=sv-latin1
FONT=ter-116n
EOF
sed -i 's/#\(en_US.UTF-8\)/\1/' /mnt/etc/locale.gen
sed -i 's/#\(en_GB.UTF-8\)/\1/' /mnt/etc/locale.gen
sed -i 's/#\(sv_SE.UTF-8\)/\1/' /mnt/etc/locale.gen
cat > /mnt/etc/locale.conf <<EOF
# Determines the default locale in the absence of other locale related environment variables.
LANG=en_GB.UTF-8
# Format of interactive words and responses.
LC_MESSAGES=en_GB.UTF-8
# Character classification and case conversion.
LC_CTYPE=sv_SE.UTF-8
# Numeric formatting.
LC_NUMERIC=sv_SE.UTF-8
# Date and time formats.
LC_TIME=sv_SE.UTF-8
# Monetary formatting.
LC_MONETARY=sv_SE.UTF-8
# Default measurement system used within the region.
LC_MEASUREMENT=sv_SE.UTF-8
# Convention used for formatting of street or postal addresses.
LC_ADDRESS=sv_SE.UTF-8
# Conventions used for representation of telephone numbers.
LC_TELEPHONE=sv_SE.UTF-8
# Default paper size for region.
LC_PAPER=sv_SE.UTF-8
# Collation order.
LC_COLLATE=sv_SE.UTF-8
EOF

# Prepare initramfs
print "Prepare initramfs"
sed -i "s/HOOKS=.*/HOOKS=(base udev autodetect modconf block keyboard keymap consolefont zfs filesystems)/g" /mnt/etc/mkinitcpio.conf
sed -i "s/BINARIES=.*/BINARIES=(setfont)/g" /mnt/etc/mkinitcpio.conf
sed -i 's/#\(COMPRESSION="zstd"\)/\1/' /mnt/etc/mkinitcpio.conf
sed -i "s/FILES=.*/FILES=(\/etc\/zfs\/zroot.key)/g" /mnt/etc/mkinitcpio.conf

cat > /mnt/etc/mkinitcpio.d/linux-lts.preset <<EOF
# mkinitcpio preset file for the 'linux-lts' package

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux-lts"

PRESETS=('default')

#default_config="/etc/mkinitcpio.conf"
default_image="/boot/initramfs-linux-lts.img"
#default_options=""

#fallback_config="/etc/mkinitcpio.conf"
#fallback_image="/boot/initramfs-linux-lts-fallback.img"
#fallback_options="-S autodetect"
EOF

# Configure username
print 'Set regular username'
read -r -p "Username: " user

# Create ZFS dataset for user
zfs create zroot/data/home/"$user"

print "Copy ZFS files"
cp /etc/hostid /mnt/etc/hostid
cp /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache
cp /etc/zfs/zroot.key /mnt/etc/zfs

# Chroot and configure
print "Chroot and configure system"

arch-chroot /mnt /bin/bash -xe <<EOF

  # Configure pacman
  sed -i "/Color/s/^#//" /etc/pacman.conf
  sed -i "s/#\[multilib\]/[multilib]/" /etc/pacman.conf
  sed -i "/\[multilib\]$/{n;s/^#//;}" /etc/pacman.conf
  pacman -Sy

  ## Re-initialize keyring
  # As keyring is initialized at boot and copied to the install directory with pacstrap
  # while NTP is running, time changed after keyring initialization. This leads to mal-
  # function. Keyring must be re-initialized properly to be able to sign archzfs key.
  rm -Rf /etc/pacman.d/gnupg
  pacman-key --init
  pacman-key --populate archlinux
  pacman-key --recv-keys F75D9D76 --keyserver keyserver.ubuntu.com
  pacman-key --lsign-key F75D9D76
  pacman -S archlinux-keyring --noconfirm
  cat >> /etc/pacman.conf <<EOSF

[archzfs]
Server = http://archzfs.com/archzfs/x86_64
Server = http://mirror.sum7.eu/archlinux/archzfs/archzfs/x86_64
Server = https://mirror.biocrafting.net/archlinux/archzfs/archzfs/x86_64
EOSF

  pacman -Syu --noconfirm zfs-dkms zfs-utils

  # Sync clock
  hwclock --systohc

  # Set date
  ln -sf /usr/share/zoneinfo/Europe/Stockholm /etc/localtime
  # Setting date/time in chroot causes errors.
  #timedatectl set-ntp true
  #timedatectl set-timezone Europe/Stockholm
  systemctl enable systemd-timesyncd.service

  # Generate locale
  locale-gen
  source /etc/locale.conf

  # Generate initramfs
  mkinitcpio -P

  # Install ZFSBootMenu and dependencies
  git clone --depth=1 https://github.com/zbm-dev/zfsbootmenu/ /tmp/zfsbootmenu
  pacman -S cpanminus kexec-tools fzf util-linux --noconfirm
  cd /tmp/zfsbootmenu
  make
  make install
  cpanm --notest --installdeps .

  # Configure networking
  pacman -S --noconfirm networkmanager openssh
  systemctl enable NetworkManager.service
  systemctl enable sshd.service

  # Create user
  useradd ${user} -M -g users -G wheel -s /bin/bash
  cp -a /etc/skel/. /home/${user}
  chown -R ${user}:users /home/${user}
  chmod 700 /home/${user}

EOF

# Set root passwd
print "Set root password"
arch-chroot /mnt /bin/passwd

# Set user passwd
print "Set user password"
arch-chroot /mnt /bin/passwd "$user"

# Configure sudo
print "Configure sudo"
sed -i "/%wheel ALL=(ALL:ALL) ALL/s/^# //" /mnt/etc/sudoers

# Activate ZFS
print "Configure ZFS"
systemctl enable zfs-import-cache --root=/mnt
systemctl enable zfs-mount --root=/mnt
systemctl enable zfs-import.target --root=/mnt
systemctl enable zfs.target --root=/mnt

# Configure zfs-mount-generator
print "Configure zfs-mount-generator"
mkdir -p /mnt/etc/zfs/zfs-list.cache
touch /mnt/etc/zfs/zfs-list.cache/zroot
zfs list -H -o name,mountpoint,canmount,atime,relatime,devices,exec,readonly,setuid,nbmand | sed 's/\/mnt//' > /mnt/etc/zfs/zfs-list.cache/zroot
systemctl enable zfs-zed.service --root=/mnt

# Configure zfsbootmenu
mkdir -p /mnt/efi/EFI/zbm

# Generate zfsbootmenu efi
print 'Configure ZFSBootMenu'
# https://github.com/zbm-dev/zfsbootmenu/blob/master/etc/zfsbootmenu/mkinitcpio.conf

cat > /mnt/etc/zfsbootmenu/mkinitcpio.conf <<EOF
MODULES=()
BINARIES=(setfont)
FILES=()
HOOKS=(base udev autodetect modconf block keyboard keymap consolefont)
COMPRESSION="zstd"
EOF

cat > /mnt/etc/zfsbootmenu/config.yaml <<EOF
Global:
  ManageImages: true
  BootMountPoint: /efi
  InitCPIO: true
Components:
  Enabled: false
EFI:
  ImageDir: /efi/EFI/zbm
  Versions: false
  Enabled: true
Kernel:
  CommandLine: ro quiet loglevel=0 vt.global_cursor_default=0 zbm.import_policy=hostid
  Prefix: vmlinuz
EOF

# Set cmdline
zfs set org.zfsbootmenu:commandline="rw quiet loglevel=0 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 nowatchdog rd.vconsole.keymap=sv-latin1" zroot/ROOT/"$root_dataset"

# Generate ZBM
print 'Generate ZBM'
arch-chroot /mnt /bin/bash -xe <<EOF

  # Export locale
  export LANG="en_GB.UTF-8"

  # Generate ZFSBootMenu
  generate-zbm
EOF

# Set DISK
if [[ -f /tmp/disk ]]
then
  DISK=$(cat /tmp/disk)
else
  print 'Select disk the system is installed on:'
  select ENTRY in $(ls "$DEVPATH");
  do
      DISK="$DEVPATH/$ENTRY"
      echo "Creating boot entries on $ENTRY."
      break
  done
fi

# Create UEFI entries
print 'Create EFI boot entries'
if ! efibootmgr | grep ZFSBootMenu
then
    efibootmgr --disk "$DISK" \
      --part 1 \
      --create \
      --label "ZFSBootMenu Backup" \
      --loader "\EFI\zbm\vmlinuz-backup.efi" \
      --verbose
    efibootmgr --disk "$DISK" \
      --part 1 \
      --create \
      --label "ZFSBootMenu" \
      --loader "\EFI\zbm\vmlinuz.efi" \
      --verbose
else
    print 'Boot entries already created'
fi

# Umount all partitions
print "Umount all partitions"
umount /mnt/efi
zfs umount -a

# Export zpool
print "Export zpool"
zpool export zroot

# Finish
echo -e "\e[32mAll OK!"
