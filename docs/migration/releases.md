---
title: Release notes
description: What changed in opx_infinity and opx_lib, newest first, starting with the replacement of the opx77_* resources in September 2026.
---

# Release notes

Newest first. The version is the one in each resource's `open77.lua`.

## opx_infinity — creator API, wardrobe pictures, calls (PRs #50–#52) {#infinity-creator-api}

Merged into `main` after the 2026-10-02 changes below; the manifest version is still `0.1.2`.

| Change | Pages |
|---|---|
| **Creator API.** Other resources can call curated [server exports](../creators/server-exports.md) and [client exports](../creators/client-exports.md) and listen to [public server events](../creators/server-events.md). Who may call is `SERVER.EXPORTS.READ`/`WRITERS` (writers empty by default) and `CLIENT.EXPORTS.CALLERS`. New codes `export.callerDenied`, `export.badArgument`, `export.booting`, `export.mustAwait`. New core function `OPX.Publish`. | [For creators](../creators/index.md), [core config](../reference/core-config.md#config-server-exports) |
| New contract functions: `character.AddMoneyOffline`, `character.PublicView`; inventory `AddToStash`, `RemoveFromStash`, `CountInStash`, `RemoveWhere` (codes `stash_namespace`, `stash_cap`); chat server contract `Send`, `Broadcast`; `vehiclekeys.Revoke`, `RevokeAll`; `vehicles.SetState` (codes `vehicle.impounded`, `vehicle.busy`, `vehicle.badState`). | [character](../modules/character.md), [inventory](../modules/inventory.md), [chat](../modules/chat.md), [vehiclekeys](../modules/vehiclekeys.md), [vehicles](../modules/vehicles.md) |
| New hooks `job:beforeSet`, `gang:beforeSet` (codes `job.vetoed`, `gang.vetoed`) and `money:beforeAddOffline`. The internal job and gang events are now also raised when a membership is removed. | [character](../modules/character.md#hooks) |
| Calls: a *Cancel* button and the `opx:net:calls:withdraw` event take back an outgoing call without touching a live one; leaving a call withdraws a pending join invite. The unused dismiss/repop card and `CARD_DWELL_S` are gone. | [calls](../modules/calls.md) |
| Fitting room: garment names and pictures (`garments-*.lua`, `web/images/clothing/`, `tools/generate-garments.mjs`); the panel `tiles` spec gains optional `labels` and `images`; categories read *Top*, *Jacket*, *Pants*, *Shoes*. | [appearance](../modules/appearance.md#garments), [panel](../modules/panel.md) |

## opx_infinity — main after 0.1.2 (2026-10-02) {#infinity-main-2026-10-02}

Merged into `main`; the manifest version is still `0.1.2`.

| Change | Pages |
|---|---|
| New module **vehiclekeys**: keys are inventory items (`vehicle_key`, metadata `plate`, `label`) that lock and unlock a vehicle from the target eye. Garages' bring-out and dealership purchases hand out a key; staff get `/opx.admin.vehicle.key`. | [vehiclekeys](../modules/vehiclekeys.md), [garages](../modules/garages.md), [dealership](../modules/dealership.md), [admin](../modules/admin.md) |
| Inventory contract: `CountWhere`, `TrunkLocked`, `AddToTrunk`, `RemoveFromTrunk`, `CountInTrunk`; new refusal codes `locked` and `hands_full`. | [inventory](../modules/inventory.md) |
| Hauling reworked into a crate job sold to drop-off NPCs (new `IsCarrying`, `DROP` and `SELLERS` events, `hauling_crate` item, per-site models and NPCs). The `HAUL_PAY_PER_CRATE` tunable is now applied. New manifest permission `world.npcs`. | [hauling](../modules/hauling.md) |
| Hauling: an unpaid sale puts crates back anywhere they fit, and records the rest for a refund (`not_paid_lost`, audit event `hauling.crateLost`); load and sell also check the routing bucket (`wrong_bucket`). Vehicle keys accept any printable ASCII plate of 1–16 characters, matched exactly, and a raising lock native answers `lockRefused`. | [hauling](../modules/hauling.md#codes), [vehiclekeys](../modules/vehiclekeys.md#codes) |
| HUD: contract `ApplyVanilla`; the shipped config hides every vanilla HUD component except the minimap. | [hud](../modules/hud.md) |
| Calls: one call screen (the holo); hanging up also withdraws an outgoing call that was not answered yet. | [calls](../modules/calls.md) |

## opx_infinity 0.1.2 (September 2026) {#infinity-0-1-2}

The first release of the single resource. It replaces twenty-one `opx77_*`
resources (sixteen of them were documented on this site).

| Change | Read |
|---|---|
| One resource, `opx_infinity`, with a core runtime and modules under `modules/<id>/`. | [Overview](../how-it-works/overview.md) |
| Modules talk through in-process contracts (`OPX.Api`); **no Open77 exports** are published. | [Modules and contracts](../how-it-works/modules-and-contracts.md) |
| Event names moved to `opx:net:`, `opx:on:`, `opx:in:`. | [Events and channels](../how-it-works/events.md) |
| Commands moved from `opx77.*` to `opx.*`, with optional short aliases. | [Core configuration](../reference/core-config.md#config-server-command-aliases) |
| One WebUI page for every screen. | [The WebUI page](../how-it-works/webui.md) |
| Garages, dealers and showroom cars are written in config; legacy tables are adopted at boot. | [garages](../modules/garages.md), [dealership](../modules/dealership.md) |
| Modules that had no page on the old site: spawn, entry, theme, diagnostics, downed, target, progress, panel, calls, blips, shops, crafting, gunsmith, hauling, teleports, garages, dealership, clothing, vehicles. | [Modules](../modules/index.md) |

## opx_lib 0.4.0 (September 2026) {#lib-0-4-0}

The client library `opx_infinity` depends on. Delivered as `files`, loaded with
`require('@opx_lib')`, client only. See [opx_lib](../reference/opx-lib.md).
