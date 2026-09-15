---
title: opx77_chat exports
description: The six client exports opx77_chat publishes — addMessage, clearMessages, addSuggestion, removeSuggestion, setEnabled and isEnabled — with their arguments, results and refusal codes.
---

# Exports

`opx77_chat` publishes six client exports. Five of them are the names the platform documents
on its own `open77_chat` package, with the same arguments and the same message schema. The
sixth is not: `clear` was renamed to [`clearMessages`](#clearmessages) in `0.3.0`, because it
empties the message log and leaves the suggestions alone, and its neighbours all name what they
act on. Code written against the platform package needs that one-word change and nothing
else.

!!! info "Read the export contract first"

    Every call on this page is asynchronous, resource-scoped and can fail at three different
    levels. [The export contract](../../concepts/export-contract.md) explains the shape; this
    page assumes it.

```lua
local promise, reason = Open77.exports.call("opx77_chat", "addMessage", { text = "hello" })
```

There are no server exports here. A server resource that wants to put a line in one player's
box sends that player `chat:addMessage` instead — see [Events](events.md).

## What every export answers {#result-shape}

Every export answers a table carrying `ok`, and never raises. When `ok` is `false` the table
also carries `error`, a stable snake_case code meant for branching rather than for a player to
read — a caller that wants to show one renders it through its own catalogue, because these
codes are not translated.

The shapes have names, annotated in `opx77_chat/std/types.lua`, which the manifest never loads:
`ChatResponse` and `ChatEnabledState` for the answers, `ChatMessage` for one line,
`ChatSuggestion` and `ChatSuggestionParameter` for a completion entry, `ChatError` for the codes
below, and `ChatConfig` for `config.lua`.

| Code | Meaning |
|---|---|
| `export_call_required` | There was no invoking resource — the call came from inside `opx77_chat` itself, or from outside the export machinery. |
| `no_surface` | `WebUI.create` failed at start. There is no box in this generation and there never will be. |
| `page_not_ready` | The surface exists but has not raised `chat:ready` yet. Try again. |
| `invalid_message` | The message was neither a string nor a table. |
| `invalid_command` | The command name was empty — including a suggestion table that names none — which the page would silently drop. |

The four exports that put something on the page check the surface before answering, because
the client's internal `send` is silent when the surface is missing or still starting, and
answering `ok` for a message nobody will ever see would be the one lie this surface can tell.

!!! warning "This differs from the official package, on purpose"

    The official `open77_chat` exports return bare booleans, and return `true` even when the
    page is not there to receive the payload. A caller that only tests truthiness reads
    `{ ok = true }` as true either way, so the shapes are compatible; a caller that wants to
    know *why* now has it. Do not port a check for a literal `true` — port a check for `.ok`.

## addMessage {#addmessage}

Adds one line to the calling player's own chat box, and answers
`{ ok = false, error = … }` if the surface is missing, still starting, or the message is
neither a string nor a table.

```lua
Open77.exports.call("opx77_chat", "addMessage", message)
```

- message: `table | string`
    - A bare string is taken as `{ text = message }`.
    - `type`: `string` — becomes the line's CSS class. The stylesheet styles `chat`, `info`,
      `error` and `system`; anything else is rendered with no styling of its own.
    - `author`: `string` — the tag drawn before the text. Rendered as text and never as
      markup.
    - `text`: `string` — the line.
    - `color`: `{ r, g, b }` — tints the **author tag only**, not the body, and overrides the
      colour the line's `type` gives it. Kept for third-party senders: no OPX//77 resource sends
      one, and a line meant as information or an error is better sent with its `type` alone.

**Returns** `table` — a `ChatResponse`: `{ ok = true }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | Called with no invoking resource. |
| `no_surface` | The WebUI surface was never created. |
| `page_not_ready` | The page has not raised `chat:ready` yet. |
| `invalid_message` | Not a string and not a table. |

**Side** `client export` — callable from any client resource through `Open77.exports.call`.
Local only: the line renders on this machine and travels nowhere. A resource that wants
everyone to see it says so on the server, with `chat:addMessage` to `-1`.

### Example {#addmessage-example}

```lua
-- client/main.lua of your own resource
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_chat", "addMessage", {
    type = "info",
    author = "RIPPERDOC",
    text = "You are patched up.",
  })
  if not promise then return Open77.log.warn("not dispatched: " .. tostring(reason)) end

  local answer, callError = promise:await()
  if callError then return Open77.log.warn("call failed: " .. tostring(callError)) end
  if not answer.ok then Open77.log.warn("chat refused: " .. tostring(answer.error)) end
