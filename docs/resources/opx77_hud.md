# opx77_hud

The player HUD. Segmented gauges in the bottom-left corner, and a bare read-out
of money, job and street cred in the top-right.

**It reads [`opx77_core`](opx77_core.md) and draws. It decides nothing and
writes nothing.**

There is no state in this resource that another resource would want. The
character comes from the core, the status chips come from
[`opx77_status`](opx77_status.md), and everything on screen is a rendering of
one of those two. The only thing `opx77_hud` owns is the rectangle.

| | |
|---|---|
| Version | `0.1.0` |
| Reload policy | `reconnect` |
| Permissions | `network.events` |
| Exports | `setVisible`, `isVisible` |
| Command | `/hud` |

The surface is a WebUI page on the `hud` layer, 1920 × 1080 at 30 fps, `zIndex`
705, transparent. `web_ui_auto_create` is `false` in the manifest: the page is
created in `client/main.lua` instead, so a surface that fails to come up costs
one logged line rather than a resource that will not start.

!!! note "Why the reload policy is `reconnect`"

    The CEF surface is never replaced in place. Restarting the resource against
    a live client would leave the old page on screen, so the platform requires
    the client to reconnect.

## What it draws

Every frame is a list of rows built from the `PlayerData` snapshot the core
last handed over. A row is either a **bar**, which lands in the gauge block at
`ANCHOR`, or a **text** line, which lands in the info block at `INFO_ANCHOR`.

`Config.BLOCKS` names the builders that produce those rows, in order. The
shipped order is:

```lua
BLOCKS = { "vitals", "cyber", "needs", "money", "identity" }
```

Two rules apply to every bar:

- **Percent.** A value that is not a finite number reads as `0`. Anything else
  is clamped to `0..100` and rounded. The gauge is cut into ten blocks and the
  lit count is rounded *up*, so a bar with anything left in it never reads as
  empty. A change animates over 220 ms.
- **Tone.** At or below 15 the bar takes the `bad` role, at or below 33 the
  `warn` role, and above that the default one. Rows without a tone are drawn
  plain.

### `vitals` — health and armour

Reads `PlayerData.metadata.health` and `PlayerData.metadata.armor`.

`HP` is always drawn; a missing or malformed value reads as zero rather than
disappearing. `ARMOR` is drawn **only when it is above zero** — a character with
no armour has an empty row instead of a bar that says nothing. The armour row
carries no tone: low armour is not the warning that low health is.

### `cyber` — stamina

Reads `PlayerData.metadata.stamina`.

!!! info "Absent until a gameplay file fills it in"

    The core carries `stamina` in metadata and never reads it. Until something
    writes a number there, this block appends nothing and the row simply does
    not exist. That is the intended state on a bare install, not a fault.

When present, the row is hidden while the value is above `NEEDS_THRESHOLD`, on
the same rule as the needs below.

### `needs` — hunger and thirst

Reads `PlayerData.metadata.hunger` (drawn as `FOOD`) and
`PlayerData.metadata.thirst` (drawn as `HYDRATION`).

Each is skipped when the key is not a finite number, and hidden while the value
is **above `NEEDS_THRESHOLD`** — a full bar sitting permanently on screen says
nothing, so it waits until it has something to say. Set `NEEDS_THRESHOLD` to
`false` to always show them.

The needs themselves belong to the core, which decays them and applies their
consequences. This resource only draws the number.

### `money` — the purse

Reads `PlayerData.money`.

`EDDIES` and `BANK` lead, in that order. Every other **string** key in the purse
follows, sorted alphabetically — an operator's own money types appear without
this resource being told about them. A type whose amount is zero, or not a
finite number, is not drawn at all.

Amounts are formatted with a space between thousands and the sign kept in front
of the digits: `-1 250`.

!!! note "String keys only"

    A non-string key is dropped before sorting. Sorting mixed types raises, and
    it would raise inside the one thread that keeps this surface repaired.

### `identity` — job and street cred

