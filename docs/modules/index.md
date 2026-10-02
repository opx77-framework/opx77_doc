---
title: All modules
description: Every module of opx_infinity with the side it runs on, what it needs, and a one-line summary, linking to its reference page.
---

# Modules

`opx_infinity` is made of the modules below. Each runs on the server, the client
or both, and may **require** other modules (it does not run without them) or use
them **optionally**. Each page lists the module's commands, contract, events,
page channels, configuration and refusal codes. A module is switched off with
`enabled = false` in its config file; see [Configure](../getting-started/configure.md#disable).

## Players and characters {#players}

| Module | Side | Requires | Summary |
|---|---|---|---|
| [character](character.md) | both | — (fatal) | Accounts, characters, money, jobs, gangs, metadata and placement. Every other module reads a player through it. |
| [appearance](appearance.md) | both | character (fatal) | Face and clothes, the join bootstrap and gameplay-ready announcement, the fitting room, and the looks other players are drawn from. |
| [entry](entry.md) | client | character | Finishes a new character: opens the game's creator, then asks for a name once. |
| [spawn](spawn.md) | both | — | The menu of start locations offered when a character enters the world. |
| [needs](needs.md) | both | character | Hunger, thirst, stamina and street cred, and the status-effect chips any module can add. |
| [downed](downed.md) | both | character | Who is down, the down screen (wait for help or give up), and revival. |
| [calls](calls.md) | both | character | Player-to-player holocalls and contact swapping. |
| [animations](animations.md) | both | — | Emotes: `/e`, a picker, a stop key, walking paces. |

## Economy and items {#economy}

| Module | Side | Requires | Summary |
|---|---|---|---|
| [inventory](inventory.md) | both | character | The bag, stashes, vehicle trunks and gloveboxes, ground piles, weapons drawn from the bag, and eddies carried as an item. |
| [shops](shops.md) | both | character, appearance | Clothing shops: the fitting room billed per changed slot, ready-made looks and saved outfits. |
| [clothing](clothing.md) | both | — | Clothing-store markers that open the appearance module's fitting room. |
| [crafting](crafting.md) | both | inventory, character | Workbenches and recipes; materials go in, the output is collected later. |
| [gunsmith](gunsmith.md) | both | crafting, character | Armouries: a crafting bench, a stash and a job gate per entry. |
| [hauling](hauling.md) | both | character | A delivery job: carry crates, load them into a trunk, sell them to an NPC. |

## Vehicles {#vehicles}

| Module | Side | Requires | Summary |
|---|---|---|---|
| [vehicles](vehicles.md) | server | character | The registry of owned vehicles: plates, bringing a car out, putting it away, saving its condition. |
| [vehiclekeys](vehiclekeys.md) | both | — | Vehicle keys as inventory items, and the lock a key turns. |
| [garages](garages.md) | both | character | Markers where a player brings out their own vehicles or puts one away. |
| [dealership](dealership.md) | both | character | Dealers that sell vehicles, locked showroom cars, and player-to-player sales paid into a company account. |

## World {#world}

| Module | Side | Requires | Summary |
|---|---|---|---|
| [weather](weather.md) | both | — | One server authority for time of day and weather, synced to every client. |
| [elevators](elevators.md) | both | character | Job-gated floor lists on the game's lifts; the server re-checks every move. |
| [teleports](teleports.md) | both | character | Operator-placed teleport pads, one- or two-way, optionally job-locked. |
| [blips](blips.md) | client | — | Map pins for garages, dealers, shops, teleports and job sites. |

## Screens and input {#screens}

| Module | Side | Requires | Summary |
|---|---|---|---|
| [hud](hud.md) | client | character | Gauges, money and job, status chips, microphone and speed; hides the game's own HUD. |
| [chat](chat.md) | both | — | The chat box, and the only way a typed slash command reaches the host. |
| [menu](menu.md) | client | — | The keyboard list menu other modules open through its contract. |
| [form](form.md) | client | — | A modal asking for text, choice or slider values. |
| [panel](panel.md) | client | — | A mouse-driven drawer with tabs, a searchable list, buttons and sliders. |
| [prompts](prompts.md) | both | — | The "press X to do Y" key strip, drawn with the player's own bindings. |
| [progress](progress.md) | both | — | One timed-action bar that can lock movement and play a gesture. |
| [target](target.md) | client | — | The target eye (hold ALT): world-interaction rows other modules register. |
| [theme](theme.md) | both | — | The server's colours and surface style, pushed to every player's screen. |

## Staff and tools {#staff}

| Module | Side | Requires | Summary |
|---|---|---|---|
| [admin](admin.md) | both | character | The staff panel (F9), target-eye rows and the `opx.admin.*` commands. |
| [diagnostics](diagnostics.md) | both | — | `/opx.modules`, `/opx.version`, `/opx.client`; forwards page errors and failed client modules to the server log. |

**fatal** means the resource reports a failed boot if the module fails.
Optional dependencies are listed on each module page.
