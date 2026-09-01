# Getting started

This page covers installing OPX//77 on an Open77 dedicated server: where the
resources go, how the server is told to load them, and the load-order rule
that decides whether anything works at all.

!!! warning "Early development"

    OPX//77 is not production-ready. The API and internals change without
    notice.

## Requirements

- An Open77 dedicated server. This documentation was written against
  `open77-server-2.31.4+op77.11`.
- A MySQL-compatible database, for `opx77_core`. Without one, `OPX.Storage`
  degrades to a single logged line and a refusal to log anybody in — the rest
  of the server still boots.

Every resource declares `open77_version ">=0.0.1"` and `auto_start true`.

## 1. Put the resources in place

Copy each resource directory into the server's resources root, one directory
per resource, keeping the directory name identical to the `resource "..."` name
in its `open77.lua`:

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

## 2. The `server.jsonc` resources block

Resource loading is configured in `server.jsonc`, at the server root. Start
from `server.example.jsonc`:

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

`"load": ["*"]` loads everything in `root`, which is the simplest setup. To
load only OPX//77 and nothing else, name the resources explicitly:

```jsonc
"load": ["opx77_*"]
```

The rules are **ordered**: normal entries add matches, an entry prefixed with
`!` removes earlier matches. So to load everything except the elevators:

```jsonc
"load": ["*", "!opx77_elevators"]
```

`watchIntervalMilliseconds` is how often the server rescans for changes, with a
floor of 250 ms and a ceiling of 60 000 ms.

!!! note "`root` is relative to the server root"

    `server.example.jsonc` ships with `"root": "../resources"`, but the
    `resources/` directory sits **next to** `server.jsonc`, not one level up.
    Use `"root": "resources"`.

### The database

`opx77_core` requires the `database.access` permission, which needs the
database to be enabled:

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

Every resource holding `database.access` talks to the same database with the
same credential — there is no per-resource schema or table prefix. All
`opx77_core` tables are prefixed `opx77_`.

### Staff commands and the ACL

`opx77_weather` registers its mutating commands as **restricted**, so the host
resolves `command.<name>` against the caller's ACL before the resource runs.
Grant them in `acl.jsonc`, which `server.jsonc` names under `accessControl`. A
trailing wildcard covers the whole desk:

```text
command.opx77.weather.*
```

Console helpers: `acl.reload`, `acl.list`,
`acl.check <playerId> <permission>`.

### Pinning the clock at boot

`server.jsonc` has a `startup.commands` list that runs once, in order, after
the server has finished starting — the equivalent of `exec` in a `server.cfg`.
Each line goes through the same dispatcher as the stdin console, carries that
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

## 3. Reload policy

Each resource declares how a reload should be handled:

| Policy | Resources | Why |
|---|---|---|
| `local` | `opx77_core`, `opx77_chat`, `opx77_weather`, `opx77_elevators` | A reload is a script reload, not a reconnect. `opx77_weather` hands its live state to the host and keeps the sky; `opx77_elevators` re-adopts lifts from the next client sighting. |
| `reconnect` | `opx77_menu`, `opx77_hud`, `opx77_status` | A generation change or a CEF surface that is never replaced in place needs a clean reconnect. |

## 4. Configuration

`opx77_core` splits configuration by who may read it:

| File | Scope |
|---|---|
| `config/shared.lua` | values both sides need — **shipped to every client, never put a secret in it** |
| `config/server.lua` | slots, autosave, paychecks, entry deadlines |
| `config/client.lua` | client cadences — never loaded by the server VM |

Anything an operator may want to change mid-session is a **tunable** instead
and lives in `server/tunables.lua`, editable from the Warden operator panel
without a restart.

The satellites each have a single `config.lua`. See their pages for what is in
it.

## 5. Check it came up

Start the server and watch the log. Each resource logs its own startup, and
failures are logged rather than thrown:

- `opx77_core` with no database: one line, and logins are refused.
- `opx77_hud` with no core running: one log line, not a broken screen.
- `opx77_elevators` with no `opx77_menu`: one log line; the exports still work
  for a caller drawing its own panel.

In game, `/hud` toggles the HUD, and `opx77.weather` (open to everybody)
prints the current time and sky.
