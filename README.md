# depenguin.me mfsbsd-script
depenguin.me installer script for mfsBSD image to install FreeBSD 15.0 (traditional install not pkgbase, with zfs-on-root) using qemu

https://depenguin.me

## Install FreeBSD-15.0 traditional install on a dedicated server from a Linux rescue environment

### 1. Boot into rescue console

You must be logged in as root. Prepare file path or URL of SSH public key.

### 2. Download and run installer script

Boot your server into rescue mode, then download and run the custom [mfsBSD-based installer](https://github.com/depenguin-me/depenguin-builder) for FreeBSD-15.0, traditional install (non-pkgbase) with root-on-ZFS.

    wget https://depenguin.me/run.sh && chmod +x run.sh && \
      ./run.sh [ -d ] [ -f ] [ -r ram ] [ -m <url of own mfsbsd image> ] authorized_keys ...

The "-d" parameter will send the qemu process to the background.

The "-f" parameter will disable QEMU KVM acceleration for hosts where this is a problem, such as Hetzner EX44.

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

### 4. [Optional] Disable serial ports

FreeBSD hangs on some ASUS boards on boot if serial ports are enabled (see issue [10](https://github.com/depenguin-me/depenguin-run/issues/10)). To work around this problem, you can either disable serial ports in the BIOS or, more easily, disable them in /boot/loader.conf:

```
hint.uart.0.disabled="1"
hint.uart.1.disabled="1"
```

### 5. Install with unattended bsdinstall script, or use the manual `bsdinstall` process

We recommend the unattended process for most setups.

### 5a. Install FreeBSD-15.0 using unattended bsdinstall

Copy the file `depenguin_settings.sh.sample` to `depenguin_settings.sh` and edit for your server's details.

    cp depenguin_settings.sh.sample depenguin_settings.sh
    nano depenguin_settings.sh

Configure your specific settings in applicable fields. Take note that Hetzner DNS is used in this example, you might need other servers listed for different hosts.

    conf_hostname="depenguintest"
    conf_interface="CHANGEME-igb0-or-em0-etc"
    conf_ipv4="1.2.3.4"
    conf_ipv6="abcd:xxxx:yyyy:zzzz::p"
    conf_gateway="6.7.8.9"
    conf_nameserveripv4one="185.12.64.1"
    conf_nameserveripv4two="185.12.64.2"
    conf_nameserveripv6one="2a01:4ff:ff00::add:1"
    conf_nameserveripv6two="2a01:4ff:ff00::add:2"
    conf_username="myusername"
    conf_pubkeyurl="http://url.host/keys.txt"
    conf_disks="ada0 ada1" # or ada0 | or ada0 ada1 ada2 ada3 | or nvme0n1 | or nvme0n1 nvme1n1
    conf_disktype="mirror" # or stripe for single disk, or raid10, or raidz1, for four disk systems
    run_installer="1" # set to 1 to enable installer
    tweak_ax102="0" # only enable for Hetzner AX102 servers

If installing on a Hetzner AX102 server, configure `tweak_ax102=1` to perform a additional steps to allow successful booting after installation (see issue [100](https://github.com/depenguin-me/depenguin-run/issues/100)).

Then run the unattended installer script as follows. 

    ./depenguin_bsdinstall.sh 

This script will update the `INSTALLERCONFIG` file used by `bsdinstall` with the values set above.

When complete the mfsbsd VM will shutdown automatically. Proceed to step 6. 

#### 5b. Install with `bsdinstall`

This is the manual approach, which requires choosing options from menus. You want this if you have custom needs, such as encrypted swap or partitions.

Run `bsdinstall -h` to see options. 

Start install process by running `bsdinstall`.

Before reboot, take note of the following manual network configuration required for Hetzner servers.

The "canonical" setup we suggest using involves renaming the interface to `untrusted` and configuring `/etc/rc.conf` as follows, replacing IP addresses with your specific values (see issue [94](https://github.com/depenguin-me/depenguin-run/issues/94)):

    ifconfig_em0_name="untrusted"
    ifconfig_untrusted="up"
    ifconfig_untrusted_ipv6="up"
    ifconfig_untrusted_aliases="inet 1.2.3.4/32 inet6 2a01:444:111:222::2/64"
    static_routes="gateway default"
    route_gateway="-host 1.2.3.1 -interface untrusted"
    route_default="default 1.2.3.1"
    ipv6_defaultrouter="fe80::1%untrusted"

You may need to manually shutdown the `mfsbsd` instance. Proceed to step 6.

### 6. Reboot

Switch to the rescue console session.

Qemu will exit automatically after a few seconds if you used the unattended install process. You can type `reboot` to exit the rescue console and wait for your installed system to boot.

Alternatively, press `ctrl-c` to end qemu. Then type `reboot`.

### 7. Connect to your new server

After a few minutes to boot up, connect to your server via SSH:

    ssh YOUR-USER@ip-address

> Make sure to remove any rescue/mfsbsd ssh keys stored in `.ssh/known_hosts` before connecting.

Check DNS is available and then perform initial system configuration such as:

    freebsd-update --not-running-from-cron fetch
    freebsd-update --not-running-from-cron install

End

## Legacy: Install an older FreeBSD on a dedicated server from a Linux rescue environment

You can pass in the `-m <url of own mfsbsd image>` using one of the following URLs to install a legacy version:

* https://depenguin.me/files/mfsbsd-13.1-RELEASE-amd64.iso
* https://depenguin.me/files/mfsbsd-13.2-RELEASE-amd64.iso
* https://depenguin.me/files/mfsbsd-13.4-RELEASE-amd64.iso
* https://depenguin.me/files/mfsbsd-13.5-RELEASE-amd64.iso
* https://depenguin.me/files/mfsbsd-14.0-RELEASE-amd64.iso
* https://depenguin.me/files/mfsbsd-14.1-RELEASE-amd64.iso
* https://depenguin.me/files/mfsbsd-14.2-RELEASE-amd64.iso
* https://depenguin.me/files/mfsbsd-14.3-RELEASE-amd64.iso
* https://depenguin.me/files/mfsbsd-15.0-RELEASE-amd64.iso
