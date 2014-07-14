#!/bin/bash

set -x

sudo ifconfig eth1 promisc up
sudo ifconfig eth2 promisc up

HOSTNAME=$(hostname)

sudo sed -i '2i127.0.0.1  '$HOSTNAME'' /etc/hosts

#fix oslo.config problem
cd /opt/stack/oslo.config/
git pull
sudo pip install -U setuptools
sudo python setup.py install

#Update six to latest version
sudo pip install -U six

DEVSTACK_LOGS="/opt/stack/logs/screen"
LOCALRC="/home/ubuntu/devstack/localrc"
LOCALCONF="/home/ubuntu/devstack/local.conf"
PBR_LOC="/opt/stack/pbr"
# Clean devstack logs
rm -f "$DEVSTACK_LOGS/*"
rm -rf "$PBR_LOC"

if [ -e "$LOCALRC" ]
then
        MYIP=$(/sbin/ifconfig eth0 2>/dev/null| grep "inet addr:" 2>/dev/null| sed 's/.*inet addr://g;s/ .*//g' 2>/dev/null)
        [ -z "$MYIP" ] && exit 1
        sed -i 's/^HOST_IP=.*/HOST_IP='$MYIP'/g' "$LOCALRC"
        sed -i 's/^HOST_IP=.*/HOST_IP='$MYIP'/g' "$LOCALCONF"
fi

cd /home/ubuntu/devstack
git pull
sudo easy_install -U pip
./unstack.sh
./stack.sh
