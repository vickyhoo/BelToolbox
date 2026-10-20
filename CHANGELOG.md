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