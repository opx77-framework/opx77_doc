---
title: The WebUI page
description: Every screen in opx_infinity is drawn by one CEF page built from Vue sources; Lua talks to it on named channels through OPX.UI, and modules keep their rules apart from the view.
---

# The WebUI page

Everything a player sees from `opx_infinity` — HUD, menus, inventory, toasts,
name tags — is drawn by **one CEF page**, `web/index.html`. It is built from the
Vue sources in `ui/src/` with `npm run build`; only `web/` ships. Lua talks to
the page through [`OPX.UI`](../reference/core.md#opx-ui-send).

## Two layers in one page {#layers}

| Layer | What goes there | Focus |
|---|---|---|
| `overlay` | HUD, toasts, prompts, name tags | never takes the keyboard or the pointer |
| `modal` | anything the player drives: menu, form, panel, inventory | takes focus while open |

The page is created once by the client boot (`OPX.UI.Surface()`), before the
modules start, with the settings in
[`OPX.Config.CLIENT.SURFACE`](../reference/core-config.md#config-client-surface).

## Channels {#channels}

Lua and the page exchange messages on **channels** named `<module>:<verb>`, for
example `menu:open` or `menu:choose`. The surface adds an `opx:` prefix, so the
page sees `opx:menu:open`.

| Call | Direction | Use |
|---|---|---|
| [`OPX.UI.Send(target, channel, payload)`](../reference/core.md#opx-ui-send) | Lua → page | push state or open a view |
| [`OPX.UI.On(target, channel, handler)`](../reference/core.md#opx-ui-on) | page → Lua | receive an action; the handler only gets table payloads |
| [`OPX.UI.Serve(target, channel, handler)`](../reference/core.md#opx-ui-serve) | page → Lua → page | answer a request; the handler's return value is sent back with the request's `ref` |

Each page view emits `<module>:ready` when it mounts. A send made before the
page is ready is dropped, not queued. Every module page lists its channels in a
**Page channels** table; the core's own are in
[Runtime events and channels](../reference/runtime-events.md).

The page reports its own JavaScript errors on the `diag` channel, and the
diagnostics module forwards them to the server journal. The CEF console is not
visible anywhere else.

## Focus {#focus}

Several views may want the keyboard at once. The client keeps a **focus stack**:

| Call | Effect |
|---|---|
| [`OPX.UI.AcquireFocus(owner, { keyboard, cursor })`](../reference/core.md#opx-ui-acquirefocus) | puts `owner` on top; `keyboard` defaults to `true`, `cursor` to `false` |
| [`OPX.UI.ReleaseFocus(owner)`](../reference/core.md#opx-ui-releasefocus) | removes `owner`; focus falls to the next one |
| [`OPX.UI.FocusOwner()`](../reference/core.md#opx-ui-focusowner) | who holds it now |

The Escape key belongs to the platform's `open77_pause`; never bind it.

## Keep rules and drawing apart {#view-seam}

A module owns its state and rules but does not draw. It raises its `VIEW`
event (on the `opx:on:` channel) with what should be shown, and takes the
player's actions back through one function, `M.FromView(action, payload)`. One
file, usually `client/view.lua`, is the only one that knows the other end is a
CEF page. `modules/chat/client/view.lua` is the reference example.

Before you write a new Vue view, check whether the
[menu](../modules/menu.md), [form](../modules/form.md) or
[panel](../modules/panel.md) module can draw what you need. They are services
any module can use through their contracts.

## Colours come from the theme {#theme}

Do not hard-code a colour in a view. The [theme module](../modules/theme.md)
sends the server's palette (from `config/theme.lua`) to the page, which writes
it as CSS custom properties on `:root`. `ui/README.md` in the framework is the
binding style guide for views.
