---
title: opx77_admin configuration
description: Every key of OPX_ADMIN_CONFIG with its shipped default — keys, rates, the audit ring, placement, noclip and its speed keys, announcements, ban durations, vehicles, the inventory, the linked commands, the sky lists and the destinations — plus the vehicle catalogue and its parts, the weapon classes and the locale catalogue.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_ADMIN_CONFIG`.
**Every value shown on this page is the shipped default**, exactly as the file
declares it. The file's header block carries one `@field` line per key path.

!!! danger "Nothing in this file authorises anybody"

    `config.lua` is a `shared_script`, so every connecting player downloads it.
    It holds no secrets and no grants. Who may run what lives in `acl.jsonc`
    and nowhere else — see [Commands](commands.md#granting).

A number the server cannot do arithmetic on — a string, a NaN, an infinity — is
read as the shipped value rather than raised on. The client's noclip keys go
further: a value outside its range is also the shipped value, with a warning in
the client log.

## LOCALE {#locale}

Which `locales/<code>.lua` catalogue player-facing text is read from.

```lua
LOCALE = 'en',
```

**Type** `string` — `'en'` or `'fr'` as shipped.

Applied at load by `shared/locale.lua`, on both sides. An unknown code is
accepted, and every key then falls back to `en`, then to the key itself. See
[Player-facing text](#locales).

## KEYS {#keys}

The default keys of the three key mappings this resource declares with
`RegisterKeyMapping`. A player's own rebind, in the pause menu's key bindings
tab, overrides them.

```lua
KEYS = {
	MENU = 'F9',
	SPEED_UP = 'PAGEUP',
	SPEED_DOWN = 'PAGEDOWN',
},
```

| Key | Mapping id | Name in the pause menu | Does |
|---|---|---|---|
| `MENU` | `opx77_admin.menu` | *Staff: open or close the menu* | with the menu down, sends `/opx77.admin`; with it up, closes it |
| `SPEED_UP` | `opx77_admin.noclipFaster` | *Staff: noclip faster* | while noclip is on, raises its speed; held, it repeats |
| `SPEED_DOWN` | `opx77_admin.noclipSlower` | *Staff: noclip slower* | while noclip is on, lowers its speed; held, it repeats |

**Type** `string|false` each — a key name the host's key vocabulary knows, or
`false` to register no mapping. A value that is neither is a client log warning
and the default:

```text
config: KEYS.MENU must be a key name or false; using "F9"
```

**No key opens anything by itself.** The menu key sends the same command line
the chat box would, so the host resolves `command.opx77.admin` first: a player
without the grant gets the host's refusal and no menu. It is registered for
every player, staff or not, because the client cannot know the ACL. The speed
keys only choose a number and send it as
[`opx77.admin.self.speed`](commands.md#self-speed) — see [`NOCLIP`](#noclip). A
press while another surface holds the keyboard — the chat box, a form, the
pause menu — does nothing.

The mapping names are read from the configured locale when the resource starts.
The root screen's **Close** row names the key the player actually has, and
follows a rebind without the menu being reopened. F9 is clear of the keys the
rest of a stock resource set takes; Page Up and Page Down are clear of those and
of noclip's own keys.

## RATE {#rate}

Floors between two runs of the same thing by the same operator, in
milliseconds.

```lua
RATE = {
	ACTION_MS = 400,
	READ_MS = 1000,
	REFRESH_MS = 750,
},
```

| Key | Floor between |
|---|---|
| `ACTION_MS` | two runs of one mutating command |
| `READ_MS` | two runs of one command that only reads — the opener, `self.pos`, `weapon.read`, `inventory.view` and the four `read.*` |
| `REFRESH_MS` | two [`opx77_admin:refresh`](events.md#refresh) requests on one topic |

A command run inside its floor answers `too_fast`. The floor is per operator
**per command**, so running `heal` and then `revive` is not cooled. The console
is never cooled, and a disconnect forgets the player's history.

The chat-suggestion request is cooled at a literal 2000 ms and is not a key.

## AUDIT_ENTRIES {#audit-entries}

How many actions [`opx77.admin.read.audit`](commands.md#audit) can look back
over, this uptime.

```lua
AUDIT_ENTRIES = 200,
```

**Type** `integer` — never fewer than `10`.

The ring is in memory and dies with the process. The platform log line written
beside each entry is the record — see [The audit](index.md#audit).

## TOAST_MS {#toast-ms}

How long a target's "a staff member did this" toast stays up, in milliseconds.

```lua
TOAST_MS = 6000,
```

**Type** `integer`

Announcements have their own lifetime, [`ANNOUNCE.DURATION_MS`](#announce).

## PLACEMENT {#placement}

How a player is put down after a move. Every move is a
[kill and a respawn](index.md#placement).

```lua
PLACEMENT = {
	HEALTH = 1.0,
	GRACE_MS = 5000,
	BESIDE = { X = 1.5, Y = 0.0, Z = 0.0 },
	OBSERVE_HEIGHT = 2.0,
},
```

| Key | Does |
|---|---|
| `HEALTH` | the fraction of full health a respawn or a revive stands the player up with, clamped to `0.01`–`1.0` |
| `GRACE_MS` | respawn protection after a move or a revive, in ms; never negative |
| `BESIDE` | the offset from the other player on [`goto`](commands.md#player-goto) and [`bring`](commands.md#player-bring), in metres on the world axes |
| `OBSERVE_HEIGHT` | metres above the target an [observer](commands.md#player-observe) lands, noclip on |

!!! info "A fraction here, points elsewhere"

    `Open77.players.getHealth` answers absolute points and `revive` and
    `respawn` take a fraction. `HEALTH` is the fraction;
    [`opx77.admin.player.health`](commands.md#player-health) takes points. The
    code never mixes the two.

## NOCLIP {#noclip}

The noclip speed, the speed keys, and the controls drawn while noclip is on.

```lua
NOCLIP = {
	SPEED = 40.0,
	MIN_SPEED = 1.0,
	MAX_SPEED = 500.0,
	STEP = 0.15,
	SEND_AFTER_MS = 500,
	PROMPTS = true,
},
```

| Key | Range | Does |
|---|---|---|
| `SPEED` | `0.1`..`500` | m/s applied the first time noclip goes on for a player, unless they chose one. The native accepts `0.1` to `500`, and a value outside it is `40` on both sides |
| `MIN_SPEED` | `0.1`..`500` | the lowest speed the keys choose |
| `MAX_SPEED` | `MIN_SPEED`..`500` | the highest speed the keys choose |
| `STEP` | `0.01`..`1` | one press changes the speed by this fraction of itself, by at least 0.5 m/s: fine at walking pace, a few seconds of holding from one end of the range to the other |
| `SEND_AFTER_MS` | `0`..`10000` | quiet time after the last press before the chosen speed is sent; never below [`RATE.ACTION_MS`](#rate) plus 100, or a second change would land inside the server's floor and be refused |
| `PROMPTS` | `boolean` | the travel controls in `opx77_prompts`' strip; `false` for none |

The client reads `MIN_SPEED`, `MAX_SPEED`, `STEP` and `SEND_AFTER_MS` once, at
load; a value outside its range is the shipped one, with a warning:

```text
config: NOCLIP.STEP must be a number in 0.01..1; using 0.15
```

**A key only chooses a number.** While noclip is on, [`KEYS.SPEED_UP`](#keys)
and [`KEYS.SPEED_DOWN`](#keys) step the speed — held, a key repeats after 350 ms,
then every 110 ms — and do nothing with noclip off. Once the keys have been
quiet for `SEND_AFTER_MS`, one
[`opx77.admin.self.speed`](commands.md#self-speed) line goes out, so a held key
is one command and not thirty, the host resolves the ACL for it like a typed
one, and the native is set only by the server's answer. An accepted change is
not toasted — the strip already shows the number — and a refused one is, and
puts the read-out back to the speed the server has. The mouse wheel is not
offered: no client call on this platform reports it.

**The controls.** While noclip is on and the player is alive,
`opx77_prompts` draws a *NOCLIP* group in its corner strip: move (`W A S D`), up
and down (`SPACE`, `CTRL`), the speed keys with the current speed, fast and slow
(`SHIFT` ×4 and `ALT` ×0.25, held — the native's own modifiers), and the menu
key that leads to the **Noclip** row that turns it off. Keys named by a mapping
follow a rebind. While map travel is armed a *MAP TRAVEL* group says a
double-click on the map goes there. Both come down when the mode goes off, when
noclip is switched off by anything else, on death, and when this resource stops.

`opx77_prompts` is a soft dependency: while it is not running the keys still
work, and the client log says so once:

```text
opx77_prompts is not running; the travel controls are not drawn
```

## ANNOUNCE {#announce}

```lua
ANNOUNCE = {
	DURATION_MS = 12000,
	CHAT = true,
	MAX_CHARACTERS = 240,
},
```

| Key | Does |
|---|---|
| `DURATION_MS` | the announcement toast's lifetime on every client, in ms |
| `CHAT` | also write the announcement into the chat box, on `chat:addMessage`, as a `system` line with no colour, which `opx77_chat` styles; only `false` turns it off |
| `MAX_CHARACTERS` | the announcement is cut to this many characters |

## BAN_DURATIONS {#ban-durations}

The ban durations the menu's ban form offers.

```lua
BAN_DURATIONS = { '1h', '1d', '7d', '30d', 'perm' },
```

**Type** `string[]`

A typed ban is not limited to these: it takes any `<n>s`, `<n>m`, `<n>h` or
`<n>d` up to `3650d`, or `perm` — see
[`opx77.admin.moderate.ban`](commands.md#moderate-ban).

## VEHICLES {#vehicles}

```lua
VEHICLES = {
	SPAWN_OFFSET = { X = 3.0, Y = 0.0, Z = 0.25 },
	PER_OWNER = 8,
	NEAR_RADIUS = 30.0,
	OCCUPIED_REPAIRS = { glass = true, body = true, lights = true, tires = true, visual = true },
	FLAGS = { 'locked', 'engineOn', 'lightsOn', 'invulnerable' },
},
```

| Key | Does |
|---|---|
| `SPAWN_OFFSET` | where a vehicle appears, on the world axes, from whoever it is spawned for |
| `PER_OWNER` | vehicles this resource keeps out per player at once; never fewer than `1`. Past it `vehicle_cap` |
| `NEAR_RADIUS` | how far `near` looks when the operator is not in a vehicle, in metres, within their bucket |
| `OCCUPIED_REPAIRS` | the repair scopes allowed with somebody aboard. `full` and `mechanical` are left out because they may respawn the vehicle; a scope missing here answers `unsafe_repair` |
| `FLAGS` | the `Open77.vehicles.flags` names [`opx77.admin.vehicle.flag`](commands.md#vehicle-flag) may toggle. A name the host has no mask for is refused like one not listed |

A vehicle removed by somebody else is forgotten the next time the list is
consulted, so it stops counting against `PER_OWNER`.

## INVENTORY {#inventory}

Weapons, ammunition and bags are [`opx77_inventory`](../opx77_inventory/index.md)'s:
every weapon command but the holster, and every inventory command, calls its
server exports, which need this resource in its
[`EXPORTS.WRITERS`](../opx77_inventory/config.md#exports) — shipped so.

```lua
INVENTORY = {
	RESOURCE = 'opx77_inventory',
	MAX_COUNT = 10000,
},
```

| Key | Does |
|---|---|
| `RESOURCE` | the inventory whose exports the weapon and inventory commands call; match a renamed folder. A value that is not letters, digits, `_`, `-` and `.` is read as `'opx77_inventory'` |
| `MAX_COUNT` | the largest count [`inventory.give`](commands.md#inventory-give), [`inventory.remove`](commands.md#inventory-remove) and the ammunition gives — [`weapon.give`](commands.md#weapon-give)'s third argument, [`weapon.giveammo`](commands.md#weapon-giveammo) and [`weapon.ammo`](commands.md#weapon-ammo) — accept; never below `1`. Past it `bad_count` |

A full load of ammunition is not a key here: it is the inventory's `AMMO.MAX`
for that ammunition, read from its catalogue.

## LINKS {#links}

Commands of other OPX//77 resources the menu drives instead of doing the same
thing twice.

```lua
LINKS = {
	CHARACTERS = 'opx77',
	WHERE = 'opx77.where',
	JOB = 'opx77.job',
	GANG = 'opx77.gang',
	MONEY = 'opx77.money',
	SAVE = 'opx77.save',
	INVENTORY_OPEN = 'opx77.inventory.open',
	INVENTORY_HOLDERS = 'opx77.inventory.holders',
	WEATHER_SET = 'opx77.weather.set',
	WEATHER_NEXT = 'opx77.weather.next',
	WEATHER_FREEZE = 'opx77.weather.freeze',
	TIME = 'opx77.weather.time',
	TIME_FREEZE = 'opx77.weather.time.freeze',
},
```

**Type** `table<string, string|false>`

| Key | Menu row | Resource |
|---|---|---|
| `CHARACTERS` | *Characters in the world*, on the Server screen | [`opx77_core`](../opx77_core/commands.md#opx77) |
| `WHERE` | *Character record*, on a player | [`opx77_core`](../opx77_core/commands.md#opx77-where) |
| `JOB`, `GANG` | *Set job*, *Set gang*, on a player | [`opx77_core`](../opx77_core/commands.md#opx77-job) |
| `MONEY` | *Money*, on a player | [`opx77_core`](../opx77_core/commands.md#opx77-money) |
| `SAVE` | *Save every character now*, on the Server screen, after a confirmation | [`opx77_core`](../opx77_core/commands.md#opx77-save) |
| `INVENTORY_OPEN` | *Open the bag beside mine*, on a player | [`opx77_inventory`](../opx77_inventory/commands.md#open) |
| `INVENTORY_HOLDERS` | *Who holds an item*, on the Server screen | [`opx77_inventory`](../opx77_inventory/commands.md#holders) |
| `WEATHER_SET`, `WEATHER_NEXT`, `WEATHER_FREEZE` | the Weather screen's presets, roll, hold and release | [`opx77_weather`](../opx77_weather/commands.md#set) |
| `TIME`, `TIME_FREEZE` | the Time screen's times, another time, hold and release | [`opx77_weather`](../opx77_weather/commands.md#time) |

Match any rename made in [`opx77_core`](../opx77_core/commands.md), in
[`opx77_inventory`'s `COMMANDS`](../opx77_inventory/config.md#commands) or in
[`opx77_weather`'s `COMMANDS`](../opx77_weather/config.md#commands).
`false` removes the row. The character rows are drawn only while `opx77_core`
runs, the sky screens only while `opx77_weather` runs, and the inventory rows
only while `opx77_inventory` runs.

`INVENTORY_OPEN` and `INVENTORY_HOLDERS` are there because `opx77_inventory`
publishes no export that opens another character's bag on a staff screen or
lists the containers holding an item: the menu's *Open the bag beside mine* and
*Who holds an item* rows run those two commands, gated on
`command.opx77.inventory.open` and `command.opx77.inventory.holders`. See
[Weapons and bags](index.md#weapons-and-bags). Every name here is also put in
the access map, so the menu greys it by the operator's ACL like one of this
resource's own.

## WEATHER_PRESETS and TIMES {#sky}

What the World screen's weather and time rows offer.

```lua
WEATHER_PRESETS = { 'sunny', 'lightclouds', 'cloudy', 'rain', 'heavyclouds', 'fog',
	'pollution', 'sandstorm' },
