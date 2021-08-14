#!/bin/bash
# Wait for a file to arrive and once is there process it
# Author: Jose Vicente Nunez Zuleta
test -x /usr/bin/jq || exit 100
LSHW_FILE="$HOME/lshw.json"
# Enable the debug just to show what is going on...
trap "set +x" QUIT EXIT
set -x
while [ ! -f "$LSHW_FILE" ]; do
    sleep 30
done
/usr/bin/jq ".|.capabilities" "$LSHW_FILE"|| exit 100
