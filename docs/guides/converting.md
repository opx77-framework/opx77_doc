---
title: Converting from ESX or Qbox
description: A three-column mapping from ESX Legacy and Qbox (qbx_core) onto OPX//77, plus the four idioms that have no OPX//77 equivalent at all and what to write instead of each.
---

# Converting from ESX or Qbox

Most of what you know transfers. Characters, money, jobs with grades, gangs,
metadata and a per-character save are all here, and they are spelled almost the
way you expect. What does not transfer is the *shape of the call*, because
OPEN//77 is not FiveM: the server runtime installs no `exports`, no
`GetInvokingResource` and no cross-resource event bus, and the client runtime
puts every export through a serialising codec and answers with a promise.

!!! info "Read this first"

    [The export contract](../concepts/export-contract.md) explains the call shape
    that every row in the table below assumes, and
    [Architecture](../concepts/architecture.md) explains why the server side of
    OPX//77 is one resource rather than a core plus plug-ins.

The left two columns are what you are migrating from; the right one is what to
write instead. Every call in the OPX//77 column is either a **client export**,
reachable from any resource, or an **in-core server function**, reachable only
from a file inside `opx77_core` — the `Side` column says which, and that
distinction is the single biggest change.

## The mapping table {#mapping}

### Getting the framework {#getting-the-framework}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 | Side |
|---|---|---|---|
| `ESX = exports["es_extended"]:getSharedObject()`, or `shared_script '@es_extended/imports.lua'` | flat exports on `exports.qbx_core`; `shared_script '@qbx_core/modules/lib.lua'` for the utility belt | nothing to get. Call `Open77.exports.call("opx77_core", name, ...)` | client |
| `ESX` on the server, from any resource | `exports.qbx_core:GetPlayer(source)` from any resource | `OPX`, a plain global — **only inside `opx77_core`'s own VM** | in-core server |
| `ESX.GetSharedObject` (removed) | — | never existed | — |

There is no object to fetch and no shim to include. On the client you name the
resource on every call; on the server there is no call to make from outside, and
[Writing a server plugin](writing-a-server-plugin.md) explains what to do
instead.

### The player {#the-player}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 | Side |
|---|---|---|---|
| `ESX.GetPlayerFromId(source)` → `xPlayer` | `exports.qbx_core:GetPlayer(source)` → `Player` | `OPX.GetPlayer(source)` → `Player` | in-core server |
| `ESX.GetPlayerFromIdentifier(id)` | `exports.qbx_core:GetPlayerByCitizenId(cid)` | `OPX.GetPlayerByCitizenId(citizenId)` | in-core server |
| — | `exports.qbx_core:GetPlayerByUserId(id)` | `OPX.GetPlayerByUserId(userId)` | in-core server |
| `ESX.GetExtendedPlayers()` | `exports.qbx_core:GetQBPlayers()` | `OPX.GetPlayers()` → `Player[]` | in-core server |
| `ESX.GetNumPlayers()` | — | `OPX.GetPlayerCount()` | in-core server |
| `ESX.PlayerData` (mirror installed by `imports.lua`) | `exports.qbx_core:GetPlayerData()` | `Open77.exports.call("opx77_core", "GetPlayerData")` → `{ ok, data }` | client |
| `ESX.IsPlayerLoaded()` | `LocalPlayer.state.isLoggedIn` | `Open77.exports.call("opx77_core", "IsLoggedIn")` → `{ ok, loggedIn }` | client |
| `xPlayer.getIdentifier()` | `player.PlayerData.citizenid` | `player.PlayerData.citizenId` | both |
| `xPlayer.getName()` | `player.PlayerData.charinfo` | `player.PlayerData.charInfo` | both |

`xPlayer` carries about seventy methods that write through to the player;
Qbox's `Player.Functions` carries twenty-two, eighteen of them deprecated in
favour of flat exports, so a reader cannot tell which form is current. OPX//77
has **both forms and neither is deprecated**, because one is implemented in terms
of the other:

