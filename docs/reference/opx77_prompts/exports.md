---
title: opx77_prompts exports
description: The five client exports opx77_prompts publishes — show, update, hide, hideAll and list — with the arguments each takes, the answer each returns, every refusal code, and the ownership and owner-sweep model behind them.
---

# Exports

`opx77_prompts` publishes five client exports. Every one answers a table carrying
`ok`, plus an `error` code when `ok` is `false`, and never raises. Every one acts
on **your** groups and only yours.

!!! info "Read the export contract first"
    There is no `exports.opx77_prompts:show()` proxy. The only entry point is
    `Open77.exports.call`, it is always asynchronous, and failure reads at three
    levels. An answer without `ok = true` is a refusal. See
    [The client export contract](../../concepts/export-contract.md).

| Export | Answers | Does |
|---|---|---|
| [`show`](#show) | `ok`, `id`, `replaced`, `rows` | put a group of rows up, or replace yours with that id where it stands |
| [`update`](#update) | `ok`, `id` | change one of yours in place |
| [`hide`](#hide) | `ok`, `removed` | take one of yours down |
| [`hideAll`](#hideall) | `ok`, `removed` | take every one of yours down |
| [`list`](#list) | `ok`, `prompts`, `count`, `visible` | the ids of yours that are held, and whether any of them is on screen |

Every answer is a [`PromptResponse`](types.md#promptresponse).

The examples below share this helper, which collapses the three failure levels
into one `nil, reason`:

```lua
local function prompts(name, ...)
  if GetResourceState("opx77_prompts") ~= "running" then return nil, "not_running" end
  local promise, reason = Open77.exports.call("opx77_prompts", name, ...)
  if not promise then return nil, reason end
  local answer, callError = promise:await()
  if callError then return nil, callError end
  if type(answer) ~= "table" or answer.ok ~= true then
    return nil, type(answer) == "table" and answer.error or "refused"
  end
  return answer
end
```

## show {#show}

Puts a group of rows up under the calling resource, or replaces the one you
already hold under that id, or refuses the spec whole with a code — nothing is
ever partially applied.

```lua
Open77.exports.call("opx77_prompts", "show", id, spec)
```

- id: `string`
    - 1–64 characters of letters, digits, `_`, `:`, `-` and `.`. Yours: another
      resource's group of the same name is a different group.
- spec: [`PromptSpec`](types.md#promptspec)
    - `rows` is the only required field: 1 to 8 [rows](types.md#promptrow).

**Returns** `table` — `{ ok = true, id = string, replaced = boolean, rows = integer }`.
`replaced` is `true` when it replaced a group of yours with the same id; `rows`
is how many rows the group holds, drawn or not.

Showing an id you already hold **replaces it in place**: the group keeps its
place among groups of the same priority, so a context redrawn does not jump the
queue. The two group ceilings apply only to a new id. Once the page is ready,
the frame is sent before the call answers, unless nothing on screen changed.

**Errors**, in the order they are checked:

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus, so there is no invoking resource or generation. A call from inside this resource answers it too. |
| `no_surface` | `WebUI.create` failed at start; there is no page for this generation. A page that has not reported ready yet is **not** this: the group is held and drawn when it does. |
| `invalid_prompt_id` | `id` is not 1–64 characters of `[%w_:%-%.]`. |
| `spec_must_be_a_table` | `spec` is not a table. |
| `invalid_title` | `title` is not a string, is over 32 bytes, or carries a control character. `false` and `""` mean no title. |
| `invalid_priority` | `priority` is not an integer in −100..100. |
| `rows_required` | `rows` is missing, not a table, or empty. |
| `too_many_rows` | More than 8 rows. |
| `invalid_row` | A row is not a table. |
| `invalid_row_id` | A row `id` is not 1–32 characters of `[%w_:%-%.]`. |
| `duplicate_row_id` | Two rows of the group carry the same `id`. |
| `invalid_label` | A `label` is missing, empty, not a string, over 48 bytes, or carries a control character. |
| `invalid_value` | A `value` is neither a string nor a finite number, or is over 24 bytes, or carries a control character. |
| `invalid_hold` / `invalid_combo` / `invalid_dim` | The field is present and not a boolean. |
| `keys_required` | A row has no `keys`, or an empty list of them. |
| `too_many_keys` | More than 6 caps in one row, counting every name a literal splits into. |
| `invalid_key` | A literal is empty, has a name over 16 bytes or a control character, or an entry is neither a string nor a table with a string `mapping`. |
| `invalid_mapping` | The resource or the mapping id of a mapping is not a valid name (1–64 characters of `[%w_:%-%.]`). |
| `invalid_fallback` | A `fallback` is not a single key name of 1–16 bytes with no space or control character. |
| `owner_limit` | The id is new and you already hold 8 groups. |
| `prompt_limit` | The id is new and 32 groups are held across every owner. |

Rows are checked in order, and each row's fields in the order of that table, so
the code names the first thing wrong.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It needs no permission, and the group is owned by
whichever resource made the call.

### Example {#show-example}

```lua
-- a client script in your own resource
CreateThread(function()
  local answer, reason = prompts("show", "noclip", {
    title = "NOCLIP",
    priority = 10,
    rows = {
      { keys = "W A S D", label = "Move" },
      { keys = { "SPACE", "CTRL" }, label = "Up / down" },
      { id = "speed", keys = { { mapping = "speedUp" }, { mapping = "speedDown" } },
        label = "Speed", value = "40 m/s" },
      { keys = "SHIFT", label = "Fast", hold = true },
    },
  })
  if not answer then return print("no prompts: " .. tostring(reason)) end
end)
```

Another resource's key, with a fallback drawn when nobody registered that
mapping:

```lua
prompts("show", "hud", {
  rows = { { keys = { mapping = "opx77_hud|opx77_hud.toggle", fallback = "F8" },
             label = "Show the HUD" } },
})
```

## update {#update}

Patches one of your groups in place, keeping everything the patch says nothing
about, or refuses with a code — the merged group is validated whole, and nothing
is applied when it fails.

```lua
Open77.exports.call("opx77_prompts", "update", id, patch)
```

- id: `string`
    - The id you showed the group under.
- patch: [`PromptPatch`](types.md#promptpatch)
    - `rows` replaces every row; `title` replaces the title and `false` removes
      it; `priority` replaces the priority; `values` sets the value of rows by
      their row `id`, and `false` clears one. `values` cannot come with `rows`.

**Returns** `table` — `{ ok = true, id = string }`

The group keeps its place among groups of the same priority. A patch that
changes nothing on screen sends nothing to the page, so a caller can push the
same reading every frame without cost to the surface — though not without the
cost of the export call.

**Errors**, in the order they are checked:

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `no_surface` | `WebUI.create` failed at start. |
| `prompt_not_found` | You hold no group under that id — including an id that is not a string or not a valid id at all. |
| `patch_must_be_a_table` | `patch` is not a table. |
| `invalid_values` | `values` is present and not a table. |
| `rows_and_values` | `values` came with `rows` in the same patch. |
| `row_not_found` | `values` names a row id the group does not have. |
| `invalid_title`, `invalid_priority`, `rows_required`, `too_many_rows`, and every row code [`show`](#show) lists | The merged group fails the same rule `show` applies — a `value` set through `values` included. |

`owner_limit` and `prompt_limit` cannot occur: patching a group you hold is never
a new one.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It reaches only groups owned by the calling
resource.

### Example {#update-example}

```lua
-- the speed read-out of the noclip group above, changed in place
CreateThread(function()
  prompts("update", "noclip", { values = { speed = "60 m/s" } })
end)
```

## hide {#hide}

Takes one of your groups down. Hiding an id you do not hold is not an error.

```lua
Open77.exports.call("opx77_prompts", "hide", id)
```

- id: `string`

**Returns** `table` — `{ ok = true, removed = boolean }`, `removed` saying
whether a group was up under that id.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |
| `invalid_prompt_id` | `id` is not 1–64 characters of `[%w_:%-%.]`. |

There is no `no_surface` here, nor on [`hideAll`](#hideall) or [`list`](#list):
taking something down and reading your own state both work whether or not there
is a page to draw on.

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. There is no argument that would let you name
another owner.

## hideAll {#hideall}

Takes every group you hold down and answers how many that was; holding none is
not an error.

```lua
Open77.exports.call("opx77_prompts", "hideAll")
```

**Returns** `table` — `{ ok = true, removed = integer }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`. It never touches another resource's groups.

You rarely need this on a stop: [the sweep](#sweep) does it for you.

## list {#list}

The ids of your groups that are held, and whether any of them is on screen right
now. Only ever yours.

```lua
Open77.exports.call("opx77_prompts", "list")
```

**Returns** `table` — `{ ok = true, prompts = string[], count = integer, visible = boolean }`

- `prompts` is the ids of your groups, sorted; `count` is how many.
- `visible` is read from **what was drawn**, not from what is held: it is `true`
  only when at least one of your groups is in the frame the page last received.
  It is `false` while the strip has [stepped aside](index.md#steps-aside), while
  the page has not reported ready, after a send to the page failed, and for a
  group that is held but not drawn — every row cut by
  [`MAX_ROWS`](config.md#max-rows), or no row with a key that resolves. A group
  drawn in part counts as visible.

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | The call did not arrive through the export bus. |

**Side** `client export` — callable from any client resource, asynchronously,
through `Open77.exports.call`.

No resource in the set calls `update`, `hideAll` or `list` today; they are there
for yours.

## Ownership, reloads and the sweep {#ownership}

### The owner is taken from the host, never from an argument {#invoking-resource}

Every export begins by reading `GetInvokingResource()` and
`GetInvokingResourceGeneration()`. Neither is a parameter, and no parameter
anywhere on this surface names an owner, so a resource cannot claim to be
another. If the host cannot answer both, every export refuses with
`export_call_required` and nothing is touched.

Groups are stored by owner and id: two resources can both hold `main`, and
`update`, `hide`, `hideAll` and `list` only ever reach your own. A group a server
resource sent is owned by `@server:<resource>`; `@` is outside the characters a
client owner is validated against, so no client resource can reach it — see
[Events](events.md#owner).

### The ceilings {#ceilings}

| Ceiling | Value | What happens at it |
|---|---|---|
| Rows in one group | 8 | `show` refuses with `too_many_rows`. |
| Caps in one row | 6 | `show` refuses with `too_many_keys`. |
| Groups one owner holds | 8 | `show` of a new id refuses with `owner_limit`. |
| Groups held across every owner | 32 | `show` of a new id refuses with `prompt_limit`. |
| Rows drawn at once | [`MAX_ROWS`](config.md#max-rows), 10 as shipped | The lowest priority is cut; nothing is refused. |

A resource that sees `owner_limit` is putting groups up and not taking them
down.

### Your groups go when your resource does {#sweep}

You do not have to take your groups down on your own teardown. Three mechanisms
do it, and none needs a line of code from you:

| Trigger | How it is noticed |
|---|---|
| Your resource **stops** | `onClientResourceStop` fires with your name, and your groups are dropped on the spot. |
| Your resource **reloads** | Every export call carries your generation. A generation that differs from the one last seen means the code that put those groups up no longer exists, and they are dropped before the new call is served. |
| Either, missed | While any group is held, the strip re-checks every owner it knows once a second. An owner whose `GetResourceState` is neither `running` nor `starting`, or whose `Open77.resource.generation` has changed, loses its groups. |

**`starting` counts as alive.** A resource that puts a group up from its own start
handler still reads `starting` at that point, and would otherwise lose its keys
on the next sweep, a second later.

Server-sent groups are never swept: a client cannot see a server resource stop.
See [Events](events.md#server-lifetime).

### And when *this* resource stops {#self-stop}

Every group is dropped and the page is forgotten; the surface goes with the
resource generation. A caller that wants its keys back when the strip restarts
listens for `onClientResourceStart` with `opx77_prompts` and shows them again,
which is what every caller in the set does — see
[Who uses it](index.md#callers).
