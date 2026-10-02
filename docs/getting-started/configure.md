---
title: Configure OPX//77
description: Where opx_infinity's settings live — one file per module under config/, the runtime-wide files, which files are sent to every player, how to turn a module off, and what can change while the server runs.
---

# Configure the server

All settings live in `opx_infinity/config/`. There is **one file per module**
(`config/<module>.lua`) and three runtime-wide files. Edit a file, then restart
the resource. Each module page has a **Configuration** table with every key and
its default.

## The runtime-wide files {#runtime-files}

| File | Table | Sent to players? | Holds |
|---|---|---|---|
| `config/shared.lua` | `OPX.Config.SHARED` | **yes** | language, server name, money accounts, health pool, AV record prefixes |
| `config/server.lua` | `OPX.Config.SERVER` | no | command aliases, entry gate timings and buckets, conflicting resources |
| `config/client.lua` | `OPX.Config.CLIENT` | yes | the WebUI surface and toast placement |

Every key is in [Core configuration](../reference/core-config.md).

## Module files {#module-files}

Each `config/<id>.lua` sets `OPX.Config.MODULES.<id>`. Most are **shared
scripts**, so every connecting player downloads them.

!!! warning "Never put a secret in a shared config file"

    A shared config ships to every client. Credentials, webhooks and anything a
    player must not read belong in a server-only file. Granting rights belongs
    in `acl.jsonc`, not in a config file.

These module configs are **server only**: `config/vehicles.lua` and
`config/theme.lua` (the client is sent its colours over the network). All others
are shared.

### Turning a module off {#disable}

Set `enabled = false` in its config file:

```lua
OPX.Config.MODULES.calls = {
	enabled = false,
	-- ...
}
```

The module is then reported `disabled`, and every module that **requires** it
is reported `unavailable`. Check the [module list](../modules/index.md) for
dependencies before you turn one off.

## Language {#language}

Set `LOCALE` in `config/shared.lua` to `'en'` or `'fr'`. See
[Text and locales](../how-it-works/locales.md).

## Short command names {#aliases}

`COMMAND_ALIASES` in `config/server.lua` gives long commands a short name
(`noclip` for `opx.admin.self.noclip`). An alias is checked against the long
command's ACL right. An alias the host cannot register (because another resource
already uses the name) is skipped with a warning. Empty the table to remove all
aliases.

## Colours {#theme}

`config/theme.lua` sets the accent colours of every screen. See the
[theme module](../modules/theme.md).

## Values you can change while the server runs {#tunables}

Some numbers are **tunables**: an operator changes them from the platform's
Warden panel without a restart. The value in the config file (or module code) is
the default. Modules that declare tunables:

| Module | Tunables |
|---|---|
| [animations](../modules/animations.md) | `ANIM_RATE_WINDOW_MS`, `ANIM_RATE_REQUESTS`, `ANIM_ONE_SHOT_MS`, `ANIM_MAX_DURATION_MS` |
| [elevators](../modules/elevators.md) | `ELEV_TRAVEL_MS`, `ELEV_REQUEST_WINDOW_MS`, `ELEV_REQUESTS_PER_WINDOW` |
| [hauling](../modules/hauling.md) | `HAUL_REFILL_MS`, `HAUL_PAY_PER_CRATE` |
| [teleports](../modules/teleports.md) | `TP_REQUEST_WINDOW_MS`, `TP_REQUESTS_PER_WINDOW`, `TP_FADE_MS`, `TP_SETTLE_MS` |
| [admin](../modules/admin.md), [inventory](../modules/inventory.md) | see their pages |

If the host has no tunables panel, the defaults are used and the log says
`[tune] no tunables panel on this host; configured defaults are used`.

## Places in the world {#places}

Garages, dealers, clothing stores, teleports, elevators, shops, crafting
benches, armouries and hauling sites are **written in their config file**, with
coordinates. To capture a position, stand on the spot and run
`/opx.admin.self.pos` (alias `pos`); it copies the position and your facing to
the clipboard. See each module's page for the format.
