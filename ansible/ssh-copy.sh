#!/bin/bash

set -x 
NODES=$(kubectl get nodes -o name | cut -d '/' -f 2)

for i in $NODES
do
	ssh-copy-id root@$i
done


