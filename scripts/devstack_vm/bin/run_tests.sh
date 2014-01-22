#!/bin/bash

cd /opt/stack/tempest

testr init

mkdir -p /home/ubuntu/tempest

#exclude unsupported tests
testr list-tests tempest.api.compute | grep -v "rescue\|_uptime\|_console_\|AttachInterfaces" > /home/ubuntu/testr.list

testr run --parallel --subunit  --load-list=/home/ubuntu/testr.list |  subunit-2to1  > /home/ubuntu/tempest/subunit-output.log 2>&1
RET=$?
cat /home/ubuntu/tempest/subunit-output.log | /opt/stack/tempest/tools/colorizer.py > /home/ubuntu/tempest/tempest-output.log 2>&1
cd /home/ubuntu/tempest/
python /home/ubuntu/bin/subunit2html.py /home/ubuntu/tempest/subunit-output.log

exit $RET
