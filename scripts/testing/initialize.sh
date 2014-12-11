WORK_DIR=`dirname $0`

#Import openstack credentials
source /home/jenkins-slave/keystonerc_admin

#Import library functions
source $WORK_DIR/../devstack_vm/bin/library.sh
source $HOME/octavian/data/creds.txt
source $HOME/octavian/data/hv_nodes.txt
source $HOME/octavian/data/patch_info.txt

#UUID=$(python -c "import uuid; print uuid.uuid4().hex")
export NAME="devstack-test-octavian"
echo NAME=$NAME > $HOME/octavian/data/run_params.txt
CONSOLE_LOG="$HOME/octavian/data/console-$NAME.log"
echo NAME=$NAME > $CONSOLE_LOG 2>&1

echo WORK_DIR=$WORK_DIR >> $CONSOLE_LOG 2>&1

FLOATING_IP=$(nova floating-ip-create public | awk '{print $2}'|sed '/^$/d' | tail -n 1) || echo `date -u +%H:%M:%S` "Failed to alocate floating IP" >> $CONSOLE_LOG 2>&1
if [ -z "$FLOATING_IP" ]
then
   exit 1
fi
echo FLOATING_IP=$FLOATING_IP >> $HOME/octavian/data/run_params.txt
echo FLOATING_IP=$FLOATING_IP >> $CONSOLE_LOG 2>&1

NET_ID=$(nova net-list | grep private| awk '{print $2}')
echo NET_ID=$NET_ID >> $HOME/octavian/data/run_params.txt
echo NET_ID=$NET_ID >> $CONSOLE_LOG 2>&1

echo `date -u +%H:%M:%S` FLOATING_IP=$FLOATING_IP > $CONSOLE_LOG 2>&1
echo `date -u +%H:%M:%S` NAME=$NAME >> $CONSOLE_LOG 2>&1
echo `date -u +%H:%M:%S` NET_ID=$NET_ID >> $CONSOLE_LOG 2>&1
echo `date -u +%H:%M:%S` "Deploying devstack $NAME" >> $CONSOLE_LOG 2>&1

devstack_image="devstack"

echo `date -u +%H:%M:%S` "Image used is: $devstack_image" >> $CONSOLE_LOG 2>&1
echo `date -u +%H:%M:%S` "Deploying devstack $NAME" >> $CONSOLE_LOG 2>&1

nova boot --availability-zone sandbox --flavor m1.medium --image $devstack_image --key-name default --security-groups devstack --nic net-id="$NET_ID" "$NAME" --poll >> $CONSOLE_LOG 2>&1
if [ $? -ne 0 ]
then
    echo `date -u +%H:%M:%S` "Failed to create devstack VM: $NAME" >> $CONSOLE_LOG 2>&1
    nova show "$NAME" >> $CONSOLE_LOG 2>&1
    exit 1
fi

nova show "$NAME" >> $CONSOLE_LOG 2>&1

export VMID=`nova show $NAME | awk '{if (NR == 20) {print $4}}'`
echo VM_ID=$VMID >> $HOME/octavian/data/run_params.txt
echo VM_ID=$VMID >> $CONSOLE_LOG 2>&1

echo `date -u +%H:%M:%S` VM_ID=$VMID >> $CONSOLE_LOG 2>&1

echo `date -u +%H:%M:%S` "Fetching devstack VM fixed IP address" >> $CONSOLE_LOG 2>&1
FIXED_IP=$(nova show "$NAME" | grep "private network" | awk '{print $5}')
export FIXED_IP="${FIXED_IP//,}"

