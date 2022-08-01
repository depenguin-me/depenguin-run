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
#
# v0.0.4  2022-08-01  grembo depenguin.me
#  use more official packages
#  add options
#  some cleanup

# this script must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root. Recovery console should be root user"
  exit
fi

set -eo pipefail

exit_error() {
	echo "$*" 1>&2
	exit 1;
}

usage() {
	cat <<-EOF
	Usage: $(basename "${BASH_SOURCE[0]}") [-hd] [-k authorized_keys] [-n URL] [-m url]

	  -h Show help
	  -d daemonize
	  -k /path/to/authorized_keys : Path to authorized_keys file
	  -n : https://host.domain/authorized_keys : URL to authorized key file
	  -m : URL of mfsbsd image (defaults to image on https://dependuin.me)

	  At least one of -k and -n is mandatory.
	EOF
}

AUTHKEYURL=
AUTHKEYFILE=
DAEMONIZE=NO
MFSBSDISO="https://depenguin.me/files/mfsbsd-13.1-RELEASE-amd64.iso"

while getopts "hdk:m:n:" flags; do
	case "${flags}" in
	h)
		usage
		exit 0
		;;
	d)
		DAEMONIZE=YES
		;;
	k)
		AUTHKEYURL=""
		AUTHKEYFILE=$(realpath "${OPTARG}")
		;;

	m)
		MFSBSDISO="${OPTARG}"
		;;
	n)
		AUTHKEYURL=${OPTARG}
		AUTHKEYFILE=""
		;;
	*)
		exit_error "$(usage)"
		;;
	esac
done
shift "$((OPTIND-1))"

if [ -z "${AUTHKEYFILE}" ] && [ -z "${AUTHKEYURL}" ]; then
	exit_error "$(usage)"
fi

# install required packages
apt-get update
apt-get install -y mkisofs
apt-get install -y qemu

# vars, do not adjust unless you know what you're doing for this script
QEMUBASE="/tmp/depenguinme"
USENVME=0
MYPRIMARYIP=$(ip route get 1 | awk '{print $(NF-2);exit}')
MYVNC="127.0.0.1:1"
MYVGA="std"   # could be qxl but not enabled for the static-qemu binary
MYBIOS="/usr/share/ovmf/OVMF.fd"
MYKEYMAP="en-us"
MYLOG="${QEMUBASE}/qemu-depenguin.log"
MYISOAUTH="${QEMUBASE}/myiso.iso"
MFSBSDFILE="${QEMUBASE}/$(echo "$MFSBSDISO" | sha256sum | awk '{print $1}').iso"

mkdir -p "$QEMUBASE"

###
# Custom build mfsbsd file
###
export MFSBSDFILE  # XXX: why export?
export MFSBSDISO  # XXX: why export?

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

QEMUBIN=$(which qemu-system-x86_64)

# change directory to /tmp to continue
cd "${QEMUBASE}" || exit_error "Could not cd to $QEMUBASE"

# setup or retrieve authorised keys
: >COPYKEY.pub

if [ -n "${AUTHKEYFILE}" ]; then
	cat "${AUTHKEYFILE}" >>COPYKEY.pub
fi

if [ -n "${AUTHKEYURL}" ]; then
	wget -qO - "${AUTHKEYURL}" >>COPYKEY.pub
fi

[ -s COPYKEY.pub ] || exit_error "Authorized key sources are empty"

# temp solution to make iso with authorized_keys
mkdir -p "${QEMUBASE}"/myiso
if [ -f "${QEMUBASE}"/COPYKEY.pub ] && [ -d "${QEMUBASE}"/myiso ]; then
	cp -f COPYKEY.pub "${QEMUBASE}"/myiso/mfsbsd_authorized_keys
else
	exit_error "Error copying COPYKEY.pub to myiso/mfsbsd_authorized_keys"
fi

# create iso image with the public keys
if [ -f "${QEMUBASE}"/myiso/mfsbsd_authorized_keys ]; then
	/usr/bin/genisoimage -v -J -r -V MFSBSD_AUTHKEYS \
	  -o "${MYISOAUTH}" "${QEMUBASE}"/myiso/mfsbsd_authorized_keys
else
	exit_error "Missing myiso/mfsbsd_authorized_keys"
fi

