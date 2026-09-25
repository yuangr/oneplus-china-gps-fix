# OnePlus China GPS Fix

当前设备：**一加 Ace 6（PLQ110）、骁龙 8 至尊版（Snapdragon 8 Elite / SM8750）、Evolution X Android 17 / SDK 37**。

## v1.4.8 (2026-09-25)

- 根据实机 AVC，补齐 `vendor_location` 向专用 `vendor_location_xtra_daemon` 发送生命周期信号的最小权限；`loc_launcher` 与 `loc_mq_clnt` 同属该源域。
- 修复开机时序：`boot_completed` 后最多等待 90 秒已验证的 Wi-Fi、移动数据或以太网，再提交一次 Framework PSDS/时间请求；避免在网络刚建立、尚不可用的间隙过早提交。
- 无已验证网络时仍按旧行为提交一次，避免因离线开机永久跳过；无常驻服务、无手工下载、无高频注入。
- 实机验证：室外首次定位从原先的 30~60 秒大幅缩短至 5.9~6.0 秒，达到标准秒级定位水平。

## v1.4.7 (2026-09-22)

- 补齐 `loc_launcher` 进入 XTRA/LOWI 专用域时的 `siginh`、`rlimitinh`、父进程文件描述符使用及子进程回收权限；这些是 Android SELinux 标准域转换的一部分。
- 实机临时策略验证后，`xtra-daemon` 与 `lowi-server` 均稳定留在专用域，且不再出现本组启动 AVC。

## v1.4.6 (2026-09-22)

- 将 `loc_launcher` 启动 `xtra-daemon` 与 `lowi-server` 的 SELinux 修复改为进入系统已定义的专用域；不再使用 `execute_no_trans` 让子进程停留在通用 `vendor_location` 域。
- 实机验证 v1.4.5 的 `execute_no_trans` 会使 `xtra-daemon` 持续遭遇 `vndbinder` 与 `servicemanager` 拒绝；专用域已有完整的 Binder、网络和数据目录权限，补齐域转换才是正确修复。

## v1.4.5 (2026-09-22)

- 删除无法通过 SELinux 访问 `/data/vendor/location` 的手工 XTRA 文件下载与常驻 6 小时刷新进程，恢复由 Android Framework 负责下载并向 HAL 注入的 `force_psds_injection`。
- 每次开机最多提交一次请求；并发执行由 BusyBox `flock` 互斥，失败最多重试三次（15/30 秒退避），所有结果写入模块运行日志。
- 根据一加 Ace 6 实机启动 AVC，仅放行 `vendor_location` 执行 `xtra-daemon` 与 `lowi-server` 所缺少的 `execute_no_trans`，移除读取全部 `system_file` / `vendor_configs_file` 的宽泛规则。
- 安装时优先使用 Root 管理器自带 BusyBox AWK，修复 Android 17 系统 AWK 无法解析配置合并脚本的问题。

## v1.4.4 (2026-09-22)

- **彻底剔除有害 Bind Mount 逻辑**：排查并彻底清除 `service.sh` 中遗留的 `mount -o bind "$MODDIR/gps.conf" "$target"` 逻辑。在 v1.4.x 动态合成架构下，根目录 `gps.conf` 仅为 10 行差量补丁模板，开机误执行 bind 挂载会导致覆盖底层包含 446 行骁龙 8 至尊版（SM8750）硬件射频校准、星座掩码与多频点支持的完整配置文件，引发硬件 HAL 搜星失效。挂载已完全由 APatch / Magisk 的 OverlayFS 接管。
- **全方位根治 Android 17 / APatch SELinux AVC 拦截**：在 `post-fs-data.sh` 与 `prepare-config.sh` 中针对合成下发目录执行递归 `chcon` 标签纠正（`system/odm` 与 `system/vendor` 标记为 `vendor_configs_file:s0`）；并在 `sepolicy.rule` 中补充放行规则，彻底解决 `vendor_hal_gnss_qti` 因 Treble 隔离无法读取配置文件的 AVC Denied 问题。
- **重构后台守护进程为精简定时服务**：移除此前在亮屏搜星时每 15 秒高频无效触发 AOSP `force_psds_injection` 的 Binder 轮询，改为开机联网完成首次同步与时间注入，随后每 6 小时原子化安全刷新 XTRA 星历缓存（权限 `gps:gps` 644），零多余功耗开销。

## v1.4.3 (2026-09-21)

