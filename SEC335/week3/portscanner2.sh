#!/usr/bin/env bash

# A bunch of stuff copied and pasted from week 2's scanner.sh into last semester's portscanner2.sh.

set -o pipefail
set -o noclobber
set -o errexit
set -o noglob
set +o nounset
if [ -t 2 ] && [ -z "${NO_COLOR+x}" ]; then 
  error_msg () { printf '\e[1;31mERROR: \e[22m%s\e[m\n' "$*" >&2 ; }
else
  error_msg () { printf 'ERROR: %s' "$*" >&2 ; }
fi
set -o nounset

## PARSE OPTIONS
while [ $# -gt 2 ]; do
	if [ "$1" = '--debug' ]; then # lazy debugging implementation that I use rather frequently in shell scripts
		set -x
		shift
	fi
done
if [ $# -ne 2 ]; then
	error_msg "Expected 2 arguments, got $#." >&2
	exit 1
fi

network="$1"
port="$2"


echo "ip,port"

for ip in "$network".{1..254}; do
	if timeout .1 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null; then
	       	echo "$ip,$port"
	fi
done
exit 0
