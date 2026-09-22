#!/system/bin/sh
# Usage: sh prepare-config.sh [verified-ROM-baseline-directory]
# Run during installation, before new overlays are mounted.
set -eu
MODDIR=${0%/*}
BASELINE=${1:-}
mkdir -p "$MODDIR/originals" "$MODDIR/system"
fingerprint=$(getprop ro.build.fingerprint)
active=/data/adb/modules/oneplus_cn_gps_fix
gps_awk() {
    # Android 17 may expose a limited system awk that rejects this merge
    # program. Root managers already ship a known-compatible BusyBox awk.
    for bb in /data/adb/ap/bin/busybox /data/adb/ksu/bin/busybox /data/adb/magisk/busybox; do
        if [ -x "$bb" ]; then
            "$bb" awk "$@"
            return
        fi
    done
    if command -v awk >/dev/null 2>&1; then
        awk "$@"
        return
    fi
    echo 'No compatible awk implementation found' >&2
    return 1
}
if [ -n "$BASELINE" ]; then
    [ "$(cat "$BASELINE/fingerprint")" = "$fingerprint" ] || {
        echo 'ROM baseline fingerprint does not match this phone' >&2; exit 1;
    }
elif [ -f "$active/originals/fingerprint" ] &&
     [ "$(cat "$active/originals/fingerprint")" = "$fingerprint" ]; then
    BASELINE="$active/originals"
elif [ -f "$active/module.prop" ] && [ ! -f "$active/disable" ]; then
    echo 'Active older module or changed ROM: disable it, reboot, then reinstall to capture clean ROM settings.' >&2
    exit 1
fi
if [ -z "$BASELINE" ] && [ -f "$active/gps.conf" ]; then
    for target in /odm/etc/gps.conf /vendor/etc/gps.conf /system/etc/gps.conf; do
        if [ -f "$target" ] && cmp -s "$active/gps.conf" "$target"; then
            echo 'Legacy config is still mounted; reboot after disabling before reinstalling.' >&2
            exit 1
        fi
    done
fi
for entry in odm:/odm/etc/gps.conf:system/odm/etc/gps.conf vendor:/vendor/etc/gps.conf:system/vendor/etc/gps.conf system:/system/etc/gps.conf:system/etc/gps.conf framework:/system/etc/gps_debug.conf:system/etc/gps_debug.conf; do
    name=${entry%%:*}; rest=${entry#*:}; target=${rest%%:*}; output=${rest#*:}
    original="$MODDIR/originals/$name.conf"
    if [ -n "$BASELINE" ]; then
        if [ -f "$BASELINE/$name.conf" ]; then
            [ "$BASELINE/$name.conf" = "$original" ] || cp "$BASELINE/$name.conf" "$original"
        else
            [ "$name" = framework ] || continue
            : > "$original"
        fi
    elif [ -f "$target" ]; then
        cp "$target" "$original"
    else
        [ "$name" = framework ] || continue
        : > "$original"
    fi
    patch="$MODDIR/gps.conf"
    [ "$name" != framework ] || patch="$MODDIR/framework.conf"
    mkdir -p "${MODDIR}/${output%/*}"
    gps_awk -f "$MODDIR/merge-config.awk" "$patch" "$original" > "$MODDIR/$output"
    chmod 644 "$MODDIR/$output"
    case "$output" in
        system/odm/*|system/vendor/*)
            chcon u:object_r:vendor_configs_file:s0 "$MODDIR/$output" 2>/dev/null || true
            ;;
        system/etc/*)
            chcon u:object_r:system_file:s0 "$MODDIR/$output" 2>/dev/null || true
            ;;
    esac
done
printf '%s\n' "$fingerprint" > "$MODDIR/originals/fingerprint"
