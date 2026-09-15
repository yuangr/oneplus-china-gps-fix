# OnePlus China GPS Fix

当前设备：**一加 Ace 6（PLQ110）、骁龙 8 至尊版（Snapdragon 8 Elite / SM8750）、Evolution X Android 17 / SDK 37**。

## v1.4.0

- 挂载统一交给 Root 管理器；APatch/KernelSU 需要兼容的挂载提供者，当前手机使用 Hybrid Mount。脚本不再执行 bind mount。
- 安装时基于当前 ROM 原始配置生成 HAL gps.conf 和 AOSP gps_debug.conf，保留 RF、CAPABILITIES、LPP、紧急定位和 NFW 参数。originals/ 保存基线。
- 配置国内 NTP、高通长期星历及此前使用的千寻 SUPL 地址；这不等于启用 RTK/PPP，也不保证秒定或精度提升。服务端兼容性仍需实测。
- 普通/实时 PSDS 保持原厂设置，不再用长期文件混填。移除独立 xtra3.bin 下载及跳过 TLS 验证的逻辑。
- 开机且定位开启时至多成功提交一次 PSDS 请求，随后请求时间辅助并退出。Android 负责下载、离线排队、重试和注入。没有屏幕/GPS 轮询，不修改全局 NTP 设置。
- 文件锁防并发；每次开机记录提交状态；命令失败最多重试三次，间隔 15/30 秒。命令成功不等于下载/注入成功。
- 移除宽泛 SELinux 授权和 pkill -f service.sh。

## 安装与升级

通过 Root 管理器安装 ZIP 后重启。ZIP 只包含补丁模板，customize.sh 在安装时生成适合当前 ROM 的 system/ 文件。

旧模块没有可靠 originals/ 时，先禁用并重启再安装；或者使用从只读 ROM 分区独立读取的基线运行 prepare-config.sh。本次 Ace 6 迁移使用独立挂载命名空间读取的原始文件。仅点击禁用而不重启，旧挂载仍然存在。

换 ROM 后需要重新生成配置，不能直接复制另一 ROM 的 originals/。指纹校验只能发现明显不匹配，不能抵御 ROM 的指纹伪装。

不在线卸载旧版累积的挂载；重启后清除旧挂载并加载新配置及权限。运行中的框架可能缓存旧设置，因此升级后必须重启。

## 验证

- 模块 v1.4.0，挂载提供者启用。
- /odm/etc/gps.conf 包含国内辅助服务器及保留的原厂硬件参数。
- /system/etc/gps_debug.conf 包含 LONGTERM_PSDS_SERVER_1。
- runtime/service.log 区分提交、跳过和失败，不宣称注入成功。
- 启动完成后没有常驻 service.sh；重复运行 restart.sh 不增加挂载或重复成功提交。
- 通过 GNSS 日志确认下载与注入；室外对比首次定位时间、参与定位的卫星和误差，并验证离线恢复、息屏导航。日常无需清除辅助数据。

## 回滚

Root 管理器禁用模块并重启即可恢复 ROM 配置。2026-09-14 迁移另有电脑与手机端完整旧模块备份；仅在需要恢复旧行为时还原。

## 参考

- [AOSP 配置加载](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/location/gnss/GnssConfiguration.java)
- [AOSP 下载与注入](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/location/gnss/GnssLocationProvider.java)
- [AOSP PSDS 类型](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/location/gnss/GnssPsdsDownloader.java)
