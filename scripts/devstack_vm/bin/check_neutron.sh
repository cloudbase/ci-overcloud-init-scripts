#!/bin/bash

source /home/ubuntu/keystonerc

NEUTRON_COUNT=$(neutron agent-list | grep -c "HyperV agent.*:-)")

if [ "$NOVA_COUNT" != 2 ]
then
    exit 1
fi
