#!/bin/sh

# ----------------------------------------------------------------------------
#  "THE BEER-WARE LICENSE" (Revision 42):
#  <pmurray@nevada.net.nz> wrote this file. As long as you retain this notice
#  you can do whatever you want with this stuff. If we meet some day, and you
#  think this stuff is worth it, you can buy me a beer in return. Phil Murray.
# ----------------------------------------------------------------------------
#
#  check_carp.sh v1.0
#

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

INTERFACE=
VHID="[0-9]+"
EXPECTED_STATE=MASTER

usage()
{
  echo "Usage: check_carp [ -v VHID ]
                  [ -s STATE ] interface"
  exit 2
}

report() {
  CODE=$1
  RESULT=$2
  MESSAGE=$3

  echo "CARP ${RESULT} - ${MESSAGE}"
  exit $1
}


PARSED_ARGUMENTS=$(getopt v:s: $*)
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

eval set -- "$PARSED_ARGUMENTS"
while :; do
  case "$1" in
    -v)   VHID=$2           ; shift; shift  ;;
    -s)   EXPECTED_STATE=$2 ; shift; shift  ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

INTERFACE=$( echo "${@}" | sed 's/[^a-z0-9]//g' )

if [ "s" = "s${INTERFACE}" ]; then
  usage;
fi

if result=$(ifconfig ${INTERFACE} 2>&1); then
  vhids=$(echo "${result}" | awk "/carp:.*vhid ${VHID}/ { print \$2 \" \"  \$4 \" \" \$6 \" \" \$8 }")
  echo "${vhids}" | { while read carp_state vhid advbase advskew; do
    if [ ! -z "${vhid}" ]; then
      VHID=$vhid

      if [ $carp_state = $EXPECTED_STATE ]; then
        MSG="OK"
        RET=$STATE_OK
      else
        MSG="CRITICAL"
        RET=$STATE_CRITICAL
      fi


      report $RET $MSG "state ${carp_state} (vhid ${VHID} advbase ${advbase} advskew ${advskew})"
    else
      output="can't find CARP state for ${INTERFACE}"
      report $STATE_CRITICAL "CRITICAL" "${output}"
    fi

    break;
  done }

  if [ -z "${vhids}" -a $? -eq 0 ]; then
    report $STATE_CRITICAL "CRITICAL" "can't find CARP state for ${INTERFACE}"
  fi
else
  report $STATE_UNKNOWN "UNKNOWN" "$result"
fi

