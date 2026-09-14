---
title: opx77_animations configuration
description: Every key of OPX_ANIMATIONS_CONFIG with its shipped default, its accepted range and what replaces a bad value — the language, the presenter, toasts, disabled animations, looping and durations, the rate limit, the picker and the four commands — plus the locale catalogues and the constants that are not keys.
---

# Configuration

Everything lives in `config.lua`, in one global table, `OPX_ANIMATIONS_CONFIG`.
**Every value shown on this page is the shipped default.**

```lua
OPX_ANIMATIONS_CONFIG = {
  LOCALE = "en",
  PRESENTER = "auto",
  NOTIFY = true,
  TOAST_MS = 4000,
  DISABLED = {},
  LOOP_BY_DEFAULT = true,
  ONE_SHOT_MS = 10000,
  MAX_DURATION_MS = 600000,
  RATE_LIMIT = { WINDOW_MS = 10000, REQUESTS = 6 },
  PICKER = {
    CLOSE_ON_SELECT = true,
    SHOW_VARIANT_WORDS = true,
  },
  COMMANDS = {
    ANIM = { NAME = "opx77.anim", RESTRICTED = false },
    EMOTE = { NAME = "e", RESTRICTED = false },
    STOP = { NAME = "opx77.anim.stop", RESTRICTED = false },
    LIST = { NAME = "opx77.anim.list", RESTRICTED = false },
  },
}
```

