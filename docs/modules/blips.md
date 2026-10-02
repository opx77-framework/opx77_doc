---
title: blips module
description: Map pins for garages, dealers, clothing shops, teleports and job sites, read from the modules that own those places.
---

# blips

`blips` puts pins on the fullscreen map and on the minimap for the places a player needs to find: garages, dealers, clothing shops, teleport shortcuts and job sites. It holds no coordinates of its own. It reads the lists other modules already have on the client every few seconds and turns them into pins, so a pin moves when the place moves. Turn a category off, or change its sprite or range, in `config/blips.lua`.

| | |
|---|---|
| Side | client only |
| Requires | — |
| Optional | `garages`, `dealership`, `teleports`, `shops`, `hud` |
| Configuration | `config/blips.lua` (shared script) |
| Contract | none |

The manifest must declare `ui.vanilla.map`; without `Open77.blips` the module says so once and draws nothing.

## Where the pins come from

| Category | Source | Pins |
|---|---|---|
| `garages` | [`garages`](garages.md) client point list (own bucket only) | One per drawn point: a menu point and an entry point per location, both labelled with the garage label. |
| `dealership` | [`dealership`](dealership.md) client dealer list (own bucket only) | One per dealer. |
| `shops` | `SHOPS` in the shops config | One per shop. |
| `teleports` | [`teleports`](teleports.md) client entrance list | One per entrance (both ends of a two-way). Locked ones are pinned too. |
| `jobs` | gunsmith `ARMOURIES` and hauling `SITES` configs | Each armoury `BENCH`; each hauling site once (its `BLIP`, else its first real point) and each of its `DROPOFFS`. A site or armoury whose `JOBS` gate the player does not pass is not pinned. |

- A point at exactly `0, 0, 0` is a placeholder and is skipped (and counted in the boot note).
- Pins are created in the order above until `MAX` is reached; the rest are not pinned and a note says how many.
- The minimap shows pins only when the HUD leaves the vanilla `minimap` component visible (`VANILLA.minimap` in `config/hud.lua`). The fullscreen map always shows them. The boot note says which applies.

## Configuration {#configuration}

`config/blips.lua` sets `OPX.Config.MODULES.blips`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-blips-enabled"></a>`enabled` | `true` | `false` switches the module off. |
| <a id="config-blips-scan-ms"></a>`SCAN_MS` | `4000` | How often the pins are reconciled with the sources. |
| <a id="config-blips-batch"></a>`BATCH` | `8` | Pins created or removed before the thread yields a frame. |
| <a id="config-blips-max"></a>`MAX` | `128` | Most pins this module creates. Clamped to the platform quota of 128 per resource. |
| <a id="config-blips-categories"></a>`CATEGORIES` | see below | One block per category. |

### A category

| Field | What it does |
|---|---|
| `SHOW` | `false` hides the category. |
| `SPRITE` | Vanilla sprite: an alias (`vehicle`, `objective`, `clothes`, `fast_travel`, `guns`, `quest`, …), a 2.31 variant name or an integer 0–146. **The sprite is the colour**: there is no colour option. HUD-only sprites (`ping_*`, `remote_player`) may not appear on the fullscreen map. |
| `LABEL` | Description line on the pin (the pin title is the place's own label). Defaults to the category name. |
| `RANGE` | Metres, 0–4000. `0` = always visible. Out of range hides the pin on the HUD, minimap and map alike. |
| `WALLS` | `true` makes the pin visible through walls. |

| Category | `SPRITE` | `LABEL` | `RANGE` |
|---|---|---|---|
| `garages` | `vehicle` | `Garage` | `0` |
| `dealership` | `objective` | `Vehicle Dealer` | `0` |
| `shops` | `clothes` | `Clothing Shop` | `400` |
| `teleports` | `fast_travel` | `Shortcut` | `0` |
| `jobs` | `guns` | `Job Site` | `0` |

All default to `SHOW = true` and `WALLS = false`. A category name outside these five is reported at boot. Writing `COLOR`, `COLOUR`, `ALPHA`, `OPACITY`, `SCALE`, `CATEGORY`, `SHORTRANGE` or `SHORT_RANGE` in a category is reported at boot with the setting to use instead, because the engine refuses those options.
