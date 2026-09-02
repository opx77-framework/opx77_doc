---
title: opx77_hud configuration
description: The eight keys in OPX_HUD_CONFIG that decide which catalogue its text is read from, where the HUD sits, which blocks it builds and in what order, when a gauge hides itself, the name of the /hud command, and which of Cyberpunk's own HUD components are hidden.
---

# Configuration

Everything lives in `config.lua`, in the global table `OPX_HUD_CONFIG`. It is a
`shared_script`: the client half reads the layout, the server half reads the
command name.

**Every value shown on this page is the shipped default.**

```lua
OPX_HUD_CONFIG = {
  LOCALE = "en",
  ANCHOR = "bottom-left",
  WIDTH = 210,
  INFO_ANCHOR = "top-right",
  BLOCKS = { "vitals", "cyber", "needs", "money", "identity" },
  NEEDS_THRESHOLD = 90,
  COMMAND = "hud",
}
```

## LOCALE {#locale}

The catalogue the player-facing text is read from, applied at load.

```lua
LOCALE = "en"
```

**Type** `string` — a catalogue registered under `locales/`. `"en"` and `"fr"`
ship.

There are four strings behind this key, and they are the whole of the text this
resource writes for a player to read: the `/hud` usage line, the command's chat
suggestion, its argument help, and the `CRED` label on the street-cred line.
Everything else on screen belongs to somebody else — a money type's key, a job's
label, a chip's label — and none of it passes through here. Log lines stay in
English whatever this is set to.

An unknown code is **accepted**, not rejected: `shared/locale.lua` reads this key
before any catalogue has registered, so there is nothing to check it against yet.
Every lookup then falls back to `en`, and then to the key itself, so a string
nobody translated shows as its raw key rather than as nothing.

!!! info "Three shared scripts, and the order is load-bearing"
    `shared/locale.lua` reads `LOCALE` at load, so the manifest lists it after
    `config.lua`, and the two catalogues after it — a file below an empty
    catalogue would get its keys back instead of its strings. All three are
    `shared_script`s rather than client ones because the `/hud` command is
    registered on the server half, and that is the half that answers with the
    usage line.

## ANCHOR {#anchor}

Which corner the segmented gauge block sits in.

```lua
ANCHOR = "bottom-left"
```

**Type** `"bottom-left" | "bottom-right" | "top-left" | "top-right"`

