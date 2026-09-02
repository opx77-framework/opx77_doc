---
title: Hooks
description: The opx77_core hook system — register, remove, has and trigger, how priority orders them, what the veto can and cannot express, why a hook that yields stalls a money transfer, and the complete list of the four hook points with each payload.
---

# Hooks

A hook is a function the core calls **inside** an operation, before it commits,
so that a plug-in can refuse it. They exist for one reason: without them, a new
rule about money means editing `server/player.lua`, and the next core upgrade
takes the edit away.

```lua
OPX.Hooks.register("money:beforeRemove", function(payload)
  if payload.moneyType == "BANK" and payload.player.PlayerData.metadata.frozen then
    return false
  end
end)
```

!!! info "This surface is reachable from inside `opx77_core` only"

    `OPX.Hooks` lives in the core's own Lua state. Registering one means adding
    a file to `opx77_core/server/` and a line to `opx77_core/open77.lua` — read
    [Writing a server plugin](../../guides/writing-a-server-plugin.md) first.
    `shared/hooks.lua` is a `shared_script`, so `OPX.Hooks` also exists in the
    client VM, but **every trigger point in the framework is server-side**:
    registering a hook client-side compiles, runs, and does nothing for ever.

## Be honest about what this is {#scope}

The hook surface is small and it is money-shaped. Four points, all of them
"before", all of them boolean. Before you build on it, know what it cannot do:

- **A hook cannot modify a value.** "Charge a 5% transaction fee", "cap this
  payout at 10 000", "round to the nearest 50" are not expressible. The return
  value is read as a veto and nothing else; a hook that returns a number is
  treated as having no opinion, and the original amount goes through unchanged.
  The only way to change an amount today is to refuse the call and make a
  second one yourself.
- **There are no `after` points.** Nothing is called once a balance has actually
  moved. Use the internal event `opx77:player:moneyChange` for that — it fires
  after the write, inside the core's own VM. See [Events](events.md).
- **There is nothing outside money.** No `character:beforeCreate`, no
  `job:beforeSet`, no `login:before`. A rule about those is written where the
  operation is, or not at all.
