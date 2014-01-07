#!/bin/bash

IP=$1

if [ -z "$IP" ]
then
    echo "Missing IP address"
    exit 1
fi

count=0

while true
do
    sleep 30
    nc -w 3 -z "$IP" 22 > /dev/null 2>&1 && break
    count=$(($count + 1))
    if [ $count -eq 4 ]
    then
        exit 1
    fi
done

exit 0
