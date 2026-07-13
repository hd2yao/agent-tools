# codexU 同构界面重构设计

## 目标

将 Codex Profile Switcher 的主窗口和菜单弹窗重构为 codexU v1.0.2 的原生工作型界面。保留账号快速切换、刷新、打开/重启 Codex 和退出；额度、用量、趋势、排行与工具统计沿用本项目数据，不改变 profile/auth/symlink 和 token 归因算法。

## 参考基线

- 参考版本：`shanggqm/codexU@v1.0.2`。
- 主窗口参考：`docs/screenshot-v0.3.0-usage.png`、`docs/screenshot-v1.0.2-status-bar-customization.png`。
- 菜单弹窗参考：`docs/screenshot-v1.0.0-beta-menu-popover.png`。
- 源码参考：`UsageWidgetView`、`RuntimeStatusMenuView`、`RuntimeSummaryCard`、`MainAppWindow`。
- 许可证：MIT。复用其公开布局思想和平台组件语言，不复用品牌图标或产品名称。

## 设计契约

任务模型：
- 用户场景：从菜单栏快速判断当前账号是否可继续工作，必要时切换账号；主窗口用于查看完整额度和本机统计。
- 主要任务：判断 5h/7d 剩余额度和重置时间，并切换账号。
- 主操作：账号切换。
- 次操作：刷新、打开主窗口、重启/接管 Codex、退出、切换统计 tab。
- 非目标：修改账号底层逻辑、token 归因算法、auth 数据结构或新增外部依赖。

信息模型：
- 必须显示：当前账号、plan、5h/7d 剩余与重置时间、今日/7日/累计 token、重置卡数量和最近到期时间、托管状态、账号切换、刷新时间。
- 可选显示：峰值日、连续使用天数、最长运行时长、项目/工具/Skill 排行。
- 不显示：auth、access token、完整 reset credit id、prompt、回复正文、tool arguments、raw logs。
- 缺失值显示 `--` 或“记录不足”，不伪造成 `0`；真实 0 保留为 `0`。
- 长账号名单行尾部截断并保留 tooltip；大数字使用紧凑格式和等宽数字。

布局模型：

```text
[固定窗口 surface，默认 820x720，范围 760x620 ~ 1180x920]
[Header：产品名 | 当前账号/账号切换 | 刷新]
[仅纵向滚动区]
  [Overview section]
    [5h/7d 双环 + 两行重置]
    [今日] [近7天] [累计]
    [重置卡/到期进度]
  [Tabs section]
    [用量趋势] [账号额度] [项目排行] [工具/Skill]
    [当前 tab 内容]
[固定 Footer：数据口径 | 刷新时间]
```

- `documentView.width == clipView.width`，禁止横向滚动和横向弹性。
- 内容宽度为 `min(1080, clipWidth - 32)`，居中；窗口缩小时不低于 728。
- 背景覆盖整个 viewport，滚动内容使用连续 section surface；顶部和底部滚动边界不得露出透明空洞。
- 默认窗口严格使用 codexU 的 820 宽节奏；宽窗口只增加卡片宽度，不增加无意义列。

风格模型：
- 原生 Liquid Glass；玻璃只用于窗口和 section 层。
- 移除所有背景字符、彩色渐变底和装饰纹理。
- 卡片使用稳定的系统 surface、0.8pt 描边、8-12px 圆角；不允许后台文字穿透卡片。
- 蓝色用于 5h，紫色用于 7d，绿色只用于健康/成功，橙色用于重置卡提示。
- 系统字体、SF Symbols、等宽数字；按钮使用图标或图标+短命令。

## reference -> current 映射

| codexU 区域 | 本项目映射 | 保留差异 |
| --- | --- | --- |
| Runtime titlebar selector | 账号切换 segmented strip | 切换的是 profile，不是 runtime |
| DualQuotaRing + QuotaResetSummary | 5h/7d 双环与重置时间 | 数据按当前账号读取 |
| Today / 7d / Lifetime cards | 账号 today / 7d / lifetime | 缺失官方 today 时标“估算” |
| WoolProgressCard | 重置卡数量与最近到期 | 不提供消费操作 |
| Tasks / Usage / Projects / Skill tabs | Usage / Account / Projects / Tools+Skill | 不新增任务看板 |
| RuntimeStatusMenuView | 当前账号 Runtime 卡 | 增加账号切换条和重启按钮 |

## 数据来源

- 官方本地额度：ChatGPT.app 内置 Codex `app-server` 的 `account/rateLimits/read`。
- 重置卡详情：同一响应的 `rateLimitResetCredits.credits`，使用 `expiresAt/grantedAt/status/title/description`；不再直接读取 auth 后调用私有 HTTP endpoint。
- 账号 token 汇总：`account/usage/read` 的 `summary` 和 `dailyUsageBuckets`。
- 本机统计：现有 session/state_5.sqlite 聚合逻辑。
- 账号切换：现有 `codex_profile.py app <profile>`，不改行为。

## 验收门禁

- 干净桌面分别截取菜单弹窗和主窗口。
- 主窗口验证 760x620、820x720、1180x920；每档无横向滚动、越界、重叠或裁切。
- 每档滚到顶部和底部，背景、section 外框和 footer 连续。
- 注入 64 字符账号名、万亿级 token、0、缺失值。
- 与 codexU 参考按同尺度并排；严格复刻 Visual Verdict >= 95 才通过。
- 每轮最多修复 3 个最高影响问题；连续两轮提升不足 5 分时返回布局模型。