- **A hook cannot fail closed.** One that raises is caught and treated as
  permission granted. See [A raising hook is caught](#errors).

What it *is* good at is the case it was built for: a plug-in that must be able
to say **no** to a money movement it did not initiate, without editing the file
that moves it.

## The API {#api}

### register {#register}

Registers a hook at a named point and returns an id for removing it later;
**raises** when `name` is not a string or `fn` is not a function.

```lua
local id = OPX.Hooks.register(name, fn, priority)
```

- name: `string`
    - One of the [four points](#points), or a name of your own that you also
      [`trigger`](#trigger) yourself.
- fn: `fun(payload: HookPayload): boolean?`
    - Return `false` to veto. Return anything else, or nothing, to allow.
- priority?: `number`
    - **Lower runs first.** Anything unparseable becomes `0`.
    - Default: `0`

**Returns** `integer` — the id, for [`remove`](#remove).

**Errors**

| Code | Meaning |
|---|---|
| *(raises)* | `name` is not a string, or `fn` is not a function. A level-2 Lua error pointing at your call site — not a `Result`. |

**Side** `server` — inside `opx77_core` only. Does not yield, and **your hook
must not yield either**: it runs inside the operation it guards.

The list at each name is kept sorted on write rather than on read, because it is
written once at load and read on every money movement thereafter. Equal
priorities keep registration order, which is manifest order — which is why
keeping a plug-in's `server_script` lines contiguous in `open77.lua` matters.

There is no unregister-on-reload and none is needed: the registry is a plain
table in the core's Lua state, and a reload of `opx77_core` rebuilds the state
from nothing.

### remove {#remove}

Removes one previously registered hook by id; returns `false` when no hook
carries that id.

```lua
local removed = OPX.Hooks.remove(id)
```

- id: `integer`
    - The value [`register`](#register) returned.

**Returns** `boolean` — `true` if something was removed.

**Side** `server` — inside `opx77_core` only. Does not yield.

Ids are unique across every point, so removal does not need the name. The search
walks every registry list, which is fine at the scale this is used at and would
not be if a plug-in registered thousands.

### has {#has}

Returns whether anything is currently listening at a point, so a caller can skip
building a payload nobody will read.

```lua
if OPX.Hooks.has("money:beforeAdd") then end
```

- name: `string`

**Returns** `boolean`

**Side** `server` — inside `opx77_core` only. Does not yield.

This is an optimisation, not a guard. The core does not call it before its own
four points: a payload of four fields is cheaper than the branch.

### trigger {#trigger}

Runs every hook registered at a point, in priority order, stopping at the first
veto; returns `true` when nothing refused, including when nothing is listening.

```lua
local allowed = OPX.Hooks.trigger(name, payload)
```

- name: `string`
- payload: [`HookPayload`](types.md#hookpayload)
    - Passed to each hook by reference. The shape is a convention, not a
      constraint — a point you define yourself may carry whatever you like.

**Returns** `boolean` — `false` only when some hook returned an explicit
`false`.

**Side** `server` — inside `opx77_core` only. Does not yield, unless one of the
registered hooks does.

The core calls this at its [four points](#points). It is published so that a
plug-in can define points of its own:

```lua
-- opx77_core/server/heists.lua
if not OPX.Hooks.trigger("heist:beforePayout", { player = player, amount = take }) then
  return OPX.Refuse(source, "heist.vetoed")
end
```

A name nobody has registered at answers `true` immediately, so a point costs
one table lookup when it is unused.

## Priority and ordering {#ordering}

Hooks at one point run from **lowest priority number to highest**. Equal
priorities run in registration order — which, for plug-ins loaded from the
manifest, is the order of the `server_script` lines in `open77.lua`.

```lua
OPX.Hooks.register("money:beforeRemove", auditEverything, -100)  -- first
OPX.Hooks.register("money:beforeRemove", refuseIfFrozen,    0)   -- then
OPX.Hooks.register("money:beforeRemove", expensiveCheck,    50)  -- last
```

The first `false` wins and **the remaining hooks at that name are not run**.
That is worth designing around in both directions:

- Put a cheap, common refusal at a low priority and it saves the expensive ones
  from running at all.
- Put a hook that *must* observe every attempt at a low priority too — a hook
  that only logs will be skipped entirely whenever something earlier refuses.

## The veto {#veto}

A hook refuses by returning **`false`, and only literal `false`**. `nil`, `true`,
`0`, `""`, a string, a table — every one of them means "no opinion" and the
operation proceeds.

```lua
OPX.Hooks.register("money:beforeAdd", function(payload)
  if payload.amount > 1000000 then
    return false          -- refused
  end
  -- falling off the end returns nil, which allows
end)
```

A vetoed money mutator returns `false, "money.vetoed"` to its caller. That code
is deliberately opaque: the caller learns the operation was refused and not
which of possibly several plug-ins refused it, or why. If you want the refusal
attributable, log it in the hook — the core will not do it for you.

A vetoed `paycheck:before` is quieter still: that player is skipped for that
cycle and **nothing at all is said**, to them or to the log.

!!! warning "A hook runs *inside* the operation it guards"

    `OPX.AddMoney` calls your function synchronously, part-way through moving
    money, before the balance is written and before anything has been announced.
    Two consequences you must design around:

    **A hook that yields stalls a money transfer.** No `Wait`, no
    `promise:await`, no `OPX.Storage` call, no `MySQL.…await`. Every one of
    those suspends the thread that is in the middle of the transfer. A paycheck
    cycle runs this for every employed player in one pass, so a hook that waits
    400 ms on a query is a server that visibly stutters every time anyone is
    paid. If your rule needs data that is not already in memory, cache it at
    load and let the cache go stale.

    **A hook must not itself move money.** Calling `OPX.AddMoney` from a
    `money:beforeAdd` hook re-enters the same code path and runs your hook
    again, and then again. There is no re-entry guard and nothing detects it.

## A raising hook is caught {#errors}

Every hook is invoked under `pcall`, because it belongs to somebody else's file
and a broken one must not take a money transfer down with it. A hook that raises
is logged:

```text
hook money:beforeAdd (#3) raised: server/plugins/bounty.lua:88: attempt to index a nil value
```

and is then **treated as having no opinion**. The operation proceeds.

This is the right default — a bug in one plug-in should not silently start
refusing everybody's wages — but it has a consequence that must be stated
plainly: **a hook cannot fail closed.** If your rule is a security boundary, do
not let it depend on code that might raise. Validate first, decide second, and
keep the deciding branch trivial:

```lua
OPX.Hooks.register("money:beforeRemove", function(payload)
  -- read defensively, so the decision itself cannot raise
  local metadata = payload.player and payload.player.PlayerData
    and payload.player.PlayerData.metadata
  local frozen = metadata and metadata.frozen == true
  return not frozen and nil or false
end)
```

A hook that returns before raising has already had its verdict counted; one that
raises before returning has not.

## The hook points {#points}

Four, all server-side, all "before".

| Hook | Runs inside | Payload | On veto |
|---|---|---|---|
| [`money:beforeAdd`](#money-beforeadd) | [`OPX.AddMoney`](server-api.md#addmoney) | `player`, `moneyType`, `amount`, `reason` | returns `false, "money.vetoed"` |
| [`money:beforeRemove`](#money-beforeremove) | [`OPX.RemoveMoney`](server-api.md#removemoney) | `player`, `moneyType`, `amount`, `reason` | returns `false, "money.vetoed"` |
| [`money:beforeSet`](#money-beforeset) | [`OPX.SetMoney`](server-api.md#setmoney) | `player`, `moneyType`, `amount`, `reason` | returns `false, "money.vetoed"` |
| [`paycheck:before`](#paycheck-before) | the paycheck loop | `player`, `amount` | that player is skipped this cycle, silently |

### money:beforeAdd {#money-beforeadd}

Runs before a credit is applied, once the money type and the amount have both
been validated.

```lua
OPX.Hooks.register("money:beforeAdd", function(payload) end)
```

- payload.player: [`Player`](types.md#player)
    - Never offline: `OPX.AddMoney` refuses an offline Player with
      `money.offline` before it reaches the hook.
- payload.moneyType: [`MoneyType`](types.md#moneytype)
    - Already validated, so always a real type on this server.
- payload.amount: `number`
    - The **positive whole delta**, already rounded and already checked finite.
      Not the resulting balance.
- payload.reason: `string|nil`
    - Whatever the caller passed. Free-form; the convention is
      `"system:detail"`.

**Side** `server` — inside `opx77_core` only. Must not yield.

The balance itself has not moved yet: `payload.player.PlayerData.money` still
holds the pre-credit value, which is what makes a ceiling check possible.

### money:beforeRemove {#money-beforeremove}

Runs before a debit is applied, after the money type, the amount **and the
sufficiency check** have all passed.

```lua
OPX.Hooks.register("money:beforeRemove", function(payload) end)
```

- payload.player: [`Player`](types.md#player)
    - Never offline.
- payload.moneyType: [`MoneyType`](types.md#moneytype)
- payload.amount: `number`
    - The positive whole delta to be taken off.
- payload.reason: `string|nil`

**Side** `server` — inside `opx77_core` only. Must not yield.

The order matters: a removal that would take the balance below zero on a type
not listed in `MONEY.ALLOW_NEGATIVE` is refused with `money.insufficient`
**before** the hook runs, so this point never sees a debit that was going to
fail anyway.

### money:beforeSet {#money-beforeset}

Runs before a balance is overwritten outright.

```lua
OPX.Hooks.register("money:beforeSet", function(payload) end)
```

- payload.player: [`Player`](types.md#player)
    - Never offline.
- payload.moneyType: [`MoneyType`](types.md#moneytype)
- payload.amount: `number`
    - The **resulting balance**, not a delta — and it may legitimately be
      `0`, which is the only way an account is emptied. It may also be negative,
      for a type listed in `MONEY.ALLOW_NEGATIVE`.
- payload.reason: `string|nil`

**Side** `server` — inside `opx77_core` only. Must not yield.

!!! warning "`amount` means something different here"

    On the other two money points `amount` is a delta; here it is the balance
    the character will end up with. A single function registered at all three
    points cannot tell them apart from the payload, because the payload does not
    carry the hook name. Register three closures, or pass the name in yourself.

### paycheck:before {#paycheck-before}

Runs once per eligible employed character, each paycheck cycle, before the
salary is credited.

```lua
OPX.Hooks.register("paycheck:before", function(payload) end)
```

- payload.player: [`Player`](types.md#player)
- payload.amount: `number`
    - The grade's `payment`, floored. Always greater than zero — a job paying
      nothing is skipped before the hook.

**Side** `server` — inside `opx77_core` only. Must not yield.

There is no `moneyType` and no `reason` on this payload. The credit that follows
goes into `BANK` — a salary landing as carried cash can be taken off the body of
whoever logged in at the wrong moment — and it goes through
[`OPX.AddMoney`](server-api.md#addmoney), so **`money:beforeAdd` runs too**, with
`reason` set to `"paycheck:<job name>"`. A hook registered at both points will
see every paycheck twice, from two different angles.

Eligibility is decided before the hook: the character must have a positive
`payment`, and either be on duty, or hold a job whose `offDutyPay` is true, or
the server-wide `PAYCHECK_REQUIRES_DUTY` tunable must be off.

A veto here is **silent**. The player is not told, nothing is logged, and the
next cycle tries again.

## A worked plug-in {#example}

Two rules, in one file: nobody may hold more than ten million eddies, and a
character flagged `frozen` cannot spend from the bank.

```lua
-- opx77_core/server/economy_rules.lua
-- listed in opx77_core/open77.lua below server/player.lua
local log = OPX.Log.scope("economy")

local CEILING = 10000000

-- low priority: it is cheap, and refusing here saves the checks below
OPX.Hooks.register("money:beforeAdd", function(payload)
  if payload.moneyType ~= "EDDIES" then return end
  local held = payload.player.PlayerData.money.EDDIES or 0
  if held + payload.amount <= CEILING then return end

  -- logged here, because "money.vetoed" tells the caller nothing
  log.warn(("ceiling refused %d %s for %s (%s)"):format(
    payload.amount, payload.moneyType,
    payload.player.PlayerData.citizenId, tostring(payload.reason)))
  return false
end, -10)

OPX.Hooks.register("money:beforeRemove", function(payload)
  if payload.moneyType ~= "BANK" then return end
  local metadata = payload.player.PlayerData.metadata
  if metadata and metadata.frozen == true then return false end
end)
```

```lua
-- opx77_core/open77.lua, below server/player.lua
server_script "server/economy_rules.lua"
```

Both hooks are pure, in-memory and synchronous. Neither yields, neither moves
money, and each returns `false` only on the exact branch it means to — falling
off the end everywhere else, which is the same as allowing.

## Where to go next {#next}

- [Writing a server plugin](../../guides/writing-a-server-plugin.md) — the file
  these live in, and how to keep it upgradeable.
- [Player](player.md#addmoney) — the money mutators, and what each error code
  means to their caller.
- [Server API](server-api.md#money) — the module-level form.
- [Events](events.md) — `opx77:player:moneyChange`, which is what to listen to
  when the money has already moved.
- [Types](types.md#hookpayload) — the payload shape.
