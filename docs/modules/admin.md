---
title: admin module
description: The staff panel — a menu, rows on the target eye and about fifty restricted commands to move, heal, arm, equip, moderate and audit players.
---

# admin

`admin` is the staff tool. A staff member presses **F9** (or types `/opx.admin`) to open a menu that finds a player, goes to them, heals or moves them, gives them a car, a weapon or an item, kicks or bans them, and reads the audit. The same actions show up as rows on the target eye, and each one is also a chat command. Every action is a restricted command, so the server's ACL decides who may run what. The module stores nothing in the database. It needs only `character`; each optional module it can use adds one feature.

| | |
|---|---|
| Side | both |
| Requires | [`character`](character.md) (hard) |
| Optional | [`menu`](menu.md), [`form`](form.md), [`target`](target.md), [`inventory`](inventory.md), [`vehicles`](vehicles.md), [`downed`](downed.md), [`prompts`](prompts.md), [`diagnostics`](diagnostics.md), [`vehiclekeys`](vehiclekeys.md); `appearance` is read for the wardrobe command |
| Configuration | `config/admin.lua` (shared script) |
| Contract | `admin` v1 — server, client |
| Data | none. Locations saved in game are kept with `OPX.Carry`, not in the database |

## Granting access {#granting}

The module checks no permission itself. The host resolves `command.<name>` against `acl.jsonc` before any handler runs. The menu and the eye only grey out or hide what the ACL would refuse.

