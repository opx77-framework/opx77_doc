---
title: The opx77_hud resource
description: opx77_hud is the player HUD for OPX//77 — segmented gauges, a money and job read-out, and the status strip; it reads opx77_core and opx77_status and draws them, and decides nothing itself.
---

# opx77_hud

| At a glance | |
|---|---|
| **Version** | `0.6.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared; it reads [`opx77_core`](../opx77_core/index.md) and [`opx77_status`](../opx77_status/index.md) at runtime when they are running |
| **Auto start** | yes |
| **Reload policy** | `reconnect` — a CEF surface is never replaced in place |
| **Permissions** | `network.events`, `ui.vanilla.hud`, `input.actions` |
| **Sides** | client, plus a server half that registers one command |
| **Exports** | three, all client: [`setVisible`](exports.md#setvisible), [`isVisible`](exports.md#isvisible), [`vanilla`](exports.md#vanilla) |
| **Commands** | one: [`/hud`](commands.md#hud) |
| **Keys** | one: `opx77_hud.toggle`, `F8` by default, rebindable — see [Commands](commands.md#key) |
| **Events** | it raises no event of its own. Beyond its page, its only outbound message is a local `chat:addMessage` when a toast cannot be raised — see [Events](events.md) |
| **Reads** | `opx77_core` (client export and local events), `opx77_status` (client export and local events) |

## What it is {#what-it-is}

`opx77_hud` owns one rectangle. It draws what two other resources hold — health,
armour, the purse and the job from `opx77_core`, and stamina, hunger, thirst and
street cred from [`opx77_status`](../opx77_status/index.md) — as segmented gauges
in one corner and a bare text read-out in another. It also draws the status strip
that the same registry publishes.

It also turns Cyberpunk's own HUD off at boot — see
[`VANILLA`](config.md#vanilla) — because a replacement drawn on top of the
original leaves the player reading their health off two bars that disagree.

**It decides nothing and writes nothing.** There is no state in this resource
another resource would want. It never calls a mutator on the core, never writes
to the database, and never sends anything to the server. The only traffic between
its halves is the `/hud` command's answer travelling back to the player who typed
it. Everything on
screen is a rendering of somebody else's state, and the only thing this resource
owns is the surface it is rendered on — a WebUI page on the `hud` layer,
1920 × 1080 at 30 fps, `zIndex` 705, transparent.

The manifest sets `web_ui_auto_create false` and the page is created in
`client/main.lua` instead, so a surface that fails to come up costs one logged
line rather than a resource that will not start. `web_files { "web/**" }` is the
one glob shape that is safe on this platform; a *script* glob is fatal, and
[Architecture](../../concepts/architecture.md#load-order) explains why every
`client_script` line here is written out individually.

Player-facing text comes from this resource's own catalogue: `shared/locale.lua`
publishes the global `locale(key, params)`, `locales/en.lua` and `locales/fr.lua`
register the strings, and [`LOCALE`](config.md#locale) chooses between them. All
three are `shared_script`s, because the `/hud` command is registered on the
server half. `std/types.lua` holds the annotations for the shapes this resource
builds and is never loaded at runtime.

!!! info "The reload policy is `reconnect`"
    The CEF surface is never replaced in place. Restarting this resource against
    a live client would leave the old page on screen, so the platform requires
    the client to reconnect. In practice that means the HUD is never hot-reloaded
    and its visibility flag resets only when the player reconnects.

## Its relationship with opx77_status {#status-relationship}

The two resources are separate on purpose, and the split is a clean one:

- **[`opx77_status`](../opx77_status/index.md) owns the effect registry and the
  gameplay needs, and publishes both.** What an effect is, who added it, when it
  expires, how many one owner may hold, what order they sit in — all of that is
  decided there, and so are hunger, thirst, stamina and street cred: their
  bounds, their value on a new character and their decay. It has
  [seven exports](../opx77_status/exports.md) that third-party resources call,
  and no surface of its own.
- **`opx77_hud` renders it and owns the surface.** It listens on the local
  client events [`opx77:status:needs`](events.md#status-needs) and
  [`opx77:status:effects`](events.md#status-effects), carries what they say into
  its next frame, and places, themes and animates it. It has no opinion about
  what a chip means or what a need is worth.

A merge of the two was considered and rejected. `opx77_status` is its own
repository with its own version and licence, and its exports are a public
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

## What it reads, and from whom {#what-it-reads}

Every frame is built from one `PlayerData` snapshot and one set of needs. These
are the only keys this resource touches:

| Key | Held by | Drawn as |
|---|---|---|
| `metadata.health` | `opx77_core` | the `health` gauge, always drawn |
| `metadata.armor` | `opx77_core` | the `armor` gauge, drawn only above zero |
| `stamina` | `opx77_status` | the `stamina` gauge |
| `hunger` | `opx77_status` | the `hunger` gauge |
| `thirst` | `opx77_status` | the `thirst` gauge |
| `streetCred` | `opx77_status` | the `CRED` line, drawn above zero, floored |
| `money` | `opx77_core` | one line per money type, `EDDIES` and `BANK` first |
| `job.label`, `job.grade.name`, `job.onDuty` | `opx77_core` | the job line, `on` tone while on duty |

A gauge is named here by its row `id`, which is the page's DOM slot key and the
CSS class the stylesheet themes it through. A gauge carries **no label**: an
icon, the lit segments and the value are all it draws. Only the text lines — the
money lines, the job line and `CRED` — carry one.

Health and armour are **character metadata owned by `opx77_core`**. Hunger,
thirst, stamina and street cred are **needs owned by
[`opx77_status`](../opx77_status/index.md)**: they are not character metadata,
they are not status effects, and `opx77_core` never sees them.

The snapshot is read **once** at start, through `opx77_core`'s `GetPlayerData`
client export, and after that only from the core's own local events — there is no
poll behind them. A stop or restart of `opx77_core` raises no unload event, so
`opx77_hud` treats that stop as an unload: the character and its needs leave the
frame until the core loads a character again. The needs are read the same way, once at start through
`opx77_status`'s [`getNeeds`](../opx77_status/exports.md#getneeds) export and
after that only from [`opx77:status:needs`](events.md#status-needs), which is
pushed on every change; see [Events](events.md#non-networked). A source that is
not running is not a broken screen — the gauges it owns leave the frame rather
than reading zero, the rest keep drawing, and only an authoritative refusal
clears anything. An export answer that does not carry `ok = true` is a refusal,
whatever else it holds.

## Where to go next {#next}

- [Exports](exports.md) — the two calls that control the rectangle, and the one
  that reports what became of the game's own HUD.
- [Events](events.md) — what it listens to, and the whole message protocol
  between Lua and `web/hud.js`.
- [Commands](commands.md) — `/hud`, and the show/hide key.
- [Configuration](config.md) — the ten keys, including
  [`LOCALE`](config.md#locale) and [`VANILLA`](config.md#vanilla), and what is
  deliberately not a key.
- [`opx77_status`](../opx77_status/index.md) — the registry behind the strip.
- [The client export contract](../../concepts/export-contract.md) — read this
  before calling any of them.
