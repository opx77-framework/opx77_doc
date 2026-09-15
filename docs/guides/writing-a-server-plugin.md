---
title: Writing a server plugin for opx77_core
description: On OPEN//77 a server plug-in that needs OPX is a file you add to opx77_core/server/ and a line you add to its manifest, because OPX is a plain global in one Lua state that no export publishes; this page covers the convention, what an update costs, the house style the file follows, and how hooks let a plug-in veto a money transfer.
---

# Writing a server plugin

On ESX a plug-in is a resource. On Qbox a plug-in is a resource. On OPEN//77 a
plug-in that needs the framework's server API is **a file you add to
`opx77_core/server/` and a line you add to its manifest**, and that is not a
design preference — it is the only place that API exists.

## Why it works this way {#why}

`OPX` is a plain Lua global. It exists in exactly one Lua state — the one
`opx77_core`'s `server_script` lines are compiled into — and every OPEN//77
resource runs in a VM of its own. `OPX.GetPlayer`, `OPX.AddMoney`,
`OPX.SetMetadata` and `OPX.Hooks.register` are functions in that state, handing
out and taking live tables and functions, and none of them is an export.

Server resources can call each other, through the same asynchronous surface as
client resources: `exports(name, fn)` publishes, `Open77.exports.call(resource,
name, ...)` answers a promise, and `GetInvokingResource()` names the caller
inside the exported coroutine. `opx77_core` uses it for what another server
resource cannot do alone, and nothing more:
[eleven server exports](../reference/opx77_core/exports/server.md) —
`GetVersion`, `GetIdentity`, `GetVehiclePlate` and `GetChanges` for any server
resource `EXPORTS.READ` admits, and the seven `Inventory*` storage exports for a
caller `EXPORTS.CALLERS` grants the `inventory` scope. `opx77_status` asks
`GetIdentity` which character a player has loaded; `opx77_inventory` stores every
bag through the storage exports, and publishes
[server exports of its own](../reference/opx77_inventory/exports.md#server) that
`opx77_admin` calls.

What an export cannot do is the plug-in API. Arguments and results are copied
through a codec: a `Player` with its `Functions`, or a hook function, cannot
cross it. So a gameplay rule that needs `OPX.GetPlayer`, moves money, or must
veto a money movement before it lands has to be compiled into the core's state,
which means it must be one of the core's `server_script` lines.

!!! info "Check whether you need this at all"

    A plug-in is the strongest of the server-side channels and the most
    expensive to maintain. If the thing you are building only needs to *draw*
    something, or only needs data the player already has, write a normal client
    resource instead — see [Writing a resource](writing-a-resource.md). If it
    only needs to know which character a player has loaded, a server resource of
    your own can ask `GetIdentity`.
    [Integration channels](../concepts/integration-channels.md) compares the
    options.

## What it costs {#what-it-costs}

Being a file inside somebody else's resource has one consequence and you should
decide about it before you write a line:

**An update to `opx77_core` overwrites the directory, and your file and your
manifest line go with it.** There is no plug-in registry, no hot directory that
is scanned, and no `plugins/` convention the core itself honours at load. The
core cannot help you here — a resource on this platform is a fixed list of
scripts in a manifest.

Two conventions make the collision survivable, and OPX//77 asks you to adopt
both.

### Keep every plug-in in `server/plugins/` {#plugins-directory}

One directory, nothing of the core's own in it:

```text
opx77_core/
  server/
    ...
    loops.lua
    exports.lua
    plugins/
      shop.lua
      bounty.lua
```

An upgrade then becomes: copy the new `opx77_core` into place, copy your
`server/plugins/` back over it, and re-apply one contiguous block of manifest
lines. Diffing one directory against one directory is a job you can do in a
minute; hunting your changes through twenty core files is not.

### Keep the manifest lines in one block, last {#reserved-block}

Put them last among the `server_script` entries, after `server/exports.lua`, as
one block of their own:

```lua
server_script "server/loops.lua"
server_script "server/exports.lua"

server_script "server/plugins/shop.lua"
server_script "server/plugins/bounty.lua"
```

The shipped manifest carries no comments — the reasons for its order are in the
"Manifeste" section of `opx77_core/docs/ARCHITECTURE.md` — so the block is not
marked by one: its paths are the marker. `grep -n 'server/plugins/' open77.lua`
lists every line to re-apply after an upgrade. The manifest is not reformatted
either: keep its double quotes and one entry per line.

!!! warning "One line per file, and last"

    Do not be tempted by `server_scripts { "server/plugins/**/*.lua" }`. An empty
    glob is not ignored on this platform: it refuses the resource set, and on the
    client side that means nobody can connect. Every shipped OPEN//77 resource
    lists its scripts one per line. Last, because load order is manifest order:
    every file above has already published its half of `OPX`, and a plug-in that
    runs before `server/functions.lua` has no `OPX.GetPlayer` to reach for.

### What you inherit, and what you owe {#inherited}

Your file is compiled into `opx77_core`. It therefore inherits:

- the core's **permissions** — `network.events`, `database.access`,
  `players.life.read`, `players.life.kill`, `players.life.respawn`,
  `players.life.revive`, `players.damage.apply`, `world.vehicles`, `acl.read`
  and `players.disconnect`. You do not declare your own, and you cannot request
  more without editing the core's `permissions` block;
- the core's **ACL namespace** — a `RegisterCommand('myshop.give', …, true)` in
  your file resolves `command.myshop.give` like any other;
- the core's **failure surface** — an error raised at load in your file is an
  error in `opx77_core`, and the whole core does not start. Guard your load-time
  code accordingly;
- the core's **house style**, if you ever want the file upstreamed: annotation
  blocks and no prose comments, tabs and single quotes, `local function
  camelCase`, and English and French text for anything a player reads. See
  [Contributing](contributing.md).

## A worked plug-in {#worked-example}

A bounty desk. Anyone may check their own bounty; only an operator may set one;
paying a bounty out moves money; and a hook stops any money at all moving into a
frozen account.

```lua
--- @author DemiAutomatic
--- @file server/plugins/bounty.lua
--- @description A bounty ledger kept in character metadata, with a frozen-account hook.

--- @author DemiAutomatic
--- @type {string}
--- @description Metadata key holding the bounty on a character.
local KEY = 'bounty.amount'

OPX.Locale.register('en', {
	['bounty.none'] = 'There is no bounty on that character.',
	['bounty.report'] = 'Bounty on {citizenId}: {amount}.',
	['bounty.set'] = 'The bounty on {citizenId} is now {amount}.',
	['bounty.usage'] = 'Usage: bounty.set <playerId|citizenId> <amount>',
})

OPX.Locale.register('fr', {
	['bounty.none'] = "Il n'y a aucune prime sur ce personnage.",
	['bounty.report'] = 'Prime sur {citizenId} : {amount}.',
	['bounty.set'] = 'La prime sur {citizenId} est maintenant de {amount}.',
	['bounty.usage'] = 'Usage : bounty.set <playerId|citizenId> <montant>',
})

--- @author DemiAutomatic
--- @method bountyOf
--- @description Answers the bounty on one character, or zero.
--- @param identifier {Player|Source|CitizenId}
--- @returns {integer}
local function bountyOf(identifier)
	return tonumber(OPX.GetMetadata(identifier, KEY)) or 0
end

--- @author DemiAutomatic
--- @command /bounty
--- @description Reports the bounty on the caller's own character.
RegisterCommand('bounty', function(source, _, raw)
	local player = OPX.GetPlayer(source)
	if not player then
		return OPX.CommandNotice(source, raw, 'error', locale('error.notLoggedIn'))
	end
	OPX.CommandResult(source, raw, true, locale('bounty.report', {
		citizenId = player.PlayerData.citizenId,
		amount = bountyOf(player),
	}))
end, false)

--- @author DemiAutomatic
--- @command /bounty.set
--- @description Sets the bounty on a character; the host checks the ACL first.
RegisterCommand('bounty.set', function(source, args, raw)
	local target = OPX.GetPlayer(tonumber(args[1]) or -1)
		or OPX.GetPlayerByCitizenId(tostring(args[1] or ''):upper())
	local amount = math.floor(tonumber(args[2]) or -1)

	if not target or amount < 0 then
		return OPX.CommandNotice(source, raw, 'warning', locale('bounty.usage'))
	end

	OPX.SetMetadata(target, KEY, amount)
	OPX.Logger.player(target, 'bounty.set', ('set by %s'):format(tostring(source)), { amount = amount })

	OPX.CommandNotice(source, raw, 'success', locale('bounty.set', {
		citizenId = target.PlayerData.citizenId,
		amount = amount,
	}))
end, true)

--- @author DemiAutomatic
--- @method payOut
--- @description Pays the bounty on a target to a claimant, then clears it.
--- @param claimant {Player|Source|CitizenId}
--- @param target {Player|Source|CitizenId}
--- @returns {boolean, string|nil}
local function payOut(claimant, target)
	local hunter = OPX.GetPlayer(claimant)
	local quarry = OPX.GetPlayer(target)
	if not hunter or not quarry then return false, 'error.notLoggedIn' end

	local amount = bountyOf(quarry)
	if amount <= 0 then return false, 'bounty.none' end

	local ok, why = OPX.AddMoney(hunter, 'EDDIES', amount, 'bounty:' .. quarry.PlayerData.citizenId)
	if not ok then
		Open77.log.warn(('[bounty] payout refused: %s'):format(tostring(why)))
		return false, why
	end

	OPX.SetMetadata(quarry, KEY, 0)
	OPX.Logger.player(hunter, 'bounty.claimed', 'paid out', { amount = amount, target = quarry.PlayerData.citizenId })
	return true
end

--- @author DemiAutomatic
--- @type {integer}
--- @description Id of the hook refusing money into a frozen account.
local frozenHook = OPX.Hooks.register('money:beforeAdd', function(payload)
	if payload.player.PlayerData.metadata.frozen then
		OPX.Logger.security('money.frozen', 'add refused', {
			citizenId = payload.player.PlayerData.citizenId,
			moneyType = payload.moneyType,
			amount = payload.amount,
		}, payload.player.PlayerData.source)
		return false
	end
end, 100)

Open77.log.info(('[bounty] desk ready, hook #%d'):format(frozenHook))
```

The file carries no comment a reader could skim for the reasoning, so here it
is — and in an upstreamed plug-in it would be the core's `docs/ARCHITECTURE.md`
that says it:

- **It is listed last** in `open77.lua`, so that everything it reaches for —
  `OPX.GetPlayer`, `OPX.AddMoney`, `OPX.SetMetadata`, `OPX.Hooks`, `locale` —
  has already been published.
- **The metadata key is namespaced**, because metadata is one flat table shared
  with the core and with every other plug-in on this server.
- **Its text is registered into the core's catalogues.** `OPX.Locale.register`
  merges keys into a language, so the plug-in carries its own English and French
  lines without editing `opx77_core/locales/`, and `payOut` can answer
  `bounty.none` as a code `locale()` renders.
- **`/bounty` is unrestricted** (`false`): reading your own bounty is not an
  operator action. **`bounty.set` passes `true`**, so the host resolves
  `command.bounty.set` against the caller's ACL *before* the handler runs. There
  is no permission check inside it and there must not be one — the host has
  already done it, and a second one would drift.
- **`OPX.Logger` is the ledger** an operator will be asked about later.
  `Open77.log` is for what the code is doing; `OPX.Logger` is for what happened
  to somebody's money.
- **`payOut` is called from the core's own code**; a client request for it would
  arrive as a net event and be validated first.
- **The hook's priority is 100**, so it runs *after* any lower-priority hook that
  might refund or adjust, and its veto is the last word. It returns an explicit
  `false`; `nil` is "no opinion". Its id is kept, for `OPX.Hooks.remove`.

Three things in that file are the whole point of the page: `OPX.GetPlayer` is
in scope because the file is in the same VM; `OPX.AddMoney` is checked for
*both* return values; and the hook makes a rule that applies to every money
movement in the framework, including ones written by somebody else. Both return
values matter because the refusals are not interchangeable: `money.insufficient`
is a game state, `money.badType` is a bug in this file, and `money.vetoed` is
another plug-in deliberately saying no.

The two answers are not interchangeable either. What a command **did**, or why
it did not, is [`OPX.CommandNotice`](../reference/opx77_core/server-api.md#commandnotice):
a toast the core's client half raises through `opx77_notify`, or a chat line on
a client without it. What a command **reads** — a figure, a list, a dump — is
[`OPX.CommandResult`](../reference/opx77_core/server-api.md#commandresult), a
chat line that can be scrolled back, sent with its `type` and no colour of its
own: `opx77_chat` styles it. Neither goes on `open77:command:result`:
`opx77_chat` prints none of that event's accepted answers, so a command that
answered there would be heard by nobody.

## Hooks {#hooks}

Hooks are the extension point that keeps a plug-in *additive*: without them, a
new rule about money means editing `server/player.lua`, and the next core upgrade
takes the edit away.

### Registering {#hook-register}

`OPX.Hooks.register(name, fn, priority)` adds `fn` at `name` and answers the
hook's integer id. `priority` defaults to `0`; `fn` receives the payload and
returns `false` to veto.

```lua
--- @author DemiAutomatic
--- @type {integer}
--- @description Id of the hook capping bank withdrawals.
local capHook = OPX.Hooks.register('money:beforeRemove', function(payload)
	if payload.moneyType == 'BANK' and payload.amount > 50000 then
		return false
	end
end, 10)
```

- **Lower `priority` runs first.** Equal priorities run in registration order,
  which is manifest order, which is why the plug-in block being contiguous
  matters.
- **`OPX.Hooks.remove(id)`** answers `true` if it removed something.
- **`OPX.Hooks.has(name)`** answers whether anything is listening, for skipping a
  payload nobody will read.
- `OPX.Hooks` lives in `shared/hooks.lua`, so it exists in the client VM too —
  but every trigger point in the framework is server-side, so registering one
  client-side does nothing.

### The veto {#hook-veto}

A hook returns **`false` and only `false`** to refuse. `nil`, `true`, a string, a
table — all of them mean "no opinion". The first `false` wins and the remaining
hooks at that name are not run.

A vetoed operation returns `false, 'money.vetoed'` to its caller. That code is
deliberately opaque: the operation was refused, and the caller is not told which
of possibly several plug-ins refused it. Log it in the hook if you want it
attributable.

### Where hooks run {#hook-trigger-points}

| Hook | Runs inside | Payload | On veto |
|---|---|---|---|
| `money:beforeAdd` | `OPX.AddMoney` | `player`, `moneyType`, `amount`, `reason` | returns `false, 'money.vetoed'` |
| `money:beforeRemove` | `OPX.RemoveMoney` | `player`, `moneyType`, `amount`, `reason` | returns `false, 'money.vetoed'` |
| `money:beforeSet` | `OPX.SetMoney` | `player`, `moneyType`, `amount`, `reason` | returns `false, 'money.vetoed'` |
| `paycheck:before` | the paycheck loop | `player`, `amount` | that player is skipped this cycle, silently |

`amount` on `money:beforeAdd` and `money:beforeRemove` is the **validated,
positive delta** — the sign is already resolved and the value has already passed
the finite-number check. `amount` on `money:beforeSet` is the **resulting
balance**, not a delta, and it is already rounded. Both arrive after the money
type has been validated, so `payload.moneyType` is always a real type.

!!! warning "A hook runs *inside* the operation it guards"

    `OPX.AddMoney` calls your function synchronously, in the middle of moving
    money, before the balance is written. That has two consequences you must
    design around.

    **A hook that yields stalls a money transfer.** No `Wait`, no
    `promise:await`, no database round trip. If your rule needs data that is not
    already in memory, cache it and let the cache go stale — an autosave that
    takes 400 ms because a hook waited on a query is a server that stutters every
    time anyone is paid.

    **A hook must not itself move money.** Calling `OPX.AddMoney` from a
    `money:beforeAdd` hook re-enters the same path and runs your hook again.
    Nothing stops it; there is no re-entry guard.

### A raising hook is caught {#hook-errors}

Every hook is invoked under `pcall`, because it belongs to somebody else's file
and a broken one must not take a money transfer down with it. A hook that raises
is logged as an error line

```text
[hooks] money:beforeAdd (#3) raised: server/plugins/bounty.lua:88: attempt to index a nil value
```

and then **treated as no opinion**. The operation proceeds. This is the right
default — a bug in a plug-in should not silently start refusing everybody's
wages — but it means *a hook cannot fail closed*. If your rule is a security
boundary, do not let it depend on code that might raise: validate first, decide
second, and keep the deciding branch trivial.

## Keeping data of your own {#storage}

Most plug-ins need no table. Character metadata, through `OPX.SetMetadata`, is
saved with the character by the core's autosave and on departure, as the bounty
desk above relies on.

A plug-in that does need a table owns it itself. `OPX.Schema`, in
`server/storage/schema.lua`, is the core's own list of
`CREATE TABLE IF NOT EXISTS` statements, applied once by the boot thread and
mirrored by `sql/schema.sql`; there are no migrations, and an upgrade replaces
both files. Keep your statement in your plug-in, run it through
`OPX.Storage.execute` from a `CreateThread` once `OPX.Storage.ready()` answers
`true`, and read and write through `OPX.Storage.query`, `single`, `insert` and
`update`, each of which answers an `OPX.Result`. A table keyed on a citizen id
belongs in `CHARACTERS.CASCADE_TABLES` in `config/server.lua`, so its rows go
with a deleted character. See [Persistence](../concepts/persistence.md) for what
the core's own tables hold.

## Talking to the rest of the server {#talking-out}

Inside the core VM you have `OPX` and you have the platform's `Open77` bindings.
The channels that work, in the direction they work:

| You want to | Channel |
|---|---|
| tell a client something | `TriggerClientEvent(name, source, …)` — the core holds `network.events` |
| hear from a client | `RegisterNetEvent`, and validate everything except `source` |
| notify a player | `OPX.Notify(source, message, kind, durationMs)` or `OPX.Refuse(source, code, operation)` |
| answer a command | `OPX.CommandNotice(source, raw, kind, message)` for what it did, `OPX.CommandResult(source, raw, accepted, message)` for what it reads |
| ask another server resource | `Open77.exports.call(resource, name, …)` from a thread, an event handler or a command handler, then `:await()` — checked at three levels, and a refusal is any answer whose `ok` is not `true` |
| know whether another resource is up | `GetResourceState('name')` — a hint; the export answer is the proof |
| persist something across a restart | character metadata, a table of your own through `OPX.Storage`, or `Open77.state.save` |
| record what happened | `OPX.Logger.player` / `OPX.Logger.security` |
| say what the code is doing | `Open77.log.debug` / `.info` / `.warn` / `.error` |

What no channel gives you is another server resource's *events*: `TriggerEvent`
on the server walks only its own VM, so `OPX.Events.Internal` is heard by the
core's files and your plug-in, and by nothing outside. A server resource that
needs to follow characters reads the core's `GetChanges` cursor instead.
`opx77_elevators` uses `GetResourceState` to warn that the official
`open77_elevators` is also running, and `opx77_chat` to warn that `open77_chat`
is.

## Checklist {#checklist}

- [ ] The plug-in genuinely needs `OPX` — a server export of the core would not
      do.
- [ ] The file lives in `opx77_core/server/plugins/`.
- [ ] Its manifest line is in the plug-in block, last, one line per file.
- [ ] Nothing at load time can raise — an error there stops the whole core.
- [ ] Every `OPX.*` mutator call checks both return values.
- [ ] Metadata keys are namespaced to your plug-in.
- [ ] Text a player reads is registered in English and French.
- [ ] Restricted commands pass `true` and contain **no** permission check of
      their own.
- [ ] No hook yields, and no hook moves money.
- [ ] Every hook returns an explicit `false` to veto and `nil` otherwise.
- [ ] Anything an operator will be asked about later goes through `OPX.Logger`.

## Where to go next {#next}

- [Integration channels](../concepts/integration-channels.md) — the server-side
  channels that are *not* a plug-in, and when they are enough.
- [`opx77_core`'s server exports](../reference/opx77_core/exports/server.md) —
  what a server resource of your own can ask the core.
- [Architecture](../concepts/architecture.md) — why the server side of the
  framework is one resource.
- [Contributing](contributing.md) — the house style your plug-in should match if
  you ever want to upstream it.
