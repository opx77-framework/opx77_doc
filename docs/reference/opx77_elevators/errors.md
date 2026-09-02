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
| `too_far` | server | further than `USE_RADIUS` from the declared shaft |
| `floor_out_of_range` | server | past the native device's floor count |
| `move_rejected` | server | `Open77.elevators.goTo` refused |
| `adopt_refused` | server, log | `Open77.elevators.adopt` answered `nil` |
| `adopt_raised` | server, log | `Open77.elevators.adopt` raised |
| `wrong_place` | server, log | the reported hash belongs to a lift that is not at this elevator |
| `already_owned` | server, log | that lift is already bound to another key |

The last four never reach a client: they are the adoption path's own outcomes
and appear in the server log only.

## The five hints {#hints}

!!! danger "`no_character`, `job_stale`, `job_required`, `grade_too_low` and `off_duty` are hints"

    They are decided on the client, from a snapshot of `PlayerData` that a
    modified client never has to read. They say what **this client believes**,
    which is what the player sees. They are not what a server would swear to,
    and the server half of this resource cannot check any of them — it has no
    way to ask `opx77_core` anything.

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

## `rate_limited` is silent {#rate-limited}

A rate-limited request gets **no** answer event at all. The limit governs the
cabin, and a refused packet would otherwise still cost one outbound event
echoing whatever the client sent — a client being told to slow down does not
need telling more often than it is allowed to ask.

Server-side refusal logging is capped the same way, at one line per player per
second: the refusal path is the cheap one for an attacker, and it is the path
that writes to disk.

So a caller waiting on [`opx77:elevators`](events.md#opx77-elevators) for a
verdict must tolerate never receiving one. Two other paths are silent for the
same reason — a sighting the server rejects, and a request from a player whose
`source` did not resolve.

## Codes declared but never produced {#unreachable}

`types.lua` declares two more codes that no shipped code path can answer, and
they are documented here so that a reader diffing the annotations against the
behaviour does not go looking for the setting that produces them.

| Code | Why it never appears |
|---|---|
| `panel_disabled` | Annotated as *`PANEL` is not `"menu"`*. There is no `PANEL` key in `config.lua`, and no file reads one. The panel is always attempted, and answers `menu_not_running` when `opx77_menu` is not running. |
| `request_refused` | Annotated as *`request` refused*. No file produces it; a request the server refuses is answered with the server's own code on `opx77_elevators:answer`. |

## Codes that only reach the log {#log-only}

The client's helper for calling another resource keeps the three levels of an
export call apart, and its reasons are logged rather than returned. They are not
export errors, but they are what an operator reads in the console:

| Reason | Meaning |
|---|---|
| `not_running` | the target resource is not in the `running` state |
| `not_dispatched` | `Open77.exports.call` refused to dispatch — level 1 |
| `malformed_answer` | the target answered something that is not a table |
| `refused` | the target answered `ok = false` with no code of its own |

A call the core **answered** and refused is authoritative: there is no
character, and the job snapshot is dropped at once. A call that **never landed**
says nothing about the character, only about the core, so the snapshot is left
alone to age out under `JOB_MAX_AGE_MS` rather than be thrown away on someone
else's restart — and rather than be trusted forever.
