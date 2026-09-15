---
title: The opx77_charselector stage
description: While a player chooses a character, opx77_charselector orbits the camera to face the player's own character, locks it against the mouse and holds the character where it stands — how the camera, the lock and the hold work, why none of them is the keyboard, who owns the stage when, and the log lines it prints.
---

# The stage

While the player chooses a character, the camera looks at the player's own
character from the front, the mouse cannot turn it, and the character stays
where it stands. It is on as shipped and set by [`STAGE`](config.md#stage) in
`config.lua`; the code is `client/stage.lua`, and `client/main.lua` decides when.

Nobody else is on the stage either: `opx77_core` keeps a player with no
character loaded in a routing bucket of their own — see
[the selection bucket](../opx77_core/config.md#server-entry-bucket).

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
  engine camera takeover can reset the rig after a first success — and on every
  frame while [the camera is locked](#lock), so a free look cannot leave it
  turned. A refused
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

## Why not the keyboard {#keyboard}

The platform's way to keep input from the game is a **focused** WebUI surface:
the fitting room focuses its page, keyboard and mouse, which is also what keeps
its camera still.

The roster cannot do that. `opx77_menu` draws on a `hud` surface that is never
focused and polls the arrow keys through `Open77.input.isDown`, and its input
tick reads nothing at all while `Open77.input.isCaptured()` is true — which it is
whenever any surface holds the keyboard. A focused surface under the list would
freeze the list along with the player.

[`opx77_input`](../opx77_input/index.md#focus) takes the keyboard for the
creation form, and **not the mouse**. Under the form the walk keys were already
the form's; the camera was not, and before this lock it could be turned there
too.

## The lock and the hold {#lock}

The platform has **resource-owned player controls**, under the
`players.controls` grant, that restrict the local player natively without any
surface taking input. They are the calls the platform's own context menu makes
while it is open — and that menu keeps reading its own key through `isDown` the
whole time. They set bits in the player's control mask
(`Open77.players.getControlMask`); `isCaptured` answers whether a WebUI owns the
keyboard, which is a different thing, and none of them sets it. `opx77_menu`
keeps reading its arrows under all of them.

| Key | Controls | What they stop |
|---|---|---|
| [`STAGE.LOCK_CAMERA`](config.md#stage-lock-camera) | `freezeRotation(true)` | the native camera and turn restriction: the mouse no longer turns the character, nor the orbit around it |
| [`STAGE.FREEZE`](config.md#stage-freeze) | `freezePosition(true)`, and `allowJump`, `allowCrouch`, `allowDodge`, `allowWeapons`, `allowAim`, `allowShoot`, `allowInteraction` all `false` | walking, jumping, crouching, dodging, drawing and firing a weapon, using the world |

- **Asked for when the stage comes up, and again on every tick.** The host
  drops every block on death and on a player-body replacement — a creation's
  gender change is one — so they are re-acquired rather than trusted to stand.
- **Released with `Open77.players.resetControls()`** when the stage goes down.
  It releases this resource's blocks and nothing else: another resource's blocks
  and the game's own restrictions are untouched. The host also releases them on a
  resource stop and at session teardown, so a disconnect leaves nothing behind.
- **Kept while a selection is with the core.** The controls cancel no server
  teleport or respawn, and the core sends `onPlayerLoaded` — which takes the
  stage down — before it places the character.
- **A refusal while the body is being replaced** is one warning per run, and a
  recovery another:

```text
Open77.players.freezePosition was refused: <reason>
the stage controls are held again
```

!!! note "Zoom"
    `Open77.camera.orbit` takes a yaw and no distance, so the stage has nothing
    to hold a zoom with. The platform documents `freezeRotation` as its camera
    and turn restriction; whether the mouse wheel still moves the orbit is
    something to check in game.

### The fallback pin {#hold}

On a client without the controls, or with the grant refused, the camera is
**not locked** — nothing else keeps the mouse off it without taking focus — and
[`STAGE.FREEZE`](config.md#stage-freeze) falls back to holding the character by
teleport:

| | |
|---|---|
| Cadence | 30 times a second (every 33 ms), `Open77.character.state()` is read |
| Correction | a character more than **5 cm** from where it stood, or turned more than **10°**, is put back with `Open77.travel.teleport` |
| Height | left to the game, so nothing is held in the air while it settles |
| A placement | a move of more than **3 m** between two reads is a placement, not a walk; the character is held from where it was put |
| Not corrected | while the puppet is dead, detached or in a vehicle, or while a selection is with the core |

The correction is the bounded, few-centimetre one the platform's own arena
boundary makes, and nothing else: `player.travel` is never used to move anybody
anywhere. The walk animation can show for a frame before a correction lands.

Its failures, each said once:

```text
Open77.players.freezeRotation is not on this client: the camera is not locked, and the character is held by teleport
the player controls were refused (<reason>) -- the manifest must grant players.controls
Open77.travel.teleport is not on this client: the character is not held
the character cannot be held (<reason>) -- the manifest must grant player.travel
holding the character was refused: <reason>
```

The first two switch the stage to the pin for the session. The next two stop the
pin for the session — the second when the teleport's refusal names
`permission_denied` — and the camera orbit is unaffected by any of them.

## Who owns it, and when {#ownership}

This resource owns the stage from the roster through the form and back: it alone
calls the orbit, the clear, the controls and the teleport. Another resource that keeps the
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
| a selection is with the core | camera and controls; the fallback pin lets go, since a teleport would pull the placed character back |
| a character is loaded | down at once, the controls released, and the holder forgotten |
| `opx77_appearance` publishes `needsCreation` | down at once: its face editor has a camera of its own. Stays down until the character is unloaded or a roster arrives |
| another resource calls `close` | down at once: the player has been taken elsewhere |
| the holder stops or reloads without releasing | the hold is forgotten on the next tick, and the stage lingers out. A holder still `starting` — one that holds from its own start handler — keeps its hold |
| `opx77_core` stops | as a character unload: the list closes and the roster is asked for again; a hold stands |
| the gameplay world is not up | down |
| the player is back in the pre-game world | down, and a list up or still being opened is closed |
| this resource stops | down: the controls released, the orbit cleared and the perspective handed back |
| the player disconnects | nothing to do: the host releases the controls at session teardown |

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
- A holder in the `starting` state counts as alive, so a hold taken from the
  holder's own start handler stands.
- A holder that stops or reloads without releasing is noticed on the tick:

```text
<resource> stopped holding the stage without releasing it
```

`needsCreation` normally arrives after `onPlayerLoaded`, which has already taken
the stage down. It is listened for, on
[`APPEARANCE_EVENT`](config.md#appearance-event), for a character this resource
did not see load.

## See also {#see-also}

- [Configuration](config.md#stage) — `ENABLED`, `ORBIT_DEGREES`, `LOCK_CAMERA`,
  `FREEZE`.
- [The selection bucket](../opx77_core/config.md#server-entry-bucket) — why
  nobody else is on the stage.
- [Exports](exports.md#holdstage) — `holdStage` and `releaseStage`.
- [opx77_charcreator](../opx77_charcreator/index.md#the-stage) — the holder on a
  stock install.
