#!/bin/bash

/sbin/iptables -t nat -I POSTROUTING 1 -o eth0 -j MASQUERADE
/sbin/iptables -I FORWARD 1 -i eth0 -o br100 -m state --state RELATED,ESTABLISHED -j ACCEPT
/sbin/iptables -I FORWARD 2 -i br100 -o eth0 -j ACCEPT

/sbin/iptables -I INPUT -p tcp -j ACCEPT
/sbin/iptables -I INPUT -p udp -j ACCEPT
/sbin/iptables -I INPUT -p icmp -j ACCEPT
