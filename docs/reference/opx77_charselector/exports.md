---
title: opx77_charselector exports
description: The six client exports opx77_charselector publishes — open, close, isOpen, state, holdStage and releaseStage — with what each answers, every code each refuses with, and which refusals still count.
---

# Exports

`opx77_charselector` publishes six exports, all **client** exports. Every one
answers `{ ok = boolean, error = string|nil }` and **never raises**; `error` is a
stable code, never player-facing text. See
[The client export contract](../../concepts/export-contract.md) for the call
shape and the three levels of failure.

| Export | Answers | Does |
|---|---|---|
| [`open`](#open) | [`SelectorOpened`](types.md#selectoropened) | Puts the list up, asking `opx77_core` for the roster when there is none. |
| [`close`](#close) | [`SelectorResponse`](types.md#selectorresponse) | Takes it down, and the stage with it. |
| [`isOpen`](#isopen) | [`SelectorOpen`](types.md#selectoropen) | Whether the list is on the player's monitor. |
| [`state`](#state) | [`SelectorState`](types.md#selectorstate) | The phase, the gameplay world, the roster it holds, and the stage. |
| [`holdStage`](#holdstage) | [`SelectorStaged`](types.md#selectorstaged) | Keeps the stage up while the caller has the player choosing without the list. |
| [`releaseStage`](#releasestage) | [`SelectorResponse`](types.md#selectorresponse) | Lets go of the caller's hold. |

The caller is read from `GetInvokingResource()`. A call that did not arrive
through the export mechanism answers `export_call_required`.

!!! info "Always test the promise for presence"

    `Open77.exports.call` answers a **userdata** promise on this host, not a
    table. Test it with `if not promise`, never `type(promise) ~= "table"`: the
    second refuses every call before it is dispatched. This resource shipped
    that bug, and a player with no character sat on the loading screen for ever
    because nothing it asked for was ever asked.

## open {#open}

Puts the roster up. Answers that the list was **asked for**: `opx77_menu` is
called on a thread, so the list appears a moment later, or one log line says why
it did not.

```lua
Open77.exports.call("opx77_charselector", "open")
```

Takes no arguments.

**Returns** [`SelectorOpened`](types.md#selectoropened) — `ok = true,
queued = true` on success.

A call to `open` ends a creation this resource handed over, **whatever it
answers**: the caller has asked for the list back, so the next world entry or
roster may put it up.

**Errors**

| Code | Meaning | Counts? |
|---|---|---|
| `menu_not_running` | `opx77_menu` is not running; there is nothing to draw the list on. | no |
| `export_call_required` | The call did not come from another resource. | no |
| `busy` | A selection is with the server. | no |
| `in_world` | A character is loaded: the core sends no roster to a client that is already playing. | no |
| `no_roster` | None has arrived. `open` asks `opx77_core` for one on the way out, so the list comes up by itself. | **yes** |
| `world_not_ready` | The gameplay world is not up. The list goes up by itself when it is. | **yes** |

A refusal that **counts** is not a failure: the roster goes up without another
call, so a caller has nothing to retry. [`opx77_charcreator`](../opx77_charcreator/index.md)
treats both that way when it hands a player back.

**Side** `client export` — callable by any client resource through
`Open77.exports.call`. Asynchronous: it answers a promise, and `await` is only
usable inside a `CreateThread`.

### Example {#open-example}

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_charselector", "open")
  if not promise then return Open77.log.warn(tostring(reason)) end
  local answer, callError = promise:await()
  if callError then return Open77.log.warn(tostring(callError)) end
  if not answer.ok and answer.error ~= "no_roster" and
    answer.error ~= "world_not_ready" then
    Open77.log.warn("the roster refused: " .. tostring(answer.error))
  end
end)
```

## close {#close}

Takes the roster down, and the stage with it at once. The player is left wherever
the core put them, free to move: whoever closed the list has taken the player
somewhere else.

```lua
Open77.exports.call("opx77_charselector", "close")
```

Takes no arguments.

**Returns** [`SelectorResponse`](types.md#selectorresponse).

**Errors** `menu_not_running`, `export_call_required`, and `busy` while a
selection is with the server.

**Side** `client export` — as [`open`](#open).

## isOpen {#isopen}

Whether the roster is on the player's monitor right now: any phase but `idle`.
Never fails.

```lua
Open77.exports.call("opx77_charselector", "isOpen")
```

**Returns** [`SelectorOpen`](types.md#selectoropen).

**Errors** — none.

**Side** `client export` — as [`open`](#open).

## state {#state}

What this client knows. Never fails.

```lua
Open77.exports.call("opx77_charselector", "state")
```

**Returns** [`SelectorState`](types.md#selectorstate): `open`, `phase`,
`world` (whether the gameplay world is up, which the roster waits for),
`characters` and `slots` from the roster it holds, `citizenId` for the row the
cursor is on while the list is up, and the stage — `staged` (the camera is on the
character), `frozen` (the character is held) and `stageHolder`.

It is the first thing to read for a player who reports an empty screen: `world =
false` is the loading cover, `characters = 0, slots = 0` is a roster that never
arrived, and `phase = "busy"` is a selection the core has not answered.

**Errors** — none.

**Side** `client export` — as [`open`](#open).

## holdStage {#holdstage}

Keeps [the stage](stage.md) up while the caller has the player choosing without
the list — a creation form. Held until [`releaseStage`](#releasestage), a
character loading, or the caller stopping or reloading.

```lua
Open77.exports.call("opx77_charselector", "holdStage")
```

Takes no arguments; the holder is the invoking resource.

**Returns** [`SelectorStaged`](types.md#selectorstaged) — `ok = true` and
`staged`, which is `false` where [`STAGE.ENABLED`](config.md#stage-enabled) is
off. The hold is taken either way, so there is nothing for the caller to branch
on.

One holder at a time; a second hold replaces the first. Call it as soon as the
player is yours: after a creation is handed over the stage waits
[5 seconds](stage.md#handover) to be claimed.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not come from another resource. |
| `in_world` | A character is loaded. There is no stage once one is. |
| `world_not_ready` | The gameplay world is not up. |

**Side** `client export` — as [`open`](#open). It does not need `opx77_menu`.

## releaseStage {#releasestage}

Lets go of the caller's hold. The stage lingers
[1.5 seconds](stage.md#linger), so a roster the caller asked for just before takes
it over without the camera moving.

```lua
Open77.exports.call("opx77_charselector", "releaseStage")
```

**Returns** [`SelectorResponse`](types.md#selectorresponse).

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not come from another resource. |
| `not_holder` | The caller holds nothing — including after a character loaded, which ends every hold. That is not an error worth logging. |

**Side** `client export` — as [`open`](#open).

### Example {#releasestage-example}

The hand-back order a holder uses, so the camera does not move between its screen
and the list:

```lua
CreateThread(function()
  local function call(name)
    local promise = Open77.exports.call("opx77_charselector", name)
    if promise then return promise:await() end
  end
  call("open")          -- the roster first: it takes the stage over inside the linger
  call("releaseStage")  -- then let go; not_holder after a character loaded is normal
end)
```

## See also {#see-also}

- [The stage](stage.md) — what a hold keeps up, and when it goes regardless.
- [Events](events.md#create-requested) — the hand-over a holder listens for.
- [Types](types.md#selectorerror) — every code on this page.
