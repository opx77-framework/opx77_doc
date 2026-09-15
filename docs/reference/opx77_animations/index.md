---
title: The opx77_animations resource
description: opx77_animations is emotes for OPX//77 — a command, a picker drawn by opx77_menu and eight client exports that ask the platform's animation service to play one of fifteen profiles, and a presenter that poses every streamed body.
---

# opx77_animations

Emotes and animations. A player types `/e dance`, or `/e` on its own — or
presses F3 — for a categorised picker, and everyone in the routing bucket sees
it. Another resource plays and stops an animation through
[client exports](exports.md).

| At a glance | |
|---|---|
| **Version** | `0.3.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `local` — the picker is `opx77_menu`'s surface, not this resource's, and the mirror of who plays what is rebuilt from the service's next snapshot |
| **Permissions** | `network.events`, `players.animations.control`, `animations.presentation`, `input.actions` |
| **Sides** | server, which decides what is asked of the platform's service; client, which mirrors the service, poses bodies, draws the picker, holds the keys and publishes the exports |
| **Exports** | eight, all client — see [Exports](exports.md) |
| **Commands** | four, all open as shipped, all renamable — see [Commands](commands.md) |
| **Keys** | two rebindable mappings: the picker on F3, stop on X — see [Keys](#keys) |
| **Events** | three local events a caller listens on — see [Events](events.md) |
| **Optional at runtime** | [`opx77_menu`](../opx77_menu/index.md) for the picker, [`opx77_notify`](../opx77_notify/index.md) for refusal toasts, [`opx77_prompts`](../opx77_prompts/index.md) for the stop key while an animation plays |

Nothing is declared as a hard dependency. Without `opx77_menu` there is no
picker, and the commands and exports carry on; without `opx77_notify` a refusal
or a command's answer is a chat line instead of a toast; without
`opx77_prompts` the stop key is not shown, and one log line says so.

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

## The picker {#picker}

A list drawn by [`opx77_menu`](../opx77_menu/index.md), **one screen at a
time**:

| Screen | Rows |
|---|---|
| root | **Stop**, then one row per category with something offered |
| a category | its animations: one with a single offered variant plays when chosen, one with several opens its variants screen |
| an animation's variants | one **Variant n** row per offered variant, with the engine's clip words beside it when [`SHOW_VARIANT_WORDS`](config.md#picker) is on |

Every screen below the root ends in a **Back** row, and Backspace steps up a
screen as well — on the root it closes the picker, as Escape does anywhere.

**A named category opens its own screen.** `/e <category>`, or
[`openPicker`](exports.md#openpicker) with a category, puts that category's
screen up directly, with the root stacked under it and its cursor on that
category, so **Back** and Backspace return there. A category with nothing
offered in it has no row on the root, so naming it opens the root; so does `/e`
with nothing after it and the [picker key](#keys).

Each screen is its own `opx77_menu` `open`, with the stack of screens kept in
this resource, not a submenu of one tree: the whole catalogue in one menu is past
the host's bound of 1,024 values on an export call, which drops the call without
a word. A screen lists at most 40 rows and ends in a disabled *n more not shown*
row past that; the shipped catalogue comes nowhere near it. Every open replaces
a picker of this resource's already up.

**A picker that cannot open is a toast as well as a log line**, so the key or
the command never seems to do nothing:

| Why | The player sees |
|---|---|
| another resource's menu is up (`menu_busy`) | *Another menu is open. Close it first.*, as info |
| `opx77_menu` is not running | the [`menu_not_running`](types.md#animationerror) toast |
| any other refusal, a refused spec included | *The animation picker could not be opened.*, as a warning |

```text
picker root did not open: menu_busy
```

When a lower screen cannot open, the picker stays on the screen still up.

## Keys {#keys}

Two key mappings, declared with `RegisterKeyMapping` when the resource starts:

| Mapping id | Name in the pause menu (`en`) | Default | Does |
|---|---|---|---|
| `opx77_animations.picker` | *Animations: open or close the picker* | `F3` | opens the picker at its root, or closes it when it is up |
| `opx77_animations.stop` | *Animations: stop* | `X` | stops the local player's animation, whoever started it, as the picker's **Stop** row does |

The pause menu's key bindings tab lists both under those names, read from the
configured locale, and every player can rebind them there.
[`KEYS.PICKER` and `KEYS.STOP`](config.md#keys) set the defaults a player's own
rebind overrides, and `false` registers no mapping. A press while another
surface holds the keyboard — the chat box, a form, the pause menu — does
nothing; that is read with `Open77.input.isCaptured`, which is why the manifest
declares `input.actions`.

The keys act on the client, as the [`openPicker`](exports.md#openpicker) and
[`stop`](exports.md#stop) exports do, not through the commands: `RESTRICTED` on a
command gates what is typed, and the server applies the same policy to a request
from a key as to any other. A key's refusal is the same toast the picker shows,
and its verdict is raised on [`result`](events.md#result) with
`source = "key"`. A mapping the host refuses is one warning,
`key mapping <id> (<key>) not registered: <reason>`.

The picker's **Stop** row names the stop key the player actually has, and an open
root screen is redrawn when a player rebinds it (`open77:keybinds:changed`).

### The stop key while an animation plays {#stop-prompt}

While the local player's own animation plays — looping or not, whoever started
it — the stop key is shown in [`opx77_prompts`](../opx77_prompts/index.md)'
strip as *Stop animation*, under the key the player actually has. It follows the
presenter's mirror, the same state [`state`](exports.md#state) reads, and comes
down when that says the playback ended; so it needs the presentation natives the
mirror needs.

Nothing is shown with [`PROMPTS = false`](config.md#prompts), with
`KEYS.STOP = false` (a prompt with no key has nothing to say), or while
`opx77_prompts` is not running, which is logged once:

```text
opx77_prompts is not running; the stop key is not shown
```

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
| `shared/common.lua` | shared. The clock (`OpxAnimations.Common.NowMs`, with a `GetGameTimer` fallback on the server only), the loop guard, and the wire value tests both halves apply |
| `shared/locale.lua` | shared. The catalogue, and the `locale(key, params)` every file below it calls |
| `locales/en.lua`, `locales/fr.lua` | shared. Player-facing text, keyed `animations.<thing>` |
| `shared/catalogue.lua` | shared. The fifteen animations and their clips |
| `shared/settings.lua` | shared. `config.lua` read once, checked, and resolved to fallbacks |
| `server/service.lua` | the offer against the build, the rate, the gate, and every call to the service |
| `server/commands.lua` | the four commands and the chat suggestions |
| `server/main.lua` | the inbound net events, the departure hook, the boot banner |
| `client/presenter.lua` | the mirror of the service's wire, and the bodies posed from it |
| `client/main.lua` | requests, verdicts, refusal toasts, export ownership |
| `client/keys.lua` | the key mappings, and following a player's rebinds |
| `client/picker.lua` | the picker, borrowed from `opx77_menu` one screen at a time, its stack of screens, and the two keys' actions |
| `client/prompt.lua` | the stop key in `opx77_prompts`' strip while the local player's animation plays |
| `client/exports.lua` | the eight public exports |

The LuaLS types live in `std/types.lua`, with one stub per namespace function
under `std/client`, `std/server` and `std/shared`; none of it is loaded. Why the
code is written the way it is — in French — is in the resource's
`docs/ARCHITECTURE.md`.

## Permissions {#permissions}

```lua
permissions {
  "network.events",
  "players.animations.control",
  "animations.presentation",
  "input.actions",
}
```

| Permission | For |
|---|---|
| `network.events` | this resource's own request and answer events both ways, and on the client the service's state and snapshot wire, which the presenter mirrors |
| `players.animations.control` | server: `Open77.animations.play`, `stop`, `get` and `list` against a player |
| `animations.presentation` | client: `Open77.animations._context`, and posing streamed bodies with `_playProfile` and `stop`. Only used while this client presents |
| `input.actions` | client: the two [key mappings](#keys), the key a mapping answers to now, and whether chat or a form holds the keyboard |

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
