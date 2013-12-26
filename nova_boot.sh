NETID1=`neutron net-show net1 | awk '{if (NR == 5) {print $4}}'`

nova boot --flavor 2 --image "CentOS-6.4" --key-name admin --nic net-id=$NETID1 vm1


