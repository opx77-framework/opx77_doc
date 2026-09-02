---
title: opx77_elevators types
description: The shapes opx77_elevators reads and answers with — the configuration entries, the gate's snapshot, the tables every export returns, and the two host shapes it consumes.
---

# Types

The annotations in `types.lua`, as the code actually uses them. Nothing here is
loaded at runtime: Lua tables carry no schema, and these are the shapes the
resource reads and answers with.

Field names are `UPPER_CASE` in the configuration — it is written by a human —
and `lowerCamelCase` everywhere the code produces a value.

## ElevatorKey {#elevatorkey}

The durable name of an elevator: the key of an entry in `config.lua`'s
`ELEVATORS`.

```lua
---@alias ElevatorKey string
```

!!! warning "The key is the name; the id is not"

    The Open77 elevator id is assigned at adoption and changes on every restart.
    Every export, every event payload and the diagnostic command use the **key**.
    Store the key; treat an id as a debugging aid.

## FloorIndex {#floorindex}

The **native** floor index of a stop, 0-based.

```lua
---@alias FloorIndex integer
```

!!! danger "Never the position of a row in `FLOORS`"

    The panel's order is a presentation choice; the shaft's order is not. Indexes
    run `0` to `FLOOR_COUNT - 1` and are per-lift — floor `2` of one lift has
    nothing to do with floor `2` of another. Getting this wrong sends the cabin
    to the wrong storey with **no error at all**, because the index was valid.

## ElevatorError {#elevatorerror}

The `error` code carried by any refusal.

```lua
---@alias ElevatorError string
```

Every code, who decided it, and which five of them are client-side hints rather
than proof, are listed on [Error codes](errors.md).

## ElevatorSpec {#elevatorspec}

One entry of `config.lua`'s `ELEVATORS`: where a shaft is, how many floors the
native device has, and the stops this resource offers there.

