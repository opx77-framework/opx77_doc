# OPX//77

OPX//77 is a roleplay framework for [OPEN//77](https://open2077.net), the
multiplayer platform for Cyberpunk 2077. It gives a server the systems a
roleplay game mode needs — characters, money, jobs, gangs, persistence,
entry gating — plus a set of shared client services that other resources
build on.

!!! warning "Early development"

    OPX//77 is not production-ready. The API, architecture, features and
    internal systems are subject to change at any time without notice, and
    breaking changes will be introduced as development progresses. Do not
    rely on the current API for production resources yet.

## The seven resources

| Resource | Version | What it is |
|---|---|---|
| [`opx77_core`](resources/opx77_core.md) | 0.2.0 | The framework itself: characters, money, jobs, gangs, metadata, persistence and readiness-gate integration. Everything else reads it. |
| [`opx77_menu`](resources/opx77_menu.md) | 0.1.0 | A keyboard-driven menu service. One resource owns the surface; every other resource opens a menu through an export and is told which row the player chose. |
| [`opx77_hud`](resources/opx77_hud.md) | 0.1.0 | The player HUD. Health, armour, stamina and RAM as segmented gauges, plus money and job. It reads `opx77_core` and draws — it decides nothing. |
| [`opx77_chat`](resources/opx77_chat.md) | 0.1.0 | The chat box, and the path a typed slash command takes to the host's authenticated dispatcher. Without it, nothing typed in game reaches the server. |
| [`opx77_status`](resources/opx77_status.md) | 0.2.0 | A shared status-effect strip. Any resource adds a chip — bleeding, over encumbered, a buff on a timer — and this one owns the ordering and the countdown. |
| [`opx77_weather`](resources/opx77_weather.md) | 0.1.0 | A synchronized clock and weather authority. The server decides the time of day and the sky; every client is told and applies it. |
| [`opx77_elevators`](resources/opx77_elevators.md) | 0.2.0 | Job-gated in-world elevators: a floor list on the lifts Night City already has, with each floor opened or closed by the job a character holds in `opx77_core`. |

## How they relate

`opx77_core` is the only one that owns state on the server. It is a **single
server resource split into files**, because the Open77 server runtime installs
no `exports`, no `GetInvokingResource` and no cross-resource event bus — server
resources simply cannot call each other. See
[Architecture](architecture.md) for what follows from that.

Everything else is a **client** resource, or has its server half talk only to
its own client half:

- `opx77_hud` and `opx77_elevators` read the character from `opx77_core`'s
  client half through an export.
- `opx77_menu` and `opx77_status` are *services*: they own one piece of screen
  each, and other resources drive them through client exports. `opx77_elevators`
  draws its floor panel with `opx77_menu`, and treats a missing menu as one log
  line rather than a failure.
- `opx77_chat` and `opx77_weather` each own a server half, but it talks to that
  resource's own clients only — never to another resource.

Two consequences are worth stating up front, because they surprise everyone
arriving from FiveM:

1. **Every OPX//77 export is client-side.** A server resource that needs core
   data sends a net event to its own client half, which calls the export.
2. **Anything that must be unforgeable belongs in `opx77_core`'s server VM.**
   `opx77_elevators` says so in its own README: its job check is a client-side
   hint, and no setting turns it into anything else.

## Where to go next

- [Getting started](getting-started.md) — installing the resources on an
  Open77 server, and the `server.jsonc` block that loads them.
- [Architecture](architecture.md) — the one platform constraint that decides
  the whole shape of the framework, and the client export contract.
- [The Open77 platform](platform.md) — the runtime, the manifest, identity,
  the readiness gate, the database and the ACL.
- [Resources](resources/index.md) — one page per resource.

## License

Every resource is MIT licensed. Copyright © 2026 Luis MOUTA.
