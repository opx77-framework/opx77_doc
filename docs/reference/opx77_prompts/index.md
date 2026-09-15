---
title: The opx77_prompts resource
description: opx77_prompts is the key strip for OPX//77 — one corner surface that any resource fills with "press this key to do that" while it matters, through five client exports or four net events, naming each key by the player's own binding.
---

# opx77_prompts

!!! warning "Early development"

    `opx77_prompts` is version `0.2.0`. The exports, the spec shape and the
    error codes are subject to change without notice. Do not build a
    production resource on the current surface.

The key strip for OPX//77: one surface in the bottom-right corner, owned by this
resource, that any other resource can put "press this key to do that" on while
it matters — the noclip controls while noclip is on, the key that stops an
animation while one plays, the keys of a menu while it is open.

## At a glance {#at-a-glance}

| At a glance | |
|---|---|
| **Version** | `0.2.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared, and nothing needs to be running for it to start |
| **Auto start** | yes |
| **Reload policy** | `reconnect`, because it owns a WebUI surface |
| **Permissions** | `input.actions` and `network.events` — see [below](#permissions) |
| **Sides** | client only. There is no `server_script` |
| **Exports** | five, all client: [`show`](exports.md#show), [`update`](exports.md#update), [`hide`](exports.md#hide), [`hideAll`](exports.md#hideall), [`list`](exports.md#list) |
| **Commands** | none, and no key mapping either |
| **Events** | listens on [four net events](events.md#networked) a server resource sends; raises none |
| **Surface** | its own, on the `hud` layer at `zIndex` 710 |

## What it is {#what-it-is}

A resource that puts the player in a mode — noclip, an animation, a menu — had
nowhere to say which keys work in it. This is that place. A caller hands it a
**group** of rows; each row is one or more key caps, a label, and optionally a
live value (`SPEED | 60 m/s`). The strip draws them, orders them, and takes them
down when the caller says so or when the caller goes away.

It is **client-side**, because that is the only side exports exist on. A server
resource reaches it over [four net events](events.md#networked).

It **draws no key of its own and reads none**. It registers no command and no key
mapping; the key that does the thing belongs to the caller, and the caller acts
on it. This resource only says which key it is.

!!! note "Not the prompts in the world"
    The prompts drawn at `opx77_inventory`'s piles and stashes are not this
    resource's: they are proximity prompts registered with the platform's
    `open77_interactions`. `opx77_prompts` is a fixed strip in a screen corner
    and knows nothing about positions in the world.

## Groups, rows and the order they are drawn in {#strip}

- **A group goes up and comes down together.** A caller names it with an id of
  its own; two resources can both hold a group called `main` and never touch
  each other. A group holds 1 to 8 rows, and may carry a title drawn above them
  as a `//` eyebrow.
- **Priority orders the groups.** An integer from −100 to 100, default 0. The
  highest sits nearest the anchored edge; between equal priorities, the most
  recently shown group does. Showing an id you already hold replaces that group
  **where it stands**, so a context redrawn does not jump the queue.
