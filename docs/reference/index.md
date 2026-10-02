---
title: API reference
description: Lookup pages for the opx_infinity core runtime (OPX.*), its configuration, runtime events, the shared lib/ helpers, the opx_lib client library and the shared error codes.
---

# API reference

These pages list every function, setting and event that is **not** owned by a
single module. Module APIs (contracts, commands, events, settings) are on each
[module page](../modules/index.md).

| Page | What is on it | Side |
|---|---|---|
| [Core runtime](core.md) | `OPX.Modules`, `OPX.Api`, `OPX.Event`, `OPX.Scheduler`, `OPX.Command`, toasts and answers, the entry gate, buckets, sessions, tunables, `OPX.UI` | both |
| [Core configuration](core-config.md) | `config/shared.lua`, `config/server.lua`, `config/client.lua`, command aliases | both |
| [Runtime events and channels](runtime-events.md) | the core's own network events, host event names, the core page channels | both |
| [Shared library](lib.md) | `OPX.Result`, `OPX.Text`, `OPX.Math`, `OPX.JobGate`, `OPX.Spots`, `OPX.Hooks`, `OPX.Locale`, `OPX.Storage`, `OPX.Audit`, `OPX.Surface`… | both / server / client |
| [opx_lib](opx-lib.md) | the separate client library resource | client |
| [Error codes](error-codes.md) | the shared refusal codes and the `Result` convention | both |

## Reading the tables {#conventions}

| Column | Meaning |
|---|---|
| Side | `server`, `client` or `both` — where the function exists. |
| Parameters | In call order. `name?` is optional. |
| Returns | `Result` means `{ ok = true, value = … }` or `{ ok = false, error = code, detail = … }`. `ok, code` means two values. |
| Yields | The call waits (database, network). Call it from a thread. |

All of these are reachable only from code running **inside** `opx_infinity`,
except `opx_lib`, which any client resource can `require`.
