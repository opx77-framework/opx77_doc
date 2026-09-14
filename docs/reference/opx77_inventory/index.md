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
| **Version** | `0.1.0` |
| **Requires** | `open77_version ">=0.0.1"`, and `opx77_core` 0.4.0 or later running. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `reconnect` — swapping a live CEF surface mid-session is unstable, so a generation change reconnects |
| **Permissions** | `network.events`, `world.props`, `world.vehicles`, `players.life.read`, `acl.read`, `input.actions` |
| **Sides** | server, which holds every container and decides every move; client, which draws the screen, registers the keys and publishes the client exports |
| **Exports** | seventeen server exports and nine client exports — see [Exports](exports.md) |
| **Commands** | five, **every one** ACL-restricted, all renamable — see [Commands](commands.md) |
| **Keys** | the open key, `I`, and five hotbar keys, `4` to `8` — see [Keys](#keys) |
| **Optional at runtime** | the platform's `open77_weapons` (drawing a weapon), `open77_interactions` (the prompts at piles and stashes), `open77_contextmenu` (the trunk and glovebox rows); [`opx77_notify`](../opx77_notify/index.md), [`opx77_status`](../opx77_status/index.md), [`opx77_animations`](../opx77_animations/index.md) |

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
    with `Open77.exports.call("opx77_inventory", name, ...)`, and itself calls
    `opx77_core`'s. Some concept pages on this site still say a server VM has no
    `exports`; the code of this resource publishes and calls them, and this
    page follows the code.

## What it needs {#requirements}

- **`opx77_core` 0.4.0 or later**, running, with `opx77_inventory` listed in its
  `config/server.lua` `EXPORTS.CALLERS` with the `inventory` scope — the shipped
  default. The two inventory tables are its migrations `0005_inventories` and
  `0006_inventory_items`. Every request is refused while the core does not
  answer.
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
    menu, or set [`KEYS.OPEN`](config.md#keys) to a free key such as `F7`.

## Weapons {#weapons}

`data/weapons.lua` is a fixed list: seventeen weapons in nine classes, and four
ammunition items, each with the `MAX` rounds one weapon of that type holds. A weapon is one unit per slot, with a `serial` and its loaded `ammo` in
its metadata; it is given a serial when added.

- **Use** draws it: the relay puts its record in
  [`WEAPONS.SLOT`](config.md#weapons), drawn, then states the rounds the item
  carries, magazine first. **Use again** reads the rounds back and takes it out.
- **An ammunition item used** loads the drawn weapon that takes it, up to that
  type's `MAX`; the item is spent at once.
- **The item is the ledger.** While drawn, the rounds are read back every
  `AMMO_SYNC_MS` and the item only ever goes down to that reading.
- **The item leaving the bag** — moved, dropped, handed over, taken — puts the
  weapon away at once.
- **A weapon nothing backs** — one put in a slot by anything but this resource,
  one taken from the game's own screen — is taken off every `SCAN_MS` while
  `REMOVE_UNBACKED` is on.

`opx77_admin`'s weapon commands give, refill and take these items through this
resource's exports — see
[Weapons and bags](../opx77_admin/index.md#weapons-and-bags). The platform
refuses grenades, heavy weapons and arm cyberware in these slots, so none is
listed. Weapon attachments and the workshop are not part of this resource.

## Who a player is {#identity}

The server half never takes a citizen id from a client. It reads
`opx77_core`'s `GetChanges` cursor once a second: a character entering the world
loads its bag and pushes it, a character leaving puts its weapon away, closes
what it had open, and writes and forgets its bag. After this resource starts,
and after the core reloads, every player the host knows is asked about.

**Nothing acts on a player whose readiness gate is closed**: the screen does not
open, nothing is used, drawn, handed over or dropped. Exports that only change a
container are not gated.

## Saving {#saving}

A change marks its container unwritten. Once the container has been quiet for
[`SAVE.DELAY_MS`](config.md#save), the sweep writes it through the core — up to
`SAVE.BATCH` containers in one transaction — and a failed write stays marked and
is tried again. A bag is also written before it is forgotten.

!!! warning "A stop writes nothing"

    A stopping server VM cannot call another resource's exports, so the last
    `SAVE.DELAY_MS` of changes cannot be written on the way out. What is still
    unwritten is handed to the host with `Open77.state`: a reload gives it to
    the next start, which writes it before it reads anything, and a stop drops
    it. Keep `SAVE.DELAY_MS` short.

    ```text
    stopping with 3 container(s) not yet written
    ```

Piles on the ground and the storage of a vehicle the core did not spawn live in
memory only, and a restart clears them.

## Events {#events}

Local client events, raised with `TriggerEvent` on the host-wide bus: listen with
a bare `AddEventHandler`. Any resource can raise these names, so check a
payload's shape.

| Event | Raised when |
|---|---|
| `opx77:inventory:changed` | the server pushed this player's bag |
| `opx77:inventory:used` | a use went through |
| `opx77:inventory:armed` | a weapon was drawn or put away |
| `opx77:inventory:opened` | the screen opened |
| `opx77:inventory:closed` | the screen closed |

The net events between the two halves — `opx77_inventory:hello` and
`opx77_inventory:request` up, `:answer`, `:own`, `:container`, `:open`, `:close`
and the rest down — are private and not a contract.

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
  bounds.
- [Exports](exports.md) — the server and client exports, and the error codes.

## See also {#see-also}

- [`opx77_admin`](../opx77_admin/index.md#weapons-and-bags) — the staff menu's
  weapon and bag commands, which call this resource's exports.
- [Getting started](../../guides/getting-started.md#restricted-commands) —
  every restricted command on a full install.
