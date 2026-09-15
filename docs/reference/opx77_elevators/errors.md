---
title: opx77_elevators error codes
description: Every error code opx77_elevators can answer with, who decided it — this client, the server, or the log alone — and which of them are hints rather than proof.
---

# Error codes

Every export answers a table carrying `ok`, and on a refusal an `error` that is
a stable `snake_case` code meant for branching. The same codes appear on
[`opx77_elevators:answer`](events.md#answer) and on the
resource's own answer channel,
[`opx77:elevators`](events.md#opx77-elevators).

The **Decided by** column is the one that matters, because this resource cannot
decide everything on the side it would like to.

## Every code {#every-code}

| Code | Decided by | Meaning |
|---|---|---|
| `export_call_required` | client | no invoking resource, so the call came from inside |
| `no_elevator_nearby` | client | not standing at a configured elevator |
| `no_such_elevator` | both | no such key in `config.lua` |
| `no_such_floor` | both | that index is not a floor this elevator declares |
| `not_adopted` | both | sighted, but this resource does not own it yet |
| `no_character` | client, **hint** | `opx77_core` has no character, or never answered |
| `job_stale` | client, **hint** | the last snapshot is older than `JOB_MAX_AGE_MS` |
| `job_required` | client, **hint** | the character holds none of the floor's jobs |
| `grade_too_low` | client, **hint** | it holds one, below the minimum grade |
| `off_duty` | client, **hint** | it holds one, at grade, and is not clocked in |
| `menu_not_running` | client | `opx77_menu` is not running |
| `no_floors_available` | client | everything is gated and `DENIED_FLOORS` is `"hidden"` |
| `not_sent` | client | the net event was not accepted by the runtime |
| `rate_limited` | server | too many requests in `REQUEST_WINDOW_MS` |
| `no_position` | server | no replicated position snapshot for that player |
| `wrong_bucket` | server | the player is in another routing bucket |
| `too_far` | server | further than `USE_RADIUS` from the declared shaft, across the ground |
| `floor_out_of_range` | server | past the native device's floor count |
| `move_rejected` | server | `Open77.elevators.goTo` refused |
| `adopt_refused` | server, log | `Open77.elevators.adopt` answered `nil` |
| `adopt_raised` | server, log | `Open77.elevators.adopt` raised |
| `wrong_place` | server, log | the reported hash belongs to a lift that is not at this elevator |
| `already_owned` | server, log | that lift is already bound to another key |

The last four never reach a client: they are the adoption path's own outcomes
and appear in the server log only.

## What the player is shown {#wording}

A code is never shown to a player. The built-in panel turns one into text in two
places, and both prefer the operator's own words:

- **Beside a greyed row**, the floor's `REASON`, or `elevators.locked` —
  *"Locked"* — where the floor declares none. A greyed row with nothing beside
  it reads as broken.
- **In a toast**, after a floor picked from the list is refused, locally or by
  the server: the `reason` the refusal carried, or this resource's own wording
  for the code where it carried none. The list has already closed on the
  selection, so the toast goes through `opx77_notify` (id
  `opx77_elevators.answer`), and becomes a chat line when `opx77_notify` cannot
  show it — see [the panel's refusals](events.md#panel-refusals).

That wording is read from the catalogue in `locales/`, under
`elevators.<thing>`, in the language [`LOCALE`](config.md#locale) names. Sixteen
codes have an entry of their own — `no_elevator_nearby`, `no_such_elevator`,
`no_such_floor`, `not_adopted`, `floor_out_of_range`, `move_rejected`,
`not_sent`, `rate_limited` (`elevators.rateLimited`), the
[five hints](#hints), `no_position`, `wrong_bucket` and `too_far`. Any other
code, and any code a later release adds, reads as `elevators.refused`: *"That
floor is not available."*

A `REASON` and a `LABEL` in `config.lua` are the server owner's own words and
are never translated. Neither are the codes themselves, the diagnostic command
or the `Open77.log` lines. See [Player-facing text](config.md#locales).

## The five hints {#hints}

!!! danger "`no_character`, `job_stale`, `job_required`, `grade_too_low` and `off_duty` are hints"

    They are decided on the client, from a snapshot of `PlayerData` that a
    modified client never has to read. They say what **this client believes**,
    which is what the player sees. They are not what a server would swear to,
    and the server half of this resource checks none of them — `opx77_core` has
    no server export that answers a job.

    Use them to grey a row and to word a refusal. Do not use them to settle
    anything that must be unforgeable; see
    [The export contract](../../concepts/export-contract.md) for what a client
    answer is worth, and [the overview](index.md#satellite-lesson) for what a
    satellite can prove instead.

## The codes decided on both sides {#both-sides}

`no_such_elevator`, `no_such_floor` and `not_adopted` are decided twice, and the
two decisions are made from different evidence.

- On the **client**, they come out of `config.lua` and this client's own
  bindings. They stop a press before anything is sent.
- On the **server**, they come out of `config.lua` and the server's own
  `owned` index — the record of what this resource actually adopted, checked
  again against `Open77.elevators.get`. A lift the host has removed under us is
  answered `not_adopted` too, and the adoption is dropped so the next sighting
  can take it again.

A client that skipped the first still meets the second.

## `rate_limited` {#rate-limited}

The rate limit is the first thing the server checks, and it governs the cabin,
not the reply: a request past `REQUESTS_PER_WINDOW` in `REQUEST_WINDOW_MS` is
answered `rate_limited` on [`opx77_elevators:answer`](events.md#answer) like
every other refusal, one answer event per request, so the player sees why
nothing moved.

Server-side refusal logging is capped, at one line per player per second: the
refusal path is the cheap one for an attacker, and it is the path that writes
to disk.

Two paths are still silent — a sighting the server rejects, and a request from
a player whose `source` did not resolve — so a caller waiting on
[`opx77:elevators`](events.md#opx77-elevators) for a verdict must tolerate never
receiving one.

## Codes that no longer exist {#unreachable}

The type annotations (now `std/types.lua`) used to declare two more codes that no shipped code path could
answer. Both have been dropped from the annotations. Neither was ever produced,
so a caller branching on either has a branch that never runs, and they are named
here only because earlier documentation described them.

| Code | What it was |
|---|---|
| `panel_disabled` | Annotated as *`PANEL` is not `"menu"`*. There was never a `PANEL` key in `config.lua` and no file read one. The panel is always attempted, and answers `menu_not_running` when `opx77_menu` is not running. |
| `request_refused` | Annotated as *`request` refused*. No file produced it; a request the server refuses is answered with the server's own code on `opx77_elevators:answer`. |

## Codes that only reach the log {#log-only}

The client's helper for calling another resource keeps the three levels of an
export call apart, and its reasons are logged rather than returned. They are not
export errors, but they are what an operator reads in the console:

| Reason | Meaning |
|---|---|
| `not_running` | the target resource is not in the `running` state |
| `not_dispatched` | `Open77.exports.call` refused to dispatch — level 1 |
| `malformed_answer` | the target answered something that is not a table |
| `refused` | the target answered a table without `ok = true` and with no code of its own |

Any answer whose `ok` is not exactly `true` is a refusal, not only `ok = false`,
so a table without `ok` is never taken for a success.

A call the core **answered** and refused is authoritative: there is no
character, and the job snapshot is dropped at once. A call that **never landed**
says nothing about the character, only about the core, so the snapshot is left
alone to age out under `JOB_MAX_AGE_MS` rather than be thrown away on someone
else's restart — and rather than be trusted forever.
