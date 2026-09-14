---
title: opx77_input exports
description: The four client exports opx77_input publishes — open, close, state and setStatus — with the arguments each takes, the response each answers and every stable error code each can refuse with.
---

# Exports

`opx77_input` publishes four exports. All four are **client** exports: a server
resource that needs a value from a player calls these from its own client half.
See [The client export contract](../../concepts/export-contract.md) for the call
shape and the three levels of failure.

| Export | Answers | Does |
|---|---|---|
| [`open`](#open) | [`InputOpened`](types.md#inputopened) | Asks the player for one or more values, refusing the spec whole if any field is malformed. |
| [`close`](#close) | [`InputResponse`](types.md#inputresponse) | Takes your own form back down. It still answers, as a cancel. |
| [`state`](#state) | [`InputState`](types.md#inputstate) | Reports whether a form is open and whether it is yours. |
| [`setStatus`](#setstatus) | [`InputResponse`](types.md#inputresponse) | Writes the transient line under the fields. |

Every export answers a table and **never raises**. `ok` is always present;
`error` is a stable code meant for branching, never for showing to a player.

Identity is never an argument. Every export reads the caller from
`GetInvokingResource()` and `GetInvokingResourceGeneration()`, both from the
host, so a caller can neither claim to be another resource nor outlive its own
reload. A call that did not arrive through the export mechanism answers
`export_call_required`.

**None of them returns the answer.** `open` answers that the form went up; what
the player typed arrives later, once, as an [event](events.md). A promise that
waited for a human would hold the caller's coroutine for as long as they
deliberated.

## open {#open}

Opens a form and returns its handle, or refuses the spec whole with a code
naming what was wrong — nothing is ever partially built.

```lua
Open77.exports.call("opx77_input", "open", spec)
```

- spec: [`InputSpec`](types.md#inputspec)
    - The form to build. Only `fields` is required; see
      [The form spec](form-spec.md#spec).

**Returns** [`InputOpened`](types.md#inputopened) — on success `handle`
(unique for the life of the client session), `id` (the form's id, defaulting to
your resource name) and `fields` (how many it built).

Opening while you already have a form open replaces it: the old one answers
first, with `action = "cancel"` and `reason = "reopened"`. The new spec is
validated before the old form is taken down, so a refused spec costs the player
nothing.

**Errors — call and ownership**

| Code | Meaning |
|---|---|
| `no_surface` | The WebUI surface never came up. Nothing can be drawn. |
| `export_call_required` | The call did not arrive through the export mechanism, so the host named no calling resource. |
| `spec_must_be_a_table` | `spec` was not a table. |
| `input_busy` | Another resource owns the open form. There is no `steal`. |
| `keyboard_busy` | Another surface already holds the keyboard — chat's composer, the pause menu. |
| `no_keyboard` | The host refused to give the keyboard to this surface. No form is left open. |
| `invalid_owner` | The calling resource's name failed name validation. |

**Errors — the form. The spec is refused whole**

| Code | Meaning |
|---|---|
| `invalid_form_id` | `spec.id` is not a [valid name](form-spec.md#names) of at most 64 characters. |
| `invalid_description` | `spec.description` is not text, or is longer than 160 characters. |
| `invalid_event` | `spec.event` is not a valid name of at most 96 characters. |
| `invalid_status` | `spec.status` is not text, or is longer than 120 characters. |
| `invalid_form_data` | `spec.data` is not a table. |
| `form_data_too_large` | `spec.data` exceeds 64 nodes or 4 levels of nesting. |
| `fields_must_be_a_table` | `spec.fields` is not a table. |
| `empty_form` | `spec.fields` has no entries. |
| `too_many_fields` | More than 8 fields. |
| `duplicate_field_id` | Two fields share an `id`. The answer is keyed by id, so one answer would be lost. |

**Errors — a field**

| Code | Meaning |
|---|---|
| `field_must_be_a_table` | A field is not a table. |
| `invalid_field_id` | A field `id` is not a valid name of at most 64 characters. |
| `invalid_field_label` | A field has no usable `label`, or one longer than 96 characters. |
| `invalid_field_description` | A field `description` is not text, or is longer than 160 characters. |
| `invalid_options` | `options` is not a table. |
| `empty_options` | `options` has no entries. |
| `too_many_options` | More than 64 options. |
| `invalid_option` | An option is not a string, a number or a table with a label of at most 48 characters. |
| `invalid_option_value` | An option `value` is neither a finite number nor text of at most 96 characters. |
| `invalid_selected` | `selected` is not a whole number within the options. |
| `invalid_slider` | `slider` is not a table. |
| `invalid_slider_range` | The slider's `max` is not above its `min`. |
| `invalid_slider_suffix` | The slider's `suffix` is not text, or is longer than 8 characters. |
| `invalid_max_length` | `maxLength` is not a whole number from 1 to 512. |
| `invalid_placeholder` | `placeholder` is not text, or is longer than 64 characters. |
| `invalid_charset` | `charset` is not a string. |
| `unknown_charset` | `charset` names none of the [five sets](form-spec.md#charsets). |
| `invalid_pattern` | `pattern` is empty, longer than 64 characters, or not a Lua pattern that compiles. |
| `invalid_value` | A text field's initial `value` is not text, is past `maxLength`, or is refused by the field's own `charset` or `pattern` — a caller's bug, not a player's. |

**Side** `client export` — callable by any client resource through
`Open77.exports.call`. Asynchronous: it answers a promise, and `await` is only
usable inside a `CreateThread`. Not reachable from a server resource, and not
reachable as an event.

### Example {#open-example}

```lua
-- a client file of your own resource
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_input", "open", {
    title = "New plate",
    event = "garage:plateAnswered",
    data = { vehicle = 7 },
    fields = {
      { id = "plate", label = "Plate", placeholder = "KV-000",
        maxLength = 8, charset = "name", required = true },
      { id = "colour", label = "Colour",
        options = { "Crimson", { label = "Ice", value = "ice" } }, selected = 1 },
      { id = "tint", label = "Tint",
        slider = { min = 0, max = 100, step = 5, value = 40, suffix = "%" } },
    },
  })
  if not promise then return Open77.log.warn(tostring(reason)) end
  local opened, callError = promise:await()
  if callError or not opened.ok then
    return Open77.log.warn("form refused: " .. tostring(callError or opened.error))
  end
end)

AddEventHandler("garage:plateAnswered", function(payload)
  if type(payload) ~= "table" or payload.action ~= "submit" then return end
  print(payload.values.plate, payload.values.colour, payload.values.tint)
end)
```

## close {#close}

Takes your own form back down. The form still answers, exactly once, with
`action = "cancel"` and `reason = "caller"`.

```lua
Open77.exports.call("opx77_input", "close")
Open77.exports.call("opx77_input", "close", handle)
```

- handle?: [`InputHandle`](types.md#inputhandle)
    - The form to close. Omitted means *"my form, whichever handle it has"*.

**Returns** [`InputResponse`](types.md#inputresponse).

**Errors**

| Code | Meaning |
|---|---|
| `no_surface` | The WebUI surface never came up. |
| `export_call_required` | The call did not arrive through the export mechanism. |
| `no_form_open` | Nothing is open. |
| `not_owner` | The open form belongs to another resource. A caller may never close another's. |
| `not_open` | A `handle` was passed and it is not the open form's. |

**Side** `client export` — as [`open`](#open).

## state {#state}

Reports whether a form is open and whether it is yours; it never fails, and
`ok` is always `true`.

When the open form is **not** yours — or nothing is open — the answer is
deliberately just `{ ok = true, open = <boolean>, mine = false }`. When it is
yours, the snapshot adds `handle`, `owner`, `form`, `title`, `index` (the
focused field's position), `total` and `fieldId`.

It **never reports what the player has typed**, not even to the owner: the
answer is the event, and there is no second way to read it.

This is the one export that answers even when the WebUI surface failed.

```lua
Open77.exports.call("opx77_input", "state")
```

Takes no arguments.

**Returns** [`InputState`](types.md#inputstate).

**Errors** — none.

**Side** `client export` — as [`open`](#open).

## setStatus {#setstatus}

Writes the transient line under the fields, or clears it now when `text` is
`nil`. The line clears itself after **six seconds**.

```lua
Open77.exports.call("opx77_input", "setStatus", text, ok)
```

- text: `string | nil`
    - The line. A number is accepted; at most 120 characters. `nil` clears it.
- ok?: `boolean`
    - `false` marks a failure, which draws the line red. Default: `true`.

The same line carries this resource's own refusals — a character a field does
not accept, a required field left empty — in the player's language, so a line of
yours can be replaced by one of those while the player types.

**Returns** [`InputResponse`](types.md#inputresponse).

**Errors**

| Code | Meaning |
|---|---|
| `no_surface` | The WebUI surface never came up. |
| `export_call_required` | The call did not arrive through the export mechanism. |
| `no_form_open` | Nothing is open. |
| `not_owner` | The open form belongs to another resource. |
| `invalid_status` | `text` is neither `nil`, a string nor a number, or is longer than 120 characters. |

**Side** `client export` — as [`open`](#open).

## See also {#see-also}

- [The form spec](form-spec.md) — what `open` accepts, field by field.
- [Events](events.md) — where the answer arrives.
- [Types](types.md) — every shape named on this page.
