# opx77_status

| | |
|---|---|
| **Version** | `0.2.0` |
| **Reload policy** | `reconnect` |
| **Permissions** | none |
| **Side** | client only |

## What it is

A shared status-effect strip. Any resource adds a chip — bleeding,
over-encumbered, a wanted level, a buff on a timer — and `opx77_status` owns the
registry, the ordering and the countdown.

Without it every resource that wanted to say something on screen would draw its
own box, and they would overlap. One registry means one place decides what an
urgent chip outranks, one place decides how many fit, and one place ticks the
timers down.

The manifest declares `permissions {}`, and the empty table is the honest
answer: the resource draws nothing of its own and speaks to no server, so there
is no surface to register and no network reach to grant.

!!! note "Hunger and thirst are not here"

    They used to be. They moved to [`opx77_core`](opx77_core.md), because they
    are **character metadata**, and a server resource cannot read another
    resource's players. A gauge that has to survive a reconnect and follow a
    character belongs to the resource that owns characters, not to the strip
    that happens to be able to draw a bar.

## It owns no surface

This is the non-obvious part of the resource, and the thing to know before
reading anything else on this page.

`opx77_status` holds the effects and publishes what should be drawn on the
client event `opx77:status:effects`. **[`opx77_hud`](opx77_hud.md) draws them.**

```lua
--- What opx77_hud listens on to draw the strip. A client-side event, because the client
--- runtime has a cross-resource bus and this is exactly what it is for.
local EFFECTS_EVENT = "opx77:status:effects"
```

The reasoning is the same one that put the effects in one registry in the first
place. The chips live in one corner of the screen, and the hud already places,
themes and animates a surface in that corner. Two surfaces for one corner was
two things to place, two things to theme, and two things to keep in step
whenever either moved.

The published payload carries the placement alongside the chips, so the hud
never has to read this resource's config:

```lua
{
  anchor = "bottom-left",  -- OPX_STATUS_CONFIG.ANCHOR
  offset = 120,            -- OPX_STATUS_CONFIG.OFFSET
  chips  = { --[[ up to MAX_VISIBLE chips, already ordered ]] },
  hidden = 0,              -- how many were left out of the cut
}
```

Each chip in `chips` is `{ id, label, icon, tone, progress, remainingMs,
totalMs }`, where `id` is the effect's id prefixed with its owner
(`"opx77_medical:bleeding"`) so two resources can both call an effect
`bleeding`.

The event is republished only when the drawing actually changes. `remainingMs`
is deliberately left out of the change signature — a countdown ticking down is
not a new picture, and the hud animates it on its own clock.

