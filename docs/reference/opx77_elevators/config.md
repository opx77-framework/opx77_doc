---
title: opx77_elevators configuration
description: Every key of OPX_ELEVATORS_CONFIG with its shipped default, how to describe an elevator and its floors, and the constants that are not configurable at all.
---

# Configuration

Everything lives in `config.lua`, in one global table, `OPX_ELEVATORS_CONFIG`.
**Every value shown on this page is the shipped default**, exactly as the file
declares it.

!!! danger "Nothing in this file is secret"

    `config.lua` is a `shared_script`: it is loaded by the server half **and
    shipped to every client**. Every job name, every grade, every door's wording
    and every shaft position is on the player's machine, readable in a text
    editor. That is inherent to the design — the gate has to run on the client,
    because the client is the only side that can reach `opx77_core` — and it is
    another reason the job check is a hint. Put nothing here you would not
    publish.

## LOCALE {#locale}

Which catalogue in `locales/` the player-facing text is read from.

```lua
LOCALE = "en",
```

**Type** `string`

Two catalogues ship, `en` and `fr`. An unknown code is accepted rather than
refused — catalogues register after `shared/locale.lua` loads, so the file
cannot know at that moment which codes exist — and every key then falls back to
`en`, and then to the key itself. A value that is not a non-empty string is
ignored, leaving the catalogue at `en`.

