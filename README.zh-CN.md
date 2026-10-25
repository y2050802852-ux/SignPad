<div align="center">

<img src="docs/assets/icon.png" width="120" height="120" alt="SignPad 图标"/>

# ✍️ SignPad

**把 MacBook 触控板变成签名板。原生 · 隐私 · 零依赖**

在触控板上签名 → 调整笔迹 → 导出 PDF/SVG/PNG → 留下可回放的历史

[![Download](https://img.shields.io/badge/⬇_下载-v1.0.0_DMG-blue?style=for-the-badge&logo=apple)](https://github.com/y2050802852-ux/SignPad/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS_15+-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-SwiftUI_+_SwiftData-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-green)
![Deps](https://img.shields.io/badge/dependencies-zero-brightgreen)

*纯原生 · 无 API Key · 无第三方依赖 · 数据全在本地*

[English](README.md) | [简体中文](README.zh-CN.md)

</div>

---

## 📸 截图

<div align="center">
<img src="docs/assets/screenshot-main.png" width="900" alt="SignPad 主窗口"/>
<p><sub>全窗口磨砂透底、白色画布、双行工具栏、历史栏一键清空——窗口后是什么颜色，玻璃就透出什么颜色。</sub></p>
<img src="docs/assets/screenshot-signing.png" width="900" alt="画布上的签名"/>
<p><sub>完成后的签名——速度感应笔锋，可直接导出或重新编辑。</sub></p>
</div>

---

## ✨ 功能

### 🖌️ 四种笔刷 · 速度感应笔锋
- **钢笔·笔锋 / 圆珠笔 / 马克笔 / 铅笔·纹理**——macOS 触控板没有公开压力 API，SignPad 以**笔速合成力度**（gamma 0.7 缓动），且每笔记录落笔时的粗细倍率
- **全局粗细滑杆 0.5×–3×**——在几何构建时生效、随笔画记录，之后拖动滑杆，回放与导出永不漂移
- 六色预设色板 + 始终镜像当前颜色的取色器

### 🖐️ 全窗口捕获书写态
- 点「开始签名」后指针冻结并消失——**手指在窗口任何位置书写**（工具栏、侧栏、随手指去哪都行）；**回车 / Esc** 结束。白布仅展示，全窗口透明捕获层接收触控板裸触摸
- 呼吸高亮边框标记书写态；cmd-tab 切走自动安全取消（画布保留、不入库）
- **Esc / 回车 / 按钮**统一走一条提交路径；空会话绝不产生历史记录

### 📄 矢量三件套导出
- 一键导出 **PDF + SVG + PNG @4×** 到 `~/Desktop/签名/`——矢量给打印，高清位图给聊天窗口
- 成功 toast 带「在 Finder 中显示」；失败弹窗明示原因；同秒重复导出自动唯一化命名
- PNG 用纯 CoreGraphics 位图上下文渲染（无 DPI 隐式映射，回归测试确保「中心必有墨」）

### 🗂️ 可回放历史
- 每次完成签名经 **SwiftData** 存入 `~/Library/Application Support/SignPad/`（缩略图 + 完整笔画 JSON）
- 点击缩略图**载入画布**（保持普通态）→「继续编辑」换笔换色补笔，完成后入库为新记录
- **⌘Z 撤销**在普通态与书写态都可用；侧栏**一键清空**（带确认）

### 🧊 真·磨砂玻璃
- 整窗 chrome 为 `NSVisualEffectView` `.underWindowBackground`——macOS 最强透底，桌面颜色直接透进来
- 应用图标由 SignPad 自己的墨迹管线渲染：Catmull-Rom + 法线偏移丝带的白色飞白，加上边缘泛洪抠底的用户手绘印章——经典的「签名 + 盖章」构图

### 🌐 双语界面
- 界面语言中英双语，⌘, 设置可切换

## 🛠️ 实现方式

| 层 | 选型 | 说明 |
|---|---|---|
| 捕获 | AppKit `NSTouch`（`.direct` + `.indirect`）落在全窗口透明层 | 书写不依赖指针位置；画布 NSView 仅展示 |
| 力度 | **笔速 → 力度合成**（`PenDynamics`，gamma 0.7） | 触控板无压力，笔速是诚实的信号 |
| 墨迹 | Catmull-Rom 平滑 → **法线偏移丝带轮廓** / 居中描边 / 定序颗粒 | 一条几何管线同时服务画布、缩略图与全部导出器 |
| 导出 | PDF（CGContext）、SVG（手写模板，数字/日期格式化区域无关）、PNG（纯 CG 位图 @4×） | 无 DPI 魔法，像素确定性 |
| 存储 | SwiftData（`@Model`）+ 自定义 Codable 兼容旧数据 | 旧笔画缺 `widthScale` 时解码为 1 |
| 界面 | SwiftUI 确定性 `HStack` 布局 + `NSVisualEffectView` | 双行工具栏，侧栏钉在 240pt |

## 📦 下载

从 [**Releases**](https://github.com/y2050802852-ux/SignPad/releases/latest) 下载 `SignPad-1.0.0.dmg`，打开后把 **SignPad.app** 拖入「应用程序」。

> 需要 macOS 15（Sequoia）及以上，Apple Silicon。Ad-hoc 签名（未公证）：若 Gatekeeper 拦截，右键应用 → **打开**。

### 从源码构建

```bash
git clone https://github.com/y2050802852-ux/SignPad.git
cd SignPad
open SignPad.xcodeproj    # Xcode 16+，⌘R 即可
```

随时可用 `swift Scripts/make_icon.swift <输出目录>` 重新生成应用图标。

## 📄 许可证

MIT
