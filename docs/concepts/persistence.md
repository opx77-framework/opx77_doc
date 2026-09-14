---
title: Persistence — the schema, migrations and the shared database
description: How OPX//77 stores characters, groups and vehicles — the opx77_-prefixed schema and why it is prefixed, append-only migrations, named SQL parameters, the await forms that raise instead of returning a reason, and the threat model of a database every resource shares.
---

# Persistence

OPX//77 keeps its durable state in MySQL: accounts, characters, group
memberships and owned vehicles. This page is about the shape of that state and
the rules for writing against it — the rules matter more than usual here,
because on OPEN//77 the database is not yours.

## The database is common ground {#threat-model}

!!! danger
    Every resource holding `database.access` talks to the **same** database,
    with the same credential. There is no per-resource schema, table prefix or
    statement filter, so a resource can read and write another resource's
    tables. `database.access` is a boolean gate, not an allocation: granting it
    to a leaderboard also grants it the ability to rewrite the money column.
    **Never treat the contents of the database as unforgeable by another
    installed resource.**

That is the threat model, and it does not have a mitigation on this platform —
only a discipline:

- **Grant `database.access` only to resources that genuinely persist state.**
  Turning the database on turns it on for every resource that asked, not only
  the one you had in mind.
- **Prefix every table you own.** It is the only namespace there is.
- **Treat a row you did not write as input**, with the same suspicion you give a
  client payload. The core validates on read as well as on write for this
  reason.
- **Do not write into another resource's tables** because you can. A third-party
  resource writing `opx77_characters` directly is writing behind the core's
  back, and the core's next autosave — every `AUTOSAVE_SECONDS`, 300 by
  default — overwrites it from the roster.

