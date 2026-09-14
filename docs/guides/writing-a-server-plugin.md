---
title: Writing a server plugin for opx77_core
description: On OPEN//77 a server plug-in is a file you add to opx77_core/server/ and a line you add to its manifest, because OPX is a plain global in one Lua state; this page covers the convention, what an update costs, and how hooks let a plug-in veto a money transfer.
---

# Writing a server plugin

On ESX a plug-in is a resource. On Qbox a plug-in is a resource. On OPEN//77 a
plug-in is **a file you add to `opx77_core/server/` and a line you add to its
manifest**, and that is not a design preference — it is the only arrangement the
runtime permits.

## Why it works this way {#why}

The OPEN//77 **server** runtime installs no `exports`, no
`GetInvokingResource` and no cross-resource event bus. `TriggerEvent` on the
server walks only its own VM. A second server resource therefore cannot be asked
for anything, ever, by anybody.

`OPX` is a plain Lua global. It exists in exactly one Lua state — the one
`opx77_core`'s `server_script` lines are compiled into — and there is no door into
that state from outside. So a gameplay rule that needs `OPX.GetPlayer` must be
compiled into the same state, which means it must be one of those
`server_script` lines.

This is what the platform itself does. Its own gamemode kernel puts a gamemode's
entire server side into one resource for the same reason, and `pursuit` — the
platform's flagship gamemode — carries a **byte-identical copy** of another
resource's data file because there is no way to share it, and says so in its
manifest.

!!! info "Check whether you need this at all"

    A plug-in is the strongest of three server-side channels and the most
    expensive to maintain. If the thing you are building only needs to *draw*
    something, or only needs data the player already has, write a normal client
    resource instead — see [Writing a resource](writing-a-resource.md).
    [Integration channels](../concepts/integration-channels.md) compares all
    three.

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
    plugins/
      shop.lua
      bounty.lua
```

An upgrade then becomes: copy the new `opx77_core` into place, copy your
`server/plugins/` back over it, and re-apply one contiguous block of manifest
lines. Diffing one directory against one directory is a job you can do in a
minute; hunting your changes through fourteen core files is not.

### Keep the manifest lines in one reserved block {#reserved-block}

Put them last among the `server_script` entries, under a marker you can grep for:

```lua
server_script "server/loops.lua"

-- --------------------------------------------------------------------------
-- LOCAL PLUG-INS -- re-apply this block after an opx77_core upgrade.
-- Everything below is server/plugins/*. Load order is manifest order and these
-- come last on purpose: every file above has already published its half of OPX,
-- so a plug-in may reach for anything.
-- --------------------------------------------------------------------------
server_script "server/plugins/shop.lua"
server_script "server/plugins/bounty.lua"
```

!!! warning "One line per file, and last"

    Do not be tempted by `server_scripts { "server/plugins/**/*.lua" }`. An empty
    glob is not ignored on this platform: it refuses the resource set, and on the
    client side that means nobody can connect. Every shipped OPEN//77 resource
    lists its scripts one per line. Last, because load order is manifest order
    and a plug-in that runs before `server/functions.lua` has no `OPX.GetPlayer`
    to reach for.

### What you inherit, and what you owe {#inherited}

Your file is compiled into `opx77_core`. It therefore inherits:

- the core's **permissions** — `network.events`, `database.access`,
  `players.life.*`, `world.vehicles`. You do not declare your own, and you cannot
  request more without editing the core's `permissions` block;
- the core's **ACL namespace** — a `RegisterCommand("myshop.give", …, true)` in
  your file resolves `command.myshop.give` like any other;
- the core's **failure surface** — an error raised at load in your file is an
  error in `opx77_core`, and the whole core does not start. Guard your load-time
  code accordingly.

## A worked plug-in {#worked-example}

A bounty desk. Anyone may check their own bounty; only an operator may set one;
paying a bounty out moves money; and a hook stops any money at all moving into a
frozen account.

