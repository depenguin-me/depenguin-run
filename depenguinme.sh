#!/usr/bin/env bash
#
# depenguinme.sh
# v0.0.1  2022-07-28  bretton depenguin.me
#  this is a proof of concept with parts to be further developed
#
# v0.0.2  2022-07-30  bretton depenguin.me
#  retrieve and insert ssh key
#
# v0.0.3  2022-07-31  bretton depenguin.me
#  use uefi.bin as bios to enable support of >2TB disks
#  use hardened mfsbsd image and copy in imported keys

# this script must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root. Recovery console should be root user"
  exit
fi

usage() { echo "Usage: $0 [-k /path/to/authorized_keys] [-n http://host.domain/keys.pub]" 1>&2; exit 1; }

while getopts ":k:n:" flags; do
    case "${flags}" in
        k)
            AUTHKEYURL=""
            AUTHKEYFILE=$(realpath "${OPTARG}")
            ;;
        n)
            AUTHKEYURL="${OPTARG}"
            AUTHKEYFILE=""
            ;;
        *)
            usage
            ;;
    esac
done
shift "$((OPTIND-1))"

#if [ -z "${k}" ] || [ -z "${n}" ]; then
#    usage
#fi

# install required packages
apt-get update
apt-get install -y mkisofs
###
# disabled for now as not sure about bios stuff, using statically-compiled qemu with copied-in uefi bios instead
# apt-get install -y qemu
###

# vars, do not adjust unless you know what you're doing for this script
QEMUBASE="/tmp"
USENVME=0
MYPRIMARYIP=$(ip route get 1 | awk '{print $(NF-2);exit}')
MYVNC="127.0.0.1:1"
MYVGA="std"   # could be qxl but not enabled for the static-qemu binary
MYBIOS="uefi.bin"  # default is bios-256k.bin, uefi.bin is downloaded separately
MYKEYMAP="keymaps/en-us"
MYLOG="${QEMUBASE}/qemu-depenguin.log"
MYISOAUTH="myiso.iso"

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
#
# For bios supporting >2TB disks
# - https://support.org.ua/Soft/vKVM/orig/uefi.tar.gz
# + https://depenguin.me/files/vkvm.tar.gz
###

# static qemu files
QEMUSTATICSRC="https://depenguin.me/files/vkvm.tar.gz"
export QEMUSTATICSRC
QEMUSTATICFILE=$(echo "${QEMUSTATICSRC}"|awk -F "/" '{print $5}')
export QEMUSTATICFILE
QEMUBIN="${QEMUBASE}/qemu-system-x86_64"
QEMUALTBIOSSRC="https://depenguin.me/files/uefi.tar.gz"
export QEMUALTBIOSSRC
QEMUALTBIOSFILE=$(echo "${QEMUALTBIOSSRC}"|awk -F "/" '{print $5}')
export QEMUALTBIOSFILE

# change directory to /tmp to continue
cd "${QEMUBASE}" || exit

# setup or retrieve authorised keys
if [ -z "${AUTHKEYURL}" ] && [ -z "${AUTHKEYFILE}" ]; then
    echo "No keys selected, you should get the usage message instead of this error"
    exit 1
elif [ -z "${AUTHKEYURL}" ] && [ -n "${AUTHKEYFILE}" ]; then
    # if no url, yet with file link, copy file to holding file
    cp -f "${AUTHKEYFILE}" COPYKEY.pub
elif [ -n "${AUTHKEYURL}" ] && [ -z "${AUTHKEYFILE}" ]; then
    # if url, but no file link, retrieve from url, to holding file
    wget -qc "${AUTHKEYURL}" -O COPYKEY.pub
elif [ -n "${AUTHKEYURL}" ] && [ -n "${AUTHKEYFILE}" ]; then
    # if url and file link, combine both and upload
    wget "${AUTHKEYURL}" -O COPYKEY.pub
    cat "${AUTHKEYFILE}" >> COPYKEY.pub
fi

# temp solution to make iso with authorized_keys
mkdir -p "${QEMUBASE}"/myiso
if [ -f "${QEMUBASE}"/COPYKEY.pub ] && [ -d "${QEMUBASE}"/myiso ]; then
    cp -f COPYKEY.pub "${QEMUBASE}"/myiso/mfsbsd_authorized_keys
