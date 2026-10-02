---
title: garages module
description: Garage markers where a player brings out one of their own vehicles or puts the one they sit in away.
---

# garages

`garages` draws glowing markers where players fetch and park their own vehicles. On foot at a **menu point**, the key (**E** by default) opens the list of every vehicle filed under that garage. Sitting in one of your own vehicles at the **entry point**, the same key puts it away. A vehicle comes out at the first free **exit** of the location you stand at. Garages are written in `config/garages.lua`; nothing is placed in game.

| | |
|---|---|
| Side | both |
| Requires | `character` (hard) |
| Optional | `vehicles`, `prompts`, `downed`, `menu`, `vehiclekeys` |
| Configuration | `config/garages.lua` (shared script) |
| Contract | `garages` v1 — server, client |
| Data | `opx77_garages` (legacy, read-only) |

Without `vehicles` every request is refused. Without `menu` the list cannot open but `/opx.garages.bring` still works. Without `prompts` the markers still draw, only the key row is missing. With [`vehiclekeys`](vehiclekeys.md), the owner is given a key on the way out when their bag holds none to that plate; a full bag is said to the player and does not stop the car coming out.

## How a garage works

- A **garage** is a key (for example `garage1`). A vehicle's `garage` column holds that key, so a car stored at one location comes out at every location of the same garage.
- Each **location** has one `MENU` point (opens the list), one `ENTRY` point (takes the car you sit in), and an ordered list of `EXITS`.
- **Exits** are tried in the order written. An exit counts as taken when any vehicle in the same routing bucket is within `EXIT_CLEARANCE` metres of it (the car being fetched never blocks its own exit). When all exits are taken the request is refused with `garages.noFreeExit`.
- **Put away or bring out** is decided by the server from the host's seat assignment, never by the client.
- A car of yours that is already out elsewhere is **moved** to the exit (see [`vehicles.Spawn`](vehicles.md#server-vehicles-spawn)). It is refused with `vehicle.occupied` if anyone sits in it.
- `KIND = 'garage'` brings out ground vehicles only; `KIND = 'avpad'` brings out AVs only. An AV is created `AV_LIFT` metres above the exit. Which records are AVs is `AV_PREFIXES` in `config/shared.lua`.

### Legacy table `opx77_garages`

The old `/opx.garages.add` and `/opx.garages.remove` commands are gone. At every boot the server reads `opx77_garages` and adopts each row whose key is **not** in `GARAGES`, as a garage of one location whose menu, entry and only exit are the captured point. It prints each adopted garage to the server log as `[garages] config line: ...` lines, ready to paste into `config/garages.lua`, then warns how many exist only in the table. A config garage with the same key wins. Nothing writes to or drops the table.

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-garages-list"></a>`/opx.garages.list` | ACL `command.opx.garages.list` | — | Lists every garage: kind, label, each location's points, exit count, bucket, and whether it came from config or the legacy table. |
| <a id="opx-garages-bring"></a>`/opx.garages.bring` | ACL `command.opx.garages.bring` | `[garage] [plate]` | Brings one of the caller's own vehicles out at the garage they stand at. `garage` is a garage key (nearest point of it) or omitted (nearest point). `plate` is one of yours; omitted picks the first eligible one. Same distance and bucket checks as the marker. |

`command.opx.garages.*` grants both. Command names come from `COMMANDS` in the config.

## Server contract {#server-contract}

`local garages = OPX.Api.Get('garages')` on the server, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-garages-bring"></a>`Bring` | `source, key?, plate?` | Result `{ok, value = {spot, garage, label, exit, plate, id, recalled?}}` | Yields. Brings out at a free exit of the location the player stands at. `key` is a point key or garage key; nil means the nearest point. Without `plate`, a car filed at this garage is preferred, then any eligible one, ties broken by plate. Also cuts a key through `vehiclekeys.Ensure` on a separate thread. |
| <a id="server-garages-use"></a>`Use` | `source, key?, plate?` | Result: `{spot, garage, label, plate, stored = true}` or the `Bring` value | Yields. What the marker key does: puts away the owned car the player sits in, filed under this garage; otherwise `Bring`. |
| <a id="server-garages-list"></a>`List` | `source, key?` | Result `{ok, value = {spot, garage, label, kind, vehicles}}` | Yields. `vehicles` = `{plate, record, here}[]`, every eligible vehicle of the player; `here` is true when filed at this garage. |
| <a id="server-garages-spots"></a>`Spots` | — | table | Not a Result. Every drawn point by point key (`<garage>#<n>` for a menu, `<garage>#<n>.in` for an entry). |
| <a id="server-garages-garages"></a>`Garages` | — | table | Not a Result. Every garage by key: `{key, label, kind, locations = {index, bucket, menu, entry, exits}[]}`. |
| <a id="server-garages-state"></a>`State` | — | Result `{ok, value = {garages}}` | `garages[key] = {kind, label, locations (count), adopted}`. |

## Client contract {#client-contract}

`local garages = OPX.Api.Get('garages')` on the client, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-garages-bring"></a>`Bring` | `origin?` | Result `{ok, value = verdict}` | Same as pressing the key on the point underfoot: opens the list at a menu point, sends a request at an entry point. `origin` is copied into the verdict's `source`. The real answer arrives later on `opx:on:garages:decision`. |
| <a id="client-garages-nearest"></a>`Nearest` | — | Result `{key, label, kind}` | `garages.noSuchSpot` when not standing on a point. |
| <a id="client-garages-spots"></a>`Spots` | — | Result `{spots}` | Points this client was sent (its own bucket only). |
| <a id="client-garages-garages"></a>`Garages` | — | Result `{garages}` | `garages[key] = {key, label, kind}`, derived from the points. |
| <a id="client-garages-state"></a>`State` | — | Result | Diagnostic: counts, nearest point, its role, whether the row is shown, open list, key label. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-garages-ask"></a>`opx:net:garages:ask` | client → server | — | Ask for the points of the caller's bucket. Sent at start and every `POLL_MS`. |
| <a id="opx-net-garages-sync"></a>`opx:net:garages:sync` | server → client | `{ spots }` | The points of the player's bucket. Each: `key, label, kind, x, y, z, heading, bucket, garage, role, location`. |
| <a id="opx-net-garages-list"></a>`opx:net:garages:list` | client → server | `key` | Ask for the list behind a menu point. Counts against the request window. |
| <a id="opx-net-garages-vehicles"></a>`opx:net:garages:vehicles` | server → client | `{ spot, garage, label, kind, vehicles }` or `{ spot, error }` | The list for a menu point (same shape as server `List`). |
| <a id="opx-net-garages-request"></a>`opx:net:garages:request` | client → server | `key, plate?` | Press the key at an entry point, or pick a row in the list. Runs `Use`. Cooldown `COOLDOWN_MS` plus the request window. |
| <a id="opx-net-garages-answer"></a>`opx:net:garages:answer` | server → client | `key, ok, error?, plate?, action?` | The verdict. `action` is `brought`, `recalled` or `stored`. |
| <a id="opx-on-garages-decision"></a>`opx:on:garages:decision` | client local | `{ ok, error?, spot?, plate?, action?, queued?, closed?, source }` | Every verdict, local refusals included. `source` is `key`, `menu`, `server`, `client` or the caller's `origin`. Only handlers inside opx_infinity's client hear it. |

## Configuration {#configuration}

`config/garages.lua` sets `OPX.Config.MODULES.garages`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-garages-enabled"></a>`enabled` | `true` | `false` switches the module off. |
| <a id="config-garages-use-radius"></a>`USE_RADIUS` | `4.0` | Flat metres from a point's X/Y within which it can be used. |
| <a id="config-garages-exit-clearance"></a>`EXIT_CLEARANCE` | `3.0` | Flat metres around an exit that must be free of vehicles. |
| <a id="config-garages-marker"></a>`MARKER` | `garage = cylinder/spawn/2.5`, `avpad = ring/objective/3.5`, `entry = ring/interaction/3.0` | Marker look per kind (menu points) and for entry points. Each `{ shape, style, RADIUS }`. |
| <a id="config-garages-max-distance"></a>`MAX_DISTANCE` | `150.0` | Metres beyond which a marker is not drawn (1–500). |
| <a id="config-garages-ground-offset"></a>`GROUND_OFFSET` | `0.06` | Metres the marker is lifted off Z (0–2). A ring at exact floor height is invisible. |
| <a id="config-garages-av-lift"></a>`AV_LIFT` | `1.2` | Metres above the exit an AV is created (0–10). |
| <a id="config-garages-scan-ms"></a>`SCAN_MS` | `500` | Client marker scan interval. |
| <a id="config-garages-poll-ms"></a>`POLL_MS` | `15000` | How often the client re-asks for its points. |
| <a id="config-garages-request-window-ms"></a>`REQUEST_WINDOW_MS` | `10000` | Length of the per-player request window. |
| <a id="config-garages-requests-per-window"></a>`REQUESTS_PER_WINDOW` | `6` | Requests allowed per window (bring-outs and lists together). |
| <a id="config-garages-cooldown-ms"></a>`COOLDOWN_MS` | `3000` | Minimum gap between two bring-outs from one player. |
| <a id="config-garages-key"></a>`KEY` | `{ ID = 'opx.garages.use', NAME = 'garages.key.use', DEFAULT = 'E' }` | The key mapping. `ID` is stable (rebinds are stored under it). `DEFAULT = false` registers no key. |
| <a id="config-garages-menu"></a>`MENU` | `{ ANCHOR = 'center', WIDTH = 560, HEIGHT = 560, MAX_HEIGHT_VH = 88, VISIBLE_ROWS = 12 }` | Size of the list panel. The menu module clamps every value. |
| <a id="config-garages-commands"></a>`COMMANDS` | `{ list = 'opx.garages.list', bring = 'opx.garages.bring' }` | Command names. An empty name registers nothing. |
| <a id="config-garages-garages"></a>`GARAGES` | `garage1`, `garage2` (one location each) | Every garage. See below. |

Markers use the engine vocabulary: shape `ring` or `cylinder`, style `interaction`, `objective`, `spawn` or `danger`, `RADIUS` 0.1–50. A bad field falls back to the module default and is reported at boot.

### A garage entry

```lua
GARAGES = {
    garage1 = {                        -- the key: 1-48 chars, never rename it
        LABEL = 'Watson Garage',       -- shown to players, not translated; defaults to the key
        KIND = 'garage',               -- 'garage' (ground vehicles) or 'avpad' (AVs)
        LOCATIONS = {
            {
                BUCKET = 0,            -- routing bucket of the whole location
                MENU  = { X = -1527.21, Y = -218.56, Z = 7.86 },
                ENTRY = { X = -1527.21, Y = -218.56, Z = 7.86, HEADING = 199.6 },
                EXITS = {
                    { X = -1527.21, Y = -218.56, Z = 7.86, HEADING = 199.6 },
                },
            },
        },
    },
}
```

Every point follows the shared spot rules (see [the spot helpers](../reference/lib.md)): `X`, `Y`, `Z` finite and within ±1,000,000; `HEADING` a finite number (default `0`); `BUCKET` a whole number ≥ 0 (default `0`). Only X and Y are measured against. A garage with any bad point, no location or a location without exits is refused whole, with a boot warning naming it. To capture a point, stand on it facing the way a car should come out and run `/opx.admin.self.pos`; it copies the position and heading to your clipboard.

!!! warning
    Never rename a garage key. Every vehicle filed under the old key is orphaned.

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `garages.noVehicles` | No `vehicles` contract on this server. |
| `garages.noCharacter` | No character loaded. |
| `garages.noPosition` | The player's position could not be read. |
| `garages.noSuchSpot` | No point underfoot, or the named key does not exist. |
| `garages.wrongBucket` | The point is in another routing bucket. |
| `garages.tooFar` | Further than `USE_RADIUS` from the point. |
| `garages.nothingHere` | The player owns nothing of this garage's kind. |
| `vehicle.notFound` | The named plate is not one of the player's eligible vehicles. |
| `garages.noFreeExit` | Every exit of the location is taken. |
| `garages.rateLimited` | Cooldown or request window (bring-outs). |
| `error.tooFast` | Request window (lists). |
| `error.noPermission` | Client side only: another surface holds the keyboard. |

Codes from [`vehicles`](vehicles.md#codes) (`vehicle.occupied`, `vehicle.busy`, `vehicle.spawnRefused`, …) pass through unchanged. Each code is also a locale key.
