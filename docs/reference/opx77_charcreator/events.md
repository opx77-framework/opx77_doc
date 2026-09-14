---
title: opx77_charcreator events
description: The opx77:charcreator channel every decision of the creation flow is published on — opened, created, cancelled and handedOver — and every event the resource listens to from opx77_charselector, opx77_input, opx77_core and opx77_appearance.
---

# Events

Every event here is **local, on the client**. This resource registers no net
event and sends none: the write is the core's `CreateCharacter` client export,
and the core answers it by event.

## Non-networked: what it raises {#raises}

### opx77:charcreator {#opx77-charcreator}

Raised after every decision this resource reaches, on
[`EVENT`](config.md#event) — `opx77:charcreator` as shipped.

```lua
AddEventHandler("opx77:charcreator", function(payload) end)
```

- payload: [`CreatorEvent`](types.md#creatorevent)

| `event` | Raised when | Carries |
|---|---|---|
| `opened` | the form went up for the first time this flow | `ok = true`, `slot` |
| `created` | `opx77_core` answered a registration | `ok = true` and `citizenId` for a character made; `ok = false` and `error` for a refusal |
| `cancelled` | the flow ended without a character | `ok = true`, `reason` |
| `handedOver` | `opx77_appearance` was asked to open the in-world face editor | `ok`, `citizenId`, and `error` when `openCreator` refused |

A refused `created` is not the end of the flow: the form reopens with the reason
under it, and the player may try again. `citizenId` on a successful `created` is
the character the new roster gained; it is absent where the roster made that
impossible to tell.

`cancelled` carries one of these reasons:

| `reason` | The flow ended because |
|---|---|
| `escape`, `pause` | the player cancelled the form |
| `input_stopped` | `opx77_input` stopped with the form up |
| `closed by <resource>` | a resource called [`close`](exports.md#close) |
| `no_origins` | the lifepaths could not be read from `opx77_core` |
| `form_unavailable` | `opx77_input` would not put the form up |
| `failed` | the flow raised while starting |

A flow that ends because a character loaded publishes nothing further.

!!! warning "`EVENT` must be a name of its own"

    An `EVENT` equal to [`SELECTOR_EVENT`](config.md#selector-event),
    [`APPEARANCE_EVENT`](config.md#appearance-event) or this resource's private
    answer name would make every publish re-enter the handler for that channel.
    Such a value, or one that is not a string, publishes nothing, and the boot
    says so:

    ```text
    EVENT must be a name of its own, unlike SELECTOR_EVENT and APPEARANCE_EVENT: nothing will be told what this resource decided
    ```

## Non-networked: what it listens to {#listens}

### createRequested {#create-requested}

On [`SELECTOR_EVENT`](config.md#selector-event), from `opx77_charselector` — see
[createRequested](../opx77_charselector/events.md#create-requested). It starts
the flow for `slot`, `used` and `slots`, unless a character is loaded or a flow
is already running.

### The form's answer {#answer}

`opx77_input` raises the answer on `opx77:charcreator:answered`, a private name
nothing else uses, so an answer arriving there is always this form's. A `submit`
is validated and sent; a `cancel` ends the flow, except `reopened`, which is this
resource replacing its own form.

### From opx77_core {#from-core}

| Event | Does |
|---|---|
| `opx77:client:charactersReady` | Remembers the account's citizen ids. While a registration is in flight, the roster **is** the answer: the flow ends, and `created` is published with the id the roster gained. |
| `opx77:client:onPlayerLoaded` | A character is in the world: any flow ends, and the roster is not asked for. |
| `opx77:client:onPlayerUnloaded` | There is something to create into again. |
| `opx77:client:refused` | Only one naming the `createCharacter` operation, and only while a registration is in flight: `created` is published with `ok = false` and the form reopens with the reason. |

A refusal is branched on its **operation**, never on the code: an
`error.tooFast` raised by a character selection is left alone rather than taken
for the answer to a registration still in flight. The catalogue renders
`character.limit`, `character.rowLimit`, `character.badName`,
`character.badOrigin`, `entry.noIdentity`, `error.unavailable`,
`error.badRequest`, `error.tooFast` and `error.notLoggedIn` in the player's
language; any other code is shown as *That was refused (\<code\>).*

!!! info "`error.unavailable` on every attempt was a core bug"

    Before `opx77_core`'s nullable-column fix, creating a character failed on
    every attempt with `error.unavailable`, because the host's database bridge
    drops a `nil` parameter and a new character has no position. The form
    reopened with *"That is unavailable right now."* each time. See
    [Troubleshooting](../../guides/troubleshooting.md#create-unavailable).

### needsCreation {#needs-creation}

On [`APPEARANCE_EVENT`](config.md#appearance-event), from `opx77_appearance`. A
loaded character has no face; unless
[`ANSWER_NEEDS_CREATION`](config.md#answer-needs-creation) is `false`, this
resource calls [`openCreator`](../opx77_appearance/exports.md#opencreator) and
publishes `handedOver`. See
[Who opens the face editor](index.md#face-editor).

## See also {#see-also}

- [Exports](exports.md) — starting and ending a flow from another resource.
- [Types](types.md#creatorevent) — the payload shape.
