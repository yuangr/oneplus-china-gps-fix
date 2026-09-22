#!/system/bin/sh
MODDIR=${0%/*}

# Wait for boot completion
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Ensure domestic NTP
settings put global ntp_server ntp.aliyun.com 2>/dev/null

check_network() {
    if ip route show default 2>/dev/null | grep -q "default"; then
        return 0
    fi
    if dumpsys connectivity 2>/dev/null | grep -q "state: CONNECTED"; then
        return 0
    fi
    if [ -n "$(getprop net.dns1)" ]; then
        return 0
    fi
    return 1
}

sync_xtra() {
    if command -v curl >/dev/null 2>&1; then
        mkdir -p /data/vendor/location
        if curl -s -k --connect-timeout 6 -m 15 -o /data/vendor/location/xtra3.bin.tmp https://pathcf.prod.xtracloud.cn/xtra3Mgrbeji.bin 2>/dev/null; then
            if [ -s /data/vendor/location/xtra3.bin.tmp ]; then
                mv -f /data/vendor/location/xtra3.bin.tmp /data/vendor/location/xtra3.bin
                chmod 644 /data/vendor/location/xtra3.bin
                chown gps:gps /data/vendor/location/xtra3.bin 2>/dev/null
                chcon u:object_r:vendor_location_data_file:s0 /data/vendor/location/xtra3.bin 2>/dev/null || true
                return 0
            fi
        fi
        rm -f /data/vendor/location/xtra3.bin.tmp
    fi
    return 1
}

inject_time() {
    cmd location providers send-extra-command gps force_time_injection 2>/dev/null || \
    cmd location send-extra-command gps force_time_injection 2>/dev/null
}

# Background daemon for assistance maintenance
(
    # Wait up to 30 seconds for initial network
    net_waited=0
    while ! check_network; do
        sleep 3
        net_waited=$((net_waited + 3))
        if [ $net_waited -ge 30 ]; then
            break
        fi
    done

    if check_network; then
        sync_xtra
        inject_time
    fi

    last_sync=$(date +%s)

    while true; do
        # Stop immediately on shutdown/reboot
        if [ -n "$(getprop sys.shutdown.requested)" ]; then
            exit 0
        fi

        # Sleep in 60s increments to allow prompt shutdown exit
        sleep 60

        now=$(date +%s)
        # Periodically refresh ephemeris cache every 6 hours
        if [ $((now - last_sync)) -ge 21600 ]; then
            if check_network; then
                if sync_xtra; then
                    inject_time
                    last_sync=$now
                fi
            fi
        fi
    done
) &
