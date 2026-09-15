---
title: The opx77_inventory resource
description: opx77_inventory is the inventory of OPX//77 — a bag of slots and grams per character, stashes, vehicle storage and piles on the ground on one screen, weapons as items, five restricted staff commands, and server exports that other resources change a bag through, all stored by opx77_core.
---

# opx77_inventory

A character carries a bag of slots with a weight limit. Stashes, vehicle trunks
and gloveboxes, and piles on the ground sit beside it on one screen; items are
dragged, stacked, split, used, handed over and dropped. Weapons are items: using
one draws it.

| At a glance | |
|---|---|
| **Version** | `0.3.0` |
| **Requires** | `open77_version ">=0.0.1"`, and `opx77_core` 0.4.0 or later running. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `reconnect` — swapping a live CEF surface mid-session is unstable, so a generation change reconnects |
| **Permissions** | `network.events`, `world.props`, `world.vehicles`, `players.life.read`, `acl.read`, `input.actions` |
| **Sides** | server, which holds every container and decides every move; client, which draws the screen, registers the keys and publishes the client exports |
| **Exports** | seventeen server exports, nine client exports and four context menu callbacks — see [Exports](exports.md) |
| **Commands** | five, **every one** ACL-restricted, all renamable — see [Commands](commands.md) |
| **Keys** | the open key, `I`, and five hotbar keys, `4` to `8` — see [Keys](#keys) |
| **Optional at runtime** | the platform's `open77_weapons` (drawing a weapon), `open77_interactions` (the prompts at piles and stashes), `open77_contextmenu` (the trunk and glovebox rows); [`opx77_notify`](../opx77_notify/index.md) (staff command answers), [`opx77_status`](../opx77_status/index.md), [`opx77_animations`](../opx77_animations/index.md) |

!!! danger "The server is the only authority on what a container holds"

    The screen predicts a move and draws it at once; the server checks it again
    — the slot, the stack, the weight, the reach, the readiness gate — and
    answers. A refusal rolls the prediction back. Nothing a client sends is a
    citizen id, a position or a count taken on its word.

**It owns no table.** Every container and every stack is stored by
[`opx77_core`](../opx77_core/index.md), in `opx77_inventories` and
`opx77_inventory_items`, through the core's server exports. The manifest asks
for no `database.access`: the core writes every row.

!!! info "Server exports"

    This resource publishes server exports, called from another server resource
    with `Open77.exports.call('opx77_inventory', name, ...)`, and itself calls
    [`opx77_core`'s](../opx77_core/exports/server.md) —
    [`GetIdentity`](../opx77_core/exports/server.md#getidentity),
    [`GetChanges`](../opx77_core/exports/server.md#getchanges),
    [`GetVehiclePlate`](../opx77_core/exports/server.md#getvehicleplate) and the
    `Inventory*` family, from
    [`InventoryEnsure`](../opx77_core/exports/server.md#inventoryensure) to
    [`InventoryHolders`](../opx77_core/exports/server.md#inventoryholders).

## What it needs {#requirements}

- **`opx77_core` 0.4.0 or later**, running, with `opx77_inventory` listed in its
  `config/server.lua` `EXPORTS.CALLERS` with the `inventory` scope — the shipped
  default. The core creates both inventory tables at boot, when they do not
  exist, from its single schema (`server/storage/schema.lua`); there is nothing
  to import. Every request is refused while the core does not answer.
- **`open77_weapons`**, for drawing a weapon from the bag. Without it a weapon
  use times out, and five seconds after start the server says so:

```text
open77_weapons is not running: its client half answers weapon requests, so drawing a weapon from the bag times out
```

Each optional resource in the table above costs its own feature and nothing
else.

Install it **after** `opx77_core` in `resources.load`: no dependency is
declared, so the host does not order them. It also waits and retries while the
core boots, for up to a minute, and says in its boot line whether the core
answered:

```text
ready: <n> item(s), 0 stash(es), bag 40 slots / 30000 g; core answering; commands: opx77.inventory.give, opx77.inventory.remove, opx77.inventory.clear, opx77.inventory.open, opx77.inventory.holders
```

When it did not, one error follows, naming the core resource and what to fix:

```text
opx77_core is not answering: no bag can be loaded until it does. Start it, and list opx77_inventory in its EXPORTS.CALLERS with the inventory scope.
```

## Keys {#keys}

| Mapping id | Name in the pause menu | Default | Does |
|---|---|---|---|
| `opx77_inventory.open` | *Inventory: open or close* | `I` | opens the screen; beside a pile it opens the pile with it, seated in a vehicle its glovebox; closes it when it is up |
| `opx77_inventory.hotbar1` … `hotbar5` | *Inventory: use hotbar slot n* | `4` … `8` | uses the item in bag slot n, the screen closed |

All are declared with `RegisterKeyMapping`, so every player rebinds them in the
pause menu's key bindings tab. [`KEYS.OPEN` and `KEYS.HOTBAR`](config.md#keys)
set the defaults; `false` registers none. A press while chat, a form or the
pause menu holds the keyboard does nothing. The hotbar starts at `4` because `1`
to `3` are the game's weapon slots, which this resource drives.

The defaults sit clear of the rest of a stock set: `F2` wardrobe, `F3` animation
picker, `F5` appearance panel, `F6` and `F7` perspective (`F7` is the platform's
native third person), `F8` HUD, `F9` staff menu, `F11` voice mode, `X` stop
animation, `V` push-to-talk, `ALT` context menu, `²` the terminal.

**The open key closes the screen too.** While the screen is up it holds the
keyboard itself, so no mapping fires: Escape closes it, and so does the open
key, read by the page. Lua sends the page the key the player actually has, from
`Open77.input.keyFor`, and again whenever `open77:keybinds:changed` says a key
was rebound. The page closes on the key's **release**, of a press it saw go
down — so the press that opened the screen, and its repeats, never close it
again — and ignores the key while one of its own text fields has focus.

!!! warning "`I` is also the game's own backpack key"

    A mapping never hides its key from the game, and the platform's
    `Open77.input.setNativeActionBlocked` blocks only the map (`OpenMapMenu`),
    so this resource cannot keep the game from seeing the press. If a build
    opens the game's backpack behind the screen, rebind the mapping in the pause
    menu, or set [`KEYS.OPEN`](config.md#keys) to a free key such as `F10`.
    Not `F6` or `F7`: the platform uses both for the camera perspective, and a
    mapping on either would switch the camera as well.

## Piles and stashes {#piles}

A pile on the ground and a configured stash each get a prompt from
`open77_interactions`, marked in the screen's accent colour:

| Prompt | Key | Shown within | Opens |
|---|---|---|---|
| a pile | [`DROPS.PROMPT_KEY`](config.md#drops), `E` | [`REACH.DISTANCE`](config.md#reach); registered within `DROPS.PROMPT_RADIUS` | that pile beside the bag |
| a stash from [`STASHES`](config.md#stashes) | [`STASH.PROMPT_KEY`](config.md#stashes), `E` | `REACH.DISTANCE` | that stash beside the bag |

**The open key finds a pile too.** Pressed within `REACH.DISTANCE` of a known
pile, it asks the server to open the nearest one; the server looks from its own
position, in the player's routing bucket, and checks reach again. A drop joins
an existing pile only within the shorter [`DROPS.DISTANCE`](config.md#drops).

Pile prompts follow the character: none is created before the server has pushed
a bag, and every one is removed when the character unloads. The server sends a
joining client the list of piles in parts of 64, and every client one event per
pile added or removed.

!!! note "Piles of every routing bucket"

    The client receives the piles of every bucket and has no reading of its own,
    so a pile in another bucket at the same spot still shows a prompt; the
    server refuses to open it, and the open key falls back to the bag alone.
    Stash prompts stay registered while no character is loaded; using one then
    is refused, or opens nothing on screen.

## Weapons {#weapons}

`data/weapons.lua` is a fixed list: the **189** weapons of the weapon catalogue
the platform's `open77_admin` ships for build 2.31, in nine classes, and four
ammunition items. A weapon is one unit per slot, with a `serial` and its loaded
`ammo` in its metadata; it is given a serial when added.

| Class | Weapons | Loaded by |
|---|---|---|
| `handgun` | 41 | `ammo_handgun` |
| `revolver` | 17 | `ammo_handgun` |
| `smg` | 18 | `ammo_rifle` |
| `rifle` | 18 | `ammo_rifle` |
| `precision` | 7 | `ammo_rifle` |
| `lmg` | 4 | `ammo_rifle` |
| `sniper` | 12 | `ammo_sniper` |
| `shotgun` | 20 | `ammo_shotgun` |
| `melee` | 52 | nothing |

| Ammunition item | Grams | `MAX` |
|---|---|---|
| `ammo_handgun` | 10 | 500 |
| `ammo_rifle` | 12 | 900 |
| `ammo_shotgun` | 30 | 190 |
| `ammo_sniper` | 25 | 170 |

Double-barrels are shotguns; blades, knives and blunt weapons are melee. `MAX` is
the most rounds one weapon of that type holds, magazine included. The engine
caps each ammunition type below a ceiling of its own (handgun past 520, rifle
under 1000, sniper 175, shotgun 200) and refuses a load above it, so keep `MAX`
under it.

- **Use** draws it: the relay puts its record in
  [`WEAPONS.SLOT`](config.md#weapons), drawn, then states the rounds the item
  carries, magazine first. **Use again** reads the rounds back and takes it out.
- **An ammunition item used** loads the drawn weapon that takes it, up to that
  type's `MAX`; the item is spent at once.
- **The item is the ledger.** While drawn, the rounds are read back every
  `AMMO_SYNC_MS` and the item only ever goes down to that reading. A weapon
  handed over between two readings keeps the rounds fired since the last one.
- **The item leaving the bag** — moved, dropped, handed over, taken — puts the
  weapon away at once.
- **A weapon nothing backs** — one put in a slot by anything but this resource,
  one taken from the game's own screen — is taken off every `SCAN_MS` while
  `REMOVE_UNBACKED` is on.

**The catalogue is indexed in parts.** The host rolls the whole resource set back
when one script's load runs past its deadline, which it checks every 10 000 VM
instructions, and a weapon costs about 160. The weapons are indexed forty to a
file, `shared/catalog-1.lua` to `shared/catalog-5.lua`; past two hundred weapons,
add a part to `open77.lua` for every forty more, and a boot line says when the
last part carried more than its share:

```text
data: data/weapons.lua: 43 weapons were left to the last catalogue part; add a shared/catalog-<n>.lua part to open77.lua for every 40 weapons past it
```

For the same reason the screen is sent the catalogue forty entries at a time.

`opx77_admin`'s weapon commands give, refill and take these items through this
resource's exports — see
[Weapons and bags](../opx77_admin/index.md#weapons-and-bags). The platform
refuses grenades, heavy weapons and arm cyberware in these slots, so none is
listed. Weapon attachments and the workshop are not part of this resource.

## Who a player is {#identity}

The server half never takes a citizen id from a client. It reads
`opx77_core`'s `GetChanges` cursor once a second: a character entering the world
loads its bag and pushes it, a character leaving puts its weapon away, closes
what it had open, and writes and forgets its bag. A client's hello — on its
start, and when the core says a character loaded — only makes the server ask
the core's `GetIdentity` again. After this resource starts, and after the core
reloads, every player the host knows is asked about.

**Nothing acts on a player whose readiness gate is closed**: the screen does not
open, nothing is moved, split, sorted, used, drawn, handed over or dropped, and
no pile, stash or vehicle storage opens. Exports that only change a container
are not gated, and neither are the staff commands.

## Saving {#saving}

A change marks its container unwritten. Once the container has been quiet for
[`SAVE.DELAY_MS`](config.md#save), the sweep writes it through the core — up to
`SAVE.BATCH` containers in one transaction — and a failed write stays marked and
is tried again. A bag is also written before it is forgotten; one that cannot be
written then, a character leaving while the core is down, stays in memory until
the sweep writes it.

The server times these delays, the rate limit and the cooldowns with
`Open77.time.monotonic`. Should it stop answering, the server falls back to
`GetGameTimer` and says so once, so no window or wait freezes:

```text
Open77.time.monotonic unreadable; falling back to GetGameTimer
```

!!! warning "A stop writes nothing"

    A stopping server VM cannot call another resource's exports, so the last
    `SAVE.DELAY_MS` of changes cannot be written on the way out. What is still
    unwritten is handed to the host with `Open77.state`: a reload gives it to
    the next start, which writes it before it reads anything, and a stop drops
    it. The host keeps 64 KiB across a reload: past about 60 KB of encoded
    stacks nothing is carried, and the error log says so. Keep
    `SAVE.DELAY_MS` short.

    ```text
    stopping with 3 container(s) not yet written
    ```

Piles on the ground and the storage of a vehicle the core did not spawn live in
memory only, and a restart clears them. A pile's prop is created with a lifetime
of `DROPS.LIFETIME_MINUTES` plus two minutes, as a backstop to the sweep. A
trunk or glovebox opened while `opx77_core` does not answer is refused
(`core_unavailable`) rather than opened in memory, so nothing put in an owned
vehicle is lost.

## What a client is sent {#payloads}

A client decodes at most 1,024 JSON values per event, whatever the bytes. What
the server pushes stays under it:

- **A container** — a bag, a stash, a trunk — past 900 values or 40 KiB encoded
  is sent with each stack's metadata cut to the keys the screen draws
  (`serial`, `ammo`, `durability`, `label`, `description`); if it is still past
  900 values, the last rows are sent without metadata until it fits. The
  server keeps the whole metadata either way, and says so once per container:

    ```text
    container 12 is too heavy to push whole (21504 bytes, 896 values); metadata trimmed
    ```

- **The pile list** a client gets on joining goes in parts of 64 piles.
- **The catalogue** goes to the screen in writes of forty entries.

Display text the server shapes — a stash title, an item name a command echoes —
is cut on a character boundary, never inside a multi-byte UTF-8 character.

## Events {#events}

Local client events, raised with `TriggerEvent` on the host-wide bus: listen with
a bare `AddEventHandler`, no permission. Any resource can raise these names, so
check a payload's shape.

| Event | Payload | Raised when |
|---|---|---|
| `opx77:inventory:changed` | `{ inventory, changes = { { name, delta } } }` | the server pushed this player's bag |
| `opx77:inventory:used` | `{ name, slot, label, close, status?, animation? }` | a use went through |
| `opx77:inventory:armed` | `{ name, serial, slot }`, or `nil` when put away | a weapon was drawn or put away |
| `opx77:inventory:opened` | none | the screen opened |
| `opx77:inventory:closed` | none | the screen closed |

`inventory` is the bag as the server pushed it — `id`, `kind`, `title`, `slots`,
`maxWeight`, `weight`, and `items` as `{ slot, name, count, metadata }` — and
`changes` what it gained and lost since the previous push of the same bag. The
shapes are annotated in `std/types.lua` (`ContainerPayload`, `UsedPayload`).

The net events between the two halves — `opx77_inventory:hello` and
`opx77_inventory:request` up; `:answer`, `:own`, `:container`, `:secondary`,
`:nearby`, `:open`, `:close`, `:reset`, `:used`, `:armed`, `:drops`, `:drop` and
`:commandAnswer` down — and the prompt events `opx77_inventory:pilePrompt` and
`:stashPrompt` are private and not a contract.

## What is not here {#not-built}

| Wanted | Why not |
|---|---|
| Weapon attachments and the workshop | Out of scope. |
| Worn clothing as items | The clothing a character wears is already an authoritative record on this platform, changed from the game's own wardrobe. Mirroring it as items would make two authorities. |
| Money as an item | Money stays in `opx77_core`. |
| Shops | A shop is another resource: it charges through the core and calls [`AddItem`](exports.md#additem). |
| Job-gated stashes in `config.lua` | Open a job stash from the resource that knows the job, with [`OpenStash`](exports.md#server-openstash). |

## Pages {#pages}

- [Commands](commands.md) — the five staff commands, their arguments and their
  refusals.
- [Configuration](config.md) — every key of `OPX_INVENTORY_CONFIG`, with its
  bounds, and the catalogue.
- [Exports](exports.md) — the server and client exports, and the error codes.

## See also {#see-also}

- [`opx77_admin`](../opx77_admin/index.md#weapons-and-bags) — the staff menu's
  weapon and bag commands, which call this resource's exports.
- [Getting started](../../guides/getting-started.md#restricted-commands) —
  every restricted command on a full install.
