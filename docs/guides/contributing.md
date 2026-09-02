---
title: Contributing to OPX//77
description: The house style for OPX//77 resources — directory layout, the manifest load-order rule, the comment convention, two-space indentation, the {ok = boolean} export contract, how to syntax-check with PUC Lua 5.4, and the README-is-marketing policy.
---

# Contributing

OPX//77 has a house style and it is enforced by review rather than by a linter,
so it is written down here. Most of it is ordinary; three parts of it are not,
and those three are the ones a pull request is most often asked to change.

## How a resource is laid out {#layout}

Every OPX//77 resource has the same shape:

```text
opx77_<name>/
  open77.lua        the manifest -- a declarative DSL, NOT executed as Lua
  config.lua        one file, for a satellite
  types.lua         ---@meta annotations; never loaded at runtime
  shared/           compiled into both VMs
  client/           distributed to and run by clients
  server/           never included in the client package
  web/              the CEF surface, where there is one
  README.md         marketing
  LICENSE
```

`opx77_core` is the exception and splits its configuration by who may read it:

```text
opx77_core/
  config/shared.lua    both VMs -- SHIPPED TO EVERY CLIENT, never a secret
  config/server.lua    slots, autosave, paychecks, entry deadlines
  config/client.lua    client cadences; never loaded by the server VM
  data/                jobs, gangs, origins -- definitions, not settings
  locales/             one file per language
  server/tunables.lua  anything an operator changes mid-session
  server/storage/      the database layer
```

The `config` / `data` / `tunables` split is a real distinction, not filing.
**Config** is what a server owner sets before boot. **Data** is definitions —
renaming a job renames something players already hold, so it is not a setting.
**Tunables** are what an operator changes at 3 a.m. from the Warden panel without
a restart. Putting a value in the wrong one is a review comment.

## The load-order rule {#load-order}

**Load order is manifest order, and it is dependency order.** There is no
autoloader, no `require` across files, and no deferred initialisation: a file
that reaches for something a later file publishes fails at load, not at runtime.

Three consequences the shipped manifests all obey:

1. `shared/main.lua` is first, because it creates the `OPX` global everything
   else hangs off. Every resource has one such file and one such global —
   `OPX`, `OpxMenu`, `OpxHud`, `OpxChat`, `OpxStatus`, `OpxWeather`,
   `OpxElevators`.
2. `client/exports.lua` is **last** among a resource's client scripts. Publishing
   the surface claims everything it reads, so it must not run before the things
   it reads exist.
3. Every line whose position is load-bearing carries a comment saying so.
   `opx77_core/open77.lua` carries eight such notes — *"after storage, because it
   writes through it"*, *"after player.lua: a group change writes through the
   Player"*. Copy the habit: the next person to reorder the block needs to know
   which lines are safe to move.

!!! warning "One script per line. Never glob a script directory."

    `client_scripts { "client/**/*.lua" }` requires an intermediate directory and
    matches **nothing** against a flat `client/main.lua`. An empty glob does not
    warn and is not skipped — it refuses the **whole client resource set**, and
    no player can connect to the server at all. `**` is safe only under
    `web_files`.

## Comments explain *why* {#comments}

This is the part that most often surprises a new contributor, and it is
deliberate.

A comment in this codebase does not restate what the line does. It records the
reasoning that is not recoverable from the code: what was tried, what broke, what
the alternative would have cost, and which of two disagreeing sources was
believed.

```lua
-- an if/else: in `a >= 0 and Add() or Remove()` a false from Add runs Remove as well
local ok, why
if amount >= 0 then
  ok, why = OPX.AddMoney(target, moneyType, amount, reason)
else
  ok, why = OPX.RemoveMoney(target, moneyType, -amount, reason)
end
```

```lua
-- sorted: `pairs` order would reshuffle the report between two runs, and comparing two
-- dumps is the whole use for it
table.sort(report)
```

```lua
-- Said, because the alternative is what happened last time: the client grew a leading
-- argument, every sighting died here, no lift was ever adopted, and the only symptom was
-- a panel answering `not_adopted` forever. One log line is the difference between that
-- and an audit.
```

Three rules follow:

- **A file starts with a `---` block saying what it is for and what it is not.**
  Not a table of contents — the constraint the file exists to satisfy.
- **A surprising line gets a comment; an obvious one gets none.** A comment on
  `local Config = OPX.Config.SERVER` is noise.
