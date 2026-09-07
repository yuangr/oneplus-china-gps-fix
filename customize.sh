ui_print "- 正在安装 OnePlus China GPS / BeiDou Accelerator..."
ui_print "- 目标设备: 一加 (OnePlus) 高通平台"
ui_print "- 适配系统: Android 15 / 16 (AviumUI / Infinity-X / AOSP)"
ui_print "- 适配模式: 支持 SELinux Enforcing 强制模式"
ui_print "- 注入阿里云/腾讯 NTP 高精度授时..."
ui_print "- 注入千寻位置国家北斗地基增强网 SUPL A-GPS (7275)..."
ui_print "- 注入高通 XTRA 3.0 中国节点 (pathcf.prod.xtracloud.cn) 全星系星历..."
ui_print "- 校验配置文件与安全上下文..."

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/sepolicy.rule" 0 0 0644
set_perm "$MODPATH/gps.conf" 0 0 0644
chcon u:object_r:vendor_configs_file:s0 "$MODPATH/gps.conf" 2>/dev/null

ui_print "- 安装成功！重启手机后即可享受秒级北斗高精搜星。"
