#!/system/bin/sh
MODDIR=${0%/*}

# Set global domestic NTP server
settings put global ntp_server ntp.aliyun.com 2>/dev/null

# Bind mount onto /odm/etc/gps.conf before daemons start
if [ -f "$MODDIR/gps.conf" ]; then
    mount -o bind "$MODDIR/gps.conf" /odm/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /vendor/odm/etc/gps.conf 2>/dev/null
fi
