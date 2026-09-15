---
title: opx77_admin commands
description: The forty-three ACL-restricted commands opx77_admin registers — the menu, yourself, other players, moderation, vehicles, weapons, a character's bag, the world and the read-outs — with their arguments, refusals, rate limits and the permissions to grant.
---

# Commands

`opx77_admin` registers forty-three commands and **every one is restricted**.
They go through one registry in `server/main.lua`, which calls
`RegisterCommand(name, handler, true)` and has no argument for an unrestricted
command: every command here acts on the world or on somebody.

!!! info "The permission check is the host's, and this resource never repeats it"

    The host resolves `command.<name>` against the caller's ACL and calls the
    handler only if it passes. There is no permission check anywhere in this
    resource's handlers, and there must not be one. A player without the grant
    never reaches this code: the host sends the refusal itself, and nothing is
    audited, because nothing here ran.

## Granting them {#granting}

The permission is always `command.` plus the name exactly as registered. Grant
a family with a trailing wildcard — `command.opx77.admin.player.*` covers the
eleven player commands at once.

!!! warning "`command.opx77.admin.*` does not cover `command.opx77.admin`"

    A trailing wildcard grants what is *below* the prefix. The bare command
    `opx77.admin` — the one that opens the menu — is `command.opx77.admin`,
    which is not below `command.opx77.admin.`, so a principal holding only the
    wildcard can run every staff command typed and cannot open the menu. Grant
    both.

    `command.opx77.*` covers all forty-three, the opener included, **and every
    other OPX//77 staff command on the server** — `opx77_core`'s money among
    them. Grant it only to whoever may have all of it.

Three desks, from least to most:

```jsonc
{
  "version": 1,
  "principals": [
    {
      // gets themselves unstuck and looks around; does nothing to anybody else
      "name": "helper",
      "userId": "00000000-0000-0000-0000-000000000001",
      "publicKey": "…",
      "permissions": [
        "command.opx77.admin",
        "command.opx77.admin.self.*",
        "command.opx77.admin.read.*",
        "command.opx77.where"
      ]
    },
    {
      // handles a report: reach the player, fix them, remove them. No money, no world.
      "name": "moderator",
      "userId": "00000000-0000-0000-0000-000000000002",
      "publicKey": "…",
      "permissions": [
        "command.opx77.admin",
        "command.opx77.admin.self.*",
        "command.opx77.admin.read.*",
        "command.opx77.admin.player.*",
        "command.opx77.admin.moderate.*",
        "command.opx77.admin.vehicle.*",
        "command.opx77.admin.world.announce",
        "command.opx77.admin.inventory.view",
        "command.opx77.admin.weapon.read",
        "command.opx77.inventory.open",
        "command.opx77.inventory.holders",
        "command.opx77",
        "command.opx77.where"
      ]
    },
    {
      // the whole tool, plus the core's economy and the sky
      "name": "operator",
      "userId": "00000000-0000-0000-0000-000000000003",
      "publicKey": "…",
      "permissions": [
        "command.opx77",
        "command.opx77.*"
      ]
    }
  ]
}
```

