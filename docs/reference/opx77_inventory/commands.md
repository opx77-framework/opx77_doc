---
title: opx77_inventory commands
description: The five ACL-restricted staff commands opx77_inventory registers — give, remove, clear, open and holders — with their arguments, their refusals, how they answer and the permissions to grant.
---

# Commands

`opx77_inventory` registers five commands and **every one is restricted**: the
host resolves `command.<name>` against the caller's ACL before this resource
runs, and no handler checks a permission. Each action writes an `[audit]` line,
in the same `event=... severity=...` shape `opx77_core` writes, so one grep finds
both.

| Command | Key | Does |
|---|---|---|
| [`opx77.inventory.give`](#give) | `GIVE` | adds items to a bag |
| [`opx77.inventory.remove`](#remove) | `REMOVE` | takes items from a bag |
| [`opx77.inventory.clear`](#clear) | `CLEAR` | empties a bag |
| [`opx77.inventory.open`](#open) | `OPEN` | opens that bag beside your own, to take from it; in game only |
| [`opx77.inventory.holders`](#holders) | `HOLDERS` | lists the containers holding an item, largest stacks first |

Every name on this page is the **shipped default**, set in
[`COMMANDS`](config.md#commands); the ACL permission follows the name you give
it, and `false` registers none. The chat offers each one, with its arguments,
only to a player the ACL grants it — without an ACL reader on the host, to
nobody.

!!! warning "`opx77.inventory.give` creates items out of nothing"

    Grant `command.opx77.inventory.give` like money.

```jsonc
// acl.jsonc: a principal who may search bags and list holders, but not create items
{
  "name": "moderator",
  "userId": "00000000-0000-0000-0000-000000000002",
  "publicKey": "…",
  "permissions": [
    "command.opx77.inventory.open",
    "command.opx77.inventory.holders"
  ]
}
```

[`opx77_admin`](../opx77_admin/index.md)'s menu runs `open` and `holders` for
its *Open the bag beside mine* and *Who holds an item* rows, so a staff principal
needs these two grants for the menu to offer them. Its own weapon and inventory
commands call this resource's [exports](exports.md) instead.

## How a command answers {#answers}

A command answers the player who ran it on `open77:command:result`, in the
catalogue [`LOCALE`](config.md#locale) names. The same command at the **server
console** answers into the platform log in English — `info` when it succeeded,
`warn` when it was refused. **The sample lines on this page are the English
ones.**

`opx77_chat` prints no accepted answer of that event, so a success typed in the
chat box shows nothing there; a refusal it does show. `opx77_admin`'s menu
writes the answer to a command it sent under its list, and a
[`holders`](#holders) list to the chat box.

The same operator running the same command inside 400 ms is answered *Slow down
a little.* The console is never cooled.

### Targets {#targets}

A target is a **player id** — whose loaded character's bag is meant — or a
**citizen id**, which also reaches a character that is not in the world: that bag
is loaded for the command, written, and forgotten, unless somebody opened it
meanwhile.

| Refusal | English answer | When |
|---|---|---|
| `bad_target` | Give a player id or a citizen id. | not a positive player id, and not a word of at most 32 characters the core knows |
| `not_loaded` | That player has no character in the world. | a player id with no character loaded |
| `no_character` | No living character carries that citizen id. | the core answered `character.notFound` |
| `core_unavailable` | opx77_core is not answering. | the core did not answer |

`count` is a whole number from `1` to
[`MAX_COMMAND_COUNT`](config.md#commands), `1` when left out; anything else
answers *The count must be a whole number from 1 to 10000.*

A connected target other than the operator is told by toast what was done to
their bag.

## opx77.inventory.give {#give}

Adds items to a bag.

```text
opx77.inventory.give <playerId|citizenId> <item> [count]
```

- item: a name from `data/items.lua` or `data/weapons.lua`, without case.
  Anything else answers *No item called {item} in the catalogue.*
- count?: `integer` — default `1`.

A weapon is added one unit per slot, each with its own serial and no rounds.

| Refusal | English answer |
|---|---|
| `no_room` | That bag has no room for them. |
| `too_heavy` | That would make the bag too heavy. |

```text
Gave 2x Water to H7K-M4X3.
```

## opx77.inventory.remove {#remove}

Takes items from a bag.

```text
opx77.inventory.remove <playerId|citizenId> <item> [count]
```

- item: any item name — letters, digits, `_`, `-` and `.`, up to 48 — not only
  one the catalogue still carries.
- count?: `integer` — default `1`.

A bag holding fewer answers `not_enough`, *That bag does not hold that many.*

```text
Took 1x Water from H7K-M4X3.
```

## opx77.inventory.clear {#clear}

Empties a bag.

```text
opx77.inventory.clear <playerId|citizenId>
```

```text
Emptied the bag of H7K-M4X3: 4 stack(s).
```

## opx77.inventory.open {#open}

Opens a character's bag beside your own, on your inventory screen, to search it
and take from it.

```text
opx77.inventory.open <playerId|citizenId>
```

**In game only** — at the console it answers *That command has to be run in
game.* Aimed at yourself it answers *Open your own bag with the inventory key.*,
and without a character of your own loaded, `not_loaded`. Audited as
`inventory.search`.

```text
Searching the bag of H7K-M4X3.
```

## opx77.inventory.holders {#holders}

Lists the containers holding an item, largest stacks first — at most twenty.

```text
opx77.inventory.holders <item>
```

- item: any item name, as for [`remove`](#remove).

It asks `opx77_core`, which answers from its tables with the `inventory` scope
only this resource holds; `core_unavailable` when it does not answer. Each line
names the container's kind and owner, the slot and the count. Being a read of
the stored rows, it does not see piles on the ground or the memory-only storage
of a vehicle the core did not spawn, nor a change still inside
[`SAVE.DELAY_MS`](config.md#save).

```text
water: 2 container(s) hold it, largest first.
  character H7K-M4X3  slot 1  x12
  stash afterlife_locker  slot 4  x3
```

## See also {#see-also}

- [Configuration](config.md#commands) — renaming the commands, and the count
  ceiling.
- [`opx77_admin` commands](../opx77_admin/commands.md#inventory) — the staff
  menu's own bag commands.
