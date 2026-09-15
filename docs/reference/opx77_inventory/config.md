---
title: opx77_inventory configuration
description: Every key of OPX_INVENTORY_CONFIG with its shipped default and accepted range — the language, the core, bag and vehicle sizes, reach, the hotbar and the keys, use and rate limits, saving, piles on the ground, stashes and their prompt key, weapons, the tabs, the export callers and the staff commands.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_INVENTORY_CONFIG`.
**Every value shown on this page is the shipped default.** The file documents
each key with an `@field` line above the table.

!!! danger "Nothing in this file is a secret"

    `config.lua` is a `shared_script`, so every connecting player downloads it.
    Who may run a staff command lives in `acl.jsonc`; who may call a writing
    export is [`EXPORTS.WRITERS`](#exports).

`shared/settings.lua` reads the file once and checks every value: a wrong one is
a server warning at boot and its default, never a raise mid-request.

```text
config: BAG.SLOTS must be a whole number in 1..200; using 40
```

Weights are **whole grams** everywhere.

## LOCALE {#locale}

```lua
LOCALE = 'en',
```

**Type** `string` — `'en'` or `'fr'` as shipped. Player-facing text lives in
`locales/<code>.lua`, keyed `inventory.<thing>` and `item.<name>`; a key missing
from the active catalogue falls back to `en`, then to the key itself. Server
logs, the console's command answers and the error codes stay English. At boot,
a key one shipped catalogue has and the other lacks is a warning:

```text
locales/fr.lua is missing inventory.error.weapon_full
```

To add a language, copy `locales/en.lua` to `locales/<code>.lua`, change the
code in its `register` call, translate the values, add
`shared_script "locales/<code>.lua"` to `open77.lua` beside the others, and set
`LOCALE`.

## CORE {#core}

```lua
CORE = 'opx77_core',
```

The resource that stores every container, asked through its server exports.
Match a renamed folder.

## BAG {#bag}

A new character's bag.

```lua
BAG = { SLOTS = 40, MAX_WEIGHT = 30000 },
```

| Key | Range |
|---|---|
| `SLOTS` | `1`..`200` |
| `MAX_WEIGHT` | `0`..`4000000000` grams |

A bag keeps the size it was created with: raising these gives existing
characters nothing, and lowering them takes nothing away.

## Items {#items}

```lua
DEFAULT_ITEM_WEIGHT = 100,
MAX_STACK = 1000000,
MAX_METADATA_BYTES = 1024,
```

| Key | Range | Does |
|---|---|---|
| `DEFAULT_ITEM_WEIGHT` | `0`..`1000000` grams | the weight of a stored item the catalogue no longer carries; a value out of range is `100`, without a warning |
| `MAX_STACK` | `1`..`2147483647` | the most one slot holds of a stackable item |
| `MAX_METADATA_BYTES` | `64`..`4096` | one stack's metadata, encoded; the core refuses past 4096 |

## REACH {#reach}

```lua
REACH = {
	DISTANCE = 3.0,
	VEHICLE = 4.5,
},
```

| Key | Range | Does |
|---|---|---|
| `DISTANCE` | `0.5`..`25` m | to a stash, a pile on the ground, or a player handed something; also where a pile or stash prompt shows, and how near a pile the open key opens it |
| `VEHICLE` | `1`..`25` m | from a vehicle's centre, to reach its trunk; also the context menu rows' distance |

Reach is measured on the server, from its own position of the player, and needs
the same routing bucket.

## HOTBAR {#hotbar}

```lua
HOTBAR = {
	ENABLED = true,
	SLOTS = 5,
},
```

With `ENABLED` on, the first `SLOTS` bag slots — `0`..`9` — are used straight
from the hotbar keys, the screen closed. Only `false` turns it off, and then no
hotbar key is registered.

## KEYS {#keys}

The default keys, which each player can rebind in the pause menu.

```lua
KEYS = {
	OPEN = 'I',
	HOTBAR = { '4', '5', '6', '7', '8' },
},
```

| Key | Does |
|---|---|
| `OPEN` | open or close the inventory; beside a pile it opens the pile, seated a glovebox |
| `HOTBAR` | one key per hotbar slot, in order; a slot with no entry takes its default, the slot number plus three |

Each is a key name or `false`, which registers no mapping. A key name is `A`–`Z`,
`0`–`9`, `F1`–`F12`, `SPACE`, `ENTER`, `TAB`, `SHIFT`, `CTRL`, `ALT`,
`CAPSLOCK`, `BACKSPACE`, `INSERT`, `DELETE`, `HOME`, `END`, `PAGEUP`,
`PAGEDOWN`, `UP`, `DOWN`, `LEFT` or `RIGHT`. A hotbar key that is the open key is
not registered, with a warning:

```text
config: KEYS.HOTBAR[1] is the open key "I"; that hotbar key is not registered
```

`I` is also the game's own backpack key — see [Keys](index.md#keys) for what
that costs and how the page closes on it. To move `OPEN`, pick a free key such
as `F10`. **Not `F6` or `F7`**: the platform uses both for the camera
perspective (`F7` is native third person), and a mapping never hides its key
from the game, so the press would switch the camera too. `F5` is the appearance
panel's.

## USE_COOLDOWN_MS and USE_HANDLER_MS {#use}

```lua
USE_COOLDOWN_MS = 750,
USE_HANDLER_MS = 5000,
```

| Key | Range | Does |
|---|---|---|
| `USE_COOLDOWN_MS` | `0`..`60000` | the least time between two item uses by one player |
| `USE_HANDLER_MS` | `500`..`25000` | how long another resource's use handler may take before the use is refused |

## RATE_LIMIT {#rate-limit}

```lua
RATE_LIMIT = { WINDOW_MS = 1000, REQUESTS = 20 },
```

The requests one player may send from the screen per window — moves, uses,
opens, everything. `WINDOW_MS` is `100`..`60000`, `REQUESTS` `1`..`1000`.

Past `REQUESTS`, **every refused request is answered `too_fast`**, so the screen
never waits on a request nobody answers, up to twice `REQUESTS` refusals in the
window; a flood past that gets no answer until the window ends.

## SAVE {#save}

```lua
SAVE = {
	DELAY_MS = 2000,
	SWEEP_MS = 1000,
	BATCH = 16,
},
```

| Key | Range | Does |
|---|---|---|
| `DELAY_MS` | `0`..`600000` | a changed container is written this long after its last change |
| `SWEEP_MS` | `250`..`60000` | how often changed containers are looked for |
| `BATCH` | `1`..`64` | containers written in one transaction |

A stop writes nothing, so keep `DELAY_MS` short — see
[Saving](index.md#saving).

## DROPS {#drops}

Piles on the ground.

```lua
DROPS = {
	ENABLED = true,
	SLOTS = 25,
	LIFETIME_MINUTES = 30,
	MAX = 200,
	MAX_PER_CHARACTER = 10,
	COOLDOWN_MS = 1000,
	DISTANCE = 1.5,
	MODEL = 'crate.small',
	PROMPT_KEY = 'E',
	PROMPT_RADIUS = 20.0,
},
```

| Key | Range | Does |
|---|---|---|
| `ENABLED` | | players may leave items on the ground; only `false` turns it off |
| `SLOTS` | `1`..`200` | stacks one pile holds |
| `LIFETIME_MINUTES` | `1`..`10080` | a pile untouched this long is swept away, its contents with it |
| `MAX` | `1`..`2048` | piles on the server at once |
| `MAX_PER_CHARACTER` | `1`..`2048` | piles one character has made that still exist |
| `COOLDOWN_MS` | `0`..`60000` | the least time between two new piles by one player |
| `DISTANCE` | `0.1`..`10` m | a drop this close to a pile goes in that pile. Opening a pile uses [`REACH.DISTANCE`](#reach) |
| `MODEL` | | the world prop drawn for a pile: a curated `Open77.props` alias; `prop.catalog` in game lists them |
| `PROMPT_KEY` | key name | the key the pile's prompt answers to; `false` is `E`, since a prompt needs a key |
| `PROMPT_RADIUS` | `2`..`250` m | within which a pile's prompt is registered |

A joining player is sent every pile in parts of 64, so `MAX` up to its ceiling
reaches every client whole.

## TRUNK, GLOVEBOX and BIKES {#vehicles}

```lua
TRUNK = { SLOTS = 30, MAX_WEIGHT = 80000 },
GLOVEBOX = { SLOTS = 10, MAX_WEIGHT = 10000 },