Reads `PlayerData.job` and `PlayerData.metadata.streetCred`.

The job row is drawn when `job` is a table with a `label`. The label is the row
label, the value is `job.grade.name`, and the row takes the `on` tone when
`job.onDuty` is `true` — that is the whole on-duty indicator.

`CRED` is drawn from `metadata.streetCred` when it is a finite number greater
than zero, floored to a whole number.

## Exports

Both exports are **client-side**, and both answer a plain table.

| Export | Arguments | Answers |
|---|---|---|
| `setVisible` | `value: boolean` | `{ ok = true, visible = boolean }` |
| `isVisible` | — | `{ ok = true, visible = boolean }` |

`visible` is the resulting state, not the requested one. Any value other than
`false` shows the HUD.

The intended use is narrow: **hide it for a cutscene or a full-screen menu, and
show it again after.** Visibility is a property of the rectangle, not of the
character drawn in it — hiding the HUD does not stop it following the core, and
showing it again does not need a refresh.

```lua
CreateThread(function()
  local promise, reason = Open77.exports.call("opx77_hud", "setVisible", false)
  if not promise then return print(reason) end        -- dispatch failed
  local result, callError = promise:await()           -- resolution failed
  if callError or not result.ok then return end

  playTheCutscene()

  local restore = Open77.exports.call("opx77_hud", "setVisible", true)
  if restore then restore:await() end
end)
```

