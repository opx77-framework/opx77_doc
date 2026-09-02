---
title: opx77_appearance exports
description: The five client exports opx77_appearance publishes — open, barber, isOpen, current and state — with every error code each can answer, why open only ever means "asked for", and why nothing on this surface writes a face.
---

# Exports

`opx77_appearance` publishes five client exports. Every one answers a table
carrying `ok`, plus an `error` code when `ok` is `false`, and none of them
raises.

!!! info "Read the export contract first"
    There is no `exports.opx77_appearance:open()` proxy. The only entry point is
    `Open77.exports.call`, it is always asynchronous, and failure reads at three
    levels. See [The client export contract](../../concepts/export-contract.md).

| Export | Does |
|---|---|
| [`open`](#open) | ask for the editor — `"ripperdoc"` or `"hairdresser"` |
| [`barber`](#barber) | the same call with the mode fixed |
| [`isOpen`](#isopen) | whether a native modal is on screen, and which one |
| [`current`](#current) | the stored face, as `PlayerData.appearance` carries it |
| [`state`](#state) | what this client knows, for a face that did not come back |

**Client-side only.** The OPEN//77 server runtime installs no export mechanism,
so there is nothing to call from a server resource — see
[`opx77_core`'s server exports page](../opx77_core/exports/server.md).

## There is no export that writes a face {#no-write}

Deliberately. A caller that could hand this resource a snapshot could hand it
somebody else's, and the only face this resource will ever send to the core is
one the player just built in the native mirror on their own screen.

The write channel is [`opx77:server:saveAppearance`](events.md#save-appearance),
and the core takes the character from the connection rather than from the
payload. Nothing on this page reaches it except by the player confirming a modal.

## open {#open}

Asks for the appearance editor on the live character, and answers that it was
**asked for** — not that the modal is on screen.

```lua
Open77.exports.call("opx77_appearance", "open", mode)
```

- mode: [`AppearanceMode`](types.md#appearancemode)`|nil`
    - `"ripperdoc"` or `"hairdresser"`. Lower-cased on the way in; `nil`
      defaults to `"ripperdoc"`; anything else is refused with `invalid_mode`.

**Returns** `table` — `{ ok = true, queued = true, citizenId = string }`

!!! warning "`ok = true` means asked, and the answer arrives elsewhere"
    An export handler is not a coroutine, so nothing here could wait for a
    player to finish in a modal. What becomes of the face arrives later on
    [`opx77:appearance`](events.md#opx77-appearance) — `saved`, or `saved` with
    an `error`. There is no callback channel on this platform; see
    [Integration channels](../../concepts/integration-channels.md#local-events).

    A modal that then fails to open at all is reported **only** as a toast
    (`appearance.editorUnavailable`) and a log line. No event is published for
    it, so a caller cannot learn about that case from the event channel.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus, so the owner could not be read from the host. |
| `invalid_mode` | `mode` is neither `"ripperdoc"` nor `"hairdresser"`. |
| `character_creation_in_progress` | The character creator is on screen. Checked before the busy test, so the specific refusal is not hidden by the general one. |
| `appearance_busy` | This resource's editor is already open, or the host reports a native modal on screen. |
| `no_character` | `opx77_core` has no character loaded on this client. |

The checks run in exactly that order.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It needs no permission.

!!! info "It cannot change the body family"
    No gender is ever passed to the native editor. The body family is
    `charInfo.gender` on the character row and `opx77_core` owns it — see
    [Who owns the body family](index.md#body-family).

A character whose stored face is missing, or is from a build
[`GAME_BUILDS`](config.md#game-builds) does not accept, is warned with
`appearance.editorDefaultFace` **before** the mirror appears: an editor that
silently opens on the default face reads as a wiped character.

### Example {#open-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_appearance", "open", "ripperdoc")
  if not promise then return print("not dispatched: " .. tostring(reason)) end

  local result, callError = promise:await()
  if callError then return print("call failed: " .. tostring(callError)) end
  if not result.ok then return print("refused: " .. tostring(result.error)) end

  print("editor asked for, on " .. tostring(result.citizenId))
end)

-- the outcome arrives here, not above
AddEventHandler("opx77:appearance", function(payload)
  if payload.event ~= "saved" then return end
  if payload.ok then return print("stored") end
  print("refused: " .. tostring(payload.error))
end)
```

## barber {#barber}

The hairdresser's chair: [`open`](#open) with the mode fixed to
`"hairdresser"`, so a prop that only ever cuts hair has no mode argument to get
wrong.

```lua
Open77.exports.call("opx77_appearance", "barber")
```

**Returns** `table` — `{ ok = true, queued = true, citizenId = string }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `character_creation_in_progress` | The character creator is on screen. |
| `appearance_busy` | An editor or a native modal is already up. |
| `no_character` | No character is loaded on this client. |

`invalid_mode` cannot occur: the mode is not a parameter.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## isOpen {#isopen}

Whether a native appearance modal is on screen right now, and whether it is one
of this resource's two.

```lua
Open77.exports.call("opx77_appearance", "isOpen")
```

**Returns** [`AppearanceOpenState`](types.md#appearanceopenstate) —
`{ ok = true, open = boolean, editing = boolean, creating = boolean }`

- `open` is the host's own answer, so it is `true` for a native modal this
  resource did not raise.
- `editing` and `creating` are this resource's own flags: the editor
  [`open`](#open) asked for, and the character creator.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## current {#current}

The stored face for the live character, exactly as `PlayerData.appearance`
carries it. It is what `opx77_core` holds, **not** a capture of the puppet.

```lua
Open77.exports.call("opx77_appearance", "current")
```

**Returns** [`AppearanceCurrent`](types.md#appearancecurrent) — `ok`, plus
`citizenId`, `family` and `snapshot`.

`snapshot` is `nil` for a character that has never had a face captured, and
`family` is `nil` when `charInfo` carried none.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_character` | No character is loaded on this client. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! info "The core answers the same question"
    `opx77_core` publishes a `GetAppearance` client export that reads the same
    mirrored `PlayerData.appearance`. Use whichever resource you already depend
    on; neither reaches the database from the client.

## state {#state}

What this client knows: which character it is dressing, whether the stored face
is on the puppet, which of the two modals is open, and whether the readiness
announcement has gone out. It exists to debug a face that did not come back.

```lua
Open77.exports.call("opx77_appearance", "state")
```

**Returns** [`AppearanceClientState`](types.md#appearanceclientstate) —
`ok`, plus `citizenId`, `family`, `stored`, `wearing`, `settled`, `restoring`,
`committing`, `creating`, `editing`, `worldEligible` and `announced`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! warning "It is a report, not an authority"
    Every field is one client's own view, sampled at the moment of the call, and
    nothing in it is proof of anything to a server. `announced = true` says this
    client sent [`open77:session:gameplayReady`](events.md#gameplay-ready), not
    that the platform accepted it.

### Example {#state-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise = Open77.exports.call("opx77_appearance", "state")
  if not promise then return end
  local result, callError = promise:await()
  if callError or not result.ok then return end

  if result.stored and not result.wearing then
    print("a face is held for " .. tostring(result.citizenId) ..
      " and is not on the puppet")
  end
end)
```

## The caller is taken from the host {#invoking-resource}

Every export begins by asking the host who is calling:

```lua
local owner = GetInvokingResource()
```

It is not a parameter, and there is no parameter anywhere on this surface that
would let you name another resource or another character. A name the host cannot
answer for — or one that is empty, over 64 characters, or outside
`^[%w_%-%.]+$` — is refused with `export_call_required` and nothing is touched.
Nothing inside this resource's own VM reaches the public surface, so a call with
no invoking resource went somewhere by mistake. See
[Identity comes from the host](../../concepts/export-contract.md#invoking-resource).

Unlike [`opx77_notify`](../opx77_notify/exports.md#ownership) and
[`opx77_status`](../opx77_status/exports.md#ownership), this resource keeps no
per-owner registry and has nothing to sweep when a caller stops: it holds one
face for one character, and it belongs to the player rather than to the resource
that asked for the modal.

## See also {#see-also}

- [Events](events.md) — where the answer to an [`open`](#open) actually arrives.
- [Types](types.md) — every shape on this page, and every error code.
- [The client export contract](../../concepts/export-contract.md) — the three
  levels of failure this page's examples check.
