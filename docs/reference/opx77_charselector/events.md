---
title: opx77_charselector events
description: The one event opx77_charselector raises — createRequested, when the player asks for a character the account does not have — and every event it listens to from opx77_core, opx77_menu, opx77_appearance and the platform, with what each does to the roster and the stage.
---

# Events

Every event here is **local, on the client**. This resource registers no net
event and sends none: the roster arrives on `opx77_core`'s own local events, and
every write goes through the core's client exports.

## Non-networked: what it raises {#raises}

### opx77:charselector — createRequested {#create-requested}

Raised when the player chooses an empty slot or the create row, on
[`EVENT`](config.md#event) — `opx77:charselector` as shipped.
[`opx77_charcreator`](../opx77_charcreator/index.md) listens on it; nothing in
this resource creates anything.

```lua
AddEventHandler("opx77:charselector", function(payload)
  if type(payload) ~= "table" or payload.event ~= "createRequested" then return end
  -- payload.slot   which row was chosen, 1-based
  -- payload.used   how many characters the account holds
  -- payload.slots  how many it may hold
end)
```

- payload: [`SelectorEvent`](types.md#selectorevent)

By the time it is raised the list is already down and `opx77_menu` is handing the
keyboard back, so a listener may take the keyboard at once. **The stage is not
down**: it stays up for [5 seconds](stage.md#handover) for the listener to claim
through [`holdStage`](exports.md#holdstage).

**Putting the list back is the listener's job.** Call [`open`](exports.md#open)
when the player backs out. A creation that succeeds needs no call:
`opx77_core` sends a fresh roster after `CreateCharacter`, this resource adopts
it, and the list opens on the new character's row. While a creation it handed
over runs, this resource reopens nothing on a world entry by itself.

An `EVENT` that is not a name leaves the create row doing nothing, and says so:

```text
EVENT is not a name: nothing can be told the player wants a character
```

## Non-networked: what it listens to {#listens}

### From opx77_core {#from-core}

Every one is listened to with a plain `AddEventHandler`: no permission, no
`RegisterNetEvent`. The core also answers the `GetCharacters`,
`RequestCharacters`, `SelectCharacter` and `IsLoggedIn`
[client exports](../opx77_core/exports/client.md#getcharacters) this resource
calls.

#### opx77:client:charactersReady {#characters-ready}

The roster, `{ list, slots, origins }` — see
[`charactersReady`](../opx77_core/events.md#charactersready). It is adopted
whenever it arrives. Before the gameplay world it is only kept; in it the list is
opened again, on a new character's row when the roster has gained one. It clears
a pending selection and a creation handed over, since a fresh roster is the
answer to either.

#### opx77:client:onPlayerLoaded {#on-player-loaded}

A character is in the world: the list closes and the stage drops at once, holder
and all.

#### opx77:client:onPlayerUnloaded {#on-player-unloaded}

Without a selection under way, the list closes, the roster is forgotten, and
`RequestCharacters` is called, so the fresh roster puts the list back up.

#### opx77:client:refused {#refused}

`(code, kind, operation)`. **A refusal is branched on its operation**, never on
the code. `error.tooFast` is raised by every
request the core has, and without the operation this resource would take a
vehicle spawn's refusal for its own. It answers three:

| Operation | Does |
|---|---|
| `selectCharacter` | The selection is over: the list unlocks and the reason goes under it. |
| `ready`, `entry` | The reason goes under the list; with no list up, one log line: `<operation> was refused: <code>`. |

The code is a locale key, and this resource's catalogue carries every one the
three can produce — `character.notFound`, `character.inUse`, `entry.failed`,
`entry.noIdentity`, `entry.timedOut`, `error.unavailable`, `error.badRequest`,
`error.tooFast`, `error.notLoggedIn` — so it is rendered in the player's
language. An unknown code is shown as *That was refused (\<code\>).*

### From opx77_menu {#from-menu}

#### opx77_charselector:row {#row}

The name the roster's rows are raised on. Anything can raise it, so the payload's
`owner` is checked before anything is read.

| `action` | Does |
|---|---|
| `focus` | Follows the cursor, from the spec's [`reportFocus`](../opx77_menu/events.md#focus). |
| `select` | Acts on the row named by its own `data`: `SelectCharacter`, or the hand-over. |
| `close` | The list is gone. For `pause`, `back`, `item` or `closed` — a dismissal — it goes back up 250 ms later while the player still has nothing to choose with. |

A close is not always something this resource asked for — `opx77_menu` lists
eleven reasons, seven of which nobody asked for — so the stage is judged again
from the `close` branch rather than after the export call, and lingers there for
the list that goes back up.

### From opx77_appearance {#from-appearance}

#### needsCreation {#needs-creation}

On [`APPEARANCE_EVENT`](config.md#appearance-event). A loaded character has no
face and the in-world editor is coming for it, with a camera of its own, so the
stage drops at once and stays down until the character is unloaded or a roster
arrives. See
[`needsCreation`](../opx77_appearance/events.md#needs-creation).

### From the platform {#from-platform}

#### open77:worldReady {#world-ready}

Counted only when `Open77.session.characterBootstrap().phase` is `"ready"`: the
pre-game menu world raises it too, while the bootstrap is still `waiting`. The
tick then waits for an attached, alive puppet before the list goes up. A world
entry in any other phase takes the world down, and the stage with it.

#### open77:playerReset:complete {#player-reset}

In the `ready` phase, the gameplay puppet is bootstrapped: the world is up, and
the list goes up if nothing stands in its way.

#### onClientResourceStart and onClientResourceStop {#resource-lifecycle}

| Event | Does |
|---|---|
| `onClientResourceStart`, this resource | The boot: the configuration warnings, then `IsLoggedIn`, `GetCharacters` and `RequestCharacters`. |
| `onClientResourceStart`, `opx77_menu` | `opx77_menu` started late: the roster that could not be drawn goes up now. |
| `onClientResourceStop`, this resource | The stage drops — the orbit cleared, the perspective handed back — because nothing else would take it down. |

A world entry that finds a character loaded, a selection pending or a creation
handed over leaves the list down. That is what keeps the body reload after a
selection, or during a creation, from putting the roster back over the player.

## Log lines {#log}

What this resource says at `warn` and above, verbatim:

```text
no roster yet: asking opx77_core again every 3000 ms
the roster could not be asked for: <reason>
the roster did not open: <reason>
opx77_menu answered no handle for the roster
opx77_menu is not running: the roster goes up when it starts
<operation> was refused: <code>
ROSTER_RETRY_MS is not a positive number: 3000 ms is used
ROSTER_RETRY_MS is inside opx77_core's cooldown: raised to 2500 ms
```

The first carries the configured interval. The stage's own lines are on
[The stage](stage.md), and the `STAGE` configuration warnings on
[Configuration](config.md#stage).

## See also {#see-also}

- [Exports](exports.md) — what a listener calls back.
- [The stage](stage.md#ownership) — what each of these events does to it.
- [Types](types.md#selectorevent) — the hand-over's payload.
