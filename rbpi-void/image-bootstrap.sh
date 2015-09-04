#!/bin/bash
set -u
# This script will be executed inside the chroot

echo squeezie > /etc/hostname
export XBPS_TARGET_ARCH=armv6l
xbps-install -Suy
xbps-install -Sy openssh python3 alsa-utils rpi-kernel rpi-firmware faad2 libmad python3.4-Flask python3.4-pip python3.4-requests

useradd -m -G audio squeezie

cat <<EOF >>/etc/fstab
/dev/mmcblk0p1 /boot vfat defaults 0 0
EOF

pushd /etc/runit/runsvdir/default/
rm agetty-tty{3,4,5,6} sshd
for sv in alsa squeezelite;do
  ln -s /etc/sv/$sv .
done
popd

# Add system user for dbus service, wondering why this is not done automatically
#useradd -r -U dbus

rm -rf /usr/share/man /var/cache/xbps/* /usr/share/doc/*

>/etc/resolv.conf

mkdir /etc/sv/squeezelite

cat <<EOF >/etc/squeezelite.cfg
SERVER=squeeze.foo.bar
NAME=squeezie
OUTPUT=default:CARD=U0x41e0x30d3
LOGLEVEL=info
EOF


cat <<EOF >/etc/sv/squeezelite/run
#!/bin/sh
sv start alsa || exit 1
sv start dhcpcd || exit 1
>/var/log/squeeze.log
. /etc/squeezelite.cfg
exec chpst -u squeezie:squeezie /usr/local/bin/squeezelite -s \$SERVER -n \$NAME -o \$OUTPUT -d all=\$LOGLEVEL -f /var/log/squeeze.log
EOF

