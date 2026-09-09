#!/system/bin/sh
MODDIR=${0%/*}

# Set global domestic NTP server
settings put global ntp_server ntp.aliyun.com 2>/dev/null

# Ensure proper SELinux context and bind mount gps.conf to all known paths
if [ -f "$MODDIR/gps.conf" ]; then
    chcon u:object_r:vendor_configs_file:s0 "$MODDIR/gps.conf" 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /system/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /odm/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /vendor/odm/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /vendor/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /system/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /odm/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /vendor/odm/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /vendor/etc/gps.conf 2>/dev/null
fi