TIMES = { '06:00', '09:00', '12:00', '17:30', '20:30', '23:00', '03:00' },
```

Preset names come from [`opx77_weather`'s `WEATHER` table](../opx77_weather/config.md#weather),
and are sent to its commands as written. A preset that is not letters, digits,
`_` and `-`, or a time that is not `H:MM` or `HH:MM`, gets no row.

## LOCATIONS {#locations}

Saved destinations, for [`send`](commands.md#player-send) and the menu.

```lua
LOCATIONS = {
	{ NAME = 'watson', LABEL = 'Watson, west', X = -667.14, Y = -382.61, Z = 9.16, HEADING = 0.0 },
	{ NAME = 'heights', LABEL = 'Northwest heights', X = -1441.0, Y = 1269.0, Z = 123.0,
		HEADING = 180.0 },
	{ NAME = 'coast', LABEL = 'Southwest coast', X = -1716.38, Y = -2421.28, Z = 62.59,
		HEADING = 0.0 },
	{ NAME = 'stoop', LABEL = 'Watson, King Stoop forecourt', X = -410.22, Y = 722.73, Z = 115.0,
		HEADING = 147.0 },
	{ NAME = 'northside', LABEL = 'Watson, north promenade', X = -469.47, Y = 930.99, Z = 56.45,
		HEADING = -68.0 },
	{ NAME = 'junction', LABEL = 'Watson, lower junction', X = -644.91, Y = 1019.37, Z = 36.56,
		HEADING = 75.5 },
	{ NAME = 'underpass', LABEL = 'Watson, lower underpass', X = -701.49, Y = 1033.97, Z = 35.71,
		HEADING = -104.5 },
	{ NAME = 'dealer', LABEL = 'Westbrook, vehicle dealership', X = -1442.2, Y = 127.4, Z = 18.0,
		HEADING = 0.0 },
	{ NAME = 'racegrid', LABEL = 'Westbrook, race grid', X = -1450.2, Y = 119.9, Z = 14.8,
		HEADING = 200.0 },
	{ NAME = 'lab', LABEL = 'East, laboratory', X = 1669.75, Y = -739.12, Z = 49.86,
		HEADING = 0.0 },
	{ NAME = 'arena', LABEL = 'Badlands, arena', X = 381.36, Y = -2401.79, Z = 181.99,
		HEADING = 0.0 },
},
```

Eleven destinations: the platform's freeroam landing spots captured on build
2.31 — Watson west, the northwest heights and the southwest coast, Watson's King
Stoop forecourt, north promenade, lower junction and underpass, the Westbrook
dealership and race grid, the laboratory in the east and the Badlands arena.
Replace them with your own.

`NAME` is what staff type: 1 to 32 letters, digits, `_` and `-`, lower-cased.
`LABEL` is cut to 48 characters and defaults to the name. `HEADING` is in
degrees on arrival, `0` when it is not a number. A row whose `NAME` is not such
a name, or whose `X`, `Y` or `Z` is not a number, is skipped at boot:

```text
LOCATIONS #2 ignored: NAME must be a slug and X, Y, Z numbers
```

Stand where you want one and run
[`opx77.admin.self.pos`](commands.md#self-pos): it copies a row in this shape
to the clipboard. Destinations added in game with
[`loc.add`](commands.md#loc-add) last until the next restart.

## Catalogues {#catalogues}

The vehicles staff may spawn are definitions, not settings, and live in
`data/vehicles.lua` (`OPX_ADMIN_VEHICLES`). The weapons, ammunition and items
they may hand out are not listed here at all: they are
[`opx77_inventory`](../opx77_inventory/index.md)'s catalogue. `data/weapons.lua`
(`OPX_ADMIN_WEAPONS`) keeps only the weapon classes.

!!! danger "They are allowlists, not suggestions"

    A record that is not a row of `data/vehicles.lua` never reaches
    `Open77.vehicles.create`, and a name that is not an item of the inventory's
    catalogue is never given, whatever a client types. The inventory checks the
    name again.

### Vehicles {#vehicles-catalogue}

The platform has no server-side call that enumerates vehicle records, so
`data/vehicles.lua` is copied from the vehicle catalogue the platform's
`open77_admin` ships for build 2.31: **271 vehicles in ten classes**, every
drivable `_player` record and every distinct traffic livery.

| `KEY` | `LABEL` | Rows |
|---|---|---|
| `street` | Street | 44 |
| `sport` | Sport | 42 |
| `hyper` | Hypercars | 25 |
| `bike` | Motorcycles | 25 |
| `suv` | SUVs | 23 |
| `pickup` | Pickups and vans | 22 |
| `truck` | Trucks | 29 |
| `service` | Corporate and services | 13 |
| `gang` | Gangs | 29 |
| `police` | Police and military | 19 |

Left out are the records that catalogue files as quest, scripted scene or
special; their courier, locked, broken and heat-response copies; the traffic
twin of a `_player` record; the numbered development models; and every AV,
whose flight the platform does not certify. Most rows are catalogue records
nobody has spawned on this platform yet.

A row, as the file ships it:

```lua
{ NAME = 'outlaw', LABEL = 'Herrera Outlaw', CLASS = 'hyper',
	RECORD = 'Vehicle.v_sport1_herrera_outlaw_player' },
