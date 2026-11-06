# Local EUI compatibility review — 2026-11-05

Client: `_forever_`; installed EUI: **9.7.5**. This is a scoped source/API review, not a complete upstream changelog or an in-game test report.

## Confirmed change and fix

Player rest text moved from `_restIndicator` to `_restText`. EUI now owns `_restAnim`, `_restUpdate` and `_restPlace`, with `restedIndicatorAnimated` and `restedIndicatorAnimatedSize` settings. Bel Toolbox uses this native implementation when present, preserves the main EUI visibility switch, and retains its older adapter for older EUI versions.

## Other locally listed new features

EUIOptions/EUI__General_Options.lua lists travel-block click destinations/cooldowns; micro-menu guild public notes with custom color; animated resting icon and size; centered raid groups; role icons on the top name bar; a movable player-group label; click-casting actions; continuous pip textures; and Forever Anti-Clip Glow. These are the installed What's New entries, not a claim that all arrived in one patch.

## Integration review

| Surface | Finding |
| --- | --- |
| Micro-menu icons | Boolean style cache, block factory and named icon frames still present. Existing toolbox adaptation retained; guild-note additions affect native tooltip content. |
| Transport markers | `_MapTravel` configuration/application interface still present. Native OpenMap integration remains separate. |
| Unlock mode | Registration/session listener and mover hooks still present. |
| Chat copy | Installed engine matches the available older local snapshot; no engine change found in that comparison. |
| Merchant bulk buy | Native edit box, total-cost region and refresh hook used by the bridge still present. |

Simulation coverage includes old/native resting transitions and preference restoration, micro-icon colors/textures, chat actions, transport matching, toolbar editing and layout. Rendering, protected-action behavior and interference from other installed addons still require client verification.
