---
title: The opx77_admin resource
description: opx77_admin is the staff tool for OPX//77 — forty-four restricted commands and a keyboard menu that drives them, gated by acl.jsonc and nothing else, with every action audited in the platform log.
---

# opx77_admin

The staff tool. Find a player, get to them, fix them, move them, arm them, hand
them a car or remove them from the server — from a keyboard menu drawn by
[`opx77_menu`](../opx77_menu/index.md), or from the chat box and the server
console with the same commands.

| At a glance | |
|---|---|
| **Version** | `0.2.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `local` — no CEF surface of its own: `opx77_menu` and `opx77_input` draw everything, and both drop this resource's menu and form when its generation changes |
| **Permissions** | `network.events`, `acl.read`, `players.life.read`, `players.life.kill`, `players.life.respawn`, `players.life.revive`, `players.damage.read`, `players.damage.apply`, `players.stats.read`, `players.stats.apply`, `players.disconnect`, `players.access`, `world.vehicles`, `player.travel`, `clipboard.write`, `input.actions`. None for `opx77_inventory`: that resource lists this one in its `EXPORTS.WRITERS` |
| **Sides** | server, which registers every command and decides everything, and client, which draws the menu, registers the keys and applies noclip and map travel |
| **Exports** | three, all client: [`open`](exports.md#open), [`close`](exports.md#close), [`state`](exports.md#state) |
| **Commands** | forty-four, **every one** ACL-restricted — see [Commands](commands.md) |
| **Keys** | three rebindable mappings: the menu on F9, noclip faster and slower on Page Up and Page Down — see [`KEYS`](config.md#keys) |
| **Events** | eight server-to-client net events and one client-to-server, all private — see [Events](events.md) |
| **Optional at runtime** | `opx77_menu`, `opx77_input`, `opx77_notify`, `opx77_prompts`, `opx77_core`, `opx77_appearance`, `opx77_weather`, [`opx77_inventory`](../opx77_inventory/index.md), and the platform's `open77_weapons` |

It owns no character data. What a character *is* — citizen id, job, gang, money
— belongs to [`opx77_core`](../opx77_core/index.md), and the menu drives the
core's own staff commands for it rather than writing a second set. What a
character *carries*, weapons and ammunition included, belongs to
[`opx77_inventory`](../opx77_inventory/index.md): every weapon and bag command
goes through its server exports, so the inventory stays the one record of it —
see [Weapons and bags](#weapons-and-bags). It owns no table and declares no
`database.access`: nothing here persists to the database.

!!! danger "The host ACL is the only authority, and this resource adds none of its own"

    Every staff action is a command registered with
    `RegisterCommand(name, handler, true)`, so the host resolves
    `command.<name>` against `acl.jsonc` **before the handler runs**. No handler
    checks a permission, and none may: the host has already decided, and a
    second check would only drift from it.

    The menu is a front-end. Each row sends a command line through
    `open77:command:execute`, the path the chat box uses, and meets the same
    gate. So does each key. A forged row, a forged form or a hand-built packet
    gets exactly what the typed command would get.

## What a missing resource costs {#soft-dependencies}

None of these is declared: a declared dependency is hard, and a staff tool that
refuses to start because `opx77_menu` is missing is no tool at the moment
somebody has to be kicked. Each missing one costs one log line and its screens.

| Resource | What needs it |
|---|---|
| [`opx77_menu`](../opx77_menu/index.md) | the menu itself; every command still runs typed |
| [`opx77_input`](../opx77_input/index.md) | the forms: reasons, amounts, coordinates, counts, announcements |
| [`opx77_notify`](../opx77_notify/index.md) | the toast a target sees, "A staff member healed you.", and the toast answering each staff action; without it that answer is a chat line |
| [`opx77_prompts`](../opx77_prompts/index.md) | the noclip and map travel controls drawn on screen while those modes are on; the keys work without it |
| [`opx77_core`](../opx77_core/index.md) | the character rows: record, job, gang, money, save, characters online |
| [`opx77_appearance`](../opx77_appearance/index.md) | the readiness gate opening at all — see [Nothing touches a body behind a closed gate](#readiness-gate) |
| [`opx77_weather`](../opx77_weather/index.md) | the weather and time screens |
| [`opx77_inventory`](../opx77_inventory/index.md) | every weapon command but the holster, and every inventory command and menu row. It must list `opx77_admin` in its [`EXPORTS.WRITERS`](../opx77_inventory/config.md#exports), as it ships |
| `open77_weapons` | the holster: its client half answers the relay |

The client half says so once per resource, the first time a row needs it:

```text
opx77_menu is not running; the staff menu cannot use it
opx77_prompts is not running; the travel controls are not drawn
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
Open77.weapons is unavailable on this host: the holster refuses
```

`opx77_inventory` — [`INVENTORY.RESOURCE`](config.md#inventory) — is looked for
five seconds after start, in a thread rather than at file scope, because a
resource listed after this one is not running yet at load:

```text
opx77_inventory is not running: the weapon and inventory commands refuse until it is
```

When the server half has registered everything it logs one line, and the count
in it is the number of commands on [Commands](commands.md):

```text
ready -- 44 restricted commands; grant command.opx77.admin to open the menu
```

The server clock is `Open77.time.monotonic`. When it cannot be read the server
half falls back to `GetGameTimer`, logged once, so the command floors, the
catalogue cache and the holster requests keep expiring; only when both fail is
the last reading held:

```text
Open77.time.monotonic unreadable; falling back to GetGameTimer
```

The client half has no such fallback, since `GetGameTimer` is server-only: it
keeps its last reading.

## Nothing touches a body behind a closed gate {#readiness-gate}

Every teleport, kill, heal, revive, god toggle, health or armour write, holster
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
stuck on the loading screen must still be removable. Neither is a change to a
bag — a weapon, ammunition or inventory command other than the holster — which
`opx77_inventory` makes in its own records and pushes when the player is there
to see it.

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

- **A target is a player id, or `me`.** `self` is read as `me`. A command that
  acts on a body takes nothing else. The weapon, ammunition and inventory
  commands but the holster take a **holder** instead: a player id, `me`, or a
  citizen id, which also reaches a character that is not in the world —
  `opx77_inventory` resolves it through the core and loads that bag for the
  call. See [Targets](commands.md#targets).
- **A vehicle with somebody aboard** is never removed, and never given a `full`
  or `mechanical` repair, both of which may respawn it. Occupancy is read at the
  moment of the command.
- **Catalogues are allowlists.** Only a row of `data/vehicles.lua` is ever
  spawned, and only an item of `opx77_inventory`'s catalogue is ever given,
  whatever a client types; the inventory checks the name again — see
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
`self.noclip`. A disconnect clears both switches and the chosen speed, so a
recycled player id does not inherit them, and both halves turn them off on this
resource's stop.

### The speed keys and the controls {#noclip-keys}

The staff menu has no speed row. While noclip is on, Page Up and Page Down —
[`KEYS.SPEED_UP`](config.md#keys) and [`KEYS.SPEED_DOWN`](config.md#keys) —
raise and lower the speed by [`NOCLIP.STEP`](config.md#noclip) of itself,
repeating while held, between `NOCLIP.MIN_SPEED` and `NOCLIP.MAX_SPEED`. With
noclip off they do nothing.

**A key only chooses a number.** Once the keys have been quiet for
`NOCLIP.SEND_AFTER_MS` — never less than `RATE.ACTION_MS` plus 100 ms — the
client sends one [`opx77.admin.self.speed`](commands.md#self-speed) line, so a
held key is one command, the host resolves the ACL for it like a typed one, and
the native is set only by the server's answer. An accepted change is not
toasted; a refused one is, and puts the read-out back. The mouse wheel is not
used: no client call on this platform reports it.

While noclip is on and the player is alive,
[`opx77_prompts`](../opx77_prompts/index.md) draws the controls in its corner
strip: move, up and down, the speed keys with the current speed, the native's
`SHIFT` and `ALT` modifiers, and the menu key that leads to the **Noclip** row
that turns it off. Map travel gets one row while armed. They come down when the
mode goes off, when the native reports noclip off, on death, and with this
resource. [`NOCLIP.PROMPTS`](config.md#noclip) `= false` draws none.

## Weapons and bags {#weapons-and-bags}

[`opx77_inventory`](../opx77_inventory/index.md) is the only record of what a
character carries. A weapon is one of its items, drawn by the player from the
bag, and the inventory takes off, every
[`WEAPONS.SCAN_MS`](../opx77_inventory/config.md#weapons), any weapon in a game
slot that no item backs. So no command here puts a record in a game slot any
more. Each one calls the inventory's server exports:

| Action | Goes through | Permission |
|---|---|---|
| [`weapon.give`](commands.md#weapon-give) | `CanCarry`, then `AddItem(holder, weapon, 1, { ammo = 0 })`. With ammunition: `GetInventory` and `CanCarry` for both first, then the two `AddItem`, and `RemoveItem` of that very weapon, by its serial, when the second is refused | `command.opx77.admin.weapon.give` |
| [`weapon.giveammo`](commands.md#weapon-giveammo) | `GetItems`, `CanCarry`, `AddItem(holder, ammo, count)` | `command.opx77.admin.weapon.giveammo` |
| [`weapon.ammo`](commands.md#weapon-ammo) | `GetInventory`, then `CanCarry` and `AddItem` per ammunition type the bag's weapons take; no weapon item is written | `command.opx77.admin.weapon.ammo` |
| [`weapon.remove`](commands.md#weapon-remove) | `GetInventory`, `RemoveItem` per weapon name and count; the inventory holsters a drawn one itself | `command.opx77.admin.weapon.remove` |
| [`weapon.read`](commands.md#weapon-read) | `GetInventory`, `GetHeldWeapon` | `command.opx77.admin.weapon.read` |
| [`weapon.holster`](commands.md#weapon-holster) | the relay's `holster` | `command.opx77.admin.weapon.holster` |
| [`inventory.view`](commands.md#inventory-view) | `GetInventory`, every page | `command.opx77.admin.inventory.view` |
| [`inventory.give`](commands.md#inventory-give) | `GetItems`, `CanCarry`, `AddItem` | `command.opx77.admin.inventory.give` |
| [`inventory.remove`](commands.md#inventory-remove) | `RemoveItem` | `command.opx77.admin.inventory.remove` |
| [`inventory.clear`](commands.md#inventory-clear) | `ClearInventory` | `command.opx77.admin.inventory.clear` |
| Open the bag beside mine | the inventory's [`opx77.inventory.open`](../opx77_inventory/commands.md#open) | `command.opx77.inventory.open` |
| Who holds an item | the inventory's [`opx77.inventory.holders`](../opx77_inventory/commands.md#holders) | `command.opx77.inventory.holders` |
| The item, weapon and ammunition pickers | `GetItems`; the removal picker `GetInventory` | the menu's grant, and the view or remove grant for a bag |

**Why these are this resource's commands, and those two are links.** The menu
drives another resource's own command where that resource publishes no door this
one may use: `opx77_core` gives it no writing export for a job or money, so
those rows run `opx77.job` and `opx77.money`. `opx77_inventory` does: it lists
`opx77_admin` in `EXPORTS.WRITERS`. So a weapon or bag action is a command here,
gated on `command.opx77.admin.…` like every other staff action, audited in this
resource's ledger and answered in its toasts, and it calls the inventory's
exports, which check every argument again. Opening another character's bag on a
staff screen and listing an item's holders have no export — the second is a
query the inventory makes with the core's inventory scope, which only it holds —
so those two rows run the inventory's commands, gated on
`command.opx77.inventory.…`. Either way the host resolves the grant before
anything runs.

!!! warning "Five grants create things"

    `command.opx77.admin.inventory.give` and `command.opx77.inventory.give` both
    create items out of nothing, `command.opx77.admin.weapon.give` creates
    weapons, and `command.opx77.admin.weapon.giveammo` and
    `command.opx77.admin.weapon.ammo` create ammunition items, as `weapon.give`
    does with its third argument. Grant them like money.

**Ammunition is an item, not a number on the weapon.** A weapon is given with 0
rounds. Its rounds are ammo items of the inventory's catalogue — `ammo_handgun`,
`ammo_rifle`, `ammo_shotgun`, `ammo_sniper` as it ships — which the player uses,
from the bag or a hotbar slot, while the weapon that takes them is drawn: the
inventory loads it up to that ammunition's `AMMO.MAX` and spends the items. No
command here writes a weapon item's rounds.

**What stays on the relay, and why.** The inventory has no export that
holsters, so the holster is still the platform's `Open77.weapons.holster`: it
changes no item and leaves the weapon in its slot. Nothing else uses the relay:
a refill only adds ammunition items, which the player loads themselves.

**Without `opx77_inventory`** — stopped, or its exports answering
`export_not_found` or not at all — every weapon command but the holster and every
inventory command answers `inventory_unavailable`, and the menu greys the weapon
rows and hides the inventory ones. There is **no fallback to the relay**: this
resource cannot read the running inventory's
[`WEAPONS.REMOVE_UNBACKED`](../opx77_inventory/config.md#weapons), and a weapon
put in a slot while the inventory is down is exactly the unbacked weapon it
removes once it is back, or keeps unrecorded when that is off.
`inventory_denied` means `opx77_admin` is not in its `EXPORTS.WRITERS`, and the
toast says so.

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
- `message` is the English detail — the coordinates of a move, the weapon,
  holder and ammunition of a weapon give, the reason of a kick — cut to 120
  characters, with control characters replaced so a name cannot forge a second
  log line.

A ring of the last [`AUDIT_ENTRIES`](config.md#audit-entries) actions is kept in
memory for [`opx77.admin.read.audit`](commands.md#audit). **The log is the
record**; the ring dies with the process.

Not every refusal is written. A usage error, a malformed argument, `too_fast`
and a target that does not resolve are answered to the operator and not
audited; the gate's refusals, a native's, the relay's, a failed placement and
every refusal that comes back from `opx77_inventory` are, and so is a weapon
taken back out of a bag because its ammunition was refused. Reading a bag with
[`inventory.view`](commands.md#inventory-view) is audited too: somebody's
belongings were read.

## Where the pieces live {#layout}

| File | Does |
|---|---|
| `config.lua` | shared. Keys, rates, placement, noclip, announcements, vehicles, the inventory, the linked commands, the sky lists, the destinations |
| `data/vehicles.lua` | shared. The vehicle catalogue, and the allowlist: 271 vehicles in ten classes |
| `data/weapons.lua` | shared. The weapon classes only: their menu order and their label |
| `shared/catalog.lua` | shared. The index over both files; names a malformed row at boot |
| `shared/catalog-1.lua` … `shared/catalog-4.lua` | shared. Index the vehicle rows 68 to a part, so no script's load runs near the host's deadline — see [Catalogue parts](config.md#catalogue-parts) |
| `shared/text.lua`, `shared/locale.lua` | shared. Cleaning and cutting text, and the `locale(key, params)` every file below calls |
| `locales/en.lua`, `locales/fr.lua` | shared. Player-facing text, keyed `admin.<thing>` |
| `server/main.lua` | answers, the audit, the readiness gate, placement, the clock, and the one registry every command goes through |
| `server/players.lua` | yourself, other players, noclip and map travel, moderation |
| `server/vehicles.lua` | spawn, give, repair, flag, remove, clean up |
| `server/inventory.lua` | the bridge to `opx77_inventory`'s server exports, its catalogue, and the four inventory commands; before `weapons.lua` and `menu.lua`, which call through it |
| `server/weapons.lua` | give, ammunition, refill, take and read weapon items through `server/inventory.lua`; the holster over the platform's weapon relay |
| `server/world.lua` | destinations, announcements, and the read commands |
| `server/menu.lua` | the opener command and the refresh event; loaded last, because the access map it sends lists what the others registered |
| `client/main.lua` | the command channel, answers, export calls and the travel capabilities |
| `client/keys.lua` | the key mappings and their rebinds |
| `client/controls.lua` | the noclip speed keys and the travel controls in `opx77_prompts`' strip |
| `client/forms.lua`, `client/menu.lua` | the forms on `opx77_input`, the menu screens on `opx77_menu` and the menu key |
| `client/exports.lua` | the three public exports, loaded last |
| `std/types.lua`, `std/**` | not loaded. The LuaLS classes — see [Types](types.md) — and one stub file per code file |
| `docs/ARCHITECTURE.md` | not loaded. Why the code is written the way it is, in French |

## The menu {#menu}

`/opx77.admin` or the menu key, F9 as shipped, opens it; the arrow keys move,
Enter chooses, Backspace goes back a screen. Running it again, or pressing the
key, closes it.

- **Each screen is its own `opx77_menu` menu**, not a submenu of one tree.
  `opx77_menu` refuses a spec past 400 rows across the whole tree, and a roster
  of thirty players with twenty actions each is past it; the stack of screens
  lives in this resource.
- **A vehicle, weapon or item list is drawn twenty rows at a time**, with a
  **More** row to the next page: `opx77_menu` checks every row it is handed in
  one client handler, and the host stops a handler that runs past 10 000 VM
  instructions. The roster, the destination lists, the ammunition picker and a
  bag's stacks are cut at 190 rows instead, under the menu's 200 a level, to
  leave room for the navigation.
- **A row whose command the ACL refuses is drawn greyed**, with *no access*
  beside it. The access map is a hint for drawing and nothing more; the host
  still resolves every line. It is re-read when you leave the root screen, so an
  `acl.reload` shows without reopening. On a host with no ACL reader every row
  is drawn enabled and the host answers for each one.
- **A command's answer is written under the list**, and also raised as a
  toast, or a chat line for a report — see
  [How a command answers](commands.md#answers). A refusal from the host — no
  grant — is written there in words, and `opx77_chat` toasts it. Only an answer
  to a command the menu sent in the last fifteen seconds goes under the list,
  and only its first line, cut to 116 bytes on a whole character.
- **Kill, kick, ban, taking every weapon, emptying a bag, the vehicle cleanup,
  an announcement and saving every character** go through a confirmation screen
  with Cancel first. Nothing else does.
- **Forms are `opx77_input`'s.** The menu steps aside while one is up and comes
  back where it was. The job and gang forms read their options from
  `opx77_core`'s `GetJobs` and `GetGangs`, and the money form its currencies
  from `GetSharedConfig`.
- **A player's INVENTORY rows**, drawn only while `opx77_inventory` runs:
  *Show the bag in chat* ([`inventory.view`](commands.md#inventory-view));
  *Open the bag beside mine*, which runs
  [`LINKS.INVENTORY_OPEN`](config.md#links) and closes the menu for the
  inventory's screen; *Give an item*, a category and an item of the inventory's
  catalogue, then a count; *Take an item*, a stack of that bag — read again each
  time the screen opens — then a count; *Empty the bag*. The **Server** screen
  adds *Who holds an item*, a category and an item that run
  [`LINKS.INVENTORY_HOLDERS`](config.md#links). A picker row is greyed when the
  ACL refuses the command it ends in.
- **The weapon rows** — give a weapon, give ammunition, refill ammunition,
  holster, take every weapon, weapons in the bag — are drawn on a player's
  **ITEMS** rows and on the **Weapons** screen. Every one but the holster is
  greyed *unavailable* while `opx77_inventory` is not running, and the holster
  while `Open77.weapons` is missing. The weapon picker lists the inventory's
  weapon items grouped by the classes of `data/weapons.lua`, in that file's
  order, then any class it does not name, under its key; a weapon row gives it
  empty. *Give ammunition* lists the catalogue's ammunition items, then opens a
  count form that starts at one full load; *Refill ammunition* gives one full
  load of each ammunition the bag's weapons take. A picker whose list has not
  arrived shows *Loading...*, and *opx77_inventory did not answer.* when it
  could not be had.
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
| Noclip speed on the mouse wheel | No client call reads the wheel; the speed is on two rebindable keys instead. |
| Invisibility | No binding hides a player from other clients. |
| Unban | No Lua binding lifts a ban; the server console's `unban <identity>` does. |
| A citizen id as a `<player>` | Those commands act on a body, which needs a connected player id. A bag is reached by citizen id: `opx77_inventory` resolves it. |
| A fallback to the weapon relay without `opx77_inventory` | A weapon put in a slot with no item is the unbacked weapon the inventory removes, or keeps unrecorded. See [Weapons and bags](#weapons-and-bags). |
| Destinations that survive a restart | That would need the database, and a staff tool must not require one. `self.pos` copies a config row. |
| A full vehicle catalogue | No enumeration binding exists; the shipped list is a copy of the platform's own catalogue, and an allowlist. Weapons and items are `opx77_inventory`'s catalogue. |
| Short aliases like `/tp`, `/noclip` | Each alias is a separate permission, and a bare name can shadow another resource's command. |
| Its own job, money and weather commands | `opx77_core` and `opx77_weather` own those, and are already ACL-gated. |
| Ping in the roster | Lua has no reader for it. |

## Pages {#pages}

- [Commands](commands.md) — all forty-four, their arguments, their refusals,
  and the permissions to grant.
- [Configuration](config.md) — every key of `OPX_ADMIN_CONFIG`, the two
  data files, the catalogue parts and the locale catalogue.
- [Exports](exports.md) — the three client exports.
- [Events](events.md) — the nine private net events, and the platform events
  both halves use.
- [Types](types.md) — the refusal codes and the shapes on the wire, from
  `std/types.lua`.

## See also {#see-also}

- [Getting started](../../guides/getting-started.md#acl) — writing `acl.jsonc`.
- [`opx77_core` commands](../opx77_core/commands.md) — the character, job, gang
  and money commands the menu drives.
- [`opx77_weather` commands](../opx77_weather/commands.md) — the sky and clock
  commands the menu drives.
- [`opx77_prompts`](../opx77_prompts/index.md) — the strip the noclip controls
  are drawn in.
