# OnePlus China GPS / BeiDou Accelerator (一加类原生北斗与高精度 GPS 搜星加速模块)

[![Platform](https://img.shields.io/badge/Platform-Qualcomm%20Snapdragon-orange.svg)](#)
[![Android Version](https://img.shields.io/badge/Android-15%20%7C%2016-green.svg)](#)
[![Root Support](https://img.shields.io/badge/Root-APatch%20%7C%20KernelSU%20%7C%20Magisk-blueviolet.svg)](#)

专为**一加 (OnePlus) 旗舰机型**及刷入 **Infinity-X、LineageOS、PixelOS 等 AOSP 类原生 ROM** 的设备打造。解决高德地图、百度地图等国内导航软件在类原生系统下**“连接不上北斗卫星导航”、“搜星极慢/无信号”、“冷启动长达十几分钟”**的问题。

---

## 🔍 问题背景与原理

在刷入类原生（AOSP）系统后，高德地图提示“未连接北斗卫星导航”，主要原因并非硬件不支持，而是底层配置与网络在国内受阻：

1. **一加专属底层路径问题**：
   - 一加高通平台的 GNSS 硬件抽象层（`libgps.utils.so`）只读取 `/vendor/odm/etc/gps.conf`（即 `/odm/etc/gps.conf`），**不读取**常规模块修改的 `/system/etc/gps.conf` 或 `/vendor/etc/gps.conf`，导致社区旧模块全部失效。
2. **A-GPS 辅助服务器被墙**：
   - 原生系统默认请求 `supl.google.com:7275`，国内直连超时（Timeout）。没有 A-GPS 注入卫星轨道星历，手机被迫退化为**纯硬件冷启动**（卫星空中广播传输星历速率仅 50 bps），在室内/车内几乎永远无法完成定位。
3. **授时服务器断连**：
   - 默认配置的 `time.xtracloud.net` 在国内实测 **100% 丢包**；系统全局 `ntp_server` 为空，芯片缺乏精确微秒级时间参考。
4. **缺失多星系 XTRA 3.0**：
   - 未配置高通在国内的高速 XTRA CDN 节点，无法秒级下载包含**北斗（BDS）**在内的多星座轨道参数。

---

## ✨ 核心优化特性

- 🛰 **高通 XTRA 3.0 全星系预报星历秒级热注入 (v1.2.0 新增)**：
  - 内置智能后台守护，开机与每隔 12 小时自动从高通官方国内 CDN 节点（`https://pathcf.prod.xtracloud.cn/xtra3Mgrbeji.bin`）拉取 7 天预报星历（64KB）。
  - 通过 Android 定位框架标准接口（`force_psds_injection` 与 `force_time_injection`）主动热注入高通基带，彻底解决类原生系统由于缺少运营商后台导致首次定位沦为 **80 秒纯冷启动** 的顽疾，实现 **1~3 秒极速秒定**。
- 🇨🇳 **千寻位置国家北斗地基增强网 SUPL**：
  - 配置 `supl.qxwz.com:7276`（免 TLS 证书非加密端口），彻底消除高通基带在缺少千寻企业私有 CA 证书时引发的 15~30 秒 TLS 握手假死与超时等待。
- ⚡️ **高精度国内双云授时**：
  - 注入阿里云（`ntp.aliyun.com`）、腾讯云（`ntp.tencent.com`）与中国 NTP 池（`cn.pool.ntp.org`），网络延迟降至 20ms，丢包率 0%。
  - 开机通过 `settings put global ntp_server` 同步修正 Android 全局系统授时。
- 🔒 **无损与高兼容性**：
  - 修复 `gps.conf` 中的 CA 证书路径为 Android 标准 `/system/etc/security/cacerts`。
  - 完整保留原厂全部硬件射频损耗（RF Loss）、PPS 脉冲同步、DR 惯导与陀螺仪参数。
  - 通过 `post-fs-data` 与 `service.sh` 动态多点挂载，全面覆盖 `/odm/etc/`、`/vendor/odm/etc/` 与 `/vendor/etc/`。
  - 内置 `sepolicy.rule` 策略注入，完美兼容 SELinux Enforcing 强制模式。

---

## 📱 适配设备与系统

- **测试机型**：一加 Ace 6 (PLQ110 / 骁龙 8 至尊版)，向下兼容一加 Ace 2/3 系列、一加 11/12/13/15 等高通平台机型。
- **系统支持**：Android 15、Android 16（Infinity-X、LineageOS、Evolution X、CrDroid 等各类 AOSP ROM）。
- **Root 管理器**：APatch、KernelSU、Magisk。

---

## 🚀 安装方法

### 方式一：APatch / KernelSU / Magisk 刷入（推荐）
1. 前往本仓库的 Releases 页面下载最新的 `OnePlus_China_GPS_BeiDou_Fix.zip`。
2. 打开 **APatch** / **KernelSU** / **Magisk** 应用。
3. 进入“模块”板块，选择“从本地安装”，选中下载的 zip 文件。
4. 安装完成后**重启手机**即可生效。

### 方式二：ADB 命令行一键推送到手机
如果手机已开启 USB 调试且已 Root：
```bash
adb push OnePlus_China_GPS_BeiDou_Fix.zip /sdcard/Download/
```
然后直接在手机管理器中刷入。

---

## 🧪 验证搜星效果

1. 重启手机后，确保开启系统“使用精确位置”。
2. 打开 **高德地图** 或开源测试软件 **GPSTest**。
3. 在窗边或室外开阔处打开导航，观察顶部状态：
   - 数秒内即可看到大量中国国旗 🇨🇳（BDS / 北斗）卫星被锁定。
   - 高德地图顶部快速点亮并提示：**“已连接北斗卫星导航”**。

---

## 🧭 类原生秒级定位的“最后一块拼图”：网络定位 (NLP)

> [!IMPORTANT]
> **搜星速度（TTFF，首次定位时间）在物理上由三要素决定：精确时间 + 预报星历 + 粗略初始位置（Coarse Location）。**
> 
> 1. **原厂系统的秘密**：在官方 ColorOS 下，高德/百度地图调用系统内置的国内网络定位服务（NLP），利用附近 Wi-Fi BSSID 与基站信号在 **0.1 秒内** 获得几百米精度的粗略经纬度并注入基带。有了大致坐标，高通芯片只需在天顶可见的十余颗卫星频段上精确解算，实现 **1~2 秒秒定**。
> 2. **类原生系统的短板**：刷入类原生（AOSP）后，原生的 Google 网络定位在国内完全不可用，若 ROM 未内置国内 NLP，高通芯片**完全不知道自己位于地球何处**，被迫盲扫全天球 100 多颗卫星并从空中 50 bps 的微弱广播流中解算，即使星历注入成功，在没有粗略位置辅助时首次定位仍可能需要数十秒。
> 
> **💡 终极提速建议**：
> - 配合安装 **MicroG** 并开启 **高德定位后端 / 百度定位后端 (UnifiedNLP)**，或者使用 Magisk/KernelSU 刷入国内网络定位补丁模块。
> - 在拥有粗略位置 + 本模块提供的 XTRA 3.0 全星系预报星历与阿里云授时后，即可实现真正的 **1 秒极速冷启秒定**！

---

## 📝 更新日志

### 🚀 v1.3.0
- **全节点纯化与去污染**：彻底剔除 `gps.conf` 中被国内屏蔽的海外 XTRA / PSDS 节点，所有备用节点统一采用国内高通官方 CloudFront CDN，杜绝 AOSP 随机选点触发的 30~90 秒网络连接挂死。
- **SUPL 免证书端口切换**：将千寻位置 SUPL 端口由 `7275` 切换为免证书握手的 `7276` 端口，消除基带因缺少私有 CA 证书造成的 TLS 握手假死。
- **AOSP PSDS 键名全兼容与热注入增强**：补全 AOSP 标准键名（`LONGTERM_PSDS_SERVER` 等）与高通底层 `XTRA_SERVER` 系列键名；配合响应式后台守护，应用唤醒 GPS 硬件时毫秒级热补发轨道星历与高精授时。
- **进程耗电与稳定性优化**：加入亮息屏动态轮询检测与关机状态识别（`sys.shutdown.requested`），防止关机死锁并极大降低待机功耗；全项目脚本与配置文件行尾符统一规范为 Linux (LF)。
- **守护进程防阻塞改造**：重构 `service.sh`，彻底移除依赖 ICMP 的 `ping` 网络死循环检测，改用路由表与连接服务双重判断，完美兼容拦截 Ping 报文的移动蜂窝数据网络。
- **Android 12~16 全版本注入适配**：支持 `cmd location providers send-extra-command` 与 `cmd location send-extra-command` 双重兼容回退。
- **KernelSU / APatch 深度适配与多点挂载**：直接提供顶层 `vendor` 与 `odm` 镜像目录，解决 OverlayFS 无法穿透动态分区的问题；在 `post-fs-data` 与 `service` 阶段覆盖 `/odm/etc/`、`/vendor/etc/` 与 `/system/etc/` 全局挂载；扩充 AIDL GNSS (`hal_gnss_default` 等) SELinux 策略规则。

### 🚀 v1.2.0
- **全星系星历秒级热注入**：解决类原生 ROM 在缺少运营商组件时首次搜星长达 80 秒纯冷启动的问题，开机与每隔 12 小时自动拉取高通中国 CDN 预报星历并主动注入基带。
- **证书路径修复**：修正 `gps.conf` 中不存在的 Linux 证书路径为 Android 标准 `/system/etc/security/cacerts`。
- **时间注入权限开放**：开启 `CAPABILITIES=0x37`（+ `TIME_INJECTION`），支持系统框架直接下发高精 NTP 授时。
- **SUPL 假死消除**：移除未安装的 `carrierlocation` NFW 规则，杜绝基带因请求 IMSI 失败产生的 30~60 秒超时假死。
- **挂载覆盖增强**：自动补全 `/vendor/etc/gps.conf` 动态挂载点。
- **CI 打包修复**：GitHub Actions 自动构建补齐 `sepolicy.rule`。

### 🚀 v1.1.0
- **SELinux Enforcing 深度适配**：补充 `sepolicy.rule` 规则，消除 AviumUI / LineageOS 强制模式下的 AVC 权限拒绝。

### 🚀 v1.0.0
- 初始版本发布，支持阿里云/腾讯云 NTP 授时与千寻位置 SUPL 2.0。

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。
