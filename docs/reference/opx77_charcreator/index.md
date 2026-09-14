---
title: The opx77_charcreator resource
description: opx77_charcreator is the flow between the character roster and a character that exists — one opx77_input form checked against opx77_core's own rules, the write through the core, the hand-back to the roster, the stage it holds, and the call that opens opx77_appearance's in-world editor.
---

# opx77_charcreator

Character creation. The flow between the character roster and a character that
exists: it asks the player who they are, checks the answers against the rules
`opx77_core` will apply anyway, writes the character through the core, hands the
player back to the roster, and opens the face editor for a character that has no
face.

**It draws nothing of its own.** The form is
[`opx77_input`](../opx77_input/index.md)'s, the character row
[`opx77_core`](../opx77_core/index.md)'s, the camera on the character
[`opx77_charselector`](../opx77_charselector/stage.md)'s, and the face
[`opx77_appearance`](../opx77_appearance/index.md)'s. What is here is the flow,
and the flow is the whole of it.

## At a glance {#at-a-glance}

| At a glance | |
|---|---|
| **Version** | `0.1.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared; a missing `opx77_input` is one logged line |
| **Auto start** | yes |
| **Reload policy** | none declared, so the host's default applies. It holds no surface and no state a reload could strand |
| **Permissions** | none. The stage's camera and hold are `opx77_charselector`'s, reached through its exports, so the grants they need are in that manifest |
| **Sides** | client only. No `web/`, no `server/`, no `sql/`, no table, no `database.access` |
| **Exports** | four, all client: [`open`](exports.md#open), [`close`](exports.md#close), [`isOpen`](exports.md#isopen), [`state`](exports.md#state) |
| **Commands** | none |
| **Events** | raises [`opx77:charcreator`](events.md#opx77-charcreator) after every decision; listens to `opx77_charselector`, `opx77_input`, `opx77_core` and `opx77_appearance` — see [Events](events.md) |
| **Reads** | `opx77_core` for the rules and the write; `opx77_input` for the form; `opx77_charselector` for the roster and the stage; `opx77_appearance`'s `needsCreation` |

## Where it sits {#where-it-sits}

```text
opx77_charselector --(createRequested)--> opx77_charcreator --(open)--> opx77_input
                                                 |                          |
                                          CreateCharacter <---(answer)------+
                                                 v
                                            opx77_core --(charactersReady)--> the roster
