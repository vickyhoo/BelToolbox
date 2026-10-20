# Bel Toolbox for EllesmereUI

贝尔工具箱 · Quality-of-life extensions for **EllesmereUI on WoW Forever**.

Author: **Bel** · License: **MIT** · Current version: **0.17.0 beta**

## Features

- **Mage Bar:** teleport/portal flyouts, mana gems, conjure food and water, rank-specific casting and remembered spell selection. Supports EUI Unlock Mode.
- **Merchant assistant:** Shift-click bulk purchases, a four-column merchant layout and learned-recipe markers.
- **Bags and mail:** offline inventory/bank snapshots, character-colored item counts, mail recipient shortcuts, favorites and recent contacts.
- **Bag shortcuts:** optional automatic weapon buff targeting and Mage comprehension-scroll shortcuts outside combat.
- **Tooltips:** item/spell title icons, AFK/DND status beside player names, class/reaction/quality borders and configurable text colors.
- **Profession helper:** estimated recipe-list profit and return percentage using installed Auctionator, TradeSkillMaster or CraftProfit price APIs; preserves skill-up arrows and supports difficulty-colored recipe names.
- **Chat:** configurable channel shortcuts, original micro-menu artwork, and an EUI chat-copy window with dragging, resizing, name/text search, channel colors and class-colored player names.
- **Interface utilities:** quick focus with optional control marker, map resize handle, EUI window-movement integration, animated resting indicator, native quest-object sparkles and compact raid-tool extensions.

## Installation

1. Install EllesmereUI for your WoW Forever client.
2. Download a release ZIP and extract its `BelToolbox` folder into `Interface/AddOns/`.
3. If using GitHub's **Code → Download ZIP**, rename the extracted `BelToolbox-main` folder to `BelToolbox`.
4. Confirm that `Interface/AddOns/BelToolbox/BelToolbox.toc` exists, then restart the game or run `/reload`.

Settings are in **EUI → Bel Toolbox**, or enter `/bel` / `/beltoolbox`.

### 中文安装说明

将插件文件夹命名为 `BelToolbox`，放入无限服客户端的 `Interface/AddOns/`，确认目录内直接包含 `BelToolbox.toc`。设置入口为 **EUI → 贝尔工具箱**，也可输入 `/bel`。

聊天复制窗口可拖动顶部移动、拖动右下角调整大小，并记忆位置和尺寸。搜索框可按角色名或正文筛选，清空后恢复全部消息。角色名称使用已知发言者、队伍和公会的职业信息染色，未知职业保留原色，正文保留频道颜色；染色选项位于 **界面增强 → 聊天复制窗口**。

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

- `/belbagdebug`: bag shortcut eligibility.
- `/belmaildebug`: mail recipient API diagnostics.
- `/belprofitdebug on`, `/belprofitdebug`, `/belprofitdebug off`: opt-in, bounded profession tooltip diagnostics. Disabled by default, no polling or saved trace.

Lua syntax and simulated regression checks cover the supported integrations. Beta client behavior, prices, UI layout and EUI compatibility still need in-game verification; mock checks are not a live performance benchmark.

When reporting a problem, include the addon/EUI/client versions, steps to reproduce and any relevant Lua error or opt-in diagnostic output. Remove unrelated chat or character details before posting.

## License and artwork

Code is licensed under [MIT](LICENSE), copyright © 2026 Bel. The bundled micro-menu artwork is original Bel Toolbox artwork; the project logo was generated for this project. RS/NDui artwork, third-party addon code and user SavedVariables are not bundled. Blizzard assets referenced by in-game paths remain part of the game client.

See [CHANGELOG.md](CHANGELOG.md) for the current release notes.
