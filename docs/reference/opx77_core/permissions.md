---
title: opx77_core permissions
description: The eight capabilities opx77_core requests in its manifest, what each one is used for and where, and the five it deliberately does not request — with the reasoning, so a fork knows what it is changing.
---

# Permissions

`opx77_core` requests eight capabilities in the `permissions {}` block of its
`open77.lua`. This page says what each one is for and where it is used, so a
server owner reviewing the resource can check the list against the behaviour,
and a fork knows what it is taking on when it adds one.

```lua
permissions {
  "network.events",
  "database.access",
  "players.life.read",
  "players.life.kill",
  "players.life.respawn",
  "players.life.revive",
  "players.damage.apply",
  "world.vehicles",
}
```

!!! info
    These are **manifest** permissions: they grant a resource access to a
    binding. They are a different thing from the ACL permissions that gate
    restricted commands, which are granted to a *person* in `acl.jsonc` and are
    documented in [Commands](commands.md). A manifest permission grants access
    to an API; it never replaces validation of identity, ownership, distance,
    bucket or gameplay state.

---

## network.events {#network-events}

Grants `RegisterNetEvent`, `TriggerClientEvent` and `Open77.net`.

This is the core's whole transport. The server half sends every
`opx77:client:*` name with it and receives every `opx77:server:*` doorway with
it; without it the client mirror is never filled, no character can be selected
and nothing appears on screen.

`local.events` is **not** requested and is not needed: the core's
`TriggerEvent` / `AddEventHandler` traffic stays inside its own VM on the server
and inside the host-wide local bus on the client, and neither costs a grant.

**Used by** `server/character.lua`, `server/events.lua`, `server/player.lua`,
`server/groups.lua`, `server/functions.lua`, `server/vehicles.lua`,
`server/commands.lua`, and every file in `client/`.

---

## database.access {#database-access}

Grants `Open77.database` / `MySQL` — the shared connection every resource on the
server shares.

Persistence. Every SQL statement in the resource lives in
`server/storage/`, which owns the `opx77_`-prefixed schema and its migrations,
and nothing else in the core writes SQL.

!!! warning
    This grant is a **whole-database** grant. The platform applies no
    per-resource schema, prefix or statement filter, so any resource holding it
    can read and write any other resource's tables. That is why the core is the
    only writer of its own tables and why a third-party resource should treat
    them as read-only. [`opx77_status`](../opx77_status/index.md) is the only
    other resource in this set that requests it, for the one table it owns.

It is safe on a server with no database configured: `OPX.Storage` degrades to
one logged line and a refusal to log anybody in, rather than raising. The
`/opx77` status command prints a `DEGRADED:` line in that state.

**Used by** `server/storage/main.lua`, `schema.lua`, `players.lua`,
`vehicles.lua`, and `server/logger.lua`, which writes through storage.

---

## players.life.read {#players-life-read}

Grants the player life-state reads — `Open77.players.getLifeState`, and the
position snapshot the core re-derives every save from.

Placement asks the host five times over a second whether the player has settled
before it does anything. Acting server-side on a client that is not incarnated
crashes that client, and the readiness gate can open on a timeout with the
player holding no puppet at all, so "is this player really there" is a question
the core has to be able to ask.

It is also what `/opx77.where` prints, and what makes an `unreadable` life phase
a diagnosis rather than a mystery.

**Used by** `server/character.lua` (`PlaceCharacter`), `server/player.lua`
(`SamplePosition`), `server/commands.lua`, `server/vehicles.lua`.

---

## players.life.kill {#players-life-kill}

Grants `Open77.players.kill`.

Placement is **kill then respawn**, never a raw transform write, because the
respawn transaction carries the fade, the streaming preload and the grace
window that a teleport skips. The kill is the first half of that pair and has no
other use in this resource.

