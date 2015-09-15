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

array_to_regex()
{
    local ar=(${@})
    local regex=""

    for s in "${ar[@]}"
    do
        if [ "$regex" ]; then
            regex+="\\|"
        fi
        regex+="^"$(echo $s | sed -e 's/[]\/$*.^|[]/\\&/g')
    done
    echo $regex
}

test_for_nova (){
    if [ -f "$EXCLUDED_TESTS" ]; then
        exclude_tests=(`awk 'NF && $1!~/^#/' $EXCLUDED_TESTS`)
    fi
    exclude_regex=$(array_to_regex ${exclude_tests[@]})
    testr list-tests | grep -v $exclude_regex > "$RUN_TESTS_LIST"
    res=$?
    if [ $res -ne 0 ]; then
        echo "failed to generate list of tests"
        exit $res
    fi
}

test_for_neutron () {
    # Run tests list
    echo '# Due to neutron project split:' >> "$EXCLUDED_TESTS"
    testr list-tests tempest.api.network | grep "network.test_vpnaas_extensions" >> "$EXCLUDED_TESTS"
    res=$?
    if [ $res -ne 0 ]; then
        echo "failed to generate list of tests"
        exit $res
    fi
    testr list-tests tempest.api.network | grep -v "network.test_vpnaas_extensions" > "$RUN_TESTS_LIST"
    res=$?
    if [ $res -ne 0 ]; then
        echo "failed to generate list of tests"
        exit $res
    fi
}

cd /opt/stack/tempest

#Install tempest_lib
sudo pip install tempest-lib

testr init

TEMPEST_DIR="/home/ubuntu/tempest"
EXCLUDED_TESTS="/home/ubuntu/exclude-tests.txt"
RUN_TESTS_LIST="$TEMPEST_DIR/test_list.txt"
mkdir -p "$TEMPEST_DIR"
cp $EXCLUDED_TESTS $TEMPEST_DIR

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
