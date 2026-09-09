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
    for target in /system/etc/gps.conf /odm/etc/gps.conf /vendor/odm/etc/gps.conf /vendor/etc/gps.conf; do
        if [ -f "$target" ]; then
            mount -o bind "$MODDIR/gps.conf" "$target" 2>/dev/null
            chcon u:object_r:vendor_configs_file:s0 "$target" 2>/dev/null
        fi
    done
fi

check_network() {
    # Check default routing table (fastest, standard linux)
    if ip route show default 2>/dev/null | grep -q "default"; then
        return 0
    fi
    # Check connectivity service
    if dumpsys connectivity 2>/dev/null | grep -q "state: CONNECTED"; then
        return 0
    fi
    # Check DNS property
    if [ -n "$(getprop net.dns1)" ]; then
        return 0
    fi
    return 1
}

sync_xtra() {
    # If curl exists, cache XTRA 3.0 data
    if command -v curl >/dev/null 2>&1; then
        mkdir -p /data/vendor/location
        curl -s -k --connect-timeout 6 -m 15 -o /data/vendor/location/xtra3.bin https://pathcf.prod.xtracloud.cn/xtra3Mgrbeji.bin 2>/dev/null
        if [ -s /data/vendor/location/xtra3.bin ]; then
            chmod 644 /data/vendor/location/xtra3.bin
            chown gps:gps /data/vendor/location/xtra3.bin 2>/dev/null
            return 0
        fi
    fi
    return 1
}

inject_assistance() {
    # Dual compatibility for different AOSP branches (cmd location providers vs cmd location)
    cmd location providers send-extra-command gps force_time_injection 2>/dev/null || \
    cmd location send-extra-command gps force_time_injection 2>/dev/null

    cmd location providers send-extra-command gps force_psds_injection 2>/dev/null || \
    cmd location send-extra-command gps force_psds_injection 2>/dev/null
}

# Responsive daemon: keep ephemeris fresh & hot-inject whenever GPS is requested by any app
(
    # Wait up to 30 seconds for initial network without hard blocking
    net_waited=0
    while ! check_network; do
        sleep 3
        net_waited=$((net_waited + 3))
        if [ $net_waited -ge 30 ]; then
            break
        fi
    done

    sync_xtra
    # Send initial assistance injection on boot
    inject_assistance

    last_sync=$(date +%s)
    last_injected=0

    while true; do
        # 关机检测：如果系统正在关机/重启，立刻退出守护进程，防止死锁 Binder
        if [ "$(getprop sys.shutdown.requested)" != "" ]; then
            exit 0
        fi

        now=$(date +%s)
        # Periodically refresh ephemeris cache every 6 hours
        if [ $((now - last_sync)) -ge 21600 ]; then
            if check_network; then
                sync_xtra
                last_sync=$now
            fi
        fi

        # 耗电优化：只有在亮屏状态下，才以高频率检测 GPS 活动
        is_awake=$(dumpsys power 2>/dev/null | grep -q "mWakefulness=Awake" && echo 1 || echo 0)
        
        if [ "$is_awake" = "1" ]; then
            # Detect if any foreground/background app has activated the GPS hardware (mStarted=true)
            if dumpsys location 2>/dev/null | grep -q "mStarted=true"; then
                # Rate-limit injection to at most once every 15 seconds during active positioning
                if [ $((now - last_injected)) -ge 15 ]; then
                    inject_assistance
                    last_injected=$now
                fi
                sleep 5
            else
                sleep 10
            fi
        else
            # 息屏状态下，放慢轮询频率至 30 秒，极大地节省待机电量
            sleep 30
        fi
    done
) &