!!! warning
    A placement that kills and then fails to respawn leaves a body on the floor.
    That is exactly the case [`players.life.revive`](#players-life-revive)
    exists to recover, and why the two are requested together.

**Used by** `server/character.lua` (`PlaceCharacter`), once.

---

## players.life.respawn {#players-life-respawn}

Grants `Open77.players.respawn`.

The second half of placement: it carries the stored position, heading, routing
bucket, restored health and a five-second grace window. This is the only call in
the resource that decides where a character stands.

**Used by** `server/character.lua` (`PlaceCharacter`), once.

---

## players.life.revive {#players-life-revive}

Grants `Open77.players.revive`.

The recovery for a placement that killed a player and then could not respawn
them. Without it a failed respawn leaves the player dead with nothing in this
resource able to undo it.

A revive leaves the body where it fell rather than where the row says, so the
core deliberately does **not** turn position sampling back on afterwards: the
stored position survives for the next attempt instead of being overwritten with
wherever the engine dropped them.

**Used by** `server/character.lua` (`PlaceCharacter`), on the respawn-failed
path only.

---

## players.damage.apply {#players-damage-apply}

Grants the player health and damage mutations — `Open77.players.setArmor` here.

Armour is re-applied after a respawn, because armour is not one of the respawn
options and the body is replaced by the transaction. Nothing in this resource
reads damage back; see [`players.damage.read`](#not-requested), which is
deliberately not requested.

**Used by** `server/character.lua` (`PlaceCharacter`), after the respawn
succeeds and only when the stored armour is above zero.

---

## world.vehicles {#world-vehicles}

Grants `Open77.vehicles` — create, get, update, damage and remove.

Spawning a character's own car and writing back what happened to it. The runtime
id the host issues is **not** durable — a reload removes every vehicle this
resource owns — so the plate is the identity the core stores, and the runtime id
is forgotten whenever the host says the vehicle is gone.

**Used by** `server/vehicles.lua`, which is the only file in the resource that
touches the world at all.

---

## Routing buckets, with no grant {#routing-buckets}

`Open77.routingBuckets` — `getPlayer`, `setPlayer`, `setPopulationEnabled`,
`setLockdownMode` — is installed for every server resource and appears in no
permission, so there is nothing in the manifest for it. The core uses it to keep a
player with no character loaded in a bucket of their own.

**Used by** `server/buckets.lua`, called from the join, the placement, the unload
and the stop. See [`ENTRY.BUCKET`](config.md#server-entry-bucket).

---

## players.disconnect {#players-disconnect}

Grants `Open77.players.disconnect`, alias `kick`.

Requested for exactly one purpose: a connecting player the host will not give a
verified identity for. With no `userId` there is no account to key a roster,
a character or a save against, and releasing the readiness gate — which is what
the core did before — left that player in the world with no character and no
way to obtain one. The core now releases its hold and disconnects them with
`entry.noIdentity`, *"Your identity could not be verified."*, which the player
reads on their own screen. If the disconnect is refused, the core logs an error
and sends the same code as an `entry` refusal instead.

The other two entry failures do **not** disconnect. A roster query that fails
answers `entry.failed` and releases the gate, and the selection deadline
(`SELECTION_MS`) only frees the gate hold: in both cases
`opx77_charselector` keeps asking for the roster, and a player still filling
in `opx77_charcreator`'s form is not thrown out.

The reason is delivered to `onPlayerDisconnected`, which the core writes to
the audit log as a `session.disconnect` line.

**This is not a moderation tool.** Nothing in the framework disconnects a player
for anything they *do*, and `players.ban` is not requested.

**Used by** `server/lifecycle.lua` (`beginEntry`), and nothing else.

!!! note "This entry used to be in the list below"

    It read: *"Nothing in this framework kicks anybody. A framework that can
    disconnect players is a framework whose bugs can disconnect players."* The
    reasoning still holds for moderation, which is why the capability is
    confined to one function on one failure path — but a player the host will
    not vouch for cannot be brought in at all.

---

## Deliberately not requested {#not-requested}

Named here so that a fork knows it is changing a decision rather than filling a
gap.

| Capability | Why not |
|---|---|
| `world.props` | The core places no props. A prop is gameplay, and gameplay belongs in a satellite. |
| `world.elevators` | `opx77_elevators` requests this for itself. A shared lift service in the core would put a gameplay feature behind the framework's release cycle. |
| `combat.config` | The core arbitrates no damage and configures no combat. Nothing here should be able to. |
| `players.damage.read` | Armour is written after a respawn and never read back. Health comes from the character row, which is the copy the core is authoritative for. |
| `players.gate` | A gate handler in the core would put every connection behind the resource with the widest failure surface — and the host **admits** a player whose gate handler raised, so a core bug would be a silent open door rather than a loud one. A gate belongs in a small resource that does nothing else. See [Connection control](../../concepts/connection-gate.md#opx77). |
| `players.ban` | A ban is a moderation decision with a Master-side effect that outlives every resource. That is an operator's tool, not a framework's. |
| `filesystem.read` / `filesystem.write` | Everything the core keeps durable belongs in the database, where it can be queried, joined and migrated. A second store in `data/` would be a second source of truth. |
| `player.appearance.read` / `player.appearance.edit` | The core stores the face and never wears it. Reading the catalogue and dressing the puppet are client capabilities, and [`opx77_appearance`](../opx77_appearance/index.md) requests them for itself. |

If you need one of these, it belongs in a satellite resource that requests it
for itself — not in a patch to the core's manifest. That is the whole point of
the split: a permission is granted to a resource, so the smaller the resource
holding it, the smaller the blast radius.

## Where to go next {#next}

- [Overview](index.md) — the manifest at a glance.
- [Commands](commands.md) — the ACL permissions, which are the other kind.
- [Reference overview](../index.md) — what the other eight resources request.
- [The Open77 platform](../../concepts/the-platform.md) — how capabilities are enforced.
