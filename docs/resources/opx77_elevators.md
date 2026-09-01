# opx77_elevators

!!! danger "The job check is a client-side hint, and no setting turns it into anything else"

    The Open77 server runtime has no cross-resource event bus, so this
    resource's **server half cannot ask [`opx77_core`](opx77_core.md) for a
    player's job**. There is no message to send and no promise to await. It
    re-derives everything else — the elevator, the floor, the player's position
    and routing bucket, the rate — but not the job.

    **Do not gate money, contraband or a body count on it.** Gate the flavour:
    which floor a lift stops at, which corridor a story happens in. A decision
    that has to be unforgeable belongs in `opx77_core`'s server VM, where the
    job is already in memory.

    A modified client skips every line of the gate. What it still cannot do is
    move a cabin it is not standing at, or one this resource never adopted.

## What it is

Job-gated in-world elevators: a floor list on the lifts Night City already has,
each floor opened or closed by the job a character holds in
[`opx77_core`](opx77_core.md). An Arasaka executive floor, the NCPD holding
level, a ripperdoc's back room — the jobs, the grades and the wording all live
in `config.lua`.

| | |
|---|---|
| Resource | `opx77_elevators` |
| Version | `0.2.0` |
| Requires | `open77_version ">=0.0.1"` |
| Reload policy | `local` — no CEF surface; the server re-adopts from the next client sighting |
| Auto start | yes |
| Permissions | `network.events`, `world.elevators`, `elevators.read` |
| Optional at runtime | [`opx77_menu`](opx77_menu.md) for the panel, `opx77_core` for the job |

Nothing is declared as a hard dependency. Without `opx77_core` every gated
floor closes and every public floor stays open; without `opx77_menu` the
built-in panel is unavailable and the exports carry on unchanged.

## What the server does prove

The honest security boundary, stated plainly.

Every adopted lift is locked with the host's own `Open77.elevators.flags.locked`
flag. That is the platform's switch for *refuse requests coming from a client*,
so the elevator authority rejects a request sent straight off a client, and this
resource's server half is the only way the cabin moves.

On every floor request, from its own authority, the server re-derives:

| It checks | Refusal |
|---|---|
| The elevator key is one `config.lua` declares | `no_such_elevator` |
| The floor index is one that elevator declares | `no_such_floor` |
| The elevator is one **this resource** adopted, and the host still has it | `not_adopted` |
| The index is inside the native device's own floor count | `floor_out_of_range` |
| The player has a fresh replicated position | `no_position` |
| The player is in the elevator's routing bucket | `wrong_bucket` |
| The player is within `USE_RADIUS` of the **declared** shaft position | `too_far` |
| The player is inside the rate limit | `rate_limited` |
| The host accepted the move | `move_rejected` |

Distance is measured against the declared shaft position, never the cabin's: a
cabin parked at the top of the shaft is thirty metres from the player standing
at the ground-floor panel, who is exactly the person allowed to call it.

!!! warning "The residual, exactly"

    A modified client reaches **the configured floors of an elevator it is
    standing at**, and not the whole shaft. It cannot reach a floor no
    `config.lua` entry declares, a lift in another bucket, a lift across the
    map, or a lift this resource never adopted. It can reach a gated floor of
    the lift it is standing next to. Design as though it will.

## Exports

