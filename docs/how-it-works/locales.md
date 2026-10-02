---
title: Text and locales
description: Player-facing text in opx_infinity comes from English and French catalogues looked up by key with OPX.Locale or the locale() shorthand; the server language is set once in config/shared.lua.
---

# Text and locales

Every sentence a player reads comes from a **catalogue**, looked up by key.
Logs, console answers and error codes stay in English. The language of the
server is [`OPX.Config.SHARED.LOCALE`](../reference/core-config.md#config-shared-locale)
in `config/shared.lua` (`'en'` by default; `en` and `fr` ship).

## Where text lives {#files}

| File | Holds |
|---|---|
| `locales/en.lua`, `locales/fr.lua` | runtime-wide text, mostly the shared refusal codes (`error.*`) |
| `modules/<id>/locales.lua` | one module's text, both languages in one file |

Each file calls [`OPX.Locale.Register(code, strings)`](../reference/lib.md#opx-locale-register)
once per language. English and French must define **the same keys with the same
`{placeholders}`**.

```lua
OPX.Locale.Register('en', {
	['thing.done'] = 'You picked up {count} items.',
})
OPX.Locale.Register('fr', {
	['thing.done'] = 'Vous avez ramassé {count} objets.',
})
```

## Looking text up {#lookup}

| Call | Answers |
|---|---|
| `locale(key, params)` | The text, with `{name}` placeholders filled. Global shorthand for `OPX.Locale.Text`. |
| [`OPX.Locale.Text(key, params)`](../reference/lib.md#opx-locale-text) | Same. |
| [`OPX.Locale.Exists(key)`](../reference/lib.md#opx-locale-exists) | Whether the key is in the active or English catalogue. |
| [`OPX.Locale.Catalogue()`](../reference/lib.md#opx-locale-catalogue) | Every key, English merged under the active language. The page gets its text this way. |

A missing key falls back to English, then to the key itself, so an untranslated
string shows its key on screen.

## Codes are keys {#codes}

Refusal codes such as `error.tooFast` are also catalogue keys. The server sends
the code; the client turns it into text. **Do not rename a key**: it may be a
code on the wire. [`OPX.RefusalKey`](../reference/core.md#opx-refusalkey) turns
any code that has no text (for example a storage error) into
`error.unavailable` before a player sees it. See
[Error codes](../reference/error-codes.md).

## Adding a language {#new-language}

Add a `locales/<code>.lua` and a `OPX.Locale.Register('<code>', …)` block in
every `modules/<id>/locales.lua`, list any new file in `open77.lua`, then set
`LOCALE` to the new code. Keys you leave out fall back to English.
