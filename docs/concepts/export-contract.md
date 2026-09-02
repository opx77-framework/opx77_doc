---
title: The client export contract
description: Every OPX//77 export is a client export answering a promise, and failure has three levels that mean different things — how to call one correctly, what each level of failure tells you, and why a service answers with an event rather than a callback.
---

# The client export contract

Everything OPX//77 exposes to another resource is a **client** export, because
the client runtime is the only one that has `exports` and
`GetInvokingResource`. There is no server-side equivalent and there cannot be
one; [Architecture](architecture.md#the-constraint) explains why, and
[Integration channels](integration-channels.md) covers what a *server* resource
gets instead.

Three things surprise everyone arriving from FiveM, and the third is the one
that costs people an afternoon.

## The call shape {#call-shape}

**There is no `exports.<resource>:<name>()` proxy.** Indexing the exports
function raises *attempt to index a function value* — the sandbox removes
`setmetatable`, so the proxy trick FiveM uses cannot be built. The call is
always:

```lua
Open77.exports.call(resource, name, ...)
```

**It is asynchronous, always.** The call answers a promise, and `await` is only
usable inside a `CreateThread`. There is no synchronous form and adding one is
not possible from Lua.

**Failure has three levels**, and they mean different things. Checking only the
first turns a remote error into a silent `nil`.

```lua
CreateThread(function()
  -- level 1: the call could not be dispatched at all
  local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
  if not promise then
    return print("not dispatched: " .. tostring(reason))
  end

  -- level 2: it was dispatched, and resolution failed
  local result, callError = promise:await()
  if callError then
    return print("call failed: " .. tostring(callError))
  end

  -- level 3: the resource answered, and refused
  if not result.ok then
    return print("refused: " .. tostring(result.error))
  end

  print(result.data.citizenId)
end)
```

The platform's own example collapses levels 1 and 2 and discards the rejection
reason. Do not copy it. Each level below is a different fact about the world,
and a caller that cannot tell them apart cannot decide what to do next.

## Level 1 — the call was never dispatched {#level-1}

`Open77.exports.call` returned `nil, reason`. The target resource is not
running, is mid-reload, or publishes no export of that name — `export_not_found`
is the documented example reason.

**A level-1 failure says nothing about your request.** The target may simply be
restarting. A caller that caches something should let the cached value age out
rather than throw it away here: discarding a good value because a resource
happened to be reloading is a worse outcome than serving it a second longer.

```lua
local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
if not promise then
  -- keep whatever we already had; try again on the next tick of our own loop
  return
end
```

## Level 2 — dispatched, and resolution failed {#level-2}

`promise:await()` returned a non-nil `callError`. The call landed and the
promise did not resolve to a value: the target raised, or its generation was
invalidated because it stopped or reloaded while the call was in flight.

There is **no call timeout**. The only documented exit is generation
invalidation when the target resource stops or reloads, so a promise that is
never going to resolve because the target is wedged will not wake your thread
up. Structure long-lived consumers so that a missed answer is survivable — poll
again on your own cadence rather than blocking a loop on one `await`.

## Level 3 — the resource answered, and refused {#level-3}

The promise resolved. **Every OPX//77 export answers a plain
`{ ok = boolean, … }` table**, not the core's internal `OPX.Result`, because the
value crosses a codec and lands in code that does not have `OPX.Result` loaded.
On refusal the table carries `error`, a stable locale key such as
`error.notLoggedIn`, which a UI can render with the core's `Locale` export and
get the player's language for free.

**A level-3 refusal is authoritative.** The target read your request, understood
it, and said no. That is a fact you can act on: show the message, take the
button away, stop retrying.

The three levels in one line each:

| Level | What happened | What it tells you |
|---|---|---|
| 1 | `Open77.exports.call` answered `nil, reason` | Nothing about your request. The target may be restarting. |
| 2 | `promise:await()` answered a `callError` | The call landed; the answer did not come back. |
| 3 | `result.ok` is `false` | The target answered and refused. Authoritative. |

## Identity comes from the host, never from an argument {#invoking-resource}

!!! warning
    A service that needs to know who called it must read
    `GetInvokingResource()`. Taking the caller's name from a parameter lets any
    resource impersonate any other, and there is nothing on the receiving side
    that can detect it. This is the platform's own rule, and it applies to every
    export that gates anything on ownership.

`opx77_menu` is the worked example in this framework: it keys menu ownership on
the invoking resource, so a resource can only close or replace a menu it opened.

## There is no callback channel {#no-callbacks}

The runtime puts every export through a bounded value codec — arguments and
results must be serialisable — so **a function cannot cross a resource
boundary**. There is no "pass me a callback and call it later", and no amount of
wrapping produces one.

A service that has something to say later therefore raises an **event** instead.
That is not a stylistic choice; it is the only mechanism available. It is why
[`opx77_menu`](../reference/opx77_menu/events.md) tells you which row was chosen
by raising an event, and why
[`opx77_status`](../reference/opx77_status/events.md) reports an expired effect
the same way.

The same limit is why there is no `getSharedObject()` in OPX//77 and cannot be.
Handing `OPX` across the boundary would hand over a table stripped of every
function that makes it useful. The data half is therefore split into individual
exports, each answering a closed shape — `GetVersion`, `GetSharedConfig`,
`GetJobs`, `GetGangs`, `GetOrigins`, `GetPlayerData`, `GetCharacters` — and the
state changes are not asked for at all. They arrive, on the two event channels
described next.

## The client local event bus is host-wide {#local-bus}

This is the counter-intuitive half, and it is the opposite of the server.

On the **server**, `TriggerEvent` walks the handler table of its own VM and
stops there. On the **client**, the local event bus reaches every resource. The
platform's own shipped code depends on it: `open77_zones` accepts a
caller-supplied event name and fires it with a plain `TriggerEvent`, and
`pursuit` — a different resource entirely — receives it with a bare
`AddEventHandler`.

```lua
-- open77_zones/client/main.lua, on entering a zone
TriggerEvent(zone.enterEvent, { id = zone.id, handle = zone.handle })
```

```lua
-- pursuit/client/main.lua, in another resource
AddEventHandler("pursuit:readyUpEnter", function() … end)
```

That is what makes `OPX.Events.Local` a real public channel: a satellite listens
with a plain `AddEventHandler` and needs **no permission at all**. The wire
channel, `OPX.Events.Client`, is also public, and needs `network.events` and
`RegisterNetEvent`. Both are supported; the local one is the one to prefer.

!!! warning
    No name appears on both channels, and that is load-bearing rather than
    tidy. This platform's dispatcher matches an event by name and ignores the
    network flag, so a `TriggerEvent` also reaches every `RegisterNetEvent`
    handler of the same name. Re-emitting a wire name from inside its own
    handler re-enters that handler — tick-paced rather than recursive, so it is
    a silent permanent busy loop rather than a crash. Nothing is logged and
    nothing stops. If you republish an OPX//77 event under your own name, give
    it a name of your own.

The two vocabularies are listed side by side in
[the core's event reference](../reference/opx77_core/events.md).

## Where to go next {#next}

- [Integration channels](integration-channels.md) — every channel a third-party
  resource can use, including the server-side ones.
- [The core's client exports](../reference/opx77_core/exports/client.md) — every
  call the core publishes, with its error codes.
- [Writing a resource](../guides/writing-a-resource.md) — the whole thing, end
  to end.
