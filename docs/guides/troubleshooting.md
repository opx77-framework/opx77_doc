---
title: Troubleshooting OPX//77
description: Symptom, the exact log line the code actually prints, cause and fix — for the failures OPX//77 and the OPEN//77 platform produce most often, from a permanently closed readiness gate to an export call that answers nil.
---

# Troubleshooting

Every entry below is a symptom, the **exact** line the shipped code prints when it
happens, the cause, and the fix. The lines are quoted from the resources rather
than paraphrased, so they are safe to grep the platform log for; the ones that
come from the host itself rather than from OPX//77 say so.

Every OPX//77 log line is written through `Open77.log`, the host's own logger,
including the core's. The core prefixes a scope in square brackets — `[core]`,
`[storage]`, `[lifecycle]`, `[character]`, `[player]`, `[events]`, `[exports]`,
`[commands]`, `[bucket]`, `[vehicles]`, `[groups]`, `[appearance]`,
`[clothing]`, `[hooks]`, `[loops]`, `[client]`, `[audit]` — and the satellites
carry the host's own resource prefix. The host
owns the level; there is no `LOG_LEVEL` setting in this framework any more, and
no `OPX.Log`.

## Nothing at all happens when I join {#nothing-on-join}

**Symptom.** A player connects. Nothing places them, nothing waits on them, and
any resource that was written to wait for `onPlayerReady` does nothing for ever.
On the host log, once a minute, per player — this is the host's own wording, with
its placeholders filled in:

```text
player 3 has been connected for 180000ms and the platform still cannot confirm
they are in the world (gameplay announced=False, snapshots=...); nothing will
place them until it can. A client still in the character creator is normal here;
a client already walking around is not, and means no resource is emitting
open77:session:gameplayReady
```

`opx77_core` says the same thing once, at boot:

```text
[lifecycle] no resource here emits `open77:session:gameplayReady`, so the platform's `__platform` hold never clears and `Open77.ready.isReady` stays false
```

**Cause.** Every joiner arrives holding a platform hold named `__platform`. No
Lua may take it, no Lua may release it, and it has **no deadline** — the expiry
tick can never fire for it. It clears on exactly one thing: the client sending
the net event `open77:session:gameplayReady`. In this resource set that comes
from [`opx77_appearance`](../reference/opx77_appearance/index.md). If nothing on
the server emits it, the gate stays shut for the whole session.

The website's own readiness-gate page says the opposite — "a server where nothing
participates is a server where the gate is always open". That is true of
*resource* participation only; the platform hold is unconditional.

**Fix.** Start `opx77_appearance` — it ships with the framework, and the core's
boot check looks for it by that name. The check also accepts the official
`open77_appearance`, which sends the announcement too, but do not run that
package instead of this one or beside it: it follows the platform's own join
model, and the two fight over the character bootstrap and the face. If you
cannot run one, do not write anything that waits
on `Open77.ready.isReady` or on `onPlayerReady` — on your server they will wait
for ever. `opx77_core` itself waits on neither, so characters still load and
are still placed. See [The entry gate](../concepts/entry-gate.md).

## A player is stuck on the loading screen {#stuck-loading-screen}

**Symptom.** A player connects, the OPEN//77 loading cover comes up, and it
never lifts. The same host warning as above arrives once a minute, with
`gameplay announced=False` and `snapshots=True` filled in:

```text
player 3 has been connected for 180000ms and the platform still cannot confirm
they are in the world (gameplay announced=False, snapshots=True); nothing will
place them until it can. A client still in the character creator is normal here;
a client already walking around is not, and means no resource is emitting
open77:session:gameplayReady
```

The client log shows `opx77_appearance` judging the pre-game menu — a debug
line, visible when the host's log level includes debug — and then never the
line that spends the bootstrap:

```text
world entry (worldReady): bootstrap phase=waiting -> menu, not announcing
```

On a working join, within `BOOTSTRAP.ROSTER_WAIT_MS` of that line, the client
log carries both of these — the body and the reason vary — and the cover lifts
once the world has streamed:

```text
bootstrap (worldReady): loading the female body, the last character played
character bootstrap resolved as female
```

**Cause.** The platform's `open77_shell` keeps the cover up for as long as the
character bootstrap is `"waiting"`, and nothing a server resource draws is
visible under it. The world only loads once a resource has called
`Open77.session.resolveCharacterBootstrap`. Two things leave it unspent:

