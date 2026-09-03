---
title: opx77_weather commands
description: The eight staff commands opx77_weather registers — the two open read-only ones and the six ACL-gated mutations — with their permissions, arguments, refusals and examples.
---

# Commands

`opx77_weather` registers eight commands: two read-only ones that are open to every player, and
six mutations that are registered **restricted**, so the host resolves `command.<name>` against
the caller's ACL **before this resource runs at all**.

!!! info "The permission check is the host's, and this resource never repeats it"

    There is no permission check anywhere in `server/commands.lua`, and there must not be one.
    The third argument to `RegisterCommand` marks a command restricted; the host resolves it
    against the caller's grants and calls the handler only if it passes. A check written here
    would be a second, weaker gate in front of one that has already happened.

Grant the desk in `acl.jsonc`, which `server.jsonc` names under `accessControl`. A trailing
wildcard covers all of it at once:

```text
command.opx77.weather.*
```

Console helpers: `acl.reload`, `acl.list`, `acl.check <playerId> <permission>`.

Every name on this page is the **shipped default** and is yours to change in
[`config.lua`](config.md#commands) — the ACL key follows the name you choose. A command whose
`NAME` is `false` or empty is not registered at all, and its ACL key is never consulted because
there is no command behind it.

## How a command answers {#answers}

A command typed in chat answers over `open77:command:result`, which
[`opx77_chat`](../opx77_chat/index.md) renders as a cyan `COMMAND` line when accepted and a red
one when refused. The same command typed at the **server console** runs as `source = 0`, is
never rate limited, and answers into the platform log instead — `info` when accepted, `warn`
when refused.

!!! info "A player reads the locale catalogue; the console and the log stay English"

    Every answer on this page exists in two renderings of the same facts. A player is sent the
    text of the catalogue [`LOCALE`](config.md#locale) names, composed key by key in
    `server/commands.lua`; the console and the platform log are sent the operator's own English
    line, which is `Authority.statusText()`. **The sample output on this page is the English
    one.**

Every command that succeeds answers with the same status line:

```text
weather: 21:30:04  day=180min  weather=rain (next roll in 214s)  rev=42
```

The same moment as a player reads it in the box, with the shipped `en` catalogue:

```text
It is 21:30:04. A day lasts 180 real minutes. The sky is rain. Next roll in 214s. Revision 42.
```

The two bracketed halves change with the freezes: `(clock held)` appears after the day length
when the clock is frozen, and `(schedule held)` replaces `(next roll in Ns)` when the schedule
is. A `DEGRADED: no usable preset in OPX_WEATHER_CONFIG.WEATHER` suffix means the weather table
has no usable row — the clock still runs, but every weather mutation will answer `no_presets`.

Refusals reach the console as the mutator's own snake_case codes, shown verbatim:
`unknown_preset`, `invalid_time`, `invalid_transition`, `invalid_day_length`, `day_too_short`,
`no_presets`. A player is sent the catalogue sentence for the same code instead — `No such
weather preset.` in `en` — and a code the catalogue does not name falls back to `That could not
be done.` A wrong argument count answers a `usage:` line, which is a catalogue key of its own
and reads the same in `en` on both sides.

Registered names, with `[acl]` or `[open]` beside each, are printed once at boot:

```text
commands: opx77.weather [open], opx77.weather.presets [open], opx77.weather.set [acl], …
```

They are also published as chat completion entries: the resource answers `chat:ready` with
`chat:addSuggestions`, carrying each registered command's help line and its parameter names, so
staff see the usage while typing. Those help lines are rendered from the catalogue as the
suggestions go out.

## Show the time and sky {#status}

!!! info "No permission required"

    Open to every player. `COMMANDS.STATUS.RESTRICTED` ships as `false`, and for the two
    read-only commands the test is `RESTRICTED == true` — they are open unless you explicitly
    say otherwise.

```text
/opx77.weather
```

Takes no arguments. Answers the status line described [above](#answers): the current time, the
day length, the clock freeze, the preset, the schedule freeze or the seconds to the next roll,
and the revision.

Floored at one run per player every 2 s. A run inside the floor is dropped silently. The server
console is never floored — an operator's own terminal is not a rate to limit.

### Example {#status-example}

```text
> /opx77.weather
weather: 21:30:04  day=180min  weather=rain (next roll in 214s)  rev=42
```

## List the configured presets {#presets}

!!! info "No permission required"

    Open to every player. `COMMANDS.PRESETS.RESTRICTED` ships as `false`.

```text
/opx77.weather.presets
```

Takes no arguments. Answers one line per row of `OPX_WEATHER_CONFIG.WEATHER`, in config order:
the `NAME` staff type, the REDengine `PRESET` behind it, the weight, the duration band in real
seconds, and the crossfade. This is the list [`/opx77.weather.set`](#set) accepts, and the
refusal for an unknown preset points at it by name.

Floored at one run per player every 2 s, like the status command.

### Example {#presets-example}

```text
> /opx77.weather.presets
weather presets (name / engine preset / weight / seconds):
  sunny        24h_weather_sunny          w=28  480..900s  transition 18s
  lightclouds  24h_weather_light_clouds   w=24  360..720s  transition 20s
  rain         24h_weather_rain           w=12  180..420s  transition 30s
```

## Cross to a weather preset {#set}

!!! info "Requires `command.opx77.weather.set`"

    Registered restricted. The flag is read as `RESTRICTED ~= false`, so a missing, misspelled
    or quoted flag still gates it — only an explicit `RESTRICTED = false` opens it, and the
    boot log then warns `command opx77.weather.set is OPEN to every player`.

```text
/opx77.weather.set <preset> [seconds]
```

- preset: `string`
    - A `NAME` or an engine `PRESET` from the weather table, matched without case.
- seconds?: `number`
    - How long the sky takes to cross into it, `0..300`. Omit for the preset's own
      `TRANSITION_SECONDS`.

Crossing re-draws the preset's duration and re-arms the roll countdown from now, so a hand-set
sky holds for its own configured band before the schedule takes over again. It bumps
`weatherRevision`, so every client applies it rather than skipping it as a repeat.

**Errors**

| Refusal | Meaning |
|---|---|
| `usage: <preset> [transitionSeconds]` | Fewer than one or more than two arguments. |
| `unknown_preset -- run opx77.weather.presets` | Neither a `NAME` nor a `PRESET` in the table. A player is sent `No such weather preset. Run opx77.weather.presets to see the list.` instead. |
| `invalid_transition` | Not a number, or outside `0..300` seconds. |
| `no_presets` | The weather table has no usable row. |

### Example {#set-example}

```text
> /opx77.weather.set rain
weather: 21:30:11  day=180min  weather=rain (next roll in 298s)  rev=43

> /opx77.weather.set 24h_weather_fog 5
weather: 21:30:19  day=180min  weather=fog (next roll in 241s)  rev=44
```

## Roll the weather table now {#next}

!!! info "Requires `command.opx77.weather.next`"

    Registered restricted, with the same `RESTRICTED ~= false` rule as every other mutation.

```text
/opx77.weather.next
```

Takes no arguments. Picks the next preset by weight and crosses to it immediately, **even
while the schedule is frozen** — freezing holds the automatic countdown, not the staff desk.

It calls the same roll the scheduler does, so a manual roll obeys the same rules: the preset
already up is never a candidate, rows weighted `0` never roll, and the new preset's duration is
drawn on the way in. If nothing is left to roll — a one-row table, or every other row weighted
`0` — the current preset is returned and the sky stays put rather than looping.

**Errors**

| Refusal | Meaning |
|---|---|
| `usage: no arguments` | Any argument was given. |
| `no_presets` | The weather table has no usable row. |

### Example {#next-example}

```text
> /opx77.weather.next
weather: 21:31:02  day=180min  weather=lightclouds (next roll in 604s)  rev=45
```

## Hold or release the weather schedule {#freeze}

!!! info "Requires `command.opx77.weather.freeze`"

    Registered restricted, with the same `RESTRICTED ~= false` rule as every other mutation.

```text
/opx77.weather.freeze <on|off>
```

- on|off: `string`
    - `on`, `true` and `1` all mean on; `off`, `false` and `0` all mean off. A bare toggle is
      deliberately not accepted — it would have to be run twice to be read.

This holds the **roll schedule**, not the engine's weather lock. The client keeps
`setWeatherFrozen(true)` taken regardless, so REDengine's own cycle never runs underneath the
projection whether this is on or off. While the schedule is frozen the snapshot carries no
`nextRollInMs` at all, and the status line reads `(schedule held)`.

Releasing it **re-arms** the countdown from a fresh draw — otherwise an expired timer would
make "resume" mean "next".

**Errors**

| Refusal | Meaning |
|---|---|
| `usage: <on\|off>` | Not exactly one argument, or an argument that is neither on nor off. |

### Example {#freeze-example}

```text
> /opx77.weather.freeze on
weather: 21:31:40  day=180min  weather=lightclouds (schedule held)  rev=46
```

## Set the authoritative clock {#time}

!!! info "Requires `command.opx77.weather.time`"

    Registered restricted, with the same `RESTRICTED ~= false` rule as every other mutation.

```text
/opx77.weather.time <HH:MM[:SS]>
```

- HH:MM[:SS]: `string`
    - 24-hour, for example `21:30` or `21:30:45`. The hour may be one or two digits; the
      minutes must be two.

The pattern is anchored at both ends, so a prefix like `12:30pm` is refused rather than
half-read, and an hour that does not exist is a mistake rather than a wrap — `25:00` is
`invalid_time`, not `01:00`.

Setting the time rewrites the anchor to now, so the clock resumes from the value you gave at
the current rate. Every client applies it as a mutation, which is what lets it move
*backwards*: an ordinary drift correction refuses a backwards step of more than twelve hours,
because the engine's `setTime` picks the next occurrence and a stale packet would otherwise
become a full-day jump.

**Errors**

| Refusal | Meaning |
|---|---|
| `usage: <HH:MM[:SS]>` | Not exactly one argument. |
| `invalid_time` | Unparsable, or an hour, minute or second that does not exist. |

### Example {#time-example}

```text
> /opx77.weather.time 20:30
weather: 20:30:00  day=180min  weather=lightclouds (schedule held)  rev=47
```

## Hold or release the clock {#time-freeze}

!!! info "Requires `command.opx77.weather.time.freeze`"

    Registered restricted, with the same `RESTRICTED ~= false` rule as every other mutation.

```text
/opx77.weather.time.freeze <on|off>
```

- on|off: `string`
    - `on`, `true` and `1` all mean on; `off`, `false` and `0` all mean off.

The anchor is rewritten at the moment of the freeze, so releasing it resumes from where the
clock stood rather than jumping forward by however long it was held. The status line reads
`(clock held)` while it is on.

This holds the engine's clock as well as the authority's: every client takes
`Open77.environment.setTimeFrozen(true)` on the change, so REDengine's own clock does not run
underneath the held projection. Before `0.3.0` it held the authority alone and the engine ran
free — see [the clock lock](index.md#time-lock).

**Errors**

| Refusal | Meaning |
|---|---|
| `usage: <on\|off>` | Not exactly one argument, or an argument that is neither on nor off. |

### Example {#time-freeze-example}

```text
> /opx77.weather.time.freeze on
weather: 20:30:12  day=180min (clock held)  weather=lightclouds (schedule held)  rev=48
```

## Set how long a day takes {#day-length}

!!! info "Requires `command.opx77.weather.daylength`"

    Registered restricted, with the same `RESTRICTED ~= false` rule as every other mutation.

```text
/opx77.weather.daylength <realMinutes>
```

- realMinutes: `number`
    - Real minutes per whole in-game day. `180` matches the engine's own rate.

The rate is `86400 / (minutes * 60)`, in game seconds per real second — exactly `8.0` at the
shipped 180 minutes. The anchor is rebased to now before the rate changes, so the time of day
does not jump when the speed does.

Accepted from **1 minute to 10080 minutes (7 days)**. On top of that the rate is capped at
`120.0` game seconds per real second, which refuses anything under **12 real minutes a day**.
The cap exists because a client past the drift tolerance at that speed would be jumping the
world continuously instead of running it.

**Errors**

| Refusal | Meaning |
|---|---|
| `usage: <realMinutes>` | Not exactly one argument. |
| `invalid_day_length` | Not a number, NaN, or outside `1..10080` minutes. |
| `day_too_short` | Inside the range, but the resulting rate is past `120.0` — under 12 real minutes a day. |

### Example {#day-length-example}

```text
> /opx77.weather.daylength 60
weather: 20:30:12  day=60min (clock held)  weather=lightclouds (schedule held)  rev=49

> /opx77.weather.daylength 5
day_too_short
```

## Two names, one ACL key {#duplicate-names}

!!! warning "A duplicated `NAME` silently binds one permission for both commands"

    Two entries in `COMMANDS` sharing one `NAME` would register one command name and one ACL
    key, and whichever registered second would inherit the first's `RESTRICTED` flag — which is
    how an open read-only command can end up opening a mutation. The loader refuses the second
    one instead and logs it at error level:

    ```text
    command opx77.weather.set is declared twice (COMMANDS.SET and COMMANDS.NEXT); NEXT is NOT registered
    ```

    Read the boot log after editing `COMMANDS`. A command that is not registered fails as
    `unknown_command`, which looks like a typo rather than a config clash.

## See also {#see-also}

- [Configuration](config.md#commands) — renaming, opening and disabling each of these.
- [`opx77_chat`](../opx77_chat/index.md) — the box a command's answer is rendered in.
- [Getting started](../../guides/getting-started.md) — writing the grants into `acl.jsonc`.
