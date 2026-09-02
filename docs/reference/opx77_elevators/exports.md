---
title: opx77_elevators exports
description: The six client exports of opx77_elevators — floors, check, use, panel, nearest and state — with their parameters, answers, error codes and the side each can be called from.
---

# Exports

Six exports, all **client-side**, because that is the only side exports exist
on: the Open77 server runtime installs none. A server resource that wants an
elevator panel sends a net event to its own client half, and that half calls
these. [The client export contract](../../concepts/export-contract.md) covers
the call shape and its three levels of failure.

Every call answers a table carrying `ok` and never raises. `error` is a stable
`snake_case` code meant for branching; every code is listed in
[Error codes](errors.md).

`elevator` is optional everywhere it appears and always defaults to the elevator
the player is standing at — the nearest configured elevator within `USE_RADIUS`,
from a sighting no older than two `SCAN_MS` scans. Every answer that has one
carries the `elevator` key back, so a caller drawing its own panel needs nothing
else.

!!! info "Called from another resource, always"

    Each export reads the caller from `GetInvokingResource()` and refuses
    `export_call_required` when there is none. A call with no invoking resource
    is a call made from inside this VM, which went somewhere it did not mean to —
    `OpxElevators.runtime` and `OpxElevators.panel` are right there.

## floors {#floors}

Returns every floor to draw at an elevator, each with whether this client
believes the player may take it, or `ok = false` with `no_elevator_nearby` when
the player is not standing at a configured elevator.

!!! warning "The `ok` on each row is a hint, not proof"

    The four job codes are decided on this client, from a snapshot of
    `PlayerData` that a modified client never has to read. Grey a row with them;
    do not settle anything with them. The server re-derives the elevator, the
    floor, the position, the bucket and the rate, and not the job.

```lua
Open77.exports.call("opx77_elevators", "floors", elevator)
```

- elevator?: `ElevatorKey`
    - The `config.lua` key of the elevator to list.
    - Default: the elevator the player is standing at

