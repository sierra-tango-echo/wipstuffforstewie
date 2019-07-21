IMAGENAME=$1
IMAGEBASE=/export/service/image/

IMAGE=${IMAGEBASE}${IMAGENAME}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

READONLYROOT=0
FLIGHTINSTALL=1

if [ -z "${IMAGENAME}" ]; then
  echo "Gimme image name plz" >&2
  exit 1
elif [ -e ${IMAGE} ]; then 
  echo "Image exists" >&2
  exit 1
fi

mkdir -p $IMAGE

#INSTALL A ROOT
yum groups -c /export/service/image/cluster.repo -y install "Compute Node" "Core" --releasever=7 --installroot=$IMAGE
yum -c /export/service/image/cluster.repo -y install vim emacs xauth xhost xdpyinfo xterm xclock tigervnc-server ntpdate vconfig bridge-utils patch tcl-devel gettext wget dracut-network nfs-utils --installroot=$IMAGE
cat << EOF > $IMAGE/etc/fstab
tmpfs   /dev/shm    tmpfs   defaults   0 0
sysfs   /sys        sysfs   defaults   0 0
proc    /proc       proc    defaults   0 0
EOF

#cat << EOF > $IMAGE/etc/resolv.conf
#search pri.rscfd1.alces.network mgt.rscfd1.alces.network ib.rscfd1.alces.network bmc.mgt.rscfd1.alces.network rscfd1.alces.network
#nameserver 10.10.0.1
#EOF

#PREP IMAGE
sed -e 's/^SELINUX=.*$/SELINUX=disabled/g' -i $IMAGE/etc/sysconfig/selinux
cp -v $DIR/rwtab $IMAGE/etc/rwtab
rm -rf /etc/rwtab.d/*

if [ ${READONLYROOT} -eq 1 ]; then
  sed -e 's/^TEMPORARY_STATE=.*$/TEMPORARY_STATE=yes/g' -i $IMAGE/etc/sysconfig/readonly-root
fi


ln -snf /usr/share/zoneinfo/Europe/London $IMAGE/etc/localtime
echo 'ZONE="Europe/London"' > $IMAGE/etc/sysconfig/clock

echo 'root:$1$kl5Vk5UX$Kb.TQ73sEm5bVZiqb0v/31' | chpasswd -e -R $IMAGE

if [ ${FLIGHTINSTALL} -eq 1 ]; then
  mkdir -p $IMAGE/var/lib/flightinstall/bin/
  cp -v $DIR/flightinstall.sh $IMAGE/var/lib/flightinstall/bin/setup.sh
fi

mount -o bind /proc $IMAGE/proc
mount -o bind /sys  $IMAGE/sys
mount -o bind /run  $IMAGE/run
mount -o bind /dev  $IMAGE/dev

KERNEL=`chroot $IMAGE rpm -q kernel | tail -n 1 | sed -e 's/^kernel-//g'`
#chroot $IMAGE systemctl disable NetworkManager
chroot $IMAGE systemctl disable kdump
#chroot $IMAGE dracut -N -a livenet -a dmsquash-live -a nfs -a biosdevname -o ifcfg -f -v /boot/initrd.diskless $KERNEL
chroot $IMAGE dracut -N -a livenet -a dmsquash-live -a nfs -a biosdevname -f -v /boot/initrd.$IMAGENAME $KERNEL

if [ ${FLIGHTINSTALL} -eq 1 ]; then
  mkdir -p $IMAGE/var/lib/flightinstall/bin/
  cp -v $DIR/flightinstall.sh $IMAGE/var/lib/flightinstall/bin/setup.sh
  chroot $IMAGE bash /var/lib/flightinstall/bin/setup.sh
fi


chroot $IMAGE cp -v /boot/vmlinuz-$KERNEL /boot/kernel.$IMAGENAME
yum clean all
umount -f $IMAGE/proc $IMAGE/sys $IMAGE/run $IMAGE/dev

sleep 5

chmod 644 $IMAGE/boot/initrd.$IMAGENAME
chmod 644 $IMAGE/boot/kernel.$IMAGENAME

echo "Image done.."
echo "------------"
echo "Kernel: $IMAGE/boot/kernel.$IMAGENAME"
echo "InitRD: $IMAGE/boot/initrd.$IMAGENAME"
echo
echo "For NFS root, something like.."
echo "LABEL $IMAGENAME"
echo "     MENU LABEL $IMAGENAME"
echo "     KERNEL boot/kernel-$IMAGENAME"
echo "     APPEND initrd=boot/initrd-$IMAGENAME root=nfs:<NFSSERVER>:<IMAGEEXPORT> rw selinux=0 console=tty0 console=ttyS0,115200n8"
echo


