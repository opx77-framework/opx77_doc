---
title: The opx77_animations resource
description: opx77_animations is emotes for OPX//77 — a command, a picker drawn by opx77_menu and eight client exports that ask the platform's animation service to play one of fifteen profiles, and a presenter that poses every streamed body.
---

# opx77_animations

Emotes and animations. A player types `/e dance`, or `/e` on its own for a
categorised picker, and everyone in the routing bucket sees it. Another resource
plays and stops an animation through [client exports](exports.md).

| At a glance | |
|---|---|
| **Version** | `0.1.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `local` — the picker is `opx77_menu`'s surface, not this resource's, and the mirror of who plays what is rebuilt from the service's next snapshot |
| **Permissions** | `network.events`, `players.animations.control`, `animations.presentation` |
| **Sides** | server, which decides what is asked of the platform's service; client, which mirrors the service, poses bodies, draws the picker and publishes the exports |
| **Exports** | eight, all client — see [Exports](exports.md) |
| **Commands** | four, all open as shipped, all renamable — see [Commands](commands.md) |
| **Events** | three local events a caller listens on — see [Events](events.md) |
| **Optional at runtime** | [`opx77_menu`](../opx77_menu/index.md) for the picker, [`opx77_notify`](../opx77_notify/index.md) for refusal toasts |

Nothing is declared as a hard dependency. Without `opx77_menu` there is no
picker, and the commands and exports carry on; without `opx77_notify` a refusal
or a command's answer is a chat line instead of a toast.

!!! danger "The platform's animation service is the authority, not this resource"

    The service owns every playback, replicates it to the bucket, and itself
    refuses a dead player, a player in a vehicle, or a second owner's animation
    over a running one. This resource's server half decides only what it
    **asks** the service for: the catalogue as `config.lua` leaves it, a rate
    per player, and an open readiness gate.

    A modified client can still speak to the service's own wire directly and
    skip that policy. Only the service's own checks are unforgeable. Gate
    flavour on this resource, never anything of value.

## What it asks, and what it cannot {#authority}

Every request a player makes — a typed command, a picker row, an export call —
reaches this resource's server half, which checks it in this order before the
service is called at all:

| It checks | Refusal |
|---|---|
| `Open77.animations.play` and `stop` exist on this server | `service_unavailable` |
| The name is in the catalogue, not `DISABLED`, and present on this build | `unknown_animation` |
| The variant is one of that animation's offered variants | `invalid_variant` |
| The loop word and the duration are well formed and in range | `invalid_options` |
| The player is inside [`RATE_LIMIT`](config.md#rate-limit) | `rate_limited` |
| `Open77.ready.isReady(player)` answers `true` | `player_not_ready` |

Then `Open77.animations.play(player, name, { clip, loop, durationMs })` is
called, and whatever the service refuses with — `player_not_alive`,
`player_in_vehicle`, `animation_owned` — is passed through as the service
answered it. Every code is listed under
[`AnimationError`](types.md#animationerror).

!!! warning "No readiness gate, no animations"

    `player_not_ready` is read from `Open77.ready.isReady`, and the platform's
    `__platform` hold keeps that `false` until a client sends
    `open77:session:gameplayReady`. That comes from
    [`opx77_appearance`](../opx77_appearance/index.md) or the platform's own
    `open77_appearance`. On a server with neither, **every animation request is
    refused, for ever** — see
    [The entry gate](../../concepts/entry-gate.md#platform-hold).

## The catalogue {#catalogue}

`shared/catalogue.lua` lists each animation under the platform's own profile
identifier, with the engine clip of each variant. It is a `shared_script`, so
both halves agree on what a name and a variant number mean. Fifteen animations,
73 variants, in six categories, in the order the picker draws them:

| Category | Name | Label (`en`) | Variants | Placement | Prop |
|---|---|---|---|---|---|
| `gestures` | `handsup` | Hands up | 4 | standing | — |
| | `clap` | Applaud | 3 | standing | — |
| `social` | `dance` | Dance | 6 | standing | — |
| | `phone` | Use a phone | 2 | standing | `phone` |
| `emotions` | `cry` | Cry | 4 | standing | — |
| | `think` | Think it over | 4 | standing | — |
| `relaxation` | `sit` | Sit on the ground | 4 | ground | — |
| | `meditate` | Meditate | 5 | standing | — |
| | `stretch` | Stretch | 15 | standing | — |
| `consumables` | `smoke` | Smoke a cigarette | 11 | standing | `cigarette` |
| | `cigar` | Smoke a cigar | 6 | standing | `cigar` |
| | `drink` | Drink from a can | 6 | standing | `can` |
| `interactions` | `give` | Hold out an item | 1 | standing | — |
| | `examine` | Kneel and look closer | 1 | ground | — |
| | `wounded` | Sit wounded | 1 | ground | — |

`prop` and `placement` are what the platform does with the profile. They are
reported to a caller of [`list`](exports.md#list) and change nothing here.

**The offer is checked against the running build.** At boot the server asks
`Open77.animations.get` — or, without it, `Open77.animations.list` — for each
profile. A profile the build does not have, or a clip it does not list, is logged
and not offered, and every client is sent what is. A name in
[`DISABLED`](config.md#disabled) is logged as `<name> is disabled in config.lua`
and not asked about at all.

```text
<name> is not a profile on this build; not offered
<name> variant <n> (<clip>) is not on this build; not offered
<count> catalogue entries could not be checked against this build; offered as written
ready: <animations> animations, <variants> variants offered; presenter <PRESENTER>
```

The third line is what a build that cannot be asked produces: those entries are
trusted as written rather than dropped. The last line is the boot banner, always
printed.

**Variant numbers are this resource's own**, 1-based, in the order the catalogue
writes them. They are not the order `open77_animations`' `/anim info` prints. The
words shown beside a variant in the picker are the engine's clip name, reduced —
identifiers rather than text, and never translated.

!!! info "Adding an animation needs a profile the platform ships"

    This resource asks the service to play a profile by name. It cannot bring a
    profile of its own, so a row added to the catalogue for a profile the build
    lacks is logged and not offered.

## Who poses the bodies {#presenter}

The service replicates **state**: who is playing which clip, at which step, in
which cycle. Something on each client still has to pose the streamed bodies to
match. `client/presenter.lua` does that: it mirrors the service's
`open77:animations:state` and `open77:animations:snapshot` wire for this
client's bucket, asks for a fresh snapshot every five seconds, and poses every
streamed body with the presentation natives.

Two presenters on one body restart each other's clip, so
[`PRESENTER`](config.md#presenter) decides, once a second, whether this client
poses at all. Shipped as `"auto"`, it steps aside while the platform's
`open77_animations` is running or starting and poses otherwise. The client says
which, when it changes:

```text
posing bodies on this client (PRESENTER auto)
leaving bodies to open77_animations (PRESENTER auto)
```

The mirror and the [`changed`](events.md#changed) event run either way, so
[`state`](exports.md#state) answers the same whether or not this client is the
one posing.

A body whose pose the natives refuse is raised as
[`failed`](events.md#failed). When it is the **local** player's, the playback is
stopped rather than left running for everybody else to see alone, and the player
is told.

## Who owns an animation an export started {#ownership}

An animation started through [`play`](exports.md#play) is remembered against the
calling resource, read from the host. When that resource stops, the animation is
stopped with it:

```text
<resource> stopped; ending the animation it started
```

The owner is only remembered for the playback that is running. [`stop`](exports.md#stop)
ends the local player's animation whoever started it — a command, the picker, or
another resource.

## Compatibility with the platform's packages {#compatibility}

**`open77_animations`.** This resource does what that package's `/anim` command
and its `list`, `get`, `state`, `request` and `cancel` exports do, under its own
names. It does not implement `sequence`, a multi-step request, because the only
entry point observed for one is the service's client wire, which would bypass
this resource's server policy. That package's local events are not raised here;
listen to the [`opx77:animations:*`](events.md) names instead.

The two run side by side. With `PRESENTER = "auto"` this resource stops posing
bodies while `open77_animations` runs, and its commands, picker and exports keep
working on top of the same service. At boot the server says which way it went:

```text
open77_animations is running; its client poses the bodies and this
  resource only asks for animations (PRESENTER auto)
