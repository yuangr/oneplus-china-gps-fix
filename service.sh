#!/system/bin/sh
MODDIR=${0%/*}

# Wait for boot completion
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Ensure domestic NTP
settings put global ntp_server ntp.aliyun.com

# Ensure bind mount is active and has valid SELinux label
if [ -f "$MODDIR/gps.conf" ]; then
    chcon u:object_r:vendor_configs_file:s0 "$MODDIR/gps.conf" 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /odm/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /vendor/odm/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /odm/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /vendor/odm/etc/gps.conf 2>/dev/null
fi