COUNT=0
while [ -z "$FIXED_IP" ]
do
    if [ $COUNT -ge 10 ]
    then
        echo `date -u +%H:%M:%S` "Failed to get fixed IP" >> $CONSOLE_LOG 2>&1
        echo `date -u +%H:%M:%S` "nova show output:" >> $CONSOLE_LOG 2>&1
        nova show "$NAME" >> $CONSOLE_LOG 2>&1
        echo `date -u +%H:%M:%S` "nova console-log output:" >> $CONSOLE_LOG 2>&1
        nova console-log "$NAME" >> $CONSOLE_LOG 2>&1
        echo `date -u +%H:%M:%S` "neutron port-list output:" >> $CONSOLE_LOG 2>&1
        neutron port-list -D -c device_id -c fixed_ips | grep $VMID >> $CONSOLE_LOG 2>&1
        exit 1
    fi
    sleep 15
    export FIXED_IP=$(nova show "$NAME" | grep "private network" | awk '{print $5}')
    COUNT=$(($COUNT + 1))
done

echo FIXED_IP=$FIXED_IP >> $HOME/octavian/data/run_params.txt
echo `date -u +%H:%M:%S` "FIXED_IP=$FIXED_IP" >> $CONSOLE_LOG 2>&1

exec_with_retry "nova add-floating-ip $NAME $FLOATING_IP" 15 5 >> $CONSOLE_LOG 2>&1

echo `date -u +%H:%M:%S` "nova show $NAME:" >> $CONSOLE_LOG 2>&1
nova show "$NAME" >> $CONSOLE_LOG 2>&1

echo "Waiting for answer on port 22 on the VM" >> $CONSOLE_LOG 2>&1
wait_for_listening_port $FLOATING_IP 22 10 >> $CONSOLE_LOG 2>&1 || { echo `date -u +%H:%M:%S` "nova console-log $NAME:" >> $CONSOLE_LOG 2>&1; nova console-log "$NAME" >> $CONSOLE_LOG 2>&1; exit 1; }
sleep 5

#set timezone to UTC
echo "Set timezone to UTC on the devstack VM" >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "sudo ln -fs /usr/share/zoneinfo/UTC /etc/localtime" 1 >> $CONSOLE_LOG 2>&1

# copy files to devstack
echo "Copy required scripts to devstack VM" >> $CONSOLE_LOG 2>&1
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i /home/jenkins-slave/admin-msft.pem ../devstack_vm/* ubuntu@$FLOATING_IP:/home/ubuntu/ >> $CONSOLE_LOG 2>&1

set +e
#get VLAN range for VM
VLAN_RANGE=`/usr/local/src/ci-overcloud-init-scripts/vlan_allocation.py -a $NAME`
if [ ! -z "$VLAN_RANGE" ]
then
  run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "sed -i 's/TENANT_VLAN_RANGE.*/TENANT_VLAN_RANGE='$VLAN_RANGE'/g' /home/ubuntu/devstack/localrc /home/ubuntu/devstack/local.conf" 1  >> $CONSOLE_LOG 2>&1
fi
echo "Reserving VLAN range for VM. Result:" >> $CONSOLE_LOG 2>&1
echo "VLAN_RANGE=$VLAN_RANGE" >> $CONSOLE_LOG 2>&1
set -e

echo "Set keystonerc values on devstack VM." >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "sed -i 's/export OS_AUTH_URL.*/export OS_AUTH_URL=http:\/\/127.0.0.1:5000\/v2.0\//g' /home/ubuntu/keystonerc" 1 >> $CONSOLE_LOG 2>&1

# Add 2 more interfaces after successful SSH
echo "Adding the additional 2 network interfaces." >> $CONSOLE_LOG 2>&1
nova interface-attach --net-id "$NET_ID" "$NAME" >> $CONSOLE_LOG 2>&1
nova interface-attach --net-id "$NET_ID" "$NAME" >> $CONSOLE_LOG 2>&1

echo "Updating devstack git repos to latest." >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "/home/ubuntu/bin/update_devstack_repos.sh --branch $ZUUL_BRANCH --build-for $ZUUL_PROJECT" 1 >> $CONSOLE_LOG 2>&1

