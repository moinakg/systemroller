#!/bin/bash
# Convert a live CD iso so that it can be booted over the network
# using PXELINUX.
# Copyright 2008 Red Hat, Inc.
# Written by Richard W.M. Jones <rjones@redhat.com>
# Based on a script by Jeremy Katz <katzj@redhat.com>
# Based on original work by Chris Lalancette <clalance@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#

export PATH=/sbin:/usr/sbin:${PATH}

usage() {
    echo "Usage: livecd-iso-to-ramiso <iso image>"
    exit 1
}

cleanup() {
    [ -d "$CDMNT" ] && umount $CDMNT && rmdir $CDMNT
}

exitclean() {
    echo "Cleaning up to exit..."
    cleanup
    exit 1
}

if [ $(id -u) != 0 ]; then
    echo "You need to be root to run this script."
    exit 1
fi

# Check pxelinux.0 exists.
if [ ! -f /usr/share/syslinux/pxelinux.0 -a ! -f /usr/lib/syslinux/pxelinux.0 ]; then
    echo "Warning: pxelinux.0 not found."
    echo "Make sure syslinux or pxelinux is installed on this system."
fi

while [ $# -gt 1 ]; do
    case "$1" in
	*) usage ;;
    esac
    shift
done

ISO="$1"

if [ -z "$ISO" -o ! -e "$ISO" ]; then
    usage
fi

# Mount the ISO.
# FIXME: would be better if we had better mountpoints
CDMNT=$(mktemp -d /media/cdtmp.XXXXXX)
mount -o loop "$ISO" $CDMNT || exitclean

ISOWORK=$(mktemp -d /media/isotmp.XXXXXX)
trap exitclean SIGINT SIGTERM

# Does it look like an ISO?
if [ ! -d $CDMNT/isolinux -o ! -f $CDMNT/isolinux/initrd0.img ]; then
    echo "The ISO image doesn't look like a LiveCD ISO image to me."
    exitclean
fi

ISOBASENAME=`basename "$ISO"`
ISODIRNAME=`dirname "$ISO"`

# Take the LiveOS dir from that ISO and create a new ISO with just that
VOL=`echo ${ISOBASENAME} | cut -f1 -d"."`
MKISO_ARGS="-J -r -hide-rr-moved -hide-joliet-trans-tbl"
mkdir -p ${ISOWORK}/pre-iso ${ISOWORK}/pre-iso-stage
cp -a ${CDMNT}/LiveOS ${ISOWORK}/pre-iso-stage
mkisofs ${MKISO_ARGS} -V "${VOL}" -o ${ISOWORK}/pre-iso/${ISOBASENAME} ${ISOWORK}/pre-iso-stage

mkdir -p ${ISOWORK}/iso-stage

# Create a cpio archive of just the ISO and append it to the
# initrd image.  The Linux kernel will do the right thing,
# aggregating both cpio archives (initrd + ISO) into a single
# filesystem.
( cd ${ISOWORK}/pre-iso/ && echo "$ISOBASENAME" | cpio -H newc --quiet -o ) |
  gzip -9 |
  cat $CDMNT/isolinux/initrd0.img - > ${ISOWORK}/iso-stage/initrd0.img

# Copy isolinux from original ISO
cp -a ${CDMNT}/isolinux ${CDMNT}/EFI ${ISOWORK}/iso-stage

# Move new initrd into proper place
mv ${ISOWORK}/iso-stage/initrd0.img ${ISOWORK}/iso-stage/isolinux

# Fixup files in EFI directory
(cd ${ISOWORK}/iso-stage/isolinux/
rm -f ${ISOWORK}/iso-stage/isolinux/macboot.img
for f in *
do
	if [ ! -e ${ISOWORK}/iso-stage/EFI/boot/${f} ]
	then
		ln ${ISOWORK}/iso-stage/EFI/boot/${f} ${ISOWORK}/iso-stage/isolinux/${f}
	fi
done)

cat ${ISOWORK}/iso-stage/EFI/BOOT/grub.cfg | sed -e "s#LABEL=[^ ]*#$ISOBASENAME#" -e "s/rd.live.image/rootflags=loop rd.live.image/" > ${ISOWORK}/iso-stage/EFI/BOOT/grub.cfg.new
mv ${ISOWORK}/iso-stage/EFI/BOOT/grub.cfg.new ${ISOWORK}/iso-stage/EFI/BOOT/grub.cfg

# Get boot append line from original cd image
if [ -f $CDMNT/isolinux/isolinux.cfg ]; then
	cat $CDMNT/isolinux/isolinux.cfg | sed -e "s#CDLABEL=[^ ]*#/$ISOBASENAME#" -e "s/rd.live.image/rootflags=loop rd.live.image/" > ${ISOWORK}/iso-stage/isolinux/isolinux.cfg
fi

# Now generate final ISO
VOL="${VOL}_ram"
mkisofs ${MKISO_ARGS} -V "${VOL}" -o ${VOL}.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-info-table -boot-load-size 4 ${ISOWORK}/iso-stage

# All done, clean up
umount $CDMNT
rmdir $CDMNT

rm -rf ${ISOWORK}

exit 0

