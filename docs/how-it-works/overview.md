---
title: How OPX//77 is built
description: OPX//77 is one Open77 resource, opx_infinity, made of a small core runtime and about thirty modules, plus a client library resource, opx_lib.
---

# Overview

OPX//77 is a roleplay framework for Open77, the multiplayer platform for
Cyberpunk 2077. Since September 2026 it ships as **one resource**,
`opx_infinity`, plus a small client library resource, `opx_lib`. Read this page
first if you want to change the framework or write code against it.

## Two resources {#two-resources}

| Resource | What it is | Runs code on |
|---|---|---|
| `opx_infinity` | The whole framework: core runtime, every module, the WebUI page. | server and client |
| `opx_lib` | A client library. Other resources load it with `require('@opx_lib')`. `opx_infinity` reaches it as `OPX.Lib`. | client only (see [opx_lib](../reference/opx-lib.md)) |

`opx_infinity` declares `dependency "opx_lib"`, so the platform refuses to start
it unless `opx_lib` is running.

## What is inside opx_infinity {#layout}

```text
open77.lua          the manifest; load order is this file, top to bottom
config/             operator settings, one file per module
core/               the runtime: registry, lifecycle, channels, schedulers, commands, UI
lib/shared/         helpers on both runtimes, installed as OPX.*
lib/server/         storage (database) and audit
lib/client/         the opx_lib bridge and the WebUI surface
modules/<id>/       one gameplay concern each
  module.lua        the declaration: id, side, dependencies, events
  shared/ server/ client/
  data/             catalogues
  locales.lua       English and French text
locales/            runtime-wide text
ui/src/             the Vue sources of the WebUI page (never shipped)
web/                the built page and the join screen (shipped)
tests/              a stub platform (host.lua) and the test suite (run.lua)
```

## The pieces {#pieces}

| Piece | One-line summary | Read more |
|---|---|---|
| Module | One gameplay concern: `character`, `inventory`, `garages`… | [Modules and contracts](modules-and-contracts.md) |
| Contract | The table of functions a module offers other modules. | [Modules and contracts](modules-and-contracts.md#contracts) |
| Lifecycle | `Init`, `Api`, `Start`, `Stop`, run for every module in dependency order. | [Modules and contracts](modules-and-contracts.md#lifecycle) |
| Event channels | `opx:net:`, `opx:on:`, `opx:in:` event names. | [Events and channels](events.md) |
| Scheduler | `OPX.Scheduler.Every` — the way to run repeating work. | [The scheduler](scheduler.md) |
| Server authority | The server re-checks everything a client sends. | [Server authority](server-authority.md) |
| WebUI page | One CEF page for every module's screens. | [The WebUI page](webui.md) |
| Storage | `OPX.Storage` over the platform's MySQL bridge. | [Storage](storage.md) |

## How it starts {#boot}

On the **server**, `core/server/boot.lua` starts a thread that:

1. checks the database (`OPX.Storage.Ready()`); with no database it logs
   `no database: nobody will be able to connect until this is fixed.`;
2. runs every module's `Init` and `Api` phases;
3. publishes the tunables (`OPX.Tune.Publish`) and applies the database schema
   (`OPX.Schema.Apply`);
4. runs every module's `Start`;
5. prints one `[module]` line per module and `opx_infinity <version> up`
   (with `-- degraded: <reason>` when something failed).

On the **client**, `core/client/boot.lua` builds the WebUI surface and the toast
layer, runs the module phases, then starts the client scheduler loop.

Both sides stop modules in reverse order when the resource stops.

## What the framework does not offer {#limits}

- **Only a curated export set.** A module inside the resource uses
  [contracts](modules-and-contracts.md#contracts). A separate resource gets the
  server and client exports and the public server events described in
  [For creators](../creators/index.md), and nothing else.
- **No server library.** The server sandbox has no `require`, so `opx_lib` is
  client only. Server and shared code use the helpers in
  [`lib/`](../reference/lib.md).
