# GPS 优化验证记录

设备：一加 Ace 6 / PLQ110 / sun，骁龙 8 至尊版 Snapdragon 8 Elite / SM8750，Evolution X Android 17 / SDK 37。

## v1.4.7 最终验证 — 2026-09-22

- APatch 报告模块 `v1.4.7` / `versionCode=147`，已启用且没有待处理更新。
- 完整重启后，`loc_launcher` 运行于 `vendor_location`；其子进程 `lowi-server` 和 `xtra-daemon` 分别稳定运行于系统已有的 `vendor_location_lowi_server` 与 `vendor_location_xtra_daemon` 专用域。
- 冷启动及延时复查均没有出现与 `loc_launcher`、`lowi-server`、`xtra-daemon` 或上述域相关的新 AVC；模块没有常驻 `service.sh` 进程。
- 服务日志在本次 boot ID 下记录一次 `PSDS command submitted` 和一次 `time command submitted`。这只能证明 Framework 接受命令，不能单独证明服务端下载及 HAL 注入成功。
- `/odm/etc/gps.conf` 保持 452 行、`vendor_configs_file` 标签、`CAPABILITIES=0x17`、千寻 `SUPL_PORT=7275` 及原厂 XTRA 地址；`/system/etc/gps_debug.conf` 保持 `system_file` 标签。
- `/proc/mounts` 共 168 项，仅有 `/odm/etc` 与 `/system/etc` 两个模块目录覆盖，没有 `gps.conf` 单文件绑定挂载。
- 手机隔离测试全部通过：每开机一次请求、关闭定位、失败重试、并发锁、旧式命令、关机、热升级、禁用、配置合并及 SELinux 静态约束。

v1.4.5 的 `execute_no_trans` 虽能启动原厂辅助进程，但让它们停留在 `vendor_location`，导致 `xtra-daemon` 持续遭遇 `vndbinder`/`servicemanager` 拒绝。v1.4.6 改用专用域后，又暴露出父进程资源和文件描述符继承权限不完整。v1.4.7 按 Android 标准域转换补齐 `siginh`、`rlimitinh`、`noatsecure` 静默项、父进程 FD 使用及 `sigchld`，实机验证稳定。

仍需在室外开阔场地进行同条件冷启动 TTFF、参与定位卫星、精度与离线恢复 A/B 测试，才能量化定位效果。

## 实施结果

- GPS 模块已更新至 v1.4.7，并在目标手机完成安装、完整重启和冷启动检查。
- 通过 APatch 官方命令行安装并重启；现有 Hybrid Mount 正常提供 systemless 配置覆盖。
- 从只读 ROM 分区、独立挂载命名空间读取原始 ODM / framework 配置。ROM 原本没有 vendor/etc/gps.conf 和 system/etc/gps.conf，不再人为增加这两个副本。
- 生成配置保留 61 项未覆盖的原厂设置，包括 CAPABILITIES=0x17、LPP_PROFILE=2；只变更明确列出的服务器配置及 SUPL 版本。
- AOSP gps_debug.conf 配置长期 PSDS；没有用长期文件覆盖 NORMAL/REALTIME 类型。
- 移除独立星历文件下载、高频注入、屏幕/GPS 轮询、手动 bind mount、全局 pkill 和额外宽泛 SELinux 授权。
- 重启前有 2,047 条 gps.conf 独立挂载记录；重启后为 0，配置通过挂载提供者的目录覆盖生效。

## 测试

Android 实机 shell 隔离测试通过：

1. 同一开机周期仅提交一次请求对，重复运行跳过。
2. 关闭定位时跳过且不消耗本次开机请求机会。
3. 命令失败最多尝试 3 次，退避 15/30 秒，不误记成功。
4. 并发调用由 BusyBox 文件锁互斥。
5. 兼容旧式 send-extra-command 命令选择。
6. 关机期间不提交请求。
7. 热升级延迟标记生效。
8. 模块禁用标记生效。
9. 配置合并保留硬件参数、PSDS 类型与注释，去重覆盖键，支持空基线。

测试中的模拟 Binder 同时检查 stdout 必须为管道，覆盖本次实机发现的日志文件句柄错误。脚本 LF 和 sh -n 检查通过。

## 实机检查

14:41:05，新服务记录 PSDS command submitted 和 time command submitted；再次运行记录 request already submitted this boot。命令提交成功不代表数据已成功下载或被 HAL 接受。

发现并修复的兼容问题：

- Android mksh 不可靠地保留传给外部 flock 的高编号文件描述符，改用 BusyBox flock FILE PROGRAM 持锁执行。
- Binder 命令直接重定向到模块日志文件返回 Failed transaction；改用管道收集输出后由脚本写日志，实机返回成功。未通过扩大 SELinux 授权绕过。

## 尚未量化

未进行室外同条件首次定位时间、精度、参与定位卫星、离线恢复或耗电 A/B 测试；不能宣称秒定、精度提升或具体省电比例。PSDS 下载/基带注入是否实际完成仍需对应 GNSS/HAL 日志确认。

## 备份与回滚

- 电脑旧模块归档：backup-phone/oneplus-gps-before-20260914.tar。
- 手机旧模块归档：/data/local/tmp/oneplus-gps-before-20260914.tar。
- 本地仓库原文件：backup-local/。
- 原始 ROM 配置：rom-baseline/。
- Obsidian 修改前副本：guide.before.md、guide.before-final-write.md。
- 常规回滚：Root 管理器禁用 GPS 模块并重启，恢复 ROM 默认配置。