- `command.opx.admin` opens the menu. Holding this grant is what makes someone "staff" for [`IsStaff`](#server-admin-isstaff) and for the badge on name tags.
- `command.opx.admin.*` covers every action. Only a rule ending in `.*` is a prefix, so `command.opx.admin.*` does **not** cover the opener. An operator role needs **both**.
- Grant a narrower family instead when you want to, for example `command.opx.admin.player.*`. The `character.*` commands are separate on purpose: `list` shows one account's characters, `find` searches everyone who has ever played, and `rename`/`delete` change rows that outlive a session.
- The menu and the eye also run other modules' commands, named in [`LINKS`](#config-admin-links): `opx.players`, `opx.where`, `opx.job`, `opx.gang`, `opx.money`, `opx.save`, `opx.inventory.open`, `opx.inventory.holders`, `opx.weather.set`, `opx.weather.next`, `opx.weather.freeze`, `opx.time`, `opx.time.freeze`. Grant those too, for example `command.opx.weather.*`, `command.opx.time` and `command.opx.time.*`.
- **The eye hides what the menu greys.** The menu draws a row the ACL refuses and marks it refused. The eye does not register that row at all. A missing grant therefore looks like a missing feature on the eye. The client writes the grants it dropped rows for to the server journal, for example `[admin] target rows, player 3: … this ACL does not grant: opx.inventory.open opx.weather.set`. Each name in that line is a `command.<name>` to add.
- A short alias is gated on the long command's right, never on its own name.

## Commands {#commands}

All commands are restricted. The right is always `command.` plus the full name. A *target* `playerId|me` takes a server id, or `me`/`self` for the caller. A *holder* `playerId|me|citizenId` also accepts a citizen id, online or offline. Switches take `on`/`off` (also `true`/`false`, `1`/`0`, `yes`/`no`); leaving one out toggles. "In game" means the console gets `in_game_only`.

Moving, reviving, healing, killing and spawning for a player first require that player's readiness gate to be open (`not_incarnated`, `gate_closed`, `gate_unreadable`). A move is a kill and a respawn at the new point, with health set to `PLACEMENT.HEALTH` and a grace window. If the respawn is refused, the player is revived where they stood.

Each operator has a cooldown per command: 400 ms for actions and 1000 ms for reads, set by `RATE` and the tunables. The console has no cooldown. A run inside the cooldown is refused with `too_fast`. Every action writes an audit line, and the target gets a toast unless they are the caller.

### Menu

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin"></a>`/opx.admin` | ACL `command.opx.admin` | — | In game. Opens the staff menu and sends it the access map, the roster, the locations, the bodies state and, if `inventory` runs, the item list. Also bound to `KEYS.MENU` (F9). |

### Self

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin-self-noclip"></a>`/opx.admin.self.noclip` | ACL `command.opx.admin.self.noclip` | `[on\|off]` | In game. Turns noclip on or off. While flying, the body is hidden from other players. Noclip is turned off when the grant is revoked (checked every 2 s). Alias `noclip`. |
| <a id="opx-admin-self-speed"></a>`/opx.admin.self.speed` | ACL `command.opx.admin.self.speed` | `<m/s>` (0.1–500) | In game. Sets the noclip speed. The speed keys send this command. Alias `speed`. |
| <a id="opx-admin-self-maptravel"></a>`/opx.admin.self.maptravel` | ACL `command.opx.admin.self.maptravel` | `[on\|off]` or `<x> <y> <z>` | In game. With a switch, arms or disarms map travel: a point double-clicked on the world map is sent back as `x y z`. With three numbers, moves the caller there. |
| <a id="opx-admin-self-heal"></a>`/opx.admin.self.heal` | ACL `command.opx.admin.self.heal` | — | In game. Sets the caller's health to its maximum. Alias `heal`. |
| <a id="opx-admin-self-revive"></a>`/opx.admin.self.revive` | ACL `command.opx.admin.self.revive` | — | In game. Revives the caller, through `downed` when it runs. Alias `revive`. |
| <a id="opx-admin-self-god"></a>`/opx.admin.self.god` | ACL `command.opx.admin.self.god` | `[on\|off]` | In game. God mode for the caller. Alias `god`. |
| <a id="opx-admin-self-invisible"></a>`/opx.admin.self.invisible` | ACL `command.opx.admin.self.invisible` | `[on\|off]` | In game. Hides the caller's body from other players. Switching it off during noclip takes effect only when noclip ends. Alias `invis`. |
| <a id="opx-admin-self-pos"></a>`/opx.admin.self.pos` | ACL `command.opx.admin.self.pos` | — | In game, read. Answers the position, the facing and the bucket, and copies `{ NAME = "here", LABEL = "Here", X = …, Y = …, Z = …, HEADING = … },` to the clipboard, ready for a config file. Alias `pos`. |
| <a id="opx-admin-self-tags"></a>`/opx.admin.self.tags` | ACL `command.opx.admin.self.tags` | `[on\|off]` | In game. Shows name tags above nearby players. The choice is remembered on the client and restored on the next join if the grant still holds. |
| <a id="opx-admin-self-model"></a>`/opx.admin.self.model` | ACL `command.opx.admin.self.model` | `[ped\|off]` | In game. Wears an NPC body from `data/peds.lua` (by name or record), or takes it off (`off`, `none`, `reset`, `self`, `own`). With no argument, takes it off if one is worn. Needs `Open77.players.setModel`, otherwise `models_unavailable`. |

### Player

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin-player-goto"></a>`/opx.admin.player.goto` | ACL `command.opx.admin.player.goto` | `<playerId>` | In game. Moves the caller beside the player (offset `PLACEMENT.BESIDE`), in their bucket. Alias `goto`. |
| <a id="opx-admin-player-bring"></a>`/opx.admin.player.bring` | ACL `command.opx.admin.player.bring` | `<playerId>` | In game. Moves the player beside the caller. Alias `bring`. |
| <a id="opx-admin-player-tp"></a>`/opx.admin.player.tp` | ACL `command.opx.admin.player.tp` | `<playerId\|me> <x> <y> <z> [heading]` | Moves a player to coordinates. Each coordinate must be within ±1,000,000. Alias `tp`. |
| <a id="opx-admin-player-send"></a>`/opx.admin.player.send` | ACL `command.opx.admin.player.send` | `<playerId\|me> <location>` | Moves a player to a saved location, configured or added in game. |
| <a id="opx-admin-player-observe"></a>`/opx.admin.player.observe` | ACL `command.opx.admin.player.observe` | `<playerId>` | In game. Moves the caller `PLACEMENT.OBSERVE_HEIGHT` metres above the player and turns noclip on. Alias `spectate`. |
| <a id="opx-admin-player-heal"></a>`/opx.admin.player.heal` | ACL `command.opx.admin.player.heal` | `<playerId\|me>` | Sets health to its maximum. |
| <a id="opx-admin-player-revive"></a>`/opx.admin.player.revive` | ACL `command.opx.admin.player.revive` | `<playerId\|me>` | Revives, through `downed`'s `Revive` when it runs (a player who is not down still succeeds), otherwise the host's revive. |
| <a id="opx-admin-player-god"></a>`/opx.admin.player.god` | ACL `command.opx.admin.player.god` | `<playerId\|me> [on\|off]` | God mode for a player. |
| <a id="opx-admin-player-freeze"></a>`/opx.admin.player.freeze` | ACL `command.opx.admin.player.freeze` | `<playerId> [on\|off]` | Holds a player still, or releases them. Released when the module stops. Alias `freeze`. |
| <a id="opx-admin-player-kill"></a>`/opx.admin.player.kill` | ACL `command.opx.admin.player.kill` | `<playerId>` | Kills the player. The caller is recorded as the killer. |
| <a id="opx-admin-player-health"></a>`/opx.admin.player.health` | ACL `command.opx.admin.player.health` | `<playerId\|me> <points>` | Sets health, capped at the player's maximum. |
| <a id="opx-admin-player-armor"></a>`/opx.admin.player.armor` | ACL `command.opx.admin.player.armor` | `<playerId\|me> <points>` (0–10000) | Sets armour. |
| <a id="opx-admin-player-model"></a>`/opx.admin.player.model` | ACL `command.opx.admin.player.model` | `<playerId> [ped\|off]` | Same as `self.model`, for another player. |
| <a id="opx-admin-player-wardrobe"></a>`/opx.admin.player.wardrobe` | ACL `command.opx.admin.player.wardrobe` | `<playerId\|me>` | Opens the fitting room for the player through `appearance`'s `OpenWardrobe`. If that contract is not running, the command is refused with reason `appearance_unavailable`. |

### Character

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin-character-list"></a>`/opx.admin.character.list` | ACL `command.opx.admin.character.list` | `<playerId\|me>` | In game, read. Lists every character of a connected player's account: citizen id, name, gender, creation date. `*` marks the one being played and `>` the active one. |
| <a id="opx-admin-character-find"></a>`/opx.admin.character.find` | ACL `command.opx.admin.character.find` | `<name\|citizenId>` | In game, read. Searches every character in the database through `character`'s `FindCharacters`: citizen id, name, account, last logout. `*` means in play, `+` means the account is online. |
| <a id="opx-admin-character-rename"></a>`/opx.admin.character.rename` | ACL `command.opx.admin.character.rename` | `<citizenId> <firstName> <lastName>` | In game. Renames a character through `character`'s `RenameCharacter`. |
| <a id="opx-admin-character-delete"></a>`/opx.admin.character.delete` | ACL `command.opx.admin.character.delete` | `<citizenId>` | In game. Deletes a character through `character`'s `RemoveCharacter`. Warns the player holding it, if online. |

!!! danger "Character delete and bag clear cannot be undone"
    `opx.admin.character.delete` removes the character row through `character`, and `opx.admin.inventory.clear` empties the bag through `inventory`. Neither command asks for confirmation when typed. Neither has an alias.

### Moderation

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin-moderate-kick"></a>`/opx.admin.moderate.kick` | ACL `command.opx.admin.moderate.kick` | `<playerId> [reason…]` | Kicks the player. The reason is cut to 127 bytes. With no reason, a default text is used. |
| <a id="opx-admin-moderate-ban"></a>`/opx.admin.moderate.ban` | ACL `command.opx.admin.moderate.ban` | `<playerId> [duration] [reason…]` | Bans the player's account through `Open77.access.ban` (the server's own ban list, not the ACL). Duration is `<n>s`, `m`, `h` or `d` (at most 3650 days), or `perm`/`permanent`. With no duration, the ban is permanent. The resource needs the `players.access` permission. |

