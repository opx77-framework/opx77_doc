---
title: opx77_animations commands
description: The four commands opx77_animations registers — opx77.anim, e, opx77.anim.stop and opx77.anim.list — what each takes and answers, why all four ship open, and how to rename, restrict or switch one off.
---

# Commands

Four commands, each registered from an entry of
[`COMMANDS`](config.md#commands) in `config.lua` rather than from a literal
name. The names below are the shipped defaults.

| Command | Key | Restricted as shipped | Does |
|---|---|---|---|
| [`opx77.anim`](#opx77-anim) | `ANIM` | no | the picker, an animation, a category, `stop` or `list` |
| [`e`](#e) | `EMOTE` | no | the same command, short |
| [`opx77.anim.stop`](#opx77-anim-stop) | `STOP` | no | stop your own animation |
| [`opx77.anim.list`](#opx77-anim-list) | `LIST` | no | what the first two accept |

!!! info "Why all four ship open"

    Every one acts on the caller only — their own body, their own picker, their
    own list — so every one is registered with `RESTRICTED = false`. Set
    `RESTRICTED = true` on an entry and the host resolves `command.<NAME>`
    against the caller's ACL **before** this resource's handler runs; the
    permission follows whatever name the entry registers.

    The flag is read as `RESTRICTED == true`. A misspelled or quoted flag leaves
    the command **open**, which is the safe direction for a command that can only
    move its own caller.

A `NAME` of `false` registers nothing, and says so once:

```text
command <KEY> is off (COMMANDS.<KEY>.NAME)
```

Two entries sharing one name would bind one ACL key and one `RESTRICTED` flag
between them, so the second is refused rather than registered:

```text
command <name> is declared twice (COMMANDS.<KEY> and COMMANDS.<KEY>); <KEY> is NOT registered
```

At boot the server lists what it registered, each marked `[open]` or `[acl]`:

```text
commands: opx77.anim [open], e [open], opx77.anim.stop [open], opx77.anim.list [open]
```

**Where the answers go.** Every answer but the list is a toast, in the one slot
the picker's refusals use. A refusal about what was typed — a usage error, an
unknown name or variant — is a warning that says what was typed wrong, sent from
the server on [`opx77_animations:notice`](events.md#private-wire) for the
client to raise. Every other refusal — not ready, dead, in a vehicle, too fast —
is the same toast the picker shows. With `opx77_notify` stopped, or
[`NOTIFY`](config.md#notify) off, each toast is a chat line instead. A
successful play has no answer at all: the body moving is the answer.
[`opx77.anim.list`](#opx77-anim-list) is a report and stays in the chat box,
sent with `chat:addMessage`. None of it goes on `open77:command:result`, whose
accepted answers [`opx77_chat`](../opx77_chat/index.md) does not print.

**Keys are not commands.** The picker key (F3) and the stop key (X) act on the
client, as the `openPicker` and `stop` exports do, so `RESTRICTED` on these
entries does not gate them; set [`KEYS`](config.md#keys) to `false` for no key.
See [Keys](index.md#keys).

**Suggestions.** When a player's chat box raises `chat:ready`, the server sends
`chat:addSuggestions` for every command it registered, with help text in the
configured locale. At most once every two seconds per player.

## opx77.anim {#opx77-anim}

Plays an animation on the caller, opens the picker, or runs `stop` or `list`,
depending on what follows the command.

```text
opx77.anim [name [variant] | category | stop | list]
```

- *(nothing)*
    - Opens the picker. At most once a second per player; a faster run is
      dropped silently.
- name: `string`
    - Plays that animation, e.g. `opx77.anim dance`. Case is ignored.
- variant?: `integer`
    - With a name: which variant, e.g. `opx77.anim smoke 3`.
    - Default: the first variant offered on this build
- category: `string`
    - Alone: opens the picker on that category's screen, e.g.
      `opx77.anim social`, with the root under it and its cursor on that
      category, so **Back** returns there. A category with nothing offered opens
      the root. Shares the once-a-second limit with the bare form. See
      [The picker](index.md#picker).
- `stop`
    - Alone: the same as [`opx77.anim.stop`](#opx77-anim-stop).
- `list`
    - Alone: the same as [`opx77.anim.list`](#opx77-anim-list).

`stop`, `list` and a category are only recognised as the **single** argument.
Anything with more than two arguments is a usage error.

**Answers**

| Case | Answer |
|---|---|
| more than two arguments | `usage: [name [variant] \| category \| stop \| list]`, a warning toast |
| `unknown_animation` | *That animation is not available here.* followed by *Run /opx77.anim.list to see the list.*, a warning toast |
| `invalid_variant` | *That animation has no such variant.* with the same hint, a warning toast |
| any other refusal | a toast, or a chat line — see [`AnimationError`](types.md#animationerror) |
| played | nothing: the body moves |

The hint names the [`LIST`](config.md#commands) command as registered, and is
left off when that command is switched off. The lines are in the configured
locale; the ones above are `en`.

A play typed here runs the same server checks as any other request — see
[What it asks, and what it cannot](index.md#authority) — and its verdict is also
raised on [`opx77:animations:result`](events.md#result) with `requestId = 0` and
`source = "command"`.

**From the console** the command answers
`animations are played by a player, not the console`, as a warning in the log:
there is no body to play one on.

**Side** `server` — registered in this resource's server VM, removed with it on
stop or reload.

### Example {#opx77-anim-example}

```text
> /opx77.anim
  (the picker opens)
> /opx77.anim smoke 3
  (the third variant of smoke plays)
> /opx77.anim relaxation
  (the picker opens on the Relaxation screen; Back returns to the root)
> /opx77.anim smoke 99
  (a warning toast) That animation has no such variant. Run /opx77.anim.list to see the list.
```

## e {#e}

The same command as [`opx77.anim`](#opx77-anim), under a name short enough to
type in the middle of a scene.

```text
e [name [variant] | category | stop | list]
```

Every argument, answer and limit is the one described above; the two share a
handler and the picker's once-a-second limit. The hint on an unknown name names
[`LIST`](config.md#commands), and a player shown the *picker unavailable* toast
is told to type `/e` followed by a name — `EMOTE`'s `NAME` is preferred over
`ANIM`'s for that hint while both are set.

**Side** `server`.

## opx77.anim.stop {#opx77-anim-stop}

Stops the caller's animation, whichever resource started it.

```text
opx77.anim.stop
```

Takes no argument; any argument is answered `usage: no arguments`, a warning
toast.

The server calls `Open77.animations.stop` on the caller and tells the caller's
client to release a playback a client resource started over the service's own
wire, which this resource's server half has no way to reach. Nothing playing is
not a failure and shows nothing. A refusal — `rate_limited` past twice
[`RATE_LIMIT.REQUESTS`](config.md#rate-limit), or a code the service refused with
— is the refusal toast.

**From the console** it answers
`animations are stopped by a player, not the console`.

**Side** `server`.

## opx77.anim.list {#opx77-anim-list}

Lists what [`opx77.anim`](#opx77-anim) accepts: every offered animation, grouped
by category, each with how many variants it offers.

```text
opx77.anim.list
```

Takes no argument; any argument is answered `usage: no arguments`, a warning
toast. At most once every two seconds per player; a faster run is dropped
silently. `opx77.anim list` shares the same limit.

**Output, to a player**, in the configured locale, as a chat line sent with
`chat:addMessage`, `type = 'info'`, authored `animations.title` and with no
colour of its own — `opx77_chat` styles it — a report someone asked to read,
which a toast would cut short:

```text
animations, by category (name, then its variant count):
  Gestures: handsup (4), clap (3)
  Social: dance (6), phone (2)
  Emotions: cry (4), think (4)
  Relaxation: sit (4), meditate (5), stretch (15)
  Consumables: smoke (11), cigar (6), drink (6)
  Interactions: give, examine, wounded
```

That is the whole catalogue offered. An animation with a single offered variant
is listed without a count. Only
categories with something offered are listed, and a server offering nothing
answers *No animation is offered on this server.*

**Output, to the console**, in English whatever the locale, one log line per
offered animation with every offered variant number resolved:

```text
  handsup    gestures     variants 1,2,3,4
  clap       gestures     variants 1,2,3
```

**Side** `server`.

## See also {#see-also}

- [Configuration](config.md#commands) — the four entries, their names and their
  flags.
- [Exports](exports.md) — the same requests, from another resource.
- [Getting started](../../guides/getting-started.md#acl) — writing the ACL a
  restricted command resolves against.
