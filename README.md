<h1 align="center">OPX//77 · Documentation</h1>

<p align="center">
  <strong>The documentation site for OPX//77, the serious-roleplay framework for <a href="https://open2077.net">Open77</a>, the Cyberpunk 2077 multiplayer platform.</strong>
</p>

<p align="center">
  <a href="https://github.com/opx77-framework/opx77_doc/actions/workflows/deploy.yml"><img alt="Deploy documentation" src="https://github.com/opx77-framework/opx77_doc/actions/workflows/deploy.yml/badge.svg?branch=main"></a>
  <a href="https://opx77-framework.github.io/opx77_doc/"><img alt="Read the docs" src="https://img.shields.io/badge/docs-online-c5003c"></a>
  <a href="https://discord.gg/xpSuYgEYsU"><img alt="Discord" src="https://img.shields.io/badge/discord-join-5865F2?logo=discord&logoColor=white"></a>
</p>

<p align="center">
  <strong><a href="https://opx77-framework.github.io/opx77_doc/">opx77-framework.github.io/opx77_doc</a></strong>
</p>

---

## What it covers

OPX//77 is **one resource, [`opx_infinity`](https://github.com/opx77-framework/opx_infinity)**,
plus the client library **[`opx_lib`](https://github.com/opx77-framework/opx_lib)**. This
site documents both, and the exports other resources may call.

| Section | What is in it |
|---|---|
| [Getting started](https://opx77-framework.github.io/opx77_doc/docs/getting-started/install) | Install on an Open77 server, configure, troubleshoot. |
| [opx_infinity](https://opx77-framework.github.io/opx77_doc/docs/opx_infinity) | How it works (concepts, core), then every module: commands, configuration, refusal codes, server and client contracts, events. |
| [opx_lib](https://opx77-framework.github.io/opx77_doc/docs/opx_lib) | One page per library module. |
| [For creators](https://opx77-framework.github.io/opx77_doc/docs/creators) | Every server and client export, and the public events. |
| [Guides](https://opx77-framework.github.io/opx77_doc/docs/guides/writing-a-module) | Write a module, write a separate resource, convert from FiveM, contribute. |
| [Migration](https://opx77-framework.github.io/opx77_doc/docs/migration/from-opx77) | From the old `opx77_*` resources, and the release notes. |

The site is also served as plain text for tools and assistants: `/opx77_doc/llms.txt`.

## Built with

[Fumadocs](https://fumadocs.dev) on Next.js, exported as static HTML and deployed to
GitHub Pages: fumadocs-core / fumadocs-ui 16, fumadocs-mdx 15, Next 16, React 19,
Tailwind v4, Orama static search. Modelled on the
[overextended docs](https://github.com/overextended/overextended.github.io).

## Run it locally

Requirements: **Node.js 24** and npm.

```bash
npm ci
npm run dev            # http://localhost:3000/opx77_doc/
npm run build          # static export to out/
npm start              # serve out/ (open /opx77_doc/)
```

## Checks

```bash
node scripts/check-content.mjs   # MDX compiles, front matter, internal links and anchors
npm run types:check
npm run check:api                # every published name of the framework has its page anchor
```

`check:api` boots the real `opx_infinity` manifest on its stub host and fails on any
module, command, export, event, config key or `OPX.*` function the docs do not
document. It needs `opx_infinity` and `opx_lib` checked out next to this repository and
desktop **Lua 5.4**; on CI, with no framework checkout, it reports a skip.

Pushing to `main` runs [`deploy.yml`](.github/workflows/deploy.yml): install, content
check, coverage check, type check, build, deploy to GitHub Pages. Pull requests run the
same build without deploying.

## Contributing

Corrections are very welcome: a wrong sentence on this site costs every operator who
reads it. Read [`CONTRIBUTING.md`](CONTRIBUTING.md) for how the pages are written
(snippets explain, prose stays short; every published name has an anchor; nothing is
documented that was not read in the code), how to add a module, and how old URLs are
kept working. Report a problem with the *Documentation issue* form, or ask on
[Discord](https://discord.gg/xpSuYgEYsU).

Everyone taking part follows the
[Code of Conduct](https://github.com/opx77-framework/.github/blob/main/CODE_OF_CONDUCT.md).

## Security

A vulnerability in the framework goes through a
[private security advisory](https://github.com/opx77-framework/opx_infinity/security/advisories/new),
never a public issue or pull request here; see the
[security policy](https://github.com/opx77-framework/.github/blob/main/SECURITY.md).

## License

The documented resources (`opx_infinity`, `opx_lib`) are MIT licensed. Copyright © 2026
Luís MOUTA.

## Credits

Written by **dop42** and the OPX//77 contributors. Built with
[Fumadocs](https://fumadocs.dev); structure and style after the
[overextended docs](https://github.com/overextended/overextended.github.io).
Support the project on [Tipeee](https://fr.tipeee.com/dop42/).

<sub>OPX//77 is an independent community project and is not affiliated with or endorsed by CD PROJEKT RED.</sub>
