---
title: opx77_lib — the copy-in snippet library
description: The twenty-odd helper lines every OPX//77 satellite re-types — finite, clamp, nowMs, displayText, response and the three-level export-call contract — reconciled into one versioned file you paste into your own resource, because a shared library resource is impossible on this platform.
---

# opx77_lib

**`opx77_lib` is source, not a service.** It is not a resource, you do not
install it, it publishes no exports and nothing on your server loads it. It is
a file on this page that you copy into your own resource.

That is not a stylistic preference. It is the only shape a shared library can
take on this platform, and the reason is worth two paragraphs because it also
explains several other things about OPX//77.

## Why a library resource is impossible {#why-copy-in}

Three facts, each verified against the shipped server binary rather than the
documentation:

1. **`require` is `nil` on the server.** The runtime's sandbox sets nine
   globals to `nil` before any resource code runs — `io`, `os`, `debug`,
   `package`, `dofile`, `loadfile`, `load`, `collectgarbage` and `require`.
   There is no module system on the server at all.
2. **On the client `require` exists, and is confined to the calling
   resource.** `require("shared.helpers")` resolves
   `<your resource>/shared/helpers.lua`, then
   `<your resource>/shared/helpers/init.lua`. There is no `@resource/file`
   include syntax, and no path that leaves your own directory.
3. **`Open77.resource.readFile` is confined too.** It is the only general
   file-reading primitive, and it *"does not grant access to the repository,
   the game directory, another resource, or an absolute path"*.

So there is no mechanism — none — by which one resource can hand Lua source to
another. The runtime's only cross-resource channel is a **client** export,
which puts every argument and every result through a bounded value codec:
*"Lua objects are never shared between states"*, and a function cannot cross
the boundary at all. You could publish `finite` as an export; you would get an
asynchronous, serialising, promise-returning round trip to test whether a
number is a number.

And on the **server** even that is gone: no `exports`, no
`GetInvokingResource`, no cross-resource event bus.

!!! info "This is the same constraint that shapes the whole framework"
    It is why there is no `getSharedObject()`, why a plug-in that needs server
    authority is a file added to `opx77_core` rather than a resource of its
    own, and why [the export contract](../concepts/export-contract.md) reads
    the way it does. A copy-in snippet is the honest answer here, in the same
    way that `ox_lib` is the honest answer on a platform that has real
    modules.

## What copying costs, and how the version pays for it {#versioning}

Copying has one real failure mode: six copies drift and nobody notices. That is
exactly what happened in this framework — `finite()` is written five times
across the satellites in three mutually incompatible ways, and one of them
**accepts infinity despite its name**.

The file below is the reconciliation. Every function is the strictest correct
behaviour of the copies it replaces, and it carries a `VERSION` field so that
the question *"which copy is this?"* has an answer:

```lua
if OPX_LIB.VERSION ~= "1.0.0" then
  Open77.log.warn("opx77_lib copy is " .. OPX_LIB.VERSION .. ", not 1.0.0")
end
```

**Current version: `1.0.0`.**

## Installing it {#installing}

