---
title: Error codes
description: The shared refusal vocabulary of opx_infinity — how a refusal reaches a player, the core error.* locale keys, and the Result convention with the codes the shared library answers.
---

# Error codes

When `opx_infinity` says no, it answers with a short code. A code shown to a player is always a locale key, such as `error.tooFast`, so it is translated and never leaks internals. A code that stays in Lua, such as `query-failed`, is for the caller and the log. This page lists the codes shared by the whole runtime. Each module page has a **Refusal codes** section for its own (`money.insufficient`, `character.notFound` and so on); start from the [module list](../modules/index.md).

## How a refusal reaches a player {#refusal-path}

| Step | What happens |
|---|---|
| 1 | Server code calls [`OPX.Refuse(source, code, operation, icon?)`](core.md#opx-refuse). |
| 2 | [`OPX.RefusalKey(code)`](core.md#opx-refusalkey) checks the code is a locale key that exists. If not, the player gets `error.unavailable` and the real code is written to the server log. |
| 3 | The client receives [`opx:net:runtime:notify`](runtime-events.md#opx-net-runtime-notify) and shows `locale(code)` as an error toast. |

`operation` only tells the client which request was refused; the toast does not show it. The same rule applies to [`OPX.NotifyLocale`](core.md#opx-notifylocale).

## Core locale keys {#core-keys}

Registered in `locales/en.lua` and `locales/fr.lua`.

| Code | English | French | When |
|---|---|---|---|
| <a id="error-unavailable"></a>`error.unavailable` | That is not available right now. | Ce n'est pas disponible pour le moment. | The fallback for any code that has no locale entry, and the answer of a page request whose Lua handler raised. |
| <a id="error-badrequest"></a>`error.badRequest` | That request could not be read. | Cette requete n'a pas pu etre lue. | The arguments of a request were malformed. |
| <a id="error-payloadrefused"></a>`error.payloadRefused` | That answer was too large to display. | Cette reponse etait trop volumineuse pour etre affichee. | The host refused a reply to the page as too large ([`OPX.UI.Answer`](core.md#opx-ui-answer)). |
| <a id="error-rpc-timeout"></a>`error.rpc_timeout` | That took too long. Try again. | Cela a pris trop de temps. Réessayez. | Set by the page when Lua never answered a request. |
| <a id="error-rpc-failed"></a>`error.rpc_failed` | That did not go through. | Cela n'a pas abouti. | Set by the page when Lua answered a failure with no code. |
| <a id="error-toofast"></a>`error.tooFast` | Slow down. | Doucement. | A command's `cooldownMs` window, or an `OPX.Cooling` check, was still open. |
| <a id="error-nopermission"></a>`error.noPermission` | You may not do that. | Vous ne pouvez pas faire cela. | An access check failed, for example a command alias whose full command the player may not run. |

### Export codes {#export-codes}

Answered by the [creator exports](../creators/index.md#answer) in `{ ok = false, error = <code> }`.

| Code | English | French | When |
|---|---|---|---|
| <a id="export-callerdenied"></a>`export.callerDenied` | That resource may not make this call. | Cette ressource n'est pas autorisée à faire cet appel. | The calling resource is not in the allowlist (`SERVER.EXPORTS.READ`/`WRITERS`, `CLIENT.EXPORTS.CALLERS`), or the host named no caller. |
| <a id="export-badargument"></a>`export.badArgument` | An argument of that call could not be read. | Un argument de cet appel n'a pas pu être lu. | Wrong type, unknown player id, bad citizen id, name or count out of bounds. |
| <a id="export-booting"></a>`export.booting` | The server is still starting. Try again in a moment. | Le serveur démarre encore. Réessayez dans un instant. | The server boot has not finished. |
| <a id="export-mustawait"></a>`export.mustAwait` | That call reaches the database: make it with Open77.exports.call and await it. | Cet appel atteint la base de données : faites-le avec Open77.exports.call et attendez-le. | A call that may wait was made synchronously. Nothing was done. |

The inventory adds `stash_namespace` and `stash_cap` (text `inventory.error.stash_namespace` / `inventory.error.stash_cap`) for stashes created through `AddToStash`; see [inventory](../modules/inventory.md#codes).

The `character` module adds `error.notLoggedIn` ("You are not in the world yet."): the action needs a loaded character. The `weather.*` keys in the same core files belong to the [weather](../modules/weather.md) module.

## The Result convention {#result}

Lua functions that can fail answer a Result instead of raising:

```lua
{ ok = true,  value = v }                     -- success; v may be nil
{ ok = false, error = 'code', detail = '…' }  -- failure
```

Branch on `ok` and `error`. `detail` is free text for the log; never show it to a player. Build them with [`OPX.Result.Ok` / `OPX.Result.Err`](lib.md#result) (or `Lib.Result` in [`opx_lib`](opx-lib.md#results), same shape). Some functions answer a plain pair `ok, reason` instead; each function's row says which.

### Codes from the shared library {#lib-codes}

These are Lua-side codes. Turn them into a locale key before you refuse a player.

| Code | From | Meaning |
|---|---|---|
| `no-database` | `OPX.Storage.*` | The MySQL bridge is not installed. |
| `query-failed` | `OPX.Storage.*` | The statement raised. `detail` holds the raw database error. |
| `transaction-raised` | `OPX.Storage.Transaction` | The bridge raised. |
| `transaction-failed` | `OPX.Storage.Transaction` | The bridge rolled back. |
| `schema-failed` | `OPX.Storage.ApplySchema` | A `CREATE TABLE` failed; `detail` is the table. |
| `type`, `too-short`, `too-long`, `not-utf8`, `format` | `OPX.Validate.Text` | See [Validate](lib.md#validate). |
| `type`, `not-finite`, `not-integer`, `too-small`, `too-large` | `OPX.Validate.Number` | |
| `type`, `length`, `alphabet`, `checksum` | `OPX.CitizenId.Parse` | |
| `no_character`, `job_stale`, `job_required`, `grade_too_low`, `off_duty` | `OPX.JobGate.Evaluate` (second return) | See [JobGate](lib.md#jobgate). |
| `bad-namespace`, `no-state-api` | `OPX.Carry.Save` (second return) | |
| `invalid_source`, `duplicate`, `notification_refused`, or the host's reason | `OPX.Notify` (second return) | |
| `toast_must_be_a_table`, `invalid_toast_message`, `invalid_toast_icon`, `no_such_toast`, `patch_must_be_a_table`, `payload_refused`, `surface_unavailable` | `OPX.Toast.*` (second return) | |

`opx_lib` has its own codes, listed per function on [its page](opx-lib.md).
