#Get required predefined functions
WORK_DIR = `dirname $0`
CONSOLE_LOG = "$WORK_DIR/console-$NAME.log"

source $WORK_DIR/../devstack_vm/bin/library.sh
source $WORK_DIR/data/creds.txt
source $WORK_DIR/data/hv_nodes.txt
source $WORK_DIR/data/patch_info.txt
source $WORK_DIR/run_params.txt
source /home/jenkins-slave/keystonerc_admin

set +e
echo "Releasing devstack floating IP" >> $CONSOLE_LOG 2>&1
nova remove-floating-ip "$NAME" "$FLOATING_IP" >> $CONSOLE_LOG 2>&1
echo "Removing devstack VM" >> $CONSOLE_LOG 2>&1
nova delete "$NAME" >> $CONSOLE_LOG 2>&1
echo "Releasing allocated VLAN range" >> $CONSOLE_LOG 2>&1
/usr/local/src/ci-overcloud-init-scripts/vlan_allocation.py -r $NAME >> $CONSOLE_LOG 2>&1
echo "Deleting devstack floating IP" >> $CONSOLE_LOG 2>&1
nova floating-ip-delete "$FLOATING_IP" >> $CONSOLE_LOG 2>&1