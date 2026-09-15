---
title: opx77_appearance types
description: Every shape opx77_appearance names — the aliases, the snapshot it captures and sends, the clothing record it puts on and saves, the response tables its twelve exports answer with, the payload its event channel carries, the reasons a panel closes, the look handed to other players, and where each error code can surface.
---

# Types

`opx77_appearance` ships its annotations in `std/types.lua`, a `---@meta` file
that is never loaded at runtime: it is not in the manifest, and the editor reads
it through the `std/` library. The shapes below are what those annotations
describe.

The snapshot and the clothing record are **not this resource's shapes**:
`opx77_core` defines them, validates them and stores them, and what is written
here is the client's view of the same tables. Where the two pages differ, the
core's is the contract — see
[`AppearanceSnapshot`](../opx77_core/types.md#appearancesnapshot).

## Aliases {#aliases}

### CitizenId {#citizenid}

The character this resource is dressing: `opx77_core`'s own character id, in the
grouped form `"H7K-M4X3"`.

```lua
---@alias CitizenId string
---| # opx77_core's character id, "H7K-M4X3". The character this resource is dressing.
```

Issued by the core and carried in `PlayerData`. This resource never derives one.
It sends the live one back with every face and clothing save, only so the core
can refuse a save captured for the character before a switch — the core takes
the character from the connection either way. See
[`CitizenId`](../opx77_core/types.md#citizenid).

### BodyFamily {#bodyfamily}

The character's body type.

```lua
---@alias BodyFamily "female"|"male"
---| # opx77_core's `charInfo.gender`, and the engine's two pristine puppets. The core owns it.
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

Why something was refused. Codes this resource decides are hints. Of the codes
from `opx77_core`, the seven a face save can be refused with are locale keys this
resource's catalogue carries, so they can be shown in the player's language; the
clothing codes are published and logged, never displayed.

**Decided here**

| Code | Meaning | Where it surfaces |
|---|---|---|
| `export_call_required` | No invoking resource, so the call came from inside this VM. | every export |
| `no_character` | `opx77_core` has no character loaded here. | [`getSkin`](exports.md#getskin), [`getFamily`](exports.md#getfamily), [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin), [`openEditor`](exports.md#openeditor), [`openCreator`](exports.md#opencreator), [`openPanel`](exports.md#openpanel) |
| `appearance_busy` | A modal is on screen — or `Open77.appearance.isOpen()` raised — a creation is running, or a capture is with the core. | [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin), [`openEditor`](exports.md#openeditor), [`openCreator`](exports.md#opencreator), [`openPanel`](exports.md#openpanel); a panel close reason |
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
| `save_timeout` | The core never answered a captured face, or a clothing save — published for clothing when it is the second failed save in a row. | the `created` event; the `clothingSaved` event; a toast on an edit |
| `invalid_snapshot` | The capture, or the snapshot given, is not a snapshot. | [`captureSkin`](exports.md#captureskin), [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin); a toast |
| `invalid_option` | An entry of the option list is not a table. | the same |
| `invalid_option_name` | An option name is not a string. | the same |
| `stored_build_mismatch` | The face is from another game build. | [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin); the `settled` event |
| `body_family_mismatch` | The creation editor could not be kept on the right body: it came back on the other one past `FAMILY_RETRIES`, or the reload onto it failed. | the `created` event |
| `clothing_not_restored` | The stored clothing never read back on the puppet after five put-ons. | the `clothingRestored` event |

!!! info "Removed in `0.6.0`"
    `bootstrap_already_spent` and `character_bootstrap_failed` are gone. The
    bootstrap is spent at join, before any character is chosen, so
    [`openCreator`](exports.md#opencreator) is always called after it and no
    creation ending fails it.

**Decided by `opx77_core`**

| Code | Meaning | Where it surfaces |
|---|---|---|
| `appearance.invalid` | The core could not read the snapshot. | the `saved` and `created` events; a toast |
| `appearance.stale` | A face captured for the character loaded before a switch. | the same |
| `appearance.tooLarge` | The encoded JSON is over the core's limit. | the same |
| `error.badRequest` | The payload was not a table. | the same; `clothingSaved` |
| `error.notLoggedIn` | No character loaded on the core for this connection. | the `saved` and `created` events; a toast. Nothing for a clothing save |
| `error.tooFast` | Two saves inside the core's 2000 ms cooldown. | the `saved` and `created` events; a toast. A clothing save is sent again |
| `error.unavailable` | The core's storage layer refused the write, or the character's stored clothing could not be read at login. | the `saved` and `created` events; a toast; `clothingSaved` after two in a row |
| `clothing.invalid` | The core could not read the clothing record. | `clothingSaved` |
| `clothing.tooLarge` | The clothing record is over the core's limit. | `clothingSaved` |
| `clothing.stale` | A clothing save read for the character loaded before a switch. | nothing: the save is dropped |

!!! info "A failed restore carries a code from neither list"
    The `error` on a `restored` event is whatever the host's own apply answered —
    `restore_timeout` when the attempts ran out, or one of the reasons the host
    reports. Those strings are the platform's and are not enumerated in
    `std/types.lua`; treat them as opaque and log them rather than branching on
    them.

### AppearanceEventName {#appearanceeventname}

Which of this resource's decisions an [event](events.md#opx77-appearance)
reports.

```lua
---@alias AppearanceEventName
---| "gameplayReady"    the readiness announcement went out; the player may be placed
---| "restored"         a stored face was put on the puppet, or could not be
---| "settled"          this world entry's face was decided, and there is none to wear
---| "needsCreation"    this character has no face; call `openCreator` to open the editor
---| "applied"          `setSkin` reached the puppet, or could not
---| "created"          a new character's face was built and stored, or was not
---| "saved"            an edit was committed, or was refused
---| "characterChanged" the live character switched underneath this resource
---| "panelOpened"      this resource's own panel came up
---| "panelClosed"      it went down; `reason` says what took it down
---| "clothingRestored" the stored clothing, or the default record, is on the puppet, or is not
---| "clothingSaved"    a clothing change was stored, or was refused, or saves have stopped
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
| `clothingRestored` | The stored clothing, or the default record, read back on the puppet, or never did. |
| `clothingSaved` | A clothing change was stored, or was refused, or saves stopped for the character. |

Which `ok` each carries, and which of them are only ever failures, is on
[Events](events.md#opx77-appearance).

### AppearancePanelReason {#appearancepanelreason}

Why the panel closed, carried as `reason` on a `panelClosed` event.

```lua
---@alias AppearancePanelReason
---| "caller"            `closePanel`, or a row that opens the native editor
---| "player"            Escape, the pause key, BACK at the top of the list, or the panel key
---| "appearance_busy"   a native modal came up, and the panel never draws over one
---| "character_changed" the live character switched underneath the panel
---| "no_character"      the character unloaded
---| "owner_stopped"     the resource that opened it is no longer running
---| "owner_reloaded"    the resource that opened it reloaded
---| "menu_closed"       opx77_menu took the list down for a reason of its own
```

| Reason | What took the panel down |
|---|---|
| `caller` | [`closePanel`](exports.md#closepanel), or a row that opens the native editor. |
| `player` | Escape, the pause key, BACK at the top of the list, or [the panel key](index.md#key) — which closes a panel whoever opened it. |
| `appearance_busy` | A native modal came up; the panel never draws over one. |
| `character_changed` | The live character switched underneath the panel. |
| `no_character` | The character unloaded, or `opx77_core` stopped with a character loaded. |
| `owner_stopped` | The resource that opened it is neither running nor starting. |
| `owner_reloaded` | The resource that opened it reloaded. |
| `menu_closed` | `opx77_menu` took the list down for a reason of its own. A close for another list, or one with the reason `reopened`, closes nothing. |

### AppearanceClothingPhase {#appearanceclothingphase}

What this client is doing with the clothes, carried as `clothing` on
[`state`](exports.md#state).

```lua
---@alias AppearanceClothingPhase
---| "idle"      no character, or opx77_core carries no clothing for it: nothing is touched
---| "waiting"   the stored clothing goes on once the face has settled and been announced
---| "restoring" it was put on and has not read back yet
---| "worn"      it is on, and what the player changes is saved
---| "saving"    worn, with a save still unanswered
---| "unsaved"   worn, and saves have stopped for this character
---| "failed"    it never read back; nothing is saved until the next world entry
```

`idle` also covers [`CLOTHING.PERSIST = false`](config.md#clothing-persist) and a
running `open77_appearance`.

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

The snapshot this resource sends is these five fields and nothing else: the
editor-only metadata the host's capture carries is stripped, because the
runtime's value codec will not carry it.

Two snapshots are treated as the same face when `gameBuild`, `catalogDigest`,
`gender`, the option count, and every option's `part`, `name` and `value` match.
`choices` is deliberately outside that comparison — it describes the catalogue,
not the choice. The comparison is what skips an apply the puppet does not need,
and a save the core would answer with silence.

## The clothes {#clothes}

### AppearanceClothing {#appearanceclothing}

What `opx77_core` stores as a character's clothing, and carries as
`PlayerData.clothing`: the platform's own record shape.

```lua
---@class AppearanceClothing
---@field schemaVersion integer  1
---@field equipment table<string, string|false>  the nine equipment slots: a record name, or false
---@field wardrobe { active: integer|nil, outfits: table<string, table<string, string|false>> }
```

- equipment — `Head`, `Face`, `InnerChest`, `OuterChest`, `Legs`, `Feet`,
  `Outfit`, `UnderwearTop` and `UnderwearBottom`, each a record name or `false`.
- wardrobe — `active`, the outfit index `0` to `6` or none, and `outfits` keyed
  `"0"` to `"6"`, each overriding any of the first seven slots with a record, or
  hiding one with `false`. An outfit that overrides nothing is left out.

`PlayerData.clothing` is `false` for a character with none stored yet, which
wears the platform's default record — every slot empty but
`Items.Underwear_Basic_01_Bottom`, no outfit — and it is absent for an
`opx77_core` older than `0.5.0`, or a row the core could not read, in which case
this resource touches nothing. See [What the character wears](index.md#clothing).

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

Clothing is not part of it: the stored clothes go on after the announcement.

### AppearanceOpenState {#appearanceopenstate}

What [`isOpen`](exports.md#isopen) answers.

Extends [`AppearanceResponse`](#appearanceresponse)

**Fields**

- open: `boolean` — a native modal is on screen. The host's answer, so it is
  `true` for a modal this resource did not raise, and `true` when the host's
  call raised.
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
- body: [`BodyFamily`](#bodyfamily)`|nil` — the body the puppet is on, as far as
  this client can tell: the engine's `captureBody`, else the family this client
  loaded, else the one the bootstrap resolved.
- bodyReloading: `boolean` — a body reload has not been through its new
  puppet's reset yet.
- panel: `boolean` — this resource's own panel is on screen, whoever opened it.
- clothing: [`AppearanceClothingPhase`](#appearanceclothingphase) — what this
  client is doing with the clothes.

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

## AppearanceLook {#appearancelook}

One player's look as the presence halves hand it to the other players, on
[`opx77_appearance:present`](events.md#presence-wire) and
[`opx77_appearance:look`](events.md#presence-wire). **Never stored.** New in
`0.8.0`.

```lua
--- One player's look as the presence halves hand it to the other players. Never stored.
---@class AppearanceLook
---@field body AppearanceBody
---@field equipment table<string, string|false>  the nine equipment slots: a record name, or false
---@field wardrobe { active: integer|nil, outfits: table<string, table> }

---@class AppearanceBody
---@field family BodyFamily
---@field groups { part: "head"|"body"|"arms", name: string, keys: string[][] }[]
```

- body — what `Open77.appearance.captureBody` reads: the family and 1 to 64
  customization groups, each a `part`, a `name` hash and 1 to 64 keys, each a
  pair of hashes. A hash is `0x` and sixteen hex digits, not all zero. Encoded,
  at most 49152 bytes. A body outside those bounds is refused whole.
- equipment — `Head`, `Face`, `InnerChest`, `OuterChest`, `Legs`, `Feet`,
  `Outfit`, `UnderwearTop` and `UnderwearBottom`, each a record name or `false`.
  Anything else in a slot becomes `false`.
- wardrobe — `active`, the outfit index `0` to `6` or none, and `outfits` by
  index, each overriding any of the first seven slots. The client sends only the
  active outfit's overrides.

## See also {#see-also}

- [Exports](exports.md) — which export answers which of these.
- [Events](events.md) — the payload and the channel.
- [`opx77_core` types](../opx77_core/types.md#appearancesnapshot) — the
  authoritative definition of a stored face.