**Returns** a [`FloorListing`](types.md#floorlisting) — on `ok = true`,
`elevator` is the key the list is for and `floors` is an array of
[`FloorRow`](types.md#floorrow) in **configured order**. Under
`DENIED_FLOORS = "hidden"` the refused rows are absent and the array can be
empty.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource, so the call came from inside this VM. |
| `no_elevator_nearby` | The player is not standing at a configured elevator. |
| `no_such_elevator` | No entry of that name in `config.lua`'s `ELEVATORS`. |

**Side** `client export` — callable from any resource on the player's machine,
asynchronous, arguments and answer pass through the runtime's codec.

### Example {#floors-example}

```lua
-- in a client script of your own resource
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_elevators", "floors")
  if not promise then
    return Open77.log.warn("floors not dispatched: " .. tostring(reason))
  end

  local result, callError = promise:await()
  if callError then
    return Open77.log.warn("floors failed: " .. tostring(callError))
  end

  if not result.ok then
    return Open77.log.info("no floor list: " .. tostring(result.error))
  end

  for index = 1, #result.floors do
    local row = result.floors[index]
    print(("%s  floor %d  %s"):format(
      result.elevator, row.index,
      row.ok and "open" or (row.reason or row.error)))
  end
end)
```

## check {#check}

Answers whether this client believes the player may take one floor, deciding
nothing and sending nothing, or `ok = false` with the closest near-miss when it
believes not.

!!! warning "This is a hint, not proof"

    `check` runs the same gate the built-in panel runs, on this client, from a
    snapshot that a modified client never has to read. It is here so a caller
    drawing its own UI greys a row for the same reason the built-in panel does —
    not so a caller can settle anything with it.

```lua
Open77.exports.call("opx77_elevators", "check", elevator, floor)
```

- elevator?: `ElevatorKey`
    - Default: the elevator the player is standing at
- floor: `FloorIndex`
    - The **native** floor index, 0-based — never the row's position in `FLOORS`.

**Returns** a [`FloorDecision`](types.md#floordecision) — `label` is the floor's
`LABEL`, and `reason` is its `REASON`, present only on a refusal.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource, so the call came from inside this VM. |
| `no_elevator_nearby` | The player is not standing at a configured elevator. |
| `no_such_elevator` | No entry of that name in `config.lua`'s `ELEVATORS`. |
| `no_such_floor` | That index is not a floor this elevator declares. |
| `no_character` | `opx77_core` has no character, or has never answered. **Hint.** |
| `job_stale` | The last snapshot is older than `JOB_MAX_AGE_MS`. **Hint.** |
| `job_required` | The character holds none of the floor's jobs. **Hint.** |
| `grade_too_low` | It holds one, below the minimum grade. **Hint.** |
| `off_duty` | It holds one, at grade, and is not clocked in. **Hint.** |

**Side** `client export` — callable from any resource on the player's machine,
asynchronous, arguments and answer pass through the runtime's codec.

### Example {#check-example}

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call(
    "opx77_elevators", "check", "arasaka_tower", 11)
  if not promise then return Open77.log.warn(tostring(reason)) end

  local result, callError = promise:await()
  if callError then return Open77.log.warn(tostring(callError)) end

  if result.ok then
    print("Executive Suite is open")
  else
    print(("%s: %s"):format(result.error, result.reason or "no wording configured"))
  end
end)
```

## use {#use}

Selects a floor: runs the same gate as `check` and, on a pass, sends the request
to this resource's server half, answering `ok = false` with the refusal when the
gate closed or nothing could be sent.

!!! warning "`ok = true` means asked, never moved"

    An export handler is not a coroutine, so nothing inside one can wait for the
    server. `ok = true` says the gate passed on this client, the lift is adopted
    and the net event was accepted. The verdict arrives afterwards, on
    [`opx77:elevators`](events.md#opx77-elevators) with `source = "server"`.

```lua
Open77.exports.call("opx77_elevators", "use", elevator, floor)
```

- elevator?: `ElevatorKey`
    - Default: the elevator the player is standing at
- floor: `FloorIndex`
    - The **native** floor index, 0-based.

**Returns** a [`FloorDecision`](types.md#floordecision) — with `queued = true`
when the request left the client, and `source` set to the invoking resource's
own name, which is what lets a listener on the answer channel recognise its own
press.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource, so the call came from inside this VM. |
| `no_elevator_nearby` | The player is not standing at a configured elevator. |
| `no_such_elevator` | No entry of that name in `config.lua`'s `ELEVATORS`. |
| `no_such_floor` | That index is not a floor this elevator declares. |
| `no_character` | `opx77_core` has no character, or has never answered. **Hint.** |
| `job_stale` | The last snapshot is older than `JOB_MAX_AGE_MS`. **Hint.** |
| `job_required` | The character holds none of the floor's jobs. **Hint.** |
| `grade_too_low` | It holds one, below the minimum grade. **Hint.** |
| `off_duty` | It holds one, at grade, and is not clocked in. **Hint.** |
| `not_adopted` | The lift was sighted, but the server has not taken ownership yet. |
| `not_sent` | `TriggerServerEvent` refused the send; the runtime's own reason replaces the code when it gives one. |

A refusal from the **server** never arrives here. It arrives as
[`opx77_elevators:answer`](events.md#answer) and is republished
on [`opx77:elevators`](events.md#opx77-elevators).

**Side** `client export` — callable from any resource on the player's machine,
asynchronous, arguments and answer pass through the runtime's codec.

### Example {#use-example}

```lua
CreateThread(function()
  -- nearest elevator, floor 3
  local promise, reason = Open77.exports.call("opx77_elevators", "use", nil, 3)
  if not promise then
    return Open77.log.warn("use not dispatched: " .. tostring(reason))
  end

  local result, callError = promise:await()
  if callError then
    return Open77.log.warn("use failed: " .. tostring(callError))
  end

  if not result.ok then
    -- refused here, on this client, before anything was sent
    return Open77.log.info("refused: " .. tostring(result.error))
  end

  print("requested " .. tostring(result.label))   -- asked, not moved
end)
```

## panel {#panel}

Opens the floor list through [`opx77_menu`](../opx77_menu/index.md), or answers
`ok = false` with `menu_not_running` when the menu is not running and
`no_floors_available` when every floor is gated and `DENIED_FLOORS` is
`"hidden"`.

!!! warning "`ok = true` means asked, never drawn"

    `await` is coroutine-only and an export handler is not a coroutine, so the
    call to `opx77_menu` is queued on a thread. A menu that failed to open is a
    log line, not a return value.

```lua
Open77.exports.call("opx77_elevators", "panel", elevator)
```

- elevator?: `ElevatorKey`
    - Default: the elevator the player is standing at

**Returns** `table` — `{ ok = true, queued = true, elevator = <key>, floors = <row count> }`
on a pass; a [`FloorListing`](types.md#floorlisting) refusal otherwise.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource, so the call came from inside this VM. |
| `menu_not_running` | `opx77_menu` is not in the `running` state. |
| `no_elevator_nearby` | The player is not standing at a configured elevator. |
| `no_such_elevator` | No entry of that name in `config.lua`'s `ELEVATORS`. |
| `no_floors_available` | Every floor is gated and `DENIED_FLOORS` is `"hidden"`; an empty menu is refused by `opx77_menu` anyway, and "nothing happened" is a worse answer to the player than a named one. |

**Side** `client export` — callable from any resource on the player's machine,
asynchronous, arguments and answer pass through the runtime's codec.

### Example {#panel-example}

```lua
-- the one call an interaction resource needs: bind it to a prompt on the
-- elevator's call button and this resource does the rest
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_elevators", "panel")
  if not promise then return Open77.log.warn(tostring(reason)) end

  local result, callError = promise:await()
  if callError then return Open77.log.warn(tostring(callError)) end

  if not result.ok then
    return Open77.log.info("panel refused: " .. tostring(result.error))
  end

  print(("panel queued for %s, %d rows"):format(result.elevator, result.floors))
end)
```

## nearest {#nearest}

Returns which configured elevator the player is standing at, or `ok = false`
with `no_elevator_nearby` when none is within `USE_RADIUS`.

```lua
Open77.exports.call("opx77_elevators", "nearest")
```

**Returns** `table` — `{ ok = true, elevator = <ElevatorKey>, id = <integer|nil> }`.
`id` is the Open77 elevator id and is present only once the lift is adopted.

!!! warning "The id is not a name"

    Ids are assigned at adoption and change on every restart, which is why the
    durable name of an elevator is its `config.lua` **key** and never its id.
    Store the key; treat the id as a debugging aid.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource, so the call came from inside this VM. |
| `no_elevator_nearby` | No configured elevator within `USE_RADIUS`, from a sighting no older than two scans. |

**Side** `client export` — callable from any resource on the player's machine,
asynchronous, arguments and answer pass through the runtime's codec.

### Example {#nearest-example}

```lua
CreateThread(function()
  local promise = Open77.exports.call("opx77_elevators", "nearest")
  if not promise then return end
  local result = promise:await()
  if result and result.ok then
    print("standing at " .. result.elevator)
  end
end)
```

## state {#state}

Returns what this client knows and how old it is — the job it read, whether the
gate still trusts that reading, and how many lifts are in range — and never
refuses except for `export_call_required`.

!!! warning "This is a report, not authority"

    Everything here is what one client believes. It is enough to debug a panel
    that will not open and nothing a caller could mistake for a decision.

```lua
Open77.exports.call("opx77_elevators", "state")
```

**Returns** an [`ElevatorClientState`](types.md#elevatorclientstate).

| Field | Meaning |
|---|---|
| `job` | the primary job's name, or `nil` |
| `grade` | its grade level, or `nil` |
| `onDuty` | whether the character is clocked in |
| `fresh` | whether the gate still trusts the snapshot |
| `ageMs` | how old the snapshot is, in milliseconds |
| `seen` | configured lifts in range |
| `bound` | of those, how many this resource owns |
| `nearest` | the elevator key the player is standing at, or `nil` |

`fresh = false` with a `job` present is the state worth recognising: the core has
been unreachable for longer than `JOB_MAX_AGE_MS`, so every gated floor is closed
even though a job is on screen.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource, so the call came from inside this VM. |

**Side** `client export` — callable from any resource on the player's machine,
asynchronous, arguments and answer pass through the runtime's codec.

### Example {#state-example}

```lua
CreateThread(function()
  local promise = Open77.exports.call("opx77_elevators", "state")
  if not promise then return end
  local report = promise:await()
  if report and report.ok and not report.fresh then
    Open77.log.warn("elevator gate is closed: the core has not answered recently")
  end
end)
```
