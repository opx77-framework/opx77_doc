---
title: Types
description: Every class and alias declared by opx77_core — PlayerData, Player, PlayerJob, Result, Session and the rest — with each field, its meaning, and the places where the shipped type annotations have drifted away from the code.
---

# Types

These are the shapes the OPX//77 core passes around. They are declared in
`opx77_core/types.lua`, a file that opens with `---@meta` and is **never loaded
at runtime**: it exists so that the Lua language server can complete and
type-check a plug-in written against the core. Nothing in it is enforced. A
table that is missing a field will not be rejected; it will simply be wrong
later, somewhere else.

!!! warning "`types.lua` has drifted from the code"

    Three declarations no longer describe what the core does, and one field the
    core sets is not declared at all. Every drift is called out on the type it
    belongs to, and **this page documents the code, not the annotation**. If the
    two disagree, the code wins — and the annotation is a bug worth fixing.

Types are grouped below the way the core groups them: the aliases first, then
results, then a character, then jobs and gangs, then the entry machinery, then
the infrastructure shapes.

## Aliases {#aliases}

### Source {#source}

A player id: which connection slot somebody is on right now.

```lua
---@alias Source integer
```

**Recycled.** A slot is reissued the moment its holder leaves, so a `Source`
held across a `Wait` may name a different person by the time it is used. Every
core function that resolves one re-checks the account behind it — see
[Identity](../../concepts/identity.md#ensure-session) for why that check cannot
be skipped.

### UserId {#userid}

The durable account id, a GUID signed by the OPEN//77 Master server.

```lua
---@alias UserId string
```

This is the one identifier that survives a reconnect, a name change and a new
machine. It is what `opx77_accounts` is keyed on, and what
`OPX.Config.SERVER.CHARACTERS.SLOTS_BY_USER` is keyed on.

### CitizenId {#citizenid}

One character's durable id, in grouped form: `"H7K-M4X3"`.

```lua
---@alias CitizenId string
```

Six payload symbols and one check symbol drawn from a 23-symbol alphabet with no
ambiguous glyph, so a player reading one aloud cannot produce a valid id
belonging to somebody else. It is also the `character_key`
`open77_appearance` stores an appearance under — one identity, not two. See
[Identity](../../concepts/identity.md#citizen-id).

### MoneyType {#moneytype}

The name of one currency, and a key of `OPX.Config.SHARED.MONEY.TYPES`.

```lua
---@alias MoneyType string
```

Shipped: `"EDDIES"` and `"BANK"`. An operator may add more, and
[`OPX.IsMoneyType`](server-api.md#ismoneytype) resolves against the config
rather than against a hard-coded list, so a type added there is accepted
everywhere. A money type name becomes a key in the stored `money` JSON column:
adding one is free, and renaming one orphans every balance already held under
the old name.

### GroupType {#grouptype}

Which of the two membership tables an operation is about.

```lua
---@alias GroupType "job"|"gang"
```

### Origin {#origin}

A character's lifepath, chosen at creation and never changed afterwards.

```lua
---@alias Origin "nomad"|"streetkid"|"corpo"
```

Validated against `OPX.Origins` at creation, so the alias and
[`data/origins.lua`](data.md) must agree.

### Gender {#gender}

The body family `open77_appearance` understands.

```lua
---@alias Gender "female"|"male"
```

Two values, and not a claim about anything else: it is the value that resource's
`CHECK` constraint accepts, which is why the core validates against exactly this
set at creation.

## Results {#results}

### Result {#result}

Success or failure as a value, so `nil` never has to mean both "it failed" and
"there was nothing there".

```lua
---@alias Result LibOk|LibErr
```

Every core function whose failure a caller must be able to distinguish returns
one of these. Branch on `.ok` first, always:

```lua
local outcome = OPX.SetJob(source, "ncpd", 2)
if not outcome.ok then
  OPX.Refuse(source, outcome.error)
  return
end
local job = outcome.value
```

A `Result` never unwinds the stack. There is nothing to `pcall`.

The money mutators are the deliberate exception: they return
`boolean, string?` rather than a `Result`, because a caller almost always wants
`if not ok then` and nothing else. See
[the money section](server-api.md#money) for the codes.

### LibOk {#libok}

A success.

**Fields**

- ok: `true`
- value: `any`
    - May be `nil`. An empty answer is still a success — `Result.ok(nil)` means
      "the operation worked and there is nothing to hand back", not "it failed".

### LibErr {#liberr}

A failure.

**Fields**

- ok: `false`
- error: `string`
    - The stable code. It is what a caller branches on, and wherever the failure
      is shown to a player it doubles as a locale key: `OPX.Refuse(source,
      outcome.error)` works because `locales/en.lua` carries an entry for each
      one.
- detail: `string|nil`
    - For logs and staff only. It can carry a raw database exception, so never
      put it on a player's screen.

## A character {#character}

### Player {#player}

What a caller holds while a character is loaded: the data, the methods that
mutate it, and whether it is in the world.

**Fields**

- PlayerData: [`PlayerData`](#playerdata)
- Functions: [`PlayerFunctions`](#playerfunctions)
- Offline: `boolean`
    - `true` for the temporary Player the group functions build around a
      character who is not in the world. An offline Player has the same
      `Functions`, but sends nothing to a client, places nobody, and is refused
      by every money mutator with `money.offline`.

!!! warning "`types.lua` does not declare `Revision` or `MaySample`"

    [`OPX.CreatePlayer`](server-api.md#createplayer) sets two more fields on
    every Player, and they are deliberately *not* on `PlayerData`, which keeps
    them out of the client payload and out of every database column:

    - **`Revision`** (`integer`) — the autosave's dirty counter. Bumped by
      `Functions.UpdatePlayerData` and never reset. A plug-in that assigns into
      `PlayerData` directly instead of going through a mutator makes a change
      this counter cannot see, and the autosave will not write it.
    - **`MaySample`** (`boolean`) — false until the world agrees with the stored
      row. Only [`OPX.PlaceCharacter`](server-api.md#placecharacter) ever sets
      it true. While it is false the position sampler will not touch the stored
      position, which is what stops a failed placement overwriting the very
      coordinates it was trying to restore.

    Neither is declared in `types.lua`. Both are real, and both are read by the
    core every second.

See [Player](player.md) for the whole object in use.

### PlayerData {#playerdata}

Everything the core knows about one character.

!!! danger "The client mirrors this whole table"

    Every field below is sent verbatim to the client that owns the character, on
    login and on every change. Nothing secret may be put in it — not a staff
    flag another resource trusts, not an internal balance, not an admin note.
    A plug-in that needs private per-character state should key its own table on
    the [`CitizenId`](#citizenid) instead.

**Fields**

- source: [`Source`](#source)`|nil`
    - `nil` for an offline Player. Never key persistent state on it.
- userId: [`UserId`](#userid)
- citizenId: [`CitizenId`](#citizenid)
- cid: `integer`
    - The slot number within the account, 1-based. A slot number, not an
      identity: deleting character 2 of 3 leaves the third as `cid` 3, and the
      freed 2 is handed to the next character created.
- name: `string`
    - The account display name as at the last login. It is the *account's* name,
      not the character's — `charInfo` holds the character's.
- charInfo: [`CharInfo`](#charinfo)
- money: `table<`[`MoneyType`](#moneytype)`, integer>`
    - Whole units only. A fractional balance round-tripped through a JSON column
      drifts, so every mutator rounds before it writes. Read it, never assign
      into it: a direct write is invisible to the hooks, the audit log, the
      client and the dirty counter.
- job: [`PlayerJob`](#playerjob)
    - The **primary** job — the one that pays, and the one `HasJob` answers
      about.
- gang: [`PlayerGang`](#playergang)
- jobs: `table<string, integer>`
    - Every job membership, as `name -> grade`. Mirrored from
      `opx77_player_groups`, which is the authority.
- gangs: `table<string, integer>`
    - Every gang membership, as `name -> grade`.
- position: [`Position`](#position)`|nil`
    - `nil` until the character has been somewhere. A `nil` here means "we have
      never known", which is not the same as "at the origin", and the core keeps
      the two apart deliberately.
- metadata: [`PlayerMetadata`](#playermetadata)
- lastLoggedOut: `string|nil`
    - A database timestamp, stamped by the save that ran with `loggedOut` true.
      Shown on the character-selection screen.
- reportedHeading: `number|nil`
    - The client's own report of which way it is facing, and the one field of a
      position the core takes from the client at all. A hint, never proof: x, y
      and z are always re-derived server-side from
      `Open77.players.position`.

### CharInfo {#charinfo}

Who the character is, as opposed to what they have.

**Fields**

- firstName: `string`
    - 2–32 characters by default, validated against
      [`OPX.ValidateName`](server-api.md#validatename). The pattern accepts
      accented Latin, Greek, Cyrillic and CJK; it refuses emoji.
- lastName: `string`
- birthDate: `string`
    - `"YYYY-MM-DD"`. Shape-checked and never parsed — the server sandbox
      removes `os`, so there is no clock to check it against. It is flavour,
      not a fact, and a character claiming to be four hundred years old will be
      accepted.
- origin: [`Origin`](#origin)
- gender: [`Gender`](#gender)
- phone: `string`
    - Drawn at creation from the template `111-111-1111`. Drawn with
      `math.random`, so it is not unguessable and nothing may treat it as a
      secret.

### PlayerMetadata {#playermetadata}

Free-form per-character state. A plug-in adds its own keys and they survive
every save.

**Fields**

- health: `number`
    - 0–100. Restored on the respawn transaction during placement, scaled into
      the 0.15–1.0 the platform's `respawn` takes.
- armor: `number`
    - 0–100. Applied with `Open77.players.setArmor` *after* the respawn has
      settled, because armour is not a respawn option and the body is replaced
      by the transaction.
- hunger: `number`
    - 0–100. Decayed by `server/needs.lua` every `NEEDS.TICK_SECONDS`, by
      `NEEDS.hunger.PER_TICK` a tick. At zero it costs
      `NEEDS.DAMAGE_AT_ZERO` health per tick.
- thirst: `number`
    - 0–100, decayed the same way and faster, as in every survival system.
- stamina: `number`
    - Carried and saved, never read by the core. An agreed name, for a plug-in
      that wants one.
- streetCred: `number`
    - Carried and saved, never read by the core.
- isDead: `boolean`
- inLastStand: `boolean`
- `[string]`: `any`
    - Anything else a plug-in writes through
      [`Functions.SetMetaData`](player.md#setmetadata). It is stored as one JSON
      column, so a key added by a plug-in survives a core upgrade and costs
      nothing.

!!! warning "Two drifts live in this type"

    `types.lua` declares **`ram`** — "carried, never read by the core". Nothing
    in the core writes it, it is not in
    `OPX.Config.SERVER.PLAYER.STARTING_METADATA`, and no character will have it
    unless a plug-in puts it there. Reading `metadata.ram` on a stock install
    yields `nil`.

    `types.lua` also declares `thirst` as "the one need Night City justifies —
    there is no hunger". **There is hunger.** It ships in
    `STARTING_METADATA`, `OPX.Config.SERVER.NEEDS.hunger.PER_TICK` is `1.0`,
    and `server/needs.lua` decays it on the same tick as thirst. The annotation
    predates the needs loop.

### Position {#position}

Where a character is, and in which routing bucket.

**Fields**

- x: `number`
- y: `number`
- z: `number`
- heading: `number`
    - The one client-supplied field, taken from
      [`PlayerData.reportedHeading`](#playerdata) and falling back to the
      previously stored heading, then to `0.0`.
- bucket: `integer`
    - The routing bucket, from the platform's own position snapshot.

`x`, `y` and `z` always come from `Open77.players.position` — the server's view,
never the client's claim.

### PlayerFunctions {#playerfunctions}

The methods bound to one Player. Each is the module-level `OPX.*` mutator with
the player already supplied, so a rule added to one is a rule both obey.

**Fields**

- UpdatePlayerData: `fun()`
- SetPlayerData: `fun(key: string, value: any)`
- SetMetaData: `fun(key: string, value: any)`
- GetMetaData: `fun(key?: string): any`
- SetCharInfo: `fun(key: string, value: any)`
- AddMoney: `fun(moneyType: MoneyType, amount: number, reason?: string): boolean, string?`
- RemoveMoney: `fun(moneyType: MoneyType, amount: number, reason?: string): boolean, string?`
- SetMoney: `fun(moneyType: MoneyType, amount: number, reason?: string): boolean, string?`
- GetMoney: `fun(moneyType?: MoneyType): integer|table`
- SetJob: `fun(name: string, grade: integer): Result`
- SetGang: `fun(name: string, grade: integer): Result`
- SetJobDuty: `fun(onDuty: boolean): Result`
- Save: `fun(): Result`
- Logout: `fun()`

Each one is documented, with its errors and whether it yields, in
[Player](player.md#functions).

## Jobs and gangs {#groups}

### PlayerJob {#playerjob}

One character's primary job, flattened: the definition and the grade resolved
into a single table, so nothing downstream has to look a grade up again.

**Fields**

- name: `string`
    - The key in `OPX.Jobs`. This is what a check compares.
- label: `string`
    - The human name, for display. Never compare against it.
- type: `string|nil`
    - The job's category, copied from the definition. Optional and free-form —
      `"leo"` for police-shaped jobs is the convention.
- payment: `integer`
    - What this grade is paid per paycheck cycle, into `BANK`.
- onDuty: `boolean`
    - Whether the character is clocked in **right now**. Set from the
      definition's `defaultDuty` when the job is assigned, then moved only by
      [`OPX.SetJobDuty`](server-api.md#setjobduty).
- isBoss: `boolean`
    - From the grade, not the job.
- bankAuth: `boolean`
    - From the grade. The core spends neither of these; they are agreed names a
      plug-in or a satellite gates on.
- grade: `{ name: string, level: integer }`
    - `level` is the number stored in `opx77_player_groups`; `name` is the
      grade's label.

Built by [`OPX.ResolveJob`](server-api.md#resolvejob). A character whose stored
job no longer exists in `data/jobs.lua` falls back to
`OPX.Config.SERVER.PLAYER.DEFAULT_JOB` at load rather than failing to load — a
character refused because a job was renamed is, in effect, a deleted character.

### PlayerGang {#playergang}

The same shape for a gang, minus the two fields only a job has.

**Fields**

- name: `string`
- label: `string`
- isBoss: `boolean`
- bankAuth: `boolean`
- grade: `{ name: string, level: integer }`

A gang has no `payment` and no `onDuty`: gangs are not paid and there is no
shift to clock into. The shipped default gang is `"none"`, which every character
holds until they are put in a real one.

### JobDefinition {#jobdefinition}

One entry of `OPX.Jobs`, as written in [`data/jobs.lua`](data.md).

**Fields**

- label: `string`
- type: `string|nil`
- defaultDuty: `boolean`
    - `true` for a job with no shift to clock into. A job with `defaultDuty`
      true is refused by [`OPX.SetJobDuty`](server-api.md#setjobduty) with
      `job.noDuty`: clocking out of "unemployed" is a state nothing reasons
      about.
- offDutyPay: `boolean`
    - Pays whether or not its holder is clocked in. This is the job's own
      override and the server-wide `PAYCHECK_REQUIRES_DUTY` tunable does not
      overrule it.
- grades: `table<integer, `[`JobGrade`](#jobgrade)`>`
    - Contiguous from `0`. [`OPX.TopGrade`](server-api.md#topgrade) walks
      upwards from 0 and stops at the first hole, so a gap silently truncates
      the job.

### JobGrade {#jobgrade}

**Fields**

- name: `string`
- payment: `integer`
- isBoss: `boolean|nil`
- bankAuth: `boolean|nil`

### GangDefinition {#gangdefinition}

One entry of `OPX.Gangs`.

**Fields**

- label: `string`
- grades: `table<integer, `[`GangGrade`](#ganggrade)`>`

### GangGrade {#ganggrade}

**Fields**

- name: `string`
- isBoss: `boolean|nil`
- bankAuth: `boolean|nil`

## Entry {#entry}

### Session {#session}

A connected machine, not a loaded character. Somebody sitting in the character
selection screen has one of these and no [`Player`](#player).

**Fields**

- source: [`Source`](#source)
- userId: [`UserId`](#userid)
- displayName: `string`
    - From `GetPlayerName` at the moment the session was created. `""` when the
      host would not answer.
- connectedAt: `integer`
    - `OPX.Now()` at creation — process-monotonic milliseconds, not a wall
      clock. The sandbox removes `os`, so there is no wall clock to use.
- gateSession: `any|nil`
    - The opaque handle `Open77.ready.hold` returned, held for as long as the
      readiness gate is held for this player. Compared rather than
      interpreted: releasing by a recycled `Source` alone could clear somebody
      else's hold.
- citizenId: [`CitizenId`](#citizenid)`|nil`
    - Set once a character is loaded, and cleared on logout. This is what the
      selection watchdog polls to decide whether the player ever chose.
- charactersSent: `boolean`
- released: `boolean|nil`
    - Set true once the gate has been released for this player, so the watchdog
      exits instead of releasing a second time.

!!! warning "`types.lua` does not declare `heldAt`"

    `OPX.Lifecycle.hold` also stamps `session.heldAt` with `OPX.Now()`. It is
    real and it is not in the annotation.

Sessions live in `OPX.Sessions`, and every read of one goes through
[`OPX.EnsureSession`](server-api.md#ensuresession), which is what makes the
recycled-slot check unskippable. See
[Identity](../../concepts/identity.md#session-vs-player).

### CharacterSummary {#charactersummary}

The trimmed shape sent to a client for the selection screen.

**Fields**

- citizenId: [`CitizenId`](#citizenid)
- cid: `integer`
- firstName: `string`
- lastName: `string`
- origin: [`Origin`](#origin)
- gender: [`Gender`](#gender)
- job: `string|nil`
    - The job's **label**, not its name.
- gang: `string|nil`
    - The gang's label, and `nil` for the default gang `"none"` — a character in
      no gang shows no gang rather than showing "None".
- lastLoggedOut: `string|nil`

Money, metadata and the stored position are deliberately absent. They are
nobody's business until a character is loaded, the account owner's included:
the selection screen is reachable before any ownership decision has been made.

## Infrastructure {#infrastructure}

### HookPayload {#hookpayload}

What a hook function is handed. Which fields are populated depends on the hook
point.

**Fields**

- player: [`Player`](#player)
    - Always present.
- moneyType: [`MoneyType`](#moneytype)`|nil`
    - Present on the three `money:*` points, absent on `paycheck:before`.
      Already validated when the hook runs, so it is always a real type.
- amount: `number|nil`
    - Already validated, finite and rounded. On `money:beforeAdd` and
      `money:beforeRemove` it is the positive delta with the sign resolved; on
      `money:beforeSet` it is the **resulting balance**, not a delta.
- reason: `string|nil`
    - Whatever the caller passed as its audit reason. Free-form, and absent on
      `paycheck:before`.

See [Hooks](hooks.md) for the points, the ordering and the veto.

### Migration {#migration}

One entry of `OPX.Schema`.

**Fields**

- name: `string`
    - The key the runner records in `opx77_migrations`. **Append-only.** Never
      rename or edit one that has shipped: the runner keys on this name and it
      has already run on live databases.
- statements: `string[]`
    - Run in order. The runner stops at the first failure, because a
      half-applied schema is the one state neither rolling forward nor back is
      safe from.

See [Persistence](../../concepts/persistence.md#migrations).

### LogEntry {#logentry}

One structured audit line, as taken by
[`OPX.Logger.log`](server-api.md#loggerlog). Declared in `server/logger.lua`
rather than in `types.lua`.

**Fields**

- event: `string`
    - Stable and greppable: `"money.remove"`, `"character.delete"`. Entries
      whose event begins `money.` or `character.` and whose severity is `info`
      or `debug` are treated as ledger lines and are never collapsed by the
      dedupe window.
- severity: `string|nil`
    - `"debug"`, `"info"`, `"warn"` or `"error"`. Anything else becomes
      `"info"`.
- message: `string|nil`
    - Truncated to 200 characters and stripped of control characters.
- source: [`Source`](#source)`|nil`
- citizenId: [`CitizenId`](#citizenid)`|nil`
- userId: [`UserId`](#userid)`|nil`
- data: `table|nil`
    - JSON-encoded into the line and truncated to 200 characters.

### LogScope {#logscope}

A named logger, as returned by [`OPX.Log.scope`](server-api.md#logscope-fn).

**Fields**

- debug: `fun(...)`
- info: `fun(...)`
- warn: `fun(...)`
- error: `fun(...)`

Every argument is passed through `tostring` and joined with spaces, so a table
prints as its address — encode it yourself if you want to read it.

### Vector3Like {#vector3like}

Any `{ x, y, z }` point.

**Fields**

- x: `number`
- y: `number`
- z: `number|nil`

Vectors are a client concept on this platform, so both runtimes use plain
tables. `z` is optional because
[`OPX.Math.distanceSquared`](server-api.md#distancesquared) treats a missing one
as `0` and a great many comparisons are two-dimensional.

## Where to go next {#next}

- [Player](player.md) — the object these types describe, in use.
- [Server API](server-api.md) — every function that produces or consumes one.
- [Hooks](hooks.md) — where [`HookPayload`](#hookpayload) arrives.
- [Writing a server plugin](../../guides/writing-a-server-plugin.md) — the file
  that holds the code these types annotate.
