# Doushujun iOS（抖数君会员）

微信小程序「doushujun_wx对接第三方支付」的 iOS 端会员充值 App。

## 功能

- **用户ID登录**：与小程序共用用户体系（输入小程序「我的」页复制的用户ID）
- **会员中心**：VIP 状态卡（套餐类型 / 剩余天数 / 有效期）+ 会员权益展示
- **购买会员**：套餐列表（低请求版 / 高请求版）+ 支付方式（微信 / 支付宝）
- **第三方支付**：创建订单后内置 WebView 打开支付页，支持复制链接 / Safari 打开，支付完成后自动轮询订单状态，VIP 立即生效
- **我的**：复制用户ID / 刷新会员信息 / 开通步骤 / 退出登录

## 对接接口（与小程序同源）

| 接口 | 方法 | 说明 |
|---|---|---|
| `/api/mini_program/vip/packages` | GET | 套餐列表 |
| `/api/mini_program/vip/create-order` | POST | 创建订单，返回 `pay_info.pay_url` |
| `/api/mini_program/vip/return-url?out_trade_no=` | GET | 轮询支付结果（paid/unpaid） |
| `/api/mini_program/vip/status` | POST | 用户 VIP 状态（登录校验 + 会员中心） |

后端 baseURL：`https://duochacha.top`（见 `Doushujun/Core/API.swift`）。

## 工程结构

- `generate_project.py` —— **工程唯一真源**：扫描 `Doushujun/` 下源码手写生成 `Doushujun.xcodeproj/project.pbxproj`（与 admin-dashboard-ios 同方法论）。加文件/改构建设置必须改这里。
- `.github/workflows/ios-build.yml` —— GitHub Actions：macOS 上 `python3 generate_project.py` → `xcodebuild`（免签名）→ 打包 `Doushujun-unsigned.ipa` artifact。
- `Doushujun/` —— SwiftUI 源码（iOS 16+，纯 SwiftUI + async/await，JSON 用 JSONSerialization 容错解析）。

## CI 构建

push 到 main/master 或手动 `workflow_dispatch` 触发；产物 artifact 名 `Doushujun-unsigned`（外壳 zip 内含 IPA），下载后用爱思助手签名安装。
