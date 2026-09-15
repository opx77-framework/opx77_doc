---
title: opx77_elevators
description: Job-gated in-world elevators for OPX//77 — one building's door policy, and the clearest worked example in the repository of what a satellite resource can and cannot prove.
---

# opx77_elevators

Job-gated in-world elevators: a floor list on the lifts Night City already has,
each floor opened or closed by the job a character holds in
[`opx77_core`](../opx77_core/index.md). An Arasaka executive floor, the NCPD
holding level, a ripperdoc's back room — the jobs, the grades and the wording
all live in `config.lua`.

It is also the smallest complete example of a **satellite**: a resource that
lives outside `opx77_core`, has to reach the core for the one fact it cares
about, and today reads that fact on the client. Read it before writing your own.

| At a glance | |
|---|---|
| **Version** | `0.5.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `local` — no CEF surface; the server re-adopts from the next client sighting |
| **Permissions** | `network.events`, `world.elevators`, `elevators.read`, `acl.read` |
| **Sides** | client, which runs the gate, the scan and the panel, and server, which adopts, locks and re-derives every request |
| **Exports** | six, all client-side — see [Exports](exports.md) |
| **Commands** | one, ACL-restricted — see [Commands](commands.md) |
| **Events** | five net events between the two halves, plus the answer channel — see [Events](events.md) |
| **Optional at runtime** | [`opx77_menu`](../opx77_menu/index.md) for the panel, [`opx77_core`](../opx77_core/index.md) for the job, [`opx77_notify`](../opx77_notify/index.md) for the refusal toast |

Nothing is declared as a hard dependency. Without `opx77_core` every gated floor
closes and every public floor stays open; without `opx77_menu` the built-in
panel is unavailable and the exports carry on unchanged; without `opx77_notify`
a floor refused from the panel is said in a chat line instead of a toast.

!!! danger "The job check is a client-side hint, and no setting turns it into anything else"

    This resource's **server half does not check a player's job**. A server
    half can call another resource's server exports, but `opx77_core` has no
    server export that answers a job: [`GetIdentity`](../opx77_core/exports/server.md#getidentity)
    carries identity, connection and load state only. So the check runs on the
    client, where the core's `PlayerData` can be read, and a modified client
    skips every line of it.

    **Do not gate money, contraband or a body count on it.** Gate the flavour:
    which floor a lift stops at, which corridor a story happens in. A decision
    that has to be unforgeable belongs in `opx77_core`'s server VM, where the job
    is already in memory — see
    [Writing a server plugin](../../guides/writing-a-server-plugin.md).

## What the server does prove {#what-the-server-proves}

The other half of the honest answer, and the reason this resource is worth
reading. The server proves everything a server *can*, and it proves it from its
own authority rather than from anything the client said.

Every adopted lift is locked with the host's own
`Open77.elevators.flags.locked`. That is the platform's switch for *refuse
requests coming from a client*, so the elevator authority rejects a request sent
straight off a client and this resource's server half is the only way the cabin
moves.

The lock is set with `setFlags`, OR-ed onto whatever flags the lift already had:
`powered` is left exactly as the host set it, because an operator who cut the
power to a shaft did it on purpose. A lift that could **not** be locked is a
warning line rather than a rollback — an unlocked lift still answers this
resource, it just also answers a client directly, and running that way unnoticed
is the real failure.

On every floor request the server re-derives:

| It checks, itself | Refusal |
|---|---|
| The elevator key is one `config.lua` declares | `no_such_elevator` |
| The floor index is one that elevator declares | `no_such_floor` |
| The elevator is one **this resource** adopted, and the host still has it | `not_adopted` |
| The index is inside the native device's own floor count | `floor_out_of_range` |
| The player has a replicated position at all | `no_position` |
| The player is in the elevator's routing bucket | `wrong_bucket` |
| The player is within `USE_RADIUS` of the **declared** shaft position, across the ground | `too_far` |
| The player is inside the rate limit — checked first, before any of the above | `rate_limited` |
| The host accepted the move | `move_rejected` |

Distance is measured against the declared shaft position, never the cabin's,
and it is measured **across the ground**: `X` and `Y` decide reach, and `Z` is
recorded and never compared. A cabin parked at the top of the shaft is thirty
metres from the player standing at the ground-floor panel, who is exactly the
person allowed to call it — and the player on the twelfth storey is exactly as
close to the panel as the one in the lobby, because an elevator is callable from
every floor of its own shaft.

!!! warning "The residual, exactly"

    A modified client reaches **the configured floors of an elevator it is
    standing at**, at any height inside that shaft's footprint. It cannot reach
    a floor no `config.lua` entry declares, a lift in another bucket, a lift
    across the map, or a lift this resource never adopted. It can reach a gated
    floor of the lift it is standing next to, from any storey of it. Design as
    though it will.

## What a satellite can and cannot prove {#satellite-lesson}

The general shape, stated once, because every satellite hits it:

- **The client can ask the core anything.** `Open77.exports.call` reaches
  `opx77_core`'s client half, which holds `PlayerData`. This resource does that
  every `POLL_MS`, and again on every `opx77:client:playerDataChanged`.
- **The server can ask the core only what its server exports answer.** A server
  half reaches another resource through `Open77.exports.call`, as
  `opx77_inventory` reads `opx77_core`'s identity and inventory exports; there is
  still no cross-resource event bus, and `TriggerEvent` walks only its own VM.
  `opx77_core`'s server exports answer who a player is and whether a character
  is loaded, not the character's job. So this resource's server half knows what
  the host knows — positions, buckets, entity ownership, rates — and nothing
  about a job.
- **So a satellite's server half must re-derive every clause it intends to
  enforce**, from the host or from a server export, and must be honest in its
  documentation about the clause it does not.

[The client export contract](../../concepts/export-contract.md) explains the
call shape and its three levels of failure;
[Integration channels](../../concepts/integration-channels.md) sets out what
each of the four channels can carry. If your decision has to be unforgeable, it
is not a satellite — it is a file in `opx77_core/server/`, or a server export the
core answers it through.

## Where the pieces live {#layout}

| File | Does |
|---|---|
| `config.lua` | shared. The elevators, the floors, the job requirements, the radii |
| `shared/text.lua` | shared. `OpxElevators.Text.Clean`, which cuts in **characters** while bounding the scan in bytes at `maximum * 4` through a local `span` |
| `shared/locale.lua` | shared. The catalogue, and the `locale(key, params)` every file below it calls |
| `locales/en.lua`, `locales/fr.lua` | shared. The player-facing text, keyed `elevators.<thing>` |
| `shared/access.lua` | shared. The clock (`OpxElevators.NowMs`), the numbers read once from `config.lua`, and the gate: which floor, which job, which grade, how stale |
| `client/state.lua` | what this client knows and how old each piece of it is |
| `client/main.lua` | the link to `opx77_core`, the scan, the net events, the runtime API |
| `client/panel.lua` | the floor list, borrowed from `opx77_menu`, and the refusal toast |
| `client/exports.lua` | the six public exports |
| `server/main.lua` | adoption, the lock, the re-derived request, the diagnostic command |

The LuaLS types and stubs live in `std/` (`std/types.lua` for the shapes and
the `ElevatorError` codes) and are never loaded. Why the code is written the way
it is — in French — is in the resource's `docs/ARCHITECTURE.md`.

`shared/access.lua` is loaded by both halves for different halves of the same
question: the client asks *may this player press this button*, the server asks
only *is this a button `config.lua` declared*, because the server has no
character to ask about.

## Permissions {#permissions}

```lua
permissions {
  "network.events",
  "world.elevators",
  "elevators.read",
  "acl.read",
}
```

| Permission | For |
|---|---|
| `network.events` | the five net events between the two halves — `sighted` and `request` upward, `bound`, `answer` and `released` downward — plus the diagnostic's chat lines and its chat suggestion. See [Events](events.md) |
| `world.elevators` | server-only. `adopt`, `get`, `all`, `setFlags` for the lock, and `goTo` to move the cabin |
| `elevators.read` | the client's streamed snapshots — `Open77.elevators.nearby(radius)`, which is how a lift is sighted at all |
| `acl.read` | server-only, read-only. `Open77.acl.isAllowed`, so the diagnostic command's chat suggestion is sent only to a player the ACL would let run it |

!!! info "The permission it deliberately does not ask for"

    The platform also defines `elevators.request`, a client's own bounded button
    and call intentions. This resource does not request it, because no press ever
    goes that way: every request travels to this resource's server half, which is
    the only holder of `world.elevators` in the set and the only thing a locked
    cabin will answer.

!!! warning "Nothing is scanned without the native API"

    On a client that has not loaded the world, or one whose game build predates
    the elevator API, `Open77.elevators` is absent. Both halves say so once, as an
    error line, and then do nothing — which beats a stack trace per scan.

## Pages {#pages}

- [Exports](exports.md) — the six client exports, with the errors each can
  answer.
- [Error codes](errors.md) — every code, who decided it, and which of them are
  hints.
- [Events](events.md) — the five net events between the two halves, the answer
  channel, and everything this resource listens to.
- [Commands](commands.md) — the ACL-restricted diagnostic command.
- [Configuration](config.md) — every key of `OPX_ELEVATORS_CONFIG` with its
  shipped default, how to configure an elevator, and where the player-facing
  text lives.
- [Types](types.md) — the shapes the exports answer with.

## See also {#see-also}

- [`opx77_core`](../opx77_core/index.md) — where the job actually lives, and
  where an unforgeable decision belongs.
- [`opx77_menu`](../opx77_menu/index.md) — the surface the floor list is drawn
  on.
- [Writing a resource](../../guides/writing-a-resource.md) — the satellite
  pattern this resource is an instance of.
