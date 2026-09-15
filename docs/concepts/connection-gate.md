---
title: Connection control — who gets in
description: The gate that decides whether a player is admitted at all, as distinct from the readiness gate that decides when a resource may act on one — onPlayerConnecting and its deferrals, onPlayerRejected, the reason on onPlayerDisconnected, durable identity, and the wall clock the sandbox finally has.
---

# Connection control

There are two gates on the way into Night City and they answer different
questions. This page is the first one: **whether** a player gets in. [The entry
gate](entry-gate.md) is the second: **when** a resource may act on one who
already has.

Conflating them is the easiest mistake to make here, because the platform calls
both of them gates and OPX//77 holds only the second.

## The order of things {#order}

A connection passes through these stages. Resources take part in the ones in
bold.

1. The transport connects. Nothing is known about the player.
2. The client sends its hello: protocol, game build, display name, identity
   public key with a proof, and a Master connect ticket where the server wants
   one.
3. The server checks the platform facts — protocol and build, the identity
   proof against the Master key, the ticket, identity-key stability, capacity.
   A failure here is a refusal resources are **told** about
   (**`onPlayerRejected`**) and cannot influence.
4. **`onPlayerConnecting`**, the resource gate. Every running resource holding
   `players.gate` that registered a handler is asked. Refuse, hold, or let
   through.
5. The player is admitted: welcome packet, player id,
   **`onPlayerConnected(playerId)`**.
6. The readiness gate (`Open77.ready`) and **`onPlayerReady`**. See
   [The entry gate](entry-gate.md).
7. The session ends: **`onPlayerDisconnected(playerId, reason)`**.

