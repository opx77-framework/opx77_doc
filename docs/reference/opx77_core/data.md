---
title: Jobs, gangs and origins
description: The twelve jobs, twelve gangs and three origins shipped in opx77_core/data/, printed in full with every grade, label, payment and boss flag, plus the rule that makes renaming one different from changing a setting.
---

# Jobs, gangs and origins

`opx77_core/data/` holds three files — `jobs.lua`, `gangs.lua` and
`origins.lua` — and they are **definitions, not settings.**

## `config/` versus `data/` {#config-versus-data}

!!! danger "A key in `data/` is stored on the character row"
    Changing a value in [`config/`](config.md) changes how the server behaves
    from the next tick. Changing a **key** in `data/` renames something players
    already hold.

    A job's key — `ncpd`, `merc`, `fixer` — is written into the `job` column of
    `opx77_players` and into `opx77_player_groups` for every membership. Rename
    it and every character employed under the old name is orphaned: their row
    still says `ncpd`, nothing in `data/jobs.lua` answers to it, and on their
    next login `server/player.lua` silently falls them back to
    [`PLAYER.DEFAULT_JOB`](config.md#server-player-default-job). The membership
    row is left alone, so they now hold a group they are not employed in.

    **Add freely. Rename never.** The same rule governs
    [`MONEY.TYPES`](config.md#shared-money-types), for the same reason.

Everything *inside* a definition is safe to change. A label, a grade name, a
payment, an `isBoss` flag — those are read fresh on every login and on every
`SetJob`, and moving one moves it for everybody immediately. It is only the
top-level key, and the contiguity of the grade numbers, that a stored row
depends on.

## The three files are `shared_script` {#shared}

All three are loaded on both sides, so `OPX.Jobs`, `OPX.Gangs` and
`OPX.Origins` exist in the core's client VM as well as its server VM. They are
**not** shipped to a client as data a satellite can read directly — a resource
lives in its own Lua state and cannot see the core's globals — so a resource
that wants them asks for them:

| You want | Call |
|---|---|
| Every job, with its grades | [`GetJobs`](exports/client.md) |
| Every gang, with its grades | [`GetGangs`](exports/client.md) |
| Every origin | [`GetOrigins`](exports/client.md) |

!!! warning "`grades` comes back as a 1-based array, not the 0-keyed table"
    The source tables below are keyed from `0`. The exports hand back a 1-based
    array in which every entry carries an explicit `level`, because the
    runtime's value codec documents *"string or integer keys"* and no table
    with a `0` key has ever crossed it in this framework. **Read
    `grade.level`, never the array index.** This applies to `GetJobs` and
    `GetGangs` alike.

Inside `opx77_core` itself — a gameplay file you added to `server/` and listed
in `open77.lua` — reach for `OPX.Jobs` and `OPX.Gangs` directly, or better,
`OPX.GetJob(name)` and `OPX.ResolveJob(name, grade)`. See the [Server
API](server-api.md).

---

## Jobs {#jobs}

`data/jobs.lua`, twelve of them. Twelve keys that must never be renamed, and a
great deal inside them that is yours.

### The shape of a job {#job-shape}

```lua
merc = {
  label = "Mercenary",
  type = "merc",
  defaultDuty = true,
  offDutyPay = false,
  grades = {
    [0] = { name = "Street Merc", payment = 120 },
    [1] = { name = "Solo", payment = 220 },
    [2] = { name = "Edgerunner", payment = 380 },
    [3] = { name = "Legend", payment = 600, isBoss = true },
  },
},
```

**Fields**

- label: `string`
    - Shown to players. Safe to change at any time.
- type?: `string`
    - A free-form category — `leo`, `medical`, `corpo`, `tech` and so on. The
      core stores it, publishes it on
      [`PlayerJob.type`](types.md#playerjob) and never reads it. It exists so
      a gameplay file can ask "is this player any kind of law enforcement"
      without listing four job names.
- defaultDuty: `boolean`
    - `true` for a job with no shift to clock into. A new holder starts on
      duty, and [`SetJobDuty`](server-api.md) **refuses** with `job.noDuty` —
      clocking out of "unemployed" is a state nothing reasons about.
- offDutyPay: `boolean`
    - `true` pays the holder whether or not they are clocked in. This is the
      job's own override and the server-wide
      [`PAYCHECK_REQUIRES_DUTY`](config.md#server-paycheck-requires-duty)
      switch does not overrule it.
- grades: `table<integer, JobGrade>`
    - Keyed from `0` and **contiguous**, because a promotion is `grade + 1` and
      `OPX.TopGrade` finds the ceiling by counting upward from zero until a key
      is missing. A gap silently truncates the job.

Each grade is a [`JobGrade`](types.md#jobgrade):

- name: `string` — the rank shown to players.
- payment: `integer` — eddies per paycheck, credited to `BANK`.
- isBoss?: `boolean` — published on `PlayerData.job.isBoss`.
- bankAuth?: `boolean` — published on `PlayerData.job.bankAuth`.

!!! warning "`isBoss` and `bankAuth` are hints, not permissions"
    The core sets both and reads neither. Nothing in `opx77_core` gates
    anything on either flag. **What a boss may do is entirely up to the
    gameplay file that asks**, and the flag reaches a client, so a client-side
    check on it proves nothing. Gate anything that money or a body count
    depends on server-side, in a file inside `opx77_core`.

### The twelve shipped jobs {#shipped-jobs}

`payment` is per paycheck, at the interval set by
[`PAYCHECK_MINUTES`](config.md#server-paycheck-minutes) (10 minutes shipped),
paid into `BANK`.

#### unemployed {#job-unemployed}

`label` **Unemployed** · no `type` · `defaultDuty` **true** · `offDutyPay`
**true**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Freelancer | 25 | | |

The shipped value of
[`PLAYER.DEFAULT_JOB`](config.md#server-player-default-job). It is the fallback
every character lands on, so it must exist and it must have a grade `0`. It has
nothing to clock into, which is why its tiny paycheck needs no shift.

#### merc {#job-merc}

`label` **Mercenary** · `type` `merc` · `defaultDuty` **true** · `offDutyPay`
**false**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Street Merc | 120 | | |
| 1 | Solo | 220 | | |
| 2 | Edgerunner | 380 | | |
| 3 | Legend | 600 | ✓ | |

#### fixer {#job-fixer}

`label` **Fixer** · `type` `fixer` · `defaultDuty` **true** · `offDutyPay`
**false**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Runner | 100 | | |
| 1 | Broker | 260 | | |
| 2 | Fixer | 500 | ✓ | ✓ |

#### ripperdoc {#job-ripperdoc}

`label` **Ripperdoc** · `type` `medical` · `defaultDuty` **false** ·
`offDutyPay` **false**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Apprentice | 140 | | |
| 1 | Ripperdoc | 300 | | |
| 2 | Chrome Surgeon | 520 | ✓ | ✓ |

#### netrunner {#job-netrunner}

`label` **Netrunner** · `type` `tech` · `defaultDuty` **false** · `offDutyPay`
**false**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Script Kiddie | 110 | | |
| 1 | Netrunner | 280 | | |
| 2 | Blackwall Diver | 540 | ✓ | |

#### trauma {#job-trauma}

`label` **Trauma Team** · `type` `medical` · `defaultDuty` **false** ·
`offDutyPay` **true**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Paramedic | 180 | | |
| 1 | Trauma Specialist | 320 | | |
| 2 | Team Lead | 480 | | |
| 3 | Regional Director | 700 | ✓ | ✓ |

#### ncpd {#job-ncpd}

`label` **NCPD** · `type` `leo` · `defaultDuty` **false** · `offDutyPay`
**true**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Cadet | 150 | | |
| 1 | Officer | 260 | | |
| 2 | Detective | 400 | | |
| 3 | Captain | 620 | ✓ | ✓ |

#### maxtac {#job-maxtac}

`label` **MaxTac** · `type` `leo` · `defaultDuty` **false** · `offDutyPay`
**true**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Operator | 460 | | |
| 1 | Squad Lead | 720 | ✓ | |

The shortest ladder and the steepest: two grades, and grade 0 already outpays
most jobs' bosses.

#### arasaka {#job-arasaka}

`label` **Arasaka** · `type` `corpo` · `defaultDuty` **false** · `offDutyPay`
**true**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Junior Analyst | 200 | | |
| 1 | Field Agent | 380 | | |
| 2 | Counterintel | 600 | | |
| 3 | Executive | 950 | ✓ | ✓ |

#### militech {#job-militech}

`label` **Militech** · `type` `corpo` · `defaultDuty` **false** · `offDutyPay`
**true**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Contractor | 200 | | |
| 1 | Operative | 380 | | |
| 2 | Handler | 600 | | |
| 3 | Executive | 950 | ✓ | ✓ |

Deliberately identical to `arasaka` on every number. The two corporations are
mirror ladders; only the labels and the fiction differ.

#### cabbie {#job-cabbie}

`label` **Delamain Driver** · `type` `transport` · `defaultDuty` **true** ·
`offDutyPay` **false**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Driver | 90 | | |
| 1 | Dispatcher | 180 | ✓ | |

Note that `label` and key differ here: the key is `cabbie`, the label is
"Delamain Driver". The key is what is stored; the label is what a player reads.

#### bartender {#job-bartender}

`label` **Bartender** · `type` `service` · `defaultDuty` **true** ·
`offDutyPay` **false**

| Grade | Name | Payment | Boss | Bank |
|---:|---|---:|:-:|:-:|
| 0 | Barback | 70 | | |
| 1 | Bartender | 140 | | |
| 2 | Owner | 260 | ✓ | ✓ |

The floor of the shipped economy at 70 per paycheck, against MaxTac's 460.

### `defaultDuty` at a glance {#duty-summary}

Five jobs ship with `defaultDuty = true` and therefore **cannot be clocked out
of** — `SetJobDuty` refuses them with `job.noDuty`:

`unemployed`, `merc`, `fixer`, `cabbie`, `bartender`.

The other seven start off duty and must clock in. Of those, five ship with
`offDutyPay = true` — `trauma`, `ncpd`, `maxtac`, `arasaka`, `militech` — so
they are paid regardless of
[`PAYCHECK_REQUIRES_DUTY`](config.md#server-paycheck-requires-duty), while
`ripperdoc` and `netrunner` are paid only while clocked in.

---

## Gangs {#gangs}

`data/gangs.lua`, twelve of them. Same rules as jobs, minus the employment: a
gang is not an employer, so a gang grade carries **no `payment` and no duty**.

### The shape of a gang {#gang-shape}

```lua
maelstrom = {
  label = "Maelstrom",
  grades = {
    [0] = { name = "Chromehead" },
    [1] = { name = "Enforcer" },
    [2] = { name = "Cyberpsycho" },
    [3] = { name = "Warlord", isBoss = true, bankAuth = true },
  },
},
```

**Fields**

- label: `string`
- grades: `table<integer, GangGrade>` — keyed from `0`, contiguous, exactly as
  a job's are.

Each grade is a [`GangGrade`](types.md#ganggrade): a `name`, and optionally
`isBoss` and `bankAuth`.

!!! warning "`isBoss` and `bankAuth` are hints, not permissions"
    As with jobs, the core sets both and reads neither. Nothing in
    `opx77_core` gates anything on either flag, and both reach the client, so a
    client-side check on one proves nothing. Gate anything that matters
    server-side.

There is no gang equivalent of `defaultDuty`, `offDutyPay` or `type`. A gang
member is never paid a gang paycheck; the paycheck loop reads
`PlayerData.job` only.

### The twelve shipped gangs {#shipped-gangs}

#### none {#gang-none}

**No affiliation** — grade 0 `Civilian`.

The shipped value of
[`PLAYER.DEFAULT_GANG`](config.md#server-player-default-gang). It is the
absence of a gang, kept as a real entry so no call site has to handle `nil`.
Every character has a gang; most of them have this one.

#### The eleven real gangs {#gang-roster}

| Key | Label | 0 | 1 | 2 | 3 |
|---|---|---|---|---|---|
| `maelstrom` | Maelstrom | Chromehead | Enforcer | Cyberpsycho | **Warlord** |
| `valentinos` | Valentinos | Novato | Soldado | Teniente | **Jefe** |
| `tygerclaws` | Tyger Claws | Kouhai | Senpai | Kyodai | **Oyabun** |
| `sixthstreet` | 6th Street | Recruit | Veteran | Sergeant | **Colonel** |
| `voodooboys` | Voodoo Boys | Initiate | Runner | Houngan | **Mambo** |
| `animals` | Animals | Cub | Bruiser | Beast | **Alpha** |
| `barghest` | Barghest | Conscript | Trooper | Zealot | **Commander** |
| `scavengers` | Scavengers | Scav | Harvester | **Ringleader** | — |
| `moxes` | The Mox | Regular | Bouncer | **Matron** | — |
| `wraiths` | Wraiths | Raider | Outrider | **Chief** | — |
| `aldecaldos` | Aldecaldos | Kin | Rider | **Elder** | — |

**Bold** is the top grade, and every top grade carries `isBoss = true`. All of
them also carry `bankAuth = true` **except `scavengers`**, whose Ringleader is
`isBoss` alone — the one asymmetry in the file, and it is deliberate.

Seven gangs have four grades; four have three. `none` has one.

---

## Origins {#origins}

`data/origins.lua`, three lifepaths, offered at character creation.

```lua
OPX.Origins = {
  nomad = {
    label = "Nomad",
    description = "Raised in the Badlands, loyal to a clan and to nobody in the city.",
  },
  streetkid = {
    label = "Streetkid",
    description = "Born in Night City. Knows every alley and who owns it.",
  },
  corpo = {
    label = "Corpo",
    description = "Grew up inside a tower. Knows what the city looks like from above.",
  },
}
```

**Fields**

- label: `string`
- description: `string` — one sentence, for the creation screen.

The key is validated against this table at creation — `OPX.CreateCharacter`
refuses an unknown one with `character.badOrigin`, on the client to spare a
round trip and again on the server, which is the check that decides — then
stored on [`PlayerData.charInfo.origin`](types.md#charinfo) and **never read
again by the core.** It is flavour a gameplay file may act on, not a mechanic.

The three keys are also the [`Origin`](types.md) type alias, so adding a fourth
means touching `types.lua` if you want your editor to stop complaining.

Origins are flat and string-keyed, which is why
[`GetOrigins`](exports/client.md) returns the table as it stands rather than
reshaping it the way `GetJobs` and `GetGangs` must.

---

## Editing `data/` on a live server {#editing}

A restart of `opx77_core` re-reads all three files. What happens to characters
already stored depends on what you changed:

| Change | Effect on stored characters |
|---|---|
| A label, a grade name, a description | Applied on the next login and on the next `SetJob`. Nothing is orphaned. |
| A payment | Applied to the next paycheck for anyone who logs in after the restart. |
| Adding a grade at the top | Nothing breaks; existing members keep their level. |
| Adding a job, gang or origin | Nothing breaks. |
| **Removing a grade in the middle** | The job is silently truncated at the gap — `OPX.TopGrade` counts up from `0` and stops. Anybody above the gap fails to resolve and falls back. |
| **Removing a job or gang** | Every holder falls back to [`DEFAULT_JOB`](config.md#server-player-default-job) or [`DEFAULT_GANG`](config.md#server-player-default-gang) on their next login. Their membership row in `opx77_player_groups` is left alone, mid-edit or not. |
| **Renaming a key** | The same as removing it, and there is no undo. See the danger callout at the top of this page. |

`PlayerData.job` is rebuilt from `data/jobs.lua` on every login rather than
being read back out of the row, so a payment you change is a payment everyone
gets — you do not have to touch a single character to roll out an economy
change.

## Where to go next {#next}

- [Configuration](config.md) — `PLAYER.DEFAULT_JOB`, `PLAYER.DEFAULT_GANG` and
  `PAYCHECK_MINUTES`, the three settings that read this page's data.
- [Client exports](exports/client.md) — `GetJobs`, `GetGangs` and `GetOrigins`.
- [Server API](server-api.md) — `OPX.SetJob`, `OPX.SetGang`,
  `OPX.SetJobDuty` and the group functions that write these keys onto a
  character.
- [Types](types.md) — `PlayerJob`, `PlayerGang`, `JobDefinition` and
  `GangDefinition`.
