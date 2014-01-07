#!/bin/bash

TEMPEST_CONF="/opt/stack/tempest/etc/tempest.conf"

# Clean all images
IMAGE_UUIDS=$(nova image-list | grep '[0-9az]*-[0-9az]*'|awk '{print $2}'|sed '/^$/d')
for i in "$IMAGE_UUIDS"
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

# image_ref_alt
# image_ref


#tempest.conf         tempest.conf.sample  
#ubuntu@devstack-14746:~$ ls /opt/stack/tempest/etc/tempest.conf

if [ ! -e "$TEMPEST_CONF" ]
then
    cp "$TEMPEST_CONF.sample" "$TEMPEST_CONF"
fi

sed -i 's/^image_ref_alt =.*/image_ref_alt = '$CIRROS_UUID'/g' "$TEMPEST_CONF"
sed -i 's/^image_ref =.*/image_ref = '$CIRROS_UUID'/g' "$TEMPEST_CONF"
