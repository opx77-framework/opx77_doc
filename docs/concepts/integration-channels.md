---
title: Integration channels — what a third-party resource can actually use
description: The four channels a third-party developer can integrate with OPX//77 through — client exports and two client event channels, a file added to the core's server directory, the onPlayerReady release note, and the shared database — with what each one cannot do.
---

# Integration channels

"Server resources cannot call each other" is true, and it is where most people
stop thinking. It rules out one thing — a **synchronous** server-side API, an
`ESX.GetPlayerFromId(source)` that a third-party server resource calls and gets
an answer from — and rules out nothing else. Four channels remain, all of them
real, and this page is honest about the ceiling on each.

| # | Channel | Side | Direction | Needs |
|---|---|---|---|---|
| 1 | [Client exports and events](#client-resource) | client | both ways | nothing, or `network.events` for the wire channel |
| 2 | [A file in `opx77_core/server/`](#server-plugin) | server | both ways, synchronous | write access to the core |
| 3 | [The `onPlayerReady` note](#release-note) | server | core → every server VM | nothing |
| 4 | [The shared database](#shared-database) | server | both ways, at poll latency | `database.access` |

## 1. A client resource {#client-resource}

This is the channel most resources should use, and the only one that works
without touching OPX//77's own files. The client runtime has `exports` and
`GetInvokingResource`, and its local event bus reaches every resource on the
host — so a satellite can both **ask** the core things and **be told** when
they change.

### Asking: exports {#exports}

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_core", "HasJob", "ncpd", true, 2)
  if not promise then return end
  local result, callError = promise:await()
  if callError or not result.ok then return end
  if result.result then
    -- on duty as NCPD, grade 2 or above
  end
end)
```

The full shape, and the three levels of failure that this snippet only half
handles, are in [The export contract](export-contract.md). Every export the
core publishes is listed in
[the client export reference](../reference/opx77_core/exports/client.md).

!!! warning
    Every answer a client export gives you is a **hint**. It is read from a
    mirror of the character that lives in the player's own process. Draw a UI
    from it, gate a menu on it, skip a prompt with it — and re-derive anything
    that must be unforgeable on the server, which for OPX//77 means inside the
    core. This is the platform's own governing rule, and no configuration turns
    a client-side job check into proof.

### Being told: local events {#local-events}

`OPX.Events.Local` is fired by the core's own client half with `TriggerEvent`,
immediately **after** the mirrored state has been updated — so a handler woken
by one can call `GetPlayerData` and see the change that woke it, rather than the
value it replaced.

```lua
AddEventHandler("opx77:client:onPlayerLoaded", function(playerData)
  -- a character just entered the world
end)

AddEventHandler("opx77:client:moneyChanged", function(moneyType, amount, action, balance)
  -- a balance moved
end)
```

**This needs no permission.** A plain `AddEventHandler` is enough, because the
client's local event bus is host-wide — the platform's own `open77_zones` and
`pursuit` rely on exactly this, and the proof is quoted in
[The export contract](export-contract.md#local-bus).

This is the channel a satellite should prefer.

### Being told: wire events {#wire-events}

`OPX.Events.Client` is the networked channel: the `opx77:client:*` names the
core's **server** half sends. A listener declares `network.events` in its
manifest and registers with `RegisterNetEvent`.

```lua
RegisterNetEvent("opx77:client:setPlayerData", function(playerData) end)
```

Use this if you would rather take the wire yourself — because you want the
payload before the core's mirror has been updated, or because you are not
running the core's client half at all. It is public and supported, and the names
do not change.

!!! warning
    Do not re-emit a wire name with `TriggerEvent`. The dispatcher matches on
    the name and ignores the network flag, so the emission re-enters your own
    `RegisterNetEvent` handler, tick-paced, forever, logging nothing. If you
    republish, republish under a name of your own.

Both vocabularies are listed side by side in
[the core's event reference](../reference/opx77_core/events.md). No name appears
on both.

### What this channel cannot do {#client-limits}

It cannot give a **server** resource anything directly. A server resource that
needs core data has to send a net event to its own client half, have that half
call the export, and have it answer back — which works, costs a round trip, and
is only as trustworthy as the client in the middle. If what you need is
authority rather than presentation, use channel 2.

## 2. A server plug-in: a file in `opx77_core/server/` {#server-plugin}

This is the real server-side contract, it is honest, and it is written down
almost nowhere. **A server-side OPX//77 plug-in is a Lua file added to
`opx77_core/server/` and one line added to `opx77_core/open77.lua`.**

```lua
-- opx77_core/server/heists.lua
local log = OPX.Log.scope("heists")

RegisterCommand("heist.payout", function(source)
  local player = OPX.GetPlayer(source)
  if not player then return end

  local job = player.PlayerData.job
  if not job or job.name ~= "ncpd" or not job.onDuty then
    return OPX.Refuse(source, "heist.notEligible")
  end

  local ok, why = OPX.AddMoney(player, "EDDIES", 500, "heist:payout")
  if not ok then
    log.warn(("payout refused for %s: %s"):format(player.PlayerData.citizenId, why))
    OPX.Refuse(source, why)
  end
end, true)
```

```lua
-- opx77_core/open77.lua, below the files it depends on
server_script "server/heists.lua"
```

That file runs in the core's Lua state. `OPX` is simply in scope: the roster,
the money mutators, the hooks, `OPX.Result`, `OPX.Storage`, the locale
catalogue. The call is **synchronous** and there is no codec between you and it,
so a table stays a table and a function stays a function. Nothing else on this
platform gives you that server-side.

The dependency contract is the manifest's order. Your line goes **below** every
file whose published surface it reads, and `client/exports.lua` stays last. See
[Architecture](architecture.md#load-order) for the two rules that govern it, and
[Writing a server plugin](../guides/writing-a-server-plugin.md) for the whole
procedure.

### What this channel cannot do {#server-plugin-limits}

**It is not distributable as a resource.** Your plug-in ships as a file that the
server owner copies into `opx77_core` and a manifest line they add. There is no
package manager, no dependency resolution and no version negotiation; an
OPX//77 upgrade means re-applying your line to the new `open77.lua`. That is the
cost, it is real, and it is not a defect in OPX//77 — it is what "server
resources cannot call each other" means in practice.

It also means **you are inside the trust boundary**. A file in `server/` can do
anything the core can do, including corrupt the roster or write money that no
hook ever saw. Use `OPX.AddMoney` rather than writing `PlayerData.money`, and
use `OPX.Storage` rather than issuing SQL, so that your plug-in inherits the
guards the core already has.

## 3. The `onPlayerReady` release note {#release-note}

There is exactly one thing a server resource can say to **every other server
VM**, and this is it: the note passed to `Open77.ready.release` becomes the
`detail` argument of `onPlayerReady` in every running resource.

```lua
AddEventHandler("onPlayerReady", function(rawPlayerId, detail)
  local playerId = tonumber(rawPlayerId) -- host events carry strings
  if detail == "opx77_core:character-placed" then
    -- the core has loaded a character and put them where they belong
  end
end)
```

The notes `opx77_core` sends, and what each one means:

| `detail` | The core released the gate because |
|---|---|
| `opx77_core:character-placed` | A character was selected, loaded and placed successfully. The normal join. |
| `opx77_core:character-loaded` | A character was selected and loaded, and placement did **not** succeed. They are in the world; they may not be where their row says. |
| `opx77_core:no-identity` | The connecting slot had no verified `userId`. Nothing was attributed to them. |
| `opx77_core:roster-failed` | The character list could not be read from the database. Usually a database that is down. |
| `opx77_core:selection-timeout` | Nobody chose a character before the core's own deadline. |

### What this channel cannot do {#release-note-limits}

It is **one short string, once, per player, per join** — the host truncates the
note to 64 characters and sanitises it. It carries no payload, it cannot be
replied to, and it cannot be sent at any other moment. It is a signal, not a
bus.

It is also not the only source of `detail`: the platform sends `cleared`,
`incarnated`, `resource_stopped`, `resource_reloaded` and
`liveness_lost:<resource>` too, so match on the prefix you care about rather
than assuming a note. And on a stock OPX//77 install this event **never fires at
all** — see [The entry gate](entry-gate.md#never-opens), which explains why and
what to do about it.

## 4. The shared database {#shared-database}

There is one database for the whole server, one credential, and one boolean
permission. A third-party **server** resource that needs to give a citizen 500
eddies has this channel and, realistically, only this channel.

```lua
CreateThread(function()
  local rows = MySQL.query.await(
    "SELECT citizen_id, name FROM opx77_players WHERE user_id = @user AND deleted_at IS NULL",
    { user = userId })
end)
```

The core's schema is documented in [Persistence](persistence.md#schema), every
table is prefixed `opx77_`, and the column meanings are stable.

!!! warning
    `database.access` is a **whole-database grant**. There is no schema, no
    table prefix and no statement filter behind it. A resource that can read an
    inbox table can equally run `UPDATE opx77_players SET money = …` and bypass
    every guard, hook and audit line the core has. Grant it only to resources
    that genuinely persist state, and never treat the contents of the database
    as unforgeable by another installed resource. The threat model is stated in
    full in [Persistence](persistence.md#threat-model).

### What this channel cannot do {#database-limits}

There is **no synchronous return** and no ordering except the ordering you
build; latency is your polling interval. The core does not currently expose a
validated write surface here — it owns `opx77_`-prefixed tables and is the only
writer it trusts — so a third-party resource writing directly into
`opx77_players` is writing behind the core's back, and the core's next autosave
may overwrite it. If you need an authoritative write, use channel 2.

## Choosing {#choosing}

- Presentation, UI, a HUD, a menu, anything that draws → **channel 1**, client.
- Authority: money, jobs, inventory, anything that must be true → **channel 2**,
  a file in the core.
- "Tell me when a player is in" → **channel 3**, the release note.
- A third-party server resource you cannot put inside the core → **channel 4**,
  the database, with the hazard above understood.

## Where to go next {#next}

- [The export contract](export-contract.md) — the shape of every channel-1 call.
- [Writing a resource](../guides/writing-a-resource.md) — a satellite, start to
  finish.
- [Writing a server plugin](../guides/writing-a-server-plugin.md) — channel 2,
  step by step.
- [Persistence](persistence.md) — the schema behind channel 4.
