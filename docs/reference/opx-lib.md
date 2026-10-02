---
title: opx_lib
description: The separate opx_lib resource — a client-only Lua library any resource can require — how to load it, the permissions each module needs, and every function of every module.
---

# opx_lib

`opx_lib` is a separate resource: a Lua library that any **client** script can load with `require('@opx_lib')`. It wraps Open77 natives in calls that answer a Result instead of raising (markers, blips, key bindings, cameras, screen fades, callbacks, raycasts), and adds pure helpers for text, numbers, tables, colours and translations. Use it in your own resource. `opx_infinity` also loads it once on its client and exposes it as [`OPX.Lib`](lib.md#opx-lib). It is version `0.4.0` (`Lib.VERSION`).

## Using it {#using}

In your resource's `open77.lua`:

```lua
dependency "opx_lib"
permissions { "world.markers", "input.actions" }  -- only what you use, see below
```

In a client script:

```lua
local Lib = require('@opx_lib')
local name = Lib.Validate.Word(payload.name, 24)
Lib.Notify.Show('Welcome, ' .. name)
```

| Fact | Detail |
|---|---|
| Client only | The server sandbox has no `require`, so no server script can load it. To use a `pure/` helper on the server, copy the file. |
| Runs in your VM | The code runs inside the resource that calls `require`. Your permissions, your instruction budget, and every marker, blip, key mapping or callback it creates belongs to you. |
| Permissions | `opx_lib` declares none, because a permission is checked against the calling resource. You declare what you use. A missing one comes back as `error = 'permission_denied'` with a `detail` naming the line to add. |
| Per resource | Each resource that requires it gets its own copy of every table. `Lib.Locale`'s catalogue is yours alone. |
| Without `dependency "opx_lib"` | `require` answers `nil, 'module_dependency_not_declared'`. |
| Server side | The resource's own server script only logs that it is present. |

## Manifest helpers {#manifest}

| Name | Returns | Notes |
|---|---|---|
| <a id="lib-version"></a>`Lib.VERSION` | `string` | The library version. |
| <a id="lib-needs"></a>`Lib.NEEDS` | `table<module, permission>` | Each module's `NEEDS`, read off the modules. |
| <a id="lib-manifest"></a>`Lib.Manifest()` | `string\|nil` | The `permissions { ... }` line that covers every module, or `nil`. Print it at start-up to check yours. |

### Permission per module {#needs}

| Module | Permission you declare |
|---|---|
| `Notify` | `ui.vanilla.hud` |
| `Input` | `input.actions` |
| `Marker` | `world.markers` (not for `Shapes`) |
| `Callback` | `network.events` |
| `World` | `world.query` |
| `Blip` | `ui.vanilla.map` |
| `Camera` | `camera.script` (not for `Ray`, `Owner`) |
| `Screen` | `screen.effects` |
| every other module | none |

## Results {#results}

Almost every wrapper answers a Result: `{ ok = true, value = v }` or `{ ok = false, error = code, detail = text }`. Common codes from any wrapper: `open77_unavailable`, `native_not_found` (older build), `native_raised`, `permission_denied`, or the native's own refusal string. Validation codes (`invalid_*`) are named per function below. Functions marked **yields** must run inside `CreateThread`.

## Pure modules {#pure}

No natives and no permission. Same behaviour on any runtime.

### Result {#result}

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-result-ok"></a>`Lib.Result.Ok` | `value?` | `{ ok = true, value }` | |
| <a id="lib-result-err"></a>`Lib.Result.Err` | `code, detail?` | `{ ok = false, error, detail }` | |
| <a id="lib-result-is"></a>`Lib.Result.Is` | `value` | `boolean` | A table with a boolean `ok`. |
| <a id="lib-result-or"></a>`Lib.Result.Or` | `result, fallback?` | `any` | The value of a success, else `fallback`. |
| <a id="lib-result-map"></a>`Lib.Result.Map` | `result, fn` | Result | Applies `fn` to a success. Codes: `not-a-result`, `not-a-function`, `map-raised`. |

### Validate {#validate}

Each answers the value, or `nil`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-validate-number"></a>`Lib.Validate.Number` | `value, low?, high?` | `number\|nil` | Finite, within the bounds. |
| <a id="lib-validate-integer"></a>`Lib.Validate.Integer` | `value, low?, high?` | `integer\|nil` | Whole number within the bounds. |
| <a id="lib-validate-text"></a>`Lib.Validate.Text` | `value, limit?` | `string\|nil` | Non-empty string of at most `limit` **bytes**. Not trimmed. |
| <a id="lib-validate-word"></a>`Lib.Validate.Word` | `value, limit?` | `string\|nil` | Letters, digits, `_ - .` only; `limit` default 64 bytes. |
| <a id="lib-validate-oneof"></a>`Lib.Validate.OneOf` | `value, allowed` | `any\|nil` | `allowed` may be a set (`{ a = true }`) or a list. |
| <a id="lib-validate-table"></a>`Lib.Validate.Table` | `value, limit?` | `table\|nil` | A table with no metatable and at most `limit` entries. |

### Table {#table}

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-table-copy"></a>`Lib.Table.Copy` | `value, seen?` | copy | Deep copy. |
| <a id="lib-table-same"></a>`Lib.Table.Same` | `left, right` | `boolean` | Same data, to any depth. |
| <a id="lib-table-keys"></a>`Lib.Table.Keys` | `value` | `any[]` | Every key, sorted. |
| <a id="lib-table-count"></a>`Lib.Table.Count` | `value` | `integer` | All keys. |
| <a id="lib-table-freeze"></a>`Lib.Table.Freeze` | `value` | `table` | Shallow read-only view; writing raises. |

### String {#string}

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-string-trim"></a>`Lib.String.Trim` | `value` | `string` | |
| <a id="lib-string-clean"></a>`Lib.String.Clean` | `value, limit?, ellipsis?` | `string` | Control characters replaced, capped, `ellipsis` when cut. |
| <a id="lib-string-split"></a>`Lib.String.Split` | `value, separator` | `string[]` | One-character separator; empty fields kept. |
| <a id="lib-string-starts"></a>`Lib.String.Starts` | `value, prefix` | `boolean` | |
| <a id="lib-string-signature"></a>`Lib.String.Signature` | `value` | `integer` | Short stable hash, for change detection. Not for security. |

### Math {#math}

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-math-clamp"></a>`Lib.Math.Clamp` | `value, low, high` | `number` | |
| <a id="lib-math-round"></a>`Lib.Math.Round` | `value, places?` | `number` | Half away from zero; `places` default 0. |
| <a id="lib-math-lerp"></a>`Lib.Math.Lerp` | `from, to, amount` | `number` | `amount` 0..1. |
| <a id="lib-math-distance"></a>`Lib.Math.Distance` | `left, right` — `{ x, y, z }` | `number\|nil` | |
| <a id="lib-math-distance2d"></a>`Lib.Math.Distance2D` | `left, right` | `number\|nil` | Ignores height. |
| <a id="lib-math-near"></a>`Lib.Math.Near` | `left, right, radius` | `boolean` | Within `radius`, ignoring height. |

### Class {#class}

`Lib.Class(name, parent?)` returns a class table. Call the class to make an instance (`init(self, ...)` runs if defined); `Class.Holds(value)` tests whether a value is an instance of it or of a subclass. It uses metatables, so an instance does not survive being passed through an export.

### Locale {#locale}

A per-resource translation catalogue. Formatting uses `string.format` (`%s`, `%d`), not `{name}` placeholders. A missing key answers the key itself; a format that fails answers the key.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-locale-load"></a>`Lib.Locale.Load` | `catalogue` — `table<key, string>` | `integer` accepted | Replaces the catalogue. Non-string values are refused. |
| <a id="lib-locale-set"></a>`Lib.Locale.Set` | `key, value` | `boolean` | Adds or replaces one entry. |
| <a id="lib-locale-get"></a>`Lib.Locale.Get` | `key, ...` | `string` | Never `nil`. |
| <a id="lib-locale-has"></a>`Lib.Locale.Has` | `key` | `boolean` | |

### Text {#text}

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-text-span"></a>`Lib.Text.Span` | `text, maximum` | `integer` | Byte length of the first `maximum` characters. |
| <a id="lib-text-length"></a>`Lib.Text.Length` | `value` | `integer` | Characters. |
| <a id="lib-text-clean"></a>`Lib.Text.Clean` | `value, maximum, ellipsis?` | `string\|nil` | Control characters replaced, cut to `maximum` characters. |
| <a id="lib-text-bytes"></a>`Lib.Text.Bytes` | `text, limit` | `string` | Cut to `limit` bytes on a character boundary. |
| <a id="lib-text-slug"></a>`Lib.Text.Slug` | `value, limit?` | `string\|nil` | Lower-cased letters, digits, `_`, `-`; `limit` default 64 bytes. |
| <a id="lib-text-rest"></a>`Lib.Text.Rest` | `words, first?` | `string` | Joins words from `first` (default 1). |
| <a id="lib-text-switch"></a>`Lib.Text.Switch` | `value` | `boolean\|nil` | on/off and synonyms; `nil` for anything else. |

### Array {#array}

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-array-filter"></a>`Lib.Array.Filter` | `list, test(value, index)` | `table` | |
| <a id="lib-array-map"></a>`Lib.Array.Map` | `list, change(value, index)` | `table` | |
| <a id="lib-array-find"></a>`Lib.Array.Find` | `list, test` | `value\|nil, index\|nil` | |
| <a id="lib-array-any"></a>`Lib.Array.Any` | `list, test` | `boolean` | |
| <a id="lib-array-all"></a>`Lib.Array.All` | `list, test` | `boolean` | `true` for an empty list. |
| <a id="lib-array-fold"></a>`Lib.Array.Fold` | `list, step(carried, value, index), initial` | `any` | |
| <a id="lib-array-reverse"></a>`Lib.Array.Reverse` | `list` | `table` | Copy. |
| <a id="lib-array-sorted"></a>`Lib.Array.Sorted` | `list, before?` | `table` | Sorted copy. |
| <a id="lib-array-unique"></a>`Lib.Array.Unique` | `list, by?` | `table` | First occurrence wins. |
| <a id="lib-array-groupby"></a>`Lib.Array.GroupBy` | `list, by` | `table<key, list>` | |
| <a id="lib-array-take"></a>`Lib.Array.Take` | `list, count` | `table` | Up to `count` from the front. |
| <a id="lib-array-push"></a>`Lib.Array.Push` | `list, value` | `integer` new length | In place. |
| <a id="lib-array-remove"></a>`Lib.Array.Remove` | `list, value` | `boolean` | Removes the first equal entry, in place. |
| <a id="lib-array-holds"></a>`Lib.Array.Holds` | `list, value` | `boolean` | |

### Colour {#colour}

A colour is `{ r, g, b }` (integers 0–255); HSL is `{ h, s, l }` (degrees, 0..1, 0..1).

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-colour-parse"></a>`Lib.Colour.Parse` | `value` — `'#RRGGBB'` | colour or `nil` | |
| <a id="lib-colour-hex"></a>`Lib.Colour.Hex` | `colour` | `'#RRGGBB'` | |
| <a id="lib-colour-tohsl"></a>`Lib.Colour.ToHsl` | `colour` | HSL | |
| <a id="lib-colour-fromhsl"></a>`Lib.Colour.FromHsl` | `hsl` | colour | |
| <a id="lib-colour-shade"></a>`Lib.Colour.Shade` | `colour, by` — -1..1 | colour | Lighter or darker. |
| <a id="lib-colour-saturate"></a>`Lib.Colour.Saturate` | `colour, fraction` | colour | |
| <a id="lib-colour-mix"></a>`Lib.Colour.Mix` | `from, to, amount` — 0..1 | colour | |
| <a id="lib-colour-luminance"></a>`Lib.Colour.Luminance` | `colour` | `number` 0..1 | Perceived brightness. |
| <a id="lib-colour-contrast"></a>`Lib.Colour.Contrast` | `background, onLight?, onDark?` | colour | The one that reads better; defaults black and white. |

### Permission {#permission}

Used to build `Lib.NEEDS`. Not a module with its own `require` entry in normal use.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-permission-of"></a>`Lib.Permission.Of` | `modules` | `table<name, permission>` | Reads each module's `NEEDS`. |
| <a id="lib-permission-list"></a>`Lib.Permission.List` | `needs` | `string[]` | Distinct permissions, sorted. |
| <a id="lib-permission-line"></a>`Lib.Permission.Line` | `needs` | `string\|nil` | The `permissions { ... }` line, or `nil` if none. |

## Client modules {#client}

### Native {#native}

No permission of its own. The building block every other wrapper uses.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-native-reach"></a>`Lib.Native.Reach` | `path` — e.g. `'hud.notify'` | `function\|nil, code?` | Looks the native up under `Open77` at call time. Codes: `open77_unavailable`, `native_not_found`. |
| <a id="lib-native-call"></a>`Lib.Native.Call` | `path, permission?, ...` | Result | Calls it under `pcall`. A `nil` or `false` first answer is a refusal. Do not use it for a native whose real answer can be `false`. |
| <a id="lib-native-refusal"></a>`Lib.Native.Refusal` | `path, permission?, reason` | Result | Turns `permission_denied…` into a `permission_denied` Result naming the manifest line. |

### Timer {#timer}

No permission. Everything it returns is a closure and lives in your VM.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-timer-after"></a>`Lib.Timer.After` | `delay, run` | handle or `nil` | Runs once after `delay` ms. |
| <a id="lib-timer-cancel"></a>`Lib.Timer.Cancel` | `handle` | `boolean` | |
| <a id="lib-timer-debounce"></a>`Lib.Timer.Debounce` | `wait, run` | `function` | Runs once, `wait` ms after the last call, with the last call's arguments. |
| <a id="lib-timer-throttle"></a>`Lib.Timer.Throttle` | `window, run` | `function` | First call runs at once; at most one more per window, with the latest arguments. |
| <a id="lib-timer-until"></a>`Lib.Timer.Until` | `test, timeout?, interval?` | first truthy answer or `nil` | **Yields.** Default 5000 ms timeout, 50 ms interval. |

### Character {#character}

No permission.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-character-position"></a>`Lib.Character.Position` | — | Result `{ x, y, z }` | `no_character` before the local body exists. |

### Notify {#notify}

Permission `ui.vanilla.hud`. The game's own HUD notifications (not the `opx_infinity` toasts).

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-notify-show"></a>`Lib.Notify.Show` | `text, options?` | Result | `text` 1–512 bytes. `options.replace = true` replaces what is on screen. Codes: `invalid_text`, `invalid_options`. |
| <a id="lib-notify-replace"></a>`Lib.Notify.Replace` | `text` | Result | `Show` with `replace = true`. |
| <a id="lib-notify-preset"></a>`Lib.Notify.Preset` | `preset` | Result | One of the engine's localised notifications. Code: `invalid_preset`. |
| <a id="lib-notify-clear"></a>`Lib.Notify.Clear` | `channel?` — `'ingame'` (default) or `'menu'` | Result | Code: `invalid_channel`. |

### Anim {#anim}

No permission declared by the module.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-anim-self"></a>`Lib.Anim.Self` | `animation, thirdPerson?` | Result | Plays an emote on the local player. |
| <a id="lib-anim-on"></a>`Lib.Anim.On` | `entity, animation` | Result | Plays an animation on another body. |

### Input {#input}

Permission `input.actions`. Up to 64 actions per resource (`Input.LIMIT`).

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-input-on"></a>`Lib.Input.On` | `id, label, key, pressed, released?` | Result: the effective key | Declares a rebindable action shown in the game's key bindings. `id` ≤ 64 bytes of `[A-Za-z0-9_.:-]`, `label` ≤ 96 bytes. Passing `released` makes it a hold. Codes: `invalid_id`, `invalid_label`, `invalid_key`, `invalid_handler`. |
| <a id="lib-input-off"></a>`Lib.Input.Off` | `id` | Result | |
| <a id="lib-input-block"></a>`Lib.Input.Block` | `action, blocked` | Result | Blocks or unblocks one of the game's own actions. |
| <a id="lib-input-iscaptured"></a>`Lib.Input.IsCaptured` | — | `boolean` | Whether another surface holds the keyboard. A read that raises answers `true`. |
| <a id="lib-input-isdown"></a>`Lib.Input.IsDown` | `key` | `boolean` | |
| <a id="lib-input-cursor"></a>`Lib.Input.Cursor` | — | `table\|nil` | At least `inBounds` and `captured`. |
| <a id="lib-input-keyfor"></a>`Lib.Input.KeyFor` | `action` | `string\|nil` | The key an action of yours answers to now, rebinds included. |
| <a id="lib-input-mappings"></a>`Lib.Input.Mappings` | — | `{ resource, id, key }[]\|nil, why?` | Every key mapping on the client, all resources. |

### Marker {#marker}

Permission `world.markers` (`Shapes` needs none). Up to 64 markers per resource (`Marker.LIMIT`). A handle does not mean the marker drew; use `Await`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-marker-shapes"></a>`Lib.Marker.Shapes` | — | Result: shape names | What this build supports. |
| <a id="lib-marker-place"></a>`Lib.Marker.Place` | `position, options?` — shape, style, radius, height, scale, rotation, color … | Result: handle | `position` is the bottom of the mesh; lift it slightly off the floor. |
| <a id="lib-marker-move"></a>`Lib.Marker.Move` | `handle, patch` | Result | Patches any field `Place` takes. A rejected patch changes nothing. `color = false` restores the style colour. |
| <a id="lib-marker-state"></a>`Lib.Marker.State` | `snap` | `'failed'\|'hidden'\|'rendered'\|'pending'\|'unknown'` | Reads a snapshot. |
| <a id="lib-marker-get"></a>`Lib.Marker.Get` | `handle` | Result: snapshot with `state` | |
| <a id="lib-marker-list"></a>`Lib.Marker.List` | — | Result: snapshots | Your markers. |
| <a id="lib-marker-count"></a>`Lib.Marker.Count` | — | Result: `integer` | Every marker your resource owns, made here or not. |
| <a id="lib-marker-failures"></a>`Lib.Marker.Failures` | — | Result: snapshots | Your markers that failed to load. |
| <a id="lib-marker-await"></a>`Lib.Marker.Await` | `handle, timeout?` | Result: snapshot, or why it never drew | **Yields.** Default 5000 ms. A hidden marker resolves `ok`. |
| <a id="lib-marker-remove"></a>`Lib.Marker.Remove` | `handle` | Result | |
| <a id="lib-marker-clear"></a>`Lib.Marker.Clear` | — | Result | Removes every marker your resource owns. |

### Callback {#callback}

Permission `network.events`. Asks the server half of **your own** resource (or another one you name). The server must re-check everything it receives.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-callback-ask"></a>`Lib.Callback.Ask` | `name` or `{ resource, name, timeout }`, `...` | Result: a promise | Up to 29 arguments, 48 KiB per frame. Timeout default 10000 ms, range 100–120000. |
| <a id="lib-callback-askawait"></a>`Lib.Callback.AskAwait` | `name, ...` | Result: the answer | **Yields.** |
| <a id="lib-callback-answer"></a>`Lib.Callback.Answer` | `name, handler` | Result | Answers a question the server asks with `callClient`. |
| <a id="lib-callback-silence"></a>`Lib.Callback.Silence` | `name` | Result | Stops answering. |

### Zone {#zone}

No permission. A zone definition is what `Open77.zones.contains` takes, for example `{ position = { x, y, z }, radius = 8.0 }`. A client zone is a display cue, never proof: re-check on the server.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-zone-contains"></a>`Lib.Zone.Contains` | `definition, point, options?` — grace, origin, rotation | Result: `boolean` | `ok = true, value = false` means outside. |
| <a id="lib-zone-here"></a>`Lib.Zone.Here` | `definition, options?` | Result: `boolean` | For the local player. |
| <a id="lib-zone-watch"></a>`Lib.Zone.Watch` | `definition, { onEnter?, onExit?, grace? }` | Result: handle | One shared thread polls every 250 ms. A player already inside gets `onEnter`. Codes: `invalid_definition`, `invalid_handlers`, `no_handlers`. |
| <a id="lib-zone-unwatch"></a>`Lib.Zone.Unwatch` | `handle` | Result | Code: `no_such_watch`. |
| <a id="lib-zone-count"></a>`Lib.Zone.Count` | — | `integer` | Running watches. |

### Rpc {#rpc}

No permission. Calls a **client export** of another resource through `Open77.exports.call`. It can reach `opx_infinity`'s [client exports](../creators/client-exports.md), but those answer `{ ok, value | error }`, which this helper reads as a Result.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-rpc-isrunning"></a>`Lib.Rpc.IsRunning` | `resource` | `boolean` | |
| <a id="lib-rpc-call"></a>`Lib.Rpc.Call` | `resource, name, ...` | Result; `answered = true` when the remote itself answered | **Yields.** The remote must answer a table with `ok`. Codes: `invalid_resource`, `invalid_name`, `no_exports`, `not_running`, `dispatch_raised`, `no_promise`, `malformed_answer`, or the remote's `error`. |

### Async {#async}

No permission. Create every promise first, then pass them in. **Yields.**

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-async-all"></a>`Lib.Async.All` | `promises` | Result: list of first values; `at` = failing index | Fails at the first rejection. |
| <a id="lib-async-settled"></a>`Lib.Async.Settled` | `promises` | Result: list of Results | Waits for all. |

### World {#world}

Permission `world.query`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-world-ray"></a>`Lib.World.Ray` | `from, to, options?` — `{ static, dynamic, entities }` | Result `{ hit, position, normal, material, distance, entity? }` | |
| <a id="lib-world-blocked"></a>`Lib.World.Blocked` | `from, to` | `boolean` | |
| <a id="lib-world-nearby"></a>`Lib.World.Nearby` | `radius, filter?` | Result: rows, nearest first | Around the local player; radius 0–1000 m. |
| <a id="lib-world-nearest"></a>`Lib.World.Nearest` | `radius, filter?` | Result: one row | |
| <a id="lib-world-groundz"></a>`Lib.World.GroundZ` | `position, options?` | Result: `number` | Static ground below a point. |

### Players {#players}

No permission declared by the module.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-players-all"></a>`Lib.Players.All` | `options?` | Result: array by player id | Players this client knows. |
| <a id="lib-players-localid"></a>`Lib.Players.LocalId` | — | Result: id | |
| <a id="lib-players-nearby"></a>`Lib.Players.Nearby` | `radius, options?` — `{ origin, includeSelf, limit }` | Result: array, nearest first | |
| <a id="lib-players-closest"></a>`Lib.Players.Closest` | `options?` | Result: one row | |
| <a id="lib-players-entity"></a>`Lib.Players.Entity` | `playerId` | Result: entity handle | |
| <a id="lib-players-fromentity"></a>`Lib.Players.FromEntity` | `entity` | Result: player id | |

### Blip {#blip}

Permission `ui.vanilla.map`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-blip-place"></a>`Lib.Blip.Place` | `position, options?` — sprite, label, icon, active, visibleThroughWalls, routable, range | Result: handle | |
| <a id="lib-blip-follow"></a>`Lib.Blip.Follow` | `entity, options?` | Result: handle | Follows an entity. |
| <a id="lib-blip-move"></a>`Lib.Blip.Move` | `handle, patch` | Result | Only the fields given change. |
| <a id="lib-blip-get"></a>`Lib.Blip.Get` | `handle` | Result | |
| <a id="lib-blip-setactive"></a>`Lib.Blip.SetActive` | `handle, active` | Result | |
| <a id="lib-blip-track"></a>`Lib.Blip.Track` | `handle` | Result | Sets it as the tracked destination. |
| <a id="lib-blip-remove"></a>`Lib.Blip.Remove` | `handle` | Result | |
| <a id="lib-blip-list"></a>`Lib.Blip.List` | — | Result: array | |
| <a id="lib-blip-clear"></a>`Lib.Blip.Clear` | — | Result | Every blip your resource owns. |

### Store {#store}

No permission. Small values on the player's own disk (`Open77.kvp`), per server address and per resource. The player can edit them; never trust them. 1 MiB per resource.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-store-get"></a>`Lib.Store.Get` | `key, fallback?` | value or `fallback` | Not a Result. |
| <a id="lib-store-has"></a>`Lib.Store.Has` | `key` | `boolean` | |
| <a id="lib-store-set"></a>`Lib.Store.Set` | `key, value` — string, finite number or boolean | Result | Key 1–128 bytes. No tables. Codes: `invalid_key`, `invalid_value`. |
| <a id="lib-store-delete"></a>`Lib.Store.Delete` | `key` | Result: whether it existed | |
| <a id="lib-store-keys"></a>`Lib.Store.Keys` | `prefix?` | Result: sorted keys | |

### Camera {#camera}

Permission `camera.script` (`Ray` and `Owner` need none). Up to 16 cameras per resource; only one camera can hold the view.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-camera-owner"></a>`Lib.Camera.Owner` | — | `string\|nil` | This resource's name. |
| <a id="lib-camera-state"></a>`Lib.Camera.State` | `snap` | `'mine'\|'theirs'\|'held'\|'free'\|'unknown'` | Who holds the view, from a `Cameras` snapshot. |
| <a id="lib-camera-cameras"></a>`Lib.Camera.Cameras` | — | Result: snapshot with `state` | Your cameras and the current holder. |
| <a id="lib-camera-holder"></a>`Lib.Camera.Holder` | — | Result: resource name or `nil` | |
| <a id="lib-camera-create"></a>`Lib.Camera.Create` | `options` — position, attachTo, offset, lookAt, rotation, fov | Result: camera id | Nothing renders until `Take`. |
| <a id="lib-camera-move"></a>`Lib.Camera.Move` | `camId, patch` — position, rotation, fov | Result | A patch may not carry both a rotation and a look-at. |
| <a id="lib-camera-lookat"></a>`Lib.Camera.LookAt` | `camId, target` — point or entity (`0` = player) | Result | |
| <a id="lib-camera-attach"></a>`Lib.Camera.Attach` | `camId, entity, offset?` | Result | Both arguments required. |
| <a id="lib-camera-detachfrom"></a>`Lib.Camera.DetachFrom` | `camId` | Result | |
| <a id="lib-camera-destroy"></a>`Lib.Camera.Destroy` | `camId` | Result | Destroying the live camera gives the view back. |
| <a id="lib-camera-take"></a>`Lib.Camera.Take` | `camId, options?` — `{ blendMs = 0..60000 }` | Result; `.blend` promise; `.holder` on `camera_held_by` | `camera_unavailable`: player dead or a transition running; retry next frame. |
| <a id="lib-camera-release"></a>`Lib.Camera.Release` | `options?` | Result; `.blend` | Only the holder may. |
| <a id="lib-camera-await"></a>`Lib.Camera.Await` | `promise?` | Result | **Yields.** A rejection is a release reason, as the code. |
| <a id="lib-camera-why"></a>`Lib.Camera.Why` | `reason` | `string` | The release token as a sentence. |
| <a id="lib-camera-shot"></a>`Lib.Camera.Shot` | `camId, options?, body` | Result: `body`'s answer; `.released` | **Yields.** Takes the view, runs `body`, always gives the view back. A raise becomes `shot_raised`. |
| <a id="lib-camera-follow"></a>`Lib.Camera.Follow` | `entity, options?` — distance, height, side, fov, blendMs | Result: camera id; `.blend` | One reused camera per resource. |
| <a id="lib-camera-unfollow"></a>`Lib.Camera.Unfollow` | `options?` | Result; `.blend` | Gives the view back and destroys the follow camera. `not_following` on a second call. |
| <a id="lib-camera-shake"></a>`Lib.Camera.Shake` | `camId?, preset, amplitude?, ms?` | Result | `hand`, `drunk`, `explosion`, `earthquake`; amplitude 0–4. |
| <a id="lib-camera-stopshake"></a>`Lib.Camera.StopShake` | `camId` | Result | |
| <a id="lib-camera-ray"></a>`Lib.Camera.Ray` | `x, y` — 0..1 from top left | Result `{ origin, direction }` | |

### Screen {#screen}

Permission `screen.effects`. Screen fades with a safety deadline: the client gives the image back when `timeoutMs` expires, whatever your code does.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="lib-screen-fadeout"></a>`Lib.Screen.FadeOut` | `spec?` — durationMs, color, timeoutMs | Result: id; `.covered` promise | The call returns before the screen is black; wait on `.covered`. |
| <a id="lib-screen-fadein"></a>`Lib.Screen.FadeIn` | `id, spec?` — `{ durationMs }` | Result; `.restored` | |
| <a id="lib-screen-transition"></a>`Lib.Screen.Transition` | `preset` (`'fade'`), `spec?` — durationMs, holdMs, fadeInMs, timeoutMs, color | Result: id; `.finished` | Fade, hold and return in one call. |
| <a id="lib-screen-cancel"></a>`Lib.Screen.Cancel` | `id` | Result | Restores the image now. |
| <a id="lib-screen-await"></a>`Lib.Screen.Await` | `promise?` | Result | **Yields.** |
| <a id="lib-screen-why"></a>`Lib.Screen.Why` | `reason` | `string` | |
| <a id="lib-screen-black"></a>`Lib.Screen.Black` | `spec?, body` | Result: `body`'s answer; `.restored` | **Yields.** Covers, runs `body`, always restores. `screen_busy` if another fade holds the slot; a raise becomes `screen_body_raised`. |
| <a id="lib-screen-isfaded"></a>`Lib.Screen.IsFaded` | — | `boolean` | Any fade, from anyone. Answers `true` when it cannot tell. |
| <a id="lib-screen-nativestate"></a>`Lib.Screen.NativeState` | — | Result `{ faded, fading, out, busy, ready, remainingMs }` | |
| <a id="lib-screen-state"></a>`Lib.Screen.State` | `id` | Result: snapshot with `over` | Your transition only. |
| <a id="lib-screen-over"></a>`Lib.Screen.Over` | `snap` | `boolean` | Whether the id can be dropped. |
| <a id="lib-screen-catalog"></a>`Lib.Screen.Catalog` | — | Result | Presets this build supports. |
