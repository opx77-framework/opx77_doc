---
title: The OPEN//77 platform, as it constrains a framework
description: The OPEN//77 constraints that decide how a roleplay framework can be built — the sandbox and its quotas, the network envelope, identity, the manifest, the shared database, commands and ACL — together with the points where the official documentation and the shipped binary disagree.
---

# The OPEN//77 platform

This page is not a substitute for the platform's own documentation, which lives
at [open2077.net/docs](https://open2077.net/docs) and should be read. It is the
subset that **decides a framework's design**: the facts that, had OPX//77 not
known them, would have produced a different and worse framework.

!!! info
    A second, shorter list sits at the end of this page:
    [where the official documentation is wrong](#corrections). Those entries
    were established from the shipped server binary and from the Lua source of
    the platform's own resources, and where the two disagree the binary is what
    runs.

## The runtime and the sandbox {#runtime}

Each resource gets **its own Lua state**, its own scheduler, its own allocator,
its own permission set and its own lifecycle. Nothing is shared between two
resources implicitly — not a global, not a metatable, not a handler table. The
interpreter is PUC Lua 5.4.

The sandbox does not expose `io`, `os`, `debug`, `package`, `dofile`,
`loadfile`, `load`, arbitrary native modules, FFI or bytecode loading. Direct
coroutine creation and resumption are removed; coroutines belong to the
OPEN//77 scheduler, which is why every yielding call must sit inside a
`CreateThread`. On the **server** the removal list also includes
`collectgarbage` and `require`.

That last one matters more than it looks. `require` being absent server-side is
half the reason a shared server library is impossible on this platform: even if
one existed, there would be no way to load it. The other half is that
`Open77.resource.readFile` is confined to the calling resource, and
cross-resource script paths in a manifest are rejected outright. ESX's entire
plug-in contract — `shared_script '@es_extended/imports.lua'` — has no
equivalent here, on either runtime.

## Quotas {#quotas}

Per resource, as documented defaults on the client:

| Limit | Value |
|---|---|
| Lua memory | 32 MiB |
| Instructions per coroutine resume | 500,000 |
| Global Lua frame budget | 2 ms |
| Scheduled tasks | 1,024 |
| Event handlers | 2,048 |
| WebUI handlers | 512 |
| WebUI surfaces | 8 |
| Lua source size | 4 MiB per file |
| `readFile` result | 1 MiB |
| Lua files in a resource | 1,024 |
| Declared `files` / `web_files` | 2,048 each |

The server carries the same 1,024 tasks and 2,048 handlers.

!!! warning
    Exceeding the instruction budget raises `Open77 script execution budget
    exceeded` from the instruction hook. That is a Lua error, and it unwinds
    straight out of the coroutine body: a `while true do … Wait(n) end` loop
    that hits it **never resumes again**. It does not crash the resource and it
    does not repeat. A long-running loop that silently stopped is this, far more
    often than it is a logic bug.

The 1,024-task ceiling is why OPX//77 does not spawn a thread per player per
concern. The core runs one watcher thread per *joining* player and that thread
exits the moment the gate is released or the slot changes hands, which keeps the
live count proportional to joins in flight rather than to players online.

## The network envelope {#network}

A network event accepts at most **32 arguments** in a **48 KiB JSON envelope**.
Values cross a bounded codec that rejects functions, threads, userdata, cycles,
excessive depth and oversized values.

Two design consequences:

**`PlayerData` is sent whole on every change, not as a patch.** A few hundred
bytes against a 48 KiB envelope is not a cost worth optimising, and a merge
protocol is a class of bug where the two copies drift and neither side can tell
which is right.

**Grades are re-emitted as a 1-based array carrying an explicit `level`**, never
the source table indexed from `0`. No table keyed from `0` has ever been
observed crossing this codec, and an export is not the place to find out.

During a network handler, the global `source` is set from the authenticated
connection, never from client payload data. Everything else in the payload is
attacker-controlled.

## Identity {#identity}

Three values, with three different lifetimes: `userId` is durable and signed,
`playerId` (also `source`) lasts one connection and is recycled, and
`displayName` is a profile field the player edits. The Master issues an Ed25519
certificate covering `userId || P-256 public key || displayName`, so renaming in
a modified client invalidates the certificate and the session is rejected before
it becomes active.

`source` is **not** populated in `onPlayerConnected`; it is set only in handlers
reached through a network event. The player id arrives there as an argument, and
as a string.

The full treatment, including OPX//77's own citizen id and the session/player
distinction, is in [Identity](identity.md).

## The manifest {#manifest}

A manifest declares the resource, its scripts, its assets and its permissions.
Scripts load **in manifest order**, one entry per line.

```lua
resource "garage"
version "1.0.0"
auto_start true

shared_script "shared/config.lua"
server_script "server/main.lua"
client_script "client/main.lua"

files { "assets/blips/*.png" }
permissions { "network.events" }
```

A file is reachable only if it matches a `files` declaration exactly; otherwise
`Open77.assets.texture("assets/blips/x.png")` fails. Permissions are explicit:
a resource that does not declare `network.events` cannot call
`RegisterNetEvent` or `TriggerClientEvent` at all.

!!! warning
    An empty glob does not resolve to "no files". It **refuses the whole set**,
    and for a `client_script` or `files` block that means no player can connect
    to the server. `server/**/*.lua` matches nothing against a flat directory,
    so the failure appears the first time somebody renames or flattens a folder,
    with a manifest that has not changed. Every shipped OPEN//77 resource lists
    its files one per line, and so does OPX//77.

## The database {#database}

There is **one** database connection for the whole server, built once from a
single connection string. `database.access` is a boolean gate on reaching it —
not an allocation of a private database.

- Every resource holding it talks to the same database, with the same credential.
- There is no per-resource schema, table prefix or statement filter. A resource
  can read and write another resource's tables.
- Turning the database on turns it on for **every** resource that asked for the
  permission, not only the one you had in mind.

That is an integration path as much as an attack surface, and OPX//77 treats it
as both. See [Persistence](persistence.md#threat-model) for the threat model and
[Integration channels](integration-channels.md#shared-database) for the
integration.

## Commands and the ACL {#commands}

```lua
RegisterCommand("garage.delete", function(source, args, rawCommand)
  -- source is the authenticated playerId, or 0 for the server console
end, true) -- true = restricted, subject to the ACL
```

A restricted command requires the ACL permission `command.<name>`. A `*`
wildcard, or a trailing wildcard such as `command.garage.*`, grants it too. The
ACL lives in `acl.jsonc`, is named by `server.jsonc`, and matches on the 64-byte
public key from the connection handshake — not on a name. The console offers
`acl.reload`, `acl.list` and `acl.check <playerId> <permission>`.

OPX//77 restricts every command that acts on somebody else's character and
leaves unrestricted the five a player runs on their own. Both halves are
documented per command in
[the core's command reference](../reference/opx77_core/commands.md).

## Conventions the platform imposes {#conventions}

Four rules that are not optional, and eight gamemode conventions the platform
proved on its own resources and recommends in the absence of a shared kernel.

1. **Engine identifiers are opaque.** Store the 64-bit integers as they arrive;
   never round-trip one through `tonumber`.
2. **Failures are values.** Most APIs answer `value` or `nil, reason`. The
   database `await` forms are the documented exception — see
   [Persistence](persistence.md#await-raises).
3. **Permissions are explicit in the manifest.**
4. **Server code never reaches clients**, and client scripts are signed.

The eight conventions, proven on the platform's `pursuit` and `race`
gamemodes: adopt the roster lazily and repopulate from the next event; convert
network-event player ids with `tonumber`; guard every state transition behind a
single function; place only by kill → respawn, never a raw transform; re-derive
every client-reported condition on the server, because all of them are hints;
sample positions continuously rather than snapshotting; ship a `<mode>.where`
diagnostic command; and isolate rounds in routing buckets with ambient
population switched off.

OPX//77 follows all eight. Lazy roster adoption is why `OPX.EnsureSession` sits
at every doorway rather than being called once on connect: there is no
`Open77.players.all()`, so a reload gives the VM an empty table while the server
is still full, and `onPlayerConnected` does not re-fire for players already
there.

## Where the official documentation is wrong {#corrections}

Every entry below was established from the shipped server binary
(`open77-server-2.31.4+op77.11`) and from the Lua source of the platform's 37
first-party resources. Where those two disagree with the website, the binary is
what runs. These are recorded because somebody will eventually read the website
and "fix" OPX//77 in the wrong direction.

**`Open77.ready.hold` returns one value, not two.** The bootstrap's own comment
says `returns ok, session`. It is wrong, and the website is right: the call
answers a single integer — the session number — or `nil, reason`. Writing
`local ok, session = Open77.ready.hold(id)` binds `ok` to the session number and
`session` to `nil`, the truth test still passes, and the bug only bites when a
recycled player id makes the release apply to the wrong person.

**`onPlayerReady`'s `detail` never says `timeout:` or `no_holds`.** The complete
set is: the sanitised `note` passed to `release`, `cleared`, `incarnated`,
`resource_stopped`, `resource_reloaded`, and
`liveness_lost:<resource>[,<resource>…]`. The two strings the website documents
appear in no shipped assembly, in either ASCII or UTF-16LE; the website also
omits `incarnated`. See [The entry gate](entry-gate.md#detail).

**`livenessIntervalMs` is a watchdog on your resource, not a budget for the
player.** A player may spend an hour in a character creator and nothing opens.
The gate is only ever forced by evidence that the *holder* is gone.

**Every joiner carries a `__platform` hold that no Lua may take or release**,
with no deadline at all. It clears only when the client announces
`open77:session:gameplayReady`. The website's claim that "a server where nothing
participates is a server where the gate is always open" is true of resource
holds and false of this one. See [The entry gate](entry-gate.md#platform-hold),
which also explains why this matters on a stock OPX//77 install.

**There is only one disconnect event.**
`onPlayerDisconnected(playerId, reason)` is emitted; `playerDropped` is not.
*Corrected since:* this event was undocumented when this note was written, and
carried only the player id. The platform now documents it, with a second
argument — `connection_closed` for a quit or a dropped link, otherwise the text
the disconnect was queued with. It also raises
[`onPlayerRejected`](connection-gate.md#rejected), which is **not** a departure:
it reports a connection refused *before* admission, so there is no `playerId`.
The point that survives is that there is exactly one departure event. The token
appears in no assembly outside the bootstrap's own literal — which is the text
of its own handler registration, so nothing ever calls it. Five first-party
resources listen for it anyway, and nothing breaks for them, because they all
listen for `onPlayerDisconnected` as well.

**A server `TriggerEvent` also reaches `RegisterNetEvent` handlers of the same
name.** The dispatcher matches on the event name and never looks at the network
flag; only the outbound network path filters on it. So a `RegisterNetEvent("x")`
handler whose body calls `TriggerEvent("x", …)` re-enters itself. It is not a
stack overflow — the emission goes through the task queue, so it is tick-paced —
which makes it a **silent permanent busy loop** that logs nothing and never
stops. This is why `OPX.Events.Client` and `OPX.Events.Local` share no name.

**The client's local event bus is host-wide.** `open77_zones` fires a
caller-supplied event name with `TriggerEvent` and `pursuit`, a different
resource, receives it with a bare `AddEventHandler`. This is the opposite of the
server, and it is what makes `OPX.Events.Local` usable by a satellite with no
permission at all. See
[Integration channels](integration-channels.md#local-events).

**`Open77.state.save` / `.load` / `.clear` exists** and keeps authoritative
state across a resource **reload**, and is absent from the API page that
presents itself as complete. The value round-trips through JSON, a value whose
JSON exceeds 64 KiB raises rather than returning `false`, a `save` from a stop
handler returns a bare `false`, and the state survives `reload` but deliberately
not `stop`, `restart` or `refresh` — so an operator keeps a way to say "come
back up as you started".

**`Open77.time.monotonic()` is seconds**, in both runtimes: the bootstrap
defines it as the millisecond scheduler clock divided by 1000. Mixing the two
units produces a timer that fires a thousand times too early, which is the kind
of bug only production finds.

**`Open77.routingBuckets` is installed and is absent from the permission
summary.** Any server resource can read and write any player's routing bucket
with no permission at all. That is simultaneously the platform's most useful
missing roleplay primitive — apartments, instanced interiors, an admin jail,
quiet interiors via `setPopulationEnabled(bucket, false)` — and an ungated way
for any resource to move a player into another dimension silently.

**`MySQL.<method>.await` raises rather than answering `nil, reason`**, against
the "failures are values" convention stated everywhere else.
`MySQL.transaction.await` is the exception and resolves `false, reason`. See
[Persistence](persistence.md#await-raises).

## Where to go next {#next}

- [Architecture](architecture.md) — what OPX//77 does with all of this.
- [The entry gate](entry-gate.md) — the readiness gate, in full, from the binary.
- [Persistence](persistence.md) — the database, the schema and the threat model.