!!! warning "Both levels of failure"

    `Open77.exports.call` returns `promise, reason`; `promise:await()` returns
    `result, callError`. Checking only the first turns a remote error into a
    silent `nil`. See [the client export contract](../index.md#the-client-export-contract).

If you are hiding the HUD around something that can fail, restore it in the
same thread that hid it. Nothing else will put it back: the flag is this
resource's own and no other event resets it.

## How it follows the character

Three client events, raised by `opx77_core` on the client bus:

| Event | Effect |
|---|---|
| `opx77:client:playerLoaded` | adopts the snapshot, redraws |
| `opx77:client:playerDataChanged` | adopts the snapshot, redraws |
| `opx77:client:playerUnloaded` | drops the snapshot, hides the frame |

Each handler ignores a payload that is not a table, so a malformed event costs
nothing.

Underneath those, a thread re-reads the core every **5 seconds** as a safety
net, in case a change event was missed:

```lua
local promise, reason = Open77.exports.call("opx77_core", "GetPlayerData")
```

Two details make that read safe:

- **The core is checked before the call is dispatched.** If `opx77_core` is not
  in the `running` state, nothing is called and nothing changes on screen.
- **Only an authoritative refusal clears the HUD.** The snapshot is dropped when
  the core actually ran the export and answered `ok = false`. A call that never
  landed says nothing about the character, so the last frame stays up.

A core that is not running is therefore not a broken screen: the gauges simply
stop moving, and the only lines this resource ever logs are a WebUI surface
that failed to come up and diagnostics the page itself sends back.

!!! tip "A redraw that moves nothing sends nothing"

    Before each frame the rows are reduced to a cheap signature — id, label,
    value, percent, tone and icon of every row, plus the status chips. If it
    matches the last frame sent, the message is skipped. The 5-second poll
    therefore costs one export call and, most of the time, no repaint at all.
    The signature is forced only when the page reports itself ready, because a
    new DOM makes the previous signature describe something that no longer
    exists.

## The status strip

`opx77_status` publishes what it holds on the **`opx77:status:effects`** client
event. This resource listens, and carries the chips into the next frame rather
than sending them on their own, so the page never has two sources deciding when
it repaints.

The division is deliberate:

- **`opx77_status` owns the effect registry** — what an effect is, who added it,
  when it expires, how many one owner may hold.
- **`opx77_hud` owns that corner of the screen** — placement, theme and
  animation. It already has a surface there.

Two surfaces for one corner would have been two things to place, theme and keep
in step, which is why `opx77_status` ships with no surface of its own. Its
`ANCHOR` and `OFFSET` travel in the payload and the page honours them.

The payload is treated as untrusted input, because a client-side event name is
free for any resource on the machine to raise:

- at most **12** chips are kept from one payload;
- a chip without an `id` is dropped;
- `hidden` is coerced to a number, defaulting to `0`.

See [`opx77_status`](opx77_status.md) for the registry, the chip fields and the
exports that add and remove effects.

## The `/hud` command

The command is registered **server-side only**. There is no client-side
`RegisterCommand`, because on this platform a chat command cannot be registered
from the client.

| Typed | Result |
|---|---|
| `/hud` | toggle |
| `/hud on` or `/hud show` | show |
| `/hud off` or `/hud hide` | hide |
| anything else | `usage: hud [on\|off]` |

The server does not decide anything about the HUD; it turns the typed word into
a mode and sends it straight back to the same player on the
`opx77_hud:visibility` net event, where the client half calls the same
`setVisible` the export calls. A word it does not recognise is answered with the
usage line on `open77:command:result` and nothing else happens. It is open to
every player: hiding your own HUD is not an operator action, and typing it from
the console — where there is no player to answer — logs a line saying so.

On `chat:ready` the server also registers the chat suggestion, throttled to once
per ten seconds per player — `chat:ready` is a net event, free for a client to
send and otherwise answered every time.

!!! note "The choice survives a character switch"

    Visibility is a client-side flag that lives beside the snapshot, not inside
    it. `opx77:client:playerUnloaded` clears the character and leaves the flag
    alone, so a player who typed `/hud off` before switching characters comes
    back to a hidden HUD. It resets to visible when the client reconnects, which
    is also the only way this resource restarts.

Setting `COMMAND` to `false` or an empty string registers nothing and logs one
informational line at startup.

## Configuration

`config.lua` is a shared script: the client reads the layout, the server reads
the command name.

| Key | Shipped default | Meaning |
|---|---|---|
| `ANCHOR` | `"bottom-left"` | Corner the gauge block sits in. One of `"bottom-left"`, `"bottom-right"`, `"top-left"`, `"top-right"`. |
| `WIDTH` | `210` | Width of the gauge block, in pixels at a 1920-wide surface. |
| `INFO_ANCHOR` | `"top-right"` | Corner the money, job and cred lines sit in. Same four values as `ANCHOR`. |
| `BLOCKS` | `{ "vitals", "cyber", "needs", "money", "identity" }` | Which blocks are built, **in order**. |
| `NEEDS_THRESHOLD` | `90` | Hide a need or cyber gauge above this percent. `false` always shows it. |
| `COMMAND` | `"hud"` | Chat command that shows and hides the HUD, or `false` for none. |

`BLOCKS` is an ordered list and the order is the order rows appear in.
**Removing a name drops that block entirely** — there is no separate enable
flag, and a name that matches no builder is ignored rather than raising.

```lua
OPX_HUD_CONFIG = {
  ANCHOR = "bottom-right",
  WIDTH = 240,
  INFO_ANCHOR = "top-right",
  BLOCKS = { "vitals", "needs", "money" }, -- no cyber block, no job line
  NEEDS_THRESHOLD = false,                 -- always show the needs
  COMMAND = "hud",
}
```

!!! note "What is not configurable"

    The ten gauge segments, the 220 ms bar animation, the 5-second poll and the
    12-chip ceiling are constants in `client/main.lua`. They are cadence, visual
    detail and a guard rail — not decisions an operator would make.

## Permissions

```lua
permissions { "network.events" }
```

That single grant exists for one thing: the `/hud` answer travelling from this
resource's server half to its own client half. Nothing that appears on screen
comes over the network.

- The **character** is read from `opx77_core`'s client half through a client
  export, and an export call needs no permission.
- The **status chips** arrive on a client-side event raised inside the same
  client runtime, which is not network traffic either.

So a HUD with `COMMAND = false` would still draw everything it draws today with
the network grant removed — the grant buys the command, and nothing else.
