#!/bin/bash

BASEDIR="/opt/stack"

PROJECT="openstack/nova"
BRANCH="master"

while [ $# -gt 0 ];
do
    case $1 in
        --branch)
            BRANCH=$2
            shift;;
        --build-for)
            PROJECT=$2
            shift;;
    esac
    shift
done

PROJECT_NAME=$(basename $PROJECT)

if [ ! -d "$BASEDIR" ]
then
    echo "This node has not been stacked"
    exit 1
fi

pushd "$BASEDIR"

# Update all repositories except nova
for i in `ls -A`
do
	if [ "$i" != "$PROJECT_NAME" ]
	then
		pushd "$i"
        if [ -d ".git" ]
        then
            git fetch
            git checkout "$BRANCH" || echo "Failed to switch branch"
    		git pull
        fi
		popd
	fi
done

popd
