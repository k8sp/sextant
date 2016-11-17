#!/bin/bash
#
# Check for NVIDIA driver updates
#

DRIVER=${1:-367.27}

TRACKS="${2:-alpha beta stable}"
for track in ${TRACKS}
do
  # Can't use $(< because it prints errors for a missing file!
  last=$(cat last.${track} 2>/dev/null)

  # Grab the most recent directory
  curl -s https://${track}.release.core-os.net/amd64-usr/ |
    grep -oE '<a href="[0-9.]+/">' | grep -o '[0-9\.]*' |
    sort -n | tail -1 | while read v; do
      # Use sort -V version comparison
      if [ "${last}" != "$(/bin/echo -e ${v}\\n${last} | sort -rV | head -1)" ]
      then
        # We rely on the previous sorting to build the most recent version last
        bash -x ./build.sh ${DRIVER} ${track} ${v} && echo ${v} > last.${track}
      fi
  done
done
exit
