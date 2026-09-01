# The Open77 platform

What follows is what OPX//77 knows about the platform it runs on, and why the
framework is shaped the way it is. It was surveyed on 2026-08-30 from
<https://open2077.net/docs> (37 pages, synchronised 26 August 2026, pre-alpha
status: the API can move), then corrected on 2026-08-31 by reading the
resources actually shipped with `open77-server-2.31.4+op77.11`.

!!! note "When the docs and the shipped code disagree, the shipped code wins"

    It runs. Several corrections below come from reading the official
    resources rather than the site.

## The runtime

PUC **Lua 5.4.8**. Each resource gets *its own Lua state*, its own scheduler,
allocator, permission set and lifecycle.

The sandbox removes `io`, `os`, `debug`, `package`, `dofile`, `loadfile`, the
FFI and direct coroutine creation.

Per-resource budgets, client side:

| Budget | Value |
|---|---|
| Lua memory | 32 MiB |
| Instructions per resumption | 500 000 |
| Per-frame budget | 2 ms |
| Source file size | 4 MiB |

Exceeding the budget raises `Open77 script execution budget exceeded` and the
coroutine is never resumed.

The network envelope allows at most **32 arguments and 48 KiB**. A resource may
hold 1 024 tasks and 2 048 handlers.

## No cross-resource calls on the server

This is the property that shapes the entire framework, and it has its own
section in [Architecture](architecture.md).

> Server resources cannot call each other. The server runtime installs no
> `exports`, no `GetInvokingResource`, and no cross-resource event bus.

`TriggerEvent` does not cross resource boundaries on the server: it works
per-VM. The documentation explicitly recommends grouping all of a game mode's
server logic into a **single resource**, organised into files.

An `es_extended`-style core, called by third-party resources, is therefore
impossible. Open77 abandoned its own `open77_gamemode` for this reason, and
distributes common patterns by code generation rather than runtime binding.

**On the client it is the opposite**: exports exist.

```lua
exports("openMenu", function(id) return { opened = true, id = id } end)
local promise, reason = Open77.exports.call("garage", "openMenu", 42)
local result, callError = promise:await()
```

There is **no** FiveM-style `exports.<resource>:<name>()` proxy. All 80
official exports across the 17 packages are **client-side**.

### One documented inconsistency

`/docs/api/client/open77-exports` states *"Returns: whatever the export
returns"* for `Open77.exports.call`, which contradicts its own prose (*"returns
a generation-bound Promise"*) and every example on the site. OPX//77 reads it as
`promise, reason`, like everywhere else, and treats the page as a generation
artifact.

## The manifest

```lua
resource "garage"
version "1.0.0"
auto_start true

shared_script "shared/config.lua"
server_script "server/main.lua"
client_script "client/main.lua"

web_ui_page "web/index.html"
web_files { "web/**" }
files { "assets/blips/*.png" }
permissions { "network.events" }
```

- `require("shared.helpers")` resolves to `<resource>/shared/helpers.lua` or
  `<resource>/shared/helpers/init.lua`.
