exec_with_retry2 () {
    MAX_RETRIES=$1
    INTERVAL=$2

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        eval '${@:3} >> /home/jenkins-slave/console-$NAME.log 2>&1' || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
        let COUNTER=COUNTER+1

        if [ -n "$INTERVAL" ]; then
            sleep $INTERVAL
        fi
    done
    return $EXIT
}

exec_with_retry () {
    CMD=$1
    MAX_RETRIES=${2-10}
    INTERVAL=${3-0}

    exec_with_retry2 $MAX_RETRIES $INTERVAL $CMD
}

run_wsmancmd_with_retry () {
    HOST=$1
    USERNAME=$2
    PASSWORD=$3
    CMD=$4

    exec_with_retry "python /home/jenkins-slave/wsman.py -U https://$HOST:5986/wsman -u $USERNAME -p $PASSWORD $CMD"
}

wait_for_listening_port () {
    HOST=$1
    PORT=$2
    TIMEOUT=$3
    exec_with_retry "nc -z -w$TIMEOUT $HOST $PORT" 50 5
}

run_ssh_cmd () {
    SSHUSER_HOST=$1
    SSHKEY=$2
    CMD=$3
    ssh -t -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i $SSHKEY $SSHUSER_HOST "$CMD" >> /home/jenkins-slave/console-$NAME.log 2>&1
}

run_ssh_cmd_with_retry () {
    SSHUSER_HOST=$1
    SSHKEY=$2
    CMD=$3
    INTERVAL=$4
    MAX_RETRIES=10

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        run_ssh_cmd $SSHUSER_HOST $SSHKEY "$CMD" || EXIT=$?
        if [ $EXIT -eq 0 ]; then
            return 0
        fi
        let COUNTER=COUNTER+1

        if [ -n "$INTERVAL" ]; then
            sleep $INTERVAL
        fi
    done
    return $EXIT
}

join_hyperv (){
    set +e
    WIN_USER=$1
    WIN_PASS=$2
    $URL=$3

    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\devstack\scripts\teardown.ps1"
    set -e
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "bash C:\OpenStack\devstack\scripts\gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $Z$
    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\devstack\scripts\create-environment.ps1 -devstackIP $FIXED_IP -branchName $ZUUL_BRANC$
}

teardown_hyperv () {
    WIN_USER=$1
    WIN_PASS=$2
    $URL=$3

    run_wsmancmd_with_retry $URL $WIN_USER $WIN_PASS "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\devstack\scripts\teardown.ps1"
}

