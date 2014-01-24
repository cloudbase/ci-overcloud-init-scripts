#!/bin/bash


TAR=$(which tar)
GZIP=$(which gzip)

DEVSTACK_LOGS="/opt/stack/logs/screen"
HYPERV_LOGS="/openstack"
TEMPEST_LOGS="/home/ubuntu/tempest"

LOG_DST="/home/ubuntu/aggregate"
LOG_DST_DEVSTACK="$LOG_DST/devstack_logs"
LOG_DST_HV="$LOG_DST/HyperV"

function emit_error() {
    echo "ERROR: $1"
    exit 1
}

function emit_warning() {
    echo "WARNING: $1"
    return 0
}

function archive_devstack() {
    if [ ! -d "$LOG_DST_DEVSTACK" ]
    then
        mkdir -p "$LOG_DST_DEVSTACK" || emit_error "Failed to create $LOG_DST_DEVSTACK"
    fi

    for i in `ls -A $DEVSTACK_LOGS`
    do
        if [ -h "$DEVSTACK_LOGS/$i" ]
        then
                REAL=$(readlink "$DEVSTACK_LOGS/$i")
                $GZIP -c "$REAL" > "$LOG_DST_DEVSTACK/$i.gz" || emit_warning "Failed to archive devstack logs"
        fi
    done
}

function archive_hyperv_logs() {
    if [ ! -d "$LOG_DST_HV" ]
    then
        mkdir -p "$LOG_DST_HV"
    fi
    for i in `ls -A "$HYPERV_LOGS"`
    do
        if [ -d "$HYPERV_LOGS/$i" ]
        then
            mkdir -p "$LOG_DST_HV/$i"
            for j in `ls -A "$HYPERV_LOGS/$i"`;
            do
                $GZIP -c "$HYPERV_LOGS/$i/$j" > "$LOG_DST_HV/$i/$j.gz" || emit_warning "Failed to archive $HYPERV_LOGS/$i/$j"
            done
        else
            $GZIP -c "$HYPERV_LOGS/$i" > "$LOG_DST_HV/$i.gz" || emit_warning "Failed to archive $HYPERV_LOGS/$i"
        fi
    done
}


function archive_tempest_files() {
    for i in `ls -A $TEMPEST_LOGS`
    do
        $GZIP "$TEMPEST_LOGS/$i" -c > "$LOG_DST/$i.gz" || emit_error "Failed to archive tempest logs"
    done
}

# Clean
[ -d "$LOG_DST" ] && rm -rf "$LOG_DST"
mkdir -p "$LOG_DST"

archive_devstack
archive_hyperv_logs
archive_tempest_files

pushd "$LOG_DST"
$TAR -czf "$LOG_DST.tar.gz" . || emit_error "Failed to archive aggregate logs"
popd

exit 0
