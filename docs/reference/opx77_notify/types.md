---
title: opx77_notify types
description: The shapes opx77_notify reads and answers with — the definition schema and its three documented aliases, the entry list returns, the removal payload, and the response every export answers.
---

# Types

The annotations in `types.lua`, as the code actually uses them. Nothing there is
loaded at runtime: Lua tables carry no schema, and these are the shapes the
resource reads and answers with.

Field names are `UPPER_CASE` in the configuration — it is written by a human — and
`lowerCamelCase` everywhere the code produces a value.

## NotifyKind {#notifykind}

Which of the four a toast is. Each supplies a default accent.

```lua
---@alias NotifyKind "info"|"success"|"warning"|"error"
```

| Kind | Default accent |
|---|---|
| `info` | `#22D8E2` |
| `success` | `#4FE3A9` |
| `warning` | `#F5C95C` |
| `error` | `#FF5964` |

The value is lower-cased before it is checked, so `"Success"` is accepted.
Anything else is `invalid_type`. A `color` on the definition overrides the accent;
changing the kind of a toast that never pinned one re-derives it.

## NotifyPosition {#notifyposition}

Which stack a toast joins.

```lua
---@alias NotifyPosition
---| "top_left" | "top_center" | "top_right"
---| "middle_left"
---| "bottom_left" | "bottom_center" | "bottom_right"
```

!!! warning "The set is asymmetric, and that is the platform's doing"
    There is **no `middle_right`** and **no `middle_center`**. The published schema
    defines seven positions, not nine, and this resource does not invent the
    missing two: a caller that used them here would break the moment it ran against
    the official package.

