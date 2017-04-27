#!/usr/bin/env bash

set -x
set -e
set -o nounset

if [[ $# == 0 ]]; then
    echo "usage: $0 [run|check]"
    exit 1
fi

case $1 in
    check)
        ansible-playbook site.yml -f 5 -i staging/hosts --syntax-check 
        ansible-playbook site.yml -f 5 -i staging/hosts --list-hosts 
        ansible-playbook site.yml -f 5 -i staging/hosts --list-tasks
        ;;
    run)
        ansible-playbook site.yml -f 5 -i staging/hosts 
        ;;
    *)
        echo "usage: $0 [run|check]"
        exit 1
        ;;
esac

