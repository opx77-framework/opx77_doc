---
title: Writing a resource against OPX//77
description: A complete client resource built end to end against opx77_core and opx77_menu — the manifest with no globs, the three-level export failure check, the local event bus, the ownership rule for your own exports, and teardown on onClientResourceStop.
---

# Writing a resource

This page builds one small resource from nothing: **`nc_shiftboard`**, a shift
board that reads the player's job from `opx77_core`, draws a floor-plan menu with
`opx77_menu`, and asks its own server half for something. It is deliberately the
smallest thing that touches every part of the contract you will meet again.

It is modelled on the platform's own resources — `open77_zones`,
`open77_worldui` and `pursuit` — because that is the house style you will find
everywhere else on OPEN//77, and because those three between them demonstrate
every rule below in shipped code.

!!! info "Read this first"

    [The export contract](../concepts/export-contract.md) is the one-page version
    of the call shape used throughout. If you are arriving from FiveM, read
    [Converting from ESX or Qbox](converting.md) as well — the biggest surprises
    are in the first three sections of it.

## What we are building {#what-we-are-building}

A player types `/shift`. If they hold one of the jobs the board knows about, a
menu opens listing their employer, their grade and a "request a kit" row.
Choosing that row sends a request to the resource's own server half, which
answers with a notification.

Three things make it a worked example rather than a toy:

- it reads state that lives in **another resource**, over the asynchronous
  export channel;
- it draws on a surface **another resource owns**, and is told which row was
  chosen by an **event**, because a callback cannot cross the boundary;
- it has a server half that **cannot check the job**, which is the honest shape
  of every third-party server resource on this platform and the reason
  [Writing a server plugin](writing-a-server-plugin.md) exists.

## 1. The layout {#layout}

```text
resources/nc_shiftboard/
  open77.lua
  shared/config.lua
  shared/locale.lua
  locales/en.lua
  locales/fr.lua
  client/main.lua
  client/board.lua
  server/main.lua
```

`server/` files are never included in the client package, so anything secret or
authoritative belongs there and nowhere else. `shared/` is compiled into both
VMs, which means a value you put in it is **shipped to every client** — treat it
as public.

## 2. The manifest {#manifest}

```lua
resource "nc_shiftboard"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

-- A script reload, not a reconnect: this resource owns no CEF surface of its
-- own -- the panel is opx77_menu's -- so both halves can simply rebuild.
reload_policy "local"

-- No dependency is declared on purpose. A declared dependency is HARD: the host
-- refuses the resource outright with `missing_dependency:<name>` when one is
-- absent. opx77_menu is optional here (a server with its own interaction UI
-- should still be able to run this), and opx77_core is consulted through an
-- export that answers a reason when it is not running.
dependencies {
}

-- Load order is manifest order, and the two client files depend on it:
-- client/main.lua builds the `Shiftboard` global, client/board.lua hangs the
-- panel off it. Swapping these two lines breaks the resource at load, not at
-- runtime.
shared_script "shared/config.lua"
shared_script "shared/locale.lua" -- after the config: LOCALE is read at load
shared_script "locales/en.lua" -- registered right after the catalogue, so no
shared_script "locales/fr.lua" -- file below calls locale() against an empty one
client_script "client/main.lua"
client_script "client/board.lua"
server_script "server/main.lua"

permissions {
  -- The chat command lands server-side and the answer goes back over the wire;
  -- both halves of that need network.events. Nothing else is required: reading
  -- the character through opx77_core's export costs no permission at all.
  "network.events",
}
```

!!! danger "Never glob a flat script directory"

    `client_scripts { "client/**/*.lua" }` requires an intermediate directory and
    matches **nothing** against a flat `client/main.lua`. An empty glob does not
    warn and does not skip the file — the client refuses the **whole resource
    set** with `script_pattern_empty:client/**/*.lua`, and *no player can
    connect to the server at all*. Every shipped OPEN//77 resource lists its
    scripts one per line for this reason. `**` is only safe under `web_files`.

## 3. The config {#config}

```lua
-- shared/config.lua
-- Shipped to every client. Nothing secret goes in here.
NC_SHIFTBOARD = {
  COMMAND = "shift",

  -- Job names as they appear in opx77_core/data/jobs.lua.
  JOBS = { ncpd = true, trauma = true, merc = true },

  -- The event opx77_menu raises when a row is chosen. It is OUR name, and the
  -- menu echoes it back to us -- see section 6.
  MENU_EVENT = "nc_shiftboard:row",

  -- Which locales/<code>.lua catalogue player-facing text is read from.
  LOCALE = "en",
}
```

