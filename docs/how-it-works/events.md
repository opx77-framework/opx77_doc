---
title: Events and channels
description: The three event prefixes opx_infinity uses (opx:net, opx:on, opx:in), who can hear each one, and how to build a name with OPX.Event.
---

# Events and channels

Every event name in `opx_infinity` starts with one of three prefixes. The prefix
says who may raise it and who can hear it. Build names with
[`OPX.Event(channel, module, verb)`](../reference/core.md#opx-event) instead of
typing them, so a typo fails at load.

## The three prefixes {#prefixes}

| Prefix | `OPX.Channel` | Travels | Use it for |
|---|---|---|---|
| `opx:net:<module>:<verb>` | `NET` | across the network, client ↔ server | requests from a client, answers and pushes from the server |
| `opx:on:<module>:<verb>` | `LOCAL` | inside one runtime, public | announcing something other modules may react to |
| `opx:in:<module>:<verb>` | `INTERNAL` | inside one runtime, private | one module's own halves, or core to modules |

```lua
local SAY = OPX.Event(OPX.Channel.NET, 'chat', 'say')   -- 'opx:net:chat:say'
```

Each module lists its names in its `module.lua` as `M.Event`. Every module page
has an **Events** table with the `opx:net:` and `opx:on:` names.

### Why three prefixes {#why}

The host matches handlers on the event name only. A local `TriggerEvent` on a
name that also has a `RegisterNetEvent` handler would run the network handler
too. Keeping network names and local names apart makes that impossible.

## Who can hear what {#reach}

| Raised with | On the server | On the client |
|---|---|---|
| `TriggerEvent` (`opx:on:`, `opx:in:`) | every running **server resource** that handles the name | **this resource only** |
| `TriggerClientEvent` (`opx:net:`) | — | the `opx_infinity` client of that player |
| `TriggerServerEvent` (`opx:net:`) | the server handler, with `source` set by the platform | — |

Two consequences:

- A separate **client** resource cannot hear `opx_infinity`'s `opx:on:` events.
  On the client, `TriggerEvent` stays inside one resource.
- A separate **server** resource hears server-side events. The public ones are
  raised with [`OPX.Publish`](../reference/core.md#opx-publish) and listed on
  [Public server events](../creators/server-events.md).

!!! warning "Server `opx:in:*` events are visible to every server resource"

    Server `TriggerEvent` is host-wide, so the private `opx:in:*` events also
    reach other resources, and another resource can raise them. Treat a server
    `opx:on:` or `opx:in:` handler as callable by any resource on the server, and
    never put a secret in an `opx:in:` payload. Outside code should use only the
    `opx:on:*` names.

On the server, raise a public event with `OPX.Publish(name, playerId, payload)`,
never a bare `TriggerEvent`: it checks the `opx:on:` prefix and never raises.

## Network events are requests {#net}

A handler registered with `RegisterNetEvent` gets `source` from the
authenticated connection. Everything else in the payload comes from a machine
the player controls. Re-check it on the server before acting — see
[Server authority](server-authority.md).

Network events carry at most 32 arguments in a 48 KiB envelope (platform limit).

## Host events {#host}

Names the platform owns are listed once in `OPX.Host`
(`core/shared/channels.lua`). The two runtimes use different names for the
resource start and stop events.

| `OPX.Host` key | Name |
|---|---|
| `PLAYER_CONNECTED` | `onPlayerConnected` |
| `PLAYER_DISCONNECTED` | `onPlayerDisconnected` |
| `PLAYER_READY` | `onPlayerReady` |
| `CLIENT_RESOURCE_START` / `CLIENT_RESOURCE_STOP` | `onClientResourceStart` / `onClientResourceStop` (client) |
| `RESOURCE_START` / `RESOURCE_STOP` | `onResourceStart` / `onResourceStop` (server) |
| `WORLD_READY` | `open77:worldReady` |
| `GAMEPLAY_READY` | `open77:session:gameplayReady` |
| `VEHICLE_REMOVED` | `onVehicleRemoved` |
| `TUNABLE_CHANGED` | `onTunableChanged` |
| `KEYBINDS_CHANGED` | `open77:keybinds:changed` (client: a key mapping was registered, rebound, reset or removed) |

## Hooks: events that can say no {#hooks}

When a module must let another module **veto** something (for example money
being added), it uses [`OPX.Hooks`](../reference/lib.md#opx-hooks-register)
instead of an event. A hook runs in the same VM, in priority order, and any
handler may refuse. The hooks the framework triggers are listed on the
[character module](../modules/character.md) page.

## Page channels {#page}

The WebUI page talks to Lua on a separate set of names, such as `menu:choose`.
They are not events; see [The WebUI page](webui.md#channels).
