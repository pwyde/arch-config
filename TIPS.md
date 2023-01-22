# Create Snapshot
Internal snapshots with `.qcow2` files is not possible when running VMs with [UEFI support](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface#OVMF_for_virtual_machines). Using external snapshots with [libvirt](https://wiki.archlinux.org/title/Libvirt) solves this issue. This method takes a dump of the RAM and then keep writing all subsequent writes to an external `.qcow2` file.

Create an external snapshot with command below.
```
sudo virsh snapshot-create-as --domain <VM name> --name state1 --memspec file=/var/lib/libvirt/images/<VM name>_state1.qcow2,snapshot=external --atomic
```

# Restore Snapshot
Restore external snapshot with command below.
```
sudo virsh restore --file /var/lib/libvirt/images/<VM name>_state1.qcow2
```

# Delete Snapshot
Delete external snapshot including the `.qcow2` file with the commands below..
```
sudo virsh snapshot-delete --domain <VM name> --snapshotname state1
sudo rm /var/lib/libvirt/images/<VM name>_state1.qcow2
```