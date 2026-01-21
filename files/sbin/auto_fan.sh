#!/bin/sh

# =================================================
# ================= FAN G762 Options ==============
#  fan1_target: set desired fan speed. This only makes sense in closed-loop
#            fan speed control (i.e. when pwm1_enable is set to 2).

#  fan1_input: provide current fan rotation value in RPM as reported by
#            the fan to the device.

#  fan1_div: fan clock divisor. Supported value are 1, 2, 4 and 8.

#  fan1_pulses: number of pulses per fan revolution. Supported values
#            are 2 and 4.

#  fan1_fault: reports fan failure, i.e. no transition on fan gear pin for
#            about 0.7s (if the fan is not voluntarily set off).

#  fan1_alarm: in closed-loop control mode, if fan RPM value is 25% out
#            of the programmed value for over 6 seconds 'fan1_alarm' is
#            set to 1.

#  pwm1_enable: set current fan speed control mode i.e. 1 for manual fan
#            speed control (open-loop) via pwm1 described below, 2 for
#            automatic fan speed control (closed-loop) via fan1_target
#            above.

#  pwm1_mode: set or get fan driving mode: 1 for PWM mode, 0 for DC mode.

#  pwm1: get or set PWM fan control value in open-loop mode. This is an
#            integer value between 0 and 255. 0 stops the fan, 255 makes
#             it run at full speed.

# Both in PWM mode ('pwm1_mode' set to 1) and DC mode ('pwm1_mode' set to 0),
# when current fan speed control mode is open-loop ('pwm1_enable' set to 1),
# the fan speed is programmed by setting a value between 0 and 255 via 'pwm1'
# entry (0 stops the fan, 255 makes it run at full speed). In closed-loop mode
# ('pwm1_enable' set to 2), the expected rotation speed in RPM can be passed to
# the chip via 'fan1_target'. In closed-loop mode, the target speed is compared
# with current speed (available via 'fan1_input') by the device and a feedback
# is performed to match that target value. The fan speed value is computed
# based on the parameters associated with the physical characteristics of the
# system: a reference clock source frequency, a number of pulses per fan
# revolution, etc.
# =================================================

# ================= CONFIGURATION =================
# OEM Values (Netgear RAX120 v2)
# Low: 50C -> 2250 RPM
# High: 65C -> 3200 RPM
TEMP_START=43
TEMP_MAX=70
RPM_MIN=1000
RPM_MAX=3900

# Safety: If temp exceeds MAX, trigger Turbo Mode
TEMP_CRITICAL=71
RPM_TURBO=4100

# Hysteresis.
# Only change speed if calculated target differs by more than this
RPM_HYST=0

# Polling Interval (Seconds)
SLEEP_TIME=20

# Other settings
FAN_DIV=2
FAN_PULSE=2
PWM_MODE=2

# Paths
PID_FILE="/var/run/auto_fan.pid"
# Find the G762 sensor.
FAN_SENSOR=$(ls /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -n1)
FAN_CTRL=$(dirname "$FAN_SENSOR")

# ================= INIT & SAFETY =================

if [ -z "$FAN_CTRL" ]; then
    logger -t auto_fan "CRITICAL: G762 Fan Controller not found!"
    exit 1
fi

