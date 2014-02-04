#!/bin/bash

BASEDIR="/opt/stack"
BRANCH="$1"


if [ ! -d "$BASEDIR" ]
then
    echo "This node has not been stacked"
    exit 1
fi

pushd "$BASEDIR"

# Update all repositories except nova
for i in `ls -A`
do
	if [ "$i" != "nova" ]
	then
		pushd "$i"
        if [ -d ".git" ]
        then
            git fetch
            if [ ! -z "$BRANCH" ]
            then
                git checkout "$BRANCH" || echo "Failed to switch branch"
            fi
    		git pull
        fi
		popd
	fi
done

popd
