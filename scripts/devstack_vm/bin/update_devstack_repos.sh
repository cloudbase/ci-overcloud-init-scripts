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
echo "Branch: $BRANCH"
echo "Project: $PROJECT"
echo "Project Name: $PROJECT_NAME"
DEVSTACK_DIR="/home/ubuntu/devstack"
pushd "$DEVSTACK_DIR"
find . -name *pyc -print0 | xargs -0 rm -f
git reset --hard
git clean -f -d
git fetch
git checkout "$BRANCH" || echo "Failed to switch branch $BRANCH"
git pull
echo "Devstack final branch:"
git branch
echo "Devstack git log:"
git log -10 --pretty=format:"%h - %an, %ae,  %ar : %s"
popd

if [ ! -d "$BASEDIR" ]
then
    echo "This node has not been stacked"
    exit 1
fi

pushd "$BASEDIR"
#clean any .pyc files
find . -name *pyc -print0 | xargs -0 rm -f
# Update all repositories except the one testing the patch.
for i in `ls -A`
do
	if [ "$i" != "$PROJECT_NAME" ]
	then
		pushd "$i"
	        if [ -d ".git" ]
        	then
        		git reset --hard
        		git clean -f -d
        		git fetch
        		git checkout "$BRANCH" || echo "Failed to switch branch $BRANCH"
			git pull
        	fi
		echo "Folder: $BASEDIR/$i"
		echo "Git branch output:"
		git branch
		echo "Git Log output:"
		if ! [[ $i =~ .*noVNC.* ]]
		then
			git status
			git log -10 --pretty=format:"%h - %an, %ae,  %ar : %s"
		fi
		popd
	fi
done

popd
