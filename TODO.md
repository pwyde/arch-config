# Todo

## ZFS

- Periodic [trimming](https://wiki.archlinux.org/title/ZFS#Enabling_TRIM) using systemd timer/service.
- Custom pacman [hook](https://wiki.archlinux.org/title/Pacman#Hooks) to run [`generate-zbm`](https://docs.zfsbootmenu.org/en/latest/man/generate-zbm.8.html) automatically during [kernel](https://archlinux.org/packages/?search=&q=linux-lts) and [zfs-dkms](https://aur.archlinux.org/packages?O=0&SeB=nd&K=zfs-dkms) upgrade.
- Custom pacman [hook](https://wiki.archlinux.org/title/Pacman#Hooks) to automatically snapshot root dataset before system update.

## Improvements

- Automatic installation of [paru](https://github.com/morganamilo/paru) (AUR helper).
- Implement Ansible and custom playbooks.
