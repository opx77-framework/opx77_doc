---
title: Releases and versions
description: The version each OPX//77 resource currently declares, what a version number does and does not promise while the framework is at 0.x, and where to look for what changed.
---

# Releases

Every resource carries its own version, declared on the second line of its
`open77.lua` and reported by nothing else. There is no framework-wide release
number: `opx77_core` at `0.3.0` and `opx77_hud` at `0.2.0` are the current state
of two independently versioned resources that happen to ship together.

!!! warning "Early development"

    OPX//77 is not production-ready. The API, architecture, features and internal
    systems are subject to change at any time without notice, and breaking
    changes will be introduced as development progresses. Do not rely on the
    current API for production resources yet.

## Current versions {#current}

| Resource | Version | Reload policy |
|---|---|---|
| [`opx77_core`](reference/opx77_core/index.md) | `0.3.0` | `local` |
| [`opx77_menu`](reference/opx77_menu/index.md) | `0.2.0` | `reconnect` |
| [`opx77_hud`](reference/opx77_hud/index.md) | `0.2.0` | `reconnect` |
| [`opx77_chat`](reference/opx77_chat/index.md) | `0.2.0` | `reconnect` |
| [`opx77_status`](reference/opx77_status/index.md) | `0.3.0` | `reconnect` |
| [`opx77_notify`](reference/opx77_notify/index.md) | `0.2.0` | `reconnect` |
| [`opx77_weather`](reference/opx77_weather/index.md) | `0.2.0` | `local` |
| [`opx77_elevators`](reference/opx77_elevators/index.md) | `0.3.0` | `local` |
| [`opx77_appearance`](reference/opx77_appearance/index.md) | `0.2.0` | `local` |

Each of those numbers is read from the resource's own manifest, and each is the
value [`GetVersion`](reference/opx77_core/exports/client.md#getversion) answers
for `opx77_core`. Every resource also declares `open77_version ">=0.0.1"`, which
is a floor on the **platform**, not on any OPX//77 resource: nothing here
declares a `dependency` on anything else here.

## What a version promises {#promise}

While the leading digit is `0`, it promises the reader one thing only: two
servers running the same number are running the same code. It is not a
compatibility contract.

- **A minor bump — `0.2.0` to `0.3.0` — may break you.** Every resource past
  `0.1.0` changed shape to get there, and the current round is a large one: see
  [What changed](#changes).
- **The stable surface is the error codes, not the version.** Every refusal in
  this framework answers a documented string — `job.notFound`, `money.badAmount`,
  `menu_busy`, `not_adopted` — and those codes are treated as API. A code is the
  thing to branch on; a version number is not.
- **Nothing at runtime compares versions.** No resource checks another's, and no
  consumer in the set refuses to run against an unexpected one. The only guard
  any of them applies is `GetResourceState(...) ~= "running"`, which is a check
  that something is *there*, not that it is compatible. See
  [Integration channels](concepts/integration-channels.md#client-resource).

## What changed {#changes}

There is no changelog file in any of the nine repositories. The commit history
of each resource is the record, and this documentation is written against the
code as it stands rather than against a release. If a page and the code you have
disagree, the code is right and the page is a bug — see
[Contributing](guides/contributing.md) for how to report or fix one.

The current round moved state between resources, and four of its changes break a
server or a plug-in written against the previous one.

!!! danger "A database from before this round has to be dropped and recreated"
    The core's three character tables were renamed — `opx77_accounts` →
    `opx77_users`, `opx77_players` → `opx77_characters`, `opx77_player_groups` →
    `opx77_character_groups`, with every foreign key and index renamed with them
    — **inside** migrations 0001–0003 rather than as new ones. The runner keys on
    the migration name and will not re-run one it has already recorded, so an
    existing database keeps the old tables while the code queries the new names.
    There is no automatic migration path and none is planned. See
    [Persistence](concepts/persistence.md).

- **The character's face is core-owned, and `opx77_appearance` ships.** A new
  `appearance` JSON column on the character row, written only by the core, and a
  new client-only resource that captures it and sends it on
  `opx77:server:saveAppearance`. It is also what emits
  `open77:session:gameplayReady`, which is the one thing that opens the
  platform's readiness gate.
- **The gameplay needs moved out of the core.** `hunger`, `thirst`, `stamina`
  and `streetCred` were `PlayerData.metadata` keys decayed by the core's own
  `server/needs.lua`; they belong to [`opx77_status`](reference/opx77_status/index.md)
  now, in its own `opx77_character_status` table. `health`, `armor`, `isDead`
  and `inLastStand` stay in the core. `ram` was removed outright.
- **`OPX.Log` is gone**, along with `shared/log.lua` and
  `Config.SHARED.LOG_LEVEL`. `Open77.log` is the logger, called directly, and
  the host owns the level. `OPX.Logger`, the player audit log, is a different
  thing and stays.
- **`open77:notificationRemoved` is gone.** `opx77:notify:removed` is the only
  removal event `opx77_notify` raises, which breaks the client-side half of its
  drop-in claim: a resource ported from the official package that listened for
  the platform's name now hears nothing.

Smaller shape changes in the same round: refusals carry the operation they
answer (`OPX.Refuse(source, code, operation)`), an elevator is callable from
every floor of its own shaft, `opx77_menu`'s `open` answer renamed `items` to
`nodes`, `opx77_weather`'s status line label became `weather=`, HUD bar rows no
longer carry a `label`, and every resource that renders text of its own now
carries a locale catalogue and a `LOCALE` key.

## Documenting a version bump {#bumping}

Three places in this site quote a version number, and all are read from the
manifests: the table above, the resource table on the
[reference overview](reference/index.md), and the at-a-glance table on each
resource's overview page. A bump changes those, and nothing else. The
repository's `scripts/check-api-coverage.sh` will not catch a stale version —
only a stale *name* — so it is worth grepping for the old number. See
[Contributing](guides/contributing.md#docs-style).
