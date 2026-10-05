# Contributing to opx77_doc

Thanks for helping. This file is how the documentation site is built and how its
pages are written. The reviewer rules for the framework itself are on the site:
[Contributing](content/docs/guides/contributing.mdx). The organization-wide guide is
[here](https://github.com/opx77-framework/.github/blob/main/CONTRIBUTING.md).

Questions go to [Discord](https://discord.gg/xpSuYgEYsU). A page that is wrong can be
reported with the *Documentation issue* form.

## Workflow

- Nothing is pushed to `main` directly: `main` is deployed to GitHub Pages on every
  push. Branch (`docs/<thing>`, `fix/<thing>`), push, open a pull request.
- A pull request runs the same build as a deployment, without deploying.
- **Nothing is documented that was not read in the code.** Link the framework commit
  or pull request a page change follows (for example "sync opx_infinity #88–#95").
- Commit messages: `docs: <what the pages say now>`, and a body naming the framework
  changes it follows.

## Before you push

```bash
npm ci
node scripts/check-content.mjs     # MDX compiles, front matter, links, anchors
npm run types:check
npm run build
npm run check:api                  # with opx_infinity and opx_lib checked out next to this repo
```

## Stack

A [Fumadocs](https://fumadocs.dev) site on Next.js, exported as static HTML and
modelled on the [overextended docs](https://github.com/overextended/overextended.github.io):
fumadocs-core / fumadocs-ui 16, fumadocs-mdx 15, Next 16, React 19, Tailwind v4,
Orama static search. Node 24 and npm (`package-lock.json` is committed).

```text
content/docs/            the pages (.mdx) and the sidebar order (meta.json per folder)
├── index.mdx            introduction: where to start
├── getting-started/     install, configure, troubleshooting
├── opx_infinity/        overview, concepts/, core/ (OPX.*, config, events, lib/, error codes),
│                        then one folder per module: index (commands, config, codes),
│                        server, client, events
├── opx_lib/             one page per Lib module
├── creators/            server/ and client/: one page per export; events
├── guides/              write a module, write a resource, convert, contribute
└── migration/           from opx77_* to opx_infinity, release notes

app/                     Next routes: home, /docs, search index, llms.txt,
                         anchors.json and the old-URL redirect pages
lib/legacy.ts            every URL the old MkDocs site served -> its new page
scripts/
├── check-content.mjs    MDX compiles, front matter, internal links and anchors
├── anchors.mjs          what counts as an anchor (shared by both checks)
├── check-api-coverage.sh  fails on a published name the docs do not document
└── dump-surface.lua     boots opx_infinity on its stub host and prints that surface
```

## How the pages are written

The overextended style: snippets explain, prose stays short.

- Front matter: `title` and a one-sentence `description` (shown under the title).
- A function, export or event is one heading with its anchor, a one-line
  description, the call as a `lua` snippet, a **Parameters** list and a
  **Returns** list with types, then a tiny `Example`:

  ````mdx
  ## SetWeather [#server-weather-setweather]

  Crosses to a weather and reschedules the next roll.

  ```lua
  weather.SetWeather(name, transitionSeconds, reason)
  ```

  **Parameters**
  - name: `string`
  - transitionSeconds?: `number`

  **Returns**
  - `Result` — errors `no_presets`, `unknown_preset`, `invalid_transition`
  ````

- Commands, config keys and refusal codes are tables on the module's index
  page, with `<a id="…" />` in the first cell.
- Every published name has an anchor; the rule is in
  [Contributing](content/docs/guides/contributing.mdx).
- Nothing is documented that was not read in the code. The code is the source
  of truth, not the framework manual (`docs/MANUAL.md`).
- Outside code, `{`, `}` and `<` are JSX in MDX: keep them in backticks.

## Adding a module

1. Create `content/docs/opx_infinity/<id>/` with `index.mdx`, `server.mdx`,
   `client.mdx`, `events.mdx` (only those it has) and a `meta.json`, copying
   an existing module (`weather` is the smallest complete one).
2. Add `<id>` to `content/docs/opx_infinity/meta.json` (alphabetical) and a row
   to the module list in `content/docs/opx_infinity/index.mdx`.
3. Run the checks below.

## Building locally

```bash
npm ci
npm run dev            # http://localhost:3000/opx77_doc/
npm run build          # static export to out/
npm run types:check
node scripts/check-content.mjs
```

`npm start` serves `out/` (open `/opx77_doc/`).

## Checking API coverage

The framework lives in other repositories, so the check needs checkouts of
`opx_infinity` and `opx_lib`, desktop **Lua 5.4** (`lua5.4` or `lua`) and Node:

```bash
npm run check:api                                     # finds ../opx_infinity, ../../opx_infinity or ../../../opx_infinity
./scripts/check-api-coverage.sh /path/to/opx_infinity
OPX_INFINITY=/path/to/opx_infinity OPX_LIB_PATH=/path/to/opx_lib ./scripts/check-api-coverage.sh
```

It does not grep the framework. `scripts/dump-surface.lua` boots the real
manifest on the framework's own stub host (`opx_infinity/tests/host.lua`) and
prints every module, contract member, command, alias, Open77 export, network
event, module event, page channel, config key and `OPX.*` function that is
actually registered; `opx_lib`'s functions are read from its source. The check
then fails on any name without its anchor in the right folder of
`content/docs`. With no framework checkout in reach it prints a note and exits
0, which is what happens on the CI runner.

## Old URLs

The MkDocs site served pages such as `/opx77_doc/modules/weather/`. Each of
those paths (and every path the MkDocs `redirects` plugin already forwarded)
is exported as a small page that forwards to its new home, keeping the
`#fragment` when a page still defines that anchor (looked up in
`/opx77_doc/anchors.json`). The list is `lib/legacy.ts`.

## Deployment

Pushing to `main` runs `.github/workflows/deploy.yml`: `npm ci`, content check,
coverage check (a skip on CI), type check, `npm run build`, then the `out/`
directory is deployed to GitHub Pages. Pull requests run the same build
without deploying. The repository's Pages source must be **GitHub Actions**.

