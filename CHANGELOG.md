# Bel Toolbox 0.19.22

- Added countdowns below OpenMap's native boat, zeppelin and airship dock icons, including the routes to Zephras Isle. Labels follow icon visibility and reuse existing schedules and calibration.
- Added separate EUI/OpenMap display switches in a native settings cog beside the transport timer master switch. OpenMap-only mode does not automatically enable EUI map markers; timers remain off by default.
- Fixed micro-menu icons for newer EUI versions using boolean style caches. Legacy rs selections migrate to EUI's supported Custom style, and Blizzard textures, atlases and portraits retain their native behavior.
- Added an optional player-class color setting in the Bel Toolbox icons cog. Turning it off restores EUI's current icon color.
- The Chat Bar Dungeon Journal button can open DungeonsForever or NeedRoll, selected in its settings cog. Right-click still opens loot history, and hover text follows the selected addon.

# Bel Toolbox 0.19.22-dev

- Added a native settings cog for Bel Toolbox micro-menu icons with optional player-class tinting. Disabling class tint restores EUI's latest color; Blizzard icon style remains native.
- Chat Bar's Dungeon Journal cog can now select DungeonsForever or NeedRoll for left click. Existing choices default to DungeonsForever; right click still opens loot history. Tooltip text follows the selected addon.

# Bel Toolbox 0.19.21-dev

- Updated Bel Toolbox micro-menu icons for EUI's boolean icon-style cache while retaining legacy string-cache support.
- Migrate legacy micromenu iconStyle=rs to EUI's supported custom key, fixing the raw rs dropdown label. The Bel Toolbox icons preference continues to control the original toolbox artwork.
- Preserve native Blizzard textures and atlases when switching styles or disabling toolbox icons; secure button actions remain unchanged.

# Bel Toolbox 0.19.20-dev

- Moved EUI/OpenMap countdown display switches into a native EUI settings cog beside the transport timer master toggle. Existing display preferences are preserved and can be edited while the master toggle is off.

# Bel Toolbox 0.19.19-dev

- Added separate EUI and OpenMap icon countdown switches under the transport timer master switch. Existing enabled setups retain both displays; the master switch remains off by default.
- OpenMap-only display no longer automatically enables EUI Map Markers. Turning a display off immediately hides its countdowns and restores EUI's native dock tooltip where applicable. With both displays off, the timer ticker stops.

# Bel Toolbox 0.19.18-dev

- Added OpenMap's separate airship category to countdown attachment, including the Mulgore and Alterac Mountains routes to Zephras Isle. Their existing schedules were already included; no new timetable is needed.
- Covers existing and newly-created airship pins, including mainland docks whose destination map is not part of OpenMap's stitched projection.

# Bel Toolbox 0.19.17-dev

- Added optional OpenMap compatibility for ship/zeppelin countdowns below its native dock icons on the stitched map. Reuses existing timers and calibration; no extra routes or moving icons are drawn.
- Match both departure docks and destinations to distinguish nearby piers. Labels follow OpenMap icon visibility and disappear for unsupported routes, reused non-transport icons or the timer's disabled state. Native icon clicks/tooltips remain intact.
- Supports already-created and newly-created OpenMap pins while preserving the existing EUI pin integration. OpenMap remains optional; transport timers remain off by default.

# Bel Toolbox 0.19.16

- Added text, color-block and color-block-with-label styles for the chat bar, with configurable block width and spacing. Existing settings retain text mode by default.
- Added native EUI color-setting cogs for each chat button: independent block and font colors, immediate preview and restore defaults. Default colors follow channel settings without changing chat itself.
- Added centered, left and right main-bar growth for Mage and Consumables bars, independently of flyout expansion. Incomplete rows align to the selected direction.
- Added hover-only layout controls inside native EUI movers for button size, spacing, buttons per row and growth. Each link opens its corresponding setting; narrow movers show one combined Bar settings entry.
- Improved mover identification, control placement and rendering layers. Fixed clicked links becoming faded after closing settings popups.
- Unlock edits support Save/Discard and hide during combat. Added /belbareditdebug for in-game diagnostics.

