#!/bin/bash

source /home/ubuntu/.bashrc

cd /home/ubuntu/devstack
./unstack.sh
./stack.sh
