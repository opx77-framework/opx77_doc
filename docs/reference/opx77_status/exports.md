---
title: opx77_status exports
description: The four client exports opx77_status publishes — add, update, remove and clear — with every error code each can answer, and the caller-ownership and generation-sweep model that makes them safe to depend on.
---

# Exports

`opx77_status` publishes four client exports. Every one answers a table carrying
`ok`, plus an `error` code when `ok` is `false`. Every one acts on **your**
effects and only yours.

!!! info "Read the export contract first"
    There is no `exports.opx77_status:add()` proxy. The only entry point is
    `Open77.exports.call`, it is always asynchronous, and failure reads at three
    levels. See [The client export contract](../../concepts/export-contract.md).

| Export | Does |
|---|---|
| [`add`](#add) | show an effect, or replace one of yours with the same id |
| [`update`](#update) | change one of yours in place |
| [`remove`](#remove) | take one of yours down |
| [`clear`](#clear) | take all of yours down |

## add {#add}

Registers an effect under the calling resource and answers its id, or refuses
with a code — it never partially applies a spec.

!!! warning "Adding an id you already hold replaces it outright"
    Nothing of the old effect survives, **including its start time**, so a
    replaced effect moves back to the front of its priority group and any running
    countdown restarts. Use [`update`](#update) to change a field without moving
    the chip.

```lua
Open77.exports.call("opx77_status", "add", spec)
```

- spec: [`StatusSpec`](effect-spec.md#statusspec)
    - `id` and `label` are the only required fields.

**Returns** `table` — `{ ok = true, id = "<the id you passed>" }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus, so the owner or its generation could not be read from the host. |
| `spec_must_be_a_table` | `spec` is not a table. |
| `missing_id` | `spec.id` is `nil`. |
| `invalid_id` | `spec.id` is not 1–64 characters of letters, digits, `_`, `:`, `-` and `.`. |
| `invalid_label` | `spec.label` is missing, not a string or number, or empty after cleaning. |
| `invalid_event` | `spec.event` is present and is not a valid name of at most 96 characters. |
| `invalid_tone` | `spec.tone` is present and is not one of the [tones](effect-spec.md#tones). |
| `invalid_duration` | `spec.durationMs` is present and is not a finite number in `1 .. 3600000`. |
| `invalid_data` | `spec.data` is present and is not a table. |
| `data_too_large` | `spec.data` exceeds 64 nodes or 4 levels of nesting. |
| `invalid_progress` | `spec.progress` is present and is not a finite number. |
| `owner_limit` | You already hold 24 effects and this id is a new one. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It needs no permission, and the effect is owned by
whichever resource made the call.

### Example {#add-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_status", "add", {
    id = "bleeding",
    label = "Bleeding",
    icon = "//",
    tone = "bleed",
    priority = 80,
    durationMs = 30000,
    event = "myresource:status",
    data = { severity = 2 },
  })
  if not promise then return print("not dispatched: " .. tostring(reason)) end

  local result, callError = promise:await()
  if callError then return print("call failed: " .. tostring(callError)) end
  if not result.ok then return print("refused: " .. tostring(result.error)) end

  print("effect " .. result.id .. " is up")
end)
```

## update {#update}

Patches an effect you already hold, keeping every field the patch says nothing
about, or refuses with a code — it never partially applies a patch.

!!! warning "A patch can change a field, it cannot clear one"
    Absent means *keep*, so there is no patch that sets an optional field back to
    `nil`. Dropping an icon or a tone means calling [`add`](#add) again with the
    full spec you want — and that restarts the countdown and the ordering.

```lua
Open77.exports.call("opx77_status", "update", id, patch)
```

- id: `string`
    - The id you passed to [`add`](#add).
- patch: `table`
    - Any subset of the [`StatusSpec`](effect-spec.md#statusspec) fields. The
      patch is merged over the held effect and the **whole result** is then
      re-validated, so a bad patch field is refused with the same code `add`
      would have given.
    - Omitting `durationMs` carries both the deadline and the original start
      time over, so the countdown keeps running and the chip does not jump in
      the ordering. Passing a new `durationMs` **restarts** the countdown from
      now.

**Returns** `table` — `{ ok = true }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `invalid_id` | The `id` argument is not a valid name. Checked before the effect is looked up. |
| `not_found` | You hold no effect with that id. Checked before `patch` is examined. |
| `spec_must_be_a_table` | `patch` is not a table. |
| `invalid_label`, `invalid_event`, `invalid_tone`, `invalid_duration`, `invalid_data`, `data_too_large`, `invalid_progress` | The merged result fails the same rule `add` applies. Passing `false` for a label is `invalid_label`, not a silent no-op. |

`owner_limit` cannot occur: patching an effect you already hold is never a new
one.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It reaches only effects owned by the calling
resource.

### Example {#update-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise = Open77.exports.call("opx77_status", "update", "bleeding", {
    tone = "bad",
    progress = 0.4,
    -- no durationMs: the 30-second countdown keeps running
  })
  if not promise then return end
  local result = promise:await()
  if result and not result.ok then print("refused: " .. tostring(result.error)) end
end)
```

## remove {#remove}

Takes one of your effects down and raises the
[`removed` event](events.md#opx77-status) for it; removing what is not there is
an error code, never a raise.

```lua
Open77.exports.call("opx77_status", "remove", id)
```

- id: `string`
    - The id you passed to [`add`](#add).

**Returns** `table` — `{ ok = true }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `invalid_id` | The `id` argument is not a valid name. |
| `not_found` | You hold no effect with that id. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It reaches only effects owned by the calling
resource; there is no argument that would let you name another owner.

### Example {#remove-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise = Open77.exports.call("opx77_status", "remove", "bleeding")
  if promise then promise:await() end
end)
```

## clear {#clear}

Takes down every effect you hold and answers how many that was; holding none is
not an error.

!!! warning "`clear` raises nothing"
    [`remove`](#remove) raises `removed` for the effect it takes down. `clear`
    raises nothing for the effects it drops. If you rely on that event to unwind
    something, unwind it yourself around the `clear` call.

```lua
Open77.exports.call("opx77_status", "clear")
```

**Returns** `table` — `{ ok = true, removed = integer }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It never touches another resource's effects.

### Example {#clear-example}

```lua
-- a client script in your own resource, on your own teardown path
CreateThread(function()
  local promise = Open77.exports.call("opx77_status", "clear")
  if promise then promise:await() end
end)
```

You rarely need this on a stop: [the sweep](#ownership) does it for you.

## Ownership, generations and the sweep {#ownership}

This is the model that makes the four exports above a public API rather than an
internal detail, and it is worth reading in full before you depend on them.

### The owner is taken from the host, never from an argument {#invoking-resource}

Every export begins by asking the host two questions:

```lua
local owner = GetInvokingResource()
local generation = GetInvokingResourceGeneration()
```

Neither is a parameter, and there is no parameter that would let you name another
owner — an argument would let any caller impersonate any resource. If the host
cannot answer both (the call did not arrive through the export bus), every export
refuses with `export_call_required` and nothing is touched.

Ownership then decides the whole lifetime:

- [`remove`](#remove) and [`clear`](#clear) only ever reach your own effects.
- Ids are unique **per owner**, so two resources may both hold `bleeding`.
  Internally an effect is keyed `owner:id`, and that prefixed form is what
  reaches the page as a chip id.
- You may hold **24** effects at once.

!!! warning "`MAX_PER_OWNER` is 24, and it guards additions only"
    It is a guard rail against a caller that leaks — a loop that adds a chip per
    tick and forgets to remove it — not a number an operator would tune, which is
    why it lives in the code and not in `config.lua`. Replacing one of your own
    ids is not an addition and is always allowed, so a resource that reuses its
    ids never meets the ceiling. A resource that sees `owner_limit` has a bug.

### Your effects go when your resource does {#sweep}

You do not have to unwind the strip on your own teardown. Three mechanisms take
your effects down, and none of them needs a line of code from you:

| Trigger | How it is noticed |
|---|---|
| Your resource **stops** | `onClientResourceStop` fires with your name and your effects are dropped on the spot, and the sweep below catches it in any case within 250 ms. |
| Your resource **reloads** | The host hands over a generation alongside your name on every export call. A generation that differs from the one last seen means the code that added those effects no longer exists, and they are dropped before the new call is served. The sweep checks the same thing independently. |
| A deadline **elapses** | The sweep removes the effect and raises [`expired`](events.md#opx77-status). |

The sweep runs every **250 ms**. It looks for effects whose `expiresAtMs` has
passed, then walks every owner it has ever seen and drops the lot for any whose
`GetResourceState` is no longer `running` or whose generation has moved.

!!! warning "A stopped or reloaded owner is removed in silence"
    Expiry raises [`expired`](events.md#opx77-status) and [`remove`](#remove)
    raises `removed`. A stopped owner, a reloaded owner and [`clear`](#clear)
    raise **nothing** — there is nobody left to tell, or you already know. Do not
    build an unwind that depends on hearing about them.

### And when *this* resource stops {#self-stop}

Stopping `opx77_status` publishes one final, forced, empty payload on
[`opx77:status:effects`](events.md#status-effects) before it goes. The chips are
drawn in `opx77_hud`'s page and nothing over there knows this resource stopped, so
without that last publish its chips would stay on screen for the rest of the
session.

No owner event is raised for the effects that vanish with it. An owner's handler
is free to call straight back into an export, and this VM is halfway through
stopping.