Reach is horizontal. `X` and `Y` are the only pair any distance is measured on,
which is what makes an elevator callable from every floor of its own shaft.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `LABEL` | `string` | the panel's title, and the name in the diagnostic report |
| `X` | `number` | with `Y`, where the shaft is: the pair that decides reach, in metres, never the cabin's |
| `Y` | `number` | " |
| `Z` | `number` | the shaft's height. Recorded, printed by the diagnostic command, and **never compared** |
| `BUCKET` | `integer\|nil` | routing bucket, default `0`. An elevator in a bucket is invisible to players outside it |
| `ENTITY` | `string\|nil` | the native `LiftDevice` hash, `"0x"` plus sixteen hex digits. **Opaque** — compared as a lower-cased string, never through `tonumber` |
| `FLOOR_COUNT` | `integer` | the engine's floor count, not `#FLOORS`. The ceiling every index is checked against |
| `FLOORS` | [`FloorSpec[]`](#floorspec) | the stops this resource offers, in panel order |

Written by hand and validated at boot; see
[Configuration](config.md#elevators) for what each field decides and
[Checking the configuration](config.md#validation) for what is caught.

## FloorSpec {#floorspec}

One stop this resource offers at an elevator. A floor with no `JOBS` is public.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `INDEX` | [`FloorIndex`](#floorindex) | the native floor index |
| `LABEL` | `string` | the row's label |
| `JOBS` | `table<string, integer>\|nil` | job name to **minimum grade level**. Satisfying any one entry passes |
| `ON_DUTY` | `boolean\|nil` | also require the character be clocked in, on the **primary** job |
| `REASON` | `string\|nil` | the operator's wording, shown beside a refused row |

!!! warning "A job name here cannot be verified"

    Names must exist in [`opx77_core`'s `data/jobs.lua`](../opx77_core/data.md),
    and this resource's VM cannot ask the core anything. A typo is not an error —
    it is a floor nobody can take.

## JobSnapshot {#jobsnapshot}

What the client keeps of a character, and the only thing this resource copies out
of `PlayerData`.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `job` | [`PlayerJob`](#playerjob)`\|nil` | the primary job, from `PlayerData.job` |
| `jobs` | `table<string, integer>\|nil` | every membership, from `PlayerData.jobs`. Read only when `MEMBERSHIP` is `"any"` |
| `atMs` | `integer` | when it was read, from the client clock. This is what makes it expire |

Money, metadata and the citizen id are deliberately not copied: this resource has
no use for them, and a second copy would be a second answer to a question
`opx77_core` already answers.

`nil` — the core has never answered — and a snapshot with no `job` are different
states. Both refuse a gated floor, so the difference shows up only in the log; but
it shows up there, and an operator reading `no_character` for a player who is
plainly in game has learnt something about their core.

## PlayerJob {#playerjob}

`opx77_core`'s job shape, reproduced only as far as this resource reads it.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `name` | `string` | the job's name, matched against a floor's `JOBS` keys |
| `label` | `string` | the display name. Not read by the gate |
| `onDuty` | `boolean` | whether the character is clocked in |
| `grade` | `{ name: string, level: integer }` | `level` is what a floor's minimum is compared against |

The authoritative shape is [`opx77_core`'s](../opx77_core/types.md). This is a
reader's copy, and it is out of date the moment the core adds a field.

## ElevatorResponse {#elevatorresponse}

The base every export answers with. Every call answers a table carrying `ok` and
never raises.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `ok` | `boolean` | whether the call succeeded |
| `error` | [`ElevatorError`](#elevatorerror)`\|nil` | the refusal code, on `ok = false` |

## FloorRow {#floorrow}

One row of a floor list, as [`floors`](exports.md#floors) returns it and as the
built-in panel draws it.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `index` | [`FloorIndex`](#floorindex) | the native floor index |
| `label` | `string` | the floor's `LABEL` |
| `ok` | `boolean` | whether **this client** believes the player may take it |
| `error` | [`ElevatorError`](#elevatorerror)`\|nil` | why not |
| `reason` | `string\|nil` | the floor's `REASON`, present only on a refused row |

!!! warning "`ok` here is a hint, and it is what the panel greys on"

    It is decided on the client from a snapshot a modified client never has to
    read. Grey a row with it; settle nothing with it. Under
    `DENIED_FLOORS = "hidden"` a refused row is absent from the list entirely
    rather than carrying `ok = false`.

## FloorListing {#floorlisting}

What [`floors`](exports.md#floors) answers.

Extends [`ElevatorResponse`](#elevatorresponse)

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `elevator` | [`ElevatorKey`](#elevatorkey)`\|nil` | the key the list is for, resolved from the player's position when the caller passed none |
| `floors` | [`FloorRow[]`](#floorrow)`\|nil` | the rows, in configured order. Can be empty under `DENIED_FLOORS = "hidden"` |

## FloorDecision {#floordecision}

What [`check`](exports.md#check) and [`use`](exports.md#use) answer, and the shape
of the payload published on
[`opx77:elevators`](events.md#opx77-elevators).

Extends [`ElevatorResponse`](#elevatorresponse)

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `elevator` | [`ElevatorKey`](#elevatorkey)`\|nil` | the elevator the decision is about |
| `floor` | [`FloorIndex`](#floorindex)`\|nil` | the floor it is about |
| `label` | `string\|nil` | the floor's `LABEL` |
| `reason` | `string\|nil` | the floor's `REASON`, on a refusal |
| `queued` | `boolean\|nil` | `true` when `use` sent the request to the server |
| `source` | `string\|nil` | the invoking resource's own name, `"panel"`, or `"server"` |

!!! warning "`ok = true` from `use` means asked, never moved"

    An export handler is not a coroutine, so nothing inside one can wait for the
    server. The verdict arrives afterwards on
    [`opx77:elevators`](events.md#opx77-elevators) with `source = "server"` — or
    never arrives, when the refusal was `rate_limited`.

## ElevatorClientState {#elevatorclientstate}

What [`state`](exports.md#state) answers: enough to debug a panel that will not
open, and nothing a caller could mistake for authority.

Extends [`ElevatorResponse`](#elevatorresponse)

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `job` | `string\|nil` | the primary job's name |
| `grade` | `integer\|nil` | its grade level |
| `onDuty` | `boolean` | whether the character is clocked in |
| `fresh` | `boolean` | whether the gate still trusts the snapshot |
| `ageMs` | `integer\|nil` | how old the snapshot is |
| `seen` | `integer` | configured lifts in range |
| `bound` | `integer` | of those, how many this resource owns |
| `nearest` | [`ElevatorKey`](#elevatorkey)`\|nil` | the elevator the player is standing at |

## NativeLift {#nativelift}

One entry of `Open77.elevators.nearby(radius)`, on the **client**. The host's
shape, not this resource's; it is here because a scan reads every field of it.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `engineEntity` | `string` | the opaque 64-bit hash as `"0x…"` |
| `controllerEntity` | `string` | the controller's hash |
| `position` | `{ x: number, y: number, z: number }` | **nested** here |
| `distance` | `number` | metres from the local player, in **three** dimensions, to the cabin — which moves. This resource ranks on `X` and `Y` instead, and falls back to this only when the client cannot read its own position |
| `floorCount` | `integer\|nil` | `nil` until the native device's inspect answers |
| `activeFloor` | `integer\|nil` | `nil` until the native device's inspect answers |
| `managed` | `boolean` | already adopted by some resource |
| `id` | `integer\|nil` | the Open77 id, only when `managed` |

!!! warning "Never invent a floor count"

    Topology arrives asynchronously from the native `LiftDevice`. A lift whose
    inspect has not answered carries `nil` in both count fields, and this resource
    leaves it for the next scan rather than guessing. Requires `elevators.read`.

## ServerElevator {#serverelevator}

One entry of `Open77.elevators.all(bucket)`, on the **server**.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `id` | `integer` | the Open77 elevator id |
| `engineEntity` | `string` | the opaque hash |
| `bucket` | `integer` | the routing bucket it was adopted into |
| `floorCount` | `integer` | the ceiling every request index is checked against |
| `x` | `number` | position — **flat** here |
| `y` | `number` | " |
| `z` | `number` | " |
| `phase` | `string` | the host's phase, lower-cased |
| `activeFloor` | `integer` | where the cabin is |
| `targetFloor` | `integer` | where it is going |
| `flags` | `integer` | the host's flag bits; this resource sets `locked` |
| `revision` | `integer` | the host's revision counter |

!!! warning "The position is flat here and nested on the client"

    `nearby` on the client puts `x`, `y` and `z` under `position`;
    `all` on the server puts them at the top level. Code that reads both, as this
    resource's `atElevator` does, has to accept either.

!!! warning "`all()` lists only lifts that are already adopted"

    A native lift nobody has taken is invisible to the server VM, which is why a
    sighting's hash cannot be verified and why the unused-adoption sweep exists.
    See [Constants that are not configurable](config.md#constants).
