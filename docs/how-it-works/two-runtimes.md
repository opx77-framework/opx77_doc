---
title: The two runtimes
description: The Open77 dedicated server and game client run Lua differently — no require on the server, a per-resume instruction budget on the client, no metatables in shared code — and opx_infinity is shaped by those limits.
---

# Two runtimes

Open77 runs Lua in two places: the **dedicated server** and the **game client**.
They are not the same sandbox. Most surprises in `opx_infinity` come from one of
the differences below.

| | Server | Client |
|---|---|---|
| `require` | **no** | yes (used for `opx_lib`) |
| `load`, `loadfile`, `dofile` | no | no |
| `LoadResourceFile` | own resource only | own resource only |
| `setmetatable`, `getmetatable` | yes | **no** |
| Instruction budget | none (limit of 1,024 tasks) | **per resume; an overrun stops the coroutine silently** |
| `TriggerEvent` reaches | every server resource | this resource only |
| `GetGameTimer` | yes | no — use [`OPX.Now()`](../reference/core.md#opx-now) on both |
| Logs (`Open77.log`) | the server journal | a file on the player's machine |

## Shared scripts run on both {#shared}

A `shared_script` runs in **both** sandboxes, so it may only use what both
have: no `require`, no metatables. The CI of `opx_infinity` checks this
(`tools/check-sandbox-globals.py`).

## Load order {#load-order}

Scripts load in the order of `open77.lua`, with one platform rule on top: **all
`shared_script` files run before any `server_script` or `client_script`.** A
`shared_script` listed below a `server_script` still runs first. This is why
`M.Settings` must not be captured at file scope (see
[Settings](modules-and-contracts.md#settings)).

## The client instruction budget {#budget}

The client limits how many instructions a coroutine may run before it yields.
Going over raises `Open77 script execution budget exceeded` and ends that
coroutine. A loop that hits it does not crash, does not repeat and often logs
nothing: it just stops.

How `opx_infinity` copes:

- every lifecycle phase yields one frame after each module;
- repeating client work goes through one [scheduler](scheduler.md) loop that
  runs at most four jobs per resume;
- heavy per-frame work (for example the `target` module) is cut into slices.

If a client feature "stops working" with no error, suspect the budget first.
Client module failures are forwarded to the server journal as
`client module: <id> failed ...` lines by the
[diagnostics module](../modules/diagnostics.md).

## Why there is no server library {#no-server-lib}

The server has no `require` and cannot read another resource's files, so no
resource can load code into a server VM. That is why `opx_lib` is client-only
and why server code uses the helpers in [`lib/shared/`](../reference/lib.md),
which are loaded by `opx_infinity`'s own manifest and installed on `OPX`.

## Never guess a native {#natives}

Open77 natives are not FiveM natives. Look every one up with the Open77 devkit
before using it, and declare the manifest permission it needs (see
[Permissions](permissions.md)).
