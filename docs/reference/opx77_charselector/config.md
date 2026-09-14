---
title: opx77_charselector configuration
description: Every key of OPX_CHARSELECTOR_CONFIG with its shipped default — the language, the hand-over and appearance channels, the roster retry and its floor, the STAGE block, the selection deadline — the locale catalogue, and the constants that are not keys.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_CHARSELECTOR_CONFIG`,
loaded first by the manifest. **Every value shown on this page is the shipped
default.**

```lua
OPX_CHARSELECTOR_CONFIG = {
  LOCALE = "en",
  EVENT = "opx77:charselector",
  APPEARANCE_EVENT = "opx77:appearance",
  ROSTER_RETRY_MS = 3000,
  STAGE = {
    ENABLED = true,
    ORBIT_DEGREES = 180,
    LOCK_CAMERA = true,
    FREEZE = true,
  },
  REQUEST_TIMEOUT_MS = 20000,
}
```

A value of the wrong type is said **once, in the log, at start**, and the shipped
one is used. Nothing here is re-read while the resource runs.

!!! info "There is no `PREVIEW` block"

    Earlier builds shipped a `PREVIEW` block for a camera at a fixed world
    point. It was never implemented and cannot be on this platform; it is gone,
    and [`STAGE`](#stage) replaces it. A leftover `PREVIEW` key is ignored.

## LOCALE {#locale}

Which `locales/<code>.lua` catalogue player-facing text is read from.

```lua
LOCALE = "en"
```

**Type** `string` — `"en"` or `"fr"` as shipped.

Each resource carries its own catalogue, so this is set here as well as in
`opx77_core`: the core's `Locale` export is client-only and asynchronous, and a
resource that renders text at load cannot wait on it. See [Locales](#locales).

## EVENT {#event}

The client event raised when the player asks for a character this account does
not have.

```lua
EVENT = "opx77:charselector"
```

**Type** `string`

The payload is [`createRequested`](events.md#create-requested).
[`opx77_charcreator`](../opx77_charcreator/config.md#selector-event) listens on
it through its own `SELECTOR_EVENT`, and the two must match. An `EVENT` that is
not a name leaves the create row doing nothing, with one log error.

## APPEARANCE_EVENT {#appearance-event}

The channel [`opx77_appearance`](../opx77_appearance/index.md) publishes its
decisions on.

```lua
APPEARANCE_EVENT = "opx77:appearance"
```

**Type** `string` — must match `OPX_APPEARANCE_CONFIG.EVENT` in that resource.

Only [`needsCreation`](events.md#needs-creation) is read from it: the face editor
is coming, with a camera of its own, so the stage goes. A value that is not a
string is read as the shipped name, because `AddEventHandler` raises on a
non-string and that would abandon the whole file.

## ROSTER_RETRY_MS {#roster-retry-ms}

How often `opx77_core` is asked for the roster again while none has arrived and
no character is loaded, in milliseconds.

```lua
ROSTER_RETRY_MS = 3000
```

**Type** `integer` — never under `2500`.

`opx77_core` cools a roster request for **2000 ms per player** and drops a cooled
one without answering, so a retry inside that window is a retry that is never
answered. The 500 ms margin covers the network between the two clocks. Each retry
reads `GetCharacters` first and calls `RequestCharacters` only when the core
holds nothing; see [When the roster does not arrive](index.md#roster-retry).

| Configured | Used | Said at start |
|---|---|---|
| a number of 2500 or more | that number | nothing |
| a positive number under 2500 | `2500` | `ROSTER_RETRY_MS is inside opx77_core's cooldown: raised to 2500 ms` |
| anything else | `3000` | `ROSTER_RETRY_MS is not a positive number: 3000 ms is used` |

A run of retries is one warning, carrying the value in force:

```text
no roster yet: asking opx77_core again every 3000 ms
```

## STAGE {#stage}

