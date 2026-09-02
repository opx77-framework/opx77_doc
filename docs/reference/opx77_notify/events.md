---
title: opx77_notify events
description: The four net events opx77_notify answers to — the entire wire vocabulary the platform's server-side Open77.notifications API emits — and the one local event it raises when a toast goes away.
---

# Events

`opx77_notify` is on both ends of an event: it **listens** for four networked
names, which is how a server resource reaches it, and it **raises** one
non-networked name, which is how a caller hears that a toast has gone.

!!! danger "Local and networked names are kept disjoint, and must stay that way"
    On this platform `TriggerEvent` also reaches `RegisterNetEvent` handlers of
    the same name — the dispatcher matches on the name and ignores the network
    flag. Re-emitting a wire name from inside its own handler re-enters that
    handler. It is tick-paced rather than stack recursion, so it is a **silent
    permanent busy loop**: nothing crashes and nothing is logged.

    No name on this page appears in both roles. The four `open77:notifications:*`
    names are listened for and never raised; `opx77:notify:removed` is raised and
    never listened for.

## Networked {#networked}

Four inbound names, and no outbound ones at all. This resource never calls
`TriggerServerEvent` and has no server half to call. `network.events` in its
manifest is for `RegisterNetEvent` alone.

**These four are the entire wire vocabulary of the platform's own server-side
notification API.** `Open77.notifications.send`, `broadcast`, `update`, `dismiss`
and `clear` live in every server VM's Lua bootstrap, and all any of them does is
fire one of these at a target. That is why a server resource written against the
standard API needs no change to render here — see
[the drop-in](index.md#server-side).

!!! warning "Every payload is re-derived and type-checked"
    `source` on the server cannot be forged, but a payload always can, and these
    names also sit on the client's local bus where any resource can raise them.
    Each handler re-checks the envelope's shape and drops anything that does not
    match.

### open77:notifications:show {#notifications-show}

Raises a toast owned by a **server** resource, or replaces the one it already has
under that id.

```lua
-- fired by the host's Open77.notifications.send / .broadcast, never by you
{ owner = "<server resource name>", id = "<owner-local id>", definition = { ... } }
```

- `owner`: `string` — the server resource's manifest name, from
  `GetCurrentResourceName()` on the server. It is stored as `@server:<owner>`.
- `id`: `string` — 1–96 characters of `[%w_:%-%.]`. The server's own record is
  keyed on it, and a later `update` or `dismiss` addresses it.
- `definition`: `table` — a [`NotifyDefinition`](types.md#notifydefinition).

The envelope's `id` wins over any `id` inside the definition, and `replace` is
forced to `true`: the server has already decided this id may be re-sent, and its
record is the one that has to stay addressable.

### open77:notifications:update {#notifications-update}

Patches a toast that server resource already has.

```lua
{ owner = "<server resource name>", id = "<owner-local id>", patch = { ... } }
```

An `id` with no live toast is dropped in silence. There is no channel back to the
server: the server keeps its own record and expires it on its own clock.

### open77:notifications:dismiss {#notifications-dismiss}

Takes down one toast that server resource has, with reason `server_dismissed`.

```lua
{ owner = "<server resource name>", id = "<owner-local id>" }
```

### open77:notifications:clear {#notifications-clear}

Takes down every toast that server resource has, with reason `server_cleared`.

```lua
-- the whole payload is the owner name; this one is NOT a table
"<server resource name>"
```

!!! info "The odd one out, and it is the host's shape, not ours"
    `clear` is the only one of the four whose payload is a bare string. The
    server's `notificationClear` sends `GetCurrentResourceName()` as the entire
    argument, so that is what the handler accepts.

## Non-networked (the client local bus) {#non-networked}

The client's local event bus is **host-wide**: a `TriggerEvent` in one client
resource reaches a plain `AddEventHandler` in another. See
[The client export contract](../../concepts/export-contract.md).

One name, raised exactly once for every removal.

### opx77:notify:removed {#opx77-notify-removed}

The removal event, in this framework's own namespace. It is raised whatever took
the toast down — a deadline, its owner, a position that overflowed, a server-side
dismissal — and it is the only way a caller hears that one of its toasts has
gone.

```lua
AddEventHandler("opx77:notify:removed", function(payload) end)
```

- payload: [`NotifyRemoved`](types.md#notifyremoved)
    - `handle`: `integer` — the handle [`show`](exports.md#show) answered.
    - `id`: `string` — the owner-local id.
    - `owner`: `string` — the resource that raised it, or `@server:<resource>`.
    - `reason`: [`NotifyReason`](types.md#notifyreason).
    - `data`: `table` — your opaque table, echoed back. `{}` when there was none.

| `reason` | Raised when |
|---|---|
| `expired` | Its duration elapsed. |
| `dismissed` | Its owner called [`dismiss`](exports.md#dismiss). |
| `queue_limit` | A ninth toast joined its position and it was the oldest there. |
| `owner_cleared` | Its owner called [`clear`](exports.md#clear). |
| `owner_disabled` | Its owner called [`setEnabled(false)`](exports.md#setenabled). |
| `owner_reloaded` | Its owner's code was replaced. |
| `owner_stopped` | Its owner stopped. |
| `server_dismissed` | The server resource that sent it called `Open77.notifications.dismiss`. |
| `server_cleared` | The server resource that sent it called `Open77.notifications.clear`. |

!!! warning "The platform's own removal name is not raised"
    `open77_notifications` documents its removal event as
    `open77:notificationRemoved`. This resource raised that name alongside its own
    up to `0.1.0` and no longer does: one removal, one event. The exports are
    still a drop-in, but a resource ported from the official package has to rename
    its removal handler.

!!! warning "This fires for other resources' toasts too"
    It is global. The payload carries `owner` precisely so you can tell yours
    apart, and a listener that does not filter on it will act on somebody else's
    toast.

!!! warning "Stopping `opx77_notify` raises nothing"
    When this resource itself stops, everything it holds is dropped in silence.
    An owner's handler is free to call straight back into an export, and this VM is
    halfway through stopping when that path would run. Do not build an unwind that
    depends on hearing about it.

The reason it is an event at all is that an export cannot answer a callback on
this platform: the codec rejects functions, so when a toast goes away for a reason
its owner did not ask for, an event is the only way to say so. See
[Integration channels](../../concepts/integration-channels.md).

#### Example {#opx77-notify-removed-example}

```lua
-- a client script in your own resource
AddEventHandler("opx77:notify:removed", function(payload)
  if payload.owner ~= GetCurrentResourceName() then return end
  if payload.reason == "expired" and payload.id == "download" then
    -- the toast timed out on its own; nothing acknowledged it
  end
end)
```

## Not events: the page channels {#page-channels}

`notify:config`, `notify:add`, `notify:update`, `notify:remove`, `notify:ready`
and `notify:diag` look like event names and are not. They are `page:send` and
`page:on` channels on this resource's own WebUI surface — local UI IPC down a
private pipe, not the event bus — and nothing outside this resource can raise or
hear them.
