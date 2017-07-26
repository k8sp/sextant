#!/bin/bash

set -x 

# for python2.x installs
sudo yum install python-devel.x86_64 -y 
# pyyaml
sudo yum install python-yaml -y
sudo pip install -r requirement.txt