!!! danger "Nothing in this file is secret"

    `config.lua` is a `shared_script`: loaded by the server half **and shipped
    to every client**. Put no secret and no ACL grant in it. Grants belong in
    `acl.jsonc` — see [Getting started](../../guides/getting-started.md#acl).

**Every value is checked once, at load**, by `shared/settings.lua`. One that is
missing, of the wrong type or out of range is replaced by its fallback and named
in the server's boot log, rather than raising in the middle of a request:

```text
config: TOAST_MS must be a whole number in 750..120000; using 4000
```

The lines are written by the server half only. Each key below quotes its own.

## LOCALE {#locale}

Which `locales/<code>.lua` catalogue player-facing text is read from.

```lua
LOCALE = "en",
```

**Type** `string` — `"en"` or `"fr"` as shipped.

Applied at load. An unknown code is accepted rather than refused, because
catalogues register after the selection is made; a key missing from the active
catalogue falls back to `en`, then to the key itself. Each resource carries its
own catalogue, so this is set here as well as in
[`opx77_core`](../opx77_core/config.md). See [Locales](#locales).

## PRESENTER {#presenter}

Who poses the bodies on each client.

```lua
PRESENTER = "auto",
```

**Type** `"auto" | "always" | "never"`

| Value | This client poses bodies |
|---|---|
| `"auto"` | while `open77_animations` is neither running nor starting |
| `"always"` | always |
| `"never"` | never |

Decided once a second on each client. Two presenters on one body restart each
other's clip on every body, so each wrong combination is said at server boot:

```text
open77_animations is running and PRESENTER is "always": both pose every
  body, restarting each other's clip. Set PRESENTER to "auto" or drop one
  from resources.load in server.jsonc.
```

```text
PRESENTER is "never" and open77_animations is not running: the service
  accepts animations and no client poses a body for them.
```

Anything else is read as `"auto"`:

```text
config: PRESENTER must be "auto", "always" or "never"; using "auto"
```

See [Who poses the bodies](index.md#presenter).

## NOTIFY {#notify}

Whether a refusal, and a typed command's answer, is shown as an
[`opx77_notify`](../opx77_notify/index.md) toast. The list command is a report
and stays in the chat either way.

```lua
NOTIFY = true,
```

**Type** `boolean` — read as `NOTIFY ~= false`, so a misspelled value keeps it on.

The toast is raised with a fixed id and `replace = true`, so a player mashing a
refused row sees one toast rather than a stack. With `false`, with `opx77_notify`
not running, or when it refuses the toast, the same message is a chat line
instead — see [`chat:addMessage`](events.md#chat-addmessage). It governs what the
**player** sees; the [`result`](events.md#result) event is raised either way.

## TOAST_MS {#toast-ms}

How long a refusal toast, or a command's answer, stays up.

```lua
TOAST_MS = 4000,
```

**Type** `integer` — milliseconds, 750 to 120000. Fallback `4000`.

## DISABLED {#disabled}

Catalogue names never offered to anybody.

```lua
DISABLED = {},
```

**Type** `string[]` — e.g. `{ "cigar", "wounded" }`, without case.

A disabled name is not offered to any client, not in the picker, not in
[`list`](exports.md#list), and refused as `unknown_animation` by every path. The
server logs each one at boot as `<name> is disabled in config.lua`.

A name that is not in the catalogue is named rather than silently ignored, and
a value that is not a table disables nothing:

```text
config: DISABLED names "ciggar", which is not in the catalogue
config: DISABLED must be a list of catalogue names
```

## LOOP_BY_DEFAULT {#loop-by-default}

What a request that says nothing about looping gets.

```lua
LOOP_BY_DEFAULT = true,
```

**Type** `boolean` — read as `~= false`.

A typed command and a picker row never say, so this decides for both. An export
caller passes `loop` in [`AnimationOptions`](types.md#animationoptions) to
override it.

## ONE_SHOT_MS {#one-shot-ms}

How long a request that does not loop plays when it names no duration.

```lua
ONE_SHOT_MS = 10000,
```

**Type** `integer` — milliseconds, from 1000 to
[`MAX_DURATION_MS`](#max-duration-ms). Fallback `10000`, or `MAX_DURATION_MS` if
that is smaller.

A playback that does not loop has to end somewhere, and the service is given this
duration for it.

## MAX_DURATION_MS {#max-duration-ms}

The longest duration a request may name.

```lua
MAX_DURATION_MS = 600000,
```

**Type** `integer` — milliseconds, 1000 to 600000. Fallback `600000`.

The ceiling is the service's own: it validates a step's duration against 600000
ms and refuses a longer one on the wire. The floor is this resource's: a clip
shorter than a second reads as a twitch. A request naming a duration outside
1000 to this value is refused `invalid_options`, on the client and again on the
server.

## RATE_LIMIT {#rate-limit}

How many requests a player may make per window.

```lua
RATE_LIMIT = { WINDOW_MS = 10000, REQUESTS = 6 },
```

**Type** `table`

| Field | Range | Fallback | Meaning |
|---|---|---|---|
| `WINDOW_MS` | 250 to 600000 | `10000` | the window, in milliseconds, from a player's first request in it |
| `REQUESTS` | 1 to 1000 | `6` | play requests per player per window |

Stop requests are counted separately and get **twice** `REQUESTS`. The console is
not limited — it cannot play anything.

Past the limit a request is refused `rate_limited`. Only the first refusal in a
window is answered, so a held key is one toast; the rest are dropped without an
answer, and an export or picker request among them ends as `request_timeout` on
[`opx77:animations:result`](events.md#result).

A `RATE_LIMIT` that is not a table is named, and both fields fall back with a
line each:

```text
config: RATE_LIMIT must be a table
config: RATE_LIMIT.WINDOW_MS must be a whole number in 250..600000; using 10000
config: RATE_LIMIT.REQUESTS must be a whole number in 1..1000; using 6
```

## PICKER {#picker}

How the picker behaves.

```lua
PICKER = {
  CLOSE_ON_SELECT = true,
  SHOW_VARIANT_WORDS = true,
},
```

**Type** `table` — both fields read as `~= false`.

| Field | Meaning |
|---|---|
| `CLOSE_ON_SELECT` | close the picker once an animation or **Stop** is chosen. Passed to `opx77_menu` as `closeOnSelect` |
| `SHOW_VARIANT_WORDS` | show the engine's own clip words beside **Variant n** — `rub chin 1`, `stretch arms 3`. They are identifiers and are never translated |

## COMMANDS {#commands}

The four commands: the name each is registered under, and whether the host gates
it on the ACL.

```lua
COMMANDS = {
  ANIM = { NAME = "opx77.anim", RESTRICTED = false },
  EMOTE = { NAME = "e", RESTRICTED = false },
  STOP = { NAME = "opx77.anim.stop", RESTRICTED = false },
  LIST = { NAME = "opx77.anim.list", RESTRICTED = false },
},
```

**Type** `table<string, AnimationCommand>` — see
[`AnimationCommand`](types.md#animationcommand).

| Field | Meaning |
|---|---|
| `NAME` | the name registered, and so the ACL permission `command.<NAME>`. `false` registers nothing |
| `RESTRICTED` | `true` gates the command on `command.<NAME>` before the handler runs. Read as `== true`, so anything else leaves it open |

`ANIM` and `EMOTE` share one handler; `STOP` and `LIST` are the stand-alone forms
of `stop` and `list`. Two entries with one name are refused rather than
registered. A `COMMANDS` that is not a table registers none:

```text
config: COMMANDS must be a table; no command exists
```

See [Commands](commands.md).

## Locales {#locales}

Player-facing text lives in `locales/en.lua` and `locales/fr.lua`, keyed
`animations.<thing>`, with `{placeholder}` parameters filled from a table. Both
halves load them: the server renders the command answers and suggestions, the
client the toasts, the picker and the labels [`list`](exports.md#list) answers
with.

To add a language: copy `locales/en.lua` to `locales/<code>.lua`, change the code
in the `register` call and translate every value, add
`shared_script "locales/<code>.lua"` to `open77.lua` beside the others, above
every file that renders a string, and set [`LOCALE`](#locale) to it.

What stays English whatever the setting: server and client log lines, the console
form of `opx77.anim.list`, the variant words, and the error codes.

## What is deliberately not a key {#not-configurable}

Constants in the resource's Lua: cadences, and bounds the service or the wire
imposes.

| Constant | Value | What it is |
|---|---|---|
| Request timeout | `15000 ms` | how long a request waits for its verdict, swept every `5000 ms` |
| Presenter tick | `100 ms` | how often the mirror is read and bodies are posed |
| Snapshot request | `5000 ms` | how often the service is asked for a snapshot of the bucket |
| Presenter decision | `1000 ms` | how often [`PRESENTER`](#presenter) is looked at again |
| Release hold | `5000 ms` | how long a playback this client asked to stop stays unposed |
| Snapshot assembly | `10000 ms` | how long a snapshot split across pages may take to arrive |
| Change events per tick | `32` | the most [`changed`](events.md#changed) events raised in one tick |
| Picker cooldown | `1000 ms` | per player, for a command that opens the picker |
| List cooldown | `2000 ms` | per player, for `opx77.anim.list` |
| Offer throttle | `1000 ms` | per player, for a client asking for the offer |
| Name and clip bounds | `64`, `128` bytes | the longest profile id and clip either half accepts |

## See also {#see-also}

- [Commands](commands.md) — what the four [`COMMANDS`](#commands) entries do.
- [Overview](index.md#authority) — where each request-shaping key is checked.
- [Types](types.md) — the shapes these keys govern.
