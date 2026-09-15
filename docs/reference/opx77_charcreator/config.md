---
title: opx77_charcreator configuration
description: Every key of OPX_CHARCREATOR_CONFIG with its shipped default — the language, the three event channels, whether to answer needsCreation, whether to hand the player back to the roster, whether to hold the stage, and the registration deadline — and the locale catalogue.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_CHARCREATOR_CONFIG`,
loaded first by the manifest. **Every value shown on this page is the shipped
default.**

```lua
--- @author DemiAutomatic
--- @file config.lua
--- @description Event names, handoffs to other resources, and the registration deadline.
--- @field LOCALE {string} Catalogue for player-facing text: 'en' or 'fr'.
--- @field EVENT {string} Client event this resource publishes its decisions on.
--- @field SELECTOR_EVENT {string} Must match OPX_CHARSELECTOR_CONFIG.EVENT.
--- @field APPEARANCE_EVENT {string} Must match OPX_APPEARANCE_CONFIG.EVENT.
--- @field ANSWER_NEEDS_CREATION {boolean} Answer needsCreation by calling opx77_appearance's openCreator.
--- @field RETURN_TO_SELECTOR {boolean} Put the selection screen back up when a creation ends.
--- @field HOLD_STAGE {boolean} Hold opx77_charselector's stage while a character is built.
--- @field REQUEST_TIMEOUT_MS {integer} Milliseconds before an unanswered registration reopens the form.