Every export is **client-side** — the Open77 server runtime installs none. A
server resource that wants an elevator panel sends a net event to its own
client half, and that half calls these. See
[the client export contract](../index.md#the-client-export-contract) for the full contract.

Every call answers a table carrying `ok` and never raises. `error` is a stable
`snake_case` code meant for branching.

| Export | Parameters | Answers |
|---|---|---|
| `floors` | `elevator?` | the floor list to draw |
| `check` | `elevator?`, `floor` | whether one floor would be allowed |
| `use` | `elevator?`, `floor` | select a floor |
| `panel` | `elevator?` | open the floor list through `opx77_menu` |
| `nearest` | — | which configured elevator the player is standing at |
| `state` | — | what this client knows, and how old it is |

`elevator` is always optional and always defaults to the elevator the player is
standing at — the nearest configured elevator within `USE_RADIUS`, from a
sighting no older than two scans. Every answer that has one carries the
`elevator` key back, so a caller drawing its own panel needs nothing else.

!!! note "Called from another resource, always"

    Each export reads the caller from `GetInvokingResource()` and refuses
    `export_call_required` when there is none. A call with no invoking resource
    is a call made from inside this VM, which went somewhere it did not mean to.

### `floors(elevator?)`

The floor list for a player standing at an elevator: every floor they may
select, plus — under `DENIED_FLOORS = "shown"` — the ones they may not, each
carrying its reason. Rows come back in **configured order**.

```lua
---@class FloorListing
---@field ok       boolean
---@field error    string|nil
---@field elevator string|nil   the key the list is for
---@field floors   table[]|nil  { index, label, ok, error, reason }
```

Each row:

| Field | Meaning |
|---|---|
| `index` | the **native** floor index, 0-based |
| `label` | the floor's `LABEL` |
| `ok` | whether this client believes the player may take it |
| `error` | why not: `job_required`, `grade_too_low`, `off_duty`, `job_stale`, `no_character` |
| `reason` | the floor's `REASON`, present only on a refused row |

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_elevators", "floors")
  if not promise then                          -- dispatch failure
    return Open77.log.warn("floors not dispatched: " .. tostring(reason))
  end

  local result, callError = promise:await()    -- resolution failure
  if callError then
    return Open77.log.warn("floors failed: " .. tostring(callError))
  end

  if not result.ok then
    -- no_elevator_nearby | no_such_elevator | export_call_required
    return Open77.log.info("no floor list: " .. tostring(result.error))
  end

  for index = 1, #result.floors do
    local row = result.floors[index]
    print(("%s  floor %d  %s"):format(
      result.elevator, row.index,
      row.ok and "open" or (row.reason or row.error)))
  end
end)
```

Errors: `export_call_required`, `no_elevator_nearby`, `no_such_elevator`.

### `check(elevator?, floor)`

Would this player be allowed on this floor? Decides nothing and sends nothing —
it is the same call `use` makes, exposed so a caller can grey a row of its own
UI the way the built-in panel does.

```lua
---@class FloorDecision
---@field ok       boolean
---@field error    string|nil
---@field elevator string|nil
---@field floor    integer|nil
---@field label    string|nil
---@field reason   string|nil   the floor's REASON, on a refusal
```

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call(
    "opx77_elevators", "check", "arasaka_tower", 11)
  if not promise then return Open77.log.warn(tostring(reason)) end

  local result, callError = promise:await()
  if callError then return Open77.log.warn(tostring(callError)) end

  if result.ok then
    print("Executive Suite is open")
  else
    print(("%s: %s"):format(result.error, result.reason or "no wording configured"))
  end
end)
```

Errors: `export_call_required`, `no_elevator_nearby`, `no_such_elevator`,
`no_such_floor`, plus the four gate refusals `no_character`, `job_stale`,
`job_required`, `grade_too_low`, `off_duty`.

### `use(elevator?, floor)`

Select a floor. Runs the same gate as `check`, and on a pass sends the request
to this resource's server half.

```lua
---@class FloorRequest : FloorDecision
---@field queued boolean|nil   true when the request left the client
---@field source string|nil    the invoking resource's name, "panel", or "server"
```

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call(
    "opx77_elevators", "use", nil, 3)              -- nearest elevator, floor 3
  if not promise then
    return Open77.log.warn("use not dispatched: " .. tostring(reason))
  end

  local result, callError = promise:await()
  if callError then
    return Open77.log.warn("use failed: " .. tostring(callError))
  end

  if not result.ok then
    -- refused here, on this client, before anything was sent
    return Open77.log.info("refused: " .. tostring(result.error))
  end

  -- asked, not moved: wait for the verdict on Config.EVENT
  print("requested " .. tostring(result.label))
end)
```

Errors: `export_call_required`, `no_elevator_nearby`, `no_such_elevator`,
`no_such_floor`, the five gate refusals, `not_adopted` (the lift was sighted but
the server has not taken ownership yet), and `not_sent` (the net event was not
accepted by the runtime).

### `panel(elevator?)`

Open the floor list through [`opx77_menu`](opx77_menu.md). The one call an
interaction resource needs: bind it to a prompt on the elevator's call button
and this resource does the rest.

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_elevators", "panel")
  if not promise then return Open77.log.warn(tostring(reason)) end

  local result, callError = promise:await()
  if callError then return Open77.log.warn(tostring(callError)) end

  if not result.ok then
    -- menu_not_running | no_floors_available | no_elevator_nearby | no_such_elevator
    return Open77.log.info("panel refused: " .. tostring(result.error))
  end

  print(("panel queued for %s, %d rows"):format(result.elevator, result.floors))
end)
```

