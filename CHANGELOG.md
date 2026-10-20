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