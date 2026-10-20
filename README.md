# 抖数君会员 iOS 端（doushujun-ios）

AI 作品分析建议优化平台的原生 iOS 客户端，从安卓端 `doushujun-app-android` 全量移植，功能与接口协议完全对齐（与 web 端共用同一套后端 `https://doushujun.me/api`）。

- **语言/UI**：Swift 5.9 + SwiftUI（无 Storyboard，纯代码构建）
- **最低版本**：iOS 16.0（仅 iPhone，`UIDeviceFamily=[1]`）
- **Bundle ID**：`com.doushujun.member`，显示名「抖数君会员」
- **构建方式**：GitHub Actions 云端编译（本项目目录即工程真源，由 `generate_project.py` 生成 `project.pbxproj`），产物为未签名 ipa，用爱思助手等工具自签安装

---

## 一、五大功能模块（对应底部五 Tab）

### 1. 权重查询（WeightView.swift）
- 输入抖音作品链接（支持口令/短链，粘贴自动提取），选择指标组合后发起查询
- 接口：`v2/query/weight`（带 X-Signature 签名），Task 轮询 5s×60 次取结果
- 结果页：作品基础信息卡片 + 雷达图（5 维互动数据率，Charts.swift 自绘）+ 指标明细徽章
- 支持查询历史（WeightHistoryView，可回看/删除/再次分析）

### 2. 作品解析（WorkView.swift）
- 解析抖音作品：无水印视频/图片、封面、AI 推荐标题、作者信息、流量池等级
- 接口：`v2/query/douyin`，结果可保存到相册（需 `NSPhotoLibraryAddUsageDescription` 权限）
- 作品历史（WorkHistoryView）与监控直通车：从解析结果一键发起监控/权重分析

### 3. 数据监控（MonitorView.swift + MonitorChartView.swift）
- 对已解析作品持续监控播放/点赞/评论/分享增量，多作品并行
- 监控详情：折线图（MonitorChartView，多指标多色 Series）+ 汇总统计行
- 接口：`v2/query/refresh`（刷新）、`v2/query/history`、`query/delete`

### 4. 取素材（MaterialView.swift）
- 素材提取：视频转图、去水印等（`remove_watermark` 走旧版 MD5 签名协议）
- 等级徽章图集（dengji_1~6.png）与评级图标（rating_a~d.png）本地资源展示

### 5. 我的（MineView.swift）
- 账户信息：余额、会员状态、邀请码
- 子页面：充值 VIP（VipView）、邀请返利（InviteView）、意见反馈（FeedbackView）、更新检查（AppUpdater）

---

## 二、认证体系（AuthView.swift）

三面板单页切换：登录 / 注册 / 找回密码。

- **图形验证码**：`captcha/generate` 返回 base64 PNG dataURI，配套 `captcha_key` 提交
- **极验 4.0 滑块**：`captcha/geetest/config` 取 captcha_id → WKWebView 加载本地 `geetest.html`（注入 ID、JS 桥 `dsj` 回调）→ 前端验证通过拿四元组 → `captcha/geetest/verify` 服务端二次校验换 `slider_token`
  - 兼容降级：生产后端暂未部署极验（config 404）时自动跳过安全验证直接登录，后端上线后无需改码
- **登录态**：Bearer token + SHA-256 签名（`Crypto.webSignature`），token 过期（code 401）全局踢回登录页

---

## 三、核心层（Core/）

| 文件 | 职责 |
|---|---|
| `Network.swift` | 统一请求层：URL 拼接、签名头注入、Bearer 会话、错误分类（business/notFound/maintenance/sessionExpired）、成功码 code==200\|\|1 |
| `Crypto.swift` | SHA-256（web 签名：signParams 按键排序拼接+时间戳+密钥）、MD5（旧版素材签名） |
| `SessionStore.swift` | UserDefaults 持久化：token/用户名/邮箱/余额/查询历史等 |
| `AppState.swift` | 全局并发任务总线：TaskGroup 轮询 AI/支付任务，结果回主线程 |
| `SessionBus.swift`（并入 App） | 登录态切换、跨 Tab 直通车（pendingWorkId/pendingWeightId/pendingTaskLink）、全局 Toast/Loading |
| `Theme.swift` | 深色主题体系：色板（primary/secondary/warn/textMain…）、玻璃卡片、渐变 |
| `Components.swift` | 共享组件：NetImage（NSCache 异步图）、AnnouncementBar 公告栏、GradientBanner、.snackbar 修饰器 |
| `Charts.swift` | 纯 SwiftUI 自绘图表：雷达图（RadarChartView）、折线图（LineChartView），Canvas 绘制 |
| `LinkParser.swift` | 抖音链接/口令提取：正则匹配 v.douyin.com 短链与长链 |
| `AppUpdater.swift` | 版本检查：`app/version` 对比 build 号，弹更新窗（含 APK 下载地址兼容逻辑） |

---

## 四、工程结构与构建

```
doushujun-ios/
├── Doushujun/
│   ├── DoushujunApp.swift      # App 入口：路由 + 会话 + 直通车
│   ├── Core/                   # 网络层/加密/存储/主题/组件/图表（9 文件）
│   ├── Views/                  # 五 Tab + 认证 + 子页面（12 文件）
│   ├── Info.plist
│   └── Assets.xcassets         # AppIcon
├── Resources/                  # 打包进 bundle 的资源（geetest.html、徽章/评级 PNG）
├── generate_project.py         # 工程真源：手写生成 project.pbxproj
├── _push_github.py             # Git Data API 全量推送（tree+commit+push）
├── _poll.py                    # CI 轮询（失败自动拉 build-log 提错误行）
├── _dl_art.py / _verify_ipa.py # artifact 下载 / ipa 静态验证
└── README.md
```

**云端构建流程**：`_push_github.py` 推送 → GitHub Actions（Xcode 15，`xcodebuild archive` + `xcodebuild -exportArchive`）→ 产出 `Doushujun-unsigned.ipa` artifact → `_dl_art.py` 下载 → 爱思助手自签安装。

---

## 五、已知事项

- 极验滑块在生产后端部署前自动跳过（见认证体系说明）
- 微信登录未开放（按钮点击仅提示）
- 未签名 ipa 需自签（个人证书 7 天有效期），签名安装见爱思助手操作
