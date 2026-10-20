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