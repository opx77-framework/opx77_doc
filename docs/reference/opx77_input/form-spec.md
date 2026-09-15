---
title: The opx77_input form spec
description: The table opx77_input's open export takes — the form's own fields, the three field kinds and how a field's kind is decided from its shape, the five character sets, what a text field refuses and when, and every limit.
---

# The form spec

The table handed to [`open`](exports.md#open). Only `fields` is required.
Every limit on this page is a **refusal**, with a code: nothing a caller sends is
silently cut, and nothing comes back shorter than it was sent.

## The spec {#spec}

```lua
{
  fields = { ... },
  id = "garage.plate",
  title = "New plate",
  description = "Plates are checked against the registry.",
  event = "garage:plateAnswered",
  data = { vehicle = 7 },
  cursor = "plate",
  status = "connected",
}
```

- fields: [`InputField[]`](types.md#inputfield)
    - One to eight fields. Required.
- id?: `string`
    - A [valid name](#names) of at most 64 characters, echoed as `form` in the
      answer.
    - Default: your resource's name.
- title?: `string`
    - The heading. At most 96 characters.
    - Default: your resource's name, upper-cased.
- description?: `string`
    - A sentence under the title. At most 160 characters.
    - Default: none.
- event?: `string`
    - The event the answer is raised on, besides
      [`opx77:input`](events.md#opx77-input). A valid name of at most 96
      characters.
    - Default: none — the answer then reaches only `opx77:input`.
- data?: `table`
    - Opaque to the form. Echoed untouched in the answer as `data`. At most 64
      nodes — keys count as well as values — nested at most 4 deep.
    - Default: none.
- cursor?: [`InputCursor`](types.md#inputcursor)
    - Which field is focused first: a field `id`, or a 1-based index.
      **Advisory** — an unresolvable value falls back to the first field.
    - Default: the first field.
- status?: `string`
    - A line written under the fields as the form opens; see
      [`setStatus`](exports.md#setstatus). At most 120 characters.
    - Default: none.

## How a field's kind is decided {#kinds}

!!! info "The kind is derived from the shape, never declared"

    `options` makes a **choice**, `slider` makes a **slider**, and anything
    else is a **text** field. There is no `kind` field to set, and the checks
    run in that order, so a field carrying both `options` and `slider` is a
    choice.

Every field accepts these, whatever its kind:

- label: `string`
    - The text on the left. Required; at most 96 characters.
- id?: `string`
    - A valid name of at most 64 characters, unique in the form. It is the key
      the field's answer arrives under in `payload.values`, which is why there is
      no per-field `data`.
    - Default: `field_<n>`, where `n` is the field's 1-based position.
- description?: `string`
    - Shown under the fields while this one is focused. At most 160 characters.
    - Default: none.

## text {#kind-text}

A typed line. The answer is a string, `""` when left empty.

- value?: `string | number`
    - What the field starts with. Refused with `invalid_value` if the field's
      own `maxLength`, `charset` or `pattern` would refuse it.
- placeholder?: `string`
    - Drawn while the field is empty. At most 64 characters.
- maxLength?: `integer`
    - The longest answer, in characters. Default `96`, ceiling `512`: the whole
      answer rides in one event payload, so the ceiling is a payload bound rather
      than a taste.
- charset?: [`InputCharset`](types.md#inputcharset)
    - The characters the field accepts. See [Character sets](#charsets).
- pattern?: `string`
    - A Lua pattern the **whole** answer must match: it is anchored at both
      ends for you, so `%d+` and `^%d+$` mean the same. At most 64 characters.
    - A malformed pattern is refused at `open` with `invalid_pattern`, checked
      by its structure rather than by trying it: a trailing lone `%` (`%d%`), a
      `%b` without its two characters, a `%f` not followed by `[`, an unclosed
      set, a `)` with no open capture, an unclosed capture, more than 32
      captures, or a back reference to a capture not yet closed.
    - A pattern that still raises while matching (too complex for Lua) refuses
      the answer as a format error, and the first failure per field is logged.
- required?: `boolean`
    - An empty answer is refused on `ENTER`. Default: `false`.

### What a text field refuses, and when {#text-refusals}

| Rule | Checked | What the player sees |
|---|---|---|
| `maxLength` | as it is typed | the buffer does not grow; *"This field takes at most {max} characters."* |
| `charset` | as it is typed | the character does not go in; *"That character is not accepted here."* |
| `required` | on `ENTER` | the focus moves to the field; *"This field cannot be left empty."* |
| `pattern` | on `ENTER` | the focus moves to the field; *"That is not a value this field accepts."* |

A refused keystroke is not merely hidden: the accepted buffer stays as it was
and the page is told to put it back, because Lua holds the authoritative text and
the page only reports candidates. Control characters are stripped from every
candidate.

An empty field passes `pattern`, because emptiness is what `required` answers.
Minimum length is the one rule a field cannot express; a caller that has one
checks it in its handler and reopens the form — see
[`opx77_charcreator`](../opx77_charcreator/index.md#the-form), which does.

### Character sets {#charsets}

`charset` names one of a fixed table. A caller cannot pass a class of its own: a
malformed one raises inside `string.match`, and a slow one would run against
every keystroke.

| `charset` | Accepts | Pattern |
|---|---|---|
| `alnum` | letters and digits | `^[%w]+$` |
| `alpha` | letters | `^[%a]+$` |
| `digits` | digits | `^[%d]+$` |
| `hex` | hexadecimal digits | `^[%x]+$` |
| `name` | letters, digits, space, and `-` `_` `.` `'` | `^[%w %-_%.']+$` |

!!! warning "Every set is ASCII"

    Lua's `%a` and `%w` are ASCII-only, so `name` refuses *"Éloïse"*. A field
    that has to accept a name `opx77_core` would store names no `charset` and
    carries the rule in `pattern` instead.

## choice {#kind-choice}

One of an ordered list. `LEFT` and `RIGHT` cycle it, wrapping. The answer is the
chosen option's `value`.

- options: [`InputOption[]`](types.md#inputoption)
    - One to 64 options. A bare string or number means
      `{ label = s, value = s }`. A label is at most 48 characters; a `value` is
      a finite number or text of at most 96 characters, kept exactly as the
      caller wrote it.
- selected?: `integer`
    - Which option starts selected, 1-based. Default: `1`.

## slider {#kind-slider}

A number with a step. `LEFT` and `RIGHT` step it, clamped rather than wrapped —
a volume that jumps from 0 to 100 is a complaint — and snapped back onto the step
grid after every move.

- slider: [`InputSlider`](types.md#inputslider)
    - min?: `number` — Default: `0`
    - max?: `number` — must be above `min`. Default: `100`
    - step?: `number` — taken as its absolute value; zero becomes `1`. Default: `1`
    - value?: `number` — clamped into range. Default: `min`
    - suffix?: `string` — drawn after the number, e.g. `"%"`. At most 8 characters

!!! warning "A slider answers a float"

    The answer is a float even where it renders whole: `40` comes back as
    `40.0`. Handing it straight to `%d` raises.

A whole value is drawn without a decimal, anything else with two.

## Names {#names}

An `id` or `event` is a valid name when it is a non-empty string of letters,
digits, `_`, `:`, `-` and `.` only, within its length: 64 characters for an
`id`, 96 for an `event`.

## Limits {#limits}

| Bound | Value |
|---|---|
| fields per form | 8 |
| options per choice | 64 |
| title, field label | 96 characters |
| option label | 48; option value 96 |
| placeholder | 64 |
| description, form or field | 160 |
| slider suffix | 8 |
| status line | 120 |
| text answer | `maxLength`, default 96, ceiling 512 |
| `pattern` | 64 characters |
| `data` | 64 nodes — keys count as well as values — nested at most 4 deep |

Eight fields is the point where a form stops being a question and becomes a
list, and a list is what [`opx77_menu`](../opx77_menu/index.md) draws. Lengths
are counted in characters, not bytes.

## See also {#see-also}

- [Exports](exports.md#open) — every code a malformed spec is refused with.
- [Events](events.md) — the shape `values` arrives in.
