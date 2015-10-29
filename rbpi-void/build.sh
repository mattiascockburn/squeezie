#!/bin/bash
set -u
set -e
set -o pipefail
cat <<EOF
This script makes a few assumptions:

  - you have enabled binfmt support for arm
	- you have installed qemu-user-static
	- the script needs kpartx in order to split the loopfs
	- it uses sfdisk to partition the image file

I am on Arch and just use the binaries provided by debian:
https://packages.debian.org/sid/qemu-user-static

This script is based on instructions found at
https://github.com/voidlinux/documentation/wiki/Raspberry-Pi#rootfs-install
EOF

set +e
error=0
for bin in mkfs.vfat mkfs.ext4 mkfs.f2fs tar parted dd kpartx losetup;do
  if ! which $bin &>/dev/null; then
    echo $bin not found in PATH. Please make this binary available
    error=1
  fi
done

[[ $error -eq 1 ]] && {
  echo Essential binaries not found. Exiting.
  exit 1
}
set -e

# The rootfs to download and use
VOIDURL=http://repo.voidlinux.eu/live/current
VOIDIMAGE=void-rpi-rootfs-20150713.tar.xz

SQUEEZEURL='http://squeezelite-downloads.googlecode.com/git'
SQUEEZE='squeezelite-armv6hf'

# Qemu Static stuff
QEMU=/usr/local/bin/qemu-arm-static
# squeezie specific kernel commandline for the resulting image
KCMDLINE='wireless=0 squeezie-name=testing squeezie-master=http://squeeze.foo.bar:5555'

# temp files like image download and squeezelite binary
BUILD=$(pwd)/build

BUILDDIR=$(mktemp -d /tmp/squeezie-build-XXX)


IMAGENAME="squeezie-raspberry-$(date +%Y%m%d).img"

IMAGESIZE='800M'

echo Creating sparse image $IMAGENAME in $BUILDDIR
mkdir -pv ${BUILDDIR}/{out,mnt} ${BUILD}
IPATH="${BUILDDIR}/out/${IMAGENAME}"
MNT="${BUILDDIR}/mnt"
dd if=/dev/zero of=${IPATH} bs=1 count=0 seek=$IMAGESIZE

#parted /dev/mmcblk0 <- change this to match your SD card
#
## Create the FAT partition of 256MB and make it bootable
#(parted) mktable msdos
#(parted) mkpart primary fat32 2048s 256MB
#(parted) toggle 1 boot
#
## Create the rootfs partition until end of device
#(parted) mkpart primary ext4 256MB -1
#(parted) quit

echo Associating loop file with image
LOOP=$(sudo losetup -f --show "$IPATH")
LNAME=$(echo $LOOP | sed -e 's|^/dev/||g')

ped() {
	sudo parted -s -a optimal $LOOP -- $@
}

echo Downloading Void Linux image to ${BUILD}/${VOIDIMAGE}
wget -c "${VOIDURL}/${VOIDIMAGE}" -O ${BUILD}/${VOIDIMAGE}

echo Downloading squeezelite static
wget -c "${SQUEEZEURL}/${SQUEEZE}" -O "${BUILD}/${SQUEEZE}"

echo Creating partition table
ped 'mktable msdos'
ped 'mkpart primary fat32 2048s 100MB'
ped 'toggle 1 boot'
ped 'mkpart primary ext4 100MB -1'

sudo kpartx -avs ${LOOP}

echo Creating filesystems

ROOTPART=/dev/mapper/${LNAME}p2
BOOTPART=/dev/mapper/${LNAME}p1
sudo mkfs.vfat -F32 $BOOTPART
sudo mkfs.f2fs $ROOTPART

echo Mounting image at $MNT
sudo mount "$ROOTPART" "${MNT}"
sudo mkdir "${MNT}/boot"
sudo mount "$BOOTPART" "${MNT}/boot"

echo Extracting ${VOIDIMAGE}
sudo tar xfJp ${BUILD}/${VOIDIMAGE} -C "${MNT}"
sudo sync


echo Setting up chroot

sudo mkdir -p ${MNT}/var/cache/xbps
sudo mount tmpfs -t tmpfs -o size=1024M ${MNT}/var/cache/xbps
# now actually do some work
sudo cp $QEMU ${MNT}/usr/local/bin
for a in sys dev proc;do
	sudo mount --bind /$a ${MNT}/$a
done
sudo cp /etc/resolv.conf ${MNT}/etc/
chmod +x ${BUILD}/${SQUEEZE}
sudo cp ${BUILD}/${SQUEEZE} ${MNT}/usr/local/bin/squeezelite
set +e
sudo cp image-bootstrap.sh ${MNT}/
sudo cp cmdline.txt ${MNT}/boot/
sudo cp rc.conf ${MNT}/etc/
#sudo chroot ${MNT} /bin/bash
sudo chroot ${MNT} /image-bootstrap.sh

sudo bash -c "echo > ${MNT}/etc/resolv.conf"
echo Unmounting image
sudo umount -R ${MNT}
sudo kpartx -dvs ${LOOP}
sudo losetup -d ${LOOP}

mv ${IPATH} .
#xz -T 0 -z -c ${IPATH} > ${IMAGENAME}.xz

rm -rf ${BUILDDIR}

