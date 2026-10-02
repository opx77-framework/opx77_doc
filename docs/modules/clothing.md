---
title: clothing module
description: Clothing stores, a marker a player stands on to open the appearance module's fitting room.
---

# clothing

The `clothing` module places clothing stores in the world. A store is a marker: the player stands on it, presses **E**, and the `appearance` module's fitting room opens with the game's whole clothing catalogue for their body. This module owns the place and the door only. It has no catalogue of its own, moves no money and creates nothing. The server checks the player is really at a store before the room's save is allowed. It ships with no stores; operators capture them in game with `/opx.clothing.add`.

| | |
|---|---|
| Side | both |
| Optional | `appearance` (the fitting room), `prompts` (the key hint row) |
| Configuration | `config/clothing.lua` (shared script) |
| Contract | `clothing` v1 — server, client |
| Data | `opx77_clothing` (captured stores) |

Without `appearance`, the markers still draw and the key answers `clothing.noWardrobe`. Without `prompts`, only the hint row is missing.

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-clothing-add"></a>`/opx.clothing.add` | ACL `command.opx.clothing.add` | `[key] [label]` | Captures a store where the caller stands (position and routing bucket read by the server). `key` is 1–48 characters; without one a free `storeN` is chosen. `label` defaults to the key, cut at 64 characters. The same key again moves the store. Prints the line to copy into `SPOTS`. |
| <a id="opx-clothing-remove"></a>`/opx.clothing.remove` | ACL `command.opx.clothing.remove` | `<key>` | Deletes a captured store. A store from `SPOTS` is refused: edit the config instead. |
| <a id="opx-clothing-list"></a>`/opx.clothing.list` | ACL `command.opx.clothing.list` | none | Lists every store: key, label, position, bucket, and `config` or `captured`. |

The command names come from `COMMANDS` in the config.

## Server contract {#server-contract}

`local clothing = OPX.Api.Get('clothing')` on the server, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-clothing-spots"></a>`Spots` | none | table `key → store` | The live merged list (config and captured). Each store has `key, label, x, y, z, bucket`. Read only: it is the module's own table, not a copy. |
| <a id="server-clothing-state"></a>`State` | none | Result `{ok, value = {stores = {[key] = {label, bucket, captured}}}}` | `captured` is true for a store from the database. |

## Client contract {#client-contract}

`local clothing = OPX.Api.Get('clothing')` on the client, from code inside opx_infinity. Every function answers a Result.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-clothing-state"></a>`State` | none | `{spots, markers, nearest, shown, key}` | Counts of stores and drawn markers, the key of the store underfoot, whether the hint row is up, and the key label. |
| <a id="client-clothing-nearest"></a>`Nearest` | none | `{key, label}` | The store the player stands on. Error `clothing.noSuchStore`. |
| <a id="client-clothing-spots"></a>`Spots` | none | `{spots = {[key] = store}}` | The stores this client was sent (its own routing bucket). |
| <a id="client-clothing-open"></a>`Open` | `origin?` | the verdict table | Same as pressing the key: tells the server, then opens the fitting room. `origin` is echoed as `source` on the decision. Error: a locale key such as `clothing.noSuchStore`, `clothing.noWardrobe`, `clothing.wardrobeRefused`, `error.noPermission`. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-clothing-ask"></a>`opx:net:clothing:ask` | client → server | none | Send me the stores of my routing bucket. Asked at start and every `POLL_MS`. |
| <a id="opx-net-clothing-sync"></a>`opx:net:clothing:sync` | server → client | `{spots = { {key, label, x, y, z, bucket}, … }}` | The stores of the player's bucket. Also sent to everyone after a capture or removal. |
| <a id="opx-net-clothing-open"></a>`opx:net:clothing:open` | client → server | none | The key was pressed. The server measures the player's distance to a store in their bucket (`USE_RADIUS`) and, if they are on one, calls `appearance.AllowClothingSave`. Nothing is sent back. Cooldown 1 s. |
| <a id="opx-on-clothing-decision"></a>`opx:on:clothing:decision` | client, local | `{source, ok, error?, reason?, store?, citizenId?}` | Raised after every key press or `Open` call. `error` is a locale key; `reason` is the fitting room's own refusal (e.g. `player_down`, `no_character`, `appearance_busy`). |

## Configuration {#configuration}

`config/clothing.lua` sets `OPX.Config.MODULES.clothing`. Shared script. `enabled = false` switches the module off.

| Key | Default | What it does |
|---|---|---|
| <a id="config-clothing-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-clothing-use-radius"></a>`USE_RADIUS` | `4.0` | Flat distance in metres from the store's X and Y within which it can be used. Checked on both sides. |
| <a id="config-clothing-marker"></a>`MARKER` | `{ shape = 'cylinder', style = 'interaction', RADIUS = 2.5 }` | Marker look. Shapes: `ring`, `cylinder`. Styles: `interaction`, `objective`, `spawn`, `danger`. `RADIUS` 0.1–50. |
| <a id="config-clothing-max-distance"></a>`MAX_DISTANCE` | `150.0` | Distance in metres beyond which a marker is not drawn (1–500). |
| <a id="config-clothing-ground-offset"></a>`GROUND_OFFSET` | `0.06` | Metres the marker is lifted off Z (0–2). A ring at floor height does not draw. |
| <a id="config-clothing-scan-ms"></a>`SCAN_MS` | `500` | Marker and position scan interval. |
| <a id="config-clothing-poll-ms"></a>`POLL_MS` | `15000` | How often the client asks for the store list again, so a bucket change is picked up. |
| <a id="config-clothing-key"></a>`KEY` | `{ ID = 'opx.clothing.use', NAME = 'clothing.key.use', DEFAULT = 'E' }` | The rebindable key. `ID` stores the player's rebind; `NAME` is the label's locale key. `DEFAULT = false` registers no key. |
| <a id="config-clothing-commands"></a>`COMMANDS` | `{ add = 'opx.clothing.add', remove = 'opx.clothing.remove', list = 'opx.clothing.list' }` | Command names. All three are restricted. |
| <a id="config-clothing-spots"></a>`SPOTS` | `{}` | Stores from config: `key = { LABEL, X, Y, Z, BUCKET }`. Captured stores with the same key override them. |

Example `SPOTS` entry, as `/opx.clothing.add` prints it:

```lua
SPOTS = {
  store_example = { LABEL = "JINGUJI", X = -1771.79, Y = -77.30, Z = 7.53, BUCKET = 0 },
},
```

Bad values (non-positive `USE_RADIUS`, `SCAN_MS`, `POLL_MS`, an invalid marker, store or `KEY`) are logged as `[clothing] config:` warnings at start.

## Refusal codes {#codes}

Shown to the player as a toast. The text is the locale key.

| Code | Meaning |
|---|---|
| `clothing.noSuchStore` | The player is not on a store. |
| `clothing.noWardrobe` | The `appearance` contract is not running. |
| `clothing.wardrobeRefused` | The fitting room refused; `{reason}` is its code. |
| `error.noPermission` | Another surface holds the keyboard. |
| `clothing.noPosition` | `/opx.clothing.add`: the caller's position could not be read. |
| `clothing.captureFailed` | `/opx.clothing.add`: the store was invalid or could not be saved. |
