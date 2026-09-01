# opx77_chat

The chat box, and the path a typed command takes to the server.

| | |
|---|---|
| Version | `0.1.0` |
| Reload policy | `local` — a CEF surface, rebuilt on start |
| Permissions | `network.events` |
| Requires | `open77_version >=0.0.1`. Nothing else in OPX//77. |
| Commands | None of its own. |

## What it is

`opx77_chat` owns one WebUI surface — a log, an input line and a completion
list — and one job besides drawing it: turning a typed line into something the
server can act on.

A line that does not start with `/` is a message. It goes to this resource's
own server half on `chat:submit`, and comes back to every client on
`chat:addMessage`, attributed to the connection that sent it.

A line that starts with `/` is a command, and it does **not** go to this
resource's server half at all. The client tokenises it and triggers
`open77:command:execute` on the **host's** dispatcher, which resolves the
caller's ACL before any resource Lua runs.

!!! danger "Without `opx77_chat`, nothing typed in game reaches the server"

    Slash commands travel on the host's authenticated dispatcher, and this is
    the resource that tokenises a line and hands it over. Every
    `RegisterCommand` in every other resource is reachable from the console
    and from `startup.commands` — but from a player's keyboard only through
    this box. Its own client half says so when the surface fails to come up:

    ```text
    WebUI surface failed: <reason>
      no command typed in chat will reach the server.
    ```

It carries no commands of its own. It carries everybody else's.

The open key belongs to the host, not to this resource: the host raises
`open77:chat:open` when the player presses it, and there is no binding here.
`chat:open` and `chat:close` are also handled, so another resource can open or
close the box.

## How a command travels

```text
player types  /opx77.weather.time 20:30:00
      │
      ▼
web page  ──chat:submit──►  client/main.lua
      │
      │  commandTokens(): strips the '/', splits on whitespace,
      │  honours quotes and backslash escapes, refuses past 32 tokens
      ▼
TriggerEvent("chat:commandSubmitted", text, tokens)      -- local, this client
TriggerServerEvent("open77:command:execute", tokens...)  -- the HOST dispatcher
      │
      ▼
host: resolves command.<name> against the caller's ACL
      │
      ▼
the target resource's RegisterCommand handler runs
      │
      ▼
TriggerClientEvent("open77:command:result", player, raw, accepted, message)
      │
      ▼
client/main.lua prints it as a COMMAND line in the box
```

!!! important "The ACL check is the host's, and this resource never repeats it"

    `server/main.lua` relays messages and nothing else. There is no command
    relay in it, deliberately — the third argument to `RegisterCommand` marks a
    command *restricted*, and the host resolves `command.<name>` against the
    caller's permissions **before** the handler runs. A relay written here
    would be a second, weaker gate in front of a check that has already
    happened. See [Getting started](../getting-started.md) for granting those
    permissions in `acl.jsonc`.

Because the dispatcher is the host's, a command line is not subject to
`RATE_MS`: that floor guards `chat:submit`, the message path. Three checks do
apply on the way out, all of them in `commandTokens` before anything is sent,
and each reported in the box as a red `COMMAND` line:

