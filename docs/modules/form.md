---
title: form module
description: The modal that asks the player for typed text, a choice or a slider value, opened by other client modules through the form contract.
---

# form

The form module draws one modal box that asks the player for values: up to eight fields of typed text, a choice list or a slider, answered together with Enter or cancelled with Escape. Other client modules open it through the `form` contract and get one callback with every answer. Lua holds the real text of each field and checks length, character set, pattern and required fields itself; the page only proposes keystrokes. Use it when a module needs the player to type an amount, a name or a code.

| | |
|---|---|
| Side | client |
| Requires | none |
| Optional | `downed` (no form opens over a downed player) |
| Configuration | `config/form.lua` (shared script) |
| Contract | `form` v1 — client |
| Data | none |

## Client contract {#client-contract}

`local form = OPX.Api.Get('form')` on the client, from code inside opx_infinity. Every function answers `{ ok = true, value = … }` or `{ ok = false, error = code }`. None yields: the answer arrives later through `spec.on`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-form-open"></a>`Open` | `spec` | `{ handle, id, fields }` | Opens a form from a [spec](#the-form-spec). Refused whole on the first bad field. If another owner's form is open, answers `form_busy` (there is no `steal`). The same owner opening again cancels its old form with reason `reopened`. |
| <a id="client-form-close"></a>`Close` | `handle` | `true` | Takes the form down. The callback still runs, as `cancel` with reason `caller`. |
| <a id="client-form-setstatus"></a>`SetStatus` | `handle?, text, bad?` | `true` | Writes the status line under the fields (max 120 characters), red when `bad`. Clears after `STATUS_MS`. `nil` or `''` clears it. |
| <a id="client-form-state"></a>`State` | — | `{ open = false }` or `{ open, handle, owner, form, title, index, total, fieldId }` | The open form and the focused field. |

### The form spec {#the-form-spec}