# Bel Toolbox 0.19.16-dev

- Unlock action links now open only their corresponding size, spacing, row-count or growth control. The compact Bar settings entry still exposes all controls.
- Disabled EUI's cog-owner dimming for these text links so clicking/closing settings does not leave them faded. Separate compact/single-control popup caches preserve the correct contents after mover width changes.

# Bel Toolbox 0.19.15-dev

- Fixed the confirmed Consumables editor lookup mismatch: its registered key is BelToolboxconsumables, not BelToolboxConsumables. Editor discovery now reads the exact key saved by mover registration instead of maintaining a separate spelling.
- Mage registration shares the same key handoff. Diagnostics include the expected key; regression coverage uses the actual shared registration path.

# Bel Toolbox 0.19.14-dev

- Discover Mage/Consumables movers from the native EllesmereUnlockMode host as well as mouse focus, so overlaid mouse focus cannot prevent editor attachment.
- Added read-only /belbareditdebug diagnostics: session state, watcher ticks, visibility gate, captured runtime error and root/mover/control geometry and layers. Live client diagnostics are needed if controls remain invisible.

# Bel Toolbox 0.19.13-dev

- Fixed Mage/Consumables unlock controls being covered by the native mover's opaque background. Parent the action row directly to its EUI mover and keep it above the mover's frame level, including hover/selection raises.
- Keep the compact bounds-aware layout, native settings popups and Unlock Mode save/discard behavior.

# Bel Toolbox 0.19.12-dev

- Fixed unlock quick-edit links extending outside native EUI mover borders. Size the action row from the mover's actual bounds and use short labels; narrow movers show a single Bar settings entry with all controls.
- Removed writes to EUI's private hover-size cache. Native mover sizing and animation remain under EUI's control.

# Bel Toolbox 0.19.11-dev

- Added native EUI inline color-setting cogs beside individual chat button toggles: independent block and font colors, live preview and restore defaults. Defaults continue to follow channel colors without changing chat's own settings.
- Replaced the separate Mage/Consumables editor box with compact action links inside the native mover's hover area. EUI retains the background, centered name, coordinate readout and position cog; layout controls open native EUI settings popups.
- Preserved hover-only visibility, combat suppression and Unlock Mode save/discard behavior.

# Bel Toolbox 0.19.10-dev

- Mage and Consumables quick-edit controls now appear only while hovering their bar or native EUI mover in Unlock Mode. Short enter/leave delays keep controls usable while crossing to the editor or growth menu.
- Controls hide when the pointer leaves, the bar hides, combat begins or Unlock Mode closes. Hover checks run only during Unlock Mode.

# Bel Toolbox 0.19.9-dev

- Added quick-edit panels beside Mage and Consumables bars during EUI Unlock Mode: button size, spacing, buttons per row and centered/left/right growth. Discard restores layout settings; combat hides the controls.
- Added main-bar growth direction settings independently of flyout expansion. Explicit growth changes preserve the current screen rectangle and pin future resizing to the selected edge or center; incomplete rows align to that direction.
- Existing bars retain their layout until growth is changed. Consumable root positioning now runs before child placement.

# Bel Toolbox 0.19.8-dev

- Added text, color-block and color-block-with-label styles for the chat bar. Existing settings retain text mode by default.
- Color blocks use configured chat channel colors, with channel names and shortcuts available on hover. Click actions remain unchanged.
- Added adjustable color-block width and button spacing; both horizontal and vertical layouts support the new styles.

# Bel Toolbox 0.19.7

