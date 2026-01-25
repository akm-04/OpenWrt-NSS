#!/bin/sh

# ----------------- Fix caldata for rax120v2 ---------------#
logger -t rax120v2_fix "Starting binary patching process..."
# copy over the art partition onto the memory
echo "--- Starting Caldata fix (RAX120v2) ---"

echo "Copying over art partition onto /tmp"
dd if=/dev/mtd17 of=/tmp/art_full.bin

# Now work with the copy of art partition
echo "Now working on copied art partition ..."
dd if=/tmp/art_full.bin of=/tmp/real_factory_cal.bin bs=1 skip=4096 count=131072
# Import the functions
. /lib/functions/caldata.sh
# Patch the three radios
ath11k_patch_mac $(mtd_get_mac_binary boarddata1 0xc) 0 /tmp/real_factory_cal.bin
ath11k_patch_mac $(mtd_get_mac_binary boarddata1 0x0) 1 /tmp/real_factory_cal.bin
ath11k_patch_mac $(mtd_get_mac_binary boarddata1 0x6) 2 /tmp/real_factory_cal.bin

# Set the correct MAC according to your unit.
echo "Patching mac onto new Caldata ..."
ath11k_set_macflag /tmp/real_factory_cal.bin

# Copy and replace the caldata
if [ -f /lib/firmware/ath11k/IPQ8074/hw2.0/cal-ahb-c000000.wifi.bin ]; then
    mv /lib/firmware/ath11k/IPQ8074/hw2.0/cal-ahb-c000000.wifi.bin /lib/firmware/ath11k/IPQ8074/hw2.0/cal-ahb-c000000.wifi.bin.bak
fi
cp /tmp/real_factory_cal.bin /lib/firmware/ath11k/IPQ8074/hw2.0/cal-ahb-c000000.wifi.bin
logger -t rax120v2_fix "Caldata installed."

# Now replace the board-2.bin
if [ -f /sbin/board-2.bin ]; then
    if [ -f /lib/firmware/ath11k/IPQ8074/hw2.0/board-2.bin ]; then
        mv /lib/firmware/ath11k/IPQ8074/hw2.0/board-2.bin /lib/firmware/ath11k/IPQ8074/hw2.0/board-2.bin.bak
    fi
    cp /sbin/board-2.bin /lib/firmware/ath11k/IPQ8074/hw2.0/board-2.bin
    logger -t rax120v2_fix "RAX120v2 board-2.bin installed."
else 
    logger -t rax120v2_fix "WARNING: board-2.bin not found in /sbin!"
fi

# Save changes and reboot
sync
echo "Done! Rebooting in 5 seconds ..."
logger -t rax120v2_fix "Patching complete. Rebooting in 5 seconds..."
sleep 5
reboot