| Field | Type | Default | Meaning |
|---|---|---|---|
| `owner` | string | required | Your module id. Letters, digits, `_ : - .`, max 64. If that module stops, the form is cancelled (`owner_stopped`). |
| `on` | function | required | `on(payload)`, called once on submit or cancel. See [The answer](#the-answer). |
| `fields` | list | required | 1 to 8 [fields](#fields). Field ids must be unique. |
| `id` | string | `owner` | Echoed as `payload.form`. |
| `title` | string | `owner` upper-cased | The question, max 96 characters. |
| `description` | string | — | A note under the title, max 160. |
| `data` | table | — | Echoed as `payload.data`. Max 64 nodes, 4 levels. |
| `cursor` | string or integer | first field | Field id or index to focus first. |
| `status`, `statusBad` | string, boolean | — | Status line at open. |

### Fields {#fields}

The kind comes from the shape: `options` makes a choice, `slider` makes a slider, anything else is text.

| Kind | Shape | Answer value |
|---|---|---|
| text | `maxLength` (1..512, default 96), `placeholder` (max 64), `value` (initial text), `required`, `charset`, `pattern` | The typed string, `''` when empty. |
| choice | `options = { 'A', 'B' }` or `{ { label, value }, … }` (max 64, label max 48), `selected` (index) | The chosen option's `value` (its label when no value was given). |
| slider | `slider = { min = 0, max = 100, step = 1, value, suffix }` | A number. |

Every field also takes `id` (default `field_<index>`), `label` (required, max 96) and `description` (max 160, shown when focused).

| Text rule | Checked | On failure |
|---|---|---|
| `maxLength` | every keystroke | Keystroke refused, `form.refuse.tooLong` shown. |
| `charset` | every keystroke | Keystroke refused, `form.refuse.character`. Values: `alnum`, `alpha`, `digits`, `hex`, `name` (letters, digits, space, `- _ . '`). |
| `required` | on Enter | Focus moves to the field, `form.refuse.required`. |
| `pattern` | on Enter | A Lua pattern, max 64 characters, anchored automatically. `form.refuse.format`. |

Keys: Up/Down move between fields, Left/Right change a choice or slider, typing edits a text field, Enter submits, Escape cancels.

### The answer {#the-answer}

`on(payload)` and [`opx:on:form:answer`](#opx-on-form-answer) receive:

| Field | Meaning |
|---|---|
| `form`, `handle`, `owner` | Which form. |
| `action` | `submit` or `cancel`. |
| `values` | On `submit` only: `{ [fieldId] = value }`. |
| `reason` | On `cancel`: `caller`, `dismissed` (Escape on the page), `pause`, `reopened`, `owner_stopped`, `player_down`, `stopped`. |
| `data` | The spec's `data`. |

```lua
OPX.Api.Get('form').Open({
  owner = 'mymodule',
  title = 'Withdraw',
  fields = { { id = 'amount', label = 'Amount', charset = 'digits', required = true, maxLength = 7 } },
  on = function(p)
    if p.action == 'submit' then print(tonumber(p.values.amount)) end
  end,
})
```

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-on-form-answer"></a>`opx:on:form:answer` | client local | the [answer payload](#the-answer) | Raised after the owner's callback for every submit and cancel. Reaches only code inside opx_infinity's client VM. |

## Page channels {#page-channels}

All on the `interactive` surface; every payload carries the form `handle`.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-form-edit"></a>`form:edit` | page → Lua | `{ handle, id, seq, text }` | Candidate text for a field. Lua answers with the accepted text in the next frame. |
| <a id="page-form-key"></a>`form:key` | page → Lua | `{ handle, key, repeat }` | `up`, `down`, `left`, `right` or `enter`. |
| <a id="page-form-step"></a>`form:step` | page → Lua | `{ handle, id, direction }` | Click on a choice/slider arrow; `direction` is `1` or `-1`. |
| <a id="page-form-focus"></a>`form:focus` | page → Lua | `{ handle, id }` | The player clicked into a field. |
| <a id="page-form-dismiss"></a>`form:dismiss` | page → Lua | `{ handle }` | Escape; cancels with reason `dismissed`. |
| `focus:set` | page → Lua | `{ owner, focus }` | Shared; the form answers for owner `form` (keyboard only). |
| `form:open` | Lua → page | first frame plus `anchor, width, dim` | Re-sent until the page is ready. |
| `form:frame` | Lua → page | `{ handle, title, note, rows, hint, keys, status, statusBad }` | Every field, with `ack` (last `seq` ruled on) on text rows. |
| `form:close` | Lua → page | `{ handle }` | Take the form down. |

## Configuration {#configuration}

`config/form.lua` sets `OPX.Config.MODULES.form`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-form-enabled"></a>`enabled` | `true` | `false` switches the module off. |
| <a id="config-form-anchor"></a>`ANCHOR` | `'center'` | `center`, `top-left`, `top-right`, `left` or `right`. |
| <a id="config-form-width"></a>`WIDTH` | `420` | Box width in pixels. |
| <a id="config-form-dim"></a>`DIM` | `true` | Dim the scene behind an open form. |
| <a id="config-form-status-ms"></a>`STATUS_MS` | `6000` | Milliseconds the status line stays up. |
| <a id="config-form-while-down"></a>`WHILE_DOWN` | `{ admin = true }` | Owners whose form may open, and stays open, while the player is down. |

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `spec_must_be_a_table`, `invalid_owner`, `callback_required` | Bad spec basics. |
| `no_surface` | The interactive WebUI surface does not exist. |
| `player_down` | The player is down and the owner is not in `WHILE_DOWN`. |
| `form_busy` | Another owner's form is open. |
| `invalid_form_id`, `invalid_description`, `invalid_status` | Spec field malformed or too long. |
| `invalid_form_data`, `form_data_too_large` | `data` not a table, or over 64 nodes / 4 levels. |
| `fields_must_be_a_table`, `empty_form`, `too_many_fields`, `duplicate_field_id` | The field list is wrong. |
| `field_must_be_a_table`, `invalid_field_id`, `invalid_field_label`, `invalid_field_description` | A field is malformed. |
| `invalid_options`, `empty_options`, `too_many_options`, `invalid_option`, `invalid_option_value`, `invalid_selected` | A choice field is malformed. |
| `invalid_slider`, `invalid_slider_range`, `invalid_slider_suffix` | A slider field is malformed. |
| `invalid_max_length`, `invalid_placeholder`, `invalid_charset`, `unknown_charset`, `invalid_pattern`, `invalid_value` | A text field is malformed, or its initial `value` breaks its own rules. |
| `handle_required`, `no_form_open`, `stale_handle` | `Close`/`SetStatus` on nothing or on an old handle. |

Player-facing locale keys: `form.refuse.required`, `form.refuse.format`, `form.refuse.character`, `form.refuse.tooLong`, and the key caps `form.key.*`.