### Vehicle

`vehicleId|near` takes a live vehicle id. `near` picks the vehicle the caller sits in, otherwise the nearest one in the caller's bucket within `VEHICLES.NEAR_RADIUS`.

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin-vehicle-spawn"></a>`/opx.admin.vehicle.spawn` | ACL `command.opx.admin.vehicle.spawn` | `<vehicle>` | In game. Spawns a vehicle from `data/vehicles.lua` (by name or record) beside the caller. Each player can have at most `VEHICLES.PER_OWNER` of them. An AV is lifted `AV_LIFT`. If `vehiclekeys` runs, the caller also gets a key. Alias `car`. |
| <a id="opx-admin-vehicle-give"></a>`/opx.admin.vehicle.give` | ACL `command.opx.admin.vehicle.give` | `<playerId\|me> <vehicle>` | Same, beside another player, who gets the key. |
| <a id="opx-admin-vehicle-key"></a>`/opx.admin.vehicle.key` | ACL `command.opx.admin.vehicle.key` | `[vehicleId\|near]` | In game. Puts a key to that vehicle in the caller's own bag, through `vehiclekeys`' `GiveFor`. There is no plate argument. Without `vehiclekeys`: `keys_unavailable`. |
| <a id="opx-admin-vehicle-remove"></a>`/opx.admin.vehicle.remove` | ACL `command.opx.admin.vehicle.remove` | `[vehicleId\|near\|mine]` | Removes one empty vehicle (default `near`), or `mine`: every vehicle this module spawned for the caller. Occupied vehicles are kept (`occupied`). If the host refuses the removal: `not_ours`. Alias `dv`. |
| <a id="opx-admin-vehicle-cleanup"></a>`/opx.admin.vehicle.cleanup` | ACL `command.opx.admin.vehicle.cleanup` | — | Removes every empty vehicle this module spawned, for everybody. |
| <a id="opx-admin-vehicle-repair"></a>`/opx.admin.vehicle.repair` | ACL `command.opx.admin.vehicle.repair` | `[vehicleId\|near] [scope]` | Repairs. Scope: `glass`, `body`, `lights`, `tires`, `visual`, `mechanical`, `full` (default). On an occupied vehicle, only scopes listed in `VEHICLES.OCCUPIED_REPAIRS` are allowed (`unsafe_repair`). Alias `fix`. |
| <a id="opx-admin-vehicle-enter"></a>`/opx.admin.vehicle.enter` | ACL `command.opx.admin.vehicle.enter` | `[vehicleId\|near]` | In game. Seats the caller in the first free seat, driver first, even in a locked vehicle. |
| <a id="opx-admin-vehicle-flag"></a>`/opx.admin.vehicle.flag` | ACL `command.opx.admin.vehicle.flag` | `<vehicleId\|near> <flag> [on\|off]` | Sets a vehicle flag. Only names listed in `VEHICLES.FLAGS` are accepted. |

