---
title: opx77_charselector types
description: Every shape opx77_charselector names — the phase, the roster and the character summary opx77_core sends, the menu rows it builds, the hand-over payload, the response tables its exports answer with and every error code.
---

# Types

`opx77_charselector` ships its annotations in `types.lua`, a `---@meta` file that
is never loaded at runtime. The types below are what those annotations describe.

## SelectorPhase {#selectorphase}

Where the roster is. Only one phase is ever live.

`Type:` `"idle" | "roster" | "busy"`

| Phase | Means |
|---|---|
| `idle` | Nothing on screen: no roster, no gameplay world, a character loaded, or a creation handed over. |
| `roster` | The list is up and the player may choose. |
| `busy` | A selection is with `opx77_core`, unanswered. |

## SelectorRowKind {#selectorrowkind}

What a row in the list is.

`Type:` `"character" | "empty" | "create"`

## SelectorRoster {#selectorroster}

The roster as `opx77_core` publishes it on `opx77:client:charactersReady`. The
`GetCharacters` export answers the same content under `characters` instead of
`list`; both shapes are adopted.

**Fields**

- list: [`CharacterSummary[]`](#charactersummary)
- slots: `integer` — how many characters this account may hold.
- origins: `table<string, { label: string, description: string|nil }>`

## CharacterSummary {#charactersummary}

One character, exactly the fields `opx77_core` sends. Money, metadata,
appearance and stored position are **deliberately absent** from a roster, which
is why the stage cannot show the character under the cursor.

**Fields**

- citizenId: `string`
- cid: `integer`
- firstName: `string`
- lastName: `string`
- origin: `string` — a key of `origins`.
- gender: `"female" | "male"`
- job?: `string`
- gang?: `string`
- lastLoggedOut?: `string`

## SelectorRowData {#selectorrowdata}

The table put on every row. `opx77_menu` echoes it back untouched as
`payload.data`, so it is the only thing a chosen row is read from.

**Fields**

- index: `integer` — 1-based, into the list's rows.
- kind: [`SelectorRowKind`](#selectorrowkind)
- action?: `"select" | "create"` — absent on a row that cannot be chosen.
- citizenId?: `string` — on a character row only.

## SelectorRow {#selectorrow}

One row, in the shape `opx77_menu`'s `items` takes — a
[`MenuItem`](../opx77_menu/types.md#menuitem).

**Fields**

- id: `string` — `character_<n>`, `slot_<n>` or `create`.
- label: `string` — the character's name, or the row's own wording.
- value?: `string` — the citizen id, or the slot number.
- description?: `string` — the identifying facts, under the list while selected.
- disabled?: `true` — drawn, never selectable. The create row on a full account.
- data: [`SelectorRowData`](#selectorrowdata)

## SelectorEvent {#selectorevent}

What this resource raises on [`EVENT`](config.md#event), with a plain
`AddEventHandler`. See [createRequested](events.md#create-requested).

**Fields**

- event: `"createRequested"`
- slot: `integer` — which row was chosen, 1-based.
- used: `integer` — how many characters the account holds.
- slots: `integer` — how many it may hold.

## SelectorResponse {#selectorresponse}

What every export answers. No export raises.

**Fields**

- ok: `boolean`
- error?: [`SelectorError`](#selectorerror) — a stable code, never player-facing
  text.

## SelectorOpened {#selectoropened}

What [`open`](exports.md#open) answers.

Extends [`SelectorResponse`](#selectorresponse)

**Fields**

- queued?: `true` — the list was asked for; `opx77_menu` is called on a thread,
  so it appears a moment later.

## SelectorState {#selectorstate}

What [`state`](exports.md#state) answers.

Extends [`SelectorResponse`](#selectorresponse)

**Fields**

- open: `boolean`
- phase: [`SelectorPhase`](#selectorphase)
- world: `boolean` — whether the gameplay world is up, which the roster waits
  for.
- characters: `integer` — how many the account holds.
- slots: `integer` — how many it may hold.
- citizenId?: `string` — the character the cursor is on, while the list is up and
  the cursor is on one.
- staged: `boolean` — whether the stage camera is on the player's character.
- frozen: `boolean` — whether the character is being held in place.
- stageHolder?: `string` — the resource holding the stage through `holdStage`.

## SelectorStaged {#selectorstaged}

What [`holdStage`](exports.md#holdstage) answers.

Extends [`SelectorResponse`](#selectorresponse)

**Fields**

- staged?: `boolean` — `false` where `STAGE.ENABLED` is `false`. The hold is
  still taken, and there is nothing for the caller to branch on.

## SelectorOpen {#selectoropen}

What [`isOpen`](exports.md#isopen) answers.

Extends [`SelectorResponse`](#selectorresponse)

**Fields**

- open: `boolean`

## SelectorError {#selectorerror}

Every code an export answers with.

| Code | Means |
|---|---|
| `menu_not_running` | `opx77_menu` is not running; there is nothing to draw the list on. |
| `export_call_required` | The call did not come from another resource. |
| `in_world` | A character is loaded, so there is no roster to show. |
| `no_roster` | The core has not sent one, and has now been asked again. |
| `world_not_ready` | The gameplay world is not up; the list goes up by itself when it is. |
| `busy` | A selection is already in flight. |
| `not_holder` | `releaseStage` from a resource that does not hold the stage. |
