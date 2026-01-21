#!/bin/sh

# Kernel driver g762
# ==================

# The GMT G762 Fan Speed PWM Controller is connected directly to a fan
# and performs closed-loop or open-loop control of the fan speed. Two
# modes - PWM or DC - are supported by the device.

# For additional information, a detailed datasheet is available at
# http://natisbad.org/NAS/ref/GMT_EDS-762_763-080710-0.2.pdf. sysfs
# bindings are described in Documentation/hwmon/sysfs-interface.

# The following entries are available to the user in a subdirectory of
# /sys/bus/i2c/drivers/g762/ to control the operation of the device.
# This can be done manually using the following entries but is usually
# done via a userland daemon like fancontrol.

# Note that those entries do not provide ways to setup the specific
# hardware characteristics of the system (reference clock, pulses per
# fan revolution, ...); Those can be modified via devicetree bindings
# documented in Documentation/devicetree/bindings/hwmon/g762.txt or
# using a specific platform_data structure in board initialization
# file (see include/linux/platform_data/g762.h).

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

# Note that the driver will update its values at most once per second.


# ================= CONFIGURATION =================
# Simulation Range (Degrees Celsius)
TEMP_START=40
TEMP_END=75

# Hardware RPM Limits (Your V5 settings)
RPM_MIN=1000
RPM_MAX=4050

# Simulation Settings
STEP_SIZE=1        # Increase temp by 1 degree per step
WAIT_TIME=4        # Seconds to wait for fan to stabilize before reading

# Other settings of fan
FAN_DIV=2
FAN_PULSE=2
PWM_MODE=2

# Hysteresis (Simulate the "Jitter" prevention)
RPM_HYST=0       # Set to 0 to see the raw raw curve without hysteresis
# =================================================

# 1. Detect Fan Path
FAN_SENSOR=$(ls /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -n1)
FAN_PATH=$(dirname "$FAN_SENSOR")

if [ -z "$FAN_PATH" ]; then
    echo "CRITICAL: Could not find G762 fan controller path."
    exit 1
fi

# 3. Initialize Hardware (The "Golden Config")
echo "Initializing G762 Hardware (Closed Loop Mode)..."
if [ -f "$FAN_PATH/fan1_div" ]; then echo $FAN_DIV > "$FAN_PATH/fan1_div"; fi
if [ -f "$FAN_PATH/fan1_pulses" ]; then echo $FAN_PULSE > "$FAN_PATH/fan1_pulses"; fi
if [ -f "$FAN_PATH/pwm1_enable" ]; then echo $PWM_MODE > "$FAN_PATH/pwm1_enable"; fi

# 4. Calculate Slope
RPM_RANGE=$((RPM_MAX - RPM_MIN))
TEMP_RANGE=$((TEMP_END - TEMP_START))
# Avoid division by zero
if [ "$TEMP_RANGE" -eq 0 ]; then TEMP_RANGE=1; fi
SLOPE=$((RPM_RANGE / TEMP_RANGE))

echo "========================================"
echo " Fan Curve Simulator "
echo " Range: $TEMP_START C -> $TEMP_END C"
echo " RPM:   $RPM_MIN -> $RPM_MAX"
echo " Slope: $SLOPE RPM/C"
echo " Hyst:  $RPM_HYST RPM"
echo "========================================"
echo "Temp_C,Target_RPM,Actual_RPM"

# 5. Start Simulation
CURRENT_TEMP=$TEMP_START
LAST_SETTING=0

# Reset Fan to 0 first
echo 0 > "$FAN_PATH/fan1_target"
sleep 4

while [ "$CURRENT_TEMP" -le "$TEMP_END" ]; do
    
    # --- CALCULATE TARGET (Same Logic as V5 Script) ---
    if [ "$CURRENT_TEMP" -ge "$TEMP_END" ]; then
        TARGET_RPM=$RPM_MAX
    elif [ "$CURRENT_TEMP" -lt "$TEMP_START" ]; then
        TARGET_RPM=0
    else
        DELTA_TEMP=$((CURRENT_TEMP - TEMP_START))
        ADDED_RPM=$((DELTA_TEMP * SLOPE))
        TARGET_RPM=$((RPM_MIN + ADDED_RPM))
    fi

    # --- APPLY HYSTERESIS LOGIC ---
    # We read what we *last set* (or ask the chip what it's trying to do)
    CURRENT_SETTING=$(cat "$FAN_PATH/fan1_target" 2>/dev/null)
    if [ -z "$CURRENT_SETTING" ]; then CURRENT_SETTING=0; fi

    DIFF=$((TARGET_RPM - CURRENT_SETTING))
    if [ "$DIFF" -lt 0 ]; then DIFF=$((DIFF * -1)); fi

    # Apply only if diff > Hysteresis OR if turning ON/OFF/MAX
    if [ "$DIFF" -ge "$RPM_HYST" ] || { [ "$TARGET_RPM" -eq 0 ] && [ "$CURRENT_SETTING" -ne 0 ]; } || [ "$TARGET_RPM" -eq "$RPM_MAX" ]; then
        echo "$TARGET_RPM" > "$FAN_PATH/fan1_target"
    fi

    # --- WAIT & RECORD ---
    sleep "$WAIT_TIME"
    ACTUAL_RPM=$(cat "$FAN_PATH/fan1_input")
    
    # CSV Output
    echo "$CURRENT_TEMP,$TARGET_RPM,$ACTUAL_RPM"
    
    CURRENT_TEMP=$((CURRENT_TEMP + STEP_SIZE))
done

# Safety Finish
echo "Simulation Complete. Returning fan to Safe Default (2250 RPM)." >&2
echo 2250 > "$FAN_PATH/fan1_target"
