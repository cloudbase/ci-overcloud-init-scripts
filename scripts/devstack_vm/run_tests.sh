#!/bin/bash

source /home/ubuntu/.bashrc

cd /opt/stack/tempest
testr init
testr run --parallel tempest
