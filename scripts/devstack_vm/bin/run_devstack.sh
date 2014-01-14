#!/bin/bash

set -x

sudo ifconfig eth1 promisc up
sudo ifconfig eth2 promisc up

LOCALRC="/home/ubuntu/devstack/localrc"

if [ -e "$LOCALRC" ]
then
        MYIP=$(/sbin/ifconfig eth0 2>/dev/null| grep "inet addr:" 2>/dev/null| sed 's/.*inet addr://g;s/ .*//g' 2>/dev/null)
        [ -z "$MYIP" ] && exit 1
        sed -i 's/^HOST_IP=.*/HOST_IP='$MYIP'/g' "$LOCALRC"
fi

cd /home/ubuntu/devstack
./unstack.sh
./stack.sh
