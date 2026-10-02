---
title: Contributing and house style
description: How to change opx_infinity or opx_lib — branches, checks before pushing, code conventions, text, and what to update in this documentation site in the same change.
---

# Contributing

This page is for anyone changing `opx_infinity`, `opx_lib` or this site. It
lists the rules reviewers apply. The framework's own `README.md` and
`ui/README.md` are the authority when they disagree with this page.

## Branches and pull requests {#branches}

Nothing is pushed to `main` directly. Branch, push, open a pull request.
`main` is what the test server must be able to run.

| Branch | For |
|---|---|
| `feat/<thing>` | a new capability |
| `fix/<thing>` | a defect |
| `audit/<thing>` | a sweep across the codebase |

## Before you push {#checks}

From the `opx_infinity` folder, with `opx_lib` checked out next to it:

```bash
lua tests/run.lua                                    # must be green
luac -p $(find . -name '*.lua' -not -name 'open77.lua')
npm run typecheck && npm run build                   # only if ui/ changed
```

| Check | Catches |
|---|---|
| `tests/run.lua` | boots the real manifest on a stub platform; also fails on a file missing from the manifest, a global the sandbox removes, a client-only global in server code, or a module hanging its internals on `OPX` |
| `luac -p` | syntax errors. `open77.lua` is the manifest DSL, not Lua, so it is excluded. |
| `npm run build` | writes `web/index.html`, the shipped page. Commit it with the `ui/` change. |
| CI (`.github/workflows/check.yml`) | the above, plus `tools/check-sandbox-globals.py` (no metatables or `require` in shared code) |

## Code conventions {#code}

| Rule | Detail |
|---|---|
| Lua 5.4, not CfxLua | No vector literals, no backtick hashes, no `?.`, no `+=`. |
| Indentation | Tabs in `.lua`; two spaces elsewhere (`.editorconfig`). LF line endings, UTF-8. |
| Quotes | Single quotes in Lua. |
| One file per manifest line | Never glob scripts. Every `.lua` file must be listed in `open77.lua`. |
| Modules talk through contracts | Never reach into another module's files or tables. Nothing new goes on `OPX` without a reason (the test suite keeps a list). |
| Read settings late | `M.Settings` inside a phase, never at file scope. |
| Answer, don't raise | Prefer a refusal with a named code. Most functions answer a `Result` (`{ ok = true, value }` / `{ ok = false, error, detail }`); `error` is stable, `detail` is for logs only. |
| Server decides | Re-check every network payload; see [Server authority](../how-it-works/server-authority.md). |
| Repeating work | [`OPX.Scheduler.Every`](../how-it-works/scheduler.md), not a hand-written loop. |
| Natives | Look every native up with the Open77 devkit; add its manifest permission in the same change. |
| Comments | Explain *why*, not what. `-- @author <name>` on a file header and on a public function. |

## Text {#text}

- Player-facing text comes from a catalogue: `locale(key, params)`. Logs and
  error codes stay in English.
- `modules/<id>/locales.lua` holds English **and** French with the same keys and
  the same `{placeholders}`.
- Never rename a key: it may be a code on the wire.

See [Text and locales](../how-it-works/locales.md).

## The WebUI {#ui}

Read `ui/README.md` in the framework first; it is binding. Hard-code no colour —
use the theme tokens. `open77_pause` owns Escape.

## Commit messages {#commits}

Say what changed and **why it was wrong before**. If a change fixes something
that failed silently, describe what the player saw, because that is what someone
will search for later.

## Deploying to the test server {#deploy}

Archive from the commit, not the working tree, then restart and read the journal
in the same change. See [Install a server](../getting-started/install.md#copy).
Never `DROP DATABASE`; empty tables instead, after a `mysqldump`.

## Updating this documentation {#docs}

A change that adds, removes or changes a command, event, contract function,
config key or page channel updates this site **in the same change**.

### Adding a module {#new-module}

1. Create `docs/modules/<id>.md` from an existing module page. Keep the
   section order: summary table, Commands, Server contract, Client contract,
   Events, Page channels, Configuration, Refusal codes. Leave out sections the
   module does not have.
2. Add `- <id>: modules/<id>.md` under **Modules** in `mkdocs.yml`, in
   alphabetical order, and a row in `docs/modules/index.md`.
3. Run the coverage check (below) until nothing is missing.

### Anchors {#anchors}

Every published name needs an anchor, either `{#anchor}` on a heading or
`<a id="anchor"></a>` in a table cell. The anchor is the name in lower case
with every run of other characters replaced by `-`:

| Name | Anchor |
|---|---|
| server contract member `character.AddMoney` | `server-character-addmoney` |
| command `opx.admin.player.goto` | `opx-admin-player-goto` |
| event `opx:net:chat:say` | `opx-net-chat-say` |
| page channel `menu:choose` | `page-menu-choose` |
| config key `SELLER_CUT_PERCENT` of `dealership` | `config-dealership-seller-cut-percent` |
| function `OPX.Scheduler.Every` | `opx-scheduler-every` |
| opx_lib function `Lib.Rpc.Call` | `lib-rpc-call` |
| server export `AddMoney` (in `docs/creators/`) | `export-server-addmoney` |

### Checks {#docs-checks}

```bash
pip install -r requirements.txt
mkdocs build --strict
./scripts/check-api-coverage.sh ../opx_infinity
```

`scripts/check-api-coverage.sh` boots the framework on its stub host (it needs
Lua 5.4) and fails on any published name without an anchor.

### Writing style {#style}

- Every page starts with front matter (`title`, one-sentence `description`) and
  one plain paragraph: what it is and when to use it.
- Short, direct sentences. Tables for anything a reader looks up.
- British spelling.
- Never document something you have not read in the code. If the code and the
  framework README disagree, the code wins; say so to the maintainers.
- Admonitions are rare: `warning` for a surprising or irreversible effect,
  `danger` for lost money or data.

## Licence {#licence}

The framework is MIT licensed. A contribution is accepted under the same terms.
