---
title: gunsmith module
description: Armouries made of a crafting bench, a stash chest and a job gate, all declared in one config file.
---

# gunsmith

The gunsmith module turns each entry of its config into an armoury: a workbench where players craft ammunition, weapons or tools, and a chest (a shared stash) beside it. Both appear as rows on the target eye. An armoury can be public or limited to jobs, a minimum grade and on-duty status; each recipe can ask for a higher grade. The bench itself is run by the [crafting](crafting.md) module and the chest by the [inventory](inventory.md) module. Use it to give a job or a district its own armoury without writing code.

| | |
|---|---|
| Side | both |
| Requires | `crafting`, `character` (hard) |
| Optional | `inventory` (the chest), `target` (the bench and chest rows) |
| Configuration | `config/gunsmith.lua` (shared script) |
| Contract | none |
| Data | none of its own. Orders are in `opx77_crafting_orders`; chests are `stash` rows in `opx77_inventories`. |

!!! warning
    The shipped armoury positions in `config/gunsmith.lua` are placeholders and have not been surveyed. A bench more than `REACH` metres from where players stand can never be used, and nothing reports it. Set real positions before going live.

## How an armoury works {#armouries}

- At start the module registers one crafting bench per armoury, keyed `gunsmith:<armouryKey>`, with `owner = 'gunsmith'`. Recipes use the [crafting recipe fields](crafting.md#recipe-fields) plus `GRADE`.
- The bench gate reads the character's job from the `character` contract. A gated armoury refuses when the job record is older than `JOB_MAX_AGE_MS`. An armoury with no `JOBS` is open to everyone, and `GRADE` is then ignored.
- A recipe's `GRADE` is a minimum grade on top of the armoury's own `JOBS` grades.
- The chest opens through the inventory `OpenStash` contract, with the chest's position, so the inventory module checks reach with its own `REACH.DISTANCE`. The chest uses the same job gate as the bench (without recipe grades). Opening it is audited (`gunsmith.chest`).
- Without `inventory`, benches work and no chest opens. Without `crafting`, no armoury has a bench.

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-gunsmith-chest"></a>`opx:net:gunsmith:chest` | client → server | `armouryKey` | Open this armoury's chest. |
| <a id="opx-net-gunsmith-refused"></a>`opx:net:gunsmith:refused` | server → client | `armouryKey, code` | The chest was refused. The client toasts `gunsmith.<code>`. |

Bench refusals arrive through [`opx:net:crafting:refused`](crafting.md#opx-net-crafting-refused).

## Configuration {#configuration}

`config/gunsmith.lua` sets `OPX.Config.MODULES.gunsmith`. Shared script (the client draws the target spheres). `enabled = false` switches the module off.

| Key | Default | What it does |
|---|---|---|
| <a id="config-gunsmith-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-gunsmith-membership"></a>`MEMBERSHIP` | `'primary'` | `'primary'`: only the job being worked counts. `'any'`: every job the character holds counts for the grade, but never for `ON_DUTY`. |
| <a id="config-gunsmith-job-max-age-ms"></a>`JOB_MAX_AGE_MS` | `60000` | Oldest job record a gated armoury accepts. |
| <a id="config-gunsmith-reach"></a>`REACH` | `2.5` | Bench reach in metres, checked by crafting on the server. |
| <a id="config-gunsmith-prompt-radius"></a>`PROMPT_RADIUS` | `2.5` | Radius of the bench and chest target spheres. |
| <a id="config-gunsmith-armouries"></a>`ARMOURIES` | `arasaka_armoury`, `ncpd_watson_armoury`, `kabuki_workshop` | The armouries, keyed by slug. See below. |

### An armoury entry

| Field | What it does |
|---|---|
| `LABEL` | Bench menu title. Defaults to the key. |
| `JOBS` | `{ job = minimumGrade }`. Absent or empty = public. |
| `ON_DUTY` | `true` = the job must be the one worked, on duty. |
| `BENCH` | `{ X, Y, Z, BUCKET? }`. Without a valid position the armoury has no bench. |
| `CHEST` | `{ NAME, LABEL?, SLOTS? (50), MAX_WEIGHT? (100000), X, Y, Z, BUCKET? (0) }`. `NAME` is the stash key: letters, digits, `_`, `-`, `.`, up to 48. Never rename it: a new name is an empty chest. |
| `QUEUE` | Orders per character on this bench (crafting caps it at its `MAX_QUEUE`). |
| `RECIPES` | List of [crafting recipes](crafting.md#recipe-fields), each with an optional `GRADE` (0–255). |

## Refusal codes {#codes}

Chest refusals use `gunsmith.<code>`. Bench gate refusals use `crafting.<code>`; this module adds those four keys to the locales.

| Code | Where | Meaning |
|---|---|---|
| `job_required` | chest, bench | The character does not hold a listed job. |
| `grade_too_low` | chest, bench | Grade below the armoury's or the recipe's minimum. |
| `off_duty` | chest, bench | `ON_DUTY` is set and the character is off duty. |
| `job_stale` | chest, bench | The job record is older than `JOB_MAX_AGE_MS`. |
| `no_character` | chest, bench | No character loaded (gated armouries only). |
| `no_such_chest` | chest | Unknown armoury, or it has no chest. |
| `not_for_you` | chest | Gate refused with no code. |
| `unavailable` | chest | No `inventory` contract. |
| `too_far`, `not_ready`, `not_loaded`, `bad_argument` | chest | Passed through from inventory `OpenStash`. |
