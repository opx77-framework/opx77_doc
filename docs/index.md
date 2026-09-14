---
title: OPX//77 — a roleplay framework for OPEN//77
description: OPX//77 is a roleplay framework for the OPEN//77 multiplayer platform for Cyberpunk 2077; this page points you at the guide, concept or reference page that answers what you came here to ask.
---

# OPX//77

OPX//77 is a roleplay framework for [OPEN//77](https://open2077.net), the
multiplayer platform for Cyberpunk 2077. It gives a server the systems a
roleplay game mode needs — characters, money, jobs, gangs, appearance,
persistence, entry gating — plus a set of shared client services that other
resources build on.

!!! warning "Early development"

    OPX//77 is not production-ready. The API, architecture, features and
    internal systems are subject to change at any time without notice, and
    breaking changes will be introduced as development progresses. Do not rely
    on the current API for production resources yet.

## Start where your question is {#start-here}

**Coming from ESX or Qbox?**
The habits transfer; the call shapes do not, and one of them — a server-side
export — has no equivalent here at all. Read
[Converting from ESX or Qbox](guides/converting.md).

**Installing a server?**
Fourteen resources, one load order and one `server.jsonc` block, in the order
that works. Read [Getting started](guides/getting-started.md).

**Players stuck on the loading screen, or never offered a character?**
The world loads before anybody is chosen, and the character is chosen in it.
Read [The entry gate](concepts/entry-gate.md#world-first), then
[Troubleshooting](guides/troubleshooting.md#stuck-loading-screen).

**Writing a resource?**
Everything OPX//77 exposes to you is a *client* export answering a promise, and
the failure model has three levels rather than one. Read
[Writing a resource](guides/writing-a-resource.md), then
[The export contract](concepts/export-contract.md) for the shape every call
takes.

**Want to know why the server side is one resource?**
Because the OPEN//77 server runtime installs no `exports`, no
`GetInvokingResource` and no cross-resource event bus, so a second server
resource could never be asked for anything. Read
[Architecture](concepts/architecture.md), and
[Integration channels](concepts/integration-channels.md) for the three
asynchronous channels that remain.

## The three registers {#registers}

[**Guides**](guides/getting-started.md) read top to bottom.
[**Concepts**](concepts/architecture.md) say why the framework is shaped the way
it is, because nearly every surprising decision in it is a consequence of a
platform constraint. [**Reference**](reference/index.md) is the lookup: one
section per resource, every export, event, command, config key and type, with
its error codes and the side it can be called from.

## License {#license}

Every resource is MIT licensed. Copyright © 2026 Luis MOUTA.
