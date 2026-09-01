# OPX//77

OPX//77 is a roleplay framework for [OPEN//77](https://open2077.net), the
multiplayer platform for Cyberpunk 2077. It gives a server the systems a
roleplay game mode needs — characters, money, jobs, gangs, persistence,
entry gating — plus a set of shared client services that other resources
build on.

!!! warning "Early development"

    OPX//77 is not production-ready. The API, architecture, features and
    internal systems are subject to change at any time without notice, and
    breaking changes will be introduced as development progresses. Do not
    rely on the current API for production resources yet.

## The seven resources

| Resource | Version | What it is |
|---|---|---|
| [`opx77_core`](resources/opx77_core.md) | 0.2.0 | The framework itself: characters, money, jobs, gangs, metadata, persistence and readiness-gate integration. Everything else reads it. |
| [`opx77_menu`](resources/opx77_menu.md) | 0.1.0 | A keyboard-driven menu service. One resource owns the surface; every other resource opens a menu through an export and is told which row the player chose. |
| [`opx77_hud`](resources/opx77_hud.md) | 0.1.0 | The player HUD. Health, armour and stamina as segmented gauges, plus money, job and street cred. It reads `opx77_core` and draws — it decides nothing. |
| [`opx77_chat`](resources/opx77_chat.md) | 0.1.0 | The chat box, and the path a typed slash command takes to the host's authenticated dispatcher. Without it, nothing typed in game reaches the server. |
| [`opx77_status`](resources/opx77_status.md) | 0.2.0 | A shared status-effect strip. Any resource adds a chip — bleeding, over encumbered, a buff on a timer — and this one owns the ordering and the countdown. |
| [`opx77_weather`](resources/opx77_weather.md) | 0.1.0 | A synchronized clock and weather authority. The server decides the time of day and the sky; every client is told and applies it. |
| [`opx77_elevators`](resources/opx77_elevators.md) | 0.2.0 | Job-gated in-world elevators: a floor list on the lifts Night City already has, with each floor opened or closed by the job a character holds in `opx77_core`. |

## How they relate

`opx77_core` is the only one that owns state on the server. It is a **single
server resource split into files**, because the Open77 server runtime installs
no `exports`, no `GetInvokingResource` and no cross-resource event bus — server
resources simply cannot call each other. What would be a plugin resource on
another platform is, here, one more file added to `opx77_core/server/`.

Everything else is a **client** resource, or has its server half talk only to
its own client half:

- `opx77_hud` and `opx77_elevators` read the character from `opx77_core`'s
  client half through an export.
- `opx77_menu` and `opx77_status` are *services*: they own one piece of screen
  each, and other resources drive them through client exports. `opx77_elevators`
  draws its floor panel with `opx77_menu`, and treats a missing menu as one log
  line rather than a failure.
- `opx77_chat` and `opx77_weather` each own a server half, but it talks to that
  resource's own clients only — never to another resource.

Two consequences are worth stating up front, because they surprise everyone
arriving from FiveM:

1. **Every OPX//77 export is client-side.** A server resource that needs core
   data sends a net event to its own client half, which calls the export.
2. **Anything that must be unforgeable belongs in `opx77_core`'s server VM.**
   `opx77_elevators` says so in its own README: its job check is a client-side
   hint, and no setting turns it into anything else.

## The client export contract

Everything a resource exposes in OPX//77 is a **client** export, because the
client runtime is the only one that has `exports` and `GetInvokingResource`.
Three things surprise everyone arriving from FiveM.

**There is no `exports.<resource>:<name>()` proxy.** Indexing the function
raises *attempt to index a function value*. The call is always
`Open77.exports.call(resource, name, ...)`.

**It is asynchronous, always.** The call answers a promise, and `await` only
works inside a `CreateThread`.

**Failure has two levels, and they mean opposite things.** Checking only the
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

  -- level 3, the resource's own answer: every OPX//77 export answers a plain
  -- `{ ok = boolean, ... }`, because the value crosses a codec and lands in
  -- code that does not have the framework loaded
  if not result.ok then
    return print("refused: " .. tostring(result.error))
  end

  print(result.data.citizenId)
end)
```

A call the target **answered and refused** is authoritative. A call that never
landed says nothing — the target may simply be restarting — so a caller that
caches something should let it age out rather than throw it away on a dispatch
failure.

!!! warning "Identity comes from the host, never from an argument"

    An exported service must read its caller from `GetInvokingResource()`.
    Taking the caller's name from a parameter would let any resource
    impersonate another.

!!! note "There is no callback channel"

    The runtime puts every export through a codec — arguments and results must
    be serializable — so a function cannot cross a resource boundary. A service
    that has something to say later raises an **event** instead. That is why
    [`opx77_menu`](resources/opx77_menu.md) tells you which row was chosen by
    raising one, and [`opx77_status`](resources/opx77_status.md) reports an
    expired effect the same way.


## Where to go next

- [Getting started](getting-started.md) — installing the resources on an
  Open77 server, and the `server.jsonc` block that loads them.
- [Resources](resources/index.md) — one page per resource.

## License

Every resource is MIT licensed. Copyright © 2026 Luis MOUTA.
