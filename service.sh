#!/system/bin/sh
# One bounded request per boot. Android owns download, retry and HAL injection.
MODDIR=${0%/*}
RUNDIR="$MODDIR/runtime"
umask 077
mkdir -p "$RUNDIR" || exit 1
if [ "${1:-}" != --locked ]; then
    # mksh may close inherited high-numbered descriptors. Let BusyBox hold
    # the lock while running the entire child, instead of passing an FD.
    for bb in /data/adb/ap/bin/busybox /data/adb/ksu/bin/busybox /data/adb/magisk/busybox; do
        if [ -x "$bb" ]; then
            exec "$bb" flock -n "$RUNDIR/service.lock" /system/bin/sh "$0" --locked
        fi
    done
    echo 'BusyBox required for the service lock' >&2
    exit 1
fi
log_msg() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$RUNDIR/service.log"
}
if [ -f "$RUNDIR/service.log" ]; then
    tail -100 "$RUNDIR/service.log" > "$RUNDIR/service.log.tmp" &&
        mv "$RUNDIR/service.log.tmp" "$RUNDIR/service.log"
fi
is_stopping() {
    [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ] ||
        [ -n "$(getprop sys.shutdown.requested)" ]
}
waited=0
until [ "$(getprop sys.boot_completed)" = 1 ]; do
    is_stopping && exit 0
    [ "$waited" -ge 300 ] && { log_msg 'boot wait timed out'; exit 1; }
    sleep 5
    waited=$((waited + 5))
done
is_stopping && exit 0
boot_id=$(cat /proc/sys/kernel/random/boot_id) || exit 1
if [ "$(cat "$RUNDIR/requested_boot" 2>/dev/null)" = "$boot_id" ]; then
    log_msg 'request already submitted this boot; exiting'
    exit 0
fi
# Live upgrades wait for reboot to load the new overlays.
if [ "$(cat "$RUNDIR/defer_boot" 2>/dev/null)" = "$boot_id" ]; then
    log_msg 'upgrade staged; request deferred until reboot loads new overlays'
    exit 0
fi
location_enabled=$(timeout -k 2 10 cmd location is-location-enabled 2>/dev/null)
if [ "$location_enabled" != true ]; then
    log_msg 'location disabled or unavailable; leaving normal GNSS requests to Android'
    exit 0
fi
help_text=$(timeout -k 2 10 cmd location help 2>/dev/null)
case "$help_text" in
    *send-extra-command*) ;;
    *) log_msg 'send-extra-command unsupported'; exit 1 ;;
esac
case "$help_text" in
    *'providers command'*) command_style=providers ;;
    *) command_style=legacy ;;
esac
send_request() {
    # Binder receives cmd's output FDs. Do not pass an adb/module log file
    # that system_server cannot receive/write under SELinux; use a pipe.
    if [ "$command_style" = providers ]; then
        request_output=$(timeout -k 2 10 cmd location providers send-extra-command gps "$1" 2>&1)
    else
        request_output=$(timeout -k 2 10 cmd location send-extra-command gps "$1" 2>&1)
    fi
    request_status=$?
    [ -z "$request_output" ] || log_msg "$request_output"
    return "$request_status"
}
attempt=1
while [ "$attempt" -le 3 ]; do
    is_stopping && exit 0
    if send_request force_psds_injection; then
        # Records submission, NEVER download/injection success.
        printf '%s\n' "$boot_id" > "$RUNDIR/requested_boot.tmp" &&
            mv "$RUNDIR/requested_boot.tmp" "$RUNDIR/requested_boot"
        log_msg 'PSDS command submitted; verify download and injection in GNSS logs'
        is_stopping && exit 0
        if send_request force_time_injection; then
            log_msg 'time command submitted'
        else
            log_msg 'time command failed; normal framework time handling remains active'
        fi
        exit 0
    fi
    log_msg "PSDS command failed (attempt $attempt/3)"
    [ "$attempt" -eq 3 ] && break
    sleep $((attempt * 15))
    attempt=$((attempt + 1))
done
exit 1