BIKES = { PATTERNS = { 'sportbike', '_bike_' }, TRUNK_DIVISOR = 3 },
```

`SLOTS` is `0`..`200` — `0` gives none — and `MAX_WEIGHT` `0`..`4000000000`
grams. A record containing one of `BIKES.PATTERNS` is a two-wheeler: a trunk
divided by `TRUNK_DIVISOR` (`1`..`100`), and no glovebox. An owned vehicle keeps
its storage on its plate; any other vehicle's lives as long as the vehicle does.

## STASH and STASHES {#stashes}

Fixed stashes, each with a prompt at its position. None ships.

```lua
STASH = { PROMPT_KEY = 'E' },
STASHES = {},
```

`STASH.PROMPT_KEY` is the key every fixed stash's prompt answers to, a
[key name](#keys); `false` is `E`, since a prompt needs a key. A configuration
file without `STASH` keeps `E`.

A row of `STASHES`:

```lua
STASHES = {
	{ NAME = 'afterlife_locker', LABEL = 'stash.afterlife', SLOTS = 50, MAX_WEIGHT = 100000,
		POSITION = { X = -1446.2, Y = 1008.5, Z = 17.0 }, BUCKET = 0 },
},
```

| Field | Rule |
|---|---|
| `NAME` | the stored identity: letters, digits, `_`, `-` and `.`, up to 48. Renaming one is a new, empty stash |
| `LABEL` | a catalogue key or plain text, the stash's title and its prompt's description; without one the prompt reads *Storage* |
| `SLOTS` | `1`..`200`, default `50` |
| `MAX_WEIGHT` | `0`..`4000000000` grams, default `100000` |
| `POSITION` | `X`, `Y` and `Z`, required |
| `BUCKET` | the routing bucket, `0`..`1000000`, default `0` |

A stash with no valid `NAME` or `POSITION`, or declared twice, is left out with
a warning. Another resource opens a stash after its own checks — a job, a key, a
code — with the [`OpenStash`](exports.md#server-openstash) export instead.

## WEAPONS {#weapons}

```lua
WEAPONS = {
	ENABLED = true,
	SLOT = 1,
	REMOVE_UNBACKED = true,
	SCAN_MS = 5000,
	AMMO_SYNC_MS = 2000,
},
```

| Key | Range | Does |
|---|---|---|
| `ENABLED` | | a weapon is used from the bag: drawn, and holstered on a second use. Only `false` turns it off |
| `SLOT` | `1`..`3` | the game weapon slot an inventory weapon is put in |
| `REMOVE_UNBACKED` | | take off any weapon the bag does not back. Only `false` turns it off |
| `SCAN_MS` | `1000`..`600000` | how often a player's weapon slots are read for weapons nothing backs |
| `AMMO_SYNC_MS` | `500`..`60000` | how often a drawn weapon's rounds are read back into its item |

With `REMOVE_UNBACKED` on, a weapon put in a game slot by anything but this
resource is taken off at the next scan. That is why `opx77_admin` gives weapons
as items of this resource rather than through the platform's relay — see
[Weapons and bags](../opx77_admin/index.md#weapons-and-bags).

## NEARBY {#nearby}

```lua
NEARBY = {
	MAX = 4,
	SCAN_MS = 1000,
},
```

How many players the screen offers to hand something to (`0`..`12`), and how
often that list is refreshed while the screen is open (`250`..`10000` ms). A
player handed something is shown by distance, never by name.

## TABS {#tabs}

Category tabs over a grid.

```lua
TABS = {
	{ KEY = 'all' },
	{ KEY = 'weapons', CATEGORIES = { 'weapon', 'ammo' } },
	{ KEY = 'food', CATEGORIES = { 'food', 'drink' } },
	{ KEY = 'medical', CATEGORIES = { 'medical' } },
	{ KEY = 'materials', CATEGORIES = { 'material', 'tool' } },
	{ KEY = 'misc', REST = true },
},
```

`KEY` is labelled by `inventory.tab.<KEY>`; `CATEGORIES` gathers item
categories; `REST = true` takes the leftovers. A tab with no `KEY` is left out
with a warning.

## TOAST_MS {#toast-ms}

```lua
TOAST_MS = 4000,
```

How long a refusal, a notice or a staff command's toast stays on screen,
`750`..`120000` ms.

## EXPORTS {#exports}

Who may call the [server exports](exports.md#server).

```lua
EXPORTS = {
	READ = '*',
	WRITERS = { opx77_admin = true },
},
```

| Key | Does |
|---|---|
| `READ` | the server resources a read answers: `'*'` for all, or a set of resource names. Anything else is a warning, and reads then answer nobody |
| `WRITERS` | the set of resources allowed to call anything that changes a container |

A caller not allowed is answered `caller_denied`, and logged:

```text
[audit] event=inventory.export.denied severity=warn message="my_resource called AddItem" data={"caller":"my_resource","export":"AddItem"}
```

`opx77_admin` ships in `WRITERS`: its weapon and inventory commands call
`AddItem`, `RemoveItem`, `SetMetadata` and `ClearInventory`. Take it out and
every one of them answers `inventory_denied`.

## COMMANDS and MAX_COMMAND_COUNT {#commands}

```lua
COMMANDS = {
	GIVE = 'opx77.inventory.give',
	REMOVE = 'opx77.inventory.remove',
	CLEAR = 'opx77.inventory.clear',
	OPEN = 'opx77.inventory.open',
	HOLDERS = 'opx77.inventory.holders',
},
MAX_COMMAND_COUNT = 10000,
```

The name each staff command is registered under — letters, digits, `_`, `.` and
`-`, up to 64 — or `false` for none, which logs `command GIVE is off
(COMMANDS.GIVE)`. The ACL permission is `command.` plus the name. A rename here
has to be followed in [`opx77_admin`'s `LINKS`](../opx77_admin/config.md#links)
for `OPEN` and `HOLDERS`.

`MAX_COMMAND_COUNT` is the largest count a staff command accepts, `1`..`MAX_STACK`.

## The catalogue {#catalogue}

`data/items.lua` (`OPX_INVENTORY_ITEMS`) and `data/weapons.lua`
(`OPX_INVENTORY_WEAPONS`) are definitions, not settings. As shipped they carry
fifteen items, four ammunition items and 189 weapons — see
[Weapons](index.md#weapons). Nothing is created in game. An item's key is the
name stored in every container: renaming one strands what players hold, and an
item taken out of the file stays where it is, unusable, weighing
`DEFAULT_ITEM_WEIGHT`, until somebody moves it.

```lua
OPX_INVENTORY_ITEMS = {
	water = {
		WEIGHT = 500,            -- grams per unit, required
		CATEGORY = 'drink',      -- its tab; 'misc' when absent
		STACK = true,            -- false puts one unit per slot
		LABEL = 'item.water',    -- catalogue key or plain text; absent reads item.<name>
		DESCRIPTION = nil,       -- the same; absent reads item.<name>.description when it exists
		IMAGE = 'water.png',     -- a file under web/images/; absent draws the initials
		USE = {
			CONSUME = 1,           -- units taken per use, 0 for none
			CLOSE = true,          -- false keeps the screen open
			STATUS = { thirst = 35 },                                -- through opx77_status addNeeds
			ANIMATION = { NAME = 'drink', VARIANT = 1, DURATION_MS = 3000 }, -- through opx77_animations
		},
	},
}
```

A stack's metadata is free, bounded by `MAX_METADATA_BYTES`. The screen reads
`label`, `description` and `image` (overriding the catalogue for that one copy),
`durability` (0–100, a bar), `serial` and `ammo`. Two stacks stack only when
their metadata is the same.

A malformed entry is named at boot, under the file and the table it sits in, and
so is a file that declares no table at all:

```text
data: data/weapons.lua weapon_foo: CLASS "blaster" is not in CLASSES; left out
data: data/weapons.lua AMMO ammo_laser: not a table
data: data/weapons.lua declares no OPX_INVENTORY_WEAPONS
```

## See also {#see-also}

- [Overview](index.md) — the keys, weapons and saving these settings tune.
- [Commands](commands.md) — the staff commands `COMMANDS` names.
