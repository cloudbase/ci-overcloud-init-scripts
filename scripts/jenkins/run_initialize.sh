#Get required predefined functions
source $SCRIPTS_FOLDER/scripts/jenkins/library.sh

FLOATING_IP=$(nova floating-ip-create ext_net | awk '{print $2}'|sed '/^$/d' | tail -n 1) || echo "Failed to alocate floating IP" >> /home/jenkins-slave/console-$NAME.log 2>&1
if [ -z "$FLOATING_IP" ]
then
   exit 1
fi
echo FLOATING_IP=$FLOATING_IP > /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

UUID=$(python -c "import uuid; print uuid.uuid4().hex")
export NAME="devstack-$UUID"
echo NAME=$NAME >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo NAME=$NAME

NET_ID=$(nova net-list | grep net1| awk '{print $2}')
echo NET_ID=$NET_ID >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

echo FLOATING_IP=$FLOATING_IP > /home/jenkins-slave/console-$NAME.log 2>&1
echo NAME=$NAME >> /home/jenkins-slave/console-$NAME.log 2>&1
echo NET_ID=$NET_ID >> /home/jenkins-slave/console-$NAME.log 2>&1

echo "Deploying devstack $NAME" >> /home/jenkins-slave/console-$NAME.log 2>&1
nova boot --availability-zone nova --flavor m1.medium --image devstack --key-name admin --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll >> /home/jenkins-slave/console-$NAME.log 2>&1

if [ $? -ne 0 ]
then
    echo "Failed to create devstack VM: $NAME" >> /home/jenkins-slave/console-$NAME.log 2>&1
    nova show "$NAME" >> /home/jenkins-slave/console-$NAME.log 2>&1
    exit 1
fi

export VMID=`nova show $NAME | awk '{if (NR == 16) {print $4}}'`
echo VM_ID=$VMID >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt
echo VM_ID=$VMID >> /home/jenkins-slave/console-$NAME.log 2>&1

echo "Fetching devstack VM fixed IP address" >> /home/jenkins-slave/console-$NAME.log 2>&1
FIXED_IP=$(nova show "$NAME" | grep "net1 network" | awk '{print $5}')
export FIXED_IP="${FIXED_IP//,}"

COUNT=0
while [ -z "$FIXED_IP" ]
do
    if [ $COUNT -ge 10 ]
    then
        echo "Failed to get fixed IP" >> /home/jenkins-slave/console-$NAME.log 2>&1
        echo "nova show output:" >> /home/jenkins-slave/console-$NAME.log 2>&1
        nova show "$NAME" >> /home/jenkins-slave/console-$NAME.log 2>&1
        echo "nova console-log output:" >> /home/jenkins-slave/console-$NAME.log 2>&1
        nova console-log "$NAME" >> /home/jenkins-slave/console-$NAME.log 2>&1
        echo "neutron port-list output:" >> /home/jenkins-slave/console-$NAME.log 2>&1
        neutron port-list -D -c device_id -c fixed_ips | grep $VMID >> /home/jenkins-slave/console-$NAME.log 2>&1
        exit 1
    fi
    sleep 15
   FIXED_IP=$(nova show "$NAME" | grep "net1 network" | awk '{print $5}')
   export FIXED_IP="${FIXED_IP//,}"
   COUNT=$(($COUNT + 1))
done

echo FIXED_IP=$FIXED_IP >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

exec_with_retry "nova add-floating-ip $NAME $FLOATING_IP" 15 5

nova show "$NAME" >> /home/jenkins-slave/console-$NAME.log 2>&1


wait_for_listening_port $FLOATING_IP 22 5 || { nova console-log "$NAME" >> /home/jenkins-slave/console-$NAME.log 2>&1; exit 1; }
sleep 5

# copy files to devstack
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/ci-overcloud-init-scripts/scripts/devstack_vm/* ubuntu@$FLOATING_IP:/home/ubuntu/ >> /home/jenkins-slave/console-$NAME.log 2>&1

set +e
VLAN_RANGE=`/usr/local/src/ci-overcloud-init-scripts/vlan_allocation.py -a $NAME`
if [ ! -z "$VLAN_RANGE" ]
then
  run_ssh_cmd_with_retry ubuntu@$FLOATING_IP $DEVSTACK_SSH_KEY "sed -i 's/TENANT_VLAN_RANGE.*/TENANT_VLAN_RANGE='$VLAN_RANGE'/g' /home/ubuntu/devstack/localrc /home/ubuntu/devstack/local.conf" 1
fi
set -e

# Add 2 more interfaces after successful SSH
nova interface-attach --net-id "$NET_ID" "$NAME" >> /home/jenkins-slave/console-$NAME.log 2>&1
nova interface-attach --net-id "$NET_ID" "$NAME" >> /home/jenkins-slave/console-$NAME.log 2>&1

run_ssh_cmd_with_retry ubuntu@$FLOATING_IP $DEVSTACK_SSH_KEY "/home/ubuntu/bin/update_devstack_repos.sh --branch $ZUUL_BRANCH --build-for $ZUUL_PROJECT" 1

scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i $DEVSTACK_SSH_KEY /usr/local/src/ci-overcloud-init-scripts/scripts/devstack_vm/devstack/* ubuntu@$FLOATING_IP:/home/ubuntu/devstack >> /home/jenkins-slave/console-$NAME.log 2>&1

ZUUL_SITE=`echo "$ZUUL_URL" |sed 's/.\{2\}$//'`
echo ZUUL_SITE=$ZUUL_SITE >> /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.$JOB_TYPE.txt

run_ssh_cmd_with_retry ubuntu@$FLOATING_IP $DEVSTACK_SSH_KEY  "/home/ubuntu/bin/gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT" 1

# run devstack
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/keystonerc; /home/ubuntu/bin/run_devstack.sh' 5  
# run post_stack
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP $DEVSTACK_SSH_KEY "source /home/ubuntu/keystonerc && /home/ubuntu/bin/post_stack.sh" 5 

# join Hyper-V servers
echo "win_user: $WINDOWS_USER"
echo "win_pass: $WINDOWS_PASSWORD"
echo "node01: $hyperv01"
echo "node02: $hyperv02"
join_hyperv $WINDOWS_USER $WINDOWS_PASSWORD $hyperv01
join_hyperv $WINDOWS_USER $WINDOWS_PASSWORD $hyperv02

# check for nova join (must equal 2)
# NOTE: the following check fails if there is any node named "up". Since the format returned by nova service-list differs between the openstack releases the awk method (nova service-list | awk "{if (NR > 3) {print \$2 \" \" \$10 }}" | grep -c "nova-compute up") can't be used. 
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/keystonerc; NOVA_COUNT=$(nova service-list | grep nova-compute | grep -c -w up); if [ "$NOVA_COUNT" != 2 ];then nova service-list; exit 1;fi' 12

#check for neutron join (must equal 2)
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP $DEVSTACK_SSH_KEY 'source /home/ubuntu/keystonerc; NEUTRON_COUNT=$(neutron agent-list | grep -c "HyperV agent.*:-)"); if [ "$NEUTRON_COUNT" != 2 ];then neutron agent-list; exit 1;fi' 12

