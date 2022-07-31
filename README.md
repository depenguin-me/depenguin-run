# mfsbsd-13.1-script
Installer script for mfsBSD image to install FreeBSD 13.1 with zfs-on-root using a statically compiled qemu binary

https://depenguin.me

## Install FreeBSD-13.1 on your dedicated server from within a Linux rescue environment

### 1. Download and run installer script
Boot your server into rescue mode, then download and run the custom [mfsBSD-based installer](https://github.com/depenguin-me/depenguin-installer) for FreeBSD-13.1 with root-on-ZFS.
```
wget https://depenguin.me/run.sh && chmod +x run.sh && ./run.sh [ -k /path/to/authorized_keys ] [ -n "http://host.dom/keys.pub" ]
```

Supporting files will be downloaded to /tmp. You must be root.

You can pass in one or both of the parameters "-k" and "-n" but it will exit if none listed. You must include a pubkey to get access to the installer.

```
note: run.sh on the website is a symlink to the depenguinme.sh script
```

### 2. Connect via SSH
Wait up to 5 minutes and connect via SSH:
```
ssh -p 1022 mfsbsd@your-host-ip
```

This is a secured-by-ssh-key installer. The username is mfsbsd and you can sudo su - to root without a password. You cannot login as root.

If trouble with ssh connection, wait 2 minutes and try again.

### 3. Install FreeBSD-13.1
The environment includes base.txz and kernel.txz needed for FreeBSD install.

From within the environment you can run
```
/root/bin/zfsinstall [-h] -d geom_provider [-d geom_provider ...] [ -u dist_url ] [-r mirror|raidz[1|2|3]] [-m mount_point] [-p zfs_pool_name] [-s swap_partition_size] [-z zfs_partition_size] [-c] [-C] [-l] [-4] [-A]
```

#### Examples

##### Single disk ada0
```
zfsinstall -d ada0 -s 4G -A -4 -c -p zroot
```

##### Mirror disks ada0 and ada1
```
zfsinstall -d ada0 -d ada1 -r mirror -s 4G -A -4 -c -p zroot
```