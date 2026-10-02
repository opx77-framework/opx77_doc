---
title: chat module
description: The in-game chat box, which carries player messages and is the only way a typed slash command reaches the host's command dispatcher.
---

# chat

The chat module draws the chat box: a log of recent lines at the top of the screen and an input line that opens on a key (`T` by default). A line that does not start with `/` is sent to every player, under the speaker's character name. A line that starts with `/` is split into arguments and sent to the host's command dispatcher, which checks the ACL and runs the command; refusals come back as toasts. Without this module, commands can only be run from the server console. The module checks no permission and saves nothing.

| | |
|---|---|
| Side | both |
| Requires | none |
| Optional | `character` (author names), `downed` (box hides and refuses to open while down) |
| Configuration | `config/chat.lua` (shared script) |
| Contract | `chat` v1 — client |
| Data | none |

## Client contract {#client-contract}

`local chat = OPX.Api.Get('chat')` on the client, from code inside opx_infinity. Every function answers `{ ok = true, value = … }` or `{ ok = false, error = code }`. None yields.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-chat-addmessage"></a>`AddMessage` | `message` | `true` | Adds a line to this player's log only. `message` is a string or `{ kind?, author?, text }`. `kind` decides the look: `say` (default), `chat`, `error`, `warning`. |
| <a id="client-chat-clearmessages"></a>`ClearMessages` | — | `true` | Empties this player's log. |
| <a id="client-chat-addsuggestion"></a>`AddSuggestion` | `command, help?, params?` or `{ command/name, help, parameters/params }` | `true` | Adds or replaces one completion in the input line. |
| <a id="client-chat-removesuggestion"></a>`RemoveSuggestion` | `command` | `true` | Removes one completion. |
| <a id="client-chat-setenabled"></a>`SetEnabled` | `enabled` | the new state | `false` closes the box and refuses to open it. |
| <a id="client-chat-isenabled"></a>`IsEnabled` | — | boolean | |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-chat-say"></a>`opx:net:chat:say` | client → server | `text` | A chat line. The server drops it if it comes within `RATE_MS` of the sender's last one, or is blank, cuts it to `MAX_LENGTH`, and broadcasts it to **every** player. |
| <a id="opx-net-chat-ready"></a>`opx:net:chat:ready` | client → server | none | The input line is up; asks for command completions. Answered at most once per `READY_MS`. |
| <a id="opx-net-chat-message"></a>`opx:net:chat:message` | server → client | `{ kind = 'chat', author, text }` | A line to add to the log. `author` is the character's first and last name, else the account name, else `player <id>`. |
| <a id="opx-net-chat-suggestions"></a>`opx:net:chat:suggestions` | server → client | `{ suggestions = { { name, help, params }, … } }` | Every command registered through `OPX.Command.Register` that this player may run. |
| <a id="opx-net-runtime-commandresult"></a>`opx:net:runtime:commandResult` | server → client | `{ type = 'info'/'error', author, text }` | Core's command read-back (`OPX.CommandResult`, used by `/opx.anim.list`, `/opx.elevators.where` and others). Chat draws it in the log. |
| <a id="opx-on-chat-submitted"></a>`opx:on:chat:submitted` | client local | `{ text, tokens }` | A slash command was typed, just before it is sent to the dispatcher. |
| <a id="opx-on-chat-view"></a>`opx:on:chat:view` | client local | `{ kind, surface, … }` | The seam between the state and the view; every update to the page passes here. |

Host events the client half uses: `open77:command:execute` (sends a command), `open77:command:result` (refusals become toasts), `open77:chat:open` (open the box; raised by the `T` mapping and by the platform's `open77_chat` if loaded), `open77:pauseKey` (closes the box).

## Page channels {#page-channels}

The log lives on the `overlay` surface and the input line on the `interactive` surface.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-chat-ready"></a>`chat:ready` | page → Lua | `{ surface }` | That half of the page is up; Lua sends its config (and completions for the input line). |
| <a id="page-chat-submit"></a>`chat:submit` | page → Lua | `{ text }` | The player pressed Enter. |
| <a id="page-chat-close"></a>`chat:close` | page → Lua | `{}` | Escape in the input line. |
| <a id="page-chat-diag"></a>`chat:diag` | page → Lua | `{ text }` | Written to the client log. |
| `chat:view` | Lua → page | `{ kind, surface, … }` | `kind` is `config`, `line`, `clear`, `visible`, `open`, `close`, `focus`, `suggest`, `unsuggest` or `suggestions`. |

## Configuration {#configuration}

`config/chat.lua` sets `OPX.Config.MODULES.chat`. Shared script: both halves read the length and rate limits.

| Key | Default | What it does |
|---|---|---|
| <a id="config-chat-enabled"></a>`enabled` | `true` | `false` switches the module off. Typed commands then have no way in. |
| <a id="config-chat-anchor"></a>`ANCHOR` | `'top-center'` | `bottom-left`, `bottom-center`, `top-left` or `top-center`; anything else reads as `bottom-left`. |
| <a id="config-chat-offset"></a>`OFFSET` | `48` | Pixels from the anchored edge on a 1080-high surface. |
| <a id="config-chat-width"></a>`WIDTH` | `620` | Box width on a 1920-wide surface. |
| <a id="config-chat-history"></a>`HISTORY` | `60` | Lines kept; older ones drop off. |
| <a id="config-chat-fade-ms"></a>`FADE_MS` | `12000` | How long a line stays visible while the box is closed. `0` never fades. |
| <a id="config-chat-max-length"></a>`MAX_LENGTH` | `240` | Longest message, in characters. |
| <a id="config-chat-rate-ms"></a>`RATE_MS` | `800` | Minimum milliseconds between two messages from one player. Faster ones are dropped silently. |
| <a id="config-chat-ready-ms"></a>`READY_MS` | `5000` | Minimum milliseconds between two completion lists for one player. |
| <a id="config-chat-notify"></a>`NOTIFY` | `true` | Refused commands as toasts; `false` writes a red line in the box instead. |
| <a id="config-chat-keys"></a>`KEYS` | `{ OPEN = 'T' }` | Default key to open the box; players rebind it in the pause menu. `false` registers none. |

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `chat.invalidMessage` | `AddMessage` got neither a string nor a table. |
| `chat.noView` | That half of the page has not reported ready yet. |
| `chat.invalidCommand` | A suggestion with no command name. |

Player-facing refusals for typed commands: `chat.tooManyArgs` (more than 32 arguments), `chat.escapeAtEnd`, `chat.unterminatedQuote`, `chat.commandExpected`, `chat.commandNotSent`, `chat.messageNotSent`, and the dispatcher answers `chat.command.unknown`, `chat.command.denied`, `chat.command.tooFast`, `chat.command.failed`.