Save the [source](#source) as `shared/opx77_lib.lua` inside **your** resource
and list it in your manifest before anything that uses it:

```lua
-- your_resource/open77.lua
shared_script "shared/opx77_lib.lua"
```

!!! danger "Do not create a directory for it under `resources/`"
    `server.jsonc` loads `resources/*`. A folder there without a valid manifest
    is picked up as a broken resource and refused, and on the client half a
    refused resource takes the whole session's resource set with it — nobody
    can connect. This is a file inside a resource you already have, never a
    resource of its own.

It defines one global, `OPX_LIB`. Globals are per-resource — each resource
receives its own Lua state — so that name is private to you and cannot collide
with anything. Rename it if it reads better inside your own namespace.

## What is in it {#contents}

| Function | Side | Replaces |
|---|---|---|
| [`isFinite`](#isfinite) | both | the boolean `finite()` in `opx77_hud`, `opx77_menu`, `opx77_status` |
| [`finite`](#finite) | both | the coercing `finite()` in `opx77_core`, `opx77_elevators` |
| [`integer`](#integer) | both | `integer()` in `opx77_elevators` (twice) |
| [`clamp`](#clamp) | both | `OPX.Math.clamp` |
| [`percent`](#percent) | both | `percent()` in `opx77_hud` |
| [`nowMs`](#nowms) | both | `nowMs()` in all six satellites |
| [`displayText`](#displaytext) | both | `displayText()` in `opx77_menu`, `opx77_status` |
| [`identifier`](#identifier) | both | `validName()` in `opx77_menu`, `opx77_status` |
| [`response`](#response) | client | `response()` in four satellites |
| [`caller`](#caller) | client | `caller()` in four satellites |
| [`call`](#call) | client | `Runtime.call` / `core()` in `opx77_elevators`, `opx77_hud` |

---

## isFinite {#isfinite}

Returns `true` only for a real, finite number, and `false` for everything else
including a numeric string.

```lua
OPX_LIB.isFinite(value)
```

- value: `any`

**Returns** `boolean`

**Side** both — pure, no host call.

`value ~= value` is the NaN test and not a typo. NaN arrives through JSON from
a client, passes every comparison it is put through, and poisons any sum it
lands in. Both infinities are rejected too: a predicate named `finite` that
accepts `math.huge` is precisely the bug this reconciliation exists to remove.

Use this when a non-number must be **refused**; use [`finite`](#finite) when it
should be parsed.

### Example {#isfinite-example}

```lua
if not OPX_LIB.isFinite(payload.radius) then
  return OPX_LIB.response(false, { error = "invalid_radius" })
end
```

---

## finite {#finite}

Coerces a value to a finite number, or returns `nil` when it is not one.

```lua
OPX_LIB.finite(value, limit)
```

- value: `any`
- limit?: `number`
    - Reject a magnitude above this. For a value with a known domain — world
      coordinates, a duration in milliseconds — a bound turns "technically a
      number" into "a number that could be true".

**Returns** `number|nil`

**Side** both — pure, no host call.

This is the one to use on anything that came off the wire, out of JSON, or out
of a caller's table, where `"120"` and `120` should both be accepted.

`opx77_elevators` bounds its coordinates at `1000000`; that is what `limit` is
for, and it is deliberately not a default — a money amount and a world
coordinate do not share a ceiling.

### Example {#finite-example}

```lua
local radius = OPX_LIB.finite(spec.radius, 1000000)
if radius == nil then return OPX_LIB.response(false, { error = "invalid_radius" }) end
```

---

## integer {#integer}

Coerces a value to a whole number, or returns `nil`; a fractional value is
refused rather than rounded.

```lua
OPX_LIB.integer(value, limit)
```

- value: `any`
- limit?: `number`
    - As [`finite`](#finite).

**Returns** `integer|nil`

**Side** both — pure, no host call.

Refused, never rounded: a caller that meant `3` and sent `3.5` has a bug, and
rounding hides it behind behaviour that looks correct until it does not.

---

## clamp {#clamp}

Confines a number to a range.

```lua
OPX_LIB.clamp(value, low, high)
```

- value: `number`
- low: `number`
- high: `number`

**Returns** `number`

**Side** both — pure, no host call.

!!! warning "NaN survives a clamp untouched"
    Both comparisons are false for NaN, so it falls through and is returned as
    it arrived. That is not a defect in `clamp` — it is why
    [`finite`](#finite) exists. Pass anything that came from outside through
    `finite` first; `clamp` assumes it already holds a real number.

---

## percent {#percent}

Returns a `0`–`100` integer for a bar, a fill or a percentage row, answering
`0` for anything unusable.

```lua
OPX_LIB.percent(value)
```

- value: `any`

**Returns** `integer` — `0` to `100`

**Side** both — pure, no host call.

Unusable input gives `0` rather than `nil` because a gauge is cosmetic:
refusing to draw one is a worse outcome than drawing an empty one, and a `nil`
here reaches a web page as a missing property that renders as `NaN%`.

### Example {#percent-example}

```lua
page:send("hud:frame", {
  health = OPX_LIB.percent(data.metadata.health),
  hunger = OPX_LIB.percent(data.metadata.hunger),
  thirst = OPX_LIB.percent(data.metadata.thirst),
})
```

---

## nowMs {#nowms}

Returns milliseconds since the host started.

```lua
OPX_LIB.nowMs()
```

**Returns** `integer`

**Side** both — reads the host clock.

!!! warning "`Open77.time.monotonic()` answers SECONDS"
    On both sides. The platform's API reference says so, and the host's own Lua
    bootstrap defines `monotonic` as the millisecond scheduler clock divided by
    1000. Three files in this framework carry — or carried — a comment claiming
    the reference says milliseconds; the reference is right and the comments
    were wrong. Treating the value as milliseconds gives a timer that fires a
    thousand times too early, which presents as a loop that will not stop
    rather than as a wrong number.

This is not `GetGameTimer()`. On the client that native exists and is a
different clock; on the server it is defined by the bootstrap and is the same
scheduler clock. Pick one and stay with it — the core uses `OPX.Now()`, which
prefers `GetGameTimer` and falls back to this.

---

## displayText {#displaytext}

Sanitises text a caller offered for display — control characters become spaces,
then the result is truncated on a UTF-8 character boundary — returning `nil`
only for a value that is not text at all.

```lua
OPX_LIB.displayText(value, maxBytes)
```

- value: `any`
    - A string, or a number, which is rendered with `tostring`.
- maxBytes: `integer`
    - The ceiling in **bytes**, not characters. A label budget is a byte budget
      wherever it is stored or sent.

**Returns** `string|nil`

**Side** both — pure, no host call.

Cleaned rather than refused. Cosmetic text is never worth failing a whole call
over a stray tab, so the only `nil` is for a table, a boolean or a function.

Two things this does that the copies it replaces did not:

- **It truncates on a character boundary.** The satellite copies cut at
  `#value` bytes, which splits a multi-byte sequence in half. Half a character
  is bytes no page can render, and on a CEF surface it is a mojibake that
  outlives the message.
- **It matches control characters as an explicit byte range**,
  `[\0-\31\127]`, rather than `%c`, whose meaning above `0x7F` depends on the
  C locale. These are the bytes that forge a line in a log, a row in a chat
  box, or a node in a web page.

### Example {#displaytext-example}

```lua
local label = OPX_LIB.displayText(spec.label, 96)
if label == nil then return OPX_LIB.response(false, { error = "invalid_label" }) end
```

---

## identifier {#identifier}

Returns `true` for a machine-readable identifier: ASCII letters, digits, `_`,
`-`, `.` and `:`, non-empty and within a byte budget.

```lua
OPX_LIB.identifier(value, maxBytes)
```

- value: `any`
- maxBytes: `integer`

**Returns** `boolean`

**Side** both — pure, no host call.

For an id, an event suffix, a menu row name. Measured in bytes because that is
how it is compared and concatenated.

A resource name is stricter than this — it carries no colon — which is why
[`caller`](#caller) has its own pattern rather than reusing this one.

---

## response {#response}

Builds the answer shape every OPX//77 export gives: a plain table carrying
`ok`, and an `error` code when `ok` is `false`.

```lua
OPX_LIB.response(ok, values)
```

- ok: `boolean`
- values?: `table`
    - The rest of the answer. Mutated in place and returned, so do not pass a
      table you still hold a reference to.

**Returns** `table` — `values` with `ok` set

**Side** `client` — this is what an `exports(...)` body returns. Nothing stops
you calling it on the server; there is simply nowhere for the value to go.

A plain table and not the core's `OPX.Result`, because the value crosses the
runtime's codec and lands in a resource that has no `Result` loaded. On refusal
put a stable string code in `error` — a locale key, so a UI can render it in
the player's language through the core's `Locale` export. See [the export
contract](../concepts/export-contract.md#level-3).

### Example {#response-example}

```lua
exports("setVisible", function(value)
  local owner = OPX_LIB.caller()
  if owner == nil then
    return OPX_LIB.response(false, { error = "export_call_required" })
  end
  return OPX_LIB.response(true, { visible = Runtime.setVisible(value) })
end)
```

---

## caller {#caller}

Returns which resource is calling your export and at which generation of its
code, or `nil` when there is no invoking resource.

```lua
OPX_LIB.caller()
```

**Returns** `string|nil` owner, and `string|integer` — the generation, or the
refusal code `export_call_required` when owner is `nil`

**Side** `client` — the server runtime installs no `GetInvokingResource`.

!!! danger "Never take an owner name as an argument"
    Both values come from the host, so a caller can neither claim to be another
    resource nor outlive its own reload. **Accepting an owner name as a normal
    Lua parameter lets any resource impersonate any other, and there is nothing
    on the receiving side that can detect it.** This is the platform's own
    rule, and it applies to every export that gates anything on ownership —
    `opx77_menu` keys menu ownership on exactly this, so a resource can only
    close a menu it opened.

`nil` is also the answer for a call made from inside your own VM. Nothing in
your resource should be reaching your own public surface — your locals are
right there — so such a call went somewhere it did not mean to, and refusing it
is correct.

The generation is the second half. A caller that reloads gets a new one, so an
ownership record keyed on `owner` alone will hand a stale menu, chip or panel
to the caller's successor. Key it on both.

---

## call {#call}

Makes one call to another resource's client export and keeps the three failure
levels apart, so a caller can tell "the target refused" from "the target was
not there".

!!! warning "Coroutine only"
    `await` has no synchronous form on this platform and one cannot be added
    from Lua. Call this inside a `CreateThread`.

```lua
OPX_LIB.call(resource, name, ...)
```

- resource: `string`
- name: `string`
- ...: `any`
    - Arguments, which must survive the value codec: plain data only, no
      functions, no metatables, no cycles.

**Returns** three values

- `table|nil` — the answer, when the call succeeded and was not a refusal
- `string|nil` — the reason, when it was not
- `boolean` — `answered`, and this is the one that matters

**Errors**

| Code | `answered` | Meaning |
|---|:-:|---|
| `not_running` | `false` | `GetResourceState` says the target is not running. Checked first, because it is free and it is the common case during a reload. |
| `not_dispatched` | `false` | `Open77.exports.call` returned `nil` with no reason of its own. |
| *(the host's reason)* | `false` | `Open77.exports.call` returned `nil, reason` — `export_not_found` is the documented example. |
| *(the call error)* | `false` | The promise rejected: the target raised, or its generation was invalidated because it stopped or reloaded mid-flight. |
| `malformed_answer` | `true` | The target answered with something that is not a table. Its bug, not yours, but you still cannot use the value. |
| `refused` | `true` | The target answered `ok = false` with no `error` field. |
| *(the target's `error`)* | `true` | The target answered `ok = false` and named a code. Authoritative. |

**Side** `client` — the server runtime installs no `exports` and no way to
reach another resource at all.

!!! danger "`answered` decides whether you may act on the failure"
    `answered == true` means the target **ran your export and refused**. That
    is a fact about your request: show the message, take the button away, stop
    retrying.

    `answered == false` means the call never got there, and says **nothing**
    about your request — the target may simply be restarting. A consumer that
    caches something should let the cached value **age out** here rather than
    throwing it away. Discarding a good value because a resource happened to be
    reloading is a worse outcome than serving it one poll longer.

    Collapsing the two is the single most common mistake in code written
    against this platform, and the platform's own example collapses them.

There is **no call timeout.** The only documented exit is generation
invalidation when the target stops or reloads, so a promise that will never
resolve because the target is wedged will not wake your thread. Structure
long-lived consumers so a missed answer is survivable — poll again on your own
cadence rather than blocking a loop on one `await`.

### Example {#call-example}

```lua
CreateThread(function()
  local result, reason, answered = OPX_LIB.call("opx77_core", "GetPlayerData")
  if result == nil then
    -- answered: the core told us there is no character. Clear the panel now.
    -- not answered: the core is restarting. Keep what we had and try again.
    if answered then State.forget() end
    Open77.log.debug("core: " .. tostring(reason))
    return
  end
  State.adopt(result.data, OPX_LIB.nowMs())
end)
```

[The export contract](../concepts/export-contract.md) sets out the three levels
in full, including what each one licenses you to do.

---

## The source {#source}

Verified against Lua 5.4 with `luac -p` and exercised against the cases
described above. Copy the whole file.

```lua title="shared/opx77_lib.lua"
--- opx77_lib 1.0.0 -- COPY-IN SOURCE, NOT A SERVICE.
---
--- Paste this file into your own resource as `shared/opx77_lib.lua` and list it in your
--- manifest. It is not a resource, it publishes no exports, and nothing loads it for you:
--- `require` is nil on the server and confined to the calling resource on the client, and
--- `Open77.resource.readFile` cannot leave the resource that calls it. There is therefore no
--- way for one resource to hand Lua source to another, and a "library resource" on this
--- platform cannot exist. Copying is the mechanism, so the version above is the contract.
---
--- Everything here is pure except `nowMs`, `caller` and `call`, which are marked.

local Lib = { VERSION = "1.0.0" }

-- ---------------------------------------------------------------------------
-- Numbers
-- ---------------------------------------------------------------------------

--- True only for a real, finite number. `value ~= value` is the NaN test and not a typo: NaN
--- arrives through JSON from a client, passes every comparison, and poisons any sum it lands
--- in. Both infinities are rejected too -- a value named `finite` that accepts `math.huge`
--- is the bug this function exists to prevent.
---@param value any
---@return boolean
function Lib.isFinite(value)
  return type(value) == "number"
    and value == value
    and value ~= math.huge
    and value ~= -math.huge
end

--- Coerces to a finite number, or nil. Use this on anything that came off the wire, out of
--- JSON, or out of a caller's table; use `isFinite` when a non-number must be refused rather
--- than parsed.
---@param value any
---@param limit? number reject a magnitude above this, for a value with a known domain
---@return number|nil
function Lib.finite(value, limit)
  local parsed = tonumber(value)
  if not Lib.isFinite(parsed) then return nil end
  if limit and (parsed > limit or parsed < -limit) then return nil end
  return parsed
end

--- Coerces to a whole number, or nil. A fractional value is refused, never rounded: a caller
--- that meant 3 and sent 3.5 has a bug, and rounding hides it.
---@param value any
---@param limit? number
---@return integer|nil
function Lib.integer(value, limit)
  local parsed = Lib.finite(value, limit)
  if parsed == nil or parsed % 1 ~= 0 then return nil end
  return math.floor(parsed)
end

--- Confines a number to a range. NaN survives this untouched -- both comparisons are false
--- for it -- so pass the value through `finite` first when it came from outside.
---@param value number
---@param low number
---@param high number
---@return number
function Lib.clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

--- A 0-100 integer for a bar, a fill or a percentage row. Anything unusable is 0, because a
--- gauge is cosmetic and refusing to draw one is worse than drawing an empty one.
---@param value any
---@return integer
function Lib.percent(value)
  local parsed = Lib.finite(value)
  if parsed == nil then return 0 end
  return math.floor(Lib.clamp(parsed, 0, 100) + 0.5)
end

-- ---------------------------------------------------------------------------
-- Time
-- ---------------------------------------------------------------------------

--- Milliseconds since the host started. `Open77.time.monotonic()` answers SECONDS on both
--- sides -- the API reference says so and the host's own Lua bootstrap divides its
--- millisecond scheduler clock by 1000 before handing it over. Treating it as milliseconds
--- gives a timer that fires a thousand times too early.
---
--- Impure: reads the host clock.
---@return integer
function Lib.nowMs()
  return math.floor(Open77.time.monotonic() * 1000)
end

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------

--- Control characters as an explicit byte range rather than `%c`, whose meaning above 0x7F
--- depends on the C locale. These are the bytes that forge a line in a log, a row in a chat
--- box, or a node in a web page.
local CONTROL = "[\0-\31\127]"

--- Truncates to at most `maxBytes` bytes without splitting a UTF-8 character in half. A
--- straddling character is dropped whole: half a character is bytes no page can render, and
--- on a CEF surface it is a mojibake that outlives the message.
---@param text string
---@param maxBytes integer
---@return string
local function truncate(text, maxBytes)
  if #text <= maxBytes then return text end
  local at = maxBytes + 1
  -- 10xxxxxx is a continuation byte: step back to the lead byte that owns it
  while at > 1 do
    local byte = text:byte(at)
    if byte == nil or byte < 0x80 or byte >= 0xC0 then break end
    at = at - 1
  end
  return text:sub(1, at - 1)
end

--- Sanitises text a caller offered for display: control characters become spaces, then the
--- result is truncated on a character boundary. Cleaned rather than refused -- cosmetic text
--- is never worth failing a call over a stray tab -- so this returns nil only for a value
--- that is not text at all.
---@param value any a string, or a number which is rendered
---@param maxBytes integer
---@return string|nil
function Lib.displayText(value, maxBytes)
  if value == nil then return nil end
  if type(value) == "number" then value = tostring(value) end
  if type(value) ~= "string" then return nil end
  value = value:gsub(CONTROL, " ")
  return truncate(value, maxBytes)
end

--- True for a machine-readable identifier: an id, an event suffix, a resource name. ASCII
--- letters, digits, `_`, `-`, `.` and `:`. Measured in bytes, because it is compared and
--- concatenated as bytes.
---@param value any
---@param maxBytes integer
---@return boolean
function Lib.identifier(value, maxBytes)
  return type(value) == "string" and #value > 0 and #value <= maxBytes
    and value:match("^[%w_:%-%.]+$") ~= nil
end

-- ---------------------------------------------------------------------------
-- The export surface -- CLIENT ONLY
-- ---------------------------------------------------------------------------

--- The answer shape every OPX//77 export gives: a plain table carrying `ok`, and an `error`
--- code when `ok` is false. Not a `Result` object -- the value crosses the runtime's codec
--- and lands in a resource that has no `Result` loaded.
---@param ok boolean
---@param values? table
---@return table
function Lib.response(ok, values)
  values = values or {}
  values.ok = ok == true
  return values
end

--- Who is calling, and at which generation of their code. Both come from the host, so a
--- caller can neither claim to be another resource nor outlive its own reload. Never take an
--- owner name as an argument: any resource could then impersonate any other and nothing on
--- this side could tell.
---
--- Returns nil outside an export invocation, which is also the answer for a call made from
--- inside this VM -- your own locals are right there, so such a call went somewhere it did
--- not mean to.
---
--- Impure. Client only: the server runtime installs no `GetInvokingResource`.
---@return string|nil owner
---@return string|integer generation the refusal code when owner is nil
function Lib.caller()
  local owner = GetInvokingResource()
  local generation = GetInvokingResourceGeneration()
  -- a resource name carries no colon, so this is stricter than `Lib.identifier`
  if type(owner) ~= "string" or owner == "" or #owner > 64
    or owner:match("^[%w_%-%.]+$") == nil or type(generation) ~= "number" then
    return nil, "export_call_required"
  end
  return owner, generation
end

--- One call to another resource's client export, with the three failure levels kept apart.
--- The third return is the one that matters: `answered` true means the target ran the export
--- and refused, which is authoritative and can be acted on. `answered` false means the call
--- never got there, which says nothing at all about your request -- let a cached value age
--- out rather than throwing it away because the target happened to be reloading.
---
--- Coroutine only: `await` has no synchronous form, so call this inside a `CreateThread`.
---
--- Impure. Client only: the server runtime installs no `exports` and no way to reach another
--- resource.
---@param resource string
---@param name string
---@return table|nil result
---@return string|nil reason
---@return boolean answered
function Lib.call(resource, name, ...)
  if GetResourceState(resource) ~= "running" then return nil, "not_running", false end
  local promise, reason = Open77.exports.call(resource, name, ...)
  if not promise then return nil, tostring(reason or "not_dispatched"), false end
  local result, callError = promise:await()
  if callError then return nil, tostring(callError), false end
  if type(result) ~= "table" then return nil, "malformed_answer", true end
  if result.ok == false then return nil, tostring(result.error or "refused"), true end
  return result, nil, true
end

--- Published as a global, because there is no other way: `require` is nil on the server.
--- Globals are per-resource -- each resource gets its own Lua state -- so this name is
--- private to you. Rename it if it reads better inside your own namespace.
OPX_LIB = Lib
```

## Changelog {#changelog}

### 1.0.0 {#v1-0-0}

First release. Reconciles the copies scattered across `opx77_core`,
`opx77_menu`, `opx77_hud`, `opx77_chat`, `opx77_status`, `opx77_weather` and
`opx77_elevators`. Where they disagreed, the strictest correct behaviour won:

- **`finite` now rejects both infinities.** `opx77_core/server/needs.lua`
  accepted them.
- **The magnitude bound is a parameter, not a constant.** The two
  `opx77_elevators` copies hard-coded `1000000`, which is right for a world
  coordinate and wrong for everything else.
- **The predicate and the coercer are two functions.** Three satellites had a
  `finite` that returned a boolean and refused strings; two had one that
  returned a number and accepted them. Both are useful and they are now
  [`isFinite`](#isfinite) and [`finite`](#finite).
- **`displayText` truncates on a character boundary.** Every copy cut at a
  byte offset.
- **`displayText` matches control characters as an explicit byte range**
  rather than `%c`.
- **`call` checks `GetResourceState` first**, as `opx77_elevators` and
  `opx77_hud` do, and reports `answered` as a third return so the caller
  cannot accidentally collapse levels 1 and 2 into level 3.
- **`caller` requires the generation as well as the name.** `opx77_chat` and
  `opx77_elevators` read only the name; `opx77_menu` and `opx77_status` read
  both, and both is correct.

## Where to go next {#next}

- [The export contract](../concepts/export-contract.md) — the three failure
  levels in full, and why a service answers with an event rather than a
  callback.
- [Writing a resource](../guides/writing-a-resource.md) — the whole thing, end
  to end, with this file in place.
- [Integration channels](../concepts/integration-channels.md) — every channel
  a third-party resource can use, including what a *server* resource gets
  instead of exports.
