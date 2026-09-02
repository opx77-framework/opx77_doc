---
title: The opx77_notify resource
description: opx77_notify is the toast service for OPX//77 — seven client exports any resource can call, the four net events the platform's own server-side notification API already fires, and one transparent surface that never takes focus.
---

# opx77_notify

| At a glance | |
|---|---|
| **Version** | `0.1.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `reconnect`, because it owns a WebUI surface |
| **Permissions** | `network.events`, and nothing else |
| **Sides** | client only. There is no `server_script` and no server half at all |
| **Exports** | seven, all client: [`show`](exports.md#show), [`update`](exports.md#update), [`dismiss`](exports.md#dismiss), [`clear`](exports.md#clear), [`list`](exports.md#list), [`setEnabled`](exports.md#setenabled), [`isEnabled`](exports.md#isenabled) |
| **Commands** | none |
| **Events** | listens on [four net events](events.md#networked); raises [`open77:notificationRemoved`](events.md#notificationremoved) and [`opx77:notify:removed`](events.md#opx77-notify-removed) |
| **Surface** | its own, on the `hud` layer at `zIndex` 720 |

## What it is {#what-it-is}

A toast renderer any resource can call. A resource asks for a notice — a job
accepted, a payment received, a connection degrading — and `opx77_notify` owns
the stack, the ordering, the countdown and the pixels. Without it every resource
that wanted to say something transient would draw its own box, and they would
overlap.

It is **client-side**, and that is not a preference. The OPEN//77 server runtime
installs no `exports` and no `GetInvokingResource`: a server-side notification
service could not be called by anything, and could not tell who was calling if it
were. See [Architecture](../../concepts/architecture.md).

## It is a drop-in on both sides {#drop-in}

This is the design point, and it is worth reading before the export list.

### The server side already speaks to it {#server-side}

The platform ships an owner-aware notification API **inside every server VM's
bootstrap** — `Open77.notifications.send`, `broadcast`, `update`, `dismiss` and
`clear`. Recovered from the shipped server binary, all `send` does is fire a net
event at the target:

```lua
TriggerClientEvent("open77:notifications:show", target, {
  owner = GetCurrentResourceName(), id = id, definition = definition,
})
```

`update`, `dismiss` and `clear` are the same shape on
`open77:notifications:update`, `:dismiss` and `:clear`. **Nothing in that code
names, checks for, or depends on the official `open77_notifications` client
package.** It fires four names and hopes something is listening.

`opx77_notify` listens for all four. A server resource already written against
`Open77.notifications.*` renders in OPX//77's toasts **without changing a line**.
The four envelopes and their exact shapes are on [Events](events.md#networked).

### The client side already calls it {#client-side}

The seven exports are the names the platform documents on its own package, with
the same arguments, the same definition schema and the same limits. A client
resource written against `open77_notifications` works here too.

The one thing that is not identical is the **shape of the answer**: every export
here returns a table carrying `ok` rather than a bare boolean or a bare array.
That is this framework's convention, and it is additive — a caller that only
tests truthiness reads `{ ok = true }` as true either way, and one that wants a
reason now has a stable `error` code. See
[The client export contract](../../concepts/export-contract.md).

!!! danger "Do not run this and `open77_notifications` at the same time"

    Both listen on the same four `open77:notifications:*` net events and both
    publish the same export names, so **every server-sent toast is drawn twice**,
    on two surfaces, in two corners.

    The resource says so in the client log at start. The check runs inside a
    `CreateThread` rather than at file scope, because at load time a conflicting
    resource listed later in `resources.load` is still `discovered` and a
    file-scope check would silently pass — which would make the warning depend on
    load order, the one thing an operator did not choose.

    Drop one of the two from `resources.load` in `server.jsonc`.

## Top right, not middle left {#position-default}

[`OPX_NOTIFY_CONFIG.POSITION`](config.md#position) defaults to `"top_right"`. The
official package defaults to `"middle_left"`.

**This is a deliberate departure, and it is the only default that differs.** The
top right is where this framework's other surfaces already put transient notices —
[`opx77_hud`](../opx77_hud/index.md)'s info column is anchored there by default —
and a player who has learned to read one corner for "something just happened"
should not have to learn a second one.

A caller that names a `position` explicitly still gets exactly the position it
named, so a resource ported from the official package keeps its own placement.

## Title and description, both rendered {#title-and-body}

A toast is a heading and a line under it. `title` is the heading, `message` is the
body, and the documented aliases are accepted for both halves of the pair the
schema defines: `text` for `message`, `kind` for `type`, `duration` for
`durationMs`.

The body is **required** and the title is not: a toast with a title and nothing
under it is a label, not a notification. Where both spellings of an alias are
present, the primary one wins — see [`NotifyDefinition`](types.md#notifydefinition).

## The surface {#surface}

One WebUI page, created in `client/main.lua` so a failure is one logged line
rather than a silent absence, on the `hud` layer at `zIndex` 720. That is the
platform's own number for toasts: above `opx77_hud` (705) and `opx77_chat` (700),
below [`opx77_menu`](../opx77_menu/index.md) (725), because a notice that arrives
while a menu is being driven is the one thing that may not cover it.

The page is transparent, sets `pointer-events: none` on the document, and **never
takes focus** — there is no `setFocus` call anywhere in the resource, which is why
its manifest asks for no `webui.*` permission. Every string is inserted with
`textContent`; nothing a caller sends can become markup.

Toasts raised before the page reports ready are **held and replayed**, not
dropped. A page that never existed at all is different: if `WebUI.create` failed,
[`show`](exports.md#show) refuses with `no_surface` rather than answering `ok` for
a toast nobody will ever see.

## Why the permission block is what it is {#permissions}

```lua
permissions {
  "network.events",
}
```

`network.events` is needed for exactly one thing: `RegisterNetEvent` on the four
inbound names. It is **inbound only** — this resource never calls
`TriggerServerEvent`, and has no server half to call.

Nothing else is declared, and the emptiness beyond that line is deliberate rather
than an omission. Export calls need no permission on either side; the client's
local event bus is host-wide, so the two removal events reach a bare
`AddEventHandler` in another resource without a grant; the surface is never
focused, so no `webui.*` capability applies; and no world, input or environment
API is touched.

## Where to go next {#next}

- [Exports](exports.md) — the seven calls, every error code, and the ownership
  and generation model behind them.
- [Events](events.md) — the four net events it answers to, and the two local ones
  it raises.
- [Configuration](config.md) — the four keys, and what is deliberately not one.
- [Types](types.md) — the definition schema, the entry, and the removal payload.
- [The client export contract](../../concepts/export-contract.md) — read this
  before calling anything here.
