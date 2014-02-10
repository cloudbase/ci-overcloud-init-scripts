#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <architecture> <buildroot version>"
    exit 1
fi
export ARCH=$1
export br_ver=$2
export WORKDIR=$PWD

sudo apt-get -y install bison flex texinfo build-essential gettext ncurses-dev unzip bzr qemu-kvm cvs quilt 
bzr branch lp:cirros
cd cirros
mkdir -p ../download
ln -snf ../download download
cd $WORKDIR/download && wget http://buildroot.uclibc.org/downloads/buildroot-${br_ver}.tar.gz
cd $WORKDIR/cirros
tar -xvf download/buildroot-${br_ver}.tar.gz
ln -snf buildroot-${br_ver} buildroot
./bin/mkcabundle > src/etc/ssl/certs/ca-certificates.crt
cd buildroot && QUILT_PATCHES=$PWD/../patches-buildroot quilt push -a
cd $WORKDIR/cirros
make ARCH=$ARCH br-source
make ARCH=$ARCH OUT_D=$WORKDIR/cirros/output/$ARCH
if [ "$ARCH" == "i386" ]
then
    wget https://launchpad.net/ubuntu/+archive/primary/+files/linux-image-3.2.0-41-virtual_3.2.0-41.66_i386.deb -O $WORKDIR/download/linux-image-package.deb
elif [ "$ARCH" == "x86_64" ]
then
    wget https://launchpad.net/ubuntu/+archive/primary/+files/linux-image-3.2.0-41-virtual_3.2.0-41.66_amd64.deb -O $WORKDIR/download/linux-image-package.deb
else
    echo "Please enter a valid architecture!"
fi
sed -i 's/cp "${initramfs}.smaller"/cp "${initramfs}"/' $WORKDIR/cirros/bin/bundle
echo -e "mptbase\nmptscsih\nhv_netvsc\nhv_vmbus\nhv_utils\nhv_storvsc\n" >> $WORKDIR/cirros/src/etc/modules
cd $WORKDIR
sudo bash cirros/bin/bundle -v cirros/output/$ARCH/rootfs.tar download/linux-image-package.deb cirros/output/$ARCH/images
qemu-img convert -O raw cirros/output/$ARCH/images/disk.img cirros/output/$ARCH/images/disk-raw.img