| Refusal | Message |
|---|---|
| More than 32 tokens (the transport's cap) | `Commands are limited to 32 arguments.` |
| A trailing `\` | `A command cannot end with an escape character.` |
| An unclosed `"` or `'` | `The command contains an unterminated quote.` |
| `/` with nothing after it | `Enter a command after '/'.` |

Quoting works the way a shell's does, so an argument may contain spaces:

```text
/opx77.create "Jean Pierre" Dubois corpo female
```

### Answering a command

A command handler answers the player with `open77:command:result`, carrying
`(raw, accepted, message)`. The box renders an accepted answer as a cyan
`COMMAND` line and a refusal as a red one. `opx77_core` wraps this as
`OPX.CommandResult(source, raw, accepted, message)`, which prints to the
console instead when `source` is `0`.

!!! note "The queue acknowledgement is suppressed"

    The dispatcher acknowledges queueing immediately and then sends the useful
    result. An accepted message beginning `queued by ` is dropped by the
    client, so every answer is one line rather than two.

## Publishing command suggestions

Completion is not a list this resource maintains. Every resource publishes its
own, and the contract is two events:

1. The client sends the **net event** `chat:ready` to the server — once when
   the page reports ready, and again each time the box is opened.
2. A resource answers that player with `chat:addSuggestions` (a list) or
   `chat:addSuggestion` (one), from its **server** half.

A suggestion is a table of `command`, `help` and `parameters`. A leading `/` is
added if you omit it. Each parameter is a table with a `name`; the page appends
every parameter name to the help text in square brackets, and reads nothing
else from it, so an `optional` or `help` key is documentation for whoever
reads your code next.

```lua
--- Suggestions for the chat autocomplete. Sent on the client's `chat:ready`
--- rather than at boot: suggestions sent before that surface is up land nowhere.
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
    { command = "/opx77.characters", help = "List your characters." },
    { command = "/opx77.select", help = "Enter the world as one of your characters.",
      parameters = { { name = "citizenId" } } },
    { command = "/opx77.create", help = "Create a character.",
      parameters = {
        { name = "firstName" }, { name = "lastName" },
        { name = "nomad|streetkid|corpo", optional = true },
        { name = "female|male", optional = true },
      } },
  })
end)
```

!!! warning "Publish on `chat:ready`, never at boot"

    A suggestion sent before the player's chat surface exists lands nowhere —
    the client drops everything it is sent until the page has reported ready.
    `chat:ready` is the signal that there is somewhere to put them.

!!! danger "Floor your answer"

    `chat:ready` is a net event, free for any client to send as fast as it
    likes, and every one of them is answered. `opx77_core`, `opx77_hud` and
    `opx77_weather` each keep a per-player timestamp and refuse a second answer
    inside 10 s. Do the same.

Everything a resource may send to a player's chat client:

| Event | Payload | Effect |
|---|---|---|
| `chat:addMessage` | `{ type, author, text, color }`, or a string | Adds one line. |
| `chat:addSuggestion` | `command, help, parameters` | Adds or replaces one suggestion. |
| `chat:addSuggestions` | a list of `{ command, help, parameters }` | Adds or replaces several. |
| `chat:removeSuggestion` | `command` | Drops one, by name. |
| `chat:clearSuggestions` | — | Drops all of them. |
| `chat:clear` | — | Empties the log. |
| `chat:setEnabled` | `boolean` | `false` closes the box and refuses to open it. |

A message's `type` becomes the line's CSS class — the resource itself uses
`chat`, `info` and `error`. `color` is `{ r, g, b }` and tints the author tag
only. `author` is rendered as text and never as markup: a display name is
something a player chose.

!!! note "An author is a label, never an identity"

    The server attributes every relayed message to `source`, the authenticated
    connection inside the net event handler — never to a name in the payload. A
    client cannot speak as somebody else. The display name shown in the box is
    read server-side from `Open77.players.name`, and falls back to
    `player <id>`.

## The box

- **History.** ++arrow-up++ and ++arrow-down++ walk back through what *you*
  typed this session — the page keeps the last 40 submitted lines, separately
  from the log. Walking past the newest entry gives you an empty input back.
  While the completion list is up the arrow keys move the selection in it
  instead; history takes over once there is nothing to select.
- **Completion.** ++tab++ replaces the input with the selected command plus a
  trailing space. The list appears only while the input starts with `/` and has
  no space in it yet, matches on prefix, sorts by name and shows at most eight
  rows. It is drawn above the input, because a list growing downward from a box
  at the bottom of the screen would leave the screen.
- **Submit and cancel.** ++enter++ sends the line and closes the box; ++escape++
  closes it without sending. The box closes on submit either way, including
  when a command is refused before it is sent.
- **The fade.** Lines are visible for `FADE_MS` and then fade out while the box
  is closed. Opening it brings the whole retained log back, and a new message
  resets the timer for every line on screen. `FADE_MS = 0` never fades. The log
  is history, not furniture.
- **Focus.** The surface lives on the `hud` layer and takes keyboard focus
  **explicitly, and only while it is open** — focus on open, released on close.
  It is requested *before* the page is told to open, because both travel the
  same ordered pipe and the element focus has to land in a browser that already
  holds focus. If focus is refused the client logs `keyboard focus was refused;
  the box will take no text` rather than leaving a box that silently ignores
  typing.

!!! tip "Refusals are printed, never silent"

    "The key does nothing" has three different causes, and each is logged as
    itself: the surface was never created, the chat was disabled by the server
    with `chat:setEnabled`, or keyboard focus was refused.

## Limits and rate

| Limit | Where | Behaviour |
|---|---|---|
| `MAX_LENGTH` (240) | Both | The input carries a `maxlength`; the server also truncates to `MAX_LENGTH` and appends `...`. Everything off the wire is treated as hostile. |
| `RATE_MS` (800) | Server | A floor between two messages from the same player. A message inside the floor is dropped silently. Commands do not pass through here and are not affected. |
| `HISTORY` (60) | Page | Lines kept on screen; older ones fall off the top. |
| 40 typed lines | Page | The ++arrow-up++ recall buffer. Not configurable. |
| 32 tokens | Client | The transport's cap on a command line, refused here rather than dropped by the host. |

Control characters in a message are replaced with spaces before it is relayed:
a newline in a payload would forge a line in everybody's box. Blank and
whitespace-only messages are dropped.

## Configuration

`config.lua`, loaded on both sides. The page is sent everything but `RATE_MS`,
which is a server rule.

```lua
OPX_CHAT_CONFIG = {
  ANCHOR = "bottom-left", -- "bottom-left" | "top-left"
  WIDTH = 620,            -- box width in pixels, at a 1920-wide surface
  HISTORY = 60,           -- messages kept on screen; older ones fall off the top
  FADE_MS = 12000,        -- how long a message stays visible when the box is closed; 0 never fades
  MAX_LENGTH = 240,       -- the longest message a player may send
  RATE_MS = 800,          -- floor between two messages from the same player
}
```

| Key | Default | Meaning |
|---|---|---|
| `ANCHOR` | `"bottom-left"` | Which corner the box sits in. `"top-left"` is the only alternative; any other value reads as bottom-left. |
| `WIDTH` | `620` | Box width in pixels, against a 1920-wide surface. Ignored unless it is a positive number. |
| `HISTORY` | `60` | How many lines the log keeps. |
| `FADE_MS` | `12000` | How long a line stays visible once the box is closed. `0` disables the fade entirely. |
| `MAX_LENGTH` | `240` | The longest message a player may send. Enforced on the server as well as in the input. |
| `RATE_MS` | `800` | Minimum gap between two messages from one player. Server-side only. |

## Layering

The surface is created on the `hud` layer at `zIndex = 700`, 1920×1080,
transparent, 60 fps, and **visible from creation** — a surface created hidden
never uploads a frame once shown.

`hud` rather than `menu` is the deliberate half: a `hud` surface takes focus
only when it asks for it, which is exactly this box's rule — focused while
open, never otherwise. The compositor draws by layer first and `zIndex` second,
higher on top, so the number only orders this surface against the others
OPX//77 puts on `hud`:

| Surface | Layer | `zIndex` |
|---|---|---|
| `opx77_chat` | `hud` | 700 |
| [`opx77_hud`](opx77_hud.md) | `hud` | 705 |
| [`opx77_menu`](opx77_menu.md) | `hud` | 725 |

A chat that opens under a menu is a chat nobody can read what they are typing
in. If you re-theme these surfaces, keep the box above anything a player can
have open at the same time as the input line — and change it where it is
declared, in `WebUI.create`, not in CSS, which cannot reach across surfaces.

!!! warning "The shipped number and the comment beside it disagree"

    The comment above `zIndex = 700` in `client/main.lua` reads *"above
    `opx77_hud` (705) and `opx77_menu`"*, but 700 draws **below** both, and
    `opx77_menu` describes its own 725 as *"above chat (700)"*. 700 is also the
    value the platform's own chat resource uses, so the shipped ordering is
    consistent with the platform and it is the comment that is wrong. Read the
    table above as the truth, and expect one of the two to move.

## See also

- [`opx77_core`](opx77_core.md) — `OPX.CommandResult`, and the suggestion list
  the example above is taken from.
- [`opx77_menu`](opx77_menu.md) and [`opx77_hud`](opx77_hud.md) — the other two
  surfaces on the `hud` layer.
