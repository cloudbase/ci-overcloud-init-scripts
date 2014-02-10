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
    testr list-tests tempest | grep "TestVolumeBootPattern\|TestAggregatesBasicOps" >> "$EXCLUDED_TESTS"
    # Unimplemented
    echo '# Not implemented' >> "$EXCLUDED_TESTS"
    testr list-tests tempest | grep "rescue\|_uptime\|_console_\|AttachInterfaces" >> "$EXCLUDED_TESTS" || echo "failed to generate exclude list"
    echo '# AMI images not supported' >> "$EXCLUDED_TESTS"
    testr list-tests tempest | grep "TestMinimumBasicScenario" >> "$EXCLUDED_TESTS" || echo "failed to generate exclude list"
    # Run tests list
    testr list-tests tempest | grep -v "TestVolumeBootPattern\|TestAggregatesBasicOps\|TestMinimumBasicScenario\|rescue\|_uptime\|_console_\|AttachInterfaces" > "$RUN_TESTS_LIST" || echo "failed to generate exclude list"    
}

test_for_neutron () {
    # Run tests list
    testr list-tests tempest.api.network > "$RUN_TESTS_LIST" || echo "failed to generate exclude list"
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
else:
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
