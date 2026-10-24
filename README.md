# Bel Toolbox for EllesmereUI

贝尔工具箱 · Quality-of-life extensions for **EllesmereUI on WoW Forever**.

Author: **Bel** · License: **MIT** · Current version: **0.19.21-dev**

消耗品条：在 EUI → 贝尔工具箱 → 消耗品条开启（默认关闭）。鼠标移入展开，左键使用，展开项右键设为当前选项；支持食物、饮水、红药、蓝药、治疗石、法力宝石、绷带、合剂、药剂、抗性药水。空类别保留灰色按钮以保持位置稳定。未知或增益食物需手动指定，已知普通食物与魔法制造食物可自动选择。战斗中不根据背包变化自动切换物品，脱战后更新。位置使用 EUI 解锁模式；按键使用 EUI 快速键位绑定模式（/kb），并在原窗口保存或取消。

可开启“隐藏空类别”，设置每行按钮个数、按钮间距和类别顺序。达到设定个数后自动换行。按钮大小支持 18–64，间距为 0 时图标直接相接。开启 `/kb` 时空类别临时显示，便于绑定按键。鼠标移入自动展开同类物品，展开方向根据屏幕剩余空间自动选择；左键使用单个物品，右键设为当前选项，点击“自动”清除指定并恢复自动选择。展开项在战斗中也可通过安全按钮使用／指定，新增或耗尽物品在脱战后更新。类别勾选和排序使用 EUI 的可拖拽下拉设置。带增益的杂味炖肉等食物需手动指定。合剂、药剂和抗性药水也需手动指定默认项，避免自动选错职业效果或抗性类型；“自动”会清除这三类的指定。新类别追加在既有顺序之后，默认每行仍为 7 个，可在设置中调整。

## Features

- **Consumables bar:** ten categories with secure hover flyouts, per-character choices, item counts and cooldowns, EUI drag ordering, adaptive expansion, configurable size/spacing/wrapping, and Quick Keybind Mode (/kb). Off by default.

- **Mage Bar:** teleport/portal flyouts, mana gems, conjure food and water, rank-specific casting and remembered spell selection. EUI drag ordering and visibility, automatic or manual expansion direction, 18–64 button sizes, 0–16 spacing and configurable buttons per row. Supports EUI Unlock Mode.
- **Merchant assistant:** Shift-click bulk purchases, a four-column merchant layout and learned-recipe markers. When EUI Bulk Buy is enabled, reuse its window with individual quantities for ordinary gold items; otherwise use the toolbox window.
- **Bags and mail:** offline inventory/bank snapshots, character-colored item counts, mail recipient shortcuts, favorites and recent contacts.
- **Bag shortcuts:** optional automatic weapon buff targeting and Mage comprehension-scroll shortcuts outside combat.
- **Tooltips:** item/spell title icons, AFK/DND status beside player names, class/reaction/quality borders and configurable text colors.
- **Profession helper:** estimated recipe-list profit and return percentage using installed Auctionator, TradeSkillMaster or CraftProfit price APIs; preserves skill-up arrows and supports difficulty-colored recipe names.
- **Chat:** configurable channel shortcuts, original micro-menu artwork, and an EUI chat-copy window with dragging, resizing, name/text search, channel colors and class-colored player names.
- **Ship/zeppelin timers:** countdowns below EUI world-map transport icons and, when installed, OpenMap's native dock icons. Labels follow each map's icon visibility and use the same built-in schedules and recorded-track calibration while standing aboard. Disabled by default.
- **Interface utilities:** quick focus with optional control marker, map resize handle, EUI window-movement integration, animated resting indicator, native quest-object sparkles and compact raid-tool extensions.

## Installation

`main` is reserved for formal releases. Ongoing development, fixes and beta iterations are maintained on `dev`.

分支约定：`dev` 用于功能开发、修复和测试版本；`main` 仅用于正式发布。

正式版本合并到 `main` 后，GitHub Actions 自动发布相同 ZIP 和本次更新日志到 GitHub Release 与 CurseForge。[发布流程与失败重试说明](docs/RELEASING.md)。

1. Install EllesmereUI for your WoW Forever client.
2. Download a release ZIP and extract its `BelToolbox` folder into `Interface/AddOns/`.
3. If using GitHub's **Code → Download ZIP**, rename the extracted `BelToolbox-main` folder to `BelToolbox`.
4. Confirm that `Interface/AddOns/BelToolbox/BelToolbox.toc` exists, then restart the game or run `/reload`.

Settings are in **EUI → Bel Toolbox**, or enter `/bel` / `/beltoolbox`.

### 中文安装说明

将插件文件夹命名为 `BelToolbox`，放入无限服客户端的 `Interface/AddOns/`，确认目录内直接包含 `BelToolbox.toc`。设置入口为 **EUI → 贝尔工具箱**，也可输入 `/bel`。

