---
title: opx77_chat
description: opx77_chat owns the OPX//77 chat box and is the only path a slash command typed in game takes to the server's authenticated dispatcher.
---

# opx77_chat

The chat box, and the only path a typed command takes to the server.

| At a glance | |
|---|---|
| **Version** | `0.2.0` |
| **Requires** | `open77_version ">=0.0.1"`. Nothing else in OPX//77 |
| **Auto start** | yes |
| **Reload policy** | `reconnect` — a CEF surface is never replaced in place |
| **Permissions** | `network.events` |
| **Sides** | client, plus a server half that relays messages and nothing else |
| **Exports** | six, all client-side — see [Exports](exports.md) |
| **Commands** | **none of its own.** It carries everybody else's — see [Events](events.md#command-path) |
| **Events** | the message path, the command path and the suggestion protocol — see [Events](events.md) |
| **Locales** | `en` and `fr`; [`LOCALE`](config.md#locale) picks one. Logs stay English — see [below](#locales) |
| **Conflicts with** | `open77_chat`, the official package it replaces. See [below](#official-package-conflict) |

## What it is {#what-it-is}

`opx77_chat` owns one WebUI surface — a log, an input line and a completion list — and one
job besides drawing it: turning a typed line into something the server can act on.

A line that does not start with `/` is a message. It goes to this resource's own server half
on `chat:submit`, and comes back to every client on `chat:addMessage`, attributed to the
authenticated connection that sent it and never to a name in the payload. A line that starts
with `/` is a command, and it does **not** go to this resource's server half at all: the
client tokenises it and triggers `open77:command:execute` on the **host's** dispatcher, which
resolves the caller's ACL before any resource Lua runs. Both routes are traced end to end in
[Events](events.md).

The open key belongs to the host, not to this resource. The host raises `open77:chat:open`
when the player presses it and there is no binding here; `chat:open` and `chat:close` are
handled too, so another resource on the same client can open or close the box.

!!! danger "Without `opx77_chat`, nothing typed in game reaches the server"

    Slash commands travel on the host's authenticated dispatcher, and this is the resource
    that tokenises a line and hands it over. Every `RegisterCommand` in every other resource
    stays reachable from the server console and from `startup.commands` — but from a player's
    keyboard, only through this box. Its own client half says so when the surface fails to
    come up:

    ```text
    WebUI surface failed: <reason>
      no command typed in chat will reach the server.
    ```

## The pages {#pages}

- **[Exports](exports.md)** — the six client exports, deliberately the same names and
  arguments the platform documents on its own `open77_chat` package.
- **[Events](events.md)** — every event in and out, split by networked and non-networked, and
  the full path a typed slash command takes to the dispatcher.
- **[Configuration](config.md)** — the seven keys in `config.lua`.

## The box {#the-box}

- **History.** ++arrow-up++ and ++arrow-down++ walk back through what *you* typed this
  session — the page keeps the last 40 submitted lines, separately from the log. Walking past
  the newest entry gives you an empty input back. While the completion list is up the arrow
  keys move the selection in it instead; history takes over once there is nothing to select.
- **Completion.** ++tab++ replaces the input with the selected command plus a trailing space.
  The list appears only while the input starts with `/` and has no space in it yet, matches on
  prefix, sorts by name and shows at most eight rows. It is drawn above the input, because a
  list growing downward from a box at the bottom of the screen would leave the screen.
- **Submit and cancel.** ++enter++ sends the line and closes the box; ++escape++ closes it
  without sending. The box closes on submit either way, including when a command is refused
  before it is sent.
- **The fade.** Lines are visible for `FADE_MS` and then fade out while the box is closed.
  Opening it brings the whole retained log back, and a new message resets the timer for every
  line on screen. `FADE_MS = 0` never fades. The log is history, not furniture.
- **Focus.** The surface lives on the `hud` layer and takes keyboard focus **explicitly, and
  only while it is open** — focus on open, released on close, and released again on resource
  stop before the page handle is dropped. It is requested *before* the page is told to open,
  because both travel the same ordered pipe and the element focus has to land in a browser
  that already holds focus.

Refusals are printed, never silent. "The key does nothing" has four different causes and each
is logged as itself:

| Logged | Cause |
|---|---|
| `open refused: the WebUI surface was never created` | `WebUI.create` failed at start. There is no box, and there never will be in this generation. |
| `open refused: the chat is disabled by the server` | Something called `chat:setEnabled(false)` or the `setEnabled` export. |
| `open refused: the page has not reported ready` | The page has not raised `chat:ready` yet. `opened` is deliberately left false, so the next press succeeds the moment it does. |
| `keyboard focus was refused; the box will take no text` | The surface exists and opened, but the host would not hand over the keyboard. |

!!! warning "The ready check is what keeps the keyboard from locking"

    Taking keyboard focus before the page reports ready captures the keyboard with the entry
    line still hidden, and the only ++escape++ handler bound to an input nobody can see —
    game input is suppressed with no way out. That is why the third refusal exists and why it
    leaves `opened` false rather than latching it.

## Limits and rate {#limits}

| Limit | Where | Behaviour |
|---|---|---|
| `MAX_LENGTH` (240) | Both | The input carries a `maxlength`; the server truncates to `MAX_LENGTH` **characters** and appends `...`. Everything off the wire is treated as hostile, and the two sides count a character differently at the boundary — see [Configuration](config.md#max-length). |
| `RATE_MS` (800) | Server | A floor between two messages from the same player. A message inside the floor is dropped silently. Commands do not pass through here and are not affected. |
| `HISTORY` (60) | Page | Lines kept on screen; older ones fall off the top. |
| 40 typed lines | Page | The ++arrow-up++ recall buffer. Not configurable. |
| 32 tokens | Client | The transport's cap on a command line, refused here rather than dropped by the host. |

Control characters in a relayed message are replaced with spaces before it goes out: a newline
in a payload would forge a line in everybody's box. Blank and whitespace-only messages are
dropped.

## Player-facing text {#locales}

Every sentence this resource writes itself comes from a catalogue in `locales/`, and
[`LOCALE`](config.md#locale) in `config.lua` picks which one. `en` and `fr` ship;
`shared/locale.lua` publishes the one global every file below it uses, `locale(key, params)`,
and a key missing from the chosen catalogue falls back to `en` and then to the key itself.

It is a short list, because this resource mostly carries other people's text:

| Rendered from the catalogue | Where |
|---|---|
| The four command-line refusals | A red `COMMAND` line, before anything is sent |
| `The command could not be sent.` and `The message could not be sent.` | A red `NETWORK` line, when the trigger itself is refused |
| The `COMMAND` and `NETWORK` author tags | Every line this resource writes itself |
| `player <id>` | The author on a relayed message, when the host has no display name for that connection |
| The input's placeholder | Sent to the page with the rest of the config |

The page has no words of its own — every string it draws arrives from Lua already translated,
the placeholder included — so there is no second catalogue in `web/`.

Nothing else moves. A line another resource sends on
[`chat:addMessage`](events.md#chat-addmessage) is drawn exactly as it arrives, and so is the
dispatcher's answer on [`open77:command:result`](events.md#open77-command-result), including its
`unknown_command` and `permission_denied:` codes. The client log stays English whatever the
locale is.

## Layering {#layering}

The surface is created on the `hud` layer at `zIndex = 700`, 1920×1080, transparent, 60 fps,
and **visible from creation** — a surface created hidden never uploads a frame once shown.

`hud` rather than `menu` is the deliberate half: a `hud` surface takes focus only when it asks
for it, which is exactly this box's rule. The compositor draws by layer first and `zIndex`
second, higher on top, so the number only orders this surface against the others OPX//77 puts
on `hud`:

| Surface | Layer | `zIndex` |
|---|---|---|
| `opx77_chat` | `hud` | 700 |
| [`opx77_hud`](../opx77_hud/index.md) | `hud` | 705 |
| [`opx77_menu`](../opx77_menu/index.md) | `hud` | 725 |

700 draws **below** both, which is the platform's own number for its chat and the ordering
`opx77_menu` already assumes. It is tolerable because the box holds keyboard focus only while
it is open and the host does not raise the open key while another surface owns focus, so a
menu and an open input line are not on screen together. If you re-theme these surfaces, change
the number where it is declared, in `WebUI.create` — not in CSS, which cannot reach across
surfaces.

## Running alongside the official `open77_chat` {#official-package-conflict}

`opx77_chat` replaces the platform's own `open77_chat` package. It is not an addition to it,
and the two cannot both be loaded.

If both are running, the server half warns once at boot:

```text
open77_chat is running and is the package this one replaces
  both draw their own chat box, both answer chat:addMessage and both take
  focus on the open key, so every message is rendered twice. Drop one from
  resources.load in server.jsonc.
```

What actually goes wrong:

- **Two CEF surfaces.** Each package declares its own `web_ui_page` and creates its own
  `WebUI.create` surface. Both are on screen at once.
- **Every message rendered twice.** A server event fans out to every resource VM that
  registered the name, and both packages call `RegisterNetEvent("chat:addMessage", …)`. Both
  server halves also relay `chat:submit` to every client, so one typed line plausibly becomes
  four rendered lines rather than two.
- **Both take the keyboard on the open key.** Both bind `open77:chat:open` and both call
  `setFocus(true, …)`. Which surface ends up with the keyboard is a race.

There is no export collision: `Open77.exports.call` is resource-scoped, so a caller naming
`open77_chat` can never reach `opx77_chat` and vice versa. The conflict is entirely in the
shared event names and the shared surface.

The check is a `GetResourceState("open77_chat")` from a deferred thread rather than at file
scope — a conflicting resource listed after this one in `resources.load` is still `discovered`
at load time, and the warning would silently depend on load order. Server resources cannot
call each other on this platform, so asking the host is the only way to ask at all; see
[Integration channels](../../concepts/integration-channels.md).

## See also {#see-also}

- [`opx77_core`](../opx77_core/index.md) — `OPX.CommandResult`, and the suggestion list every
  chat client is answered with.
- [Getting started](../../guides/getting-started.md) — granting `command.*` permissions in
  `acl.jsonc`.
- [The export contract](../../concepts/export-contract.md) — the three-level failure model
  every call on this page obeys.
