---
title: opx77_charcreator types
description: Every shape opx77_charcreator names — the phase, the field ids and body family, the hand-over it acts on, the registration it sends opx77_core, the event it publishes, the response tables its exports answer with and every error code.
---

# Types

`opx77_charcreator` ships its annotations in `types.lua`, a `---@meta` file that
is never loaded at runtime. The types below are what those annotations describe.

## CreatorPhase {#creatorphase}

Where the flow is. Only one phase is ever live.

`Type:` `"idle" | "asking" | "busy"`

| Phase | Means |
|---|---|
| `idle` | Nothing is being built. |
| `asking` | The `opx77_input` form is up and the player is filling it in. |
| `busy` | A registration is with `opx77_core`, unanswered. |

## CreatorFieldId {#creatorfieldid}

`Type:` `"firstName" | "lastName" | "birthDate" | "origin" | "gender"`

The five fields of [the form](index.md#the-form), in the order they are asked.

## BodyFamily {#bodyfamily}

The body families `opx77_core` stores on `charInfo.gender`.

`Type:` `"female" | "male"`

It is the body `opx77_appearance` reloads the world onto once the character is
selected, and the body its in-world editor opens on.

## SelectorHandoff {#selectorhandoff}

What `opx77_charselector` raises on its `EVENT`. Only `createRequested` is acted
on; every other name on that channel is ignored.

**Fields**

- event: `string`
- slot?: `integer` — which slot was pressed, 1-based.
- used?: `integer` — how many characters the account holds.
- slots?: `integer` — how many it may hold.

## CreatorContext {#creatorcontext}

What the form is opened for, from the hand-over or from [`open`](exports.md#open).
Used only to write the line above the fields.

**Fields**

- slot?: `integer`
- used?: `integer`
- slots?: `integer`

## CreatorDraft {#creatordraft}

What the player last answered, kept so a reopened form comes back filled in.
Every value is exactly what `opx77_input` handed over.

**Fields**

- firstName?: `string`
- lastName?: `string`
- birthDate?: `string`
- origin?: `string`
- gender?: `string`

## Registration {#registration}

The table handed to `opx77_core`'s
[`CreateCharacter`](../opx77_core/exports/client.md#createcharacter). Every field
is checked here first against the rules the core applies.

**Fields**

- firstName: `string` — trimmed.
- lastName: `string` — trimmed.
- birthDate: `string` — `YYYY-MM-DD`.
- origin: `string` — a key of the core's `GetOrigins`.
- gender: [`BodyFamily`](#bodyfamily)

## NameBounds {#namebounds}

The name bounds `opx77_core` answers from `GetSharedConfig`, counted in
characters. `2` and `32` until it answers.

**Fields**

- MIN: `integer`
- MAX: `integer`

## CreatorEventName {#creatoreventname}

Which of this resource's decisions an event reports.

`Type:` `"opened" | "created" | "cancelled" | "handedOver"`

| Name | Means |
|---|---|
| `opened` | the form went up |
| `created` | `opx77_core` answered a registration |
| `cancelled` | the flow ended without a character |
| `handedOver` | `opx77_appearance` was asked to open the in-world face editor |

## CreatorEvent {#creatorevent}

What arrives on [`EVENT`](config.md#event), with a plain `AddEventHandler`. See
[Events](events.md#opx77-charcreator).

**Fields**

- ok: `boolean`
- event: [`CreatorEventName`](#creatoreventname)
- error?: `string` — a refusal code, never player-facing text.
- citizenId?: `string` — on `created` and `handedOver`, where it can be told.
- slot?: `integer` — on `opened`.
- reason?: `string` — on `cancelled`.

## CreatorResponse {#creatorresponse}

What every export answers. No export raises.

**Fields**

- ok: `boolean`
- error?: [`CreatorError`](#creatorerror) — a stable code, never player-facing
  text.

## CreatorOpen {#creatoropen}

What [`isOpen`](exports.md#isopen) answers.

Extends [`CreatorResponse`](#creatorresponse)

**Fields**

- open: `boolean`

## CreatorState {#creatorstate}

What [`state`](exports.md#state) answers. It never reports what the player has
typed.

Extends [`CreatorResponse`](#creatorresponse)

**Fields**

- open: `boolean`
- phase: [`CreatorPhase`](#creatorphase)
- slot?: `integer` — the slot the form was opened for.
- attempts: `integer` — how many times the form has been put up this flow.
- origins: `integer` — how many lifepaths `opx77_core` has answered with.
- inputReady: `boolean` — whether `opx77_input` is running.

## CreatorError {#creatorerror}

Every code an export answers with.

| Code | Means |
|---|---|
| `export_call_required` | The call did not come from another resource. |
| `in_world` | A character is loaded, so there is nothing to create into. |
| `no_origins` | `opx77_core` could not be asked for the lifepaths. |
| `input_not_running` | `opx77_input` is not running; there is no form to draw. |
| `busy` | A flow is already running, or a registration is in flight. |
| `not_open` | `close` with no form up. |

`no_origins` is declared in `types.lua` but no export answers it: a flow that
cannot read the lifepaths has already been accepted, and ends as
[`cancelled`](events.md#opx77-charcreator) with `reason = "no_origins"` instead.
