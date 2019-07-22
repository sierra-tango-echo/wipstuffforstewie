IMAGENAME=$1
IMAGEBASE=/export/service/image/

IMAGE=${IMAGEBASE}${IMAGENAME}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


STAGINGBASE="/media/staging"
STAGINGDIR="${STAGINGBASE}/${IMAGENAME}"
LOOP="${STAGINGBASE}/${IMAGENAME}-loop"
IMAGEFILE=${IMAGE}.img

if [ -z "${IMAGENAME}" ]; then
  echo "Gimme image name plz" >&2
  exit 1
elif ! [ -d ${IMAGE} ]; then 
  echo "Doofus, gimme image that exists" >&2
  exit 1
elif [ -e ${IMAGEFILE} ]; then
  echo "Image file already exists!" >&2
  exit 1
elif [ -e ${STAGINGDIR} ]; then
  echo "Staging dir already exists!" >&2
  exit 1
elif ! ( which qemu-img ); then
  echo "Please install qemu-img" >&2 
  exit 1
elif ! ( which mksquashfs ); then 
  echo "Plz install mksquashfs" >&2 
  exit 1
fi

echo $IMAGEFILE
echo $STAGINGDIR

mkdir -p ${STAGINGDIR}/LiveOS/
mkdir -p ${LOOP}

echo "Creating Image and formatting it.."
qemu-img create -f raw ${STAGINGDIR}/LiveOS/ext3fs.img 8G
mkfs.ext4 -L root -F ${STAGINGDIR}/LiveOS/ext3fs.img

echo "Mounting image and copying data.."
mount -o loop ${STAGINGDIR}/LiveOS/ext3fs.img ${LOOP} 
rsync -pa ${IMAGE}/ ${LOOP}/

echo "Hacking fstab..:"
echo "/dev/root  /         ext4    defaults,noatime 0 0" >> ${LOOP}/etc/fstab

sleep 2
umount ${LOOP}

echo "Squashing.."
mksquashfs ${STAGINGDIR}/ ${IMAGEFILE}

echo "Cleaning.."
rm -rf ${STAGINGDIR}

echo "Done.."
echo "Imgage: ${IMAGEFILE}"
echo "Now u prolly want somefin like..."
echo "LABEL $IMAGENAME-livehttp"
echo "     MENU LABEL $IMAGENAME"
echo "     KERNEL boot/kernel-$IMAGENAME"
echo "     APPEND initrd=boot/initrd-$IMAGENAME root=live:http:http://<HTTPSERVER>/<HTTPPATH>/${IMAGENAME}.img rw selinux=0 console=tty0 console=ttyS0,115200n8"
echo "Or.."
echo "LABEL $IMAGENAME-livenfs"
echo "     MENU LABEL $IMAGENAME"
echo "     KERNEL boot/kernel-$IMAGENAME"
echo "     APPEND initrd=boot/initrd-$IMAGENAME root=live:nfs:<NFSERVER>:<NFSEXPORT>/${IMAGENAME}.img rw selinux=0 console=tty0 console=ttyS0,115200n8"
echo
