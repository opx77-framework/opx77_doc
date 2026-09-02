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

- An OPEN//77 dedicated server. This documentation was written against
  `open77-server-2.31.4+op77.11`.
- A MySQL-compatible database, for `opx77_core`. Without one, `OPX.Storage`
  degrades to a pair of logged errors and a refusal to log anybody in — the rest
  of the server still boots.
- **A resource that emits `open77:session:gameplayReady`.** In practice that is
  the platform's own `open77_appearance`. It is not part of OPX//77 and OPX//77
  does not declare it as a dependency, but without it the platform's readiness
  gate never opens for anybody. [What that costs](#the-appearance-requirement) is
  below, and the mechanism is set out in
  [The entry gate](../concepts/entry-gate.md).

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
    ├── opx77_weather/
    └── opx77_elevators/
```

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

The rules are **ordered**: normal entries add matches, an entry prefixed with `!`
removes earlier matches. So to load everything except the elevators:

```jsonc
"load": ["*", "!opx77_elevators"]
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

Every resource holding `database.access` talks to the same database with the same
credential — there is no per-resource schema or table prefix. All `opx77_core`
tables are prefixed `opx77_`.

If the database is missing or unreachable, `opx77_core` logs

```text
no database: <reason>
the core will boot, but nobody can be logged in until this is fixed
```

and carries on with every login refused. See
[Troubleshooting](troubleshooting.md#no-database).

## 3. Staff commands and the ACL {#acl}

Twenty-four commands are registered across the seven resources. Sixteen of them
pass `true` as the third argument to `RegisterCommand`, which makes them
**restricted**: the host resolves `command.<name>` against the caller's ACL
*before* the resource's handler runs, so there is no permission check inside any
OPX//77 command and there must not be one. The dedicated console runs as
`source = 0` and is always authorised.

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

### Every restricted command {#restricted-commands}

These sixteen resolve an ACL permission before they run. The permission is always
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
likewise `COMMAND` in `opx77_elevators/config.lua`.

### The eight commands that need no permission {#open-commands}

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
`open77:session:gameplayReady`. On a stock OPEN//77 server that event comes from
`open77_appearance`, once it has seen that the local puppet is attached, alive
and past the "press any key to continue" screen.

If nothing on your server emits it, the readiness gate never opens for anybody:
`Open77.ready.isReady` stays `false` for the whole session, `onPlayerReady` never
fires, and the host logs one WRN naming `__platform` per connected player every
60 seconds.

`opx77_core` is unaffected — it neither reads `isReady` nor waits on
`onPlayerReady`, so characters still load and are still placed — but it checks
for the resource at boot and says so:

```text
no resource here emits `open77:session:gameplayReady`
  so the platform's own `__platform` hold never clears: the readiness gate
  never opens, `Open77.ready.isReady` is permanently false and the
  `onPlayerReady` handler in server/events.lua can never fire. The core is
  unaffected -- it reads neither -- but do not build on either of them, and
  expect one host WRN naming __platform per connected player.
```

Install `open77_appearance` alongside OPX//77 unless you have another resource
emitting that event. If you cannot, do not write any resource that waits on
`Open77.ready.isReady` or on `onPlayerReady`, because on your server they will
wait for ever. [The entry gate](../concepts/entry-gate.md) explains the whole
mechanism, including the hold `opx77_core` takes on top of it.

## 5. Reload policy {#reload-policy}

Each resource declares how a reload should be handled:

| Policy | Resources | Why |
|---|---|---|
| `local` | `opx77_core`, `opx77_weather`, `opx77_elevators` | A reload is a script reload, not a reconnect. `opx77_weather` hands its live state to the host and keeps the sky; `opx77_elevators` re-adopts lifts from the next client sighting. |
| `reconnect` | `opx77_menu`, `opx77_hud`, `opx77_status`, `opx77_chat` | A generation change or a CEF surface that is never replaced in place needs a clean reconnect. |

## 6. Configuration {#configuration}

`opx77_core` splits configuration by who may read it:

| File | Scope |
|---|---|
| `config/shared.lua` | values both sides need — **shipped to every client, never put a secret in it** |
| `config/server.lua` | slots, autosave, paychecks, entry deadlines |
| `config/client.lua` | client cadences — never loaded by the server VM |

Anything an operator may want to change mid-session is a **tunable** instead and
lives in `server/tunables.lua`, editable from the Warden operator panel without a
restart.

The satellites each have a single `config.lua`. Every key of every file is listed
under [Reference](../reference/index.md).

## 7. Check it came up {#check-it-came-up}

Start the server and watch the log. Each resource logs its own startup, and
failures are logged rather than thrown:

- `opx77_core` with no database: three ERR lines — two from `[storage]`, one
  from `[core]` — and every login refused.
- `opx77_core` with no `open77_appearance`: six WRN lines, and a permanently
  closed readiness gate. See [above](#the-appearance-requirement).
- `opx77_hud` with no core running: one log line, not a broken screen.
- `opx77_elevators` with no `opx77_menu`: one log line; the exports still work
  for a caller drawing its own panel.

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
