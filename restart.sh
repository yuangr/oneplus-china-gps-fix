#!/system/bin/sh
# No pkill: service uses a lock and a per-boot submission marker.
MODDIR=${0%/*}
exec /system/bin/sh "$MODDIR/service.sh"
