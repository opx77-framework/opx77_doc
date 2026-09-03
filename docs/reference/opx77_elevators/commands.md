---
title: opx77_elevators commands
description: The single ACL-restricted diagnostic command opx77_elevators registers, what each line of its report means, and how to rename or disable it.
---

# Commands

One command, registered only when `OPX_ELEVATORS_CONFIG.COMMAND` is a non-empty
string. It is shipped as `opx77.elevators.where`; setting `COMMAND` to `false`
registers none. See [Configuration](config.md#command).

## Where the elevators are {#where}

Prints every configured elevator with its position, the floors it offers, and —
when this resource has adopted it — the live state of the cabin, alongside every
configuration problem that can be seen without a world.

!!! info "Permission required"

    The command is registered **restricted**, so the host resolves the ACL
    permission `command.opx77.elevators.where` against the caller before this
    resource's handler runs at all. A player without it never reaches this code;
    the host sends the refusal itself. Wildcards grant it, so
    `command.opx77.elevators.*` and `command.*` both work.

    Grant it deliberately. The output is world positions and adoption state,
    which is operator information — a list of every gated door in the city and
    whether each one is currently answering.

    Renaming the command in `config.lua` renames the permission with it: the host
    derives `command.<lowercase name>` from whatever name is registered.

```text
opx77.elevators.where [key]
```

- key?: `ElevatorKey`
    - Report only this elevator.
    - Default: every configured elevator

**Output.** Every line is printed to the server console and, when a player typed
it, echoed back to that player on
[`open77:command:result`](events.md#command-result). The order is stable:
`pairs` order would reshuffle the report between two runs, and comparing two
dumps is the whole use for it.

| Line | Content |
|---|---|
| `config: …` | one line per configuration problem, exactly as reported at boot |
| `<key> <LABEL> pos=… floors=…/… id=… …` | one line per elevator |
| `denied=… membership=…` | the effective `DENIED_FLOORS` and `MEMBERSHIP` |

An elevator line reads:

```text
ncpd_watson NCPD WATSON pos=-652.10,1394.55,12.40 floors=5/5 id=7 phase=<phase> floor=0 flags=<bits>
```

- `pos=` — the **declared** shaft position from `config.lua`, not the cabin's.
  All three axes are printed; only `X` and `Y` decide anything, and `Z` is
  recorded and never compared. An axis that is not a finite coordinate prints as
  `0.00`, and a `config:` line above says which one it was.
- `floors=A/B` — `A` stops this resource offers, against the elevator's declared
  `FLOOR_COUNT` of `B`. `A` smaller than `B` is normal; a floor absent from
  `FLOORS` is one no panel offers and no request can name.
- `id=` — the Open77 elevator id, or `-` when this resource has not adopted it.
  Ids change on every restart, which is why the durable name is the key.
- The tail is the host's live view — `phase`, `activeFloor` and `flags`, each
  printed verbatim as the host reports it — or `not adopted` when the host has no
  such elevator. `flags` is a raw bitfield; that it carries the host's `locked`
  bit is the confirmation that a client cannot move this cabin directly.

**Errors** — none. The command never refuses and never reports a usage error: a
key that matches nothing simply produces no elevator lines, and the trailing
settings line still arrives.

**Side** `server` — inside `opx77_elevators` only. Commands are registered per
VM and are removed with it on stop or reload.

### Example {#where-example}

```text
> opx77.elevators.where arasaka_tower
config: arasaka_tower floor #4: INDEX 8 is outside FLOOR_COUNT 8
arasaka_tower ARASAKA TOWER pos=-1521.40,892.75,42.10 floors=5/12 id=- not adopted
denied=shown membership=primary
```

`id=-` with `not adopted` on an elevator a player is standing next to is the
first thing to check when [`requestFloor`](exports.md#requestfloor) answers `not_adopted`: it means
no client sighting has been accepted for it yet. The server logs the reason it
rejected one.
