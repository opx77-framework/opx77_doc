---
title: opx77_chat configuration
description: The nine keys of OPX_CHAT_CONFIG in opx77_chat/config.lua — where the box sits and how far above its corner, how wide it is, how much it keeps, how long lines stay visible, the two limits on what a player may send, whether a refused command is a toast, and the locale its own text is read from.
---

# Configuration

Everything below lives in `opx77_chat/config.lua`. **The value shown in each fence is the
shipped default**, so a key you never touch behaves exactly as written here.

```lua
--- @author DemiAutomatic
--- @file config.lua
--- @description Operator configuration for the box, message caps and command feedback.
--- @field ANCHOR {string} bottom-left or top-left; anything else reads as bottom-left.
--- @field OFFSET {integer} Pixels above the anchored inset on 1080 high; 0..1080.
--- @field WIDTH {integer} Box width in pixels on the 1920-wide surface.
--- @field HISTORY {integer} Messages kept on screen; older ones fall off the top.
--- @field FADE_MS {integer} Milliseconds a line stays visible while closed; 0 never fades.
--- @field MAX_LENGTH {integer} Longest message a player may send, in characters.
--- @field RATE_MS {integer} Milliseconds between two messages from one player.
--- @field NOTIFY {boolean} Refused commands as opx77_notify toasts; false prints a red line.
--- @field LOCALE {string} Catalogue code in locales/ player-facing text is read from.

OPX_CHAT_CONFIG = {
	ANCHOR = 'bottom-left',
	OFFSET = 155,
	WIDTH = 620,
	HISTORY = 60,
	FADE_MS = 12000,
	MAX_LENGTH = 240,
	RATE_MS = 800,
	NOTIFY = true,
	LOCALE = 'en',
}
```

