#!/bin/bash

# Loud fan control script to lower speed of fun based on current
# max temperature of any cpu
#
# See README.md for details.

# Set to false to suppress logs
DEBUG=true

# Make sure only root can run our script
if (( $EUID != 0 )); then
   echo "This script must be run as root:" 1>&2
   echo "sudo $0" 1>&2
   exit 1
fi

if [ -f /sys/devices/odroid_fan.13/fan_mode ]; then
   FAN=13
elif [ -f /sys/devices/odroid_fan.14/fan_mode ]; then
   FAN=14
else
   echo "This machine is not supported."
   exit 1
fi

TEMPERATURE_FILE="/sys/devices/10060000.tmu/temp"
FAN_MODE_FILE="/sys/devices/odroid_fan.$FAN/fan_mode"
FAN_SPEED_FILE="/sys/devices/odroid_fan.$FAN/pwm_duty"
TEST_EVERY=3 #seconds

# Make sure after quiting script fan goes to auto control
function cleanup {
  ${DEBUG} && echo "event: quit; temp: auto" >&2
  echo 1 > ${FAN_MODE_FILE}
}
trap cleanup EXIT

function exit_xu3_only_supported {
  ${DEBUG} && echo "event: non-xu3 $1" >&2
  exit 2
}
if [ ! -f $TEMPERATURE_FILE ]; then
  exit_xu3_only_supported "no temp file"
elif [ ! -f $FAN_MODE_FILE ]; then
  exit_xu3_only_supported "no fan mode file"
elif [ ! -f $FAN_SPEED_FILE ]; then
  exit_xu3_only_supported "no fan speed file"
fi


current_max_temp=`cat ${TEMPERATURE_FILE} | cut -d: -f2 | sort -nr | head -1`
echo "fan control started. Current max temp: ${current_max_temp}"

prev_fan_speed=0
# To be sure we can manage fan
echo 0 > ${FAN_MODE_FILE}

prev_temp=0
while [ true ];
do

  current_max_temp=`cat ${TEMPERATURE_FILE} | cut -d: -f2 | sort -nr | head -1`
  if [ $current_max_temp -eq $prev_temp ]; then
    sleep ${TEST_EVERY}
    continue
  fi

  prev_temp=$current_max_temp

  new_fan_speed=0
  if (( ${current_max_temp} >= 75000 )); then
    new_fan_speed=255
  elif (( ${current_max_temp} >= 70000 )); then
    new_fan_speed=200
  elif (( ${current_max_temp} >= 68000 )); then
    new_fan_speed=130
  elif (( ${current_max_temp} >= 66000 )); then
    new_fan_speed=70
  elif (( ${current_max_temp} >= 63000 )); then
    new_fan_speed=65
  elif (( ${current_max_temp} >= 60000 )); then
    new_fan_speed=60
  else
    new_fan_speed=50
  fi

  if (( ${prev_fan_speed} != ${new_fan_speed} )); then
    ${DEBUG} && echo "event: read_max; temp: ${current_max_temp}" >&2
    ${DEBUG} && echo "event: adjust; speed: ${new_fan_speed}" >&2
    echo ${new_fan_speed} > ${FAN_SPEED_FILE}
    prev_fan_speed=${new_fan_speed}
  fi

  sleep ${TEST_EVERY}
done
