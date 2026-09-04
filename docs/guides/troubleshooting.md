---
title: Troubleshooting OPX//77
description: Symptom, the exact log line the code actually prints, cause and fix — for the failures OPX//77 and the OPEN//77 platform produce most often, from a permanently closed readiness gate to an export call that answers nil.
---

# Troubleshooting

Every entry below is a symptom, the **exact** line the shipped code prints when it
happens, the cause, and the fix. The lines are quoted from the resources rather
than paraphrased, so they are safe to grep the platform log for; the two that come
from the host itself rather than from OPX//77 say so.

Every OPX//77 log line is written through `Open77.log`, the host's own logger,
including the core's. The core prefixes a scope in square brackets —
`[storage]`, `[lifecycle]`, `[core]`, `[player]`, `[events]`, `[appearance]`,
`[audit]` — and the satellites carry the host's own resource prefix. The host
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
[lifecycle] no resource here emits `open77:session:gameplayReady`, so the
`__platform` hold never clears and `Open77.ready.isReady` stays false
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

**Fix.** Start `opx77_appearance` — it ships with the framework and the core's
boot check looks for it by that name or by the official `open77_appearance`. Any
other resource that emits `open77:session:gameplayReady` does just as well. If
you cannot run one, do not write anything that waits
on `Open77.ready.isReady` or on `onPlayerReady` — on your server they will wait
for ever. `opx77_core` itself reads neither, so characters still load and are
still placed. See [The entry gate](../concepts/entry-gate.md).

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

## A command answers "unknown command", or is silently refused {#unknown-command}

**Symptom.** An operator types `opx77.money 3 EDDIES 500` in the OPEN//77 terminal
and the host answers that the command is unknown or is not permitted. The
resource's handler never ran, so there is nothing in the resource's own log.

**Cause.** Sixteen of the twenty-four OPX//77 commands are registered with
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
`onClientResourceStop` handler calls `closeChat()` before dropping the page
handle, precisely because "a stop that leaves focus held leaves the player unable
to move".

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
sighting rejected: first argument is not an engine hash (...); the client and
this handler disagree about the wire format
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

**4. The configuration does not match the world.** Every configuration problem is
printed at boot *and* on demand by `opx77.elevators.where`, because they all
produce the same symptom — a button that does nothing:

```text
config: <problem>
```

**5. A lift was adopted and then never used**, so it was handed back:

```text
<key> released: adopted 30 minutes ago and never used
```

That one is normal housekeeping; the next client sighting re-adopts it.

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
| 3 | `result.ok == false` | The target **ran and refused**. `result.error` is a stable code. | Authoritative. The answer is no, and it will still be no in a second. |

`opx77_hud` keeps the distinction explicitly, and its comment is the rule in one
line: *"only a refusal clears the HUD: a call that never landed says nothing about
the character"*.

**Fix.** Use a helper that returns the reason and, where it matters, whether the
target answered:

```lua
---@return table|nil result, string|nil reason, boolean answered
local function call(resource, name, ...)
  if GetResourceState(resource) ~= "running" then
    return nil, "not_running", false
  end
  local promise, reason = Open77.exports.call(resource, name, ...)
  if not promise then return nil, tostring(reason or "not_dispatched"), false end
  local result, callError = promise:await()
  if callError then return nil, tostring(callError), false end
  if type(result) ~= "table" then return nil, "malformed_answer", true end
  if result.ok == false then return nil, tostring(result.error or "refused"), true end
  return result, nil, true
end
```

Two further causes of a level-1 failure worth naming:

- **`await` outside a coroutine.** `promise:await()` only works inside a
  `CreateThread`. An export handler is not a coroutine, so an export that needs
  to call out must queue the work and answer "asked".
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

`opx77_hud` prints the same line for the same reason, and its symptom is a blank
HUD rather than a refusal.

## The database is absent and nobody can log in {#no-database}

**Symptom.** The server boots, the resources start, and every attempt to enter
the world is refused with `error.notLoggedIn` or nothing at all.

```text
[storage] no database: <the driver's own exception text>
[storage] the core will boot, but nobody can be logged in until this is fixed
[core] opx77_core 0.3.0 is up but cannot load characters: no database
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
opx77_core 0.3.0 -- 0 character(s) in the world, 2 session(s) connected
  DEGRADED: no database
```

**The related failure** is a database that answers but has the wrong schema:

```text
[storage] cannot create the migration table: <detail>
[storage] migration <name> statement <n> failed: <detail>
[core] refusing to accept logins against an unknown schema
```

The core refuses logins rather than writing characters into a shape it does not
recognise. Fix the migration, do not work around it: the alternative is silent
data loss on the next save.

## Two resources are placing the same player {#conflicting-placers}

**Symptom.** A player spawns, is moved, and is then moved somewhere else — or
lands in the right place on one connect and the wrong one on the next, with no
pattern.

```text
[core] <name> is running and also places players
[core]   two resources moving the same player means the last one wins, with no
[core]   rule saying which. See CONFLICTING_PLACERS in config/server.lua.
```

**Cause.** Placement on this platform is kill-then-respawn, not a transform
write, and two resources doing it race. There is no arbitration and there cannot
be one — the core cannot ask another server resource to stand down, because
server resources cannot call each other. `GetResourceState` is the only question
it can ask, and warning is the only thing it can do with the answer.

**Fix.** Run one placer. Drop the other from `resources.load` in `server.jsonc`,
or add its name to `CONFLICTING_PLACERS` in `opx77_core/config/server.lua` so at
least the warning names it next time.

## Characters spawn inside a building {#default-spawn}

```text
[core] DEFAULT_SPAWN.SET is false in config/shared.lua
[core]   characters with no stored position will be left where the game put them.
[core]   run `opx77.here` in game to print a coordinate in the right shape.
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

```text
[exports] NOTIFY_POSITION "topleft" is not one of the documented
open77_notifications positions; expected one of middle_left, top_left,
top_center, top_right, bottom_left, bottom_center, bottom_right
```

**Cause.** `NOTIFY_POSITION` in `config/shared.lua` is not one of the seven
accepted values. It is checked once at load, not per call, so a UI that asks a
hundred times does not get a hundred lines — and it is warned about rather than
dropped.

**Fix.** Use one of the seven names in the message.

## Still stuck {#still-stuck}

- `opx77` (restricted) prints the version, the session count, every loaded
  character and the boot error if there is one.
- `opx77.where <playerId>` (restricted) prints everything the **server** believes
  about one player — session, gate, life phase, position, job, gang, balances.
  It deliberately does not agree with the client: a report that agreed would be
  useless for diagnosing a disagreement between the two.
- `opx77.elevators.where [key]` (restricted) prints adoption state per lift.
- `acl.check <playerId> <permission>` answers the exact question the host asks.
- Raise the **host's** log level to see the core's own debug chatter. It is the
  host's setting: the framework has no log-level key of its own.

If the answer is not here, [the FAQ](faq.md) covers the questions that are about
the design rather than a fault.
