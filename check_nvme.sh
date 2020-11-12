#!/bin/sh

args=`getopt u: $*`

MAX_USED=10

if [ $? -ne 0 ]; then
  echo 'Usage: ...'
  exit 2
fi
set -- $args

while :; do
  case "$1" in
  -u)
          MAX_USED="$2"
          shift; shift
          ;;
  --)
          shift; break
          ;;
  esac
done

DISKS=$(nvmecontrol devlist | grep -o '^ nvme[0-9]' | sed 's:^ *::g')
CRIT=false
MESSAGE=""

for DISK in $DISKS ; do
  OUTPUT=$(nvmecontrol logpage -p2 $DISK)

  # Check for critical_warning
  $(echo "$OUTPUT" | awk -F ':' '/Critical Warning State/ && $2 != 0 {exit 1}')
  if [ $? == 1 ]; then
    CRIT=true
    MESSAGE="$MESSAGE $DISK has critical warning,"
  fi

  # Check media_errors
  $(echo "$OUTPUT" | awk -F ':' '/Media errors/ && $2 != 0 { exit 1 }')
  if [ $? == 1 ]; then
    CRIT=true
    MESSAGE="$MESSAGE $DISK has media errors,"
  fi

  # Check num_err_log_entries
  $(echo "$OUTPUT" | awk -F ':' '/error info log entries/ && $2 != 0 {exit 1}')
  if [ $? == 1 ]; then
    CRIT=true
    MESSAGE="$MESSAGE $DISK has errors logged,"
  fi

  # Check num_err_log_entries
  $(echo "$OUTPUT" | awk -F ':' "/Percentage used/ && \$2 >= $MAX_USED {exit 1}")
  if [ $? == 1 ]; then
    CRIT=true
    MESSAGE="$MESSAGE $DISK is over maximum percentage used"
  fi
done

if [ $CRIT = "true" ]; then
  echo "CRITICAL: ($(echo "$MESSAGE" | sed 's:,$::' | sed 's:^ *::'))"
  exit 2
else
  echo "OK $(echo $DISKS | tr -d '\n')"
  exit 0
fi
