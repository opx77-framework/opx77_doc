---
title: Troubleshooting
description: The log lines opx_infinity prints when something is wrong, what each one means, and what to do about it.
---

# Troubleshooting

Start with the server journal. `opx_infinity` names every problem it can see
there, including client-side module failures, which are forwarded to the server
as `client module: ...` lines. Search the journal for the text in the first
column.

## Boot {#boot}

| Log line | Meaning | Fix |
|---|---|---|
| `[storage] no database: ...` / `no database: nobody will be able to connect until this is fixed.` | The database is unreachable. The resource boots, but no character can load. | Fix the connection string and restart. A database that comes back later is only picked up by a restart. |
| `[storage] creating <table> failed: ...` | A `CREATE TABLE` failed. Boot is degraded (`schema failed`). | Check the database user's rights. |
| `opx_infinity <version> up -- degraded: <reason>` | Boot finished with a problem; the reason follows. | Read the lines above it. |
| `[<module>] init failed: ...` (or `api`, `start`) | A module raised in a phase and is `failed`. | Read the error. Its dependants become `unavailable`. |
| `[<module>] requires "<other>", which is ...` | A required module is off, missing or failed. | Enable or fix `<other>`. |
| `[<module>] contract "<name>" is withdrawn with it` | A failed module had published a contract; it is removed. | Fix the failing module. |
| `[boot] <name> is running and also places players` | Another resource also moves players. | Remove it. See [`CONFLICTING_PLACERS`](../reference/core-config.md#config-server-conflicting-placers). |
| `[commands] the alias "<alias>" for "<command>" was skipped: ...` | Another resource owns that short name. | Harmless; the long command works. Change the alias in [`COMMAND_ALIASES`](../reference/core-config.md#config-server-command-aliases). |
| `[tune] no tunables panel on this host; configured defaults are used` | Tunables cannot be changed live. | Harmless. |

## Players stuck at the loading screen {#stuck}

| Log line | Meaning | Fix |
|---|---|---|
| `[gate] no resource here emits ... so the __platform hold never clears` (names `open77:session:gameplayReady`) | Nobody tells the platform the player is in the world. The [appearance module](../modules/appearance.md) sends it. | Make sure `appearance` is `started`. |
| `[gate] <id> spent too long behind the gate; releasing without them` | The entry flow did not finish in time and the gate was opened anyway. | Read the lines about that player; check `character`, `spawn` and `form`. |
| `client module: form failed ...` (or any client module) | A client module failed, often on the instruction budget. | See [Two runtimes](../how-it-works/two-runtimes.md#budget). Report it with the full line. |

## Something on screen stopped working {#client}

| Symptom / log line | Meaning |
|---|---|
| `Open77 script execution budget exceeded` | The client instruction budget was exceeded; the coroutine that hit it stopped. |
| `[scheduler] <job> suspended after 3 failures` | A client job raised three times in a row and was cancelled for the session. The previous lines give the error. |
| `[boot] the surface could not be built: ...` | The WebUI page was not created; nothing will be drawn. |
| `[surface opx] <channel> not sent: ...` | A message to the page was refused (often the page is not ready yet). |

Ask the player to run `/opx.client` in the game console: it prints the client
module states and the job list to their client log.

## Staff menu or eye rows missing {#acl}

A row a role may not run is greyed in the staff menu and **not shown** on the
target eye. The admin module logs the missing grants once per registration, for
example:

```text
[admin] target rows, player 3: 25 staff rows on the eye; 12 hidden, this ACL does not grant: opx.inventory.open opx.weather.set
```

Add `command.<name>` for each listed name to `acl.jsonc`. See
[Permissions](../how-it-works/permissions.md#acl).

## Useful commands {#commands}

| Command | Where | Prints |
|---|---|---|
| `/opx.modules` | server (staff) | every module's state and reason |
| `/opx.version` | server (staff) | versions |
| `/opx.client` | client console | client module states and scheduler jobs |

See the [diagnostics module](../modules/diagnostics.md).
