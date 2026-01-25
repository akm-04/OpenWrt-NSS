#!/bin/sh

echo "--- Starting Aquantia Firmware Update ---"
# Only proceede to flash firmware if fgrep -i 'ethphyfw' /proc/mtd returns "mtd25: 00080000 00020000 "ethphyfw""
SAFETY_STRING='mtd25: 00080000 00020000 "ethphyfw"'

# Check if the partition table matches the safety string EXACTLY
if grep -Fq "$SAFETY_STRING" /proc/mtd; then
    echo "[OK] Partition Layout Confirmed."
    
    if [ -f /sbin/aqr_v4.3.C.mbn ]; then
        echo "Preparing to flash 5G Ethernet port fw. Do not turn off power..."
        
        # Move to tmp as per standard procedure
        cp /sbin/aqr_v4.3.C.mbn /tmp/aqr_v4.3.C.mbn
        
        # Write to partition
        echo "Writing to /dev/mtd25..."
        mtd write /tmp/aqr_v4.3.C.mbn /dev/mtd25
        
        echo "[SUCCESS] Aquantina Firmware written successfully."
        echo "The router must reboot to apply changes."
        echo "Rebooting in 5 seconds..."
        sleep 5
        reboot
    else
        echo "[FAIL] Aquantia Firmware file at /sbin/aqr_v4.3.C.mbn not found!"
        echo "Exiting without doing anything ..."
    fi
else
    # Partition layout mismatch, exit without doing anything
    echo "[CRITICAL FAIL] Partition layout mismatch!"
    echo "Expected: $SAFETY_STRING"    
    echo "Actual:   $(grep 'mtd25' /proc/mtd)"
    echo "ABORTING. No changes made."    
fi
