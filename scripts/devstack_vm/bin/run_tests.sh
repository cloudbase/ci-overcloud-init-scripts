#!/bin/bash

cd /opt/stack/tempest/tempest

mkdir -p /home/ubuntu/tempest
sudo pip install -U nose nose-exclude

nosetests -sv --exclude-test-file=/home/ubuntu/exclude-tests.txt --with-xunit --xunit-file=/home/ubuntu/tempest/results.xml --detailed-errors tempest.api.compute > /home/ubuntu/tempest/tempest-output.log 2>&1

#nosetests -sv --exclude-test-file=/home/ubuntu/exclude-tests.txt --with-xunit --xunit-file=/home/ubuntu/tempest/result1.xml --detailed-errors tempest.api.compute.admin.test_aggregates.AggregatesAdminTestJSON > /home/ubuntu/tempest/tempest-output.log 2>&1

# testr init
# testr run --parallel tempest.api.compute --load-list=/home/ubuntu/tests_clean
#testr run tempest.api.compute.admin.test_flavors.FlavorsAdminTestJSON.test_create_flavor_with_int_id
#testr run tempest.api.compute.admin.test_hypervisor.HypervisorAdminTestXML.test_get_hypervisor_uptime

