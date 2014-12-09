#!/bin/bash
# Vlans:
vlan_start=500
vlan_step=25
vlan_stop=999
mysql -u root cbs_data -e "truncate table vlanIds"
for i in `seq $vlan_start $vlan_step $vlan_stop`;do mysql -u root cbs_data -e "insert into vlanIds(vlanStart,vlanEnd) VALUES($i,$(($i+$vlan_step-1)));";done;
