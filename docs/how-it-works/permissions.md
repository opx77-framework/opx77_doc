---
title: Permissions and ACL rights
description: Two different things are called permissions on Open77 — manifest permissions that let a resource call natives, and ACL rights that let a player run a command — and opx_infinity uses both.
---

# Permissions

Open77 has two separate permission systems. Do not confuse them.

| | Manifest permissions | ACL rights |
|---|---|---|
| What they gate | Which platform natives a **resource** may call | What a **player** may do |
| Where they live | `permissions { ... }` in the resource's `open77.lua` | the server's `acl.jsonc` (named by `accessControl.file`) |
| Who sets them | the resource author | the server operator |
| Example | `database.access`, `world.vehicles` | `command.opx.admin`, `command.opx.garages.*` |

## Manifest permissions {#manifest}

`opx_infinity` declares every permission its natives need in `open77.lua`. A
native called without its permission answers `permission_denied:<name>`; the
resource still starts. `opx_lib` declares none, because a library runs in the
consumer's VM and the **consumer's** manifest is checked — see
[opx_lib](../reference/opx-lib.md).

When you add a native call to a module, look the native up with the Open77
devkit and add its permission to `open77.lua` in the same change.

## ACL rights {#acl}

### Commands {#commands}

A command registered as **restricted** (`OPX.Command.Register(name, { restricted = true }, ...)`)
is checked by the host against the right `command.<name>` **before** the
handler runs. A player without it gets no answer from the resource.

The right matches the typed word exactly, and only a rule ending in `.*` is a
prefix. So a role needs **both** spellings to open a menu and use what is in it:

| To let a role… | Grant |
|---|---|
| open the staff menu and use every row | `command.opx.admin` **and** `command.opx.admin.*` |
| use the garage, dealer and wardrobe staff commands | `command.opx.garages.*`, `command.opx.dealership.*`, `command.opx.clothing.*` |
| control weather and time | `command.opx.weather.*`, `command.opx.time`, `command.opx.time.*` |
| set money, jobs and gangs by command | `command.opx.money`, `command.opx.job`, `command.opx.gang` (see [character](../modules/character.md#commands)) |

Short aliases (`noclip`, `goto`, …, see
[`COMMAND_ALIASES`](../reference/core-config.md#config-server-command-aliases))
are checked against the **long** command's right, so an alias is never less
restricted than its command.

Each module page lists its commands with the right each needs. The built-in
`admin` and `owner` roles hold `command.*` and `*` and need nothing more.

### Rights that are not commands {#other-rights}

`opx_infinity` currently checks no right outside `command.*`. The old
`opx.dealership.place` right is no longer read by any code (showroom cars are
written in `config/dealership.lua`); it can be removed from roles.

### Checking a right in code {#in-code}

A staff action that does not arrive as a restricted command (for example a net
event from a menu) must check the right itself on the server with
`Open77.acl.isAllowed(source, '<right>')` (needs the `acl.read` permission).
Hiding a button is not a check.
