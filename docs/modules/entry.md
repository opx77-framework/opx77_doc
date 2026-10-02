---
title: entry module
description: The client flow that turns a new, empty character into a playable one — the game's creator for body and face, then a form for the name.
---

# entry

The `entry` module runs on the client and finishes a character the server created empty. When the appearance module says the character needs a body, entry opens the game's own character creator. Once the face is settled, it shows a form asking for a first and last name, and keeps asking until the server accepts one (a name is written once). It also tells other modules when the player is still being asked something, so the spawn menu and the HUD wait. A returning character with a name sees nothing from this module.

| | |
|---|---|
| Side | client |
| Requires | `character` (hard) |
| Optional | `appearance` (no creator without it), `form` (no name form without it) |
| Configuration | `config/entry.lua` (shared script) |
| Contract | `entry` v1 — client |

## The order {#order}

A new character is asked three things, in this order: the **creator** (body and face), the **name**, then the **clothes** (the appearance module's fitting room, if its `WARDROBE.OFFER_POLICY` offers one). The [`spawn`](spawn.md) menu waits until all three are done. Nothing schedules this; each screen waits while the one before it reports busy on `opx:on:entry:state`.

- A cancelled name form comes back after 1.5 s.
- A sent name is waited on for up to 8 s before the form is offered again.
- A refused creator is asked for again after 2 s.

## Client contract {#client-contract}

`local entry = OPX.Api.Get('entry')` on the client, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-entry-state"></a>`State` | — | `Result` | `value = { citizenId, creating, naming, named, wardrobe }`: what the join is still waiting on. |
| <a id="client-entry-askname"></a>`AskName` | — | `Result` | Shows the name form again now, skipping the retry delay. Errors: `no_character`, `already_asking`, `already_named`. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-on-entry-state"></a>`opx:on:entry:state` | client local | `{ open, phase }` | `phase` is `'creator'`, `'name'`, `'wardrobe'` (a fitting room is still owed) or `'idle'`; `open` is false only for `'idle'`. |

Entry also listens to `opx:on:character:loaded`, `changed` and `unloaded`, the appearance module's `opx:on:appearance:decision`, and refusals on `opx:net:runtime:notify` whose `operation` is `name`.

## Configuration {#configuration}

`config/entry.lua` sets `OPX.Config.MODULES.entry`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-entry-enabled"></a>`enabled` | `true` | `false`: nobody is sent to the creator or asked for a name. New characters keep no name. |
| <a id="config-entry-name"></a>`NAME` | `{ MIN = 2, MAX = 32 }` | Length bounds the form uses. Keep them equal to `CHARACTERS.NAME` in `config/character.lua`; the server's bounds are the ones that count. |

## Refusal codes {#codes}

The name is refused by the `character` module: `character.badName`, `character.nameSet`, `error.tooFast`, `error.notLoggedIn`. The form shows the refusal text above the fields and keeps what the player typed. A code with no locale text shows as `That was refused (<code>).`