### Inventory

These commands need the `inventory` contract (`inventory_unavailable`). Counts are from 1 to `INVENTORY.MAX_COUNT`.

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin-inventory-view"></a>`/opx.admin.inventory.view` | ACL `command.opx.admin.inventory.view` | `<holder>` | Read. Lists the bag: slots, weight, each stack with rounds and serial. |
| <a id="opx-admin-inventory-give"></a>`/opx.admin.inventory.give` | ACL `command.opx.admin.inventory.give` | `<holder> <item> [count]` | Adds an item from the inventory catalogue (default 1). The bag's slot and weight limits apply. |
| <a id="opx-admin-inventory-remove"></a>`/opx.admin.inventory.remove` | ACL `command.opx.admin.inventory.remove` | `<holder> <item> [count]` | Removes items (default 1). |
| <a id="opx-admin-inventory-clear"></a>`/opx.admin.inventory.clear` | ACL `command.opx.admin.inventory.clear` | `<holder>` | Empties the bag through `inventory`'s `ClearInventory`. |

### Weapon

Weapons are inventory items, so these commands need `inventory` too. A weapon is named by its item, with or without the `weapon_` prefix. Ammunition is named by its own item.

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin-weapon-give"></a>`/opx.admin.weapon.give` | ACL `command.opx.admin.weapon.give` | `<holder> <weapon> [ammo] [count]` | Adds one weapon, unloaded. With an ammunition item, also adds `count` of it (default `INVENTORY.DEFAULT_AMMO`). If the ammunition is refused, the weapon is taken back. Alias `addweapon`. |
| <a id="opx-admin-weapon-giveammo"></a>`/opx.admin.weapon.giveammo` | ACL `command.opx.admin.weapon.giveammo` | `<holder> <ammo> [count]` | Adds ammunition (default `DEFAULT_AMMO`). Alias `addammo`. |
| <a id="opx-admin-weapon-ammo"></a>`/opx.admin.weapon.ammo` | ACL `command.opx.admin.weapon.ammo` | `<holder> [ammo\|all] [count]` | Adds `count` of one ammunition item, or of every ammunition type already in the bag (`all`, the default). |
| <a id="opx-admin-weapon-remove"></a>`/opx.admin.weapon.remove` | ACL `command.opx.admin.weapon.remove` | `<holder> <weapon\|all>` | Removes every unit of one weapon, or every weapon. Alias `delweapon`. |
| <a id="opx-admin-weapon-holster"></a>`/opx.admin.weapon.holster` | ACL `command.opx.admin.weapon.holster` | `<playerId\|me>` | Always refused with `holster_unavailable`: the `inventory` contract has no holster call. |
| <a id="opx-admin-weapon-read"></a>`/opx.admin.weapon.read` | ACL `command.opx.admin.weapon.read` | `<holder>` | Read. Lists the weapons in the bag with slot, serial and rounds, and marks the one drawn. |

