---
title: opx77_menu overview
description: opx77_menu owns the single keyboard-driven menu surface on the client, and every other resource opens a menu through a client export and is told which row the player chose by an event.
---

# opx77_menu

!!! warning "Early development"

    `opx77_menu` is version `0.2.0`. The exports, the payload shape and the
    error codes are subject to change without notice. Do not build a production
    resource on the current surface.

One resource owns the menu surface. Every other resource opens a menu through a
client export and is told which row the player chose. There is no second
surface, no per-caller instance and no cursor: the strip is drawn on the **HUD
layer**, so it is never focused and can never take input away from the game,
and it is navigated entirely from the arrow keys, `ENTER` and `BACKSPACE`.

The consequence a reader arriving from FiveM has to absorb first is that a menu
item carries **no callback**. The client runtime puts every export argument
through a codec that refuses functions, so the answer comes back as a local
event you registered for yourself. That mechanism, and the fact that it is the
same one `open77_zones` and `open77_worldui` use, is the subject of
[Events](events.md).

## At a glance {#at-a-glance}

| At a glance | |
|---|---|
| **Version** | `0.2.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared, and nothing needs to be running for it to start |
| **Auto start** | yes |
| **Reload policy** | `reconnect` — handles and owner generations belong to the client session, so a generation change needs a clean reconnect rather than a hot swap |
| **Permissions** | `input.actions` — `Open77.input.isDown` and `isCaptured`. It never takes focus, so it needs no `webui` permission |
| **Sides** | client only. The server runtime has no `exports`, so there is no server surface and there cannot be one |
| **Exports** | six, all client: [`open`](exports.md#open), [`update`](exports.md#update), [`close`](exports.md#close), [`state`](exports.md#state), [`status`](exports.md#status), [`keys`](exports.md#keys) |
| **Commands** | none |
| **Events** | local only, on the client. Nothing crosses the wire — see [Events](events.md) |

## The surface {#surface}

The manifest declares the page but not its creation — `web_ui_auto_create false`
— because `client/main.lua` creates it, so a failure is one logged line rather
than a dead resource:

```lua
web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }
```

It is a `1920x1080`, transparent, 30 fps surface on the **`hud`** layer at
`zIndex` **725** — above the platform's chat (700) and toasts (720), below
`open77_admin`'s strip (730). The layer choice is load-bearing: a `menu` layer
surface can be focused and would swallow the player's input, and a `hud` one
never can.

!!! warning "A failed surface refuses, it does not pretend"

    The exports are published by `client/exports.lua` whether or not
    `WebUI.create` succeeded. When it failed, every export that would draw
    something answers `no_surface` rather than telling a caller `ok = true` for
    a menu nothing will ever draw. [`state`](exports.md#state) and
    [`keys`](exports.md#keys) still answer, because neither draws anything.

## One menu at a time {#one-menu}

There is one open menu on the client, or none. A second resource asking to open
one is refused with `menu_busy` unless it passes `steal = true`; the *same*
resource opening a second menu always replaces its own.

A replaced menu is **closed, not dropped**. The previous owner is entitled to
hear that it is gone, and receives a [`close` payload](events.md#payload) with
`reason = "reopened"` when the same owner reopened, or `"superseded"` when
another owner stole the surface.

The new spec is validated **before** the old menu is closed, so a caller that
hands over a malformed spec loses nothing: it is refused whole and whatever was
on screen stays there.

## A menu never outlives the code that opened it {#lifetime}

Every export call reads the caller from `GetInvokingResource()` and
`GetInvokingResourceGeneration()`. Both come from the host, so a caller can
neither claim to be another resource nor outlive its own reload. Three
mechanisms sit behind that, and each closes the menu with its own `reason`:

- **A caller that came back at a new generation.** The generation is recorded on
  every export call. A call at a different generation closes that owner's open
  menu with `reason = "owner_reloaded"` before doing anything else.
- **A caller that stopped or crashed.** A sweep runs once a second while a menu
  is open, checking that the owner is still `running` and still at the
  generation it opened at. A caller that died mid-menu loses its menu within
  that second, with `reason = "owner_stopped"`. A menu therefore outlives its
  owner by up to one second, never more.
- **`opx77_menu` itself stopping.** It closes the open menu with
  `reason = "menu_stopped"` from `onClientResourceStop`, while there is still a
  Lua state to say so in.

## The keyboard {#keyboard}

Six actions, and the key each drives. These are not an operator setting and
they are not rebindable: they are the keys everyone already tries on a list,
and the platform exposes no key-mapping API of any kind — `Open77.input` has
exactly `isDown` and `isCaptured`.

| Action | Key |
|---|---|
| `UP` | `UP` |
| `DOWN` | `DOWN` |
| `LEFT` | `LEFT` |
| `RIGHT` | `RIGHT` |
| `SELECT` | `ENTER` |
| `BACK` | `BACKSPACE` |

There is one backend and a failure state, picked once at resource start and
logged. `"poll"` means `Open77.input.isDown` answered and the six keys are
being read directly each frame. `"none"` means the keyboard cannot be read at
all, which in practice means the manifest did not grant `input.actions`; it is
logged as an error and the menu cannot be driven. [`keys`](exports.md#keys)
reports which of the two is live.

### Feel {#feel}

A held key fires once immediately, repeats after **260 ms**, then every
**55 ms**.

### Courtesy {#courtesy}

The menu stands down whenever another surface owns the keyboard — chat's
composer, the pause menu, an operator panel — rather than fighting for the
arrow keys. On every captured tick it also re-primes its edge state, so a key
pressed into chat cannot leak out of it and into the menu. The same priming
runs the instant a menu opens, because a menu is very often opened by a chat
command whose `ENTER` is still physically down.

The player opening the pause menu closes the open menu with `reason = "pause"`:
the plugin swallows Escape in the window procedure and raises
`open77:pauseKey` instead, and this resource listens for it.

### `LEFT` and `BACKSPACE` are not the same key {#left-vs-backspace}

Both pop one level, but they differ at the two edges:

- **`LEFT` belongs to the row first.** On a [`toggle`](menu-spec.md#kind-toggle),
  [`choices`](menu-spec.md#kind-choices) or [`slider`](menu-spec.md#kind-slider)
  row it changes the value instead of popping. That is decided by the row's
  *kind*, not by whether the value actually moved — so a slider already at its
  minimum does not unexpectedly throw the player up a level.
- **At the root they part ways.** `BACKSPACE` at the root closes the menu with
  `reason = "back"`. `LEFT` at the root does nothing.

## Treat the menu as optional {#optional}

Nothing forces a caller to hard-depend on this resource, and a declared
dependency on this platform is a hard one. [`opx77_elevators`](../opx77_elevators/index.md)
is the worked example: it owns no surface of its own and draws its floor panel
entirely through these exports, yet it checks
`GetResourceState("opx77_menu") == "running"` and answers `menu_not_running`
when it is not. A missing menu costs it one logged line and leaves its own
exports doing exactly what they did before.

## Where to go next {#next}

- [Exports](exports.md) — the six calls, their error codes and what each refuses.
- [The menu spec](menu-spec.md) — the spec table, the eight item kinds and every limit.
- [Events](events.md) — how a chosen row reaches you, and why there is no callback.
- [Configuration](config.md) — the three keys in `config.lua`.
- [Types](types.md) — every shape named on these pages.
- [The client export contract](../../concepts/export-contract.md) — how to call an export correctly, and the three levels of failure.
