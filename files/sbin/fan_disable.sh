#!/bin/sh

PID_FILE="/var/run/auto_fan.pid"
FAN_SENSOR=$(ls /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -n1)
FAN_CTRL=$(dirname "$FAN_SENSOR")

if [ -z "$FAN_CTRL" ]; then
    echo "Error: Fan controller not found." >&2
    exit 1
fi

if [ -f "$PID_FILE" ]; then
    echo "Stopping auto_fan service (PID: "$(cat "$PID_FILE")")..."
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
fi

if [ -f "$FAN_CTRL/fan1_target" ]; then
    echo 0 > "$FAN_CTRL/fan1_target"
    echo "Fan Disabled (Target set to 0 RPM)."
else
    echo "Error: fan1_target interface not found!" >&2
    exit 1
fi