```lua
--- opx77_core/server/plugins/bounty.lua
--- A bounty ledger, kept in character metadata.
---
--- Listed LAST in open77.lua so that everything it reaches for -- OPX.GetPlayer,
--- OPX.AddMoney, OPX.SetMetadata, OPX.Hooks -- has already been published.

--- Metadata key. Namespaced, because metadata is one flat table shared with the
--- core and with every other plug-in on this server.
local KEY = "bounty.amount"

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------

--- The bounty on one character, or 0.
---@param identifier Player|Source|CitizenId
---@return integer
local function bountyOf(identifier)
  return tonumber(OPX.GetMetadata(identifier, KEY)) or 0
end

RegisterCommand("bounty", function(source, _, raw)
  local player = OPX.GetPlayer(source)
  if not player then
    -- a refusal is an outcome: a toast, not a chat line
    return OPX.CommandNotice(source, raw, "error", locale("error.notLoggedIn"))
  end
  -- a figure the player asked to read is a report: a chat line
  OPX.CommandResult(source, raw, true,
    ("bounty on %s: %d"):format(player.PlayerData.citizenId, bountyOf(player)))
-- unrestricted: reading your own bounty is not an operator action
end, false)

-- ---------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------

--- `true`, so the host resolves `command.bounty.set` against the caller's ACL
--- BEFORE this handler runs. There is no permission check in here and there must
--- not be one -- the host has already done it, and a second one would drift.
RegisterCommand("bounty.set", function(source, args, raw)
  local target = OPX.GetPlayer(tonumber(args[1]) or -1)
    or OPX.GetPlayerByCitizenId(tostring(args[1] or ""):upper())
  local amount = math.floor(tonumber(args[2]) or -1)

  if not target or amount < 0 then
    -- typed wrong: a warning, since the same command with the right words works
    return OPX.CommandNotice(source, raw, "warning",
      "usage: bounty.set <playerId|citizenId> <amount>")
  end

  OPX.SetMetadata(target, KEY, amount)

  -- The ledger line an operator will be asked about later. Open77.log is for
  -- what the code is doing; OPX.Logger is for what happened to somebody's money.
  OPX.Logger.player(target, "bounty.set", ("set by %s"):format(tostring(source)),
    { amount = amount })

  OPX.CommandNotice(source, raw, "success",
    ("bounty on %s is now %d"):format(target.PlayerData.citizenId, amount))
end, true)

-- ---------------------------------------------------------------------------
-- Paying out
-- ---------------------------------------------------------------------------

--- Claim the bounty on a target. Called from this core's own code; a client
--- request would arrive as a net event and be validated first.
---@param claimant Player|Source|CitizenId
---@param target Player|Source|CitizenId
---@return boolean ok, string? reason  a locale key
local function payOut(claimant, target)
  local hunter = OPX.GetPlayer(claimant)
  local quarry = OPX.GetPlayer(target)
  if not hunter or not quarry then return false, "error.notLoggedIn" end

  local amount = bountyOf(quarry)
  if amount <= 0 then return false, "bounty.none" end

  -- BOTH return values. `ok` alone throws away which refusal it was, and the
  -- refusals are not interchangeable: money.insufficient is a game state,
  -- money.badType is a bug in this file, and money.vetoed is another plug-in
  -- deliberately saying no.
  local ok, why = OPX.AddMoney(hunter, "EDDIES", amount,
    "bounty:" .. quarry.PlayerData.citizenId)
  if not ok then
    Open77.log.warn(("[bounty] payout refused: %s"):format(tostring(why)))
    return false, why
  end

  OPX.SetMetadata(quarry, KEY, 0)
  OPX.Logger.player(hunter, "bounty.claimed", "paid out",
    { amount = amount, target = quarry.PlayerData.citizenId })
  return true
end

-- ---------------------------------------------------------------------------
-- A hook: no money moves into a frozen account, whoever is moving it
-- ---------------------------------------------------------------------------

--- Priority 100, so this runs AFTER any lower-priority hook that might refund or
--- adjust, and its veto is the last word.
OPX.Hooks.register("money:beforeAdd", function(payload)
  if payload.player.PlayerData.metadata.frozen then
    OPX.Logger.security("money.frozen", "add refused",
      { citizenId = payload.player.PlayerData.citizenId,
        moneyType = payload.moneyType, amount = payload.amount },
      payload.player.PlayerData.source)
    return false -- an EXPLICIT false. nil is "no opinion".
  end
end, 100)

Open77.log.info("[bounty] desk ready")
```

Three things in that file are the whole point of the page: `OPX.GetPlayer` is
in scope because the file is in the same VM; `OPX.AddMoney` is checked for
*both* return values; and the hook makes a rule that applies to every money
movement in the framework, including ones written by somebody else.

