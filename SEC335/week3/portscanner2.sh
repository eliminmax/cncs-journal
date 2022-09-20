#!/bin/bash

## PARSE OPTIONS
while [ $# -gt 2 ]; do
	if [ "$1" = '--debug' ]; then
		set -x
		shift
	fi
done
if [ $# -ne 2 ]; then
	echo "Expected 2 arguments, got $#" >&2
	exit 1
fi

network="$1"
port="$2"


echo "ip,port"

for ip in "$network".{1..254}; do
	timeout .1 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null && echo "$ip,$port"
done

