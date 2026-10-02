---
title: vehicles module
description: Owned vehicles — the plate registry, bringing a car out, putting it away and keeping its condition across restarts.
---

# vehicles

`vehicles` is the registry of what each character owns. It draws plates, writes the rows, creates a car in the world, puts it away and saves its health, damage and paint every few minutes. Players never talk to it directly: they use a [garage](garages.md) marker or a [dealer](dealership.md), and those modules call this one. Use its contract when your own code needs to give a character a car, list their cars or bring one out.

| | |
|---|---|
| Side | server only (the client half does not exist) |
| Requires | `character` (hard) |
| Configuration | `config/vehicles.lua` (server script — never sent to a client) |
| Contract | `vehicles` v1 — server |
| Data | `opx77_vehicles` |

**The plate is the identity.** A runtime vehicle id belongs to one spawn and is recycled; the plate is the row. Only vehicles this module spawned have a plate: `PlateOf` answers nothing for a car created by anything else.

**Every out vehicle is stored again** when its owner disconnects, when the owner is no longer loaded at the next save pass, when the host removes it, and when the resource stops. A character that is deleted loses all its rows (the character delete is soft, so this module deletes them itself).

## Server contract {#server-contract}

`local vehicles = OPX.Api.Get('vehicles')` on the server, from code inside opx_infinity. Every function that reads the database **yields**: call it from a `CreateThread`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-vehicles-register"></a>`Register` | `citizenId, record, options?` | Result `{ok, value = vehicle}` | Yields. Creates a row under a fresh plate, state stored, in `options.garage` or `DEFAULT_GARAGE`. `options`: `appearance`, `garage`, `paint`, `metadata`. Refuses `vehicle.limit` at `PER_CHARACTER`, `vehicle.badRecord` over 256 characters, `vehicle.plateExhausted` after 5 colliding draws. |
| <a id="server-vehicles-list"></a>`List` | `citizenId` | Result `{ok, value = vehicle[]}` | Yields. Every row the character owns, oldest first. |
| <a id="server-vehicles-get"></a>`Get` | `plate` | Result `{ok, value = vehicle}` | Yields. Adds `spawned` (boolean) and `id` (runtime id when out). `vehicle.notFound` when no row. |
| <a id="server-vehicles-plateof"></a>`PlateOf` | `vehicleId` | `plate, citizenId` or `nil, nil` | No yield. Only vehicles this module has out. |
| <a id="server-vehicles-liveid"></a>`LiveId` | `plate` | runtime id or `nil` | No yield, no database. Says nothing about ownership. |
| <a id="server-vehicles-occupied"></a>`Occupied` | `source` | Result `{ok, value = {plate, id}}` or `{ok, value = nil}` | No yield. The owned vehicle the player sits in, read from the host's seat assignment. `nil` on foot or in a car they do not own. |
| <a id="server-vehicles-spawn"></a>`Spawn` | `source, plate, at?` | Result `{ok, value = {plate, id, recalled?, alreadyOut?}}` | Yields. Ownership is proved from the loaded character. Without `at` the car appears `SPAWN_OFFSET` m beside the player; if it is already out the answer is `alreadyOut = true` and nothing moves. With `at = {x, y, z, yaw?, bucket?}` it is created exactly there; a car already out is stored first and created again at `at` (`recalled = true`), or refused `vehicle.occupied` if anyone sits in it. Stored damage and flags are re-applied. |
| <a id="server-vehicles-store"></a>`Store` | `plate, garage?` | Result `{ok, value = {plate}}` | Yields. Writes condition back and removes the car. `garage` re-files it. No ownership check: the caller must prove it. |
| <a id="server-vehicles-storeall"></a>`StoreAll` | `citizenId?` | integer | Yields. Stores every out vehicle of one character, or of everyone when `nil`. Answers how many. |

A **vehicle** table has `plate`, `citizenId`, `record`, `appearance`, `garage`, `state` (`0` out, `1` stored, `2` impounded), `health`, `damage`, `paint`, `metadata`.

!!! warning
    `Spawn` with a named place moves a car that is already out. That is how a garage marker "recalls" a car parked elsewhere.

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-vehicles-spawn"></a>`opx:net:vehicles:spawn` | client → server | `{ plate }` | Spawn one of the caller's own vehicles beside them. 3 s cooldown per player. Answers with a toast (`vehicle.spawned` or the refusal) and an `OPX.Refuse` under operation `vehicleSpawn`. |
| <a id="opx-net-vehicles-store"></a>`opx:net:vehicles:store` | client → server | `{ plate }` | Put away one of the caller's own vehicles that is out. 3 s cooldown. Operation `vehicleStore`. |

A plate that is not the caller's is answered `vehicle.notFound`, the same as a plate that does not exist.

## Configuration {#configuration}

`config/vehicles.lua` sets `OPX.Config.MODULES.vehicles`. It is a **server script**: no client reads it.

| Key | Default | What it does |
|---|---|---|
| <a id="config-vehicles-enabled"></a>`enabled` | `true` | `false` switches the module off. Garages and dealers then refuse everything. |
| <a id="config-vehicles-per-character"></a>`PER_CHARACTER` | `8` | Most vehicles one character may own. `0` = no limit. |
| <a id="config-vehicles-plate-format"></a>`PLATE_FORMAT` | `'11AAA111'` | `1` draws a digit, `A` a letter, `.` either; anything else is copied. ASCII capitals only (the column is `ascii_bin`, 12 characters wide). |
| <a id="config-vehicles-default-garage"></a>`DEFAULT_GARAGE` | `'impound'` | The garage key a vehicle registered with no garage is filed under. |
| <a id="config-vehicles-spawn-offset"></a>`SPAWN_OFFSET` | `3.0` | Metres beside the player a car appears when no place is named. |
| <a id="config-vehicles-save-seconds"></a>`SAVE_SECONDS` | `120` | How often the condition of every out vehicle is written. Minimum 1 s. |

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `vehicle.notFound` | No such plate, or it is not yours. |
| `vehicle.limit` | The character already owns `PER_CHARACTER` vehicles (detail: the limit). |
| `vehicle.badRecord` | The record is longer than 256 characters. |
| `vehicle.plateExhausted` | Five plate draws all collided. |
| `vehicle.notLoggedIn` | No character loaded on that connection, or it changed during the spawn (the new car is removed). |
| `vehicle.noPosition` | The host would not say where the player is. |
| `vehicle.spawnRefused` | `Open77.vehicles.create` refused; detail carries its reason. |
| `vehicle.notSpawned` | `Store` on a plate that is not out. |
| `vehicle.storeRefused` | The host would not remove the car; it stays out and the row stays `out`. |
| `vehicle.occupied` | A recall was asked but somebody sits in the car. |
| `vehicle.busy` | Another spawn of the same plate is in progress. |
| `error.badRequest` | Missing or wrong-typed argument. |
| `error.tooFast` | The 3 s request cooldown (net events only). |

Each code is also a locale key (English and French) used for the toast.
