#!/bin/bash

cd /opt/stack/tempest
testr init
testr run --parallel tempest.api.compute --load-list=/home/ubuntu/tests_clean
#testr run tempest.api.compute.admin.test_flavors.FlavorsAdminTestJSON.test_create_flavor_with_int_id
#testr run tempest.api.compute.admin.test_hypervisor.HypervisorAdminTestXML.test_get_hypervisor_uptime

