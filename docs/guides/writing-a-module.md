---
title: Write a module for opx_infinity
description: Step by step, add a new module to opx_infinity — declaration, config, server and client halves, a contract, a network event, a command, text, and the manifest lines.
---

# Write a module

A module is the normal way to add a feature to OPX//77. It lives inside
`opx_infinity` under `modules/<id>/`, runs in the same Lua VM as every other
module, and can use their [contracts](../how-it-works/modules-and-contracts.md#contracts).
This guide builds a small module, `tips`, that lets a player tip another player
some money.

Read [Modules and contracts](../how-it-works/modules-and-contracts.md) and
[Server authority](../how-it-works/server-authority.md) first.

## 1. The files {#files}

```text
config/tips.lua                 settings
modules/tips/module.lua         declaration and event names
modules/tips/locales.lua        English and French text
modules/tips/server/main.lua    the rules
modules/tips/client/main.lua    the request
```

## 2. Declare it {#declare}

```lua
-- modules/tips/module.lua
local M = OPX.Modules.Declare{
	id = 'tips',
	side = 'both',
	fatal = false,
	requires = { 'character' },   -- money lives in the character contract
}

M.Event = {
	SEND = OPX.Event(OPX.Channel.NET, 'tips', 'send'),      -- client -> server
	SENT = OPX.Event(OPX.Channel.LOCAL, 'tips', 'sent'),    -- server-side announcement
}
```

## 3. Configure it {#config}

```lua
-- config/tips.lua
OPX.Config.MODULES.tips = {
	enabled = true,
	MAX_AMOUNT = 500,
	COOLDOWN_MS = 10000,
}
```

Read it as `M.Settings.MAX_AMOUNT` inside a phase, never at file scope (see
[Settings](../how-it-works/modules-and-contracts.md#settings)).

## 4. Text {#locales}

```lua
-- modules/tips/locales.lua
OPX.Locale.Register('en', {
	['tips.sent'] = 'You tipped {amount} eddies.',
	['tips.badAmount'] = 'That is not a valid tip.',
})
OPX.Locale.Register('fr', {
	['tips.sent'] = 'Vous avez donné un pourboire de {amount} eddies.',
	['tips.badAmount'] = "Ce n'est pas un pourboire valide.",
})
```

## 5. The server half {#server}

```lua
-- modules/tips/server/main.lua
local M = OPX.Modules.Get('tips')

local character   -- the contract, resolved in Start

local function send(source, target, amount)
	amount = math.floor(tonumber(amount) or 0)
	target = tonumber(target)
	if amount < 1 or amount > M.Settings.MAX_AMOUNT or target == nil or target == source then
		return OPX.Refuse(source, 'tips.badAmount', 'tips.send')
	end
	-- ... take from `source`, give to `target` through the character contract,
	-- refunding if the second half fails. See the character module page for
	-- the exact functions and their answers.
	OPX.Publish(M.Event.SENT, source, { target = target, amount = amount })
	OPX.NotifyLocale(source, 'tips.sent', { amount = amount }, 'success')
end

function M.Api()
	OPX.Api.Provide('tips', 1, {
		Send = send,
	})
end

function M.Start()
	character = OPX.Api.Require('character')

	RegisterNetEvent(M.Event.SEND, function(target, amount)
		local source = source          -- from the connection, never the payload
		if OPX.Cooling(source, 'tips.send', M.Settings.COOLDOWN_MS) then
			return OPX.Refuse(source, 'error.tooFast', 'tips.send')
		end
		send(source, target, amount)
	end)

	OPX.Command.Register('opx.tip', { help = 'tips.help' }, function(source, args)
		send(source, args[1], args[2])
	end)
end
```

Points to keep:

- `OPX.Publish` raises `opx:on:tips:sent` for **every resource on the server**
  (server `TriggerEvent` is host-wide). Give it a plain payload, never a live
  record, and list the event on [Public server events](../creators/server-events.md).
  For wiring between your own halves or other modules only, use an `opx:in:`
  name; it is still visible to other server resources, but not a promise.
- To let other resources **call** your module, add a wrapper to
  `core/server/exports.lua` (or `core/client/exports.lua`) and document it under
  [For creators](../creators/index.md).
- `source` comes from the connection. Re-check every value in the payload.
- [`OPX.Command.Register`](../reference/core.md#opx-command-register) instead of
  `RegisterCommand`, so the chat box knows the command. Use
  `{ restricted = true }` for a staff command; the host then checks
  `command.opx.tip` before the handler runs.
- Refuse with a code (`OPX.Refuse`), not a sentence.

## 6. The client half {#client}

```lua
-- modules/tips/client/main.lua
local M = OPX.Modules.Get('tips')

function M.Start()
	-- e.g. a target row or a menu row calls this
end

function M.Ask(target, amount)
	TriggerServerEvent(M.Event.SEND, target, amount)
end
```

Repeating client work goes through [`OPX.Scheduler.Every`](../how-it-works/scheduler.md);
screens go through the [menu](../modules/menu.md), [form](../modules/form.md)
or [panel](../modules/panel.md) contracts before you write a new Vue view.

## 7. List every file in the manifest {#manifest}

Add each file to `open77.lua`, one per line, after the modules you depend on and
after `config/<id>.lua`:

```lua
shared_script "config/tips.lua"

shared_script "modules/tips/module.lua"
shared_script "modules/tips/locales.lua"
server_script "modules/tips/server/main.lua"
client_script "modules/tips/client/main.lua"
```

A file that is not listed never loads, and nothing tells you. The framework's
test suite fails on an unlisted `.lua` file. If your module calls a native that
needs a new manifest permission, add it to the `permissions` block.

## 8. Check it {#check}

From the `opx_infinity` folder:

```bash
lua tests/run.lua
luac -p $(find . -name '*.lua' -not -name 'open77.lua')
```

Then deploy, restart, and look for `[module] tips started` in the journal.

## 9. Document it {#document}

Add `docs/modules/tips.md` to this site and a line in `mkdocs.yml`; see
[Contributing](contributing.md#new-module). The coverage check fails until every
command, event, contract function and config key has an entry.
