---
title: The opx77_appearance resource
description: opx77_appearance is the character's face for OPX//77 — it spends the character bootstrap at join, puts the selected character's body and face on in the world, opens Cyberpunk's own customization mirror, sends what the player built to opx77_core, emits the one announcement that clears the platform's readiness hold, and hands every player's look to the other players so they are drawn at all.
---

# opx77_appearance

| At a glance | |
|---|---|
| **Version** | `0.8.0` |
| **Requires** | `open77_version ">=0.0.1"`. No `dependency` is declared |
| **Auto start** | yes |
| **Reload policy** | `local` — a reload is a script reload, not a reconnect: the face is re-read from `PlayerData`, the panel is taken down, and nothing here survives one |
| **Permissions** | `network.events`, `player.appearance.read`, `player.appearance.edit`, `player.equipment.read`, `puppets.present`, `players.life.read` |
| **Sides** | client, which does everything about the face; and one server file, `server/presence.lua`, which only hands each player's look to the other players, in memory — see [How other players see this one](#presence). There is no `sql/`, no table, no `database.access` and no WebUI page |
| **Exports** | twelve, all client: [`getSkin`](exports.md#getskin), [`captureSkin`](exports.md#captureskin), [`getFamily`](exports.md#getfamily), [`setSkin`](exports.md#setskin), [`saveSkin`](exports.md#saveskin), [`openEditor`](exports.md#openeditor), [`openCreator`](exports.md#opencreator), [`isOpen`](exports.md#isopen), [`openPanel`](exports.md#openpanel), [`closePanel`](exports.md#closepanel), [`isSettled`](exports.md#issettled), [`state`](exports.md#state) |
| **Commands** | none |
| **Events** | sends two net events to the platform and the core, and seven of its own between its two halves; raises [`opx77:appearance`](events.md#opx77-appearance) after every decision — see [Events](events.md) |
| **Reads** | [`opx77_core`](../opx77_core/index.md) for the roster, the character and the stored face; [`opx77_menu`](../opx77_menu/index.md) to draw the panel, optionally; [`opx77_notify`](../opx77_notify/index.md) for toasts, optionally |

## What it is {#what-it-is}

The character's face, and the body it goes on. `opx77_appearance` spends the
platform's one-shot character bootstrap at join, puts the selected character's
own body family and stored face on the puppet in the gameplay world, opens
Cyberpunk's own customization mirror on demand, captures what the player built,
and sends it to [`opx77_core`](../opx77_core/index.md), which validates it and
stores it on the character row.

**It is a service, not a flow.** It reads, applies, stores and edits the live
character's face; it never decides that a player should be sent to an editor.
When the live character has no stored face it publishes
[`needsCreation`](events.md#needs-creation) and waits for something to call
[`openCreator`](exports.md#opencreator) — see
[Who opens the creator](#who-opens-the-creator). On a stock install that is
[`opx77_charcreator`](../opx77_charcreator/index.md).

**It stores nothing itself.** The face is the `appearance` column of
`opx77_characters`, `opx77_core` owns every write to it, and it travels in
`PlayerData` like any other field of the character. This resource holds one
client's view of it for the length of a session, dresses the local puppet with
it, and decides when the player is ready to be let into the world.

Its manifest says the same thing in the permissions block, which asks for six
grants and deliberately declines the rest:

```lua
permissions {
  "network.events",           -- both halves: the face and the look, and the looks handed back
  "player.appearance.read",   -- read the catalogue; also what captureBody needs
  "player.appearance.edit",   -- write the puppet
  "player.equipment.read",    -- client: the equipment registry and the active outfit, read only
  "puppets.present",          -- client: setBody, setSlot, setWardrobe on another player's proxy
  "players.life.read",        -- the local player's life state, read only
}
```

`read` alone would let this resource save a face and never put it back on, which
is why both appearance grants are taken. There is no `webui.*`: the panel is a
list [`opx77_menu`](../opx77_menu/index.md) draws, and that resource owns the
surface. `database.access`, the `players.life.*` writes, `world.*`,
`combat.config` and `player.equipment.edit` are declined in a comment naming each
one: the core owns the face, and this resource dresses its own puppet and hands
on what the others wear without changing it.

!!! danger "This resource is what opens the readiness gate"

    Every joining player is held by a hold named `__platform` that no Lua may
    take or release and that has no deadline. It clears on exactly one thing:
    the client announcing
    [`open77:session:gameplayReady`](events.md#gameplay-ready), which this
    resource sends once a character is loaded, on its own body, with its face
    settled, and the local puppet is attached, alive and past the "press any key
    to continue" screen. Without something emitting it, `Open77.ready.isReady`
    is permanently false and `onPlayerReady` never fires for anybody — see
    [The entry gate](../../concepts/entry-gate.md#platform-hold).

## The world comes first {#world-first}

The platform's shell keeps an opaque loading cover over the client for as long as
the character bootstrap — `Open77.session.characterBootstrap().phase` — is
`"waiting"`, and **nothing a server resource draws is visible under it**. It
starts loading the gameplay world only once a resource has called
`Open77.session.resolveCharacterBootstrap(family)`, and lifts the cover once that
world has streamed. A roster opened before then is on screen and unseen, and
nothing is ever chosen.

So this resource spends the bootstrap **at join, before any character is
chosen**, and everything that involves the player — the roster, the identity
form, the face editor — happens in the gameplay world afterwards:

1. The pre-game menu world raises `open77:worldReady` with the phase still
   `"waiting"`, or this resource starts into that state. Either one begins the
   pick, once per connection.
2. The pick reads the roster `opx77_core` already holds — the
   `opx77:client:charactersReady` it broadcast, or the `GetCharacters` client
   export — every 250 ms for up to
   [`BOOTSTRAP.ROSTER_WAIT_MS`](config.md#bootstrap-roster-wait-ms). It never
   *requests* one: the core cools roster requests at 2000 ms per player and
   drops the excess, and a request from here would cost the roster screen its
   own.
3. The body family loaded is the `gender` of the account's most recently played
   character — the highest `lastLoggedOut` in that roster. With no roster in
   time, or no character ever played, it is
   [`BOOTSTRAP.DEFAULT_FAMILY`](config.md#bootstrap-default-family).
4. The shell loads the world on that body and lifts the cover. `opx77_core` holds
   the player unplaced until a character is selected in it.

The decision is one log line, with the reason:

```text
bootstrap (worldReady): loading the female body, the last character played
character bootstrap resolved as female
```

The reason is one of `the last character played`, `no character played yet` or
`no roster in time`, and the origin in brackets is `worldReady` or
`resourceStart`.

That body is a guess made before anybody is chosen, so it is not always the
selected character's — see [Who owns the body family](#body-family).

!!! warning "Known issue: a character on the other body can leave the cover up"

    Selecting a character whose body family differs from the body loaded at join
    reloads the world onto the right one, and that reload can leave the loading
    cover up. It is being fixed. Until it is, the body loaded at join is the most
    recently played character's, so entering as that character avoids the
    reload altogether. See
    [Troubleshooting](../../guides/troubleshooting.md#body-family-cover).

## What holds a player, and what does not {#readiness}

This resource takes **no readiness hold of its own**. What holds a player is the
platform's `__platform` hold, and this resource decides when it falls.

The announcement is **never sent before a character is loaded**. Until one is,
`opx77_core` holds the player unplaced in the gameplay world, which is intended.
After that it is withheld while the world reloads onto the character's body,
while a stored face is still going on, and for as long as the player is still
building a face in the editor — an hour included — and goes out the moment the
face is settled, built, or honestly given up on. There is no deadline on an open
editor: a player deliberating is not a fault, and a player who quits out of it
was never holding anything the server keeps.

`opx77_core` is the one thing the gate does not stop. It places the character and
releases its own hold as part of `selectCharacter`, without consulting
`Open77.ready`, so on a character with no stored face **the player is placed
before the editor opens**. That is the core's own sequence, not this resource's.

## Who opens the creator {#who-opens-the-creator}

Not this resource. When the live character has no stored face it publishes
[`needsCreation`](events.md#needs-creation) on its event channel and waits:

```lua
AddEventHandler("opx77:appearance", function(payload)
  if payload.event ~= "needsCreation" then return end
  -- payload.family is the body the editor opens on
  CreateThread(function()
    Open77.exports.call("opx77_appearance", "openCreator")
  end)
end)
```

[`openCreator`](exports.md#opencreator) opens Cyberpunk's own mirror **in the
world**, in `ripperdoc` mode, on the body family the character was created with
(`charInfo.gender`):

1. it waits for a puppet a face may go on — the gameplay world, not a body about
   to be replaced by a reload, past the "continue" screen;
2. when the world is on the other body it reloads the player with
   `Open77.appearance.switchBodyFamily(gender, true)` — the `true` marks the
   reload as an edit transition — and reopens the editor once
   `Open77.appearance.takeBodyFamilyTransition()` answers `edit:<gender>` on the
   other side of it;
3. it opens `Open77.appearance.open({ mode = "ripperdoc", gender = gender })`.

There is no pre-world creator. The vanilla character creator the platform can
raise inside the bootstrap is never asked for: the bootstrap is already spent by
the time anybody has a character to build a face for.

Everything after the player confirms belongs here again — the capture, the check
that the body they built on is the body their character is, and the save through
`opx77_core`. The outcome arrives as `created`, and the readiness announcement
follows it.

The announcement waits for an answer to `needsCreation` for
[`CREATION_WAIT_MS`](config.md#creation-wait-ms). If nothing has called
`openCreator` by then, this resource says so in the log, once, naming the export
that was never called, and lets the player in on the default face of their own
body. It still opens nothing itself.

## The panel {#panel}

One resource owns the appearance panel, so a ripperdoc, a clothes store and a
menu all call the same one instead of each shipping their own page. It is a
**list, drawn by [`opx77_menu`](../opx77_menu/index.md)**:
[`openPanel`](exports.md#openpanel) puts it up and
[`closePanel`](exports.md#closepanel) takes it down, for the caller that opened
it only.

| Level | Rows |
|---|---|
| root | `Looks`, `Body`, `Outfits`, each carrying its own summary as a value |
| `Looks` | the saved look, **Wear it**, **Edit face** and **Hair only** — the two ways into the native editor |
| `Body` | the body family, stated and not offered: `opx77_core` owns it |
| `Outfits` | one row saying it is not built |

A row that cannot be used is drawn disabled with the reason as its value —
`none`, `other build`, `worn`, `Not right now.` — rather than greyed out with
nothing beside it. There is no section argument: `opx77_menu` publishes nothing
that opens a list already inside one of its levels.

**It is the frame around the face, not the face.** An appearance option is
`{ part, name, value, choices }` where `name` is an opaque 64-bit catalogue hash
with no human label anywhere on the platform, so there is nothing to label a
slider with. Cyberpunk's own modal is the only face editor there is, and the
panel's job is to open it.

**The panel never draws over the native mirror.** There is no event for the
mirror opening, and `opx77_menu` is a HUD surface that would keep drawing over it
and take its arrow keys, so while the panel is up `Open77.appearance.isOpen()` is
read every 200 ms and a modal — this resource's or anybody's — takes the panel
down. A raise from that call counts as on screen: a closed list is recoverable, a
list over the mirror is not. **Edit face** and **Hair only** take the panel down
and wait for `opx77_menu` to answer the close *before* the mirror is asked for.

One panel at a time, keyed on the invoking resource. It also closes when its
owner stops or reloads, when the character changes or unloads, on Escape and the
pause key, and on BACK at the top of the list. Every close is published as
`panelClosed` with a [reason](types.md#appearancepanelreason).

!!! info "One saved look, and why"
    The core stores exactly one face per character — a single nullable JSON
    column — with no slot number, so a wardrobe of saved looks is not possible
    without core work. The panel shows the one stored look, says whether the
    puppet is wearing it, and puts it back on when it is not. **Outfits** is
    drawn so the gap is visible: it needs a clothing catalogue with human labels,
    and nothing on this platform publishes one.

`opx77_menu` is optional and is not declared a dependency. With it stopped,
`openPanel` answers `menu_not_running` and every other export is unaffected.

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
| read | `opx77_core`'s `GetAppearance` client export, or this resource's [`getSkin`](exports.md#getskin) |
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
it when they created the character, and it is the body this resource puts the
world on once the character is selected. The body the world first loads with at
join is only [the guess made before anybody is chosen](#world-first).

A selected character whose `charInfo.gender` is not the body the world loaded is
**reloaded onto it before any face goes on**, with
`Open77.appearance.switchBodyFamily(gender, false)`. The old puppet is neither
dressed nor announced while the reload runs — [`isSettled`](exports.md#issettled)
answers `waiting = "body"` — and the world entry that follows the reload runs the
restore again, on the new puppet. `body_family_already_active` counts as done. A
restore that the engine answers with `body_gender_switch_requires_reload` is
reloaded the same way, onto the character's family.

So **nothing here can change it**. [`openEditor`](exports.md#openeditor) never
passes a gender to the native editor; [`openCreator`](exports.md#opencreator)
passes the character's own, and a creation editor that comes back on the other
body is refused and reopened. The reloads and the reopened editors both count
against [`FAMILY_RETRIES`](config.md#family-retries) for the character; past it
the player keeps the body they are on. Changing a character's body type means
changing the character, in `opx77_core`.

!!! warning "The engine's `gender` is not the character's"
    A snapshot's `gender` field is the **engine's** opaque body-family hash. The
    `"female"`/`"male"` string is [`CharInfo.gender`](../opx77_core/types.md#charinfo)
    and lives on the character row. The two are not interchangeable and this
    resource never derives one from the other — see
    [`BodyFamily`](types.md#bodyfamily).

## How other players see this one {#presence}

**Another client draws a player only from what it is handed**: the body — the
family and its customization groups, as `Open77.appearance.captureBody` reads
them, put on with `Open77.puppets.setBody` — every equipment slot, put on with
`setSlot`, and the wardrobe, with `setWardrobe`. The engine replicates the
position, the vehicle and the actions; it does not replicate a look, and a proxy
that has none is never dressed, so the player is not there at all. A vehicle they
drive is.

On the platform, `open77_appearance` hands those records out and its
`open77_equipment` and `open77_wardrobe` relays put them on; both relays depend
on it, so none of them runs beside this resource. This resource does all of it,
in `client/presence.lua` and `server/presence.lua`:

- **Publishing.** Once the player is announced into the gameplay world on their
  own settled face, with no editor up and no body reload running, the client
  reads the body, the equipment registry and the active outfit every second, and
  sends them when they changed, or when the server did not answer the last ones
  within three seconds. An item the body family cannot wear is sent as an empty
  slot, as the platform's record drops it. Every world entry, and a restart of
  either half, publishes again.
- **Asking.** After every world entry the client asks for everybody else's look,
  whatever state its own is in — a player whose own body cannot be read still
  sees the others — and asks again until the server answers.
- **Handing out.** The server takes the player id from the connection and checks
  the shape: the platform's own bounds for a body, refused whole when it is
  wrong, and answered so the client does not keep sending it; a record name or
  `false` for each of the nine slots and the seven an outfit overrides, where
  anything else becomes an empty slot rather than costing the player their body.
  It sends the look to every other client, never to its owner, whose look is the
  engine's.
- **Buckets.** The native roster retires the replicas of a player who changes
  routing bucket, and `opx77_core` moves every player out of a selection bucket
  when a character is placed. On `onPlayerBucketChange` the server hands the
  player and everybody already in that bucket each other's looks again, and
  ignores a move another one has superseded.
- **A body reload** withdraws the body first: observers drop their proxy, and
  get the new body with the publication that follows the reload. A character
  unloading withdraws it too.
- **Nothing is stored.** A look lives in the server's memory until the player
  leaves.

What is checked is the shape, not the truth: a client can only ever describe its
own player, which is the trust the platform's package extends as well.
[`PRESENT_BODIES = false`](config.md#present-bodies) turns both halves off, for
a server where another resource hands looks out.

!!! warning "Run this resource or `open77_appearance`, never both"

    Both halves stand down, with one log line each, while the platform's
    `open77_appearance` is running — it hands looks out itself. But the two
    fight over the character bootstrap and the face, so the stand-down is not a
    way to run them together: run one.

    ```text
    open77_appearance is running and hands looks out itself; this resource does not. Two appearance resources fight over the bootstrap and the face: run one.
    ```

A body the server cannot read is said once per player, and the players the
server hands it to cannot draw them:

```text
player 7 published a body this server cannot read; other players cannot draw them
```

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

Nobody is ever left unable to enter. The world is already loaded when a character
is chosen, so **no ending fails the character bootstrap**: every one below lets
the player in, and none of them stores anything. The character itself exists
either way — only its face does not.

| Ending | What the player gets | `created` error |
|---|---|---|
| The editor is closed or cancelled | the pristine face of their own body | `character_creation_cancelled` |
| Nothing calls `openCreator` within `CREATION_WAIT_MS` | the same, and one log warning | none: no `created` is published |
| The editor will not open | the same, with the reason on screen | `character_creator_unavailable` |
| The editor's face cannot be captured | the same, with the reason on screen | the capture's reason, else `character_capture_failed` |
| Wrong body type, `FAMILY_RETRIES` times | the pristine face of whichever body they are on | `body_family_mismatch` |
| The core refuses the write, or never answers | the pristine face of their own body, with the reason on screen | a core code, `not_sent` or `save_timeout` |

After any of them but the unanswered one — where a late `openCreator` still
opens the editor — the editor is **not** reopened by `openCreator` for that
character again this session (`creation_refused`), or it would come straight back
up on top of somebody standing in Night City.
[`openEditor`](exports.md#openeditor) is the way back: it opens an editor on a
character with no stored face and saves the first one like any other capture.

## Why there is no command {#no-command}

There is none. Its one server file hands looks out and registers nothing else.
The panel is opened through
[`openPanel`](exports.md#openpanel) and the native editor through
[`openEditor`](exports.md#openeditor) — a menu, a ripperdoc prop or any other
client resource makes the call.

## Where to go next {#next}

- [Exports](exports.md) — the twelve calls, their error codes, and which of them
  answer only that the work was asked for.
- [Events](events.md) — the two net events it sends, the private wire between
  its two halves, the channel it publishes every decision on, and everything it
  listens to.
- [Configuration](config.md) — the eleven keys, `BOOTSTRAP` and
  `PRESENT_BODIES` among them, the deadlines, and the locale catalogue.
- [Types](types.md) — every shape the exports answer with and every error code
  they can carry.
- [The entry gate](../../concepts/entry-gate.md) — what `__platform` is and why
  this resource is the only thing that clears it.
- [The client export contract](../../concepts/export-contract.md) — read this
  before calling anything here.
