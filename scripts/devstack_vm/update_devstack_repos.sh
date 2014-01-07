#!/bin/bash

BASEDIR="/opt/stack"

if [ ! -d "$BASEDIR" ]
then
    echo "This node has not been stacked"
    exit 1
fi

# Update all repositories except nova
for i in `ls -A`
do
	if [ "$i" != "nova" ]
	then
		pushd $i
        if [ -d ".git" ]
        then
    		git pull
        fi
		popd
	fi
done

