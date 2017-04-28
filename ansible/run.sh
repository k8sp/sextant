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
        ansible-playbook site.yml -f 5 -i staging/hosts --syntax-check -l worker
        ansible-playbook site.yml -f 5 -i staging/hosts --list-hosts  -l worker
        ansible-playbook site.yml -f 5 -i staging/hosts --list-tasks -l worker
        ;;
    run)
        ansible-playbook site.yml -f 5 -i staging/hosts  -l worker
        ;;
    *)
        echo "usage: $0 [run|check]"
        exit 1
        ;;
esac

