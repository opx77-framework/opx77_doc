# opx77_doc

Documentation for **OPX//77**, a roleplay framework for
[OPEN//77](https://open2077.net), the multiplayer platform for Cyberpunk 2077.

Published at <https://opx77-framework.github.io/opx77_doc/>.

## What is in here

MkDocs Material sources. `docs/` holds the pages, `mkdocs.yml` holds the
configuration and the navigation.

```text
docs/
├── index.md            what OPX//77 is, and the seven resources
├── getting-started.md  installing on an Open77 server
├── architecture.md     why the framework is shaped the way it is
├── platform.md         what the Open77 platform provides and constrains
└── resources/          one page per resource
```

## Building locally

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/mkdocs serve      # http://127.0.0.1:8000
.venv/bin/mkdocs build --strict
```

`--strict` turns warnings into errors. CI builds with it, so a broken internal
link fails the deploy rather than shipping.

## Deployment

Pushing to `main` runs `.github/workflows/deploy.yml`, which builds the site
and publishes it to GitHub Pages through the GitHub Actions source.

## License

The documented resources are MIT licensed. Copyright © 2026 Luis MOUTA.

OPX//77 is an independent community project and is not affiliated with or
endorsed by CD PROJEKT RED.