```

**`open77_player_interactions`** declares `dependency 'open77_animations
>=1.0.0'`. A declared dependency is matched by resource name, so the host
refuses that package unless `open77_animations` itself is running; this resource
cannot stand in for it. Run both beside this one with `PRESENTER = "auto"`.

**`freeroam`**'s menu depends on `open77_animations` the same way, and uses the
client-side `Open77.animations` promises, which this resource neither provides
nor replaces.

## Where the pieces live {#layout}

| File | Does |
|---|---|
| `config.lua` | shared. Every operator setting — see [Configuration](config.md) |
| `shared/common.lua` | shared. The monotonic clock, the loop guard, and the wire value tests both halves apply |
| `shared/locale.lua` | shared. The catalogue, and the `locale(key, params)` every file below it calls |
| `locales/en.lua`, `locales/fr.lua` | shared. Player-facing text, keyed `animations.<thing>` |
| `shared/catalogue.lua` | shared. The fifteen animations and their clips |
| `shared/settings.lua` | shared. `config.lua` read once, checked, and resolved to fallbacks |
| `server/service.lua` | the offer against the build, the rate, the gate, and every call to the service |
| `server/commands.lua` | the four commands and the chat suggestions |
| `server/main.lua` | the inbound net events, the departure hook, the boot banner |
| `client/presenter.lua` | the mirror of the service's wire, and the bodies posed from it |
| `client/main.lua` | requests, verdicts, refusal toasts, export ownership |
| `client/picker.lua` | the picker, borrowed from `opx77_menu` |
| `client/exports.lua` | the eight public exports |