- **When the code and a comment elsewhere disagree, say which is right and why.**
  The framework does this in several places and it is one of the more valuable
  habits in it. A contribution that silently "fixes" a comment to match code that
  is itself wrong will be asked to adjudicate instead.

## Formatting {#formatting}

`.editorconfig` is in the repository root and is the authority:

| Setting | Value |
|---|---|
| Indentation | **two spaces**, never tabs |
| Line endings | LF |
| Encoding | UTF-8 |
| Final newline | required |
| Trailing whitespace | trimmed (except in Markdown) |
| Maximum line length | 100 columns, in `.lua` |
| String quotes | double |

100 columns is not advisory. It is what makes a three-pane diff readable, and
long lines are the most common formatting comment on a pull request.

Naming, matching the shipped code: `PascalCase` for the framework's public
functions (`OPX.AddMoney`), `camelCase` for locals and file-private functions,
`UPPER_SNAKE` for config keys and module-level constants, and
`resource:side:subject` for event names (`opx77:client:onPlayerLoaded`).

Annotate with LuaLS. `.luarc.json` sets `runtime.version` to Lua 5.4, makes
`undefined-global` an **error**, and lists the platform globals; a new global
belongs in that list rather than in a `---@diagnostic disable` comment.

## Every export answers `{ ok = boolean, ... }` {#export-contract}

Without exception, on every resource:

```lua
---@return { ok: boolean, data?: PlayerData, error?: string }
exports("GetPlayerData", function()
  if not OPX.IsLoggedIn then return { ok = false, error = "error.notLoggedIn" } end
  return { ok = true, data = OPX.PlayerData }
end)
```

- **A plain table.** The value crosses a serialising codec and lands in a VM
  that has none of your types, metatables or error classes.
- **`ok = false` rather than an empty result**, so a caller cannot mistake "not
  logged in yet" for "logged in with nothing".
- **`error` is a stable code meant for branching**, never a sentence shown to a
  player. Translate it through the `Locale` export at the point of display.
- **An export never raises.** A refusal is a value.
- **Read the caller from `GetInvokingResource()`**, never from a parameter.
  Taking a caller's name from an argument would let any resource impersonate any
  other, and every published service in the framework guards it the same way.
- **Document every code an export can answer.** They belong in the reference page
  for that resource, in a table. `opx77_elevators`' 24-row error table is the
  template.

Server-side, the equivalent convention is `OPX.Result` — `{ ok = true, value = … }`
or `{ ok = false, error = code, detail = … }` — where `error` is stable and
branchable and `detail` is for logs and staff only, because it can carry a raw
database exception. The simple mutators return `boolean, string?` instead, where
the string is the locale key naming which refusal it was; check both.

## Syntax-checking {#syntax-check}

The framework targets **PUC Lua 5.4** — the reference implementation, currently
5.4.8. It is not LuaJIT and it is not CfxLua: there are no compile-time hashes,
no vector literals, no safe-navigation operator, no `continue`, and no
compound-assignment operators. Code that uses any of those will not load.

Check every file you touched before opening a pull request:

```bash
# one file
luac5.4 -p opx77_core/server/player.lua

# everything, and stop on the first failure
find . -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
```

`luac -p` parses without producing output, so it catches every syntax error and
nothing else. It does **not** catch an undefined global or a wrong argument
count — that is what LuaLS with the shipped `.luarc.json` is for, and both are
expected to be clean.

The manifest is *not* Lua and must not be checked this way: `open77.lua` is a
declarative DSL, which is why `auto_start true` is legal there and would be a
syntax error in a script.

## README is marketing; the docs site is the API {#readme-policy}

A resource's `README.md` exists to tell somebody browsing the repository what the
resource is for and why they might want it. It is **not** technical
documentation, and it must not be the place a developer looks up a config key, an
export or an event.

The public API — every export, event, command, config key, type and error code —
belongs on this site, under `reference/`, and nowhere else. A README that
documents an API drifts, and three OPX//77 READMEs currently promise config keys,
themes and gauges that do not exist, which is exactly the failure this policy
exists to prevent.

So, for a pull request that changes behaviour:

- [ ] The `reference/` page for that resource is updated in the same change.
- [ ] The README is updated **only** if the marketing claim changed.
- [ ] A new export or event has an entry with its parameters, its return, its
      error codes and the side it can be called from.
- [ ] A removed one is removed from the reference, not left to rot.

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
