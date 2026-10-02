---
title: Install OPX//77 on a server
description: Install the opx_lib and opx_infinity resources on an Open77 dedicated server, connect the database, grant staff rights and check the boot log.
---

# Install a server

OPX//77 is two resources: `opx_lib` (a client library) and `opx_infinity` (the
framework). This page installs both on an Open77 dedicated server and checks that
they started.

## What you need {#needs}

| Need | Why |
|---|---|
| An Open77 dedicated server | `opx_infinity` declares `open77_version ">=0.0.1"`. |
| A MySQL database | Characters, inventories, vehicles… Without it the server boots but nobody can load a character. |
| `opx_lib` | `opx_infinity` declares `dependency "opx_lib"`; the platform will not start it without `opx_lib` running. |
| The platform's `open77_notifications` (recommended) | Server toasts sent with `OPX.Notify` go through `Open77.notifications.send`, which is drawn by that package on the client (shipped load lists start it). Without it those toasts are not shown. Refusals and command answers are drawn by `opx_infinity` itself. |

## 1. Copy the two resources {#copy}

Put each repository in its own folder under the server's resource root. The
folder name **must** equal the resource name:

```text
resources/
  opx_lib/          open77.lua, init.lua, pure/, client/, boot/
  opx_infinity/     open77.lua, config/, core/, lib/, locales/, modules/, web/
```

`opx_infinity` only needs `open77.lua config core lib locales modules web` on the
server. `ui/`, `tests/` and `tools/` are for development; the built page is
`web/index.html`. To deploy a commit rather than a working tree:

```bash
git archive --format=tar HEAD open77.lua config core lib locales modules web \
  | gzip | ssh root@<host> 'cd /opt/open77-server/resources/opx_infinity && tar xzf -'
```

## 2. Load them in order {#load}

In `server.jsonc`, list `opx_lib` **before** `opx_infinity` in `resources.load`:

```jsonc
"resources": {
  "load": [
    // ... the platform's own resources ...
    "opx_lib",
    "opx_infinity"
  ]
}
```

## 3. Connect the database {#database}

Give the server a MySQL connection string, either in `server.jsonc`:

```jsonc
"database": { "enabled": true, "connectionString": "Server=...;Database=...;User ID=...;Password=..." }
```

or in the environment variable named by `database.connectionStringEnvironmentVariable`
(`OP77_DATABASE_CONNECTION` by default). See the platform's *Configure a SQL
database* guide for the details. The tables are created at the first boot; there
is nothing to import.

## 4. Grant staff rights {#acl}

Staff commands are restricted. Add rights to the server's ACL file (named by
`accessControl.file` in `server.jsonc`, usually `acl.jsonc`). A staff role
typically needs:

```text
command.opx.admin          open the staff menu (F9)
command.opx.admin.*        use the rows inside it
command.opx.garages.*      garage staff commands
command.opx.dealership.*   dealer staff commands
command.opx.clothing.*     wardrobe store commands
command.opx.weather.*      weather controls
command.opx.time           the clock
command.opx.time.*
```

See [Permissions](../how-it-works/permissions.md#acl) for why both
`command.opx.admin` and `command.opx.admin.*` are needed, and each
[module page](../modules/index.md) for its commands.

## 5. Start and read the log {#check}

Restart the server and read the journal. A healthy boot ends with one line per
module and a version line:

```text
[storage] schema ready: N table(s)
[module] character     started
[module] inventory     started
...
opx_infinity 0.1.2 up
```

| If you see | It means | Fix |
|---|---|---|
| `no database: nobody will be able to connect until this is fixed.` | The database is not reachable. | Check the connection string, restart. |
| `opx_infinity ... up -- degraded: <reason>` | Boot finished with a problem. | Read the reason; see [Troubleshooting](troubleshooting.md). |
| `[module] <id> unavailable requires "<other>", ...` | A required module is off or failed. | Fix or enable `<other>`. |
| `[boot] <name> is running and also places players` | Another resource also places players. | Remove it, or accept the conflict (see [`CONFLICTING_PLACERS`](../reference/core-config.md#config-server-conflicting-placers)). |

Run `/opx.modules` (staff) or `/opx.version` for the same report later, and
`/opx.client` in a game client's console for the client side.

## Next {#next}

[Configure the server](configure.md).
