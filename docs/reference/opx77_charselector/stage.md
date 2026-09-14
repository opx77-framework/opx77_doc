---
title: The opx77_charselector stage
description: While a player chooses a character, opx77_charselector orbits the camera to face the player's own character and holds the character where it stands — how the camera and the hold work, why the hold is not the keyboard, who owns the stage when, and the log lines it prints.
---

# The stage

While the player chooses a character, the camera looks at the player's own
character from the front and the character stays where it stands. It is on as
shipped and set by [`STAGE`](config.md#stage) in `config.lua`; the code is
`client/stage.lua`, and `client/main.lua` decides when.

The stage replaces the `PREVIEW` block and `client/preview.lua` of earlier
versions. That camera at a fixed world point was never written, and cannot exist
on this platform: there is no camera at a world point to put one at.

## The camera {#camera}

`Open77.camera.orbit(STAGE.ORBIT_DEGREES)`, the platform's third-person orbit
around the player's puppet — what its own fitting room stages a look with, under
the same `camera.preview` grant. `180` is in front, which is that fitting room's
FRONT; `0` is behind.

- **Third person is asked for first.** The orbit is a view of third person, so
  the stage remembers the perspective the player asked for, then asks
  `Open77.perspective` for `"tps"`. The player's own perspective is handed back
  when the stage goes, after `Open77.camera.clearOrbit`.
- **The orbit is asked for again on every tick**, every 250 ms, because an
  engine camera takeover can reset the rig after a first success. A refused
  orbit asks for third person again before the next try, since a world entry can
  have reset the perspective.
- **A refusal is one log line per run**, not one per tick, and a recovery is
  another:

```text
the stage camera was refused: <reason>
the stage camera is on the character again
```

Observed live, in the first seconds of the gameplay world while the platform's
loading hand-off and its perspective arbiter are still settling:

```text
the stage camera was refused: perspective_not_third_person
the stage camera is on the character again
```

That pair is the tick doing its job and needs nothing. A refusal with no recovery
line after it is the one to look at. A client whose runtime has no
`Open77.camera.orbit` at all says so once and has no camera:

```text
Open77.camera.orbit is not on this client: the stage has no camera
```

What the camera shows is **the puppet the world was loaded with**, not the
character under the cursor. The world loads on the most recently played
character's body at join, and a roster carries no face to dress a stand-in with.

## The hold, and why it is not the keyboard {#hold}

The platform's way to keep the walk keys from the game is a **focused** WebUI
surface: the fitting room focuses its page, and
[`opx77_input`](../opx77_input/index.md#focus) focuses its form, which is why
nobody walks while the creation form is up.

The roster cannot do that. `opx77_menu` draws on a `hud` surface that is never
focused and polls the arrow keys through `Open77.input.isDown`, and its input
tick reads nothing at all while `Open77.input.isCaptured()` is true — which it is
whenever any surface holds focus. A focused surface under the list would freeze
the list along with the player.

So [`STAGE.FREEZE`](config.md#stage-freeze) holds the character instead:

| | |
|---|---|
| Cadence | 30 times a second (every 33 ms), `Open77.character.state()` is read |
| Correction | a character more than **5 cm** from where it stood, or turned more than **10°**, is put back with `Open77.travel.teleport` |
| Height | left to the game, so nothing is held in the air while it settles |
| A placement | a move of more than **3 m** between two reads is a placement, not a walk; the character is held from where it was put |
| Not corrected | while the puppet is dead, detached or in a vehicle |

The correction is the bounded, few-centimetre one the platform's own arena
boundary makes, and nothing else: `player.travel` is never used to move anybody
anywhere. The walk animation can show for a frame before a correction lands;
`FREEZE = false` lets the character walk under the camera instead. Under the
creation form the game gets no walk keys, so the hold writes nothing there.

Its failures, each said once:

```text
Open77.travel.teleport is not on this client: the character is not held
the character cannot be held (<reason>) -- the manifest must grant player.travel
holding the character was refused: <reason>
```

The first two stop the hold for the session — the second when the teleport's
refusal names `permission_denied` — and the camera is unaffected.

## Who owns it, and when {#ownership}

This resource owns the stage from the roster through the form and back: it alone
calls the orbit, the clear and the teleport. Another resource that keeps the
player choosing without the list — `opx77_charcreator`'s form — **holds** it
through [`holdStage`](exports.md#holdstage) and lets go with
[`releaseStage`](exports.md#releasestage). It never touches the camera itself,
and needs no grant for it.

| While | The stage |
|---|---|
| the list is up | camera and hold |
| the list was dismissed and is going back up | lingers `STAGE_LINGER_MS` (1.5 s), so it does not flicker |
| create was chosen, until the listener calls `holdStage` | camera and hold for `HANDOVER_MS` (5 s) |
| a holder holds it: the form, a registration with the core | camera and hold |
| the holder hands back: `open`, then `releaseStage` | the list takes it over inside the linger |
| a selection is with the core | camera only: the core places the character, and a hold would pull it back |
| a character is loaded | down at once, and the holder forgotten |
| `opx77_appearance` publishes `needsCreation` | down at once: its face editor has a camera of its own. Stays down until the character is unloaded or a roster arrives |
| another resource calls `close` | down at once: the player has been taken elsewhere |
| the holder stops or reloads without releasing | the hold is forgotten on the next tick, and the stage lingers out |
| the gameplay world is not up | down |
| this resource stops | down: the orbit cleared and the perspective handed back |

### The hand-over window {#handover}

When the player chooses create, the list closes and
[`createRequested`](events.md#create-requested) is raised, but the stage stays up
for **5 seconds** unclaimed. A listener that calls `holdStage` inside that window
keeps it without the camera moving; a creation nobody picks up leaves the player
free after it.

### The linger {#linger}

The stage outlives the last thing that wanted it by **1.5 seconds**. The roster
reopening after a dismissal, the form going up after a hand-over and the roster
coming back after the form are each a gap of a few hundred milliseconds, and the
camera must not snap back to the player for them. That is why a holder calls
`open` **before** `releaseStage`.

### The rules for a holder {#holder-rules}

- Call `holdStage` as soon as the player is yours: the hand-over window is 5 s.
- Hand back by calling `open` before `releaseStage`.
- A character loading ends every hold. `releaseStage` answers `not_holder` after
  that, which is not an error.
- A holder that stops or reloads without releasing is noticed on the tick:

```text
<resource> stopped holding the stage without releasing it
```

`needsCreation` normally arrives after `onPlayerLoaded`, which has already taken
the stage down. It is listened for, on
[`APPEARANCE_EVENT`](config.md#appearance-event), for a character this resource
did not see load.

## See also {#see-also}

- [Configuration](config.md#stage) — `ENABLED`, `ORBIT_DEGREES`, `FREEZE`.
- [Exports](exports.md#holdstage) — `holdStage` and `releaseStage`.
- [opx77_charcreator](../opx77_charcreator/index.md#the-stage) — the holder on a
  stock install.
