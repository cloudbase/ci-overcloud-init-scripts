#!/bin/bash

FLOATING_IP=$(nova floating-ip-list| grep "None.*None.*ext_net" | awk '{print $2}'|tail -n 1)

if [ -z "$FLOATING_IP" ]
then
	FLOATING_IP=$(nova floating-ip-create ext_net | awk '{print $2}'|sed '/^$/d' | tail -n 1) || echo "Failed to alocate floating IP" && exit 1
fi

NAME="devstack-$RANDOM"
NET_ID=$(nova net-list | grep net1| awk '{print $2}')

echo "Deploying devstack $NAME"
nova boot --flavor m1.medium --image devstack --key-name admin --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll > /dev/null 2>&1
FIXED_IP=$(nova show "$NAME" | grep "net1 network" | awk '{print $5}')

nova add-floating-ip "$NAME" "$FLOATING_IP"

nova interface-attach --net-id "$NET_ID" "$NAME"
nova interface-attach --net-id "$NET_ID" "$NAME"

echo "$FLOATING_IP,$FIXED_IP"
