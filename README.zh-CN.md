<div align="center">

# ZRemote

**zemote,去掉协议复刻。**

开源、协议免疫的 **ZCode 远程控制启动器** ——
把桌面设备收进一个列表,点一下,直达官方 Web 远程控制。
没有 relay 握手,没有配对证明,没有需要追着改的 IPC。

[English](README.md) · [为什么做 ZRemote?](#-为什么做-zremote) · [功能](#-功能) · [对比](#️-zremote-vs-zemote) · [快速开始](#-快速开始) · [架构](#-架构) · [路线图](#️-路线图)

[![Release](https://img.shields.io/github/v/release/opensymph/ZRemote?style=flat-square&logo=github&color=blue)](https://github.com/opensymph/ZRemote/releases)
[![Build](https://img.shields.io/github/actions/workflow/status/opensymph/ZRemote/ci.yml?style=flat-square&label=build)](https://github.com/opensymph/ZRemote/actions/workflows/ci.yml)
[![Stars](https://img.shields.io/github/stars/opensymph/ZRemote?style=flat-square&color=yellow)](https://github.com/opensymph/ZRemote/stargazers)
[![Forks](https://img.shields.io/github/forks/opensymph/ZRemote?style=flat-square&color=orange)](https://github.com/opensymph/ZRemote/forks)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=flat-square)](#-快速开始)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44%2B-blue?style=flat-square&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12%2B-0175C2?style=flat-square&logo=dart)](https://dart.dev)

</div>

---

## 💡 为什么做 ZRemote?

[zemote](https://github.com/HumanAILoop/zemote) 证明了第三方 ZCode 远程客户端是可行的 —— 代价是复刻整套私有协议:relay 握手、HMAC-SHA256 配对证明、rpc-frame 分片、IPC 编解码、V4 快照/增量。

它是一份令人敬佩的逆向工程,也是一台跑步机:智谱每动一次协议,协议客户端就碎一次,直到有人重新移植。

**ZRemote 押了相反的方向:一行协议都不实现。** 它是一个启动器 —— 干净的设备列表 + 打开官方 Web 远程页的内嵌浏览器。协议归智谱,升级归智谱,ZRemote 只负责指过去。

- 🧬 **协议升级免疫** —— 智谱明天上线 remote v5?扫一次新码,App 一行不用改。
- 🪶 **约 1000 行 Dart** —— 九个文件,三个是 UI,没有会腐烂的东西。
- 📋 **把列表做对** —— 扫码 / 粘贴 / 相册识码添加,重命名 / 删除 / 复制 / 备份导入导出。
- 🌐 **官方体验,永远最新** —— 真正的 Web 远程页跑在全屏 WebView 里,配对状态跨会话保留。
- 🎨 **像素级官方主题** —— 设计 token 直接从官方 bundle 提取(中性灰 + 天空蓝,深色 `#161616`),看上去就是一家人。
- 🔐 **凭据只留在手机上** —— 设备 URL 只存本地,没有服务器、没有埋点、没有账号。

> *zemote 是给重度用户的客户端,ZRemote 是永远不会坏的那个。*

觉得靠谱?给个 **Star ⭐** 持续关注。

---

## ✨ 功能

| | |
|---|---|
| 📋 **设备列表** | 卡片展示设备名 / 主机 / 上次使用时间;重命名、删除、复制链接、浏览器打开;设备备份 JSON 导出 / 导入 |
| ➕ **扫码 / 粘贴 / 截图添加** | 相机扫码(`mobile_scanner`)、纯 Dart 相册识码(`zxing2`)、粘贴链接;自动去重;无法解析的链接照样保存,绝不丢 |
| 🌐 **应用内远程页** | 全屏 `flutter_inappwebview`,加载进度条、刷新、"在浏览器中打开"逃生口;DOM Storage 保留官方页配对状态 |
| 🎨 **官方设计 token** | 从官方 bundle 提取的中性灰阶 + 天空蓝;深色 `#161616` 默认,浅色、跟随系统 |
| 🌗 **主题切换** | 深色 / 浅色 / 跟随系统,持久化;默认深色,和官方页一致 |
| 📱 **Android + iOS** | 一套代码双平台,相机 / 相册权限已配好 |

---

## ⚔️ ZRemote vs zemote

诚实对比,按需选用。zemote 同样值得一颗 Star。

| | **ZRemote** | **[zemote](https://github.com/HumanAILoop/zemote)** |
|---|---|---|
| 思路 | URL 启动器 + 官方 Web 远程 | 完整协议复刻 |
| 智谱改协议后 | ✅ 重扫一次码,App 不动 | ⚠️ 需要更新协议层 |
| 远程界面 | 官方 Web 页(永远最新) | 原生重实现 |
| 原生对话 / 流式 UI | ❌ 走 Web 页 | ✅ 原生 |
| 后台 / 推送通知 | ❌ | ✅ Android |
| 多设备管理 | ✅ 列表 + JSON 备份 | ✅ 列表 + 实时连接状态 |
| 需要维护的代码 | 约 1k 行,无协议 | relay + rpc-frame + IPC + V4 全套 |
| 离线配对状态 | WebView 存储保留 | 原生配对 |
| Android | ✅ | ✅ |
| iOS | ✅ 需在 Mac 上打包 | ⚠️ 未验证 |

---

## 📸 截图

随首个正式 Release 补上。想帮忙拍?见[贡献指南](#-贡献)。

---

## 🚀 快速开始

你需要一台运行 **ZCode**(zcode.z.ai)的桌面设备。在那里生成远程链接:ZCode → 远程控制 → 二维码 / 复制链接,形如:

```text
https://zcode.z.ai/remote/v4?sid=...&hash=...&t=...&mid=...&name=...
```

### 方式 A · 下载预编译 APK

从 [Releases](https://github.com/opensymph/ZRemote/releases) 下载最新 APK,装到手机上,扫桌面二维码添加第一台设备。

> ⚠️ 请只安装你信任来源的 APK —— 远程链接等同于设备凭据。审查代码,或选择方式 B 自行构建。

### 方式 B · 源码构建

前置条件:[Flutter](https://docs.flutter.dev/get-started/install) 3.44+(Dart 3.12+)。构建 Android 需要 JDK 17 + Android SDK;构建 iOS 需要 Mac + Xcode。

```bash
git clone https://github.com/opensymph/ZRemote.git
cd ZRemote
flutter pub get

flutter run                       # 连接真机调试
flutter build apk                 # → build/app/outputs/flutter-apk/app-release.apk
flutter build ipa                 # 在 Mac 上,配置好签名后
```

应用内:**添加设备** → 扫码或粘贴 → 点击卡片 → 进入远程控制。

---

## 🧱 架构

```
┌─────────────────────────────────────────────────┐
│ UI (lib/ui)                                     │
│   devices_page · remote_page · qr_scan_page     │
├─────────────────────────────────────────────────┤
│ State (lib/state)                               │
│   device_store — SharedPreferences JSON         │
├─────────────────────────────────────────────────┤
│ Core (lib/core)                                 │
│   connection_params — 仅从 URL 提取设备名标签    │
└───────────────┬─────────────────────────────────┘
                │ 打开 URL
┌───────────────▼─────────────────────────────────┐
│ ZCode 官方 Web 远程(WebView 内)                 │
│   relay · 配对 · IPC · V4                        │
│   —— 归智谱所有、随官方更新,与我们无关           │
└─────────────────────────────────────────────────┘
```

```text
lib/
├── main.dart                  # 入口:主题 + 主页
├── core/
│   ├── connection_params.dart # 远程 URL 解析(仅取标签,不碰协议)
│   └── id.dart                # UUID
├── state/
│   └── device_store.dart      # 设备模型 + 持久化 + 导入导出
└── ui/
    ├── theme.dart             # 官方设计 token + 深浅主题
    ├── devices_page.dart      # 设备列表
    ├── qr_scan_page.dart      # 相机 + 相册扫码
    └── remote_page.dart       # 全屏 WebView 远程页
```

---

## 🗺️ 路线图

- [ ] README 截图 + 演示 GIF
- [ ] 剪贴板检测 —— 复制远程链接后自动提示添加
- [ ] 拖拽排序 + 置顶设备
- [ ] 每设备 `theme=dark|light` URL 参数
- [ ] 桌面快捷打开小组件(Android)
- [ ] Release 工作流产出 iOS 产物
- [ ] 英文本地化

---

## 🤝 贡献

欢迎 Issue 和 PR。提交前请确保:

```bash
flutter analyze   # 零告警
flutter test      # 全部通过
```

小而聚焦的 PR 最快被合并。UI 改动请保持[官方设计 token](lib/ui/theme.dart) —— 这是本项目的立身之本。

---

## 🙏 致谢

- **[zemote](https://github.com/HumanAILoop/zemote)** —— 本项目参考的先行者;URL 解析器、扫码流程、存储模式改编自它。MIT。
- **ZCode 与官方 Web 远程** —— 真正的远程体验与全部协议能力都在那里。
- Flutter 生态:`flutter_inappwebview`、`mobile_scanner`、`zxing2`、`shared_preferences`、`url_launcher`。

> ⚠️ ZRemote 是独立的社区工具,与智谱 AI 无任何隶属、背书或关联。请仅用于你自己的设备,并遵守 ZCode 服务条款。

---

## 许可证

MIT © ZRemote contributors —— 详见 [LICENSE](LICENSE)。
