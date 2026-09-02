---
title: opx77_chat events
description: Every event opx77_chat sends and receives, split by networked and non-networked, and the complete path a typed slash command takes to the host's authenticated command dispatcher.
---

# Events

Events are how every other resource reaches the chat box, and how a typed line reaches the
server. `opx77_chat` publishes [six client exports](exports.md) as well, but they are local to
the machine that calls them — the wire names below are the only way a **server** resource can
put a line in a player's box.

!!! danger "Without `opx77_chat`, nothing typed in game reaches the server"

    Slash commands travel on the host's authenticated dispatcher, and this is the resource
    that tokenises a line and hands it over. Every `RegisterCommand` in every other resource
    stays reachable from the server console and from `startup.commands` — but from a player's
    keyboard, only through this box.

## The path a typed slash command takes {#command-path}

This is the single most important thing about this resource, so it is written out in full.

```text
player types  /opx77.weather.time 20:30:00
      │
      ▼
web/chat.js  ──emit("chat:submit", { text })──►  client/main.lua, page:on("chat:submit")
      │
      │  the line starts with '/', so commandTokens() runs:
      │  strips the leading '/', splits on whitespace, honours "quotes",
      │  'single quotes' and backslash escapes, refuses past 32 tokens
      ▼
TriggerEvent("chat:commandSubmitted", text, tokens)        -- local to this client
TriggerServerEvent("open77:command:execute", tokens...)    -- the HOST's dispatcher
      │
      ▼
host: resolves command.<name> against the caller's ACL, before any resource Lua runs
      │
      ▼
the target resource's RegisterCommand handler runs, with (source, args, raw)
      │
      ▼
TriggerClientEvent("open77:command:result", player, raw, accepted, message)
      │
      ▼
client/main.lua renders it as a COMMAND line in the box
```

The box closes on submit either way — after the command is sent, and also when it is refused
before it is sent.

!!! warning "The ACL check is the host's, and this resource never repeats it"

    `server/main.lua` relays messages and nothing else. There is no command relay in it,
    deliberately: the third argument to `RegisterCommand` marks a command *restricted*, and
    the host resolves `command.<name>` against the caller's permissions **before** the handler
    runs. A relay written here would be a second, weaker gate in front of a check that has
    already happened. See [Getting started](../../guides/getting-started.md) for granting those
    permissions in `acl.jsonc`.

Because the dispatcher is the host's, a command line is not subject to `RATE_MS`: that floor
guards `chat:submit`, the message path. Four checks do apply on the way out, all of them in
`commandTokens` before anything is sent, and each reported in the box as a red `COMMAND` line:

