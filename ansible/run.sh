#!/usr/bin/env bash

set -x
set -e
set -o nounset

function usage() {
    echo "usage: $0 [run|check|limit] [limted hosts, eg: (master|worker|00-25-90-c0-f7-88)]"
}

if [[ $# == 0 ]]; then
    usage
    exit 1
fi

FORKS=4

case $1 in
    check)
        ansible-playbook site.yml -f ${FORKS} -i staging/hosts --syntax-check 
        ansible-playbook site.yml -f ${FORKS} -i staging/hosts --list-hosts  
        ansible-playbook site.yml -f ${FORKS} -i staging/hosts --list-tasks 
        ;;
    run)
        ansible-playbook site.yml -f ${FORKS} -i staging/hosts 
        ;;
    limit-run)
        ansible-playbook site.yml -f ${FORKS} -i staging/hosts  -l $2 
        ;;
    limit-check)
        ansible-playbook site.yml -f ${FORKS} -i staging/hosts --syntax-check -l $2 
        ansible-playbook site.yml -f ${FORKS} -i staging/hosts --list-hosts  -l $2 
        ansible-playbook site.yml -f ${FORKS} -i staging/hosts --list-tasks -l $2 
        ;;
    *)
        usage
        exit 1
        ;;
esac