- Added Mage Bar category visibility and drag sorting, buttons per row, 18–64 button sizes and 0–16 spacing. Zero spacing removes icon gaps.
- Added automatic Mage flyout direction based on available screen space while preserving manual direction, legacy settings and remembered spell ranks.
- Improved Mage and consumable flyout tooltip placement to avoid covering expanded buttons; aligned consumable arrows with the actual expansion edge.
- Improved Mage Bar stability when changing spacing or categories: reuse cached spells for layout updates, preserve temporarily unavailable icons, position the root before its buttons and repair unresolved button coordinates with one deferred check.
- Layout and spell changes requested during combat are applied after combat ends. Expanded /belmagedebug diagnostics with button geometry and anchors.

# Bel Toolbox 0.19.7-dev

- Addressed Mage Bar buttons reporting shown/visible with nil screen coordinates after category toggles. Position the clamped root before anchoring/showing its buttons, and avoid clearing valid, unchanged anchors during layout updates.
- Add a single deferred geometry check per refresh burst to repair enabled, learned categories with unresolved positions. No continuous polling; combat changes remain deferred.
- Expanded /belmagedebug with root/button anchor tuples to diagnose any remaining client-specific layout issue.
- Simulated all 32 category visibility combinations across repeated sweeps, the reported two-button state, missing geometry recovery and parent position changes.

# Bel Toolbox 0.19.6-dev

- Separated Mage Bar layout changes from spellbook scans: adjusting size, spacing, row count or category order reuses the last known spell list rather than hiding/rebuilding spells at every slider tick.
- Preserve the last resolved icon if spell texture data is temporarily unavailable, and update root bounds before child layout. Deferred spell rescans survive combat.
- Added read-only /belmagedebug output for unresolved in-game disappearance reports: visibility, alpha, icons, positions and cached/live spell counts. This targets plausible refresh causes; client verification remains necessary.

# Bel Toolbox 0.19.5-dev

- Added native EUI drag-reorder/category controls to Mage Bar settings, configurable buttons per row, 18–64 button sizes and 0–16 spacing. Removed icon insets so zero spacing produces touching edges.
- Added automatic flyout direction using screen space, preserving explicit manual and legacy direction settings. Re-evaluate positions after movement and hover outside combat.
- Preserved legacy large-button sizes and rank-specific remembered spells. Layout changes during combat wait until combat ends.
- Mage flyout tooltips share the consumable flyout avoidance helper so automatic expansion does not put the tooltip over expanded spells.

# Bel Toolbox 0.19.4-dev

- Changed consumable tooltips to use the Mage Bar's right-side owner anchor. While expanded, position tooltips beside the full flyout grid so they do not cover its item buttons; horizontal flyouts use the space above or below.
- Matched Mage Bar expansion arrows: 14px, centered on the edge corresponding to the actual expansion direction.

# Bel Toolbox 0.19.3

- Added an optional consumables bar for food, drink, healing potions, mana potions, healthstones, mana gems, bandages, flasks, elixirs and resistance potions. Enable it under EUI > Bel Toolbox > Consumables.
- Hover a category to expand its items. Left-click an expanded item to use it without changing the default; right-click to make it the default. Click Auto to clear the manual choice. Defaults are remembered per character.
- Flyouts automatically choose their direction using available screen space. Existing choices can be used or selected through secure buttons during combat; inventory-driven replacements wait until combat ends.
- Added EUI Quick Keybind Mode (/kb) support for category buttons, including keyboard, mouse side buttons and wheel bindings. Save or cancel using EUI's original binding window.
- Added EUI Unlock Mode positioning and native drag-reorder category controls, optional empty-category hiding, buttons per row with wrapping, 18–64 button sizes and adjustable spacing. Zero spacing now removes the icon inset as well.
- Improved cooked-food recognition, including Westfall Stew (733). Buff/unknown food, flasks, elixirs and resistance potions require manual selection to avoid choosing an unwanted effect.
- Preserved the seven-button default row width and existing saved category order. Empty categories temporarily appear in /kb for binding.
- Avoided repeated item-data requests for already-cached items above the player's level. Counts and cooldowns update through events rather than continuous polling.