`config.lua` is one `shared_script`, so both halves read the same table. The page is sent
everything except `RATE_MS`, which is a server rule with no meaning in the browser,
[`NOTIFY`](#notify), which the client's Lua reads before anything reaches the page, and
[`LOCALE`](#locale), which never crosses as a code at all — the page is sent the one string it
has to draw, already translated:

```lua
send('chat:config', {
	anchor = Config.ANCHOR,
	offset = Config.OFFSET,
	width = Config.WIDTH,
	history = Config.HISTORY,
	fadeMs = Config.FADE_MS,
	maxLength = Config.MAX_LENGTH,
	placeholder = locale('chat.placeholder'),
})
```

The page validates each value on the way in and keeps its own built-in default for anything
that does not survive: an `OFFSET` outside `0..1080`, a `WIDTH` that is not a finite number
above zero, a `HISTORY` that is not above zero, a negative `FADE_MS` or a `MAX_LENGTH` that is
not above zero are ignored rather than applied. A wrong value therefore shows up as "the setting did nothing", not as a
broken box.

Changing any of these needs a restart of `opx77_chat`. There is no live reload of the config
table and no tunable declaration.

## ANCHOR {#anchor}

Which corner the box sits in.

```lua
ANCHOR = 'bottom-left',
```

**Type** `"bottom-left" | "top-left"`

`"top-left"` is the only alternative; **any other value reads as bottom-left**, because the
page tests for the one string and falls through. The completion list is always drawn above the
input, whichever anchor is in use, so a list growing downward from a box at the bottom of the
screen cannot leave the screen.

## OFFSET {#offset}

How far the box sits from its anchored edge, in pixels past the standard inset, measured
against the 1080-high surface.

```lua
OFFSET = 155,
```

**Type** `integer` — `0..1080`; `0` puts the box back on the inset

Shipped at 155 so the box clears [`opx77_hud`](../opx77_hud/index.md) in the same corner: its
gauges end 130 px above the bottom of the 1080-high surface and
[`opx77_status`](../opx77_status/index.md)'s chip strip 171 px, and the box starts 12 px above
that. No resource can read another's config, so moving the HUD or the strip means setting this
again. Whatever it is set to, the column stays on screen: the oldest log lines give way before
the suggestions or the input line do. A value outside `0..1080`, or not a number, is ignored
and the page keeps its own default.

## WIDTH {#width}

The width of the box in pixels, measured against the 1920-wide surface rather than against the
player's real resolution.

```lua
WIDTH = 620,
```

**Type** `number`

The surface is created at a fixed 1920×1080 and scaled by the compositor, so this is a
proportion in disguise: 620 is a shade under a third of the screen at any resolution. Ignored
unless it is a finite number above zero.

## HISTORY {#history}

How many lines the log keeps on screen. Older ones fall off the top.

```lua
HISTORY = 60,
```

**Type** `integer`

This is the rendered log, not the recall buffer: ++arrow-up++ walks back through the last **40
lines you typed**, which is a separate list in the page and is not configurable.

## FADE_MS {#fade-ms}

How long a line stays visible once the box is closed.

```lua
FADE_MS = 12000,
```

**Type** `integer` — milliseconds; `0` never fades

Opening the box brings the whole retained log back, and a new message resets the timer for
every line on screen. The log is history, not furniture — a faded line is hidden, not deleted,
and `HISTORY` is what actually drops it.

## MAX_LENGTH {#max-length}

The longest message a player may send.

```lua
MAX_LENGTH = 240,
```

**Type** `integer` — characters, not bytes

Enforced twice, and the second one is the one that counts. The page sets it as the input's
`maxlength` attribute, which is a convenience; the server also truncates any `chat:submit` to
`MAX_LENGTH` and appends `...`, because everything off the wire is treated as hostile.

The server counts **characters**, by counting UTF-8 lead bytes, so a cut never lands in the
middle of a multi-byte one. `shared/text.lua` does the measuring: `OpxChat.Text.Clean` skips
the measuring entirely when the whole line is already no longer in bytes than the cap is in
characters, and otherwise asks `span`, a function local to that file, for the byte length of
the first `MAX_LENGTH` characters.

The scan `span` runs is **bounded in bytes** at `maximum * 4` — the widest a UTF-8
character can be — so a line made of continuation bytes, which start no character at all, is
walked four times the cap and no further rather than to its end.

!!! info "The two sides count differently at the boundary"

    HTML's `maxlength` counts UTF-16 code units; the server counts Unicode characters. They
    agree across the Basic Multilingual Plane — all of Latin, Greek, Cyrillic, Hebrew, Arabic
    and CJK — and diverge on astral characters, which is emoji and the rarer CJK extensions:
    the page counts one of those as two and the server as one. A line of emoji is therefore
    stopped by the input at half of `MAX_LENGTH`. That is left as it is, because it is the safe
    direction: the server is the side that must not be outrun, and it is the more generous of
    the two.

!!! warning "It bounds the relay, not what another resource may send"

    `MAX_LENGTH` is applied to player messages arriving on `chat:submit`. A line your own
    resource sends with [`chat:addMessage`](events.md#chat-addmessage) — a command's report
    included — is not truncated by anything. Long lines wrap in the box rather than being cut.

## RATE_MS {#rate-ms}

The floor between two messages from the same player.

```lua
RATE_MS = 800,
```

**Type** `integer` — milliseconds

Server-side only. A message that arrives inside the floor is **dropped silently** — the sender
is not told, on purpose: an answer would cost more than the message it refused. The timestamp
is kept per session player id and cleared on `onPlayerDisconnected`. It moves for every
message outside the floor, including a blank one that is then dropped, so a flood of
whitespace does not buy a scan per packet. The clock is `Open77.time.monotonic`; when it cannot
be read the server falls back to `GetGameTimer` and logs that once, rather than freezing the
floor.

!!! warning "Commands are not rate limited here"

    `RATE_MS` guards `chat:submit`, the message path. A slash command goes straight to the
    host's dispatcher on `open77:command:execute` and never passes through this resource's
    server half, so it is not affected. If a command of yours needs a floor, put one in your
    own handler — `opx77_weather` floors its two open commands at 2 s per player and leaves
    the ACL-gated ones alone.

## NOTIFY {#notify}

Whether a refused command is an `opx77_notify` toast or a red line in the box.

```lua
NOTIFY = true,
```

**Type** `boolean` — only `false` turns it off

Client-side only. With it on, a refusal on
[`open77:command:result`](events.md#open77-command-result), a command line that could not be
split into tokens and a command the transport would not send are each a toast titled
`COMMAND`, in one slot the next one replaces. With `false` each is the red `COMMAND` line it
used to be. The toast is best-effort either way: while `opx77_notify` is not running, or when it
refuses the toast, the line is written instead and the client log says so once —
`opx77_notify` is never a dependency.

It governs refusals only. An **accepted** command result prints nothing whatever this is set
to, and a chat message that could not be sent stays a `NETWORK` line in the box.

## LOCALE {#locale}

Which catalogue in `locales/` the box's own text is read from.

```lua
LOCALE = 'en',
```

**Type** `string` — a code registered in `locales/`. `en` and `fr` ship.

`shared/locale.lua` calls `OpxChat.Locale.Set` with this value at load, on both halves, which is what
makes the key do anything at all; it is listed after `config.lua` in the manifest for exactly
that reason. An unknown code is **accepted** rather than refused, because the catalogues
register after that file loads and there is nothing to check it against yet. Every lookup then
falls back to `en`, and then to the key itself, so an untranslated string shows the player its
raw key rather than nothing.

Both halves read it: the client renders the command refusals, the toast title, the author tags
and the placeholder, and the server renders the `player <id>` fallback author on a relayed
message.
[Player-facing text](index.md#locales) lists everything it reaches — which is only what this
resource writes itself, and never a line another resource hands it.

## See also {#see-also}

- [Events](events.md) — what each of these limits actually guards.
- [Overview](index.md#limits) — every limit in the resource in one table, including the ones
  that are not configurable.
