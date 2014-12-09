#!/bin/bash
set -e

LSB_RELEASE=$(lsb_release -rs)

if [ "$LSB_RELEASE" != "12.04" ]
then
    echo "WARNING: This script was tested only on Ubuntu 12.04"
fi

if [ $# -ne 1 ]; then
    echo "Usage: $0 <architecture> [buildroot version] [Cirros version]"
    exit 1
fi
export ARCH=$1
export br_ver=${2:-"2012.05"}
cirros_ver=${3:-"0.3.3"}
export WORKDIR=$PWD

if [ "$ARCH" == "x86_64" ];
then
    deb_arch="amd64"
else
    deb_arch=$ARCH
fi

kernel_deb="linux-image-3.8.0-44-generic_3.8.0-44.66~precise1_$deb_arch.deb"

sudo apt-get -y install bison flex texinfo build-essential gettext ncurses-dev unzip bzr qemu-kvm cvs quilt

if [ -d cirros ];
then
    # TODO replace this with a less brutal approach :)
    rm -rf cirros
fi

bzr branch lp:cirros -r tag:$cirros_ver

cd cirros
mkdir -p ../download
ln -snf ../download download
cd $WORKDIR/download

wget http://buildroot.uclibc.org/downloads/buildroot-${br_ver}.tar.gz
wget https://launchpad.net/ubuntu/+archive/primary/+files/$kernel_deb -O linux-image-package.deb

cd $WORKDIR/cirros

tar -xvf download/buildroot-${br_ver}.tar.gz
ln -snf buildroot-${br_ver} buildroot

# TODO: remove when the libcurl configure curl_socklen_t issue gets fixed
wget https://launchpadlibrarian.net/169640275/patch.patch -O libcurl_curl_socklen_t.patch
patch -p0 < libcurl_curl_socklen_t.patch

./bin/mkcabundle > src/etc/ssl/certs/ca-certificates.crt
cd buildroot && QUILT_PATCHES=$PWD/../patches-buildroot quilt push -a

cd $WORKDIR/cirros
make ARCH=$ARCH br-source
make ARCH=$ARCH OUT_D=$WORKDIR/cirros/output/$ARCH

sed -i 's/cp "${initramfs}.smaller"/cp "${initramfs}"/' $WORKDIR/cirros/bin/bundle
echo -e "mptbase\nmptscsih\nhv_netvsc\nhv_vmbus\nhv_utils\nhv_storvsc\n" >> $WORKDIR/cirros/src/etc/modules

cd $WORKDIR
sudo bash cirros/bin/bundle -v cirros/output/$ARCH/rootfs.tar download/linux-image-package.deb cirros/output/$ARCH/images

image_base_path=cirros/output/$ARCH/images/cirros-$cirros_ver
vhd_path="$image_base_path.vhd"
vhdx_path="$image_base_path.vhdx"

qemu-img convert -O vpc cirros/output/$ARCH/images/disk.img $vhd_path
gzip $vhd_path
echo "VHD image: $vhd_path.gz"

qemu-img convert -O vhdx cirros/output/$ARCH/images/disk.img $vhdx_path
gzip $vhdx_path
echo "VHDX image: $vhdx_path.gz"
