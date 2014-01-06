#!/bin/bash -e

GERRIT_SITE=$1
ZUUL_SITE=$2
GIT_ORIGIN=$3
ZUUL_NEWREV=$4
ZUUL_REF=$5
ZUUL_CHANGE=$6
ZUUL_PROJECT=$7

BUILD_DIR="c:/OpenStack/build/"
PROJECT_DIR="$BUILD_DIR/$ZUUL_PROJECT"

function exit_error(){
    echo $1
    exit 1
}

if [ -z "$GERRIT_SITE" ]
then
  echo "The gerrit site name (eg 'https://review.openstack.org') must be the first argument."
  exit 1
fi

if [ -z "$ZUUL_SITE" ]
then
  echo "The zuul site name (eg 'http://zuul.openstack.org') must be the second argument."
  exit 1
fi

if [ -z "$GIT_ORIGIN" ] || [ -n "$ZUUL_NEWREV" ]
then
    GIT_ORIGIN="$GERRIT_SITE/p"
    # git://git.openstack.org/
    # https://review.openstack.org/p
fi

if [ -z "$ZUUL_REF" ]
then
    echo "This job may only be triggered by Zuul."
    exit 1
fi

if [ ! -z "$ZUUL_CHANGE" ]
then
    echo "Triggered by: $GERRIT_SITE/$ZUUL_CHANGE"
fi

set -x

if [ ! -d "$BUILD_DIR" ]
then
    mkdir -p "$BUILD_DIR" || exit_error "Failed to create build dir"
fi

if [ ! -d "$PROJECT_DIR" ]
then
    mkdir -p  "$PROJECT_DIR" || exit_error "Failed to create project dir"
fi

cd "$PROJECT_DIR" || exit_error "Failed to enter project build dir"

if [[ ! -e .git ]]
then
    ls -a
    rm -fr .[^.]* *
    git clone $GIT_ORIGIN/$ZUUL_PROJECT .
fi
git remote set-url origin $GIT_ORIGIN/$ZUUL_PROJECT

# attempt to work around bugs 925790 and 1229352
if ! git remote update
then
    echo "The remote update failed, so garbage collecting before trying again."
    git gc
    git remote update
fi

git reset --hard
if ! git clean -x -f -d -q ; then
    sleep 1
    git clean -x -f -d -q
fi

if [ -z "$ZUUL_NEWREV" ]
then
    git fetch $ZUUL_SITE/p/$ZUUL_PROJECT $ZUUL_REF
    git checkout FETCH_HEAD
    git reset --hard FETCH_HEAD
    if ! git clean -x -f -d -q ; then
        sleep 1
        git clean -x -f -d -q
    fi
else
    git checkout $ZUUL_NEWREV
    git reset --hard $ZUUL_NEWREV
    if ! git clean -x -f -d -q ; then
        sleep 1
        git clean -x -f -d -q
    fi
fi

if [ -f .gitmodules ]
then
    git submodule init
    git submodule sync
    git submodule update --init
fi
