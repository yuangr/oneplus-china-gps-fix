#!/system/bin/sh
MODDIR=${0%/*}

# Ensure proper SELinux context and bind mount gps.conf to existing target paths
if [ -f "$MODDIR/gps.conf" ]; then
    chcon u:object_r:vendor_configs_file:s0 "$MODDIR/gps.conf" 2>/dev/null
    for target in /system/etc/gps.conf /odm/etc/gps.conf /vendor/odm/etc/gps.conf /vendor/etc/gps.conf; do
        if [ -f "$target" ]; then
            mount -o bind "$MODDIR/gps.conf" "$target" 2>/dev/null
            chcon u:object_r:vendor_configs_file:s0 "$target" 2>/dev/null
        fi
    done
fi
