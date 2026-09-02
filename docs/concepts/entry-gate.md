---
title: The entry gate — readiness holds, liveness and placement
description: How the OPEN//77 join-time readiness gate really works — participating and holding, the liveness watchdog, the complete detail vocabulary, the undocumented __platform hold that never clears on a stock install, and why placement is kill then respawn.
---

# The entry gate

The readiness gate is the barrier that stops one resource acting on a player
another resource has not finished with. The host owns it, because on the server
resources cannot call each other and this is the only place the two sides can
meet.

!!! danger
    **Do not teleport, spawn, kill or force a respawn on a player until their
    readiness gate has opened.** Acting server-side on a client that is not yet
    incarnated crashes that client. Reading their state, putting them on a
    roster, sending them a HUD payload — all unaffected.

Everything on this page was established from the shipped server binary and from
the platform's own resource source. Several parts of it contradict the platform's
website; where they do, the difference is called out and the binary is what runs.

## It is a barrier, not a trigger {#barrier-not-trigger}

`onPlayerReady` says only that nobody is holding this player any more. It says
nothing about whether *your* resource is ready, and it is not the place to do
your work. The platform's own prescribed shape is "check on my event, resume on
theirs":

```lua
if not Open77.ready.isReady(playerId) then
  record.awaitingReady = true -- come back on onPlayerReady
  return
end

AddEventHandler("onPlayerReady", function(rawPlayerId, detail)
  local playerId = tonumber(rawPlayerId) -- host events carry strings
  -- resume whatever was parked
end)
```

Keep your own readiness signal and ask the gate for permission.

## Participating, holding, releasing {#holds}

A resource that needs the player to finish something first declares itself
**once, at load**:

```lua
Open77.ready.participate({ livenessIntervalMs = 30000, reason = "character_creation" })
```

From then on, every player who connects arrives with one implicit hold in that
resource's name. This is the important half: the resource is not racing to grab
a hold before something else moves the player — it already has one before the
player exists. `opx77_core` calls `participate` at the bottom of
`server/lifecycle.lua`, at load, for exactly this reason.

It then either releases, or takes an explicit hold:

```lua
local session = Open77.ready.hold(playerId, "character_creation")
Open77.ready.release(playerId, session, "my_resource:done")
```

!!! warning
    `Open77.ready.hold` returns **one** value — the session number — or
    `nil, reason`. The bootstrap's own comment says `returns ok, session` and it
    is wrong. Writing `local ok, session = Open77.ready.hold(id)` binds `ok` to
    the session number and `session` to `nil`; the truth test still passes, so
    nothing looks broken until a recycled player id makes the release apply to
    somebody else's hold.

Capture the session number **before** any `await` and pass it back afterwards.
An answer computed for a player who has since reconnected is then discarded
instead of opening a stranger's gate. Omit it and the release applies to whoever
holds that id now.

`hold`, `release`, `isReady` and `status` **raise** a Lua error
(`id must be positive`) for a null or negative player id, rather than answering a
reason. A resource that never called `participate` may still take a hold, and
gets a default liveness interval of 30,000 ms.

## The liveness interval is a watchdog on your resource {#liveness}

This is the most misread field in the whole API.

`livenessIntervalMs` — `timeoutMs` is the same field under an older name — is
**not a budget for the player**. It is how long the host will wait for a sign of
life from *your resource* before concluding the holder is gone.

Taking the hold again is what refreshes it, and that **is** the heartbeat. A
hold stands indefinitely for as long as it is refreshed: somebody may spend an
hour in a character creator and that is correct. The gate is only ever forced by
evidence the holder has disappeared — the resource died, was reloaded away, or
the client it was waiting on stopped answering — and then it opens by itself
with the detail `liveness_lost:<resource>`, and one host `WRN` names the
resource, because "nothing happens when I join" is otherwise undiagnosable.

If a normal join reaches that path, the readiness condition is wrong. Raising
the number is not the fix. `ready` at the server console lists who is holding
whom.

The host clamps the declared interval to `[1000, 600000]` ms.

### What the core does, and why {#core-deadlines}

`opx77_core` takes one hold per join and never heartbeats it, so for the core
the interval **is** in practice the deadline it has. That makes two deadlines,
and the core's own is deliberately the shorter one:

| Deadline | Where | Shipped | What happens |
|---|---|---|---|
| The host's liveness interval | `ENTRY.GATE_MS` | 300,000 ms | The host decides the core is gone, opens the gate itself, and the detail reads `liveness_lost:opx77_core`. |
| The core's join pipeline | `ENTRY.PIPELINE_MS`, tunable `SELECTION_MS` | 240,000 ms | The core gives up, releases deliberately, and says why. |

If the host wins that race, the gate opens with the player possibly still in the
selection screen and holding **no puppet at all**. That is why the core's
deadline sits below it and why `SELECTION_MS` is capped at `PIPELINE_MS` rather
than left open — a tunable an operator could raise past the liveness interval
would have the host declare the core dead mid-screen.

Release is idempotent and safe for a player who never had a hold. If the session
has lost track of its gate session the core asks the host with
`Open77.ready.status(source)` rather than skipping the release: a hold nobody
releases is not on a clock, so it stalls that player until the host decides this
resource has stopped answering — which, on a core that is still running, is
never.

## The complete `detail` vocabulary {#detail}

`onPlayerReady(playerId, detail)` fires in every resource when the last hold
falls. `detail` is exactly one of:

| `detail` | Meaning |
|---|---|
| the `note` passed to `release` | Sanitised and truncated to 64 characters. |
| `cleared` | The holds were cleared. |
| `incarnated` | The `__platform` hold fell because the player is genuinely in the world. |
| `resource_stopped` | A holder stopped. |
| `resource_reloaded` | A holder was reloaded away. |
| `liveness_lost:<resource>[,<resource>…]` | One or more holders stopped answering. |

!!! warning
    The website documents `no_holds` and `timeout:<resource>`. **Neither string
    exists in any shipped assembly** — searched byte by byte, in ASCII and
    UTF-16LE. The website also omits `incarnated`. Code that tests
    `detail:sub(1, 8) == "timeout:"` has a branch that can never run; the prefix
    to test is `liveness_lost:`.

The notes `opx77_core` itself sends are listed in
[Integration channels](integration-channels.md#release-note), which is where the
release note is treated as what it is — the one thing the core can say to every
other server VM.

## The `__platform` hold {#platform-hold}

Every joiner also arrives held by a second hold, named `__platform`, placed
before any resource's hold. It is not like the others:

- **It has no deadline at all** — a liveness deadline of positive infinity.
- **No Lua may take or release it.** `hold` and `release` refuse the name with
  `reserved_resource`.
- **It clears on one thing only:** the client announcing
  `open77:session:gameplayReady`, which `open77_appearance` emits once it has
  seen that this world attachment is the *gameplay* one — not the vanilla menu
  the character creator runs inside — and that the local puppet is attached,
  alive and above zero health. The resulting `detail` is `incarnated`.

That is what makes an open gate worth something. It means "this player is
incarnated and may be teleported, spawned, killed or respawned", not merely "the
other resources have finished".

## On a stock OPX//77 install the gate never opens {#never-opens}

The website says: *"A server where nothing participates is a server where the
gate is always open."* That is true of **resource** holds and false of
`__platform`.

On a server whose resource set contains nothing that emits
`open77:session:gameplayReady` — in practice, nothing that ships
`open77_appearance` — every player's `__platform` hold stands forever. So:

- `Open77.ready.isReady(playerId)` is **permanently false**.
- `onPlayerReady` **never fires**, for anybody, ever.
- The host logs one `WRN` naming `__platform` per connected player, roughly once
  a minute.

There is no timeout, no fallback and no substitute probe. **A stock OPX//77
resource set is such a server**, because the seven `opx77_*` resources do not
include an appearance service.

What to do about it:

- **The core is unaffected** and says so at boot. It neither reads `isReady` nor
  waits on `onPlayerReady`; it holds the gate, loads the character, places them
  and releases. `server/lifecycle.lua` checks for `open77_appearance` at load and
  logs a five-line warning when it is absent, because this is otherwise
  undiagnosable.
- **Do not build on either signal.** A satellite that parks work behind
  `Open77.ready.isReady` or resumes it on `onPlayerReady` will hang forever on
  this install. Use the core's own signals instead — `opx77:client:onPlayerLoaded`
  on the client, or the release note on the server.
- **Install an appearance resource** if you want the platform's signal to work.
  Once something emits `open77:session:gameplayReady`, both come alive with no
  change to OPX//77.

## Placement is kill → respawn {#placement}

!!! warning
    Never place a player with a raw transform write. The respawn transaction
    carries the fade, the streaming preload and the grace window that a direct
    teleport skips, and the platform lists "placement only by kill → respawn"
    among the eight conventions it proved on its own gamemodes.

The sequence `OPX.PlaceCharacter` runs:

1. **Poll the life state** up to five times over a second. The gate has not
   opened — the core is still holding it — so this poll is the whole of what
   stands between placement and a player mid-transition. A `nil` snapshot is the
   platform's own prescribed test for "not yet incarnated" and is rejected here.
2. **`Open77.players.kill`** with `cause = "script"` and
   `weapon = "opx77_core:placement"`.
3. **`Open77.players.respawn`** with the target position, heading and bucket, the
   character's stored health clamped to 0.15–1.0 of full, and a 5,000 ms grace
   window.
4. **Apply armour after the transaction.** Armour is not a respawn option, and
   the body is about to be replaced.

If the kill succeeded and the respawn did not, the core **revives** rather than
leaving a corpse — and deliberately does not mark the position sampler as
allowed, because a revive leaves the body where it fell rather than where the
row says.

### Order matters at the level above too {#order}

Log in, place, **then** release the gate. Releasing first lets every other
resource act on a player who is not yet where they belong, which is the exact
race the gate exists to prevent.

### The position sampler {#sampler}

A character's stored position is only overwritten once the world agrees with the
row. `MaySample` is switched on in exactly one place, on success, and every
failing exit leaves it off — so a failed placement never writes "wherever the
engine dropped them" over the position it could not restore.

The one exception is deliberate: if there is no stored position and
`DEFAULT_SPAWN.SET` is false, placement declines and **does** allow sampling.
Nothing was restored, so there is nothing to overwrite, and wherever the engine
dropped them is the best answer available.

## Where to go next {#next}

- [Integration channels](integration-channels.md#release-note) — the release note
  as a channel.
- [Identity](identity.md#session-vs-player) — sessions, players, and why a slot
  is re-checked.
- [The OPEN//77 platform](the-platform.md#corrections) — the rest of the points
  where the website and the binary disagree.