### World

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin-world-announce"></a>`/opx.admin.world.announce` | ACL `command.opx.admin.world.announce` | `<text…>` | Sends an announcement toast to every player (at most `ANNOUNCE.MAX_CHARACTERS` characters), and a chat line when `ANNOUNCE.CHAT` is on. Answers how many players received it. Alias `announce`. |
| <a id="opx-admin-world-pvp"></a>`/opx.admin.world.pvp` | ACL `command.opx.admin.world.pvp` | `[on\|off]` | Turns damage between players on or off for the whole server (`Open77.combat.setFriendlyFire`). Set from `COMBAT.PVP` at start. |
| <a id="opx-admin-world-door"></a>`/opx.admin.world.door` | ACL `command.opx.admin.world.door` | `<doorId> <open\|close\|lock\|unlock\|seal\|unseal\|reset>` | In game. Changes a door (`0x` + hex id) for every player in the caller's bucket. Each bucket holds at most `DOORS.MAX_PER_BUCKET` doors. Refused with `doors_networked` while `open77_doors` runs. States are kept in memory only. |
| <a id="opx-admin-world-loc-add"></a>`/opx.admin.world.loc.add` | ACL `command.opx.admin.world.loc.add` | `<name> [label…]` | In game. Saves the caller's position as a location (name: a slug up to 32 characters). |
| <a id="opx-admin-world-loc-remove"></a>`/opx.admin.world.loc.remove` | ACL `command.opx.admin.world.loc.remove` | `<name>` | Removes a location saved in game. A configured location is refused (`seeded_location`). |

### Read

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-admin-read-status"></a>`/opx.admin.read.status` | ACL `command.opx.admin.read.status` | — | Read. Shows players connected and in the world, vehicles spawned by staff, uptime, which optional contracts run, and the state of `open77_doors`. |
| <a id="opx-admin-read-audit"></a>`/opx.admin.read.audit` | ACL `command.opx.admin.read.audit` | `[count]` (1–40, default 15) | Read. Shows the latest staff actions from the in-memory ring of `AUDIT_ENTRIES`. The ring is lost on restart. The platform audit log written with each entry is the lasting record. |

## Server contract {#server-contract}

`local admin = OPX.Api.Get('admin')` on the server, from code inside opx_infinity. Every member returns a Result table, never yields, and changes nothing. Every change is a command.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-admin-isstaff"></a>`IsStaff` | `playerId` | `{ ok = true, value = { staff } }` | `staff` is true when the ACL grants `command.opx.admin`. False when the ACL cannot be read. The console (`0`) is always staff. |
| <a id="server-admin-roster"></a>`Roster` | — | `{ ok = true, value = { rows } }` | One row per connected player: `id`, `name` (character, else account), `user` (account when a character is loaded), `citizenId`, `state` (`loading`, `gate`, `down`, `up`), `bucket`. |
| <a id="server-admin-recentactions"></a>`RecentActions` | `count?` (1–200, default 15) | `{ ok = true, value = { entries } }` | Newest last. Entry: `seq`, `atMs`, `event` (e.g. `admin.player.kill`), `ok`, `actor` (0 = console), `actorName`, `target`, `targetName`, `detail`. |

## Client contract {#client-contract}

`local admin = OPX.Api.Get('admin')` on the client, inside opx_infinity. Opening is only a request: the client sends `/opx.admin` and the ACL decides.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-admin-open"></a>`Open` | — | `Ok({ open = true })` if already open, `Ok({ queued = true })` if sent, `Err('not_sent')` | `queued` does not mean allowed. |
| <a id="client-admin-openat"></a>`OpenAt` | `screen, arg?, form?` | `Ok(true)` or `Err('not_sent')` | Opens on one screen over the root. Screens: `root`, `players`, `player`, `playerMove`, `playerHealth`, `playerCharacter`, `playerCharacters`, `character`, `offlineChars`, `playerItems`, `playerInventory`, `self`, `vehicles`, `vehicleClasses`, `vehicleList`, `pedFamilies`, `pedList`, `weaponList`, `ammoList`, `itemCategories`, `itemList`, `bag`, `locations`, `saved`, `world`, `dev`, `weather`, `time`, `server`, `confirm`. Unknown screen → `not_sent`. |
| <a id="client-admin-close"></a>`Close` | — | `Ok(true)` | Closes the menu and any form it opened. |
| <a id="client-admin-state"></a>`State` | — | `Ok({ open, screen })` | `screen` is the screen on top, or nil. |

## Events {#events}

