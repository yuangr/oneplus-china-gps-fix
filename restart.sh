pkill -f service.sh
nohup sh /data/adb/modules/oneplus_cn_gps_fix/service.sh > /dev/null 2>&1 &
cmd location providers send-extra-command gps force_time_injection 2>/dev/null || cmd location send-extra-command gps force_time_injection 2>/dev/null
cmd location providers send-extra-command gps force_psds_injection 2>/dev/null || cmd location send-extra-command gps force_psds_injection 2>/dev/null
