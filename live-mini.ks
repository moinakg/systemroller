# fedora-live-mini.ks
#
# Defines the basics for all kickstarts in the fedora-mini branch

lang C
keyboard us
timezone US/Eastern
auth --useshadow --enablemd5
selinux --permissive
firewall --disabled
part / --size 1400 --fstype ext4
services --enabled=sshd,network

#
# The root passwd below in plaintext is fedora12
# Use this for testing root access.
#
rootpw --iscrypted $6$cQUoSQBm$nC5VeDt0d8JxFZsMU/sHNBIZYBmBRam8qQaatum8f5m/8k0K5TemsEncllSuqeE8JRWpkFtg/YIDKv2bb6zxR/

#
# The root passwd below is something random. Generate one or
# use the one below to prevent root access to the live environment.
#
#rootpw --iscrypted $6$8oCSN7US$JpGCyd.WfUzo.uVmWK0iOeL6plX8kFIwG0dJWFaAfCwttbqiDab9pWsrsuLlvxgPcO9bbaly7Yscq6MxyExXf.
authconfig --enableshadow --passalgo=sha512 --enablefingerprint

#repo --name=rawhide --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=rawhide&arch=$basearch
#repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch
#repo --name=updates --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f$releasever&arch=$basearch
#repo --name=updates-testing --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-testing-f$releasever&arch=$basearch
repo --name=local-fedora --baseurl=file:///repo/x86_64/18/packages

%packages --nobase --excludedocs
@core
@hardware-support
kernel
memtest86+
ncurses-libs
binutils
firewalld
vim-minimal
passwd
htop
thttpd
powertop
firewalld
openssh-clients
openssh-server
rpm
policycoreutils
shim
grub2-efi
dhclient
dmidecode
numactl
pciutils
ethtool
nfs-utils
nscd
ipmitool
smartmontools
traceroute
iproute
iputils
bind-utils
bc
curl
net-tools

%end

%post --nochroot
/bin/sed -i -e 's/ rhgb/ selinux=0 processor.max_cstate=1 nomodeset elevator=noop/g' -e 's/ quiet//g' -e 's/timeout 100/timeout 1/' $LIVE_ROOT/isolinux/isolinux.cfg

cp scripts/dhclient-up-hooks ${INSTALL_ROOT}/etc/dhcp
chmod +x ${INSTALL_ROOT}/etc/dhcp/dhclient-up-hooks

mkdir ${INSTALL_ROOT}/rbin
cp scripts/rbash.setup ${INSTALL_ROOT}/bin/rbash.setup
chmod a+x ${INSTALL_ROOT}/bin/rbash.setup

#
# Setup a lesskey file to block shell escape and vi from less
#
cat >${INSTALL_ROOT}/rbin/lk <<EOF
#command
|         status
v         status
!         status
EOF
lesskey -o ${INSTALL_ROOT}/rbin/.lessk ${INSTALL_ROOT}/rbin/lk
rm ${INSTALL_ROOT}/rbin/lk

for prog in `ls scripts/rbin`
do
	cp scripts/rbin/${prog} ${INSTALL_ROOT}/rbin/${prog}
	chmod a+x ${INSTALL_ROOT}/rbin/${prog}
done

for lnk in `cat symlinks.lst`
do
	_IFS=$IFS
	IFS=","
	set -- $lnk
	IFS=$_IFS

	l=$1
	t=$2
	ln -s $t ${INSTALL_ROOT}/$l
done

# only works on x86, x86_64
if [ "$(uname -i)" = "i386" -o "$(uname -i)" = "x86_64" ]; then
  if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
  cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS
fi
%end

%post
cat << __EOF > /etc/issue
####################################################
##    Welcome to System Test/Diagnostics Tool     ##
####################################################
__EOF

if [ -f /etc/selinux/config ]
then
	# Weaken selinux
	cp /etc/selinux/config /etc/selinux/config.orig
	cat /etc/selinux/config.orig | sed 's/SELINUX=enforcing/SELINUX=permissive/' > /etc/selinux/config