```

| Field | Rule |
|---|---|
| `NAME` | what staff type: 1 to 32 letters, digits, `_` or `-`, lower-cased |
| `LABEL` | what the menu shows, up to 48 characters; defaults to the name |
| `CLASS` | a `KEY` from the file's `CLASSES`, which also sets the menu order |
| `RECORD` | the exact TweakDB record: letters, digits, `_` and `.` |

A command accepts the `NAME` or the exact `RECORD`, without case. A malformed
row — a bad name or record, an unknown class, or a name or record declared
twice — is dropped and named in a boot warning rather than raised on:

```text
data/vehicles.lua: row #3: CLASS is not a KEY in CLASSES
```

A record the engine does not know passes the allowlist and is refused when it
is spawned, with the host's own reason in the answer. In the menu, a class's
vehicles are drawn twenty to a page, with a **More** row to the next.

#### Catalogue parts {#catalogue-parts}

The rows are indexed at load in four parts, `shared/catalog-1.lua` to
`shared/catalog-4.lua`, after `shared/catalog.lua`: the host rolls the whole
resource set back when one script's load runs past its deadline, which it checks
every 10 000 VM instructions, and a row costs about 110. Each of the first three
parts indexes the next 68 rows (`OpxAdmin.Catalog.PART`); the last indexes
whatever is left. Past 272 rows, add a part to `open77.lua` for every 68 more,
before the last one. The server names an overloaded last part at boot:

```text
data/vehicles.lua: 90 rows were left to the last catalogue part; add a shared/catalog-<n>.lua part to open77.lua for every 68 rows past it
```

A missing part costs load time on the last one, never a vehicle.

### Weapons and items {#weapons-catalogue}

Weapons, ammunition and items are `opx77_inventory`'s `data/items.lua` and
`data/weapons.lua`, read through its `GetItems` export, page by page, and kept
for up to five minutes, forgotten as soon as that resource starts or stops. There
is one list: a weapon staff can hand out is always one the inventory backs, and
it is added to or trimmed there. Staff type a weapon by its item name,
`weapon_lexington`, or without the prefix, `lexington`, and ammunition by its
item name, `ammo_rifle`, or by a weapon that takes it.

`data/weapons.lua` here keeps only the classes:

```lua
OPX_ADMIN_WEAPONS = {
	CLASSES = {
		{ KEY = 'handgun', LABEL = 'Handguns' },
		{ KEY = 'revolver', LABEL = 'Revolvers' },
		{ KEY = 'smg', LABEL = 'SMGs' },
		{ KEY = 'rifle', LABEL = 'Assault rifles' },
		{ KEY = 'precision', LABEL = 'Precision rifles' },
		{ KEY = 'sniper', LABEL = 'Sniper rifles' },
		{ KEY = 'shotgun', LABEL = 'Shotguns' },
		{ KEY = 'lmg', LABEL = 'Light machine guns' },
		{ KEY = 'melee', LABEL = 'Melee' },
	},
}
```

| Field | Rule |
|---|---|
| `KEY` | matched on `CLASS` in the inventory's `data/weapons.lua`; the order of the list is the menu's |
| `LABEL` | what the weapon picker shows, up to 48 characters; defaults to the key |

A class sets no rounds: a weapon is given empty, and its ammunition is an item
of its own — see [`weapon.give`](commands.md#weapon-give). A class the inventory
uses and this file does not name is listed last, under its key. A class with no
unique `KEY` is dropped and named at boot:

```text
data/weapons.lua: class #3 needs a unique KEY
```

## Player-facing text {#locales}

`locales/en.lua` and `locales/fr.lua`, keyed `admin.<thing>`, registered
through `shared/locale.lua`, which publishes the global `locale(key, params)`.

Every answer a player reads is translated, a staff member's included, and so are
the key mapping names and the noclip controls. The answer the console gets,
`Open77.log` lines, the audit and the refusal codes stay English. Catalogue
labels, destination labels, vehicle flag names and weather preset names are
data, not text, and are shown as written.

A key present in one catalogue and missing from the other is a defect, not a
fallback, and is named at boot:

```text
locales/fr.lua is missing admin.error.tooFast
```

To add a language: copy `locales/en.lua` to `locales/<code>.lua`, change the
code in the `register` call, translate the values, add
`shared_script "locales/<code>.lua"` to `open77.lua` beside the others, and set
[`LOCALE`](#locale) to it. The boot check compares `en` and `fr` only.

## Constants that are not configurable {#constants}

| Constant | Value | What it is |
|---|---|---|
| Kick reason | 127 bytes | the platform refuses a longer disconnect reason outright |
| Longest ban | `3650d` | a longer duration answers `bad_duration` |
| Coordinates | ±1,000,000 | a point past it on any axis answers `bad_coordinates` |
| Armour | `0`–`10000` points | the range [`player.armor`](commands.md#player-armor) accepts |
| Noclip speed | `0.1`–`500` m/s | the range [`self.speed`](commands.md#self-speed) and the native accept |
| Audit read | `1`–`40`, default `15` | what [`read.audit`](commands.md#audit) shows at once |
| List chunk | 20 rows | per [`opx77_admin:roster`](events.md#roster), [`locations`](events.md#locations), [`items`](events.md#items) or [`bag`](events.md#bag) event: the host drops an event past 1024 value nodes without a word |
| Catalogue cache | 300,000 ms | how long `opx77_inventory`'s catalogue is kept before it is read again |
| Travel sweep | 2000 ms | how often a revoked grant is looked for |
| Holster request | 30,000 ms | how long an unanswered holster relay request is remembered |
| Speed key repeat | 350 ms, then 110 ms | how soon a held speed key first repeats, then how often |
| Menu answer | 15,000 ms | how long a command the menu sent may take to have its answer put under the list |
| Menu status | 116 bytes | the first line of an answer written under the list, cut on a whole character |
| Menu page | 20 rows | per page of a vehicle, weapon or item list, with a **More** row: `opx77_menu` checks every row in one client handler, and the host stops a handler past 10 000 VM instructions |
| Menu rows | 190 | per roster, destination list, spots saved in game, ammunition picker or bag, under `opx77_menu`'s 200 a level |
| Catalogue part | 68 rows | vehicle rows each `shared/catalog-<n>.lua` indexes at load |

## See also {#see-also}

- [Commands](commands.md) — what each key changes, command by command.
- [Overview](index.md) — the gate, placement and the audit these keys tune.
