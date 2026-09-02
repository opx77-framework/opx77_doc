---
title: opx77_hud exports
description: The three client exports opx77_hud publishes — setVisible, isVisible and vanilla — which control the HUD surface and report what became of the game's own HUD.
---

# Exports

`opx77_hud` publishes three client exports. The first two control **the
rectangle, not the character drawn in it**: hiding the HUD does not stop it
following the core, and showing it again does not need a refresh. The third
reports what became of *Cyberpunk's own* HUD, which this resource turns off at
boot so that its health bar and clock are not drawn underneath this one.

!!! info "Read the export contract first"
    There is no `exports.opx77_hud:setVisible()` proxy. The only entry point is
    `Open77.exports.call`, it is always asynchronous, and failure reads at three
    levels. See [The client export contract](../../concepts/export-contract.md).

## setVisible {#setvisible}

Shows or hides the whole surface and answers the visibility it ended up with;
it never answers `ok = false` and never returns `nil`.

!!! warning "Nothing else puts it back"
    The visibility flag is this resource's own. No event, no character change and
    no reconnect of the core resets it — only another `setVisible`, the
    [`/hud`](commands.md#hud) command, or the player reconnecting. If you hide the
    HUD around something that can fail, restore it in the same thread that hid it.

```lua
Open77.exports.call("opx77_hud", "setVisible", value)
```

- value: `boolean`
    - `false` hides the surface. **Any other value shows it**, including `nil`
      and a table — the test is `value ~= false`, not a truthiness test.

**Returns** `table` — `{ ok = true, visible = boolean }`. `visible` is the
resulting state, not the requested one.

**Errors**

| Code | Meaning |
|---|---|
| — | The export itself never refuses. `ok` is always `true`. |
| `export_not_found` (level 1) | `opx77_hud` is not running, or is mid-reload. Returned as the second value of `Open77.exports.call`, not inside a result. |
| *any* (level 2) | The call was dispatched and resolution failed. Returned as `callError` from `promise:await()`. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It needs no permission.

### Example {#setvisible-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_hud", "setVisible", false)
  if not promise then return print("not dispatched: " .. tostring(reason)) end

  local result, callError = promise:await()
  if callError then return print("call failed: " .. tostring(callError)) end
  if not result.ok then return end

  playTheCutscene()

  -- restored in the same thread that hid it
  local restore = Open77.exports.call("opx77_hud", "setVisible", true)
  if restore then restore:await() end
end)
```

## isVisible {#isvisible}

Answers whether the surface is currently shown; it never answers `ok = false`
and never returns `nil`.

The flag it reports is the surface's, not the character's. `isVisible` can be
`true` while nothing is on screen, because no character is loaded and no chip is
live — see [what actually hides the surface](events.md#hud-hide).

```lua
Open77.exports.call("opx77_hud", "isVisible")
```

**Returns** `table` — `{ ok = true, visible = boolean }`

**Errors**

| Code | Meaning |
|---|---|
| — | The export itself never refuses. `ok` is always `true`. |
| `export_not_found` (level 1) | `opx77_hud` is not running, or is mid-reload. |
| *any* (level 2) | The call was dispatched and resolution failed. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It needs no permission.

### Example {#isvisible-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise = Open77.exports.call("opx77_hud", "isVisible")
  if not promise then return end
  local result = promise:await()
  if result and result.ok and not result.visible then
    -- the player has hidden their HUD; do not fight them for it
  end
end)
```

## vanilla {#vanilla}

Answers what became of the game's own HUD on this client. Read-only: it never
answers `ok = false` and never returns `nil`.

There is deliberately no setter. The game's HUD is this resource's to hide
because this resource draws the replacement; a second opinion arriving from
another resource is how a player ends up with neither HUD. To change which
components are hidden, edit [`VANILLA`](config.md#vanilla) in `config.lua`.

```lua
Open77.exports.call("opx77_hud", "vanilla")
```

**Returns** `table` — `{ ok = true, available = boolean, found = table|nil, state = table|nil }`

| Field | Meaning |
|---|---|
| `available` | Whether `Open77.hud` exists on this client at all. `false` on a client older than the `ui.vanilla.hud` capability, and then nothing was hidden. |
| `found` | Component → the visibility it had **before** this resource touched it, which is what is put back when the resource stops. `nil` until the first apply. A component the client would not report reads `nil` and is left alone on the way out. |
| `state` | Whatever `Open77.hud.state()` reports right now, verbatim, or `nil` if the client will not say. |

**Errors**

| Code | Meaning |
|---|---|
| — | The export itself never refuses. `ok` is always `true`. |
| `export_not_found` (level 1) | `opx77_hud` is not running, or is mid-reload. |
| *any* (level 2) | The call was dispatched and resolution failed. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It needs no permission; the `ui.vanilla.hud`
capability is declared by `opx77_hud`'s own manifest, not by yours.

### Example {#vanilla-example}

```lua
-- a client script in your own resource: is the vanilla minimap still on screen,
-- and if so, why?
CreateThread(function()
  local promise = Open77.exports.call("opx77_hud", "vanilla")
  if not promise then return end
  local result = promise:await()
  if not (result and result.ok) then return end

  if not result.available then
    -- this client predates Open77.hud; nothing could be hidden
    return
  end

  local live = result.state
  if live and live.minimap == true then
    -- the API exists and the component is still shown: it was left out of
    -- VANILLA, or the client refused the call
  end
end)
```

## A server resource cannot call these {#from-the-server}

Server resources have no `exports` and no cross-resource bus on this platform.
A server plug-in that wants the HUD hidden registers its own net event, sends it
to the player with `TriggerClientEvent`, and calls `setVisible` from the client
handler in its own resource. See
[Integration channels](../../concepts/integration-channels.md#wire-events).

`opx77_hud`'s own [`opx77_hud:visibility`](events.md#visibility) net event is not
a public API — it is the `/hud` answer, and it carries a mode string rather than
a boolean.
