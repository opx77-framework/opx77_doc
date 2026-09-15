---
title: Writing a resource against OPX//77
description: A complete resource built end to end against opx77_core and opx77_menu in the OPX//77 house style — the manifest with no globs, annotation blocks and std/ stubs, en and fr catalogues, the three-level export failure check, the local event bus, a server half that asks the core's GetIdentity export, and teardown on onClientResourceStop.
---

# Writing a resource

This page builds one small resource from nothing: **`nc_shiftboard`**, a shift
board that reads the player's job from `opx77_core`, draws a floor-plan menu with
`opx77_menu`, and asks its own server half for something. It is deliberately the
smallest thing that touches every part of the contract you will meet again.

Every file on this page is written in the OPX//77 house style described in
[Contributing](contributing.md) — tabs, single quotes, annotation blocks instead
of comments, one namespace table — so it reads like the sixteen shipped
resources, and the opx-tools checkers pass on it, with two findings that come
from its not being an OPX//77 resource. The blocks carry `@author DemiAutomatic`
as the shipped resources do; a resource of your own may put your name there, and
`anncheck` reports that line. And `stdcheck` recognises only the `OPX` and
`Opx<Name>` namespaces, so it reports the stubs of `NcShiftboard` as naming
nothing.

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
- it has a server half that can ask `opx77_core` **whether** the player has a
  character loaded, but **not which job** that character holds — which is the
  honest shape of a third-party server resource today, and the reason
  [Writing a server plugin](writing-a-server-plugin.md) exists.

## 1. The layout {#layout}

```text
resources/nc_shiftboard/
  open77.lua
  config.lua
  shared/locale.lua
  locales/en.lua
  locales/fr.lua
  client/main.lua
  client/board.lua
  client/exports.lua
  server/main.lua
  std/shared/locale.lua
  std/client/main.lua
  std/client/board.lua
  docs/ARCHITECTURE.md
  README.md
```

`server/` files are never included in the client package, so anything secret or
authoritative belongs there and nowhere else. `shared/` and a root `config.lua`
declared as a shared script are compiled into both VMs, which means a value you
put in them is **shipped to every client** — treat it as public.

`std/` holds the editor's types and is never loaded; `docs/ARCHITECTURE.md` holds
the reasoning that the code no longer carries as comments (the OPX//77 resources
write theirs in French); the README is what an operator reads to install and
configure it.

## 2. The manifest {#manifest}

```lua
--- @author DemiAutomatic
--- @file open77.lua
--- @description Resource manifest declaring scripts, permissions and reload policy.

resource "nc_shiftboard"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

reload_policy "local"

shared_script "config.lua"
shared_script "shared/locale.lua"
shared_script "locales/en.lua"
shared_script "locales/fr.lua"
client_script "client/main.lua"
client_script "client/board.lua"
client_script "client/exports.lua"
server_script "server/main.lua"

permissions {
  "network.events",
}
```

The manifest is a declarative DSL, not Lua: it keeps its double quotes, and it
carries its header block and no other comment. The reasons behind each line go
to the "Manifeste" section of `docs/ARCHITECTURE.md`, and they are these:

