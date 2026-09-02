---
title: Releases and versions
description: The version each OPX//77 resource currently declares, what a version number does and does not promise while the framework is at 0.x, and where to look for what changed.
---

# Releases

Every resource carries its own version, declared on the second line of its
`open77.lua` and reported by nothing else. There is no framework-wide release
number: `opx77_core` at `0.2.0` and `opx77_hud` at `0.1.0` are the current state
of two independently versioned resources that happen to ship together.

!!! warning "Early development"

    OPX//77 is not production-ready. The API, architecture, features and internal
    systems are subject to change at any time without notice, and breaking
    changes will be introduced as development progresses. Do not rely on the
    current API for production resources yet.

## Current versions {#current}

| Resource | Version | Reload policy |
|---|---|---|
| [`opx77_core`](reference/opx77_core/index.md) | `0.2.0` | `local` |
| [`opx77_menu`](reference/opx77_menu/index.md) | `0.1.0` | `reconnect` |
| [`opx77_hud`](reference/opx77_hud/index.md) | `0.1.0` | `reconnect` |
| [`opx77_chat`](reference/opx77_chat/index.md) | `0.1.0` | `reconnect` |
| [`opx77_status`](reference/opx77_status/index.md) | `0.2.0` | `reconnect` |
| [`opx77_notify`](reference/opx77_notify/index.md) | `0.1.0` | `reconnect` |
| [`opx77_weather`](reference/opx77_weather/index.md) | `0.1.0` | `local` |
| [`opx77_elevators`](reference/opx77_elevators/index.md) | `0.2.0` | `local` |

Each of those numbers is read from the resource's own manifest, and each is the
value [`GetVersion`](reference/opx77_core/exports/client.md#getversion) answers
for `opx77_core`. Every resource also declares `open77_version ">=0.0.1"`, which
is a floor on the **platform**, not on any OPX//77 resource: nothing here
declares a `dependency` on anything else here.

## What a version promises {#promise}

While the leading digit is `0`, it promises the reader one thing only: two
servers running the same number are running the same code. It is not a
compatibility contract.

- **A minor bump — `0.1.0` to `0.2.0` — may break you.** The three resources at
  `0.2.0` all changed shape to get there.
- **The stable surface is the error codes, not the version.** Every refusal in
  this framework answers a documented string — `job.notFound`, `money.badAmount`,
  `menu_busy`, `not_adopted` — and those codes are treated as API. A code is the
  thing to branch on; a version number is not.
- **Nothing at runtime compares versions.** No resource checks another's, and no
  consumer in the set refuses to run against an unexpected one. The only guard
  any of them applies is `GetResourceState(...) ~= "running"`, which is a check
  that something is *there*, not that it is compatible. See
  [Integration channels](concepts/integration-channels.md#client-resource).

## What changed {#changes}

There is no changelog file in any of the eight repositories. The commit history
of each resource is the record, and this documentation is written against the
code as it stands rather than against a release. If a page and the code you have
disagree, the code is right and the page is a bug — see
[Contributing](guides/contributing.md) for how to report or fix one.

## Documenting a version bump {#bumping}

Two places in this site quote a version number, and both are read from the
manifests: the table above, and the at-a-glance table on each resource's
overview page. A bump changes both, and nothing else. The
repository's `scripts/check-api-coverage.sh` will not catch a stale version —
only a stale *name* — so it is worth grepping for the old number. See
[Contributing](guides/contributing.md#docs-style).
