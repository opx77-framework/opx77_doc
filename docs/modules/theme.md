---
title: theme module
description: The server's colour scheme and surface style, set in one config file and pushed to every player's interface.
---

# theme

The `theme` module sets the look of every OPX screen: the accent colour, the alarm colour, how dark the panels are, the scanline, the tilt and the corner cut. The operator sets them once in `config/theme.lua`; every player gets the same theme, and players cannot pick their own. From one accent hex the module derives the whole colour ladder (idle, deep, hi, text, alarm and two panel grounds). A key left out keeps the interface's shipped value. Without this module the interface keeps its shipped red.

| | |
|---|---|
| Side | both |
| Requires | nothing |
| Configuration | `config/theme.lua` (**server** script) |
| Contract | `theme` v1 — server |

The config is a server script: clients never hold a copy and only receive the resolved values. Bad values are refused at start with a line in the server log, one per value.

## Server contract {#server-contract}

`local theme = OPX.Api.Get('theme')` on the server, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-theme-current"></a>`Current` | — | `table` | A copy of the resolved payload (see below). Empty when nothing is configured. Read only; there is no setter. |

### Payload

Colours are `{ r, g, b }` integers 0–255. Keys appear only when the matching config key is set.

| Key | From | Range |
|---|---|---|
| `accent`, `idle`, `deep`, `hi`, `text`, `alarm`, `plate`, `plateLit` | `ACCENT` (`alarm` from `ALARM` when set) | 0–255 per channel |
| `plateAlpha` | `PLATE_OPACITY` | 0.20–0.98 |
| `plateQuietAlpha` | `PLATE_OPACITY − 0.20` | 0.00–0.98 |
| `plateLitAlpha` | `PLATE_OPACITY + 0.12` | 0.20–1.00 |
| `interlaceAlpha` | `0.05 × INTERLACE` | 0.00–0.15 |
| `tiltDeg` | `TILT` | 0–15 |
| `cutSm`, `cutMd`, `cutLg` | `6`, `12`, `20` × `CUT` (rounded) | 1–24, 1–48, 1–80 |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-theme-request"></a>`opx:net:theme:request` | client → server | — | "What is the theme?" Sent once per client start. Answered at most every 2 s per player. |
| <a id="opx-net-theme-set"></a>`opx:net:theme:set` | server → client | `payload` | The resolved theme. The client checks it against the same bounds again. |

## Page channels {#page-channels}

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-theme-ready"></a>`theme:ready` | page → Lua | — | The page is up and can take the theme. |
| `theme:set` | Lua → page | `payload` | Sent once both the page is ready and the server has answered; re-sent when the page is rebuilt. |

## Configuration {#configuration}

`config/theme.lua` sets `OPX.Config.MODULES.theme`. Server script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-theme-enabled"></a>`enabled` | `true` | `false`: the interface keeps its shipped look. |
| <a id="config-theme-accent"></a>`ACCENT` | `'#ff3b47'` | The main colour, `#RRGGBB` only. Every other rung is derived from it. A very light or very dark accent (lightness outside 0.30–0.78) is accepted with a warning: the bright states will look alike. |
| <a id="config-theme-alarm"></a>`ALARM` | `'#ffa8ae'` | The alarm colour, `#RRGGBB`. Unset, it is derived from `ACCENT`. |
| <a id="config-theme-plate-opacity"></a>`PLATE_OPACITY` | `0.78` | Darkness of panel backgrounds, 0.20–0.98. |
| <a id="config-theme-interlace"></a>`INTERLACE` | `1` | Scanline strength: `0` off, `1` shipped, `2` double; capped at 3. |
| <a id="config-theme-tilt"></a>`TILT` | `7` | Lean of edge-anchored panels, in degrees, 0–15. |
| <a id="config-theme-cut"></a>`CUT` | `1` | Scale of the corner cut over 6/12/20 px. Never 0. |
