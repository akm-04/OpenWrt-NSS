#!/bin/sh

TARGET_RPM=$1

# 1. Validation
if [ -z "$TARGET_RPM" ]; then
    echo "Usage: $0 <RPM>"
    echo "Example: $0 2500"
    exit 1
fi

# 2. Find Hardware
PID_FILE="/var/run/auto_fan.pid"
FAN_SENSOR=$(ls /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -n1)
FAN_CTRL=$(dirname "$FAN_SENSOR")

# First disable the auto_fan.sh
if [ -f "$PID_FILE" ]; then
    echo "Stopping auto_fan service (PID: "$(cat "$PID_FILE")")..."
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
fi

# Ensure we are in Mode 2 (Target RPM)
if [ -f "$FAN_CTRL/pwm1_enable" ]; then
    echo 2 > "$FAN_CTRL/pwm1_enable"
fi

# Write the Target
if [ -f "$FAN_CTRL/fan1_target" ]; then
    echo "$TARGET_RPM" > "$FAN_CTRL/fan1_target"
    echo "Fan speed set to $TARGET_RPM RPM (Closed Loop)."
else
    echo "Error: Hardware does not support fan1_target."
    exit 1
fi