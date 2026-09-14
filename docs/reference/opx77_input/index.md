---
title: The opx77_input resource
description: opx77_input owns the one form on the client — text fields, choice lists and sliders answered together — drawn as opx77_menu's strip, holding the keyboard for exactly as long as the form is open, and answering with one event.
---

# opx77_input

!!! warning "Early development"

    `opx77_input` is version `0.1.0`. The exports, the payload shape and the
    error codes are subject to change without notice. Do not build a production
    resource on the current surface.

One resource owns the form. Every other resource asks it for one or more values
through a client export and is told what the player answered by an event.
[`opx77_menu`](../opx77_menu/index.md) draws a list of choices; this draws what a
list cannot — a typed line, a picked option, a number on a slider — answered
together, in one form.

## At a glance {#at-a-glance}

| At a glance | |
|---|---|
| **Version** | `0.1.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared, and nothing needs to be running for it to start |
| **Auto start** | yes |
| **Reload policy** | `reconnect` — swapping a live CEF surface mid-session is unstable, so a generation change reconnects |
| **Permissions** | `input.actions` — `Open77.input.isCaptured`, asked before a form takes the keyboard |
| **Sides** | client only. The server runtime has no `exports`, so there is no server surface |
| **Exports** | four, all client: [`open`](exports.md#open), [`close`](exports.md#close), [`state`](exports.md#state), [`setStatus`](exports.md#setstatus) |
| **Commands** | none |
| **Events** | one local event per form, on the caller's name and on [`opx77:input`](events.md#opx77-input) — see [Events](events.md) |
| **Reads** | nothing in the framework. [`opx77_charcreator`](../opx77_charcreator/index.md) is its one caller on a stock install |

## Why a form, and not one value at a time {#why-a-form}

A caller that needs three values from a one-value service opens three modals in
a row and has to sequence them itself: listen for the first answer, open the
second from inside that handler, and hold its own half-built result across all
three. Worse, the form is one-at-a-time keyed on the caller, so a second
resource can take the slot between two of them and the sequence is left
half-answered.

So the primitive here is the **form**, and one field is simply a form with one
field — the same code path, and the common case still reads as one call. The
answer is one event carrying every value at once, which is also the shape a
caller wants: `payload.values.plate`.

There is no `update`. A form is answered in seconds, and rebuilding one under
the player would throw away what they have already typed; a caller that needs
different fields closes and opens again.

## The surface {#surface}

The manifest declares the page but not its creation — `web_ui_auto_create false`
— because `client/main.lua` creates it, so a failure is one logged line rather
than a dead resource:

```lua
web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }
```

It is a `1920x1080`, transparent, **60 fps** surface on the `hud` layer at
`zIndex` **728** — above `opx77_menu` (725), below `open77_admin`'s strip (730).
Sixty rather than the menu's thirty because this surface carries a caret and the
player is typing at it. The surface is created visible: one created hidden never
uploads a frame once shown.

!!! warning "A failed surface refuses, it does not pretend"

    When `WebUI.create` fails, the resource logs

    ```text
    WebUI surface failed: <reason>
      the exports will refuse: there is nothing to ask on.
    ```

    and [`open`](exports.md#open), [`close`](exports.md#close) and
    [`setStatus`](exports.md#setstatus) answer `no_surface`.
    [`state`](exports.md#state) still answers, because it draws nothing.

## The look {#look}

The form is drawn exactly as `opx77_menu` draws a menu, and its stylesheet
carries the menu's values. Going from a list to the form it leads to — the
character roster to the identity form is the stock case — reads as one UI rather
than a switch to another.

- The strip sits at the menu's [`ANCHOR`](config.md#anchor) and is the menu's
  [`WIDTH`](config.md#width), with the same slide-in.
- A title plate carries the yellow accent rule and the scanline.
- One cut plate per field: the label on the left, the value on the right, and
  `‹›` beside a value that `LEFT` and `RIGHT` change.
- The focused field is the menu's cursor row: it pops out of the column in
  yellow.
- A text field's typed line sits where a menu row's value does and is sized in
  characters, so its plate grows with what it holds. The character count shows
  on the focused field only.
- The form's description, the focused field's description, the status line
  (red on a refusal) and the key line each follow as a plate of their own
  underneath, the key line in the menu's breadcrumb voice.

There is no scrim as shipped: [`DIM`](config.md#dim) is off, because the menu
draws none, and a scene dimmed behind one panel and not the other reads as two
UIs.

## The keyboard {#keyboard}

The arrows and `ENTER` mean what they mean in the menu:

| Key | In the form |
|---|---|
| `UP`, `DOWN` | move between fields. Wraps |
| `LEFT`, `RIGHT` | change a choice or step a slider; on a text field they move the caret |
| `ENTER` | submit. `required` and `pattern` are checked here |
| `ESCAPE` | cancel |
| `BACKSPACE` | belongs to the text fields. It is not the menu's way back here |

Unlike the menu, which draws on a surface that is never focused, **this surface
takes focus** — `setFocus(true)` on open, `setFocus(false)` on every answer. It
is how the platform keeps the typed keys, and the walk keys, from the game while
a form is up. The page reports each key; Lua decides what it means, and a key
name outside the six above is dropped.

### Taking the keyboard, and giving it back {#focus}

- `open` asks `Open77.input.isCaptured()` first and answers `keyboard_busy`
  when another surface already holds the keyboard — chat's composer, the pause
  menu. Taking it from chat's composer would type the player's line into
  nothing.
- A host that refuses focus answers `no_keyboard`, and no form is left open
  without it.
- The keyboard is handed back **before** the answer is raised, so a handler that
  opens something else finds it free.
- A stop of this resource hands it back unconditionally: a keyboard left
  captured over a stop leaves the player unable to move.

When the manifest's grant is missing, or the host refuses the probe, the start
says so and carries on:

```text
the keyboard cannot be read (no_is_captured -- the manifest must grant input.actions)
  a form will open over whatever else already holds it.
```

Escape always cancels. So does the platform's own pause key, raised as
`open77:pauseKey` even where the page never sees the keystroke — that is the
backstop that stops a broken page from stranding a player in a form they cannot
leave.

## One form at a time {#one-form}

There is one open form on the client, or none.

- A second resource asking to open one is refused with `input_busy`. There is
  **no way to steal it**: the player is typing into it, and taking it away loses
  their work and fires an answer at somebody who did not ask for one.
- The same resource may replace its **own** open form. The one it replaces still
  answers, with `action = "cancel"` and `reason = "reopened"`. The new spec is
  validated before the old form is taken down.
- A form never outlives the code that opened it. The caller's generation is read
  from the host on every export call, and a sweep runs once a second while a form
  is open: an owner that stopped or reloaded has its form cancelled within that
  second, with `owner_reloaded` or `owner_stopped`.

## Where to go next {#next}

- [Exports](exports.md) — the four calls and every code they refuse with.
- [The form spec](form-spec.md) — the spec table, the three field kinds and
  every limit.
- [Events](events.md) — the one answer a form raises, and every cancel reason.
- [Configuration](config.md) — the four keys in `config.lua`, and the locale
  catalogue.
- [Types](types.md) — every shape named on these pages.
- [The client export contract](../../concepts/export-contract.md) — how to call
  an export correctly, and the three levels of failure.
