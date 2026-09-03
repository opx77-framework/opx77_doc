---
title: opx77_appearance exports
description: The ten client exports opx77_appearance publishes — getSkin, captureSkin, getFamily, setSkin, saveSkin, openEditor, openCreator, isOpen, isSettled and state — with every error code each can answer, and why a write only ever means "asked for".
---

# Exports

`opx77_appearance` publishes ten client exports. Every one answers a table
carrying `ok`, plus an `error` code when `ok` is `false`, and none of them
raises.

!!! info "Read the export contract first"
    There is no `exports.opx77_appearance:openEditor()` proxy. The only entry
    point is `Open77.exports.call`, it is always asynchronous, and failure reads
    at three levels. See
    [The client export contract](../../concepts/export-contract.md).

**Reading a face**

| Export | Does |
|---|---|
| [`getSkin`](#getskin) | the stored face for the live character, as `opx77_core` holds it |
| [`captureSkin`](#captureskin) | what the puppet is wearing right now, ready to hand back |
| [`getFamily`](#getfamily) | the character's body family, `"female"` or `"male"` |

**Writing a face**

| Export | Does |
|---|---|
| [`setSkin`](#setskin) | put a face on the puppet; stores nothing |
| [`saveSkin`](#saveskin) | store one through `opx77_core`; defaults to a capture |

**The native modals**

| Export | Does |
|---|---|
| [`openEditor`](#openeditor) | the native mirror — `"ripperdoc"` or `"hairdresser"` |
| [`openCreator`](#opencreator) | the vanilla character creator, for a character with no face |
| [`isOpen`](#isopen) | whether a native modal is on screen, and which one |

**Where the session is**

| Export | Does |
|---|---|
| [`isSettled`](#issettled) | whether this world entry's appearance work has finished |
| [`state`](#state) | what this client knows, for a face that did not come back |

**Client-side only.** The OPEN//77 server runtime installs no export mechanism,
so there is nothing to call from a server resource — see
[`opx77_core`'s server exports page](../opx77_core/exports/server.md).

!!! warning "Renamed in `0.4.0`"

    The surface was five exports and is now ten. `open` and `editor` became
    [`openEditor`](#openeditor), `current` became [`getSkin`](#getskin), and
    `barber` was **deleted** — a hairdresser's chair is
    `openEditor("hairdresser")`, which is the same call with the argument
    written out. Six exports on this page are new.

## It is a service, not a flow {#service}

This resource reads, applies, stores and edits the live character's face. It
never decides that a player should be sent to a creator: when the live character
has no stored face it publishes
[`needsCreation`](events.md#opx77-appearance) and waits for something to call
[`openCreator`](#opencreator). A character selector or a character creator
resource owns that decision.

!!! info "A write answers that it was asked for"
    [`setSkin`](#setskin), [`saveSkin`](#saveskin), [`openEditor`](#openeditor)
    and [`openCreator`](#opencreator) all answer
    [`AppearanceQueued`](types.md#appearancequeued): `ok = true` means the call
    was accepted, never that the work is done. An export handler is not a
    coroutine, so nothing here can wait for the engine to schedule an apply, for
    `opx77_core` to validate a save, or for a player to finish in a modal. The
    outcome arrives on [`opx77:appearance`](events.md#opx77-appearance) — see
    [Integration channels](../../concepts/integration-channels.md#local-events).

## getSkin {#getskin}

The stored face for the live character, exactly as `PlayerData.appearance`
carries it. It is what `opx77_core` holds, **not** a capture of the puppet —
[`captureSkin`](#captureskin) answers that.

```lua
Open77.exports.call("opx77_appearance", "getSkin")
```

**Returns** [`AppearanceSkin`](types.md#appearanceskin) — `ok`, plus
`citizenId`, `family` and `snapshot`.

`snapshot` is `nil` for a character that has never had a face captured, and
`family` is `nil` when `charInfo` carried none.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus, so the owner could not be read from the host. |
| `no_character` | No character is loaded on this client. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! info "The core answers the same question"
    `opx77_core` publishes a `GetAppearance` client export that reads the same
    mirrored `PlayerData.appearance`. Use whichever resource you already depend
    on; neither reaches the database from the client.

## captureSkin {#captureskin}

What the puppet is wearing **right now**, in canonical form and ready to hand
straight back to [`setSkin`](#setskin) or [`saveSkin`](#saveskin). It reads the
engine, so it answers nothing useful before the world has loaded.

```lua
Open77.exports.call("opx77_appearance", "captureSkin")
```

**Returns** [`AppearanceCapture`](types.md#appearancecapture) — `ok`, plus
`snapshot` and `citizenId`.

The payload is the five fields that *are* a face — `schemaVersion`,
`gameBuild`, `catalogDigest`, `gender` and `options` — with the host's
editor-only metadata stripped, because the runtime's value codec will not carry
it.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `capture_failed` | The engine would not answer what the puppet is wearing. |
| `invalid_snapshot` | The native capture is not a snapshot. |
| `invalid_option` | An entry of the option list is not a table. |
| `invalid_option_name` | An option name is not a string. |

It does **not** answer `no_character`: it reads the engine rather than the
character, and `citizenId` is `nil` when none is loaded.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## getFamily {#getfamily}

The body family of the live character — `"female"` or `"male"`.

```lua
Open77.exports.call("opx77_appearance", "getFamily")
```

**Returns** [`AppearanceFamily`](types.md#appearancefamily) — `ok`, plus
`family` and `citizenId`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_character` | No character is loaded on this client. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! info "It is the core's value, and nothing here can change it"
    The family is `charInfo.gender` on the character row and `opx77_core` owns
    it — see [Who owns the body family](index.md#body-family). It is **not** the
    `gender` field of a snapshot, which is the engine's opaque body hash.

## setSkin {#setskin}

Puts a snapshot on the puppet. **Nothing is stored** —
[`saveSkin`](#saveskin) is what persists a face.

```lua
Open77.exports.call("opx77_appearance", "setSkin", snapshot)
```

- snapshot: [`AppearanceSnapshot`](types.md#appearancesnapshot)
    - A face in the form this resource sends and the core stores. A
      [`captureSkin`](#captureskin) answer can be handed straight back.

**Returns** [`AppearanceQueued`](types.md#appearancequeued) —
`{ ok = true, queued = true, citizenId = string }`

The apply gets eight attempts, 400 ms apart, and the outcome is published on
[`opx77:appearance`](events.md#opx77-appearance) as `applied`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_character` | No character is loaded on this client. |
| `appearance_busy` | This resource's editor or its character creator is on screen. |
| `invalid_snapshot` | `snapshot` is not a snapshot. |
| `invalid_option` | An entry of the option list is not a table. |
| `invalid_option_name` | An option name is not a string. |
| `stored_build_mismatch` | The snapshot's `gameBuild` is not one [`GAME_BUILDS`](config.md#game-builds) accepts. |

The checks run in exactly that order.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## saveSkin {#saveskin}

Stores a face on the live character **through `opx77_core`**, defaulting to a
capture of the puppet when no snapshot is given.

```lua
Open77.exports.call("opx77_appearance", "saveSkin")            -- capture and store
Open77.exports.call("opx77_appearance", "saveSkin", snapshot)  -- store this one
```

- snapshot?: [`AppearanceSnapshot`](types.md#appearancesnapshot)`|nil`
    - Defaults to a capture of the puppet.

**Returns** [`AppearanceQueued`](types.md#appearancequeued) —
`{ ok = true, queued = true, citizenId = string }`

The outcome arrives on [`opx77:appearance`](events.md#opx77-appearance) as
`saved`. A face identical to the stored one is answered by the core with
**silence**, so this resource completes that case itself and publishes `saved`
with `unchanged = true`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_character` | No character is loaded on this client. |
| `appearance_busy` | A capture is already with the core, or a modal of this resource's is on screen. |
| `capture_failed` | The engine would not answer what the puppet is wearing. |
| `invalid_snapshot`, `invalid_option`, `invalid_option_name` | The snapshot given, or the capture taken, is not a face. |
| `stored_build_mismatch` | The `gameBuild` is not one [`GAME_BUILDS`](config.md#game-builds) accepts. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! warning "It stores whatever it is handed"
    Nothing here checks that the snapshot came off this player's own puppet. The
    decision that has to be unforgeable — whether a face may be written to the
    character row — is `opx77_core`'s, made in its server VM from the connection
    rather than from the payload. See
    [`opx77:server:saveAppearance`](events.md#save-appearance).

### Example {#saveskin-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise = Open77.exports.call("opx77_appearance", "captureSkin")
  local result = promise and promise:await()
  if not (result and result.ok) then return end

  Open77.exports.call("opx77_appearance", "saveSkin", result.snapshot)
end)

-- the outcome arrives here, not above
AddEventHandler("opx77:appearance", function(payload)
  if payload.event ~= "saved" then return end
  if payload.ok then return print(payload.unchanged and "unchanged" or "stored") end
  print("refused: " .. tostring(payload.error))
end)
```

## openEditor {#openeditor}

Asks for the native appearance editor on the live character, and answers that it
was **asked for** — not that the modal is on screen.

```lua
Open77.exports.call("opx77_appearance", "openEditor", mode)
```

- mode?: [`AppearanceMode`](types.md#appearancemode)`|nil`
    - `"ripperdoc"` or `"hairdresser"`. Lower-cased on the way in; `nil`
      defaults to `"ripperdoc"`; anything else is refused with `invalid_mode`.

**Returns** [`AppearanceQueued`](types.md#appearancequeued) —
`{ ok = true, queued = true, citizenId = string }`

What becomes of the face arrives later on
[`opx77:appearance`](events.md#opx77-appearance) as `saved`, when the player
confirms the modal.

A modal that then fails to open at all is reported **only** as a toast
(`appearance.editorUnavailable`) and a log line. No event is published for it,
so a caller cannot learn about that case from the event channel.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `invalid_mode` | `mode` is neither `"ripperdoc"` nor `"hairdresser"`. |
| `character_creation_in_progress` | The character creator is on screen. Checked before the busy test, so the specific refusal is not hidden by the general one. |
| `appearance_busy` | This resource's editor is already open, the host reports a native modal on screen, or a captured face is still with the core. |
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

### Example {#openeditor-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise, reason =
    Open77.exports.call("opx77_appearance", "openEditor", "hairdresser")
  if not promise then return print("not dispatched: " .. tostring(reason)) end

  local result, callError = promise:await()
  if callError then return print("call failed: " .. tostring(callError)) end
  if not result.ok then return print("refused: " .. tostring(result.error)) end

  print("editor asked for, on " .. tostring(result.citizenId))
end)
```

## openCreator {#opencreator}

Opens the vanilla character creator for a character that has no face yet. This
is the call that answers [`needsCreation`](events.md#opx77-appearance), and the
outcome arrives on the event channel as `created`.

```lua
Open77.exports.call("opx77_appearance", "openCreator")
```

**Returns** [`AppearanceQueued`](types.md#appearancequeued) —
`{ ok = true, queued = true, citizenId = string }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_character` | No character is loaded on this client. |
| `appearance_busy` | The creator is already up, this resource's editor is open, or the host reports a native modal on screen. |
| `creation_refused` | This character's creator run already ended for good. It is not reopened until the character changes or this resource restarts. |
| `already_has_a_face` | The character has a stored face. Use [`openEditor`](#openeditor). |
| `bootstrap_already_spent` | The one-shot character bootstrap has been resolved, so the world is already loaded and there is no menu for the creator to run inside. |
| `character_creator_unavailable` | The engine would not open the creator. |

The checks run in exactly that order.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! warning "There is no deadline on the creator"
    A player deliberating for an hour leaves the readiness gate closed for an
    hour, and that is deliberate. What **is** bounded is how long this resource
    waits for somebody to make this call: see
    [`CREATION_WAIT_MS`](config.md#creation-wait-ms).

### Example {#opencreator-example}

```lua
-- a client script in your own resource: the needsCreation handshake
AddEventHandler("opx77:appearance", function(payload)
  if payload.event ~= "needsCreation" then return end
  -- payload.family is the body the creator must come back on
  CreateThread(function()
    Open77.exports.call("opx77_appearance", "openCreator")
  end)
end)
```

## isOpen {#isopen}

Whether a native appearance modal is on screen right now, and whether it is one
of this resource's two. The call an interaction resource makes before offering a
prompt.

```lua
Open77.exports.call("opx77_appearance", "isOpen")
```

**Returns** [`AppearanceOpenState`](types.md#appearanceopenstate) —
`{ ok = true, open = boolean, editing = boolean, creating = boolean }`

- `open` is the host's own answer, so it is `true` for a native modal this
  resource did not raise.
- `editing` and `creating` are this resource's own flags: the editor
  [`openEditor`](#openeditor) asked for, and the character creator
  [`openCreator`](#opencreator) asked for.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## isSettled {#issettled}

Whether the appearance work for this world entry has finished — restored,
created, or honestly failed — and, when it has not, what it is short of.
[`open77:session:gameplayReady`](events.md#gameplay-ready) goes out on exactly
this condition.

```lua
Open77.exports.call("opx77_appearance", "isSettled")
```

**Returns** [`AppearanceSettled`](types.md#appearancesettled) — `ok`, plus
`settled`, `announced`, `waiting` and `citizenId`.

| `waiting` | What the session is short of |
|---|---|
| `"creator"` | the character creator is on screen |
| `"creation"` | the character has no face and nothing has called [`openCreator`](#opencreator) |
| `"server"` | the face for this world entry has not been decided yet |
| `"restore"` | a restore is still in flight |
| `nil` | nothing; `settled` is `true` |

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! info "`settled` here and `settled` on `state` are the same value"
    Both are `State.appearanceSettled()`. [`state`](#state) additionally carries
    `decided`, the coarser flag underneath it: `decided` says this world entry's
    face was decided, `settled` says every piece of work behind that decision has
    also finished. A queued apply is `decided = true`, `settled = false`.

## state {#state}

What this client knows: which character it is dressing, whether the stored face
is on the puppet, which of the two modals is open, and whether the readiness
announcement has gone out. It exists to debug a face that did not come back.

```lua
Open77.exports.call("opx77_appearance", "state")
```

**Returns** [`AppearanceClientState`](types.md#appearanceclientstate) —
`ok`, plus `citizenId`, `family`, `stored`, `wearing`, `decided`, `settled`,
`restoring`, `committing`, `creating`, `editing`, `worldEligible` and
`announced`.

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

- [Events](events.md) — where the answer to a write or a modal actually arrives.
- [Types](types.md) — every shape on this page, and every error code.
- [The client export contract](../../concepts/export-contract.md) — the three
  levels of failure this page's examples check.
