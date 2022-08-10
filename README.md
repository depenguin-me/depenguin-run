# depenguin.me mfsbsd-13.1-script
depenguin.me installer script for mfsBSD image to install FreeBSD 13.1 (with zfs-on-root) using qemu

https://depenguin.me

## Install FreeBSD-13.1 on a dedicated server from a Linux rescue environment

### 1. Boot into rescue console

You must be logged in as root. Prepare file path or URL of SSH public key.

### 2. Download and run installer script
Boot your server into rescue mode, then download and run the custom [mfsBSD-based installer](https://github.com/depenguin-me/depenguin-installer) for FreeBSD-13.1, with root-on-ZFS.

    wget https://depenguin.me/run.sh && chmod +x run.sh && \
      ./run.sh [ -d ] [ -r ram ] [ -m <url of own mfsbsd image> ] authorized_keys ...

The "-d" parameter will send the qemu process to the background.

The "-r" parameter allows setting qemu memory for low memory systems, default is `8G` for `8GiB`.

The "-m" parameter allows using a custom mfsbsd ISO.

You must specify at least one authorized_keys source, both URLs and local files are supported.

    note: run.sh on the website is a symlink to the depenguinme.sh script

Example invocations:

    ./run.sh https://example.org/mypubkey
    ./run.sh /tmp/my_public_key

### 3. Connect via SSH
Wait until the script reports SSH to be available (takes a few minutes), then connect:

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

### 5. Complete post-install actions
Chroot to installed system.

    chroot /mnt

Create a group and username, set ssh keys.

    pw groupadd YOUR-USER
    pw useradd -m -n YOUR-USER -g YOUR-USER -G wheel -h - -c "your name"
    cd /home/YOUR-USER
    mkdir .ssh && chown YOUR-USER .ssh && chmod 700 .ssh
    cd .ssh
    vi authorized_keys    #paste in SSH pubkeys
    chown YOUR-USER authorized_keys && chmod 600 authorized_keys
    cd

Configure `/etc/rc.conf` for hostname, networking, SSH server.

A configuration suitable for Hetzner is listed below. Adapt to your settings:

    vi /etc/rc.conf
    
    hostname="yourhostname"
    ifconfig_igb0_name="untrusted"
    ifconfig_untrusted="up"
    ifconfig_untrusted_ipv6="up"
    ifconfig_untrusted_aliases="inet 1.2.3.4/32 inet6 1234::123:123:1234::2/64"
    ipv6_activate_all_interfaces="YES"
    static_routes="gateway default"
    route_gateway="-host 6.7.8.9 -interface untrusted"
    route_default="default 6.7.8.9"
    ipv6_defaultrouter="fe80::1%untrusted"
    sshd_enable="YES"
    zfs_enable="YES"

Configure `/etc/resolv.conf` for DNS servers. Hetzner's are used in this example:

    vi /etc/resolv.conf
    
    search YOURDOMAIN
    nameserver 185.12.64.1
    nameserver 185.12.64.2
    nameserver 2a01:4ff:ff00::add:1
    nameserver 2a01:4ff:ff00::add:2

### 6. Reboot
Exit the chroot environment with `ctrl-d`. 

Switch to the rescue console session and press `ctrl-c` to end qemu. Then type `reboot`. 

### 7. Connect to your new server
After a few minutes to boot up, connect to your server via SSH:

    ssh YOUR-USER@ip-address

Check DNS is available and then perform initial system configuration such as:

    freebsd-update fetch
    freebsd-update install

End