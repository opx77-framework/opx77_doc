---
title: Public server events
description: The opx:on:* events opx_infinity raises on the server for other resources — character, money, jobs, inventory, downed, vehicles, dealership and hauling — with their arguments, plus a warning about the private opx:in:* events.
---

# Public server events

On the server, `TriggerEvent` reaches **every** running resource. `opx_infinity`
uses this to announce what happens, on `opx:on:<module>:<verb>` names raised
through [`OPX.Publish`](../reference/core.md#opx-publish). Any server resource
can listen; no allowlist applies.

```lua
-- my_logs/server/main.lua
AddEventHandler('opx:on:character:money', function(playerId, payload)
	print(('%s %s %d %s (now %s)'):format(payload.citizenId, payload.action,
		payload.amount, payload.moneyType, tostring(payload.balance)))
end)
```

Every event has two arguments: **`playerId`** — the player the event is about,
or `nil` when that character is not online — and **`payload`**, a plain table
built for the event (never a live record, and never the free-form `metadata`).
The events are announcements: they fire after the change, and nothing a listener
does can undo or veto it.

## Characters and money {#character}

| Event | Payload | When |
|---|---|---|
| `opx:on:character:loaded` | the public view: `{ source, citizenId, userId, firstName, lastName, money, job, gang, jobs, gangs }` | A character was loaded for a player. |
| `opx:on:character:unloaded` | `{ citizenId, userId }` | A character left the world (logout, switch, disconnect). |
| `opx:on:character:money` | `{ citizenId, moneyType, amount, action, reason, balance, offline }` | Any balance change. `action` is `add`, `remove` or `set`. `offline = true` (and `playerId` nil) for [`AddMoneyOffline`](server-exports.md#money). |
| `opx:on:character:job` | `{ citizenId, job, removed, offline }` | The primary job was set, its duty changed, or a job membership was removed (`removed` names it). `job` is the primary job after the change. `offline = true` when the change was made to a character nobody is playing. |
| `opx:on:character:gang` | `{ citizenId, gang, removed, offline }` | The same for gangs. |

## Inventory {#inventory}

| Event | Payload | When |
|---|---|---|
| `opx:on:inventory:changed` | `{ kind, owner, container, citizenId }` | A container's contents were written. `citizenId` (and `playerId`) only for a player's bag. |
| `opx:on:inventory:used` | `{ citizenId, name, slot, consumed, metadata }` | A player used an item. |

## Down and up {#downed}

| Event | Payload | When |
|---|---|---|
| `opx:on:downed:changed` | down: `{ citizenId, down = true, waiting, restored }` · up: `{ citizenId, down = false, reason, kept }` | A player went down or got up. `restored` = the down state came back after a reconnect. `kept` = the character left the world still down, so the state returns with them. |

## Vehicles {#vehicles}

| Event | Payload | When |
|---|---|---|
| `opx:on:vehicles:spawned` | `{ citizenId, plate, record, vehicleId, vehicleKey, recalled }` | An owned vehicle was brought out. `vehicleKey` is the engine id as text (safe in JSON). `recalled` = it was already out and was moved. |
| `opx:on:vehicles:stored` | `{ citizenId, plate, garage }`, or `{ citizenId, plate, removed }` | It was put away, or the host removed it from the world (`removed` says why). |
| `opx:on:dealership:sold` | `{ kind = 'counter', citizenId, plate, entry, record, dealer, garage, price, currency }` or `{ kind = 'offer', ..., seller, sellerCitizenId, company, commission, banked }` | A vehicle was bought at a dealer, or sold player-to-player (`offer`). |
| `opx:on:hauling:sold` | `{ citizenId, site, dropoff, count, pay, each, currency }` | Crates were sold to a drop-off NPC. |

## The private opx:in:* events {#private}

!!! warning "Server `opx:in:*` events are visible to every server resource"

    Because server `TriggerEvent` is host-wide, the internal `opx:in:*` events
    (for example `opx:in:character:loaded`) also reach your resource, and your
    resource could raise them. They are **not** part of the public surface:
    their names and arguments change without notice. Listen to the `opx:on:*`
    events above instead, and never raise an `opx:` event yourself.

## On the client {#client}

The client-side `opx:on:*` events (menu actions, inventory opened…) stay inside
`opx_infinity`: a client `TriggerEvent` does not leave its resource. Answers to
your own client calls reach you through the
[reply export](client-exports.md#replies).
