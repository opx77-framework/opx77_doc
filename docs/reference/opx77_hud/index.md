---
title: The opx77_hud resource
description: opx77_hud is the player HUD for OPX//77 — segmented gauges, a money and job read-out, and the status strip; it reads opx77_core and opx77_status and draws them, and decides nothing itself.
---

# opx77_hud

| At a glance | |
|---|---|
| **Version** | `0.1.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared; it reads [`opx77_core`](../opx77_core/index.md) and [`opx77_status`](../opx77_status/index.md) at runtime when they are running |
| **Auto start** | yes |
| **Reload policy** | `reconnect` — a CEF surface is never replaced in place |
| **Permissions** | `network.events` |
| **Sides** | client, plus a server half that registers one command |
| **Exports** | two, both client: [`setVisible`](exports.md#setvisible), [`isVisible`](exports.md#isvisible) |
| **Commands** | one: [`/hud`](commands.md#hud) |
| **Events** | it raises no Lua event at all. Its only outbound messages are to its own page — see [Events](events.md) |
| **Reads** | `opx77_core` (client export and local events), `opx77_status` (local event) |

## What it is {#what-it-is}

`opx77_hud` owns one rectangle. It draws the character `opx77_core` holds —
health, armour, stamina, hunger, thirst, the purse, the job and street cred — as
segmented gauges in one corner and a bare text read-out in another. It also
draws the status strip that [`opx77_status`](../opx77_status/index.md) publishes.

**It decides nothing and writes nothing.** There is no state in this resource
another resource would want. It never calls a mutator on the core, never writes
to the database, and never sends anything to the server except the `/hud`
command's answer travelling back to the player who typed it. Everything on
screen is a rendering of somebody else's state, and the only thing this resource
owns is the surface it is rendered on — a WebUI page on the `hud` layer,
1920 × 1080 at 30 fps, `zIndex` 705, transparent.

The manifest sets `web_ui_auto_create false` and the page is created in
`client/main.lua` instead, so a surface that fails to come up costs one logged
line rather than a resource that will not start. `web_files { "web/**" }` is the
one glob shape that is safe on this platform; a *script* glob is fatal, and
[Architecture](../../concepts/architecture.md#load-order) explains why every
`client_script` line here is written out individually.

!!! info "The reload policy is `reconnect`"
    The CEF surface is never replaced in place. Restarting this resource against
    a live client would leave the old page on screen, so the platform requires
    the client to reconnect. In practice that means the HUD is never hot-reloaded
    and its visibility flag resets only when the player reconnects.

## Its relationship with opx77_status {#status-relationship}

The two resources are separate on purpose, and the split is a clean one:

- **[`opx77_status`](../opx77_status/index.md) owns the effect registry and
  publishes a payload.** What an effect is, who added it, when it expires, how
  many one owner may hold, what order they sit in — all of that is decided
  there, and it has [four exports](../opx77_status/exports.md) that third-party
  resources call. It has no surface of its own.
- **`opx77_hud` renders it and owns the surface.** It listens on the local
  client event [`opx77:status:effects`](events.md#status-effects), carries the
  chips into its next frame, and places, themes and animates them. It has no
  opinion about what a chip means.

A merge of the two was considered and rejected. `opx77_status` is its own
repository with its own version and licence, and its four exports are a public
API that other resources are written against; folding them into the resource
that happens to own a rectangle would have made the rectangle a dependency of
every resource that wanted to say a word on screen.

Two surfaces for one corner of the screen, on the other hand, would have been
two things to place, two things to theme and two things to keep in step — which
is why the registry publishes a payload rather than drawing one.

!!! warning "A HUD the player turned off stays off, chips included"
    The whole surface is one element's `open` class, strip included. Hiding is
    therefore decided on this resource's own visibility flag and never on whether
    there is anything to draw: a live chip must not keep a HUD the player turned
    off on screen. If you need the strip visible you need the HUD visible.

## What it reads from the core {#what-it-reads}

Every frame is built from one `PlayerData` snapshot. These are the only keys
this resource touches:

| Key | Drawn as |
|---|---|
| `metadata.health` | the `HP` gauge, always drawn |
| `metadata.armor` | the `ARMOR` gauge, drawn only above zero |
| `metadata.stamina` | the `STAMINA` gauge, absent until a gameplay file writes it |
| `metadata.hunger` | the `FOOD` gauge |
| `metadata.thirst` | the `HYDRATION` gauge |
| `metadata.streetCred` | the `CRED` line, drawn above zero, floored |
| `money` | one line per money type, `EDDIES` and `BANK` first |
| `job.label`, `job.grade.name`, `job.onDuty` | the job line, `on` tone while on duty |

Hunger and thirst are **character metadata owned by `opx77_core`**, which seeds
and decays them in `server/needs.lua`. They are not status effects and
`opx77_status` never touches them.

The snapshot arrives on three local events and is re-read every five seconds as
a net under them; see [Events](events.md#non-networked). A core that is not
running is not a broken screen — the gauges simply stop moving, and only an
authoritative refusal clears the HUD.

## Where to go next {#next}

- [Exports](exports.md) — the two calls that control the rectangle.
- [Events](events.md) — what it listens to, and the whole message protocol
  between Lua and `web/hud.js`.
- [Commands](commands.md) — `/hud`.
- [Configuration](config.md) — the six keys, and what is deliberately not a key.
- [`opx77_status`](../opx77_status/index.md) — the registry behind the strip.
- [The client export contract](../../concepts/export-contract.md) — read this
  before calling either export.
