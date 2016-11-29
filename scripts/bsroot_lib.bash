#!/usr/bin/env bash

# check_prerequisites checks for required software packages.
function check_prerequisites() {
    printf "Checking prerequisites ... "
    local err=0
    for tool in wget tar gpg docker tr go make; do
        command -v $tool >/dev/null 2>&1 || { echo "Install $tool before run this script"; err=1; }
    done
    if [[ $err -ne 0 ]]; then
        exit 1
    fi
    echo "Done"
}

# parse_yaml was shamelessly stolen from
# https://gist.github.com/pkuczynski/8665367.  It encapsulates a AWK
# script which converts a .yaml file into a .bash file, where each
# bash variable corresponds to a key-value pair in the .yaml file.
# 
# For example, the following invocation generates parseResult.bash,
# where every bash variable's name is composed of the prefix,
# cluster_desc_, and the key name (including all its ancestor keys).
# 
#    parse_yaml example.yaml "cluster_desc_" > parseResult.bash
# 

## derived from https://gist.github.com/epiloque/8cf512c6d64641bde388
## works for arrays of hashes, as long as the hashes do not have arrays
parse_yaml() {
    local prefix=$2
    local s
    local w
    local fs
    s='[[:space:]]*'
    w='[a-zA-Z0-9_]*'
    fs="$(echo @|tr @ '\034')"
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
    awk -F"$fs" '{
      indent = length($1)/2;
      if (length($2) == 0) { conj[indent]="+";} else {conj[indent]="";}
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
              vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
              printf("%s%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, conj[indent-1],$3);
      }
    }' | sed 's/_=/+=/g'
}

# load_yaml calls parse_yaml to convert a .yaml file into a temporary
# .bash file, run the temporary .bash file, and delete it.  So we will
# have bash variables defined and whose values are values in the .yaml
# file.  For example, the following invocation creates some bash
# variables, each corresponds to a key-value pair in the .yaml file.
#
#   load_yaml example.yaml "cluster_desc_"
# 
function load_yaml() {
    local yaml=$1
    local prefix=$2
    local parsedYaml=$(mktemp /tmp/bsroot-parse-yaml.XXXXX)
    parse_yaml $yaml $prefix > $parsedYaml
    source $parsedYaml
    rm $parsedYaml
}

