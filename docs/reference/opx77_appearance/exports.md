---
title: opx77_appearance exports
description: The twelve client exports opx77_appearance publishes — getSkin, captureSkin, getFamily, setSkin, saveSkin, openEditor, openCreator, isOpen, openPanel, closePanel, isSettled and state — with every error code each can answer, and why a write only ever means "asked for".
---

# Exports

`opx77_appearance` publishes twelve client exports. Every one answers a table
carrying `ok`, plus an `error` code when `ok` is `false`, and none of them
raises.

!!! info "Read the export contract first"
    There is no `exports.opx77_appearance:openEditor()` proxy. The only entry
    point is `Open77.exports.call`, it is always asynchronous, it answers a
    promise to be tested for presence, and failure reads at three levels. See
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
| [`openCreator`](#opencreator) | the in-world editor on the character's own body, for a character with no face |
| [`isOpen`](#isopen) | whether a native modal is on screen, and which one |

**This resource's own panel**

| Export | Does |
|---|---|
| [`openPanel`](#openpanel) | the appearance panel, as a list drawn by `opx77_menu` |
| [`closePanel`](#closepanel) | take your own panel back down |

**Where the session is**

| Export | Does |
|---|---|
| [`isSettled`](#issettled) | whether this world entry's appearance work has finished |
| [`state`](#state) | what this client knows, for a face that did not come back |

**Client-side only.** This resource publishes no server export: its one server
file hands looks out and registers nothing else. The clothing the character
wears has no export here either; `opx77_core` carries it in `PlayerData` — see
[What the character wears](index.md#clothing).

!!! warning "What moved, by version"

    **`0.4.0`** — the surface went from five exports to ten. `open` and `editor`
    became [`openEditor`](#openeditor), `current` became [`getSkin`](#getskin),
    and `barber` was **deleted**: a hairdresser's chair is
    `openEditor("hairdresser")`.

    **`0.5.0`** — [`openPanel`](#openpanel) and [`closePanel`](#closepanel) are
    new, and [`state`](#state) reports one more field, `panel`. The ten above
    them are unchanged.

    **`0.6.0`** — [`openCreator`](#opencreator) opens the in-world editor on the
    character's body rather than the pre-world vanilla creator, and no longer
    refuses with `bootstrap_already_spent`. [`isSettled`](#issettled) can answer
    `waiting = "body"` while the world reloads onto the character's body family.

    **`0.7.0`** — a body reload ends when its new puppet has been through its
    reset, so `waiting = "body"` lasts until then. [`state`](#state) reports
    `body` and `bodyReloading`.

    **`0.9.0`** — [`state`](#state) reports `clothing`, and the event channel
    carries `clothingRestored` and `clothingSaved`.

    **`0.10.0`** — [`isOpen`](#isopen), [`openEditor`](#openeditor) and
    [`openCreator`](#opencreator) no longer raise when the engine cannot say
    whether a native modal is up: `isOpen` answers `open = true` and the other
    two `appearance_busy`. No export was added or removed.

## It is a service, not a flow {#service}

This resource reads, applies, stores and edits the live character's face. It
never decides that a player should be sent to an editor: when the live character
has no stored face it publishes
[`needsCreation`](events.md#needs-creation) and waits for something to call
[`openCreator`](#opencreator). A character creator resource owns that decision —
[`opx77_charcreator`](../opx77_charcreator/index.md) on a stock install.

!!! info "A write answers that it was asked for"
    [`setSkin`](#setskin), [`saveSkin`](#saveskin), [`openEditor`](#openeditor),
    [`openCreator`](#opencreator) and [`openPanel`](#openpanel) all answer
    [`AppearanceQueued`](types.md#appearancequeued): `ok = true` means the call
    was accepted, never that the work is done. An export handler is not a
    coroutine, so nothing here can wait for the engine to schedule an apply, for
    `opx77_core` to validate a save, for a world to reload, or for a player to
    finish in a modal. The outcome arrives on
    [`opx77:appearance`](events.md#opx77-appearance) — see
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
    `gender` field of a snapshot, which is the engine's opaque body hash, and it
    is not necessarily the body the world loaded with at join: that was a guess
    made before any character was chosen, and the world is reloaded onto this
    value once the character is selected.

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
| `appearance_busy` | This resource's editor is open, or a creation is running — from [`openCreator`](#opencreator) to the core's answer. |
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

The save names the character live when the call was made. A character switch
during the cooldown wait makes the core refuse it with `appearance.stale`, which
arrives as `saved` with `ok = false`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_character` | No character is loaded on this client. |
| `appearance_busy` | A capture is already with the core, this resource's editor is open, or a creation is running. |
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
| `character_creation_in_progress` | A creation is running, from [`openCreator`](#opencreator) to the core's answer. Checked before the busy test, so the specific refusal is not hidden by the general one. |
| `appearance_busy` | This resource's editor is already open, the host reports a native modal on screen — or cannot say, because `Open77.appearance.isOpen()` raised — or a captured face is still with the core. |
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

This is also the way back for a character whose creation ended without a face:
it opens an editor on a character with no stored face, and the first confirm is
saved like any other capture.

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

Opens Cyberpunk's own mirror **in the world**, in `ripperdoc` mode, on the body
family the character was created with, for a character that has no face yet.
This is the call that answers [`needsCreation`](events.md#needs-creation), and
the outcome arrives on the event channel as `created`.

```lua
Open77.exports.call("opx77_appearance", "openCreator")
```

**Returns** [`AppearanceQueued`](types.md#appearancequeued) —
`{ ok = true, queued = true, citizenId = string }`

`ok = true` means the creation has begun. The editor itself comes up on a thread,
in three steps:

1. It waits for a puppet a face may go on: the gameplay world, not a body that
   is about to be replaced by a reload, and a player past the "continue" screen.
   The character's placement can still be putting the puppet back up.
2. When the puppet is on the other body family, it reloads the player with
   `Open77.appearance.switchBodyFamily(gender, true)`, tells the player
   `appearance.creatorSwitching`, and reopens the editor once
   `Open77.appearance.takeBodyFamilyTransition()` answers `edit:<gender>` on the
   other side of the reload. A reload that enters the world without that answer
   reopens the editor all the same, or the readiness gate would wait on it for
   ever. Each reload counts against
   [`FAMILY_RETRIES`](config.md#family-retries).
3. It opens `Open77.appearance.open({ mode = "ripperdoc", gender = gender })`.

A failure in any of them does **not** reach this return value: it ends the
creation, and the `created` event carries the reason — see
[What happens when a character never gets a face](index.md#no-face).

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_character` | No character is loaded on this client. |
| `appearance_busy` | A creation is already running, this resource's editor is open, the host reports a native modal on screen — or `Open77.appearance.isOpen()` raised — or a captured face is still with the core. |
| `creation_refused` | This character's creation already ended without a face. It is not reopened until the character changes or this resource restarts; [`openEditor`](#openeditor) still can. |
| `already_has_a_face` | The character has a stored face. Use [`openEditor`](#openeditor). |

The checks run in exactly that order.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! warning "There is no deadline on the editor"
    A player deliberating for an hour leaves the readiness gate closed for an
    hour, and that is deliberate. What **is** bounded is how long this resource
    waits for somebody to make this call: see
    [`CREATION_WAIT_MS`](config.md#creation-wait-ms). A call that comes after
    that wait ran out still opens the editor.

### Example {#opencreator-example}

```lua
-- a client script in your own resource: the needsCreation handshake
AddEventHandler("opx77:appearance", function(payload)
  if payload.event ~= "needsCreation" then return end
  -- payload.family is the body the editor opens on
  CreateThread(function()
    local promise = Open77.exports.call("opx77_appearance", "openCreator")
    local result = promise and promise:await()
    if result and not result.ok then print("refused: " .. tostring(result.error)) end
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
  resource did not raise. When `Open77.appearance.isOpen()` raises, the export
  still answers, with `open = true`: a modal that cannot be ruled out counts as
  on screen, as it does for the panel.
- `editing` and `creating` are this resource's own flags: the editor
  [`openEditor`](#openeditor) asked for, and a creation
  [`openCreator`](#opencreator) began. `creating` covers the whole creation, from
  the call to the core's answer, so it is `true` during a body reload and while a
  captured face is with the core, not only while the editor is on screen.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## openPanel {#openpanel}

Puts this resource's appearance panel on screen, drawn by
[`opx77_menu`](../opx77_menu/index.md): the saved look, the body family and the
two ways into the native editor. See [The panel](index.md#panel).

```lua
Open77.exports.call("opx77_appearance", "openPanel")
```

**Returns** [`AppearanceQueued`](types.md#appearancequeued) —
`{ ok = true, queued = true, citizenId = string }`

The list opens on a thread, and `panelOpened` is published on
[`opx77:appearance`](events.md#opx77-appearance) once `opx77_menu` has answered.
A menu that refuses on the way out costs one log line and no event:

```text
the appearance panel did not open: <reason>
```

The owner calling it again while its panel is up **redraws** its own panel and
answers the same; there is no level a caller can ask for, so a reopen is a
redraw.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `menu_not_running` | `opx77_menu` is not running; there is nothing to draw the list on. |
| `no_character` | No character is loaded on this client. |
| `appearance_busy` | A native modal is on screen, this resource's editor is open, or a creation is running. A raise from `Open77.appearance.isOpen()` counts as on screen. |
| `panel_busy` | Another resource owns the open panel — including this resource itself, when a player opened the panel with [the panel key](index.md#key). |

The checks run in exactly that order.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! info "It closes itself"
    The panel is taken down, and `panelClosed` published with a
    [reason](types.md#appearancepanelreason), when a native modal comes up, when
    its owner stops or reloads, when the character changes or unloads, and when
    the player leaves it — Escape, the pause key, BACK at the top, or
    [the panel key](index.md#key), which closes a panel whoever opened it. An
    owner that reads `starting` counts as running. Nobody has to remember to
    close it.

## closePanel {#closepanel}

Takes your own panel back down. A caller may not close another resource's.

```lua
Open77.exports.call("opx77_appearance", "closePanel")
```

**Returns** [`AppearanceResponse`](types.md#appearanceresponse) —
`{ ok = true }`

`panelClosed` is published with the reason `caller`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_panel_open` | No panel is on screen. |
| `not_owner` | The panel on screen belongs to another resource. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## isSettled {#issettled}

Whether the appearance work for this world entry has finished — restored,
created, or honestly failed — and, when it has not, what it is short of.
[`open77:session:gameplayReady`](events.md#gameplay-ready) goes out on exactly
this condition, and never before a character is loaded.

```lua
Open77.exports.call("opx77_appearance", "isSettled")
```

**Returns** [`AppearanceSettled`](types.md#appearancesettled) — `ok`, plus
`settled`, `announced`, `waiting` and `citizenId`.

| `waiting` | What the session is short of |
|---|---|
| `"creator"` | a creation is running: the editor, a body reload for it, or its capture with the core |
| `"creation"` | the character has no face and nothing has called [`openCreator`](#opencreator) yet |
| `"server"` | the face for this world entry has not been decided yet |
| `"body"` | the world is reloading onto the character's body family |
| `"restore"` | a restore is still in flight |
| `nil` | nothing that has a name; `settled` may still be `false` |

The names are tested in that order, and the first that applies is answered.

`waiting = nil` with `settled = false` is a session with no character loaded —
the announcement is never sent for one — or a queued restore still waiting on the
mirror's own confirmation and on `open77:playerReset:complete`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

!!! info "`settled` here and `settled` on `state` are the same value"
    Both are `OpxAppearance.State.AppearanceSettled()`. [`state`](#state) additionally carries
    `decided`, the coarser flag underneath it: `decided` says this world entry's
    face was decided, `settled` says every piece of work behind that decision has
    also finished. A queued apply is `decided = true`, `settled = false`.

## state {#state}

What this client knows: which character it is dressing, whether the stored face
is on the puppet, which of the two modals is open, which body the puppet is on,
whether the panel is up, what it is doing with the clothes, and whether the
readiness announcement has gone out. It exists to debug a face, or clothes, that
did not come back.

```lua
Open77.exports.call("opx77_appearance", "state")
```

**Returns** [`AppearanceClientState`](types.md#appearanceclientstate) —
`ok`, plus `citizenId`, `family`, `stored`, `wearing`, `decided`, `settled`,
`restoring`, `committing`, `creating`, `editing`, `worldEligible`, `announced`,
`body`, `bodyReloading`, `panel` and `clothing`.

`clothing` is one of `idle`, `waiting`, `restoring`, `worn`, `saving`, `unsaved`
and `failed` — see
[`AppearanceClothingPhase`](types.md#appearanceclothingphase).

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

The panel is the one thing on this surface that belongs to a caller: it is keyed
on that name and on `GetInvokingResourceGeneration()`, so a caller that stops or
reloads loses its panel within a second, while a caller still `starting` keeps
it. A panel the player opened with [the panel key](index.md#key) belongs to
`opx77_appearance` itself. Beyond it, and unlike
[`opx77_notify`](../opx77_notify/exports.md#ownership) and
[`opx77_status`](../opx77_status/exports.md#ownership), this resource keeps no
per-owner registry: it holds one face for one character, and that belongs to the
player rather than to the resource that asked for the modal.

## See also {#see-also}

- [Events](events.md) — where the answer to a write or a modal actually arrives.
- [Types](types.md) — every shape on this page, and every error code.
- [The client export contract](../../concepts/export-contract.md) — the three
  levels of failure this page's examples check.