An unrecognised value falls back to `bottom-left` in the page rather than
raising. It reaches the page once, on
[`hud:config`](events.md#hud-config), and is never resent — a change needs a
reconnect, like every other change to this resource.

## WIDTH {#width}

Width of the gauge block, in pixels at a 1920-wide surface.

```lua
WIDTH = 210
```

**Type** `integer`

Ignored by the page unless it is a finite number above zero, in which case it
sets the `--hud-width` custom property. It does not affect the text block, which
sizes itself to its content.

## INFO_ANCHOR {#info-anchor}

Which corner the money, job and street-cred lines sit in.

```lua
INFO_ANCHOR = "top-right"
```

**Type** `"bottom-left" | "bottom-right" | "top-left" | "top-right"`

The same four values as [`ANCHOR`](#anchor), and independent of it. An
unrecognised value falls back to `top-right`.

## BLOCKS {#blocks}

Which row builders run, **in order**; the order is the order rows appear in.

```lua
BLOCKS = { "vitals", "cyber", "needs", "money", "identity" }
```

**Type** `string[]`

| Name | Builds |
|---|---|
| `vitals` | The `health` gauge always, the `armor` gauge only above zero. Armour carries no tone — low armour is not the warning low health is. |
| `cyber` | The `stamina` gauge, from `opx77_status`. Without that resource answering, this block appends nothing, which is the intended state. |
| `needs` | The `hunger` and `thirst` gauges, both from `opx77_status`, each skipped when the value is not a finite number. |
| `money` | One text line per money type. `EDDIES` and `BANK` lead in that order; every other **string** key follows, sorted alphabetically. A zero or non-finite amount is not drawn. |
| `identity` | The job line from `opx77_core` — label, grade name, and the `on` tone while `job.onDuty` is `true` — and `CRED` from `opx77_status`'s `streetCred` when it is above zero, floored. Its label is the one string here that comes from the [catalogue](#locale). |

A gauge is named here by its row `id` — the page's DOM slot key, and the CSS
class the stylesheet themes it through. Gauges carry no label at all; the text
rows the `money` and `identity` blocks build are the only rows that do.

**Removing a name drops that block entirely**; there is no separate enable flag.
A name that matches no builder is ignored rather than raising, so a typo costs
you a block silently.

!!! warning "Money keys that are not strings are dropped"
    A non-string key in `PlayerData.money` is discarded before the sort. Sorting
    mixed types raises, and `:lower()` on a number raises — both inside the single
    thread that keeps this surface repaired, which would leave the HUD frozen on
    its last frame.

## NEEDS_THRESHOLD {#needs-threshold}

The percentage above which a need or stamina gauge hides itself, so a full bar
does not sit on screen saying nothing.

```lua
NEEDS_THRESHOLD = 90
```

**Type** `integer | false`

`false` always shows them, and so does anything else that is not a number: a
comparison against a string would raise rather than refuse, so it is read as
`false`. It applies to the `needs` and `cyber` blocks only: `health` is always
drawn, and `armor` has its own rule (above zero).

## COMMAND {#command}

The chat command that shows and hides the HUD, without its leading slash.

```lua
COMMAND = "hud"
```

**Type** `string | false`

`false` or an empty string registers nothing, offers no chat suggestion, and logs
one informational line at startup. See [Commands](commands.md#no-command). The
value is interpolated into the usage line the server answers with, which comes
from the [catalogue](#locale) and reads `usage: /<name> [on|off]`, so renaming
the command renames it everywhere.

## VANILLA {#vanilla}

Cyberpunk's own HUD, component by component. This resource draws the
replacement, so it is also the resource that turns the original off — left
alone, the two stack and the player reads their health off two bars that
disagree while one of them animates.

```lua
VANILLA = {
  minimap = false,
  compass = false,
  clock = false,
  health = false,
  stamina = false,
  weapon = false, -- the weapon and its ammunition count, together
  speedometer = false,
}
```

**Type** `table<string, boolean> | false`

The value is the visibility you want, not the change you want: `false` hides the
component, `true` puts it back. A component with no line is left alone.
`VANILLA = false` leaves the game's HUD entirely alone.

| Written | Effect |
|---|---|
| `component = false` | Hidden at boot, and again whenever a character loads. |
| `component = true` | Explicitly shown, overriding whatever the client had. |
| *(line removed)* | Untouched. |
| `VANILLA = false` | The whole feature is off; nothing is read and nothing is called. |

**Applied** at `onClientResourceStart`, and again on
[`opx77:client:onPlayerLoaded`](events.md), because the game brings its own HUD
back at incarnation and that lands after this resource started.

**Restored** when the resource stops — to the visibility each component was
*found* at, not to what is written here. A component the player's own settings
already had hidden stays hidden. Whether the platform would also restore them by
itself is undocumented; this resource does not rely on either answer.

!!! warning "The names belong to the client, not to this table"
    The seven above are the ones that existed when this was written.
    `Open77.hud.components()` is what the client itself reports, and it is what
    the resource validates against: a name this client does not recognise is one
    logged warning and nothing else, never a script error. A newer client that
    adds an eighth component can have it hidden by adding a line here — no
    release of `opx77_hud` is needed.

!!! info "Requires `ui.vanilla.hud`"
    Declared by `opx77_hud`'s manifest, not by yours. Like the rest of the
    `ui.vanilla` family it is presentation **on the client that holds it**:
    nothing here is authoritative and none of it is worth trusting on the server.

    `Open77.hud` is newer than every other API this framework touches and is
    absent from the published API reference, so a client that predates it cannot
    hide anything. That case is a logged warning naming the capability, and
    [`exports("vanilla")`](exports.md#vanilla) reports `available = false` so you
    can tell it apart from a component that simply refused.

## What is deliberately not a key {#not-configurable}

These are constants in `client/main.lua`. They are cadence, visual detail and a
guard rail — not decisions an operator would make — and changing one means
editing the resource.

| Constant | Value | What it is |
|---|---|---|
| `GAUGE_SEGMENTS` | `10` | How many blocks a gauge is cut into. |
| `POLL_MS` | `5000` | How often the core is re-read as a net under its change events. There is no equivalent for the needs: they are pushed. |
| `MAX_CHIPS` | `12` | The most chips kept from one `opx77:status:effects` payload. |
| `MAX_HIDDEN` | `999` | The largest `+N` overflow counter that still reads as a number. |

The strip's own corner and offset are **not** here either. They belong to
[`opx77_status`](../opx77_status/config.md), which publishes them with every
payload so this resource never has to read another resource's config.
