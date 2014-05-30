#!/bin/bash

PROJECT="openstack/nova"

while [ $# -gt 0 ];
do
    case $1 in
        --build-for)
            PROJECT=$2
            shift;;
    esac
    shift
done

PROJECT_NAME=$(basename $PROJECT)

test_for_nova (){
    # make a list of excluded tests.
    echo '# Under investigation' >> "$EXCLUDED_TESTS"
    testr list-tests tempest | grep "test_resize_server\|verify_resize_state" >> "$EXCLUDED_TESTS"
    testr list-tests tempest | grep "test_get_hypervisor_show_details" >> "$EXCLUDED_TESTS"
#    testr list-tests tempest | grep "scenario\|test_metering_extensions\|test_neutron_meter_label" >> "$EXCLUDED_TESTS"
    testr list-tests tempest | grep "scenario\|test_metering_extensions\|tempest.thirdparty.boto.test_ec2_instance_run\|test_live_block_migration\|test_fwaas_extensions\|test_delete_server_while_in_attached_volume\|test_list_migrations_in_flavor_resize_situation\|test_delete_server_while_in_attached_volume\|tempest.api.orchestration.stacks\|test_list_servers_by_changes_since" >> "$EXCLUDED_TESTS"
    # Unimplemented
    echo '# Not implemented' >> "$EXCLUDED_TESTS"
    testr list-tests tempest | grep "rescue\|_uptime\|_console_\|AttachInterfaces\|VolumesBackupsTest" >> "$EXCLUDED_TESTS" || echo "failed to generate exclude list"
#    echo '# AMI images not supported' >> "$EXCLUDED_TESTS"
#    testr list-tests tempest | grep "TestMinimumBasicScenario" >> "$EXCLUDED_TESTS" || echo "failed to generate exclude list"
    # Run tests list
    #testr list-tests tempest | grep -v "scenario\|rescue\|_uptime\|_console_\|AttachInterfaces\|test_metering_extensions\|test_neutron_meter_label" > "$RUN_TESTS_LIST" || echo "failed to generate list of tests"
    testr list-tests tempest | grep -v "scenario\|rescue\|_uptime\|_console_\|AttachInterfaces\|test_metering_extensions\|VolumesBackupsTest\|tempest.thirdparty.boto.test_ec2_instance_run\|test_live_block_migration\|test_resize_server\|verify_resize_state\|test_get_hypervisor_show_details\|test_fwaas_extensions\|test_delete_server_while_in_attached_volume\|test_list_migrations_in_flavor_resize_situation\|test_delete_server_while_in_attached_volume\|tempest.api.orchestration.stacks\|test_list_servers_by_changes_since" > "$RUN_TESTS_LIST" || echo "failed to generate list of tests"
}

test_for_neutron () {
    # Run tests list
    echo '# Under investigation' >> "$EXCLUDED_TESTS"
    testr list-tests tempest.api.network | grep "test_fwaas_extensions" >> "$EXCLUDED_TESTS" || echo "failed to generate exclude list"
    testr list-tests tempest.api.network | grep -v "test_fwaas_extensions" > "$RUN_TESTS_LIST" || echo "failed to generate list of tests"
#    testr list-tests tempest.api.network > "$RUN_TESTS_LIST" || echo "failed to generate list of tests"
}

cd /opt/stack/tempest

testr init

TEMPEST_DIR="/home/ubuntu/tempest"
EXCLUDED_TESTS="$TEMPEST_DIR/excluded_tests.txt"
RUN_TESTS_LIST="$TEMPEST_DIR/test_list.txt"
mkdir -p "$TEMPEST_DIR"

if [ "$PROJECT_NAME" == "nova" ]
then
    test_for_nova
elif [ "$PROJECT_NAME" == "neutron" -o "$PROJECT_NAME" == "quantum" ]
then
    test_for_neutron
else
    echo "ERROR: Cannot test for project $PROJECT_NAME"
    exit 1
fi

testr run --parallel --subunit  --load-list=$RUN_TESTS_LIST |  subunit-2to1  > /home/ubuntu/tempest/subunit-output.log 2>&1
cat /home/ubuntu/tempest/subunit-output.log | /opt/stack/tempest/tools/colorizer.py > /home/ubuntu/tempest/tempest-output.log 2>&1
# testr exits with status 0. colorizer.py actually sets correct exit status
RET=$?
cd /home/ubuntu/tempest/
python /home/ubuntu/bin/subunit2html.py /home/ubuntu/tempest/subunit-output.log

exit $RET
