---
title: opx77_appearance events
description: The two net events opx77_appearance sends — the face it hands to opx77_core and the readiness announcement that clears the platform hold — the local channel it publishes every decision on, and everything it listens to from the core, from opx77_menu and from the host.
---

# Events

This resource sends **two** net events and registers **none**: there is no
`RegisterNetEvent` anywhere in it, and no server half to answer one. Everything
it hears arrives on the client's local bus, either from
[`opx77_core`](../opx77_core/index.md)'s client half,
[`opx77_menu`](../opx77_menu/index.md) or the host.

- **Networked** — crosses the wire. Sending one needs `network.events`, which
  this resource declares for exactly the two calls below.
- **Non-networked** — never leaves the machine. Registered with a bare
  `AddEventHandler`.

!!! warning "The client's local bus is host-wide"

    Any resource on the player's machine can `TriggerEvent` any name, and a
    local `TriggerEvent` also reaches `RegisterNetEvent` handlers of the same
    name. Nothing this resource receives locally is a trust boundary, and
    nothing it publishes is proof to anybody. The one decision that has to be
    unforgeable — whether a face may be stored — is made by `opx77_core`'s
    server half from the connection. See
    [The client export contract](../../concepts/export-contract.md#local-bus).

## Networked (client → server) {#networked-client-to-server}

### opx77:server:saveAppearance {#save-appearance}

The face the player just confirmed, sent to `opx77_core` to be validated and
stored. It is the only write channel there is.

```lua
TriggerServerEvent("opx77:server:saveAppearance", { snapshot = snapshot })
```

- payload: `table`
    - `snapshot`: [`AppearanceSnapshot`](types.md#appearancesnapshot) — the four
      fields that *are* the face, plus the options array. The editor-only
      metadata the host's capture carries is stripped first, because the
      runtime's value codec will not carry it.

**What the core does with it.** It is registered in
`opx77_core/server/appearance.lua`. The character comes from the connection and
never from the payload, the payload must be a table, the request is cooled at
2000 ms under the key `appearance.request`, and the snapshot is then put into
canonical form — dense options, lower-cased names, every field the type the
column expects — before it is written to `opx77_characters.appearance` and
published back.

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

### open77:session:gameplayReady {#gameplay-ready}

The announcement that this player is genuinely in the world. It takes no
arguments, and it is the **only** thing that clears the platform's `__platform`
readiness hold.

```lua
TriggerServerEvent("open77:session:gameplayReady")
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
an honest settled state and must not strand the player behind the gate.

The conditions are re-tested every 200 ms by a worker thread, because the engine
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

There are none. This resource registers no net event at all. Everything the core
sends it arrives through the core's own client half, which re-raises each wire
event on the local bus — which is why every handler below is a bare
`AddEventHandler`.

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
| `panelOpened` | `true` | `opx77_menu` answered [`openPanel`](exports.md#openpanel) with a list on screen. |
| `panelClosed` | `true` | The panel went down; `reason` says why. |

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
[`FAMILY_RETRIES`](config.md#family-retries). Those raise a toast and a log line
only.

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
| `opx77:client:onPlayerLoaded` | Adopts the character: the citizen id, `charInfo.gender` as the body family, and `PlayerData.appearance` as the stored face. Then decides what this world entry's face is, putting the world on the character's own body first. |
| `opx77:client:playerDataChanged` | The same call. Money and jobs move through this name constantly, so it returns immediately unless the citizen id changed. |
| `opx77:client:onPlayerUnloaded` | Drops everything, and takes the panel down: a face belongs to a character. |
| [`opx77:client:appearanceSaved`](#appearance-saved) | The core stored a face. |
| [`opx77:client:refused`](#refused) | The core would not. |

It also calls two of the core's client exports. On start, `GetPlayerData` once,
because a resource reload mid-session misses every emission above and there is no
replay. During the join-time bootstrap, `GetCharacters`, every 250 ms until a
roster is held or [`BOOTSTRAP.ROSTER_WAIT_MS`](config.md#bootstrap-roster-wait-ms)
runs out. It never calls `RequestCharacters`: the core cools roster requests at
2000 ms per player and drops the excess, so a request from here would land in
the same window as the roster screen's own.

#### opx77:client:appearanceSaved {#appearance-saved}

The core's confirmation, carrying the canonical snapshot. What happens next
depends on what this client was waiting for:

- a **create** was outstanding — the editor's face is now stored, `created` is
  published, a toast goes up, and the readiness announcement may go out;
- an **edit** was outstanding — the puppet is recorded as wearing it, `saved` is
  published and a toast goes up;
- **nothing** was outstanding — the face was stored by something other than this
  client, so it is put on the puppet like any other restore.

#### opx77:client:refused {#refused}

The core's refusal, re-raised by the core's client half with three arguments.

```lua
AddEventHandler("opx77:client:refused", function(code, kind, operation) end)
```

- code: `string` — a locale key.
- kind: `string` — `"error"` in every case the core currently sends.
- operation: `string` — which request it answers. This resource acts **only**
  on `"saveAppearance"`, and only while a capture is outstanding.

The operation is what makes a refusal this resource's. It is
`OPX.Operations.SAVE_APPEARANCE` in the core's VM; a satellite cannot import
`OPX.Operations`, so this resource repeats the literal `"saveAppearance"` in
`client/editor.lua` and the two have to be read together. An `error.tooFast`
raised by a character selection or a vehicle spawn is left alone rather than
taken for the answer to a capture still in flight.

Six codes are recognised, and each is a locale key this resource's catalogue
carries, so every one is shown in the player's language:

| Code | Meaning |
|---|---|
| `appearance.invalid` | `opx77_core` could not read the snapshot. |
| `appearance.tooLarge` | The encoded JSON is over the core's limit. |
| `error.badRequest` | The payload was not a table. |
| `error.notLoggedIn` | No character is loaded on the core for this connection. |
| `error.unavailable` | The core's storage layer refused the write. |
| `error.tooFast` | Two saves inside the core's 2000 ms cooldown. |

A code outside that list is **still acted on** — an edit is rolled back and the
player told, a creation ends on the default face — but it is logged first:

```text
save refused with an unlisted code: <code>
```

### From opx77_menu {#from-menu}

| Event | What this resource does with it |
|---|---|
| `opx77_appearance:panel` | The panel's own rows: **Wear it**, **Edit face** and **Hair only** on `select`, and `close` when `opx77_menu` took the list down by itself — a close it reports as `pause`, `back`, `item` or `select` is published as `player`, anything else as `menu_closed`. Only a payload for this resource's own `appearance` menu is read. |

### From the host {#from-host}

| Event | What this resource does with it |
|---|---|
| `open77:worldReady` | A new world entry: the per-entry flags reset, this world is judged eligible or not from the character-bootstrap phase, the body reload that asked for it — if any — is taken as arrived, and the character's face is decided again. The pre-game menu world raises it too, with the phase still `"waiting"`, which is what begins the join-time bootstrap. |
| `open77:appearance:confirmed` | The player confirmed a modal. Which one is decided by what is open, not by the event: the host raises the same name for the editor, the creation editor and a finalising restore mirror. |
| `open77:appearance:cancelled` | A modal was cancelled; the native mutation transaction is released. A cancelled creation editor ends the creation with `character_creation_cancelled`, on the default face. |
| `open77:appearance:restore_failed` | The mirror aborted a restore. A bootstrap restore that was never confirmed is re-dispatched up to [`RESTORE_RETRIES`](config.md#restore-retries) times; a puppet already wearing the right face is left alone. |
| `open77:playerReset:complete` | One of the two confirmations a queued restore waits on before the readiness announcement may go out. A body reload that reached the world without a `worldReady` of its own is judged here instead, or nothing would ever go on the new puppet. |
| `onClientResourceStart` | Checks the host's appearance, session and character APIs are present, re-establishes world eligibility (no `worldReady` follows a republish into a live world), begins the join-time bootstrap if the phase is still `"waiting"`, catches up on the character, and starts the announcement worker. |
| `onClientResourceStop` | Releases the native mutation transaction. |

It also reads one thing no event carries: every 200 ms the worker asks
`Open77.appearance.takeBodyFamilyTransition()` what a body reload answered on the
other side of it. `edit:<gender>` reopens a creation editor; `error:<reason>`
tells the player `appearance.bodyChangeFailed` and judges the world again on the
body it has.

!!! warning "A missing host API is a logged line, not a crash"
    If `Open77.appearance`, `Open77.session` or `Open77.character` is absent at
    start, this resource logs one error and does nothing further: the bootstrap
    is not spent, no face is stored or restored, and — since it is what sends
    [`open77:session:gameplayReady`](#gameplay-ready) — no player is let past
    the platform hold either.

    ```text
    native appearance API unavailable; no face will be stored or restored
    ```

## See also {#see-also}

- [Overview](index.md#storage) — the read and write channels in one table.
- [Configuration](config.md) — the event name, the deadlines, `BOOTSTRAP` and
  the two retry counts named on this page.
- [`opx77_core` events](../opx77_core/events.md) — the wire events behind the
  core's local re-emissions.