Every client → server payload is checked on the server. None of them changes anything except noclip turning off. Lists arrive in chunks of `{ rows, offset, total?, done }`.

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-admin-open"></a>`opx:net:admin:open` | server → client | `{ access, aclKnown, inventory }` | Answer to `/opx.admin`. `access` maps command names the ACL grants to `true`. |
| <a id="opx-net-admin-access"></a>`opx:net:admin:access` | server → client | `{ access, aclKnown, inventory }` | Refreshed access map. Empty when the opener is no longer granted. |
| <a id="opx-net-admin-roster"></a>`opx:net:admin:roster` | server → client | chunk of roster rows (plus `distance` in metres in the same bucket) | The player list. |
| <a id="opx-net-admin-locations"></a>`opx:net:admin:locations` | server → client | chunk of `{ name, label, runtime }` | Saved locations. |
| <a id="opx-net-admin-items"></a>`opx:net:admin:items` | server → client | chunk of `{ name, label, category, weapon?, ammo? }`, `error?` | The inventory catalogue. |
| <a id="opx-net-admin-bag"></a>`opx:net:admin:bag` | server → client | chunk of `{ slot, name, count, label }`, `target`, `error?` | One holder's bag. |
| <a id="opx-net-admin-characters"></a>`opx:net:admin:characters` | server → client | chunk of character rows, `target`, `error?` | One account's characters. |
| <a id="opx-net-admin-found"></a>`opx:net:admin:found` | server → client | chunk of rows, `tag`, `mode`, `more?`, `cursor?`, `seenAt?`, `error?` | One page of the offline character search. |
| <a id="opx-net-admin-answer"></a>`opx:net:admin:answer` | server → client | `raw, ok, message, kind` | A command's answer to the operator. `kind` is `info`, `success`, `warning` or `error`. |
| <a id="opx-net-admin-travel"></a>`opx:net:admin:travel` | server → client | `action, value` | `noclip` (bool), `speed` (number), `mapPick` (bool), `copy` (clipboard row). |
| <a id="opx-net-admin-bodies"></a>`opx:net:admin:bodies` | server → client | `{ invisible, frozen, worn, wornSelf, models }` | State for the menu's and the eye's checkboxes. |
| <a id="opx-net-admin-tagsstate"></a>`opx:net:admin:tagsState` | server → client | `on, persist` | Name tags on or off. |
| <a id="opx-net-admin-tagrows"></a>`opx:net:admin:tagRows` | server → client | chunk of `{ id, name, staff? }` | Who to tag. |
| <a id="opx-net-admin-doors"></a>`opx:net:admin:doors` | server → client | chunk of `{ id, open, locked, sealed }` | All door states of the player's bucket. |
| <a id="opx-net-admin-door"></a>`opx:net:admin:door` | server → client | `id, state\|false` | One door changed. `false` means reset. |
| <a id="opx-net-admin-pvp"></a>`opx:net:admin:pvp` | server → client | `on` | Current PvP state, broadcast on change. |
| <a id="opx-net-admin-announce"></a>`opx:net:admin:announce` | server → client | `{ text, durationMs }` | An announcement. Each client wraps it in its own `ANNOUNCE.STINGER` clips. |
| <a id="opx-net-admin-refresh"></a>`opx:net:admin:refresh` | client → server | `topic, arg?` | Asks for a list: `roster`, `locations`, `access`, `items`, `bag`, `characters`, `found`. Requires the opener grant, plus the matching command for `bag`/`characters`/`found`. |
| <a id="opx-net-admin-noclipbody"></a>`opx:net:admin:noclipBody` | client → server | `false` | Noclip went off on the client, so the server stops hiding the body. |
| <a id="opx-net-admin-tagsrestore"></a>`opx:net:admin:tagsRestore` | client → server | — | Asks to turn the remembered name tags back on. The grant is checked again. |
| <a id="opx-net-admin-doorshello"></a>`opx:net:admin:doorsHello` | client → server | — | Asks for the bucket's door states again. |
| <a id="opx-net-admin-pvprequest"></a>`opx:net:admin:pvpRequest` | client → server | — | Asks for the current PvP state. |
| <a id="opx-net-admin-targetreport"></a>`opx:net:admin:targetReport` | client → server | `text` | A line about the eye's rows (including the grants it lacked) for the server journal. |
| <a id="opx-on-admin-tags"></a>`opx:on:admin:tags` | client, local | `{ kind, … }` | For a name tag view. `kind = 'config'` (colours, distance, labels), `'rows'` (`rows` of `playerId`, `entity`, `own`, `name`, `user`, `citizenId`, `staff`, `offsetZ`, `alpha`) or `'hide'`. Only resources in the same client VM receive it. |

What the module listens to from others:

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-on-downed-changed"></a>`opx:on:downed:changed` | client, local | `downed`'s payload | Keeps the menu key and the name tags working while the operator is down. See [`downed`](downed.md). |
| <a id="open77-command-result"></a>`open77:command:result` | server → client | `raw, accepted, message` | The host dispatcher's answer to a line the menu sent. Shown under the menu or as a toast. |

Every menu row, eye row and form ends in `open77:command:execute`, exactly as if typed in chat.

## Configuration {#configuration}

`config/admin.lua` sets `OPX.Config.MODULES.admin`. It is a shared script, so every client downloads it: keep no secret in it. Keys marked *tunable* are defaults for a live panel entry (`ADMIN_*`), read when used. The rest are read at start.