OPX_CHARCREATOR_CONFIG = {
	LOCALE = 'en',
	EVENT = 'opx77:charcreator',
	SELECTOR_EVENT = 'opx77:charselector',
	APPEARANCE_EVENT = 'opx77:appearance',
	ANSWER_NEEDS_CREATION = true,
	RETURN_TO_SELECTOR = true,
	HOLD_STAGE = true,
	REQUEST_TIMEOUT_MS = 20000,
}
```

!!! info "There is no `PREVIEW` block"

    Earlier builds shipped one for a camera at a fixed world point, which was
    never implemented. The camera is now `opx77_charselector`'s
    [stage](../opx77_charselector/stage.md), which this resource
    [holds](#hold-stage); `state` no longer reports `previewPlaced`.

## LOCALE {#locale}

Which `locales/<code>.lua` catalogue player-facing text is read from.

```lua
LOCALE = 'en'
```

**Type** `string` — `"en"` or `"fr"` as shipped. See [Locales](#locales).

## EVENT {#event}

The client event raised after every decision this resource reaches.

```lua
EVENT = 'opx77:charcreator'
```

**Type** `string` — a name of its own.

The payloads are [`CreatorEvent`](types.md#creatorevent), listed on
[Events](events.md#opx77-charcreator). A value that is not a string, or that
equals `SELECTOR_EVENT`, `APPEARANCE_EVENT` or the form's private answer name,
publishes nothing — every publish would otherwise re-enter the handler for that
channel — and the boot logs one error.

## SELECTOR_EVENT {#selector-event}

The channel `opx77_charselector` raises `createRequested` on.

```lua
SELECTOR_EVENT = 'opx77:charselector'
```

**Type** `string` — must match
[`OPX_CHARSELECTOR_CONFIG.EVENT`](../opx77_charselector/config.md#event).

A value that is not a string is read as the shipped name, because
`AddEventHandler` raises on a non-string and that would abandon the whole file.

## APPEARANCE_EVENT {#appearance-event}

The channel `opx77_appearance` publishes its decisions on.

```lua
APPEARANCE_EVENT = 'opx77:appearance'
```

**Type** `string` — must match `OPX_APPEARANCE_CONFIG.EVENT` in that resource.
A value that is not a string is read as the shipped name.

## ANSWER_NEEDS_CREATION {#answer-needs-creation}

Whether to answer `opx77_appearance`'s
[`needsCreation`](../opx77_appearance/events.md#needs-creation) by calling its
[`openCreator`](../opx77_appearance/exports.md#opencreator) export, which opens
the in-world face editor on the character's body.

```lua
ANSWER_NEEDS_CREATION = true
```

**Type** `boolean` — only `false` turns it off.

Nothing else answers `needsCreation` on a stock install. With this off and no
other resource answering, `opx77_appearance` waits its own `CREATION_WAIT_MS`,
says in the log that nothing called `openCreator`, and lets the player in on the
default face of their body with nothing stored. Set it to `false` only where
another resource takes the job. See
[Who opens the face editor](index.md#face-editor).

## RETURN_TO_SELECTOR {#return-to-selector}

Whether to put `opx77_charselector`'s screen back up when a creation ends.

```lua
RETURN_TO_SELECTOR = true
```

**Type** `boolean` — only `false` turns it off.

At once when the player backs out; a second after a character was created, if
the roster `opx77_core` sends has not brought the screen back by itself. While a
creation it handed over runs, `opx77_charselector` reopens nothing on its own, so
without this a player who cancels is left looking at the world with nothing to
choose from. See [Handing the player back](index.md#hand-back).

## HOLD_STAGE {#hold-stage}

Whether to hold `opx77_charselector`'s stage while a character is being built —
the camera it turned to face the character stays there, and the character stays
where it stood, from the roster through the form and back.

```lua
HOLD_STAGE = true
```

**Type** `boolean` — only `false` turns it off.

The look is configured there, under
[`STAGE`](../opx77_charselector/config.md#stage). `false` lets the stage go when
the [hand-over window](../opx77_charselector/stage.md#handover) runs out, about
five seconds after the roster closes for the form; the form still keeps the walk
keys from the game while it is up. A value that is not a boolean holds the stage
and says so once at start:

```text
HOLD_STAGE is not a boolean: the stage is held
```

## REQUEST_TIMEOUT_MS {#request-timeout-ms}

How long a submitted registration may stay unanswered before the form comes back
with the answers still in it, in milliseconds.

```lua
REQUEST_TIMEOUT_MS = 20000
```

**Type** `integer`

`opx77_core` answers `CreateCharacter` by event, not by return value — a fuller
roster, or a refusal naming `createCharacter` — so a lost reply would leave the
player looking at nothing. Past the deadline the form reopens on `firstName` with
*Nothing answered. Try again.* A value that is not a positive number turns the
deadline off.

The deadline is one `SetTimeout` armed when the registration is sent, for this
many milliseconds rounded up; it reopens the form only while that same
registration is still out. A duration the host refuses leaves that registration
without a deadline, with one warning:

```text
the registration deadline could not be armed: <reason>
```

## Locales {#locales}

`locales/en.lua` and `locales/fr.lua`. The catalogue carries the form's title,
field labels, descriptions, placeholders, body labels and every refusal this
resource checks for, **and** the core codes a registration can be refused with.

The lifepath labels are **not** translated here. They come from
`opx77_core/data/origins.lua`, which is the server owner's own words.

To add a language, copy `locales/en.lua` to `locales/<code>.lua`, change the code
in the `register` call, translate the values, add a
`shared_script "locales/<code>.lua"` line to `open77.lua` beside the others, and
set [`LOCALE`](#locale) to it. A key missing from a catalogue falls back to
English, then to the key itself. `Open77.log` lines stay English whatever the
setting.

## Constants that are not keys {#constants}

| Constant | Value | What it is |
|---|---|---|
| `RETURN_GRACE_MS` | `1000` | How long a creation that made a character leaves the roster to come back on its own. |
| Name bounds | `2`–`32` | Used until `opx77_core`'s `GetSharedConfig` answers with its own `nameBounds`. |
| Birth date | `YYYY-MM-DD`, 8–10 characters, a real day from 1900 | Checked here for the shape, then the calendar. `opx77_core` refuses a well-shaped date that is not a real day, or is before 1900, with `character.badBirthdate`. Nothing checks that it lies in the past. |
| Answer event | `opx77:charcreator:answered` | The private name `opx77_input` answers this resource's form on. |
