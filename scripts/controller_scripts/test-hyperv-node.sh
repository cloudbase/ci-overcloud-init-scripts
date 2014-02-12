#!/bin/bash


exec_with_retry2 () {
    MAX_RETRIES=$1
    INTERVAL=$2

    COUNTER=0
    while [ $COUNTER -lt $MAX_RETRIES ]; do
        EXIT=0
        eval '${@:3}' || EXIT=$?
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
    exec_with_retry "nc -z -w$TIMEOUT $HOST $PORT" 40 5
}

run_ssh_cmd () {
    SSHUSER_HOST=$1
    SSHKEY=$2
    CMD=$3
    ssh -t -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i $SSHKEY $SSHUSER_HOST "$CMD"
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

teardown_hyperv () {
    run_wsmancmd_with_retry $1 administrator H@rd24G3t "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\devstack\scripts\teardown.ps1"
}

join_hyperv (){
    run_wsmancmd_with_retry $1 administrator H@rd24G3t 'powershell -ExecutionPolicy RemoteSigned C:\OpenStack\devstack\scripts\teardown.ps1'
    run_wsmancmd_with_retry $1 administrator H@rd24G3t 'git clone https://github.com/openstack/nova c:\openstack\build\openstack\nova'
    run_wsmancmd_with_retry $1 administrator H@rd24G3t "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\devstack\scripts\create-environment.ps1 $FIXED_IP"
}

teardown_devstack (){
    nova delete "$NAME"
    nova floating-ip-delete "$FLOATING_IP"
    exit $?
}

teardown_all (){
    teardown_devstack
    for i in $@
    do
        teardown_hyperv $i
    done
}

source /home/jenkins-slave/keystonerc_admin

FLOATING_IP=$(nova floating-ip-create ext_net | awk '{print $2}'|sed '/^$/d' | tail -n 1) || echo "Failed to alocate floating IP"
if [ -z "$FLOATING_IP" ]
then
   exit 1
fi

export NAME="devstack-$RANDOM"


echo "Getting network id for net1"
NET_ID=$(nova net-list | grep net1| awk '{print $2}')

if [ -z "$NET_ID" ]
then
    echo "Failed to get network ID for net1"
    exit 1
fi

echo "Deploying devstack $NAME"
BOOT_OUT=$(nova boot --flavor m1.medium --image devstack --key-name admin --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll 2>&1)

if [ $? -ne 0 ]
then
    echo "Failed to create devstack VM: $NAME"
    echo "$BOOT_OUT"
    nova show "$NAME"
    exit 1
fi

echo "Fetching devstack VM fixed IP address"
export FIXED_IP=$(nova show "$NAME" | grep "net1 network" | awk '{print $5}')

COUNT=0
while [ -z "$FIXED_IP" ]
do
    if [ $COUNT -ge 10 ]
    then
        echo "Failed to get fixed IP"
        exit 1
    fi
    sleep 15
    export FIXED_IP=$(nova show "$NAME" | grep "net1 network" | awk '{print $5}')
    COUNT=$(($COUNT + 1))
done

exec_with_retry "nova add-floating-ip $NAME $FLOATING_IP" 15 5 || teardown_devstack

wait_for_listening_port $FLOATING_IP 22 5 || teardown_devstack
sleep 5

echo "Updating devstack repos"
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "/home/ubuntu/bin/update_devstack_repos.sh" 1 || teardown_devstack
echo "updating nova repo"
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "cd /opt/stack/nova && git pull" 1 || teardown_devstack


# Add 2 more interfaces after successful SSH
nova interface-attach --net-id "$NET_ID" "$NAME" || teardown_devstack
nova interface-attach --net-id "$NET_ID" "$NAME" || teardown_devstack

# copy files to devstack
scp -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i /home/jenkins-slave/admin-msft.pem /usr/local/src/ci-overcloud-init-scripts/scripts/devstack_vm/* ubuntu@$FLOATING_IP:/home/ubuntu/ || teardown_devstack

# run devstack
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem 'source source /home/ubuntu/keystonerc; /home/ubuntu/bin/run_devstack.sh' 5  || teardown_devstack 
# run post_stack
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "source /home/ubuntu/keystonerc && /home/ubuntu/bin/post_stack.sh" 5 || teardown_devstack

# join Hyper-V servers
export FAILURE=0
for i in $@
do
    echo "Joining hyper-v node: $i"
    join_hyperv $i
    if [ $? -ne 0 ]
    then
        echo "Join failed on $i"
        export FAILURE=1
        break
    fi
done

if [ $FAILURE -eq 0 ]
then
    #check for nova join (must equal 2)
    run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem 'source /home/ubuntu/keystonerc; NOVA_COUNT=$(nova service-list | awk "{if (NR > 3) {print \$2 \" \" \$10 }}" | grep -c "nova-compute up"); if [ "$NOVA_COUNT" != '$#' ];then exit 1;fi' 12 || export FAILURE=1
fi

if [ $FAILURE -eq 0 ]
then
    #check for neutron join (must equal 2)
    run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem 'source /home/ubuntu/keystonerc; NOVA_COUNT=$(neutron agent-list | grep -c "HyperV agent.*:-)"); if [ "$NOVA_COUNT" != '$#' ];then exit 1;fi' 12 || export FAILURE=1
fi

if [ $FAILURE -eq 0 ]
then
    echo "Running tests"
    ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i /home/jenkins-slave/admin-msft.pem ubuntu@$FLOATING_IP "source /home/ubuntu/keystonerc && /home/ubuntu/bin/run_tests.sh"  || export FAILURE=$?
fi

for i in $@
do
    teardown_hyperv $i
done


if [ $FAILURE != 0 ]
then
    echo "!!!Test run failed!!!"
    echo "Collecting logs..."
    ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i /home/jenkins-slave/admin-msft.pem ubuntu@$FLOATING_IP "/home/ubuntu/bin/collect_logs.sh"
    scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i /home/jenkins-slave/admin-msft.pem ubuntu@$FLOATING_IP:/home/ubuntu/aggregate.tar.gz "$PWD/aggregate-$NAME.tar.gz"
    echo "Logs saved in $PWD/aggregate-$NAME.tar.gz"
else
    echo "Test run was a success!"
fi

teardown_devstack