- **`reload_policy "local"`** — a script reload, not a reconnect: this resource
  owns no WebUI surface of its own (the panel is `opx77_menu`'s), so both halves
  can simply rebuild.
- **The order.** `config.lua` publishes `NC_SHIFTBOARD_CONFIG`, which
  `shared/locale.lua` reads at load for `LOCALE`; the two catalogues register
  right after it, so no file below calls `locale()` against an empty one.
  `client/main.lua` defines `NcShiftboard.Call` and `NcShiftboard.Job`,
  `client/board.lua` creates `NcShiftboard.Board`, and `client/exports.lua` comes
  last because publishing the surface claims everything it reads.
- **`network.events`** — the command lands server-side and the board is opened
  over the wire, and the kit request goes back the other way. Reading the
  character through `opx77_core`'s exports costs no permission at all.
- **No `dependency`.** A declared dependency is hard: the host refuses the
  resource outright when it is absent. `opx77_menu` is optional here — a server
  with its own interaction UI should still be able to run this — and
  `opx77_core` is consulted through exports that answer a reason when it is not
  running.

!!! danger "Never glob a flat script directory"

    `client_scripts { "client/**/*.lua" }` requires an intermediate directory and
    matches **nothing** against a flat `client/main.lua`. An empty glob does not
    warn and does not skip the file — the client refuses the **whole resource
    set** with `script_pattern_empty:client/**/*.lua`, and *no player can
    connect to the server at all*. Every shipped OPEN//77 resource lists its
    scripts one per line for this reason. `**` is only safe under `web_files`.

## 3. The config {#config}

```lua
--- @author DemiAutomatic
--- @file config.lua
--- @description Shift board command, covered jobs, menu event and locale.
--- @field COMMAND {string} Slash command that opens the board.
--- @field JOBS {table<string, boolean>} Job names as in opx77_core data/jobs.lua.
--- @field MENU_EVENT {string} Our event name; opx77_menu raises it on a chosen row.
--- @field LOCALE {string} Catalogue code player-facing text is read from.

NC_SHIFTBOARD_CONFIG = {
	COMMAND = 'shift',
	JOBS = { ncpd = true, trauma = true, merc = true },
	MENU_EVENT = 'nc_shiftboard:row',
	LOCALE = 'en',
}
```

The keys are documented in the header block, one `@field` per path, and nowhere
else in the file; `JOBS` holds names that are data, so it is documented once at
the parent. This file is shipped to every client: nothing secret goes in it.
What an operator needs beyond those one-line notes — that `MENU_EVENT` is echoed
back by the menu, see [section 6](#menu) — goes in the README's Configuration
section.

### Player-facing text {#locale}

A resource that shows a player a word carries its own catalogue. Thirteen of the
fifteen shipped satellites do — every one but `opx77_notify` and `opx77_status`
— and the shape is the same in each of them, adapted to the resource's own
namespace:

- `shared/locale.lua` (`client/locale.lua` in a resource with no server half) —
  creates the namespace's `Locale` module with `register`, `Set` and `Get`,
  `{placeholder}` substitution and an English fallback, and publishes the
  `locale = NcShiftboard.Locale.Get` shorthand. `register` stays lowercase,
  because an operator's own `locales/<code>.lua` calls it.
- `locales/en.lua` and `locales/fr.lua` — one `register` call each, one entry
  per line.

```lua
--- @author DemiAutomatic
--- @file locales/en.lua
--- @description English player-facing text for the shift board.

NcShiftboard.Locale.register('en', {
	['shiftboard.title'] = 'SHIFT BOARD',
	['shiftboard.employer'] = 'Employer',
	['shiftboard.grade'] = 'Grade',
	['shiftboard.requestKit'] = 'Request a kit',
	['shiftboard.requestKit.description'] = 'Asks the depot to prepare a standard kit for your grade.',
	['shiftboard.kitRequested'] = 'A kit has been requested for {job}.',
})
```

```lua
--- @author DemiAutomatic
--- @file locales/fr.lua
--- @description French player-facing text for the shift board.

NcShiftboard.Locale.register('fr', {
	['shiftboard.title'] = 'TABLEAU DE SERVICE',
	['shiftboard.employer'] = 'Employeur',
	['shiftboard.grade'] = 'Grade',
	['shiftboard.requestKit'] = 'Demander un kit',
	['shiftboard.requestKit.description'] = 'Demande au dépôt de préparer un kit standard pour votre grade.',
	['shiftboard.kitRequested'] = 'Un kit a été demandé pour {job}.',
})
```

The catalogue lines in [section 2](#manifest) come before every file that
renders a string, and that order is not negotiable: a file that calls `locale()`
before the catalogues are registered gets the key back instead of the text.

**You cannot borrow the core's.** `opx77_core` publishes a
[`Locale`](../reference/opx77_core/exports/client.md#locale) export, but it is
client-only and asynchronous: a server half cannot call it, and a file that
renders a string at load cannot wait on it. That is the whole reason `LOCALE`
appears a second time in your own `config.lua` on a server that has already set
one in `config/shared.lua`.

Name keys `<resource>.<thing>` — `shiftboard.employer`, `weather.status`,
`elevators.rateLimited` — and keep both catalogues carrying **exactly the same
keys with the same placeholders**: a key present in one and missing in the other
is a defect, not a fallback, and `localecheck` reports it.

What gets localised is anything a **player** reads: a command's answer, toast
and notification text, chat suggestions, a menu label, refusal text shown in a
UI. What does not: `Open77.log` lines, console output, ACL-gated diagnostic
commands — those are for the operator reading a server log, and translating them
makes a support request harder to answer. Error **codes** stay as they are too;
`not_owner` and `rate_limited` are a branching surface for a caller, not text,
and a resource that wants to show one renders it through its own catalogue.

Operator-authored strings in a `config.lua` — an elevator's `REASON`, a job's
label in `opx77_core/data/jobs.lua` — are the server owner's own words. Leave
them alone.

## 4. Calling another resource {#calling}

What this resource's client half calls are **client** exports, published by
other client resources. Server resources have exports too, on a separate
registry with the same call shape — [section 8](#server-half) uses one. Three
things surprise everyone:

- there is no `exports.<resource>:<name>()` proxy — indexing the function raises
  *attempt to index a function value*;
- the call is asynchronous, always, and `await` only works inside a
  `CreateThread`;
- **failure has three levels, and they mean different things.**

Write the plumbing once, at the top of `client/main.lua`:

```lua
--- @author DemiAutomatic
--- @file client/main.lua
--- @description The export call helper, the job mirror and the teardown.

--- @author DemiAutomatic
--- @type {string}
--- @description The resource that owns the loaded character.
local CORE = 'opx77_core'

--- @author DemiAutomatic
--- @method NcShiftboard.Call
--- @description Calls another resource's export, answering nil and a reason on failure.
--- @param resource {string}
--- @param name {string}
--- @param ... {any}
--- @returns {table|nil, string|nil}
function NcShiftboard.Call(resource, name, ...)
	local promise, dispatchError = Open77.exports.call(resource, name, ...)
	if not promise then return nil, tostring(dispatchError or 'not_dispatched') end

	local result, callError = promise:await()
	if callError then return nil, tostring(callError) end
	if type(result) ~= 'table' then return nil, 'malformed_answer' end
	if result.ok ~= true then return nil, tostring(result.error or 'refused') end

	return result
end
```

The three levels, because collapsing them turns a remote refusal into a silent
`nil`:

1. `Open77.exports.call` answers `nil` plus a reason when the call could not be
   **dispatched** — the resource is missing, stopped or reloading. What it
   answers otherwise is a promise, which is a userdata: test it for presence,
   never with `type(promise) == 'table'`.
2. `promise:await()` answers a second error when it was dispatched and
   **resolution** failed — the handler raised.
3. The resource's own answer. Every OPX//77 export replies with a plain
   `{ ok = true, ... }` or `{ ok = false, error = '<code>' }`, because the value
   crosses a codec and lands in code that does not have the framework loaded.
   **Anything but `ok == true` is a refusal**: test `result.ok ~= true`, so an
   answer that carries no `ok` at all is not taken for a success.

`NcShiftboard.Call` is a namespace function because `client/board.lua` uses it
too, so it is defined with its full path in PascalCase and has a stub in
`std/client/main.lua`, which LuaLS reads and the host never loads:

```lua
---@meta

NcShiftboard = {}

--- One call to another resource's export, checked at all three levels.
---@param resource string
---@param name string
---@param ... any the export's arguments
---@return table|nil result the answer, when it is ok
---@return string|nil reason why there is none
function NcShiftboard.Call(resource, name, ...) end

--- The job the player currently holds, or nil.
---@return table|nil
function NcShiftboard.Job() end
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

Because `await` is coroutine-only, every use of `NcShiftboard.Call` is inside a
`CreateThread` — and never under a `pcall`, because a yield cannot cross one. An
export handler is **not** a coroutine, so an export of yours that needs to call
out must queue the work and answer "asked", not "done" — `NcShiftboard.Board.Open`
in section 6 shows the shape.

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
| `opx77:client:clothingSaved` | the core stored new clothing; carries the record |
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

The rest of `client/main.lua` keeps the one field this resource cares about:

```lua
--- @author DemiAutomatic
--- @type {table|nil}
--- @description The player's primary job, as the core last reported it.
local job = nil

--- @author DemiAutomatic
--- @method NcShiftboard.Job
--- @description Answers the job the player currently holds, or nil.
--- @returns {table|nil}
function NcShiftboard.Job()
	return job
end

--- @author DemiAutomatic
--- @method refresh
--- @description Reads the loaded character's job from opx77_core again.
local function refresh()
	CreateThread(function()
		local result, reason = NcShiftboard.Call(CORE, 'GetPlayerData')
		if not result then
			job = nil
			Open77.log.debug('no character: ' .. reason)
			return
		end
		job = result.data.job
	end)
end

--- @author DemiAutomatic
--- @event opx77:client:onPlayerLoaded
--- @description Takes the job from the character that entered the world.
--- @param playerData {table}
AddEventHandler('opx77:client:onPlayerLoaded', function(playerData)
	job = type(playerData) == 'table' and playerData.job or nil
end)

--- @author DemiAutomatic
--- @event opx77:client:jobChanged
--- @description Takes the job the core reports after a change.
--- @param updated {table}
AddEventHandler('opx77:client:jobChanged', function(updated)
	job = updated
end)

--- @author DemiAutomatic
--- @event opx77:client:onPlayerUnloaded
--- @description Forgets the job and closes the board when the character leaves.
AddEventHandler('opx77:client:onPlayerUnloaded', function()
	job = nil
	NcShiftboard.Board.Close()
end)

--- @author DemiAutomatic
--- @event onClientResourceStart
--- @description Asks the core for the job once this resource starts.
--- @param name {string}
AddEventHandler('onClientResourceStart', function(name)
	if name ~= GetCurrentResourceName() then return end
	refresh()
end)
```

Two things in it are not visible from the code alone, and are what
`docs/ARCHITECTURE.md` would say. The job is mirrored rather than derived,
because the core is the only thing that knows it. And `onClientResourceStart`
asks once instead of waiting: a reload replaces this VM while the world is
already up, `onPlayerLoaded` fired long ago and will not fire again. "No
character loaded yet" arrives at `refresh` as `error.notLoggedIn`, which is the
normal state at boot, so it is a debug line and not an error.

`refresh` is a `local function`, declared above the handler that uses it: a
local referenced before its declaration compiles to a nil global.
`NcShiftboard.Board` is read only inside handler bodies, so it may be created by
a file that loads later.

!!! warning "A job read on the client is a hint, never proof"

    `job.name`, and the `HasJob` export, read the client's mirror. That is the
    right call for deciding what to *draw*. It is never the right call for
    deciding what a player is *allowed to do*: this code runs on the player's
    machine and a modified client answers whatever it likes. `opx77_elevators`
    ships with a client-side job gate and says so at the top of its README.
    Anything unforgeable belongs in
    [a server plugin](writing-a-server-plugin.md).

## 6. Drawing the menu {#menu}

`opx77_menu` owns one screen surface for the whole server. You hand it a spec
and it hands you back a handle; when a row is chosen it raises the **event you
named on the spec** and echoes that row's opaque `data` table back untouched.

That indirection is not stylistic. The export codec cannot carry a Lua function,
so there is no way to hand the menu a callback — an event and an echoed `data`
table are your closure and its captured state, written down.

```lua
--- @author DemiAutomatic
--- @file client/board.lua
--- @description Opens, closes and answers the shift board drawn by opx77_menu.

NcShiftboard.Board = {}

--- @author DemiAutomatic
--- @type {string}
--- @description The resource that owns the menu surface.
local MENU = 'opx77_menu'

--- @author DemiAutomatic
--- @type {integer|nil}
--- @description Handle of the menu this resource currently owns.
local handle = nil

--- @author DemiAutomatic
--- @method available
--- @description Answers whether opx77_menu is running to draw the board.
--- @returns {boolean}
local function available()
	return GetResourceState(MENU) == 'running'
end

--- @author DemiAutomatic
--- @method NcShiftboard.Board.Open
--- @description Asks opx77_menu for the board; ok means asked, not drawn.
--- @returns {table}
function NcShiftboard.Board.Open()
	if not available() then return { ok = false, error = 'menu_not_running' } end

	local current = NcShiftboard.Job()
	if not current then return { ok = false, error = 'no_character' } end
	if not NC_SHIFTBOARD_CONFIG.JOBS[current.name] then
		return { ok = false, error = 'job_not_covered' }
	end

	local items = {
		{ label = locale('shiftboard.employer'), value = current.label, disabled = true },
		{ label = locale('shiftboard.grade'), value = current.grade and current.grade.name or '?', disabled = true },
		{ separator = true },
		{
			id = 'kit',
			label = locale('shiftboard.requestKit'),
			description = locale('shiftboard.requestKit.description'),
			data = { job = current.name, grade = current.grade and current.grade.level },
		},
	}

	CreateThread(function()
		local result, reason = NcShiftboard.Call(MENU, 'open', {
			id = 'shiftboard',
			title = current.label,
			event = NC_SHIFTBOARD_CONFIG.MENU_EVENT,
			closeOnSelect = true,
			items = items,
		})
		if not result then
			handle = nil
			Open77.log.warn('board did not open: ' .. reason)
			return
		end
		handle = result.handle
	end)

	return { ok = true, queued = true }
end

--- @author DemiAutomatic
--- @method NcShiftboard.Board.Close
--- @description Closes this resource's own board, if it has one open.
function NcShiftboard.Board.Close()
	if handle == nil or not available() then return end
	local closing = handle
	handle = nil
	CreateThread(function() NcShiftboard.Call(MENU, 'close', closing) end)
end

--- @author DemiAutomatic
--- @method NcShiftboard.Board.IsOpen
--- @description Answers whether this resource believes its board is on screen.
--- @returns {boolean}
function NcShiftboard.Board.IsOpen()
	return handle ~= nil
end
```

`NcShiftboard.Board.Open` answers immediately, and `ok = true` means "asked",
not "on screen". A board that did not open is one log line, not a failure: it is
a command the player will type again. `Close` only ever closes this resource's
own menu — a caller may not close another resource's, and `opx77_menu` enforces
that with `not_owner`. `available` is a state check rather than a dependency,
because `opx77_menu` is optional.

The eight row kinds — action, submenu, toggle, choices, slider, separator, back
and close — are derived from the *shape* of the item, never declared. A row with
`items` is a submenu, a row with `toggle` is a boolean, a row with `separator` is
a rule. The full grammar is in
[the menu spec](../reference/opx77_menu/menu-spec.md).

## 7. Answering the row {#answering}

The rest of `client/board.lua` opens the board when the server half says so, and
answers the row:

```lua
--- @author DemiAutomatic
--- @event nc_shiftboard:open
--- @description Opens the board when the server half answers the command.
RegisterNetEvent('nc_shiftboard:open', function()
	NcShiftboard.Board.Open()
end)

--- @author DemiAutomatic
--- @event NC_SHIFTBOARD_CONFIG.MENU_EVENT
--- @description Sends a kit request when the player chooses the kit row.
--- @param payload {table}
AddEventHandler(NC_SHIFTBOARD_CONFIG.MENU_EVENT, function(payload)
	if type(payload) ~= 'table' then return end
	if payload.action ~= 'select' then return end
	if payload.owner ~= GetCurrentResourceName() then return end

	local data = payload.data
	if type(data) ~= 'table' or payload.itemId ~= 'kit' then return end

	handle = nil

	local sent, reason = TriggerServerEvent('nc_shiftboard:requestKit', data.job)
	if not sent then
		Open77.log.warn('kit request not sent: ' .. tostring(reason))
	end
end)
```

The client local event bus is host-wide: **any** resource on this machine can
raise `nc_shiftboard:row` with any payload. Nothing here is a security boundary
— the server re-checks what it can of the request — but validating the shape
is what keeps a peer from crashing this VM or emptying its task budget. `handle`
is forgotten because the spec set `closeOnSelect`: the menu is already gone.

Two details are load-bearing. `payload.owner` is filled in by `opx77_menu` from
`GetInvokingResource()` at open time, so it cannot be spoofed by a payload — but
the *event* can, which is why the shape is checked before anything is read from
it. And `TriggerServerEvent` answers `accepted, reason`; a send that was refused
is worth a line, because the alternative symptom is a button that silently does
nothing.

## 8. Asking the server, and what the server cannot know {#server-half}

```lua
--- @author DemiAutomatic
--- @file server/main.lua
--- @description The shift command and the kit request, checked against opx77_core.

--- @author DemiAutomatic
--- @type {string}
--- @description The resource whose GetIdentity export names a loaded character.
local CORE = 'opx77_core'

--- @author DemiAutomatic
--- @method loadedCitizenOf
--- @description Answers the citizen id opx77_core has loaded for a player.
--- @param player {integer}
--- @returns {string|nil, string|nil}
local function loadedCitizenOf(player)
	local promise, reason = Open77.exports.call(CORE, 'GetIdentity', player)
	if not promise then return nil, tostring(reason or 'not_dispatched') end
	local answer, callError = promise:await()
	if callError then return nil, tostring(callError) end
	if type(answer) ~= 'table' then return nil, 'malformed_answer' end
	if answer.ok ~= true then return nil, tostring(answer.error or 'refused') end
	if answer.loaded ~= true or type(answer.citizenId) ~= 'string' then return nil, 'not_loaded' end
	return answer.citizenId
end

--- @author DemiAutomatic
--- @command NC_SHIFTBOARD_CONFIG.COMMAND
--- @description Opens the shift board on the calling player's client.
RegisterCommand(NC_SHIFTBOARD_CONFIG.COMMAND, function(source, _, raw)
	local player = tonumber(source) or 0
	if player <= 0 then
		Open77.log.info('/' .. NC_SHIFTBOARD_CONFIG.COMMAND .. ' is a player command')
		return
	end
	TriggerClientEvent('nc_shiftboard:open', player, raw or '')
end, false)

--- @author DemiAutomatic
--- @event nc_shiftboard:requestKit
--- @description Answers a kit request from a player with a loaded character.
--- @param jobName {string}
RegisterNetEvent('nc_shiftboard:requestKit', function(jobName)
	local player = tonumber(source) or 0
	if player <= 0 then return end
	if type(jobName) ~= 'string' or NC_SHIFTBOARD_CONFIG.JOBS[jobName] ~= true then return end

	CreateThread(function()
		local citizenId, reason = loadedCitizenOf(player)
		if not citizenId then
			Open77.log.debug(('kit request from %d refused: %s'):format(player, tostring(reason)))
			return
		end
		Open77.notifications.send(player, {
			type = 'info',
			title = locale('shiftboard.title'),
			message = locale('shiftboard.kitRequested', { job = jobName }),
			durationMs = 5000,
		})
	end)
end)
```

The command has to live here: there is no client-side `RegisterCommand` on this
platform — a typed slash command reaches the server's dispatcher and is resolved
against server registrations only. It is registered with `false`, because
opening your own board is not an operator action; passing `true` would make the
host resolve `command.shift` against the caller's ACL before the handler ran.

In the kit request, `source` is the authenticated session and is the only thing
that cannot be forged; `jobName` came from the player's own machine. So the
handler asks the core. `GetIdentity` is one of
[`opx77_core`'s server exports](../reference/opx77_core/exports/server.md): the
core reads its caller from the host, admits any server resource to its reads as
shipped (`EXPORTS.READ = '*'`), and answers whether that player id is online and
whether a character is loaded, with its `citizenId`. The call is awaited inside a
`CreateThread`, never at file scope, and checked at the same three levels as on
the client.

**What this half still cannot do** is check the job. None of the core's server
exports answers a character's job, so `jobName` stays an unverifiable claim, and
nothing of value may be handed out on the strength of it. `opx77_elevators` is in
the same position and says so at the top of its README. `Open77.notifications.send`
works because notifications are a **platform** binding available to any server
resource.

If the kit cost money, or if holding the job had to be *true* rather than
*claimed*, this handler would have to move into `opx77_core/server/` — where
`OPX.GetPlayer` and `OPX.RemoveMoney` are in scope, because the core's plug-in
API is a global in its own VM and no export publishes it.
[Writing a server plugin](writing-a-server-plugin.md) is that procedure, and
[Integration channels](../concepts/integration-channels.md) sets out the other
options and what each costs.

## 9. Exporting something of your own {#exports}

If another resource should be able to ask your resource something, publish an
export, in `client/exports.lua`, the last client script. Two rules are
non-negotiable.

**Read your caller from the host, never from an argument.**
`GetInvokingResource()` is filled in by the runtime. Taking the caller's name
from a parameter would let any resource impersonate any other, and every shipped
service on this platform guards against it the same way:

```lua
--- @author DemiAutomatic
--- @file client/exports.lua
--- @description The resource's one client export, with its caller read from the host.

--- @author DemiAutomatic
--- @method caller
--- @description Reads the invoking resource and its generation from the host.
--- @returns {string|nil, string|nil}
local function caller()
	local owner = GetInvokingResource()
	local generation = GetInvokingResourceGeneration()
	if type(owner) ~= 'string' or owner == '' or type(generation) ~= 'number' then
		return nil, 'export_call_required'
	end
	return owner, nil
end

--- @author DemiAutomatic
--- @export isOpen
--- @description Answers whether this resource's board is on screen.
--- @returns {table}
exports('isOpen', function()
	local owner, reason = caller()
	if not owner then return { ok = false, error = reason } end
	return { ok = true, open = NcShiftboard.Board.IsOpen() }
end)
```

Both the name and the generation come from the host, so a caller can neither
claim to be another resource nor outlive its own reload. A service that keeps
something per caller stores both, and forgets an owner whose generation moved.

**Answer a plain `{ ok = true, ... }` and never raise.** The value crosses a
codec and lands in code that does not have your resource's types, your metatables
or your error class. `ok = false` plus a short stable `error` code — meant for
branching, never for showing a player — is the whole convention, and it is what
lets the three-level `NcShiftboard.Call` in section 4 work against every resource
on the server. List every code in the README.

## 10. Cleaning up {#teardown}

A reload replaces your VM while the world is still up. Anything you left in
*another* resource's VM outlives you, and nothing left alive remembers why. The
last handler of `client/main.lua`:

```lua
--- @author DemiAutomatic
--- @event onClientResourceStop
--- @description Hands the menu back and forgets the job on either stop.
--- @param name {string}
AddEventHandler('onClientResourceStop', function(name)
	if name ~= GetCurrentResourceName() and name ~= CORE then return end
	NcShiftboard.Board.Close()
	job = nil
end)
```

On this resource's own stop, the board goes back
before the VM dies: `opx77_menu` sweeps a stopped owner on its own, but not
instantly, and a board left on screen with nothing behind it is the worse
failure. On an `opx77_core` stop, the character is treated as unloaded: a core
restart raises no `onPlayerUnloaded`, so a resource that mirrors character state
drops it there — `opx77_hud`, `opx77_appearance`, `opx77_status`,
`opx77_charselector` and `opx77_elevators` all do.

Handle the *other* direction too where it matters: if a service you depend on
stops and restarts, your handles in it are gone. `opx77_menu` and
`open77_zones` both key their records by owner **and generation**, so a handle
from before your own reload is refused with `not_owner` rather than silently
addressing somebody else's menu. A service that sweeps owners that went away
treats an owner in state `starting` as alive: a resource mid-restart has not
left.

## Checklist {#checklist}

Before you ship a resource against OPX//77:

- [ ] Every script is listed on its own line. No `**` glob outside `web_files`.
- [ ] Load order in the manifest matches the order the files depend on each
      other, and `client/exports.lua` is the last client script.
- [ ] No `dependency` is declared — it is hard and refuses the resource when
      absent.
- [ ] Every export call goes through a helper that checks all three levels and
      treats anything but `ok == true` as a refusal.
- [ ] Every `await` is inside a `CreateThread` and never under a `pcall`.
- [ ] Every export you publish reads its caller from `GetInvokingResource()`.
- [ ] Every export you publish answers `{ ok = boolean, ... }` and never raises.
- [ ] Every handler on the local event bus validates the shape of its payload
      before reading it.
- [ ] Nothing of value depends on a client-side job, gang or money check.
- [ ] Every string a player reads comes from `locales/en.lua` and
      `locales/fr.lua`, which carry the same keys, and every `Open77.log` line
      stays English.
- [ ] Every file carries annotation blocks and no prose comment; every namespace
      function has its `std/` stub; the reasons are in `docs/ARCHITECTURE.md`.
- [ ] `onClientResourceStop` hands back everything you left in another VM.
- [ ] The opx-tools checkers report nothing but what the introduction to this
      page explains — see [Contributing](contributing.md#syntax-check).

## Where to go next {#next}

- [Writing a server plugin](writing-a-server-plugin.md) — for the half this
  resource could not write.
- [The export contract](../concepts/export-contract.md) — the failure model on
  its own.
- [Contributing](contributing.md) — the house style every file on this page
  follows.
- [Reference](../reference/index.md) — every export, event, command and config
  key of every resource.
- [Troubleshooting](troubleshooting.md) — when the button does nothing.
