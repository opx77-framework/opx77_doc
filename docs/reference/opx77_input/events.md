---
title: opx77_input events
description: The one local event a form raises when it is answered or cancelled — on the caller's own name and on opx77:input — its payload, every cancel reason, and the platform event the form listens to.
---

# Events

A form answers **exactly once**. The answer is a local event on the client,
raised on the spec's `event` if it has one and on `opx77:input` beside it.
Nothing crosses the wire, and there is no callback: the client runtime puts every
export argument through a codec that refuses functions, so an answer can only
come back as an event you registered for yourself — the same mechanism
[`opx77_menu`](../opx77_menu/events.md#no-callback) uses.

## Non-networked {#non-networked}

### Your own event name {#your-event}

Fires once per form, when it is submitted or cancelled.

```lua
AddEventHandler("garage:plateAnswered", function(payload) end)
```

- payload: [`InputPayload`](types.md#inputpayload)
    - Always a table. Branch on `payload.action` first.

The keyboard has already been handed back when the handler runs, and the form is
already gone, so a handler may open another form, a menu or the chat at once.

!!! warning "Your event name is not private, and the payload is not trusted"

    The client's local bus is host-wide, so any resource on the player's machine
    can raise your event name with any payload. Check `type(payload) == "table"`,
    check `payload.action`, and check `payload.owner == GetCurrentResourceName()`
    if it matters.

### opx77:input {#opx77-input}

Fires for every answer on every form on this client, whoever opened it.

```lua
AddEventHandler("opx77:input", function(payload) end)
```

- payload: [`InputPayload`](types.md#inputpayload)
    - `payload.owner` names the resource that opened the form, and
      `payload.form` its id.

It is a name, not a setting. It is suppressed when it is already the spec's
`event`, so a form that declares `event = "opx77:input"` gets one payload, not
two.

## The payload {#payload}

| Field | Type | |
|---|---|---|
| `form` | `string` | The form's `id`. |
| `handle` | [`InputHandle`](types.md#inputhandle) | Unique for the life of the client session. |
| `owner` | `string` | The resource that opened the form. From the host, never from an argument. |
| `action` | [`InputAction`](types.md#inputaction) | `"submit"` or `"cancel"`. |
| `values` | `table<string, string \| number> \| nil` | On `submit` only: every field's answer, keyed by field `id`. |
| `reason` | `string \| nil` | On `cancel` only. See [Cancel reasons](#reasons). |
| `data` | `table \| nil` | The spec's `data`, echoed untouched on both actions. |

What each field kind answers in `values`:

| Kind | Answers |
|---|---|
| [text](form-spec.md#kind-text) | the typed string, control characters stripped; `""` when empty |
| [choice](form-spec.md#kind-choice) | the chosen option's `value`, exactly as the caller wrote it |
| [slider](form-spec.md#kind-slider) | a float, even where it renders whole |

A submit is only raised once every `required` and `pattern` rule has passed, so a
handler never sees an answer the form itself would refuse. Rules the form cannot
express — a minimum length, a date that must parse — are the handler's to check.

## Cancel reasons {#reasons}

| Reason | The form was cancelled because |
|---|---|
| `escape` | The player pressed Escape on the page. |
| `pause` | The platform raised `open77:pauseKey`. |
| `caller` | The owner called [`close`](exports.md#close). |
| `reopened` | The owner opened another form, replacing this one. |
| `owner_reloaded` | The owner called an export at a new generation: its code was reloaded under it. |
| `owner_stopped` | The once-a-second sweep found the owner stopped, or running at a different generation. |
| `input_stopped` | `opx77_input` itself is stopping. |

!!! info "A cancel is the only teardown signal you get"

    Five of those seven reasons are nothing the owner asked for. A resource
    that holds state while its form is up releases it from the `cancel` branch
    of its handler, not after the export call that opened the form.

## Events opx77_input listens for {#inbound}

### open77:pauseKey {#pausekey}

The plugin swallows Escape in the window procedure and raises this instead. The
open form is cancelled with `reason = "pause"`. The page reports the same key,
and both reach the one place a form is answered; the second finds nothing left to
answer. This is the backstop that keeps a broken page from stranding a player.

## See also {#see-also}

- [Exports](exports.md) — what opens and closes a form.
- [The form spec](form-spec.md) — what decides each field's kind.
- [Types](types.md#inputpayload) — the payload shape.
