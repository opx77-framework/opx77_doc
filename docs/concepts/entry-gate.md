---
title: The entry gate — readiness holds, liveness and placement
description: How the OPEN//77 join-time readiness gate really works — participating and holding, the liveness watchdog, the complete detail vocabulary, the undocumented __platform hold, the loading cover that makes the world come first, and why placement is kill then respawn.
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
  `open77:session:gameplayReady`. In this resource set
  [`opx77_appearance`](../reference/opx77_appearance/index.md) is what sends it,
  once it has seen that this world attachment is the *gameplay* one — the
  character bootstrap is `ready`, which is the only thing that tells it from the
  pre-game menu world — that a character is loaded and stands on its own body,
  that this world entry's face has been settled, and that the announcement has
  not already gone out. The resulting `detail` is `incarnated`, and the host
  says so:

```text
player 3 is incarnated: the client reports an attached, alive puppet past the
continue screen
```

That is what makes an open gate worth something. It means "this player is
incarnated and may be teleported, spawned, killed or respawned", not merely "the
other resources have finished".

## The world comes first {#world-first}

Between connecting and the gameplay world there is a stretch of the join that no
server resource can draw on, and the order of everything OPX//77 does at join
follows from it. Every fact in this section was established on
`open77-server-2.31.13+op77.63`, with a client probe relaying the client's
state to the server log during a real join, and from the Lua source of the
platform's own `open77_shell` and `open77_appearance`.

### The loading cover {#loading-cover}

On join, `open77_shell` — a system resource, running in a host of its own —
keeps an opaque OPEN//77 loading cover up for as long as
`Open77.session.characterBootstrap().phase` is `"waiting"`.

- **Nothing a server resource draws is visible under it.** Moving a surface to
  the `"system"` layer, with `webui.system` and a z-index above the shell's,
  does not bring it through. That was tried with `opx77_menu`, `opx77_input` and
  `opx77_notify`, and every OPX//77 surface stays on `"hud"`.
- **A server resource cannot lift it.** `TriggerEvent("open77:shell:hide")`
  from a server resource reaches nothing: the shell runs in another host, and a
  local event does not cross from one host to the other.
- **The one UI the shell lets through** before the world is the vanilla
  character creator, `Open77.session.requestCharacterCreator()`, for which it
  swaps the cover for a transparent notice while the bootstrap is in
  `creator_requested`, `creator_open` or `awaiting_commit`. OPX//77 does not use
  it.
- **The world loads only once the bootstrap is spent.** The shell calls
  `Open77.session.loadPristine(family)` once the phase is `"ready"` — that is,
  once some resource has called
  `Open77.session.resolveCharacterBootstrap(family)`, with `family` `"female"`
  or `"male"`, once per connection. The cover lifts when that world has
  streamed.

