# depenguin.me mfsbsd-13.1-script
depenguin.me installer script for mfsBSD image to install FreeBSD 13.1 (with zfs-on-root) using qemu

https://depenguin.me

## Install FreeBSD-13.1 on a dedicated server from a Linux rescue environment

### 1. Boot into rescue console

You must be logged in as root. Prepare file path or URL of SSH public key.

### 2. Download and run installer script
Boot your server into rescue mode, then download and run the custom [mfsBSD-based installer](https://github.com/depenguin-me/depenguin-installer) for FreeBSD-13.1, with root-on-ZFS.

    wget https://depenguin.me/run.sh && chmod +x run.sh && \
      ./run.sh [-d] [-m <url of own mfsbsd image> ] authorized_keys ...

The "-d" parameter will send the qemu process to the background.

You must specify at least one authorized_keys source, both URLs and local files are supported.

    note: run.sh on the website is a symlink to the depenguinme.sh script

Example invocations:

    ./run.sh https://example.org/mypubkey
    ./run.sh /tmp/my_public_key

### 3. Connect via SSH
Wait up to 5 minutes and connect via SSH:

    ssh -i /path/to/privkey -p 1022 mfsbsd@your-host-ip

Once logged in, you can `sudo su -` to root without a password. You cannot login as root.

If you have trouble with the ssh connection, wait 2 minutes and try again.

### 4. Install FreeBSD-13.1
To install FreeBSD-13.1 run the ```zfsinstall``` program with configuration parameters

    /root/bin/zfsinstall [-h] -d geom_provider [-d geom_provider ...] [ -u dist_url ] [-r mirror|raidz[1|2|3]] [-m mount_point] [-p zfs_pool_name] [-s swap_partition_size] [-z zfs_partition_size] [-c] [-C] [-l] [-4] [-A]

#### Examples

##### Single disk ada0

    zfsinstall -d ada0 -s 4G -A -4 -c -p zroot

##### Mirror disks ada0 and ada1

    zfsinstall -d ada0 -d ada1 -r mirror -s 4G -A -4 -c -p zroot
