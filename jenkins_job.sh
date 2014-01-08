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
    exec_with_retry "nc -z -w$TIMEOUT $HOST $PORT" 10 5
}

run_ssh_cmd () {
    SSHUSER_HOST=$1
    SSHKEY=$2
    CMD=$3
    ssh -t -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -i $SSHKEY $SSHUSER_HOST "$CMD"
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

source /home/jenkins-slave/keystonerc_admin

FLOATING_IP=$(nova floating-ip-list| grep "None.*None.*ext_net" | awk '{print $2}'|tail -n 1)

if [ -z "$FLOATING_IP" ]
then
	FLOATING_IP=$(nova floating-ip-create ext_net | awk '{print $2}'|sed '/^$/d' | tail -n 1) || echo "Failed to alocate floating IP" && exit 1
fi

NAME="devstack-$RANDOM"
NET_ID=$(nova net-list | grep net1| awk '{print $2}')

echo "Deploying devstack $NAME"
nova boot --flavor m1.medium --image devstack --key-name admin --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll > /dev/null 2>&1
FIXED_IP=$(nova show "$NAME" | grep "net1 network" | awk '{print $5}')

nova add-floating-ip "$NAME" "$FLOATING_IP"

nova interface-attach --net-id "$NET_ID" "$NAME"
nova interface-attach --net-id "$NET_ID" "$NAME"

wait_for_listening_port $FLOATING_IP 22 5
sleep 5

#scp -o "StrictHostKeyChecking no" -i /home/jenkins-slave/admin-msft.pem /home/jenkins-slave/update_devstack_repos.sh ubuntu@$FLOATING_IP:/home/ubuntu/bin/update_devstack_repos.sh

run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "/home/ubuntu/bin/update_devstack_repos.sh" 1

ZUUL_SITE=`echo "$ZUUL_URL" |sed 's/.\{2\}$//'`

run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem  "/home/ubuntu/bin/gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT" 1

#run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "echo Q_PLUGIN=ml2 >> /home/ubuntu/devstack/localrc" 1
#run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "echo Q_ML2_PLUGIN_MECHANISM_DRIVERS=openvswitch,hyperv >> /home/ubuntu/devstack/localrc" 1

run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "cd /home/ubuntu/bin/run_devstack.sh" 5

#echo export OS_USERNAME=admin > /home/jenkins-slave/keystonerc_$NAME
#echo export OS_TENANT_NAME=admin >> /home/jenkins-slave/keystonerc_$NAME
#echo export OS_PASSWORD=Passw0rd >> /home/jenkins-slave/keystonerc_$NAME
#echo export OS_AUTH_URL=http://$FIXED_IP:35357/v2.0/ >> /home/jenkins-slave/keystonerc_$NAME
#scp -o "StrictHostKeyChecking no" -i /home/jenkins-slave/admin-msft.pem /home/jenkins-slave/keystonerc_$NAME ubuntu@$FLOATING_IP:/home/ubuntu/keystonerc
#run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "source /home/ubuntu/keystonerc && /home/ubuntu/bin/post_stack.sh" 5

run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "/home/ubuntu/bin/post_stack.sh" 5

run_wsmancmd_with_retry 10.21.7.43 administrator H@rd24G3t "bash C:\OpenStack\devstack\scripts\gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT"
run_wsmancmd_with_retry 10.21.7.43 administrator H@rd24G3t "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\devstack\scripts\create-environment.ps1 $FIXED_IP"

set +e
#ssh -o "StrictHostKeyChecking no" -i /home/jenkins-slave/admin-msft.pem ubuntu@$FLOATING_IP "source /home/ubuntu/keystonerc && /home/ubuntu/bin/run_tests.sh"
ssh -o "StrictHostKeyChecking no" -i /home/jenkins-slave/admin-msft.pem ubuntu@$FLOATING_IP "/home/ubuntu/bin/run_tests.sh"
set -e

run_wsmancmd_with_retry 10.21.7.43 administrator H@rd24G3t "powershell -ExecutionPolicy RemoteSigned C:\OpenStack\devstack\scripts\teardown.ps1"
nova delete "$NAME"

# TO DO
# collect logs from hyperv and devstack
# return collected logs and screen output
