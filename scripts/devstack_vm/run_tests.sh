#!/bin/bash

cd /opt/stack/tempest
testr init
testr run --parallel tempest