`ok = true` here also means **asked**: `await` is coroutine-only and an export
handler is not a coroutine, so the call to `opx77_menu` is queued on a thread
and the answer is a log line, not a return value.

Errors: `export_call_required`, `menu_not_running`, `no_elevator_nearby`,
`no_such_elevator`, `no_floors_available` (every floor is gated and
`DENIED_FLOORS` is `"hidden"`, and an empty menu is refused by `opx77_menu`
anyway).

### `nearest()`

```lua
-- { ok = true, elevator = "ncpd_watson", id = 7 }
-- { ok = false, error = "no_elevator_nearby" }
```

`id` is the Open77 elevator id, present only once the lift is adopted. Ids are
assigned at adoption and change on every restart, which is why the durable name
of an elevator is its config **key** and never its id.

### `state()`

What this client knows, and how old it is — enough to debug a panel that will
not open, and nothing a caller could mistake for authority.

| Field | Meaning |
|---|---|
| `job` | the primary job's name, or `nil` |
| `grade` | its grade level, or `nil` |
| `onDuty` | whether the character is clocked in |
| `fresh` | whether the gate still trusts the snapshot |
| `ageMs` | how old the snapshot is |
| `seen` | configured lifts in range |
| `bound` | of those, how many this resource owns |
| `nearest` | the elevator key the player is standing at, or `nil` |

`fresh = false` with a `job` present is the state worth recognising: the core
has been unreachable for longer than `JOB_MAX_AGE_MS`, so every gated floor is
closed even though a job is on screen.

### Every error code

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
| `no_position` | server | no fresh replicated position snapshot |
| `wrong_bucket` | server | the player is in another routing bucket |
| `too_far` | server | further than `USE_RADIUS` from the declared shaft |
| `floor_out_of_range` | server | past the native device's floor count |
| `move_rejected` | server | `Open77.elevators.goTo` refused |
| `adopt_refused` | server, log | `Open77.elevators.adopt` answered `nil` |
| `adopt_raised` | server, log | `Open77.elevators.adopt` raised |
| `wrong_place` | server, log | the reported hash belongs to a lift that is not at this elevator |
| `already_owned` | server, log | that lift is already bound to another key |

The last four never reach a client: they are the adoption path's own outcomes
and appear in the server log.

!!! note "`rate_limited` is silent"

    A rate-limited request gets **no** answer event. The limit governs the
    cabin, and a refused packet would otherwise still cost one outbound event
    echoing whatever the client sent — a client being told to slow down does not
    need telling more often than it is allowed to ask. Server-side refusal
    logging is likewise capped at one line per player per second.

## `ok = true` never means the cabin moved

An export handler is **not a coroutine**, so nothing inside one can wait for the
server. `use` answers what is known now, which is *asked*: the gate passed, the
elevator is adopted, and the net event was accepted. The verdict arrives later.

Two channels carry it, and both are client-side events:

- **`opx77_elevators:answer`** — the raw net event from this resource's server
  half, `(key, index, ok, error)`.
- **`OPX_ELEVATORS_CONFIG.EVENT`** — shipped as `opx77:elevators`, raised on the
  client after **every** decision, local or remote. This is the one to listen on.

```lua
AddEventHandler("opx77:elevators", function(payload)
  -- payload = { elevator, floor, ok, error, label, reason, source, queued }
  if payload.source ~= "my_resource" then return end   -- only my own presses

  if payload.ok then
    print(("cabin moving to %s floor %d"):format(payload.elevator, payload.floor))
  else
    print(("floor %s refused: %s"):format(
      tostring(payload.floor), payload.reason or payload.error))
  end
end)
```

`source` is the invoking resource's name for a press made through the `use`
export, `"panel"` for one made in the built-in floor list, and `"server"` for
the verdict itself.

!!! tip "What is published, and when"

    A **local** refusal — the gate, `not_adopted`, `not_sent` — is published
    immediately, before anything leaves the client. A press that passes locally
    publishes **nothing** at that moment; the next event about it is the
    server's verdict, with `source = "server"`. So a successful press produces
    exactly one event and a locally refused one also produces exactly one.

!!! warning "The event name is not a trust boundary"

    The client runtime *does* have a cross-resource event bus, so any resource
    on the player's machine can raise `opx77:elevators` with any payload. Treat
    what arrives as a notification, not as authority — the server re-derives
    every clause of a request regardless.

