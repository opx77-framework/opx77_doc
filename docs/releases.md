---
title: Releases and versions
description: The version each OPX//77 resource currently declares, what a version number does and does not promise while the framework is at 0.x, and where to look for what changed.
---

# Releases

Every resource carries its own version, declared on the second line of its
`open77.lua` and reported by nothing else. There is no framework-wide release
number: `opx77_core` at `0.3.0` and `opx77_appearance` at `0.6.0` are the
current state of two independently versioned resources that happen to ship
together.

!!! warning "Early development"

    OPX//77 is not production-ready. The API, architecture, features and internal
    systems are subject to change at any time without notice, and breaking
    changes will be introduced as development progresses. Do not rely on the
    current API for production resources yet.

## Current versions {#current}

| Resource | Version | Reload policy |
|---|---|---|
| [`opx77_core`](reference/opx77_core/index.md) | `0.3.0` | `local` |
| [`opx77_menu`](reference/opx77_menu/index.md) | `0.4.0` | `reconnect` |
| [`opx77_input`](reference/opx77_input/index.md) | `0.1.0` | `reconnect` |
| [`opx77_hud`](reference/opx77_hud/index.md) | `0.3.0` | `reconnect` |
| [`opx77_chat`](reference/opx77_chat/index.md) | `0.3.0` | `reconnect` |
| [`opx77_status`](reference/opx77_status/index.md) | `0.4.0` | `reconnect` |
| [`opx77_notify`](reference/opx77_notify/index.md) | `0.2.0` | `reconnect` |
| [`opx77_weather`](reference/opx77_weather/index.md) | `0.3.0` | `local` |
| [`opx77_elevators`](reference/opx77_elevators/index.md) | `0.4.0` | `local` |
| [`opx77_appearance`](reference/opx77_appearance/index.md) | `0.6.0` | `local` |
| [`opx77_charselector`](reference/opx77_charselector/index.md) | `0.3.0` | `local` |
| [`opx77_charcreator`](reference/opx77_charcreator/index.md) | `0.1.0` | not declared |
| [`opx77_animations`](reference/opx77_animations/index.md) | `0.1.0` | `local` |
| [`opx77_admin`](reference/opx77_admin/index.md) | `0.1.0` | `local` |

