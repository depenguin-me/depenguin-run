#!/usr/bin/env bash
#
# depenguinme.sh
# v0.0.1  2022-07-28  bretton depenguin.me
#  this is a proof of concept with parts to be further developed
#

# this script must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root. Recovery console should be root user"
  exit
fi

# vars, do not adjust unless you know what you're doing for this script
QEMUBASE="/tmp"
USENVME=0
#not in use
#MYPRIMARYIP=$(ip route get 1 | awk '{print $(NF-2);exit}')
MYVNC="127.0.0.1:1"
MYVGA="std"   # could be qxl but not enabled for the static-qemu binary
MYBIOS="bios-256k.bin"
MYKEYMAP="keymaps/en-us"
MYLOG="${QEMUBASE}/qemu-depenguin.log"

###
# Custom build mfsbsd file
###
MFSBSDISO="https://depenguin.me/files/mfsbsd-13.1-RELEASE-amd64.iso"
export MFSBSDISO
MFSBSDFILE=$(echo "${MFSBSDISO}"|awk -F "/" '{print $5}')
export MFSBSDFILE

###
# 2022-07-28
# due to problems compiling static qemu binary from source we'll use
# the one referenced in this post
# https://forums.freebsd.org/threads/installing-freebsd-in-hetzner.85399/post-575119
# Mirrors
# - https://support.org.ua/Soft/vKVM/orig/vkvm.tar.gz
# - https://cdn.rodney.io/content/blog/files/vkvm.tar.gz
# - https://abcvg.ovh/uploads/need/vkvm-latest.tar.gz
# + https://depenguin.me/files/vkvm.tar.gz
###
QEMUSTATICSRC="https://depenguin.me/files/vkvm.tar.gz"
export QEMUSTATICSRC
QEMUSTATICFILE=$(echo "${QEMUSTATICSRC}"|awk -F "/" '{print $5}')
export QEMUSTATICFILE
QEMUBIN="${QEMUBASE}/qemu-system-x86_64"

# change directory to /tmp to continue
cd "${QEMUBASE}" || exit

# download mfsbsd
wget -qc "${MFSBSDISO}"

# download qemu static
wget -qc "${QEMUSTATICSRC}"

if [ -f "${QEMUSTATICFILE}" ]; then
    tar -xzvf "${QEMUSTATICFILE}"
else
    echo "missing ${QEMUSTATICFILE}"
    exit
fi

# check if qemu-static file exists
echo "Checking if ${QEMUBIN} exists"
stat "${QEMUBIN}" || exit

# check if sda & sdb
checkdiskone=$(lsblk |grep sda |head -1)
notcdrom=$(lsblk |grep sdb |grep cdrom)
if [ -z "${notcdrom}" ]; then
    checkdisktwo=$(lsblk |grep sdb |head -1)
else
    checkdisktwo=""
fi

# check for nvme, hetzner specific
mycheck=$(which nvme)
if [ -n "${mycheck}" ]; then
    existsnvme=$(nvme list |grep -c "/dev/nvme")
    if [ "$existsnvme" -ge 2 ]; then
        checknvmeone=$(lsblk |grep nvme0n1 |head -1)
        checknvmetwo=$(lsblk |grep nvme1n1 |head -1)
        USENVME=1
    elif [ "$existsnvme" -eq 1 ]; then
        checknvmeone=$(lsblk |grep nvme0n1 |head -1)
        USENVME=1
    elif [ -z "$existsnvme" ]; then
        USENVME=0
    fi
fi

