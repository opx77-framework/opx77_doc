---
title: Getting started — installing OPX//77 on an OPEN//77 server
description: Where the OPX//77 resources go on an OPEN//77 dedicated server, the server.jsonc block that loads them, the acl.jsonc principal that grants the staff commands, and the one external resource without which no player is ever placed.
---

# Getting started

This page covers installing OPX//77 on an OPEN//77 dedicated server: where the
resources go, how the server is told to load them, which of the commands need an
ACL entry, and the load-order rule that decides whether anything works at all.

!!! warning "Early development"

    OPX//77 is not production-ready. The API and internals change without
    notice.

## Requirements {#requirements}

- An OPEN//77 dedicated server. This documentation is written against
  `open77-server-2.31.13+op77.63`.
- A MySQL-compatible database, for `opx77_core`. Without one, `OPX.Storage`
  degrades to a pair of logged errors and a refusal to log anybody in — the rest
  of the server still boots.
- **A resource that emits `open77:session:gameplayReady`.** `opx77_appearance`
  ships with OPX//77 and is that resource, so a full install already satisfies
  this. Nothing declares it as a dependency, and without it the platform's
  readiness gate never opens for anybody. The same resource spends the character
  bootstrap at join, which is what lifts the platform's loading cover, and hands
  every player's look to the others, which is what lets players see each other.
  The platform's own `open77_appearance`, which the core's boot check also
  accepts, is not a stand-in for it, and must not run beside it.
  [What that costs](#the-appearance-requirement) is below, and the mechanism is
  set out in [The entry gate](../concepts/entry-gate.md).

Every OPX//77 resource declares `open77_version ">=0.0.1"` and `auto_start true`.

## 1. Put the resources in place {#place-the-resources}

Copy each resource directory into the server's resources root, one directory per
resource, keeping the directory name identical to the `resource "..."` name in
its `open77.lua`:

```text
open77-server/
└── resources/
    ├── opx77_core/
    ├── opx77_menu/
    ├── opx77_hud/
    ├── opx77_chat/
    ├── opx77_status/
    ├── opx77_notify/
    ├── opx77_weather/
    ├── opx77_elevators/
    ├── opx77_appearance/
    ├── opx77_input/
    ├── opx77_charselector/
    ├── opx77_charcreator/
    ├── opx77_animations/
    ├── opx77_admin/
    └── opx77_inventory/
```

Three of them are what a player needs to get into the world at all:
`opx77_appearance` spends the character bootstrap so the world loads,
`opx77_charselector` draws the roster in it, and `opx77_charcreator` — with
`opx77_input` drawing its form — makes the first character. None of them is
declared a dependency of anything, so leaving one out is not refused at boot; it
is found out by the first player who joins.

!!! danger "Do not put anything else in `resources/`"

    The server scans this directory and tries to load every match as a game
    resource. A documentation checkout, a build directory or a stray archive
    placed here will be picked up.

## 2. The `server.jsonc` resources block {#server-jsonc}

Resource loading is configured in `server.jsonc`, at the server root. Start from
`server.example.jsonc`:

```jsonc
"resources": {
  "enabled": true,
  "root": "resources",
  // Ordered directory rules, resolved from root (absolute paths also work).
  // Normal entries add matches; ! removes earlier matches. `*` is one folder
  // level, `**` is recursive. Omitting this field keeps the ["*"] default.
  "load": ["*"],
  "autoStart": true,
  "watchIntervalMilliseconds": 1000,
  "download": {
    "enabled": true,
    "listenUrl": "http://0.0.0.0:11779",
    "publicBaseUrl": "http://127.0.0.1:11779/",
    "cacheDirectory": ".open77/resource-cache",
    "signingKeyFile": ".open77/resource-signing-key.json",
    "chunkSizeBytes": 1048576
  }
}
```

`"load": ["*"]` loads everything in `root`, which is the simplest setup. To load
only OPX//77 and nothing else, name the resources explicitly:

```jsonc
"load": ["opx77_*"]
```

That picks up all fifteen. Naming them one by one does the same and makes the
set explicit:

```jsonc
"load": [
  "opx77_core",
  "opx77_menu", "opx77_input", "opx77_notify",
  "opx77_appearance", "opx77_charselector", "opx77_charcreator",
  "opx77_hud", "opx77_chat", "opx77_status",
  "opx77_weather", "opx77_elevators", "opx77_animations", "opx77_admin",
  "opx77_inventory"
]
```

`opx77_inventory` stores every bag through `opx77_core`'s server exports and
needs `opx77_core` 0.4.0 or later: keep it **after** `opx77_core` — see
[`opx77_inventory`](../reference/opx77_inventory/index.md#requirements).

The rules are **ordered**: normal entries add matches, an entry prefixed with `!`
removes earlier matches. So to load everything except the elevators and the
staff tool:

```jsonc
"load": ["*", "!opx77_elevators", "!opx77_admin"]
```

`watchIntervalMilliseconds` is how often the server rescans for changes, with a
floor of 250 ms and a ceiling of 60 000 ms.

`server.example.jsonc` ships with `"root": "../resources"`, but the `resources/`
directory sits **next to** `server.jsonc`, not one level up. Use
`"root": "resources"`.

### The database {#database}

`opx77_core` requires the `database.access` permission, which needs the database
to be enabled:

```jsonc
"database": {
  "enabled": true,
  "connectionStringEnvironmentVariable": "OP77_DATABASE_CONNECTION",
  "maxRows": 10000
}
```

!!! danger "Keep `server.jsonc` credential-free"

    A connection string *is* a credential. Export it in the environment rather
    than writing it into the tracked config file:

    ```bash
    export OP77_DATABASE_CONNECTION='Server=localhost;Port=3306;Database=open77;User ID=open77;Password=...;SslMode=None'
    ```

    An explicit `connectionString` key still wins when both are present, for
    operator overlays and containers. Prefer a local-only account.

Two resources hold `database.access`: `opx77_core`, for the character, and
`opx77_status`, for the one table it owns. They talk to the same database with
the same credential — there is no per-resource schema or table prefix — and
every table either creates is prefixed `opx77_`. Each applies its own schema at
boot; `opx77_core/sql/` and `opx77_status/sql/` hold the statements in a form an
operator can read and run by hand.

!!! danger "There is no upgrade path from an older database"
    The core's character tables were renamed inside their original migrations,
    so a database created before this release keeps `opx77_accounts`,
    `opx77_players` and `opx77_player_groups` while the code queries
    `opx77_users`, `opx77_characters` and `opx77_character_groups`. Drop it and
    let the runner recreate it. See
    [Persistence](../concepts/persistence.md#schema).

If the database is missing or unreachable, `opx77_core` logs

```text
[storage] no database: <reason>
[storage] the core will boot, but nobody can be logged in until this is fixed
```

and carries on with every login refused. See
[Troubleshooting](troubleshooting.md#no-database).

### The connection gate deadline {#connect-gate-timeout}

One more key is worth knowing about even though no OPX//77 resource reads it:

```jsonc
"simulation": {
  // how long a resource holding players.gate may hold a connecting player
  "connectGateTimeoutSeconds": 8
}
```

Default 8, allowed 0.5 to 9. The client abandons the handshake at 10 seconds
either way, so a longer wait would only trade one error for another. At the
deadline the player is refused with `connection_gate_timeout`.

This matters the moment you add a whitelist or a ban list, because a gate that
defers and never answers refuses **everybody**. See
[Connection control](../concepts/connection-gate.md) for the gate itself and
[Troubleshooting](troubleshooting.md#nobody-connects) for the symptom.

!!! note "The ACL and the gate are different doors"

    The ACL below governs *commands* — who may run `opx77.money`. The gate
    governs *access* — who may connect at all. Neither one implies the other,
    and an ACL entry does not let anybody past a whitelist.

## 3. Staff commands and the ACL {#acl}

Seventy-six commands are registered across the fifteen resources. Sixty-four of
them pass `true` as the third argument to `RegisterCommand`, which makes them
**restricted**: the host resolves `command.<name>` against the caller's ACL
*before* the resource's handler runs, so there is no permission check inside any
OPX//77 command and there must not be one. The dedicated console runs as
`source = 0` and is always authorised. Forty-three of the sixty-four are
[`opx77_admin`](../reference/opx77_admin/index.md)'s, and every one of those is
restricted with no setting to open it; five are
[`opx77_inventory`](../reference/opx77_inventory/index.md)'s, likewise always
restricted.

### Writing `acl.jsonc` {#acl-file}

`server.jsonc` names the ACL file:

```jsonc
"accessControl": {
  "file": "acl.jsonc"
}
```

A principal is matched on the 64 bytes of public key certified during the
handshake, and — if the entry carries one — on the `userId` as well. The
displayed nickname and the temporary `playerId` never take part in
authorisation, so neither of them can be used to grant anything.

The player exports their own principal by typing `identity.dump` in the OPEN//77
developer terminal (`²`); the file it writes contains a ready-to-copy
`aclPrincipal` object with the `userId`, the P-256 public key and its
fingerprint. Paste that object into `principals` and add the permissions:

```jsonc
{
  "version": 1,
  "principals": [
    {
      "name": "owner",
      "userId": "8f0f3a7c-2e11-4d59-9a63-5c1f0a2d47b8",
      "publicKey": "BFq2n1x9O8k7c2Yv0m3Qw1sT4uJ6hR8pL5aZ...",
      "permissions": [
        "command.opx77",
        "command.opx77.*"
      ]
    },
    {
      "name": "weather-desk",
      "userId": "1c4b9e02-77aa-4d38-8f10-6b2ecb90d51e",
      "publicKey": "BJ7yQ0d4kM2hV8n1pR6sT3uW5xZ9aC0eG2iL4oN...",
      "permissions": [
        "command.opx77.weather.*"
      ]
    }
  ]
}
```

Reload it without restarting the server with `acl.reload` in the administration
console. `acl.list` reports the path actually loaded, and
`acl.check <playerId> <permission>` answers the exact question the host will ask.

!!! warning "`command.opx77.*` does not cover `command.opx77`"

    A trailing wildcard grants every permission *below* the prefix. The bare
    command `opx77` — the one that prints the roster — is `command.opx77`, which
    is not below `command.opx77.`, so a principal holding only
    `command.opx77.*` is refused it. Grant both, as the example above does, or
    grant `*`.

!!! warning "The staff menu is `command.opx77.admin`, not `command.opx77.admin.*`"

    The same rule, one level down. `opx77.admin` opens `opx77_admin`'s staff
    menu, and its permission `command.opx77.admin` is not below
    `command.opx77.admin.`, so a principal granted only
    `command.opx77.admin.*` can type every staff command and cannot open the
    menu. A staff principal wants both:

    ```jsonc
    "permissions": [
      "command.opx77.admin",
      "command.opx77.admin.*"
    ]
    ```

    `command.opx77.*` covers all forty-three, the menu included — and with them
    every other OPX//77 staff command, the core's `opx77.money` and the
    inventory's `opx77.inventory.give` among them.
    Grant a narrower prefix, such as `command.opx77.admin.read.*` or
    `command.opx77.admin.player.*`, to give a moderator one family of commands.
    The menu greys out whatever the ACL would refuse.

### Every restricted command {#restricted-commands}

These twenty-one resolve an ACL permission before they run, and so do the
forty-three of `opx77_admin` [below](#admin-commands). The permission is always
`command.` plus the command name exactly as registered.

| Permission | Resource | What the command does |
|---|---|---|
| `command.opx77` | `opx77_core` | Version, session count, and one line per loaded character. |
| `command.opx77.where` | `opx77_core` | Everything the **server** believes about one player: session, gate, life phase, position, job, gang, balances. |
| `command.opx77.here` | `opx77_core` | Prints the caller's position already formatted as a `DEFAULT_SPAWN` block. |
| `command.opx77.whois` | `opx77_core` | The `userId` and display name behind a player id. |
| `command.opx77.money` | `opx77_core` | `<playerId\|citizenId> <TYPE> <amount>`; a negative amount removes. |
| `command.opx77.job` | `opx77_core` | `<playerId\|citizenId> <job> [grade]`. |
| `command.opx77.gang` | `opx77_core` | `<playerId\|citizenId> <gang> [grade]`. |
| `command.opx77.group` | `opx77_core` | `<job\|gang> <name>` — the roster of one group. |
| `command.opx77.save` | `opx77_core` | Writes every loaded character back now, for the minute before a planned restart. |
| `command.opx77.weather.set` | `opx77_weather` | `<preset> [seconds]` — cross to a preset. |
| `command.opx77.weather.next` | `opx77_weather` | Roll the weighted table now, even while frozen. |
| `command.opx77.weather.freeze` | `opx77_weather` | `<on\|off>` — hold the weather **schedule**. |
| `command.opx77.weather.time` | `opx77_weather` | `<HH:MM[:SS]>` — set the authoritative clock. |
| `command.opx77.weather.time.freeze` | `opx77_weather` | `<on\|off>` — hold the clock. |
| `command.opx77.weather.daylength` | `opx77_weather` | `<realMinutes>` — how long a day takes. |
| `command.opx77.elevators.where` | `opx77_elevators` | Adoption state and world positions for every configured lift. |
| `command.opx77.inventory.give` | `opx77_inventory` | `<playerId\|citizenId> <item> [count]` — adds items to a bag. Creates items: grant it like money. |
| `command.opx77.inventory.remove` | `opx77_inventory` | `<playerId\|citizenId> <item> [count]` — takes items from a bag. |
| `command.opx77.inventory.clear` | `opx77_inventory` | `<playerId\|citizenId>` — empties a bag. |
| `command.opx77.inventory.open` | `opx77_inventory` | `<playerId\|citizenId>` — opens that bag beside your own; in game only. |
| `command.opx77.inventory.holders` | `opx77_inventory` | `<item>` — the containers holding an item, largest stacks first. |

The eight names in that table beginning `opx77.weather` are the *shipped
defaults*. Every one of them is `COMMANDS.<KEY>.NAME` in
`opx77_weather/config.lua` and can be renamed or switched off with
`NAME = false`; the ACL permission follows whatever name you give it. The six
mutating ones are restricted unless the config says `RESTRICTED = false`
explicitly — a missing, misspelled or quoted flag leaves them shut — and setting
it to `false` logs

```text
command <name> is OPEN to every player (COMMANDS.<KEY>.RESTRICTED = false)
```

at boot, once, so the decision is on the record. `opx77.elevators.where` is
likewise `COMMAND` in `opx77_elevators/config.lua`, and the five
`opx77.inventory.*` names are
[`COMMANDS`](../reference/opx77_inventory/config.md#commands) in
`opx77_inventory/config.lua`, where `false` registers none — they are always
restricted.

### `opx77_admin`'s forty-three {#admin-commands}

Every one is registered restricted, and the names are fixed in the resource
rather than read from its configuration. A `<player>` is a player id or `me`,
never a citizen id. A `<holder>` — the weapon and inventory commands but the
holster — is a player id, `me` or a citizen id, online or not. Each is documented
in full, with its refusals, under
[`opx77_admin`'s commands](../reference/opx77_admin/commands.md).

| Permission | What the command does |
|---|---|
| `command.opx77.admin` | Opens or closes the staff menu. |
| `command.opx77.admin.self.noclip` | `[on\|off]` — noclip. |
| `command.opx77.admin.self.speed` | `<m/s>` — noclip speed, 0.1–500. |
| `command.opx77.admin.self.maptravel` | `[on\|off]` — arm map double-click travel, or `<x> <y> <z>` to jump. |
| `command.opx77.admin.self.god` | `[on\|off]` — your own god mode. |
| `command.opx77.admin.self.heal` | Heals yourself. |
| `command.opx77.admin.self.revive` | Revives yourself. |
| `command.opx77.admin.self.pos` | Copies your position as a `LOCATIONS` row. |
| `command.opx77.admin.player.goto` | `<player>` — teleport beside them. |
| `command.opx77.admin.player.bring` | `<player>` — bring them beside you. |
| `command.opx77.admin.player.tp` | `<player> <x> <y> <z> [heading]`. |
| `command.opx77.admin.player.send` | `<player> <location>` — to a saved destination. |
| `command.opx77.admin.player.observe` | `<player>` — land above them with noclip on. |
| `command.opx77.admin.player.heal` | `<player>` — heal to maximum. |
| `command.opx77.admin.player.revive` | `<player>` — revive where they lie. |
| `command.opx77.admin.player.god` | `<player> [on\|off]` — god mode. |
| `command.opx77.admin.player.health` | `<player> <points>`. |
| `command.opx77.admin.player.armor` | `<player> <points>` — 0–10000. |
| `command.opx77.admin.player.kill` | `<player>` — kill. |
| `command.opx77.admin.moderate.kick` | `<player> [reason]`. |
| `command.opx77.admin.moderate.ban` | `<player> [duration] [reason]` — an account ban on this server. |
| `command.opx77.admin.vehicle.spawn` | `<vehicle>` — beside you. |
| `command.opx77.admin.vehicle.give` | `<player> <vehicle>` — beside a player. |
| `command.opx77.admin.vehicle.repair` | `<id\|near> [scope]`. |
| `command.opx77.admin.vehicle.flag` | `<id\|near> <flag> [on\|off]`. |
| `command.opx77.admin.vehicle.remove` | `[id\|near\|mine]`. |
| `command.opx77.admin.vehicle.cleanup` | Removes every empty vehicle it spawned. |
| `command.opx77.admin.weapon.give` | `<holder> <weapon> [rounds]` — a loaded weapon item in the bag, through `opx77_inventory`. |
| `command.opx77.admin.weapon.ammo` | `<holder> [weapon\|all] [rounds]` — set the rounds of weapon items; a full load when left out. |
| `command.opx77.admin.weapon.remove` | `<holder> <weapon\|all>` — take weapon items out of the bag. |
| `command.opx77.admin.weapon.holster` | `<player>` — holster, through the platform's weapon relay. |
| `command.opx77.admin.weapon.read` | `<holder>` — the weapon items in the bag, and which one is drawn. |
| `command.opx77.admin.inventory.view` | `<holder>` — every stack in the bag. |
| `command.opx77.admin.inventory.give` | `<holder> <item> [count]` — add items. Creates items: grant it like money. |
| `command.opx77.admin.inventory.remove` | `<holder> <item> [count]` — take items. |
| `command.opx77.admin.inventory.clear` | `<holder>` — empty the bag. |
| `command.opx77.admin.world.announce` | `<text>` — a toast and a chat line to everyone. |
| `command.opx77.admin.world.loc.add` | `<name> [label]` — save a destination until restart. |
| `command.opx77.admin.world.loc.remove` | `<name>` — forget one saved in game. |
| `command.opx77.admin.read.players` | Connected players: state, bucket, distance. |
| `command.opx77.admin.read.status` | Counts, uptime, dependency states. |
| `command.opx77.admin.read.audit` | `[count]` — recent staff actions. |
| `command.opx77.admin.read.locations` | Every destination. |

Several of the menu's screens run another resource's command rather than one of
these — `opx77.money`, `opx77.job`, `opx77.gang` and `opx77.where` for a
character, `opx77.inventory.open` and `opx77.inventory.holders` for a bag,
`opx77_weather`'s for the sky — so a staff principal needs those permissions too
for the menu to offer them. Every weapon command but the holster, and every
inventory command, needs `opx77_inventory` running.

### The twelve commands that need no permission {#open-commands}

These are registered with `false` and are open to every player, deliberately:
they act on the caller's own character or their own screen.

| Command | Resource | Why it is open |
|---|---|---|
| `opx77.characters` | `opx77_core` | Lists *your* characters. |
| `opx77.select` | `opx77_core` | Enters the world as one of *your* characters. |
| `opx77.create` | `opx77_core` | Creates a character in one of *your* slots. |
| `opx77.delete` | `opx77_core` | Deletes one of *your* characters. |
| `opx77.duty` | `opx77_core` | Clocks *you* in or out; rate-limited to one run per 2 s. |
| `opx77.weather` | `opx77_weather` | Reads the time and sky. |
| `opx77.weather.presets` | `opx77_weather` | Lists what `.set` accepts. |
| `hud` | `opx77_hud` | Shows or hides *your own* HUD. |
| `opx77.anim` | `opx77_animations` | Plays an emote on *you*, or opens the picker. |
| `e` | `opx77_animations` | The same command, short. |
| `opx77.anim.stop` | `opx77_animations` | Stops *your own* animation. |
| `opx77.anim.list` | `opx77_animations` | Lists what `opx77.anim` accepts. |

`opx77_animations`' four are `COMMANDS.<KEY>.NAME` in its `config.lua`, like
the weather commands, and each can be closed with `RESTRICTED = true` or turned
off with `NAME = false`.

### Pinning the clock at boot {#startup-commands}

`server.jsonc` has a `startup.commands` list that runs once, in order, after the
server has finished starting — the equivalent of `exec` in a `server.cfg`. Each
line goes through the same dispatcher as the stdin console, carries that
authority and never a player's, and anything a resource registered with
`RegisterCommand` is fair game. A line the dispatcher refuses is logged at ERR
with its position and the server starts anyway.

```jsonc
"startup": {
  "commands": [
    "opx77.weather.time 20:30:00",
    "opx77.weather.set lightclouds"
  ]
}
```

Keep this list credential-free too.

## 4. The appearance requirement {#the-appearance-requirement}

Every player who joins arrives holding a platform hold called `__platform`. No
Lua may take it and no Lua may release it, it carries no deadline, and it clears
on exactly one thing: the client sending the net event
`open77:session:gameplayReady`. In this resource set that event comes from
[`opx77_appearance`](../reference/opx77_appearance/index.md), once it has seen
that this world attachment is the gameplay one — the character bootstrap is
`ready`, which is the only thing that tells it from the pre-game menu world —
that a character is loaded on its own body, and that this world entry's face has
been settled.

The same resource does a second thing no join can do without: it **spends the
character bootstrap at join**, before anybody is chosen. The platform keeps its
loading cover up until that bootstrap is spent, and nothing a server resource
draws is visible under the cover, so the world has to come first. It loads the
body of the account's most recently played character — or
[`BOOTSTRAP.DEFAULT_FAMILY`](../reference/opx77_appearance/config.md#bootstrap),
`"female"` as shipped, when there is none in time — and the cover lifts once
that world has streamed. The roster
([`opx77_charselector`](../reference/opx77_charselector/index.md)), the identity
form ([`opx77_charcreator`](../reference/opx77_charcreator/index.md), drawn by
[`opx77_input`](../reference/opx77_input/index.md)) and the face editor all
happen in the gameplay world afterwards, with the camera turned to face the
player's character. On a server where nothing spends the bootstrap, the cover
stays up for everybody. See
[The entry gate](../concepts/entry-gate.md#world-first) for the whole sequence.

If nothing on your server emits it, the readiness gate never opens for anybody:
`Open77.ready.isReady` stays `false` for the whole session, `onPlayerReady` never
fires, and the host logs one WRN naming `__platform` per connected player every
60 seconds.

`opx77_core` is unaffected — it neither reads `isReady` nor waits on
`onPlayerReady`, so characters still load and are still placed — but it checks
for the resource at boot and says so:

```text
[lifecycle] no resource here emits `open77:session:gameplayReady`, so the
`__platform` hold never clears and `Open77.ready.isReady` stays false
```

The check accepts either `opx77_appearance` or the official
`open77_appearance`, because both send the announcement. That does not make them
interchangeable: the official package follows
[the platform's own model](../concepts/entry-gate.md#platform-model), not this
framework's, and **running both conflicts** — they fight over the character
bootstrap and the face. Run `opx77_appearance`, and not the official package
beside it. If you run neither, do not write any resource that waits on
`Open77.ready.isReady` or on `onPlayerReady`, because on your server they will
wait for ever.

The same resource is also what lets players **see each other**. The engine
replicates a player's position, vehicle and actions, not their look, and another
client draws a player only from the body, equipment and outfit it is handed.
`opx77_appearance` hands every player's look to the others — what the official
package does with its `open77_equipment` and `open77_wardrobe` relays — so
without it, or with
[`PRESENT_BODIES = false`](../reference/opx77_appearance/config.md#present-bodies)
and nothing else handing looks out, nobody sees anybody else's body. See
[How other players see this one](../reference/opx77_appearance/index.md#presence).
[The entry gate](../concepts/entry-gate.md) explains the whole mechanism,
including the hold `opx77_core` takes on top of it.

## 5. Reload policy {#reload-policy}

Each resource declares how a reload should be handled:

| Policy | Resources | Why |
|---|---|---|
| `local` | `opx77_core`, `opx77_weather`, `opx77_elevators`, `opx77_appearance`, `opx77_charselector`, `opx77_animations`, `opx77_admin` | A reload is a script reload, not a reconnect. `opx77_weather` hands its live state to the host and keeps the sky; `opx77_elevators` re-adopts lifts from the next client sighting; `opx77_appearance` re-reads the face from `PlayerData` and keeps nothing across one. `opx77_charselector` and `opx77_admin` own no CEF surface: `opx77_menu` draws for them. |
| `reconnect` | `opx77_menu`, `opx77_input`, `opx77_hud`, `opx77_status`, `opx77_chat`, `opx77_notify`, `opx77_inventory` | A generation change or a CEF surface that is never replaced in place needs a clean reconnect. |
| none declared | `opx77_charcreator` | Its manifest names no policy. It owns no surface either: `opx77_input` draws its form. |

## 6. Configuration {#configuration}

`opx77_core` splits configuration by who may read it:

| File | Scope |
|---|---|
| `config/shared.lua` | values both sides need, the language and the appearance limits — **shipped to every client, never put a secret in it** |
| `config/server.lua` | slots, autosave, paychecks, entry deadlines |
| `config/vehicles.lua` | plate format, per-character ceiling, spawn offset |
| `config/client.lua` | client cadences — never loaded by the server VM |

Anything an operator may want to change mid-session is a **tunable** instead and
lives in `server/tunables.lua`, editable from the Warden operator panel without a
restart.

The satellites each have a single `config.lua`. Eleven of the fourteen — every one
but `opx77_menu`, `opx77_status` and `opx77_notify` — carry their own locale
catalogue in `locales/` and their own `LOCALE` key, because a satellite cannot
read the core's: that export is client-only and asynchronous, and a satellite's
server half can never call it.
`LOCALE` ships `"en"` everywhere, `opx77_core` included. Every key of every file
is listed under [Reference](../reference/index.md).

## 7. Check it came up {#check-it-came-up}

Start the server and watch the log. Each resource logs its own startup, and
failures are logged rather than thrown:

- `opx77_core` with no database: three ERR lines — two from `[storage]`, one
  from `[core]` — and every login refused.
- `opx77_core` with no appearance resource: one WRN line, and a permanently
  closed readiness gate. See [above](#the-appearance-requirement).
- `opx77_hud` with no core running: one log line, not a broken screen.
- `opx77_elevators` with no `opx77_menu`: one log line; the exports still work
  for a caller drawing its own panel.

Then join. The loading cover should lift within a few seconds of the resources
starting, the roster should come up in the world, and the client log should say
which body the world was loaded with — on a fresh account, the default:

```text
bootstrap (worldReady): loading the female body, no character played yet
character bootstrap resolved as female
```

If the cover never lifts, or the world loads with no roster in it, see
[Troubleshooting](troubleshooting.md#stuck-loading-screen) and
[the roster that never arrives](troubleshooting.md#roster-never-arrives).

In game, `/hud` toggles the HUD, and `opx77.weather` (open to everybody) prints
the current time and sky. `opx77.characters` lists your characters and
`opx77.select <citizenId>` puts you in the world as one of them.

When something did not come up, [Troubleshooting](troubleshooting.md) is
organised by the exact line the code prints.

## Where to go next {#next}

- [Writing a resource](writing-a-resource.md) — a complete client resource built
  against `opx77_core` and `opx77_menu`.
- [Writing a server plugin](writing-a-server-plugin.md) — the honest contract for
  anything that must be unforgeable.
- [Converting from ESX or Qbox](converting.md) — what your habits map onto here,
  and the four that do not map at all.
