---
title: opx77_hud commands
description: The /hud chat command, which lets any player show or hide their own HUD without any permission, the chat suggestion opx77_hud registers for it, and the rebindable F8 key that does the same.
---

# Commands

`opx77_hud` registers exactly one command, and it is registered **server-side
only** — on this platform a chat command cannot be registered from the client, so
`server/main.lua` exists for this and nothing else. The same toggle is also
bound to a [rebindable key](#key), which works on the client alone.

## Show or hide your HUD {#hud}

!!! info "No permission required"
    `/hud` is open to **every** player. It is registered with a restricted flag of
    `false`, there is no ACL check anywhere in the handler, and hiding your own HUD
    is not an operator action. Nobody can use it to change anybody else's screen.

```
/hud [on|off]
```

- on|off?: `string`
    - `on` or `show` shows the HUD; `off` or `hide` hides it. Omit the argument
      to toggle. The argument is lower-cased before it is matched.
    - Default: toggle.

| Typed | Result |
|---|---|
| `/hud` | toggle |
| `/hud on`, `/hud show` | show |
| `/hud off`, `/hud hide` | hide |
| anything else | `usage: /hud [on\|off]`, a warning toast, and nothing changes |

The server decides nothing about the HUD. It turns the typed word into a mode,
sends that mode straight back to the same player on the
[`opx77_hud:visibility`](events.md#visibility) net event, and the client half
calls the same code path [`setVisible`](exports.md#setvisible) calls. A word it
does not recognise is answered with a warning toast carrying the usage line,
sent on [`opx77_hud:notice`](events.md#notice) and raised by the client half
through `opx77_notify`, and nothing else happens. Showing or hiding answers
nothing: the HUD going up or down is the answer. `opx77_notify` stays optional —
while it is stopped, or with [`NOTIFY = false`](config.md#notify), the same text
is a chat line instead, and the client log says so once. None of it goes on
`open77:command:result`, whose accepted answers `opx77_chat` does not print.

Typing it from the server console, where there is no player to answer, logs one
line saying it is a player command.

!!! warning "The choice survives a character switch"
    Visibility is a client-side flag that lives beside the character snapshot, not
    inside it. `opx77:client:onPlayerUnloaded` clears the character and leaves the
    flag alone, so a player who typed `/hud off` before switching characters comes
    back to a hidden HUD. The flag resets to visible only when the client
    reconnects — which, given the `reconnect` reload policy, is also the only way
    this resource restarts.

### Example {#hud-example}

```
/hud off
```

The player's HUD goes down. Nothing else in the framework puts it back: a
resource that hid the HUD for a cutscene must restore it itself, and it will be
restoring it on top of a flag the player may have set deliberately.

## The chat suggestion {#suggestion}

On `chat:ready` the server half registers the command's completion metadata with
the chat resource, throttled to **once per ten seconds per player**.

```lua
TriggerClientEvent('chat:addSuggestion', player, '/' .. name,
	locale('hud.commandHelp'),
	{ { name = 'on|off', help = locale('hud.commandArgument'), optional = true } })
```

Both strings come from this resource's own catalogue, so the suggestion is in the
language [`LOCALE`](config.md#locale) names; on the shipped `en` they read
"Show or hide your HUD" and "omit to toggle". The argument is marked optional, so
the chat box draws it as `[on|off]` and shows its help while it is typed. The
usage line the server answers a bad argument with comes from the same place.

The throttle is not cosmetic: `chat:ready` is a net event, free for a client to
send as often as it likes, and it was otherwise answered every time. It is
measured on `GetGameTimer`, the server scheduler's monotonic milliseconds. The
per-player record is dropped on `onPlayerDisconnected`; a player id there that
will not convert to a number is logged as a warning rather than clearing a slot
no player holds.

!!! warning "The host never emits `playerDropped`"
    That name is emitted by no OPEN//77 binary, and a handler for it never runs.
    `onPlayerDisconnected` is the departure event for an admitted player;
    `onPlayerRejected` also exists, for connections refused before admission,
    which a HUD has no reason to listen for. If you copied a `playerDropped`
    handler from a FiveM resource, it is dead code in yours.

## The show/hide key {#key}

| Mapping id | Name in the pause menu | Default | Does |
|---|---|---|---|
| `opx77_hud.toggle` | *HUD: show or hide* (`hud.key.toggle`) | `F8` | what `/hud` with no argument does |

The key is declared with `RegisterKeyMapping` when the resource starts, so the
pause menu's key bindings tab lists it under the name above, read from the
configured [locale](config.md#locale), and every player can rebind it there. It
needs `input.actions`, which the manifest declares.

- It toggles **on the client**, without the round trip the command makes. Like
  the command it needs no permission, and it changes only the player's own
  screen.
- A press while another surface holds the keyboard — the chat box, an
  `opx77_input` form, the pause menu — does nothing, so a key typed into one of
  them never hides the HUD.
- [`KEYS.TOGGLE`](config.md#keys) sets the default, which a player's own binding
  overrides. `KEYS.TOGGLE = false` registers no mapping; the command and the
  exports are unaffected.
- A refused registration is one client log warning,
  `key mapping opx77_hud.toggle (F8) not registered: <reason>`, and the HUD
  keeps working through the command.

## Turning the command off {#no-command}

Set [`COMMAND`](config.md#command) to `false` or an empty string. Nothing is
registered, no suggestion is offered, and the server half logs one informational
line at startup. The exports and the [show/hide key](#key) still work, and the
HUD still draws — the `network.events` grant buys the command, its suggestion and
its answers, and nothing else.
