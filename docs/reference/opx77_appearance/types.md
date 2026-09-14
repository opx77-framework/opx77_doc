---
title: opx77_appearance types
description: Every shape opx77_appearance names — the aliases, the snapshot it captures and sends, the response tables its twelve exports answer with, the payload its event channel carries, the reasons a panel closes, and where each error code can surface.
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
puppets. **The core owns it** and this resource only reads it. The character
bootstrap is resolved with one of the two at join — the most recently played
character's, else [`BOOTSTRAP.DEFAULT_FAMILY`](config.md#bootstrap-default-family)
— and the world is reloaded onto the selected character's own value once it is
chosen.

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
| `no_character` | `opx77_core` has no character loaded here. | [`getSkin`](exports.md#getskin), [`getFamily`](exports.md#getfamily), [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin), [`openEditor`](exports.md#openeditor), [`openCreator`](exports.md#opencreator), [`openPanel`](exports.md#openpanel) |
| `appearance_busy` | A modal is on screen, a creation is running, or a capture is with the core. | [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin), [`openEditor`](exports.md#openeditor), [`openCreator`](exports.md#opencreator), [`openPanel`](exports.md#openpanel); a panel close reason |
| `character_creation_in_progress` | A creation is running, from [`openCreator`](exports.md#opencreator) to the core's answer. | [`openEditor`](exports.md#openeditor) |
| `invalid_mode` | Not `"ripperdoc"` or `"hairdresser"`. | [`openEditor`](exports.md#openeditor) |
| `already_has_a_face` | [`openCreator`](exports.md#opencreator) on a character that has a stored face. | [`openCreator`](exports.md#opencreator) |
| `creation_refused` | This character's creation already ended without a face. | [`openCreator`](exports.md#opencreator) |
| `character_creator_unavailable` | The engine would not open the creation editor. | the `created` event |
| `character_creation_cancelled` | The player closed the creation editor without confirming. | the `created` event |
| `character_capture_failed` | The creation editor's face could not be read, and the capture gave no reason of its own. | the `created` event |
| `menu_not_running` | The panel is `opx77_menu`'s, and it is not running. | [`openPanel`](exports.md#openpanel) |
| `panel_busy` | Another resource owns the open panel. | [`openPanel`](exports.md#openpanel) |
| `no_panel_open` | [`closePanel`](exports.md#closepanel) with nothing on screen. | [`closePanel`](exports.md#closepanel) |
| `not_owner` | [`closePanel`](exports.md#closepanel) on another resource's panel. | [`closePanel`](exports.md#closepanel) |
| `capture_failed` | The engine would not answer what the puppet is wearing. | [`captureSkin`](exports.md#captureskin), [`saveSkin`](exports.md#saveskin); a toast |
| `not_sent` | The net event was not accepted. | the `created` and `saved` events; a toast on an edit |
| `save_timeout` | The core never answered a captured face. | the `created` event; a toast on an edit |
| `invalid_snapshot` | The capture, or the snapshot given, is not a snapshot. | [`captureSkin`](exports.md#captureskin), [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin); a toast |
| `invalid_option` | An entry of the option list is not a table. | the same |
| `invalid_option_name` | An option name is not a string. | the same |
| `stored_build_mismatch` | The face is from another game build. | [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin); the `settled` event |
| `body_family_mismatch` | The creation editor could not be kept on the right body: it came back on the other one past `FAMILY_RETRIES`, or the reload onto it failed. | the `created` event |

!!! info "Removed in `0.6.0`"
    `bootstrap_already_spent` and `character_bootstrap_failed` are gone. The
    bootstrap is spent at join, before any character is chosen, so
    [`openCreator`](exports.md#opencreator) is always called after it and no
    creation ending fails it.

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
---| "panelOpened" | "panelClosed"
```

| Name | The decision |
|---|---|
| `gameplayReady` | The readiness announcement went out; the player may be placed. |
| `restored` | A stored face was put on the puppet, or could not be. |
| `settled` | This world entry's face was decided, and there is none to wear. |
| `needsCreation` | This character has no face; call [`openCreator`](exports.md#opencreator) to open the editor. |
| `applied` | [`setSkin`](exports.md#setskin), or the panel's **Wear it**, reached the puppet, or could not. |
| `created` | A new character's face was built and stored, or was not. |
| `saved` | An edit was committed, or was refused. |
| `characterChanged` | The live character switched underneath this resource. |
| `panelOpened` | This resource's own panel came up. |
| `panelClosed` | It went down; `reason` says what took it down. |

Which `ok` each carries, and which of them are only ever failures, is on
[Events](events.md#opx77-appearance).

### AppearancePanelReason {#appearancepanelreason}

Why the panel closed, carried as `reason` on a `panelClosed` event.

```lua
---@alias AppearancePanelReason
---| "caller" | "player" | "appearance_busy" | "character_changed"
---| "no_character" | "owner_stopped" | "owner_reloaded" | "menu_closed"
```

| Reason | What took the panel down |
|---|---|
| `caller` | [`closePanel`](exports.md#closepanel), or a row that opens the native editor. |
| `player` | Escape, the pause key, or BACK at the top of the list. |
| `appearance_busy` | A native modal came up; the panel never draws over one. |
| `character_changed` | The live character switched underneath the panel. |
| `no_character` | The character unloaded. |
| `owner_stopped` | The resource that opened it is no longer running. |
| `owner_reloaded` | The resource that opened it reloaded. |
| `menu_closed` | `opx77_menu` took the list down for a reason of its own. |

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
[`closePanel`](exports.md#closepanel) answers exactly this and nothing more.

**Fields**

- ok: `boolean`
- error: [`AppearanceError`](#appearanceerror)`|nil` — present only when `ok` is
  `false`.

### AppearanceQueued {#appearancequeued}

What a write or a modal call answers: that it was **asked for**, never that it
has happened. [`setSkin`](exports.md#setskin),
[`saveSkin`](exports.md#saveskin), [`openEditor`](exports.md#openeditor),
[`openCreator`](exports.md#opencreator) and
[`openPanel`](exports.md#openpanel) all answer this shape.

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
- waiting: `"server"|"body"|"restore"|"creation"|"creator"|nil` — what the
  session is short of. `"creation"` means the character has no face and nothing
  has called [`openCreator`](exports.md#opencreator) yet; `"body"` that the
  world is reloading onto the character's body family. The full table is on
  [`isSettled`](exports.md#issettled).
- citizenId: [`CitizenId`](#citizenid)`|nil`

### AppearanceOpenState {#appearanceopenstate}

What [`isOpen`](exports.md#isopen) answers.

Extends [`AppearanceResponse`](#appearanceresponse)

**Fields**

- open: `boolean` — a native modal is on screen. The host's answer, so it is
  `true` for a modal this resource did not raise.
- editing: `boolean` — and it is this resource's editor.
- creating: `boolean` — a creation this resource began is running, from
  [`openCreator`](exports.md#opencreator) to the core's answer; not only while
  the editor is on screen.

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
- creating: `boolean` — a creation is running, from
  [`openCreator`](exports.md#opencreator) to the core's answer.
- editing: `boolean` — this resource's editor is on screen.
- worldEligible: `boolean` — this world attachment is the gameplay one rather
  than the pre-game menu the join starts in.
- announced: `boolean` — [`open77:session:gameplayReady`](events.md#gameplay-ready)
  has gone out.
- panel: `boolean` — this resource's own panel is on screen. New in `0.5.0`.

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
  editor opens on.
- unchanged: `boolean|nil` — on `saved`: the face matched the stored one, so the
  core wrote nothing.
- reason: [`AppearancePanelReason`](#appearancepanelreason)`|nil` — on
  `panelClosed`: what took the panel down.

## See also {#see-also}

- [Exports](exports.md) — which export answers which of these.
- [Events](events.md) — the payload and the channel.
- [`opx77_core` types](../opx77_core/types.md#appearancesnapshot) — the
  authoritative definition of a stored face.
