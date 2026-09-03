---
title: opx77_appearance types
description: Every shape opx77_appearance names — the aliases, the snapshot it captures and sends, the response tables its ten exports answer with, the payload its event channel carries, and where each error code can surface.
---

# Types

`opx77_appearance` ships its annotations in `types.lua`, a `---@meta` file that
is never loaded at runtime. The shapes below are what those annotations
describe.

The snapshot itself is **not this resource's shape**: `opx77_core` defines it,
validates it and stores it, and what is written here is the client's view of the
same table. Where the two pages differ, the core's is the contract — see
[`AppearanceSnapshot`](../opx77_core/types.md#appearancesnapshot).

## Aliases {#aliases}

### CitizenId {#citizenid}

The character this resource is dressing: `opx77_core`'s own character id, in the
grouped form `"H7K-M4X3"`.

```lua
---@alias CitizenId string
```

Issued by the core and carried in `PlayerData`. This resource never derives one
and never sends one — see [`CitizenId`](../opx77_core/types.md#citizenid).

### BodyFamily {#bodyfamily}

The character's body type.

```lua
---@alias BodyFamily "female"|"male"
```

It is `charInfo.gender` on the character row, and the engine's two pristine
puppets. **The core owns it**, this resource only reads it, and the value is what
the engine's character bootstrap is resolved with.

!!! danger "Not the `gender` field of a snapshot"
    A snapshot's `gender` is the **engine's** opaque body-family hash, `"0x"` and
    16 hex digits. These two are never interchangeable, and no code in this
    resource converts between them.

### AppearanceMode {#appearancemode}

Which editor [`openEditor`](exports.md#openeditor) asks for.

```lua
---@alias AppearanceMode "ripperdoc"|"hairdresser"
```

Lower-cased on the way in; `nil` means `"ripperdoc"`; anything else is refused
with `invalid_mode`. There is no second export for the second value: a
hairdresser's chair calls `openEditor("hairdresser")`.

### AppearanceError {#appearanceerror}

Why something was refused. Codes this resource decides are hints; codes from
`opx77_core` are locale keys, and this resource's catalogue carries all six of
them so they can be shown in the player's language.

**Decided here**

| Code | Meaning | Where it surfaces |
|---|---|---|
| `export_call_required` | No invoking resource, so the call came from inside this VM. | every export |
| `no_character` | `opx77_core` has no character loaded here. | [`getSkin`](exports.md#getskin), [`getFamily`](exports.md#getfamily), [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin), [`openEditor`](exports.md#openeditor), [`openCreator`](exports.md#opencreator) |
| `appearance_busy` | A modal is on screen, or a capture is with the core. | [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin), [`openEditor`](exports.md#openeditor), [`openCreator`](exports.md#opencreator) |
| `character_creation_in_progress` | The character is still being built. | [`openEditor`](exports.md#openeditor) |
| `invalid_mode` | Not `"ripperdoc"` or `"hairdresser"`. | [`openEditor`](exports.md#openeditor) |
| `already_has_a_face` | [`openCreator`](exports.md#opencreator) on a character that has a stored face. | [`openCreator`](exports.md#opencreator) |
| `bootstrap_already_spent` | [`openCreator`](exports.md#opencreator) after the world has already loaded. | [`openCreator`](exports.md#opencreator) |
| `creation_refused` | This character's creator run ended for good. | [`openCreator`](exports.md#opencreator) |
| `character_creator_unavailable` | The engine would not open the creator. | [`openCreator`](exports.md#opencreator) |
| `capture_failed` | The engine would not answer what the puppet is wearing. | [`captureSkin`](exports.md#captureskin), [`saveSkin`](exports.md#saveskin); a toast |
| `not_sent` | The net event was not accepted. | the `created` and `saved` events |
| `save_timeout` | The core never answered a captured face. | the `created` event; a toast on an edit |
| `invalid_snapshot` | The capture, or the snapshot given, is not a snapshot. | [`captureSkin`](exports.md#captureskin), [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin); a toast |
| `invalid_option` | An entry of the option list is not a table. | the same |
| `invalid_option_name` | An option name is not a string. | the same |
| `stored_build_mismatch` | The face is from another game build. | [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin); the `settled` event |
| `body_family_mismatch` | The creator came back on the other body. | the `created` event |
| `character_bootstrap_failed` | The host would not load a world for this body. | the `created` event |

**Decided by `opx77_core`**

| Code | Meaning |
|---|---|
| `appearance.invalid` | The core could not read the snapshot. |
| `appearance.tooLarge` | The encoded JSON is over the core's limit. |
| `error.badRequest` | The payload was not a table. |
| `error.notLoggedIn` | No character loaded on the core for this connection. |
| `error.tooFast` | Two saves inside the core's 2000 ms cooldown. |
| `error.unavailable` | The core's storage layer refused the write. |

!!! info "A failed restore carries a code from neither list"
    The `error` on a `restored` event is whatever the host's own apply answered —
    `restore_timeout` when the attempts ran out, or one of the reasons the host
    reports. Those strings are the platform's and are not enumerated in
    `types.lua`; treat them as opaque and log them rather than branching on them.

### AppearanceEventName {#appearanceeventname}

Which of this resource's decisions an [event](events.md#opx77-appearance)
reports.

```lua
---@alias AppearanceEventName
---| "gameplayReady" | "restored" | "settled" | "needsCreation"
---| "applied" | "created" | "saved" | "characterChanged"
```

| Name | The decision |
|---|---|
| `gameplayReady` | The readiness announcement went out; the player may be placed. |
| `restored` | A stored face was put on the puppet, or could not be. |
| `settled` | This world entry's face was decided, and there is none to wear. |
| `needsCreation` | This character has no face; call [`openCreator`](exports.md#opencreator) to open one. |
| `applied` | [`setSkin`](exports.md#setskin) reached the puppet, or could not. |
| `created` | A character was built and stored, or was not. |
| `saved` | An edit was committed, or was refused. |
| `characterChanged` | The live character switched underneath this resource. |

Which `ok` each carries, and which of them are only ever failures, is on
[Events](events.md#opx77-appearance).

## The face {#face}

### AppearanceOption {#appearanceoption}

One logical customization option: a position in the catalogue, not a mesh.

**Fields**

- part: `"head"|"body"|"arms"`
- name: `string`
    - An opaque 64-bit catalogue hash, `"0x"` and 16 hex digits, lower-cased.
      This resource lower-cases it when building the payload as well as the core
      canonicalising it, so a fresh capture can be compared field for field with
      a face the core has already stored.
- value: `integer` — the chosen index, 0-based.
- choices: `integer` — how many that option has; `0` means the engine reported
  none.

The bounds — 0 to 511 for `value`, 0 to 512 for `choices`, uniqueness of
`part` + `name` — are the core's and are enforced there. See
[`AppearanceOption`](../opx77_core/types.md#appearanceoption).

### AppearanceSnapshot {#appearancesnapshot}

A whole face, in the form `opx77_core` stores and this resource sends.

**Fields**

- schemaVersion: `integer` — always `1`.
- gameBuild: `string` — the build it was captured on, `"2.31"` as shipped. Read
  back only into a build [`GAME_BUILDS`](config.md#game-builds) accepts.
- catalogDigest: `string` — 64 lower-case hex characters: which catalogue those
  indices index.
- gender: `string` — the **engine's** opaque body hash, never
  `"female"`/`"male"`.
- options: [`AppearanceOption[]`](#appearanceoption)

The payload this resource sends is these five fields and nothing else: the
editor-only metadata the host's capture carries is stripped, because the
runtime's value codec will not carry it.

Two snapshots are treated as the same face when `gameBuild`, `catalogDigest`,
`gender`, the option count, and every option's `part`, `name` and `value` match.
`choices` is deliberately outside that comparison — it describes the catalogue,
not the choice. The comparison is what skips an apply the puppet does not need,
and a save the core would answer with silence.

## What the exports answer {#responses}

### AppearanceResponse {#appearanceresponse}

The shape every export answers with. None of them raises.

**Fields**

- ok: `boolean`
- error: [`AppearanceError`](#appearanceerror)`|nil` — present only when `ok` is
  `false`.

### AppearanceQueued {#appearancequeued}

What a write or a modal call answers: that it was **asked for**, never that it
has happened. [`setSkin`](exports.md#setskin),
[`saveSkin`](exports.md#saveskin), [`openEditor`](exports.md#openeditor) and
[`openCreator`](exports.md#opencreator) all answer this shape.

Extends [`AppearanceResponse`](#appearanceresponse)

**Fields**

- queued: `boolean|nil` — `true` means **asked**, never "it is done".
- citizenId: [`CitizenId`](#citizenid)`|nil`

Renamed from `AppearanceOpenResult` in `0.4.0`, because it is no longer only the
modals that answer it.

### AppearanceCapture {#appearancecapture}

What [`captureSkin`](exports.md#captureskin) answers: the puppet as it is right
now, canonical and ready to hand straight back to
[`setSkin`](exports.md#setskin) or [`saveSkin`](exports.md#saveskin).

Extends [`AppearanceResponse`](#appearanceresponse)

**Fields**

- snapshot: [`AppearanceSnapshot`](#appearancesnapshot)`|nil`
- citizenId: [`CitizenId`](#citizenid)`|nil` — `nil` when no character is
  loaded, which is not itself a refusal: this export reads the engine rather
  than the character.

### AppearanceFamily {#appearancefamily}

What [`getFamily`](exports.md#getfamily) answers.

Extends [`AppearanceResponse`](#appearanceresponse)

**Fields**

- family: [`BodyFamily`](#bodyfamily)`|nil`
- citizenId: [`CitizenId`](#citizenid)`|nil`

The value is `opx77_core`'s `charInfo.gender` and nothing here can change it.

### AppearanceSettled {#appearancesettled}

What [`isSettled`](exports.md#issettled) answers.

Extends [`AppearanceResponse`](#appearanceresponse)

**Fields**

- settled: `boolean` — the appearance work for this world entry has finished.
- announced: `boolean` — [`open77:session:gameplayReady`](events.md#gameplay-ready)
  has gone out.
- waiting: `"server"|"restore"|"creation"|"creator"|nil` — what the session is
  short of. `"creation"` means the character has no face and nothing has called
  [`openCreator`](exports.md#opencreator).
- citizenId: [`CitizenId`](#citizenid)`|nil`

### AppearanceOpenState {#appearanceopenstate}

What [`isOpen`](exports.md#isopen) answers.

Extends [`AppearanceResponse`](#appearanceresponse)

**Fields**

- open: `boolean` — a native modal is on screen. The host's answer, so it is
  `true` for a modal this resource did not raise.
- editing: `boolean` — and it is this resource's editor.
- creating: `boolean` — and it is this resource's character creator.

### AppearanceSkin {#appearanceskin}

What [`getSkin`](exports.md#getskin) answers. Renamed from `AppearanceCurrent`
in `0.4.0`, with the export.

Extends [`AppearanceResponse`](#appearanceresponse)

**Fields**

- citizenId: [`CitizenId`](#citizenid)`|nil`
- family: [`BodyFamily`](#bodyfamily)`|nil`
- snapshot: [`AppearanceSnapshot`](#appearancesnapshot)`|nil` — what
  `PlayerData.appearance` carries, and `nil` for a character that has never had
  a face captured.

### AppearanceClientState {#appearanceclientstate}

What [`state`](exports.md#state) answers: one client's own view, sampled at the
moment of the call. It is the diagnostic report behind
[`isSettled`](exports.md#issettled).

Extends [`AppearanceResponse`](#appearanceresponse)

**Fields**

- citizenId: [`CitizenId`](#citizenid)`|nil`
- family: [`BodyFamily`](#bodyfamily)`|nil`
- stored: `boolean` — a stored snapshot is held on this client.
- wearing: `boolean` — the puppet is wearing it.
- decided: `boolean` — this world entry's face has been decided.
- settled: `boolean` — and every piece of work behind that decision has
  finished. This is the same value [`isSettled`](exports.md#issettled) answers
  with, and the condition
  [`open77:session:gameplayReady`](events.md#gameplay-ready) waits on. A queued
  apply is `decided = true`, `settled = false`.
- restoring: `boolean` — a restore is in flight.
- committing: `boolean` — a captured face is with the core, unanswered.
- creating: `boolean` — the character creator is on screen.
- editing: `boolean` — this resource's editor is on screen.
- worldEligible: `boolean` — this world attachment is the gameplay one rather
  than the vanilla menu.
- announced: `boolean` — [`open77:session:gameplayReady`](events.md#gameplay-ready)
  has gone out.

None of it is authority. `wearing` is a record of an accepted apply, not a
reading of the puppet, and `announced` says the send succeeded, not that the
platform accepted it.

## AppearanceEvent {#appearanceevent}

What arrives on [`OPX_APPEARANCE_CONFIG.EVENT`](config.md#event), with a bare
`AddEventHandler`.

**Fields**

- ok: `boolean`
- event: [`AppearanceEventName`](#appearanceeventname) — branch on this first.
- error: [`AppearanceError`](#appearanceerror)`|nil`
- citizenId: [`CitizenId`](#citizenid)`|nil`
- family: [`BodyFamily`](#bodyfamily)`|nil` — on `needsCreation`: the body the
  creator must come back on.
- unchanged: `boolean|nil` — on `saved`: the face matched the stored one, so the
  core wrote nothing.

## See also {#see-also}

- [Exports](exports.md) — which export answers which of these.
- [Events](events.md) — the payload and the channel.
- [`opx77_core` types](../opx77_core/types.md#appearancesnapshot) — the
  authoritative definition of a stored face.
