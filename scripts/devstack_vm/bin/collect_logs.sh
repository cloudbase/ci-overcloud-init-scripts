#!/bin/bash


TAR=$(which tar)
GZIP=$(which gzip)

DEVSTACK_LOGS="/opt/stack/logs/screen"
HYPERV_LOGS="/openstack"
TEMPEST_LOGS="/home/ubuntu/tempest"

LOG_DST="/home/ubuntu/aggregate"

function emit_error() {
    echo $1
    exit 1
}

function archive_devstack() {
    for i in `ls -A $DEVSTACK_LOGS`
    do
        if [ -h "$DEVSTACK_LOGS/$i" ]
        then
                REAL=$(readlink "$DEVSTACK_LOGS/$i")
                $GZIP "$REAL" -c > "$LOG_DST/$i.gz" || emit_error "Failed to archive devstack logs"
        fi
    done
}

function archive_hyperv_logs() {
    $TAR -czf "$LOG_DST/HyperV-compute-logs.tar.gz" "$HYPERV_LOGS" || emit_error "Failed to archive hyperv logs"
}


function archive_tempest_files() {
    for i in `ls -A $TEMPEST_LOGS`
    do
        $GZIP "$TEMPEST_LOGS/$i" -c > "$LOG_DST/$i.gz" || emit_error "Failed to archive tempest logs"
    done
    $GZIP /home/ubuntu/exclude-tests.txt -c > "$LOG_DST/exclude-tests.txt.gz" || emit_error "Failed to archive excluded tests"
}

# Clean
[ -d "$LOG_DST" ] && rm -rf "$LOG_DST"
mkdir -p "$LOG_DST"

archive_devstack
archive_hyperv_logs
archive_tempest_files

$TAR -czf "$LOG_DST.tar.gz"  "$LOG_DST" || emit_error "Failed to archive aggregate logs"

exit 0
