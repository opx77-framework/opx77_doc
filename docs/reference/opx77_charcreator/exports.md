---
title: opx77_charcreator exports
description: The four client exports opx77_charcreator publishes — open, close, isOpen and state — with what each answers, every code each refuses with, and why the outcome of a creation never arrives in a return value.
---

# Exports

`opx77_charcreator` publishes four exports, all **client** exports. Every one
answers `{ ok = boolean, error = string|nil }` and **never raises**; `error` is a
stable code, never player-facing text. See
[The client export contract](../../concepts/export-contract.md) for the call
shape and the three levels of failure.

| Export | Answers | Does |
|---|---|---|
| [`open`](#open) | [`CreatorResponse`](types.md#creatorresponse) | Starts the flow: puts the form up on a blank character. |
| [`close`](#close) | [`CreatorResponse`](types.md#creatorresponse) | Ends it without a character, and hands the player back to the roster. |
| [`isOpen`](#isopen) | [`CreatorOpen`](types.md#creatoropen) | Whether a character is being built right now. |
| [`state`](#state) | [`CreatorState`](types.md#creatorstate) | What this client knows, for a creation that did not come back. |

**A stock install calls none of them.** `opx77_charselector` reaches the same
path through its [`createRequested`](../opx77_charselector/events.md#create-requested)
event. They exist for a resource that starts a creation from somewhere else — a
command, an NPC, a registrar's desk.

The caller is read from `GetInvokingResource()`. A call that did not arrive
through the export mechanism answers `export_call_required`.

## open {#open}

Starts the flow. Answers that the flow was **started**: the form opens on a
thread, and the outcome arrives on [the event channel](events.md), never in the
return value — a creation takes as long as the player deliberates, and a promise
that waited for it would hold the caller's coroutine that long.

```lua
Open77.exports.call("opx77_charcreator", "open", context)
```

- context?: [`CreatorContext`](types.md#creatorcontext)
    - `{ slot, used, slots }`, used only to write the line above the fields —
      *"Slot 2 of 3. None of this can be changed later."* Omitted, the line
      reads *"None of this can be changed later."*

**Returns** [`CreatorResponse`](types.md#creatorresponse).

The flow holds `opx77_charselector`'s stage, reads the lifepaths and name bounds
from `opx77_core` if it has not yet, and puts the form up. A flow that cannot —
no lifepath readable, or a form `opx77_input` refused — ends as `cancelled` and
hands the player back to the roster.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not come from another resource. |
| `busy` | A flow is already running. |
| `in_world` | A character is loaded: there is nothing to create into. |
| `input_not_running` | `opx77_input` is not running; there is no form to draw. |

**Side** `client export` — callable by any client resource through
`Open77.exports.call`. Asynchronous: it answers a promise, and `await` is only
usable inside a `CreateThread`.

### Example {#open-example}

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_charcreator", "open",
    { slot = 2, used = 1, slots = 3 })
  if not promise then return Open77.log.warn(tostring(reason)) end
  local answer, callError = promise:await()
  if callError or not answer.ok then
    return Open77.log.warn("creation refused: " .. tostring(callError or answer.error))
  end
end)

AddEventHandler("opx77:charcreator", function(payload)
  if type(payload) ~= "table" then return end
  if payload.event == "created" and payload.ok then
    Open77.log.info("new character " .. tostring(payload.citizenId))
  end
end)
```

## close {#close}

Ends the flow without a character. The open form is taken down, `cancelled` is
published with `reason = "closed by <caller>"`, and the roster goes back up — a
player with no character loaded has nowhere else to be.

```lua
Open77.exports.call("opx77_charcreator", "close")
```

Takes no arguments.

**Returns** [`CreatorResponse`](types.md#creatorresponse).

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not come from another resource. |
| `busy` | A registration is with `opx77_core`. It cannot be recalled, and its answer is on the way. |
| `not_open` | No flow is running. |

**Side** `client export` — as [`open`](#open).

## isOpen {#isopen}

Whether a character is being built right now: any phase but `idle`. Never fails.

```lua
Open77.exports.call("opx77_charcreator", "isOpen")
```

**Returns** [`CreatorOpen`](types.md#creatoropen).

**Errors** — none.

**Side** `client export` — as [`open`](#open).

## state {#state}

What this client knows, for a creation that did not come back. Never fails.

```lua
Open77.exports.call("opx77_charcreator", "state")
```

**Returns** [`CreatorState`](types.md#creatorstate): `open`, `phase`, the `slot`
the form was opened for, `attempts` (how many times the form has been put up
this flow), `origins` (how many lifepaths `opx77_core` has answered with) and
`inputReady`.

It **never reports what the player has typed**: the answer is the character, and
there is no second way to read a half-built one. `origins = 0` is a core that
could not be asked for the lifepaths, and `inputReady = false` a form that cannot
be drawn.

**Errors** — none.

**Side** `client export` — as [`open`](#open).

## See also {#see-also}

- [Events](events.md) — where the outcome of every flow arrives.
- [Types](types.md#creatorerror) — every code on this page.