Each of those numbers is read from the resource's own manifest, and each is the
value [`GetVersion`](reference/opx77_core/exports/client.md#getversion) answers
for `opx77_core`. Every resource also declares `open77_version ">=0.0.1"`, which
is a floor on the **platform**, not on any OPX//77 resource: nothing here
declares a `dependency` on anything else here.

## What a version promises {#promise}

While the leading digit is `0`, it promises the reader one thing only: two
servers running the same number are running the same code. It is not a
compatibility contract.

- **A minor bump — `0.3.0` to `0.4.0` — may break you.** Every resource past
  `0.1.0` changed shape to get there, and the last two rounds were large ones:
  see [What changed](#changes).
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

There is no changelog file in any of the fourteen repositories. The commit
history of each resource is the record, and this documentation is written
against the code as it stands rather than against a release. If a page and the
code you have disagree, the code is right and the page is a bug — see
[Contributing](guides/contributing.md) for how to report or fix one.

### The world-first entry {#world-first-entry}

The most recent round changes **the order a player joins in**. Nothing a server
resource draws is visible under the platform's loading cover, and the cover
stays up until the one-shot character bootstrap is spent; the framework spent it
on the chosen character's body, so the roster that had to choose one was open
under the cover and nobody ever got in. The world now comes first, and the
character is chosen in it. The whole sequence is in
[The entry gate](concepts/entry-gate.md#world-first).

| Resource | Change |
|---|---|
| [`opx77_appearance`](reference/opx77_appearance/index.md) `0.6.0` | Spends the bootstrap at join, on the body of the account's most recently played character or [`BOOTSTRAP.DEFAULT_FAMILY`](reference/opx77_appearance/config.md#bootstrap). Reloads the body onto a selected character's `charInfo.gender` when it differs. [`openCreator`](reference/opx77_appearance/exports.md#opencreator) opens the in-world editor in `ripperdoc` mode; there is no pre-world creator, and no ending fails the bootstrap. |
| [`opx77_charselector`](reference/opx77_charselector/index.md) | Opens the roster only in the gameplay world (`world_not_ready` before it), asks the core again every `ROSTER_RETRY_MS` until a roster arrives, and stages the character: the camera orbits to face it and it is held in place. New exports `holdStage` and `releaseStage`, new `STAGE` keys, new permissions `camera.preview` and `player.travel`. `PREVIEW` is gone. |
| [`opx77_charcreator`](reference/opx77_charcreator/index.md) | Handles `world_not_ready`, hands the player back to the roster in the world, and holds the stage through its form (`HOLD_STAGE`). |
| [`opx77_core`](reference/opx77_core/index.md) | Binds an absent column as `NULL` with `NULLIF`, which fixes every character creation — see [Persistence](concepts/persistence.md#nil-parameters). Its push of the roster on connect no longer cools the client's own request. |
| [`opx77_input`](reference/opx77_input/index.md) | The form is drawn as `opx77_menu`'s strip. New `ANCHOR`; `WIDTH` ships at `340` and `DIM` at `false`. |
| [`opx77_menu`](reference/opx77_menu/index.md) `0.4.0` | Reports where the cursor is, with the `focus` action, to a caller that sets `reportFocus`. |
| `opx77_charselector`, `opx77_charcreator`, [`opx77_elevators`](reference/opx77_elevators/index.md) | Test the export promise for presence. It is a userdata, and a `type(promise) ~= "table"` guard refused every call — see [The export contract](concepts/export-contract.md#level-1). |

Beside them:

- **Two resources are new.** [`opx77_admin`](reference/opx77_admin/index.md) is
  a staff desk: thirty-nine commands, every one restricted and answering to
  `acl.jsonc` alone, and a menu that drives them.
  [`opx77_animations`](reference/opx77_animations/index.md) plays emotes, from
  a command or a picker drawn by `opx77_menu`. Both are optional.
- **`opx77_input`, `opx77_charselector` and `opx77_charcreator` are documented**
  for the first time; they shipped just after the export audit and had no
  pages until now.
- **`opx77_appearance`'s `0.5.0` is documented too**: its panel is drawn through
  `opx77_menu`, with the [`openPanel`](reference/opx77_appearance/exports.md#openpanel)
  and [`closePanel`](reference/opx77_appearance/exports.md#closepanel) exports.
- **What breaks.** A caller of `openCreator` that relied on
  `bootstrap_already_spent` no longer gets it, and `character_bootstrap_failed`
  is gone. Anything that drew a character selection before the world will now
  sit under the cover, and belongs after it.
- **Known issue.** Selecting a character whose body family differs from the body
  loaded at join can leave the loading cover up. It is being fixed; see
  [Troubleshooting](guides/troubleshooting.md#body-family-cover).

Written against `open77-server-2.31.13+op77.63`.

### The export audit {#export-audit}

The round before it was an audit of the **export surface**: eleven exports were
renamed and one was deleted, across five resources. Nothing on the wire moved —
no net event, no WebUI message and none of `opx77_core`'s PascalCase exports —
so what breaks is caller code that names an export by string.

| Resource | Was | Is |
|---|---|---|
| [`opx77_status`](reference/opx77_status/exports.md) | `add` | [`addEffect`](reference/opx77_status/exports.md#addeffect) |
| | `update` | [`updateEffect`](reference/opx77_status/exports.md#updateeffect) |
| | `remove` | [`removeEffect`](reference/opx77_status/exports.md#removeeffect) |
| | `clear` | [`clearEffects`](reference/opx77_status/exports.md#cleareffects) |
| | `needs` | [`getNeeds`](reference/opx77_status/exports.md#getneeds) |
| [`opx77_menu`](reference/opx77_menu/exports.md) | `status` | [`setStatus`](reference/opx77_menu/exports.md#setstatus) |
| [`opx77_weather`](reference/opx77_weather/exports.md) | `getState` | [`state`](reference/opx77_weather/exports.md#state) |
| [`opx77_chat`](reference/opx77_chat/exports.md) | `clear` | [`clearMessages`](reference/opx77_chat/exports.md#clearmessages) |
| [`opx77_elevators`](reference/opx77_elevators/exports.md) | `check` | [`isFloorAllowed`](reference/opx77_elevators/exports.md#isfloorallowed) |
| | `use` | [`requestFloor`](reference/opx77_elevators/exports.md#requestfloor) |
| | `panel` | [`openPanel`](reference/opx77_elevators/exports.md#openpanel) |
| | `nearest` | [`nearestElevator`](reference/opx77_elevators/exports.md#nearestelevator) |
| [`opx77_appearance`](reference/opx77_appearance/exports.md) | `open`, `editor` | [`openEditor`](reference/opx77_appearance/exports.md#openeditor) |
| | `current` | [`getSkin`](reference/opx77_appearance/exports.md#getskin) |
| | `family` | [`getFamily`](reference/opx77_appearance/exports.md#getfamily) |
| | `barber` | **deleted** — call `openEditor("hairdresser")` |

The shape being converged on is the one the resources that got it right already
used: `get*` reads, `set*` writes, `is*` asks a yes/no, and a bare noun answers a
report. `opx77_core` stays PascalCase; that difference is deliberate.

Beside the renames:

- **`opx77_appearance` is now a service rather than a flow**, and publishes ten
  exports where it published five.
  [`captureSkin`](reference/opx77_appearance/exports.md#captureskin),
  [`setSkin`](reference/opx77_appearance/exports.md#setskin),
  [`saveSkin`](reference/opx77_appearance/exports.md#saveskin),
  [`openCreator`](reference/opx77_appearance/exports.md#opencreator),
  [`isSettled`](reference/opx77_appearance/exports.md#issettled) and
  [`getFamily`](reference/opx77_appearance/exports.md#getfamily) are new. It no
  longer opens a character creator on its own: it publishes
  [`needsCreation`](reference/opx77_appearance/events.md#needs-creation) and
  waits for something to call `openCreator`, saying so in the log after
  [`CREATION_WAIT_MS`](reference/opx77_appearance/config.md#creation-wait-ms) if
  nothing does. `AppearanceCurrent` became
  [`AppearanceSkin`](reference/opx77_appearance/types.md#appearanceskin),
  `AppearanceOpenResult` became
  [`AppearanceQueued`](reference/opx77_appearance/types.md#appearancequeued), and
  the `createRequired` event is now `needsCreation`.
- **`opx77_hud` stopped polling.** It read `GetPlayerData` every five seconds as
  a net under the core's change events; it now reads once at boot and lives on
  those events. `POLL_MS` is gone.
- **`opx77_weather`'s frozen clock is now actually frozen.** `setTimeFrozen` was
  declared and never taken, so a held authority left REDengine's own clock
  running free — see [the clock lock](reference/opx77_weather/index.md#time-lock).
- **`opx77_elevators`' client fallback can disagree with the server in both
  directions.** When `Open77.character.position()` answers nothing, the client
  ranks a lift by the host's 3D distance to the *cabin*, which is a different
  measurement to a different point. The previous claim that it "can only ask for
  less than the server allows" was wrong — see
  [`USE_RADIUS`](reference/opx77_elevators/config.md#use-radius).

### The state round, before it {#state-round}

The round before it moved state between resources, and four of its changes break
a server or a plug-in written against the previous one.

!!! danger "A database from before that round has to be dropped and recreated"
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
