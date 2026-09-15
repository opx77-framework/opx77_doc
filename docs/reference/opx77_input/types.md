---
title: opx77_input types
description: Every shape opx77_input names — the aliases, the spec, field, option and slider tables you hand it, the payload its answer carries, the response tables its exports answer with, and the internal shapes that never cross the export boundary.
---

# Types

`opx77_input` ships its annotations in `std/types.lua`, a `---@meta` file that is
never loaded at runtime. The types below are what those annotations describe.

## InputHandle {#inputhandle}

An opaque integer identifying one open form, unique for the life of the client
session.

`Type:` `integer`

Handed back by [`open`](exports.md#open), carried in the
[answer](events.md#payload), and accepted by [`close`](exports.md#close). It
does not survive a reconnect.

## InputAction {#inputaction}

What became of the form, on the `action` field of the answer.

`Type:` `"submit" | "cancel"`

## InputKind {#inputkind}

What a field is, decided once at build from its shape. Never sent by a caller.

`Type:` `"text" | "choice" | "slider"`

See [How a field's kind is decided](form-spec.md#kinds).

## InputCharset {#inputcharset}

The characters a text field accepts.

`Type:` `"alnum" | "alpha" | "digits" | "hex" | "name"`

A fixed table; see [Character sets](form-spec.md#charsets). Every set is ASCII.

## InputCursor {#inputcursor}

Which field is focused first: a field `id`, or a 1-based index.

`Type:` `string | integer`

**Advisory.** An unresolvable value falls back to the first field.

## InputSpec {#inputspec}

The table handed to [`open`](exports.md#open). Only `fields` is required.

**Fields**

- fields: [`InputField[]`](#inputfield) — one to eight.
- id?: `string` — unique per owner. Default: the owner's name.
- title?: `string` — Default: the owner's name, upper-cased.
- event?: `string` — the event the answer is raised on.
- data?: `table` — opaque, echoed in the answer as `data`.
- cursor?: [`InputCursor`](#inputcursor) — which field is focused first.
- description?: `string` — a sentence above the fields.
- status?: `string` — a line under the fields. Refused if not text.

Field-by-field detail is on [The form spec](form-spec.md#spec).

## InputField {#inputfield}

One field. Its kind comes from its shape: `options` makes a choice, `slider` a
slider, anything else a text field.

**Fields**

- label: `string` — required.
- id?: `string` — Default: `field_<n>`.
- description?: `string` — shown under the fields while this one is focused.
- value?: `string | number` — text only, the initial value.
- placeholder?: `string` — text only, drawn while the field is empty.
- maxLength?: `integer` — text only. Default `96`, ceiling `512`.
- pattern?: `string` — text only, a Lua pattern the whole answer must match.
- charset?: [`InputCharset`](#inputcharset) — text only.
- required?: `boolean` — text only, an empty answer is refused.
- options?: [`InputOption[]`](#inputoption) — a choice. A bare string means
  `{ label = s, value = s }`.
- selected?: `integer` — which option starts selected, 1-based.
- slider?: [`InputSlider`](#inputslider) — a number the player steps.

## InputOption {#inputoption}

One option of a choice.

**Fields**

- label: `string` — what the player reads. At most 48 characters.
- value: `string | number` — what the answer carries. Default: the label.

## InputSlider {#inputslider}

**Fields**

- min?: `number` — Default: `0`
- max?: `number` — Default: `100`
- step?: `number` — Default: `1`
- value?: `number` — Default: `min`
- suffix?: `string` — drawn after the number, e.g. `"%"`.

## InputPayload {#inputpayload}

The one event a form raises, on the spec's `event` and on
[`opx77:input`](events.md#opx77-input) beside it. Exactly one per open form.

**Fields**

- form: `string` — the form's id.
- handle: [`InputHandle`](#inputhandle)
- owner: `string` — the resource that opened it.
- action: [`InputAction`](#inputaction)
- reason?: `string` — why it was cancelled; on `cancel` only. See
  [Cancel reasons](events.md#reasons).
- values?: `table<string, string | number>` — field id to answer; on `submit`
  only.
- data?: `table` — the spec's `data`, echoed untouched.

## InputResponse {#inputresponse}

The envelope every export answers. No export raises.

**Fields**

- ok: `boolean`
- error?: `string` — a stable code, never player-facing text.

[`close`](exports.md#close) and [`setStatus`](exports.md#setstatus) answer this
shape exactly.

## InputOpened {#inputopened}

What [`open`](exports.md#open) answers.

Extends [`InputResponse`](#inputresponse)

**Fields**

- handle?: [`InputHandle`](#inputhandle)
- id?: `string` — the form's id.
- fields?: `integer` — how many fields it built.

## InputState {#inputstate}

What [`state`](exports.md#state) answers. It reports where the player is, never
what they have typed.

Extends [`InputResponse`](#inputresponse)

**Fields**

- open: `boolean`
- mine: `boolean` — `true` when the open form belongs to the caller. Every field
  below is present only then.
- handle?: [`InputHandle`](#inputhandle)
- owner?: `string`
- form?: `string`
- title?: `string`
- index?: `integer` — the focused field's position.
- total?: `integer`
- fieldId?: `string`

## Internal shapes {#internal}

These appear in the source and never cross the export boundary. None is part of
the contract.

- **`InputEntry`** — a normalised field with its `kind` resolved: a text field's
  accepted buffer, its `maxLength`, `pattern`, the Lua character class its
  `charset` resolved to, `required`, and `patternFailed` once a raising match
  has been logged; a choice's options and `selected`; a slider's bounds.
- **`InputRecord`** — the one open form: handle, owner, owner generation, id,
  title, description, event, data, the entries, the focused index and the status.
- **`InputStatus`** — the transient line: `text`, `ok`, and the millisecond it
  was written at, after which it has six seconds to live.
- **`InputView`** — one frame as the page receives it: the title, the form's
  description as `note`, the rows, the focused field's description as `hint`,
  the key line already in the player's language, the status and `statusBad`.
- **`InputRow`** — one drawn row: `id`, `kind`, `label`, a text field's `text`,
  `placeholder` and `max`, a choice's or slider's rendered `value`, a slider's
  `fill` from 0 to 1, and the flags `spin` and `on`. A flag is `true` or
  **absent**, never `false`: an absent field costs no value node.
