#!/bin/bash

zip ceph-install.zip ./install*.sh
scp ceph-install.zip atlas@10.10.10.192:~/install-ceph/

