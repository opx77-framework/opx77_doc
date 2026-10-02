---
title: teleports module
description: Operator-placed teleport pads to places players cannot walk to, optionally locked to a job, with every trip checked and performed by the server.
---

# teleports

The teleports module lets operators place pads that move a player to another spot: a rooftop with no stair, a mezzanine, an interior the game only reaches by cutscene. The player sees a marker, stands on it, and presses `E`; the prompt strip names the destination. A pad can be one-way or two-way, and its outbound leg can be locked to jobs, grades and duty. The client only sends a pad key and a direction; the server re-checks the job gate, the player's own position and bucket, then moves the player with the platform's teleport. Use it to open up unreachable places or give a job its own entrance.

| | |
|---|---|
| Side | both |
| Requires | `character` (hard) |
| Optional | `prompts` (the strip row), `downed` (refuses while down) |
| Configuration | `config/teleports.lua` (shared script) |
| Contract | `teleports` v1 — server, client |
| Data | none |

!!! warning "No pad ships enabled"
    The three entries in `POINTS` are examples at coordinate `0,0,0` with `enabled = false`. A server has no teleports until an operator adds real ones. Read positions and heading with `/opx.admin.self.pos`.

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-teleports-where"></a>`/opx.teleports.where` | ACL `command.opx.teleports.where` | `[key]` | Prints config problems, then one line per pad: label, bucket, one/two-way, both ends, job gate, and how many trips were taken, refused and lost. Ends with whether the platform teleport native exists. Name set by [`COMMAND`](#config-teleports-command). |

## Server contract {#server-contract}

`local teleports = OPX.Api.Get('teleports')` on the server, from code inside opx_infinity. Every function answers `{ ok, value }` / `{ ok = false, error }` and does not yield.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-teleports-entrances"></a>`Entrances` | `source` | `{ bucket, entrances = { { key, leg, label, x, y, z, allowed, error?, reason? } } }` | The entrances in the player's current bucket, each marked allowed or refused for them. Refused ones are left out when `DENIED = 'hidden'`. |
| <a id="server-teleports-isallowed"></a>`IsAllowed` | `source, key, leg` | `{ key, leg, label }` | Job gate only (no position check). `leg` is `'out'` or `'back'`. |
| <a id="server-teleports-state"></a>`State` | — | `{ count, points = { [key] = { label, bucket, twoWay, gated, taken, refused, lost } } }` | Configured pads and trip counters since start. |

## Client contract {#client-contract}