!!! danger "A roster drawn before the bootstrap is spent deadlocks the join"
    A framework that waits for the player to choose a character before it
    resolves the bootstrap on that character's body never gets a choice: the
    roster is open, and holds the keyboard, under a cover nobody can see
    through. That was OPX//77's own order before this round, and a probe caught
    it exactly so — `opx77_charselector` in phase `roster`, `opx77_menu` with a
    menu open, the player on the loading screen for ever. See
    [Troubleshooting](../guides/troubleshooting.md#stuck-loading-screen).

Two things the client reports cannot tell the pre-game menu from the gameplay
world:

- **`open77:worldReady` fires for the pre-game menu world too**, while the
  bootstrap is still `"waiting"` — the probe saw it about 1.5 s after connect.
- **`Open77.character.state()` in that menu world answers** `attached = true`,
  `alive = true`, `health = 100`, at a position near the origin. That is the
  menu's puppet.

Only the bootstrap phase `"ready"` distinguishes the gameplay world. Every
OPX//77 resource that waits for it tests the phase together with the puppet.

### The platform's own model {#platform-model}

The official `open77_appearance` never draws UI of its own before the world. On
`open77:worldReady` — the menu world's included — its client sends
`open77:appearance:ready`, and its server answers one of three ways:

| The server knows | It answers | The client |
|---|---|---|
| a character | `bootstrapReady(family, key)` | resolves the bootstrap on `family` |
| nothing, because there is no database | the family `"female"`, key `"default"` | resolves the bootstrap on it |
| a new player | `createRequired` | opens the vanilla creator, commits, then resolves |

**Selecting a character is the roleplay framework's job, and it happens in the
world.** The platform's README puts it in one line: a server-side gamemode
switches the active character after its own authorisation and selection logic,
with `TriggerEvent("open77:appearance:setCharacter", playerId, key)`. The server
then sends the client `characterChanged`, and the client reconciles: when the
record's family is not the body loaded, it calls
`Open77.appearance.switchBodyFamily(family, false)`, which reloads the player's
body — the world entry that follows runs the reconcile again, and
`body_family_already_active` is not an error — then applies the face and
announces `open77:session:gameplayReady`.

The in-world editor opens on a body family with
`Open77.appearance.open({ mode = "ripperdoc", gender = g })`; `gender` is
accepted in `ripperdoc` mode only. When `g` is not the body loaded, the official
client first calls `Open77.appearance.switchBodyFamily(g, true)` — `true` marks
an edit transition — and reopens the editor after the reload, when
`Open77.appearance.takeBodyFamilyTransition()` answers `"edit:<gender>"`, or
gives up when it answers `"error:<reason>"`. Closing the editor raises the local
events `open77:appearance:confirmed` or `open77:appearance:cancelled`;
`Open77.appearance.capture()` reads the result, and `finishCommit()` releases
the native mutation transaction. `open77:playerReset:complete` fires once the
gameplay puppet is bootstrapped.

### What OPX//77 does at join {#join-sequence}

OPX//77 follows that model. The bootstrap is spent before anybody is chosen, so
the cover lifts without any OPX//77 UI having been used, and the roster, the
identity form and the face editor all happen in the gameplay world.

1. **The player connects.** `opx77_core` takes its hold,
   `opx77_character_selection`, and pushes the roster at once. That push goes
   out before any of the client's resources run, so it usually lands nowhere,
   and it is deliberately neither cooled nor cooling: the `READY` the core's
   client sends when it starts a second or two later is answered.
2. **The bootstrap is spent.** When the pre-game menu raises
   `open77:worldReady`, or `opx77_appearance` starts with the phase still
   `"waiting"`, it waits up to
   [`BOOTSTRAP.ROSTER_WAIT_MS`](../reference/opx77_appearance/config.md#bootstrap)
   for the roster the core already holds — read, never requested — and resolves
   the bootstrap on the body of the account's most recently played character,
   or on `BOOTSTRAP.DEFAULT_FAMILY` when there is none in time:

    ```text
    bootstrap (worldReady): loading the male body, the last character played
    character bootstrap resolved as male
    ```

3. **The world loads**, on that body, and the cover lifts when it has streamed.
4. **The roster goes up in the world.**
   [`opx77_charselector`](../reference/opx77_charselector/index.md) opens it
   through `opx77_menu` once the phase is `"ready"` and the gameplay puppet
   exists, and puts the stage up with it: the camera orbits to face the
   player's own character, and the character is held where it stands. A roster
   that has not arrived is asked for again every
   [`ROSTER_RETRY_MS`](../reference/opx77_charselector/config.md#roster-retry-ms).
5. **A selection** goes to the core, which places the character and releases
   its own hold. `opx77_appearance` then reloads the body when the character's
   `charInfo.gender` is not the one the world loaded, puts the stored face on,
   and announces. `__platform` falls with `incarnated`.
6. **A creation** goes through
   [`opx77_charcreator`](../reference/opx77_charcreator/index.md), which holds
   the stage through its `opx77_input` form and writes the character through
   the core. The player then selects it like any other, and a character with no
   stored face gets Cyberpunk's own editor, opened in the world in `ripperdoc`
   mode on the body chosen in the form.

!!! warning "Known issue: a character on the other body can leave the cover up"
    Selecting a character whose body family differs from the body the world
    loaded sends the player through a body reload, and that reload can leave
    the loading cover up. It is being fixed. Until then, the body loaded at join
    is the most recently played character's, so a player entering as that
    character does not reload at all. See
    [Troubleshooting](../guides/troubleshooting.md#body-family-cover).

## Without an appearance resource the gate never opens {#never-opens}

The website says: *"A server where nothing participates is a server where the
gate is always open."* That is true of **resource** holds and false of
`__platform`.

On a server whose resource set contains nothing that emits
`open77:session:gameplayReady`, every player's `__platform` hold stands forever.
So:

- `Open77.ready.isReady(playerId)` is **permanently false**.
- `onPlayerReady` **never fires**, for anybody, ever.
- The host logs one `WRN` naming `__platform` per connected player, roughly once
  a minute.

There is no timeout, no fallback and no substitute probe.

**A stock OPX//77 resource set is not such a server**, because
[`opx77_appearance`](../reference/opx77_appearance/index.md) ships with it and
sends the announcement. Stop that resource, or run the set without it, and every
symptom above comes back.

`opx77_core/server/lifecycle.lua` checks for it at load — `opx77_appearance`, or
the official `open77_appearance`, either name satisfies the check — and logs one
warning when neither is running, because this is otherwise undiagnosable:

```text
[lifecycle] no resource here emits `open77:session:gameplayReady`, so the
`__platform` hold never clears and `Open77.ready.isReady` stays false
```

The check accepting either name is about the announcement only. The official
package spends the bootstrap by [its own model](#platform-model), not by
[this framework's](#world-first), and hands every player's look out as
`opx77_appearance` does. Run one of them: the two fight over the bootstrap and
the face, and `opx77_appearance` stands its look distribution down while the
official package runs — see
[How other players see this one](../reference/opx77_appearance/index.md#presence).

Two things to know either way:

- **The core is unaffected.** It neither reads `isReady` nor waits on
  `onPlayerReady`; it holds the gate, loads the character, places them and
  releases. That is also why a character with no stored face is placed *before*
  the face editor opens — the core's sequence never consulted `Open77.ready`,
  and no appearance resource has ever gated it.
- **Prefer the core's own signals anyway.** A satellite that parks work behind
  `Open77.ready.isReady` or resumes it on `onPlayerReady` hangs on any install
  where the announcement is missing. `opx77:client:onPlayerLoaded` on the client,
  or the release note on the server, do not have that failure mode.

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