The same property read the other way makes the database an **integration
channel**, and the honest one for a third-party server resource that cannot be
put inside the core. That side is covered in
[Integration channels](integration-channels.md#shared-database).

## The schema {#schema}

Every table is prefixed `opx77_`. Four belong to `opx77_core`, one to
`opx77_status`, and one is the runner's own ledger.

| Table | Owner | Primary key | Holds |
|---|---|---|---|
| `opx77_users` | core | `user_id` CHAR(36) | One row per platform account: `display_name`, `created_at`, `last_seen_at`. No password and no email — the platform proved who this is before the session existed. |
| `opx77_characters` | core | `citizen_id` VARCHAR(16) | One row per character: `user_id`, `cid`, `name`, the JSON columns `char_info`, `money`, `job`, `gang`, `position`, `metadata` and `appearance`, plus `last_logged_out`, `created_at`, `updated_at` and `deleted_at`. |
| `opx77_character_groups` | core | `(citizen_id, group_type, group_name)` | Every job and gang membership, with its `grade` and `joined_at`. |
| `opx77_vehicles` | core | `plate` VARCHAR(12) | Owned vehicles: `citizen_id`, `record`, `appearance`, `garage`, `state`, `health`, and the JSON columns `body`, `paint` and `metadata`. |
| `opx77_character_status` | [`opx77_status`](../reference/opx77_status/index.md) | `citizen_id` | The character's gameplay needs — hunger, thirst, stamina and street cred — as one JSON column. |
| `opx77_migrations` | core | `name` VARCHAR(190) | The applied-migration ledger. Created by the migration runner itself, not declared in `schema.lua`. |

!!! danger "A database from before the renames has to be dropped and recreated"
    `opx77_accounts`, `opx77_players` and `opx77_player_groups` were renamed to
    the three names above, with every foreign key and index renamed with them,
    **inside** migrations 0001–0003 rather than as new migrations. The runner
    keys on the migration name and will not re-run one a database has already
    recorded, so an existing database keeps the old tables while the code
    queries the new ones. There is no automatic migration path and none is
    planned: drop the database and let the runner recreate it.

### Where an operator reads the schema {#sql-directory}

`opx77_core/sql/` holds one `.sql` file per table — `users.sql`,
`characters.sql`, `character_groups.sql`, `vehicles.sql` — and `opx77_status`
has its own `sql/status.sql`. Those are the copies an operator reads, and runs
by hand when they migrate by hand.

They are **not** what executes. The OPEN//77 *server* runtime installs no
file-reading API — `Open77.resource` is `{ name, state }`, the sandbox removes
`io`, `os` and `loadfile`, and a `.sql` file is not a script a manifest can list
— so the migration runner cannot open them. The statements live twice: in
`sql/`, and in `server/storage/schema.lua`, which is what runs. Each entry of
[`OPX.Schema`](../reference/opx77_core/server-api.md#schema) carries a `file`
naming its `sql/` counterpart, the two are edited together, and
`python3 tools/check_sql_parity.py` in `opx77_core` exits non-zero when they
drift.

### One satellite owns a table {#satellite-tables}

The rule everywhere else in this framework is that a satellite persists nothing
and owns no table: it draws and reacts, and anything durable goes through the
core. [`opx77_status`](../reference/opx77_status/index.md) is the single
exception. It keeps the character's needs in `opx77_character_status`, keyed on
the citizen id, and declares `database.access` for that and nothing else. The
values are owned by the client during play and pushed back on a throttle, which
means they are forgeable — that was accepted deliberately rather than overlooked.

Everything else in this set — `opx77_appearance` included, and it is the
resource that captures the face stored on the character row — declares no
`database.access` and ships no `sql/`.

Design decisions worth knowing before you write against these tables:

- **`user_id` is `ascii_bin`.** A case-insensitive collation would make two
  Master-issued GUIDs compare equal, which would merge two accounts into one.
- **`citizen_id` is the primary key of `opx77_characters`**, because it is also
  the character key every satellite addresses a character by, `opx77_status`'s
  own table included. One identity, not two.
- **The JSON columns are never queried by their contents.** They are read whole,
  decoded, and written whole. Nothing indexes into them, so nothing breaks when
  a gameplay file adds a key.
- **`cid` is a slot number, not an identity.** Deleting character 2 of 3 leaves
  the third as `cid` 3.
- **The composite primary key on `opx77_character_groups`** makes rejoining a
  group a promotion rather than a duplicate row.
- **`opx77_vehicles` is keyed on the plate**, not the runtime id: the OPEN//77
  vehicle id is issued at spawn and is gone the moment the owning resource
  reloads. The plate is the only durable handle.
- **`appearance` is nullable**, and `NULL` means "this character has never been
  to the mirror" rather than "empty". It is written by the core alone, and only
  through [`OPX.SaveAppearance`](../reference/opx77_core/server-api.md#saveappearance).
- **The core's own tables cascade.** `opx77_character_groups` and
  `opx77_vehicles` cascade from `opx77_characters`, which cascades from
  `opx77_users`. `opx77_character_status` does **not**: it belongs to another
  resource, and a foreign key across that line would make one resource's
  migration order depend on another's.

### Deletion is soft {#soft-delete}

Deleting a character sets `deleted_at` and leaves the row. Two things follow: a
mistake is recoverable, and **the citizen id is never reissued to a stranger** —
which matters because players write those codes down.

Every read in the core filters `deleted_at IS NULL`, with exactly one exception:
the lifetime row count, which deliberately counts deleted rows too. Create,
delete and create again writes a new row each time, and `ROW_CEILING` — 60 by
default, well above the per-account slot limit — is what bounds it.

## Migrations {#migrations}

`server/storage/schema.lua` is **append-only**. The runner keys on the migration
`name`, never on position, because an index renumbers the moment somebody
inserts one in the middle.

!!! warning
    Never edit a migration that has shipped. It has already run on live
    databases and the runner will not run it again, so your edit reaches new
    installs only and the two schemas diverge silently. Add a new migration
    instead.

Migrations apply in order and **stop at the first failure**. A half-applied
schema is the one state that neither rolling forward nor rolling back is safe
from, so the runner refuses to continue past a statement that did not work and
says which one.

Shipped by the core: `0001_users`, `0002_characters`, `0003_character_groups`,
`0004_vehicles`. `opx77_status` runs its own single statement for
`opx77_character_status` at boot.

## Named parameters, and no comments in SQL {#named-parameters}

Use `@name` parameters throughout. Never positional `?`.

```lua
local rows = OPX.Storage.query([[
SELECT citizen_id, name FROM opx77_characters
 WHERE user_id = @user AND deleted_at IS NULL
]], { user = session.userId })
```

The reason is mechanical rather than stylistic. The platform's bridge rewrites
`?` placeholders into real named parameters by **scanning the statement**, and
that scan has to reason about quoting and comments to know which `?` is
genuinely a placeholder rather than a character inside a string.

!!! warning
    For the same reason there is not one comment inside any SQL string in this
    framework — including in the migrations, which have no parameters at all. A
    statement that gains a `?` next year must not also be the one carrying a
    comment, and the way to guarantee that is to never write the comment. Put
    the explanation on a Lua line above the string.

## A `nil` parameter is dropped, not bound as `NULL` {#nil-parameters}

The bridge builds its parameter list from the Lua table it is handed, and a key
whose value is `nil` is not in that table at all. So `position = nil` does not
bind `NULL`: the statement reaches MySqlConnector naming `@position` with no
such parameter, and the connector refuses the **whole** statement. The host's
database log says so:

```text
[ERR] [database] resource 'opx77_core' update failed: Parameter '@position' must be defined.
```

That was every character creation until this round — a new character has no
position — and it answered the player `error.unavailable`. The same shape was
waiting on every nullable column the core writes.

Absence now travels as an empty string, and the statement turns it back into
`NULL` with `NULLIF`:

```lua
OPX.Storage.execute([[
UPDATE opx77_characters
   SET position = NULLIF(@position, ''),
       appearance = NULLIF(@appearance, '')
 WHERE citizen_id = @citizen
]], {
  citizen = entity.citizenId,
  position = entity.position ~= nil and json.encode(entity.position) or "",
  appearance = entity.appearance ~= nil and json.encode(entity.appearance) or "",
})
```

It is safe because no real value is ever empty: encoded JSON never is, and
neither is a vehicle's appearance name. The columns read back
exactly as before. In `opx77_core` the rule covers a character's `position` and
`appearance` on every save, clearing a stored face, and a vehicle's
`appearance`, `body` and `paint`, through a `nullable` helper in each storage
file.

!!! warning "Write every nullable column this way"
    A statement that works in testing because the value happened to be present
    fails the first time it is absent, with nothing to see until then. Any
    column that may be written as `NULL` takes `NULLIF(@x, '')` and a parameter
    that is never `nil`.

## `await` raises rather than returning a reason {#await-raises}

The platform's stated convention is that failures are values: most APIs answer
`value` or `nil, reason`. **The database `await` forms are the exception.**

`MySQL.<method>.await` **raises** on failure. `MySQL.transaction.await` is the
exception to the exception and resolves `false, reason`.

!!! warning
    An `await` that raises inside a `CreateThread` kills that thread silently —
    no log line, no unwound state, nothing on screen. On this framework that
    thread is usually a player's login, so the symptom is one player who
    connects and never gets a character while the server looks healthy.

`OPX.Storage` exists to make that impossible to get wrong. Every method wraps
its call in `pcall` and answers an `OPX.Result`:

```lua
local result = OPX.Storage.single(
  "SELECT * FROM opx77_characters WHERE citizen_id = @citizen AND deleted_at IS NULL",
  { citizen = citizenId })

if not result.ok then
  -- result.error is "no-database" or "query-failed"; result.detail is the message
  return
end
-- result.value is the row, or nil for "no such row" -- which is not a failure
```

`transaction` is handled in a separate function rather than through the same
wrapper, precisely because it resolves `false, reason` instead of raising: run
through the generic path, a rolled-back transaction would be read as a success.

A `nil` value is an **empty result, not a failure**: `single` answers `nil` for
"no such row", and conflating the two is how a missing character becomes a
crash.

Every SQL statement in the framework lives under `server/storage/`. Nothing
above that layer writes SQL, which is what keeps the parameter and `pcall` rules
enforceable by reading one directory.

## When there is no database {#no-database}

`OPX.Storage.ready()` probes once with `SELECT 1` and caches the answer for the
rest of the run. On a server with no database configured, the core boots, logs
two lines, and refuses to log anybody in:

```text
[storage] no database: <the reason>
[storage] the core will boot, but nobody can be logged in until this is fixed
```

That is deliberate. A framework that let players in without persistence would be
a framework that loses an evening of play at the first restart, and the failure
would surface hours after its cause.

## Where to go next {#next}

- [Integration channels](integration-channels.md#shared-database) — the database
  as a third-party integration path.
- [Identity](identity.md#citizen-id) — the citizen id these rows are keyed on.
- [The OPEN//77 platform](the-platform.md#database) — the platform's half.
