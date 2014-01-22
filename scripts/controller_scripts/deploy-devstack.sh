#!/bin/bash

set -x

function emit_error(){
    echo "$1"
    exit 1
}

FLOATING_IP=$(nova floating-ip-list| grep "None.*None.*ext_net" | awk '{print $2}'|tail -n 1)

if [ -z "$FLOATING_IP" ]
then
	FLOATING_IP=$(nova floating-ip-create ext_net | awk '{print $2}'|sed '/^$/d' | tail -n 1) || echo "Failed to alocate floating IP" 
fi

NAME="devstack-$RANDOM"
NET_ID=$(nova net-list | grep net1| awk '{print $2}')
if [ $? -ne 0 ] || [ -z $NET_ID ]
then
    echo "Failed to get NET_ID for net1"
    exit 1
fi

echo "Deploying devstack $NAME"
OUTPUT=$(nova boot --flavor m1.medium --image devstack --key-name admin --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll 2>&1)
if [ $? -ne 0 ]
then
    echo "Failed to create devstack instance:"
    echo "$OUTPUT"
    nova show "$NAME"
    nova delete "$NAME" > /dev/null 2>&1
    exit 1
fi
FIXED_IP=$(nova show "$NAME" | grep "net1 network" | awk '{print $5}')

nova add-floating-ip "$NAME" "$FLOATING_IP" || emit_error "failed to add floating IP"

nova interface-attach --net-id "$NET_ID" "$NAME" || emit_error "Failed to attach interface"
nova interface-attach --net-id "$NET_ID" "$NAME" || emit_error "Failed to attach interface"

echo "$FLOATING_IP $FIXED_IP"
