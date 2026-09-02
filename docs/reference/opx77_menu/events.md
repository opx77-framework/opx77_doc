---
title: opx77_menu events
description: How a chosen menu row reaches the resource that opened the menu — the caller-supplied event name, the global opx77:menu event, the payload every action carries, and why there is no callback channel on this platform.
---

# Events

This is how you get your answer. `opx77_menu` tells nobody anything by return
value: [`open`](exports.md#open) hands back a handle and then goes quiet, and
everything the player subsequently does arrives as a **local client event** that
you registered a handler for yourself.

## There is no callback {#no-callback}

!!! danger "You cannot pass a function to a menu item"

    The client runtime puts every export argument and every export result
    through a codec, and *a function does not serialise*. Handing `onSelect =
    function() … end` to [`open`](exports.md#open) does not fail loudly — it
    fails at the boundary, and your row does nothing forever.

    The return channel is an **event**, because it is the only channel there
    is. See [There is no callback channel](../../concepts/export-contract.md#no-callbacks).

The shape is: **you supply the event name, the service raises it, you receive it
with a bare `AddEventHandler`.** Your identifiers ride in the `data` table you
attached to the row, which comes back untouched in the payload.

This is not an `opx77_menu` invention. It is the platform's own callback
convention, and the first-party resources use it identically:

- `open77_zones` takes `enterEvent` and `exitEvent` names on `create`, and
  raises them with a plain `TriggerEvent(zone.enterEvent, { … })`.
- `open77_interactions` takes an `event` per choice, falls back to the
  interaction's own, and then raises the global `open77:interaction` when the
  two differ — exactly the resolution `opx77_menu` uses.
- `pursuit` is on the receiving end of the first: it registers
  `enterEvent = "pursuit:readyUpEnter"` with `open77_zones` and then listens
  with `AddEventHandler("pursuit:readyUpEnter", …)`. Two different resources,
  one bare local handler, and it works.

!!! info "The client's local event bus is host-wide"

    That last point is the one nothing you brought from FiveM prepares you for.
    On the client, `TriggerEvent` in `opx77_menu` reaches an `AddEventHandler`
    in *your* resource. The bus spans the whole host, not one VM. (The server
    is the exact opposite: server resources cannot reach each other at all.
    See [Integration channels](../../concepts/integration-channels.md#local-events).)

## How an event name is chosen {#name-resolution}

Every payload is raised on **at most two** names, resolved in this order:

1. The **row's own `event`**, if it declared one.
2. Otherwise the **menu's `event`**, if the spec declared one.
3. Then the global [`opx77:menu`](#opx77-menu) — unless that is already the
   name raised at step 1 or 2, in which case it is not raised twice.

A row whose menu declares no `event` and which declares none itself reaches
**only** the global event. That is a working configuration, not a mistake: a
caller that watches `opx77:menu` and filters on `payload.owner` never needs a
name of its own.

## Networked {#networked}

**None.** `opx77_menu` raises nothing on the wire and listens for nothing on the
wire. Everything on this page is a local client event, and there is no reason
for any handler here to be a `RegisterNetEvent`.

!!! warning "Do not register a menu event with `RegisterNetEvent`"

    A local `TriggerEvent` also reaches `RegisterNetEvent` handlers of the same
    name, so registering your menu event as a net event *appears* to work.
    What you have actually done is open the name to the server as well, and
    given yourself a permanent hazard: re-emitting a wire name from inside its
    own handler is a tick-paced, silent, infinite loop. Use
    `AddEventHandler`.

## Non-networked {#non-networked}

### Your own event name {#your-event}

Fires once for every action the player takes on a row that resolves to this
name — `select`, `change`, `open`, `back` — and once more when the menu closes,
whatever closed it.

```lua
AddEventHandler("myresource:garage", function(payload) end)
```

- payload: [`MenuPayload`](types.md#menupayload)
    - Always a table. Branch on `payload.action` first; see
      [The payload](#payload).

!!! warning "Your event name is not private, and the payload is not trusted"

    The client's local bus is host-wide, so **any** resource on the player's
    machine can raise your event name with any payload it likes. Check
    `type(payload) == "table"`, check `payload.action`, check
    `payload.owner == GetCurrentResourceName()` if it matters, and check the
    type of `data` before you index it. Do not spawn a thread per message
    either: a client resource is allowed 1024 tasks, and a loop empties that
    budget.

### opx77:menu {#opx77-menu}

Fires for every action on every menu on this client, whoever opened it — the
one place to watch all menu traffic at once.

```lua
AddEventHandler("opx77:menu", function(payload) end)
```

- payload: [`MenuPayload`](types.md#menupayload)
    - `payload.owner` names the resource that opened the menu, and
      `payload.menu` its id.

It is a name, not a setting: it is not configurable, because a caller that
wants a different one simply listens on its own. It is suppressed when it is
already the name resolved at step 1 or 2, so a menu that declares
`event = "opx77:menu"` gets exactly one payload per action, not two.

!!! warning "The payload is not trusted here either"

    Any resource on the player's machine can raise `opx77:menu`, and this
    handler sees traffic from every other resource's menus by design. Check
    `payload.owner` before you act on anything.

## The payload {#payload}

One shape, for every action.

| Field | Type | |
|---|---|---|
| `menu` | `string` | The menu's `id`. |
| `handle` | [`MenuHandle`](types.md#menuhandle) | Unique for the life of the client session. |
| `owner` | `string` | The resource that opened the menu. From the host, never from an argument. |
| `action` | [`MenuAction`](types.md#menuaction) | `"select"`, `"change"`, `"open"`, `"back"` or `"close"`. |
| `itemId` | `string \| nil` | The row's id. Absent on a menu-level `back` and on every `close`. |
| `label` | `string \| nil` | The row's label. Absent in the same two cases. |
| `index` | `integer` | The cursor's 1-based position within the current screen's full row list — not within the drawn window. |
| `depth` | `integer` | `1` at the root. |
| `value` | `any` | Boolean for a toggle, the chosen string for a choice list, the number for a slider, the row's own `value` string otherwise. **Absent** when no row is involved. |
| `data` | `table \| nil` | The row's own `data`, echoed untouched. |
| `menuData` | `table \| nil` | The menu's `data`, echoed untouched. |
| `reason` | `string \| nil` | On `close` only. See [Close reasons](#reasons). |

!!! warning "Read `value` by presence, not by truthiness"

    A `false` toggle is a legitimate value, and `nil` means *no row was
    involved*. The resource assigns `value` explicitly rather than folding it
    through an `and`/`or` for exactly this reason. Test `payload.value ~= nil`,
    then compare with `== true`.

## Which action sets what {#actions}

| Action | Raised by | `itemId` / `label` / `value` |
|---|---|---|
| `select` | `ENTER` on an [`action`](menu-spec.md#kind-action) row | Set. |
| `change` | A [`toggle`](menu-spec.md#kind-toggle), [`choices`](menu-spec.md#kind-choices) or [`slider`](menu-spec.md#kind-slider) row whose value actually moved | Set, and `value` is the **new** value. |
| `open` | A [`submenu`](menu-spec.md#kind-submenu) pushed by `ENTER` or `RIGHT` | Set, and `depth`/`index` already describe the **child** screen. |
| `back` | `ENTER` on a [`back`](menu-spec.md#kind-back) row | Set — this is how you tell it from the key. |
| `back` | `LEFT` or `BACKSPACE` popping a level | **Absent.** |
| `close` | The menu closing, for any reason at all | **Absent**, plus `reason`. |

A [`close`](menu-spec.md#kind-close) row raises no `select` — only the `close`
payload with `reason = "item"`. A slider that did not move raises nothing, and
a choice list of one entry can never move.

## Close reasons {#reasons}

`reason` is present on the `close` payload and on nothing else. Every close
carries one, so a handler can always tell why its menu went away.

| Reason | The menu closed because |
|---|---|
| `caller` | The owner called the [`close`](exports.md#close) export. |
| `select` | An `action` row fired with `close = true`, or the menu had `closeOnSelect`. |
| `item` | The player chose a [`close`](menu-spec.md#kind-close) row. |
| `back` | `ENTER` on a `back` row, or `BACKSPACE`, at the root — there was nothing left to pop. |
| `pause` | The player opened the pause menu. |
| `reopened` | The same owner opened another menu, replacing this one. |
| `superseded` | Another resource opened one with `steal = true`. |
| `owner_reloaded` | The owner called an export at a new generation: its code was reloaded under it. |
| `owner_stopped` | The once-a-second sweep found the owner no longer running, or running at a different generation. |
| `menu_stopped` | `opx77_menu` itself is stopping. |
| `closed` | The fallback when a close was requested with no reason. No shipped path produces it. |

!!! info "A `close` payload is the only reliable teardown signal"

    Seven of those eleven reasons are nothing you asked for. If your resource
    holds state while its menu is open — a camera, a frozen player, a held
    vehicle — release it from the `close` branch of your handler rather than
    after the export call that opened the menu, because the export call is not
    where the menu ends.

## Events opx77_menu listens for {#inbound}

### open77:pauseKey {#pausekey}

Raised by the platform when the player presses Escape — the plugin swallows the
key in the window procedure and raises this instead — and closes the open menu
with `reason = "pause"`.

```lua
AddEventHandler("open77:pauseKey", function() end)
```

Takes no payload. You do not need to do anything with it; it is listed so the
`pause` close reason has a visible cause. Handling it yourself is fine — it is
a local event like any other — but do not re-raise it.

## Example {#example}

The handler for the panel built in [A complete example](menu-spec.md#example).

```lua
-- a client file of your own resource
local MENU = "opx77_menu"
local EVENT = "myresource:vehicle"

local function call(name, ...)
  local promise, dispatchError = Open77.exports.call(MENU, name, ...)
  if not promise then return nil, dispatchError end
  local result, callError = promise:await()
  if callError then return nil, callError end
  if type(result) ~= "table" or not result.ok then
    return nil, type(result) == "table" and result.error or "no_result"
  end
  return result
end

-- A bare AddEventHandler: this is a LOCAL event and the client bus is host-wide.
AddEventHandler(EVENT, function(payload)
  -- Any resource on this machine can raise this name. Check before acting.
  if type(payload) ~= "table" then return end
  if payload.owner ~= GetCurrentResourceName() then return end

  local plate = type(payload.menuData) == "table" and payload.menuData.plate or nil

  if payload.action == "change" then
    if payload.itemId == "engine" then
      -- A false toggle is a real value: compare, never test truthiness.
      SetVehicleEngine(plate, payload.value == true)
    elseif payload.itemId == "livery" then
      SetVehicleLivery(plate, payload.value)   -- the chosen string
    elseif payload.itemId == "tint" then
      SetVehicleTint(plate, payload.value)     -- the number
    end
    return
  end

  if payload.action == "select" and type(payload.data) == "table" then
    local ok, why = OpenDoor(plate, payload.data.door)
    -- Best-effort: the menu may already be gone, which answers no_menu_open.
    CreateThread(function() call("status", ok and "done" or why, ok) end)
    return
  end

  if payload.action == "close" then
    -- Seven of the eleven reasons are nothing you asked for. Release here.
    ReleaseVehicleCamera(plate)
    Open77.log.info("panel gone: " .. tostring(payload.reason))
  end
end)
```
