#!/bin/bash

# Loud fan control script to lower speed of fun based on current
# max temperature of any cpu
#
# See README.md for details.

# Set to false to suppress logs
DEBUG=true

# Make sure only root can run our script
if [ $EUID -ne 0 ]; then
   echo "This script must be run as root:" >&2
   echo "sudo $0" 1>&2
   exit 1
fi

if [ ! -f /sys/class/thermal/cooling_device0/cur_state ]; then
   echo "This machine is not supported." >&2
   exit 1
fi

set_mode() {
	for i in /sys/class/thermal/thermal_zone?; do
		echo $1 >$i/policy
		echo $2 >$i/mode
	done
}
enable_manual() {
	set_mode user_space disabled
}
disable_manual() {
	set_mode step_wise enabled
}
set_speed() {
	echo $1 > /sys/class/thermal/cooling_device0/cur_state
}

get_temp() {
	max=0
	for i in /sys/class/thermal/thermal_zone?/temp; do
		temp=$(cat $i)
		if [ $temp -gt $max ]; then
			max=$temp
		fi
	done
	echo $max
}

TEST_EVERY=3 #seconds

# Make sure after quiting script fan goes to auto control
function cleanup {
  $DEBUG && echo "Fan control stopped (back to auto)." >&2
  disable_manual
}
trap cleanup EXIT

echo "Fan control started." >&2

# To be sure we can manage fan
enable_manual

prev_temp=0
prev_fan_speed=-1
while [ true ]; do
  current_max_temp=$(get_temp)
  echo $current_max_temp
  if [ $current_max_temp -eq $prev_temp ]; then
    sleep $TEST_EVERY
    continue
  fi

  prev_temp=$current_max_temp

  if [ $current_max_temp -ge 75000 ]; then
    new_fan_speed=3
  elif [ $current_max_temp -ge 60000 ]; then
    new_fan_speed=2
  elif [ $current_max_temp -ge 55000 ]; then
    new_fan_speed=1
  else
    new_fan_speed=0
  fi

  if [ $prev_fan_speed -ne $new_fan_speed ]; then
    $DEBUG && echo -n "Temp: $(($current_max_temp / 1000))C, " >&2
    $DEBUG && echo "Fan speed: $(($new_fan_speed * 100 / 3))%" >&2
    set_speed $new_fan_speed
    prev_fan_speed=$new_fan_speed
  fi

  sleep $TEST_EVERY
done
