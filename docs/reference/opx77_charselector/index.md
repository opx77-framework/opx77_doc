---
title: The opx77_charselector resource
description: opx77_charselector is the character screen — the account's roster drawn by opx77_menu once the player is in the gameplay world, a retry that outlasts opx77_core's roster throttle, the stage camera on the player's character, and the hand-over to opx77_charcreator.
---

# opx77_charselector

!!! danger "Without this resource nobody plays"

    `opx77_core` sends every joining player their character roster and then
    waits. This is what draws it, and its call to the core's
    [`SelectCharacter`](../opx77_core/exports/client.md#selectcharacter) is the
    only thing on a stock install that puts a character in the world.

The character screen. The account's characters are drawn as a list by
[`opx77_menu`](../opx77_menu/index.md) **once the player is in the gameplay
world**; choosing one enters Night City as that character, and choosing an empty
slot hands over to [`opx77_charcreator`](../opx77_charcreator/index.md). While
the player chooses, the camera faces their own character and the character stays
where it stands — [the stage](stage.md).

## At a glance {#at-a-glance}

| At a glance | |
|---|---|
| **Version** | `0.3.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared; `opx77_menu` must be running for anything to be drawn |
| **Auto start** | yes |
| **Reload policy** | `local` — it has no CEF surface of its own. `opx77_menu` owns the only one, and drops this resource's roster when the generation changes |
| **Permissions** | `camera.preview` — `Open77.camera.orbit` and `clearOrbit` for the stage camera; `player.travel` — `Open77.travel.teleport` for the stage's hold, and nothing else |
| **Sides** | client only. No `server/`, no `sql/`, no table, no `database.access`, no `web/` |
| **Exports** | six, all client: [`open`](exports.md#open), [`close`](exports.md#close), [`isOpen`](exports.md#isopen), [`state`](exports.md#state), [`holdStage`](exports.md#holdstage), [`releaseStage`](exports.md#releasestage) |
| **Commands** | none |
| **Events** | raises [`createRequested`](events.md#create-requested) on `opx77:charselector`; listens to `opx77_core`, `opx77_menu`, `opx77_appearance` and the platform — see [Events](events.md) |
| **Reads** | [`opx77_core`](../opx77_core/index.md) for the roster and the selection; [`opx77_menu`](../opx77_menu/index.md) to draw it; [`opx77_appearance`](../opx77_appearance/index.md)'s `needsCreation` |

**It owns no surface.** The framework has two UI primitives — `opx77_menu` for
lists and [`opx77_input`](../opx77_input/index.md) for typed answers — and a
roster is a list. **It owns no state that outlives a session**: the roster
belongs to `opx77_core`, and every write goes through the core's own client
exports.

## The world comes first {#world-first}

Nothing a server resource draws is visible before the gameplay world. On join the
platform's shell keeps an opaque loading cover up for as long as the character
bootstrap waits, and lifts it only once that bootstrap is resolved and the
gameplay world has streamed. A list opened under the cover is up but unseen — and
`opx77_menu` holds the arrow keys under it regardless — so nothing is ever chosen.

So the order is:

1. `opx77_appearance` resolves the bootstrap **at join**, before anybody is
   chosen, on the body of the account's most recently played character or a
   configured default.
2. The gameplay world streams and the cover lifts. `opx77_core` keeps the player
   unplaced, because no character is loaded yet.
3. **This resource puts the roster up, in that world.**
4. A selection may reload the player's body onto the character's own family, in
   a new world entry. That is `opx77_appearance`'s job, and the list does not
   come back for it.

The mechanism is set out in [The entry gate](../../concepts/entry-gate.md#world-first).

### What counts as the gameplay world {#gameplay-world}

`Open77.session.characterBootstrap().phase` is `"ready"` **and** its puppet
exists. Either signal alone lies:

| Signal | Why it is not enough alone |
|---|---|
| `open77:worldReady` | The pre-game menu world raises it too, while the bootstrap is still `waiting`. |
| an attached, alive puppet | The pre-game menu's puppet also answers `attached = true, alive = true, health = 100`. |
| the `ready` phase | Right after the bootstrap resolves, the menu's puppet still answers, while the cover is still over it. |

So the world is up after `open77:playerReset:complete` in the `ready` phase, or
after an `open77:worldReady` in the `ready` phase followed by an attached, alive
puppet, which the tick polls for. A resource start into a live world gets no
world entry at all, so there a `ready` phase with an attached, alive puppet
stands in for one.

Every path that opens the roster waits for it — the boot, a roster arriving, a
late `opx77_menu`, the reopen after a dismissal, a refused or timed-out
selection, and the [`open`](exports.md#open) export, which answers
`world_not_ready` before it. A roster that arrives earlier is kept, not drawn,
and goes up when the world does.

## The flow {#flow}

1. The player joins. `opx77_core` holds its own entry gate and sends the roster
   on [`opx77:client:charactersReady`](events.md#characters-ready).
2. The gameplay world is up. The list goes up through `opx77_menu`'s `open`: one
   row per character, then the empty slots up to the account's limit, then the
   create row. [The stage](stage.md) comes up with it.
3. Choosing a character calls `SelectCharacter`. The list shows *Entering Night
   City...*, and the character is no longer held while the core places it. The
   list and the stage go when `opx77:client:onPlayerLoaded` arrives.
4. A world entry after that — the body reload for the character's gender — finds
   a character loaded or a selection pending and leaves the list down.
5. Choosing an empty slot or the create row closes the list, raises
   [`createRequested`](events.md#create-requested), and keeps the stage up for
   the listener to [hold](exports.md#holdstage). A world entry during a creation
   handed over does not put the list back over it either.

## When the roster does not arrive {#roster-retry}

The core's first roster can reach its client before this resource has started,
and `opx77_core` throttles roster requests at **2000 ms per player, dropping a
request inside that window without an answer**. Both the core's own re-announce
on `open77:worldReady` and this resource's request at boot can land inside it,
and the player then sits with no roster, for ever.

So while this resource holds no roster and no character is loaded, it tries again
every [`ROSTER_RETRY_MS`](config.md#roster-retry-ms) — 3000 as shipped, never
under 2500. Each retry reads `GetCharacters` first, since the core may hold a
roster whose event was missed, and only then calls `RequestCharacters`. A run of
retries is one log line:

```text
no roster yet: asking opx77_core again every 3000 ms
```

It stops at the first roster adopted or character loaded. A roster read back
rather than received says so:

```text
the roster was read back from opx77_core
```

On a resource reload mid-session the core has already sent the roster to a
client that no longer had this screen, so the boot reads it back through
`GetCharacters` and, failing that, asks through `RequestCharacters` with
*Waiting for your characters...* queued under the list.

!!! info "The core no longer cools its own push"

    `opx77_core`'s send on connect used to take the roster cooldown too, so the
    READY its client sends a second later was dropped. The push on connect now
    neither is cooled nor cools. The retry remains, for every other way a roster
    can be missed.

## The list {#the-list}

The roster is one `opx77_menu` spec, drawn as a vertical list with the menu's
caller-side rules: one menu at a time, keyed on the invoking resource.

```lua
{
  id = "opx77_charselector",
  title = "Choose your character",
  event = "opx77_charselector:row",
  cursor = "character_1",
  reportFocus = true,
  items = { ... },
}
```

One row per slot, in order, then the create row:

| Row | `id` | `label` | `value` | `description` |
|---|---|---|---|---|
| a character | `character_<n>` | the name | `ID <citizenId>` | lifepath, body, role, affiliation, last seen |
| an empty slot | `slot_<n>` | `Empty slot` | `Slot <n>` | `Nobody lives here yet.` |
| the create row | `create` | `New character` | — | slots used, or why none are free |

Every row carries a `data` table, `{ index, kind, action, citizenId }`, and it is
the only thing a chosen row is read from. The create row is `disabled` when the
account is full, so a player who cannot create one is told why rather than left
looking for the row. `opx77_menu` refuses a level of more than 200 rows whole, so
an account claiming more slots than that is drawn short at 199 plus the create
row.

- **The cursor is followed.** The spec sets
  [`reportFocus`](../opx77_menu/events.md#focus), so `state` and a list that
  goes back up land on the row the player left. A roster that has gained a
  character since the last one opens on the new row, with *\<name\> is ready.*
  under the list.
- **The list is dismissible, and comes back.** Escape, the pause menu,
  `BACKSPACE` at the root and a `close` row all close an `opx77_menu`. A close
  this resource did not ask for puts the roster back up 250 ms later, because a
  player with no character and no list has no way to choose one.
- **A selection never answered unlocks the list** after
  [`REQUEST_TIMEOUT_MS`](config.md#request-timeout-ms), with *Nothing answered.
  Try again.* Without it a lost reply leaves a player looking at a dimmed list
  with no way forward.

## What it does not do {#does-not}

**It does not create characters.** The fields, the validation and the face
belong to [`opx77_charcreator`](../opx77_charcreator/index.md).

**It does not open a face editor, or load a body.** The body family the world
loads with, the reload a selected character of the other gender needs, and the
in-world editor are [`opx77_appearance`](../opx77_appearance/index.md)'s. Two
resources racing to open one native editor is a bug nobody can diagnose from the
outside.

**It does not show the character under the cursor.** The stage camera shows the
puppet the world was loaded with. A roster carries no face — money, metadata,
appearance and position are deliberately absent from a
[`CharacterSummary`](types.md#charactersummary) — and there is no camera at a
world point on this platform to stage a stand-in with.

## Where to go next {#next}

- [Exports](exports.md) — the six calls and what each refuses with.
- [The stage](stage.md) — the camera, the hold, and who owns them when.
- [Events](events.md) — the hand-over it raises and everything it listens to.
- [Configuration](config.md) — the handoffs, the roster retry and `STAGE`.
- [Types](types.md) — every shape named on these pages.
