#!/bin/bash

IP=$1

if [ -z "$IP" ]
then
    echo "Missing IP address"
    exit 1
fi

count=0

function try_port() {

    while true
    do
        # we sleep from the beginning. Devstack has just been spun up
        # unless it resumes from ram, it will not be up instantly
        sleep 5
        nc -w 3 -z "$1" "$2" > /dev/null 2>&1 && break
        count=$(($count + 1))
        if [ $count -eq 24 ]
        then
            return 1
        fi
    done
    return 0
}

try_port $IP 22
