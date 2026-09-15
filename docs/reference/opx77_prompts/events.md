---
title: opx77_prompts events
description: The four net events a server resource sends opx77_prompts — show, update, hide and hideAll — with their envelopes, who may send them, how the owner is named, and why a server-sent group outlives its sender.
---

# Events

`opx77_prompts` **listens** for four networked names, which is how a server
resource reaches it, and **raises** none. Nothing about a group is announced: a
caller that needs to know whether its keys are on screen asks
[`list`](exports.md#list).

## Networked {#networked}

The server runtime installs no exports, so a server resource sends the same
operations as net events to one player, with `TriggerClientEvent`. Four inbound
names, and no outbound one: this resource never calls `TriggerServerEvent` and
has no server half. `network.events` in its manifest is for `RegisterNetEvent`
alone.

| Event | Payload | Same as |
|---|---|---|
| [`opx77_prompts:show`](#opx77-prompts-show) | `{ owner, id, spec }` | [`show`](exports.md#show) |
| [`opx77_prompts:update`](#opx77-prompts-update) | `{ owner, id, patch }` | [`update`](exports.md#update) |
| [`opx77_prompts:hide`](#opx77-prompts-hide) | `{ owner, id }` | [`hide`](exports.md#hide) |
| [`opx77_prompts:hideAll`](#opx77-prompts-hideall) | `owner`, a bare string | [`hideAll`](exports.md#hideall) |

The envelope is a [`PromptEnvelope`](types.md#promptenvelope).

!!! warning "These answer nothing, and a refusal is silent"
    There is no channel back to the server. An envelope that is not a table, or
    whose `owner` is not a valid name, is dropped. A well-formed one runs the same
    operation as the export, with the same validation and the same ceilings —
    and when that operation refuses (`invalid_label`, `owner_limit`,
    `prompt_not_found`, ...), nothing is logged and nothing is answered. Test a
    spec against the client export first.

### The owner is taken at its word {#owner}

`owner` is the sending resource's name, 1–56 characters of `[%w_:%-%.]`, and it
is **not** checked against anything: the client cannot know which server resource
sent an event. It is stored as `@server:<owner>`.

That prefix is what keeps the two worlds apart. `@` is outside the characters a
client owner is validated against, so a server-sent group can never reach a
client resource's groups, nor a client resource a server-sent one — only
envelopes sent under the same `owner` reach each other. Send
`GetCurrentResourceName()` and nothing else.

A bare `mapping` id in a server-sent row resolves against the **client half of
the resource named `owner`**, the only half that can register a key mapping.
`{ mapping = "resource|id" }` names another resource's, as it does for a client
caller.

!!! warning "The local bus reaches these handlers too"
    On this platform a client `TriggerEvent` also reaches a `RegisterNetEvent`
    handler of the same name — see
    [The client local event bus is host-wide](../../concepts/export-contract.md#local-bus).
    Any client resource can therefore raise these names under any `owner`, and
    touch that `@server:` owner's groups. It still cannot reach a client
    resource's groups. A client resource has no reason to use these: call the
    exports, which take the owner from the host.

### opx77_prompts:show {#opx77-prompts-show}

Puts up a group owned by a server resource, or replaces the one it already sent
under that id, where it stands.

```lua
-- a server script in your own resource
TriggerClientEvent("opx77_prompts:show", playerId, {
  owner = GetCurrentResourceName(),
  id = "duty",
  spec = { rows = { { keys = "E", label = "Clock in" } } },
})
```

- `owner`: `string` — the sending resource's name.
- `id`: `string` — 1–64 characters of `[%w_:%-%.]`, unique per owner.
- `spec`: [`PromptSpec`](types.md#promptspec).

**Side** `net event`, server to client. Any server resource may send it; the
receiving client runs it as [`show`](exports.md#show) would.

### opx77_prompts:update {#opx77-prompts-update}

Patches a group that server resource already sent.

```lua
TriggerClientEvent("opx77_prompts:update", playerId, {
  owner = GetCurrentResourceName(),
  id = "duty",
  patch = { title = "ON DUTY" },
})
```

- `owner`: `string`
- `id`: `string`
- `patch`: [`PromptPatch`](types.md#promptpatch).

An `id` with no group under that owner is dropped in silence.

**Side** `net event`, server to client.

### opx77_prompts:hide {#opx77-prompts-hide}

Takes down one group that server resource sent.

```lua
TriggerClientEvent("opx77_prompts:hide", playerId, {
  owner = GetCurrentResourceName(),
  id = "duty",
})
```

**Side** `net event`, server to client.

### opx77_prompts:hideAll {#opx77-prompts-hideall}

Takes down every group that server resource sent to that player.

```lua
-- the whole payload is the owner name; this one is NOT a table
TriggerClientEvent("opx77_prompts:hideAll", playerId, GetCurrentResourceName())
```

**Side** `net event`, server to client.

### A server-sent group outlives its sender {#server-lifetime}

A client cannot see a server resource stop, and a server owner has no generation
to compare, so the [owner sweep](exports.md#sweep) never touches a server-sent
group. It stays up until it is hidden, or until `opx77_prompts` or the player's
session ends. A server resource that restarts should send `hideAll` to its
players before it puts anything up again, or send the same ids so they replace
what is there.

## What it listens to on the client {#local}

These are not part of its surface, but they explain when the strip changes on its
own.

| Event | Raised by | What the strip does |
|---|---|---|
| `open77:keybinds:changed` | the platform, after any key mapping is registered, rebound, reset or removed | reads `Open77.input.mappings()` again and redraws, so a mapping row shows the new key |
| `onClientResourceStart` | the host | on its own start, creates the surface and starts its loops |
| `onClientResourceStop` | the host | on its own stop, drops everything; on another resource's stop, drops that owner's groups |

## Not events: the page channels {#page-channels}

`prompts:config`, `prompts:frame`, `prompts:hide`, `prompts:ready` and
`prompts:diag` look like event names and are not. They are `page:send` and
`page:on` channels on this resource's own WebUI surface, and nothing outside this
resource can raise or hear them. The page decides nothing: the order, the cut and
every key name arrive resolved in `prompts:frame`.
