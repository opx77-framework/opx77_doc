---
title: Modules, contracts and the lifecycle
description: How a module is declared, how modules depend on each other, how contracts are published and read, and the Init, Api, Start and Stop phases every module runs through.
---

# Modules and contracts

A **module** is one gameplay concern inside `opx_infinity`, in its own folder
under `modules/<id>/`. Modules never reach into each other's files. They talk
through **contracts**: a table of functions one module publishes and others ask
for by name. The registry (`core/shared/registry.lua`) and the lifecycle
(`core/shared/lifecycle.lua`) run all of this.

## Declaring a module {#declare}

`modules/<id>/module.lua` declares the module. It is a `shared_script`, so it
runs on both sides.

```lua
local M = OPX.Modules.Declare{
	id = 'thing',
	side = 'both',          -- 'server', 'client' or 'both'
	fatal = false,          -- true: the resource reports a failed boot if this module fails
	requires = { 'character' },   -- hard dependencies
	optional = { 'downed' },      -- soft dependencies: only change the order
}
```

| Field | Meaning |
|---|---|
| `id` | Required. Unique string. Declaring an id twice raises. |
| `side` | Where the module runs. Default `'both'`. On the other side it is marked `absent`. |
| `requires` | Modules that must be running. If one is missing, disabled or failed, this module is marked `unavailable` and never runs. |
| `optional` | Modules that run first when present. Nothing happens if they are missing. |
| `fatal` | When `true`, a failure of this module makes `OPX.Modules.Run` answer `false`. |

`Declare` returns the module's own table (`M`). The module's other files get it
back with `OPX.Modules.Get('<id>')` and hang their functions on it.

Two module tables never share fields with the runtime: the runtime only reads
`Settings` and the four phase functions from `M`.

### Settings {#settings}

`M.Settings` is `OPX.Config.MODULES[id]`, the table set by `config/<id>.lua`.

!!! warning "Do not copy `M.Settings` into a file-scope local"

    The platform runs every `shared_script` before any `server_script`. Three
    config files are server scripts (`config/server.lua`, `config/vehicles.lua`,
    `config/theme.lua`), so at declare time their module still sees an empty
    table. The registry re-points `M.Settings` at the real table once every file
    has loaded (`OPX.Modules.Rebind`). Read `M.Settings` inside your phases.

A config with `enabled = false` turns the module off: it is marked `disabled`
and its dependants become `unavailable`.

## The lifecycle {#lifecycle}

Every module goes through the same phases, in dependency order (a module runs
after everything it `requires` or lists as `optional`). A cycle between modules
is refused at boot with `module dependency cycle: a -> b -> a`.

| Phase | Use it to | Rules |
|---|---|---|
| `M.Init()` | Build state, read settings, add database tables (`OPX.Schema.Add`), declare tunables (`OPX.Tune.Declare`). | Do not call other modules. |
| `M.Api()` | Publish your contract with `OPX.Api.Provide`. | Contracts may only be published here. |
| `M.Start()` | Register events, commands, scheduler jobs; read the database. | Runs on a thread and may yield. |
| `M.Stop()` | Release what you hold: focus, controls, cameras, jobs. | Runs in reverse order, also for a module that failed half-way. |

Between `Api` and `Start` the server publishes the tunables and applies the
database schema, so `Start` is the first phase that may touch the database.

Each phase yields one frame (`Wait(0)`) after each module. This resets the
client's instruction budget between modules; see
[Two runtimes](two-runtimes.md#budget).

### Module states {#states}

`/opx.modules` (server) and `/opx.client` (client) print one line per module
with its state and reason. See the [diagnostics module](../modules/diagnostics.md).

| State | Meaning |
|---|---|
| `declared` | Waiting to run. |
| `started` | All phases ran. |
| `disabled` | `enabled = false` in its config. |
| `absent` | Its `side` is the other runtime. |
| `unavailable` | A required module is missing, disabled or failed. The reason names it. |
| `failed` | A phase raised. The reason is `<phase> failed: <error>`. |
| `stopped` | `Stop` ran. |

When a module fails, every contract it already published is withdrawn and its
dependants are dropped after the phase.

## Contracts {#contracts}

A contract is a plain table of functions with a name and a version. It is the
only supported way for one module to use another.

```lua
-- in modules/thing/server/main.lua
function M.Api()
	OPX.Api.Provide('thing', 1, {
		DoIt = function(source) ... end,
	})
end

-- in another module
local thing = OPX.Api.Get('thing')       -- nil when 'thing' is not running
if thing then thing.DoIt(source) end
```

| Function | Use |
|---|---|
| [`OPX.Api.Provide(name, version, table)`](../reference/core.md#opx-api-provide) | Publish. Only one module may provide a name; a second one raises. |
| [`OPX.Api.Get(name, minimum?)`](../reference/core.md#opx-api-get) | Read. Answers `nil` when nobody provides it (or only an older version). Use it for soft dependencies. |
| [`OPX.Api.Require(name, minimum?)`](../reference/core.md#opx-api-require) | Read or raise. Use it for a module listed in `requires`. |
| [`OPX.Api.Versions()`](../reference/core.md#opx-api-versions) | Every published contract, as `name -> version`. |

Contracts live in one Lua VM. The server and the client each have their own set,
and a separate resource cannot call them. Each module page lists its contract
under **Server contract** and **Client contract**; see the
[list of modules](../modules/index.md).

!!! info "Call `OPX.Api.Get` when you need it, not at file scope"

    Contracts exist only after the `Api` phase. Resolve them in `Start` or at the
    moment of use.