## The panel

This resource owns **no** WebUI surface. It asks for no UI permission, ships no
web files and draws nothing. The floor list is [`opx77_menu`](opx77_menu.md)'s,
opened through its client export, and everything here is the spec handed to it.

Each row becomes a menu item:

- the floor's `LABEL` is the item label;
- a refused row carries its `REASON` as the item's **value**, not a description —
  a greyed row with nothing beside it reads as broken, and "Arasaka Executive,
  on duty" reads as a door;
- a refused row is `disabled`;
- the elevator key and the floor index ride in the item's `data`.

The return channel is an **event**, because that is the only channel there is:
the client runtime puts every export through a codec, so a callback cannot be
handed across a resource boundary. `opx77_menu` echoes each item's `data` back
in the payload, and this resource reads the key and index out of it.

!!! success "Optional, never a dependency"

    A missing or stopped `opx77_menu` costs **one logged line**. `floors`,
    `check` and `use` go on doing exactly what they did before, which is what a
    server with its own interaction UI wants anyway. `panel` is the only export
    that answers `menu_not_running`.

After the server's verdict arrives, the panel writes the refusal under the list
as a status line — best-effort, since the list closes on select and the answer
lands long after. It does this only for a panel it opened itself, and only once:
any resource on the machine can raise the answer event, and one thread per
message would drain the client's task budget.

## Configuring an elevator

Elevators live in `config.lua`, each under a **durable key** — the name used by
every export, every event and the diagnostic command. It never changes; the
Open77 id does, on every restart.

```lua
OPX_ELEVATORS_CONFIG = {
  -- ... settings ...

  ELEVATORS = {
    arasaka_tower = {                 -- (1) the durable key
      LABEL = "ARASAKA TOWER",        -- (2) the panel's title
      X = -1521.40, Y = 892.75, Z = 42.10,   -- (3) where the shaft is
      BUCKET = 0,                     -- (4) routing bucket, default 0
      -- ENTITY = "0x0123456789ABCDEF",      -- (5) optional, pins WHICH lift
      FLOOR_COUNT = 12,               -- (6) the NATIVE device's floor count
      FLOORS = {                      -- (7) the stops this resource offers
        { INDEX = 0, LABEL = "Plaza" },                    -- public
        { INDEX = 2, LABEL = "Reception" },                -- public
        { INDEX = 5, LABEL = "Analytics",
          JOBS = { arasaka = 0 },                          -- (8) name -> min grade
          REASON = "Arasaka staff only" },                 -- (9) shown when refused
        { INDEX = 8, LABEL = "Counterintel",
          JOBS = { arasaka = 2, militech = 3 },            -- (10) any one of them
          REASON = "Arasaka Counterintel" },
        { INDEX = 11, LABEL = "Executive Suite",
          JOBS = { arasaka = 3 },
          ON_DUTY = true,                                  -- (11) and clocked in
          REASON = "Arasaka Executive, on duty" },
      },
    },
  },
}
```

1. **The key.** A string, unique, stable. `floors("arasaka_tower")`,
   `opx77.elevators.where arasaka_tower`, and the `elevator` field of every
   payload all use it.
2. **`LABEL`** — the panel's title, and the elevator's name in the diagnostic
   report.
3. **`X` / `Y` / `Z`** — the shaft's position, in metres. Used three ways: to
   recognise a streamed native lift as this elevator (within `MATCH_RADIUS`), to
   decide which elevator the player is standing at (within `USE_RADIUS`), and by
   the server as the reference point for `too_far`. It is the **shaft's**
   position, not the cabin's.
4. **`BUCKET`** — the routing bucket, defaulting to `0`. An elevator in a bucket
   is invisible to players outside it. The server adopts into the **elevator's**
   bucket and never the reporter's: adopting into a player's bucket would let the
   first person to walk past a lift fix it to theirs, and someone doing that from
   a private instance would leave everyone else answered `wrong_bucket` for the
   life of the process.
5. **`ENTITY`** — optional. The native `LiftDevice` hash, as a `"0x…"` string of
   sixteen hex digits. REDengine hashes are **opaque**: keep them as strings,
   never pass them through `tonumber`. When declared, it pins *which* lift among
   the ones the coordinates could match; `X` and `Y` must still agree, but `Z` is
   free — that is what the hash is for, since the cabin is wherever it last
   stopped and a tower's cabin is nowhere near its shaft's declared `Z`. The
   shipped entries declare none, and match on position alone.
