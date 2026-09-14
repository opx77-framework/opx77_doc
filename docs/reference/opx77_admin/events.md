---
title: opx77_admin events
description: The six private net events between opx77_admin's two halves, the platform command channel every staff action travels on, and the platform events both halves listen to.
---

# Events

This resource's two halves talk over six net events of its own, and **none of
them carries a mutation**. Every staff action arrives at the server as a command
line through the platform's `open77:command:execute`, never as an event of this
resource's: a net event carries no authorisation on this platform, and one added
here would be a hole.

All six are private. Nothing outside this resource should raise or rely on them,
and their payloads are free to change.

!!! warning "On the client, a peer resource can raise every one of these"

    The client's local event bus is host-wide, and a local `TriggerEvent`
    reaches `RegisterNetEvent` handlers of the same name. Each client handler is
    written so that a forged payload buys nothing: a forged
    [`open`](#open) draws a menu whose every row is a command the host refuses,
    and a forged [`travel`](#travel) does nothing a resource could not do with
    its own travel grant.

## The command channel {#command-channel}

The menu sends each row as the tokens of a command line:

```lua
TriggerServerEvent("open77:command:execute", "opx77.admin.player.heal", "7")
```

That is the path the chat box uses, and the host resolves `command.<first
token>` against the player's ACL before any handler runs. Tokens are cleaned of
control characters and cut to 256 bytes each, and a line of more than 32 tokens
is not sent: the transport refuses both outright.

The answer comes back on `open77:command:result`, `(raw, accepted, message)`,
which every resource that sends commands shares. The client half puts a line
under the menu only when it answers a command the menu sent in the last fifteen
seconds, and ignores the dispatcher's own queue acknowledgement, which arrives
on the same event and is told apart only by its English wording. The chat box
shows every answer regardless.

## Server to client {#server-to-client}

### opx77_admin:open {#open}

The opener command's answer: the operator's session. The client puts the root
screen up, or closes the menu when it is already up — the command toggles.

```lua
RegisterNetEvent("opx77_admin:open", function(session) end)
```

- session: [`AdminSession`](types.md#adminsession)
    - `access` lists the command names the ACL grants this operator — this
      resource's and every [`LINKS`](config.md#links) name. Only the grants
      travel; a refused name is absent.
    - `aclKnown` is `false` when the host has no ACL reader, and nothing is then
      greyed.
    - `weapons` says whether `Open77.weapons` exists on this host.

Followed at once by [`roster`](#roster) and [`locations`](#locations).

### opx77_admin:roster {#roster}

The roster, in chunks of twenty rows, because the host drops an event past 1024
value nodes without a word and a row is about a dozen.

```lua
RegisterNetEvent("opx77_admin:roster", function(chunk) end)
```

- chunk: `{ rows, offset, total, done }`
    - rows: [`AdminRosterRow`](types.md#adminrosterrow)`[]`
    - offset: rows sent before this chunk; `0` starts a new roster
    - done: `true` on the last chunk, which is when the client swaps it in

### opx77_admin:locations {#locations}

The destination list, sorted by name.

```lua
RegisterNetEvent("opx77_admin:locations", function(list) end)
```

- list: `{ rows = { name, label, runtime }[] }` — `runtime` marks a destination
  saved in game.

### opx77_admin:access {#access}

A fresh access map, in answer to a [`refresh`](#refresh) for `access`.

```lua
RegisterNetEvent("opx77_admin:access", function(payload) end)
```

- payload: `{ access, aclKnown }`, as in [`open`](#open). The screen on top is
  redrawn with it.

### opx77_admin:travel {#travel}

A travel switch, sent only by an ACL-gated server command.

```lua
RegisterNetEvent("opx77_admin:travel", function(action, value) end)
```

| `action` | `value` | The client |
|---|---|---|
| `noclip` | `boolean` | `Open77.travel.setNoclip` |
| `speed` | `number` | `Open77.travel.setNoclipSpeed`, only for `0.1`–`500` |
| `mapPick` | `boolean` | `Open77.travel.setMapPick`; a picked point is sent back only while armed |
| `copy` | `string` | `Open77.clipboard.setText`, only for a line of at most 160 bytes starting `{ NAME = ` |

A travel native missing from the client build is one log line and a toast:

```text
Open77.travel.setNoclip is not in this client build
```

## Client to server {#client-to-server}

### opx77_admin:refresh {#refresh}

The menu asks for a list again: the roster when it opens the players or a player
screen, the destinations when it opens a destination screen, and the access map
when it leaves the root screen.

```lua
TriggerServerEvent("opx77_admin:refresh", topic)
```

- topic: `"roster" | "locations" | "access"` — anything else is ignored.

The server cools it at [`RATE.REFRESH_MS`](config.md#rate) per topic, then
re-checks `command.opx77.admin` with `Open77.acl.isAllowed`, because anybody
can send a net event. It **fails closed**: with no ACL reader on the host every
refresh is dropped, and running the opener again refreshes everything.

## What it listens to {#listens}

| Event | Side | For |
|---|---|---|
| `open77:command:result` | client | the answer to a command the menu sent |
| `open77:map:picked` | client, local | a point double-clicked on the world map while map travel is armed, sent back as `opx77.admin.self.maptravel <x> <y> <z>` |
| `opx77_admin:row` | client, local | a menu row used, raised by `opx77_menu`; only a payload whose `owner` is this resource is read |
| `opx77_admin:form` | client, local | a form answered, raised by `opx77_input` |
| `onClientResourceStop` | client | this resource stopping: the menu and form are closed, and noclip and map travel turned off |
| `chat:ready` | server, net | the chat box asks for suggestions; only commands the ACL grants that player are sent, on `chat:addSuggestions`, cooled at 2000 ms |
| `open77:weapons:completed` | server, local | a weapon relay answered, `(playerId, requestId, operation, accepted, reason, result)` |
| `onPlayerDisconnected` | server | a departed player's rate history, travel switches and refresh floors are forgotten, so a recycled id inherits none |
| `onResourceStop` | server | this resource stopping: every travel switch it turned on is sent off |

## What it sends that is not its own {#sends}

| Event | To | Carries |
|---|---|---|
| `open77:command:execute` | server | every staff action, as a command line — see [the command channel](#command-channel) |
| `open77:command:result` | the operator | every command's answer |
| `chat:addSuggestions` | one player | the staff commands that player may run |
| `chat:addMessage` | every player | an announcement, when [`ANNOUNCE.CHAT`](config.md#announce) is on |

Toasts go through `Open77.notifications.send` on the server, which
[`opx77_notify`](../opx77_notify/index.md) draws.

## See also {#see-also}

- [Types](types.md) — the payload shapes.
- [The client export contract](../../concepts/export-contract.md#local-bus) —
  why the client bus is not a trust boundary.