| Key | Default | What it does |
|---|---|---|
| <a id="config-admin-enabled"></a>`enabled` | `true` | `false` switches the module off. |
| <a id="config-admin-keys"></a>`KEYS` | `{ MENU = 'F9', SPEED_UP = 'PAGEUP', SPEED_DOWN = 'PAGEDOWN' }` | Default key mappings players can rebind in the pause menu. `false` registers none. The speed keys change the noclip speed. |
| <a id="config-admin-rate"></a>`RATE` | `{ ACTION_MS = 400, READ_MS = 1000, REFRESH_MS = 750 }` | Per-operator cooldowns: actions, reads, menu list refreshes. Tunable (`ADMIN_RATE_ACTION_MS`, `_READ_MS`, `_REFRESH_MS`). |
| <a id="config-admin-audit-entries"></a>`AUDIT_ENTRIES` | `200` | Size of the in-memory audit ring (10–2000). Tunable. |
| <a id="config-admin-toast-ms"></a>`TOAST_MS` | `6000` | How long a target's toast stays up. Tunable. |
| <a id="config-admin-placement"></a>`PLACEMENT` | `{ HEALTH = 1.0, GRACE_MS = 5000, BESIDE = { X = 1.5, Y = 0.0, Z = 0.0 }, OBSERVE_HEIGHT = 2.0 }` | How a moved player lands: health fraction, respawn grace (tunable), offset for goto/bring, height for observe. |
| <a id="config-admin-noclip"></a>`NOCLIP` | `{ SPEED = 40.0, MIN_SPEED = 1.0, MAX_SPEED = 500.0, STEP = 0.15, SEND_AFTER_MS = 500, PROMPTS = true, EFFECT = '', EFFECT_SECONDS = 1.5, SOUND = '', HIDE_BODY = true }` | Client side. Speed range and step, the delay before a key-chosen speed is sent (never less than `RATE.ACTION_MS` + 100), on-screen prompts, a VFX alias and a sound played when noclip toggles (empty means none), and whether the client reports noclip going off so the body comes back. |
| <a id="config-admin-target"></a>`TARGET` | `{ DISTANCE = 10.0 }` | Reach of the staff rows on the eye, 1–12 m. |
| <a id="config-admin-models"></a>`MODELS` | `{ RESET_ON_DEATH = true, DURATION_MS = 0 }` | A worn ped: whether death gives the own body back, and how long it lasts (0 = until removed, at most one day). |
| <a id="config-admin-combat"></a>`COMBAT` | `{ PVP = true }` | PvP state at server start. |
| <a id="config-admin-tags"></a>`TAGS` | `DISTANCE = 25.0`, `FADE_START = 0.55`, `HEAD_LIFT = 0.35`, `HEAD_OFFSET_Z = 2.05`, `UPDATE_MS = 250`, `REFRESH_MS = 2000`, `MAX = 32`, `OWN = false`, `HIDE_IN_FIRST_PERSON = false`, `TECHNICAL = true`, `USERNAME = true`, `CITIZEN = true`, `BADGE = true`, `COLORS = { TEXT = '#F2F6F8', ACCENT = '#FCEE0A', STAFF = '#22D8E2', BACKGROUND = '#0A1220' }` | Name tags. `REFRESH_MS` is the server's list interval (tunable `ADMIN_TAGS_REFRESH_MS`). The rest is client drawing: reach, fade, height, cap, own tag, id square, account, citizen id, staff badge, colours. |
| <a id="config-admin-announce"></a>`ANNOUNCE` | `{ DURATION_MS = 12000, CHAT = true, MAX_CHARACTERS = 240, STINGER = { OPEN = 'announce-open.mp3', CLOSE = 'announce-close.mp3', VOLUME = 0.8 } }` | Announcement lifetime (tunable), chat copy, length cap, and the clips played before and after. A clip is a bare file name in the resource's `audio/`. `''` turns a clip off, and an invalid name is dropped. |
| <a id="config-admin-ban-durations"></a>`BAN_DURATIONS` | `{ '1h', '1d', '7d', '30d', 'perm' }` | Durations the ban form offers. A typed ban accepts any valid duration. |
| <a id="config-admin-vehicles"></a>`VEHICLES` | `{ SPAWN_OFFSET = { X = 3.0, Y = 0.0, Z = 0.25 }, AV_LIFT = 1.2, PER_OWNER = 8, NEAR_RADIUS = 30.0, OCCUPIED_REPAIRS = { glass = true, body = true, lights = true, tires = true, visual = true }, FLAGS = { 'locked', 'engineOn', 'lightsOn', 'invulnerable' } }` | Spawn offset, AV lift, cap per player (tunable), `near` radius (tunable), repairs allowed with people aboard, flags `vehicle.flag` accepts. Which records are AVs comes from `AV_PREFIXES` in `config/shared.lua`. |
| <a id="config-admin-inventory"></a>`INVENTORY` | `{ MAX_COUNT = 10000, DEFAULT_AMMO = 60 }` | Largest count a give or removal accepts (tunable), and the ammunition count when none is typed. |
| <a id="config-admin-doors"></a>`DOORS` | `{ MAX_PER_BUCKET = 256, SWEEP_MS = 2000, SCAN_MS = 1000, SCAN_RADIUS = 80 }` | Staff door states, used only when `open77_doors` is not running: per-bucket cap, server bucket sweep, client scan interval and radius (at most 100 m). |
| <a id="config-admin-links"></a>`LINKS` | `PLAYERS = 'opx.players'`, `WHERE = 'opx.where'`, `JOB = 'opx.job'`, `GANG = 'opx.gang'`, `MONEY = 'opx.money'`, `SAVE = 'opx.save'`, `INVENTORY_OPEN = 'opx.inventory.open'`, `INVENTORY_HOLDERS = 'opx.inventory.holders'`, `WEATHER_SET = 'opx.weather.set'`, `WEATHER_NEXT = 'opx.weather.next'`, `WEATHER_FREEZE = 'opx.weather.freeze'`, `TIME = 'opx.time'`, `TIME_FREEZE = 'opx.time.freeze'` | Other modules' commands that the menu and the eye run. `false` removes the row. They appear in the access map, so they are greyed by the same ACL. |
| <a id="config-admin-weather-presets"></a>`WEATHER_PRESETS` | `{ 'sunny', 'lightclouds', 'cloudy', 'rain', 'heavyclouds', 'fog', 'pollution', 'sandstorm' }` | Weather names offered on the sky screen and the eye. They must be `NAME`s from the `weather` config. |
| <a id="config-admin-times"></a>`TIMES` | `{ '06:00', '09:00', '12:00', '17:30', '20:30', '23:00', '03:00' }` | Clock times offered on the time screen. |
| <a id="config-admin-locations"></a>`LOCATIONS` | 11 rows (`watson`, `heights`, `coast`, `stoop`, `northside`, `junction`, `underpass`, `dealer`, `racegrid`, `lab`, `arena`) | Configured destinations: `{ NAME, LABEL, X, Y, Z, HEADING }`. `NAME` must be a slug. `/opx.admin.self.pos` copies a row in this shape. |

