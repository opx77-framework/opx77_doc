---
title: opx77_admin exports
description: The three client exports of opx77_admin — open, close and state — what each answers, why open answering ok means asked rather than allowed, and the side each can be called from.
---

# Exports

Three exports, all **client-side**: a resource on the player's machine can put
the staff menu up, take it down, and ask whether it is up. None of them
authorises anything. [The client export contract](../../concepts/export-contract.md)
covers the call shape and its three levels of failure.

Every call answers a table carrying `ok` and never raises — an
[`AdminResponse`](types.md#adminresponse). Read anything but `ok = true` as a
refusal.

!!! info "Called from another resource, always"

    Each export reads the caller from `GetInvokingResource()` and answers
    `export_call_required` when there is none, or when the name it answers is
    not a plausible resource name. A caller cannot claim to be another resource.

## open {#open}

Asks for the staff menu, for the local player.

```lua
Open77.exports.call("opx77_admin", "open")
```

It sends `/opx77.admin` through `open77:command:execute`, exactly as the chat
box and the [menu key](config.md#keys) would, so the host resolves
`command.opx77.admin` against **this player's** ACL like a typed command.

!!! warning "`ok = true` means asked, not allowed"

    A player without the grant gets the host's refusal, which `opx77_chat`
    toasts, and no menu. The export cannot tell, because the answer to a command is not a
    return value. A resource that wants to know whether the menu appeared asks
    [`state`](#state) a moment later.

**Returns** an [`AdminResponse`](types.md#adminresponse):

| Answer | Means |
|---|---|
| `ok = true, queued = true` | the opener command was sent; the host decides the rest |
| `ok = true, open = true` | the menu, or a form it put up, is already on screen; nothing was sent |

Running the opener while the menu is up closes it, which is why `open` does not
send it a second time.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |
| `menu_not_running` | `opx77_menu` is not running, so there is nothing to draw on. |
| `not_sent` | `TriggerServerEvent` refused the command line. One log line names the reason. |

**Side** `client export`.

## close {#close}

Takes the staff menu, and any form it put up, down.

```lua
Open77.exports.call("opx77_admin", "close")
```

**Returns** `{ ok = true }`, whether or not anything was up. The menu is closed
through `opx77_menu`'s and `opx77_input`'s own `close` on a thread, so it goes a
moment later.

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |

**Side** `client export`.

## state {#state}

Whether the staff menu is up, and which screen.

```lua
Open77.exports.call("opx77_admin", "state")
```

**Returns** an [`AdminState`](types.md#adminstate):

| Field | Is |
|---|---|
| `open` | the menu, or a form it put up, is on screen |
| `screen` | the screen on top of the stack — `"root"`, `"players"`, `"player"`, `"confirm"` and the others — or `nil` when none is |

**Errors**
| Code | Meaning |
|---|---|
| `export_call_required` | No invoking resource. |

**Side** `client export`.

### Example {#state-example}

```lua
-- in a client script of your own resource: a ripperdoc terminal that doubles as a staff desk
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_admin", "open")
  if not promise then return print("not dispatched: " .. tostring(reason)) end
  local asked = promise:await()
  if type(asked) ~= "table" or asked.ok ~= true then return end

  Wait(1000)
  local state = Open77.exports.call("opx77_admin", "state")
  local answer = state and state:await()
  if type(answer) == "table" and answer.ok == true and not answer.open then
    -- the host refused this player command.opx77.admin; opx77_chat already toasted it
  end
end)
```

## See also {#see-also}

- [Commands](commands.md#opx77-admin) — the opener command the `open` export
  sends.
- [Types](types.md#adminresponse) — the answer shapes.