# Trap for clean exit
cleanup() {
    logger -t auto_fan "Stopping. Leaving fan in auto mode."
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup EXIT INT TERM

# Single Instance Check
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Service already running (PID: $PID)"
        exit 1
    fi
fi
echo "$$" > "$PID_FILE"

# ================= FAN HARDWARE SETUP =================
# Default FAN data pulled from stock firmware
# root@RAX120v2:/sys/devices/platform/soc/78b6000.i2c/i2c-0/0-003e# grep . /sys/bus/i2c/devices/0-003e/*
# /sys/bus/i2c/devices/0-003e/fan1_alarm:0
# /sys/bus/i2c/devices/0-003e/fan1_div:2
# /sys/bus/i2c/devices/0-003e/fan1_fault:0
# /sys/bus/i2c/devices/0-003e/fan1_input:2254
# /sys/bus/i2c/devices/0-003e/fan1_pulses:2
# /sys/bus/i2c/devices/0-003e/fan1_target:2254
# /sys/bus/i2c/devices/0-003e/modalias:i2c:g761
# /sys/bus/i2c/devices/0-003e/name:g761
# /sys/bus/i2c/devices/0-003e/pwm1:0
# /sys/bus/i2c/devices/0-003e/pwm1_enable:2
# /sys/bus/i2c/devices/0-003e/pwm1_mode:1
# /sys/bus/i2c/devices/0-003e/uevent:DRIVER=g761
# /sys/bus/i2c/devices/0-003e/uevent:OF_NAME=g761
# /sys/bus/i2c/devices/0-003e/uevent:OF_FULLNAME=/soc/i2c@78b6000/g761@3e
# /sys/bus/i2c/devices/0-003e/uevent:OF_COMPATIBLE_0=gmt,g761
# /sys/bus/i2c/devices/0-003e/uevent:OF_COMPATIBLE_N=1
# /sys/bus/i2c/devices/0-003e/uevent:MODALIAS=i2c:g761

logger -t auto_fan "Initializing G762 Hardware..."

# 1. Set Clock Divisor to 2.
if [ -f "$FAN_CTRL/fan1_div" ]; then
    echo $FAN_DIV > "$FAN_CTRL/fan1_div"
fi

# 2. Set Pulse Count to 2.
if [ -f "$FAN_CTRL/fan1_pulses" ]; then
    echo $FAN_PULSE > "$FAN_CTRL/fan1_pulses"
fi

# 3. Set Mode to 2 (RPM Target / Closed Loop)
# This enables the chip's internal kickstart logic.
if [ -f "$FAN_CTRL/pwm1_enable" ]; then
    echo $PWM_MODE > "$FAN_CTRL/pwm1_enable"
fi

# ================= MAIN LOOP =================
logger -t auto_fan "Starting Linear Control Loop ($TEMP_START C - $TEMP_MAX C)"

# Pre-calculate Slope (Rise / Run)
# Slope = (3200 - 2250) / (65 - 50) = 950 / 15 = 63.33
# Use same logic as stock /sbin/temp_ctrl.sh

RPM_RANGE=$((RPM_MAX - RPM_MIN))
TEMP_RANGE=$((TEMP_MAX - TEMP_START))
SLOPE=$((RPM_RANGE / TEMP_RANGE))

while true; do
    # 1. Find Max Temp across all zones
    MAX_TEMP=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -r "$zone" ]; then
            RAW=$(cat "$zone" 2>/dev/null)
            # Filter non-numbers
            case "$RAW" in ''|*[!0-9]*) continue ;; esac
            # Convert millidegrees to degrees
            VAL=$((RAW / 1000))
            if [ "$VAL" -gt "$MAX_TEMP" ]; then MAX_TEMP=$VAL; fi
        fi
    done
    # Failsafe if sensors read 0
    if [ "$MAX_TEMP" -eq 0 ]; then MAX_TEMP=55; fi

    # 2. Calculate Target RPM
    if [ "$MAX_TEMP" -ge "$TEMP_CRITICAL" ]; then
        TARGET_RPM=$RPM_TURBO
    elif [ "$MAX_TEMP" -ge "$TEMP_MAX" ]; then
        TARGET_RPM=$RPM_MAX
    elif [ "$MAX_TEMP" -ge "$TEMP_START" ]; then
        # Linear Formula: Target = MinRPM + (CurrentTemp - StartTemp) * Slope
        DELTA_TEMP=$((MAX_TEMP - TEMP_START))
        ADDED_RPM=$((DELTA_TEMP * SLOPE))
        TARGET_RPM=$((RPM_MIN + ADDED_RPM))
    else
        # Below start temp? Turn off.
        TARGET_RPM=0
    fi

    # 3. Apply Speed with Hysteresis
    # We read the *current setting* (fan1_target), NOT the actual RPM (fan1_input)
    # This prevents fighting the controller while it spins up.
    CURRENT_SETTING=$(cat "$FAN_CTRL/fan1_target" 2>/dev/null)
    if [ -z "$CURRENT_SETTING" ]; then CURRENT_SETTING=0; fi

    # Calculate absolute difference
    DIFF=$((TARGET_RPM - CURRENT_SETTING))
    # Shell absolute value hack
    if [ "$DIFF" -lt 0 ]; then DIFF=$((DIFF * -1)); fi

    # Only apply if change is significant (> HYST) OR if we need to force 0
    if [ "$DIFF" -ge "$RPM_HYST" ] || { [ "$TARGET_RPM" -eq 0 ] && [ "$CURRENT_SETTING" -ne 0 ]; }; then
        echo "$TARGET_RPM" > "$FAN_CTRL/fan1_target"
    fi

    sleep "$SLEEP_TIME"

    # ================= SELF HEALING LOGIC =================
    # Read current RPM and Mode from file content
    CURRENT_RPM=$(cat "$FAN_CTRL/fan1_input" 2>/dev/null)
    CURRENT_MODE=$(cat "$FAN_CTRL/pwm1_mode" 2>/dev/null)
    
    # Default to 0 if read failed
    [ -z "$CURRENT_RPM" ] && CURRENT_RPM=0
    [ -z "$CURRENT_MODE" ] && CURRENT_MODE=0

    # LOGIC: If RPM is 0 BUT we expect it to be spinning (Target > 0)
    # AND we are not already in PWM Mode (1)... then force the switch.
    if [ "$CURRENT_RPM" -eq 0 ] && [ "$TARGET_RPM" -gt 0 ]; then
        if [ "$CURRENT_MODE" -ne 1 ]; then
            logger -t auto_fan "Tachometer RPM reading dead (0). Attempting fix: Switch to PWM Mode 1"
            echo 1 > "$FAN_CTRL/pwm1_mode"
        fi
    fi
done