fi

# Sysfont setup
echo 'FONT="latarcyrheb-sun16"' >> /etc/vconsole.conf
echo "enable -n help" > /etc/profile.d/nohelp.sh
chmod a+x /etc/profile.d/nohelp.sh

################### Force uninstall pkgs #################
# The package carnage above only removes packages preserving dependencies.
# We break dependencies here and uninstall stuff not needed for our specific purpose.
#
cat <<_PKGS > pkgs_rm
libhugetlbfs
kudzu
prelink
grubby
dos2unix
dump
finger
fprintd-pam
hunspell
jwhois
lftp
mlocate
nano
nfs-utils
pcmciautils
pm-utils
rdate
rdist
rsh
rsync
sos
stunnel
time
tree
words
ypbind
autofs
samba-client
mpage
sox
hplip
hpijs
isdn4k-utils
coolkey
wget
libcgroup
perl-Pod-Simple
perl-Pod-Escapes
fipscheck
libdrm
libpciaccess
lm_sensors-devel
gamin
grubby
acl
attr
pinentry
which
groff
newt
ed
slang
htmlview
foomatic
ghostscript
ivtv-firmware
irda-utils
fprintd
fprintd-pam
libfprint
aspell
hunspell
hunspell-en-US
man-pages
words
ql2100-firmware
ql2200-firmware
ql23xx-firmware
ql2400-firmware
ql2500-firmware
xsane
xsane-gimp
sane-backends
sendmail
yum
yum-metadata-parser
gpgme
pygpgme
gpgme
gnupg2
pth
krb5-workstation
python-urlgrabber
libedit
rpm-python
python-iniparse
make
deltarpm
preupgrade
PackageKit
libarchive
comps-extras
alsa-utils
alsa-firmware
alsa-tools-firmware
alsa-lib
cups
cups-libs
anaconda
anaconda-yum-plugins
ppp
man-db
js
freetype
groff-base
perl-Pod-Perldoc
sudo
info
_PKGS

echo "Removing unwanted packages ..."
for pkg in `cat pkgs_rm`
do
	rpm -qi $pkg 2>&1 > /dev/null
	if [ $? -eq 0 ]
	then
        	rpm -ev --nodeps $pkg
	fi
done

# Add a root-equivalent user with a restricted shell
/usr/sbin/useradd -s /bin/rbash.setup -c "Fedora Live" -g root -o -u 0 -d /root fedora
/usr/bin/passwd -d fedora > /dev/null

#
# Some SSHD configuration
#
echo "Banner /etc/issue" >> /etc/ssh/sshd_config
echo "PermitEmptyPasswords yes" >> /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# Fixup autologin to fedora user
cat /usr/lib/systemd/system/getty@.service | sed 's/noclear %I/noclear -a fedora %I/' > /etc/systemd/system/getty@.service
cp /etc/systemd/system/getty@.service /usr/lib/systemd/system/getty@.service

###############################################################################
# Add live image Init script
#
# FIXME: it'd be better to get this installed from a package
#
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" live: || [ "\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

touch /.liveimg-configured

# Make sure we don't mangle the hardware clock on shutdown
ln -sf /dev/null /etc/systemd/system/hwclock-save.service

