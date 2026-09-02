---
title: opx77_core commands
description: Every command opx77_core registers — nine restricted staff commands and five unrestricted ones a player runs on their own character — with the ACL permission each needs, its arguments, and the wildcard trap that leaves the bare /opx77 ungranted.
---

# Commands

`opx77_core` registers fourteen commands, all of them server-side. Nine are
**restricted**: from a client they require an ACL permission. Five are
**unrestricted**: any connected player may run them, because they act on that
player's own character and nothing else.

| Command | Permission |
|---|---|
| [`opx77`](#opx77) | `command.opx77` |
| [`opx77.where`](#opx77-where) | `command.opx77.where` |
| [`opx77.here`](#opx77-here) | `command.opx77.here` |
| [`opx77.whois`](#opx77-whois) | `command.opx77.whois` |
| [`opx77.characters`](#opx77-characters) | none |
| [`opx77.select`](#opx77-select) | none |
| [`opx77.create`](#opx77-create) | none |
| [`opx77.delete`](#opx77-delete) | none |
| [`opx77.duty`](#opx77-duty) | none |
| [`opx77.money`](#opx77-money) | `command.opx77.money` |
| [`opx77.job`](#opx77-job) | `command.opx77.job` |
| [`opx77.gang`](#opx77-gang) | `command.opx77.gang` |
| [`opx77.group`](#opx77-group) | `command.opx77.group` |
| [`opx77.save`](#opx77-save) | `command.opx77.save` |

Commands are typed into the OPEN//77 developer terminal (`²`) in game, or sent
as a slash command by a chat resource. Either way the client sends
`open77:command:execute` to the host's authenticated dispatcher, which resolves
the ACL **before any Lua runs**; `opx77_chat` is not in that path and stopping it
changes nothing here. Answers come back on `open77:command:result`. The
dedicated server console runs as `source = 0` and stays authorised for local
administration.

!!! warning "`command.opx77.*` does not grant `command.opx77`"
    A trailing wildcard matches the segment after the dot. `command.opx77.*`
    grants `opx77.where`, `opx77.money` and the rest — and leaves the bare
    `opx77` status command refused, which reads exactly like a broken resource.
    Grant both:

    ```json
    "permissions": [
      "command.opx77",
      "command.opx77.*"
    ]
    ```

    An exact permission, `*`, or a trailing wildcard will grant a restricted
    command. The comparison is made on the public key certified during the
    handshake; the nickname and the temporary player id never take part.

---

## Server status {#opx77}

Prints the core's version, how many characters are in the world, how many
sessions are connected, and one line per loaded character.

**Requires** `command.opx77`. Not covered by `command.opx77.*`.

```text
/opx77
```

Takes no arguments.

If the core booted degraded — a database that would not answer, most often — a
`DEGRADED:` line follows the header carrying the boot error, and no character
will have been able to log in. That line is the first thing to read when players
report that nothing loads.

### Example {#opx77-example}

```text
opx77_core 0.2.0 -- 2 character(s) in the world, 3 session(s) connected
  1    NC-4B2K-7Q V Sinclair  Mercenary
  4    NC-9T1M-2X Jack Welles  Fixer
```

---

## Where is a player {#opx77-where}

Prints one player's whole situation — session, character, gate, life phase,
position, job, gang and every balance — all of it what the **server** believes.

**Requires** `command.opx77.where`.

```text
/opx77.where [playerId]
```

- playerId?: `integer`
    - Defaults to the caller. A player with no session is reported as such.

A report that agreed with the client would be useless for diagnosing a
disagreement between the two, so every line here is read server-side:
`position` and `life` come from the host, not from anything the client sent.
`life : unreadable` means the host would not answer — which for a player still
on the "press any key to continue" screen is the expected answer.

`gate : held` means this core is still holding that player's readiness hold and
has not placed them yet. See [The entry gate](../../concepts/entry-gate.md).

---

## Print a spawn point {#opx77-here}

Prints the caller's current position in exactly the shape `config/shared.lua`
wants for `DEFAULT_SPAWN`, ready to paste.

**Requires** `command.opx77.here`.

```text
/opx77.here
```

Takes no arguments. Must be run in game: the console has no position, and
answers `opx77.here must be run in game`.

The heading is the last one the client reported, which is a hint the server
keeps precisely because its own position snapshot carries none. A transposed
digit here puts every new character on the server inside a building, which is
why this command exists rather than a wiki page of coordinates.

### Example {#opx77-here-example}

```text
DEFAULT_SPAWN = {
  SET = true,
  X = -1620.44,
  Y = 380.11,
  Z = 42.90,
  HEADING = 271.00,
},
```

---

## Who is a player {#opx77-whois}

Prints a player's temporary id, their durable `userId` and their display name.

**Requires** `command.opx77.whois`.

```text
/opx77.whois [playerId]
```

- playerId?: `integer`
    - Defaults to the caller.

The `userId` is the account, not the character, and it is what
`SLOTS_BY_USER` is keyed on and what an ACL principal is written against. The
player id is recycled; the `userId` is not. See [Identity](../../concepts/identity.md).

---

## List your characters {#opx77-characters}

Prints the caller's own characters, and re-sends the selection roster to their
client as a side effect.

**No permission required.** Any connected player may run this. It acts only on
the caller's own account.

```text
/opx77.characters
```

Takes no arguments. Must be run in game.

Cooled at one run per two seconds per player, sharing its window with the
`opx77:server:ready` net event: a second run inside it answers `error.tooFast`
and does nothing. The two entry points share one window deliberately, rather
than each granting a fresh one.

---

## Enter the world {#opx77-select}

Logs the caller in as one of their own characters, and places them.

!!! warning
    Placement is a kill followed by a respawn — that transaction carries the
    fade, the streaming preload and the grace window that a raw teleport skips.
    Running this on a character who is already in the world does that again.

**No permission required.** Ownership is re-checked server-side: a citizen id
belonging to another account answers `character.notFound`.

```text
/opx77.select <citizenId>
```

- citizenId: `string`
    - As printed by [`/opx77.characters`](#opx77-characters).

Two cooldowns stand in front of it. The command doorway is cooled at one run per
second per player and shares that window with the
`opx77:server:selectCharacter` net event; the selection itself is cooled again
at one per second inside `OPX.SelectCharacter`, because that operation is
reachable from both.

**Errors**

| Code | Meaning |
|---|---|
| `error.tooFast` | Run again inside the one-second window. |
| `entry.noIdentity` | The connection has no verified session. |
| `character.notFound` | No such character, or it belongs to another account — the same code either way, because "not yours" would be an existence oracle. |
| `character.inUse` | That character is already loaded on another connection. |
| `error.unavailable` | The database would not answer, or the outgoing character could not be saved. |

---

## Create a character {#opx77-create}

Creates a character on the caller's own account and prints the citizen id it was
given.

**No permission required.** The slot limit is enforced server-side.

```text
/opx77.create <firstName> <lastName> [origin] [gender] [birthDate]
```

- firstName: `string`
    - 2 to 32 characters, counted in characters rather than bytes.
- lastName: `string`
    - Same bounds.
- origin?: `string`
    - `nomad`, `streetkid` or `corpo`.
    - Default: `streetkid`
- gender?: `string`
    - `female` or `male`.
    - Default: `female`
- birthDate?: `string`
    - Accepted as a fifth argument, though the usage line does not advertise it.
      Shape-checked against `YYYY-MM-DD` and never parsed — the sandbox removes
      `os`, so there is no clock to check it against — and anything else is
      replaced with `2050-01-01` rather than refused.

The command doorway is cooled at one run per second per player, sharing that
window with the `opx77:server:createCharacter` net event. The write itself is
cooled again at one per three seconds — and deliberately **after** validation,
so a player fixing a mistyped name is never made to wait.

**Errors**

| Code | Meaning |
|---|---|
| `error.tooFast` | Run again inside one of the two windows. |
| `entry.noIdentity` | The connection has no verified session. |
| `error.badRequest` | The payload or the gender field was unusable. |
| `character.badName` | A name failed the length or alphabet check. |
| `character.badOrigin` | Not one of the three shipped lifepaths. |
| `character.rowLimit` | The account is at its ceiling of character **rows**, deleted ones included. |
| `character.limit` | Every character slot on the account is taken. |
| `error.unavailable` | The database would not answer, or no free citizen id came up in five draws. |

This command is unrestricted, so it prints the locale line for a refusal and
never the `detail` beside it — a detail can be a raw exception, and an
unrestricted command is not the place to hand one to a player.

---

## Delete a character {#opx77-delete}

Deletes one of the caller's own characters.

!!! danger
    The character disappears from the account immediately and nothing in this
    framework puts it back. The row itself is only **marked** deleted — so the
    citizen id is never reissued and an operator can recover it in the database
    — but every row in `CASCADE_TABLES` is deleted for real, because those
    belong to gameplay files that never agreed to the soft-delete convention.
    There is no confirmation step below this command.

**No permission required.** Ownership is re-checked server-side: a citizen id
belonging to another account answers `character.notFound`.

```text
/opx77.delete <citizenId>
```

- citizenId: `string`

The command doorway is cooled at one run per second per player, sharing that
window with the `opx77:server:deleteCharacter` net event; the deletion itself is
cooled again at one per three seconds, which guards the audit trail as much as
the write — every refused delete writes a security row. A character who is in
the world is logged out first, or the autosave would write the row back a minute
later.

**Errors**

| Code | Meaning |
|---|---|
| `error.tooFast` | Run again inside one of the two windows. |
| `entry.noIdentity` | The connection has no verified session. |
| `character.notFound` | No such character, or it belongs to another account — the same code either way, because "not yours" would be an existence oracle. |
| `error.unavailable` | The database would not answer. |

---

## Clock on or off duty {#opx77-duty}

Toggles the caller's duty state on their primary job.

**No permission required.** It acts on the caller's own character only.

```text
/opx77.duty
```

Takes no arguments.

Cooled at one run per two seconds per player. The refusal for this one arrives
as an on-screen notification rather than a command result, because each run
costs two full-`PlayerData` outbound events and the player needs to see why the
second one did nothing.

**Errors**

| Code | Meaning |
|---|---|
| `error.tooFast` | Run again inside the two-second window. |
| `error.notLoggedIn` | No character loaded — the console has none either. |
| `job.noDuty` | The job's `defaultDuty` is true: it has no shift to clock into. |
| `job.notFound` | The character holds a job that is no longer in `data/jobs.lua`. |

---

## Move money {#opx77-money}

Adds or removes money on a character and prints the new balance; a negative
amount removes.

!!! warning
    This writes the ledger directly and is audited under the reason
    `staff command by <source>`. It is not undone by anything, and a removal
    that would go negative is refused rather than clamped.

**Requires** `command.opx77.money`.

```text
/opx77.money <playerId|citizenId> <TYPE> <amount>
```

- playerId|citizenId: `integer|string`
    - A connected player's id, or the citizen id of a character who is **loaded**.
      This command resolves against the live roster only: a citizen id belonging
      to an offline character resolves to nobody and prints the usage line, as
      does a missing first argument.
- TYPE: `string`
    - A money type this server runs, upper-cased for you.
- amount: `number`
    - Positive adds, negative removes.

**Errors**

| Code | Meaning |
|---|---|
| `money.badType` | Not a money type on this server. |
| `money.badAmount` | Zero, infinite, NaN, or not a number. `NaN` is the case worth naming: it arrives over JSON, passes every comparison, and once it is in a balance so does the check that would stop the player spending it. |
| `money.insufficient` | A removal would go negative and that type does not allow it. Refused rather than clamped: a purchase that half-succeeds is worse than one that fails. |
| `money.vetoed` | A [hook](hooks.md) refused the change. |

---

## Set a job {#opx77-job}

Makes a job primary on a character at a grade, joining it if they were not
already a member.

**Requires** `command.opx77.job`.

```text
/opx77.job <playerId|citizenId> <job> [grade]
```

- playerId|citizenId: `integer|string`
    - A connected player's id, or the citizen id of a **loaded** character. This
      command resolves against the live roster only; an unresolvable target
      prints the usage line. (`OPX.SetJob` itself also accepts an offline
      citizen id — see the [Server API](server-api.md).)
- job: `string`
    - A key of `data/jobs.lua`, not a label.
- grade?: `integer`
    - Default: `0`

Duty comes from the job's own `defaultDuty` rather than being carried over from
the previous job.

**Errors**

| Code | Meaning |
|---|---|
| `job.notFound` | No job of that name in `data/jobs.lua`. |
| `job.gradeNotFound` | The job exists; that grade does not. |
| `error.unavailable` | The membership write failed. |

---

## Set a gang {#opx77-gang}

Makes a gang primary on a character at a grade, joining it if they were not
already a member.

**Requires** `command.opx77.gang`.

```text
/opx77.gang <playerId|citizenId> <gang> [grade]
```

- playerId|citizenId: `integer|string`
    - A connected player's id, or the citizen id of a **loaded** character; an
      unresolvable target prints the usage line.
- gang: `string`
    - A key of `data/gangs.lua`, not a label.
- grade?: `integer`
    - Default: `0`

**Errors**

| Code | Meaning |
|---|---|
| `gang.notFound` | No gang of that name in `data/gangs.lua`. |
| `gang.gradeNotFound` | The gang exists; that grade does not. |
| `error.unavailable` | The membership write failed. |

---

## List a group's members {#opx77-group}

Prints everyone who holds a job or gang, online or not, with their grade.

**Requires** `command.opx77.group`.

```text
/opx77.group <job|gang> <name>
```

- job|gang: `string`
    - Literally `job` or `gang`. Anything else prints the usage line.
- name: `string`
    - The group key.

This reads the membership table rather than the loaded roster, so it lists
offline characters too — which is what makes it the right command for auditing
who can open a boss menu.

**Errors**

| Code | Meaning |
|---|---|
| `error.badRequest` | The first argument was neither `job` nor `gang`. |
| `error.unavailable` | The database would not answer. |

---

## Save everyone now {#opx77-save}

Writes every loaded character back to the database immediately and reports how
many of them were saved.

**Requires** `command.opx77.save`.

```text
/opx77.save
```

Takes no arguments.

This is the command for the minute before a planned restart. It does not replace
the autosave loop, and a character whose save fails is counted in the "of N"
rather than named — read the server log for which one.

---

## Chat autocomplete {#chat-suggestions}

The core sends suggestions for the five unrestricted commands when a chat
resource announces itself with `chat:ready`, rather than at boot: suggestions
sent before that resource's surface exists land nowhere. The send is cooled at
one per ten seconds per player, because `chat:ready` is a net event anybody can
raise and the answer is several hundred bytes.

No restricted command is suggested. A suggestion is a hint in a text box, not a
grant.

## Where to go next {#next}

- [Permissions](permissions.md) — the manifest block, which is a different thing from these ACL permissions.
- [Events](events.md) — the wire names behind the unrestricted commands.
- [Server API](server-api.md) — the `OPX.*` functions these commands are thin wrappers over.
