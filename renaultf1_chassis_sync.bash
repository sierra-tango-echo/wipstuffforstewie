IMAGENAME=$1
IMAGEBASE=/export/service/image/

IMAGE=${IMAGEBASE}${IMAGENAME}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -z "${IMAGENAME}" ]; then
  echo "Gimme image name plz" >&2
  exit 1
elif ! [ -d ${IMAGE} ]; then
  echo "Image not exists" >&2
  exit 1
fi

CHASSIS=13

seq -w 2 45 | while read n; do
  rsync -pav $IMAGEBASE/$IMAGENAME/ $IMAGEBASE/cfd-ms-${CHASSIS}0$n/
done