The default is [`OPX_NOTIFY_CONFIG.POSITION`](config.md#position), which ships as
`top_right`. An unrecognised value is `invalid_position`.

## NotifyReason {#notifyreason}

Why a toast went away, as it reaches the [removal
event](events.md#opx77-notify-removed).

```lua
---@alias NotifyReason string
```

`expired`, `dismissed`, `queue_limit`, `owner_cleared`, `owner_disabled`,
`owner_reloaded`, `owner_stopped`, `server_dismissed`, `server_cleared`. Each is
described on [Events](events.md#opx77-notify-removed).

## NotifyDefinition {#notifydefinition}

The table handed to [`show`](exports.md#show), and the patch handed to
[`update`](exports.md#update). Only the body is required.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `id` | `string\|nil` | stable and owner-local, 1–96 characters of `[%w_:%-%.]`. Defaults to `notification_<handle>` |
| `replace` | `boolean\|nil` | replace an existing toast of yours with the same `id`. Without it a repeated id is `duplicate_notification_id` |
| `type` | `NotifyKind\|nil` | defaults to `info` |
| `kind` | `NotifyKind\|nil` | accepted as an alias for `type` |
| `title` | `string\|nil` | the heading, up to 96 UTF-8 bytes |
| `message` | `string\|nil` | the body. **Required**, up to 384 UTF-8 bytes |
| `text` | `string\|nil` | accepted as an alias for `message` |
| `icon` | `string\|nil` | a short textual badge, up to 16 UTF-8 bytes |
| `position` | `NotifyPosition\|nil` | defaults to [`OPX_NOTIFY_CONFIG.POSITION`](config.md#position) |
| `durationMs` | `integer\|nil` | `0` is persistent; a timed value is 750–120000 |
| `duration` | `integer\|nil` | accepted as an alias for `durationMs` |
| `progress` | `boolean\|nil` | draw the lifetime bar. Ignored when persistent |
| `color` | `string\|nil` | `#RRGGBB`, overriding the kind's accent |
| `data` | `table\|nil` | opaque, echoed in the removal event |

### The three aliases {#aliases}

`type`/`kind`, `message`/`text` and `durationMs`/`duration` are all in the
platform's published schema, and both spellings of each are read. **Where both are
present, the primary one wins** — `type` over `kind`, `message` over `text`,
`durationMs` over `duration`.

This matters most on a patch. A patch is merged over the toast it is patching, and
the stored toast is expressed in the primary spelling; so a patch that names an
alias has its alias collapsed onto the primary spelling **before** the merge. Were
it not, `update(handle, { text = "new" })` would leave both `message` (the old
one) and `text` (the new one) in the merged table and the old one would win — the
patch would be silently ignored.

### Copy is refused, not cleaned {#copy}

`title`, `message` and `icon` must be strings within their byte limits and must
carry **no control characters**. A control character is a refusal
(`invalid_title`, `invalid_message`, `invalid_icon`), not something the resource
strips: a caller that put a newline in a toast body meant something by it and
should hear that it did not work.

Nothing here can become markup in any case — the page inserts every string with
`textContent`.

### The `data` budget {#data}

`data` is yours: the resource stores it, never reads into it, and hands it back on
the removal event.

- A **non-table** `data` is ignored rather than refused. That is what the official
  package does, and diverging would break a caller that works against it.
- A **table** is counted: at most **64 nodes** and **4 levels** of nesting, keys
  included, or the call is refused with `data_too_large`. The bound exists because
  the table rides in a local event, and the host drops an oversized payload in
  silence.

## NotifyEntry {#notifyentry}

One live toast, as [`list`](exports.md#list) answers it and as it reaches the
page.

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `handle` | `integer` | client-local, monotonic, never reused within a session |
| `id` | `string` | the owner-local id |
| `type` | `NotifyKind` | |
| `title` | `string` | `""` when there is none |
| `message` | `string` | |
| `icon` | `string` | `""` when there is none |
| `position` | `NotifyPosition` | |
| `durationMs` | `integer` | |
| `progress` | `boolean` | already reduced: `false` whenever `durationMs` is `0` |
| `color` | `string` | the resolved `#RRGGBB`, never `nil` |

`owner` and `data` are deliberately absent. You know the first, the page has no
use for either, and the second is your own table — it comes back on removal
instead.

## NotifyRemoved {#notifyremoved}

The payload of [`opx77:notify:removed`](events.md#opx77-notify-removed).

**Fields**

| Field | Type | Meaning |
|---|---|---|
| `handle` | `integer` | the handle `show` answered |
| `id` | `string` | the owner-local id |
| `owner` | `string` | the resource that raised it, or `@server:<resource>` |
| `reason` | `NotifyReason` | |
| `data` | `table` | your opaque table, `{}` when there was none |

!!! info "`@server:` is a namespace no client resource can enter"
    A toast sent by a server resource is owned by `@server:<resource>`. `@` is
    outside `^[%w_:%-%.]+$`, the class an invoking resource name is validated
    against, so no value `GetInvokingResource` can ever answer collides with a
    server owner — and no export argument names an owner at all.

## NotifyResponse {#notifyresponse}

What every export answers. `ok` is always present; `error` only when `ok` is
`false`.

**Fields**

| Field | Type | Answered by |
|---|---|---|
| `ok` | `boolean` | all seven |
| `error` | `string\|nil` | any refusal. Every code is on [Exports](exports.md) |
| `handle` | `integer\|nil` | [`show`](exports.md#show), [`update`](exports.md#update) |
| `id` | `string\|nil` | [`show`](exports.md#show), [`update`](exports.md#update) |
| `replaced` | `boolean\|nil` | [`show`](exports.md#show), when it replaced one of yours |
| `removed` | `integer\|nil` | [`clear`](exports.md#clear) |
| `enabled` | `boolean\|nil` | [`setEnabled`](exports.md#setenabled), [`isEnabled`](exports.md#isenabled) |
| `notifications` | `NotifyEntry[]\|nil` | [`list`](exports.md#list) |
| `count` | `integer\|nil` | [`list`](exports.md#list) |

The value crosses a codec and lands in code that does not have this framework
loaded, so it is a plain table of plain values and nothing else: no functions, no
cycles, no userdata.
