---
title: crafting module
description: A shared crafting service: other modules register benches with recipes, players hand over materials and collect the output when the timer ends.
---

# crafting

The crafting module runs workbenches for other modules. It has no recipes of its own: a module such as [gunsmith](gunsmith.md) registers a bench with its recipes. At a bench the player sees a menu of what can be made, what each recipe needs and what is already cooking. Ordering takes the materials (and an optional fee) at once; the item is ready after the recipe's time, even across a server restart, and the player comes back to collect it. Use it when your module needs "spend items, wait, receive an item".

| | |
|---|---|
| Side | both |
| Requires | `inventory`, `character` (hard) |
| Optional | `menu` (the bench screen), `progress` (the handover bar) |
| Configuration | `config/crafting.lua` (shared script) |
| Contract | `crafting` v1 — server, client |
| Data | `opx77_crafting_orders` |

## How a bench works {#benches}

- Each character has its own queue per bench, up to the bench's `queue` orders.
- The queue is sequential: a new order starts when the previous one is ready.
- Ordering checks the gate, reach, queue space, materials and money, then removes the materials, then takes the fee. If a later step fails, earlier ones are given back.
- Ready times are kept by the database clock (`ready_at`), so an order keeps cooking while the server is down.
- Collecting checks the bag can carry the output first. The order is deleted, then the item is given; if the item cannot be given, the order is put back on the shelf.
- A bench with a `position` is checked for reach on the server. A bench without one can be used from anywhere.
- Order and collect are audited (`crafting.order`, `crafting.collect`).

## Bench definition {#bench-definition}