- Scripts load **in manifest order**, so only entry points need to be listed —
  but see the [load-order rules](architecture.md#load-order-is-the-contract):
  OPX//77 lists every file, one per line, and uses no `require` and no globs.
- A file is only reachable if it matches a `files` declaration exactly.
  `Open77.assets.texture("assets/blips/x.png")` fails otherwise.

`server_script` takes **one entry per line**, and globs are to be avoided: an
empty glob prevents the whole resource from starting. Every shipped resource
lists its files one by one.

## Identity, cryptographically verified

Three distinct values:

| Value | Meaning |
|---|---|
| `userId` | durable identifier tied to the installation, stable across sessions. The account key. |
| `playerId` (alias `source`) | valid for the current session only. |
| `displayName` | changeable by the player. |

The Master issues an Ed25519 certificate covering
`userId || P-256 public key || displayName`. Renaming in a modified client
invalidates the certificate and the session is rejected before it becomes
active.

```lua
AddEventHandler("onPlayerConnected", function(playerId, playerName)
    local player = tonumber(playerId) or 0
    print(GetPlayerIdentifier(player)) -- durable userId
    print(GetPlayerName(player))       -- displayName, verified by the Master
end)
```

`source` is **not defined** in `onPlayerConnected`: it is only populated in
handlers reached by a network event. During a network handler, `source` comes
from the authenticated connection, never from the client payload.

### Disconnection

There are **two** departure events, and neither is documented:

- `onPlayerDisconnected(playerIdStr)` — 9 uses across the shipped resources,
  including `open77_playerstate`, which uses it for its final save.
- `playerDropped()` — 5 uses, including `open77_appearance` and `open77_voice`,
  which read `source` rather than an argument.

Which one is authoritative is not stated. `opx77_core` listens to both, and
`OPX.Logout` is idempotent. The real safety net is re-checking the `userId`
behind the slot in `OPX.EnsureSession`.

### There is no player list

> There is no `Open77.players.all()`. A reload gives this VM an empty table
> while the server is still full, and `onPlayerConnected` does not re-fire for
> players who are already here.

Hence lazy roster adoption: `OPX.EnsureSession` at every entry point, and the
client re-announces itself on `onClientResourceStart` **and** on
`open77:worldReady`.

## The readiness gate

> do not teleport, spawn, kill or force a respawn on a player until their
> readiness gate has opened.

```lua
Open77.ready.participate({ timeoutMs = 30000, reason = "character_creation" })
local session, failure = Open77.ready.hold(playerId, "character_creation")
Open77.ready.release(playerId, session)
```

`participate` automatically places a hold on every player who connects
afterwards. The session number avoids confusion when `playerId` values are
recycled.

If a hold is never released, the platform opens the gate after the timeout and
emits `timeout:<resource>` — potentially with the player still in a modal
window and **holding no puppet at all**. Liveness must therefore be checked
before any placement.

`onPlayerReady(playerId, detail)` is emitted in every resource when the last
hold drops. `detail` is one of `cleared`, `no_holds`, `resource_reloaded`,
`resource_stopped` or `timeout:<resource>`.

## The database

Requires the `database.access` permission. `MySQL` is an alias of
`Open77.database`.

```lua
Open77.database.query(sql, params?, callback?)
Open77.database.single(sql, params?, callback?)
Open77.database.scalar(sql, params?, callback?)
Open77.database.insert(sql, params?, callback?)
Open77.database.update(sql, params?, callback?)
Open77.database.transaction(statements, callback?)
```

An `await` form is available: `.await(sql, params?)`. It resumes on the owning
resource's scheduler, never on the database worker.

!!! danger "`.await` raises, it does not return `nil, reason`"

    This contradicts the "failures are values" convention shown everywhere
    else. `open77_dbtest` states it plainly: *".await raises on failure, so
    pcall keeps the outcome printable instead of killing the thread."*
    `MySQL.transaction.await` is the exception: it resolves `false, reason`.

    An `await` that raises inside a `CreateThread` kills the thread silently —
    and that thread is usually a player's connection. `opx77_core` wraps every
    call in a `pcall` and returns a `Result`.

Two more rules taken from `open77_playerstate`:

- **Named `@name` parameters are preferred over `?`.** The bridge rewrites `?`
  placeholders into real named parameters by scanning the statement, and that
  scan has to reason about quoting and comments.
- **No comment may appear inside a SQL string**, for the same reason.

!!! warning "The database is common ground"

    > Every resource holding `database.access` talks to the same database, with
    > the same credential. There is no per-resource schema, table prefix or
    > statement filter. A resource can read and write another resource's tables.

    That is an integration path as much as an attack surface. All `opx77_core`
    tables are prefixed `opx77_`, and database content is never treated as
    unforgeable by another installed resource.

## Commands and ACL

```lua
RegisterCommand("garage.delete", function(source, args, rawCommand)
    -- source = authenticated playerId, or 0 for the server console
end, true)  -- true = restricted, subject to the ACL
```

The permission is `command.<name>`. A `*` wildcard or a trailing wildcard
`command.garage.*` also authorises. The ACL lives in `acl.jsonc`, named by
`server.jsonc`, and compares the 64-byte public key from the handshake.

Console commands: `acl.reload`, `acl.list`,
`acl.check <playerId> <permission>`.

`opx77_weather` is the example to copy: every mutation is registered
restricted, so the host resolves `command.<name>` against the caller's ACL
**before the resource runs at all**.

## Conventions the platform imposes

1. Engine identifiers are **opaque**: store 64-bit integers as they are, never
   pass them through `tonumber`.
2. Failures are values: most APIs return `value` or `nil, reason`, without
   exceptions. (`MySQL.*.await` is the documented exception.)
3. Permissions are explicit in the manifest.
4. Server code never reaches clients; client scripts are signed.

## The eight game-mode conventions

Proven on Pursuit and Race, to be followed in the absence of a shared kernel:

1. Lazy roster adoption — repopulate from the next event.
2. Convert `playerId` from network events with `tonumber`.
3. State transitions guarded by a single function.
4. Placement only by kill → respawn, never a raw transform.
5. Re-derive client conditions on the server: they are hints.
6. Sample positions continuously, not as a snapshot.
7. Provide a `<mode>.where` diagnostic command.
8. Isolated routing buckets per round, ambient population cut.

## Live tunables

`Open77.tunables.declare(table)` returns a live proxy, and
`onTunableChanged(key)` signals a change made from the Warden panel.

## Still unverified

These are open questions. Nothing in OPX//77 assumes an answer.

- **Whether an arbitrary event name emitted by a server resource reaches
  another resource.** Only integration names the host knows are demonstrated
  (`open77:appearance:setCharacter`). The reading OPX//77 keeps: the channel is
  **resource → host → all resources**, never resource → resource, and it only
  works for names the host knows. It is not a general bus.
- **The export codec's numeric limits**: maximum argument size, depth, and any
  call timeout. Only a "bounded value codec" is mentioned, rejecting functions,
  threads, userdata, cycles, excessive depth and oversized values. There is no
  documented call timeout; the only documented exit is generation invalidation
  when a resource stops or reloads. Because of this, `opx77_core` sends
  `PlayerData` whole on every change rather than by patch — a few hundred bytes
  against a 48 KiB envelope, and no merge protocol to let drift.
- **The unit returned by `Open77.time.monotonic()` on the server.** The API
  reference says milliseconds; `open77_playerstate` does
  `math.floor(Open77.time.monotonic() * 1000)` server-side, so it returns
  **seconds** there. `opx77_core` uses `GetGameTimer()` instead, documented as
  monotonic milliseconds and present in both runtimes.
- **Whether `setmetatable` is present.** The sandbox documentation does not
  list it among the removals, but **none** of the 37 official resources uses it,
  nor `getmetatable`. Nothing in OPX//77 depends on it.
