# Supported Servers
This is a list of confirmed working, or not working, dedicated server systems.

## WORKING

### Installer loaded, drives accessible
* Hetzner PX62-NVMe (v0.0.4, 2022-08-01)

### Full installation success
* Hetzner AX41 (v0.0.6, 2022-08-10)
* Hetzner AX42 (v0.0.19, 2025-07-10)
* Hetzner AX101 (v0.0.10, 2023-01-27)
* Hetzner AX162-R (v0.0.16, 2024-07-12)
* Hetzner AX102 (v0.0.19, 2025-04-10)
* OVH/Kimsufi KS-GAME-1 (v0.0.9, 2022-08-13)

### Full installation success (with extra steps)
* Hetzner AX41-NVMe (v 0.0.10, 2023-04-06, change interface in /etc/rc.conf) [Issue-10](https://github.com/depenguin-me/depenguin-run/issues/10#issuecomment-1225893163)
* Hetzner AX51-NVMe (v.0.0.10, 2022-08-24, ipv6-only) [Issue-10](https://github.com/depenguin-me/depenguin-run/issues/10)
* Hetzner AX52 (v0.0.16, 2024-07-12, change NIC in rc.conf from em0 to igc0) [Issue-83](https://github.com/depenguin-me/depenguin-run/issues/83)
* Hetzner AX101-NVMe (v0.0.15, 2024-02-13, change NIC in rc.conf from em0 to igb0)
* Hetzner EX43-NVMe (v.0.0.10, 2022-10-16, disable serial ports) [Issue-57](https://github.com/depenguin-me/depenguin-run/issues/57)
* Hetzner EX44-NVMe (v.0.0.15, 2024-03-19, network driver from ports/pkgs) [Issue-79](https://github.com/depenguin-me/depenguin-run/issues/79)
* Hetzner SB Intel Xeon E3-1275V6 (v 0.0.14, 2023-12-21, four disks used for mirror array)
* Hetzner SB Intel Xeon E5-1650V3 (v 0.0.14, 2024-01-02, two HDD, two SSD)
* online.net Start-3-L (v0.0.15, 2024-02-13, change NIC in rc.conf from em0 to igb0)
* Xneelo Truserv Intel Xeon E3-1230V6 (v 0.0.14, 2024-01-04, four disks, local ipv6) [Issue-12](https://github.com/depenguin-me/depenguin-run/issues/12#issuecomment-1877658404)
* OVH/Kimsufi KS-16 (v0.0.16, 2024-03-21, three disks, use raidz1 in unattended installer) [Issue-41](https://github.com/depenguin-me/depenguin-run/issues/41#issuecomment-2011833543)
* OVH Advance-2 Gen 2 (v0.0.16, 2024-04-26, four disks in raidz2, changed NIC in rc.conf from em0 to ixl0)

## NOT WORKING
* add details here