livedir="LiveOS"
for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##rd.live.dir=}" != "\${arg}" ]; then
    livedir=\${arg##rd.live.dir=}
    return
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
    return
  fi
done

# enable swaps unless requested otherwise
swaps=\`blkid -t TYPE=swap -o device\`
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -n "\$swaps" ] ; then
  for s in \$swaps ; do
    action "Enabling swap partition \$s" swapon \$s
  done
fi
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -f /run/initramfs/live/\${livedir}/swap.img ] ; then
  action "Enabling swap file" swapon /run/initramfs/live/\${livedir}/swap.img
fi

mountPersistentHome() {
  # support label/uuid
  if [ "\${homedev##LABEL=}" != "\${homedev}" -o "\${homedev##UUID=}" != "\${homedev}" ]; then
    homedev=\`/sbin/blkid -o device -t "\$homedev"\`
  fi

  # if we're given a file rather than a blockdev, loopback it
  if [ "\${homedev##mtd}" != "\${homedev}" ]; then
    # mtd devs don't have a block device but get magic-mounted with -t jffs2
    mountopts="-t jffs2"
  elif [ ! -b "\$homedev" ]; then
    loopdev=\`losetup -f\`
    if [ "\${homedev##/run/initramfs/live}" != "\${homedev}" ]; then
      action "Remounting live store r/w" mount -o remount,rw /run/initramfs/live
    fi
    losetup \$loopdev \$homedev
    homedev=\$loopdev
  fi

  # if it's encrypted, we need to unlock it
  if [ "\$(/sbin/blkid -s TYPE -o value \$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
    echo
    echo "Setting up encrypted /home device"
    plymouth ask-for-password --command="cryptsetup luksOpen \$homedev EncHome"
    homedev=/dev/mapper/EncHome
  fi

  # and finally do the mount
  mount \$mountopts \$homedev /home
  # if we have /home under what's passed for persistent home, then
  # we should make that the real /home.  useful for mtd device on olpc
  if [ -d /home/home ]; then mount --bind /home/home /home ; fi
  [ -x /sbin/restorecon ] && /sbin/restorecon /home
  if [ -d /home/liveuser ]; then USERADDARGS="-M" ; fi
}

findPersistentHome() {
  for arg in \`cat /proc/cmdline\` ; do
    if [ "\${arg##persistenthome=}" != "\${arg}" ]; then
      homedev=\${arg##persistenthome=}
      return
    fi
  done
}

if strstr "\`cat /proc/cmdline\`" persistenthome= ; then
  findPersistentHome
elif [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
fi

# if we have a persistent /home, then we want to go ahead and mount it
if ! strstr "\`cat /proc/cmdline\`" nopersistenthome && [ -n "\$homedev" ] ; then
  action "Mounting persistent /home" mountPersistentHome
fi

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
mount -t tmpfs -o mode=0755 varcacheyum /var/cache/yum
mount -t tmpfs vartmp /var/tmp
[ -x /sbin/restorecon ] && /sbin/restorecon /var/cache/yum /var/tmp >/dev/null 2>&1

# turn off firstboot for livecd boots
systemctl --no-reload disable firstboot-text.service 2> /dev/null || :
systemctl --no-reload disable firstboot-graphical.service 2> /dev/null || :
systemctl stop firstboot-text.service 2> /dev/null || :
systemctl stop firstboot-graphical.service 2> /dev/null || :

# don't use prelink on a running live image
sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink &>/dev/null || :

# turn off mdmonitor by default
systemctl --no-reload disable mdmonitor.service 2> /dev/null || :
systemctl --no-reload disable mdmonitor-takeover.service 2> /dev/null || :
systemctl stop mdmonitor.service 2> /dev/null || :
systemctl stop mdmonitor-takeover.service 2> /dev/null || :

# don't start cron/at as they tend to spawn things which are
# disk intensive that are painful on a live image
systemctl --no-reload disable crond.service 2> /dev/null || :
systemctl --no-reload disable atd.service 2> /dev/null || :
systemctl stop crond.service 2> /dev/null || :
systemctl stop atd.service 2> /dev/null || :

# and hack so that we eject the cd on shutdown if we're using a CD...
if strstr "\`cat /proc/cmdline\`" CDLABEL= ; then
  cat >> /sbin/halt.local << FOE
#!/bin/bash
# we want to eject the cd on halt, but let's also try to avoid
# io errors due to not being able to get files...
cat /sbin/halt > /dev/null
cat /sbin/reboot > /dev/null
/usr/sbin/eject -p -m \$(readlink -f /run/initramfs/livedev) >/dev/null 2>&1
echo "Please remove the CD from your drive and press Enter to finish restarting"
read -t 30 < /dev/console
FOE
chmod +x /sbin/halt.local
fi

EOF

# bah, hal starts way too late
cat > /etc/rc.d/init.d/livesys-late << EOF
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

# read some variables out of /proc/cmdline
for o in \`cat /proc/cmdline\` ; do
    case \$o in
    ks=*)
        ks="\${o#ks=}"
        ;;
    esac
done

touch /.liveimg-late-configured

EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late
###############################################################################

###############################################################################
# Add interface detection script
#
cat > /etc/rc.d/init.d/probe_interfaces << EOF
#!/bin/bash
#
# description: Probe network interfaces, detect link and add ifcfg entries for up adapters
#

mkdir -p /var/tmp/probe_interfaces

echo "Probing interfaces "
case "\$1" in
 start) for iface in \`/sbin/ip -o link show | egrep -v 'lo[0-9]*:' | cut -d: -f2\`
        do
            echo "DEVICE=\$iface" > /etc/sysconfig/network-scripts/ifcfg-\$iface
            echo "BOOTPROTO=dhcp" >> /etc/sysconfig/network-scripts/ifcfg-\$iface
            echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-\$iface
        done
        ;;
     *) echo
        ;;
esac

EOF

cat > /lib/systemd/system/probe_interfaces.service <<EOF
[Unit]
Description=Probe interfaces
Before=NetworkManager.service

[Service]
Type=forking
ExecStart=/etc/rc.d/init.d/probe_interfaces start
TimeoutSec=0
RemainAfterExit=yes

[Install]
WantedBy=NetworkManager.service

EOF

chmod a+x /etc/rc.d/init.d/probe_interfaces
systemctl enable probe_interfaces.service
###############################################################################

#
# Enable Tiny HTTP Service
#
systemctl enable thttpd.service

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

#
# Remove critical boot files since this image is not meant to be
# installable.
#
rm -f /boot/initrd*
rm -f /boot/initramfs*
rm -f /boot/vmlinuz*
rm -rf /boot/efi /boot/grub2
rm -rf /usr/lib/grub

# make sure there aren't core files lying around
rm -f /core*

# convince readahead not to collect
# FIXME: for systemd

# File carnage
# Remove selective kernel pieces
rm -rf lib/modules/3.*/kernel/sound
rm -rf lib/modules/3.*/kernel/drivers/isdn
rm -rf lib/modules/3.*/kernel/drivers/firewire
rm -rf lib/modules/3.*/kernel/drivers/bluetooth
rm -rf lib/modules/3.*/kernel/drivers/memstick
rm -rf lib/modules/3.*/kernel/drivers/gpu
rm -rf lib/modules/3.*/kernel/drivers/input/tablet
rm -rf lib/modules/3.*/kernel/drivers/input/touchscreen
rm -rf lib/modules/3.*/kernel/drivers/input/gameport
rm -rf lib/modules/3.*/kernel/drivers/input/joystick
rm -rf lib/modules/3.*/kernel/drivers/media/dvb
rm -rf lib/modules/3.*/kernel/drivers/media/video
rm -rf lib/modules/3.*/kernel/drivers/media/common/tuners
rm -rf lib/modules/3.*/kernel/drivers/media/rc
rm -rf lib/modules/3.*/kernel/net/wimax
rm -rf lib/modules/3.*/kernel/net/wireless
rm -rf lib/modules/3.*/kernel/net/phonet
rm -rf lib/modules/3.*/kernel/net/bluetooth
rm -rf lib/modules/3.*/kernel/net/dhcp
rm -rf lib/modules/3.*/kernel/net/sctp
rm -rf lib/modules/3.*/kernel/net/9p
rm -rf lib/modules/3.*/kernel/arch/x86/oprofile
rm -rf lib/modules/3.*/kernel/fs/fuse
rm -rf lib/modules/3.*/kernel/fs/gfs2
rm -rf lib/modules/3.*/kernel/fs/ubifs
rm -rf lib/modules/3.*/kernel/fs/cifs
rm -rf lib/modules/3.*/kernel/fs/cramfs
rm -rf lib/modules/3.*/kernel/fs/ecryptfs
rm -rf lib/modules/3.*/kernel/fs/xfs
rm -rf lib/modules/3.*/kernel/fs/nfs*
rm -rf lib/modules/3.*/kernel/fs/lockd
rm -rf lib/modules/3.*/kernel/drivers/block/aoe
rm -rf lib/modules/3.*/kernel/drivers/block/cryptoloop
rm -rf lib/modules/3.*/kernel/drivers/char/pcmcia
rm -rf lib/modules/3.*/kernel/drivers/net/pcmcia
rm -rf lib/modules/3.*/kernel/drivers/net/wimax
rm -rf lib/modules/3.*/kernel/drivers/net/wireless
rm -rf lib/modules/3.*/kernel/drivers/staging/zram
rm -rf lib/modules/3.*/kernel/drivers/net/usb/cdc-phonet*
rm -rf lib/modules/3.*/kernel/drivers/net/tun.*
rm -rf lib/modules/3.*/kernel/drivers/pcmcia
rm -rf lib/modules/3.*/kernel/drivers/hid/hid-wacom*
rm -rf lib/modules/3.*/kernel/drivers/uwb
rm -rf lib/modules/3.*/kernel/drivers/usb/misc/emi62*
rm -rf lib/modules/3.*/kernel/drivers/usb/misc/emi26*
rm -rf lib/modules/3.*/kernel/drivers/misc/sgi-xp
rm -rf lib/modules/3.*/kernel/drivers/usb/misc/legousbtower*I
rm -rf lib/modules/3.*/kernel/drivers/usb/misc/appledisplay*
rm -rf lib/modules/3.*/kernel/drivers/usb/misc/berry_charge*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/garmin*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/ir-usb*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/moto_modem
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/ipaq*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/visor*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/empeg*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/aircable*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/cyberjack*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/keyspan_pda*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/usb_wwan*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/opticon*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/sierra*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/navman*
rm -rf lib/modules/3.*/kernel/drivers/usb/serial/omninet*
rm -rf lib/modules/3.*/kernel/drivers/input/mouse/appletouch*
rm -rf lib/modules/3.*/kernel/drivers/imput/misc/keyspan_remote*

rm -rf /lib/firmware/mts_* /lib/firmware/av7110
rm -rf /lib/firmware/sb16 /lib/firmware/matrox
rm -rf /lib/firmware/emi62 /lib/firmware/emi26
rm -rf /lib/firmware/keyspan /lib/firmware/keyspan_pda
rm -rf /lib/firmware/vicam /lib/firmware/v4l* /lib/firmware/dvb-*

# Remove other miscellaneous files from the world
rm -f /usr/sbin/visudo /usr/sbin/update-pciids
rm -f /usr/sbin/glibc_post_upgrade
rm -f /usr/sbin/create-cracklib-dict /usr/sbin/cracklib*
rm -f /usr/sbin/fdformat /usr/sbin/usernetctl
rm -f /usr/sbin/sys-unconfig /usr/sbin/newusers
rm -f /usr/sbin/iconvconfig* /usr/sbin/tzdata-update
rm -f /usr/sbin/usermod /usr/sbin/groupmod
rm -f /usr/sbin/lusermod /usr/sbin/lgroupmod
rm -f /sbin/sln /sbin/tc /sbin/mkfs.cramfs
rm -f /sbin/fsck.cramfs /sbin/wipefs
rm -f /sbin/ldconfig /sbin/mkinitrd
rm -f /usr/bin/pinky /usr/bin/dprofpp
rm -f /usr/bin/rev /usr/bin/look /usr/bin/rpmsign
rm -f /usr/bin/pgawk /usr/bin/find2perl
rm -f /usr/bin/csplit /usr/bin/floppy
rm -f /usr/bin/info /usr/bin/unicode_*
rm -f /usr/bin/install /usr/bin/psfaddtable
rm -f /usr/bin/ksu /usr/bin/tac /usr/bin/deallocvt
rm -f /usr/bin/localedef /usr/bin/sprof
rm -f /usr/bin/vdir /usr/bin/perlthanks
rm -f /usr/bin/ptx /usr/bin/pod2* /usr/bin/loaduniumap
rm -f /usr/bin/mkdiskimage /usr/bin/isosize
rm -f /usr/bin/stdbuf /usr/bin/pcretest
rm -f /usr/bin/perlbug /usr/bin/mbchk /usr/bin/shuf
rm -f /usr/bin/db_dump185 /usr/bin/a2p
rm -f /usr/sbin/readprofile /usr/sbin/tunelp
rm -f /usr/sbin/vipw /usr/sbin/vigr /usr/sbin/filefrag
rm -f /usr/sbin/userdel /usr/bin/podselect
rm -f /usr/sbin/ssmtp /usr/sbin/zic /usr/sbin/capsh
rm -f /usr/sbin/pwck /usr/sbin/grpck
rm -f /usr/sbin/arpd /usr/sbin/groupmems
rm -f /usr/sbin/pwconv /usr/bin/pcregrep /usr/bin/isohybrid
rm -f /usr/sbin/pwunconv /usr/sbin/grpconv
rm -f /usr/sbin/grpunconv /usr/sbin/libcc_post_upgrade
rm -f /usr/sbin/grub2* /usr/bin/grub2*
rm -f /usr/bin/bzip2recover /usr/bin/gzexe
rm -f /usr/bin/cal /usr/bin/pstree.x11
rm -f /usr/bin/scriptreplay /usr/bin/mcookie
rm -f /usr/bin/zegrep /usr/bin/zfgrep /usr/bin/whereis
rm -f /usr/bin/ionice /usr/bin/pwdx /usr/bin/dircolors
rm -f /usr/bin/ppmtolss16 /usr/bin/pxelinux-options
rm -f /usr/bin/psfgettable /usr/bin/s2p /usr/bin/kill
rm -f /usr/bin/lss16toppm /usr/bin/infotocap
rm -f /usr/bin/objcopy /usr/bin/c++filt
rm -f /usr/bin/elfedit /usr/bin/gprof
rm -f /usr/bin/as /usr/bin/ranlib
rm -rf /usr/lib/anaconda-runtime /usr/lib/ConsoleKit /usr/lib/dracut
rm -rf /usr/lib64/gconv /usr/lib64/nss/unsupported-tools
rm -rf /usr/lib64/python2.6/lib2to3 /usr/lib64/python2.6/idlelib
rm -f /usr/lib64/libgmpxx* /usr/libexec/perf* /usr/lib64/libusbpp*
rm -f /usr/lib64/libpcrecpp* /usr/lib64/libpcreposix*
rm -rf /usr/libexec/getconf /usr/lib64/python2.6/distutils
rm -rf /usr/include /usr/games /etc/ssmtp /user/lib/gconv
rm -rf /etc/selinux/targeted
rm -rf /etc/X11 /etc/pki/tls/certs
rm -rf /etc/Networkmanager
rm -f /etc/DIR_COLORS* /etc/virc
rm -rf /usr/src /usr/etc /usr/local/games /usr/local/share/applications /usr/local/share/info
rm -rf /opt/dell/srvadmin/etc
rm -rf /lib/kbd/keymaps/amiga /usr/lib/rpm/platform/athlon-linux
rm -rf /lib/kbd/keymaps/atari /usr/lib/rpm/platform/geode-linux
rm -rf /lib/kbd/keymaps/mac # Glad to remove this one
rm -rf /lib/kbd/keymaps/i386/olpc /usr/lib/rpm/platform/pentium3-linux
rm -rf /lib/kbd/keymaps/i386/dvorak /usr/lib/rpm/platform/pentium4-linux
rm -rf /lib/kbd/keymaps/i386/azerty
rm -rf /lib/kbd/keymaps/i386/fgGIod
rm -rf /lib/kbd/keymaps/i386/qwertz
rm -f /bin/ypdomainname /bin/unicode_start /bin/unicode_stop
rm /lib64/security/pam_postgresok.so /lib64/security/pam_mkhomedir.so
rm /lib64/security/pam_mail.so /lib64/security/pam_stress.so
rm /lib64/security/pam_time.so /lib64/security/pam_shells.so
rm /lib64/security/pam_motd.so
rm /lib64/security/pam_ftp.so
rm /lib64/security/pam_pwhistory.so /lib64/security/pam_rhosts.so
rm /lib64/security/pam_debug.so /lib64/security/pam_tally2.so

# Remove yumdb
rm -rf /usr/lib/yum

# Remove all console fonts except the one specified
CFONT=`egrep "^FONT" /etc/vconsole.conf | cut -f2 -d'"'`
find /lib/kbd/consolefonts -maxdepth 1 -type f | grep -v $CFONT | xargs rm

# Remove partialfonts as the latarcyrheb console font does not depend on any
rm -rf /lib/kbd/consolefonts/partialfonts

# We ain't want no locales
find /usr/share/locale /usr/share/i18n -type f | egrep -v 'locale.alias' | xargs rm 
rm -f /usr/lib/locale/locale-archive
rm -f /usr/sbin/build-locale-archive

# Get rid of selected /usr/share/stuff
rm -rf /usr/share/backgrounds /usr/share/icons
rm -rf /usr/share/kde* /usr/share/wallpapers
rm -rf /usr/share/misc /usr/share/X11
rm -rf /usr/share/anaconda /usr/share/applications
rm -rf /usr/share/plymouth /usr/share/desktop-directories
rm -rf /usr/share/selinux /usr/share/ghostscript
rm -rf /usr/share/doc /usr/share/dict
rm -rf /usr/share/firstboot /usr/share/sounds
rm -rf /usr/share/emacs /usr/share/games
rm -rf /usr/share/man /usr/share/idl /usr/local/share/man
rm -rf /usr/share/omf /usr/share/aclocal
rm -rf /usr/share/pixmaps /usr/share/xsessions
rm -rf /usr/share/i18n/charmaps/EBCDIC*
rm -rf /usr/share/i18n/charmaps/IBM*
rm -rf /usr/share/gnome* /usr/share/themes
rm -rf /usr/share/syslinux/com32 /usr/share/syslinux/sanboot.c32
rm -rf /usr/share/syslinux/hdt.c32 /usr/share/syslinux/gfxboot*
rm -rf /usr/share/perl5/pod /usr/share/info
rm -rf /usr/share/perl5/desktop-directories
rm -rf /usr/share/gnupg /usr/share/augeas /usr/share/fedora-logos
rm -rf /usr/share/grub /usr/share/terminfo/A/Apple_Terminal # Glad to remove this
rm -rf /usr/share/terminfo/g/gnome* /usr/share/terminfo/m/mach*
rm -rf /usr/share/terminfo/h/hurd* /usr/share/terminfo/k/konsole*
rm -rf /usr/share/terminfo/E/Eterm* /usr/share/systemtap
rm -rf /usr/share/perl5/Pod /usr/share/dracut /usr/share/shim
rm -rf /usr/share/mime/application/* /usr/share/mime/packages/* /usr/share/mime/audio/*
rm -rf /usr/share/mime/video/* /usr/share/mime/x-content/* /usr/share/mime/image/*

# Do not bother with timezone
rm -rf /usr/share/zoneinfo

# Nuke package metadata. Not really needed.
rm -f /var/lib/rpm/Packages

# Nuke python bytecodes. Performance does not matter here.
find /usr/lib64/python* -name "*.pyc" | xargs rm -f
find /usr/lib64/python* -name "*.pyo" | xargs rm -f
find /usr/lib/python* -name "*.pyc" | xargs rm -f
find /usr/lib/python* -name "*.pyo" | xargs rm -f

find /usr/lib64/perl5 -name "*.pod" | xargs rm -f

# Re-run depmod since some kernel modules were removed
echo "Running depmod after cleanup ..."
/sbin/depmod -a -b / `basename /lib/modules/3.*`

%end

