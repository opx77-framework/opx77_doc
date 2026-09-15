---
title: Contributing to OPX//77
description: The house style for OPX//77 resources — directory layout with std/ and docs/ARCHITECTURE.md, one namespace per resource, annotation blocks instead of comments, tabs and single quotes, the { ok = true } export contract, en and fr catalogues, the opx-tools checkers, and what belongs in a README.
---

# Contributing

OPX//77 has a house style, and every one of the sixteen resources is written to
it. Most of it is checked mechanically by a set of checkers kept outside the
resources (see [Checking your change](#syntax-check)); the rest is review. It is
written down here. Most of it is ordinary; three parts of it are not — the
comment policy, the one-namespace rule and the README's role — and those three
are the ones a pull request is most often asked to change.

## How a resource is laid out {#layout}

Every OPX//77 resource has the same shape:

```text
opx77_<name>/
  open77.lua        the manifest -- a declarative DSL, NOT executed as Lua
  config.lua        OPX_<NAME>_CONFIG, the operator surface
  data/             catalogues, where the resource has them (admin, inventory)
  shared/           compiled into both VMs
  client/           distributed to and run by clients
  server/           never included in the client package
  locales/          en.lua and fr.lua
  std/              LuaLS stubs: ---@meta, never loaded, never in the manifest
    types.lua       classes and aliases
    client/ server/ shared/   one stub file per code file defining namespace functions
  docs/
    ARCHITECTURE.md why the code is written this way, in French
  web/              the WebUI surface, where there is one
  README.md         the user-facing document, in English
  LICENSE
```

A folder a resource has no use for is absent: `opx77_notify` and `opx77_status`
have no `locales/`, and `opx77_notify`, `opx77_menu`, `opx77_prompts`,
`opx77_input`, `opx77_charcreator` and `opx77_charselector` have no server half.
`opx77_status` is the one satellite with a `sql/` folder, because it owns one
table.

`opx77_core` is the exception and splits its configuration by who may read it:

```text
opx77_core/
  config/shared.lua    both VMs -- SHIPPED TO EVERY CLIENT, never a secret
  config/server.lua    slots, autosave, paychecks, entry deadlines, server exports
  config/vehicles.lua  plate format and spawn ceiling, server-only
  config/client.lua    client cadences; never loaded by the server VM
  data/                jobs, gangs, origins -- definitions, not settings
  locales/             one file per language
  server/tunables.lua  anything an operator changes mid-session
  server/storage/      the database layer; schema.lua holds OPX.Schema
  sql/schema.sql       the same CREATE TABLE statements, for an operator to read
```

Where a value goes is a real distinction, not filing:

| Layer | Where | What goes there |
|---|---|---|
| **Configuration** | `config.lua` (`OPX.Config.*` in the core) | what a server owner decides before boot: names, keys, locale, toggles, sizes, command names and their restriction flag |
| **Data** | `data/*.lua` | definitions whose keys end up stored in player data — renaming a job renames something players already hold, so it is not a setting |
| **Tunables** | `Open77.tunables`, `opx77_core/server/tunables.lua` only | what an operator changes at 3 a.m. from the Warden panel without a restart |
| **Constants** | a `local UPPER_SNAKE` in the file that uses it, or `Opx<Name>.<Module>.UPPER_SNAKE` when two files share it | cadences, timeouts, byte limits, protocol versions, cooldowns |
| **Types** | `std/` | classes, aliases and one stub per namespace function, for the editor |

A key already in a `config.lua` is an operator contract and stays where it is.
A **new** value that is interface appearance, a loop cadence, an anti-spam
cooldown, an input bound or a server-side check distance is not an operator
decision: it is a constant, and it never goes into `config.lua`. Putting a value
in the wrong layer is a review comment.

A resource that validates its config holds each fallback once, in the validator,
and its README states it once; the default is never copied into an annotation or
a second file where it can drift.

## The load-order rule {#load-order}

**Load order is manifest order, and it is dependency order.** There is no
autoloader, no `require` across files, and no deferred initialisation: a file
that reaches for something a later file publishes fails at load, not at runtime.

Three consequences the shipped manifests all obey:

1. **A file that reads a table at file scope loads after the file that creates
   it.** Each resource publishes one namespace table (see
   [Namespaces and naming](#naming)), and a module table on it is created once,
   in the file that owns it. A read inside a function body imposes no order; a
   read at file scope does, and so does a local alias such as
   `local State = OpxNotify.State`.
2. **`client/exports.lua` is last among a resource's client scripts**, and
   `opx77_core/server/exports.lua` last among the core's server scripts.
   Publishing the surface claims everything it reads, so it must not run before
   the things it reads exist.
3. **The reasons live in `docs/ARCHITECTURE.md`, not in the manifest.**
   `open77.lua` carries a header block and nothing else in the way of comments;
   its "Manifeste" section says why the order is what it is, and gives one line
   per permission. Keep it current: the next person to reorder the block needs
   to know which lines are safe to move. The manifest itself is not
   reformatted — its directives keep their double quotes and their layout.

No resource declares a `dependency`. A declared dependency is hard: the host
refuses to start the resource without it. A resource that uses another probes it
through the export answer, with `GetResourceState` as a hint, and degrades with
one log line when it is absent.

!!! warning "One script per line. Never glob a script directory."

    `client_scripts { "client/**/*.lua" }` requires an intermediate directory and
    matches **nothing** against a flat `client/main.lua`. An empty glob does not
    warn and is not skipped — it refuses the **whole client resource set**, and
    no player can connect to the server at all. `**` is safe only under
    `web_files`.

## Namespaces and naming {#naming}

Every resource runs in its own Lua VM and publishes **one** namespace table.
No other global is created, apart from the config table, the data catalogues,
and the `locale` shorthand where the resource has a catalogue.

| Resource | Namespace | Config global |
|---|---|---|
| `opx77_admin` | `OpxAdmin` | `OPX_ADMIN_CONFIG` |
| `opx77_animations` | `OpxAnimations` | `OPX_ANIMATIONS_CONFIG` |
| `opx77_appearance` | `OpxAppearance` | `OPX_APPEARANCE_CONFIG` |
| `opx77_charcreator` | `OpxCharCreator` | `OPX_CHARCREATOR_CONFIG` |
| `opx77_charselector` | `OpxCharSelector` | `OPX_CHARSELECTOR_CONFIG` |
| `opx77_chat` | `OpxChat` | `OPX_CHAT_CONFIG` |
| `opx77_core` | `OPX` | `OPX.Config.SHARED`, `.SERVER`, `.VEHICLES`, `.CLIENT` |
| `opx77_elevators` | `OpxElevators` | `OPX_ELEVATORS_CONFIG` |
| `opx77_hud` | `OpxHud` | `OPX_HUD_CONFIG` |
| `opx77_input` | `OpxInput` | `OPX_INPUT_CONFIG` |
| `opx77_inventory` | `OpxInventory` | `OPX_INVENTORY_CONFIG` |
| `opx77_menu` | `OpxMenu` | `OPX_MENU_CONFIG` |
| `opx77_notify` | `OpxNotify` | `OPX_NOTIFY_CONFIG` |
| `opx77_prompts` | `OpxPrompts` | `OPX_PROMPTS_CONFIG` |
| `opx77_status` | `OpxStatus` | `OPX_STATUS_CONFIG` |
| `opx77_weather` | `OpxWeather` | `OPX_WEATHER_CONFIG` |

Names follow one rule — `local function camelCase` for what a file keeps to
itself, `function Ns.Module.PascalCase` for what other files call:

| What | Form | Example |
|---|---|---|
| Module table on the namespace | PascalCase, created once, in the file that owns it | `OpxNotify.State = {}` |
| Function other files call | PascalCase, defined with its **full path** | `function OpxNotify.State.Remove(handle)` |
| Function on the namespace root | PascalCase | `function OpxWeather.NowMs()` |
| Constant on a module | UPPER_SNAKE | `OpxNotify.State.MAX_OWNER = 64` |
| Mutable shared field on a module | camelCase | `OpxInventory.Core.lastError` |
| File-private function | `local function camelCase` | `local function removeInternal(handle, reason, quiet)` |
| File-private variable | `local camelCase` | `local pageReady = false` |
| File-private constant | `local UPPER_SNAKE` | `local TICK_MS = 100` |
| Config and data keys | UPPER_SNAKE | `OPX_WEATHER_CONFIG.DAY_LENGTH_MINUTES` |

- **Define through the full path; read through an alias if you like.** A file
  may open with `local State = OpxNotify.State` and call `State.Remove(handle)`.
  It never writes `function State.Remove(...)`.
- **A `local function` is declared before its first use in the file.** An
  earlier reference compiles to a nil global and dies the first time it runs.
- **Documented names are frozen.** The core's plug-in API keeps the names this
  site documents — `OPX.AddMoney`, `OPX.Hooks.register`, `OPX.Storage.Players.*`
  — and every `<Ns>.Locale.register` stays lowercase, because operators' own
  `locales/<code>.lua` files call it. Exports keep their names too: the core's
  are PascalCase (`GetPlayerData`), the satellites' camelCase (`show`, `state`).
- **Events are named by their resource.** The core's use
  `opx77:<scope>:<subject>` (`opx77:client:onPlayerLoaded`,
  `opx77:server:selectCharacter`), a satellite's `<resource>:<subject>`
  (`opx77_prompts:show`), and a WebUI channel `<short>:<action>`
  (`notify:ready`).

## Comments are annotation blocks {#comments}

This is the part that most often surprises a new contributor, and it is
deliberate.

**There are no prose comments in the code.** No banner, no section rule, no
explanation above an `if`, no trailing comment, no TODO, no commented-out code.
Every `.lua` file of a resource — `open77.lua` and `config.lua` included —
contains annotation blocks, in English, and nothing else. The reasoning that is
not recoverable from the code goes to `docs/ARCHITECTURE.md`; operator guidance
goes to the README.

A block looks like this:

```lua
--- @author DemiAutomatic
--- @file client/exports.lua
--- @description The seven client exports, each answering a NotifyResponse.

local State = OpxNotify.State
local Runtime = OpxNotify.Runtime
local response = Runtime.Response

--- @author DemiAutomatic
--- @method caller
--- @description Reads the invoking resource and its generation from the host.
--- @returns {string|nil, string|nil}
local function caller()
	local owner = GetInvokingResource()
	local generation = GetInvokingResourceGeneration()
	if not State.ValidName(owner, State.MAX_OWNER) or type(generation) ~= 'number' then
		return nil, 'export_call_required'
	end
	Runtime.NoteOwner(owner, generation)
	return owner
end

--- @author DemiAutomatic
--- @export show
--- @description Raises a toast and answers the handle update and dismiss take.
--- @param definition {NotifyDefinition}
--- @returns {NotifyResponse}
exports('show', function(definition)
	local owner, reason = caller()
	if owner == nil then return response(false, { error = reason }) end
	return Runtime.Show(owner, definition)
end)
```

That is `opx77_notify/client/exports.lua` as shipped. The vocabulary is closed:

| Tag | Where | Form |
|---|---|---|
| `@author` | first line of every block | always `DemiAutomatic` |
| `@file` | the file's header block only | the path from the repository root |
| `@description` | every block | **one** line, 4 to 12 words, factual |
| `@method` | a function | the name a caller types: `OpxNotify.State.Remove`, or `removeInternal` for a local |
| `@param` | one per parameter, in order | `@param name {type}` |
| `@returns` | a function that returns | `@returns {type}`, or `{a, b}` for several values |
| `@field` | the keys of a config table, in its header block | `@field PATH {type}` |
| `@event` | an event handler registration | `@event name` |
| `@command` | a command registration | `@command /name`, or the config path: `@command OPX_WEATHER_CONFIG.COMMANDS.STATUS` |
| `@keybind` | a key mapping registration | `@keybind OPX_HUD_CONFIG.KEYS.TOGGLE` |
| `@export` | an `exports()` call | `@export name` |
| `@class` | reserved | `@class Name` |
| `@type` | a file-scope local or module field holding data | `@type {type}` |

Nothing else is a tag: no `@see`, no `@note`, no `@return`. The rules that go
with it:

- **Order inside a block:** `@author`, exactly one identity tag (`@file`,
  `@method`, `@event`, `@command`, `@keybind`, `@export`, `@class` or `@type`),
  `@description`, the `@param` lines in signature order, `@returns`, then the
  `@field` lines.
- **Types in braces**, unions with a pipe: `{string}`, `{number|nil}`,
  `{table<string, integer>}`, `{fun(source: integer): boolean}`, a class from
  `std/types.lua` such as `{NotifyDefinition}`. An optional parameter is
  `{type|nil}`.
- **A short note** may follow a `@param` whose name is ambiguous (eight words at
  most), or a config `@field` (twelve words at most: the unit, the range, what
  `false` means).
- **Every file starts with its header block** at line 1, followed by one blank
  line. A block sits directly above what it describes.
- **Required:** a block above every file-scope `function` and `local function`,
  every `exports()`, and every file-scope `RegisterNetEvent`, `AddEventHandler`,
  `RegisterCommand` and `RegisterKeyMapping` — and above a file-scope call to a
  registration helper, as `@command` or `@keybind`. A `@type` block on a
  file-scope local or module field that holds state is recommended.
- **No block inside a function body.** A nested function or a handler registered
  from inside a function is covered by the enclosing block.
- **A big catalogue** — a `data/` file, a locale file — carries its header block
  only, never one block per entry.
- `---@diagnostic` lines are functional and stay.

`config.lua` documents its keys in the header, one `@field` per UPPERCASE path,
nested keys included, rows of a list once with `[]`:

```lua
--- @author DemiAutomatic
--- @file config.lua
--- @description Defaults for toasts whose definition leaves a field out.
--- @field POSITION {string} One of the platform's seven positions.
--- @field DURATION_MS {integer} Milliseconds; 0 is persistent, otherwise 750..120000.
--- @field PROGRESS {boolean} Draw the lifetime bar on timed toasts.
--- @field WIDTH {integer} Toast width in pixels on the 1920-wide surface.

OPX_NOTIFY_CONFIG = {
	POSITION = 'top_right',
	DURATION_MS = 5000,
	PROGRESS = true,
	WIDTH = 340,
}
```

Anything an operator needs beyond those twelve words — what an out-of-range
value does, an example row — belongs in the README's Configuration section.

### `std/` {#std}

The annotation blocks are not readable by LuaLS, so the editor's types live in
`std/`: `std/types.lua` for classes and aliases, and one stub per namespace
function, in a file mirroring the code path (`client/state.lua` →
`std/client/state.lua`), with the same name and the same parameter names. These
are ordinary LuaLS files — `---@meta` on the first line, `---@param`, prose
descriptions — and the no-prose rule does not apply to them. They are never
loaded and never listed in the manifest.

```lua
---@meta

OpxNotify.State = {}

--- Removes one toast from the store and answers what it held, or nil.
---@param handle integer
---@return NotifyEntry|nil
function OpxNotify.State.Remove(handle) end
```

A public signature that changes changes its stub in the same commit. A local
function gets no stub.

### `docs/ARCHITECTURE.md` {#architecture-md}

Each resource carries one, **in French**, and it answers "why is it written like
this" where the README answers "how do I use it". It opens with a paragraph on
what the resource is responsible for and what it is not, then:

- **Manifeste** — the load order and why, one line per permission;
- **Contrats** — what the exports, events and commands guarantee beyond their
  list: who the caller is, the shape of an answer, which codes are stable;
- one section per invariant or decision, grouped by topic rather than by file,
  naming the code (`OpxNotify.Runtime.NoteOwner`) so a reader can find it;
- **Clés résolues à l'exécution** — locale keys looked up through a variable,
  such as refusal codes;
- **Limites connues** — the TODOs, and bugs found and not yet fixed.

This is where the habit the old comments carried now lives: record what was
tried, what broke, what the alternative would have cost, and which of two
disagreeing sources was believed. A contribution that silently "fixes" a
sentence to match code that is itself wrong will be asked to adjudicate
instead.

## Formatting {#formatting}

`.editorconfig` is in the repository root and is the authority:

| Setting | Value |
|---|---|
| Indentation in `.lua` | **tabs** |
| Indentation in JSON, HTML, CSS and JS | two spaces |
| Line endings | LF |
| Encoding | UTF-8 |
| Final newline | required |
| Trailing whitespace | trimmed (except in Markdown) |
| String quotes in `.lua` | **single**; double only when the text holds a `'` |
| Maximum line length | none |

- **One space between tokens.** No column alignment: `KEY = value`, never
  `KEY      = value`.
- **No line-length rule, and no reflowing.** An expression already split over
  lines keeps its breaks; a continuation line is indented one tab deeper than
  the line it continues.
- **Long strings** `[[...]]` stay as they are. `open77.lua`, `std/` and `web/`
  are not reformatted.

`.luarc.json` sets `runtime.version` to Lua 5.4, makes `undefined-global` an
**error**, lists the platform globals, loads `std` as a library and sets the
formatter to tabs and single quotes. A new global belongs in that list rather
than in a `---@diagnostic disable` line.

## Every export answers `{ ok = true, ... }` {#export-contract}

Without exception, on every resource:

```lua
--- @author DemiAutomatic
--- @export GetPlayerData
--- @description Answers the whole loaded character, refused before login.
--- @returns {table}
exports('GetPlayerData', function()
	if not OPX.IsLoggedIn then return { ok = false, error = 'error.notLoggedIn' } end
	return { ok = true, data = OPX.PlayerData }
end)
```

- **A plain table.** The value crosses a serialising codec and lands in a VM
  that has none of your types, metatables or error classes.
- **`{ ok = false, error = '<code>' }` rather than an empty result**, so a
  caller cannot mistake "not logged in yet" for "logged in with nothing".
- **`error` is a stable code meant for branching**, never a sentence shown to a
  player. Translate it at the point of display.
- **An export never raises.** A refusal is a value.
- **Read the caller from `GetInvokingResource()`** and
  `GetInvokingResourceGeneration()`, never from a parameter. Taking a caller's
  name from an argument would let any resource impersonate any other.
- **Document every code an export can answer**, in the README's error codes and
  in the reference page for that resource, in a table. `opx77_elevators`' error
  table is the template.

A caller checks three levels, every time: the call was not dispatched
(`Open77.exports.call` answers `nil` and a reason), it was dispatched and failed
(`promise:await()` answers a second error), or it answered with a refusal. **An
answer is a refusal unless `ok` is exactly `true`** — test `answer.ok ~= true`,
never `answer.ok == false`, so an answer that carries no `ok` at all is not
mistaken for a success. The promise is a userdata: test it for presence, never
`type(promise) == 'table'`. And `await` is never called under a `pcall`, because
a yield cannot cross one. [The export contract](../concepts/export-contract.md)
is the long version.

A service that keeps state per caller — a menu, a toast, a prompt — sweeps the
owners that went away. **An owner whose `GetResourceState` is `starting` is
alive**, exactly like one that is `running`: a resource mid-restart has not
left.

Server-side, the core's internal convention is `OPX.Result` —
`{ ok = true, value = … }` or `{ ok = false, error = code, detail = … }` — where
`error` is stable and branchable and `detail` is for logs and staff only, because
it can carry a raw database exception. The simple mutators return
`boolean, string?` instead, where the string is the locale key naming which
refusal it was; check both.

## Player-facing text {#locales}

- **Text a player reads comes from a catalogue**, through `locale(key, params)`:
  a command's answer, toast text, chat suggestions, a label in a WebUI page.
  `Open77.log` lines, console answers and error codes stay English literals.
- **A resource that shows text ships `locales/en.lua` and `locales/fr.lua`**,
  each one `<Ns>.Locale.register('<code>', { ... })` call with one entry per
  line, and both define **exactly the same keys with the same `{placeholders}`**.
  Placeholders are named (`{name}`), because the French catalogues reorder them.
- **Keys are not renamed.** Many of them are refusal codes on the wire — the
  core's `character.limit` is rendered by `opx77_charcreator` through
  `Locale.exists(code)` — and operators' own translation files use them.
- **A key no literal mentions** is either dead, and deleted from both
  catalogues, or looked up through a variable, and listed under "Clés résolues à
  l'exécution" in `docs/ARCHITECTURE.md`.

## Rules the checkers and reviewers apply {#invariants}

- **A shared world entity is created by a server script**; a purely local
  preview stays on the client. Nothing a client sends — a plate, an id in a
  payload — decides a persisted entity's identity.
- **A staff power is an ACL grant, checked on the server.**
  `RegisterCommand(name, fn, true)` lets the host resolve `command.<name>` before
  the handler runs; a net event that performs a staff action re-checks with
  `Open77.acl.isAllowed`. Hiding a menu entry is not a check.
- **A resource that holds player state** — controls, the camera, an animation,
  HUD visibility — releases it on its own stop and on reload.
- **A resource never reaches into another resource's internals**: only its
  exports and documented events.
- **Every write answer is checked, and a failure cancels the transaction** — no
  side effect, a refund where one was taken.
- **A function that yields can give up**, through a generation token, and a
  stale answer is dropped by comparing the provider's generation.
- **One WebUI surface per resource**, created by its own code
  (`web_ui_auto_create false`).
- **Clocks:** `GetGameTimer`, `Open77.time.unix` and `Open77.time.utc` exist on
  the server only. A client reads `Open77.time.monotonic` and keeps its last
  reading when a read fails.
- **Cutting text** never splits a UTF-8 character: cut on a boundary rather than
  with a bare `:sub(1, n)`.
- **Chat lines carry no colour.** An OPX resource sends a line with its `type`
  and lets `opx77_chat`'s `.line.info` and `.line.error` styles colour it.
- **The core owns the schema.** Every table it owns is one
  `CREATE TABLE IF NOT EXISTS` statement in `OPX.Schema`, applied at boot, and
  `sql/schema.sql` carries the same statements: the two are edited together.
  There are no migrations; see [Persistence](../concepts/persistence.md).
- **In a stylesheet, colours live in tokens.** `web/open77-ui.css` is the
  platform's token file, mirrored byte-identical in every resource and never
  edited. A resource stylesheet holds colour literals only in the one `:root { }`
  block at its top, and reads `var(--...)` everywhere else; `web/*.js` and
  `web/*.html` hold none. A token is never preceded by a hard value
  (`var(--y, fallback)`, not `'X', var(--y)`).

## Checking your change {#syntax-check}

The framework targets **PUC Lua 5.4** — the reference implementation, currently
5.4.8. It is not LuaJIT and it is not CfxLua: there are no compile-time hashes,
no vector literals, no safe-navigation operator, no `continue`, and no
compound-assignment operators. Code that uses any of those will not load.

`luac -p` parses without producing output, so it catches every syntax error and
nothing else:

```bash
luac5.4 -p opx77_core/server/player.lua
```

The manifest is *not* Lua and must not be checked this way: `open77.lua` is a
declarative DSL, which is why `auto_start true` is legal there and would be a
syntax error in a script.

The rest of this page is checked by **opx-tools**, a folder of Node checkers
(Node 18 or later; `syntaxcheck` also needs `luac` 5.4 and `loadcheck` needs
`lua` 5.4). It is separate tooling, not vendored into the resource repositories,
so it is not in any resource checkout. Each checker takes one or more resource
directories — the folder holding `open77.lua` — prints one line per finding and
exits `1` when it found anything:

| Checker | Catches |
|---|---|
| `syntaxcheck` | every `.lua` through `luac -p`; `open77.lua` through the manifest reader instead |
| `manifestcheck` | a declared script missing on disk, a `.lua` nothing loads, a glob in a script entry, a `server/` file shipped to clients, a `std/` stub declared as a script, a `---@meta` file outside `std/` |
| `anncheck` | a prose comment, a malformed or missing annotation block, a namespace function defined through an alias, a config key without its `@field` |
| `stylecheck` | indentation that is not tabs, double quotes that could be single, trailing whitespace, a missing final newline, CfxLua-only syntax |
| `localecheck` | a key missing from `en`, `fr` out of step with `en` (keys or placeholders), orphan keys, a catalogue not loaded where it is read |
| `localscheck` | a `local function` referenced above its declaration |
| `keycheck` | a default key outside the OPEN//77 key vocabulary, and two mappings sharing a default key |
| `ordercheck` | a file-scope read of a table a later script defines, or that only the other runtime loads |
| `refcheck` | a read of a namespace member nothing defines (the missed call site of a rename), or of a config key no config file declares |
| `stdcheck` | a namespace function without its `std/` stub, a stub naming nothing, a name that breaks the naming rule; `--doc <opx77_doc>/docs` exempts the names this site documents |
| `webcheck` | a colour literal outside the stylesheet's `:root` tokens, and a `web/open77-ui.css` that differs between resources |
| `helpercheck` | `GetGameTimer` in a script a client loads, a byte cut that can split a UTF-8 character, `ok == false` as the refusal test, an owner sweep that treats `starting` as gone, a dead `Open77.exports == nil` guard, an `await` reached under `pcall`, a promise tested as a table |

```bash
node <opx-tools>/runall.js opx77_<name> --doc <opx77_doc>/docs   # the twelve above
node <opx-tools>/runall.js opx77_<name> --verbose                # with every finding
```

A `helpercheck` finding that is accepted on purpose cannot be silenced by a
comment — there are none — so it is listed in `helpercheck.allow.json` next to
the tool, naming the resource, the rule, the enclosing function (or a
`path:line`) and why.

Two more are run by hand around a change that must not alter behaviour:
`contractcheck` saves the public surface (manifest, exports, events, commands,
config keys and defaults) before the change and compares it after, and
`loadcheck.lua` loads one runtime's scripts in manifest order under a stub host
and prints what got registered, for a before-and-after diff.

The checkers report; they fix nothing, and they do not replace running the
resource. `loadcheck` proves the scripts load and register the same surface; it
does not run a thread or a timer.

## What goes in a README {#readme-policy}

A resource's `README.md` is its **user-facing document**, in English: what the
resource is for, how to install it, and what an operator and an integrating
developer need at hand — its configuration keys with their units, ranges and
what `false` means, its commands, its exports and events, its error codes. It is
also where operator guidance lives now that `config.lua` carries none. It links
to `docs/ARCHITECTURE.md` for the why, and it keeps its sections from release to
release.

This site is the **complete reference**. Every export, event, command, config
key, type and error code has an entry under `reference/`, with its parameters,
its return, its codes and the side it can be called from, and the site carries
what a README does not: the cross-resource concepts, the guides, the release
notes.

The failure both exist to prevent is drift: a README or a reference page that
promises a key, an export or a code the resource no longer has. So, for a pull
request that changes behaviour:

- [ ] The README says what the change makes different, and a key whose guidance
      used to be a comment is described in its Configuration section.
- [ ] `docs/ARCHITECTURE.md` says why, when the why changed.
- [ ] The `reference/` page for that resource is updated in the same change.
- [ ] A new export or event has an entry with its parameters, its return, its
      error codes and the side it can be called from.
- [ ] A removed one is removed from the README and the reference, not left to
      rot.

## Commits and versions {#commits}

- **Summary line:** imperative, sentence case, English, no prefix, no trailing
  period — `Read GetGameTimer once, and only where the server has it`.
- **Body:** after a blank line, prose wrapped at 72 columns saying what changed,
  why, and what was verified (the checkers, `contractcheck`, `loadcheck`). No
  trailers.
- **Version:** a shipped change bumps the minor version in `open77.lua` and
  resets the patch, and every copy of the version string moves with it —
  `OPX.VERSION` in `opx77_core/shared/main.lua`, `OpxNotify.VERSION` in
  `opx77_notify/client/state.lua`.

## Documentation style {#docs-style}

If you are editing this site rather than the framework:

- **Front matter on every page**: a long `title:` and a one-sentence,
  self-contained `description:` — it becomes the search snippet.
- **British spelling**, matching the existing pages.
- **Explicit anchors** `{#like-this}` on every heading anything links to.
  `attr_list` is enabled. Generated anchors renumber silently when a page is
  reordered, and a link that used to work then points at the wrong section.
- **Admonitions are rationed.** `!!! danger` means data, money or a session is
  lost, and there are fewer than five on the whole site. `!!! warning` means
  calling this has a surprising or irreversible effect. `!!! info` is
  orientation, or a read-that-first pointer. `note` and `tip` are retired —
  make them body text.
- **Never document something you have not read in the code.** If the code and an
  older document disagree, open both, decide, and say in the page which one you
  believed.
- `mkdocs build --strict` must pass. It runs in CI and turns a broken internal
  link into a build failure, which is the only reason the cross-links on this
  site do not rot:

```bash
pip install -r requirements.txt
mkdocs build --strict
```

## Licence {#licence}

Every resource is MIT licensed. A contribution is accepted under the same terms.