# download mfsbsd image
wget -qc -O "${MFSBSDFILE}" "${MFSBSDISO}" || exit_error "Could not download mfsbsd image"

# check if qemu binay exists
echo "Checking if ${QEMUBIN} exists"
stat "${QEMUBIN}" || exit_error "Couldn't find qemu binary $QEMUBIN"

# check if sda & sdb
echo "Searching sd[ab]"
set +e
checkdiskone=$(lsblk |grep sda |head -1)
notcdrom=$(lsblk |grep sdb |grep cdrom)
if [ -z "${notcdrom}" ]; then
	checkdisktwo=$(lsblk |grep sdb |head -1)
else
	checkdisktwo=""
fi
set -e

# check for nvme, hetzner specific
set +e
echo "Searching nvme"
mycheck=$(which nvme)
if [ -n "${mycheck}" ]; then
	existsnvme=$(nvme list | grep -c "/dev/nvme")
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
set -e

# basic arguments to qemu
qemu_args=(\
  -net nic \
  -net "user,hostfwd=tcp::1022-:22" \
  -m 1024M \
  -rtc base=localtime \
  -enable-kvm \
  -cpu host \
  -M pc \
  -smp 1 \
  -bios "${MYBIOS}" \
  -vga "${MYVGA}" \
  -k "${MYKEYMAP}" \
  -cdrom "${MFSBSDFILE}" \
  -drive file="${MYISOAUTH},media=cdrom" \
  -boot once=d \
  -vnc "${MYVNC}" \
  -D "${MYLOG}"\
)

if [ "$DAEMONIZE" = "YES" ]; then
	qemu_args+=(-daemonize)
fi

disks=()

# start qemu-static with parameters
if [ "$USENVME" -eq 0 ]; then
	if [ -n "$checkdiskone" ] && [ -n "$checkdisktwo" ]; then
		printf "\nNOTICE: using sda and sdb\n\n"
		disks=(
		  -hda /dev/sda \
		  -hdb /dev/sdb \
		)
	elif [ -n "$checkdiskone" ] && [ -z "$checkdisktwo" ]; then
		printf "\nNOTICE: using sda only\n\n"
		disks=(
		  -hda /dev/sda \
		)
	fi
elif [ "$USENVME" -eq 1 ]; then
	if [ -n "$checknvmeone" ] && [ -n "$checknvmetwo" ]; then
		printf "\nNOTICE: using nvme0 and nvme1\n\n"
		disks=(
		  -hda /dev/nvme0n1 \
		  -hdb /dev/nvme1n1 \
		)
	elif [ -n "$checknvmeone" ] && [ -z "$checknvmetwo" ]; then
		printf "\nNOTICE: using nvme0 only\n\n"
		disks=(
		  -hda /dev/nvme0n1 \
		)
	fi
fi

if [ ${#disks[@]} -eq 0 ]; then
	exit_error "Could not find any disks"
fi


(
	set +e
	sleep 2

	# let the system boot, yes we need this much time
	# at least 2 minutes with rc.local adjustments
	for c in {0..5}; do
		echo "Please wait, booting... $((30 - 5*c))s"
		sleep 5
	done
	echo "Waiting for sshd to become available..."

	# scan for keys
	while ! ssh-keyscan -p 1022 -T 5 127.0.0.1 2>/dev/null; do
		echo "Waiting for sshd to become available..."
		sleep 5;
	done

	# we should be able to ssh without a password now
	cat <<-EOF
	The system should ready to access with automatic login from a host with the associated private key!

	  ssh -p 1022 mfsbsd@${MYPRIMARYIP}

	If you have difficulty connecting dueh ssh key exchange error then WAIT 2 MINUTES and try again.
	SSH needs to come up correctly first.

	Run 'zfsinstall -h' for install options, or provision with ansible scripts that cover installation.

	EOF

	if [ "$DAEMONIZE" = "YES" ]; then
		echo "--- DEPENGUINME SCRIPT COMPLETE ---"
	else
		echo "Press CTRL-C to exit qemu"
	fi
)&

keyscan_pid=$!
function finish {
	set +e
	kill $keyscan_pid >/dev/null 2>&1
}
trap finish EXIT

echo "Starting qemu..."
${QEMUBIN} "${qemu_args[@]}"

wait $keyscan_pid
