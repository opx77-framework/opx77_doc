---
title: vehiclekeys module
description: Vehicle keys as inventory items, and the host lock a key turns.
---

# vehiclekeys

`vehiclekeys` makes a car key an inventory item. Each key is one `vehicle_key` item whose metadata names the plate it opens. A player holding the key can lock or unlock that car from the target eye (*Lock / unlock*) or by using the key from their bag, standing within 6 m or sitting in it. Keys are cut automatically when a car is bought or brought out of a garage, and staff can cut one for any vehicle. A locked car cannot be entered and its trunk will not open.

| | |
|---|---|
| Side | both |
| Requires | — |
| Optional | `vehicles`, `inventory`, `target` |
| Configuration | none (constants in `modules/vehiclekeys/module.lua`) |
| Contract | `vehiclekeys` v1 — server |
| Data | none of its own; keys are `vehicle_key` items in [`inventory`](inventory.md) |

Without `inventory` (or an inventory without `CountWhere`) no key is ever cut and no lock can be turned. Without `vehicles` every vehicle gets a minted plate. Without `target` there is no row, but a key still works from the bag.

## How keys work

- **The item.** `vehicle_key`: weight 20, category `tool`, does not stack, using it consumes nothing. Metadata `{ plate, label }`, where `label` is `<model> · <plate>` (for example `Villefort Cortes · 12ABC345`), or the plate alone. Only the server writes it.
- **The plate is the identity.** An owned vehicle uses its real plate. A vehicle `vehicles` never registered (a staff spawn, a showroom car, another resource's car) gets a minted plate, `TMP-` plus six characters, the first time a key is cut for it. A minted plate is held in memory only and is forgotten when the host removes the vehicle; its keys then open nothing. Plates are matched exactly as written, byte for byte: nothing is upper-cased or trimmed, so a legacy plate such as `ABC 123` keeps its space.
- **Who gets a key.**
    - The buyer, on every [dealership](dealership.md) sale.
    - The owner, when a [garage](garages.md) brings the car out **and their bag holds no key to that plate**.
    - The player a staff spawn was made for, and a staff member using `/opx.admin.vehicle.key` (see [admin](admin.md)).
    - A full bag is told to the player (`vehiclekeys.noRoom`) and never refuses the sale or the take-out.
- **What a key does.** It flips the host's replicated entry lock (`Open77.vehicles.setLocked`). The server checks: the vehicle exists, the player sits in it or stands within 6 m in the same bucket, and their **bag** holds a key whose plate is that vehicle's. A trunk or glovebox key does not count. On success the horn chirps and a toast says locked or unlocked. A locked vehicle's trunk is refused by the inventory module.

## Server contract {#server-contract}

`local keys = OPX.Api.Get('vehiclekeys')` on the server, from code inside opx_infinity. Functions that read the bag may yield: call them from a thread.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-vehiclekeys-identity"></a>`Identity` | `vehicleId` | Result `{ok, value = {plate, record, owned, label, owner?}}` | The vehicle's plate; mints a `TMP-` plate when it has none. `owned` is true for a `vehicles` plate (`owner` = citizen id). |
| <a id="server-vehiclekeys-count"></a>`Count` | `target, plate` | integer | Keys to that plate in the bag of `target` (source or citizen id). `0` without inventory. |
| <a id="server-vehiclekeys-give"></a>`Give` | `target, plate, model?` | Result `{ok, value = {plate, label}}` | Always adds one key. `model` is a label or a TweakDB record, used for the key label. |
| <a id="server-vehiclekeys-givefor"></a>`GiveFor` | `target, vehicleId, model?` | Result `{ok, value = {plate, label}}` | Resolves the plate from the live vehicle (`Identity`), then `Give`. |
| <a id="server-vehiclekeys-ensure"></a>`Ensure` | `target, plate, model?` | Result `{ok, value = {given, plate, label}}` | Adds a key only when the bag holds none; `given` says whether one was added. |
| <a id="server-vehiclekeys-revoke"></a>`Revoke` | `target, plate` | Result `{ok, value = {plate, removed}}` | **Yields** for an offline bag. Takes every key to that plate out of one bag, whatever its label. Keys in stashes or trunks are not touched. Needs the inventory's `RemoveWhere` (else `vehiclekeys.unavailable`). |
| <a id="server-vehiclekeys-revokeall"></a>`RevokeAll` | `plate` | Result `{ok, value = {plate, removed, holders}}` | `Revoke` on the bag of every **loaded** character; offline bags are not walked. To re-key a car for good, change its plate. Audited `vehiclekeys.revokeAll`. |
| <a id="server-vehiclekeys-toggle"></a>`Toggle` | `source, vehicleId` | Result `{ok, value = {locked, label}}` | Locks or unlocks for a player who holds the key and is in reach. `locked` is the new state. Does not mint a plate. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-vehiclekeys-toggle"></a>`opx:net:vehiclekeys:toggle` | client → server | `{ vehicleId }` | Lock or unlock the vehicle the eye landed on. `vehicleId` is a decimal string; every other field is ignored. 1 s cooldown per player. Answered with a toast. |

The target row is `vehiclekeys.toggle` (*Lock / unlock*), on vehicles, 6 m, shown only when the bag holds at least one key; its checkbox shows the replicated lock state.

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `vehiclekeys.noVehicle` | No live vehicle with that id, or the used key has no plate. |
| `vehiclekeys.notOut` | The vehicle the used key opens is not in the world. |
| `vehiclekeys.tooFar` | Not seated in it and further than 6 m, or in another bucket. |
| `vehiclekeys.noKey` | No key to that vehicle in the bag. |
| `vehiclekeys.lockRefused` | The host refused the lock change, cannot read the lock, or the lock native raised. |
| `vehiclekeys.noRoom` | The bag is full or too heavy for the key (detail: the key label). |
| `vehiclekeys.unavailable` | No inventory, or the item could not be added for another reason. |
| `vehiclekeys.tooFast` | Toggle cooldown (toast only). |
| `error.badRequest` | The plate is not a valid plate: 1–16 printable ASCII characters, not only blanks. |

Each code is also a locale key (English and French).