```lua
player.Functions.AddMoney("EDDIES", 500, "gig payout")   -- bound to this player
OPX.AddMoney(citizenId, "EDDIES", 500, "gig payout")      -- the implementation
```

`Functions` binds the player into the module-level form, so a rule added to one
is a rule both obey — including a [hook](writing-a-server-plugin.md#hooks). The
fourteen methods are `UpdatePlayerData`, `SetPlayerData`, `SetMetaData`,
`GetMetaData`, `SetCharInfo`, `AddMoney`, `RemoveMoney`, `SetMoney`, `GetMoney`,
`SetJob`, `SetGang`, `SetJobDuty`, `Save` and `Logout`.

Two differences from both frameworks:

- **Every module-level mutator accepts `Player | Source | CitizenId`** in its
  first position, so one call site works for an online and an offline character.
  Qbox reached the same design and it is the best decision in that codebase;
  ESX has no equivalent and grew a separate `StaticPlayer` proxy instead.
- **Assigning into `PlayerData` directly is not free.** The autosave's dirty
  counter moves only inside `Functions.UpdatePlayerData`, so a field written by
  hand is a change the autosave cannot see. Go through `SetPlayerData`,
  `SetMetaData` or `SetCharInfo`.

### Money {#money}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 | Side |
|---|---|---|---|
| `xPlayer.addAccountMoney('bank', n)` | `exports.qbx_core:AddMoney(src, 'bank', n, reason)` | `OPX.AddMoney(identifier, "EDDIES", n, reason)` | in-core server |
| `xPlayer.removeAccountMoney('bank', n)` | `exports.qbx_core:RemoveMoney(src, 'bank', n, reason)` | `OPX.RemoveMoney(identifier, "EDDIES", n, reason)` | in-core server |
| `xPlayer.setAccountMoney('bank', n)` | `exports.qbx_core:SetMoney(src, 'bank', n, reason)` | `OPX.SetMoney(identifier, "EDDIES", n, reason)` | in-core server |
| `xPlayer.getAccount('bank').money` | `exports.qbx_core:GetMoney(src, 'bank')` | `OPX.GetMoney(identifier, "EDDIES")` | in-core server |
| read the balance on the client | `GetPlayerData().money` | `GetPlayerData()` export → `result.data.money` | client |

Money types are **upper-case** in OPX//77, and the two shipped ones are
`EDDIES` (carried, losable) and `BANK` — not `cash`/`money`/`bank`. They are
config keys as well as field names, so a type that is not in
`MONEY.TYPES` is refused with `money.badType` rather than silently creating an
account, and renaming one orphans every balance already stored under the old
name.

Three behavioural differences worth knowing before you port a shop:

- `RemoveMoney` **refuses** rather than truncating when the balance is too low,
  unless the type is listed in `MONEY.ALLOW_NEGATIVE`, which ships as
  `{ BANK = true }`. ESX's
  `removeAccountMoney` goes negative silently.
- Every mutator returns `boolean, string?` where the string is a locale key
  naming *which* refusal it was — `money.insufficient`, `money.badType`,
  `money.badAmount`, `money.offline`, `money.vetoed`, `error.notLoggedIn`. Check
  both values; `if not ok then` alone throws away the reason.
- `money.vetoed` means a **hook** said no. There is no ESX or Qbox equivalent to
  those; see [Hooks](writing-a-server-plugin.md#hooks).

### Jobs, gangs and grades {#jobs-and-gangs}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 | Side |
|---|---|---|---|
| `xPlayer.setJob(name, grade)` | `exports.qbx_core:SetJob(src, name, grade)` | `OPX.SetJob(identifier, name, grade)` | in-core server |
| — | `exports.qbx_core:SetJobDuty(src, bool)` | `OPX.SetJobDuty(identifier, onDuty)` | in-core server |
| — | `exports.qbx_core:AddPlayerToJob(...)` | `OPX.AddPlayerToJob(identifier, name, grade)` | in-core server |
| — | `exports.qbx_core:RemovePlayerFromJob(...)` | `OPX.RemovePlayerFromJob(identifier, name)` | in-core server |
| — | `exports.qbx_core:SetPlayerPrimaryJob(...)` | `OPX.SetPlayerPrimaryJob(identifier, name)` | in-core server |
| `xPlayer.setGroup(name)` (not a gang) | `exports.qbx_core:SetGang(src, name, grade)` | `OPX.SetGang(identifier, name, grade)` | in-core server |
| — | `exports.qbx_core:GetGroupMembers(type, name)` | `OPX.GetGroupMembers("job"\|"gang", name)` | in-core server |
| `ESX.GetJobs()` | `exports.qbx_core:GetJobs()` | `Open77.exports.call("opx77_core", "GetJobs")` | client |
| — | `exports.qbx_core:GetGangs()` | `Open77.exports.call("opx77_core", "GetGangs")` | client |
| `ESX.PlayerData.job.name == 'police'` | `exports.qbx_core:HasGroup('police')` | `Open77.exports.call("opx77_core", "HasJob", "ncpd", onDutyOnly, minGrade)` | client |
| — | `exports.qbx_core:HasGroup({gang = 'ballas'})` | `Open77.exports.call("opx77_core", "HasGang", name, minGrade)` | client |

Jobs and gangs are **Lua data files**, `opx77_core/data/jobs.lua` and
`data/gangs.lua`, not SQL rows: they are definitions, not settings, and renaming
one renames something players already hold. There is no `CreateJob` at runtime
and no `commitToFile` surprise.

`HasJob` takes a duty flag and a minimum grade because a grade comparison is the
whole point of asking; `HasGang` takes only a minimum grade, because a gang has
no shifts. Both are exports rather than a field read for that reason.

!!! warning "A client-side job check is a hint, never proof"

    `HasJob` reads the client's mirror of `PlayerData`. It is the right call for
    deciding what to *draw*. It is never the right call for deciding what a
    player is *allowed to do* — the client owns that code and can answer
    anything. `opx77_elevators` says so in four places and ships that way
    deliberately. Anything unforgeable belongs in
    [a server plugin](writing-a-server-plugin.md).

### Metadata {#metadata}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 | Side |
|---|---|---|---|
| `xPlayer.setMeta(key, value)` | `exports.qbx_core:SetMetadata(src, key, value)` | `OPX.SetMetadata(identifier, key, value)` | in-core server |
| `xPlayer.getMeta(key)` | `exports.qbx_core:GetMetadata(src, key)` | `OPX.GetMetadata(identifier, key)` | in-core server |
| `xPlayer.set(k, v)` / `.get(k)` — session-only, never persisted, and undocumented | — | no equivalent; there is one metadata table and it is persisted | — |

ESX's two parallel free-form stores are the classic trap: `variables` dies with
the session and `metadata` persists, and nothing in the API says which is which.
OPX//77 has one.

### Callbacks {#callbacks}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 |
|---|---|---|
| `ESX.RegisterServerCallback(name, cb)` | `lib.callback.register(name, cb)` | **none, and there cannot be one across resources** |
| `ESX.TriggerServerCallback(name, cb, ...)` | `lib.callback(name, delay, cb, ...)` | hand-rolled request/reply net events inside your own resource |
| `ESX.AwaitServerCallback(name, ...)` | `lib.callback.await(name, delay, ...)` | — |

This is the most disruptive row in the table and it gets [its own
section](#no-server-callbacks) below.

### Events {#events}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 | How to listen |
|---|---|---|---|
| `esx:playerLoaded` (client) | `QBCore:Client:OnPlayerLoaded` | `opx77:client:onPlayerLoaded` | `AddEventHandler`, no permission |
| `esx:onPlayerLogout` | `QBCore:Client:OnPlayerUnload` | `opx77:client:onPlayerUnloaded` | `AddEventHandler`, no permission |
| `esx:setPlayerData` | `qbx_core:client:setPlayerData` | `opx77:client:playerDataChanged` | `AddEventHandler`, no permission |
| `esx:setAccountMoney` | `qbx_core:client:onMoneyChange` | `opx77:client:moneyChanged` | `AddEventHandler`, no permission |
| `esx:setJob` | `QBCore:Client:OnJobUpdate` | `opx77:client:jobChanged` | `AddEventHandler`, no permission |
| — | `QBCore:Client:OnGangUpdate` | `opx77:client:gangChanged` | `AddEventHandler`, no permission |
| `esx:playerLoaded` (server, `TriggerEvent`) | `QBCore:Server:PlayerLoaded` | no cross-resource server event exists | — |

OPX//77 keeps **two disjoint vocabularies**, and this catches everyone. The names
above are the *local* ones: the core's client half raises them with
`TriggerEvent` after its mirror has already been updated, so a handler can read
`GetPlayerData()` and see the change that woke it. The client local event bus is
host-wide on this platform — the platform's own `open77_zones` fires a
caller-supplied name and `pursuit`, a different resource, receives it with a bare
`AddEventHandler` — so `AddEventHandler` reaches you and costs no permission.

There is a second, networked vocabulary (`opx77:client:playerLoaded`,
`opx77:client:setPlayerData`, `opx77:client:onMoneyChange`, …) that the server
sends over the wire. Listening on those needs `network.events` in your manifest
and `RegisterNetEvent`. Prefer the local names.

!!! warning "Never re-emit a wire name from inside its own handler"

    On this platform `TriggerEvent` also reaches every `RegisterNetEvent`
    handler of the same name — the dispatcher matches on the name and never
    looks at the network flag. A local re-emission that reused its own wire name
    re-enters the handler that fired it. It is tick-paced rather than recursive,
    so it is a **silent permanent busy loop**: nothing crashes, nothing is
    logged, and the resource simply stops responding. Keeping the two
    vocabularies disjoint is what prevents it, and it is why the two tables in
    `OPX.Events` share no name.

### Notifications {#notifications}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 | Side |
|---|---|---|---|
| `ESX.ShowNotification(msg)` | `exports.qbx_core:Notify(msg, type)` | `Open77.exports.call("opx77_notify", "show", { … })` | client |
| `xPlayer.showNotification(msg)` | `exports.qbx_core:Notify(src, msg, type)` | `Open77.notifications.send(playerId, { … })` | any server resource |
| — | — | `OPX.Notify(source, message, kind, durationMs)` | in-core server |

The **transport** is a platform service, not an OPX//77 one. `Open77.notifications`
is a host binding available to any server resource, which makes it one of the very
few things a third-party server resource can do without the core's help;
`OPX.Notify` is a thin wrapper over it that adds the server name, the configured
position and a repeat filter. `OPX.Refuse(source, code)` is the same thing for a
locale key.

The **renderer** is [`opx77_notify`](../reference/opx77_notify/index.md), and the
two meet without being introduced. `Open77.notifications.send` does nothing but
fire `open77:notifications:show` at the target; `opx77_notify` registers that
name. So a server resource you port from ESX or Qbox draws in OPX//77's toasts
while calling nothing this framework owns — and a client resource written
against the platform's own `open77_notifications` export names works too, since
`opx77_notify` publishes the same ones.

!!! warning "Do not run both renderers"
    `opx77_notify` and the platform's `open77_notifications` listen on the same
    four net events and publish the same export names, so running both draws
    every toast twice, on two surfaces, in two corners. `opx77_notify` warns
    about this at start-up. Drop one from `resources.load`.

### Menus {#menus}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 | Side |
|---|---|---|---|
| `ESX.UI.Menu.Open('default', ...)` after `ESX.UI.Menu.RegisterType` | `lib.registerContext` / `lib.showContext` (ox_lib) | `Open77.exports.call("opx77_menu", "open", spec)` | client |
| the `submit` / `cancel` callbacks | `onSelect` closures on each option | an **event name** on the spec, echoed back with the item's `data` | client |
| `ESX.UI.Menu.CloseAll()` | `lib.hideContext()` | `Open77.exports.call("opx77_menu", "close")` — your own menu only | client |

ESX hands the menu two Lua functions and Qbox hands each option a closure.
Neither works here: the export codec cannot carry a function, so `opx77_menu`
answers on an **event** you name in the spec, and echoes each item's opaque
`data` table back in the payload. That is the same reason `opx77_status` reports
an expired effect by raising an event rather than calling you back, and it is the
third of the four idioms with no equivalent, [below](#no-function-references).

### Inventory and items {#inventory}

| ESX Legacy | Qbox (`qbx_core`) | OPX//77 |
|---|---|---|
| `xPlayer.addInventoryItem` and 11 more | `ox_inventory` | none |
| `ESX.RegisterUsableItem` | `exports.qbx_core:CreateUseableItem` | none |

OPX//77 ships no inventory and no item registry, deliberately. See
[the FAQ](faq.md#why-is-there-no-inventory).

## Four things with no equivalent {#no-equivalent}

### 1. A server export {#no-server-exports}

```lua
-- ESX, from any third-party server resource:
local xPlayer = exports["es_extended"]:getSharedObject().GetPlayerFromId(source)

-- Qbox, from any third-party server resource:
local player = exports.qbx_core:GetPlayer(source)

-- OPX//77:
-- there is no line to write here, and there is no version of this that works.
```

The OPEN//77 **server** runtime installs no `exports`, no
`GetInvokingResource` and no cross-resource event bus. `TriggerEvent` on the
server walks only its own VM. This is not an OPX//77 decision and no amount of
framework design routes around it: the platform documents it, and it is the
reason the platform's own gamemode kernel puts a gamemode's entire server side in
one resource. The platform's own `pursuit` resource keeps a **byte-identical
copy** of another resource's roster file for exactly this reason, and says so in
its manifest.

**What to write instead**, in order of preference:

1. **Put the code in `opx77_core/server/`.** A plug-in on this platform is a
   file you add to the core plus a line you add to its manifest. `OPX` is a
   plain global in that one VM and everything is reachable.
   [Writing a server plugin](writing-a-server-plugin.md) is the whole procedure,
   including how to survive a core update.
2. **Go through your own client half.** Your server resource sends a net event
   to its own client, the client calls the `opx77_core` export, and the client
   sends the answer back. This is legitimate and several shipped resources do
   it — but the answer came from the client, so it is a *hint*, not proof. Never
   let money or access change on the strength of it.
3. **Read the database directly.** Every resource holding `database.access`
   talks to the same database, and the `opx77_` tables are documented. Read-only
   is safe; writing behind the core's back is not, because the core holds the
   authoritative copy in memory and will overwrite you on its next autosave.

[Integration channels](../concepts/integration-channels.md) sets out all three
with their exact costs.

### 2. A server callback {#no-server-callbacks}

ESX's `RegisterServerCallback` and Qbox's `lib.callback` are both built on the
same trick: a pair of templated net events, a random key, a table of pending
closures, and a promise on the caller's side. Both live in a *library that is
loaded into your resource*, and both reach the core through a cross-resource
call at the far end.

Neither half is available here. There is no library to load into your VM, and the
far end cannot be another server resource. So:

- **Client asks its own server half a question** — write it yourself. Two net
  events, a request carrying a correlation id and a reply carrying the same id.
  It is a dozen lines, it is entirely within one resource, and it is what the
  shipped resources do.
- **Client asks another resource's client a question** — that is an export.
  `Open77.exports.call` already returns a promise, so this case is solved.
- **Server asks another server resource a question** — impossible. Not "hard",
  not "unsupported": there is no channel. Move the code into `opx77_core` or
  restructure so the question is not asked.

### 3. A function reference through an event or export {#no-function-references}

```lua
-- ESX does this constantly and it works on FiveM:
TriggerEvent("esx:playerLogout", playerId, function(result) … end)
ESX.RegisterServerCallback("shop:buy", function(source, cb, item) cb(true) end)
esx_status.registerStatus("hunger", 1000000, ..., function(status) … end)
```

Every one of those hands a **live Lua function** across a boundary. On OPEN//77
the export path puts arguments and results through a serialising codec, so a
function cannot cross a resource boundary at all — it is not that it is
discouraged, it is that there is no representation for it.

**What to write instead:** a service that has something to say later raises an
**event**, and the caller listens for it. That is why `opx77_menu` tells you
which row was chosen by raising the event named on the spec, and why
`opx77_status` reports an expired effect the same way. Pass an opaque `data`
table on the thing you registered; the service echoes it back untouched, and that
is your closure's captured state, written down.

### 4. A shared include from another resource {#no-shared-include}

```lua
-- ESX:  the blessed path, and a textual include, not a call
shared_scripts { '@es_extended/imports.lua', '@es_extended/locale.lua' }

-- Qbox: the same trick for the utility belt
shared_script '@qbx_core/modules/lib.lua'
```

`@resource/file.lua` compiles another resource's file inside *your* VM. Nothing in
the OPEN//77 manifest grammar does this, and the platform's own resources solve
the problem by copying the file: `pursuit/shared/roster.lua` is a byte-identical
copy of `open77_vehiclepicker/shared/roster.lua`, and its manifest says why.

**What to write instead:** copy the helpers you need into your own
`shared/` directory and pin the version you copied in a comment. OPX//77 ships a
small copy-in snippet for the call plumbing —
[`opx77_lib`](../reference/opx77_lib.md) — on exactly that understanding: it is a
file you take a copy of, not a dependency you declare.

## A worked conversion {#worked-example}

The ESX shape, which will not run here:

```lua
-- server.lua of a third-party resource
ESX = exports["es_extended"]:getSharedObject()

ESX.RegisterServerCallback("shop:buy", function(source, cb, price)
  local xPlayer = ESX.GetPlayerFromId(source)
  if xPlayer.getAccount("money").money < price then return cb(false) end
  xPlayer.removeAccountMoney("money", price)
  cb(true)
end)
```

The OPX//77 shape. The purchase is a **hook-guarded core function**, so it lives
in a file you add to `opx77_core/server/`, and your own resource keeps only the
part that is genuinely yours:

```lua
-- opx77_core/server/plugins/shop.lua, listed in opx77_core/open77.lua
RegisterNetEvent("myshop:buy", function(sku)
  local src = tonumber(source)
  if not src or src <= 0 then return end

  local price = Catalogue[sku]
  if not price then return OPX.Refuse(src, "error.badRequest") end

  -- both return values: the second names which refusal it was
  local ok, why = OPX.RemoveMoney(src, "EDDIES", price, "myshop:" .. sku)
  if not ok then return OPX.Refuse(src, why) end

  TriggerClientEvent("myshop:bought", src, sku)
end)
```

Note what changed and what did not. The validation moved server-side and stayed
there. The callback became a pair of net events. The balance check disappeared
entirely, because `RemoveMoney` refuses rather than going negative and names the
refusal — which is strictly better than the ESX original, whose
`removeAccountMoney` cannot fail.

## Where to go next {#next}

- [Writing a resource](writing-a-resource.md) — the client half, end to end.
- [Writing a server plugin](writing-a-server-plugin.md) — the server half, and
  what it costs.
- [Integration channels](../concepts/integration-channels.md) — the three
  server-side channels, ranked.
- [FAQ](faq.md) — the shorter versions of the questions above.
