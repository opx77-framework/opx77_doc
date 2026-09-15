---
title: opx77_appearance configuration
description: Every key of OPX_APPEARANCE_CONFIG with its shipped default — the language, whether every player's look is handed to the others, the event name, the toasts and their chat fallback, the panel key, the catalogue builds, the deadlines, the clothing block, the two retry counts, the body reload settle and the BOOTSTRAP block that picks the body the world loads with at join — the locale catalogues, and the constants that are not keys.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_APPEARANCE_CONFIG`.
It is declared as a `shared_script`: the file is shipped to every client, and
read by the server half too, for [`PRESENT_BODIES`](#present-bodies).

**Every value shown on this page is the shipped default.**

```lua
--- @author DemiAutomatic
--- @file config.lua
--- @description Operator configuration for faces, clothing, looks and the join bootstrap.
--- @field LOCALE {string} Catalogue code player-facing text is read from.
--- @field PRESENT_BODIES {boolean} Hand every look to other players; false when another resource does.
--- @field EVENT {string} Client event raised after every decision.
--- @field NOTIFY {boolean} Raise toasts through opx77_notify; false writes chat lines instead.
--- @field KEYS {table} Default keys each player can rebind in the pause menu.
--- @field KEYS.PANEL {string|false} Open or close the panel; false registers no mapping.
--- @field GAME_BUILDS {table<string, boolean>} Builds a stored face may be read back into.
--- @field COMMIT_MS {integer} Milliseconds opx77_core has to answer a face or clothing save.
--- @field SAVE_COOLDOWN_MS {integer} opx77_core's save cooldown in milliseconds, waited out.
--- @field CLOTHING {table} What the character wears, stored by opx77_core.
--- @field CLOTHING.PERSIST {boolean} false leaves clothing alone: nothing put on or saved.
--- @field CLOTHING.SAVE_DEBOUNCE_MS {integer} Milliseconds a change holds before it is saved.
--- @field RESTORE_RETRIES {integer} Re-dispatches of a restore the mirror aborted.
--- @field FAMILY_RETRIES {integer} Body reloads and reopened creation editors per character.
--- @field BODY_RELOAD_SETTLE_MS {integer} Milliseconds waited for the respawn after a body reload.
--- @field CREATION_WAIT_MS {integer} Milliseconds needsCreation waits for openCreator.
--- @field BOOTSTRAP {table} The body the world loads with at join.
--- @field BOOTSTRAP.ROSTER_WAIT_MS {integer} Milliseconds waited for opx77_core's roster.
--- @field BOOTSTRAP.DEFAULT_FAMILY {string} 'female' or 'male'; anything else reads 'female'.

OPX_APPEARANCE_CONFIG = {
	LOCALE = 'en',
	PRESENT_BODIES = true,
	EVENT = 'opx77:appearance',
	NOTIFY = true,
	KEYS = {
		PANEL = 'F5',
	},
	GAME_BUILDS = { ['2.31'] = true },
	COMMIT_MS = 20000,
	SAVE_COOLDOWN_MS = 2000,
	CLOTHING = {
		PERSIST = true,
		SAVE_DEBOUNCE_MS = 2000,
	},
	RESTORE_RETRIES = 3,
	FAMILY_RETRIES = 2,
	BODY_RELOAD_SETTLE_MS = 10000,
	CREATION_WAIT_MS = 15000,
	BOOTSTRAP = {
		ROSTER_WAIT_MS = 3000,
		DEFAULT_FAMILY = 'female',
	},
}
```

The panel has nothing to configure here but its key: how it is anchored and how
wide it is drawn belong to [`opx77_menu`](../opx77_menu/config.md).

## LOCALE {#locale}

Which `locales/<code>.lua` catalogue player-facing text is read from.

```lua
LOCALE = 'en'
```

**Type** `string` — `"en"` or `"fr"` as shipped.

Applied at load, from `shared/locale.lua`, which is why the catalogues are
registered in `open77.lua` immediately after it: no file below them ever calls
`locale()` against an empty catalogue. An unknown code is accepted rather than
refused, because catalogues register after the selection is made; a key missing
from the active catalogue falls back to English, then to the key itself.

Each resource in this framework carries its own catalogue, so this is set here as
well as in [`opx77_core`](../opx77_core/config.md#shared-locale). The core's
`Locale` export is client-only and asynchronous, and a resource that renders text
at load cannot wait on it.

`Open77.log` lines and console output stay English whatever this says. See
[Locales](#locales).

## PRESENT_BODIES {#present-bodies}

Whether this resource hands every player's look — body, equipment, outfit — to
everybody else, and puts theirs on here, so other players are drawn at all.

```lua
PRESENT_BODIES = true
```

**Type** `boolean` — only `false` turns it off.

Read by both halves. See
[How other players see this one](index.md#presence). Without something handing
looks out, a player sees nobody else's body: the engine replicates positions,
vehicles and actions, not a look.

- **It stands down by itself** while the platform's `open77_appearance` runs,
  which hands looks out on its own — but the two fight over the bootstrap and
  the face, so run only one of them.
- **Set it to `false`** only for a server where another resource hands looks
  out. The server says so when it starts:

```text
PRESENT_BODIES is false: another resource must hand every look out
```

It does not touch the local player's own clothing: that is
[`CLOTHING.PERSIST`](#clothing-persist).

## EVENT {#event}

The name of the client event raised after every decision this resource reaches.

```lua
EVENT = 'opx77:appearance'
```

**Type** `string`

The payload is an [`AppearanceEvent`](types.md#appearanceevent) and the channel
is documented on [Events](events.md#opx77-appearance). Renaming it renames the
only channel a caller can learn an outcome on, so a consumer has to be changed
with it — on a stock install that is
[`opx77_charselector`](../opx77_charselector/index.md) and
[`opx77_charcreator`](../opx77_charcreator/index.md), whose own
`APPEARANCE_EVENT` must match it.

!!! warning "Do not give it a name that already crosses the wire"
    A local `TriggerEvent` also reaches every `RegisterNetEvent` handler of the
    same name. A name already used as a wire event elsewhere will fire that
    handler with an appearance payload it does not expect.

## NOTIFY {#notify}

Whether to tell the player through [`opx77_notify`](../opx77_notify/index.md)
toasts, or through chat lines.

```lua
NOTIFY = true
```

**Type** `boolean` — only `false` turns toasts off.

Every notice is best-effort and never a dependency. The log line is written
first and always — in English, carrying the locale key. Then:

- **With toasts on**, the message goes to `opx77_notify`'s
  [`show`](../opx77_notify/exports.md#show) under one id, `opx77_appearance`,
  with `replace = true` — a message replaces the one before it instead of
  stacking — the title from the catalogue key `appearance.title` (`APPEARANCE`
  in `en`, `APPARENCE` in `fr`), and one of the four kinds `info`, `success`,
  `warning` and `error`.
- **A toast that cannot be shown** — `opx77_notify` stopped, the call refused,
  or an answer without `ok = true` — is written as a chat line instead, and the
  first such failure is logged once:

```text
no toast (<reason>): messages go to the chat box instead
```

- **With `NOTIFY = false`** every message is a chat line.

A chat line is a local
[`chat:addMessage`](../opx77_chat/events.md#chat-addmessage) with
`author` the `appearance.title` text and `type` `info` for the `info` and
`success` kinds, `error` for `warning` and `error`. It carries no colour:
`opx77_chat` styles it with its `.line.info` and `.line.error` tokens.

!!! info "Turning it off does not make failures silent"
    It moves the player's copy to the chat box; it removes nothing of yours. The
    [`opx77:appearance`](events.md#opx77-appearance) channel and the log lines are
    unchanged, so a resource that wants to render its own message can listen
    there.

## KEYS {#keys}

The default keys this resource declares, each of which a player can rebind in the
pause menu.

```lua
KEYS = {
	PANEL = 'F5',
}
```

**Type** `table` — a `KEYS` that is not a table is a client log warning, and the
default key is used:

```text
config: KEYS must be a table; using the default key
```

### KEYS.PANEL {#keys-panel}

The default of the key that opens or closes [the panel](index.md#key).

```lua
PANEL = 'F5'
```

**Type** `string|false` — a key name, or `false`.

Registered with `RegisterKeyMapping` as `opx77_appearance.panel`, named
*Appearance: open or close the panel* (`appearance.key.panel`) in the pause
menu's key bindings tab. This value is only the default: a player's own rebind
is stored under the mapping id and overrides it.

- **`false`** registers no mapping at all — the setting for a server that keeps
  the mirror behind a ripperdoc or a salon and lets that place call
  [`openPanel`](exports.md#openpanel).
- **A value that is neither a key name nor `false`** — empty, over 32
  characters, or holding a space or control character — is a client log warning
  and `F5`:

```text
config: KEYS.PANEL must be a key name or false; using "F5"
```

Leave `F6` and `F7` alone: they are the platform's perspective controls, and a
mapping never hides a key from the game, so either would trigger both.

## GAME_BUILDS {#game-builds}

Which catalogue builds a stored snapshot may be read back into.

```lua
GAME_BUILDS = { ['2.31'] = true }
```

**Type** `table<string, boolean>` — a key must map to exactly `true` to be
accepted.

A snapshot is a list of positions in the customization catalogue, so a face
captured on another build does not mean the same thing here. One from a build
that is not a key of this table is **not applied**: the player joins on the
pristine face of their own body, is told once per character, and
[`settled`](events.md#opx77-appearance) is published with
`stored_build_mismatch`. The same test decides whether
[`openEditor`](exports.md#openeditor) warns that the editor is starting from the
default face, and whether the panel offers **Wear it**.

!!! danger "Widening this does not make an old snapshot fit"
    It only stops this resource from saying so. The indices still point into a
    catalogue that is not loaded, so the puppet gets a different face rather than
    an error.

`opx77_core` keeps its own copy of the same list in
`OPX.Config.SHARED.APPEARANCE.GAME_BUILDS`, shipped with the same single entry,
and it is the one that decides whether a capture may be **stored**. Widening
this key alone leaves the core refusing the save with `appearance.invalid`.

## COMMIT_MS {#commit-ms}

How long `opx77_core` has to answer a captured face, or a clothing save, before
it is given up on, in milliseconds.

```lua
COMMIT_MS = 20000
```

**Type** `integer`

For a face, the deadline starts when the net event actually goes out, not when
the player confirmed — the wait for the cooldown below does not count against
it. The outstanding capture is checked every 200 ms.

What happens at the deadline depends on which modal it was:

| Capture | At the deadline |
|---|---|
| an **edit** | the stored face is put back on the puppet and the player is told `appearance.saveTimedOut`. Nothing is published. |
| a **create** | `created` is published with `save_timeout`, the player enters on the default face of their own body, and `openCreator` does not reopen the editor for this character again this session. |

The modal is already closed by then, so nothing is taken away from anybody.

A clothing save is checked once a second. An unanswered one is logged and counts
as a failed save; two failed saves in a row stop saving that character's clothing
until it is loaded again — see [What the character wears](index.md#clothing).

## SAVE_COOLDOWN_MS {#save-cooldown-ms}

How long to leave between two saves, in milliseconds, so the core's own
cooldowns are waited out rather than tripped.

```lua
SAVE_COOLDOWN_MS = 2000
```

**Type** `integer`

`opx77_core` cools `opx77:server:saveAppearance` under the key
`appearance.request` and `opx77:server:saveClothing` under `clothing.request`,
both at **2000 ms**, and those numbers are literals in
`opx77_core/server/appearance.lua` and `server/clothing.lua` rather than
configuration keys. This value mirrors them. A face commit inside the window is
held back and sent when it expires; a clothing change waits for the window
before it goes out. A refusal for going too fast would cost the capture outright.

!!! warning "Lowering it below the core's number buys nothing"
    The core still refuses, and the refusal arrives as `error.tooFast` on
    [`opx77:client:refused`](events.md#refused) — at which point a face edit is
    rolled back and the player is told. Raise it if you raise the core's; do not
    lower it.

## CLOTHING {#clothing}

What the character wears, stored by `opx77_core` and put back on here.

```lua
CLOTHING = {
	PERSIST = true,
	SAVE_DEBOUNCE_MS = 2000,
}
```

**Type** `table`

See [What the character wears](index.md#clothing) for the whole sequence.

### CLOTHING.PERSIST {#clothing-persist}

Whether the stored clothing is put on once the face has settled, and the
player's changes saved.

```lua
PERSIST = true
```

**Type** `boolean` — only `false` turns it off.

`false` leaves clothing to another resource: nothing is put on, nothing is read
for a save, and nothing is sent. A running `open77_appearance`, which stores its
own, has the same effect whatever this says. Neither touches the looks handed to
other players, which is [`PRESENT_BODIES`](#present-bodies).

### CLOTHING.SAVE_DEBOUNCE_MS {#clothing-save-debounce-ms}

How long a clothing change has to hold on the puppet before it is saved, in
milliseconds.

```lua
SAVE_DEBOUNCE_MS = 2000
```

**Type** `integer`

The registry and the wardrobe are read once a second, so a player trying on three
jackets saves the one they kept. After it the change still waits for
[`SAVE_COOLDOWN_MS`](#save-cooldown-ms) since the last clothing save. A value
that is not a finite, non-negative number is read as `2000`.

## RESTORE_RETRIES {#restore-retries}

How many times a join-time restore that the native mirror aborted before
confirming may be re-dispatched.

```lua
RESTORE_RETRIES = 3
```

**Type** `integer`

Only the *bootstrap* restore is counted, and only when the abort concerns the
restore the readiness announcement is waiting on. The budget is renewed by every
adopted face and by every world entry, so it is never a per-session allowance.
When it runs out the player is told `appearance.mirrorUnconfirmed` and the
announcement goes out anyway: a face that could not be restored must not leave a
player behind the gate.

## FAMILY_RETRIES {#family-retries}

How many body-family attempts one character gets.

```lua
FAMILY_RETRIES = 2
```

**Type** `integer`

The body family is `charInfo.gender` on the character row and
[`opx77_core` owns it](index.md#body-family). Two things spend this budget, and
they share it:

- **a world reload onto the character's body.** A selected character whose
  family is not the body the world loaded is reloaded onto it before any face
  goes on, and so is a creation editor that has to open on the other body. Past
  the count no further reload goes out, the player is told
  `appearance.bodyLoadFailed` with the reason `body_family_retries`, and keeps
  the body they are on;
- **a creation editor that came back on the other body.** It is refused, the
  player is told which one to build (`appearance.wrongBody`), and the editor is
  reopened. Past the count the creation ends with `body_family_mismatch`: the
  character enters on the pristine face of whichever body they are on, nothing
  is stored, and `openCreator` does not reopen the editor for it again this
  session.

The count is renewed when the live character changes.

## BODY_RELOAD_SETTLE_MS {#body-reload-settle-ms}

After a body reload's new puppet has been through its reset, how long a face and
the creation editor may wait for the respawn the platform replays onto it to end,
in milliseconds.

```lua
BODY_RELOAD_SETTLE_MS = 10000
```

**Type** `integer`

The wait ends as soon as the life phase reads `"alive"`; the ceiling only means
that a phase which never does costs a wait rather than a player. A value that is
not a finite, non-negative number is read as `10000`. See
[A body reload, step by step](index.md#body-reload).

## CREATION_WAIT_MS {#creation-wait-ms}

How long a character with no stored face waits for something to answer
[`needsCreation`](events.md#needs-creation) before this resource lets the player
in without one.

```lua
CREATION_WAIT_MS = 15000
```

**Type** `integer` — milliseconds

**This resource never opens the editor itself.** The readiness announcement
waits on the answer, because the editor may yet come up. When the timer runs out
it writes three lines to `Open77.log`, once per character, naming the
[`openCreator`](exports.md#opencreator) export that was never called:

```text
<citizenId> has no stored face and nothing called the `openCreator` export
  the player enters on the default face; a character creator resource is
  what opens the editor. See README, "Who opens the creator".
```

— and then settles the world entry on the default face of the character's own
body, so the gate is not held for an editor that is not coming. No event is
published for it, nothing is stored, and a later `openCreator` still opens the
editor.

The clock starts when `needsCreation` is published and is cleared the moment
[`openCreator`](exports.md#opencreator) is called, so a caller that answers
promptly never trips it. It bounds the wait for the *call*, not the player: once
the editor is open there is no deadline at all.

## BOOTSTRAP {#bootstrap}

The body the world first loads with, chosen at join before any character is.

```lua
BOOTSTRAP = {
	ROSTER_WAIT_MS = 3000,
	DEFAULT_FAMILY = 'female',
}
```

**Type** `table`

The platform's shell keeps its loading cover up for as long as the character
bootstrap is `"waiting"`, and nothing a server resource draws shows through it —
the roster included. So this resource spends the bootstrap at join, when the
pre-game menu world raises `open77:worldReady` or the resource starts with the
phase still `"waiting"`, and the world is never waited on for long. See
[The world comes first](index.md#world-first).

The choice is one log line at `info`, with its origin and its reason:

```text
bootstrap (worldReady): loading the male body, the last character played
```

A character already loaded when this runs has the better claim, and the
bootstrap is spent on its own `charInfo.gender` instead.

### BOOTSTRAP.ROSTER_WAIT_MS {#bootstrap-roster-wait-ms}

How long the join waits for `opx77_core`'s roster, in milliseconds, to load the
body of the account's most recently played character.

```lua
ROSTER_WAIT_MS = 3000
```

**Type** `number` — milliseconds

The roster is **read, never requested**: the `opx77:client:charactersReady`
broadcast if one has been seen, else the core's `GetCharacters` client export,
every 250 ms. The core cools roster requests at 2000 ms per player and drops the
excess without answering, so a request from here would cost the roster screen its
own. The core's own empty mirror — no character and no slot — counts as no
roster, and so does an answer without `ok = true`.

Past the wait, [`DEFAULT_FAMILY`](#bootstrap-default-family) is loaded and the
line says `no roster in time`. A roster with no played character in it — no
`lastLoggedOut` on any row — loads the default too, saying
`no character played yet`.

A value that is not a finite, non-negative number is read as `3000`, with one
line:

```text
BOOTSTRAP.ROSTER_WAIT_MS <value> is not a number of ms; waiting 3000
```

!!! info "Raising it holds the loading cover longer"
    Every millisecond spent here is spent under the shell's cover, before the
    world has started to load. The shipped value covers the roster the core sends
    once its own client has started; a longer wait only helps a server whose
    database answers slowly, and costs every joiner the difference.

### BOOTSTRAP.DEFAULT_FAMILY {#bootstrap-default-family}

The body loaded for an account with no played character, or whose roster did not
arrive in time.

```lua
DEFAULT_FAMILY = 'female'
```

**Type** [`BodyFamily`](types.md#bodyfamily) — `"female"` or `"male"`.

`"female"` is the platform's own default. A selected character on the other body
is reloaded onto it once chosen, so this only decides which accounts go through
that reload — see [Who owns the body family](index.md#body-family).

Anything but `"female"` or `"male"` is read as `"female"`, with one line:

```text
BOOTSTRAP.DEFAULT_FAMILY <value> is not "female" or "male"; loading "female"
```

## Locales {#locales}

Player-facing text lives in `locales/en.lua` and `locales/fr.lua`, registered
through `shared/locale.lua`, which publishes the global `locale(key, params)` and
`OpxAppearance.Locale`. Placeholders are `{name}` and are filled from the
parameter table; a placeholder with no value is left as it was written.

The catalogue carries this resource's own messages — the toast title, the
editor, the creation editor, the restore, the body-family reload, the clothing,
the panel and the panel key's name — **and** the seven locale keys
[`opx77_core` refuses a face save with](events.md#refused), so every such refusal
reaches the player in their own language rather than as a bare code. The clothing
refusal codes are not in it: they are published and logged, never displayed.

`0.9.0` and `0.10.0` add keys a catalogue of your own needs:

| Key | Said when |
|---|---|
| `appearance.title` | the title of every toast, and the author of every chat line |
| `appearance.stale` | the core refused a face captured for the character before a switch |
| `appearance.clothingRestoreFailed` | the stored clothing never read back on the puppet |
| `appearance.clothingNotSaved` | two clothing saves failed in a row; `{reason}` is the last failure |
| `appearance.panel.unavailable` | the panel key was pressed and the panel could not open |
| `appearance.key.panel` | the panel key's name in the pause menu, read when the resource starts |

`appearance.panel.outfitsNote` is reworded: there is no outfit picker yet, and
what the player wears is kept with the character.

To add a language: copy `locales/en.lua` to `locales/<code>.lua`, change the code
in the `register` call, translate the values, add a
`shared_script "locales/<code>.lua"` line to `open77.lua` beside the others, and
set [`LOCALE`](#locale) to it.

## What is deliberately not a key {#not-configurable}

These are constants in the resource's Lua. They are cadences, budgets against a
host API, or numbers that belong to another resource — not decisions an operator
would make.

| Constant | Value | What it is |
|---|---|---|
| `WATCH_MS` | `200` | How often the client's worker thread runs its pass — unanswered creations, the body transition, an unseen creation editor, save deadlines, the reload watch, then the readiness announcement — how often a waiting restore looks at the world, and how often the open panel looks at the native mirror. The periodic work runs on two threads, this one and the one-second pass below: a client resource is allowed 1024 tasks, and a thread per transaction is how that budget goes. |
| `ROSTER_POLL_MS` | `250` | How often the join-time bootstrap looks at the roster `opx77_core` holds. A read, never a request. |
| Panel owner sweep | `1000 ms` | How often the open panel checks that its owner is still running, or starting, at the same generation. |
| Bootstrap apply attempts | `20` | Attempts a join-time restore gets, to cover the short window before the puppet accepts one. |
| Rollback apply attempts | `8` | Attempts a mid-session rollback, a `setSkin` or the panel's **Wear it** gets. |
| Retry spacing | `400 ms` | Between two apply attempts. |
| Retryable apply reasons | three | `options_unavailable`, `player_unavailable` and `customization_state_unavailable` mean *not yet*; every other reason is final on the first answer. |
| Finalisation delay | `250 ms` | One frame budget after a stored face before the native mutation transaction is released and the new look may replicate. |
| Slow-world warning | `60000 ms` | How long a restore, or a world entry settling on the default face, waits for a puppet a face may go on before it says one line. There is no limit — it is waiting for a human to press a key. |
| Unseen creation editor | `30000 ms` | How long a creation editor the engine accepted may stay off screen before one log line. |
| Toast id | `opx77_appearance` | The id every toast is raised under, with `replace = true`. |
| `saveAppearance`, `saveClothing` | literals | The operations a refusal must name to be the face's or the clothing's. They are `OPX.Operations.SAVE_APPEARANCE` and `SAVE_CLOTHING` in the core's VM, which a satellite cannot import. |
| Clothing and look pass | `1000 ms` | How often the client runs the clothing pass (put-on, read-back, save), then reads its own look and compares it with the one it published. |
| Clothing put-ons | `5`, read back within `2000 ms` | Put-ons a world entry spends on the stored record before it gives up on it until the next world entry. |
| Failed clothing saves | `2` in a row | Before a character's clothing stops being saved until it is loaded again. |
| Clothing hold | `15000 ms` | The longest the first published look of a world entry waits for the stored clothing to read back. |
| Default clothing record | every slot `false` but `UnderwearBottom` = `Items.Underwear_Basic_01_Bottom`, no outfit | What a character with no stored clothing wears, as the platform states it. Never written by this resource. |
| Look retry | `3000 ms` | How long a publication or a request for everybody's look waits for the server's answer before it goes again. |
| Look floor | `500 ms` | Server side: the least time between two publications, and between two requests, of one player, read on `GetGameTimer`. |
| Body bounds | `49152` bytes, 64 groups of 64 keys | Server side: the most one encoded body may weigh and hold, the platform's own bounds. Past them the body is refused whole. |
| Clothing bound | `4096` bytes | Server side: the equipment and wardrobe beside a body. Past it they are sent as empty slots. |

The slow-world line names what it is still waiting on, and begins `restore` or
`pristine`:

```text
restore token=<n> is still waiting: eligible=<bool> reloading=<bool> gameplay=<bool> reset=<phase> life=<phase>
```

The client clocks read `Open77.time.monotonic` and keep their last good reading
when it fails; there is no fallback on a client, because `GetGameTimer` exists on
the server only.

The editor has **no deadline at all** once it is open, and that is not a constant
either: a player deliberating for an hour leaves the readiness gate closed for an
hour, and a player who quits out of the editor was never holding anything the
server keeps.

## See also {#see-also}

- [Events](events.md) — the channel [`EVENT`](#event) names, and the refusals the
  catalogue translates.
- [Overview](index.md#world-first) — why the bootstrap is spent at join,
  [what the character wears](index.md#clothing), and
  [why a face from another build is refused](index.md#build) rather than applied.
- [Types](types.md) — the shapes these keys govern.