6. **`FLOOR_COUNT`** — the **native device's** floor count, not `#FLOORS`. It is
   the ceiling every index is checked against, and the config's value wins over
   whatever a client reports; a mismatch is logged once per elevator, not once
   per sighting.
7. **`FLOORS`** — the stops this resource offers, in the order the panel draws
   them. There is no need to list every native floor: a floor absent from this
   list is a floor no panel offers and no request can name.
8. **`JOBS`** — a map of job name to **minimum grade level**. `{ arasaka = 0 }`
   means "any Arasaka grade". Job names must exist in
   `opx77_core/data/jobs.lua`; this resource's VM cannot verify them, so a typo
   reads as a floor nobody can take.
9. **`REASON`** — the operator's own wording, shown beside a refused row. Write
   it as a door would be signed, not as an error.
10. **Several jobs on one floor** — the character needs to satisfy **one** of
    them. The refusal reported is the closest near-miss, ranked
    `off_duty` > `grade_too_low` > `job_required`, so a floor listing three jobs
    tells the player the most useful thing rather than whichever one `pairs`
    reached first.
11. **`ON_DUTY`** — also require the character be clocked in. Duty lives on the
    **primary** job only: the membership map holds grades, not a clock.

!!! danger "`INDEX` is the native floor index, never the position in `FLOORS`"

    The panel's order is a presentation choice; the shaft's order is not. Floor
    indexes are the vanilla per-lift indexes, `0` to `FLOOR_COUNT - 1`, and they
    are not universal floor IDs — floor `2` of one lift has nothing to do with
    floor `2` of another. Getting this wrong sends the cabin to the wrong storey
    with no error at all, because the index was valid.

### Finding real coordinates

The shipped positions are **placeholders**. Probe the real ones from the client
developer console, which lists streamed native `LiftDevice` hashes and exact
positions — including unmanaged lifts:

```text
resource.emit open77:elevators:nearby 100
```

Take the position for `X`/`Y`/`Z` and, if two shafts sit close enough to be
confused, the hash for `ENTITY`.

### Checking the configuration

Everything wrong with `ELEVATORS` that can be seen without a world is reported
at boot, as a warning line per problem, and again on demand from the diagnostic
command:

- an elevator with no `FLOORS`, so its panel would be empty;
- a `FLOOR_COUNT` that is not a whole number of at least 1;
- an `INDEX` that is not a whole number of at least 0;
- an `INDEX` outside `FLOOR_COUNT`;
- an `INDEX` declared twice;
- a floor with no `LABEL`;
- a `JOBS` that is not a table of name to minimum grade.

It cannot check a job **name**: those live in `opx77_core`, which this VM cannot
ask.

## The gate

One file decides, `shared/access.lua`, and it is the only file that reads a job.
It is pure — no runtime, no network, no elevator API — which is what makes it
testable without a client. Both halves load it, for different halves of the
question: the client asks *may this player press this button*, the server asks
only *is this a button this file declared*, because the server has no character
to ask about.

### How `evaluate` decides

1. A floor with no `JOBS`, or an empty `JOBS`, is **public**: allowed, always,
   with no further reading.
2. No snapshot, or one with no readable timestamp → `no_character`.
3. A snapshot older than `JOB_MAX_AGE_MS` → `job_stale`.
4. A snapshot with no primary job → `no_character`.
5. Otherwise every entry of `JOBS` is tried. The character passes on the first
   one it satisfies: the grade it holds is at or above the minimum, and — when
   `ON_DUTY` is set — that same job is the primary one and is clocked in.
6. If none passes, the closest near-miss is reported:
   `off_duty` > `grade_too_low` > `job_required`.

The snapshot is re-read on **every press**, so there is nothing to invalidate: a
promotion, a demotion or a job swapped at a terminal changes the panel from the
next press onward.

### `MEMBERSHIP`

| Value | What counts as holding a job |
|---|---|
| `"primary"` *(shipped)* | only the job being worked — `PlayerData.job` |
| `"any"` | the whole membership map as well — `PlayerData.jobs`, name to grade |

Under `"any"`, a character who is an NCPD officer but currently working as a
courier still reaches the NCPD floors. `ON_DUTY` is unaffected either way: it is
satisfied only by the primary job, because the membership map holds grades and
not a clock.