end)
```

## clearMessages {#clearmessages}

Empties the visible log, and answers `{ ok = false, error = … }` if the surface is missing or
still starting.

```lua
Open77.exports.call("opx77_chat", "clearMessages")
```

**Returns** `table` — a `ChatResponse`: `{ ok = true }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | Called with no invoking resource. |
| `no_surface` | The WebUI surface was never created. |
| `page_not_ready` | The page has not raised `chat:ready` yet. |

**Side** `client export` — callable from any client resource through `Open77.exports.call`.
Local only.

Suggestions are a separate list and are left alone, which is what the official package does
too. To drop the completion list as well, call [`removeSuggestion`](#removesuggestion) per
entry, or send this client `chat:clearSuggestions` from the server.

### Example {#clearmessages-example}

```lua
CreateThread(function()
  local promise = Open77.exports.call("opx77_chat", "clearMessages")
  if promise then promise:await() end
end)
```

## addSuggestion {#addsuggestion}

Adds or replaces the completion entry for one slash command, and answers
`{ ok = false, error = "invalid_command" }` for an empty name.

```lua
Open77.exports.call("opx77_chat", "addSuggestion", command, help, parameters)
Open77.exports.call("opx77_chat", "addSuggestion", suggestion)
```

- command: `string | table`
    - The page keys entries by name and prefixes the slash itself, so `"heal"` and `"/heal"`
      are the same entry.
    - A whole `ChatSuggestion` table is accepted in its place: `{ command, help, parameters }`,
      with `name` read where `command` is absent and `params` where `parameters` is. The
      table's own `help` and `parameters` are used, and `help` and `parameters` arguments are
      then ignored. A table that names no command is refused with `invalid_command`.
- help?: `string`
    - The one-line description drawn beside the name. Anything not a string is stringified.
    - Default: `""`
- parameters?: `table`
    - A list of `ChatSuggestionParameter`, in the order the arguments are typed:
      `{ name = string, help? = string, optional? = boolean }`, or a bare string taken as the
      name. Each is drawn after the command as `<name>`, or `[name]` when `optional = true`;
      while the player types that argument it is lit and its `help` is drawn on a line of its
      own under the entry. The page keeps the first 16, names cut to 40 characters and help to
      240.
    - Default: `{}`

**Returns** `table` — a `ChatResponse`: `{ ok = true }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | Called with no invoking resource. |
| `no_surface` | The WebUI surface was never created. |
| `page_not_ready` | The page has not raised `chat:ready` yet. |
| `invalid_command` | The command name was empty, or the table named no `command` or `name`. |

**Side** `client export` — callable from any client resource through `Open77.exports.call`.
Local only: it adds the entry to this player's completion list.

!!! warning "A suggestion published from the client is lost on every reload of this resource"

    The completion list lives in the page, and the page is rebuilt whenever `opx77_chat`
    starts. The supported way to publish a suggestion is from your **server** half, on the
    client's `chat:ready` net event, which is raised again every time a new page comes up —
    see [Publishing suggestions](events.md#publishing-suggestions). Use this export for an
    entry that is genuinely local and transient, such as one that only exists while a
    minigame is running.

### Example {#addsuggestion-example}

```lua
CreateThread(function()
  local promise = Open77.exports.call("opx77_chat", "addSuggestion",
    "/ripperdoc.heal", "Patch yourself up at this clinic.", {
      { name = "bodyPart", help = "arm, leg, torso; omit for all", optional = true },
    })
  if not promise then return end
  local answer = promise:await()
  if not answer.ok then Open77.log.warn(tostring(answer.error)) end
end)
```

## removeSuggestion {#removesuggestion}

Takes one completion entry back down, and answers
`{ ok = false, error = "invalid_command" }` for an empty name.

```lua
Open77.exports.call("opx77_chat", "removeSuggestion", command)
```

- command: `string`
    - With or without the leading slash; the page adds one if you omit it.

**Returns** `table` — a `ChatResponse`: `{ ok = true }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | Called with no invoking resource. |
| `no_surface` | The WebUI surface was never created. |
| `page_not_ready` | The page has not raised `chat:ready` yet. |
| `invalid_command` | The command name was empty. |

**Side** `client export` — callable from any client resource through `Open77.exports.call`.
Local only.

Removing an entry that was never added answers `ok`. The page keys by name, so there is
nothing to be wrong about.

### Example {#removesuggestion-example}

```lua
CreateThread(function()
  local promise = Open77.exports.call("opx77_chat", "removeSuggestion", "ripperdoc.heal")
  if promise then promise:await() end
end)
```

## setEnabled {#setenabled}

Turns the box off or back on for **the whole client**, closing it if it is open, and answers
the state it now holds.

!!! warning "One flag for the whole box, not one per caller"

    Disabling the chat disables it for every resource on this machine, not just for yours, and
    nothing tracks who disabled it — the last call wins and there is no stack to unwind. That
    is the official package's rule and it is the right one: a cutscene or a character creator
    that turns the chat off means to turn it off, not to stop hearing from itself. Re-enable
    it in the same code path that disabled it, including on your own error paths, or the
    player is left with a dead chat key and a logged
    `open refused: the chat is disabled by the server`.

```lua
Open77.exports.call("opx77_chat", "setEnabled", enabled)
```

- enabled: `any`
    - Anything but `false` enables. Only a literal `false` disables.

**Returns** `table` — a `ChatEnabledState`: `{ ok = true, enabled = boolean }`, the state it now holds

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | Called with no invoking resource. |

**Side** `client export` — callable from any client resource through `Open77.exports.call`.
Local only.

There is no surface check on this one, deliberately: the flag is real state whether or not
there is a page to draw it on, and a gamemode that disables the chat during a cutscene has to
be able to do it before the page has loaded.

!!! warning "The platform's own catalogue describes this wrongly"

    `resource-exports.md` says `setEnabled` "Enables/disables chat for the calling resource
    context". The official package's source sets a single file-scope flag for the whole
    resource, exactly as this one does — there is no per-caller context in either
    implementation. `opx77_chat` matches the shipped behaviour, not the sentence.

### Example {#setenabled-example}

```lua
-- a cutscene that must not be interrupted by the chat key
CreateThread(function()
  local off = Open77.exports.call("opx77_chat", "setEnabled", false)
  if off then off:await() end

  playCutscene()

  -- re-enabled on every path out, including failure
  local on = Open77.exports.call("opx77_chat", "setEnabled", true)
  if on then on:await() end
end)
```

## isEnabled {#isenabled}

Answers whether the box is currently enabled.

```lua
Open77.exports.call("opx77_chat", "isEnabled")
```

**Returns** `table` — a `ChatEnabledState`: `{ ok = true, enabled = boolean }`

**Errors**

| Code | Meaning |
|---|---|
| `export_call_required` | Called with no invoking resource. |

**Side** `client export` — callable from any client resource through `Open77.exports.call`.
Local only.

`enabled` is the flag, not the surface. It reads `true` on a client where `WebUI.create`
failed and there is no box at all, and it says nothing about whether the box is currently
*open*. There is deliberately no export for that: the open state is this resource's alone.

### Example {#isenabled-example}

```lua
CreateThread(function()
  local promise = Open77.exports.call("opx77_chat", "isEnabled")
  if not promise then return end
  local answer, callError = promise:await()
  if callError or not answer.ok then return end
  if not answer.enabled then
    Open77.log.info("something has the chat turned off; not queueing a line")
  end
end)
```

## See also {#see-also}

- [Events](events.md) — the server-side route to a player's box, and the suggestion handshake.
- [Configuration](config.md) — `MAX_LENGTH`, `HISTORY` and the rest.
- [The export contract](../../concepts/export-contract.md).
