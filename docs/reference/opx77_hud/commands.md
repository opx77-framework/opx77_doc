---
title: opx77_hud commands
description: The /hud chat command, which lets any player show or hide their own HUD without any permission, and the chat suggestion opx77_hud registers for it.
---

# Commands

`opx77_hud` registers exactly one command, and it is registered **server-side
only** — on this platform a chat command cannot be registered from the client, so
`server/main.lua` exists for this and nothing else.

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
| anything else | `usage: /hud [on\|off]`, and nothing changes |

The server decides nothing about the HUD. It turns the typed word into a mode,
sends that mode straight back to the same player on the
[`opx77_hud:visibility`](events.md#visibility) net event, and the client half
calls the same code path [`setVisible`](exports.md#setvisible) calls. A word it
does not recognise is answered on `open77:command:result` — the usage line the
chat resource renders — and nothing else happens.

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
TriggerClientEvent("chat:addSuggestion", player, "/" .. name,
  locale("hud.commandHelp"),
  { { name = "on|off", help = locale("hud.commandArgument") } })
```

Both strings come from this resource's own catalogue, so the suggestion is in the
language [`LOCALE`](config.md#locale) names; on the shipped `en` they read
"Show or hide your HUD" and "omit to toggle". The usage line the server answers a
bad argument with comes from the same place.

The throttle is not cosmetic: `chat:ready` is a net event, free for a client to
send as often as it likes, and it was otherwise answered every time. The
per-player record is dropped on `onPlayerDisconnected`.

!!! warning "The host never emits `playerDropped`"
    An earlier build also cleaned up on `playerDropped`. That name is emitted by no
    OPEN//77 binary and the handler never ran; `onPlayerDisconnected` is the only
    departure event on this platform. If you copied that pattern from a FiveM
    resource, it is dead code in yours too.

## Turning the command off {#no-command}

Set [`COMMAND`](config.md#command) to `false` or an empty string. Nothing is
registered, no suggestion is offered, and the server half logs one informational
line at startup. The exports still work, and the HUD still draws — the
`network.events` grant buys the command and nothing else.