!!! warning "`onPlayerConnected` carries one argument"

    Only the player id. There is no name parameter, and a handler that declares
    one reads `nil` every time. Resolve the name with
    [`Open77.players.identity`](#identity) instead.

## `onPlayerConnecting(player, deferrals)` {#connecting}

Requires `players.gate` in the manifest. A resource with a handler and no
permission is skipped, with one `WRN` saying so — a silent no-op is the most
common reason a gate "never runs".

At this stage there is **no player id yet**, so no `Open77.players.*` call can
be made about them. What is known is on the `player` table:

| Field | What it is |
|---|---|
| `userId` | The Master account id, a GUID. Stable across renames and reinstalls, verified by the identity proof before the gate runs. **This is the key a list is built on.** |
| `name` | The display name the client presents. The player can change it: match on it for convenience, never for security. |
| `publicKey` | The identity public key, base64. |
| `fingerprint` | `sha256:<hex>` of the public key, the same string `identity.dump` prints in the client console. |
| `ticket` | Whether a verified Master connect ticket was presented. |

Returning without deferring accepts. `deferrals.done("message")` refuses, and
the player reads that message on their own screen.

| Call | Effect |
|---|---|
| `deferrals.defer()` | Hold the player, for an answer that is not immediate. |
| `deferrals.update(message)` | A progress note. Goes to the **server log**, not to the player — the handshake has no progress channel. |
| `deferrals.done()` | Release your hold. |
| `deferrals.done(message)` | Refuse. One refusal is final, whatever any other resource says. |

The message is trimmed to 127 bytes of UTF-8 and stripped of control
characters; an empty one becomes `Connection refused by the server.`

### Two rules worth memorising

**Every branch after `defer()` must reach `done()`.** The deadline is
`simulation.connectGateTimeoutSeconds` in `server.jsonc` — 8 seconds by
default, 0.5 to 9 allowed, and the client abandons the handshake at 10 anyway.
A callback that never fires refuses *everyone* with `connection_gate_timeout`.
This is the single most common way to close a server by accident.

**A handler that raises counts as an acceptance.** The host fails open on
purpose, so that a typo in one script cannot empty the server. Where refusing
is the safe default, `pcall` your own check and refuse in the error branch
yourself.

## `onPlayerRejected(userId, name, code, message)` {#rejected}

Raised in **every** running resource, no permission needed, for every
connection refused once its hello was read — whether by the platform checks or
by a gate. It is not a departure: there is no `playerId`, because the player
was never admitted.

`code` is one of `protocolmismatch`, `gamebuildmismatch`, `invalidhello`,
`serverfull`, `duplicatehello`, `refused`. For `refused`, `message` is the
gate's own text or `connection_gate_timeout`; otherwise it is a machine token
such as `expected_game_build:<build>`, `identity_proof_invalid`,
`connect_ticket_required`, `identity_key_changed` or `server_full`.

This is the cheapest diagnostic on the server. "Players say they cannot
connect" becomes a named cause — a build mismatch after an update, a rotated
identity key, somebody else's gate timing out — for the price of one handler.

!!! danger "Treat `userId` and `name` here as untrusted"

    For `invalidhello` they come from a hello that could not be read, and for
    `identity_proof_invalid` they are what the client *claimed* and failed to
    prove. Bound and strip them before they reach a log line or a UI.

## `onPlayerDisconnected(playerId, reason)` {#disconnected}

The event every resource already knew now carries a reason. `playerId` arrives
as a **string**, like every host event argument.

`reason` is `connection_closed` when the transport dropped or the player quit,
and otherwise the text the disconnect was queued with by
`Open77.players.disconnect`, `kick` or `ban`. That distinction is what
separates a save that was lost because somebody's link died from one that was
lost to a bug.

## Reading an admitted player's identity {#identity}

`Open77.players.identity(playerId)`, alias `GetPlayerIdentity`, answers
`{ userId, name, publicKey, fingerprint, joinedAt }` for an admitted player, or
`nil`. `joinedAt` is ISO 8601 UTC. **No permission is needed.**

It is how a command turns the short session id an operator can see into the
durable `userId` a stored row must be keyed against — and the reason a resource
no longer needs its own `playerId → account` bookkeeping.

`Open77.players.identifier(playerId)` and `Open77.players.name(playerId)`
remain the short forms, and are the better choice in a per-tick sweep, where a
returned string beats a freshly allocated table.

!!! warning "It answers for **admitted** players only"

    By the time `onPlayerDisconnected` runs, the player is gone and `identity`
    returns `nil`. Anything a departure handler needs about them must be
    captured at `onPlayerConnected` and kept until then.

## Removing a player who is in {#removing}

| Call | Permission | Effect |
|---|---|---|
| `Open77.players.disconnect(playerId, reason?)`, alias `kick` | `players.disconnect` | Closes the session. The reason is shown to the player **and** delivered to `onPlayerDisconnected`. |
| `Open77.players.ban(playerId, reason?, durationSeconds?)` | `players.ban` | Records a device ban for this server at the Master and disconnects now. Enforced at the identity stage on the next connect, so it holds with no resource running. |

## The wall clock {#wall-clock}

The server sandbox has no `os`, and `GetGameTimer` and
`Open77.time.monotonic` both restart with the process. Two calls answer an
actual instant, neither needing a permission, and both **in server resources
only** — a client has no wall clock, and neither has it `GetGameTimer`:

| Call | Answers |
|---|---|
| `Open77.time.unix()`, alias `GetUnixTime` | Seconds since 1970-01-01 UTC, fractional |
| `Open77.time.utc()`, alias `GetUtcTimestamp` | The same instant, ISO 8601 |

The division is simple and worth stating plainly, because getting it backwards
is a real bug in both directions:

- **Intervals** — cooldowns, rate-limit windows, deadlines, anything measured
  inside one process — belong on `OPX.Now()` or `Open77.time.monotonic`. A wall
  clock jumps with NTP and would make them misfire.
- **Instants** — anything written to a column, a JSON blob, a log line, or read
  back after a restart — belong on the wall clock. A monotonic value persisted
  and compared after a restart is meaningless: every stored value is suddenly in
  the future.

## Where OPX//77 stands {#opx77}

`opx77_core` does **not** request `players.gate`, deliberately. A gate handler
in the framework would put every connection behind the resource with the widest
failure surface, and since the host admits a player whose handler raised, a core
bug would be a silent open door rather than a loud one. A gate belongs in a
small resource that does nothing else — the platform ships
`open77_gatekeeper` as exactly that, and it does not start by itself
(`ensure open77_gatekeeper`).

`opx77_core` does request `players.disconnect`, for one purpose: a player the
host gives no verified identity for. With no `userId` there is nothing to key
a character against, and releasing the readiness gate, which is what it used to
do, dropped that player into the world with no character and no way to get one.
They are disconnected with `entry.noIdentity`. The other entry failures — a
roster query that fails, nobody choosing a character before `SELECTION_MS` —
release the gate and do not disconnect: `opx77_charselector` keeps asking for
the roster, and a player still in `opx77_charcreator`'s form stays in. The
disconnect reason reaches the core's audit log as a `session.disconnect` line. `players.ban` is not requested and should not
be; a ban is a moderation decision, not a framework one.

## Where to go next {#next}

- [The entry gate](entry-gate.md) — the *other* gate: readiness holds, liveness
  and placement.
- [Identity](identity.md) — what the platform vouches for, and what it does not.
- [Persistence](persistence.md) — what a durable key is for.
