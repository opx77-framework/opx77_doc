--- dump-surface.lua -- print the public surface opx_infinity actually registers.
--
-- Run FROM THE ROOT OF AN opx_infinity CHECKOUT, with desktop Lua 5.4 and the
-- opx_lib checkout beside it (or OPX_LIB_PATH pointing at one), exactly as the
-- framework's own `lua tests/run.lua` needs:
--
--   cd ../opx_infinity && lua ../opx77_doc/scripts/dump-surface.lua
--
-- It boots the real manifest against the framework's own stub platform
-- (`tests/host.lua`), once per runtime, and prints one line per published name:
--
--   module    <side> <id> <state>
--   contract  <side> <name> <version>
--   api       <side> <contract> <Member> <lua type>
--   command   <name> <restricted|open> <owner module|core>
--   alias     <alias> <command>
--   export    <side> <name>                an Open77 export another resource may call
--   net       <side> <event> <owner module|core>
--   event     <module> <event>             a name in a module's M.Event table
--   channel   <channel> <owner module|core> a page -> Lua channel the client listens on
--   config    <module> <KEY>               a top-level key of OPX.Config.MODULES[id]
--   coreconfig <shared|server|client> <KEY> a top-level key of OPX.Config.SHARED/SERVER/CLIENT
--   core      <OPX.Path>                   a function on the OPX namespace
--
-- Booting rather than grepping is the point: two thirds of the commands are
-- registered under a name held in a variable or a config table, which no
-- regular expression over the source can see. The owner of a registration is
-- read from `OPX.Api.Owner`, which the lifecycle sets while a module's phase
-- runs; a registration made outside a phase (a file-scope handler in core/, or
-- one made later from a thread) is reported as `core`.

local Host = dofile('tests/host.lua')

local out = {}
local function emit(...) out[#out + 1] = table.concat({ ... }, ' ') end

local commandOwner, netOwner, channelOwner = {}, {}, {}

local function ownerOf(env)
	local api = env.OPX and env.OPX.Api
	return (api and api.Owner) or 'core'
end

local function boot(side)
	local env, control = Host.Environment(side)
	local wrapped = false
	for _, file in ipairs(Host.LoadOrder('open77.lua', side)) do
		local chunk, why = loadfile(file, 't', env)
		if not chunk then error(('%s: %s'):format(file, why)) end
		local ok, failure = pcall(chunk)
		if not ok then error(('%s: %s'):format(file, failure)) end
		-- Wrap the page listeners as soon as core/client/ui.lua has defined them
		-- and before any module's phase registers one.
		if side == 'client' and not wrapped and env.OPX and env.OPX.UI and env.OPX.UI.On then
			wrapped = true
			for _, verb in ipairs({ 'On', 'Serve' }) do
				local original = env.OPX.UI[verb]
				-- `Serve` was removed from the runtime (PR #71): wrapping a missing
				-- verb would publish a function the framework does not have.
				if type(original) == 'function' then
					env.OPX.UI[verb] = function(target, channel, ...)
						if type(channel) == 'string' and channelOwner[channel] == nil then
							channelOwner[channel] = ownerOf(env)
						end
						return original(target, channel, ...)
					end
				end
			end
		end
	end

	-- Every file has run and no phase has: from here on a registration happens
	-- inside a module's phase, and the lifecycle names the module.
	local register, net = env.RegisterCommand, env.RegisterNetEvent
	env.RegisterCommand = function(name, ...)
		if type(name) == 'string' then commandOwner[name:lower()] = ownerOf(env) end
		return register(name, ...)
	end
	env.RegisterNetEvent = function(name, ...)
		if type(name) == 'string' then netOwner[side .. ' ' .. name] = ownerOf(env) end
		return net(name, ...)
	end

	if side == 'client' then control.Fire('onClientResourceStart', 'opx_infinity') end
	control.Pump(400)
	if control.ReadyPages then control.ReadyPages() end
	control.Pump(40)
	return env, control
end

local function sorted(set)
	local list = {}
	for key in pairs(set) do list[#list + 1] = key end
	table.sort(list)
	return list
end

local commands, events, core = {}, {}, {}

local function walk(prefix, value, depth, seen)
	if seen[value] then return end
	seen[value] = true
	for key, field in pairs(value) do
		if type(key) == 'string' then
			local path = prefix .. '.' .. key
			if type(field) == 'function' then
				core[path] = true
			elseif type(field) == 'table' and depth < 2 and key ~= 'Config' and key ~= 'Lib'
				and key ~= 'Glyphs' then
				walk(path, field, depth + 1, seen)
			end
		end
	end
end

for _, side in ipairs({ 'server', 'client' }) do
	local env, control = boot(side)
	local OPX = env.OPX

	for _, record in ipairs(OPX.Modules.All()) do
		emit('module', side, record.Id, record.State)
		local namespace = OPX.Modules.Get(record.Id)
		if type(namespace) == 'table' and type(namespace.Event) == 'table' then
			for _, name in pairs(namespace.Event) do
				if type(name) == 'string' then events[record.Id .. ' ' .. name] = true end
			end
		end
	end

	local versions = OPX.Api.Versions()
	for _, name in ipairs(sorted(versions)) do
		emit('contract', side, name, tostring(versions[name]))
		local implementation = OPX.Api.Get(name)
		for key, field in pairs(implementation or {}) do
			if type(key) == 'string' then emit('api', side, name, key, type(field)) end
		end
	end

	for name, entry in pairs(control.commands) do
		commands[name] = (entry.restricted and 'restricted' or 'open') .. ' '
			.. (commandOwner[name] or 'core')
	end

	for _, name in ipairs(sorted(control.exports or {})) do emit('export', side, name) end

	for _, name in ipairs(sorted(control.netEvents)) do
		emit('net', side, name, netOwner[side .. ' ' .. name] or 'core')
	end

	if side == 'server' then
		for id, settings in pairs(OPX.Config.MODULES) do
			if type(settings) == 'table' then
				for key in pairs(settings) do
					if type(key) == 'string' then emit('config', id, key) end
				end
			end
		end
		local server = OPX.Config.SERVER or {}
		for command, alias in pairs(server.COMMAND_ALIASES or {}) do
			emit('alias', tostring(alias):lower(), command)
		end
	end

	-- The runtime-wide configuration roots: SHARED on both, SERVER and CLIENT on one.
	for _, root in ipairs({ 'SHARED', side == 'server' and 'SERVER' or 'CLIENT' }) do
		for key in pairs(OPX.Config[root] or {}) do
			if type(key) == 'string' then emit('coreconfig', root:lower(), key) end
		end
	end

	-- The core's own surface. `Config` and `Lib` are data and the client library.
	local root = {}
	for key, value in pairs(OPX) do
		if key ~= 'Config' and key ~= 'Lib' then root[key] = value end
	end
	walk('OPX', root, 0, {})
end

local aliases = {}
for _, line in ipairs(out) do
	local alias = line:match('^alias (%S+)')
	if alias then aliases[alias] = true end
end

for _, name in ipairs(sorted(commands)) do
	-- An alias is a second host registration of a command; it is reported on its
	-- own `alias` line rather than as a command of its own.
	if not aliases[name] then emit('command', name, commands[name]) end
end
for _, line in ipairs(sorted(events)) do emit('event', line) end
for _, channel in ipairs(sorted(channelOwner)) do emit('channel', channel, channelOwner[channel]) end
for _, path in ipairs(sorted(core)) do emit('core', path) end

table.sort(out)
print(table.concat(out, '\n'))
