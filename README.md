# arch-config

## Description
A collection of scripts used to quickly deploy a minimal [Arch Linux](https://www.archlinux.org/) installation with [ZFS](https://zfsonlinux.org/) on root and [native encryption](https://wiki.archlinux.org/title/ZFS#Native_encryption).

### ZFS on root features
- [Native encryption](https://wiki.archlinux.org/title/ZFS#Native_encryption) using `aes-256-gcm`
- [ZStandard](https://en.wikipedia.org/wiki/Zstd) compression (`zstd`) on all datasets
- Periodic [trimming](https://wiki.archlinux.org/title/ZFS#Enabling_TRIM) enabled (`autotrim=on`) on zpool.
- [Boot environments](https://docs.zfsbootmenu.org/en/latest/guides/general/bootenvs-and-you.html) managed with [ZFSBootMenu](https://zfsbootmenu.org/)
  - `/boot` directory resides on ZFS
- No swap volume/partition
- Separate system datasets

### ZFS dataset configuration
The following [ZFS datasets](https://wiki.archlinux.org/index.php/ZFS#Creating_datasets) will be automatically created during installation.

| **Name**                         |  **Mountpoint**    |
| ---                              | ---                |
| `zroot/ROOT/<root dataset name>` | `/`                |
| `zroot/data/home`                | `/home`            |
| `zroot/data/home/<username>`     | `/home/<username>` |
| `zroot/data/home/root`           | `/root`            |
| `zroot/var`                      | `/var`             |
| `zroot/var/cache`                | `/var/cache`       |
| `zroot/var/lib`                  | `/var/lib`         |
| `zroot/var/lib/libvirt`          | `/var/lib/libvirt` |
| `zroot/var/log`                  | `/var/log`         |

## Usage
Clone the repository.
```
git clone --recursive https://github.com/pwyde/arch-config
```
Go to install script in [scripts/zfs/install/](scripts/zfs/install/) and see [README.md](scripts/zfs/install/README.md)

Download and use [dotfiles](https://github.com/pwyde/dotfiles) repository.