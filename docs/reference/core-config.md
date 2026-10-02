---
title: Core configuration
description: Every key of config/shared.lua, config/server.lua and config/client.lua — the runtime's own settings, outside any module — with its shipped default.
---

# Core configuration

Three files hold the settings that belong to the runtime rather than to one module. `config/shared.lua` ships to every player, `config/server.lua` never leaves the server, and `config/client.lua` is read only on the client. Edit them to set the server name, the language, the money types, the health pool, the short command aliases, the entry gate and the WebUI page. Module settings live in `config/<module>.lua`; each module page lists its own.

| File | Script | Sets | Who can read it |
|---|---|---|---|
| `config/shared.lua` | `shared_script` | `OPX.Config.SHARED`, `OPX.Config.MODULES` | server and every client |
| `config/server.lua` | `server_script` | `OPX.Config.SERVER` | server only (`nil` on a client) |
| `config/client.lua` | `client_script` | `OPX.Config.CLIENT` | client only (`nil` on the server). Not trusted: a player can change it. |

Every value below is the shipped default.

## config/shared.lua {#shared}

Nothing secret belongs here: it is sent to every player.

| Key | Default | What it does |
|---|---|---|
| <a id="config-shared-locale"></a>`LOCALE` | `'en'` | Active language of the locale catalogue. English is always the fallback. Shipped catalogues: `en`, `fr`. |
| <a id="config-shared-server-name"></a>`SERVER_NAME` | `'OPEN//77'` | Title of every toast sent with `OPX.Notify`, and author of every command read-back (`OPX.CommandResult`). |
| <a id="config-shared-notify-position"></a>`NOTIFY_POSITION` | `'top-right'` | `position` passed to `Open77.notifications.send` by `OPX.Notify`. It does not move the runtime's own toasts (see [`TOASTS`](#config-client-toasts)). |
| <a id="config-shared-money"></a>`MONEY` | see below | Money types. Read by `character`, `inventory` and `admin`. See [MONEY](#money). |
| <a id="config-shared-health"></a>`HEALTH` | see below | The health pool every character is placed with, in points. Read by the `character` module, which applies it. |
| <a id="config-shared-av-prefixes"></a>`AV_PREFIXES` | `{ 'vehicle.av_', 'vehicle.max_tac_av' }` | A TweakDB vehicle record starting with one of these (compared lower-case) is an AV. Read only by [`OPX.Vehicle.IsAvRecord`](lib.md#opx-vehicle-isavrecord). An empty list falls back to the shipped pair. |

### MONEY {#money}

| Sub-key | Default | What it does |
|---|---|---|
| `DEFAULT` | `'EDDIES'` | The money type used when none is named (for example the paycheck fallback). |
| `TYPES` | `{ EDDIES = 'EDDIES', BANK = 'BANK' }` | Every money type a character has. A type not listed here is refused. |
| `ALLOW_NEGATIVE` | `{}` | Types whose balance may go below zero, as `{ BANK = true }`. |

### HEALTH {#health}

| Sub-key | Default | What it does |
|---|---|---|
| `MAX` | `250` | Maximum health in points, applied with `Open77.players.setMaxHealth`. The engine's own default is 100. |
| `LEGACY_FULL` | `100` | Stored health at or above this value is placed at full. Rows written before `MAX` existed are on a 0–100 scale. Do not raise it. |

### OPX.Config.MODULES {#modules}

`config/shared.lua` also creates `OPX.Config.MODULES = {}`. Each `config/<module>.lua` fills its own entry. The runtime reads one key from it: `enabled = false` switches a module off (its state becomes `disabled`). The file's comment also names a `provider` key; no code in this version reads it.

## config/server.lua {#server}

| Key | Default | What it does |
|---|---|---|
| <a id="config-server-conflicting-placers"></a>`CONFLICTING_PLACERS` | `{ 'open77_playerstate', 'freeroam', 'pursuit', 'race' }` | Resources that also place players. At boot, a warning is logged for each one that is running or starting. |
| <a id="config-server-autosave-ms"></a>`AUTOSAVE_MS` | `300000` | Not read by any code in this version. The `needs` module reads its own `AUTOSAVE_MS`. |
| <a id="config-server-sample-ms"></a>`SAMPLE_MS` | `1000` | Not read by any code in this version. `character` uses its own constant. |
| <a id="config-server-command-aliases"></a>`COMMAND_ALIASES` | see below | Short names for commands, full name → alias. Empty the table to turn aliases off. |
| <a id="config-server-entry"></a>`ENTRY` | see below | The readiness gate and the selection bucket a player waits in. Each value is checked once at load; a bad one is logged and the shipped value is used. |
| <a id="config-server-exports"></a>`EXPORTS` | see [EXPORTS](#server-exports) | Who may call the [server exports](../creators/server-exports.md), and the rules for stashes created by them. |

### EXPORTS {#server-exports}

Who may call the creator exports in `core/server/exports.lua`. The caller is the resource name the host reports, never an argument. A list is `'*'`, a set `{ my_shop = true }` or an array `{ 'my_shop' }`.

| Key | Default | What it does |
|---|---|---|
| `READ` | `'*'` | Who may call the read exports (`GetPlayerData`, `GetMoney`, `HasJob`, `HasItem`, `IsStaff`…). |
| `WRITERS` | `{}` | Who may call the write exports (money, jobs, gangs, duty, metadata, revive, items, stashes, chat, keys, vehicle state). **Empty**: nobody until the operator adds a resource. A refused caller is answered `export.callerDenied`, audited, and the journal prints the line to add. `'*'` admits every resource (development only). |
| `STAFF_PERMISSION` | `'command.opx.admin'` | The ACL right the `IsStaff` export checks. |
| `METADATA.MAX_BYTES` | `4096` | `SetMetadata`: largest encoded size of one value. |
| `METADATA.MAX_KEYS` | `32` | `SetMetadata`: most keys one resource may keep on one character. |
| `METADATA.MAX_TOTAL_BYTES` | `16384` | `SetMetadata`: largest encoded size of all of one resource's keys on one character. |
| `STASHES.CREATE_CAP` | `25` | How many stashes one resource may create with `AddToStash`, named `<resource>.<name>`. Counted in the database. |
| `STASHES.IDLE_MS` | `60000` | A stash loaded by an export and not opened by a player is saved and put away this long after its last use. |

See [For creators](../creators/index.md#allowlist).

### COMMAND_ALIASES {#command-aliases}

The full name is still the command: it keeps working, and the ACL right is still `command.<full name>`. An alias is checked against that same right, so grant only the full name. An alias that cannot be registered (taken by another resource, not a legal name, or starting with `opx.`) is skipped with a warning in the log. [`OPX.Command.Aliases`](core.md#opx-command-aliases) lists what actually registered. See [Aliases and the ACL](core.md#aliases).

| Alias | Command | Owner |
|---|---|---|
| `chars` | `opx.characters` | [character](../modules/character.md) |
| `duty` | `opx.duty` | [character](../modules/character.md) |
| `withdraw` | `opx.withdraw` | [inventory](../modules/inventory.md) |
| `noclip` | `opx.admin.self.noclip` | [admin](../modules/admin.md) |
| `god` | `opx.admin.self.god` | [admin](../modules/admin.md) |
| `invis` | `opx.admin.self.invisible` | [admin](../modules/admin.md) |
| `heal` | `opx.admin.self.heal` | [admin](../modules/admin.md) |
| `revive` | `opx.admin.self.revive` | [admin](../modules/admin.md) |
| `speed` | `opx.admin.self.speed` | [admin](../modules/admin.md) |
| `pos` | `opx.admin.self.pos` | [admin](../modules/admin.md) |
| `goto` | `opx.admin.player.goto` | [admin](../modules/admin.md) |
| `bring` | `opx.admin.player.bring` | [admin](../modules/admin.md) |
| `tp` | `opx.admin.player.tp` | [admin](../modules/admin.md) |
| `freeze` | `opx.admin.player.freeze` | [admin](../modules/admin.md) |
| `spectate` | `opx.admin.player.observe` | [admin](../modules/admin.md) |
| `addweapon` | `opx.admin.weapon.give` | [admin](../modules/admin.md) |
| `addammo` | `opx.admin.weapon.giveammo` | [admin](../modules/admin.md) |
| `delweapon` | `opx.admin.weapon.remove` | [admin](../modules/admin.md) |
| `car` | `opx.admin.vehicle.spawn` | [admin](../modules/admin.md) |
| `fix` | `opx.admin.vehicle.repair` | [admin](../modules/admin.md) |
| `dv` | `opx.admin.vehicle.remove` | [admin](../modules/admin.md) |
| `announce` | `opx.admin.world.announce` | [admin](../modules/admin.md) |

No alias is shipped for `opx.admin`, for irreversible commands (ban, kick, kill, character delete, `opx.delete`), or for generic words such as `give` or `weather`.

### ENTRY {#entry}

| Sub-key | Default | What it does |
|---|---|---|
| `GATE_MS` | `300000` | Liveness interval declared to the readiness gate, in ms. A watchdog on the core, not a limit on the player. Clamped to 1000–600000. |
| `WATCH_MS` | `240000` | How long [`OPX.Gate.Watch`](core.md#opx-gate-watch) waits before giving up on a player. Must be below `GATE_MS`; otherwise 80 % of `GATE_MS` is used and an error is logged. |
| `BUCKET.ISOLATE` | `true` | Put each player in their own selection bucket until a character is placed. `false` moves nobody. |
| `BUCKET.BASE` | `77000` | A player's selection bucket is `BASE + playerId`, so the range is `BASE+1 .. BASE+65535`. |
| `BUCKET.WORLD` | `0` | The shared bucket characters are placed in. A value inside the selection range is an error, and isolation is switched off. |
| `BUCKET.POPULATION` | `false` | Ambient population inside a selection bucket. |
| `BUCKET.LOCKDOWN` | `'relaxed'` | Lockdown mode of a selection bucket: `inactive`, `relaxed`, `strict` or `full`. `false` leaves the host's mode alone. |

## config/client.lua {#client}

| Key | Default | What it does |
|---|---|---|
| <a id="config-client-surface"></a>`SURFACE` | `{ layer = 'hud', zIndex = 700, fps = 60 }` | The one WebUI page. `layer`: `hud`, `menu`, `modal`, `system` or `debug` (`system` needs the `webui.system` permission; an unknown value becomes `hud`). `fps` is fixed when the page is created. |
| <a id="config-client-exports"></a>`EXPORTS` | `{ CALLERS = '*', REPLY = 'OnOpxEvent' }` | The [client exports](../creators/client-exports.md). `CALLERS`: who may call them, including `Subscribe` (`'*'`, a set or an array). `REPLY`: the export of the caller that receives answers when a call names no `reply`. A client config is advice, not a lock: the server re-checks anything that matters. |
| <a id="config-client-toasts"></a>`TOASTS` | `{ position = 'top_right', width = 340 }` | Where the runtime's own toasts stack, and their width in px. `position`: `top_left`, `top_center`, `top_right`, `middle_left`, `bottom_left`, `bottom_center` or `bottom_right`. The page refuses an unknown name and keeps its default. |
