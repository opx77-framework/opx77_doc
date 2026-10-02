---
title: Convert a FiveM resource to OPX//77
description: How FiveM, ESX and QBCore habits map onto Open77 and opx_infinity — what stays the same, what changes, and where each familiar framework call now lives.
---

# Convert from FiveM

The runtime shape of Open77 is close to FiveM: `CreateThread`, `Wait`,
`RegisterNetEvent`, `TriggerServerEvent`, `RegisterCommand` and `exports` all
exist. The natives do not: Open77 has its own `Open77.*` API. And OPX//77 is not
ESX or QBCore, even where the names look familiar. This page lists what to
change.

For the old `opx77_*` resources, read
[From opx77_* to opx_infinity](../migration/from-opx77.md) instead.

## Decide where your code goes {#where}

| Your code | Put it in |
|---|---|
| Gameplay that needs money, jobs, items, vehicles | a [module](writing-a-module.md) inside `opx_infinity` — the only place the contracts are reachable |
| Something independent that only needs to know who a player is | a [separate resource](writing-a-resource.md) reading the state bag |

## Runtime habits {#runtime}

| FiveM habit | Open77 / OPX//77 |
|---|---|
| Natives such as `GetPlayerPed`, `SetEntityCoords` | Different API. Look up each one with the Open77 devkit (`open77_fivem_equivalent`); never guess a name. |
| `while true do ... Wait(0) end` on the client | Use [`OPX.Scheduler.Every`](../how-it-works/scheduler.md). The client has a per-resume instruction budget; an overrun stops the loop silently. |
| `require` / shared Lua modules on the server | Not available on the server. Shared helpers are in [`lib/`](../reference/lib.md). |
| Metatables / classes in shared code | Not available on the client. Use plain tables. |
| CfxLua syntax (vectors, backtick hashes, `?.`, `+=`) | Plain Lua 5.4 only. |
| `TriggerEvent` to talk to another resource on the client | Does not leave the resource on Open77. |
| `ExecuteCommand` with console authority | Needs `runtime.commands`, and restricted commands are refused. |
| NUI page per resource, `SendNUIMessage` | One shared WebUI page; [`OPX.UI.Send`](../reference/core.md#opx-ui-send) on a named channel. See [The WebUI page](../how-it-works/webui.md). |
| `fxmanifest.lua` | `open77.lua`, a manifest DSL with a `permissions { }` block. List every script on its own line. |
| Server ACE permissions | ACL rights in `acl.jsonc`; a restricted command checks `command.<name>`. See [Permissions](../how-it-works/permissions.md). |
| `oxmysql` | The platform's MySQL bridge (`MySQL`), wrapped by [`OPX.Storage`](../how-it-works/storage.md). |

## ESX / QBCore calls {#framework}

OPX//77's character API is QBCore-shaped (`PlayerData`, `citizenId`,
`Functions`), but it is reached through the `character` contract, server side,
inside `opx_infinity`.

```lua
local character = OPX.Api.Get('character')
local player = character.GetPlayer(source)
```

| ESX / QBCore | OPX//77 (server, inside a module) |
|---|---|
| `QBCore.Functions.GetPlayer(src)` / `ESX.GetPlayerFromId(src)` | [`character.GetPlayer(source)`](../modules/character.md#server-character-getplayer) |
| `Player.PlayerData` | `player.PlayerData` — see [the Player object](../modules/character.md#player) |
| `Player.Functions.AddMoney('bank', n, reason)` / `xPlayer.addAccountMoney` | [`character.AddMoney(source, 'BANK', n, reason)`](../modules/character.md#server-character-addmoney) — answers `ok, code` |
| `Player.Functions.RemoveMoney` | [`character.RemoveMoney`](../modules/character.md#server-character-removemoney) |
| `Player.Functions.SetJob(job, grade)` | [`character.SetJob`](../modules/character.md#server-character-setjob) (yields) |
| `Player.Functions.SetMetaData` | [`character.SetMetadata`](../modules/character.md#server-character-setmetadata) |
| `QBCore.Functions.GetPlayers()` | [`character.GetPlayers()`](../modules/character.md#server-character-getplayers) |
| `exports['qb-inventory']:AddItem` / `xPlayer.addInventoryItem` | the [inventory contract](../modules/inventory.md#server-contract) |
| `QBCore.Functions.Notify` / `ESX.ShowNotification` | [`OPX.Notify`](../reference/core.md#opx-notify) (server) or [`OPX.Toast.Show`](../reference/core.md#opx-toast-show) (client) |
| `QBCore.Functions.CreateCallback` | a network event pair, or [`OPX.UI.Serve`](../reference/core.md#opx-ui-serve) for the page; on the client, [`Lib.Callback`](../reference/opx-lib.md) in opx_lib |
| `qb-menu` / `esx_menu_default` | the [menu module](../modules/menu.md) |
| `qb-input` / `esx_dialog` | the [form module](../modules/form.md) |
| `qb-target` / `ox_target` | the [target module](../modules/target.md) |
| `qb-garages` | the [garages module](../modules/garages.md) |
| money hooks / `onMoneyChange` | [`OPX.Hooks`](../modules/character.md#hooks) `money:beforeAdd` and friends |

Money types are upper case (`EDDIES`, `BANK`), from
[`MONEY.TYPES`](../reference/core-config.md#config-shared-money).

## A short checklist {#checklist}

1. Move the code into a module folder, or decide it stays a separate resource.
2. Replace every native using the devkit.
3. Replace client loops with scheduler jobs.
4. Replace framework calls with contract calls (table above).
5. Re-check every network payload on the server.
6. Move text into `locales.lua` (English and French).
7. List every file in `open77.lua`; add the permissions your natives need.
8. Run `lua tests/run.lua`.
