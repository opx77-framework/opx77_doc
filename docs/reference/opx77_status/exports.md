---
title: opx77_status exports
description: The seven client exports opx77_status publishes — add, update, remove and clear for the effect strip, needs, setNeeds and addNeeds for the character's gameplay needs — with every error code each can answer, and the caller-ownership and generation-sweep model that makes them safe to depend on.
---

# Exports

`opx77_status` publishes seven client exports. Every one answers a table carrying
`ok`, plus an `error` code when `ok` is `false`, and none of them ever raises.

They fall into two groups. The four **effect** exports act on **your** effects and
only yours. The three **needs** exports act on the one thing this resource owns
for the whole character, so there is nothing per-caller about them: any resource
may read the needs, and any resource may move them.

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
| [`needs`](#needs) | read the character's needs as this client holds them |
| [`setNeeds`](#setneeds) | set one or more needs outright |
| [`addNeeds`](#addneeds) | move one or more needs by a delta |

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

## needs {#needs}

Answers the character's needs as **this client** holds them, with the citizen id
they belong to. It reads a value the client already has; nothing is fetched from
the server and nothing is written.

!!! info "Read this once, then listen"
    Every later change is announced on
    [`opx77:status:needs`](events.md#status-needs). This export exists for the
    resource that starts mid-session and has already missed the load — which is
    exactly how `opx77_hud` uses it: one call at boot, then the event. Polling it
    on a timer is the wrong shape.

```lua
Open77.exports.call("opx77_status", "needs")
```

**Returns** `table` — `{ ok = true, values = <NeedValues>, citizenId = "H7K-M4X3", ready = true }`

`values` is a **copy**, so holding on to it is safe and mutating it changes
nothing. It carries one entry per key of
[`OPX_STATUS_CONFIG.NEEDS`](config.md#needs) and nothing else.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_character` | `opx77_core` has no character loaded on this client, so there is nothing to read. |
| `not_loaded` | A character is loaded but the server half has not answered for it yet. The refusal still carries `citizenId`, so you can tell "not yet" from "nobody". |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. There is no server export: the values are held on
the client during play.

### Example {#needs-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_status", "needs")
  if not promise then return print("not dispatched: " .. tostring(reason)) end

  local result, callError = promise:await()
  if callError then return print("call failed: " .. tostring(callError)) end
  if not result.ok then return print("refused: " .. tostring(result.error)) end

  print(("thirst is %.1f"):format(result.values.thirst))
end)

-- and from here on, do not call it again
AddEventHandler("opx77:status:needs", function(payload)
  if not payload.ready then return end
  -- payload.values is the same shape
end)
```

## setNeeds {#setneeds}

Sets one or more needs to an absolute value, and answers which of them actually
moved. Out-of-range values are **clamped**, not refused.

```lua
Open77.exports.call("opx77_status", "setNeeds", patch)
```

- patch: `table<NeedKey, number>`
    - Any non-empty subset of the keys of
      [`OPX_STATUS_CONFIG.NEEDS`](config.md#needs), each mapped to a finite
      number. A key that is not one of them refuses the **whole** call.

**Returns** `table` — `{ ok = true, values = <NeedValues>, changed = { "hunger", "thirst" } }`

`values` is the full set after the write. `changed` lists only the keys whose
value is different from what it was, sorted, so a patch that sets a need to the
value it already had answers `ok` with an empty `changed` — and publishes and
pushes nothing.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `not_loaded` | No character is loaded, or the server half has not answered for it yet. Checked before `patch` is examined. |
| `spec_must_be_a_table` | `patch` is not a table. |
| `unknown_need` | A key of `patch` is not a key of `OPX_STATUS_CONFIG.NEEDS`. |
| `invalid_need_value` | A value of `patch` is not a finite number, after `tonumber`. |
| `empty_patch` | `patch` named no need at all. |

!!! warning "A refused patch applies nothing"
    Every key is checked before any is written, so a two-key patch with one bad
    key moves neither. There is no partial write.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. The write lands in the client's own copy, is
announced on [`opx77:status:needs`](events.md#status-needs) with
`source = "set"`, and is pushed to the server half — at once if it moved a need
by [`PUSH_DELTA`](config.md#push-delta), otherwise on the
[`PUSH_MS`](config.md#push-ms) throttle.

### Example {#setneeds-example}

```lua
-- a client script in your own resource: a full night's sleep
CreateThread(function()
  local promise = Open77.exports.call("opx77_status", "setNeeds", { stamina = 100 })
  if not promise then return end
  local result = promise:await()
  if result and not result.ok then print("refused: " .. tostring(result.error)) end
end)
```

## addNeeds {#addneeds}

Moves one or more needs by a delta — a meal, a shot of stamina, a street cred
payout — and answers which of them actually moved. The result is clamped into the
need's bounds, so overfeeding a character is not an error.

```lua
Open77.exports.call("opx77_status", "addNeeds", patch)
```

- patch: `table<NeedKey, number>`
    - The same shape as [`setNeeds`](#setneeds), except that each number is added
      to the held value rather than replacing it. Negative is how you take
      something away.

**Returns** `table` — `{ ok = true, values = <NeedValues>, changed = { "hunger" } }`

**Errors** — identical to [`setNeeds`](#setneeds), code for code.

!!! warning "A delta at the ceiling is not `changed`"
    Adding `20` to a `hunger` already at `100` clamps to `100`, which is the value
    it had, so the key is absent from `changed` and nothing is published or
    pushed. Read `changed`, not `ok`, if you need to know whether the meal did
    anything.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It publishes with `source = "add"` and pushes on
the same rules as [`setNeeds`](#setneeds).

### Example {#addneeds-example}

```lua
-- a client script in your own resource: eating a synth-noodle bowl
CreateThread(function()
  local promise = Open77.exports.call("opx77_status", "addNeeds", {
    hunger = 25,
    thirst = 5,
  })
  if not promise then return end
  local result = promise:await()
  if not result or not result.ok then return end
  if #result.changed == 0 then
    -- already full: refund the bowl rather than eating it for nothing
  end
end)
```

## Ownership, generations and the sweep {#ownership}

This is the model that makes the four **effect** exports above a public API
rather than an internal detail, and it is worth reading in full before you depend
on them. The three needs exports sit outside it — they act on the character, not
on anything owned per caller — but they ask the host the same two questions, so
`export_call_required` and the generation note below apply to all seven.

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

For the three needs exports that is where it ends: the answer decides only
whether the call is served at all, and the generation is noted. For the four
effect exports, ownership then decides the whole lifetime:

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

Two things happen on the way out, in this order.

**The needs are pushed, forced.** A reload is the one stop this client survives,
so the held values go back to the server half first, ignoring both the
[`PUSH_MS`](config.md#push-ms) throttle and the
[`PUSH_DELTA`](config.md#push-delta) floor. Without it the drift since the last
push would be lost across a `refresh`/`restart`.

**One final, forced, empty payload** is published on
[`opx77:status:effects`](events.md#status-effects). The chips are drawn in
`opx77_hud`'s page and nothing over there knows this resource stopped, so without
that last publish its chips would stay on screen for the rest of the session.

Nothing is published on [`opx77:status:needs`](events.md#status-needs). There is
no farewell for the needs at all, so a consumer has to notice the stop itself:
`opx77_hud` watches `onClientResourceStop` for this resource's name and blanks
the gauges it drew, rather than leaving them frozen at their last value.

No owner event is raised for the effects that vanish with it either. An owner's
handler is free to call straight back into an export, and this VM is halfway
through stopping.
