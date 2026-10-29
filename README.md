# 拉杆军团 · UrhoX 工程

只保留游戏本体需要的文件，体积约 11 MB。

- 版本：`1.0.67`
- 入口：`scripts/imported_main.lua`

## 内容

```
scripts/   游戏代码
assets/    Textures（章节背景）/ audio（58 个 ogg 音效与 BGM）/ Fonts（Silkscreen）
.project/  工程配置
```

## 使用

用 TapTap 星火编辑器（SCE）打开本目录，构建入口选 `imported_main.lua`。

已验证：`-validate` 跑 240 帧，`lua_errors 0`、`resource_errors 0`、无缺失资源。

## 本版要点

- 第十五次更新：圣物栏 5→8 格，仓库 6→10 格并可存放圣物；圣物栏满时的战利品 / 商店取舍流程；装备管理新增圣物栏拖放
- 古树卫士五条转职与血根古神重绘，新增 limb / rootclaw 骨架与根须特效
- 界面卡顿优化：morphHTML 差异更新，绘制与排版去掉每帧新建的闭包
- 横屏 iPhone 适配：道具栏 8 圣物 + 3 消耗品排成一行、战场宽度恢复；灵动岛按实际遮挡分段让位；战斗统计在窄栏下不再截断
- 修复：顶栏秘银数量不刷新；看广告偶发要点多次（确认框防重复点击、播放中不叠加弹窗、超时 120s→30s）

## 注意

- `.project/project.json` 里的发布凭据（developer_id / app_id / miniapp_id）已剥离，发布时自行填写。
- `scripts/Legion/` 代码仍在，但依赖的 FusionPixel 字体已删。要启用那套实验 UI 需从上游取回字体。
- 中文由引擎内置字体兜底，工程内只带 Silkscreen 像素字体。

## 架构要点

**共享命名空间**：`game/` 模块通过 `local _ENV = require("game.env")` 互相引用函数名，LSP 报的 `undefined-global` 是预期行为，不是错误。

**增量覆盖**：历次更新用 `local _hit = hit` 包一层再覆盖。`app.lua` 末尾的 `require` 顺序决定覆盖层级，改动顺序会改变行为。

**UI 是自研引擎**：`ui/` 实现了 DOM、CSS、Flexbox/Grid、NanoVG 绘制。改界面优先改 `ui/content.lua` 的 CSS。
