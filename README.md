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

- 🇨🇳 **千寻位置国家北斗地基增强网 SUPL**：
  - 配置 `supl.qxwz.com:7275`，实测秒连开放。
  - 升级 SUPL 协议版本至 `0x20000` (SUPL 2.0)，全面支持 4G/5G 多星系定位。
- ⚡️ **高精度国内双云授时**：
  - 注入阿里云（`ntp.aliyun.com`）、腾讯云（`ntp.tencent.com`）与中国 NTP 池（`cn.pool.ntp.org`），网络延迟降至 20ms，丢包率 0%。
  - 开机通过 `settings put global ntp_server` 同步修正 Android 全局系统授时。
- 🛰 **高通 XTRA 3.0 中国节点全星系星历**：
  - 配置高通官方国内特供 CDN 节点 `https://pathcf.prod.xtracloud.cn/xtra3Mgrbeji.bin`。
  - 完整包含 GPS（M）、GLONASS（g）、Galileo（r）、BeiDou 北斗（b）、QZSS（e）全星系星历数据。
- 🔒 **无损与高兼容性**：
  - 完整保留原厂全部硬件射频损耗（RF Loss）、PPS 脉冲同步、DR 惯导与陀螺仪参数。
  - 通过 `post-fs-data` 动态挂载，兼容 EROFS 只读分区与 Android 15/16 新架构。

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

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。