else
    echo "Error copying COPYKEY.pub to myiso/mfsbsd_authorized_keys"
    exit 1
fi

# create iso image with the public keys
if [ -f "${QEMUBASE}"/myiso/mfsbsd_authorized_keys ]; then
    /usr/bin/genisoimage -v -J -r -V MFSBSD_AUTHKEYS \
      -o "${QEMUBASE}"/"${MYISOAUTH}" \
      "${QEMUBASE}"/myiso/mfsbsd_authorized_keys
else
    echo "Missing myiso/mfsbsd_authorized_keys"
    exit 1
fi

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

# download UEFI bios
wget -qc "${QEMUALTBIOSSRC}"

# extract the alternate uefi bios
if [ -f "${QEMUALTBIOSFILE}" ]; then
    cd share/qemu || exit
    tar -xzf "${QEMUBASE}"/"${QEMUALTBIOSFILE}"
    cd "${QEMUBASE}" || exit
else
    echo "Missing uefi.tar.gz"
    exit 1
fi

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
          -cdrom "${QEMUBASE}/${MFSBSDFILE}" \
          -hda /dev/sda \
          -hdb /dev/sdb \
          -drive file="${QEMUBASE}/${MYISOAUTH}",media=cdrom \
          -boot once=d \
          -vnc "${MYVNC}" \
          -D "${MYLOG}"\
          -daemonize
    elif [ -n "$checkdiskone" ] && [ -z "$checkdisktwo" ]; then
    echo ""
    echo "NOTICE: using sda only"
    echo ""

    cd "${QEMUBASE}"/share/qemu || exit

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
          -cdrom "${QEMUBASE}/${MFSBSDFILE}" \
          -hda /dev/sda \
          -drive file="${QEMUBASE}/${MYISOAUTH}",media=cdrom \
          -boot once=d \
          -vnc "${MYVNC}" \
          -D "${MYLOG}"\
          -daemonize
   fi
elif [ "$USENVME" -eq 1 ]; then
    if [ -n "$checknvmeone" ] && [ -n "$checknvmetwo" ]; then
    echo ""
    echo "NOTICE: using nvme1 and nvme2"
    echo ""

    cd "${QEMUBASE}"/share/qemu || exit

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
          -cdrom "${QEMUBASE}/${MFSBSDFILE}" \
          -hda /dev/nvme0n1 \
          -hdb /dev/nvme1n1 \
          -drive file="${QEMUBASE}/${MYISOAUTH}",media=cdrom \
          -boot once=d \
          -vnc "${MYVNC}" \
          -D "${MYLOG}" \
          -daemonize
    elif [ -n "$checknvmeone" ] && [ -z "$checknvmetwo" ]; then
    echo ""
    echo "NOTICE: using nvme1 only"
    echo ""

    cd "${QEMUBASE}"/share/qemu || exit

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
          -cdrom "${QEMUBASE}/${MFSBSDFILE}" \
          -hda /dev/nvme0n1 \
          -drive file="${QEMUBASE}/${MYISOAUTH}",media=cdrom \
          -boot once=d \
          -vnc "${MYVNC}" \
          -D "${MYLOG}" \
          -daemonize
   fi
fi

# let the system boot, yes we need this much time
# at least 2 minutes with rc.local adjustments
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Please wait, booting..."
sleep 10
echo "Almost ready..."

# scan for keys
ssh-keyscan -p 1022 -T 30 127.0.0.1

# we should be able to ssh without a password now
echo "The system should ready to access with automatic login from a host with the associated private key!"
echo ""
echo "  ssh -p 1022 root@${MYPRIMARYIP}"
echo ""
echo "If you have difficulty connecting dueh ssh key exchange error then WAIT 2 MINUTES and try again. SSH needs to come up correctly first."
echo ""
echo "Run 'zfsinstall -h' for install options, or provision with ansible scripts that cover installation."
echo ""
echo "--- DEPENGUINME SCRIPT COMPLETE ---"