- **`MAX_ROWS` cuts the strip.** At most [`MAX_ROWS`](config.md#max-rows) rows
  are drawn across every group, 10 as shipped. Rows are counted from the highest
  priority down, so the lowest priority loses its rows first, and a group can be
  drawn in part. A cut group is still held, and comes back as soon as there is
  room.
- **A row with a key it cannot name is left out.** A row with any key naming a
  mapping nobody registered, without a `fallback`, is not drawn: a prompt with
  no key to name says nothing. It does not use up a row of the budget, and it
  comes back when the mapping is registered.

The shapes are on [Types](types.md#promptspec); the calls on
[Exports](exports.md).

## Keys named by the player's own binding {#keys}

A key in a row is either a **literal name** or a **mapping**.

- A literal is a string split on spaces, so `"W A S D"` is four caps. A name in
  the [key catalogue](config.md#locale) is drawn in the configured language
  (`SPACE` is `ESPACE` in French), the arrows `UP DOWN LEFT RIGHT` are drawn as
  `↑ ↓ ← →` in every language, and anything else is drawn upper-cased as
  spelled — `F9`, `SCROLL`, `MOUSE`.
- A mapping, `{ mapping = "id" }` for one of the caller's own key mappings or
  `{ mapping = "resource|id" }` for another resource's, is drawn as the key the
  player has it bound to — their rebind if they made one, else the registered
  default — and follows a rebind the moment it happens.

`Open77.input.keyFor` only answers for the calling resource's own mappings, and
the caller here is always this resource. So every mapping, the caller's own
included, is resolved through `Open77.input.mappings()`, the registry the pause
menu's KEY BINDINGS tab reads. It is read at start and again on every
`open77:keybinds:changed`, which the platform raises after any registration,
rebind, reset or removal. A failed read keeps the last good copy and is logged
once.

## When it steps aside {#steps-aside}

Hiding the strip **never drops a group**: it comes back exactly as it was.

- **While the keyboard is taken.** With
  [`HIDE_WHEN_CAPTURED`](config.md#hide-when-captured) on, the strip hides while
  `Open77.input.isCaptured()` answers `true` — chat, an `opx77_input` form, the
  pause menu.
- **While `opx77_hud` is toggled off.** With [`FOLLOW_HUD`](config.md#follow-hud)
  on, and `opx77_hud` running, the strip asks its
  [`isVisible`](../opx77_hud/exports.md#isvisible) export once a second while it
  holds at least one group. Only an answer with `ok = true` **and**
  `visible = false` hides the strip. A call that was not dispatched, failed, or
  answered without `ok = true` leaves it drawn: a HUD that did not answer has
  hidden nothing.

The HUD is **polled** rather than followed because there is nothing to follow:
`opx77_hud` raises no event when its visibility changes, and `isVisible` is the
only way to read it. The player toggles it with its key or
[`/hud`](../opx77_hud/commands.md#hud), and any resource can toggle it with
`setVisible`; each of those hides the strip within a second.

## Who uses it {#callers}

Three resources in the set put groups up, and each treats this one as a **soft
dependency**: it checks `GetResourceState("opx77_prompts") == "running"` before
calling, logs one line if it is not, and works the same without it. Each also
listens for `onClientResourceStart` of `opx77_prompts` and sends its group again,
so a restarted strip is filled back in. All three call only `show` and `hide`.

| Resource | Group id | Priority | What it shows | Turn it off |
|---|---|---|---|---|
| [`opx77_admin`](../opx77_admin/index.md#travel) | `noclip` | 50 | the noclip controls while noclip is on and the player is alive, with the speed as a live value | [`NOCLIP.PROMPTS = false`](../opx77_admin/config.md#noclip) |
| [`opx77_admin`](../opx77_admin/index.md#travel) | `maptravel` | 49 | the double-click hint while map travel is armed | `NOCLIP.PROMPTS = false` |
| [`opx77_menu`](../opx77_menu/index.md#key-prompts) | `menu` | 40 | the menu's keys while a menu is open, following the cursor and the depth | [`PROMPTS = false`](../opx77_menu/config.md#prompts), or `prompts = false` on one menu's spec |
| [`opx77_animations`](../opx77_animations/index.md) | `playing` | 0 | the stop key while the player's own animation plays, unless `KEYS.STOP` is `false` | `PROMPTS = false` in its [configuration](../opx77_animations/config.md) |

The priorities are chosen so staff travel controls sit above a menu's keys, and
both above gameplay prompts.

## Load order {#load-order}

It does not matter where `opx77_prompts` sits in `resources.load`. No manifest in
the set declares a dependency on it, it declares none itself, and every caller
finds it with a state check at the moment it calls — then again when it starts.
Loading it with no caller running costs one idle surface.

Inside the resource, the manifest order is the load order, and it carries
weight:

1. `config.lua` publishes `OPX_PROMPTS_CONFIG`;
2. `client/locale.lua` creates the `OpxPrompts` namespace and applies `LOCALE` at
   load, so it must come after `config.lua`;
3. `locales/en.lua` and `locales/fr.lua` register their catalogues;
4. `client/state.lua` validates the settings and holds the store;
5. `client/keys.lua` names a key cap;
6. `client/main.lua` creates the surface, runs the loops and opens the four net
   events;
7. `client/exports.lua` comes last.

The LuaLS types and the signatures of the `OpxPrompts.*` functions are in `std/`
(`std/types.lua` and one stub file per script). They are never loaded.

## Why the permission block is what it is {#permissions}

```lua
permissions {
  "input.actions",
  "network.events",
}
```

- **`input.actions`** — for `Open77.input.mappings`, to name the key a player
  bound to a caller's action, and `Open77.input.isCaptured`, to step aside while
  something else has the keyboard. Nothing here registers a mapping or reads a
  key.
- **`network.events`** — for `RegisterNetEvent` on the four inbound
  `opx77_prompts:*` names a server resource sends. It is inbound only: nothing
  here calls `TriggerServerEvent`.

Export calls need no permission, on either end — reading `opx77_hud`'s
`isVisible` included. The surface never takes focus, so no `webui.*` permission
applies.

## The surface {#surface}

One WebUI page, created by `client/main.lua` rather than by the manifest
(`web_ui_auto_create false`), so a failure is a log line and a refusal rather
than a silent absence. It is a transparent `1920x1080`, 30 fps surface on the
**`hud`** layer at `zIndex` **710**: above `opx77_hud` (705) and `opx77_chat`
(700), below `opx77_notify` (720) and every menu. It sets `pointer-events: none`,
never takes focus, and inserts every string with `textContent`, so nothing a
caller sends can become markup.

The shipped corner is the one no other OPX//77 surface uses: `opx77_hud`'s gauges,
`opx77_status`'s chips and `opx77_chat` are bottom-left, `opx77_notify`'s toasts
and `opx77_hud`'s info lines top-right, `opx77_menu` and `opx77_input` top-left.

- **A failed surface refuses.** When `WebUI.create` failed at start,
  [`show`](exports.md#show) and [`update`](exports.md#update) answer `no_surface`
  rather than `ok = true` for a group nobody will ever see.
- **A page that is not ready yet does not.** Groups shown before the page reports
  ready are held, and drawn the moment it does.
- **A patch that changes nothing on screen sends nothing to the page**, so a
  caller can push the same reading on every frame without cost to the surface —
  though not without the cost of the export call.

When this resource stops, it drops every group and forgets the page; the surface
goes with the resource generation. `reload_policy "reconnect"` covers a reload,
because a live CEF surface is not replaced in place.

## Known limits {#limits}

- **The HUD visibility can be a second late.** It is only polled while a group is
  held. If `opx77_hud` is toggled while the strip holds nothing, the next group
  put up is drawn with the last reading until the next poll, at most one second
  later: the strip can show for a moment under a hidden HUD, or stay hidden for a
  moment under a shown one. Polling with nothing held would cost an export call
  every second for the whole session, and no poll can be skipped: `opx77_hud`
  raises no visibility event, and a group's first draw happens inside `show`,
  which answers without waiting on another export.
- **The keyboard capture can be half a second late the same way.** It is read by
  the strip's own pass, which runs every 500 ms while nothing is held and every
  120 ms while something is. A first group put up while chat is open can be drawn
  until that pass runs.
- **A server-sent group outlives its sender.** A client cannot see a server
  resource stop, so a group sent over the [net events](events.md#networked) stays
  up until it is hidden, or until this resource or the player's session ends.

## Where to go next {#next}

- [Exports](exports.md) — the five calls, every refusal code, and the ownership
  and sweep model behind them.
- [Events](events.md) — the four net events a server resource sends.
- [Configuration](config.md) — the seven keys, and what is deliberately not one.
- [Types](types.md) — the spec, the row, the key entry, the patch and the answer.
- [The client export contract](../../concepts/export-contract.md) — read this
  before calling anything here.
