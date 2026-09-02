---
title: opx77_notify exports
description: The seven client exports opx77_notify publishes — show, update, dismiss, clear, list, setEnabled and isEnabled — with every error code each can answer, and the caller-ownership and generation-sweep model that makes them safe to depend on.
---

# Exports

`opx77_notify` publishes seven client exports. Every one answers a table carrying
`ok`, plus an `error` code when `ok` is `false`. Every one acts on **your**
toasts and only yours.

!!! info "Read the export contract first"
    There is no `exports.opx77_notify:show()` proxy. The only entry point is
    `Open77.exports.call`, it is always asynchronous, and failure reads at three
    levels. See [The client export contract](../../concepts/export-contract.md).

| Export | Does |
|---|---|
| [`show`](#show) | raise a toast, and answer the handle the rest of this page takes |
| [`update`](#update) | change one of yours in place |
| [`dismiss`](#dismiss) | take one of yours down now |
| [`clear`](#clear) | take all of yours down |
| [`list`](#list) | your live toasts, oldest handle first |
| [`setEnabled`](#setenabled) | turn your own toasts off, or back on |
| [`isEnabled`](#isenabled) | whether yours are on |

These are the names the platform documents on its own `open77_notifications`
package, with the same arguments and the same definition schema, so code written
against the documented notification surface works here without a change. What is
**not** identical is the shape of the answer: the official package returns a bare
boolean from `isEnabled` and a bare array from `list`, and this one returns a
table carrying `ok` from all seven. See
[the client side of the drop-in](index.md#client-side).

## show {#show}

Raises a toast under the calling resource and answers its handle, or refuses with
a code — it never partially applies a definition.

```lua
Open77.exports.call("opx77_notify", "show", definition)
```

- definition: [`NotifyDefinition`](types.md#notifydefinition)
    - `message` (or its alias `text`) is the only required field.

**Returns** `table` — `{ ok = true, handle = integer, id = string }`, plus
`replaced = true` when it replaced one of yours.

!!! warning "A repeated id without `replace` is refused, not silently ignored"
    Calling `show` twice with the same `id` answers `duplicate_notification_id`
    the second time. Pass `replace = true` to mean it. A replace is a **new
    toast**: the countdown restarts, because the caller asked for this content to
    be shown now. [`update`](#update) is the call that changes a field without
    restarting anything.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus, so the owner or its generation could not be read from the host. |
| `no_surface` | `WebUI.create` failed at start. There is no page and there will not be one for this generation. A page that merely has not loaded yet is **not** this — see [holding and replay](#replay). |
| `owner_disabled` | You called [`setEnabled(false)`](#setenabled) and have not called it back on. |
| `definition_must_be_a_table` | `definition` is not a table. |
| `invalid_type` | `type`/`kind` is present and is not `info`, `success`, `warning` or `error`. |
| `invalid_notification_id` | `id` is not 1–96 characters of letters, digits, `_`, `:`, `-` and `.`. |
| `invalid_title` | `title` is not a string, is over 96 UTF-8 bytes, or carries a control character. |
| `invalid_message` | `message`/`text` is missing, empty, not a string, over 384 UTF-8 bytes, or carries a control character. |
| `invalid_icon` | `icon` is present and is not a string of at most 16 UTF-8 bytes without control characters. |
| `invalid_position` | `position` is not one of [the platform's seven](types.md#notifyposition). |
| `invalid_duration` | `durationMs`/`duration` is not an integer, is negative, is over 120000, or is between 1 and 749. |
| `invalid_progress` | `progress` is present and is not a boolean. |
| `invalid_color` | `color` is present and is not `#RRGGBB`. |
| `data_too_large` | `data` is a table of more than 64 nodes or more than 4 levels deep. |
| `duplicate_notification_id` | You already hold that `id` and did not pass `replace = true`. |
| `notification_limit` | 32 toasts are already held, across every owner. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It needs no permission, and the toast is owned by
whichever resource made the call.

### Example {#show-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_notify", "show", {
    id = "job_started",
    type = "success",
    title = "Mission accepted",
    message = "Meet the fixer at the Kabuki garage.",
    icon = "JOB",
    durationMs = 5000,
    data = { mission = "garage_intro" },
  })
  if not promise then return print("not dispatched: " .. tostring(reason)) end

  local result, callError = promise:await()
  if callError then return print("call failed: " .. tostring(callError)) end
  if not result.ok then return print("refused: " .. tostring(result.error)) end

  print("toast " .. tostring(result.handle) .. " is up")
end)
```

## update {#update}

Patches a toast you already hold, keeping every field the patch says nothing
about, or refuses with a code — it never partially applies a patch.

```lua
Open77.exports.call("opx77_notify", "update", handle, patch)
```

- handle: `integer`
    - The handle [`show`](#show) answered. A string that converts to a number is
      accepted.
- patch: [`NotifyDefinition`](types.md#notifydefinition)
    - Any subset of the definition's fields. The patch is merged over the held
      toast and the **whole result** is then re-validated, so a bad patch field is
      refused with the same code `show` would have given.
    - `id` is ignored: a toast's id is its identity, and moving it would leave the
      owner's index pointing at a live handle under the wrong name.

**Returns** `table` — `{ ok = true, handle = integer, id = string }`

!!! info "A patch that says nothing about the duration keeps the deadline"
    Omitting `durationMs` **and** `duration` carries the existing deadline over,
    so a changed message does not restart the bar underneath it. Passing either
    restarts the countdown from now.

!!! warning "A patch can change a field, it cannot clear one"
    Absent means *keep*. There is no patch that sets an optional field back to
    `nil`; the closest is a value that means empty, such as `title = ""`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_surface` | `WebUI.create` failed at start. |
| `notification_not_found` | No live toast has that handle — including a handle that is not a number at all. |
| `not_owner` | That handle belongs to another resource. Checked before the patch is examined. |
| `patch_must_be_a_table` | `patch` is not a table. |
| `invalid_type`, `invalid_notification_id`, `invalid_title`, `invalid_message`, `invalid_icon`, `invalid_position`, `invalid_duration`, `invalid_progress`, `invalid_color`, `data_too_large` | The merged result fails the same rule [`show`](#show) applies. |

`duplicate_notification_id` and `notification_limit` cannot occur: patching a
toast you already hold is never a new one.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It reaches only toasts owned by the calling
resource.

### Example {#update-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise = Open77.exports.call("opx77_notify", "update", handle, {
    type = "success",
    message = "Synchronisation complete.",
    durationMs = 3500,
  })
  if not promise then return end
  local result = promise:await()
  if result and not result.ok then print("refused: " .. tostring(result.error)) end
end)
```

!!! info "Changing the kind re-derives the accent"
    A toast that never pinned a `color` takes its kind's accent, and changing the
    kind changes the colour with it. A toast that **did** pin one keeps the colour
    it was given until a patch names a different one.

    This is a deliberate divergence from the official package, where the resolved
    colour is carried back into every merge — so its own documented example,
    `update(handle, { type = "success" })`, leaves the toast the colour it already
    was. Here it turns green.

## dismiss {#dismiss}

Takes one of your toasts down now and raises the
[removal event](events.md#opx77-notify-removed) for it with reason `dismissed`;
dismissing what is not there is an error code, never a raise.

```lua
Open77.exports.call("opx77_notify", "dismiss", handle)
```

- handle: `integer`

**Returns** `table` — `{ ok = true }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `notification_not_found` | No live toast has that handle. |
| `not_owner` | That handle belongs to another resource. |

There is no `no_surface` here, nor on [`clear`](#clear),
[`setEnabled`](#setenabled), [`list`](#list) or [`isEnabled`](#isenabled): taking
something down and reading your own state both work whether or not there is a page
to draw on.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. There is no argument that would let you name
another owner.

## clear {#clear}

Takes down every toast you hold and answers how many that was; holding none is not
an error.

```lua
Open77.exports.call("opx77_notify", "clear")
```

**Returns** `table` — `{ ok = true, removed = integer }`

Each toast it takes down raises the
[removal event](events.md#opx77-notify-removed) with reason `owner_cleared`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It never touches another resource's toasts.

You rarely need this on a stop: [the sweep](#ownership) does it for you.

## list {#list}

Your live toasts, oldest handle first. Only ever yours — a resource cannot
inspect, update or dismiss another owner's entries.

```lua
Open77.exports.call("opx77_notify", "list")
```

**Returns** `table` — `{ ok = true, notifications = NotifyEntry[], count = integer }`

Each row is a [`NotifyEntry`](types.md#notifyentry). `owner` and `data` are
deliberately absent from a row: you know the first, and the second is your own
table, echoed back to you on removal instead.

!!! warning "The official package answers a bare array here"
    `open77_notifications`'s `list` returns the array itself, with no wrapper. This
    one returns `{ ok = true, notifications = ... }`, because every export in this
    framework answers the same shape. A caller ported from the official package
    reads `result.notifications` rather than `result`.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## setEnabled {#setenabled}

Turns your own toasts off, or back on. Disabling clears everything you hold and
suppresses what you send until you enable again.

```lua
Open77.exports.call("opx77_notify", "setEnabled", enabled)
```

- enabled: `any`
    - Anything but `false` enables.

**Returns** `table` — `{ ok = true, enabled = boolean }`, the state it now holds.

Toasts dropped by disabling raise the
[removal event](events.md#opx77-notify-removed) with reason `owner_disabled`.
While disabled, [`show`](#show) refuses with `owner_disabled`.

!!! info "Per caller, and that is the official package's rule"
    This is the opposite of [`opx77_chat`'s `setEnabled`](../opx77_chat/exports.md),
    which is one flag for the whole box. A chat is a single surface a cutscene
    turns off; a toast stack belongs to many resources at once, and no one of them
    gets to silence the others.

A resource's flag is forgotten when it reloads or stops, so a resource that
disabled itself starts enabled again.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## isEnabled {#isenabled}

Whether your own toasts are on. A resource that has never called
[`setEnabled`](#setenabled) is enabled.

```lua
Open77.exports.call("opx77_notify", "isEnabled")
```

**Returns** `table` — `{ ok = true, enabled = boolean }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

## Ownership, generations and the sweep {#ownership}

This is the model that makes the seven exports above a public API rather than an
internal detail, and it is worth reading in full before you depend on them.

### The owner is taken from the host, never from an argument {#invoking-resource}

Every export begins by asking the host two questions:

```lua
local owner = GetInvokingResource()
local generation = GetInvokingResourceGeneration()
```

Neither is a parameter, and there is no parameter anywhere on this surface that
would let you name another owner — an argument would let any caller impersonate
any resource. If the host cannot answer both (the call did not arrive through the
export bus), every export refuses with `export_call_required` and nothing is
touched.

Ownership then decides the whole lifetime:

- [`update`](#update) and [`dismiss`](#dismiss) refuse another owner's handle with
  `not_owner`; [`clear`](#clear) and [`list`](#list) only ever see your own.
- Ids are unique **per owner**, so two resources may both hold `download`.
- A toast sent by a server resource is owned by `@server:<resource>`. `@` is
  outside the character class an invoking resource name is validated against, so
  **no client resource can ever hold or address a server-owned handle**.

### The two ceilings {#ceilings}

| Ceiling | Value | What happens at it |
|---|---|---|
| Toasts held at once, across every owner | 32 | [`show`](#show) refuses with `notification_limit`. |
| Toasts in one position | 8 | The **oldest in that position** is removed with reason `queue_limit`, and the new one joins. |

Both are the platform's documented numbers, not this resource's choices. Raising
them would make this resource behave differently from the package it stands in
for, so they live in the code rather than in `config.lua`. A resource that sees
`notification_limit` has a leak.

### Holding and replay {#replay}

A toast raised before the page has reported ready is **held and replayed** the
moment it does, which is what the official package does too. `no_surface` is a
different failure and means something permanent: `WebUI.create` itself failed, so
there is no page for this resource generation and there will not be one.

### Your toasts go when your resource does {#sweep}

You do not have to unwind the stack on your own teardown. Four mechanisms take
your toasts down, and none of them needs a line of code from you:

| Trigger | How it is noticed | Reason reported |
|---|---|---|
| Your resource **stops** | `onClientResourceStop` fires with your name and your toasts are dropped on the spot. The sweep catches it in any case within a second. | `owner_stopped` |
| Your resource **reloads** | The host hands over a generation alongside your name on every export call. A generation that differs from the one last seen means the code that raised those toasts no longer exists, and they are dropped before the new call is served. The sweep checks the same thing independently. | `owner_reloaded` |
| A **deadline** elapses | The tick, every 100 ms. | `expired` |
| A position **overflows** | A ninth toast joins it. | `queue_limit` |

### And when *this* resource stops {#self-stop}

Everything held is dropped **in silence** — no removal event is raised for it. An
owner's handler is free to call straight back into an export, and this VM is
halfway through stopping when that path would run.

The surface goes with the resource generation. The platform's own
`WebUI.Page.destroy` reference states it plainly — "Resource teardown performs the
same cleanup automatically" — so this resource destroys nothing by hand. There is
no focus to hand back either: this page never takes any.