The table passed to [`RegisterBench`](#server-crafting-registerbench). Lower-case keys.

| Field | Required | What it does |
|---|---|---|
| `owner` | yes | Name of the registering module. Used by `UnregisterBenches`. |
| `label` | no | Menu title. Defaults to the bench key. Max 64 bytes. |
| `position` | no | `{ x, y, z, bucket? }`. Turns on the server reach check. |
| `reach` | no | Metres, above 0 and at most [`MAX_REACH`](#config-crafting-max-reach). Defaults to [`REACH`](#config-crafting-reach). |
| `queue` | no | 1 to [`MAX_QUEUE`](#config-crafting-max-queue). Defaults to [`QUEUE`](#config-crafting-queue). |
| `canUse` | no | `function(player, recipeKey) → allowed, code?`. Called with `recipeKey = nil` for the bench itself, then once per recipe. Return a code to show `crafting.<code>`. A raise refuses with `not_for_you`. |
| `recipes` | yes | List of recipes, at most [`MAX_RECIPES`](#config-crafting-max-recipes). |

Bench and recipe keys: letters, digits, `_`, `-`, `.`, `:`, up to 64.

### Recipe fields

Upper-case keys, as in a config file.

| Field | Required | What it does |
|---|---|---|
| `KEY` | yes | Recipe key, unique on the bench. |
| `OUTPUT` | yes | Item name given. Must be in the inventory catalogue. |
| `COUNT` | no | Units given, 1 to [`MAX_YIELD`](#config-crafting-max-yield). Default `1`. |
| `SECONDS` | yes | Cooking time, [`MIN_SECONDS`](#config-crafting-min-seconds) to [`MAX_SECONDS`](#config-crafting-max-seconds). |
| `INPUTS` | yes | `{ item = units }`, 1 to [`MAX_INPUTS`](#config-crafting-max-inputs) items, each in the catalogue. |
| `PRICE` | no | Fee in whole units. Default `0`. |
| `MONEY` | if `PRICE > 0` | Money type the fee is taken from. |
| `LABEL` | no | Menu label. Defaults to the output's label. |
| `ICON` | no | A name from `OPX.Glyphs`. |

A recipe that breaks a rule is dropped with a boot warning. A bench left with no recipe is refused.

## Server contract {#server-contract}

`local crafting = OPX.Api.Get('crafting')` on the server, from code inside opx_infinity. A Result is `{ ok = true, value }` or `{ ok = false, error, detail }`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-crafting-registerbench"></a>`RegisterBench` | `benchKey, definition` | Result recipe count | Does not yield. Errors `invalid_bench` (detail: first problem), `bench_taken`. Call it from your module's `Start`, after `crafting` has published. |
| <a id="server-crafting-unregisterbenches"></a>`UnregisterBenches` | `owner` | Result number removed | Removes every bench with that `owner`. Orders already filed stay in the database. |
| <a id="server-crafting-benches"></a>`Benches` | — | Result list of `{ key, owner, label, recipes, queue, anchored }` | Sorted by key. |
| <a id="server-crafting-view"></a>`View` | `player, benchKey` | Result view | Yields. What the menu draws. See below. |
| <a id="server-crafting-order"></a>`Order` | `player, benchKey, recipeKey` | Result `{ id, seconds }` | Yields. `seconds` is the time until this order is ready, queue included. |
| <a id="server-crafting-collect"></a>`Collect` | `player, orderId` | Result `{ bench, item, count }` | Yields. |

The view is `{ bench, label, queue, cooking, free, recipes, orders }`:

- `recipes[i]`: `{ key, label, icon, output, outputLabel, count, seconds, price, money, inputs = { { item, label, need, held } }, ok, error, short }`. `ok` says whether it can be ordered now; `error` is the refusal code.
- `orders[i]`: `{ id, recipe, label, output, count, remaining, ready }`, soonest first.

## Client contract {#client-contract}

`local crafting = OPX.Api.Get('crafting')` on the client, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-crafting-open"></a>`Open` | `benchKey` | Result `true` | Asks the server for the bench and opens the menu. Errors `invalid_bench`, `no_screen` (no `menu`). The server checks everything again. |
| <a id="client-crafting-close"></a>`Close` | — | Result `true` | Closes the menu. |
| <a id="client-crafting-state"></a>`State` | — | Result `{ open, bench }` | |

While open, the menu asks the server for a fresh view every [`REFRESH_MS`](#config-crafting-refresh-ms).

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-crafting-open"></a>`opx:net:crafting:open` | client → server | `benchKey` | Send me this bench's view. Rate limited. |
| <a id="opx-net-crafting-order"></a>`opx:net:crafting:order` | client → server | `benchKey, recipeKey` | Place an order. Rate limited. |
| <a id="opx-net-crafting-collect"></a>`opx:net:crafting:collect` | client → server | `benchKey, orderId` | Collect a ready order. Rate limited. |
| <a id="opx-net-crafting-view"></a>`opx:net:crafting:view` | server → client | view | The bench view, after every open, order or collect. |
| <a id="opx-net-crafting-refused"></a>`opx:net:crafting:refused` | server → client | `benchKey, code` | A refusal. The client toasts `crafting.<code>`; `too_far`, `no_such_bench`, `no_character`, `not_for_you`, `no_position` also close the menu. |
| <a id="opx-on-crafting-state"></a>`opx:on:crafting:state` | client local | `{ open = true, bench }` or `{ open = false, reason }` | The menu opened or closed. |

## Configuration {#configuration}

`config/crafting.lua` sets `OPX.Config.MODULES.crafting`. Shared script. `enabled = false` switches the module off. These are limits on what a registering module may ask for; recipes live in the consumer's own config.

| Key | Default | What it does |
|---|---|---|
| <a id="config-crafting-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-crafting-reach"></a>`REACH` | `3.0` | Default bench reach, metres. |
| <a id="config-crafting-max-reach"></a>`MAX_REACH` | `25.0` | Largest reach a bench may ask for. |
| <a id="config-crafting-queue"></a>`QUEUE` | `3` | Default orders per character per bench. |
| <a id="config-crafting-max-queue"></a>`MAX_QUEUE` | `10` | Largest queue a bench may ask for. |
| <a id="config-crafting-min-seconds"></a>`MIN_SECONDS` | `5` | Shortest recipe time. Seconds, not milliseconds. |
| <a id="config-crafting-max-seconds"></a>`MAX_SECONDS` | `86400` | Longest recipe time. |
| <a id="config-crafting-max-yield"></a>`MAX_YIELD` | `1000` | Largest `COUNT`, and largest units per input. |
| <a id="config-crafting-max-inputs"></a>`MAX_INPUTS` | `8` | Most materials per recipe. |
| <a id="config-crafting-max-recipes"></a>`MAX_RECIPES` | `40` | Most recipes per bench; the rest are dropped. |
| <a id="config-crafting-rate-limit"></a>`RATE_LIMIT` | `{ WINDOW_MS = 10000, REQUESTS = 20 }` | Requests per player per window, across all benches. `REQUESTS = 0` turns it off. |
| <a id="config-crafting-handover-ms"></a>`HANDOVER_MS` | `1200` | Length of the `progress` bar shown when ordering. `0` turns it off. |
| <a id="config-crafting-refresh-ms"></a>`REFRESH_MS` | `5000` | How often an open menu asks for a fresh view. |

## Refusal codes {#codes}

The toast key is `crafting.<code>`. A `canUse` gate may answer its own codes; the registering module must add `crafting.<code>` to its locales (gunsmith does).

| Code | Meaning |
|---|---|
| `no_such_bench` | No bench with that key. |
| `no_such_recipe` | The bench has no such recipe (or no longer has it). |
| `not_for_you` | The `canUse` gate refused, or raised. |
| `too_far` | Out of reach, or another bucket. |
| `no_position` | The server cannot read the player's position. |
| `no_character` | No character loaded. |
| `short` | Not enough materials. |
| `cannot_pay` | Fee could not be paid. |
| `queue_full` | The queue is full. |
| `no_such_order` | Not one of this character's orders. |
| `not_ready` | Still cooking. |
| `no_room` | The bag cannot carry the output. |
| `too_fast` | Rate limit. |
| `unavailable` | Database error. |