# start qemu-static with parameters
if [ "$USENVME" -eq 0 ]; then
    if [ -n "$checkdiskone" ] && [ -n "$checkdisktwo" ]; then
    echo ""
    echo "NOTICE: using sda and sdb"
    echo ""

    cd "${QEMUBASE}"/share/qemu || exit

    echo "Wait up to _5mins_ then choose from"
    echo ""
        echo "* Open VNC client and connect to this address: <your-server-ip>:5901 with user 'root' and password 'mfsroot'."
        echo ""
        echo "* Open SSH client and connect to this address: ssh -p 1022 root@<your-server-ip> and enter password 'mfsroot' when prompted."
        echo ""
    echo "In the BSD shell, run zfsinstall -h for further instructions to install FreeBSD-13.1"
    echo ""

        "${QEMUBIN}" \
          -net nic \
          -net user,hostfwd=tcp::1022-:22 \
          -m 1024M \
          -localtime \
          -enable-kvm \
          -cpu host \
          -M pc \
          -smp 1 \
          -bios "${MYBIOS}" \
          -vga "${MYVGA}" \
          -usbdevice tablet \
          -k "${MYKEYMAP}" \
          -cdrom /tmp/"${MFSBSDFILE}" \
          -hda /dev/sda \
          -hdb /dev/sdb \
          -boot once=d \
          -vnc "${MYVNC}" \
          -D "${MYLOG}"
    elif [ -n "$checkdiskone" ] && [ -z "$checkdisktwo" ]; then
    echo ""
    echo "NOTICE: using sda only"
    echo ""

    cd "${QEMUBASE}"/share/qemu || exit

    echo "Wait up to _5mins_ then choose from"
    echo ""
        echo "* Open VNC client and connect to this address: <your-server-ip>:5901 with user 'root' and password 'mfsroot'."
        echo ""
        echo "* Open SSH client and connect to this address: ssh -p 1022 root@<your-server-ip> and enter password 'mfsroot' when prompted."
        echo ""
    echo "In the BSD shell, run zfsinstall -h for further instructions to install FreeBSD-13.1"
    echo ""

        "${QEMUBIN}" \
          -net nic \
          -net user,hostfwd=tcp::1022-:22 \
          -m 1024M \
          -localtime \
          -enable-kvm \
          -cpu host \
          -M pc \
          -smp 1 \
          -bios "${MYBIOS}" \
          -vga "${MYVGA}" \
          -usbdevice tablet \
          -k "${MYKEYMAP}" \
          -cdrom /tmp/"${MFSBSDFILE}" \
          -hda /dev/sda \
          -boot once=d \
          -vnc "${MYVNC}" \
          -D "${MYLOG}"
   fi
elif [ "$USENVME" -eq 1 ]; then
    if [ -n "$checknvmeone" ] && [ -n "$checknvmetwo" ]; then
    echo ""
    echo "NOTICE: using nvme1 and nvme2"
    echo ""

    cd "${QEMUBASE}"/share/qemu || exit

    echo "Wait up to _5mins_ then choose from"
    echo ""
        echo "* Open VNC client and connect to this address: <your-server-ip>:5901 with user 'root' and password 'mfsroot'."
        echo ""
        echo "* Open SSH client and connect to this address: ssh -p 1022 root@<your-server-ip> and enter password 'mfsroot' when prompted."
        echo ""
    echo "In the BSD shell, run zfsinstall -h for further instructions to install FreeBSD-13.1"
    echo ""

        "${QEMUBIN}" \
          -net nic \
          -net user,hostfwd=tcp::1022-:22 \
          -m 1024M \
          -localtime \
          -enable-kvm \
          -cpu host \
          -M pc \
          -smp 1 \
          -bios "${MYBIOS}" \
          -vga "${MYVGA}" \
          -usbdevice tablet \
          -k "${MYKEYMAP}" \
          -cdrom /tmp/"${MFSBSDFILE}" \
          -hda /dev/nvme0n1 \
          -hdb /dev/nvme1n1 \
          -boot once=d \
          -vnc "${MYVNC}" \
          -D "${MYLOG}"
    elif [ -n "$checknvmeone" ] && [ -z "$checknvmetwo" ]; then
    echo ""
    echo "NOTICE: using nvme1 only"
    echo ""

    cd "${QEMUBASE}"/share/qemu || exit

    echo "Wait up to _5mins_ then choose from"
    echo ""
        echo "* Open VNC client and connect to this address: <your-server-ip>:5901 with user 'root' and password 'mfsroot'."
        echo ""
        echo "* Open SSH client and connect to this address: ssh -p 1022 root@<your-server-ip> and enter password 'mfsroot' when prompted."
        echo ""
    echo "In the BSD shell, run zfsinstall -h for further instructions to install FreeBSD-13.1"
    echo ""

        "${QEMUBIN}" \
          -net nic \
          -net user,hostfwd=tcp::1022-:22 \
          -m 1024M \
          -localtime \
          -enable-kvm \
          -cpu host \
          -M pc \
          -smp 1 \
          -bios "${MYBIOS}" \
          -vga "${MYVGA}" \
          -usbdevice tablet \
          -k "${MYKEYMAP}" \
          -cdrom /tmp/"${MFSBSDFILE}" \
          -hda /dev/nvme0n1 \
          -boot once=d \
          -vnc "${MYVNC}" \
          -D "${MYLOG}"
   fi
fi
