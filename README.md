# TailScreens 📱🖥️

> **像 Screens 一样优雅地在 iPhone 上通过 Tailscale 控制你的 Mac。**
> 
> A sleek, high-performance iOS remote desktop client designed specifically for macOS Screen Sharing over Tailscale, inspired by Edovia Screens.

[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%206.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue.svg)](https://developer.apple.com)
[![Protocol](https://img.shields.io/badge/Protocol-RFB%203.8%20(VNC)-green.svg)](https://datatracker.ietf.org/doc/html/rfc6143)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

---

## 🌟 核心特性 (Features)

### 1. 🌐 Tailscale 深度集成
* **零配置发现**：集成 Tailscale REST API，自动拉取你的 Tailnet 下所有在线 Mac / PC 设备列表。
* **点对点穿透**：通过 WireGuard 隧道直接与远端机器建立安全 TCP Socket，无需公网 IP，告别复杂的端口转发。

### 2. ⚡ 原生纯 Swift RFB 3.8 引擎
* **基于 Network.framework**：利用 Apple 官方非阻塞网络栈 (`NWConnection`) 替代过时的 BSD Sockets，低延迟、低功耗。
* **纯 Swift DES 认证**：内置标准 VNC Security Type 2 (DES Challenge-Response) 加密算法，零第三方外部依赖。
* **增量脏矩形渲染**：严格按照 RFB 规范仅请求并解码屏幕变动区域 (Dirty Rects)，支持 32 位色彩快速上屏与高帧率渲染。
* **动态分辨率适配**：支持 DesktopSize 扩展，远端 Mac 切换外接显示器或分辨率改变时动态自适应。

### 3. 🎯 媲美 Screens 的移动端交互体系
* **虚拟触控板模式 (Virtual Trackpad)**：
  * 采用 macOS 经典非线性加速度曲线，手指在小屏幕上微调精准、大范围滑动快速。
  * **单指轻敲**：左键单击
  * **双指轻敲**：右键 / 上下文菜单
  * **单指长按**：窗口拖拽 / 区域框选
  * **双指上下滑动**：自然滚轮平滑滚动
* **直接触摸模式 (Direct Touch)**：点触即点击，配合双指缩放 (Pinch-to-zoom) 漫游画布。

### 4. ⌨️ Mac 专属键盘扩展栏 (Mac Keyboard Bar)
* **粘滞修饰键 (Sticky Modifiers)**：`⌘ Command`、`⌥ Option`、`⌃ Control`、`⇧ Shift`，支持单次触发或双击锁定。
* **高频系统动作一键直达**：
  * 🔍 **聚焦搜索 (Spotlight)**: `⌘ + Space`
  * 🪟 **调度中心 (Mission Control)**: `⌃ + ↑`
  * 📱 **应用切换器 (App Switcher)**: `⌘ + Tab`
  * 🔒 **快速锁屏**: `⌃ + ⌘ + Q`
  * `Esc`, `Tab`, `Return`, `Space`, 方向键 (`← ↑ ↓ →`)
* **双向剪贴板同步**：手机端与 Mac 剪贴板一键互通。

---

## 🏗️ 架构设计 (Architecture)

```
┌────────────────────────────────────────────────────────┐
│                   TailScreens iOS App                  │
├────────────────────┬───────────────────────────────────┤
│ UI 表现层          │ DeviceListView (设备卡片流 / 状态指示)   │
│                    │ RemoteDesktopView (手势视口 / 浮动工具栏)│
│                    │ MacKeyboardToolbar (Mac专用辅助按键) │
├────────────────────┼───────────────────────────────────┤
│ 交互引擎层         │ TrackpadEngine (虚拟触控板手势与加速度)   │
│                    │ MacKeyMap (X11 KeySym 与 Mac 快捷键映射) │
├────────────────────┼───────────────────────────────────┤
│ 协议与网络层       │ RFBClient (RFB 3.8 状态机 & 消息循环)   │
│                    │ RFBEncoder / RFBDecoder (二进制编解码)   │
│                    │ VNCAuthCrypto (DES ECB 密码挑战加解密)  │
│                    │ Framebuffer (脏矩形合成 & CGImage 渲染)  │
├────────────────────┼───────────────────────────────────┤
│ 数据与集成层       │ TailscaleClient (Tailnet 节点发现)       │
│                    │ DeviceStore & KeychainStore (本地持久化) │
└────────────────────┴───────────────────────────────────┘
```

---

## 🚀 快速上手 (Getting Started)

### 1. 准备你的 Mac 端
1. 打开 Mac **系统设置 (System Settings)** > **通用 (General)** > **共享 (Sharing)**。
2. 开启 **屏幕共享 (Screen Sharing)**。
3. 点击右侧的 **ℹ️ 详情** 按钮 > 点击 **电脑设置... (Computer Settings)**。
4. 勾选 **“VNC 显示程序可以使用密码控制屏幕”**，并设置一个密码。
5. 确保 Mac 已加入你的 Tailscale Tailnet，记录 Mac 的 Tailscale IP（例如 `100.80.1.25`）。

### 2. 编译与运行测试
TailScreens 采用标准 Swift Package Manager 组织，无需安装任何额外三方包：

```bash
# 克隆代码
git clone https://github.com/chenpingan529/TailScreens.git
cd TailScreens

# 编译所有模块
swift build

# 运行自动化单元测试套件 (27/27 单元测试覆盖)
swift test
```

### 3. 打开项目
直接双击根目录的 `Package.swift` 即可在 Xcode 中打开工程，选择你的 iPhone 或 iOS 模拟器直接编译运行。

---

## 🧪 单元测试覆盖 (Unit Tests)

TailScreens 包含完备的单元测试，确保核心协议与数学计算 100% 严谨：

| 测试模块 | 覆盖内容 | 结果 |
| :--- | :--- | :---: |
| `RFBPacketTests` | 协议版本解析、SecurityTypes、ServerInit、Pointer/Key/CutText 封包 | ✅ Passed |
| `VNCAuthCryptoTests` | 密码 Bit Reversal 逆序变换、标准 DES ECB 块加解密向量、挑战应答 | ✅ Passed |
| `TrackpadEngineTests` | 触控板加速度曲线、视口边缘裁剪、双指滚轮事件、手势点击 | ✅ Passed |
| `MacKeyMapTests` | ASCII 码到 KeySym 映射、Mac 快捷键动作键序闭环校验 | ✅ Passed |
| `TailscaleModelsTests`| Tailscale API JSON 响应解析、IPv4 提取、Mac OS 识别 | ✅ Passed |
| `DeviceStoreTests` | 本地存储增删改查、Keychain 密码读写、Tailscale 节点智能合并 | ✅ Passed |

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。
