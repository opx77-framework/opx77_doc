# Architecture

OPX//77 does not look like ESX or qbx_core, and the reason is a single property
of the Open77 platform. Everything else on this page follows from it.

## The constraint that decides everything

ESX and qbx_core rest entirely on one assumption: that a third-party resource
can call the core. On Open77 that is impossible **on the server**, and the
platform documentation states it on four separate pages:

!!! danger "Server resources cannot call each other"

    > The **server** runtime installs no `exports`, no `GetInvokingResource`
    > and no cross-resource event bus.

`TriggerEvent` does **not** cross resource boundaries on the server: it
operates per-VM. The platform documentation explicitly recommends grouping all
of a game mode's server logic into a **single resource**, organised into files.

This is not a gap waiting to be filled. In the platform's own words, *"it is a
platform fact, not an oversight to be fixed later"*. Open77 had planned its own
`open77_gamemode` and abandoned it for exactly this reason, distributing common
patterns by code generation rather than by runtime binding.

### What OPX//77 does about it

**One server resource, split into files.** What would be a plugin resource on
another framework is here a file added to `server/`, and `OPX.*` is the server
API — available because everything sharing it shares one Lua state.

A file added to `opx77_core/server/` types `OPX.` and finds the whole
framework: `OPX.Result`, `OPX.Table`, `OPX.Validate`, `OPX.AddMoney`,
`OPX.PlayerData`. There is no second global and nothing to import.

## On the client it is the opposite

> The client runtime *does* have `exports` and `GetInvokingResource`.

That is where splitting by resource becomes possible again, and it is what
makes the satellites possible: `opx77_hud` for the overlay, `opx77_menu` for
the shared menu surface, `opx77_status` for the shared status strip.

It is also why every shared *service* in OPX//77 is a **client** service. A
server-side menu service could not be called by anybody.

## The client export contract

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
  if not promise then return print(reason) end   -- dispatch failure
  local result, callError = promise:await()      -- resolution failure
  if callError or not result.ok then return end
  print(result.data.citizenId)
end)
```

Three traps if you arrive from FiveM:

1. **There is no `exports.<resource>:<name>()` proxy.** Indexing it raises
   *attempt to index a function value*. The only entry point is
   `Open77.exports.call(resource, export, ...)`, which returns
   `promise, reason`.
2. **It is always asynchronous.** `await` is only usable inside a
   `CreateThread`.
3. **Failure reads at *two* levels.** `promise, reason` is the dispatch
   failure; `result, callError` from `promise:await()` is the resolution
   failure. Checking only the first turns a remote error into a silent `nil`.

Publishing an export is the mirror image:

```lua
exports("openMenu", function(id) return { opened = true, id = id } end)
```

!!! warning "Take the caller's identity from the runtime, never from an argument"

    An exported service must read the caller from `GetInvokingResource()`, and
    never from a parameter — doing otherwise *"would let any caller impersonate
    another resource"*. `opx77_menu` and `opx77_status` both key ownership this
    way: an effect or an open menu belongs to the resource that created it, and
    goes when that resource stops.

### `getSharedObject` returns data, not functions

From a satellite **client** resource, `getSharedObject` returns the *data* half
of the `OPX` table: version, shared config, job and gang definitions, the
current character. It cannot return the functions — the platform passes every
export through a codec, *"arguments and results must be serializable"*, and a
function does not serialize. Calls therefore stay individual exports.

On the **server** there is no equivalent and there cannot be one, because the
server runtime installs no `exports` at all.

## Load order is the contract

Load order lives in `open77.lua`, one file per line. A file publishes into
`OPX`, and every file after it can read what was published.

Two rules, each of which has already cost somebody something:

!!! failure "No `require` on our own files"

    A file that is both listed in the manifest and loaded by `require` runs
    **twice** — the manifest loader does not populate `require`'s cache. And
    `require` is confined to the resource anyway: it could never have reached a
    library living elsewhere.

!!! failure "No globs"

    `server/**/*.lua` matches nothing against flat files, and an empty glob
    prevents the entire resource from starting. It is a failure mode that only
    shows up after a rename. Every shipped resource lists its files one per
    line.

## The layers

| Directory | Holds |
|---|---|
| `config/` | the only files an operator edits. `UPPER_SNAKE` keys |
| `data/` | jobs, gangs, life paths. Definitions, not settings |
| `shared/` | `OPX` itself: result, table, string, math, log, validate, hooks, locales, citizen identifiers |
| `server/storage/` | every SQL query, and the migrations |
| `server/` | roster, player, groups, characters, entry gate, events |
| `client/` | the state mirror and the export surface |

## Session is not player

A **session** is a connected machine. It exists from `onPlayerConnected` and
carries the `userId` signed by the Master. A **player** is a loaded character,
and exists only between the choice and the disconnect.

Somebody sitting in the selection screen has a session and no player. Any
caller that confuses the two ends up either refusing a legitimate connection or
trusting a character that was never loaded.

`playerId` is recycled; `userId` is durable. The first is therefore only a
lookup key: every read re-checks the `userId` behind the slot. A missed
departure becomes a non-event instead of a security hole.

## The citizen identifier

Players type these codes from memory, out loud: transfers, reports, admin
lookups. The format is built to survive an approximate reading.

- A 23-symbol alphabet with no ambiguous glyph — no `0`/`O`, no `1`/`I`/`L`,
  no `5`/`S`.
- Six useful symbols plus one check symbol, rendered as `H7K-M4X3`.
- The check is a weighted sum modulo 23. The modulus is prime, which makes it
  detect **all** single-symbol substitutions and **all** transpositions of two
  adjacent symbols.

Without that check, a typo can produce a valid code belonging to somebody else:
the money leaves for a stranger with no error shown.

The same code is also the `character_key` used by `open77_appearance` and
`open77_playerstate`. One identity instead of two, so there is no case where a
character's face and their money disagree about who they are.

## The entry gate

> do not teleport, spawn, kill or force a respawn on a player until their
> readiness gate has opened.

The core declares its participation once at boot, which places a hold on every
player who connects afterwards. It does not race to take a hold before
something else moves the player — it already holds one before the player
exists.

There are two deadlines, and OPX//77's is the shorter one. The host opens the
gate itself at `GATE_MS` and emits `timeout:opx77_core`, potentially with the
player still in the selection screen and **holding no puppet at all**. The core
therefore gives itself a deadline below that: it gives up first, releases
deliberately, and says why.

Placement is done by **kill → respawn**, never by a raw transform: the respawn
transaction carries the fade, the streaming preload and the grace window that a
direct teleport skips. Liveness is read first, because the host's timeout can
still win.

## What is missing

- The character selection UI (`opx77_char`, a client resource).
- Inventory, and the link to `open77_clothing`.
- Persistent vehicles.
- Bans and the queue.