聊天复制窗口增强提供总开关，关闭后恢复 EUI 原始窗口和内容；此前三个选项均关闭的设置会自动保持关闭。移动与拉伸、搜索可分别控制。启用移动与拉伸后，可拖动顶部移动、拖动右下角调整大小，并记忆位置和尺寸。搜索框可按角色名或正文筛选，清空后恢复全部消息。角色名称优先保留 EUI 原有颜色，再通过其他消息中的同一角色颜色和已知职业信息补齐，未知职业保留原色，正文保留频道颜色；染色选项位于 **界面增强 → 聊天复制窗口**。

船与飞艇倒计时默认关闭，位于 **界面增强 → 船与飞艇倒计时**。启用后会自动开启 EUI 的地图标记和交通图标，保留其他地图分类的原有设置。图标下白色表示等待抵达，金色表示等待出发；一个图标关联多条航线时显示最近一班，鼠标提示列出各航线及校准时间。无数据时显示 `?`。航行时站定一段时间可自动校准，校准记录按服务器保存。内置时刻表在服务器重启后可能偏移，乘船校准后更新。当前版本仅处理已有船／飞艇航线，不含电车、航线绘制、动态船只或玩家同步。

商人助手开启时，若同时开启 EUI 的批量购买，将复用 EUI 窗口，普通金币商品可按实际件数输入（如面包输入 1 即请求购买 1 个），总价按每包价格折算。货币兑换、唯一物品保留 EUI 的购买流程；高价金币购买保留确认。未开启 EUI 批量购买时仍使用工具箱窗口。

## Dependencies and compatibility

- Designed for **WoW Forever / Interface 16001** and the local EllesmereUI Forever APIs used by this version.
- EllesmereUI is a required TOC dependency and loads before Bel Toolbox. Missing or disabled EUI prevents Bel Toolbox from loading. Install the relevant optional EUI modules for their corresponding integrations.
- In the game addon manager, Bel Toolbox is grouped under EllesmereUI.
- Profession profit needs a supported price-provider addon with usable price data. CraftProfit is optional. No auction scanner is bundled.
- If CraftProfit's own recipe-row tags are enabled, they take priority to avoid duplicate tags.
- Some EUI extensions use guarded internal interfaces and may need updates after EUI changes.

## Notes

- Auto Weapon Buff is **off by default**. Modifier keys preserve normal bag behavior. Disable competing BuyEmAll/weapon-buff/scroll shortcuts when using their replacements.
- Visit a character's bank to update its bank snapshot. Log in on each character to record its bags. Inventory data is a snapshot, with no automatic cross-account synchronization.
- Mail shortcuts fill the recipient only; they do not send mail automatically.
- Profit is an estimate after the configured AH cut (default 5%). Basic-material costs are included; optional reagents, auction deposits and self-crafted intermediate chains are excluded. Missing prices show a dash.
- Chinese and English strings are maintained in `Locales.lua`; other clients fall back to English.

## Diagnostics and verification

- /belmagedebug: read-only Mage Bar visibility, icon, geometry and cached/live spell-count and anchor diagnostics. Run while a button appears missing; no settings or frames are changed.

- `/belchatdebug on`, `/belchatdebug`, `/belchatdebug off`: opt-in chat-copy color diagnostics. Open the copy window with enhancements on and off, then dump the last four snapshots. Reports color tokens and player-link labels without message bodies; nothing is saved or polled.
- `/belmerchantdebug`: one-shot native/override amount text, font, geometry and visibility diagnostics while Bulk Buy is open. Read-only; no purchases or rendering changes.
- `/belbagdebug`: bag shortcut eligibility.
- `/belmaildebug`: mail recipient API diagnostics.
- `/belprofitdebug on`, `/belprofitdebug`, `/belprofitdebug off`: opt-in, bounded profession tooltip diagnostics. Disabled by default, no polling or saved trace.

Lua syntax and simulated regression checks cover the supported integrations. Beta client behavior, prices, UI layout and EUI compatibility still need in-game verification; mock checks are not a live performance benchmark.

When reporting a problem, include the addon/EUI/client versions, steps to reproduce and any relevant Lua error or opt-in diagnostic output. Remove unrelated chat or character details before posting.

## License and artwork

Code is licensed under [MIT](LICENSE), copyright © 2026 Bel. The bundled micro-menu artwork is original Bel Toolbox artwork; the project logo was generated for this project. DockWatch ship/zeppelin route data is bundled under its MIT license; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). RS/NDui artwork, DockWatch UI/media/network modules and user SavedVariables are not bundled. Blizzard assets referenced by in-game paths remain part of the game client.

See [CHANGELOG.md](CHANGELOG.md) for the current release notes.
