---
title: diagnostics module
description: Commands that report which modules started, the runtime version and contracts, and that carry interface errors to the server log.
---

# diagnostics

The `diagnostics` module answers "is it running?". `/opx.modules` lists every module with its state (started, disabled, failed…) and the repeating jobs; `/opx.version` prints the runtime version and every published contract; `/opx.client` prints the same for the player's own client. It also forwards errors from the in-game interface, and client modules that failed to start, to the **server** log, so an operator sees them without asking the player for their log file.

| | |
|---|---|
| Side | both |
| Requires | nothing |
| Configuration | none |

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-modules"></a>`/opx.modules` | ACL `command.opx.modules` | — | Lists modules (`module`, `state`, `reason`) and scheduler jobs (`job`, `every`, `state`). |
| <a id="opx-version"></a>`/opx.version` | ACL `command.opx.version` | — | Prints `opx_infinity <version>`, `degraded: <reason>` if boot failed, and `contract <name> v<n>` for each contract. |
| <a id="opx-client"></a>`/opx.client` | everyone (client command) | — | Prints the client's version, module states and jobs. |

From the server console the answers are printed there. From a player, every line goes to that player's **client log**, not to chat. `/opx.client` also writes to the client log only.

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-diagnostics-page"></a>`opx:net:diagnostics:page` | client → server | `text` | One interface error, cut to 400 characters. Written to the server log as `[page] player <id>: <text>`. At most 20 per client session and 20 per player per minute on the server. |
| <a id="opx-net-diagnostics-lines"></a>`opx:net:diagnostics:lines` | server → client | `lines` | The answer to `/opx.modules` or `/opx.version`, one string per line. |

Two seconds after start, the client also reports each client module that is not `started` (or `absent`) to the server log through `OPX.Note`, under `modules`.

## Page channels {#page-channels}

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-diag"></a>`diag` | page → Lua | `{ text }` | A view threw and was removed from the page. Forwarded on `opx:net:diagnostics:page`. Listened on the `overlay` surface. |
