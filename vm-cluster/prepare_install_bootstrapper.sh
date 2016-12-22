#!/usr/bin/env bash

# In addition to run bsroot.sh to generate bsroot directory, this
# script also creates a SSH key pair and copies it to bootstrapper VM
# and to other VMs via cloud-config file.  So that all these VMs can
# SSH to each other without password.

# Create a temporary directory in OS X or
# Linux. c.f. http://unix.stackexchange.com/questions/30091/fix-or-alternative-for-mktemp-in-os-x
TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t '/tmp')

# Generate the SSH public/private key pair.
rm -rf $TMPDIR/*
ssh-keygen -t rsa -f $TMPDIR/id_rsa -P ''

# Replace the public key into cluster-desc.yml.template and generate cluster-desc.yml
PUB_KEY=$(cat $TMPDIR/id_rsa.pub)
SEXTANT_DIR=$GOPATH/src/github.com/k8sp/sextant
sed -e 's#<SSH_KEY>#'"$PUB_KEY"'#' $SEXTANT_DIR/vm-cluster/cluster-desc.yml.template > $SEXTANT_DIR/cluster-desc.yml

# Generate $SEXTANT_DIR/bsroot
cd $SEXTANT_DIR
./bsroot.sh $SEXTANT_DIR/cluster-desc.yml

# Put SSH keys into $SEXTANT_DIR/bsroot, which will be mounted to the bootstrapper VM.
mkdir -p $SEXTANT_DIR/bsroot/vm-keys
mv $TMPDIR/* $SEXTANT_DIR/bsroot/vm-keys
