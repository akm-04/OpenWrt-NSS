#!/bin/sh

echo "--- Thermal Zone Status ---"

# Loop through all thermal zones (0 to ~11)
for zone_dir in /sys/class/thermal/thermal_zone*; do
    # Check if directory exists
    [ -d "$zone_dir" ] || continue

    # Get the ID (e.g., thermal_zone0) from the path
    zone_id="${zone_dir##*/}"

    # Read the Type (Name) and Temp
    # 2>/dev/null suppresses errors if a file is missing
    type=$(cat "$zone_dir/type" 2>/dev/null)
    raw_temp=$(cat "$zone_dir/temp" 2>/dev/null)

    # Skip if we couldn't read the temp
    if [ -z "$raw_temp" ]; then
        continue
    fi

    # Convert to Celsius (Integer math)
    temp_c=$((raw_temp / 1000))

    # Print formatted output
    # Format: "thermal_zone0 (nss-top-thermal): 48°C"
    echo "$zone_id ($type): ${temp_c} C"
done