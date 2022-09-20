#!/usr/bin/env bash

# Check for --debug argument
if [ "$1" = "--debug" ]; then
	set -x
	shift
fi

# Validate argument count
if [ $# -ne 2 ]; then
	echo "expected 2 arguments, got $#" >&2
	exit 2
fi

# get values from argv
target_network="$1"
dns_server="$2"

echo "dns resolution for $target_network"

for host in "$target_network".{1..254}; do
	# pipe into awk oneliner to remove blank lines and NXDOMAIN messages
	nslookup $host $dns_server | awk '/.+/ && !/NXDOMAIN/ {print $0}'
done
