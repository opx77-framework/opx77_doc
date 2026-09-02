---
title: The opx77_appearance resource
description: opx77_appearance is the character's face for OPX//77 — a client-only resource that opens Cyberpunk's own customization modal, captures a snapshot, sends it to opx77_core to be validated and stored, and emits the one announcement that clears the platform's readiness hold.
---

# opx77_appearance

| At a glance | |
|---|---|
| **Version** | `0.2.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `local` — a reload is a script reload, not a reconnect: the face is re-read from `PlayerData` and nothing here survives one |
| **Permissions** | `network.events`, `player.appearance.read`, `player.appearance.edit` |
| **Sides** | client only. There is no `server/`, no `sql/`, no table and no `database.access` |
| **Exports** | five, all client: [`open`](exports.md#open), [`barber`](exports.md#barber), [`isOpen`](exports.md#isopen), [`current`](exports.md#current), [`state`](exports.md#state) |
| **Commands** | none |
| **Events** | sends two net events, registers none; raises [`opx77:appearance`](events.md#opx77-appearance) after every decision — see [Events](events.md) |
| **Reads** | [`opx77_core`](../opx77_core/index.md) for the character and the stored face; [`opx77_notify`](../opx77_notify/index.md) for toasts, optionally |

## What it is {#what-it-is}

The character's face. `opx77_appearance` opens Cyberpunk's own customization
mirror — for a character that arrives without a face, and on demand afterwards —
captures what the player built, and sends it to
[`opx77_core`](../opx77_core/index.md), which validates it and stores it on the
character row.

**It stores nothing itself.** The face is the `appearance` column of
`opx77_characters`, `opx77_core` owns every write to it, and it travels in
`PlayerData` like any other field of the character. This resource holds one
client's view of it for the length of a session, dresses the local puppet with
it, and decides when the player is ready to be let into the world.

Its manifest says the same thing in the permissions block, which asks for three
grants and deliberately declines the rest:

```lua
permissions {
  "network.events",           -- TriggerServerEvent; local.events is not needed
  "player.appearance.read",   -- read the catalogue
  "player.appearance.edit",   -- write the puppet
}
```

`read` alone would let this resource save a face and never put it back on, which
is why both appearance grants are taken. `database.access`, `players.life.*`,
`world.*` and `combat.config` are declined in a comment naming each one: the core
owns the face, and this resource only dresses a puppet.

!!! danger "This resource is what opens the readiness gate"

    Every joining player is held by a hold named `__platform` that no Lua may
    take or release and that has no deadline. It clears on exactly one thing:
    the client announcing
    [`open77:session:gameplayReady`](events.md#gameplay-ready), which this
    resource sends once the local puppet is attached, alive and past the
    "press any key to continue" screen. Without something emitting it,
    `Open77.ready.isReady` is permanently false and `onPlayerReady` never fires
    for anybody — see [The entry gate](../../concepts/entry-gate.md#platform-hold).

## What holds a player, and what does not {#readiness}

This resource takes **no readiness hold of its own** — it has no server half to
take one from. What holds a player is the platform's `__platform` hold, and this
resource decides when it falls.

The announcement is withheld for as long as the player is still building a
character — an hour included — and goes out the moment they are done, abandon it,
or the face is otherwise settled. There is no deadline on the creator: a player
deliberating is not a fault, and a player who quits out of it was never holding
anything the server keeps.

`opx77_core` is the one thing the gate does not stop. It places the character and
releases its own hold as part of `selectCharacter`, without consulting
`Open77.ready`, so on a character with no stored face **the player is placed
before the creator opens**. That is the core's own sequence, not this resource's.

## Where the face lives {#storage}

The client captures the mirror and sends one net event to the core:

```lua
TriggerServerEvent("opx77:server:saveAppearance", { snapshot = snapshot })
```

The core takes the character from the connection — never from the payload —
validates the snapshot, writes it, and publishes it back.

| Direction | Channel |
|---|---|
| write | [`opx77:server:saveAppearance`](events.md#save-appearance), payload `{ snapshot = … }` |
| refusal | [`opx77:client:refused`](events.md#refused), carrying a code, a kind and the operation it answers |
| read | `PlayerData.appearance`, so it arrives with `opx77:client:onPlayerLoaded` |
| read | `opx77_core`'s `GetAppearance` client export, or this resource's [`current`](exports.md#current) |
| change | `opx77:client:appearanceSaved`, whose payload is the snapshot |

A refusal names the request it answers as well as a code, and only one naming
`saveAppearance` is this resource's: an `error.tooFast` raised by a character
selection or a vehicle spawn is left alone rather than taken for the answer to a
capture still in flight. See [the refusal channel](events.md#refused).

There is a **2000 ms cooldown** on that event in the core, under the key
`appearance.request`. This resource waits it out rather than tripping it — see
[`SAVE_COOLDOWN_MS`](config.md#save-cooldown-ms).

!!! info "A save that changes nothing is answered with silence"
    The core writes nothing and publishes nothing for a face identical to the
    stored one, so an unchanged confirm is completed on the client instead of
    being waited on. Waiting for an answer would time out on a correct save.

## Who owns the body family {#body-family}

`opx77_core` does. It is `charInfo.gender` on the character row, the player chose
it when they created the character, and it is the value this resource resolves
the engine's character bootstrap with.

So **nothing here can change it**. The [`open`](exports.md#open) export never
passes a gender to the native editor, and a character creator that comes back on
the other body is refused and reopened,
[`FAMILY_RETRIES`](config.md#family-retries) times. Changing a character's body
type means changing the character, in `opx77_core`.

!!! warning "The engine's `gender` is not the character's"
    A snapshot's `gender` field is the **engine's** opaque body-family hash. The
    `"female"`/`"male"` string is [`CharInfo.gender`](../opx77_core/types.md#charinfo)
    and lives on the character row. The two are not interchangeable and this
    resource never derives one from the other — see
    [`BodyFamily`](types.md#bodyfamily).

## Why a stored face is refused after a game update {#build}

A snapshot is not a mesh. It is a list of positions in the customization
catalogue — for each option, which index the player chose — so it only means
anything against the catalogue it was captured on.
[`GAME_BUILDS`](config.md#game-builds) names the builds this resource will read a
stored face back into, and a face from any other is **not applied**: applying it
would put a different face on the puppet rather than failing.

The player joins with the pristine one, is told once, and the next save writes a
face against the catalogue that is actually loaded. Widening `GAME_BUILDS` does
not make an old snapshot fit; it only stops this resource from saying so, and the
core keeps [its own list](config.md#game-builds) regardless.

## What happens when a character never gets a face {#no-face}

Nobody is ever left unable to enter. Every ending below places the player, and
none of them stores anything.

| Ending | What the player gets |
|---|---|
| The creator is closed or cancelled | the character bootstrap is failed; there is no world to load |
| Wrong body type, `FAMILY_RETRIES` times | the pristine face of their own body, nothing stored |
| The core refuses the write, or never answers | the same, with the reason on screen |

In the last two the creator is **not** reopened for that character again this
session, or it would come straight back up on top of somebody standing in Night
City. [`open`](exports.md#open) is the way back: it opens an editor on a
character with no stored face and saves the first one like any other capture.

## Why there is no command {#no-command}

A chat command cannot be registered from a client resource on this platform, and
this one has no server half to register one from. The editor is opened through
[`open`](exports.md#open) and [`barber`](exports.md#barber) — a menu, a ripperdoc
prop or any other client resource makes the call.

## Where to go next {#next}

- [Exports](exports.md) — the five calls, their error codes, and why none of
  them writes a face.
- [Events](events.md) — the two net events it sends, the channel it publishes
  every decision on, and everything it listens to.
- [Configuration](config.md) — the eight keys, the two deadlines, and the
  locale catalogue.
- [Types](types.md) — every shape the exports answer with and every error code
  they can carry.
- [The entry gate](../../concepts/entry-gate.md) — what `__platform` is and why
  this resource is the only thing that clears it.
- [The client export contract](../../concepts/export-contract.md) — read this
  before calling anything here.
