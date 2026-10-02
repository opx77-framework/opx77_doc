---
title: OPX//77 — a roleplay framework for Open77
description: OPX//77 is a roleplay framework for Open77, the multiplayer platform for Cyberpunk 2077, shipped as one resource, opx_infinity, plus the opx_lib client library.
---

# OPX//77

OPX//77 is a roleplay framework for [Open77](https://open2077.net), the
multiplayer platform for Cyberpunk 2077. It gives a server characters, money,
jobs and gangs, appearance, an inventory, vehicles and garages, a HUD, chat,
staff tools and more. It ships as **one resource, `opx_infinity`**, plus a small
client library, `opx_lib`.

!!! warning "Early development"

    OPX//77 is not production-ready. The API and features change without notice.

## Where to start {#start-here}

| You want to… | Read |
|---|---|
| Install it on a server | [Install a server](getting-started/install.md), then [Configure it](getting-started/configure.md) |
| Fix a problem on a running server | [Troubleshooting](getting-started/troubleshooting.md) |
| Look up a module: its commands, events, settings | [Modules](modules/index.md) |
| Add a feature to the framework | [Write a module](guides/writing-a-module.md) |
| Build your own resource next to it | [Write a separate resource](guides/writing-a-resource.md) |
| Port code from the old `opx77_*` resources or from FiveM | [From opx77_* to opx_infinity](migration/from-opx77.md), [Convert from FiveM](guides/converting.md) |
| Understand how it works inside | [How it works](how-it-works/overview.md) |
| Look up a core or library function | [API reference](reference/index.md) |

## What changed in September 2026 {#infinity}

The sixteen documented `opx77_*` resources (and five more) were replaced by one
resource, `opx_infinity`. Each old resource is now a **module** inside it, and
modules talk to each other through in-process **contracts** instead of exports.
`opx_infinity` publishes no exports. See the
[migration page](migration/from-opx77.md).

## Licence {#license}

`opx_infinity` and `opx_lib` are MIT licensed. Copyright © 2026 Luís MOUTA.
OPX//77 is an independent community project, not affiliated with or endorsed by
CD PROJEKT RED.