`command.opx77.admin.weapon.give` hands a loaded weapon to anybody, the operator
included, and `command.opx77.admin.inventory.give` any item; both are left out
of the moderator on purpose, who may search a bag and see who holds something,
and take nothing out of one. `identity.dump` in the
developer terminal writes a ready-to-paste `aclPrincipal`, and
`acl.check <playerId> <permission>` answers the exact question the host asks.
See [Getting started](../../guides/getting-started.md#acl-file).

### Commands the menu drives in other resources {#linked}

The menu greys these by the same ACL, and they are not this resource's. Grant
them where the role should have them. The names are
[`LINKS`](config.md#links) in `config.lua`, so a rename in those resources is
followed there.

| Menu row | Command | Resource |
|---|---|---|
| Character record | [`opx77.where`](../opx77_core/commands.md#opx77-where) `<id>` | `opx77_core` |
| Set job, set gang | [`opx77.job`](../opx77_core/commands.md#opx77-job), [`opx77.gang`](../opx77_core/commands.md#opx77-gang) | `opx77_core` |
| Money | [`opx77.money`](../opx77_core/commands.md#opx77-money) | `opx77_core` |
| Characters in the world, save every character | [`opx77`](../opx77_core/commands.md#opx77), [`opx77.save`](../opx77_core/commands.md#opx77-save) | `opx77_core` |
| Open the bag beside mine | [`opx77.inventory.open`](../opx77_inventory/commands.md#open) `<id>` | `opx77_inventory` |
| Who holds an item | [`opx77.inventory.holders`](../opx77_inventory/commands.md#holders) `<item>` | `opx77_inventory` |
| Weather presets, roll, hold | [`opx77.weather.set`](../opx77_weather/commands.md#set), [`.next`](../opx77_weather/commands.md#next), [`.freeze`](../opx77_weather/commands.md#freeze) | `opx77_weather` |
| Time, hold the clock | [`opx77.weather.time`](../opx77_weather/commands.md#time), [`.time.freeze`](../opx77_weather/commands.md#time-freeze) | `opx77_weather` |

## How a command answers {#answers}

A command typed in chat, or sent by the menu, answers the staff member who ran
it in the catalogue [`LOCALE`](config.md#locale) names — never on
`open77:command:result`, whose accepted answers `opx77_chat` does not print. The
server half sends the answer to this resource's own client half, on
[`opx77_admin:answer`](events.md#answer):

- **An action's outcome is a toast** through `opx77_notify`, titled *STAFF*, in
  one slot each answer replaces: a success when it was done; a warning for what
  was typed wrong or for nothing to act on — a usage line,
  `admin.done.nothingToRefill`, `admin.done.noWeapons`, and the refusals
  `too_fast`, `no_target`, `bad_target`, `self_target`, `bad_number`,
  `bad_coordinates`, `bad_switch`, `bad_duration`, `empty_text`,
  `unknown_vehicle`, `bad_scope`, `unknown_flag`, `unknown_weapon`,
  `unknown_location`, `bad_location_name`, `bad_holder`, `unknown_citizen`,
  `unknown_item`, `bad_count` and `not_enough`, where the same command with the
  right word works; and an error for every other refusal, where something in the
  world has to change first — a full bag, the inventory not answering.
- **A report stays a chat line.** [`read.players`](#read-players),
  [`read.status`](#read-status), [`read.audit`](#audit),
  [`read.locations`](#read-locations), [`weapon.read`](#weapon-read) and
  [`inventory.view`](#inventory-view) are lists someone asked to read, scrolled
  back and compared, which a toast would cut short. So is the list of holders
  the menu asks `opx77_inventory` for: an accepted answer to a linked command the
  menu sent, when it runs to more than one line, is written to the chat box by
  this resource's client half.
- Either way, when the menu sent the command, the first line is also written
  under the list.

`opx77_notify` stays optional: while it is stopped, or when it refuses a toast,
the same text is a chat line, and the client log says so once.

The same command at the **server console** runs as `source = 0` and answers
into the platform log in English — `info` when it succeeded, `warn` when it was
refused — because that answer lands in a log an operator greps. **The sample
lines on this page are the English ones.**

Before a handler runs, the registry refuses in this order:

| Refusal | English answer | When |
|---|---|---|
| `in_game_only` | That command has to be run in game. | the command acts on the caller's own body and the console has none. Marked **in game only** below |
| `too_fast` | Slow down. | the same operator ran the same command inside [`RATE.ACTION_MS`](config.md#rate), or [`RATE.READ_MS`](config.md#rate) for a command marked **read** below. The console is never cooled |
| `failed` | That could not be done. | the handler raised; the log has `<name> raised: <error>` |

Every refusal a handler can answer is a code in
[`AdminError`](types.md#adminerror).

### Targets {#targets}

`<player>` is a connected player id, or `me` (`self` is read the same way).

| Refusal | When |
|---|---|
| `no_target` | nothing was typed |
| `bad_target` | not a positive integer and not `me` |
| `console_has_no_player` | `me` typed at the console |
| `not_connected` | nobody holds that id |

A citizen id is **not** a `<player>`: those commands act on a body, which needs
a connected player id. Every command that touches a body then checks
[the readiness gate](index.md#readiness-gate) and answers `not_incarnated`,
`gate_closed` or `gate_unreadable` — those are marked **gated** below.

A move that passes the gate can still answer `kill_refused` or
`respawn_refused`, carrying the host's own reason — see
[Placement](index.md#placement).

`<holder>` — every [weapon](#weapon) command but the holster, and every
[inventory](#inventory) command — is a player id, `me`, or a **citizen id**,
which also reaches a character that is not in the world:
[`opx77_inventory`](../opx77_inventory/index.md) resolves it through the core
and loads that bag for the call. None of them is gated.

| Refusal | When |
|---|---|
| `no_target` | nothing was typed |
| `console_has_no_player` | `me` typed at the console |
| `bad_holder` | a player id of `0` or less, or a word that is not 1 to 32 letters, digits, `_` or `-`; also the inventory's own `bad_target` |
| `not_connected` | a player id nobody holds |
| `inventory_unavailable` | `opx77_inventory` is not running — checked before anything is asked of it |
| `no_character` | the inventory answered `not_loaded`: that player has no character in the world |
| `unknown_citizen` | the inventory answered `no_character`: no living character carries that citizen id |
| `core_unavailable` | `opx77_core` did not answer `opx77_inventory` |

A holder is answered as `name [id]` for a connected player, and as the citizen
id otherwise.

## The menu {#menu}

### opx77.admin {#opx77-admin}

Opens the staff menu, or closes it when it is already up.

```text
opx77.admin
```

**In game only. Read.** The server answers with
[`opx77_admin:open`](events.md#open) — the access map for this operator — then
the roster and the destination list. It sends no other answer: the menu
opening is the answer, and a toast per open is noise. Without `opx77_menu`
running the client says so in a toast and draws nothing. See
[The menu](index.md#menu).

## Yourself {#self}

Every command in this family is **in game only**.

### opx77.admin.self.noclip {#self-noclip}

Toggles noclip.

```text
opx77.admin.self.noclip [on|off]
```

- `on` and `off` also accept `true`/`false`, `1`/`0` and `yes`/`no`. Nothing
  toggles. Anything else answers `bad_switch`.

The first time noclip goes on for a player, the speed is
[`NOCLIP.SPEED`](config.md#noclip) unless they chose one. Switched off within
two seconds of `command.opx77.admin.self.noclip` being removed — see
[Noclip and map travel](index.md#travel).

```text
Noclip on.
```

### opx77.admin.self.speed {#self-speed}

Sets the noclip speed.

```text
opx77.admin.self.speed <m/s>
```

- m/s: `number` — `0.1` to `500`, the range the native accepts. Anything else
  answers `usage: <0.1..500 m/s>`.

```text
Noclip speed 60.0 m/s.
```

### opx77.admin.self.maptravel {#self-maptravel}

Arms the world map, so a double-click sends you there — or, with three numbers,
is what the double-click sends.

```text
opx77.admin.self.maptravel [on|off]
opx77.admin.self.maptravel <x> <y> <z>
```

With a switch, or nothing to toggle, it arms or disarms the map. With three
numbers it places the caller at that point, through
[kill and respawn](index.md#placement), and answers
`bad_coordinates` for a point that is not three finite numbers inside a
million. The client sends that form itself on `open77:map:picked`, so the ACL is
resolved on **every jump**.

**Gated**, in the three-number form.

```text
Map travel armed: double-click a spot on the map.
Moved to -667.1 -382.6 9.2.
```

### opx77.admin.self.god {#self-god}

Toggles your own god mode.

```text
opx77.admin.self.god [on|off]
```

**Gated.** With nothing typed it reads the current state from
`Open77.players.getHealth` and flips it.

### opx77.admin.self.heal {#self-heal}

Heals you to your maximum health.

```text
opx77.admin.self.heal
```

**Gated.** The maximum is read from `getHealth`, in absolute points, and
defaults to `100` when it cannot be read.

### opx77.admin.self.revive {#self-revive}

Revives you where you lie.

```text
opx77.admin.self.revive
```

**Gated.** Revived with [`PLACEMENT.HEALTH`](config.md#placement) and
[`PLACEMENT.GRACE_MS`](config.md#placement).

### opx77.admin.self.pos {#self-pos}

Copies where you stand to the clipboard as a [`LOCATIONS`](config.md#locations)
row, to paste into `config.lua`.

```text
opx77.admin.self.pos
```

**Read.** Not gated. Answers `no_position` before the host has a replicated
position for you. The row is always named `here`: rename it when you paste it.

```text
Copied to the clipboard (bucket 0): { NAME = "here", LABEL = "Here", X = -667.14, Y = -382.61, Z = 9.16, HEADING = 0.0 },
```

## Players {#player}

### opx77.admin.player.goto {#player-goto}

Teleports you beside a player, into their routing bucket.

```text
opx77.admin.player.goto <player>
```

**In game only. Gated** — both the target, because an unincarnated player
stands in a menu world, and you. Answers `self_target` when aimed at yourself.
You land at [`PLACEMENT.BESIDE`](config.md#placement) from them.

```text
Teleported to Kiroshi [7], bucket 0.
```

!!! note "A player on the roster"
    `opx77_core` keeps a player with no character loaded in a bucket of their
    own, [`ENTRY.BUCKET`](../opx77_core/config.md#server-entry-bucket). A player
    on the roster for the first time has a closed gate and is refused. One back on
    the roster after an unload has an open gate: `goto` lands you in their
    selection bucket, 77000 plus their id as shipped, and `bring` takes them out of
    it into yours. The core undoes neither; their next selection places the
    character in the world as usual.

### opx77.admin.player.bring {#player-bring}

Teleports a player beside you, into your bucket.

```text
opx77.admin.player.bring <player>
```

**In game only. Gated** on the target. Answers `self_target` when aimed at
yourself. The target is told by toast.

### opx77.admin.player.tp {#player-tp}

Teleports a player to coordinates.

```text
opx77.admin.player.tp <player> <x> <y> <z> [heading]
```

- x, y, z: `number` — finite, and inside a million on every axis: the world is
  a few kilometres across, and past a million is a typo.
- heading?: `number` — default `0.0`.

**Gated.** Not in game only: the console can move a player. Four or five
arguments, or `usage: <playerId|me> <x> <y> <z> [heading]`.

### opx77.admin.player.send {#player-send}

Teleports a player to a saved destination.

```text
opx77.admin.player.send <player> <location>
```

- location: the `NAME` of a destination — see
  [`LOCATIONS`](config.md#locations) and
  [`opx77.admin.world.loc.add`](#loc-add). Unknown answers `unknown_location`.

**Gated.** Lands at the destination's heading.

```text
Kiroshi [7] sent to Watson, west.
```

### opx77.admin.player.observe {#player-observe}

Lands you above a player with noclip on.

```text
opx77.admin.player.observe <player>
```

**In game only. Gated.** You land [`PLACEMENT.OBSERVE_HEIGHT`](config.md#placement)
metres above them, in their bucket, and noclip is switched on under the
`opx77.admin.player.observe` grant.

!!! warning "The target can see you"

    There is no free camera at a world point on this platform. This is a
    teleport with noclip, and the answer says so:

    ```text
    Observing Kiroshi [7] with noclip on. They can see you.
    ```

### opx77.admin.player.heal {#player-heal}

Heals a player to their maximum health.

```text
opx77.admin.player.heal <player>
```

**Gated.** The target, when it is not you, is told by toast.

### opx77.admin.player.revive {#player-revive}

Revives a player where they lie.

```text
opx77.admin.player.revive <player>
```

**Gated.**

### opx77.admin.player.god {#player-god}

Toggles a player's god mode.

```text
opx77.admin.player.god <player> [on|off]
```

**Gated.** With no switch, flips what `getHealth` reports.

### opx77.admin.player.health {#player-health}

Sets a player's health, in points.

```text
opx77.admin.player.health <player> <points>
```

- points: `number` — zero or more, capped at the target's maximum health.

**Gated.** Otherwise `usage: <playerId|me> <points>`.

```text
Player 7 health 50/100.
```

### opx77.admin.player.armor {#player-armor}

Sets a player's armour, in points.

```text
opx77.admin.player.armor <player> <points>
```

- points: `number` — `0` to `10000`. Otherwise `usage: <playerId|me> <0..10000>`.

**Gated.**

### opx77.admin.player.kill {#player-kill}

Kills a player, attributed to the operator.

```text
opx77.admin.player.kill <player>
```

**Gated.** The menu asks first. The target is told by toast, as a warning.

## Moderation {#moderate}

Neither command is gated: they act on the session, not the body, and a player
stuck on the loading screen must still be removable.

### opx77.admin.moderate.kick {#moderate-kick}

Disconnects a player with a reason.

```text
opx77.admin.moderate.kick <player> [reason]
```

- reason?: every word after the player — default "Removed by staff.", in the
  server's catalogue. Cut to 127 **bytes** without splitting a character: the
  platform refuses a disconnect reason past 127 UTF-8 bytes outright.

The menu asks first.

```text
Kiroshi [7] kicked: Removed by staff.
```

### opx77.admin.moderate.ban {#moderate-ban}

Bans a player's account on this server, through the platform's server-local ban
list — never the ACL.

```text
opx77.admin.moderate.ban <player> [duration] [reason]
```

- duration?: a whole number with its unit — `3600s`, `30m`, `12h`, `7d` — up to
  `3650d`, or `perm` (`permanent`). Leaving it out bans **permanently**.
- reason?: every word after the duration — default "Banned by staff.".

**A bare number is not a duration.** It is the first word of the reason, so
`opx77.admin.moderate.ban 7 3 strikes` bans player 7 permanently with the reason
"3 strikes", and never for three seconds. A word that looks like a duration and
is out of range answers `bad_duration` rather than banning for ever.

The ban is keyed on the account id (`Open77.players.identifier`), written with
`Open77.access.ban`, and the host writes it before it disconnects anybody.
`refused` carries `access_unavailable` when the host has no `Open77.access.ban`,
and `no_identity` when the account id cannot be read.

!!! info "Lifting a ban"

    No Lua binding lifts one. The server console's `unban <identity>` does, and
    this resource does not wrap it.

```text
Kiroshi [7] banned for 168.0 h: Banned by staff.
```

## Vehicles {#vehicle}

Every vehicle command answers `vehicles_unavailable` when `Open77.vehicles` is
missing on the host. The host scopes every mutation to the resource that created
the vehicle, so these commands can only ever touch a vehicle this resource
spawned: a removal the host refuses answers `not_ours` rather than
"0 removed".

`<id|near>` is a vehicle id, or `near`: the vehicle the operator sits in,
otherwise the nearest one in the operator's bucket within
[`VEHICLES.NEAR_RADIUS`](config.md#vehicles), read at the moment of the command.
`near` at the console answers `console_has_no_player`; nothing in range answers
`no_vehicle`.

### opx77.admin.vehicle.spawn {#vehicle-spawn}

Spawns a catalogue vehicle beside you.

```text
opx77.admin.vehicle.spawn <vehicle>
```

- vehicle: a `NAME` or exact `RECORD` from `data/vehicles.lua`, without case.
  Anything else answers `unknown_vehicle` — see
  [Catalogues](config.md#catalogues).

**In game only. Gated.** Placed at [`VEHICLES.SPAWN_OFFSET`](config.md#vehicles)
in your bucket. Answers `vehicle_cap` past
[`VEHICLES.PER_OWNER`](config.md#vehicles), and `refused` with the host's own
reason for a record the engine does not know.

```text
Vehicle 12 spawned (Quadra Turbo-R) for player 3.
```

### opx77.admin.vehicle.give {#vehicle-give}

Spawns a catalogue vehicle beside a player.

```text
opx77.admin.vehicle.give <player> <vehicle>
```

**Gated** on the player, whose cap it counts against. The player is told by
toast.

### opx77.admin.vehicle.repair {#vehicle-repair}

Repairs a vehicle.

```text
opx77.admin.vehicle.repair <id|near> [scope]
```

- id|near — default `near`.
- scope?: `glass`, `body`, `lights`, `tires`, `visual`, `mechanical` or `full`
  — default `full`. Anything else answers `bad_scope`.

With somebody aboard, only a scope in
[`VEHICLES.OCCUPIED_REPAIRS`](config.md#vehicles) runs; `full` and `mechanical`
may respawn the vehicle and answer `unsafe_repair`.

### opx77.admin.vehicle.flag {#vehicle-flag}

Toggles one flag on a vehicle.

```text
opx77.admin.vehicle.flag <id|near> <flag> [on|off]
```

- flag: a name in [`VEHICLES.FLAGS`](config.md#vehicles), without case, that the
  host also has a mask for. Otherwise `unknown_flag`, listing the configured
  names.

The flags are read and rewritten whole, because the host's patch replaces the
whole set. Fewer than two arguments answers
`usage: <vehicleId|near> <flag> [on|off]`.

### opx77.admin.vehicle.remove {#vehicle-remove}

Removes a vehicle, or every vehicle this resource spawned for you.

```text
opx77.admin.vehicle.remove [id|near|mine]
```

- default `near`. `mine` removes every one spawned for the operator, and is
  refused at the console.

A vehicle with somebody aboard is never removed and answers `occupied`: removing
it drops the occupants wherever it was, and the case that matters is somebody
climbing in after the menu was drawn.

```text
2 vehicle(s) removed, 1 left in place.
```

### opx77.admin.vehicle.cleanup {#vehicle-cleanup}

Removes every empty vehicle this resource spawned, for anybody.

```text
opx77.admin.vehicle.cleanup
```

Occupied vehicles are left in place and counted. The menu asks first.

## Weapons {#weapon}

A weapon is an item of [`opx77_inventory`](../opx77_inventory/index.md): a unit
in a bag carrying a `serial` and the rounds it is loaded with, which the player
draws by using it. So a give adds that item, a refill raises the rounds it
carries, a removal takes the item, and a read lists the weapon items and which
one is drawn — all through the inventory's server exports, never by putting a
record in a game slot. See [Weapons and bags](index.md#weapons-and-bags) for
which export each one calls, and why nothing falls back to the relay.

Every weapon command but the holster takes a [`<holder>`](#targets), is **not**
gated, and answers `inventory_unavailable` while `opx77_inventory` is not
running. A weapon is named by its item name in the inventory's catalogue —
`weapon_lexington` — or without the prefix — `lexington` — without case. Any
other word answers `unknown_weapon`.

A refusal that comes back from the inventory is answered in this resource's
words: `inventory_denied` (this resource is not in its
[`EXPORTS.WRITERS`](../opx77_inventory/config.md#exports)), `bag_no_room`,
`bag_too_heavy`, `unknown_item`, `bad_count`, `not_enough` and the holder
refusals above. Any other code is `refused`, carrying the inventory's code.

### opx77.admin.weapon.give {#weapon-give}

Puts a weapon item in a bag, loaded. The player draws it from the inventory.

```text
opx77.admin.weapon.give <holder> <weapon> [rounds]
```

- weapon: a weapon item of the inventory's catalogue, `weapon_` prefix or not.
- rounds?: `integer` — the rounds the item carries, from `0`. A negative or
  non-integer value answers `bad_number`. Default: the weapon class's
  [`ROUNDS`](config.md#catalogues) in `data/weapons.lua`, or a full load for a
  class that file does not name.

The rounds are never more than the `MAX` of the ammunition that loads the
weapon, in the inventory's catalogue, and a melee weapon carries none. The
inventory gives the item its serial. `CanCarry` is asked first, so a full bag
answers `bag_no_room` and a heavy one `bag_too_heavy` before anything is added.
A connected target other than the operator is told by toast.

```text
M-10AF Lexington is in the bag of Kiroshi [7], carrying 300 rounds; it is drawn from the inventory.
```

### opx77.admin.weapon.ammo {#weapon-ammo}

Sets the rounds of every weapon item of one name in a bag, or of all of them.

```text
opx77.admin.weapon.ammo <holder> [weapon|all] [rounds]
```

- weapon|all — default `all`.
- rounds?: `integer` — from `0`, otherwise `bad_number`. Default: a full load,
  the ammunition's `MAX`. Never more than it.

Each weapon item that takes ammunition has its metadata rewritten with the new
rounds, serial and the rest kept. The one the player has **drawn** is loaded in
hand first: its rounds are stated to the engine through the relay's `setAmmo`,
magazine first, and its item is written once the engine holds them, because the
inventory lowers a drawn weapon's item to what the engine reads back and never
raises it. For a player the readiness gate does not admit, on a host without
`Open77.weapons`, or when the weapon was put away meanwhile, only the item is
written.

It can answer twice: once for the items in the bag, and once more for the drawn
weapon when the relay has answered. A bag with no such weapon answers a warning.

```text
2 weapon(s) in the bag of Kiroshi [7] refilled.
M-10AF Lexington, drawn by Kiroshi [7], loaded with 500 rounds.
Kiroshi [7] carries no such weapon to refill.
```

The drawn weapon's relay steps can answer `weapon_no_answer` when the target's
client never replies, and `refused` with the relay's own reason.

### opx77.admin.weapon.remove {#weapon-remove}

Takes every weapon item of one name, or every weapon, out of a bag.

```text
opx77.admin.weapon.remove <holder> <weapon|all>
```

- weapon|all — **no default**. Taking every weapon is never what a forgotten
  argument meant, so nothing answers `unknown_weapon`.

The bag is read, and each weapon name is removed by name and count, not by slot:
a slot read a moment ago may hold something else now. The inventory puts a drawn
weapon away itself once its item has left the bag. A connected target other than
the operator is told by toast. The menu asks first for `all`.

```text
3 weapon(s) taken from the bag of Kiroshi [7].
Kiroshi [7] carries no such weapon.
```

### opx77.admin.weapon.holster {#weapon-holster}

Holsters a player's weapon, through the platform's relay.

```text
opx77.admin.weapon.holster <player>
```

**Gated.** Takes a `<player>`, not a holder: it acts on a body. It changes no
item and leaves the weapon in its slot. Answers `weapons_unavailable` when
`Open77.weapons` is missing on the host, and `weapon_no_answer` when the target's
client never answers the relay — the client half that does the work belongs to
the platform's `open77_weapons`.

### opx77.admin.weapon.read {#weapon-read}

Lists the weapon items in a bag: slot, rounds, serial, and which one is drawn.

```text
opx77.admin.weapon.read <holder>
```

**Read.** A melee weapon has no rounds column.

```text
Weapons in the bag of Kiroshi [7]:
  slot 3  M-10AF Lexington  300 rounds  #KX1A2B3C4D  (drawn)
  slot 9  Katana  #QR5E6F7A8B
```

## Inventory {#inventory}

A character's bag, online or not, through
[`opx77_inventory`](../opx77_inventory/index.md)'s server exports. Every command
here takes a [`<holder>`](#targets), is **not** gated, and answers
`inventory_unavailable` while the inventory is not running. The inventory's
refusals are answered in this resource's words, as for
[the weapon commands](#weapon).

`count` is a whole number from `1` to
[`INVENTORY.MAX_COUNT`](config.md#inventory), `1` when left out; anything else
answers `bad_count`.

!!! warning "`inventory.give` creates items out of nothing"

    Grant `command.opx77.admin.inventory.give` like money.

### opx77.admin.inventory.view {#inventory-view}

Every stack in a bag, with its slot, the slots used and the weight.

```text
opx77.admin.inventory.view <holder>
```

**Read.** Audited — somebody's belongings were read. A stack's rounds and serial
are shown when its metadata carries them.

```text
Bag of Kiroshi [7] (H7K-M4X3): 3/40 slots, 3.5/30.0 kg
  1  Water x2
  3  M-10AF Lexington x1  300 rounds  #KX1A2B3C4D
  4  Handgun rounds x120
```

### opx77.admin.inventory.give {#inventory-give}

Adds items from the inventory's catalogue to a bag.

```text
opx77.admin.inventory.give <holder> <item> [count]
```

- item: an item name of the inventory's catalogue, exactly, without case.
  Otherwise `unknown_item`.

`GetItems`, then `CanCarry`, then `AddItem`. A connected target other than the
operator is told by toast.

```text
Put 2x Water in the bag of Kiroshi [7].
```

### opx77.admin.inventory.remove {#inventory-remove}

Takes items out of a bag.

```text
opx77.admin.inventory.remove <holder> <item> [count]
```

- item: any item name — letters, digits, `_`, `-` and `.`, up to 48 — not only a
  catalogue one: an item taken out of the catalogue stays in bags until it is
  removed.

A bag holding fewer answers `not_enough`. A connected target other than the
operator is told by toast.

```text
Took 1x Water from the bag of Kiroshi [7].
```

### opx77.admin.inventory.clear {#inventory-clear}

Empties a bag.

```text
opx77.admin.inventory.clear <holder>
```

The menu asks first. A connected target other than the operator is told by
toast.

```text
Emptied the bag of Kiroshi [7].
```

## The world {#world}

### opx77.admin.world.announce {#world-announce}

Sends an announcement to every player: a toast titled `ANNOUNCEMENT` and, when
[`ANNOUNCE.CHAT`](config.md#announce) is on, a chat line.

```text
opx77.admin.world.announce <text>
```

- text: every word, cut to [`ANNOUNCE.MAX_CHARACTERS`](config.md#announce).
  Nothing answers `empty_text`.

The menu asks first. The count is the players a toast was sent to without an
error.

```text
Announced to 14 player(s).
```

### opx77.admin.world.loc.add {#loc-add}

Saves where you stand as a destination, until the next restart.

```text
opx77.admin.world.loc.add <name> [label]
```

- name: 1 to 32 letters, digits, `_` or `-`, lower-cased. Otherwise
  `bad_location_name`.
- label?: every word after the name, up to 48 characters. Default: the name.

**In game only.** An addition under a configured name replaces that destination
for this run. Additions live in `Open77.state`, which the host carries across a
reload of this resource and drops when it stops. `self.pos` is how a spot
becomes permanent.

```text
Destination docks saved as "Northside docks" until the next restart.
```

### opx77.admin.world.loc.remove {#loc-remove}

Forgets a destination saved in game.

```text
opx77.admin.world.loc.remove <name>
```

A destination from `config.lua` answers `seeded_location`: remove it there.

## Reading {#read}

Every command in this family is **read**, and answers a listing: a report, so a
chat line rather than a toast. The menu shows its first line under the list; the
chat box has all of it.

### opx77.admin.read.players {#read-players}

Every connected player: id, verified display name, state, bucket, and distance
from the operator in the same bucket.

```text
opx77.admin.read.players
```

The state is `in world`, `down`, `joining` (a life state, gate closed) or
`loading` (no life state).

```text
2 player(s) connected:
  [3] Vex  in world  bucket 0  0m
  [7] Kiroshi  joining  bucket 0  42m
```

### opx77.admin.read.status {#read-status}

Counts, uptime, and the state of the resources this one leans on or collides
with.

```text
opx77.admin.read.status
```

The resources listed are `opx77_core`, `opx77_menu`, `opx77_input`,
`opx77_notify`, `opx77_chat`, `opx77_appearance`, `opx77_weather`, the
inventory named by [`INVENTORY.RESOURCE`](config.md#inventory),
`open77_weapons` and `open77_admin`: there is no way to enumerate resources, so
the names are fixed. "In the world" counts players the
[gate](index.md#readiness-gate) admits.

### opx77.admin.read.audit {#audit}

The latest staff actions of this uptime, from memory.

```text
opx77.admin.read.audit [count]
```

- count?: `integer` — `1` to `40`, default `15`.

The ring holds [`AUDIT_ENTRIES`](config.md#audit-entries). The platform log is
the record — see [The audit](index.md#audit).

### opx77.admin.read.locations {#read-locations}

Every destination, sorted by name; those saved in game are marked
`(until restart)`.

```text
opx77.admin.read.locations
```

## See also {#see-also}

- [Configuration](config.md) — the rates, the catalogues and the destinations
  these commands read.
- [Getting started](../../guides/getting-started.md#restricted-commands) —
  every restricted command on a full install.
- [Troubleshooting](../../guides/troubleshooting.md#unknown-command) — a command
  the host refuses before this resource runs.