### Player-facing text {#locale}

A resource that shows a player a word carries its own catalogue. Ten of the
thirteen shipped satellites do — every one but `opx77_menu`, `opx77_status` and
`opx77_notify` — and the shape is the same in each of them, copied from
`opx77_core/shared/locale.lua` and adapted to the resource's own namespace:

- `shared/locale.lua` — `register`, `set`, `current`, `exists`, `t`, and a
  `locale(key, params)` shorthand, with `{placeholder}` substitution.
- `locales/en.lua` and `locales/fr.lua` — one `register` call each.

The three manifest lines in [section 2](#manifest) come before every file that
renders a string, and that order is not negotiable: a file that calls `locale()`
before the catalogues are registered gets the key back instead of the text.

**You cannot borrow the core's.** `opx77_core` publishes a
[`Locale`](../reference/opx77_core/exports/client.md#locale) export, but it is
client-only and asynchronous: a server half can never call it, and a file that
renders a string at load cannot wait on it. That is the whole reason `LOCALE`
appears a second time in your own `config.lua` on a server that has already set
one in `config/shared.lua`.

Name keys `<resource>.<thing>` — `shiftboard.onDuty`, `weather.usage.set`,
`elevators.floorLocked` — and keep both catalogues carrying the same key set: a
key present in one and missing in the other is a defect, not a fallback.

What gets localised is anything a **player** reads: a command's answer, toast
and notification text, chat suggestions, refusal text shown in a UI. What does
not: `Open77.log` lines, console output, ACL-gated diagnostic commands — those
are for the operator reading a server log, and translating them makes a support
request harder to answer. Error **codes** stay as they are too;
`not_owner` and `rate_limited` are a branching surface for a caller, not text,
and a resource that wants to show one renders it through its own catalogue.

Operator-authored strings in a `config.lua` — an elevator's `REASON`, a preset's
label — are the server owner's own words. Leave them alone.

## 4. Calling another resource {#calling}

Everything OPX//77 and the platform expose to you is a **client** export,
because the client runtime is the only one with `exports` and
`GetInvokingResource`. Three things surprise everyone:

- there is no `exports.<resource>:<name>()` proxy — indexing the function raises
  *attempt to index a function value*;
- the call is asynchronous, always, and `await` only works inside a
  `CreateThread`;
- **failure has three levels, and they mean different things.**

Write the plumbing once, at the top of `client/main.lua`:

```lua
--- One call to another resource's export.
---
--- Three levels, because collapsing them turns a remote refusal into a silent
--- nil:
---   1. `Open77.exports.call` answers nil plus a reason when the call could not
---      be DISPATCHED -- the resource is missing, stopped or reloading.
---   2. `promise:await()` answers a second error when it was dispatched and
---      RESOLUTION failed -- the handler raised.
---   3. The resource's own answer. Every OPX//77 and OPEN//77 export replies
---      with a plain `{ ok = boolean, ... }`, because the value crosses a codec
---      and lands in code that does not have the framework loaded.
---@return table|nil result, string|nil reason
local function call(resource, name, ...)
  local promise, dispatchError = Open77.exports.call(resource, name, ...)
  if not promise then return nil, dispatchError end

  local result, callError = promise:await()
  if callError then return nil, callError end
  if type(result) ~= "table" then return nil, "malformed_response" end
  if not result.ok then return nil, result.error or "refused" end

  return result
end

-- Published on the resource's own global so client/board.lua can use it. One
-- plain global per resource, filled in by the files below it in the manifest,
-- is the shape every first-party OPEN//77 resource uses.
Shiftboard = Shiftboard or {}
Shiftboard.call = call
```

!!! warning "A dispatch failure and a refusal mean opposite things"

    A call the target **answered and refused** is authoritative: the answer is
    no, and it will still be no in a second. A call that **never landed** says
    nothing at all — the target may simply be restarting. A caller that caches
    something should let the cache age out on a dispatch failure rather than
    throw it away, and should never treat "not dispatched" as "not permitted".

    The platform's own example collapses these — it writes
    `local result = promise:await()` and discards the rejection reason. Do not
    copy it.

Because `await` is coroutine-only, every use of `call` is inside a
`CreateThread`. An export handler is **not** a coroutine, so an export of yours
that needs to call out must queue the work and answer "asked", not "done" —
`Board.open` in section 6 shows the shape.

## 5. Knowing who the player is {#player-state}

`opx77_core` publishes the loaded character two ways, and the two vocabularies
share no name.

The one you want is the **local** bus. The core's client half raises these with
`TriggerEvent` *after* its own mirror has been updated, so a handler can ask for
`GetPlayerData` and see the change that woke it. You listen with a bare
`AddEventHandler` and you need **no permission at all** — the client local event
bus is host-wide on this platform, which the platform's own resources rely on
(`open77_zones` fires a caller-supplied event name and `pursuit`, a different
resource, receives it with a bare `AddEventHandler`).

| Local event | Raised when |
|---|---|
| `opx77:client:onPlayerLoaded` | a character entered the world; carries `PlayerData` |
| `opx77:client:onPlayerUnloaded` | the character left |
| `opx77:client:playerDataChanged` | any field changed; carries the whole `PlayerData` |
| `opx77:client:jobChanged` | the job or duty state changed; carries the job |
| `opx77:client:gangChanged` | the gang changed |
| `opx77:client:moneyChanged` | a balance changed |
| `opx77:client:appearanceSaved` | the core stored a new face; carries the snapshot |
| `opx77:client:refused` | the server refused a request; carries `(code, kind, operation)` |

`opx77:client:refused` hands you three arguments, and the third is the one to
branch on: it names which request the refusal answers — `selectCharacter`,
`saveAppearance`, `spawnVehicle` and so on, from `OPX.Operations`. A resource
with more than one request in flight cannot otherwise tell whose `error.tooFast`
it is holding. The vocabulary lives in the core's own Lua state and cannot be
imported, so compare the string; the values are listed in
[the core's event reference](../reference/opx77_core/events.md#refused).

The second vocabulary — `opx77:client:playerLoaded`,
`opx77:client:setPlayerData`, `opx77:client:onJobUpdate`, … — is what the server
actually sends over the wire. Listening on those requires `network.events` in
your manifest and `RegisterNetEvent`. Take it only if you want the wire itself.

```lua
-- client/main.lua (continued)
local Config = NC_SHIFTBOARD
local CORE = "opx77_core"

--- Our own mirror of the one field this resource cares about. Refreshed from
--- the core rather than derived, because the core is the only thing that knows.
local job = nil

--- The job the player currently holds, or nil. client/board.lua reads it
--- through this rather than through a second mirror of its own.
---@return table|nil
function Shiftboard.job()
  return job
end

local function refresh()
  CreateThread(function()
    local result, reason = call(CORE, "GetPlayerData")
    if not result then
      job = nil
      -- Not an error: "no character loaded yet" arrives here as
      -- `error.notLoggedIn`, which is the normal state at boot.
      Open77.log.debug("no character: " .. tostring(reason))
      return
    end
    job = result.data.job
  end)
end

AddEventHandler("opx77:client:onPlayerLoaded", function(playerData)
  job = playerData and playerData.job or nil
end)

AddEventHandler("opx77:client:jobChanged", function(updated)
  job = updated
end)

AddEventHandler("opx77:client:onPlayerUnloaded", function()
  job = nil
  Shiftboard.board.close()
end)

AddEventHandler("onClientResourceStart", function(name)
  if name ~= GetCurrentResourceName() then return end
  -- A reload replaces this VM while the world is already up: onPlayerLoaded
  -- fired long ago and will not fire again. Ask once instead of waiting.
  refresh()
end)
```

!!! warning "A job read on the client is a hint, never proof"

    `job.name`, and the `HasJob` export, read the client's mirror. That is the
    right call for deciding what to *draw*. It is never the right call for
    deciding what a player is *allowed to do*: this code runs on the player's
    machine and a modified client answers whatever it likes. `opx77_elevators`
    ships with a client-side job gate and says so in four places, including its
    README. Anything unforgeable belongs in
    [a server plugin](writing-a-server-plugin.md).

## 6. Drawing the menu {#menu}

`opx77_menu` owns one screen surface for the whole server. You hand it a spec
and it hands you back a handle; when a row is chosen it raises the **event you
named on the spec** and echoes that row's opaque `data` table back untouched.

That indirection is not stylistic. The export codec cannot carry a Lua function,
so there is no way to hand the menu a callback — an event and an echoed `data`
table are your closure and its captured state, written down.

```lua
-- client/board.lua
local Config = NC_SHIFTBOARD
local MENU = "opx77_menu"

local Board = {}
Shiftboard.board = Board

--- Handle of the menu this resource currently owns, or nil.
local handle = nil

--- Whether the panel can be drawn at all right now. opx77_menu is optional, so
--- this is a state check rather than a dependency.
local function available()
  return GetResourceState(MENU) == "running"
end

--- Open the board for the job the player currently holds.
--- Answers immediately: `ok = true` means "asked", not "on screen".
---@return table
function Board.open()
  if not available() then return { ok = false, error = "menu_not_running" } end

  local current = Shiftboard.job()
  if not current then return { ok = false, error = "no_character" } end
  if not Config.JOBS[current.name] then
    return { ok = false, error = "job_not_covered" }
  end

  local items = {
    { label = "Employer", value = current.label, disabled = true },
    { label = "Grade", value = current.grade and current.grade.name or "?",
      disabled = true },
    { separator = true },
    {
      id = "kit",
      label = "Request a kit",
      description = "Asks the depot to prepare a standard kit for your grade.",
      -- Echoed back to us verbatim in the payload. This is the closure.
      data = { job = current.name, grade = current.grade and current.grade.level },
    },
  }

  CreateThread(function()
    local result, reason = Shiftboard.call(MENU, "open", {
      id = "shiftboard",
      title = current.label,
      event = Config.MENU_EVENT,
      closeOnSelect = true,
      items = items,
    })
    if not result then
      handle = nil
      -- One log line, not a failure: a board that did not open is a command the
      -- player will type again.
      Open77.log.warn("board did not open: " .. tostring(reason))
      return
    end
    handle = result.handle
  end)

  return { ok = true, queued = true }
end

--- Close our own menu. A caller may not close another resource's, and
--- opx77_menu enforces that with `not_owner`.
function Board.close()
  if handle == nil or not available() then return end
  local closing = handle
  handle = nil
  CreateThread(function() Shiftboard.call(MENU, "close", closing) end)
end

--- Whether this resource believes its own board is on screen.
---@return boolean
function Board.isOpen()
  return handle ~= nil
end
```

The eight row kinds — action, submenu, toggle, choices, slider, separator, back
and close — are derived from the *shape* of the item, never declared. A row with
`items` is a submenu, a row with `toggle` is a boolean, a row with `separator` is
a rule. The full grammar is in
[the menu spec](../reference/opx77_menu/menu-spec.md).

## 7. Answering the row {#answering}

```lua
-- client/board.lua (continued)
AddEventHandler(Config.MENU_EVENT, function(payload)
  -- The client local event bus is host-wide: ANY resource on this machine can
  -- raise this name with any payload. Nothing here is a security boundary --
  -- the server re-derives every clause of the request -- but validating the
  -- shape is what keeps a peer from crashing this VM or emptying its task
  -- budget.
  if type(payload) ~= "table" then return end
  if payload.action ~= "select" then return end
  if payload.owner ~= GetCurrentResourceName() then return end

  local data = payload.data
  if type(data) ~= "table" or payload.itemId ~= "kit" then return end

  handle = nil -- closeOnSelect: the menu is already gone

  local sent, reason = TriggerServerEvent("nc_shiftboard:requestKit", data.job)
  if not sent then
    Open77.log.warn("kit request not sent: " .. tostring(reason))
  end
end)
```

Two details are load-bearing. `payload.owner` is filled in by `opx77_menu` from
`GetInvokingResource()` at open time, so it cannot be spoofed by a payload — but
the *event* can, which is why the shape is checked before anything is read from
it. And `TriggerServerEvent` answers `accepted, reason`; a send that was refused
is worth a line, because the alternative symptom is a button that silently does
nothing.

## 8. Asking the server, and what the server cannot do {#server-half}

```lua
-- server/main.lua
local Config = NC_SHIFTBOARD

--- The command. It has to live here: there is no client-side RegisterCommand on
--- this platform -- a typed slash command reaches the server's dispatcher and
--- is resolved against server registrations only.
---
--- Registered with `false`: opening your own board is not an operator action.
--- Passing `true` would make the host resolve `command.shift` against the
--- caller's ACL before this handler ran.
RegisterCommand(Config.COMMAND, function(source, _, raw)
  local player = tonumber(source) or 0
  if player <= 0 then
    Open77.log.info("/" .. Config.COMMAND .. " is a player command")
    return
  end
  TriggerClientEvent("nc_shiftboard:open", player, raw or "")
end, false)

--- The kit request.
---
--- `source` is the authenticated session and is the ONLY thing here that cannot
--- be forged. `jobName` came from the player's own machine.
RegisterNetEvent("nc_shiftboard:requestKit", function(jobName)
  local player = tonumber(source) or 0
  if player <= 0 then return end
  if type(jobName) ~= "string" or Config.JOBS[jobName] ~= true then return end

  -- WHAT THIS HALF CANNOT DO, and there is no version of it that can:
  -- it cannot ask opx77_core whether this player really holds that job. The
  -- OPEN//77 server runtime installs no exports, no GetInvokingResource and no
  -- cross-resource event bus, so `jobName` is an unverifiable claim and stays
  -- one. Nothing of value may be handed out on the strength of it.
  Open77.notifications.send(player, {
    type = "info",
    title = "Shift board",
    message = "A kit has been requested for " .. jobName .. ".",
    durationMs = 5000,
  })
end)
```

This is the wall every third-party server resource on OPEN//77 meets, and it is
better to meet it in a tutorial than in production. `Open77.notifications.send`
works because notifications are a **platform** binding available to any server
resource; asking `opx77_core` anything is not, because it is a different Lua
state with no door into it.

If the kit cost money, or if holding the job had to be *true* rather than
*claimed*, this handler would have to move into `opx77_core/server/` — where
`OPX.GetPlayer` and `OPX.RemoveMoney` are in scope.
[Writing a server plugin](writing-a-server-plugin.md) is that procedure, and
[Integration channels](../concepts/integration-channels.md) sets out the two
other options and what each costs.

## 9. Exporting something of your own {#exports}

If another resource should be able to ask your resource something, publish a
client export. Two rules are non-negotiable.

**Read your caller from the host, never from an argument.**
`GetInvokingResource()` is filled in by the runtime. Taking the caller's name
from a parameter would let any resource impersonate any other, and every shipped
service on this platform guards against it the same way:

```lua
-- client/main.lua (continued)
--- Who is calling, and at which generation of their code. Both come from the
--- host, so a caller can neither claim to be another resource nor outlive its
--- own reload.
---@return string|nil owner, string|nil reason
local function caller()
  local owner = GetInvokingResource()
  local generation = GetInvokingResourceGeneration()
  if type(owner) ~= "string" or owner == "" or type(generation) ~= "number" then
    return nil, "export_call_required"
  end
  return owner, nil
end

--- Whether the board is on screen, and whose it is.
---@return { ok: boolean, open: boolean, error?: string }
exports("isOpen", function()
  local owner, reason = caller()
  if not owner then return { ok = false, open = false, error = reason } end
  return { ok = true, open = Shiftboard.board.isOpen() }
end)
```

**Answer a plain `{ ok = boolean, ... }` and never raise.** The value crosses a
codec and lands in code that does not have your resource's types, your metatables
or your error class. `ok = false` plus a short stable `error` code — meant for
branching, never for showing a player — is the whole convention, and it is what
lets the three-level `call` helper in section 4 work against every resource on
the server.

## 10. Cleaning up {#teardown}

A reload replaces your VM while the world is still up. Anything you left in
*another* resource's VM outlives you, and nothing left alive remembers why.

```lua
-- client/main.lua (continued)
AddEventHandler("onClientResourceStop", function(name)
  if name ~= GetCurrentResourceName() then return end
  -- Hand back the menu surface before this VM dies. opx77_menu sweeps a stopped
  -- owner on its own tick, but that tick is not instant and a board left on
  -- screen with nothing behind it is the worse failure.
  Shiftboard.board.close()
  job = nil
end)
```

Handle the *other* direction too where it matters: if a service you depend on
stops and restarts, your handles in it are gone. `opx77_menu` and
`open77_zones` both key their records by owner **and generation**, so a handle
from before your own reload is refused with `not_owner` rather than silently
addressing somebody else's menu.

## Checklist {#checklist}

Before you ship a client resource against OPX//77:

- [ ] Every script is listed on its own line. No `**` glob outside `web_files`.
- [ ] Load order in the manifest matches the order the files depend on each other.
- [ ] `dependencies` lists only what the resource genuinely cannot run without —
      a declared dependency is hard and refuses the resource when absent.
- [ ] Every export call goes through a helper that checks all three levels.
- [ ] Every `await` is inside a `CreateThread`.
- [ ] Every export you publish reads its caller from `GetInvokingResource()`.
- [ ] Every export you publish answers `{ ok = boolean, ... }` and never raises.
- [ ] Every handler on the local event bus validates the shape of its payload
      before reading it.
- [ ] Nothing of value depends on a client-side job, gang or money check.
- [ ] Every string a player reads comes from your own `locales/`, and every
      `Open77.log` line stays English.
- [ ] `onClientResourceStop` hands back everything you left in another VM.

## Where to go next {#next}

- [Writing a server plugin](writing-a-server-plugin.md) — for the half this
  resource could not write.
- [The export contract](../concepts/export-contract.md) — the failure model on
  its own.
- [Reference](../reference/index.md) — every export, event, command and config
  key of every resource.
- [Troubleshooting](troubleshooting.md) — when the button does nothing.