# Bel Toolbox 0.19.3-dev

- Added Flask, Elixir and Resistance Potion categories to the consumables bar, including common classic elemental protection, greater protection and magic resistance potions.
- New categories use existing hover flyouts, right-click default selection, EUI drag ordering and /kb bindings. Buff consumables require a manual default rather than automatically choosing a class effect or resistance type.
- Preserve existing category order and the seven-button default row width; new categories append automatically.

# Bel Toolbox 0.19.2-dev

- Removed vertical consumable layouts; configure buttons per row with automatic wrapping.
- Reused EUI's drag-reorder checkbox dropdown for category visibility and order.
- Expanded button sizes to 18–64 and removed the 2px icon inset so zero spacing produces touching icon edges.
- Replaced the right-click picker with secure hover flyouts. Left-click a flyout item to use it without changing the default; right-click to make it the default. The Auto control clears manual selection.
- Flyouts automatically choose a direction based on available screen space and re-evaluate after movement. Counts and cooldowns include expanded item buttons; binding mode suppresses expansion.

# Bel Toolbox 0.19.1-dev

- Match EUI's Quick Keybind Mode (/kb) naming.
- Added hide-empty categories, configurable buttons per row/column with wrapping, button spacing, and category ordering. Empty slots can still be bound while /kb is open.
- Fixed cooked/quest-reward food recognition, including Westfall Stew (733), and show unselected manual food as an available category with a choice indicator. Buff and unknown food remain manual choices.
- Choice lists now include icons, counts and the selected-item indicator. Multiple items remain accessible through the right-click picker.
- Avoid repeatedly requesting already-cached item data for items above the player's level.

# Bel Toolbox 0.19.0-dev

- Added an opt-in consumables bar for food, drink, healing/mana potions, healthstones, mana gems and bandages. Stable empty slots, counts, cooldowns, per-character item choices, automatic fallback and EUI Unlock Mode integration.
- Added an adapter for EUI's native quick keybinding mode. Hover a consumable button to bind keys, mouse buttons or the wheel; Escape clears its keys. The original window owns Save/Cancel. No secure actions or layout changes are made in combat.
- Uses conservative automatic food selection: unknown or buff food requires manual selection. Spell names are resolved in the client's language; no external addon or proprietary assets are bundled.
- Prototype remains on dev for in-game verification; no formal release is triggered.

# Bel Toolbox 0.18.9

- Fixed quest-object sparkles on clients with normal or raid outlines enabled. Save and restore all relevant settings, reapply after graphics changes, and defer changes during combat.
- Added a persistent notice beside the setting: after disabling, fully exit and relaunch the game to clear existing sparkles; /reload is not enough. Enabling and the full-restart requirement have been confirmed in game.
- Added automatic releases when a stable version is merged into main. GitHub and CurseForge receive the same addon ZIP and current-version Markdown changelog; EUI is declared a required CF dependency.
- Added release validation, ZIP checksums and upload receipts to support recovery without duplicate CF uploads. Herb/ore sparkle effects are not included.

# Bel Toolbox 0.18.9-dev

- Added a persistent notice below Quest Item Sparkles: after disabling, fully exit and relaunch the game to clear existing sparkles; /reload is not enough. The hover tooltip now gives the same explicit guidance.
- In-game feedback confirms enabling the corrected sparkle feature works and that clearing it requires a full restart.

# Bel Toolbox 0.18.8-dev

- Fixed native quest-object sparkles not appearing with normal or raid outlines enabled. Manage all five relevant graphics CVars, reapply after graphics changes, and defer changes until combat ends.
- Save and restore each supported setting, migrate the existing loot-effect baseline, and preserve external changes when disabling. No herb/ore soft-target effects are added.
- Updated the option description to explain the outline tradeoff and full game restart needed to clear cached sparkles. Client verification remains necessary.