### `JOB_MAX_AGE_MS`

The client re-reads the character from `opx77_core` every `POLL_MS`, and also on
`opx77:client:playerLoaded` and `opx77:client:playerDataChanged`. Each read
stamps the snapshot with the client clock. Past `JOB_MAX_AGE_MS`, every gated
floor closes.

The two failure levels of a cross-resource call are kept apart on purpose:

- a call the core **answered** and refused is authoritative — there is no
  character, and the snapshot is dropped at once;
- a call that **never landed** says nothing about the character, only about the
  core, so the snapshot is left alone to age out rather than be thrown away on
  someone else's restart, and rather than be trusted forever.

### `DENIED_FLOORS`

| Value | A floor the player cannot take |
|---|---|
| `"shown"` *(shipped)* | appears, greyed, with its `REASON` beside it |
| `"hidden"` | does not appear at all |

`"shown"` tells the player a door exists and who it is for, which is usually the
point of a job-gated floor. `"hidden"` tells them nothing — and when it hides
*everything* at an elevator, `panel` answers `no_floors_available` rather than
opening an empty list, because "nothing happened" is a worse answer than a named
one.

### The four ways it fails closed

1. **No character** — `opx77_core` answered that there is none.
2. **A job matching nothing** — the character's job is not one this floor lists,
   or is below its grade, or is off duty.
3. **A stale snapshot** — the last reading is older than `JOB_MAX_AGE_MS`.
4. **No snapshot at all** — the core has never answered.

!!! success "A public floor stays open through all four"

    A floor with no `JOBS` is allowed with no snapshot, with a stale snapshot,
    and with no character — a lobby that stops working while the core restarts
    is worse than anything the gate protects. Ground floors, street level and
    reception should therefore carry no `JOBS` at all.

!!! note "`no_character` on a player who is very much logged in"

    "Never answered" and "answered, no character" both refuse a gated floor, so
    the difference only shows up in the log — but it shows up there. An operator
    reading `no_character` for a player who is plainly in game has learnt
    something about their core, not about their elevators.

## Adoption

Elevators are static world entities: they are **adopted**, not spawned.

1. **Sighting.** Every `SCAN_MS`, the client asks the host for the native lifts
   within `SCAN_RADIUS` and matches each against the configured positions within
   `MATCH_RADIUS`. Only lifts that match a **configured** position are reported.
   The platform's reference resource adopts every native lift it sees, which is
   right for a reference and wrong here: this resource is a door policy, and
   adopting a lift nobody wrote a policy for would take ownership of a cabin it
   has nothing to say about.
2. **Waiting for topology.** The native device's floor count and active floor
   arrive asynchronously. A lift whose inspection has not answered yet is left
   for the next scan — a floor count is never invented. Unadopted lifts are
   re-reported no more than once every five seconds.
3. **Adoption.** The server validates the report on its own terms: the hash is
   sixteen hex digits, the coordinates are finite, the floor count is between 1
   and 1025, the active floor is inside it, and the reporter is genuinely within
   `SCAN_RADIUS` of what it claims to see. It then picks the elevator, the
   bucket and the floor count **itself** — discovery only proposes immutable
   topology. A lift already adopted in that bucket is re-claimed rather than
   adopted twice, and only if it really stands at that elevator and no other key
   already owns it.
4. **Locking.** The adopted lift's `locked` flag is set, so the host refuses
   requests coming straight off a client. `powered` is left exactly as the host
   set it: an operator who cut the power did it on purpose. A lift that could not
   be locked is a warning line rather than a rollback — an unlocked lift still
   answers this resource, it just also answers a client directly, and running
   that way unnoticed is the real failure.
5. **Binding.** The client is told the Open77 id on `opx77_elevators:bound`, and
   `use` sends requests only for an elevator it has an id for; without one it
   answers `not_adopted`.
6. **Release.** When the host removes a lift, `onElevatorRemoved` drops the
   adoption and everyone who was handed its id is told on
   `opx77_elevators:released`, so the next scan re-reports the lift rather than
   sending requests for an id nobody owns.

!!! warning "The self-healing adoption"

    A sighting's hash cannot be verified: `Open77.elevators.all()` lists only
    lifts that are **already** adopted, so a lift nobody has taken yet is
    invisible to the server VM. One packet with a well-formed hash therefore
    binds a key to a lift that may not exist, and every later sighting
    short-circuits on it — the real cabin could then never be adopted, because
    the host refuses a second adoption of the same lift in the same bucket.

    It cannot be prevented, so it is made to heal: a sweep every minute releases
    any adoption that has **never moved a cabin** within ten minutes, with a
    warning line, and the next honest sighting takes the slot.

