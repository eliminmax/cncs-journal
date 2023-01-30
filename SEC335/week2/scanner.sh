#!/usr/bin/env bash

# This horrifically overengineered script was brought to you by an Array.

sn="$(basename "$0")" # sn (short for selfname) to use in help and errors

# shell options

# normally, a pipeline's exit code is the last command, but with this, a
# failure earlier on is preserved
set -o pipefail
# don't overwrite existing files with input redirection
set -o noclobber
# exit if any command fails and is not caught with an || and is not in a
# conditional statement
set -o errexit
# globbing disabled
set -o noglob

set +o nounset # don't fail on undeclared variable (will change this shortly)

# error_msg prints an error to stderrr. if stderr is a terminal and NO_COLOR
# is unset, colorize it.
if [ -t 2 ] && [ -z "${NO_COLOR+x}" ]; then 
  error_msg () { printf '\e[1;31mERROR: \e[22m%s\e[m\n' "$*" >&2 ; }
else
  error_msg () { printf 'ERROR: %s' "$*" >&2 ; }
fi
# fail when an undeclared variable is referenced
set -o nounset

# got this list from an nmap --top-ports 10 scan of localhost on my laptop.
top10_ports='21 22 23 25 80 110 139 443 445 3389'

cmd_exists () {
  command -v "$1" &>/dev/null || (error_msg "command '$1' not found" && exit 2)
}

show_help () {
  # deindent to keep in line with the EOF and help text
cat <<EOF
$sn - An overengineered TCP port scanner, written in BASH
Usage: $sn [options] host_file port_file
    OR $sn [options] -t host_file

Options:
  -t, --top-ten: instead of reading ports from port file, use the top 10
        most common ports as reported by NMap
        Those ports are [${top10_ports// /, }].

  -o <format>, --output <format>: output with the specified format, where
        format is one of [csv, json, colorful, verbose, pretty-json].
        The default is csv. Using "pretty-json" requires the "jq" command,
        which does not respect the NO_COLOR environment variable.
        If specified multiple times, the last instance is used.

  -h, --help: print this message.
  
  --: stop parsing arguments (useful if you've done something like call the
        host file "--xX_HISTFILE_Xx--").

  host_file should contain a list of target hosts, separated by whitespace
  
  port_file should contain a list of target ports, separated by whitespace

EOF
}

# ensure that depenedencies are installed
cmd_exists 'getopt'
cmd_exists 'sed'
cmd_exists 'cat'
cmd_exists 'timeout'


# the version of getopt(1) provided by util-linux exits with error code 4 when
# called with -T, allowing us to make sure its the right version

if [ "$(getopt -T ; echo $?)" -ne 4 ]; then
  error_msg 'Requires the util-linux version of getopt' && exit 2
fi

# parse arguments in a 2-step process:
#   1.  Normalize the argument array with getopt (from the util-linux package)
#       so that options come before the '--' field separator and other
#       parameters come after it, and '--long-opt=val' becomes '--long-opt val'
#       for easier parsing.
#   2.  Pass the normalized arguments into a custom parset function

read -ra args <<EOF
$(getopt -u -l 'top-ten,help,output:' -n "$sn" -o 'tho:' -- "$@")
EOF

format=csv # default to CSV output
use_top10=false # default to reading ports from port file

parse_normalized_args () {
  while [ $# -gt 0 ]; do
    case "$1" in
      --) break ;;
      -h|--help) show_help && exit 0 ;;
      -t|--top-ten) use_top10=true ;;
      -o|--output)
        shift
        case "$1" in
          json|csv|colorful|verbose|pretty-json) format="$1" ;;
          *) 
            error_msg "Output format '$1' not supported." 
            show_help >&2
            exit 1 ;;
        esac
        ;;
      *) error_msg "Option '$1' not recognized."
        show_help >&2
        exit 1
        ;;
    esac
    shift
  done

  # loop will always end with '--' as parameter $1, and non-option parameters
  # after it. Here, it shifts one more time, to clear out the '--' separator
  shift

  # attempt to read hosts
  if [ $# -lt 1 ]; then
    error_msg 'No host file specified.'
    show_help >&2
    exit 1
  elif [ -e "$1" ]; then
    read -ra hosts <<<$(cat "$1" | xargs)
  else
    error_msg "Could not find host file '$1'"
    exit 1
  fi

  # attempt to read ports from either $top10_ports or the port file
  if [ "$use_top10" = true ]; then
    read -ra ports <<<$top10_ports
  elif [ $# -lt 2 ]; then
    error_msg 'No port file specified.'
    show_help >&2
    exit 1  
  elif [ -e "$2" ]; then
    read -ra ports <<<$(cat "$2" | xargs)
  else
    error_msg "Could not find port file '$2'"
    exit 1
  fi
}

parse_normalized_args "${args[@]}"

# Define function to scan a port
scan_port() {
  timeout .1 bash -c "echo >/dev/tcp/$1/$2" 2>/dev/null
}

# Define functions for the various output formats
output_csv() {
  printf 'host,port\n'
  for host in "${hosts[@]}"; do
    for port in "${ports[@]}"; do
      if scan_port "$host" "$port" ; then printf '%s,%s\n' "$host" "$port"; fi
    done
  done 
}

output_json() {
  printf '['
  {
    for host in "${hosts[@]}"; do
      printf '{"host": "%s", "ports": [' "$host"
      for port in "${ports[@]}"; do
      if scan_port "$host" "$port"; then printf '%s, ' "$port"; fi
      done
      printf ']}'
    done
    printf ']'
  } | sed -e 's/}{/}, {/g' -e 's/, ]/]/g' # fix comma placement
}

output_colorful() {
  for host in "${hosts[@]}"; do
    printf '\e[1;32m%s\e[m:\n' "$host"
    for port in "${ports[@]}"; do
      if scan_port "$host" "$port"; then printf ' - \e[94m%s\e[m\n' "$port"; fi
    done
  done
}

output_verbose() {
  for host in "${hosts[@]}"; do
    printf 'host %s:\n' "$host"
    for port in "${ports[@]}"; do
      if scan_port "$host" "$port"; then
        printf '  host %s: port %s is open.\n' "$host" "$port"
      else
        printf '  host %s: port %s is not open.\n' "$host" "$port"
      fi
    done
  done
}

case "$format" in
  csv) output_csv ;;
  json) output_json ;;
  colorful|colourful) output_colorful ;; # a bit of mild i18n here
  verbose) output_verbose ;;
  pretty-json) output_json | jq ;;
  *) error_msg 'an impossible error was not so impossible.'; exit 3;;
esac

exit 0

# vi: sw=2 ts=2 sts=2 et ai colorcolumn=80
