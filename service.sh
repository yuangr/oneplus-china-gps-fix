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
    mount -o bind "$MODDIR/gps.conf" /system/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /odm/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /vendor/odm/etc/gps.conf 2>/dev/null
    mount -o bind "$MODDIR/gps.conf" /vendor/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /system/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /odm/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /vendor/odm/etc/gps.conf 2>/dev/null
    chcon u:object_r:vendor_configs_file:s0 /vendor/etc/gps.conf 2>/dev/null
fi

sync_xtra() {
    mkdir -p /data/vendor/location
    curl -s -k --connect-timeout 8 -o /data/vendor/location/xtra3.bin https://pathcf.prod.xtracloud.cn/xtra3Mgrbeji.bin
    if [ -s /data/vendor/location/xtra3.bin ]; then
        chmod 644 /data/vendor/location/xtra3.bin
        chown gps:gps /data/vendor/location/xtra3.bin 2>/dev/null
        return 0
    fi
    return 1
}

# Responsive daemon: keep ephemeris fresh & hot-inject whenever GPS is requested by any app
(
    # Wait for network connectivity
    until ping -c 1 223.5.5.5 >/dev/null 2>&1 || ping -c 1 119.29.29.29 >/dev/null 2>&1; do
        sleep 5
    done
    sync_xtra

    last_sync=$(date +%s)
    last_injected=0

    while true; do
        now=$(date +%s)
        # Periodically refresh ephemeris cache every 6 hours
        if [ $((now - last_sync)) -ge 21600 ]; then
            if sync_xtra; then
                last_sync=$now
            fi
        fi

        # Detect if any foreground/background app has activated the GPS hardware (mStarted=true)
        if dumpsys location 2>/dev/null | grep -q "mStarted=true"; then
            # Rate-limit injection to at most once every 15 seconds during active positioning
            if [ $((now - last_injected)) -ge 15 ]; then
                cmd location providers send-extra-command gps force_time_injection 2>/dev/null
                cmd location providers send-extra-command gps force_psds_injection 2>/dev/null
                last_injected=$now
            fi
            sleep 3
        else
            sleep 5
        fi
    done
) &