The spawn list is `modules/admin/data/vehicles.lua` (277 rows in classes, Air first). The ped list is `modules/admin/data/peds.lua` (250 ordinary human rigs). A malformed row causes a warning at boot and is skipped.

## Refusal codes {#codes}

The operator reads the locale key `admin.error.<camelCase>` (for example `bad_target` → `admin.error.badTarget`). Codes about typed input are shown as warnings, the others as errors.

| Code | Meaning |
|---|---|
| `in_game_only` | The command needs a player, not the console. |
| `too_fast` | Inside the operator's cooldown. |
| `failed` | The handler raised an error. The log names it. |
| `no_target`, `bad_target`, `not_connected`, `self_target`, `console_has_no_player` | Target missing, malformed, offline, the caller where that is not allowed, or `me` from the console. |
| `not_incarnated`, `gate_closed`, `gate_unreadable` | The player's body cannot be acted on yet. |
| `no_position` | The host has no position for the player. |
| `kill_refused`, `respawn_refused`, `refused` | The host refused. The host's reason is shown. |
| `bad_coordinates`, `bad_switch`, `bad_duration`, `empty_text` | Malformed argument. |
| `unknown_vehicle`, `vehicle_cap`, `no_vehicle`, `occupied`, `unsafe_repair`, `bad_scope`, `unknown_flag`, `not_ours`, `vehicles_unavailable`, `keys_unavailable` | Vehicle commands. |
| `unknown_weapon`, `unknown_ammo`, `holster_unavailable`, `give_partial` | Weapon commands. `give_partial`: the weapon was given, the ammunition was refused, and the weapon could not be taken back. |
| `inventory_unavailable`, `bad_holder`, `no_character`, `unknown_citizen`, `unknown_item`, `bad_count`, `not_enough`, `bag_no_room`, `bag_too_heavy`, `bad_amount`, `bad_type`, `vetoed` | Inventory or character contract refusals. |
| `unknown_location`, `bad_location_name`, `seeded_location` | Locations. |
| `bad_door`, `door_limit`, `doors_networked`, `doors_unavailable` | Doors. |
| `combat_unavailable` | The host has no `Open77.combat.setFriendlyFire`. |
| `unknown_ped`, `models_unavailable` | Ped models. |
| `bad_name`, `characters_unavailable`, `search_short`, `bad_request` | Character commands. |
