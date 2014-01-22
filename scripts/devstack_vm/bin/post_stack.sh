#!/bin/bash

set -x

TEMPEST_CONF="/opt/stack/tempest/etc/tempest.conf"

# Clean all images
IMAGE_UUIDS=$(nova image-list | grep '[0-9az]*-[0-9az]*'|awk '{print $2}'|sed '/^$/d')
for i in $IMAGE_UUIDS
do
    nova image-delete $i
done

# Upload Cirros VHD

CIRROS_UUID=$(glance image-create --property hypervisor_type=hyperv --name "cirros" --container-format bare --disk-format vhd --is-public True --file /home/ubuntu/cirros-0.3.0-x86_64-disk.vhd  | grep "id " | awk '{print $4}')

if [ $? -ne 0 ]
then
    echo "Failed to upload cirros image"
    exit 1
fi


neutron router-gateway-clear router1 > /dev/null 2>&1
SUBNETS=$(neutron subnet-list | grep start | awk '{print $2}')
for i in $SUBNETS
do
    neutron router-interface-delete router1 $i >/dev/null 2>&1
    neutron subnet-delete $i > /dev/null 2>&1
done

NETS=$(neutron net-list | awk '{print $2}' | sed -n '/\([a-z0-9]\)\{8\}-\(\([a-z0-9]\)\{4\}-\)\{3\}\([0-9a-z]\)\{12\}/p')

for i in $NETS
do
    neutron net-delete $i
done


NETID1=`neutron net-create private | awk '{if (NR == 6) {print $4}}'`
EXTNETID1=`neutron  net-create public --router:external=True | awk '{if (NR == 6) {print $4}}'`
SUBNETID1=`neutron  subnet-create private 10.0.0.0/24 --dns_nameservers list=true 8.8.8.8 | awk '{if (NR == 11) {print $4}}'`
SUBNETID2=`neutron  subnet-create public --allocation-pool start=172.24.4.2,end=172.24.4.254 --gateway 172.24.4.1 172.24.4.0/24 --enable_dhcp=False | awk '{if (NR == 11) {print $4}}'`
neutron router-interface-add router1 $SUBNETID1 > /dev/null 2>&1
neutron router-gateway-set router1 $EXTNETID1 > /dev/null 2>&1


if [ ! -e "$TEMPEST_CONF" ]
then
    cp "$TEMPEST_CONF.sample" "$TEMPEST_CONF"
fi

sed -i 's/^image_ref_alt =.*/image_ref_alt = '$CIRROS_UUID'/g' "$TEMPEST_CONF"
sed -i 's/^image_ref =.*/image_ref = '$CIRROS_UUID'/g' "$TEMPEST_CONF"
sed -i 's/^public_network_id =.*/public_network_id = '$EXTNETID1'/g' "$TEMPEST_CONF"


nova flavor-delete m1.nano
nova flavor-delete m1.micro
nova flavor-create --ephemeral 0 --rxtx-factor 1.0 --is-public True m1.nano 42 64 1 1
nova flavor-create --ephemeral 0 --rxtx-factor 1.0 --is-public True m1.micro 84 128 1 1
nova quota-class-update --instances 50 --cores 100 --ram $((51200*4)) --floating-ips 50 --security-groups 50 --security-group-rules 100 default
cinder quota-class-update --snapshots 50 --volumes 50 --gigabytes 2000 default