# Bel Toolbox 0.18.7

Quality-of-life extensions for EllesmereUI on WoW Forever.

## New

- Added independent ship and zeppelin countdowns below EUI's existing world-map transport icons. White shows time until arrival; gold shows time until departure. Hover for individual services and calibration information.
- Transport timers are off by default. Enabling them automatically enables EUI Map Markers and Transports, preserving other map categories.
- Included 13 recorded ship/zeppelin routes with automatic onboard calibration and realm-specific saved timings. No additional route lines, clock icons or moving vehicles are drawn.

## Improvements and fixes

- The merchant assistant now reuses EUI Bulk Buy when enabled, avoiding duplicate purchase windows. Ordinary gold items accept individual quantities, including one item from a vendor bundle.
- Corrected per-item totals, affordability and fractional-copper rounding. Fixed amount-label visibility and compatibility with the namespaced currency formatter.
- Preserved native EUI handling for currency-cost and unique items, plus high-price confirmation for toolbox-managed gold purchases.
- Stopped ship/zeppelin tooltip refreshes from restarting EUI's fade animation every second.
- Added `/belmerchantdebug` for read-only amount-label diagnostics.

## Installation and notes

- Requires EllesmereUI for WoW Forever (Interface 16001). Extract the included `BelToolbox` folder into `Interface/AddOns/`, then restart or `/reload`.
- Settings: **EUI > Bel Toolbox**, or `/bel` / `/beltoolbox`.
- Enable transport timers under **Interface Enhancements**. Stand still aboard a sailing ship or zeppelin to calibrate. Server restarts or layer changes may require recalibration; unsupported docks show `?`.
- Lua compilation and simulated merchant, map, chat, profession and transport regression checks passed. Exact behavior on the live client still needs verification; the latest merchant amount fix has not yet received in-game confirmation.

DockWatch route data is included under MIT; its copyright and license are preserved in `THIRD_PARTY_NOTICES.md`.

# Bel Toolbox 0.18.7-dev

- Fixed use of the legacy global GetCoinTextureString in the merchant amount line and high-price confirmation. Prefer C_CurrencyInfo.GetCoinTextureString, matching EUI; fall back to the legacy global or localized copper text when unavailable.
- A namespace-only client simulation reproduces the previous version aborting before SetText with a missing global formatter. Updated tests remove the global instead of assuming it exists; unit-cost rendering and native dialog integration pass in both load orders. Legacy-only merchant tests also pass.
- `/belmerchantdebug` now reports both formatter API types to verify the actual client compatibility path. Live-client confirmation remains necessary.
# Bel Toolbox 0.18.6-dev

- Added read-only `/belmerchantdebug` diagnostics for the unresolved live-client blank Bulk Buy amount. Reports active adapter state, requested quantity, bundle pricing, expected copper total and both amount FontStrings' contents, visibility, alpha, geometry, font, color and anchors.
- This diagnostic build does not claim to resolve the blank label. The command performs no purchases, rendering changes, polling or persistent logging.
- Simulated diagnostic output correctly distinguishes populated and blank/hidden labels without changing purchases or visibility. Existing native EUI integration checks pass.
# Bel Toolbox 0.18.5-dev

- Fixed the replacement Bulk Buy amount line appearing blank: the new label no longer inherits content-driven bounds from EUI's initially empty native cost FontString. It is anchored directly to the dialog with a fixed 20-pixel height and explicit opacity.
- Added simulated geometry/visibility checks alongside the existing exact-unit-total, repaint and native-restoration tests, for both native dialog creation orders. Client verification remains necessary.
# Bel Toolbox 0.18.4-dev

