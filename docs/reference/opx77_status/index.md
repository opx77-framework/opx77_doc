---
title: The opx77_status resource
description: opx77_status owns two things for OPX//77 — the shared status-effect registry every resource may add a chip to, and the character's gameplay needs, in its own table with its own server half. Seven client exports, an ownership model that cleans up after a caller that stops or reloads, and the payloads opx77_hud draws.
---

# opx77_status

| At a glance | |
|---|---|
| **Version** | `0.3.0` — `version` in `open77.lua`, mirrored as `OpxStatus.VERSION` in `client/state.lua` because no Lua here can read the manifest. A release moves both lines |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `reconnect` |
| **Permissions** | `network.events`, `database.access` — see [below](#permissions) |
| **Sides** | client, plus a server half that stores the needs and does nothing else |
| **Exports** | seven, all client: [`add`](exports.md#add), [`update`](exports.md#update), [`remove`](exports.md#remove), [`clear`](exports.md#clear), [`needs`](exports.md#needs), [`setNeeds`](exports.md#setneeds), [`addNeeds`](exports.md#addneeds) |
| **Commands** | none |
| **Events** | publishes [`opx77:status:effects`](events.md#status-effects) and [`opx77:status:needs`](events.md#status-needs); raises [`opx77:status`](events.md#opx77-status) and, per effect, [your own event name](events.md#spec-event); four [net events](events.md#networked) carry the needs |
| **Database** | one table, [`opx77_character_status`](#schema) |
| **Surface** | none. [`opx77_hud`](../opx77_hud/index.md) draws the strip, and the gauges for the needs |

## What it is {#what-it-is}

Two jobs, and they are separate:

**A shared status-effect strip.** Any resource adds a chip — bleeding, over
encumbered, a wanted level, a buff on a timer — and `opx77_status` owns the
registry, the ordering and the countdown. Without it, every resource that wanted
to say something on screen would draw its own box and they would overlap. One
registry means one place decides what an urgent chip outranks, one place decides
how many fit, and one place ticks the timers down.

**The character's gameplay needs.** `hunger`, `thirst`, `stamina` and
`streetCred` belong to this resource: it stores them in [its own
table](#schema), loads them per character, decays hunger and thirst on the
client, and serves them to `opx77_hud`. See [The needs it owns](#needs).

Both halves are a **public API** rather than an internal detail of the HUD, and
that is what its seven exports are for. An effect belongs to the resource that
added it; `remove` and `clear` only ever reach your own; ids are unique per
owner, so two resources may both hold `bleeding`; and when your resource stops or
reloads, everything it held goes with it without you writing a line of teardown.
That ownership model is the whole reason another developer can depend on this
resource safely, and it is documented in full on
[Exports](exports.md#ownership).

## Its relationship with opx77_hud {#hud-relationship}

The two resources are separate on purpose:

- **`opx77_status` owns the effect registry and the needs, and publishes them.**
  What an effect is, who added it, when it expires, what order the strip sits in,
  how many are drawn before the rest collapse into a counter — all decided here.
  So are the needs: their bounds, their starting values, their decay and where
  they are stored. It draws nothing.
- **[`opx77_hud`](../opx77_hud/index.md) renders it and owns the surface.** It
  listens on [`opx77:status:effects`](events.md#status-effects) and
  [`opx77:status:needs`](events.md#status-needs), carries what arrives into its
  next frame, and places, themes and animates it. It has no opinion about what a
  chip means or what a need is for, and it never writes either back.

A merge of the two was considered and **rejected**. These exports are an API
third-party resources are written against, this is its own repository with its own
version and licence, and the bug that prompted the suggestion — the strip's
`ANCHOR` and `OFFSET` silently doing nothing — turned out to be six lines in the
HUD's web layer and is fixed.

Two surfaces for one corner of the screen would have been two things to place,
two things to theme and two things to keep in step, which is why this resource
ships with no surface of its own and publishes an event instead. The placement
travels **in the payload**, so the HUD never has to read this resource's config:

```lua
{
  anchor = "bottom-left",  -- OPX_STATUS_CONFIG.ANCHOR
  offset = 120,            -- OPX_STATUS_CONFIG.OFFSET
  chips  = { --[[ up to MAX_VISIBLE, already ordered ]] },
  hidden = 0,              -- how many were left out of the cut
}
```

The needs travel the same way. The HUD reads them once at boot with the
[`needs`](exports.md#needs) export, because a resource that starts after this one
has already missed the load, and then redraws on every
[`opx77:status:needs`](events.md#status-needs) rather than polling.

!!! warning "The strip is only as visible as the HUD is"
    The whole HUD surface is one element's `open` class, strip and gauges
    included. A player who typed `/hud off` sees no chips, however urgent, and no
    needs either. Adding an effect is not a way to put something on a screen its
    owner has turned off.

## The needs it owns {#needs}

Four keys, declared in [`OPX_STATUS_CONFIG.NEEDS`](config.md#needs) with their
bounds, their value on a new character and their decay rate:

| Need | Range | New character | Decays |
|---|---|---|---|
| `hunger` | `0 .. 100` | `100` | 0.20 a minute |
| `thirst` | `0 .. 100` | `100` | 0.28 a minute |
| `stamina` | `0 .. 100` | `100` | no |
| `streetCred` | `0 .. 100000` | `0` | no |

A key that is not in that table is refused by [`setNeeds`](exports.md#setneeds)
and [`addNeeds`](exports.md#addneeds) with `unknown_need`, never appears in a
[`needs`](exports.md#needs) answer, and is never stored. The table is the whole
list.

!!! warning "`ram` is gone"
    There was a fifth need, `ram`, carried in `opx77_core`'s metadata and read by
    nobody. It was **deleted outright** rather than moved here, and it is not a
    key of `OPX_STATUS_CONFIG.NEEDS`. A patch naming it is `unknown_need`.

The client owns the values during play. It decays them, serves them, raises
[`opx77:status:needs`](events.md#status-needs) on every change, and pushes them
back to the server half on a throttle; the server holds the last push and writes
it. The whole path, event by event, is on [Events](events.md#needs-path).

!!! danger "The citizen id and the values arrive from the client and are taken at face value"
    There is no ownership proof and no server-side re-derivation. The server
    checks the *shape* of the id, clamps every value into the bounds in
    `config.lua` before it reaches a column, and rate limits both net events —
    but a client that lies about its needs is believed. This is the project
    owner's ruling rather than an oversight, and it is stated in the resource's
    README in the same terms.

### What stays in opx77_core {#core-owned}

`health`, `armor`, `isDead` and `inLastStand` are **not** here. They stay in
`opx77_core`'s [`PlayerData.metadata`](../opx77_core/types.md), because
`OPX.PlaceCharacter` reads the stored health to clamp the respawn and applies
armour after it settles. The core's `STARTING_METADATA` carries those four keys
and no others.

The core has no needs of its own any more: `PlayerData.status`, the
`OPX.SetStatus` and `OPX.SetStatusValues` mutators, the core's `STATUS_UPDATE`
event and its `NEEDS` config block have all been removed, along with the files
that implemented them. A resource that moved a need through the core moves it
through [`setNeeds`](exports.md#setneeds) or
[`addNeeds`](exports.md#addneeds) here instead.

## The table it owns {#schema}

One table, `opx77_character_status`, one row per character:

```sql
CREATE TABLE IF NOT EXISTS opx77_character_status (
    citizen_id VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
    needs JSON NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
```

`sql/status.sql` is the copy an operator reads. `server/main.lua` holds the same
statement as a Lua string and applies it itself at boot, so nobody has to run the
file by hand — the server runtime has no file-reading API, which is why the
statement is written out twice rather than loaded from the one place. Nothing is
read or written until that `CREATE TABLE` has succeeded; if it fails, the server
half logs two lines and stops, and no character's needs load or save.

There is deliberately **no foreign key** to `opx77_characters`. One would make
this resource refuse to install until the core had migrated, and load order across
resources is not ours to decide. It follows that a row here can outlive the
character it names.

!!! danger "There is no migration in this framework"
    Nothing here upgrades an older database. A database from before this change
    must be **dropped and recreated**. That applies to the needs that used to live
    in `opx77_core`'s `metadata` column too: they are not copied across, and a
    character's needs start at the defaults in [`config.lua`](config.md#needs).

## Why it holds two permissions {#permissions}

```lua
permissions {
  "network.events", -- opx77_status:pull, :push, :values and :pushed
  "database.access", -- opx77_character_status, this resource's own table
}
```

It used to declare `permissions {}`, and that was honest at the time: the effect
registry needs neither grant. It still does not.

- An **export call** needs no permission on either side, so the seven exports
  cost nothing.
- The client's **local event bus** is host-wide, so a `TriggerEvent` here reaches
  a bare `AddEventHandler` in another resource without `network.events`. The
  three events this resource publishes are all on that bus.

Both grants are for the needs, and only for the needs:

- **`network.events`** — the four [net events](events.md#networked) that carry a
  character's needs between the two halves.
- **`database.access`** — `opx77_character_status`. Note what
  [Persistence](../../concepts/persistence.md#threat-model) says about that grant:
  it is a boolean gate over the whole database, not an allocation of one table.

## Where to go next {#next}

- [Exports](exports.md) — the seven calls, their error codes, and the ownership
  and generation model behind them.
- [The effect spec](effect-spec.md) — every field, the tones, the ordering rule
  and the countdown.
- [Events](events.md) — how an expired effect is reported back to you, the needs
  path across the wire, and the payloads the HUD draws.
- [Configuration](config.md) — the strip, the needs and the write path.
- [The client export contract](../../concepts/export-contract.md) — read this
  before calling anything here.
