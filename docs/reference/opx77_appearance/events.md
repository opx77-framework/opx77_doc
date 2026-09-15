---
title: opx77_appearance events
description: The three net events opx77_appearance sends — the face and the clothing it hands to opx77_core, and the readiness announcement that clears the platform hold — the private wire its two halves hand every player's look over, the local channel it publishes every decision on, and everything it listens to from the core, from opx77_menu and from the host.
---

# Events

This resource sends **three** net events outside itself — the face and the
clothing to the core, and the readiness announcement to the platform. Everything
about the face and the clothing that it hears arrives on the client's local bus,
either from [`opx77_core`](../opx77_core/index.md)'s client half,
[`opx77_menu`](../opx77_menu/index.md) or the host. Beside those, its two halves
hand every player's look to the other players over
[seven private net events](#presence-wire).

- **Networked** — crosses the wire. Sending one needs `network.events`, which
  this resource declares for the three calls below and for the presence wire.
- **Non-networked** — never leaves the machine. Registered with a bare
  `AddEventHandler`.

!!! warning "The client's local bus is host-wide"

    Any resource on the player's machine can `TriggerEvent` any name, and a
    local `TriggerEvent` also reaches `RegisterNetEvent` handlers of the same
    name. Nothing this resource receives locally is a trust boundary, and
    nothing it publishes is proof to anybody. The one decision that has to be
    unforgeable — whether a face or a clothing record may be stored — is made by
    `opx77_core`'s server half from the connection. See
    [The client export contract](../../concepts/export-contract.md#local-bus).

## Networked (client → server) {#networked-client-to-server}

### opx77:server:saveAppearance {#save-appearance}

The face the player just confirmed, sent to `opx77_core` to be validated and
stored. It is the only write channel for a face there is.

```lua
TriggerServerEvent('opx77:server:saveAppearance',
	{ snapshot = payload, citizenId = citizen })
```

- payload: `table`
    - `snapshot`: [`AppearanceSnapshot`](types.md#appearancesnapshot) — the four
      fields that *are* the face, plus the options array. The editor-only
      metadata the host's capture carries is stripped first, because the
      runtime's value codec will not carry it.
    - `citizenId`: [`CitizenId`](types.md#citizenid) — the character the face was
      captured for, read when the save is asked for, before the cooldown wait.

**What the core does with it.** It is registered in
`opx77_core/server/appearance.lua`. The character comes from the connection and
never from the payload, the payload must be a table, the request is cooled at
2000 ms under the key `appearance.request`, a `citizenId` that is not the
connection's loaded character is refused with `appearance.stale`, and the
snapshot is then put into canonical form — dense options, lower-cased names,
every field the type the column expects — before it is written to
`opx77_characters.appearance` and published back. A core without the stale check
ignores `citizenId`. See
[`opx77:server:saveAppearance`](../opx77_core/events.md#saveappearance) on the
core's page.

**Answers with** `opx77:client:onAppearanceUpdate` on success, which the core's
client half re-raises locally as
[`opx77:client:appearanceSaved`](#appearance-saved); or with a refusal on
[`opx77:client:refused`](#refused). A face identical to the stored one is
answered with **silence**, and this resource completes that case itself.

!!! info "The cooldown is waited out, not tripped"
    A capture goes out no sooner than [`SAVE_COOLDOWN_MS`](config.md#save-cooldown-ms)
    after the last one; a commit inside that window is held back rather than
    refused, because an `error.tooFast` would cost the capture. If nothing
    answers within [`COMMIT_MS`](config.md#commit-ms), the capture is given up
    on: an edit puts the stored face back on the puppet, and a creation ends on
    the default face.

**Side** `net event` — sent by this resource's client half. Any client resource
holding `network.events` can send the same name; the core re-derives everything
that matters from the connection.

### opx77:server:saveClothing {#save-clothing}

What the character wears, once a change has held on the puppet, sent to
`opx77_core` to be validated and stored.

```lua
TriggerServerEvent('opx77:server:saveClothing', { citizenId = citizen, clothing = record })
```

- payload: `table`
    - `citizenId`: [`CitizenId`](types.md#citizenid) — the character the record
      was read for.
    - `clothing`: [`AppearanceClothing`](types.md#appearanceclothing) — the nine
      slots, the seven outfits and the active one, in canonical form.

**What the core does with it.** It is registered in
`opx77_core/server/clothing.lua`. The payload must be a table, the request is
cooled at 2000 ms under the key `clothing.request`, the connection must have a
character loaded (`error.notLoggedIn`), and `citizenId` must be that character
(`clothing.stale`). The record is validated (`clothing.invalid`), bounded
(`clothing.tooLarge`), and written to `opx77_character_clothing` unless it
matches the stored one. A character whose stored clothing could not be read at
login is refused with `error.unavailable`.

**Answers with** `opx77:client:onClothingUpdate` on success, which the core's
client half re-raises locally as
[`opx77:client:clothingSaved`](#clothing-saved); or with a refusal on
[`opx77:client:refused`](#refused) naming the operation `saveClothing`. A record
identical to the stored one is answered with silence, and this resource does not
send one.

It is sent once a second at most, after the change has held for
[`CLOTHING.SAVE_DEBOUNCE_MS`](config.md#clothing-save-debounce-ms) and
[`SAVE_COOLDOWN_MS`](config.md#save-cooldown-ms) has passed since the last
clothing save, and never while
[`CLOTHING.PERSIST`](config.md#clothing-persist) is `false` or the platform's
`open77_appearance` is running. See
[What the character wears](index.md#clothing).

**Side** `net event` — sent by this resource's client half.

### open77:session:gameplayReady {#gameplay-ready}

The announcement that this player is genuinely in the world. It takes no
arguments, and it is the **only** thing that clears the platform's `__platform`
readiness hold.

```lua
TriggerServerEvent('open77:session:gameplayReady')
```

It is sent at most once per world entry, and only when all of these hold:

| Condition | Meaning |
|---|---|
| not already announced | one per world entry; a new world entry resets it |
| `worldEligible` | this world attachment is the gameplay one: the character bootstrap phase read `"ready"` when it was entered. The pre-game menu world raises `open77:worldReady` too, with the phase still `"waiting"`, and its puppet also answers attached and alive — so only the phase tells them apart |
| a character is loaded | nothing is announced before one is: until then `opx77_core` holds the player unplaced, which is intended |
| the face has settled | the character's own body is on — no body reload outstanding — and its face restored, committed, or honestly given up on; no creation running, no `needsCreation` still unanswered, no `create` commit outstanding. [`isSettled`](exports.md#issettled) is this condition, and `state().settled` is the same value |
| the player is in gameplay | the host reports the puppet attached, alive, and above zero health |

A restore that was merely *queued* additionally waits for the mirror's own
confirmation and for `open77:playerReset:complete`; a restore that **failed** is
an honest settled state and must not strand the player behind the gate. Clothing
is not waited on: it goes on after the announcement.

The conditions are re-tested every 200 ms by the worker thread, because the engine
state behind the last one raises no event of its own. A send the host does not
accept is one log line, and is tried again on the next pass:

```text
gameplay-ready not sent: <reason>
```

!!! danger "Nothing else on a stock install sends it"
    Without it, `Open77.ready.isReady` is permanently false and `onPlayerReady`
    never fires for anybody. See
    [The entry gate](../../concepts/entry-gate.md#platform-hold).

**Side** `net event` — sent by this resource's client half only. This resource
never checks whether the platform accepted it; the local flag records only that
the send succeeded.

## Networked (server → client) {#networked-server-to-client}

None from the core: everything the core sends this resource arrives through the
core's own client half, which re-raises each wire event on the local bus — which
is why every face and clothing handler below is a bare `AddEventHandler`. The only
net events this resource registers are its own presence wire.

## The presence wire {#presence-wire}

Private to this resource: nothing outside it should raise or rely on these, and
their payloads are free to change. See
[How other players see this one](index.md#presence).

| Event | Direction | Carries |
|---|---|---|
| `opx77_appearance:present` | client → server | this player's look — `body`, `equipment`, `wardrobe` — and a sequence number |
| `opx77_appearance:presentAck` | server → client | the sequence answered, and whether the body could be read |
| `opx77_appearance:replay` | client → server | a request for everybody else's look after a world entry, with a sequence number |
| `opx77_appearance:replayed` | server → client | the sequence answered, once every look has been sent |
| `opx77_appearance:look` | server → client | one other player's id and their [`AppearanceLook`](types.md#appearancelook), or `false` while their body is away |
| `opx77_appearance:absent` | client → server | this player's body is going — a reload, or the character unloading |
| `opx77_appearance:resend` | server → every client | the server half started and holds nothing: publish and ask again |

The server takes the player from the connection, never from the payload, and
checks the shape, not the truth: a client can only ever describe its own player.
It floors `present` and `replay` at 500 ms per player, measured on
`GetGameTimer`. Every one of them is ignored while
[`PRESENT_BODIES`](config.md#present-bodies) is `false` or the platform's
`open77_appearance` is running.

On `look`, the client puts each of the nine equipment slots on the proxy with
`Open77.puppets.setSlot`, the wardrobe with `setWardrobe`, then the body with
`setBody` — the proxy is dressed once all three are there. `false` removes the
body with `setBody(player, false)`.

## Non-networked: what it publishes {#non-networked}

### opx77:appearance {#opx77-appearance}

Raised after every decision this resource reaches, on the name
[`OPX_APPEARANCE_CONFIG.EVENT`](config.md#event) — `"opx77:appearance"` as
shipped.

```lua
AddEventHandler("opx77:appearance", function(payload) end)
```

- payload: [`AppearanceEvent`](types.md#appearanceevent)
    - `ok`: `boolean` — whether the decision went the way it was meant to.
    - `event`: [`AppearanceEventName`](types.md#appearanceeventname) — which
      decision this is. **Branch on this before anything else.**
    - `error`: `string | nil` — present only when `ok` is `false`.
    - `citizenId`: `string | nil` — the character it concerns.
    - `family`: `string | nil` — on `needsCreation` only: the body family the
      editor opens on.
    - `unchanged`: `boolean | nil` — on `saved` only: the face matched the
      stored one, so nothing was written.
    - `reason`: [`AppearancePanelReason`](types.md#appearancepanelreason)`| nil`
      — on `panelClosed` only: what took the panel down.

| `event` | `ok` | Raised when |
|---|---|---|
| `gameplayReady` | `true` | The [readiness announcement](#gameplay-ready) went out. |
| `restored` | `true` | A stored face was applied to the puppet. |
| `restored` | `false` | The apply failed for good; `error` is the host's own reason. |
| `settled` | `false` | The stored face is from a build [`GAME_BUILDS`](config.md#game-builds) does not accept; `error` is `stored_build_mismatch` and the player enters on the default face of their own body. |
| `needsCreation` | `true` | The character has no stored face. **Nothing opens an editor until something calls [`openCreator`](exports.md#opencreator)** — see [the handshake](#needs-creation). `family` carries the body the editor opens on. |
| `applied` | `true` | A snapshot handed to [`setSkin`](exports.md#setskin), or the panel's **Wear it**, reached the puppet. |
| `applied` | `false` | It did not; `error` is the host's own reason. |
| `created` | `true` | The face the editor built was stored. The readiness announcement follows it. |
| `created` | `false` | The creation stored nothing and the player keeps the default face; `error` is `character_creation_cancelled`, `character_creator_unavailable`, `body_family_mismatch`, the capture's reason or `character_capture_failed`, a core refusal code, `not_sent` or `save_timeout`. |
| `saved` | `true` | An edit was stored — or the face matched the stored one, which the core answers with silence and this resource completes itself, carrying `unchanged = true`. |
| `saved` | `false` | The core refused the save, or the net event was not accepted; `error` is the refusal code or `not_sent`. |
| `characterChanged` | `true` | The live character changed underneath this resource. |
| `panelOpened` | `true` | `opx77_menu` answered with a list on screen, for [`openPanel`](exports.md#openpanel) or [the panel key](index.md#key). |
| `panelClosed` | `true` | The panel went down; `reason` says why. |
| `clothingRestored` | `true` | The stored clothing, or the default record for a character with none, read back on the puppet. |
| `clothingRestored` | `false` | It never read back after five put-ons; `error` is `clothing_not_restored`, and nothing is saved until the next world entry. |
| `clothingSaved` | `true` | A clothing change this client sent was stored. |
| `clothingSaved` | `false` | The core refused that change — `error` is its code, such as `clothing.invalid` or `clothing.tooLarge` — or saves stopped for the character after two failures in a row, and `error` is `error.unavailable` or `save_timeout`. A refusal with `error.tooFast`, `clothing.stale` or `error.notLoggedIn` publishes nothing. |

#### The needsCreation handshake {#needs-creation}

**This resource never opens an editor on its own.** When the live character has
no stored face it publishes `needsCreation`, once per character, and waits:

```lua
AddEventHandler("opx77:appearance", function(payload)
  if payload.event ~= "needsCreation" then return end
  -- payload.family is "female" or "male": the body the editor opens on
  CreateThread(function()
    Open77.exports.call("opx77_appearance", "openCreator")
  end)
end)
```

It is published in the gameplay world, after the character has been selected —
the character bootstrap was spent at join, before anybody was chosen, and is not
waited on here. [`openCreator`](exports.md#opencreator) opens Cyberpunk's own
mirror in the world, on that body family, reloading the player onto it first when
the world was loaded on the other one.

Everything after the player confirms belongs to this resource again — the
capture, the check that the body they built on is the body their character is,
and the save through `opx77_core`. The outcome arrives as `created`.

!!! danger "If nothing answers, the player enters on the default face"

    The readiness announcement waits on the answer, so an unanswered
    `needsCreation` would hold the gate for ever. After
    [`CREATION_WAIT_MS`](config.md#creation-wait-ms) this resource says so in the
    log — **once**, naming the `openCreator` export that was never called — and
    lets the player in on the default face of their own body:

    ```text
    <citizenId> has no stored face and nothing called the `openCreator` export
      the player enters on the default face; a character creator resource is
      what opens the editor. See README, "Who opens the creator".
    ```

    No `created` is published for it. A later `openCreator` still opens the
    editor.

!!! info "`settled` is only ever a refusal"
    It is published in one place: the stored face is from a build this resource
    will not read back. Every other way a world entry settles — a restore, a
    creation, or a character that simply has no face — reports itself through
    `restored`, `created`, or nothing at all.

Some failures are told to the player and **not** published: a capture that could
not be turned into a payload on an edit, a save that timed out on an *edit*, an
editor that would not open from [`openEditor`](exports.md#openeditor) or the
panel, and a body-family reload that failed or ran out of
[`FAMILY_RETRIES`](config.md#family-retries). Those raise a toast, or a chat line,
and a log line only.

**Side** `client` — any client resource, no permission. It is a plain
`TriggerEvent`, so treat it as untrusted like any other name on the local bus.

#### Example {#opx77-appearance-example}

```lua
-- a client script in your own resource
AddEventHandler("opx77:appearance", function(payload)
  if payload.event == "gameplayReady" then
    -- the platform hold has been asked to clear; the player is playable
  elseif payload.event == "saved" and not payload.ok then
    print("the core refused a face: " .. tostring(payload.error))
  elseif payload.event == "clothingSaved" and not payload.ok then
    print("clothes not saved: " .. tostring(payload.error))
  elseif payload.event == "panelClosed" then
    print("the panel went down: " .. tostring(payload.reason))
  end
end)
```

## Non-networked: what it listens to {#listens}

### From opx77_core {#from-core}

Each of these is the core's own local re-emission of a wire event, so a bare
`AddEventHandler` is the right registration.

| Event | What this resource does with it |
|---|---|
| `opx77:client:charactersReady` | Keeps the roster it carries. The join-time bootstrap reads it to find the account's most recently played character — see [The world comes first](index.md#world-first). |
| `opx77:client:onPlayerLoaded` | Adopts the character: the citizen id, `charInfo.gender` as the body family, `PlayerData.appearance` as the stored face and `PlayerData.clothing` as the stored clothing. Then decides what this world entry's face is, putting the world on the character's own body first. |
| `opx77:client:playerDataChanged` | The same call. Money and jobs move through this name constantly, so it returns immediately unless the citizen id changed. |
| `opx77:client:onPlayerUnloaded` | [Unloads the character](index.md#unload): forgets it and any restore still under way, releases the native transaction, forgets its clothing, takes the panel down with `no_character`, and withdraws its body from the other players. |
| [`opx77:client:appearanceSaved`](#appearance-saved) | The core stored a face. |
| [`opx77:client:clothingSaved`](#clothing-saved) | The core stored a clothing record. |
| [`opx77:client:refused`](#refused) | The core would not. |

It also calls two of the core's client exports. On start, `GetPlayerData` once,
because a resource reload mid-session misses every emission above and there is no
replay. During the join-time bootstrap, `GetCharacters`, every 250 ms until a
roster is held or [`BOOTSTRAP.ROSTER_WAIT_MS`](config.md#bootstrap-roster-wait-ms)
runs out. It never calls `RequestCharacters`: the core cools roster requests at
2000 ms per player and drops the excess, so a request from here would land in
the same window as the roster screen's own. An answer without `ok = true` is
taken as no answer.

#### opx77:client:appearanceSaved {#appearance-saved}

The core's confirmation, carrying the canonical snapshot. What happens next
depends on what this client was waiting for:

- a **create** was outstanding — the editor's face is now stored, `created` is
  published, a toast goes up, and the readiness announcement may go out;
- an **edit** was outstanding — the puppet is recorded as wearing it, `saved` is
  published and a toast goes up;
- **nothing** was outstanding — the face was stored by something other than this
  client, so it is put on the puppet like any other restore.

#### opx77:client:clothingSaved {#clothing-saved}

The core's confirmation of a clothing save, carrying the canonical record.

- the record **this client sent** — `clothingSaved` is published with
  `ok = true`, and the count of failed saves starts again;
- **nothing** was outstanding — the record was stored by something other than
  this client; it becomes what the puppet should wear, and is put on again when
  the clothes were already on.

A record that arrives while a different one is still outstanding is kept as the
stored record and otherwise left alone.

#### opx77:client:refused {#refused}

The core's refusal, re-raised by the core's client half with three arguments.

```lua
AddEventHandler("opx77:client:refused", function(code, kind, operation) end)
```

- code: `string` — a code, a locale key for every face refusal.
- kind: `string` — `"error"` in every case the core currently sends.
- operation: `string` — which request it answers. This resource acts **only** on
  `"saveAppearance"`, while a captured face is outstanding, and on
  `"saveClothing"`, while a clothing save is outstanding.

The operation is what makes a refusal this resource's. The two names are
`OPX.Operations.SAVE_APPEARANCE` and `SAVE_CLOTHING` in the core's VM; a satellite
cannot import `OPX.Operations`, so this resource repeats the literals in
`client/editor.lua` and `client/clothing.lua`, and the two sides have to be read
together. An `error.tooFast` raised by a character selection or a vehicle spawn is
left alone rather than taken for the answer to a save still in flight.

**A face save.** Seven codes are recognised, and each is a locale key this
resource's catalogue carries, so every one is shown in the player's language:

| Code | Meaning |
|---|---|
| `appearance.invalid` | `opx77_core` could not read the snapshot. |
| `appearance.stale` | The face was captured for the character loaded before a switch. |
| `appearance.tooLarge` | The encoded JSON is over the core's limit. |
| `error.badRequest` | The payload was not a table. |
| `error.notLoggedIn` | No character is loaded on the core for this connection. |
| `error.unavailable` | The core's storage layer refused the write. |
| `error.tooFast` | Two saves inside the core's 2000 ms cooldown. |

An edit is rolled back and the player told; a creation ends on the default face.
A code outside that list is **still acted on** the same way, but it is logged
first, and the player is told `appearance.saveFailed` with the code as the
reason unless the catalogue happens to carry it:

```text
save refused with an unlisted code: <code>
```

**A clothing save.** Nothing is shown to the player for a single refusal:

| Code | What this resource does |
|---|---|
| `error.tooFast` | Sends the change again once it has held and the cooldown has passed. |
| `clothing.stale`, `error.notLoggedIn` | Nothing: the character the record was read for has gone. |
| `error.unavailable` | Counts a failed save; the second in a row stops saving for the character, publishes `clothingSaved` with `ok = false`, and tells the player once. |
| anything else — `clothing.invalid`, `clothing.tooLarge`, `error.badRequest` | Logs `clothing save refused: <code>` and publishes `clothingSaved` with `ok = false`; that look is not sent again. |

### From opx77_menu {#from-menu}

| Event | What this resource does with it |
|---|---|
| `opx77_appearance:panel` | The panel's own rows: **Wear it**, **Edit face** and **Hair only** on `select`, and `close` when `opx77_menu` took the list down by itself — a close it reports as `pause`, `back`, `item` or `select` is published as `player`, anything else as `menu_closed`. Only a payload for this resource's own `appearance` menu is read. A close with the reason `reopened` is ignored, and so is a close carrying another list's handle once the open panel's handle is known. |

### From the host {#from-host}

| Event | What this resource does with it |
|---|---|
| `open77:worldReady` | A new world entry: the per-entry flags reset, this world is judged eligible or not from the character-bootstrap phase, and the character's face is decided again. The pre-game menu world raises it too, with the phase still `"waiting"`, which is what begins the join-time bootstrap. The stored clothing is put on again once the face has settled. |
| `open77:appearance:confirmed` | The player confirmed a modal. Which one is decided by what is open, not by the event: the host raises the same name for the editor, the creation editor and a finalising restore mirror. |
| `open77:appearance:cancelled` | A modal was cancelled; the native mutation transaction is released. A cancelled creation editor ends the creation with `character_creation_cancelled`, on the default face. |
| `open77:appearance:restore_failed` | The mirror aborted a restore. A bootstrap restore that was never confirmed is re-dispatched up to [`RESTORE_RETRIES`](config.md#restore-retries) times; a puppet already wearing the right face is left alone. |
| `open77:playerReset:complete` | Ends a body reload, and is one of the two confirmations a queued restore waits on before the readiness announcement may go out. |
| `onClientResourceStart` | For this resource: checks the host's appearance, session and character APIs are present, re-establishes world eligibility (no `worldReady` follows a republish into a live world), begins the join-time bootstrap if the phase is still `"waiting"`, catches up on the character, and registers [the panel key](index.md#key). |
| `onClientResourceStop` | For this resource: releases the native mutation transaction. For `opx77_core`, with a character loaded: [unloads the character](index.md#unload), exactly as `opx77:client:onPlayerUnloaded` does, since a stopped core raises no unload. |

The presence halves listen to these as well:

| Event | Side | What this resource does with it |
|---|---|---|
| `open77:worldReady` | client | A new world: this client's proxies of everybody else went with the old one, so it publishes its own look again and asks for everybody's. |
| `onClientResourceStart` | client | Publishes and asks again, and says once when `open77_appearance` is running. |
| `onPlayerBucketChange` | server | Hands the player and everybody already in the new bucket each other's looks again. A move another one has superseded, or a player who has left, is ignored. |
| `onPlayerDisconnected` | server | Forgets the player's look. |
| `onResourceStart` | server | Asks every client to publish and ask again, on `resend`; or, with `PRESENT_BODIES = false`, says another resource must hand looks out. |

The withdrawal of a body on unload is part of the unload sequence above.

It also reads one thing no event carries: every 200 ms the worker asks
`Open77.appearance.takeBodyFamilyTransition()` what a body reload answered on the
other side of it, and follows `characterBootstrap().playerReset` back to
`complete` to end a reload whose `open77:playerReset:complete` never arrived.
`edit:<gender>` reopens a creation editor; `error:<reason>` tells the player
`appearance.bodyChangeFailed` and judges the world again on the body it has.

!!! warning "A missing host API is a logged line, not a crash"
    If `Open77.appearance`, `Open77.session` or `Open77.character` is absent at
    start, this resource logs one error and skips its start: the bootstrap is not
    spent and no character is caught up, and — since it is what sends
    [`open77:session:gameplayReady`](#gameplay-ready) — no player is let past the
    platform hold either.

    ```text
    native appearance API unavailable; no face will be stored or restored
    ```

## See also {#see-also}

- [Overview](index.md#storage) — the read and write channels in one table, and
  [what the character wears](index.md#clothing).
- [Configuration](config.md) — the event name, the deadlines, `BOOTSTRAP`,
  `CLOTHING` and the two retry counts named on this page.
- [`opx77_core` events](../opx77_core/events.md) — the wire events behind the
  core's local re-emissions.