- Fixed the visible EUI Bulk Buy total still reverting to bundle pricing. For toolbox-managed ordinary gold items, a dedicated cost label now occupies the original cost-line position while EUI's independently refreshed bundle-cost label is transparent. The visible total uses ceil(quantity * bundlePrice / bundleCount).
- The label copies EUI's font and color; only one cost line is visible. Special-cost/unique items, closing the dialog and disabling the assistant restore EUI's native cost line.
- Simulated 1/7-item totals, direct native bundle-cost overwrites, merchant repaints, fractional-copper rounding and special/disabled restoration passed with both native dialog creation orders. Client confirmation remains necessary.
# Bel Toolbox 0.18.3-dev

- Ship/zeppelin timers are now off by default. Only an explicitly enabled setting starts calibration, displays labels or automatically enables EUI transport markers. Existing explicit on/off preferences are preserved.
# Bel Toolbox 0.18.2-dev

- Enabling transport timers now enables EUI Map Markers and Transports through the existing MapTravel configuration and apply interface. This also runs at login for enabled timers and after late map/module loading.
- Other map categories are preserved; unchanged settings do not trigger a redundant apply. Disabling timers does not disable EUI's independently useful markers.
- Simplified the transport option tooltip: describes automatic marker activation and onboard calibration without dependency details.
- Simulated login, explicit enable, late EUI loading, disabled-state behavior and unrelated category preservation passed, alongside existing transport/tooltip/calibration checks. All addon Lua files compile.
# Bel Toolbox 0.18.1-dev

- When EUI Merchant Bulk Buy is enabled, the merchant assistant now uses EUI's existing quantity window instead of opening a second toolbox window. Ordinary gold purchases use a one-item step and accurate prorated total cost/affordability, including vendor repaints and repeated openings.
- Currency/extended-cost and unique items retain native EUI behavior. High-price gold orders retain confirmation and non-refundable warnings. Closing, disabling, changing the merchant, unconfirmed delivery or server overdelivery stops the toolbox order; native pack semantics return when the assistant is disabled.
- Fixed the ship/zeppelin tooltip's once-per-second flash: EUI's shared tooltip restarts its fade on ShowWidgetTooltip. After the initial open, timers now update only the existing owner's text and measured height, preserving alpha, anchors and animations. Hidden or unrelated widget tooltips are not shown or overwritten; if the shared frame cannot be located safely, its initial text remains static until the next hover.
- Verified against the locally installed EUI quantity-dialog and merchant implementations in simulation, both before and after native dialog creation: one-window behavior, 1/7-item requests, exact costs, partial affordability, repaint, special-item fallback, confirmations/cancellation and overdelivery. Ship tooltip live-refresh/ownership checks and existing timer/calibration regressions passed. Live-client verification remains necessary.
# Bel Toolbox 0.18.0-dev

- Added independent boat/zeppelin countdown labels below EUI Forever Essentials world-map travel pins. EUI's map markers and transport icons must already be enabled; native icons and click behavior are preserved.
- White labels count down to arrival; gold labels count down to departure. Grouped harbors show the nearest service, with individual routes and calibration provenance in the existing tooltip. Unsupported docks show `?`.
- Bundled 13 DockWatch ship/zeppelin route baselines and recorded tracks under MIT, with attribution in THIRD_PARTY_NOTICES.md. No DockWatch runtime, media, route drawing, animated transports, flights, tram or peer communication is included.
- Added conservative onboard calibration: sustained carried movement while the player stands still must match a unique recorded route/direction. Walk/taxi/fly/fall/vehicle/combat and ambiguous tracks are rejected. Calibration is stored by realm; known three-stop circuit departures propagate between legs.
- One-second work is canceled when disabled; map label discovery/rendering runs only while the map is open. Tracks are used for calibration only, not drawn. Server restarts/layer changes may invalidate an old baseline until a new ride is observed.
- Simulated label attachment, native click preservation, schedule derivation, realm isolation, recorded-track calibration, three-stop circuits, movement/combat guards, pooled pins, tooltip restoration and enable/disable checks passed. Existing merchant/map/settings, profession-profit and chat-copy regressions passed. Live-client visual/timing verification is pending.
# Bel Toolbox 0.17.3 — Beta

