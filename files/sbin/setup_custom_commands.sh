#!/bin/sh

# Clean up existing commands.
uci delete luci.commands 2>/dev/null
uci commit luci

# --- Aquantia Firmware Flash ---
uci add luci command
uci set luci.@command[-1].name='Flash 5G LAN Firmware (Aquantia)'
uci set luci.@command[-1].command='/sbin/Aquantia_fix.sh'

# --- Caldata fix script ---
uci add luci command
uci set luci.@command[-1].name='Fix 5ghz Calibration Data (RAX120v2)'
uci set luci.@command[-1].command='/sbin/fix_caldata_rax120v2.sh'

# --- First find correct Fan Speed Controls path ---
FAN_SENSOR=$(ls /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -n1)

# Get the directory name (e.g., /sys/class/hwmon/hwmon1)
FAN_PATH=$(dirname "$FAN_SENSOR")

if [ -z "$FAN_PATH" ]; then
    echo "Error: Could not detect fan sensor path!"
else
    echo "Success! Detected Fan Controller at: $FAN_PATH"

    # --- Fan Speed Controls Commands (Using Calculated Path) ---
    # Fan: Low
    uci add luci command
    uci set luci.@command[-1].name='Fan: Set Low (~2550 RPM)'
    uci set luci.@command[-1].command="echo 1 > $FAN_PATH/pwm1_enable && echo 170 > $FAN_PATH/pwm1 && echo 'Fan set to Low (170)'"

    # Fan: Mid
    uci add luci command
    uci set luci.@command[-1].name='Fan: Set Mid (~2800 RPM)'
    uci set luci.@command[-1].command="echo 1 > $FAN_PATH/pwm1_enable && echo 180 > $FAN_PATH/pwm1 && echo 'Fan set to Mid (180)'"

    # Fan: High
    uci add luci command
    uci set luci.@command[-1].name='Fan: Set High (~3200 RPM)'
    uci set luci.@command[-1].command="echo 1 > $FAN_PATH/pwm1_enable && echo 200 > $FAN_PATH/pwm1 && echo 'Fan set to High (200)'"

    # Fan: Turbo
    uci add luci command
    uci set luci.@command[-1].name='Fan: Set Turbo (~4000 RPM)'
    uci set luci.@command[-1].command="echo 1 > $FAN_PATH/pwm1_enable && echo 255 > $FAN_PATH/pwm1 && echo 'Fan set to Turbo (Max)'"

    # --- Sensors Commands ---

    # Check Fan RPM
    uci add luci command
    uci set luci.@command[-1].name='Check Fan RPM'
    uci set luci.@command[-1].command="cat $FAN_PATH/fan1_input"

    echo "LuCI commands updated successfully."
fi

# Check all Zone Temp
uci add luci command
uci set luci.@command[-1].name='Check Temperature for all ThermalZones'
uci set luci.@command[-1].command="/sbin/check_all_temp.sh"

#  Save Changes
uci commit luci
echo "LuCI commands updated successfully."

# ==============================================================================
# 2. System LED Configuration
# ==============================================================================

# Cleanup Defaults
# Remove the default Aquantia LED entry if it exists
uci delete system.led_aqr 2>/dev/null

# Power LED
uci set system.led_power='led'
uci set system.led_power.name='Power LED'
uci set system.led_power.sysfs='white:'
uci set system.led_power.trigger='default-on'

# 2.4GHz Radio LED
uci set system.led_wlan2g='led'
uci set system.led_wlan2g.name='2.4-Ghz_Radio'
uci set system.led_wlan2g.sysfs='white:_1'
uci set system.led_wlan2g.trigger='netdev'
uci set system.led_wlan2g.dev='phy1-ap0'
uci set system.led_wlan2g.mode='link tx rx'

# 5GHz Radio LED
uci set system.led_wlan5g='led'
uci set system.led_wlan5g.name='5-Ghz_Radio'
uci set system.led_wlan5g.sysfs='white:_2'
uci set system.led_wlan5g.trigger='netdev'
uci set system.led_wlan5g.dev='phy0-ap0'
uci set system.led_wlan5g.mode='link tx rx'

# WAN Port LED
uci set system.led_wan='led'
uci set system.led_wan.name='WAN_Port'
uci set system.led_wan.sysfs='white:_5'
uci set system.led_wan.trigger='netdev'
uci set system.led_wan.dev='wan'
uci set system.led_wan.mode='link tx rx'

# Radio Button LED (Heartbeat)
uci set system.led_radio_btn='led'
uci set system.led_radio_btn.name='Radio_Button-LED'
uci set system.led_radio_btn.sysfs='white:_7'
uci set system.led_radio_btn.trigger='heartbeat'

# USB Port 1 LED
# Maps to usb1 (2.0) and usb2 (3.0)
uci set system.led_usb1='led'
uci set system.led_usb1.name='USB_Port-1'
uci set system.led_usb1.sysfs='white:_4'
uci set system.led_usb1.trigger='usbport'
# Clear old ports to prevent duplicates if script is run twice
uci -q delete system.led_usb1.port  
uci add_list system.led_usb1.port='usb1-port1'
uci add_list system.led_usb1.port='usb2-port1'

# USB Port 2 LED
# Maps to usb3 (2.0) and usb4 (3.0)
uci set system.led_usb2='led'
uci set system.led_usb2.name='USB_Port-2'
uci set system.led_usb2.sysfs='white:_3'
uci set system.led_usb2.trigger='usbport'
# Clear old ports to prevent duplicates
uci -q delete system.led_usb2.port  
uci add_list system.led_usb2.port='usb3-port1'
uci add_list system.led_usb2.port='usb4-port1'

# Save System changes and restart LED service
uci commit system
/etc/init.d/led restart
echo "System LEDs updated successfully."

exit 0