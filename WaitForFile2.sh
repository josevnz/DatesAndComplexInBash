#!/bin/bash
# Wait for a file to arrive and once is there process it
# Author: Jose Vicente Nunez Zuleta
test -x /usr/bin/jq || exit 100
test -x /usr/bin/inotifywait|| exit 100
test -x /usr/bin/dirname|| exit 100
LSHW_FILE="$HOME/lshw.json"
while [ ! -f "$LSHW_FILE" ]; do
    test "$(/usr/bin/inotifywait --timeout 28800 --quiet --syslog --event close_write "$(/usr/bin/dirname "$LSHW_FILE")" --format '%w%f')" == "$LSHW_FILE" && break
done
/usr/bin/jq ".|.capabilities" "$LSHW_FILE"|| exit 100