- Fixed unbalanced inline color spans in enhanced chat-copy output: replacing each native reset with another channel-color opener left spans unclosed across messages. Channel transitions now close the previous span before opening the next, with no nested or accumulating spans.
- Preserve player/item colors and restore channel body color while keeping each message's markup balanced. Literal escaped pipes and named-color tokens are handled during transitions.
- Corrected diagnostic row alignment for messages containing embedded newlines; source message indices now map to their corresponding physical lines in the native and enhanced text.
- Regression checks cover 350 class-colored senders across 700 physical lines with depth-one, balanced color transitions and correct first-to-last name colors. Existing search, native restoration, drag/resize and diagnostic checks passed. Live-client confirmation is still needed.
# Bel Toolbox 0.17.2 — Beta

- Added opt-in `/belchatdebug on`, `/belchatdebug`, and `/belchatdebug off` diagnostics for the remaining live-client name-color issue.
- Compare source-buffer, original EUI-copy, and enhanced-output color tokens in both enabled and disabled states, including color/escape counts and active settings.
- Retain only the last four snapshots in memory; no message bodies, saved logs, polling, or default diagnostic overhead. The class-color issue remains under investigation pending a client trace.
- Diagnostic lifecycle, bounded storage, body omission, exact native restoration, search and resize simulations passed.
# Bel Toolbox 0.17.1 — Beta

- Added a master switch that restores EUI's native copy text, size and layout when disabled. Existing settings with all three old options disabled migrate to the native window.
- Bound dragging to the move/resize option and added a separate search toggle. Disabling cancels pending searches and prevents hidden controls from moving/resizing the window.
- Preserve native EUI player-name colors before applying class fallbacks. Reuse existing colored player links across messages, including pre-login history, without overwriting native inline colors.
- Removed an unnecessary GUID-format restriction for class lookups on custom clients.
- Simulated native restoration, repeated reopening, search cancellation, independent controls and name-color preservation checks passed, alongside settings, merchant/map and profession-profit regressions. Client verification remains necessary.
# Bel Toolbox 0.17.0 — Beta

- Added a draggable chat-copy header with saved window position.
- Added literal name/message search, a matching-message counter and a clear button. Closing the window cancels pending searches; reopening restores the full message list.
- Added optional class-colored player names using chat sender GUIDs and known group/guild information. Unknown or ambiguous classes retain their existing colors; message bodies preserve channel colors.
- Class metadata is session-only and bounded; search is debounced without polling or persistent chat storage.
- Simulated chat source, class lookup, search, drag/resize persistence and Lua compilation checks passed. In-game verification remains necessary.
# Bel Toolbox 0.16.1 — Beta

- Declared EllesmereUI as a required dependency instead of an optional dependency.
- Grouped Bel Toolbox under EllesmereUI in the in-game addon manager using the same Group and Category metadata as native EUI modules.
- Individual EUI feature modules and price providers remain optional.

# Bel Toolbox 0.16.0 — Beta

- Added chat copy window enhancements through EUI's HostPopup hook, without editing EUI addon files.
- Added a bottom-right resize grip, bounded dimensions and saved size restoration on reopening/reloading. ScrollingEditBox contents/range are refreshed after resizing.
- Restored each copied message's channel RGB from the active EUI engine buffer, with native chat/combat-log fallback. Inline item/player colors remain intact and color resets return to that message's channel color. Protected text is skipped.
- Added independent resize and channel-color toggles under Interface Enhancements / Chat Copy Window; both are on by default. No polling or persistent chat-history storage was added.
- Simulated engine/native source, inline color, secret-value, hosted combat-log, resize persistence, disable/restore and close-during-drag checks passed. Existing merchant/map/settings and profession-profit regressions passed. Actual in-game appearance and drag behavior require client verification.
