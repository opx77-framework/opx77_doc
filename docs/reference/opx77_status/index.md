---
title: The opx77_status resource
description: opx77_status is the shared status-effect registry for OPX//77 — four client exports any resource can call, an ownership model that cleans up after a caller that stops or reloads, and a payload opx77_hud draws.
---

# opx77_status

| At a glance | |
|---|---|
| **Version** | `0.2.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `reconnect` |
| **Permissions** | none — `permissions {}`, and it is deliberate |
| **Sides** | client only. There is no `server_script` and no server half at all, and it sends and receives nothing over the wire |
| **Exports** | four, all client: [`add`](exports.md#add), [`update`](exports.md#update), [`remove`](exports.md#remove), [`clear`](exports.md#clear) |
| **Commands** | none |
| **Events** | publishes [`opx77:status:effects`](events.md#status-effects); raises [`opx77:status`](events.md#opx77-status) and, per effect, [your own event name](events.md#spec-event) |
| **Surface** | none. [`opx77_hud`](../opx77_hud/index.md) draws the strip |

## What it is {#what-it-is}

A shared status-effect strip. Any resource adds a chip — bleeding, over
encumbered, a wanted level, a buff on a timer — and `opx77_status` owns the
registry, the ordering and the countdown. Without it, every resource that wanted
to say something on screen would draw its own box and they would overlap. One
registry means one place decides what an urgent chip outranks, one place decides
how many fit, and one place ticks the timers down.

It is a **public API** rather than an internal detail of the HUD, and that is
what its four exports are for. An effect belongs to the resource that added it;
`remove` and `clear` only ever reach your own; ids are unique per owner, so two
resources may both hold `bleeding`; and when your resource stops or reloads,
everything it held goes with it without you writing a line of teardown. That
ownership model is the whole reason another developer can depend on this resource
safely, and it is documented in full on [Exports](exports.md#ownership).

## Its relationship with opx77_hud {#hud-relationship}

The two resources are separate on purpose:

- **`opx77_status` owns the effect registry and publishes a payload.** What an
  effect is, who added it, when it expires, what order the strip sits in, how many
  are drawn before the rest collapse into a counter — all decided here. It draws
  nothing.
- **[`opx77_hud`](../opx77_hud/index.md) renders it and owns the surface.** It
  listens on [`opx77:status:effects`](events.md#status-effects), carries the chips
  into its next frame, and places, themes and animates them. It has no opinion
  about what a chip means.

A merge of the two was considered and **rejected**. These four exports are an API
third-party resources are written against, this is its own repository with its own
version and licence, and the bug that prompted the suggestion — the strip's
`ANCHOR` and `OFFSET` silently doing nothing — turned out to be six lines in the
HUD's web layer and is fixed.

Two surfaces for one corner of the screen would have been two things to place,
two things to theme and two things to keep in step, which is why this resource
ships with no surface of its own and publishes an event instead. The placement
travels **in the payload**, so the HUD never has to read this resource's config:

```lua
{
  anchor = "bottom-left",  -- OPX_STATUS_CONFIG.ANCHOR
  offset = 120,            -- OPX_STATUS_CONFIG.OFFSET
  chips  = { --[[ up to MAX_VISIBLE, already ordered ]] },
  hidden = 0,              -- how many were left out of the cut
}
```

!!! warning "The strip is only as visible as the HUD is"
    The whole HUD surface is one element's `open` class, strip included. A player
    who typed `/hud off` sees no chips, however urgent. Adding an effect is not a
    way to put something on a screen its owner has turned off.

## Why the permission block is empty {#permissions}

```lua
permissions {}
```

**The empty block is the honest answer, not an oversight.** This resource sends
and receives nothing over the network, declares no `web_ui_page`, and touches no
world API. Its whole outward surface is four client exports and the local events
they raise, and neither needs a grant:

- An **export call** needs no permission on either side.
- The client's **local event bus** is host-wide, so a `TriggerEvent` here reaches
  a bare `AddEventHandler` in another resource without `network.events`.

`open77_zones`, the first-party client service shaped exactly like this one, ships
an empty block for the same reason.

!!! info "There is no server half"
    No `server_script`, no net event, no database. Every state this resource holds
    lives in one client's VM for the length of that session, and a reconnect
    starts it empty. Nothing here survives anything. If your effect must survive a
    reconnect it is character state and belongs in
    [`opx77_core`](../opx77_core/index.md), not on the strip.

## Hunger and thirst are not here {#not-needs}

They used to be. They are **character metadata**, owned and decayed by
`opx77_core`'s server half, and they arrive with every `PlayerData` snapshot —
`opx77_hud` draws them from there. A gauge that has to survive a reconnect and
follow a character belongs to the resource that owns characters, not to the strip
that happens to be able to draw a bar. `opx77_status` never touches them.

## Where to go next {#next}

- [Exports](exports.md) — the four calls, their error codes, and the ownership
  and generation model behind them.
- [The effect spec](effect-spec.md) — every field, the tones, the ordering rule
  and the countdown.
- [Events](events.md) — how an expired effect is reported back to you, and the
  payload the HUD draws.
- [Configuration](config.md) — the three keys.
- [The client export contract](../../concepts/export-contract.md) — read this
  before calling anything here.
