#!/system/bin/sh
MODDIR=${0%/*}

# Ensure overlay files have proper SELinux contexts before modules are mounted
if [ -d "$MODDIR/system/odm" ]; then
    chcon -R u:object_r:vendor_configs_file:s0 "$MODDIR/system/odm" 2>/dev/null || true
fi
if [ -d "$MODDIR/system/vendor" ]; then
    chcon -R u:object_r:vendor_configs_file:s0 "$MODDIR/system/vendor" 2>/dev/null || true
fi
if [ -d "$MODDIR/system/etc" ]; then
    chcon -R u:object_r:system_file:s0 "$MODDIR/system/etc" 2>/dev/null || true
fi

exit 0
