# Description
The [`01-configure.sh`](/scripts/zfs/install/01-configure.sh) script will automatically perform the following tasks:
- Create partition scheme.
  - EFI partition.
  - Partition that will contain the ZFS filesystem.
- Format filesystems.
- Create an encrypted root zpool using a passphrase.
- Create ZFS datasets.
- Mount everything.

The [`02-install.sh`](/scripts/zfs/install/01-configure.sh) script will automatically perform the following tasks:
- Install and configure a bese [Arch Linux](https://www.archlinux.org/) system including [LTS Kernel](https://archlinux.org/packages/?search=&q=linux-lts).
- Generate [initramfs](https://wiki.archlinux.org/title/Arch_boot_process#initramfs).
- Configure hostname, locales, keymap, network and more...
- Install and configure [ZFSBootMenu](https://zfsbootmenu.org/) as [boot loader](https://wiki.archlinux.org/title/Arch_boot_process#Boot_loader) and will also manage [boot environments](https://docs.zfsbootmenu.org/en/latest/guides/general/bootenvs-and-you.html).
- Create regular user including passwords.

## Usage
[Download](https://archlinux.org/download/) and boot latest Arch Linux ISO.

ZFS module must be loaded using the [archiso-zfs](https://github.com/eoli3n/archiso-zfs) script. It should work on any archiso version. 
```
$ loadkeys sv-latin1
$ curl -s https://raw.githubusercontent.com/eoli3n/archiso-zfs/master/init | bash -s -- -v
```

Download and run scripts.
```
$ git clone https://github.com/pwyde/arch-config
$ cd arch-config/scripts/zfs/install
$ ./01-configure.sh
$ ./02-install.sh
```

## Debug
Run scripts in debug mode with commands below.

```
$ ./01-configure.sh debug
$ ./02-install.sh debug
```

## List EFI content
```
$ sudo lsinitcpio /efi/EFI/ZBM/*
```
