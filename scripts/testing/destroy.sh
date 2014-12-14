#Get required predefined functions
WORK_DIR=`dirname $0`
CONSOLE_LOG="$HOME/octavian/data/console-$NAME.log"

source $WORK_DIR/../devstack_vm/bin/library.sh
source $HOME/octavian/data/creds.txt
source $HOME/octavian/data/hv_nodes.txt
source $HOME/octavian/data/patch_info.txt
source $HOME/octavian/data/run_params.txt
source /home/jenkins-slave/keystonerc_admin

set +e
echo "Detaching and cleaning Hyper-V node 1" >> $CONSOLE_LOG 2>&1
teardown_hyperv $WINDOWS_USER $WINDOWS_PASSWORD $hyperv01 >> $CONSOLE_LOG 2>&1
echo "Detaching and cleaning Hyper-V node 2" >> $CONSOLE_LOG 2>&1
teardown_hyperv $WINDOWS_USER $WINDOWS_PASSWORD $hyperv02 >> $CONSOLE_LOG 2>&1

echo "Releasing devstack floating IP" >> $CONSOLE_LOG 2>&1
nova remove-floating-ip "$NAME" "$FLOATING_IP" >> $CONSOLE_LOG 2>&1
echo "Removing devstack VM" >> $CONSOLE_LOG 2>&1
nova delete "$NAME" >> $CONSOLE_LOG 2>&1
echo "Releasing allocated VLAN range" >> $CONSOLE_LOG 2>&1
/usr/local/src/ci-overcloud-init-scripts/vlan_allocation.py -r $NAME >> $CONSOLE_LOG 2>&1
echo "Deleting devstack floating IP" >> $CONSOLE_LOG 2>&1
nova floating-ip-delete "$FLOATING_IP" >> $CONSOLE_LOG 2>&1
