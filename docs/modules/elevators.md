---
title: elevators module
description: Job-gated floor lists on Night City's existing lifts, with the server re-checking job, grade, duty, bucket and distance before it moves a cabin.
---

# elevators

The elevators module takes over lifts that already exist in the game world and gives them a floor list from `config/elevators.lua`. Each floor can be public or locked to jobs, a minimum grade and being on duty. The client finds configured lifts near the player and reports them; the server adopts and locks each lift, then moves the cabin only after re-checking the player's job, bucket and distance itself. The floor list is drawn with the [menu](menu.md) module. Use it to keep a precinct's upper floors for police, or a corporate tower's offices for its staff.

| | |
|---|---|
| Side | both |
| Requires | `character` (hard) |
| Optional | `menu` (floor list), `downed` (no list while down) |
| Configuration | `config/elevators.lua` (shared script) |
| Contract | `elevators` v1 — server, client |
| Data | none |

!!! warning "Nothing opens the floor list yet"
    No key, prompt or eye row in opx_infinity calls [`OpenPanel`](#client-elevators-openpanel). The adopted lifts are locked, so players cannot use the game's own lift panel either. Until a caller is added, a player cannot ride a configured lift.

!!! warning "The shipped elevators are samples"
    The four entries in `config/elevators.lua` have placeholder positions and guessed floor indexes. A lift is matched only within `MATCH_RADIUS` of its declared position, so a wrong position matches nothing and the lift is never adopted. Read real positions with the client console command `resource.emit open77:elevators:nearby 100`.

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-elevators-where"></a>`/opx.elevators.where` | ACL `command.opx.elevators.where` | `[key]` | Prints config problems, then one line per elevator: label, position, floor counts, adopted id, phase, active floor, flags; then `DENIED_FLOORS` and `MEMBERSHIP`. Name set by [`COMMAND`](#config-elevators-command). |

## Server contract {#server-contract}

`local elevators = OPX.Api.Get('elevators')` on the server, from code inside opx_infinity. Every function answers `{ ok, value }` / `{ ok = false, error }` and does not yield.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-elevators-floors"></a>`Floors` | `source, elevatorKey` | `{ elevator, floors = { { index, label, ok, error?, reason? } } }` | Every floor and whether this player may use it. Hidden floors are left out when `DENIED_FLOORS = 'hidden'`. |
| <a id="server-elevators-isfloorallowed"></a>`IsFloorAllowed` | `source, elevatorKey, floorIndex` | `{ elevator, floor, label }` | Job gate only: no distance or bucket check. Errors are the [job-gate codes](#codes) or `no_such_floor`. |
| <a id="server-elevators-state"></a>`State` | — | `{ adopted = { [key] = { id, floorCount, used } } }` | Lifts this server has adopted. |

## Client contract {#client-contract}

`OPX.Api.Get('elevators')` on the client. Results are `{ ok, value }` / `{ ok = false, error }`; a refusal also carries `elevator`, `floor` and `reason` (the floor's `REASON`) when known. `elevatorKey` may be nil to mean the nearest elevator.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-elevators-nearestelevator"></a>`NearestElevator` | — | `{ elevator, id }` | The nearest configured lift within `USE_RADIUS` across the ground, from a recent scan. `no_elevator_nearby` otherwise. |
| <a id="client-elevators-floors"></a>`Floors` | `elevatorKey?` | `{ elevator, floors }` | Same rows as the server's `Floors`, from the client's own job snapshot. |
| <a id="client-elevators-isfloorallowed"></a>`IsFloorAllowed` | `elevatorKey?, floorIndex` | `{ elevator, floor, label }` | A local hint. The server decides. |
| <a id="client-elevators-requestfloor"></a>`RequestFloor` | `elevatorKey?, floorIndex, origin?` | `{ elevator, floor, label, queued = true, source }` | Sends the request. "Ok" means sent; the server's verdict arrives on [`opx:on:elevators:decision`](#opx-on-elevators-decision). |
| <a id="client-elevators-openpanel"></a>`OpenPanel` | `elevatorKey?` | `{ elevator, floors, queued = true }` | Opens the floor list in a menu (owner `elevators`). A refused floor from the list shows a toast. Errors include `player_down`, `menu_not_running`, `no_floors_available`, and any [menu code](menu.md#codes). |
| <a id="client-elevators-state"></a>`State` | — | `{ job, grade, onDuty, fresh, ageMs, seen, bound, nearest }` | This client's view: job snapshot, lifts in range, lifts bound by the server. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-elevators-sighted"></a>`opx:net:elevators:sighted` | client → server | `engineEntity, x, y, z, floorCount, activeFloor` | A configured, unmanaged lift was seen. The server checks the player is within `SCAN_RADIUS` and in the right bucket, then adopts and locks it. Max 12 per second per player. |
| <a id="opx-net-elevators-request"></a>`opx:net:elevators:request` | client → server | `elevatorKey, floorIndex` | Ride request. Rate-limited by `REQUESTS_PER_WINDOW`. |
| <a id="opx-net-elevators-bound"></a>`opx:net:elevators:bound` | server → client | `elevatorKey, id, floorCount` | The lift is adopted under this id. |
| <a id="opx-net-elevators-released"></a>`opx:net:elevators:released` | server → client | `elevatorKey` | The lift was given back (removed by the host, unused for 10 minutes, or the module stopped). |
| <a id="opx-net-elevators-answer"></a>`opx:net:elevators:answer` | server → client | `elevatorKey, floorIndex, ok, error?` | The server's verdict on a request. |
| <a id="opx-on-elevators-decision"></a>`opx:on:elevators:decision` | client local | `{ elevator, floor, ok, error?, reason?, label?, source }` | Every verdict, local refusals included. `source` is `server`, `panel` or `contract`. Only reaches code inside opx_infinity's client VM. |

## Configuration {#configuration}

`config/elevators.lua` sets `OPX.Config.MODULES.elevators`. Shared script. Distances are measured across the ground (X and Y) against the declared position, so a lift can be called from any floor of its shaft.

| Key | Default | What it does |
|---|---|---|
| <a id="config-elevators-enabled"></a>`enabled` | `true` | `false` switches the module off. |
| <a id="config-elevators-denied-floors"></a>`DENIED_FLOORS` | `'shown'` | `shown` greys a refused floor; `hidden` leaves it out of the list. |
| <a id="config-elevators-membership"></a>`MEMBERSHIP` | `'primary'` | `primary` reads the worked job only; `any` also counts every job membership for the grade (never for `ON_DUTY`). |
| <a id="config-elevators-job-max-age-ms"></a>`JOB_MAX_AGE_MS` | `60000` | Past this snapshot age every gated floor closes (`job_stale`); public floors stay open. |
| <a id="config-elevators-poll-ms"></a>`POLL_MS` | `15000` | How often the client re-reads the character's job. |
| <a id="config-elevators-scan-ms"></a>`SCAN_MS` | `2000` | How often the client looks for lifts. |
| <a id="config-elevators-match-radius"></a>`MATCH_RADIUS` | `6.0` | Metres between a seen lift and a declared position for them to match. |
| <a id="config-elevators-use-radius"></a>`USE_RADIUS` | `4.0` | Metres from the declared position within which a player may ride. |
| <a id="config-elevators-scan-radius"></a>`SCAN_RADIUS` | `40.0` | Metres the client scans, and the server's limit on a sighting. |
| <a id="config-elevators-travel-ms"></a>`TRAVEL_MS` | `8000` | Cabin travel time. Tunable `ELEV_TRAVEL_MS`. |
| <a id="config-elevators-request-window-ms"></a>`REQUEST_WINDOW_MS` | `10000` | Rate window. Tunable `ELEV_REQUEST_WINDOW_MS`. |
| <a id="config-elevators-requests-per-window"></a>`REQUESTS_PER_WINDOW` | `6` | Ride requests per player per window. Tunable `ELEV_REQUESTS_PER_WINDOW`. |
| <a id="config-elevators-command"></a>`COMMAND` | `'opx.elevators.where'` | The diagnostic command name; `false` registers none. |
| <a id="config-elevators-elevators"></a>`ELEVATORS` | 4 samples: `arasaka_tower`, `ncpd_watson`, `vik_clinic`, `afterlife` | Elevator key → definition. See below. |

### ELEVATORS entries

| Field | Meaning |
|---|---|
| key | The durable name of the elevator (the host's id changes each restart). |
| `LABEL` | Menu title. Never translated. |
| `X`, `Y`, `Z` | Declared position. |
| `BUCKET` | Routing bucket, default `0`. |
| `ENTITY` | Optional engine hash, when two shafts share a lobby. |
| `FLOOR_COUNT` | Floors of the native lift. Overrides what the client reports. |
| `FLOORS` | List of `{ INDEX, LABEL, JOBS?, ON_DUTY?, REASON? }`. `INDEX` is the native floor index (0-based), not the list position. |

### The job gate

A floor's `JOBS`, `ON_DUTY` and `REASON` follow the shared job-gate format; see [`OPX.JobGate.Evaluate`](../reference/lib.md#opx-jobgate-evaluate).

| Field | Meaning |
|---|---|
| `JOBS` | `{ [jobName] = minimumGradeLevel }`, e.g. `{ ncpd = 1, maxtac = 0 }`. Any one listed job at its grade passes. No `JOBS` = public. |
| `ON_DUTY` | `true` also requires that job to be the worked job and on duty. |
| `REASON` | Text shown to a refused player instead of the generic sentence. Never translated. |

## Refusal codes {#codes}

| Code | Meaning | Locale key |
|---|---|---|
| `no_elevator_nearby` | No configured lift within `USE_RADIUS`. | `elevators.noElevatorNearby` |
| `no_such_elevator`, `no_such_floor` | Not in the config. | `elevators.noSuchElevator`, `elevators.noSuchFloor` |
| `no_character` | No character, or no job snapshot. | `elevators.noCharacter` |
| `job_stale` | Snapshot older than `JOB_MAX_AGE_MS`. | `elevators.jobStale` |
| `job_required`, `grade_too_low`, `off_duty` | The job gate refused. | `elevators.jobRequired`, `elevators.gradeTooLow`, `elevators.offDuty` |
| `not_adopted` | The server has not taken the lift yet. | `elevators.notAdopted` |
| `floor_out_of_range` | Index past the lift's floor count. | `elevators.floorOutOfRange` |
| `no_position`, `wrong_bucket`, `too_far` | The server's position check failed. | `elevators.noPosition`, `elevators.wrongBucket`, `elevators.tooFar` |
| `move_rejected` | The platform refused to move the cabin. | `elevators.moveRejected` |
| `rate_limited` | Too many requests. | `elevators.rateLimited` |
| `not_sent` | The net event was not sent. | `elevators.notSent` |
| `player_down`, `menu_not_running`, `no_floors_available` | `OpenPanel` only. | — |
| `internal_error` | A client contract function raised; see the log. | — |
