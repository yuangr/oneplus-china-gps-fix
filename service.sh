#!/system/bin/sh
MODDIR=${0%/*}

# Wait for boot completion
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Ensure domestic NTP
settings put global ntp_server ntp.aliyun.com 2>/dev/null

# Ensure bind mount is active and has valid SELinux label
if [ -f "$MODDIR/gps.conf" ]; then
    chcon u:object_r:vendor_configs_file:s0 "$MODDIR/gps.conf" 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /odm/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /vendor/odm/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /vendor/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /odm/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /vendor/odm/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /vendor/etc/gps.conf 2>/dev/null
fi

# Background daemon: auto-download and inject Qualcomm XTRA multi-constellation ephemeris
(
    while true; do
        if ping -c 1 223.5.5.5 >/dev/null 2>&1 || ping -c 1 119.29.29.29 >/dev/null 2>&1; then
            mkdir -p /data/vendor/location
            curl -s -k --connect-timeout 8 -o /data/vendor/location/xtra3.bin https://pathcf.prod.xtracloud.cn/xtra3Mgrbeji.bin
            if [ -s /data/vendor/location/xtra3.bin ]; then
                chmod 644 /data/vendor/location/xtra3.bin
                chown gps:gps /data/vendor/location/xtra3.bin 2>/dev/null
                cmd location providers send-extra-command gps force_time_injection 2>/dev/null
                cmd location providers send-extra-command gps force_psds_injection 2>/dev/null
            fi
            # Ephemeris is valid for multiple days, sync every 12 hours
            sleep 43200
        else
            sleep 15
        fi
    done
) &
