#!/usr/bin/env bash

set -x
set -o nounset

ansible-playbook site.yaml -f 5 -i stage #--list-hosts