echo "Copying required devstack config files to the devstack VM" >> $CONSOLE_LOG 2>&1
scp -v -r -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -i /home/jenkins-slave/admin-msft.pem ../devstack_vm/devstack/* ubuntu@$FLOATING_IP:/home/ubuntu/devstack >> $CONSOLE_LOG 2>&1

ZUUL_SITE=`echo "$ZUUL_URL" |sed 's/.\{2\}$//'`
echo ZUUL_SITE=$ZUUL_SITE >> $HOME/octavian/data/run_params.txt
echo ZUUL_SITE=$ZUUL_SITE >> $CONSOLE_LOG 2>&1

echo "Run gerrit-git-prep.sh" >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem  "/home/ubuntu/bin/gerrit-git-prep.sh --zuul-site $ZUUL_SITE --gerrit-site $ZUUL_SITE --zuul-ref $ZUUL_REF --zuul-change $ZUUL_CHANGE --zuul-project $ZUUL_PROJECT" 1 >> $CONSOLE_LOG 2>&1

#get locally the vhdx files used by tempest
echo "Fetch the required VM images to be used by tempest." >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "mkdir -p /home/ubuntu/devstack/files/images/" >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "wget http://dl.openstack.tld/cirros-0.3.3-x86_64.vhdx -O /home/ubuntu/devstack/files/images/cirros-0.3.3-x86_64.vhdx" >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "wget http://dl.openstack.tld/Fedora-x86_64-20-20140618-sda.vhdx -O /home/ubuntu/devstack/files/images/Fedora-x86_64-20-20140618-sda.vhdx" >> $CONSOLE_LOG 2>&1

#make local.sh executable
echo "Make sure that local.sh has executable bit set." >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "chmod a+x /home/ubuntu/devstack/local.sh" >> $CONSOLE_LOG 2>&1

# run devstack
echo "Run devstack.sh" >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem 'source /home/ubuntu/keystonerc; /home/ubuntu/bin/run_devstack.sh' 5 >> $CONSOLE_LOG 2>&1
# run post_stack
echo "Run post_stack.sh" >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem "source /home/ubuntu/keystonerc && /home/ubuntu/bin/post_stack.sh" 5 >> $CONSOLE_LOG 2>&1

# join Hyper-V servers
echo `date -u +%H:%M:%S` "Joining Hyper-V node: $hyperv01"
echo `date -u +%H:%M:%S` "Joining Hyper-V node: $hyperv01" >> $CONSOLE_LOG 2>&1
join_hyperv $WINDOWS_USER $WINDOWS_PASSWORD $hyperv01
echo `date -u +%H:%M:%S` "Joining Hyper-V node: $hyperv02"
echo `date -u +%H:%M:%S` "Joining Hyper-V node: $hyperv02" >> $CONSOLE_LOG 2>&1
join_hyperv $WINDOWS_USER $WINDOWS_PASSWORD $hyperv02

#check for nova join (must equal 2)
#run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem 'source /home/ubuntu/keystonerc; NOVA_COUNT=$(nova service-list | awk "{if (NR > 3) {print \$2 \" \" \$10 }}" | grep -c "nova-compute up"); if [ "$NOVA_COUNT" != 2 ];then nova service-list; exit 1;fi' 12
echo "Checking that both hyper-v nodes are registered fine with nova" >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem 'source /home/ubuntu/keystonerc; NOVA_COUNT=$(nova service-list | grep nova-compute | grep -c -w up); if [ "$NOVA_COUNT" != 2 ];then nova service-list; exit 1;fi' 12 >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem 'source /home/ubuntu/keystonerc; nova service-list' 1 >> $CONSOLE_LOG 2>&1
#check for neutron join (must equal 2)
echo "Checking that both hyper-v nodes are registered fine with neutron" >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem 'source /home/ubuntu/keystonerc; NEUTRON_COUNT=$(neutron agent-list | grep -c "HyperV agent.*:-)"); if [ "$NEUTRON_COUNT" != 2 ];then neutron agent-list; exit 1;fi' 12 >> $CONSOLE_LOG 2>&1
run_ssh_cmd_with_retry ubuntu@$FLOATING_IP /home/jenkins-slave/admin-msft.pem 'source /home/ubuntu/keystonerc; neutron agent-list' 1 >> $CONSOLE_LOG 2>&1