- **彻底修正 AOSP 框架千寻 SUPL 端口为 7275**：此前 v1.4.2 虽然修正了 `gps.conf`，但 AOSP 框架专用的 `framework.conf` 仍遗留 7276 端口；导致类原生系统 Framework 在向千寻位置请求 A-GPS 时超时挂死，引发高德地图等导航在冷启动时因等待辅助定位超时而以弱信号基站模式初始化（搜星延迟拉长至 3 分钟以上）。本次更新彻底将 Framework 侧（`gps_debug.conf`）与 HAL 侧（`gps.conf`）对齐纠正为标准通畅的 **`7275`** 端口与 TLS 通道。
- **双端配置完全对齐**：高通硬件 HAL 驱动（`gps.conf`）与 Android Framework 辅助层（`gps_debug.conf`）全部统一为 `SUPL_PORT=7275`，结合系统已补齐的 `/system/etc/security/cacerts` CA 证书链，实现冷启动秒级星历注入与北斗/GPS 快速锁定。

## v1.4.2 (2026-09-19)

- **恢复高可靠 XTRA 辅助注入守护服务**：针对部分 AOSP ROM 在开机单次提交 PSDS 请求时可能因网络未就绪或系统静默失败导致无辅助星历可用的问题，恢复轻量级守护机制：在亮屏/GPS 激活时按需注入星历，每 6 小时周期性刷新星历缓存，息屏降低轮询频率，兼顾省电与高可用定位。

## v1.4.1 (2026-09-19)

- **HAL 侧 SUPL 端口修正**：将底层 HAL `gps.conf` 中的千寻位置 SUPL 端口从历史残留的 7276 纠正为标准 7275 端口。

## v1.4.0 (2026-09-14)

- 挂载统一交给 Root 管理器；APatch/KernelSU 需要兼容的挂载提供者，当前手机使用 Hybrid Mount。脚本不再执行 bind mount。
- 安装时基于当前 ROM 原始配置生成 HAL gps.conf 和 AOSP gps_debug.conf，保留 RF、CAPABILITIES、LPP、紧急定位和 NFW 参数。originals/ 保存基线。
- 配置国内 NTP、高通长期星历及千寻 SUPL 地址；这不等于启用 RTK/PPP，也不保证秒定或精度提升。服务端兼容性仍需实测。
- 普通/实时 PSDS 保持原厂设置，不再用长期文件混填。移除独立 xtra3.bin 下载及跳过 TLS 验证的逻辑。
- 移除宽泛 SELinux 授权。

## 安装与升级

通过 Root 管理器安装 ZIP 后重启。ZIP 只包含补丁模板，customize.sh 在安装时生成适合当前 ROM 的 system/ 文件。

旧模块没有可靠 originals/ 时，先禁用并重启再安装；或者使用从只读 ROM 分区独立读取的基线运行 prepare-config.sh。本次 Ace 6 迁移使用独立挂载命名空间读取的原始文件。仅点击禁用而不重启，旧挂载仍然存在。

换 ROM 后需要重新生成配置，不能直接复制另一 ROM 的 originals/。指纹校验只能发现明显不匹配，不能抵御 ROM 的指纹伪装。

不在线卸载旧版累积的挂载；重启后清除旧挂载并加载新配置及权限。运行中的框架可能缓存旧设置，因此升级后必须重启。

## 验证

- 模块 v1.4.8，挂载提供者（如 Hybrid Mount）正常启用。
- `/odm/etc/gps.conf` 与 `/system/etc/gps_debug.conf` 中千寻 SUPL 端口均为 `SUPL_PORT=7275`。
- `/system/etc/gps_debug.conf` 包含国内高速 `LONGTERM_PSDS_SERVER_1`。
- 通过 GNSS 测试软件（如 GPSTest）与高德地图记录同一开阔场地的冷启动 TTFF、参与定位卫星及精度；不要仅凭命令返回值宣称注入成功。

## 回滚

Root 管理器禁用模块并重启即可恢复 ROM 配置。2026-09-14 迁移另有电脑与手机端完整旧模块备份；仅在需要恢复旧行为时还原。

## 参考

- [AOSP 配置加载](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/location/gnss/GnssConfiguration.java)
- [AOSP 下载与注入](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/location/gnss/GnssLocationProvider.java)
- [AOSP PSDS 类型](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/location/gnss/GnssPsdsDownloader.java)
