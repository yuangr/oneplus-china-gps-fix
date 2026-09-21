# OnePlus China GPS Fix

当前设备：**一加 Ace 6（PLQ110）、骁龙 8 至尊版（Snapdragon 8 Elite / SM8750）、Evolution X Android 17 / SDK 37**。

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

- 模块 v1.4.3，挂载提供者（如 Hybrid Mount）正常启用。
- `/odm/etc/gps.conf` 与 `/system/etc/gps_debug.conf` 中千寻 SUPL 端口均为 `SUPL_PORT=7275`。
- `/system/etc/gps_debug.conf` 包含国内高速 `LONGTERM_PSDS_SERVER_1`。
- 通过 GNSS 测试软件（如 GPSTest）与高德地图验证冷启动秒级获取星历与北斗卫星锁定。

## 回滚

Root 管理器禁用模块并重启即可恢复 ROM 配置。2026-09-14 迁移另有电脑与手机端完整旧模块备份；仅在需要恢复旧行为时还原。

## 参考

- [AOSP 配置加载](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/location/gnss/GnssConfiguration.java)
- [AOSP 下载与注入](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/location/gnss/GnssLocationProvider.java)
- [AOSP PSDS 类型](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/location/gnss/GnssPsdsDownloader.java)
