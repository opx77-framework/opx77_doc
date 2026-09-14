---
title: opx77_admin events
description: The nine private net events between opx77_admin's two halves, the platform command channel every staff action travels on, and the platform events both halves listen to.
---

# Events

This resource's two halves talk over nine net events of its own, and **none of
them carries a mutation**. Every staff action arrives at the server as a command
line through the platform's `open77:command:execute`, never as an event of this
resource's: a net event carries no authorisation on this platform, and one added
here would be a hole.

All nine are private. Nothing outside this resource should raise or rely on them,
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

This resource's own commands answer on [`opx77_admin:answer`](#answer), from
its server half to its client half — a toast for an action, a chat line for a
report. Not on `open77:command:result`: `opx77_chat` prints none of that event's
accepted answers, so a staff member would hear nothing.

The client half still listens to `open77:command:result`, `(raw, accepted,
message)`, which every resource that sends commands shares, for what the
dispatcher and the [`LINKS`](config.md#links) resources say about a row the menu
sent. It drops the dispatcher's queue acknowledgement, which arrives on the same
event and is told apart only by its English wording — any accepted message
containing `queued by `, the fragment both known wordings share,
`queued by <resource>` and `command '<name>' queued by resource <resource>`. It
puts the dispatcher's `unknown_command` and `permission_denied:<grant>` in words,
`admin.client.unknownCommand` and `admin.client.denied`. Either kind of answer
goes under the menu only when it answers a command the menu sent in the last
fifteen seconds; `opx77_chat` toasts a refusal as well. An **accepted** answer of
more than one line to such a command — the holders of an item, from
[`opx77_inventory`](../opx77_inventory/commands.md#holders) — is also written to
the chat box, authored *STAFF*, because `opx77_chat` prints none: the line under
the list holds only its first line.

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
    - `weapons` says whether `Open77.weapons`, the holster's relay, exists on
      this host.
    - `inventory` says whether `opx77_inventory` is running: its rows are drawn
      only then.

Followed at once by [`roster`](#roster) and [`locations`](#locations), and,
while the inventory runs, by [`items`](#items) once its catalogue has been read.

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

### opx77_admin:items {#items}

`opx77_inventory`'s catalogue, for the item and weapon pickers, in chunks of
twenty rows. Sent after the opener while the inventory runs, and in answer to a
[`refresh`](#refresh) for `items`.

```lua
RegisterNetEvent("opx77_admin:items", function(chunk) end)
```

- chunk: `{ rows, offset, total, done, error }`
    - rows: `{ name, label, category, class }[]` — `class` only on a weapon
      item, which is how the weapon picker tells them apart. Sorted by label.
    - offset, total, done: as in [`roster`](#roster).
    - error: this resource's refusal code when the catalogue could not be read,
      such as `inventory_unavailable`; the picker then shows
      *opx77_inventory did not answer.*

A row is data drawn as text: what a picker row runs is a command line the host
gates like any other.

### opx77_admin:bag {#bag}

One bag's stacks, for the *Take an item* picker, in chunks of twenty rows. Sent
only in answer to a [`refresh`](#refresh) for `bag`.

```lua
RegisterNetEvent("opx77_admin:bag", function(chunk) end)
```

- chunk: `{ rows, offset, total, done, target, error }`
    - rows: `{ slot, name, count, label }[]`, in slot order.
    - target: the holder the picker asked for, as typed. A chunk for another
      holder than the one the picker is drawing is ignored.
    - error: a refusal code when the holder did not resolve or the bag could not
      be read.

### opx77_admin:access {#access}

A fresh access map, in answer to a [`refresh`](#refresh) for `access`.

```lua
RegisterNetEvent("opx77_admin:access", function(payload) end)
```

- payload: `{ access, aclKnown, inventory }`, as in [`open`](#open). The screen
  on top is redrawn with it; an inventory that has come up since asks for
  [`items`](#items).

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

### opx77_admin:answer {#answer}

A command's answer to the staff member who ran it, already in the configured
locale.

```lua
RegisterNetEvent("opx77_admin:answer", function(raw, accepted, message, kind) end)
```

- raw: `string` — the command line as typed.
- accepted: `boolean` — whether it was done.
- message: `string` — an empty one is dropped.
- kind: `"report" | "info" | "success" | "warning" | "error"` — `report` for
  a listing, answered with `admin.text.lines`; otherwise the toast's kind, as
  [How a command answers](commands.md#answers) sorts them. Anything else is
  read from `accepted`: `success` or `error`.

The client first puts the message under the list when the menu sent that
command in the last fifteen seconds. Then a `report` is a `chat:addMessage`
line authored *STAFF*, and anything else a toast through `opx77_notify`'s
`show`, titled *STAFF*, in the one slot `opx77_admin` that each answer — and
every other toast of this resource's — replaces. A toast that cannot be raised
is the same chat line, logged once:

```text
no toast (not_running): staff answers go to the chat box instead
```

A forged one draws a line or a toast on the forger's own screen, and nothing
else.

## Client to server {#client-to-server}

### opx77_admin:refresh {#refresh}

The menu asks for a list again: the roster when it opens the players or a player
screen, the destinations when it opens a destination screen, the access map
when it leaves the root screen, the inventory's catalogue when an item or weapon
picker opens without one, and a bag every time the *Take an item* picker opens
or a removal from it was sent — a bag changes under a staff member between two
visits.

```lua
TriggerServerEvent("opx77_admin:refresh", topic, holder)
```

- topic: `"roster" | "locations" | "access" | "items" | "bag"` — anything else
  is ignored.
- holder: `string` — for `bag` only: a player id, `me` or a citizen id, at most
  32 characters. A `bag` without one is ignored.

The server cools it at [`RATE.REFRESH_MS`](config.md#rate) per topic, then
re-checks `command.opx77.admin` with `Open77.acl.isAllowed`, because anybody
can send a net event. A bag's stacks are somebody's belongings, so `bag` also
needs `command.opx77.admin.inventory.view` or
`command.opx77.admin.inventory.remove`. It **fails closed**: with no ACL reader
on the host every refresh is dropped, and running the opener again refreshes
everything but a bag.

## What it listens to {#listens}

| Event | Side | For |
|---|---|---|
| `open77:command:result` | client | the dispatcher's or another resource's answer to a command the menu sent; the queue acknowledgement is dropped |
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
| `chat:addSuggestions` | one player | the staff commands that player may run |
| `chat:addMessage` | every player | an announcement, when [`ANNOUNCE.CHAT`](config.md#announce) is on |
| `chat:addMessage` | the operator, locally | a report, and any answer a toast could not carry — see [`answer`](#answer) |

A target's toast and an announcement go through `Open77.notifications.send` on the server, which
[`opx77_notify`](../opx77_notify/index.md) draws. The operator's own answer is
raised on the client instead, through `opx77_notify`'s `show` export.

## See also {#see-also}

- [Types](types.md) — the payload shapes.
- [The client export contract](../../concepts/export-contract.md#local-bus) —
  why the client bus is not a trust boundary.
