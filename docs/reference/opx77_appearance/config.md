---
title: opx77_appearance configuration
description: Every key of OPX_APPEARANCE_CONFIG with its shipped default — the language, the event name, the toasts, the catalogue builds, the two deadlines and the two retry counts — the locale catalogues, and the constants that are not keys.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_APPEARANCE_CONFIG`.
It is declared as a `shared_script` even though this resource has no server half,
so the file is shipped to every client and read there.

**Every value shown on this page is the shipped default.**

```lua
OPX_APPEARANCE_CONFIG = {
  LOCALE = "en",
  EVENT = "opx77:appearance",
  NOTIFY = true,
  GAME_BUILDS = { ["2.31"] = true },
  COMMIT_MS = 20000,
  SAVE_COOLDOWN_MS = 2000,
  RESTORE_RETRIES = 3,
  FAMILY_RETRIES = 2,
}
```

## LOCALE {#locale}

Which `locales/<code>.lua` catalogue player-facing text is read from.

```lua
LOCALE = "en"
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

## EVENT {#event}

The name of the client event raised after every decision this resource reaches.

```lua
EVENT = "opx77:appearance"
```

**Type** `string`

The payload is an [`AppearanceEvent`](types.md#appearanceevent) and the channel
is documented on [Events](events.md#opx77-appearance). Renaming it renames the
only channel a caller can learn an outcome on, so a consumer has to be changed
with it.

!!! warning "Do not give it a name that already crosses the wire"
    A local `TriggerEvent` also reaches every `RegisterNetEvent` handler of the
    same name. A name already used as a wire event elsewhere will fire that
    handler with an appearance payload it does not expect.

## NOTIFY {#notify}

Whether to raise toasts through [`opx77_notify`](../opx77_notify/index.md).

```lua
NOTIFY = true
```

**Type** `boolean`

Every notice is best-effort and never a dependency. The log line is written
first and always — in English, carrying the locale key — and the toast is then
skipped when this is not `true`, or when `opx77_notify` is not running. A refused
toast costs one debug line and changes nothing else.

Toasts are raised with the title `APPEARANCE` and one of the four kinds `info`,
`success`, `warning` and `error`.

!!! info "Turning it off does not make failures silent"
    It removes the player's copy, not yours. The
    [`opx77:appearance`](events.md#opx77-appearance) channel and the log lines are
    unchanged, so a resource that wants to render its own message can turn this
    off and listen instead.

## GAME_BUILDS {#game-builds}

Which catalogue builds a stored snapshot may be read back into.

```lua
GAME_BUILDS = { ["2.31"] = true }
```

**Type** `table<string, boolean>` — a key must map to exactly `true` to be
accepted.

A snapshot is a list of positions in the customization catalogue, so a face
captured on another build does not mean the same thing here. One from a build
that is not a key of this table is **not applied**: the player joins on the
pristine face, is told once per character, and
[`settled`](events.md#opx77-appearance) is published with
`stored_build_mismatch`. The same test decides whether
[`open`](exports.md#open) warns that the editor is starting from the default
face.

!!! danger "Widening this does not make an old snapshot fit"
    It only stops this resource from saying so. The indices still point into a
    catalogue that is not loaded, so the puppet gets a different face rather than
    an error.

`opx77_core` keeps its own copy of the same list in
`OPX.Config.SHARED.APPEARANCE.GAME_BUILDS`, shipped with the same single entry,
and it is the one that decides whether a capture may be **stored**. Widening
this key alone leaves the core refusing the save with `appearance.invalid`.

## COMMIT_MS {#commit-ms}

How long `opx77_core` has to answer a captured face before it is given up on, in
milliseconds.

```lua
COMMIT_MS = 20000
```

**Type** `integer`

The deadline starts when the net event actually goes out, not when the player
confirmed — the wait for the cooldown below does not count against it. The
outstanding capture is checked every 200 ms.

What happens at the deadline depends on which modal it was:

| Capture | At the deadline |
|---|---|
| an **edit** | the stored face is put back on the puppet and the player is told `appearance.saveTimedOut`. Nothing is published. |
| a **create** | the character bootstrap is spent on the pristine face, `created` is published with `save_timeout`, and the creator is not reopened for this character again this session. |

The modal is already closed by then, so nothing is taken away from anybody.

## SAVE_COOLDOWN_MS {#save-cooldown-ms}

How long to leave between two captures, in milliseconds, so the core's own
cooldown is waited out rather than tripped.

```lua
SAVE_COOLDOWN_MS = 2000
```

**Type** `integer`

`opx77_core` cools the `appearance.request` key at **2000 ms**, and that number
is a literal in `opx77_core/server/appearance.lua` rather than a configuration
key. This value mirrors it. A commit inside the window is held back and sent when
it expires; a refusal for going too fast would cost the capture outright.

!!! warning "Lowering it below the core's number buys nothing"
    The core still refuses, and the refusal arrives as `error.tooFast` on
    [`opx77:client:refused`](events.md#refused) — at which point the edit is
    rolled back and the player is told. Raise it if you raise the core's; do not
    lower it.

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

How many times the character creator is reopened after the player came back on
the wrong body family.

```lua
FAMILY_RETRIES = 2
```

**Type** `integer`

The body family is `charInfo.gender` on the character row and
[`opx77_core` owns it](index.md#body-family). A creator run that comes back on
the other body is refused, the player is told which one to build, and the creator
is reopened. Past this count the run ends with `body_family_mismatch`: the
character enters on the pristine face of its own body, nothing is stored, and the
creator is not reopened for it again this session.

## Locales {#locales}

Player-facing text lives in `locales/en.lua` and `locales/fr.lua`, registered
through `shared/locale.lua`, which publishes the global `locale(key, params)` and
`OpxAppearance.Locale`. Placeholders are `{name}` and are filled from the
parameter table; a placeholder with no value is left as it was written.

The catalogue carries this resource's own messages — the editor, the creator, the
restore and the body-family transition — **and** the six locale keys
[`opx77_core` refuses a save with](events.md#refused), so every refusal reaches
the player in their own language rather than as a bare code.

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
| `WATCH_MS` | `200` | How often the two workers look at the world and at the modals. One thread each: a client resource is allowed 1024 tasks, and a thread per transaction is how that budget goes. |
| Bootstrap apply attempts | `20` | Attempts a join-time restore gets, to cover the short world/menu readiness window. |
| Rollback apply attempts | `8` | Attempts a mid-session rollback gets. |
| Retry spacing | `400 ms` | Between two apply attempts. |
| Retryable apply reasons | three | `options_unavailable`, `player_unavailable` and `customization_state_unavailable` mean *not yet*; every other reason is final on the first answer. |
| Finalisation delay | `250 ms` | One frame budget after a stored face before the native mutation transaction is released and the new look may replicate. |
| Slow-restore warning | `60000 ms` | How long a restore waits for the gameplay world before it says one line. There is no limit — it is waiting for a human to press a key. |
| Toast title | `APPEARANCE` | The title every notice is raised under. |
| `saveAppearance` | literal | The operation a refusal must name to be this resource's. It is `OPX.Operations.SAVE_APPEARANCE` in the core's VM, which a satellite cannot import. |

The creator has **no deadline at all**, and that is not a constant either: a
player deliberating for an hour leaves the readiness gate closed for an hour, and
a player who quits out of the creator was never holding anything the server
keeps.

## See also {#see-also}

- [Events](events.md) — the channel [`EVENT`](#event) names, and the refusals the
  catalogue translates.
- [Overview](index.md#build) — why a face from another build is refused rather
  than applied.
- [Types](types.md) — the shapes these keys govern.
