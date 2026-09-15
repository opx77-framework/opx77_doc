---
title: opx77_prompts types
description: The shapes opx77_prompts reads and answers with — the spec, the row, the key entry and its mapping form, the patch, the answer every export returns, and the envelope a server resource sends.
---

# Types

`opx77_prompts` ships its annotations in `std/types.lua`, a `---@meta` file that
is never loaded at runtime. The types below are the shapes the resource reads and
answers with, as the code actually checks them. The two shapes the page receives,
`PromptFrame` and `PromptConfig`, are described there too; they never cross the
export boundary and are not part of the contract.

## PromptAnchor {#promptanchor}

A corner of the surface, for [`ANCHOR`](config.md#anchor).

```lua
---@alias PromptAnchor "bottom-right"|"bottom-left"|"top-right"|"top-left"
```

Anything else falls back to `"bottom-right"`, with a warning.

## PromptSpec {#promptspec}

What [`show`](exports.md#show) takes: a group of rows that go up and come down
together.

| Field | Type | Meaning |
|---|---|---|
| `rows` | [`PromptRow`](#promptrow)`[]` | **Required**, 1 to 8, drawn top to bottom. |
| `title` | `string\|nil` | Up to 32 bytes, no control character, drawn above the rows as a `//` eyebrow. `false` or `""` means none. |
| `priority` | `integer\|nil` | −100..100, default 0. Higher sits nearer the anchored edge and is the last to lose rows to [`MAX_ROWS`](config.md#max-rows); between equal priorities the newest group wins. |

The spec is validated **whole or not at all**: one malformed row refuses the
group, and the code names the first thing wrong.

## PromptRow {#promptrow}

One row: its key caps, the words beside them, and an optional live reading.

| Field | Type | Meaning |
|---|---|---|
| `keys` | [`PromptKey`](#promptkey)`\|PromptKey[]` | **Required.** One key entry or a list of them, 1 to 6 caps in all. |
| `label` | `string` | **Required**, 1–48 bytes, no control character, already in the player's language: it is drawn as sent. |
| `value` | `string\|number\|nil` | Up to 24 bytes, drawn beside the label behind a hairline (`12 m/s`). A finite number is turned into text; `""` means none. |
| `id` | `string\|nil` | 1–32 characters of `[%w_:%-%.]`, unique in the group. What [`update`](exports.md#update)'s `values` addresses. |
| `hold` | `boolean\|nil` | The key is held rather than pressed: a heavier cap and the `HOLD` tag. |
| `combo` | `boolean\|nil` | The caps are pressed together: drawn with `+` between them (`CTRL + C`). |
| `dim` | `boolean\|nil` | Unavailable for now: drawn faint. |

A row with any key it cannot name — a mapping nobody registered, without a
`fallback` — is held but not drawn.

## PromptKey {#promptkey}

One `keys` entry: a literal key name, or a [mapping](#promptmapping).

```lua
---@alias PromptKey string|PromptMapping
```

A **literal** is split on spaces, so `"W A S D"` is four caps. Each name is 1–16
bytes with no control character. It is drawn through the
[key catalogue](config.md#locale) in the configured language, the arrows as
glyphs, anything else upper-cased as spelled.

A table that carries `mapping` is **one** entry, not a list: `keys = { mapping =
"stop" }` is one cap, and `keys = { { mapping = "up" }, { mapping = "down" } }`
is two.

## PromptMapping {#promptmapping}

A key named by the mapping it is bound to, drawn as the player's effective key:
their rebind if any, else the registered default.

| Field | Type | Meaning |
|---|---|---|
| `mapping` | `string` | **Required.** A mapping id of the caller's own resource, or `"resource\|id"` for another resource's. |
| `resource` | `string\|nil` | Accepted instead of the `"resource\|"` prefix. |
| `fallback` | `string\|nil` | One key name of 1–16 bytes, no space, drawn when nobody registered the mapping. Without one the row is left out. |

Both halves are names of up to 64 characters of `[%w_:%-%.]`, or the entry is
`invalid_mapping`. For a [server-sent group](events.md#owner), a bare id belongs
to the client half of the resource named `owner`.

The mapping is resolved **when the strip is drawn**, not when the group is shown,
so a rebind reaches the strip without a call from the caller.

## PromptPatch {#promptpatch}

What [`update`](exports.md#update) takes. Absent fields keep what the group has.

| Field | Type | Meaning |
|---|---|---|
| `rows` | [`PromptRow`](#promptrow)`[]\|nil` | Replaces every row. |
| `title` | `string\|false\|nil` | Replaces the title; `false` removes it. |
| `priority` | `integer\|nil` | Replaces the priority. |
| `values` | `table<string, string\|number\|false>\|nil` | Row `id` to new value; `false` clears one. Not in the same patch as `rows`. |

The patch is merged over the held group and the result is validated as a spec
would be, so a bad field answers the code [`show`](exports.md#show) would. The
group keeps its place among groups of the same priority.

## PromptResponse {#promptresponse}

What every export answers. `ok` is always present; `error` only when `ok` is
`false`.

| Field | Type | Answered by |
|---|---|---|
| `ok` | `boolean` | all five |
| `error` | `string\|nil` | any refusal. Every code is on [Exports](exports.md) |
| `id` | `string\|nil` | [`show`](exports.md#show), [`update`](exports.md#update) |
| `replaced` | `boolean\|nil` | [`show`](exports.md#show): whether it replaced a group of yours with the same id |
| `rows` | `integer\|nil` | [`show`](exports.md#show): how many rows the group holds |
| `removed` | `boolean\|integer\|nil` | [`hide`](exports.md#hide) (whether one was up) and [`hideAll`](exports.md#hideall) (how many) |
| `prompts` | `string[]\|nil` | [`list`](exports.md#list): the ids of your groups, sorted |
| `count` | `integer\|nil` | [`list`](exports.md#list) |
| `visible` | `boolean\|nil` | [`list`](exports.md#list): whether any of your groups is in the frame last drawn |

## PromptEnvelope {#promptenvelope}

The table a server resource sends with `TriggerClientEvent`. See
[Events](events.md#networked).

| Field | Type | Meaning |
|---|---|---|
| `owner` | `string` | The sending resource's name, 1–56 characters of `[%w_:%-%.]`. Stored as `@server:<owner>`. |
| `id` | `string` | The group id. |
| `spec` | [`PromptSpec`](#promptspec)`\|nil` | `opx77_prompts:show` |
| `patch` | [`PromptPatch`](#promptpatch)`\|nil` | `opx77_prompts:update` |

`opx77_prompts:hideAll` takes the owner name alone, a bare string, instead of a
table.