The two answers are not interchangeable either. What a command **did**, or why
it did not, is [`OPX.CommandNotice`](../reference/opx77_core/server-api.md#commandnotice):
a toast the core's client half raises through `opx77_notify`, or a chat line on
a client without it. What a command **reads** — a figure, a list, a dump — is
[`OPX.CommandResult`](../reference/opx77_core/server-api.md#commandresult), a
chat line that can be scrolled back. Neither goes on `open77:command:result`:
`opx77_chat` prints none of that event's accepted answers, so a command that
answered there would be heard by nobody.

## Hooks {#hooks}

Hooks are the extension point that keeps a plug-in *additive*: without them, a
new rule about money means editing `server/player.lua`, and the next core upgrade
takes the edit away.

### Registering {#hook-register}

```lua
---@param name string
---@param fn fun(payload: HookPayload): boolean?
---@param priority? number   default 0
---@return integer id        pass to OPX.Hooks.remove
local id = OPX.Hooks.register("money:beforeRemove", function(payload)
  if payload.moneyType == "BANK" and payload.amount > 50000 then
    return false
  end
end, 10)
```

- **Lower `priority` runs first.** Equal priorities run in registration order,
  which is manifest order, which is why the reserved block being contiguous
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

A vetoed operation returns `false, "money.vetoed"` to its caller. That code is
deliberately opaque: the operation was refused, and the caller is not told which
of possibly several plug-ins refused it. Log it in the hook if you want it
attributable.

### Where hooks run {#hook-trigger-points}

| Hook | Runs inside | Payload | On veto |
|---|---|---|---|
| `money:beforeAdd` | `OPX.AddMoney` | `player`, `moneyType`, `amount`, `reason` | returns `false, "money.vetoed"` |
| `money:beforeRemove` | `OPX.RemoveMoney` | `player`, `moneyType`, `amount`, `reason` | returns `false, "money.vetoed"` |
| `money:beforeSet` | `OPX.SetMoney` | `player`, `moneyType`, `amount`, `reason` | returns `false, "money.vetoed"` |
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
is logged as

```text
hook money:beforeAdd (#3) raised: server/plugins/bounty.lua:88: attempt to index a nil value
```

and then **treated as no opinion**. The operation proceeds. This is the right
default — a bug in a plug-in should not silently start refusing everybody's
wages — but it means *a hook cannot fail closed*. If your rule is a security
boundary, do not let it depend on code that might raise: validate first, decide
second, and keep the deciding branch trivial.

## Talking to the rest of the server {#talking-out}

Inside the core VM you have `OPX` and you have the platform's `Open77` bindings.
What you do **not** have is a way to ask another server resource anything. The
channels that do work, in the direction they work:

| You want to | Channel |
|---|---|
| tell a client something | `TriggerClientEvent(name, source, …)` — the core holds `network.events` |
| hear from a client | `RegisterNetEvent`, and validate everything except `source` |
| notify a player | `OPX.Notify(source, message, kind, durationMs)` or `OPX.Refuse(source, code)` |
| answer a command | `OPX.CommandNotice(source, raw, kind, message)` for what it did, `OPX.CommandResult(source, raw, accepted, message)` for what it reads |
| know whether another resource is up | `GetResourceState("name")` — the only question you may ask it |
| persist something across a restart | the database, through `OPX.Storage`, or `Open77.state.save` |
| record what happened | `OPX.Logger.player` / `OPX.Logger.security` |
| say what the code is doing | `Open77.log.debug` / `.info` / `.warn` / `.error` |

`GetResourceState` deserves the emphasis: it is the *entire* server-side
inter-resource surface. `opx77_elevators` uses it to warn that the official
`open77_elevators` is also running, and `opx77_chat` uses it to warn that
`open77_chat` is. Warning is all you can do with it.

## Checklist {#checklist}

- [ ] The file lives in `opx77_core/server/plugins/`.
- [ ] Its manifest line is in the reserved block, last, one line per file.
- [ ] Nothing at load time can raise — an error there stops the whole core.
- [ ] Every `OPX.*` mutator call checks both return values.
- [ ] Metadata keys are namespaced to your plug-in.
- [ ] Restricted commands pass `true` and contain **no** permission check of
      their own.
- [ ] No hook yields, and no hook moves money.
- [ ] Every hook returns an explicit `false` to veto and `nil` otherwise.
- [ ] Anything an operator will be asked about later goes through `OPX.Logger`.

## Where to go next {#next}

- [Integration channels](../concepts/integration-channels.md) — the two
  server-side channels that are *not* a plug-in, and when they are enough.
- [Architecture](../concepts/architecture.md) — why the server side is one
  resource.
- [Contributing](contributing.md) — the house style your plug-in should match if
  you ever want to upstream it.
