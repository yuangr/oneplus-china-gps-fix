ui_print '- OnePlus China GPS Fix v1.4.5'
ui_print '- OnePlus Ace 6 / SM8750 / Evolution X Android 17'
ui_print '- Requires systemless mounting; APatch/KernelSU needs a mount provider'
sh "$MODPATH/prepare-config.sh" || abort '- Could not safely prepare ROM-specific configuration'
set_perm_recursive "$MODPATH" 0 0 0755 0644
for script in service.sh post-fs-data.sh restart.sh prepare-config.sh; do
    set_perm "$MODPATH/$script" 0 0 0755
done
for config in "$MODPATH/system/odm/etc/gps.conf" "$MODPATH/system/vendor/etc/gps.conf"; do
    [ ! -f "$config" ] || set_perm "$config" 0 0 0644 u:object_r:vendor_configs_file:s0
done
if [ -f "$MODPATH/system/etc/gps.conf" ]; then
    set_perm "$MODPATH/system/etc/gps.conf" 0 0 0644 u:object_r:system_file:s0
fi
set_perm "$MODPATH/system/etc/gps_debug.conf" 0 0 0644 u:object_r:system_file:s0
mkdir -p "$MODPATH/runtime"
cat /proc/sys/kernel/random/boot_id > "$MODPATH/runtime/defer_boot"
set_perm_recursive "$MODPATH/runtime" 0 0 0700 0600
ui_print '- Installed. Reboot to load overlays; validate positioning outdoors.'
