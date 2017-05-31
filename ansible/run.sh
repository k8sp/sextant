#!/usr/bin/env bash

set -x
set -e
set -o nounset

function usage() {
    echo "usage: $0 {run|check|limit-run|limit-check} {production|$2} [limted hosts, eg: (master|worker|00-25-90-c0-f7-88)]"
}

if [[ $# == 0 ]]; then
    usage
    exit 1
fi

FORKS=4
WHICH_HOSTS=$2

case $2 in 
    production)
        ;;
    $2)
        ;;
    *)
        usage
        exit 1
        ;;
esac

case $1 in
    check)
        ansible-playbook site.yml -f ${FORKS} -i $2/hosts --syntax-check 
        ansible-playbook site.yml -f ${FORKS} -i $2/hosts --list-hosts  
        ansible-playbook site.yml -f ${FORKS} -i $2/hosts --list-tasks 
        ;;
    run)
        ansible-playbook site.yml -f ${FORKS} -i $2/hosts 
        ;;
    limit-run)
        ansible-playbook site.yml -f ${FORKS} -i $2/hosts  -l $3 
        ;;
    limit-check)
        ansible-playbook site.yml -f ${FORKS} -i $2/hosts --syntax-check -l $3 
        ansible-playbook site.yml -f ${FORKS} -i $2/hosts --list-hosts  -l $3
        ansible-playbook site.yml -f ${FORKS} -i $2/hosts --list-tasks -l $3 
        ;;
    *)
        usage
        exit 1
        ;;
esac