- **An OPX//77 build from before the world-first entry** — `opx77_appearance`
  before `0.6.0`, which spent the bootstrap only on the chosen character's body.
  The roster that had to choose one was open under the cover, holding the
  keyboard, and nothing was ever chosen.
- **Any resource that draws a character selection, or anything else it waits on
  an answer to, before the bootstrap resolves.** The answer never comes.

**Fix.** Run `opx77_appearance` `0.6.0` or later together with the
`opx77_charselector`, `opx77_charcreator` and `opx77_core` of the same round;
the reference overview lists [what ships together](../reference/index.md).
Anything of your own that needs the player to choose belongs in the gameplay
world, after the bootstrap. The reasoning, and the probe that established it,
are in [The entry gate](../concepts/entry-gate.md#world-first).

## The roster never arrives {#roster-never-arrives}

**Symptom.** The world loads and the cover lifts, but no character list comes
up. The client log says, once:

```text
no roster yet: asking opx77_core again every 3000 ms
```

**Cause.** That line is `opx77_charselector` noticing it holds no roster and no
character, and starting to ask again: it reads `GetCharacters` and then calls
`RequestCharacters` every
[`ROSTER_RETRY_MS`](../reference/opx77_charselector/config.md#roster-retry-ms).
Said once and followed by the list a few seconds later, it is the retry doing its
job — the first roster can reach `opx77_core`'s client before
`opx77_charselector` has started.

Said and **never** followed by a list, the core is not answering the roster
request, or is refusing it. A current core answers the first request; a refusal
is named in the client log for as long as the list is not up:

```text
ready was refused: error.unavailable
```

`ready` is the roster request's operation. At connect the core also says which
send failed, on the server:

```text
[lifecycle] could not send the character list to 3: <error>
```

and follows it with a refusal on the `entry` operation, which the client logs as
`entry was refused: entry.failed`.

**Fix.** `error.unavailable` on the roster is almost always no database — see
[below](#no-database). A player the host will not vouch for never gets this
far: the core [disconnects them](#no-identity). If the client log instead says
`the roster could not be asked for: not_running`, `opx77_core` is not running on
the client. Right after an `opx77_core` restart that is expected and needs
nothing: `opx77_charselector` counts the core's stop as an unload, keeps asking,
and puts the list up once the core is back.

## A player is disconnected as unverified {#no-identity}

**Symptom.** A player is dropped while joining, with *"Your identity could not
be verified."* (`entry.noIdentity`) on their screen. On the server:

```text
[lifecycle] no verified identity for 3, refusing entry
```

**Cause.** At connect `opx77_core` reads the player's durable user id with
`GetPlayerIdentifier`, and the host answered nothing for this player. The core
cannot key characters to an account it does not know, so it releases its hold
and disconnects the player with `Open77.players.disconnect`. When that call is
refused — a manifest without the `players.disconnect` grant, for one — the
player stays connected instead, the client log says
`entry was refused: entry.noIdentity`, and the server says why:

```text
[lifecycle] could not disconnect 3 (no-identity): <reason>
```

**Fix.** The identity is the host's: look at the host's own log for how that
player authenticated. OPX//77 has no setting that admits a player without one.
When the second line shows, restore `players.disconnect` in `opx77_core`'s
`open77.lua`; the shipped manifest grants it.

## The stage camera is refused {#stage-camera-refused}

**Symptom.** The roster is up, but the camera stays where the game left it
rather than turning to face the character:

```text
the stage camera was refused: perspective_not_third_person
```

**Cause.** `opx77_charselector`'s stage is `Open77.camera.orbit`, and the orbit
is a view of the third-person camera: the platform refuses it while the player's
perspective is not third person. The stage asks `Open77.perspective` for third
person when it goes up and asks for the orbit again every 250 ms, so a refusal
while the world is still settling is normal. It is followed by:

```text
the stage camera is on the character again
```

**Fix.** Nothing, when that second line follows. When it never does, something
keeps the player out of third person — most likely a perspective policy that
does not allow it, declared by the gamemode or with the platform's
`/perspective` command, which prints the policy in force. Allow third person,
or set [`STAGE.ENABLED`](../reference/opx77_charselector/config.md#stage-enabled)
to `false` to leave the camera alone. The roster works either way. See
[the stage](../reference/opx77_charselector/stage.md#camera).

## The mouse still turns the stage camera {#stage-camera-unlocked}

**Symptom.** The roster or the creation form is up, and the mouse turns the
camera or the character walks. The client log said, once:

```text
Open77.players.freezeRotation is not on this client: the camera is not locked, and the character is held by teleport
the player controls were refused (permission_denied:players.controls) -- the manifest must grant players.controls
```

**Cause.** The stage locks the camera and holds the character with the
platform's player controls. The first line is a client build without them; the
second a manifest without the `players.controls` grant, usually a copy of
`opx77_charselector` from before the lock. Either way the camera cannot be
locked, and the character is held by the fallback teleport pin.

**Fix.** Deploy the current `opx77_charselector`, whose `open77.lua` grants
`players.controls`, and reconnect: `state` answers `cameraLocked = true` once the
lock holds. With no log line at all, check that
[`STAGE.LOCK_CAMERA`](../reference/opx77_charselector/config.md#stage-lock-camera)
is not `false`. See [the lock and the hold](../reference/opx77_charselector/stage.md#lock).

## Selecting a character leaves the loading cover up {#body-family-cover}

!!! warning "Known issue"
    This is a platform issue on `open77-server-2.31.13+op77.63`, not a
    configuration fault, and no resource can lift the cover. The workarounds
    are below.

**Symptom.** A player selects a character, the loading cover comes back up, and
it does not lift. It happens when the character's body family is not the body
the world loaded at join, and also when a player creates a character on the
other body. The client log shows `opx77_appearance` starting the body reload,
then the platform's own lines — the host's wording:

```text
the male body is reloading (for the character)
```

```text
Open77 scheduled a covered transition to the male pristine puppet.
Open77 body-family transition requested a covered return to menu.
```

**Cause.** A character on the other body is reloaded onto its own with
`Open77.appearance.switchBodyFamily`, which is a covered world transition. The
host puts a loading cover up for it, and nothing takes it down afterwards:
`open77_shell` lifts the cover only for the join-time pristine load, and no
`open77:shell:hide` follows the transition.

**Workaround.** `opx77_appearance` loads the body of the account's most recently
played character at join, so entering as that character involves no reload. The
body loaded is in the client log, on the `bootstrap (...)` line above. For a new
character, `opx77_charcreator` selects the body already loaded first, which keeps
that case rare.

## No player can connect at all {#nobody-connects}

**Symptom.** The server starts, appears healthy, and every client is refused
during the resource handshake with something like:

```text
script_pattern_empty:client/**/*.lua
```

**Cause.** A manifest glob matched nothing. `client/**/*.lua` requires an
intermediate directory and does not match a flat `client/main.lua`. An empty glob
is not skipped and does not warn — it **refuses the whole client resource set**,
which means nobody can join.

**Fix.** List every script on its own line, as every shipped OPEN//77 resource
does. `**` is only safe under `web_files`.

**The other cause, and the more likely one on a server that was working
yesterday.** A resource holding `players.gate` has a code path that calls
`deferrals.defer()` and never reaches `deferrals.done()` — a database callback
that never fires, an early `return`, an error swallowed inside the deferred
work. Every player is then held until
`simulation.connectGateTimeoutSeconds` expires and refused with
`connection_gate_timeout`, which is what they see on their own screen.

**Fix.** Make every branch after `defer()` end in a `done()`, including the
error branches, and give the deferred work its own guard `done()` well inside
the deadline. See [Connection control](../concepts/connection-gate.md#connecting).

## A connection gate handler never runs {#gate-never-runs}

**Symptom.** An `onPlayerConnecting` handler is registered and nothing happens;
players join as though it were not there.

**Cause.** One of three, in order of likelihood:

- The manifest does not list `players.gate`. The host skips the handler and
  says so once: `onPlayerConnecting handler ignored: the manifest lacks the
  players.gate permission`. Look for that `WRN` first.
- The resource is not running.
- The handler was registered with `RegisterNetEvent` instead of
  `AddEventHandler`. `onPlayerConnecting` is raised by the host, not sent over
  the wire.

**Related.** A player who sees `Connection refused by the server.` rather than
your own sentence was refused with `done()` given an empty string or a
non-string. A message that arrives cut short hit the 127-byte UTF-8 ceiling.

## Other players are invisible {#invisible-players}

**Symptom.** Two players are in the same place and the same routing bucket. Each
sees the other's vehicle move, but not the other's body.

**Cause.** The engine replicates a player's position, vehicle and actions, not
their look. Another client draws a player only from the body, equipment and
outfit it is handed. In this resource set
[`opx77_appearance`](../reference/opx77_appearance/index.md#presence) hands every
player's look to the others, from `0.8.0`; an older one does not, and nothing
else in the set does. Its client says why it could not publish, once:

```text
the body cannot be read (<reason>): other players cannot draw this one
```

and its server, when a published body is outside the platform's bounds:

```text
player 7 published a body this server cannot read; other players cannot draw them
```

A client that cannot put a look on a proxy says that once too:

```text
Open77.puppets.setBody is not on this client: other players are not drawn
```

A player who shows up late rather than never is normal: the first look of a
world entry waits for the character's stored clothing to read back, for at most
15 seconds.

**Fix.** Run `opx77_appearance` `0.8.0` or later with
[`PRESENT_BODIES`](../reference/opx77_appearance/config.md#present-bodies) left
on. If the platform's `open77_appearance` is also running, both presence halves
stand down and say so; the client's line is

```text
open77_appearance is running and hands looks out itself; this resource does not
```

— stop one of the two appearance resources: they fight over the bootstrap and
the face.

## A command answers "unknown command", or is silently refused {#unknown-command}

**Symptom.** An operator types `opx77.money 3 EDDIES 500` in the OPEN//77 terminal
and the host answers that the command is unknown or is not permitted. The
resource's handler never ran, so there is nothing in the resource's own log.

**Cause.** Sixty-five of the seventy-seven OPX//77 commands are registered with
`true` as the third argument to `RegisterCommand`, which makes them **restricted**:
the host resolves `command.<name>` against the caller's ACL *before* the handler
runs. There is no permission check inside any OPX//77 command and there must not
be one. So a refusal here is always the ACL, never the resource.

**Fix.** Ask the host directly, from the administration console:

```text
acl.list
acl.check 3 command.opx77.money
```

`acl.list` reports the path actually loaded — a common cause is that
`accessControl.file` in `server.jsonc` points somewhere other than where you
edited. `acl.reload` applies a change without a restart.

!!! warning "`command.opx77.*` does not grant `command.opx77`"

    A trailing wildcard grants everything *below* the prefix. The bare command
    `opx77` — the roster printout — is `command.opx77`, which is not below
    `command.opx77.`, so a principal holding only `command.opx77.*` is refused
    it and every other command works. Grant both.

    The same trap catches `opx77.weather.time.freeze`: it is below
    `command.opx77.weather.*`, so that wildcard does cover it, but a principal
    granted the exact string `command.opx77.weather.time` does **not** get
    `command.opx77.weather.time.freeze`.

The full list of restricted and open commands is in
[Getting started](getting-started.md#restricted-commands).

## The chat box has my keyboard and I cannot get out {#chat-focus}

**Symptom.** The open key was pressed, the game stopped responding to movement,
and no entry line is visible. Escape does nothing.

**Cause.** Keyboard focus was taken before the page reported ready, so the
element that owns the Escape handler does not exist yet. `opx77_chat` guards
against exactly this and refuses to open rather than trapping you:

```text
open refused: the page has not reported ready
```

`opened` is deliberately left `false` there, so the **next** press succeeds the
moment `web/chat.js` raises `chat:ready`. Press the open key again.

Every line this path can print, in the order it is reached:

| Line | Meaning |
|---|---|
| `open refused: the WebUI surface was never created` | `WebUI surface failed` was logged at start; the box does not exist. Restart the resource. |
| `open refused: the chat is disabled by the server` | Something called `setEnabled(false)`. |
| `open refused: the page has not reported ready` | Too early. Press again. |
| `keyboard focus was refused; the box will take no text` | The box is open and visible but will not accept typing. |

**If you are already stuck**, stopping `opx77_chat` hands the keyboard back: its
`onClientResourceStop` handler calls `closeChat()`, which releases the focus,
before it drops the page handle.

**A related symptom** — every message appears twice, and the open key fights
itself:

```text
open77_chat is running and is the package this one replaces
  both draw their own chat box, both answer chat:addMessage and both take
  focus on the open key, so every message is rendered twice. Drop one from
  resources.load in server.jsonc.
```

## No elevator ever adopts {#elevators-never-adopt}

**Symptom.** The floor panel opens, a floor is chosen, and every request answers
`not_adopted`. `opx77.elevators.where` reports `not adopted` against every lift.

**Cause and fix**, in the order to check them.

**1. The wire format drifted.** The client's sighting report and the server's
handler disagree about their arguments, so every sighting is rejected at the
first guard. Once, per server run:

```text
sighting rejected: first argument is not an engine hash (<argument>); the client and this handler disagree about the wire format
```

Net-event arguments are positional and unnamed, so an extra leading argument on
one side shifts every parameter on the other and nothing raises. If you have
edited either half, that is what happened.

**2. The native API is missing.** At boot, on the server:

```text
native elevator API unavailable; no elevator will be adopted
```

and on the client:

```text
native elevator API unavailable; nothing will be scanned
```

`Open77.elevators` is not present on this build. Nothing this resource can do.

**3. The official package owns the cabin.**

```text
open77_elevators is running; a lift adopted by one is refused to the other
  (the platform rejects a different owner), so whichever starts first owns
  the cabin. Drop one from resources.load in server.jsonc.
```

Each adoption the platform refuses is logged too, at most once a second per
reporting player:

```text
<key> not adopted: adopt_refused (<reason>)
```

**4. The configuration does not match the world.** Every configuration problem is
printed at boot *and* on demand by `opx77.elevators.where`, because they all
produce the same symptom — a button that does nothing:

```text
config: <problem>
```

A `SCAN_MS` that is not a whole number above zero stops the client from
scanning at all, and says so in the client log:

```text
SCAN_MS is not a whole number of milliseconds above zero; nothing will be scanned
```

**5. A lift was adopted and then never used**, so it was handed back:

```text
<key> released: adopted 10 minutes ago and never used
```

That one is normal housekeeping; the next client sighting re-adopts it.

## No bag ever loads {#inventory-core-unavailable}

**Symptom.** The inventory never opens with anything in it: players are told
*"The inventory is unavailable right now."*, the exports answer
`core_unavailable`, and the staff commands answer *"opx77_core is not
answering."* About a minute after `opx77_inventory` starts, its server log says:

```text
ready: <n> item(s), <n> stash(es), bag <slots> slots / <grams> g; core not answering (<reason>); commands: <names>
opx77_core is not answering: no bag can be loaded until it does. Start it, and list opx77_inventory in its EXPORTS.CALLERS with the inventory scope.
```

**Cause.** At start the inventory reads `opx77_core`'s `GetChanges` export up to
thirty times, two seconds apart, and none of the answers carried `ok = true`.
Either the core is not running or still booting — `<reason>` is then the
dispatch failure, such as `export_resource_unavailable` — or it answered and
refused, which leaves `<reason>` as `nil`. A core that refuses the caller says
so on its own log:

```text
[audit] event=export.denied severity=warn message="opx77_inventory called GetChanges" data=<json>
```

**Fix.** Start `opx77_core`, and list `opx77_inventory` after it in
`resources.load`. In `opx77_core/config/server.lua`, keep `EXPORTS.READ` at
`'*'` or put `opx77_inventory` in it, and keep
`CALLERS.opx77_inventory = { scopes = { inventory = true } }` — both are the
shipped defaults. Nothing needs a restart: the inventory keeps reading the core
every second and loads the bags once it answers.

## An export call answers nil, or answers `ok = false` {#export-nil-vs-refused}

**Symptom.** `Open77.exports.call(...)` came back with nothing useful and you
cannot tell whether the answer is "no" or "ask again later".

**Cause.** There are three failure levels and they mean genuinely different
things. Collapsing them is the single most common bug in a resource written
against this platform.

| Level | What you see | What it means | What to do |
|---|---|---|---|
| 1 | `Open77.exports.call` returns `nil, reason` | The call was **not dispatched**. The resource is missing, stopped, reloading, or the export name does not exist. | Nothing was decided. Retry, or let a cache age out. Never treat it as "refused". |
| 2 | `promise:await()` returns `_, callError` | It was dispatched and **resolution failed** — the handler raised. | A bug in the target. Log it. |
| 3 | `result.ok ~= true` | The target **ran and refused**. `result.error` is a stable code. An answer without `ok = true` is a refusal, never a success. | Authoritative. The answer is no, and it will still be no in a second. |

`opx77_hud` keeps the distinction explicitly: it clears the character it draws
only when `opx77_core` answered and refused, because a call that never landed
says nothing about the character.

**Fix.** Use a helper that returns the reason and, where it matters, whether the
target answered:

```lua
---@return table|nil result, string|nil reason, boolean answered
local function call(resource, name, ...)
  local state = GetResourceState(resource)
  if state ~= "running" and state ~= "starting" then
    return nil, "not_running", false
  end
  local promise, reason = Open77.exports.call(resource, name, ...)
  if not promise then return nil, tostring(reason or "not_dispatched"), false end
  local result, callError = promise:await()
  if callError then return nil, tostring(callError), false end
  if type(result) ~= "table" then return nil, "malformed_answer", true end
  if result.ok ~= true then return nil, tostring(result.error or "refused"), true end
  return result, nil, true
end
```

Two further causes of a level-1 failure worth naming:

- **`await` outside a managed coroutine.** `promise:await()` works inside a
  `CreateThread`, an event or command handler, or an exported function, which
  the host runs as a coroutine of its own. At file scope, while the resource is
  still loading, the call answers `nil, "resource_preparing"`.
- **`exports.<resource>:<name>()`.** There is no proxy on this platform.
  Indexing the function raises *attempt to index a function value*.

The whole model is set out in
[The export contract](../concepts/export-contract.md).

## The menu refuses every call with `no_surface` {#menu-no-surface}

**Symptom.** Every `opx77_menu` export answers `{ ok = false, error = "no_surface" }`.

**Cause.** At start:

```text
WebUI surface failed: <reason>
  the exports will refuse: there is nothing to draw on.
```

The exports are published whether or not the surface came up, so a caller gets a
named refusal rather than a missing export. The sweep that reclaims a stopped
owner is not running either.

**Fix.** Restart `opx77_menu`. `opx77_menu` declares `reload_policy "reconnect"`
because a CEF surface is never replaced in place, so a client that was connected
through the failure needs to reconnect.

`opx77_hud` prints the first of those lines for the same reason, and its symptom
is a blank HUD rather than a refusal. `opx77_input`, `opx77_notify` and
`opx77_prompts` print it too, followed by a second line of their own, and the
exports that need the surface answer the same `no_surface`.

## The database is absent and nobody can log in {#no-database}

**Symptom.** The server boots, the resources start, and every attempt to enter
the world is refused with `error.unavailable`, and the roster never fills.

```text
[storage] no database: <the driver's own exception text>
[storage] the core will boot, but nobody can be logged in until this is fixed
[core] opx77_core 0.6.0 is up but cannot load characters: no database
```

**Cause.** `OPX.Storage.ready()` probed with `SELECT 1` and the probe failed.
`OPX.BootError` is set to `no database` and logins are refused; everything else in
the core still runs, which is why the server looks healthy.

**Fix.** In `server.jsonc`, `database.enabled` must be `true`, and the connection
string must be reachable. Prefer the environment variable form:

```bash
export OP77_DATABASE_CONNECTION='Server=localhost;Port=3306;Database=open77;User ID=open77;Password=...;SslMode=None'
```

`opx77_core` must also hold `database.access` in its manifest — it does by
default. The `opx77` command reports the degraded state to an operator in game:

```text
opx77_core 0.6.0 -- 0 character(s) in the world, 2 session(s) connected
  DEGRADED: no database
```

**The related failure** is a database that answers but where a table cannot be
created:

```text
[storage] creating <table> failed: <detail>
[core] refusing to accept logins against an incomplete schema
[core] opx77_core 0.6.0 is up but cannot load characters: schema failed: <table>
```

The core creates its tables at boot, in order, with `CREATE TABLE IF NOT EXISTS`,
and stops at the first one that fails. It refuses logins rather than writing
characters into a schema it does not have. The usual `<detail>` is a permission
the database account lacks, or a table left over from an older shape that a
later table's foreign key cannot reference. `CREATE TABLE IF NOT EXISTS` never
alters an existing table, so fix it by dropping the offending table — or the
database — and restarting the core; see
[Persistence](../concepts/persistence.md#schema).

## Creating a character always answers `error.unavailable` {#create-unavailable}

**Symptom.** The identity form is filled in and submitted, and every attempt
comes back refused with `error.unavailable`. Logins and the roster work.
`opx77_core` says the database refused the statement, turning the storage
failure into a code the player can read:

```text
[core] "query-failed" has no catalogue entry; answering error.unavailable
```

and the host's database log — the host's wording, not OPX//77's — says why. On
an `opx77_core` older than `0.4.0` it was:

```text
[ERR] [database] resource 'opx77_core' update failed: Parameter '@position' must be defined.
```

**Cause.** A new character has no stored position, and an older core handed the
`INSERT` `position = nil`. The host's database bridge **drops a `nil`
parameter** instead of binding `NULL`, the statement reaches MySqlConnector
naming a parameter it was never given, and the connector refuses all of it. The
same shape waited on every nullable column the core writes — `position` and
`appearance` on a save, a cleared face, and a vehicle's `appearance`, `body` and
`paint` — so the same line naming `@appearance`, `@body` or `@paint` is the same
fault. With a current core, the host's line names whatever else the database
refused.

**Fix.** Update `opx77_core`: absence travels as an empty string and each
statement turns it back into `NULL` with `NULLIF(@x, '')`. A server plugin or a
resource of your own that writes a nullable column needs the same treatment —
see [Persistence](../concepts/persistence.md#nil-parameters).

## Two resources are placing the same player {#conflicting-placers}

**Symptom.** A player spawns, is moved, and is then moved somewhere else — or
lands in the right place on one connect and the wrong one on the next, with no
pattern.

```text
[core] <name> is running and also places players; see CONFLICTING_PLACERS in config/server.lua
```

**Cause.** Placement on this platform is kill-then-respawn, not a transform
write, and two resources doing it race: the last one wins, with no rule saying
which. There is no arbitration — the core has no way to tell another placer to
stand down. At boot it asks `GetResourceState` about every name in
`CONFLICTING_PLACERS`, and warning is the only thing it does with the answer.

**Fix.** Run one placer. Drop the other from `resources.load` in `server.jsonc`,
or add its name to `CONFLICTING_PLACERS` in `opx77_core/config/server.lua` so at
least the warning names it next time.

## Characters spawn inside a building {#default-spawn}

```text
[core] DEFAULT_SPAWN.SET is false in config/shared.lua: characters with no stored position are left where the game put them. Run `opx77.here` in game to print a coordinate in the right shape.
```

**Fix.** Stand where a new character should appear and run `opx77.here`. It
prints a `DEFAULT_SPAWN` block already formatted for `config/shared.lua`, which
is the point: a transposed digit puts every new character on the server inside a
wall.

## A session slot was reused by somebody else {#slot-eviction}

```text
[core] slot <n> now belongs to a different account, evicting
```

**Cause.** The host recycles player ids. The core keys its session table by that
id and detects when the account behind one has changed. This line is the core
doing the right thing, not a fault — but if you see it constantly, something is
churning connections.

## Notifications go to the wrong corner {#notify-position}

In the client log:

```text
[exports] NOTIFY_POSITION "topleft" is not one of the documented open77_notifications positions
```

**Cause.** `NOTIFY_POSITION` in `config/shared.lua` is not one of the seven
accepted values. It is checked once at load, not per call, so a UI that asks a
hundred times does not get a hundred lines — and it is warned about rather than
dropped: the value still goes out with every toast.

**Fix.** Use one of the seven: `middle_left`, `top_left`, `top_center`,
`top_right`, `bottom_left`, `bottom_center`, `bottom_right`.

## Still stuck {#still-stuck}

- `opx77` (restricted) prints the version, the session count, every loaded
  character and the boot error if there is one.
- `opx77.where <playerId>` (restricted) prints everything the **server** believes
  about one player — session, gate, life phase, position, job, gang, balances.
  It deliberately does not agree with the client: a report that agreed would be
  useless for diagnosing a disagreement between the two.
- `opx77.elevators.where [key]` (restricted) prints adoption state per lift.
- `opx77.admin.read.status` (restricted) prints `opx77_admin`'s counts, uptime
  and the state of every resource it depends on, and
  `opx77.admin.read.players` every connected player's state and bucket.
- `acl.check <playerId> <permission>` answers the exact question the host asks.
- Raise the **host's** log level to see the core's own debug chatter. It is the
  host's setting: the framework has no log-level key of its own.

If the answer is not here, [the FAQ](faq.md) covers the questions that are about
the design rather than a fault.