```

**All of it happens in the gameplay world.** `opx77_appearance` spends the
platform's character bootstrap at join, before anybody is chosen, so the loading
cover lifts first and the roster, this form and the face editor are drawn over
Night City like any other HUD surface. Nothing here runs in the pre-game menu or
waits on a bootstrap phase. See [The entry gate](../../concepts/entry-gate.md#world-first).

1. `opx77_charselector` draws the roster once that world is up. When the player
   presses an empty slot or the create row it takes its own screen down, raises
   [`createRequested`](../opx77_charselector/events.md#create-requested) and
   stops. That event is this resource's entry point.
2. This resource [holds the stage](#the-stage), reads the lifepaths and the name
   bounds from the core, and puts the form up.
3. The answer is checked here. A refusal reopens the form with the answers still
   in it; a pass is sent to the core's
   [`CreateCharacter`](../opx77_core/exports/client.md#createcharacter).
4. The core answers **by event**. A fuller roster on `charactersReady` is a
   character made: `opx77_charselector` comes back with the new row under the
   cursor, and this resource stands down. A refusal naming `createCharacter`
   reopens the form with the reason under it.
5. The player selects the new character. It has no face, so `opx77_appearance`
   publishes `needsCreation`, and this resource
   [answers it](#face-editor) by opening the in-world editor.

This resource never selects a character and never places anybody.

## Handing the player back {#hand-back}

While a creation it handed over runs, `opx77_charselector` reopens nothing by
itself — not on a world entry, not on a dismissal — so a flow that ends has to
ask for the roster back, or the player is left in the world with nothing to
choose from and no way forward.

| The flow ends because | The roster |
|---|---|
| the player backs out, or the form could not be drawn | asked for at once through `opx77_charselector`'s `open` |
| a character was created | left to the roster `opx77_core` sends; if the screen has not come back **1 second** later, asked for through `open` |
| a character loaded meanwhile | not asked for: there is no roster to go back to |
| a newer flow has started | not asked for: its form is up |

`open` refusing with `no_roster` or `world_not_ready` is **not a failure**: that
resource puts the roster up by itself once it has one and the world is there. Any
other refusal is one log line:

```text
opx77_charselector refused open: <reason>
```

[`RETURN_TO_SELECTOR`](config.md#return-to-selector) turns the hand-back off.

## The form {#the-form}

One `opx77_input` form, five fields, well under the eight that resource allows:

| Field | Kind | Sent as |
|---|---|---|
| `firstName` | text | `required`, `maxLength` from the core's name bounds, `pattern` |
| `lastName` | text | the same |
| `birthDate` | text | `required`, `maxLength = 10`, `pattern = "^%d%d%d%d%-%d%d%-%d%d$"` |
| `origin` | choice | the core's `GetOrigins`, sorted by key so the list is the same on every run |
| `gender` | choice | `female` and `male`, labelled from this resource's catalogue |

**No `charset` is named on the name fields.** Every set `opx77_input` offers is
ASCII-only, and `opx77_core` deliberately accepts *"Éloïse"*, so naming one would
refuse a name the server would have stored. The `pattern` carries the core's own
byte class instead, and `opx77_input` checks it on `ENTER`.

The answer arrives on this resource's own private event name. Every value is
checked again here — trimmed, measured in characters, matched against the core's
rule — and a failure **reopens the form** with the answers still in it, the
cursor on the field that refused, and the reason under the fields in the player's
language. Minimum length is the one rule the form cannot express, so it is always
this resource that says *"At least 2 characters."*

**One rule here is stricter than the core's**, deliberately: the core
shape-checks the birth date and quietly substitutes `2050-01-01` for one it
cannot read, and a date the player never typed is worse than being asked again.

**One thing is lost to the form**: `opx77_input` has no per-option description,
so the lifepath flavour text in `opx77_core/data/origins.lua` is not shown.

A registration nobody answers puts the form back after
[`REQUEST_TIMEOUT_MS`](config.md#request-timeout-ms), answers intact, with
*Nothing answered. Try again.*

## The stage {#the-stage}

While the roster or this form is up, the camera looks at the player's own
character and the character cannot walk off. That stage is
**`opx77_charselector`'s**: it alone calls the orbit and the hold, declares the
grants, and its [`STAGE`](../opx77_charselector/config.md#stage) block is where
the look is set. This resource only **holds** it for as long as it has the
player, so the camera does not move between the roster and the form.

| When | This resource |
|---|---|
| a flow starts, before anything else yields | calls [`holdStage`](../opx77_charselector/exports.md#holdstage), inside the 5 s the roster keeps the stage after handing a creation over |
| the form is up, or a registration is with the core | holds it. `opx77_input` takes the keyboard for its form but not the mouse, so it is the stage's [lock](../opx77_charselector/stage.md#lock) that keeps the camera still |
| the player backs out | calls `open` for the roster, **then** `releaseStage`: the stage lingers for the roster to take it over |
| a character was created | waits a second for the core's roster, calls `open` if it did not come, then `releaseStage` |
| `RETURN_TO_SELECTOR = false` | `releaseStage` at once, and the stage goes a moment later |
| a character is loaded | `opx77_charselector` has already dropped the stage and every hold; the release answers `not_holder`, which is not logged |
| `needsCreation` is answered | the stage is down: the editor `openCreator` opens has a camera of its own |
| this resource stops | nothing: `opx77_charselector` forgets a hold whose holder stopped or reloaded |

Each flow is counted, so a hand-back still waiting on the roster when the player
starts another creation neither reopens the roster over the new form nor lets go
of its stage. [`HOLD_STAGE`](config.md#hold-stage) turns the holds off.

## Who opens the face editor {#face-editor}

`opx77_appearance` does the face, and it never opens an editor on its own. Once
the player has selected a character with no stored face, it publishes
[`needsCreation`](../opx77_appearance/events.md#needs-creation) and waits for
something to call its [`openCreator`](../opx77_appearance/exports.md#opencreator)
export. That opens Cyberpunk's own customization mirror **in the world**, in
`ripperdoc` mode, on the body the player chose in this form — reloading the
player onto that body first when the world was loaded with the other one.

On a stock install nothing else answers `needsCreation`, so this resource does —
for **any** character with no face, not only one it just built, because the
resource that owns character creation is the honest place for that call. Set
[`ANSWER_NEEDS_CREATION`](config.md#answer-needs-creation) to `false` where
another resource takes the job. A refused call is logged and published as
[`handedOver`](events.md#opx77-charcreator) with `ok = false`:

```text
opx77_appearance refused openCreator: <reason>
```

Everything after the call belongs to `opx77_appearance`: the body, the capture,
the save through `opx77_core`, what happens when the player closes the editor
without confirming, and the readiness announcement.

## When opx77_input is missing {#no-input}

`opx77_input` is optional and not declared a dependency. Without it the boot
warns:

```text
opx77_input is not running; a creation asked for now would refuse
```

and a creation asked for anyway is handed straight back to the roster after:

```text
opx77_input is not running: there is no form to build a character with
  start it, or drive opx77_core's CreateCharacter export yourself.
```

## Where to go next {#next}

- [Exports](exports.md) — the four calls a resource other than the roster uses.
- [Events](events.md) — every decision this resource publishes, and what it
  listens to.
- [Configuration](config.md) — the channels, the hand-back, the stage hold and
  the deadline.
- [Types](types.md) — every shape named on these pages.