## Permissions {#permissions}

```lua
permissions {
  "network.events",
  "players.animations.control",
  "animations.presentation",
}
```

| Permission | For |
|---|---|
| `network.events` | this resource's own request and answer events both ways, and on the client the service's state and snapshot wire, which the presenter mirrors |
| `players.animations.control` | server: `Open77.animations.play`, `stop`, `get` and `list` against a player |
| `animations.presentation` | client: `Open77.animations._context`, and posing streamed bodies with `_playProfile` and `stop`. Only used while this client presents |

Without the server grant, or on a build without the service, every request is
refused and the server says so once at boot:

```text
Open77.animations.play/stop are unavailable (a build without the animation service, or players.animations.control not granted); every request is refused
```

Without the presentation natives, a client poses nothing and its
[`state`](exports.md#state) export refuses with `presentation_unavailable`:

```text
animation presentation natives unavailable; no body is posed here and the state export answers everyone as idle
```

## Pages {#pages}

- [Exports](exports.md) — the eight client exports, and which of them answer
  only that the work was asked for.
- [Commands](commands.md) — `/opx77.anim`, `/e`, `/opx77.anim.stop` and
  `/opx77.anim.list`.
- [Events](events.md) — the three local events, the private wire between the
  two halves, and the platform wire the presenter reads.
- [Configuration](config.md) — every key of `OPX_ANIMATIONS_CONFIG`, its bounds
  and its fallback.
- [Types](types.md) — every shape the exports answer with and every error code.

## See also {#see-also}

- [The entry gate](../../concepts/entry-gate.md) — why nothing plays before the
  readiness gate opens.
- [`opx77_menu`](../opx77_menu/index.md) — the surface the picker is drawn on.
- [The client export contract](../../concepts/export-contract.md) — read this
  before calling anything here.
