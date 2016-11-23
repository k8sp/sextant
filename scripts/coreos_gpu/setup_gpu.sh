#! /bin/bash

set -x

function usage(){
    echo "sudo bash $0 coreos-verison nvidia-drivier-verison"
    echo "e.g. sudo bash $0 1122.2.0 367.57"
}

if [ $# -ne 2 ]; then
   usage
   exit 1;
fi

cd `dirname $0`

mkdir -p /opt/bin
mkdir -p /var/lib/nvidia

TEMPLATE=/etc/ld.so.conf.d/nvidia.conf
[ -f $TEMPLATE ] || {
    echo "TEMPLATE: $TEMPLATE"
    mkdir -p $(dirname $TEMPLATE)
    cat << EOF > $TEMPLATE
/var/lib/nvidia
EOF
}

MODULES="modules-$1-$2"
TOOLS="tools-$2"
LIBRARIES="libraries-$2"

rm -rf {$MODULES,$TOOLS,$LIBRARIES}
mkdir -p {$MODULES,$TOOLS,$LIBRARIES}
tar -xf ${MODULES}.tar.bz2 -C $MODULES
tar -xf ${TOOLS}.tar.bz2 -C $TOOLS
tar -xf ${LIBRARIES}.tar.bz2 -C $LIBRARIES


rmmod nvidia-uvm
rmmod nvidia
insmod $MODULES/nvidia.ko
insmod $MODULES/nvidia-uvm.ko

cp $TOOLS/* /opt/bin

cp $LIBRARIES/* /var/lib/nvidia/

ldconfig

# Count the number of NVIDIA controllers found.
NVDEVS=`lspci | grep -i NVIDIA`
N3D=`echo "$NVDEVS" | grep "3D controller" | wc -l`
NVGA=`echo "$NVDEVS" | grep "VGA compatible controller" | wc -l`
N=`expr $N3D + $NVGA - 1`

for i in `seq 0 $N`; do
	mknod -m 666 /dev/nvidia$i c 195 $i
done

mknod -m 666 /dev/nvidiactl c 195 255

# Find out the major device number used by the nvidia-uvm driver
D=`grep nvidia-uvm /proc/devices | awk '{print $1}'`
mknod -m 666 /dev/nvidia-uvm c $D 0

