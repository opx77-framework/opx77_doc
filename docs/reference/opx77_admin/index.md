---
title: The opx77_admin resource
description: opx77_admin is the staff tool for OPX//77 — thirty-nine restricted commands and a keyboard menu that drives them, gated by acl.jsonc and nothing else, with every action audited in the platform log.
---

# opx77_admin

The staff tool. Find a player, get to them, fix them, move them, arm them, hand
them a car or remove them from the server — from a keyboard menu drawn by
[`opx77_menu`](../opx77_menu/index.md), or from the chat box and the server
console with the same commands.

| At a glance | |
|---|---|
| **Version** | `0.1.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `local` — no CEF surface of its own: `opx77_menu` and `opx77_input` draw everything, and both drop this resource's menu and form when its generation changes |
| **Permissions** | `network.events`, `acl.read`, `players.life.read`, `players.life.kill`, `players.life.respawn`, `players.life.revive`, `players.damage.read`, `players.damage.apply`, `players.stats.read`, `players.stats.apply`, `players.disconnect`, `players.access`, `world.vehicles`, `player.travel`, `clipboard.write` |
| **Sides** | server, which registers every command and decides everything, and client, which draws the menu and applies noclip and map travel |
| **Exports** | three, all client: [`open`](exports.md#open), [`close`](exports.md#close), [`state`](exports.md#state) |
| **Commands** | thirty-nine, **every one** ACL-restricted — see [Commands](commands.md) |
| **Events** | five server-to-client net events and one client-to-server, all private — see [Events](events.md) |
| **Optional at runtime** | `opx77_menu`, `opx77_input`, `opx77_notify`, `opx77_core`, `opx77_appearance`, `opx77_weather`, and the platform's `open77_weapons` |

It owns no character data. What a character *is* — citizen id, job, gang, money
— belongs to [`opx77_core`](../opx77_core/index.md), and the menu drives the
core's own staff commands for it rather than writing a second set. It owns no
table and declares no `database.access`: nothing here persists to the database.

!!! danger "The host ACL is the only authority, and this resource adds none of its own"

    Every staff action is a command registered with
    `RegisterCommand(name, handler, true)`, so the host resolves
    `command.<name>` against `acl.jsonc` **before the handler runs**. No handler
    checks a permission, and none may: the host has already decided, and a
    second check would only drift from it.

    The menu is a front-end. Each row sends a command line through
    `open77:command:execute`, the path the chat box uses, and meets the same
    gate. A forged row, a forged form or a hand-built packet gets exactly what
    the typed command would get.

## What a missing resource costs {#soft-dependencies}

None of these is declared: a declared dependency is hard, and a staff tool that
refuses to start because `opx77_menu` is missing is no tool at the moment
somebody has to be kicked. Each missing one costs one log line and its screens.

| Resource | What needs it |
|---|---|
| [`opx77_menu`](../opx77_menu/index.md) | the menu itself; every command still runs typed |
| [`opx77_input`](../opx77_input/index.md) | the forms: reasons, amounts, coordinates, announcements |
| [`opx77_notify`](../opx77_notify/index.md) | the toast a target sees, "A staff member healed you.", and the toast answering each staff action; without it that answer is a chat line |
| [`opx77_core`](../opx77_core/index.md) | the character rows: record, job, gang, money, save, characters online |
| [`opx77_appearance`](../opx77_appearance/index.md) | the readiness gate opening at all — see [Nothing touches a body behind a closed gate](#readiness-gate) |
| [`opx77_weather`](../opx77_weather/index.md) | the weather and time screens |
| `open77_weapons` | every weapon command: its client half answers the relay |

The client half says so once per resource, the first time a row needs it:

```text
opx77_menu is not running; the staff menu cannot use it
```

The platform's own `open77_admin` can run beside this one: every name here is
under `opx77.admin`, so no command shadows another. Two tools switching the same
player's noclip will fight, so give each operator one of them.

## What it needs from the host {#host}

`Open77.acl.isAllowed`, under the `acl.read` permission. It is read-only — this
resource never writes a role or a permission — and it is used in exactly three
places that are not a command: the menu's refresh event, the sweep that switches
a revoked travel mode off, and the chat suggestions. Without it every command
still works and is still gated by the host, but the menu cannot grey out what
the ACL refuses, the travel modes are not switched off when a grant is removed,
and the refresh request is refused. At boot:

```text
Open77.acl is unavailable: the menu cannot grey out what the ACL refuses, and the travel modes are not revoked with a grant. Every command is still gated by the host.
```

Two more host APIs are checked once at boot, and each missing one turns a whole
family of commands into a named refusal rather than a stack trace:

```text
Open77.vehicles is unavailable on this host: every vehicle command refuses
Open77.weapons is unavailable on this host: every weapon command refuses
```

`open77_weapons` is looked for five seconds after start, in a thread rather than
at file scope, because a resource listed after this one is not running yet at
load:

```text
open77_weapons is not running: its client half answers weapon requests, so every weapon command will time out
```

When the server half has registered everything it logs one line, and the count
in it is the number of commands on [Commands](commands.md):

```text
ready -- 39 restricted commands; grant command.opx77.admin to open the menu
```

## Nothing touches a body behind a closed gate {#readiness-gate}

Every teleport, kill, heal, god toggle, health or armour write, weapon request
and vehicle delivery first needs **both** a life state — the "continue" screen
has none — and `Open77.ready.isReady` true for the target. Acting server-side on
a client that is not incarnated crashes that client.

| The target | Refusal |
|---|---|
| has no life state: loading, or on the continue screen | `not_incarnated` |
| has a life state and the readiness gate is still held | `gate_closed` |
| `Open77.ready` is missing, or `isReady` raised | `gate_unreadable` |

It **fails closed**: a gate that cannot be read moves nobody. On a resource set
where nothing sends `open77:session:gameplayReady` the gate never opens, and
every one of those commands refuses — see
[The entry gate](../../concepts/entry-gate.md#platform-hold). In this framework
`opx77_appearance` is what sends it.

Kick and ban act on the **session**, not the body, and are not gated: a player
stuck on the loading screen must still be removable.

## Placement is kill, then respawn {#placement}

Every move — `goto`, `bring`, `tp`, `send`, `observe`, and a map double-click —
kills the player (unless they are already dead) and respawns them at the point,
never a transform write. Only the respawn carries the fade, the streaming
preload and the grace window. The respawn is given
[`PLACEMENT.HEALTH`](config.md#placement) and
[`PLACEMENT.GRACE_MS`](config.md#placement), and the bucket the target is in
unless the move names one: `goto` and `observe` land in the other player's
bucket, `bring` in the operator's.

A respawn the host refuses leaves a body on the ground, so a player this
resource killed for the move is revived where they fell and the command answers
`respawn_refused`.

## The server decides everything {#server-decides}

The client sends a command line. The server resolves the target, reads the live
position, bucket, life state and vehicle occupancy itself, and never acts on a
value a menu drew seconds ago.

- **A target is a player id, or `me`.** `self` is read as `me`. A citizen id is
  not accepted: that mapping lives in `opx77_core`'s VM, which no other server
  resource can ask.
- **A vehicle with somebody aboard** is never removed, and never given a `full`
  or `mechanical` repair, both of which may respawn it. Occupancy is read at the
  moment of the command.
- **Catalogues are allowlists.** Only a row of `data/vehicles.lua` or
  `data/weapons.lua` ever reaches the host, whatever a client types — see
  [Catalogues](config.md#catalogues).
- **Nobody is moved in silence.** A target other than the operator is told by
  toast what was done to them, through `Open77.notifications.send`. The toast
  is best-effort: a missing surface does not fail an action that already
  happened.
- **Travel modes follow the grant.** Noclip and map travel are switched off
  within two seconds of the permission that switched them on being removed, and
  when this resource stops.

## Noclip and map travel {#travel}

Both are client capabilities, applied by the client half through its own
`player.travel` grant when an ACL-gated server command says so, on
[`opx77_admin:travel`](events.md#travel). The ACL decides on the server; the
client only applies.

!!! warning "This is not what stops a patched client flying"

    Nothing on the server can. What it does is keep the switch in staff hands on
    an honest client. Any client resource can raise `opx77_admin:travel`
    locally, which buys it nothing it could not do with its own travel grant.

Map travel arms the world map: a double-click raises `open77:map:picked`, and
the client sends the point back as `opx77.admin.self.maptravel <x> <y> <z>`, so
the ACL is resolved again **on every jump** rather than once when the gesture
was armed.

Every two seconds a server sweep asks `Open77.acl.isAllowed` for the grant that
switched each mode on, because a grant can be removed with `acl.reload` while
the mode is on and no event says so:

```text
noclip off for player 7: opx77.admin.self.noclip is no longer granted
```

A mode switched on by `observe` is tied to `opx77.admin.player.observe`, not to
`self.noclip`. A disconnect clears both switches, so a recycled player id does
not inherit them, and both halves turn them off on this resource's stop.

## The audit {#audit}

Every staff action — and every one refused at the gate or by a native — writes
one line to the platform log, in the same shape `opx77_core` writes, so one
grep finds both:

```text
[audit] event=admin.player.kill severity=info player=3 user=8f0f3a7c-… message="" data={"target":7,"targetUser":"1c4b9e02-…","targetName":"Kiroshi","actorName":"Vex"}
```

- `player` is the operator's player id, `0` for the console, and `user` their
  durable account id. A player id is recycled and is not worth keeping on its
  own; `targetUser` is the target's account id for the same reason.
- `severity` is `info` for a success and `warn` for a refusal.
- `message` is the English detail — the coordinates of a move, the record and
  slot of a weapon give, the reason of a kick — cut to 120 characters, with
  control characters replaced so a name cannot forge a second log line.

A ring of the last [`AUDIT_ENTRIES`](config.md#audit-entries) actions is kept in
memory for [`opx77.admin.read.audit`](commands.md#audit). **The log is the
record**; the ring dies with the process.

Not every refusal is written. A usage error, a malformed argument, `too_fast`
and a target that does not resolve are answered to the operator and not
audited; the gate's refusals, a native's and a failed placement are.

## Where the pieces live {#layout}

| File | Does |
|---|---|
| `config.lua` | shared. Rates, placement, noclip, announcements, vehicles, weapons, the linked commands, the sky lists, the destinations |
| `data/vehicles.lua`, `data/weapons.lua` | shared. The two catalogues, and the allowlists |
| `shared/catalog.lua` | shared. The index over both catalogues; names a malformed row at boot |
| `shared/text.lua`, `shared/locale.lua` | shared. Cleaning and cutting text, and the `locale(key, params)` every file below calls |
| `locales/en.lua`, `locales/fr.lua` | shared. Player-facing text, keyed `admin.<thing>` |
| `server/main.lua` | answers, the audit, the readiness gate, placement, and the one registry every command goes through |
| `server/players.lua` | yourself, other players, noclip and map travel, moderation |
| `server/vehicles.lua` | spawn, give, repair, flag, remove, clean up |
| `server/weapons.lua` | give, refill, clear, holster, read, over the platform's weapon relay |
| `server/world.lua` | destinations, announcements, and the read commands |
| `server/menu.lua` | the opener command and the refresh event; loaded last, because the access map it sends lists what the others registered |
| `client/main.lua` | the command channel and the travel capabilities |
| `client/menu.lua`, `client/forms.lua` | the menu screens on `opx77_menu`, the forms on `opx77_input` |
| `client/exports.lua` | the three public exports, loaded last |

## The menu {#menu}

`/opx77.admin` opens it; the arrow keys move, Enter chooses, Backspace goes back
a screen. Running it again closes it.

- **Each screen is its own `opx77_menu` menu**, not a submenu of one tree.
  `opx77_menu` refuses a spec past 400 rows across the whole tree, and a roster
  of thirty players with twenty actions each is past it; the stack of screens
  lives in this resource. The roster, a catalogue class and the destination
  list are each cut at 190 rows, under the menu's 200 a level, to leave room
  for the navigation.
- **A row whose command the ACL refuses is drawn greyed**, with *no access*
  beside it. The access map is a hint for drawing and nothing more; the host
  still resolves every line. It is re-read when you leave the root screen, so an
  `acl.reload` shows without reopening. On a host with no ACL reader every row
  is drawn enabled and the host answers for each one.
- **A command's answer is written under the list**, and also raised as a
  toast, or a chat line for a report — see
  [How a command answers](commands.md#answers). A refusal from the host — no
  grant — is written there in words, and `opx77_chat` toasts it. Only an answer
  to a command the menu sent in the last fifteen seconds goes under the list.
- **Kill, kick, ban, clearing a loadout, the vehicle cleanup, an announcement
  and saving every character** go through a confirmation screen with Cancel
  first. Nothing else does.
- **Forms are `opx77_input`'s.** The menu steps aside while one is up and comes
  back where it was. The job and gang forms read their options from
  `opx77_core`'s `GetJobs` and `GetGangs`, and the money form its currencies
  from `GetSharedConfig`.
- **The roster** shows the platform's verified display name, the state — *in
  world*, *down*, *joining*, *loading* — the routing bucket and the distance,
  the last only for a player in the operator's bucket. It does not show the
  character's name: that is in `opx77_core`'s VM, and *Character record* runs
  `opx77.where` for it.

## Not built, and why {#not-built}

| Wanted | Why not |
|---|---|
| Freeze a player | The platform has no binding that holds a player in place. Not faked. |
| True spectate | There is no free camera at a world point. `observe` is a teleport with noclip, and says so. |
| Invisibility | No binding hides a player from other clients. |
| Unban | No Lua binding lifts a ban; the server console's `unban <identity>` does. |
| A citizen id as a target | The server cannot map one to a player: that lives in `opx77_core`. |
| Destinations that survive a restart | That would need the database, and a staff tool must not require one. `self.pos` copies a config row. |
| A full vehicle and weapon catalogue | No enumeration binding exists, and shipping a generated list is its own maintenance. |
| Short aliases like `/tp`, `/noclip` | Each alias is a separate permission, and a bare name can shadow another resource's command. |
| Its own job, money and weather commands | `opx77_core` and `opx77_weather` own those, and are already ACL-gated. |
| Ping in the roster | Lua has no reader for it. |

## Pages {#pages}

- [Commands](commands.md) — all thirty-nine, their arguments, their refusals,
  and the permissions to grant.
- [Configuration](config.md) — every key of `OPX_ADMIN_CONFIG`, the two
  catalogues and the locale catalogue.
- [Exports](exports.md) — the three client exports.
- [Events](events.md) — the six private net events, and the platform events
  both halves use.
- [Types](types.md) — the refusal codes and the shapes on the wire.

## See also {#see-also}

- [Getting started](../../guides/getting-started.md#acl) — writing `acl.jsonc`.
- [`opx77_core` commands](../opx77_core/commands.md) — the character, job, gang
  and money commands the menu drives.
- [`opx77_weather` commands](../opx77_weather/commands.md) — the sky and clock
  commands the menu drives.