`OPX.Api.Get('teleports')` on the client.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-teleports-nearest"></a>`Nearest` | — | `{ key, leg, label, allowed }` | The entrance the player is standing on. Error `teleports.noSuchTeleport`. |
| <a id="client-teleports-entrances"></a>`Entrances` | — | `{ entrances }` | The last list the server sent, keyed `key .. '\1' .. leg`. |
| <a id="client-teleports-use"></a>`Use` | `origin?` | `{ ok = true, key, leg, source }` | Same as pressing the key. "Ok" means sent; the result arrives on [`opx:on:teleports:decision`](#opx-on-teleports-decision). Errors are locale keys: `error.noPermission` (input captured), `teleports.busy` (a progress bar is up), `teleports.noSuchTeleport`, `teleports.inFlight`, `teleports.refused`. |
| <a id="client-teleports-state"></a>`State` | — | `{ entrances, markers, nearest, leg, allowed, shown, asking, key }` | Counts and the current key label. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-teleports-ask"></a>`opx:net:teleports:ask` | client → server | none | Asks for the entrance list. Sent at start, every `POLL_MS`, and after a job refusal. |
| <a id="opx-net-teleports-use"></a>`opx:net:teleports:use` | client → server | `key, leg` | Take this pad in this direction. No coordinates are sent. |
| <a id="opx-net-teleports-sync"></a>`opx:net:teleports:sync` | server → client | `{ entrances = { … } }` | The list for the player's bucket, as in [`Entrances`](#server-teleports-entrances). |
| <a id="opx-net-teleports-answer"></a>`opx:net:teleports:answer` | server → client | `key, leg, ok, code?, labelOrReason?` | The verdict after the move finished. On success the last argument is the destination label; on refusal it is the pad's `REASON`, if any. |
| <a id="opx-on-teleports-decision"></a>`opx:on:teleports:decision` | client local | `{ source, key?, leg?, ok, error? }` | Every verdict, local refusals included. Only reaches code inside opx_infinity's client VM. |

## Configuration {#configuration}

`config/teleports.lua` sets `OPX.Config.MODULES.teleports`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-teleports-enabled"></a>`enabled` | `true` | `false` switches the module off. |
| <a id="config-teleports-use-radius"></a>`USE_RADIUS` | `2.0` | Metres across the ground from an entrance within which it may be used. |
| <a id="config-teleports-use-height"></a>`USE_HEIGHT` | `2.5` | Metres above or below the entrance that still count, so a player falling past is not on it. |
| <a id="config-teleports-marker"></a>`MARKER` | `{ shape = 'cylinder', style = 'interaction', RADIUS = 1.2 }` | Marker look. Shapes `ring`, `cylinder`; styles `interaction`, `objective`, `spawn`, `danger`; radius 0.1..50. |
| <a id="config-teleports-locked-style"></a>`LOCKED_STYLE` | `'danger'` | Marker style for a pad the player may not use (with `DENIED = 'shown'`). |
| <a id="config-teleports-denied"></a>`DENIED` | `'shown'` | `shown` draws locked pads in `LOCKED_STYLE`; `hidden` draws nothing for them. The server refuses either way. |
| <a id="config-teleports-max-distance"></a>`MAX_DISTANCE` | `120.0` | Metres beyond which a marker is not drawn, 1..500. |
| <a id="config-teleports-ground-offset"></a>`GROUND_OFFSET` | `0.06` | Metres the marker is lifted off the declared Z, 0..2. |
| <a id="config-teleports-poll-ms"></a>`POLL_MS` | `15000` | How often the client re-asks for the list (carries duty and job changes). |
| <a id="config-teleports-scan-ms"></a>`SCAN_MS` | `500` | Client marker and prompt pass. |
| <a id="config-teleports-job-max-age-ms"></a>`JOB_MAX_AGE_MS` | `60000` | Job snapshot age past which gated pads close. |
| <a id="config-teleports-membership"></a>`MEMBERSHIP` | `'primary'` | `primary` or `any`, as in [elevators](elevators.md#config-elevators-membership). |
| <a id="config-teleports-fade-ms"></a>`FADE_MS` | `400` | Screen fade around the move. Tunable `TP_FADE_MS`. |
| <a id="config-teleports-settle-ms"></a>`SETTLE_MS` | `12000` | How long the platform waits for the body to stand at the destination, 1000..30000. Tunable `TP_SETTLE_MS`. |
| <a id="config-teleports-request-window-ms"></a>`REQUEST_WINDOW_MS` | `10000` | Rate window. Tunable `TP_REQUEST_WINDOW_MS`. |
| <a id="config-teleports-requests-per-window"></a>`REQUESTS_PER_WINDOW` | `4` | Trips asked per player per window. Tunable `TP_REQUESTS_PER_WINDOW`. |
| <a id="config-teleports-key"></a>`KEY` | `{ ID = 'opx.teleports.use', NAME = 'teleports.key.use', DEFAULT = 'E' }` | The use key. Players rebind it in the pause menu under `ID`. `DEFAULT = false` registers none. |
| <a id="config-teleports-command"></a>`COMMAND` | `'opx.teleports.where'` | Diagnostic command name; `false` registers none. |
| <a id="config-teleports-points"></a>`POINTS` | 3 disabled examples | Pad key → definition. See below. |

### POINTS entries

| Field | Meaning |
|---|---|
| key | Pad name, 1..48 characters. |
| `enabled` | `false` skips the pad. |
| `LABEL` | Pad name for the diagnostic, max 64. |
| `BUCKET` | Routing bucket, default `0`. Both ends share it. |
| `ENTRY` | `{ LABEL, X, Y, Z, HEADING }` — where the player stands. |
| `EXIT` | `{ LABEL, X, Y, Z, HEADING }` — where they land and which way they face. |
| `RETURN` | `true` makes the exit an entrance back to `ENTRY`. |
| `DISMOUNT` | `true` pulls the player out of a vehicle instead of refusing. The vehicle stays behind. |
| `JOBS`, `ON_DUTY`, `REASON` | The job gate, outbound leg only. |

The prompt shows the label of the end the player is going to. The way back (`RETURN`) is never gated, so nobody is stranded after losing a job.

### The job gate

Same format as elevators; see [`OPX.JobGate.Evaluate`](../reference/lib.md#opx-jobgate-evaluate).

| Field | Meaning |
|---|---|
| `JOBS` | `{ [jobName] = minimumGradeLevel }`. Any one listed job at its grade passes. No `JOBS` = public. |
| `ON_DUTY` | `true` also requires that job to be the worked job and on duty. |
| `REASON` | Text shown to a refused player, max 64. Never translated. |

## Refusal codes {#codes}

| Code | Meaning | Player sees |
|---|---|---|
| `rate_limited` | Too many requests. | `error.tooFast` |
| `in_flight` | A trip is already running (lock released after 45 s). | `teleports.inFlight` |
| `no_such_teleport` | Unknown key, or `back` on a one-way pad. | `teleports.noSuchTeleport` |
| `no_character`, `job_stale`, `job_required`, `grade_too_low`, `off_duty` | The job gate refused. | `REASON`, else `teleports.locked` |
| `downed` | The player is down. | `teleports.downed` |
| `no_position`, `wrong_bucket`, `too_far` | Not standing on the entrance. | `teleports.noPosition`, `teleports.tooFar` |
| `unavailable`, `no_promise` | `Open77.players.teleport` is missing on this host. | `teleports.unavailable` |
| `player_in_vehicle`, `dismount_failed`, `player_not_alive`, `player_not_ready`, `invalid_position` | Refused by the platform teleport. | `teleports.inVehicle`, `teleports.notAlive`, `teleports.notReady`, `teleports.badDestination` |
| `settle_timeout` | The body never stood at the exit in `SETTLE_MS`. Usually no floor at the exit. | `teleports.neverArrived` |