Each resource carries its own catalogue, so this is set here as well as in
[`opx77_core`](../opx77_core/config.md). See
[Player-facing text](#locales) for what is translated and what is not.

## DENIED_FLOORS {#denied-floors}

Decides what happens to a floor the player cannot reach: it appears greyed with
its `REASON` beside it, or it does not appear at all.

```lua
DENIED_FLOORS = "shown",
```

**Type** `"shown" | "hidden"`

`"shown"` tells the player a door exists and who it is for, which is usually the
point of a job-gated floor. `"hidden"` tells them nothing — and when it hides
*everything* at an elevator, [`openPanel`](exports.md#openpanel) answers
`no_floors_available` rather than opening an empty list, because "nothing
happened" is a worse answer than a named one.

## MEMBERSHIP {#membership}

Decides what counts as holding a job: only the one being worked, or the whole
membership map.

```lua
MEMBERSHIP = "primary",
```

**Type** `"primary" | "any"`

| Value | What counts as holding a job |
|---|---|
| `"primary"` | only the job being worked — `PlayerData.job` |
| `"any"` | the membership map as well — `PlayerData.jobs`, name to grade |

Under `"any"`, a character who is an NCPD officer but currently working as a
courier still reaches the NCPD floors. `ON_DUTY` is unaffected either way: it is
satisfied only by the primary job, because the membership map holds grades and
not a clock.

## JOB_MAX_AGE_MS {#job-max-age-ms}

How long a reading of the character stays trusted; past this age every gated
floor closes, and every public floor stays open.

```lua
JOB_MAX_AGE_MS = 60000,
```

**Type** `integer` — milliseconds

The client re-reads the character from `opx77_core` every [`POLL_MS`](#poll-ms),
and also on
[`opx77:client:onPlayerLoaded`](events.md#on-player-loaded) and
[`opx77:client:playerDataChanged`](events.md#player-data-changed). Each read
stamps the snapshot with the client clock, and the gate compares against that
stamp on every press.

The staleness rule is what makes a core outage fail closed without failing hard:
a call that never landed says nothing about the character, only about the core,
so the snapshot is left to age out rather than be thrown away on someone else's
restart — and rather than be trusted forever.

## POLL_MS {#poll-ms}

How often the client re-reads the character from `opx77_core`.

```lua
POLL_MS = 15000,
```

**Type** `integer` — milliseconds

Set well below [`JOB_MAX_AGE_MS`](#job-max-age-ms). The shipped pair gives the
core four chances to answer before the gate stops trusting what it last said.

## SCAN_MS {#scan-ms}

How often the client asks the host for native lifts in range.

```lua
SCAN_MS = 2000,
```

**Type** `integer` — milliseconds

A sighting is considered stale after **two** scans: a lift that stopped being
reported is a lift the player walked away from, and that is what makes
[`nearestElevator`](exports.md#nearestelevator) go quiet when the player leaves
the lobby.

## EVENT {#event}

The name of the local client event raised after every decision this resource
makes.

```lua
EVENT = "opx77:elevators",
```

**Type** `string`

The channel is described in full under
[`opx77:elevators`](events.md#opx77-elevators). Rename it only if the shipped
name collides with something else on the player's machine; every listener has to
be renamed with it, and the name is not a trust boundary in either case.

## MATCH_RADIUS {#match-radius}

How close a native lift must be to a declared position, **across the ground**,
for this resource to believe it is that elevator.

```lua
MATCH_RADIUS = 6.0,
```

**Type** `number` — metres

Measured on `X` and `Y` alone: `Z` is validated and then ignored, because the
cabin is wherever it last stopped and a tower's cabin is nowhere near its
shaft's declared `Z`.

Applied on the client, when a scan matches what it sees against `ELEVATORS`, and
again on the server, when it decides whether a reported hash really stands at the
elevator it claims. Widening it widens both, and two shafts closer together than
this become interchangeable — declare an [`ENTITY`](#elevators) instead.

## USE_RADIUS {#use-radius}

How close the player must be to an elevator, **across the ground**, to see its
panel and to press a floor.

```lua
USE_RADIUS = 4.0,
```

**Type** `number` — metres

Checked on the client, where it decides which elevator the player is standing at,
and re-derived on the server against the player's replicated position, where it
decides whether the request is answered at all. A client that skips the first
meets the second, as `too_far`.

Measured against the **declared shaft position**, never the cabin's, and on `X`
and `Y` alone. Two things follow. A cabin parked at the top of the shaft is
thirty metres from the player standing at the ground-floor panel, who is exactly
the person allowed to call it. And **an elevator is callable from every floor of
its own shaft**: a character on the twelfth storey is as close to the panel as
one in the lobby, because the height difference between them was never part of
the sum.

!!! warning "The client's fallback measures something else, and can disagree"

    A client that cannot read its own position — `Open77.character.position()`
    answers nothing at all before the world is up — ranks a lift by the host's
    own distance to the **cabin**, in three dimensions. That is a different
    measurement to a different point, so it can disagree with the server in
    **both** directions: it can offer the panel up to `MATCH_RADIUS` further out
    than the server accepts, because the cabin may sit that far from the
    declared position, and it can withhold it on a floor the cabin is not
    parked on, because the height difference it was never meant to count is now
    in the sum. The server re-derives `USE_RADIUS` across the ground against the
    declared position, and its answer is the one that counts.

## SCAN_RADIUS {#scan-radius}

How far from the player a sighting report is believed.

```lua
SCAN_RADIUS = 40.0,
```

**Type** `number` — metres

Passed to `Open77.elevators.nearby` on the client, and re-derived on the server:
a reporter further than this from the position it claims to see has its sighting
dropped in silence. The host caps the client call at 300 metres.

This is the one radius still measured in **three** dimensions. It is a sanity
check on a report, not a reach test — a client claiming to see a lift it is
nowhere near — so the storey the reporter stands on is part of the question.

## TRAVEL_MS {#travel-ms}

How long the cabin is told to take between floors.

```lua
TRAVEL_MS = 8000,
```

**Type** `integer` — milliseconds

Handed to `Open77.elevators.goTo` as `travelMs`. It is the host that animates the
move; this is the only say this resource has in it.

## REQUEST_WINDOW_MS {#request-window-ms}

The length of the per-player rate-limit window for floor requests.

```lua
REQUEST_WINDOW_MS = 10000,
```

**Type** `integer` — milliseconds

## REQUESTS_PER_WINDOW {#requests-per-window}

How many floor requests one player may make inside that window.

```lua
REQUESTS_PER_WINDOW = 6,
```

**Type** `integer`

!!! warning "A rate-limited request is answered with silence"

    The limit governs the cabin, not the reply: a refused packet would otherwise
    still cost one outbound event echoing whatever the client sent. Nothing is
    sent back, so a caller waiting for a verdict must tolerate never receiving
    one. See [`rate_limited` is silent](errors.md#rate-limited).

## COMMAND {#command}

The name of the ACL-restricted diagnostic command, or `false` to register none.

```lua
COMMAND = "opx77.elevators.where",
```

**Type** `string | false`

The host derives the required ACL permission from whatever name is registered, as
`command.<lowercase name>`, so renaming the command renames the permission with
it. See [Commands](commands.md#where).

## ELEVATORS {#elevators}

The elevators themselves, each under a **durable key** — the name used by every
export, every event and the diagnostic command.

```lua
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
}
```

**Type** `table<ElevatorKey, ElevatorSpec>` — see
[`ElevatorSpec`](types.md#elevatorspec). Four placeholder entries are shipped:
`arasaka_tower`, `ncpd_watson`, `vik_clinic` and `afterlife`.

1. **The key.** A string, unique, stable. `floors("arasaka_tower")`,
   `opx77.elevators.where arasaka_tower` and the `elevator` field of every
   payload all use it. It never changes; the Open77 id does, on every restart.
2. **`LABEL`** — the panel's title, and the elevator's name in the diagnostic
   report.
3. **`X` / `Y` / `Z`** — the **shaft's** position in metres, not the cabin's.
   `X` and `Y` place the shaft and are the only pair a distance is ever measured
   on: to recognise a streamed native lift as this elevator (within
   [`MATCH_RADIUS`](#match-radius)), to decide which elevator the player is
   standing at (within [`USE_RADIUS`](#use-radius)), and by the server as the
   reference point for `too_far`. `Z` is validated, recorded and printed by the
   diagnostic command, and **never compared** — which is what makes an elevator
   callable from every floor of its own shaft. Give it the storey the panel sits
   on; nothing reads it.
4. **`BUCKET`** — the routing bucket, defaulting to `0`. An elevator in a bucket
   is invisible to players outside it. The server adopts into the **elevator's**
   bucket and never the reporter's: adopting into a player's bucket would let the
   first person to walk past a lift fix it to theirs, and someone doing that from
   a private instance would leave everyone else answered `wrong_bucket` for the
   life of the process.
5. **`ENTITY`** — optional. The native `LiftDevice` hash, as a `"0x…"` string of
   sixteen hex digits. REDengine hashes are **opaque**: keep them as strings and
   never pass one through `tonumber`. When declared, it pins *which* lift among
   the ones the coordinates could match; `X` and `Y` must still agree, and `Z`
   decides nothing here either. The shipped entries declare none and match on
   position alone — where two of them are equally close, the smaller key wins, so
   that `pairs` order never decides between two shafts in one lobby.
6. **`FLOOR_COUNT`** — the **native device's** floor count, not `#FLOORS`. It is
   the ceiling every index is checked against, and the config's value wins over
   whatever a client reports; a mismatch is logged once per elevator, not once
   per sighting.
7. **`FLOORS`** — the stops this resource offers, in the order the panel draws
   them. There is no need to list every native floor: a floor absent from this
   list is a floor no panel offers and no request can name.
8. **`JOBS`** — a map of job name to **minimum grade level**. `{ arasaka = 0 }`
   means "any Arasaka grade". Names must exist in
   [`opx77_core`'s `data/jobs.lua`](../opx77_core/data.md); this resource's VM
   cannot verify them, so a typo reads as a floor nobody can take.
9. **`REASON`** — the operator's own wording, shown beside a refused row. Write
   it as a door would be signed, not as an error message.
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

!!! danger "A public floor stays open through every failure"

    A floor with no `JOBS` is allowed with no snapshot, with a stale snapshot and
    with no character. A lobby that stops working while the core restarts is
    worse than anything the gate protects, so ground floors, street level and
    reception should carry no `JOBS` at all.

## Finding real coordinates {#coordinates}

The shipped positions are **placeholders**. The platform's own
`open77_elevators` resource carries a client probe that lists streamed native
`LiftDevice` hashes and exact positions, including unmanaged lifts, from the
client developer console:

```text
resource.emit open77:elevators:nearby 100
```

Take the position for `X`/`Y`/`Z` and, if two shafts sit close enough to be
confused, the hash for `ENTITY`.

!!! warning "Do not leave both resources running"

    That probe belongs to `open77_elevators`, the official package this resource
    replaces. A lift adopted by one is refused to the other — the platform
    rejects a different owner — so whichever starts first owns the cabin, and the
    other's panel answers `not_adopted` forever. `opx77_elevators` warns at boot
    when it finds `open77_elevators` running. Probe with it, then drop one from
    `resources.load` in `server.jsonc`.

## Checking the configuration {#validation}

Everything wrong with `ELEVATORS` that can be seen without a world is reported at
boot, one warning line per problem, and again on demand from
[the diagnostic command](commands.md#where):

- an `X`, `Y` or `Z` that is not a finite number inside 1 000 000 of the origin;
- an elevator with no `FLOORS`, so its panel would be empty;
- a `FLOOR_COUNT` that is not a whole number of at least 1;
- an `INDEX` that is not a whole number of at least 0;
- an `INDEX` outside `FLOOR_COUNT`;
- an `INDEX` declared twice;
- a floor with no `LABEL`;
- a `JOBS` that is not a table of name to minimum grade.

The axes are checked first, and deliberately: every distance below them, and
every `%.2f` in the diagnostic report, raises on an axis that holds a string.

!!! info "A mistyped number is a line, not a boot failure"

    Each value is validated, and it is the **validated** value the check then
    compares. That matters because `FLOOR_COUNT = "12"` — a number in quotes,
    the easiest mistake to make in this file — used to be compared raw, and
    raised inside the diagnostic itself, at boot, rather than producing the line
    that describes it. Every problem here comes out as its own warning line and
    the rest of the report still runs.

It cannot check a job **name**. Those live in `opx77_core`, and this VM cannot
ask it anything — the same constraint that makes the job check a hint.

## Keys that do not exist {#nonexistent-keys}

`types.lua` used to mention two settings that `config.lua` never declared and no
file read. Both references have been removed from the annotations; the keys are
named here because earlier documentation described them, and neither ever did
anything.

| Named as | Reality |
|---|---|
| `PANEL` | Annotated as taking `"menu"` or `"none"`, and cited by the since-removed `panel_disabled` error code. The panel is always attempted and answers `menu_not_running` when `opx77_menu` is not running. |
| `ENFORCEMENT` | Annotated as taking `"server"`. The server always re-derives every clause it can, and there is no mode in which it does less. |

## Player-facing text {#locales}

Everything a player reads that this resource wrote itself lives in `locales/`,
one file per language, keyed `elevators.<thing>`. `en` and `fr` ship.
[`LOCALE`](#locale) picks one.

```lua
-- locales/en.lua
OpxElevators.Locale.register("en", {
  ["elevators.title"]   = "ELEVATORS",
  ["elevators.locked"]  = "Locked",
  ["elevators.refused"] = "That floor is not available.",
  ["elevators.tooFar"]  = "You are too far from the elevator.",
  -- …
})
```

A key missing from the chosen catalogue falls back to `en`, and a key missing
from that reads as the key itself — so a half-translated file degrades to
English rather than to a blank line.
[What the player is shown](errors.md#wording) lists which refusals have wording
of their own.

!!! warning "Three things are never translated"

    A floor's `REASON` and `LABEL` are the **server owner's own words**, written
    in `config.lua`, and are shown exactly as written. The `Open77.log` lines and
    [the diagnostic command](commands.md#where) stay in English, because they are
    read by an operator and quoted in a bug report. And the `error` codes are
    stable identifiers meant for branching, never for showing to a player.

### Adding a language {#adding-a-language}

1. Copy `locales/en.lua` to `locales/<code>.lua`, change the code in the
   `register` call, and translate the values. Every key must be present in every
   file — the fallback covers a missing one, but it covers it in English.
2. Add `shared_script "locales/<code>.lua"` to `open77.lua`, beside the others.
   Order matters: the catalogues are registered immediately after
   `shared/locale.lua` and above every file that renders a string, or `locale()`
   is called against an empty catalogue.
3. Set `LOCALE = "<code>"`.

Each resource carries its own catalogue and its own `LOCALE`; setting it in
`opx77_core` does not set it here.

## Constants that are not configurable {#constants}

Three numbers matter to an operator and are not in `config.lua`. They are
`local` values in the files named.

| Constant | Value | Where | What it does |
|---|---|---|---|
| `SIGHT_RETRY_MS` | `5000` | `client/main.lua` | the shortest gap between two reports of the same unadopted lift |
| `SIGHTS_PER_SECOND` | `12` | `server/main.lua` | sightings one player may send per second; a client streaming through a lobby can legitimately see several lifts at once |
| `UNUSED_MS` | `600000` | `server/main.lua` | how long an adoption that has never moved a cabin is kept before it is released |

!!! warning "Why the unused-adoption sweep exists"

    A sighting's hash cannot be verified. `Open77.elevators.all()` lists only
    lifts that are **already** adopted, so a lift nobody has taken yet is
    invisible to the server VM. One packet with a well-formed hash therefore
    binds a key to a lift that may not exist, and every later sighting
    short-circuits on it — the real cabin could then never be adopted, because
    the host refuses a second adoption of the same lift.

    It cannot be prevented, so it is made to heal: a sweep every minute releases
    any adoption that has never moved a cabin within `UNUSED_MS`, with a warning
    line, and the next honest sighting takes the slot.