[The stage](stage.md): while the roster, or a creation form holding it through
[`holdStage`](exports.md#holdstage), is up, the camera orbits to face the
player's own character, the mouse cannot turn it, and the character is held where
it stands. It goes when a character is loaded.

```lua
STAGE = {
  ENABLED = true,
  ORBIT_DEGREES = 180,
  LOCK_CAMERA = true,
  FREEZE = true,
}
```

**Type** `table`. A `STAGE` that is not a table is said once and read as all
four defaults:

```text
STAGE is not a table: the stage is up, facing, with the camera locked and the freeze on
```

### STAGE.ENABLED {#stage-enabled}

Whether the stage comes up at all.

```lua
ENABLED = true
```

**Type** `boolean` — only `false` turns it off.

`false` leaves the gameplay camera alone and the character free to walk.
`holdStage` still takes a hold and answers `staged = false`, so a holder needs no
branch for it. Any value but a boolean or `nil` is said once and read as `true`:

```text
STAGE.ENABLED is not a boolean: the stage is up
```

### STAGE.ORBIT_DEGREES {#stage-orbit-degrees}

Where the camera sits around the character, in degrees.

```lua
ORBIT_DEGREES = 180
```

**Type** `number` — from `-180` to `180`.

`180` is in front, looking at the face — the platform fitting room's FRONT — and
`0` is behind. A value outside the range is clamped, and a value that is not a
number is replaced by `180`; either is said once:

```text
STAGE.ORBIT_DEGREES is outside -180..180: clamped to <n>
STAGE.ORBIT_DEGREES is not a number: 180 is used
```

### STAGE.LOCK_CAMERA {#stage-lock-camera}

Whether the mouse is kept off the camera while the stage is up.

```lua
LOCK_CAMERA = true
```

**Type** `boolean` — only `false` turns it off.

`Open77.players.freezeRotation(true)`, the platform's native camera and turn
restriction, under `players.controls`, which `open77.lua` grants; the orbit is
also asked for on every frame instead of every tick — see
[The lock and the hold](stage.md#lock). It takes no input from a surface, so
`opx77_menu` keeps reading its arrows. `false` lets the mouse turn the camera. A
client without the controls, or a refused grant, cannot lock the camera at all,
and says so once. Any value but a boolean or `nil` is said once and read as
`true`:

```text
STAGE.LOCK_CAMERA is not a boolean: the camera is locked
```

### STAGE.FREEZE {#stage-freeze}

Whether the character is held in place while the stage is up.

```lua
FREEZE = true
```

**Type** `boolean` — only `false` turns it off.

`Open77.players.freezePosition(true)`, and no jump, crouch, dodge, weapon, aim,
shot or world interaction, under `players.controls` — see
[The lock and the hold](stage.md#lock). The roster cannot take the keyboard to
keep the walk keys from the game, because `opx77_menu` stops reading its arrows
while anything holds focus, and these controls do not take it. On a client
without them, a character that walks off is put back where it stood 30 times a
second instead, under `player.travel` — see [the fallback pin](stage.md#hold).
`false` lets it walk under the camera. Any value but a boolean or `nil` is said
once and read as `true`:

```text
STAGE.FREEZE is not a boolean: the character is held
```

## REQUEST_TIMEOUT_MS {#request-timeout-ms}

How long a selection may stay unanswered before the roster unlocks itself, in
milliseconds.

```lua
REQUEST_TIMEOUT_MS = 20000
```

**Type** `integer`

`opx77_core` answers a selection by event — `onPlayerLoaded`, or a refusal naming
`selectCharacter` — not by return value, so a lost reply would leave a player
looking at a dimmed list with no way forward. Past the deadline the list unlocks
with *Nothing answered. Try again.* A value that is not a positive number turns
the deadline off.

## Locales {#locales}

`locales/en.lua` and `locales/fr.lua`, registered through `shared/locale.lua`.
The catalogue carries the list's own wording — the title, the row facts, the
empty slot, the create row, the status lines — **and** every refusal code the
three operations this resource answers can produce, so a refusal reaches the
player in their language rather than as a bare code.

To add a language, copy `locales/en.lua` to `locales/<code>.lua`, change the code
in the `register` call, translate the values, add a
`shared_script "locales/<code>.lua"` line to `open77.lua` beside the others, and
set [`LOCALE`](#locale) to it. A key missing from the chosen catalogue falls back
to English, then to the key itself. `Open77.log` lines stay English whatever the
setting.

## Constants that are not keys {#constants}

| Constant | Value | What it is |
|---|---|---|
| `IDLE_MS` | `250` | The tick: the selection deadline, the world watch, the stage and the roster retry. |
| `REOPEN_MS` | `250` | How long the list waits before going back up after a dismissal. |
| `STAGE_LINGER_MS` | `1500` | How long the stage outlives the last thing that wanted it. See [The linger](stage.md#linger). |
| `HANDOVER_MS` | `5000` | How long a creation handed over keeps the stage unclaimed. See [The hand-over window](stage.md#handover). |
| `ROSTER_RETRY_FLOOR_MS` | `2500` | The floor under [`ROSTER_RETRY_MS`](#roster-retry-ms). |
| `PIN_MS` | `33` | The hold's cadence. |
| `PIN_FLOOR_M`, `PIN_CEILING_M` | `0.05`, `3.0` | Under the floor nothing is corrected; over the ceiling the move was a placement. |
| `PIN_TURN_DEGREES` | `10` | How far the facing may turn before it is put back. |
| `MAX_SLOT_ROWS` | `199` | `opx77_menu` refuses a level over 200 rows, and the create row is one of them. |
