set +e

echo "Detaching and cleaning Hyper-V node 1"
teardown_hyperv $WINDOWS_USER $WINDOWS_PASSWORD $hyperv01
echo "Detaching and cleaning Hyper-V node 2"
teardown_hyperv $WINDOWS_USER $WINDOWS_PASSWORD $hyperv02


echo "Collecting logs"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$FLOATING_IP "/home/ubuntu/bin/collect_logs.sh"

echo "Creating logs destination folder"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "if [ ! -d /srv/logs/$ZUUL_CHANGE/$ZUUL_PATCHSET ]; then mkdir -p /srv/logs/$ZUUL_CHANGE/$ZUUL_PATCHSET; else rm -rf /srv/logs/$ZUUL_CHANGE/$ZUUL_PATCHSET/*; fi"

echo "Downloading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$FLOATING_IP:/home/ubuntu/aggregate.tar.gz "aggregate-$NAME.tar.gz"

echo "Uploading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "aggregate-$NAME.tar.gz" logs@logs.openstack.tld:/srv/logs/$ZUUL_CHANGE/$ZUUL_PATCHSET/aggregate-logs.tar.gz
gzip -9 /home/jenkins-slave/console-$NAME.log
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "/home/jenkins-slave/console-$NAME.log.gz" logs@logs.openstack.tld:/srv/logs/$ZUUL_CHANGE/$ZUUL_PATCHSET/console.log.gz && rm -f /home/jenkins-slave/console-$NAME.log.gz

echo "Extracting logs"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "tar -xzf /srv/logs/$ZUUL_CHANGE/$ZUUL_PATCHSET/aggregate-logs.tar.gz -C /srv/logs/$ZUUL_CHANGE/$ZUUL_PATCHSET/"

echo "Fixing permissions on all log files"
ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld "chmod a+rx -R /srv/logs/$ZUUL_CHANGE/$ZUUL_PATCHSET/"

echo "Releasing devstack floating IP"
nova remove-floating-ip "$NAME" "$FLOATING_IP"
echo "Removing devstack VM"
nova delete "$NAME"
echo "Releasing the VLAN range"
/usr/local/src/ci-overcloud-init-scripts/vlan_allocation.py -r $NAME
echo "Deleting devstack floating IP"
nova floating-ip-delete "$FLOATING_IP"

set -e
