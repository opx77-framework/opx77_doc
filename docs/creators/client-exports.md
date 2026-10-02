---
title: Client exports
description: The client exports opx_infinity publishes so another resource can open a menu or a form, show a toast, run a progress bar or play an animation on the local player, and how answers come back through an OnOpxEvent export.
---

# Client exports

A **client** script of another resource can use the OPX screens on the local
player: the [menu](../modules/menu.md), the [form](../modules/form.md), toasts,
the [progress bar](../modules/progress.md) and [animations](../modules/animations.md).
The exports are in `core/client/exports.lua`. They answer
`{ ok, value | error }` like the [server exports](server-exports.md), and the
callers allowed are [`CLIENT.EXPORTS.CALLERS`](../reference/core-config.md#config-client-exports)
(`'*'`, everyone, by default).

None of these exports yields, so the synchronous form is fine:

```lua
local answer = exports.opx_infinity:ShowToast({ message = 'Order ready', kind = 'success' })
```

Everything here acts on **this player's screen only**. The server must still
check anything that matters.

## Getting answers back: the reply export {#replies}

A menu row chosen, a form answered or a bar that ended happens later. A function
cannot be passed to another resource, and a client `TriggerEvent` does not leave
`opx_infinity`, so the answer is delivered by **calling an export of yours**.
Publish this once in your client script:

```lua
-- my_shop/client/main.lua
exports('OnOpxEvent', function(event, payload)
	TriggerEvent(event, payload)   -- re-raise it on your own resource's bus
end)
```

From then on every answer arrives in your resource as an ordinary event:

| Event (on your bus) | Sent after | Payload |
|---|---|---|
| `opx:on:menu:action` | every action on a menu you opened | the menu's [action payload](../modules/menu.md#the-action-payload) |
| `opx:on:form:answer` | a form you opened is submitted or cancelled | the form's [answer](../modules/form.md#the-answer) |
| `opx:on:progress:done` | a bar you started ends | `{ owner, label, ending, finished }`; only `finished = true` means the action completed |
| `opx:on:animations:result` | the server's verdict on an animation you asked for | `{ requestId, action, ok, error?, animation?, variant?, playbackId?, ... }` |

In each payload `owner` is your resource name. The export is called
[`CLIENT.EXPORTS.REPLY`](../reference/core-config.md#config-client-exports)
(`OnOpxEvent`) unless the call names another one with `reply`. If your resource
does not publish it, the answer is lost and the client log says
`[exports] <you> did not take <event> through its OnOpxEvent export: ...`.

## The exports {#exports}

| Export | Arguments | `value` on success | Notes |
|---|---|---|---|
| <a id="export-client-openmenu"></a>`OpenMenu` | `spec` | `{ handle, id, nodes }` | The [menu spec](../modules/menu.md#the-menu-spec) without functions: `owner`, `on` and `steal` are set by OPX (any you pass are ignored). Rows carry an `id` you read back as `itemId`. Optional `spec.reply` names your reply export. Answers `menu_busy` when another owner's menu is open. |
| <a id="export-client-updatemenu"></a>`UpdateMenu` | `handle, spec` | `true` | Patch your open menu (fields as the menu's `Update`). `stale_handle` if the handle is not one of yours. |
| <a id="export-client-closemenu"></a>`CloseMenu` | `handle` | `true` | Closes your menu (`reason = 'caller'`). `stale_handle` if not yours. |
| <a id="export-client-openform"></a>`OpenForm` | `spec` | `{ handle, id, fields }` | The [form spec](../modules/form.md#the-form-spec) without `owner`/`on`. Optional `spec.reply`. Answers `form_busy` when another form is open. |
| <a id="export-client-closeform"></a>`CloseForm` | `handle` | `true` | Cancels your form. `stale_handle` if not yours. |
| <a id="export-client-showtoast"></a>`ShowToast` | `definition` | the toast id | `{ message, kind?, title?, icon?, durationMs?, id? }`. `message` is cut to 240 characters, `title` to 64. `icon` is a [glyph name](../reference/core.md#opx-toast-show). An `id` (letters, digits, `_ - .`, max 48) is kept in your own namespace, so showing the same `id` again replaces your toast. |
| <a id="export-client-dismisstoast"></a>`DismissToast` | `id` | `true` | The `id` you gave `ShowToast`. |
| <a id="export-client-startprogress"></a>`StartProgress` | `spec` | `{ owner, durationMs }` | `{ label, durationMs, cancelable?, animation? = { name, variant? }, reply? }`. One bar at a time for the whole player (`progress_busy`). See the [progress module](../modules/progress.md). |
| <a id="export-client-stopprogress"></a>`StopProgress` | — | as the module's `Stop` | Stops your bar; you get `opx:on:progress:done` with `ending = 'stopped'`. |
| <a id="export-client-playanimation"></a>`PlayAnimation` | `name, options?, reply?` | `{ queued = true, requestId, animation, variant }` | Asks the server to play an emote on the local player. `options` as the module's [Play options](../modules/animations.md#play-options). The verdict comes back as `opx:on:animations:result` with the same `requestId`. |
| <a id="export-client-stopanimation"></a>`StopAnimation` | — | as the module's `Stop` | Stops the animation you started. |

Errors: `export.callerDenied`, `export.badArgument`, `error.unavailable` (the
module is not running), `stale_handle`, and the codes of the module behind the
export (for example `menu_busy`, `form_busy`, `progress_busy`, or a spec error
such as `invalid_items`).

## Subscribing to OPX client events {#subscribe}

A client `TriggerEvent` stays inside `opx_infinity`, so your resource cannot hear
its client events directly. `Subscribe` forwards one event to your
[reply export](#replies) every time it is raised, until you unsubscribe or your
resource stops.

| Export | Arguments | `value` on success | Notes |
|---|---|---|---|
| <a id="export-client-subscribe"></a>`Subscribe` | `event, reply?` | `true` | Starts forwarding `event` to your reply export (`reply`, or `CLIENT.EXPORTS.REPLY`). Subscribing again just changes the reply export. Errors `export.notSubscribable`, `export.badArgument`, `export.callerDenied`. |
| <a id="export-client-unsubscribe"></a>`Unsubscribe` | `event` | `true` if you were subscribed, else `false` | Errors `export.notSubscribable`, `export.badArgument`. |

Each event arrives as `(event, payload)` with **one table**:

| Event | Payload |
|---|---|
| `opx:on:character:loaded` | the character's PlayerData **without `metadata`** |
| `opx:on:character:unloaded` | `{}` |
| `opx:on:character:changed` | PlayerData without `metadata` |
| `opx:on:character:money` | `{ moneyType, amount, action, balance }` (one table, not four arguments) |
| `opx:on:character:job` | the primary job table |
| `opx:on:character:gang` | the primary gang table |
| `opx:on:downed:changed` | `{ down, waiting }` |
| `opx:on:inventory:changed` | `{ inventory, changes }` (see [inventory](../modules/inventory.md#events)) |
| `opx:on:inventory:used` | `{ name, slot, label, close, status?, animation? }` |
| `opx:on:inventory:opened` | `{}` |
| `opx:on:inventory:closed` | `{}` |
| `opx:on:needs:changed` | `{ values, changed, source, citizenId, ready }` |
| `opx:on:progress:state` | `{ open, owner?, label? }`. `owner` is your own resource name for your bar; a bar drawn by **another** resource comes with no `owner`. |

No other event can be subscribed to (`export.notSubscribable`).

```lua
-- my_hud/client.lua
exports('OnOpxEvent', function(event, payload) TriggerEvent(event, payload) end)

CreateThread(function()
	exports.opx_infinity:Subscribe('opx:on:character:money')
end)

AddEventHandler('opx:on:character:money', function(p)
	print(('balance %s is now %d'):format(p.moneyType, p.balance))
end)
```

## Ownership {#ownership}

- Your screens are kept under the owner `ext:<your resource>`. You can update,
  close or stop only what you opened, and you never take over another owner's
  menu or form.
- When your resource stops, OPX closes your menus and forms, stops your bar and
  your animation.

## Example: a shop menu {#example}

```lua
-- my_shop/client/main.lua
exports('OnOpxEvent', function(event, payload) TriggerEvent(event, payload) end)

local function openShop()
	local answer = exports.opx_infinity:OpenMenu({
		title = 'NIGHT MARKET',
		closeOnSelect = true,
		items = {
			{ id = 'water', label = 'Water', value = '5 €$' },
			{ id = 'burrito', label = 'Burrito', value = '12 €$' },
		},
	})
	if not answer.ok then print('menu refused: ' .. answer.error) end
end

AddEventHandler('opx:on:menu:action', function(p)
	if p.action == 'select' and p.itemId then
		-- ask YOUR server to sell it; the server checks and charges
		TriggerServerEvent('my_shop:buy', p.itemId)
	end
end)
```

On the server, `my_shop:buy` re-checks the item and the player, then charges
with [`RemoveMoney`](server-exports.md#money) and gives with
[`AddItem`](server-exports.md#items), both awaited.