See [the client export contract](../index.md#the-client-export-contract) for why every shared service in OPX//77
is a client service.

## Exports

Every export is **client-side** and answers a table carrying `ok`, plus an
`error` code when `ok` is `false`.

| Export | Signature | Does |
|---|---|---|
| [`add`](#add) | `add(spec)` | Show an effect, or replace one of yours with the same id |
| [`update`](#update) | `update(id, patch)` | Change one of yours in place |
| [`remove`](#remove) | `remove(id)` | Take one of yours down |
| [`clear`](#clear) | `clear()` | Take all of yours down |

!!! warning "There is no `exports.opx77_status:add()` proxy"

    The only entry point is `Open77.exports.call(resource, export, ...)`, it is
    always asynchronous, and failure reads at **two** levels. See
    [the client export contract](../index.md#the-client-export-contract).

!!! note "`no_surface`"

    Every export can refuse with `no_surface`, the code for *there is nothing
    to publish to*. It is part of the contract because it once could happen and
    may again; in the shipped build nothing reports itself unavailable, so a
    correct call never sees it. Handle it the way you handle any other code —
    do not branch on it.

### `add`

Registers an effect under the calling resource. Calling `add` again with an id
you already hold **replaces** it outright — nothing of the old effect survives,
including its start time, so a replaced effect moves back to the front of its
priority group.

**Parameters**

| Parameter | Type | Notes |
|---|---|---|
| `spec` | `table` | The [effect spec](#the-effect-spec) |

**Returns** `{ ok = true, id = "<the effect id>" }`

**Errors**

| Code | When |
|---|---|
| `export_call_required` | The call did not arrive through the export bus — the owner or its generation could not be read from the runtime |
| `spec_must_be_a_table` | `spec` is not a table |
| `missing_id` | `spec.id` is `nil` |
| `invalid_id` | `spec.id` is not a valid name |
| `invalid_label` | `spec.label` is missing, unusable, or empty after cleaning |
| `invalid_event` | `spec.event` is present and is not a valid name |
| `invalid_tone` | `spec.tone` is present and is not one of the [tones](#tones) |
| `invalid_duration` | `spec.durationMs` is present and is not a finite number in `1 .. 3600000` |
| `invalid_data` | `spec.data` is present and is not a table |
| `data_too_large` | `spec.data` exceeds 64 nodes or 4 levels of nesting |
| `invalid_progress` | `spec.progress` is present and is not a finite number |
| `owner_limit` | You already hold `MAX_PER_OWNER` effects and this id is a new one |
| `no_surface` | There is nothing to publish to |

### `update`

Patches an effect you already hold. Fields absent from the patch keep the value
they have.

**Parameters**

| Parameter | Type | Notes |
|---|---|---|
| `id` | `string` | The id you passed to `add` |
| `patch` | `table` | Any subset of the [effect spec](#the-effect-spec) fields |

**Returns** `{ ok = true }`

**Errors**

| Code | When |
|---|---|
| `export_call_required` | As above |
| `invalid_id` | The `id` argument is not a valid name |
| `not_found` | You hold no effect with that id |
| `spec_must_be_a_table` | `patch` is not a table |
| `invalid_label`, `invalid_event`, `invalid_tone`, `invalid_duration`, `invalid_data`, `data_too_large`, `invalid_progress` | The merged result fails the same rules `add` applies |
| `no_surface` | There is nothing to publish to |

!!! tip "A patch without `durationMs` keeps the deadline"

    Omit `durationMs` and both the deadline and the start time are carried
    over, so the countdown keeps running and the chip does not jump in the
    ordering. Pass a new `durationMs` and the countdown **restarts** from now.

!!! note "A patch can change a field, not clear one"

    Absent means *keep*, so there is no patch that sets an optional field back
    to `nil`. Dropping an icon or a tone means calling `add` again with the
    full spec you want. Note also that a patch is merged and then re-validated
    as a whole, so a bad patch field is refused with the same code `add` would
    have given — passing `false` for a label is `invalid_label`, not a silent
    no-op.

### `remove`

Takes down one of your effects and raises the [`removed`
event](#events-raised-back-to-the-owner) for it. Removing what is not there is
an error code, never a raise.

**Parameters**

| Parameter | Type | Notes |
|---|---|---|
| `id` | `string` | The id you passed to `add` |

**Returns** `{ ok = true }`

**Errors**

| Code | When |
|---|---|
| `export_call_required` | As above |
| `invalid_id` | The `id` argument is not a valid name |
| `not_found` | You hold no effect with that id |
| `no_surface` | There is nothing to publish to |

### `clear`

Takes down every effect you hold. It never touches another resource's, and it
is not an error to hold none.

**Returns** `{ ok = true, removed = <integer> }`

**Errors**

| Code | When |
|---|---|
| `export_call_required` | As above |
| `no_surface` | There is nothing to publish to |

!!! warning "`clear` raises nothing"

    `remove` raises `removed` for the effect it takes down. `clear` does not
    raise for the effects it drops. If you rely on the event to unwind
    something, unwind it yourself around the `clear` call.

### A full call

Both levels of failure, checked:

```lua
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
  if not promise then
    return print(("status dispatch failed: %s"):format(reason))  -- dispatch failure
  end

  local result, callError = promise:await()                       -- resolution failure
  if callError then
    return print(("status call failed: %s"):format(callError))
  end
  if not result.ok then
    return print(("status refused: %s"):format(result.error))
  end

  print(("effect %s is up"):format(result.id))
end)
```

## The effect spec

`id` and `label` are the only required fields. Everything else is optional, and
an optional field that is `nil` is simply absent — it is never a refusal.

| Field | Type | Required | Rule |
|---|---|---|---|
| `id` | `string` | yes | Unique **per owner**. 1–64 characters, and only letters, digits, `_`, `:`, `-` and `.` |
| `label` | `string` | yes | Cleaned rather than refused: control characters become spaces and the result is cut to 32 characters. A number is accepted and stringified. Anything else, or an empty result, is `invalid_label` |
| `icon` | `string` | no | Cleaned the same way and cut to 2 characters. An unusable value is dropped to `nil`, never refused |
| `tone` | `string` | no | One of the [tones](#tones), or `invalid_tone` |
| `progress` | `number` | no | A finite number, **clamped** into `0 .. 1`. Out of range is not an error; non-finite or non-numeric is `invalid_progress` |
| `priority` | `number` | no | Higher sorts first and survives the `MAX_VISIBLE` cut. Anything non-finite falls back to `0` — there is no error code for it. Defaults to `0` |
| `durationMs` | `integer` | no | A finite number in `1 .. 3600000` (one hour). Outside that, or non-numeric, is `invalid_duration`. Absent means the effect stays until somebody takes it down |
| `event` | `string` | no | An event name raised for this effect in addition to the global one. Same character rules as `id`, up to 96 characters, or `invalid_event` |
| `data` | `table` | no | Opaque, echoed back in every event payload. Must be a table (`invalid_data`), at most **64 nodes** and **4 levels** deep (`data_too_large`) |

!!! note "Why `data` is bounded"

    `data` rides in every event raised for the effect, and the host silently
    drops a payload past 1024 nodes. A budget that refuses at 64 nodes turns a
    payload that would have vanished without a word into an error code you can
    read. Keys count towards the budget as well as values, so a flat table of
    thirty pairs is already sixty nodes.

!!! note "Lengths are counted in bytes"

    `label`, `icon`, `id` and `event` are measured with `#value`. Two glyphs of
    `icon` means two bytes.

## Tones

A tone is a presentation role, or one of 2077's damage types. The complete list:

| Tone | |
|---|---|
| `ok` | presentation roles |
| `warn` | |
| `bad` | |
| `accent` | |
| `bleed` | damage types |
| `burn` | |
| `shock` | |
| `chem` | |

Anything else is `invalid_tone`. Omitting `tone` is allowed, and leaves the
chip to whatever the hud draws by default.

## Ordering

The strip is sorted once, across every owner, on three keys in order:

1. **Highest `priority` first**, so the urgent chip is never pushed off the
   strip by the trivial one.
2. Then **most recently started**, so the newest thing to happen sits nearest
   the top of its priority group.
3. Then a stable tie-break on `owner` and `id`.

```lua
table.sort(all, function(a, b)
  if a.priority ~= b.priority then return a.priority > b.priority end
  if a.startedAtMs ~= b.startedAtMs then return a.startedAtMs > b.startedAtMs end
  -- a total order: equal keys would leave the strip reshuffling on `pairs` order
  return a.owner .. "\1" .. a.id < b.owner .. "\1" .. b.id
end)
```

The third key exists because the first two are not a total order. Two effects
added in the same tick, at the same priority, compare equal on both — and the
registry is walked with `pairs`, whose order is not guaranteed between passes.
Without a final tie-break the strip would reshuffle those chips on nothing more
than table iteration order, which reads on screen as chips swapping places by
themselves.

## Countdowns

`durationMs` is a *duration on arrival* and an *absolute deadline* thereafter:

```lua
-- absolute, not remaining: the page counts down from this on its own clock
expiresAtMs = duration and (atMs + math.floor(duration)) or nil,
```

The published chip carries `remainingMs` and `totalMs`, and the hud animates
between them itself. Nothing has to be sent per frame, or per second, for a
timer to appear to tick — a running countdown costs no traffic at all, and the
event is only republished when something that is not the countdown changes.

The registry sweeps for deadlines that have passed four times a second. An
effect that expires is removed and raises the [`expired`
event](#events-raised-back-to-the-owner).

## Ownership and lifetime

An effect belongs to the resource that added it. Ownership is taken from
`GetInvokingResource()` and never from an argument, because an argument would
let any caller impersonate another resource.

That ownership decides the whole lifetime:

- `remove` and `clear` only ever reach your own effects.
- Ids are unique **per owner**, so two resources may both hold `bleeding`.
- When a resource stops, everything it held goes with it. The sweep checks
  `GetResourceState(owner)` and drops the lot.
- When a resource *reloads*, the same happens. The runtime hands over a
  generation alongside the caller's name; a generation that differs from the
  one last seen means the code that added those effects no longer exists, and
  its effects are dropped rather than left orphaned on screen.

Neither of those two removals raises an event. There is nothing left to tell.

!!! warning "`MAX_PER_OWNER` is 24"

    One resource may hold 24 effects at once. It is a guard rail against a
    caller that leaks — a loop that adds a chip per tick and forgets to remove
    it — and not a number an operator would tune, which is why it lives in the
    code and not in `config.lua`.

    The limit only guards *additions*. Replacing one of your own ids is not a
    new effect and is always allowed, so a resource that reuses its ids never
    meets the ceiling. A resource that hits `owner_limit` has a bug.

## Events raised back to the owner

An export answers the call that made it and nothing more — **no export can
answer a callback**. So when an effect goes away for a reason the owner did not
ask for, the only way to say so is an event.

Two events carry the same payload:

| Event | |
|---|---|
| `opx77:status` | The global one. Raised for every effect, so one listener can watch them all |
| `spec.event` | Raised for this effect only, if you gave one. If it is the same name as the global one, it fires once, not twice |

The payload:

```lua
{
  status = "bleeding",           -- the effect id, unprefixed
  owner  = "myresource",         -- the resource that added it
  action = "expired",            -- "removed" or "expired"
  label  = "Bleeding",
  tone   = "bleed",
  data   = { severity = 2 },     -- your opaque table, echoed back
}
```

| Action | Raised when |
|---|---|
| `removed` | The owner called `remove` for it |
| `expired` | Its `durationMs` elapsed and the sweep took it down |

Nothing else raises. `add`, `update`, `clear`, a stopped owner and a reloaded
owner are all silent.

```lua
AddEventHandler("opx77:status", function(payload)
  if payload.owner ~= GetCurrentResourceName() then return end
  if payload.action == "expired" and payload.status == "bleeding" then
    -- the timer ran out on its own; stop the bleed
  end
end)
```

!!! tip "Filter on `owner` when you listen to the global event"

    `opx77:status` fires for every effect on the strip, including other
    resources'. The payload carries `owner` precisely so you can tell yours
    apart. A per-effect `event` name avoids the question entirely.

## Configuration

`config.lua`, in `OPX_STATUS_CONFIG`. Three keys, all about placement.

```lua
OPX_STATUS_CONFIG = {
  ANCHOR = "bottom-left", -- "bottom-left" | "bottom-right" | "top-left" | "top-right"
  OFFSET = 120, -- pixels the effect strip sits above the corner, clear of the gauges
  MAX_VISIBLE = 6, -- chips drawn at once, the rest are counted in a "+3" chip
}
```

| Key | Default | Meaning |
|---|---|---|
| `ANCHOR` | `"bottom-left"` | Which corner the strip sits in. One of `"bottom-left"`, `"bottom-right"`, `"top-left"`, `"top-right"` |
| `OFFSET` | `120` | Pixels the strip sits above that corner, to clear the hud's gauges |
| `MAX_VISIBLE` | `6` | How many chips are drawn at once |

`ANCHOR` and `OFFSET` are passed straight through to
[`opx77_hud`](opx77_hud.md) in the published payload — this resource reads them
only to hand them on.

`MAX_VISIBLE` is the one key that changes behaviour rather than position. The
strip is ordered first, then cut: the first `MAX_VISIBLE` effects become chips,
and everything past the cut is counted, not drawn. The count travels as
`hidden` in the payload and the hud collapses it into a single counter chip
(`+3`). Because the cut happens after the sort, raising `MAX_VISIBLE` never
changes which chip is first, and lowering it only ever takes from the bottom —
the lowest priority, oldest effects.