| Refusal | Message |
|---|---|
| More than 32 tokens (the transport's cap) | `Commands are limited to 32 arguments.` |
| A trailing `\` | `A command cannot end with an escape character.` |
| An unclosed `"` or `'` | `The command contains an unterminated quote.` |
| `/` with nothing after it | `Enter a command after '/'.` |

Those four messages and the `COMMAND` tag above them are catalogue keys, shown here in the
shipped `en` — see [Player-facing text](index.md#locales).

Quoting works the way a shell's does, so an argument may contain spaces:

```text
/opx77.create "Jean Pierre" Dubois corpo female
```

A line that does **not** start with `/` takes the other route entirely: it goes to this
resource's own server half on [`chat:submit`](#chat-submit) and comes back to every client on
[`chat:addMessage`](#chat-addmessage).

## Networked (client → server) {#networked-client-to-server}

Register these with `RegisterNetEvent` in a **server** script. Your resource needs
`network.events` in its manifest to receive them. Inside the handler, `source` is the
authenticated connection that sent it — never trust an id in the payload.

### chat:submit {#chat-submit}

Fires when a player submits a line that does not begin with `/`. Handled by `opx77_chat`'s own
server half, which cleans it and broadcasts it to everybody.

```lua
RegisterNetEvent("chat:submit", function(text) end)
```

- text: `string`

`opx77_chat` replaces control characters with spaces, truncates the line to `MAX_LENGTH`
**characters** with a trailing `...`, drops it if it is blank or inside the `RATE_MS` floor for
that player, and rebroadcasts it as `chat:addMessage` to `-1` with `type = "chat"` and an
`author` read server-side from `Open77.players.name` — or the catalogue's `player <id>` fallback
when the host has no name for that connection. The truncation counts characters and not bytes, so it
never cuts a multi-byte one in half; see [`MAX_LENGTH`](config.md#max-length).

!!! warning "The author is a label, never an identity"

    The relay attributes every message to `source`, the authenticated connection inside the
    net event handler, and never to a name in the payload — a client cannot speak as somebody
    else. The display name in the box is player-changeable, so treat it as a label: if you are
    logging or moderating, log the citizen id, not the tag on screen.

### chat:ready {#chat-ready}

Fires when a player's chat page has come up, and again every time they open the box. It is the
signal that there is somewhere to put completion entries.

```lua
RegisterNetEvent("chat:ready", function() end)
```

Carries no arguments. See [Publishing suggestions](#publishing-suggestions) for the answer.

!!! danger "Floor your answer to this event"

    `chat:ready` is a net event, free for any client to send as fast as it likes, and every
    one of them is answered with several hundred bytes. `opx77_core` and `opx77_hud` each keep
    a per-player timestamp and refuse a second answer inside 10 s; `opx77_weather` floors it at
    2 s alongside its open commands. Do the same, and clear the entry on
    `onPlayerDisconnected` — the host recycles session player ids.

### open77:command:execute {#open77-command-execute}

The host's authenticated command dispatcher. `opx77_chat` sends it; **nothing receives it in
Lua**.

```lua
-- sent by opx77_chat's client half; do not register a handler for this name
TriggerServerEvent("open77:command:execute", table.unpack(tokens))
```

- tokens: `string...` — the command name first, then one string per argument, at most 32 in
  total.

This name is consumed by the host, which resolves `command.<name>` against the caller's ACL
and then calls the matching `RegisterCommand` handler. Registering a Lua handler for it would
not intercept anything; write a `RegisterCommand` instead.

## Networked (server → client) {#networked-server-to-client}

These are what `opx77_chat`'s **client** half listens for. Send them from a server script with
`TriggerClientEvent(name, playerId, …)`, or `-1` for everyone. Your resource needs
`network.events` in its manifest to send them.

!!! info "These names are also reachable locally"

    On the client — unlike the server — a plain `TriggerEvent` also reaches `RegisterNetEvent`
    handlers of the same name, and the client's local bus is host-wide. So any resource on the
    player's machine can raise `chat:addMessage` locally and land a line in the box, without
    the round trip. The [exports](exports.md) are the supported way to do that, because they
    tell you whether the page was actually there; the local event does not.

### chat:addMessage {#chat-addmessage}

Adds one line to the recipient's box. Silently dropped if that client's page has not reported
ready.

```lua
RegisterNetEvent("chat:addMessage", function(message) end)
```

- message: `table | string`
    - A bare string is taken as `{ text = message }`.
    - `type`: `string` — the line's CSS class. `chat`, `info` and `error` are what this
      resource uses.
    - `author`: `string` — the tag before the text, rendered as text and never as markup.
    - `text`: `string`
    - `color`: `{ r, g, b }` — tints the author tag only.

!!! warning "Never re-emit a wire name from inside its own handler"

    A `TriggerEvent("chat:addMessage", …)` inside a `chat:addMessage` handler reaches that same
    handler again. There is no re-entry guard on this platform — it is tick-paced, so it does
    not blow the stack, it becomes a silent permanent busy loop instead. If you want to
    decorate a message, register a name of your own and emit `chat:addMessage` from there.

### chat:addSuggestion {#chat-addsuggestion}

Adds or replaces one completion entry on the recipient's page.

```lua
RegisterNetEvent("chat:addSuggestion", function(command, help, parameters) end)
```

- command: `string` — with or without the leading slash; the page adds one if you omit it.
- help?: `string` — the one-line description drawn beside the name.
- parameters?: `table` — a list of `{ name = string, help = string }`.

### chat:addSuggestions {#chat-addsuggestions}

Adds or replaces several completion entries at once. This is the one to answer
[`chat:ready`](#chat-ready) with.

```lua
RegisterNetEvent("chat:addSuggestions", function(suggestions) end)
```

- suggestions: `table` — a list of `{ command, help, parameters }`, each shaped as
  [`chat:addSuggestion`](#chat-addsuggestion)'s three arguments.

### chat:removeSuggestion {#chat-removesuggestion}

Drops one completion entry, by name.

```lua
RegisterNetEvent("chat:removeSuggestion", function(command) end)
```

- command: `string` — with or without the leading slash.

Removing an entry that was never added does nothing and is not an error.

### chat:clearSuggestions {#chat-clearsuggestions}

Drops every completion entry on the recipient's page, whoever published it.

```lua
RegisterNetEvent("chat:clearSuggestions", function() end)
```

Carries no arguments.

!!! warning "It is not scoped to your resource"

    The page keeps one flat map of suggestions keyed by name. Clearing it removes
    `opx77_core`'s character commands and `opx77_weather`'s staff desk along with yours, and
    nothing republishes them until that player's page comes up again. Prefer
    [`chat:removeSuggestion`](#chat-removesuggestion) per entry.

### chat:clear {#chat-clear}

Empties the recipient's visible log. Suggestions are a separate list and are left alone.

```lua
RegisterNetEvent("chat:clear", function() end)
```

Carries no arguments.

### chat:setEnabled {#chat-setenabled}

Turns the recipient's box off or back on. Disabling closes it if it is open, and the open key
then refuses with a logged line rather than silently doing nothing.

```lua
RegisterNetEvent("chat:setEnabled", function(enabled) end)
```

- enabled: `any` — anything but `false` enables. Only a literal `false` disables.

!!! warning "One flag for the whole client, with no owner and no stack"

    Disabling the chat disables it for every resource on that machine, and the last call wins.
    Re-enable it in the same code path that disabled it, including on your error paths, or the
    player is left with a dead chat key and a client log reading
    `open refused: the chat is disabled by the server`.

### open77:command:result {#open77-command-result}

The dispatcher's answer to a command that player typed. `opx77_chat` renders it as a `COMMAND`
line — cyan when accepted, red when refused.

```lua
RegisterNetEvent("open77:command:result", function(raw, accepted, message) end)
```

- raw: `string` — the command name as typed.
- accepted: `boolean`
- message: `string` — shown in place of `raw` when it is not empty.

`opx77_core` wraps sending this as `OPX.CommandResult(source, raw, accepted, message)`, which
prints to the server console instead when `source` is `0`. Other resources register the name
as well — `opx77_weather`'s client half logs the ones whose `raw` names one of its own
configured commands — so it is a shared channel, not a private one.

An accepted result whose `message` contains `' queued by resource ` is dropped by the client:
the dispatcher acknowledges queueing immediately and then sends the useful result, and showing
both puts a line of noise above every answer. Nothing on the payload marks one as the
acknowledgement — no phase, no flag, and `accepted` is true for both — so the only thing left to
match on is the platform's own wording, `command '<name>' queued by resource <resource>`. It is
matched as a substring rather than as a prefix, because the line begins with `command '`.

!!! warning "That filter is a match on somebody else's prose, not a contract"

    `opx77_chat/docs/unknowns.md` records it as such. If the platform rewords the
    acknowledgement the filter stops matching and the queue line reappears above every answer —
    cosmetic, and one constant to fix. Do not replace it by counting results or by timing them:
    `open77:command:result` is not ordered against anything else, and a command that answers
    nothing at all is normal.

!!! warning "The dispatcher's refusal codes are shown verbatim"

    `opx77_chat` renders `message` as it arrives. A player who types an unknown command sees
    the literal `unknown_command`, and one without the grant sees
    `permission_denied:command.<name>`. The platform's own package rewrites those two into
    prose; this one does not. If you want friendlier text, send your own
    [`chat:addMessage`](#chat-addmessage) from the command handler.

## Non-networked {#non-networked}

Register these with `AddEventHandler` in a **client** script. The client's local event bus is
host-wide, so a name raised in any resource on the player's machine reaches handlers in all of
them.

### open77:chat:open {#open77-chat-open}

Raised by the **host** when the player presses the chat key. `opx77_chat` has no key binding
of its own; this is the whole of it.

```lua
AddEventHandler("open77:chat:open", function() end)
```

Carries no arguments. Handle it if you need to know the box is about to open — for example to
put your own surface away first.

### chat:open {#chat-open}

Opens the box. Any client resource may raise it.

```lua
TriggerEvent("chat:open")
```

Carries no arguments. It is refused, with a logged reason, if the surface was never created,
the chat is disabled, or the page has not reported ready; see
[the box](index.md#the-box) for the four refusals.

### chat:close {#chat-close}

Closes the box and hands the keyboard back. Any client resource may raise it.

```lua
TriggerEvent("chat:close")
```

Carries no arguments. A no-op if the box is not open.

### chat:commandSubmitted {#chat-commandsubmitted}

Raised locally by `opx77_chat` the moment a slash command has been tokenised, immediately
before it goes to the dispatcher.

```lua
AddEventHandler("chat:commandSubmitted", function(text, tokens) end)
```

- text: `string` — the line as typed, leading slash included.
- tokens: `table` — the parsed argument list, command name first, slash stripped.

!!! warning "This is a notification, not a hook"

    The command has already been tokenised and is sent to the server on the next statement.
    Handling this name cannot cancel, rewrite or delay it, and it fires on the player's own
    machine, so it is not evidence of anything server-side. Use it for local presentation —
    closing your own UI, a client-side log — and nothing else.

## Publishing suggestions {#publishing-suggestions}

Completion is not a list `opx77_chat` maintains. Every resource publishes its own, and the
contract is two events:

1. The client sends the net event [`chat:ready`](#chat-ready) to the server — once when the
   page reports ready, and again each time the box is opened.
2. A resource answers **that player** with [`chat:addSuggestions`](#chat-addsuggestions) or
   [`chat:addSuggestion`](#chat-addsuggestion), from its **server** half.

```lua
--- server/main.lua of your own resource.
--- Suggestions for the chat autocomplete. Sent on the client's `chat:ready` rather than at
--- boot: suggestions sent before that surface is up land nowhere.
local lastSuggestedMs = {}

RegisterNetEvent("chat:ready", function()
  local player = tonumber(source) or 0
  if player <= 0 then return end

  -- `chat:ready` is a net event any client is free to send, and it is answered
  -- with several hundred bytes. Floor it.
  local atMs = math.floor(Open77.time.monotonic() * 1000)
  local previous = lastSuggestedMs[player]
  if previous ~= nil and atMs - previous < 10000 then return end
  lastSuggestedMs[player] = atMs

  TriggerClientEvent("chat:addSuggestions", player, {
    { command = "/ripperdoc.heal", help = "Patch yourself up at this clinic.",
      parameters = { { name = "bodyPart", help = "arm, leg, torso; omit for all" } } },
    { command = "/ripperdoc.prices", help = "List what this clinic charges." },
  })
end)

AddEventHandler("onPlayerDisconnected", function(playerId)
  lastSuggestedMs[tonumber(playerId) or -1] = nil
end)
```

!!! warning "Publish on `chat:ready`, never at boot"

    A suggestion sent before the player's chat surface exists lands nowhere — the client drops
    everything it is sent until the page has reported ready. `chat:ready` is the signal that
    there is somewhere to put them, and it arrives again after every reload of `opx77_chat`,
    which is what makes the list survive one.

A suggestion is a table of `command`, `help` and `parameters`. A leading `/` is added if you
omit it, and the page keys entries by name, so publishing the same name twice replaces rather
than duplicates. Each parameter is a table with a `name`; the page appends every parameter
name to the help text in square brackets and reads nothing else from it, so an `optional` or
`help` key is documentation for whoever reads your code next.

## See also {#see-also}

- [Exports](exports.md) — the client-local route to the same six behaviours.
- [`opx77_core`](../opx77_core/index.md) — `OPX.CommandResult` and the character command set.
- [Integration channels](../../concepts/integration-channels.md) — why a server resource must
  use the wire rather than an export.