Sightings are rate-limited to twelve per second per player: a client streaming
through a lobby can legitimately see several lifts at once, and no client needs
more.

### The diagnostic command

`COMMAND`, shipped as `opx77.elevators.where`, registers a **restricted**
command — the host resolves `command.opx77.elevators.where` against the caller's
ACL before this resource runs at all. See
the host's ACL. Set it to `false` to
register none.

```text
opx77.elevators.where [key]
```

It prints, sorted, and echoes each line back to the calling player:

- every configuration problem `Access.problems()` can see;
- one line per elevator — key, label, position, floors offered against
  `FLOOR_COUNT`, the Open77 id, and, when adopted, the live `phase`,
  `activeFloor` and `flags`;
- the effective `DENIED_FLOORS` and `MEMBERSHIP`.

An optional argument filters to a single key. The output is world positions and
adoption state, which is operator information — hence the ACL.

## Configuration

Every key of `OPX_ELEVATORS_CONFIG`, with its shipped default. The file is read
by both halves and shipped to every client: **nothing in it is secret**.

| Key | Default | Meaning |
|---|---|---|
| `DENIED_FLOORS` | `"shown"` | a floor the player cannot reach is greyed with its `REASON` (`"shown"`) or absent (`"hidden"`) |
| `MEMBERSHIP` | `"primary"` | `"primary"` reads the job being worked; `"any"` also reads the whole membership map |
| `JOB_MAX_AGE_MS` | `60000` | past this age every gated floor closes; public floors never do |
| `POLL_MS` | `15000` | how often the client re-reads the character from `opx77_core` |
| `SCAN_MS` | `2000` | how often the client looks for native lifts; a sighting is stale after two scans |
| `EVENT` | `"opx77:elevators"` | the client event raised after every decision |
| `MATCH_RADIUS` | `6.0` | how close a native lift must be to a declared position to be it, in metres |
| `USE_RADIUS` | `4.0` | how close the player must be to use the panel, in metres; re-derived on the server |
| `SCAN_RADIUS` | `40.0` | how far a client's sighting report is believed, in metres; re-derived on the server |
| `TRAVEL_MS` | `8000` | how long the cabin takes to travel |
| `REQUEST_WINDOW_MS` | `10000` | the rate-limit window, per player |
| `REQUESTS_PER_WINDOW` | `6` | floor requests one player may make in that window |
| `COMMAND` | `"opx77.elevators.where"` | the ACL-gated diagnostic command, or `false` for none |
| `ELEVATORS` | four placeholder entries | the elevators themselves, keyed by durable name |

!!! note "Radii are checked twice"

    `USE_RADIUS` and `SCAN_RADIUS` are each applied on the client, where they
    decide what the player sees, and again on the server, where they decide what
    the player gets. Widening either widens both.

## Permissions

```lua
permissions {
  "network.events",
  "world.elevators", -- adopt a native lift, lock it, and move the cabin
  "elevators.read",
}
```

| Permission | For |
|---|---|
| `network.events` | the net events between the two halves: `sighted` and `request` upward, `bound`, `answer` and `released` downward |
| `world.elevators` | server-only. `adopt`, `get`, `all`, `setFlags` for the lock, and `goTo` to move the cabin. The platform grants no client resource native movement, markers, deadlines or canonical arrivals |
| `elevators.read` | the client's streamed snapshots — `Open77.elevators.nearby(radius)`, which is how a lift is sighted at all |

!!! tip "The permission it deliberately does not ask for"

    The platform also defines `elevators.request`, the client's own bounded
    button and call intentions. This resource does not request it, because no
    press ever goes that way: every request travels to this resource's server
    half, which is the only holder of `world.elevators` in the set and the only
    thing the locked cabin will answer.

!!! warning "Nothing is scanned without the native API"

    On a client that has not loaded the world, or one whose game build predates
    the elevator API, `Open77.elevators` is absent. Both halves say so once, as
    an error line, and then do nothing — which beats a stack trace per scan.

## See also

- [`opx77_core`](opx77_core.md) — where the job actually lives, and where an
  unforgeable decision belongs.
- [`opx77_menu`](opx77_menu.md) — the surface the floor list is drawn on.
