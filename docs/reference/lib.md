---
title: Shared library (lib/)
description: Every helper in opx_infinity's lib/ directory — results, text, numbers, validation, hooks, locales, citizen ids, job gates, placed spots, storage, audit logging and the WebUI surface — with parameters and return shapes.
---

# Shared library (`lib/`)

`lib/` holds the plain helpers every module in `opx_infinity` uses: result values, text and number checks, hooks, the locale catalogue, citizen ids, the job gate, placed spots, database access, the audit log and the WebUI surface wrapper. They are loaded before any module, on the side shown. Like the rest of `OPX`, they are only reachable from code running inside `opx_infinity`. A separate resource can use the client-side [`opx_lib`](opx-lib.md) instead, which is a different library.

Runtime functions (`OPX.Modules`, `OPX.Scheduler`, `OPX.Refuse` …) are on [Core runtime](core.md).

## Result {#result}

`lib/shared/result.lua`, both sides. A Result is `{ ok = true, value = v }` or `{ ok = false, error = code, detail = text? }`. `error` is a stable code you can branch on; `detail` is for the log only. See [Error codes](error-codes.md#result).

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-result-ok"></a>`OPX.Result.Ok` | both | `value?` | `{ ok = true, value }` | `value` may be `nil`. |
| <a id="opx-result-err"></a>`OPX.Result.Err` | both | `code, detail?` | `{ ok = false, error, detail }` | |

## Table {#table}

`lib/shared/table.lua`, both sides.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-table-deepcopy"></a>`OPX.Table.DeepCopy` | both | `source, seen?` | copy | Copies keys and values; safe on self-referencing tables. |
| <a id="opx-table-count"></a>`OPX.Table.Count` | both | `source` | `integer` | Every key, array part included. |

## String {#string}

`lib/shared/string.lua`, both sides.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-string-length"></a>`OPX.String.Length` | both | `text` | `integer\|nil` | Length in characters; `nil` if not valid UTF-8. Bytes when the `utf8` library is missing. |
| <a id="opx-string-trim"></a>`OPX.String.Trim` | both | `text` | `string` | Removes leading and trailing whitespace, in linear time. |
| <a id="opx-string-interpolate"></a>`OPX.String.Interpolate` | both | `text, params?` | `string` | Replaces `{name}` with `params.name`. Unknown names stay as written. |
| <a id="opx-string-random"></a>`OPX.String.Random` | both | `template` | `string` | `A` → random letter, `1` → random digit, `.` → either; other characters are copied. |

## Math {#math}

`lib/shared/math.lua`, both sides.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-math-clamp"></a>`OPX.Math.Clamp` | both | `value, low, high` | `number` | |
| <a id="opx-math-isfinite"></a>`OPX.Math.IsFinite` | both | `value` | `boolean` | `true` only for a number that is not NaN or ±infinity. |
| <a id="opx-math-finite"></a>`OPX.Math.Finite` | both | `value` | `number\|nil` | `tonumber(value)` if finite. No size cap (unlike `OPX.Text.Finite`). |
| <a id="opx-math-distancesquared"></a>`OPX.Math.DistanceSquared` | both | `a, b` — `{ x, y, z? }` | `number` | Squared distance; a missing `z` counts as 0. |
| <a id="opx-math-groupdigits"></a>`OPX.Math.GroupDigits` | both | `value, separator?` | `string` | Whole part grouped by thousands, separator a space by default: `1234567` → `1 234 567`. |

## Text {#text}

`lib/shared/text.lua`, both sides. Display text, measured in characters, never split inside a UTF-8 character.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-text-span"></a>`OPX.Text.Span` | both | `text, maximum` | `integer` | Byte length of the first `maximum` characters. |
| <a id="opx-text-clean"></a>`OPX.Text.Clean` | both | `value, maximum, ellipsis?` | `string\|nil` | Replaces control characters with spaces and cuts to `maximum` characters, adding `ellipsis` if cut. Numbers are converted; other non-strings answer `nil`. |
| <a id="opx-text-bytes"></a>`OPX.Text.Bytes` | both | `text, limit` | `string` | Cuts to at most `limit` bytes on a character boundary. |
| <a id="opx-text-finite"></a>`OPX.Text.Finite` | both | `value` | `number\|nil` | A finite number within ±2^53, else `nil`. |
| <a id="opx-text-integer"></a>`OPX.Text.Integer` | both | `value` | `integer\|nil` | `Finite`, and whole. |
| <a id="opx-text-rest"></a>`OPX.Text.Rest` | both | `args, first` | `string\|nil` | Joins command arguments from index `first` with spaces. Uses `args.n` when set. `nil` when nothing is left. |
| <a id="opx-text-switch"></a>`OPX.Text.Switch` | both | `value` | `boolean\|nil, 'invalid'?` | `on/true/1/yes` → `true`, `off/false/0/no` → `false`, `nil` → `nil`, anything else → `nil, 'invalid'`. |
| <a id="opx-text-slug"></a>`OPX.Text.Slug` | both | `value` | `string\|nil` | Lower-cased; 1–32 characters of letters, digits, `_` and `-`, else `nil`. |

## Validate {#validate}

`lib/shared/validate.lua`, both sides. For values that came from a client. Both answer a [Result](#result).

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-validate-text"></a>`OPX.Validate.Text` | both | `value, opts?` — `{ min = 1, max = 255, pattern? }` | Result, value is the trimmed text | Codes: `type`, `too-long`, `not-utf8`, `too-short`, `format`. Input longer than `max × 4 + 16` bytes (at most 1024) is refused before any work. |
| <a id="opx-validate-number"></a>`OPX.Validate.Number` | both | `value, opts?` — `{ integer?, min?, max? }` | Result, value is the number | Codes: `type`, `not-finite`, `not-integer`, `too-small`, `too-large`. |

## Hooks {#hooks}

`lib/shared/hooks.lua`, both sides. Named points where code inside `opx_infinity` can veto an action.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-hooks-register"></a>`OPX.Hooks.Register` | both | `name, fn(payload), priority?` | `integer` id | Lower priority runs first; equal priorities keep registration order. Raises if `name` is not a string or `fn` not a function. |
| <a id="opx-hooks-remove"></a>`OPX.Hooks.Remove` | both | `id` | `boolean` removed | Also stops a trigger already in progress from calling it. |
| <a id="opx-hooks-trigger"></a>`OPX.Hooks.Trigger` | both | `name, payload` | `boolean` allowed | Runs every hook in order. Stops and answers `false` at the first hook that returns exactly `false`. A hook that raises is logged and skipped. `true` when no hook is registered. |

Hook points raised by the shipped modules (server side, all in `character`):

| Name | Payload | A `false` does |
|---|---|---|
| `money:beforeAdd` | `{ player, moneyType, amount, reason }` | refuses the credit |
| `money:beforeRemove` | `{ player, moneyType, amount, reason }` | refuses the debit |
| `money:beforeSet` | `{ player, moneyType, amount, reason }` | refuses the change |
| `paycheck:before` | `{ player, amount }` | skips that player's paycheck |
| `character:loading` | `{ citizenId, entity, data = {} }` | nothing: the result is not read. Hooks fill `data` (the `appearance` module puts `clothing` there). |

Payload fields and refusal codes are on the [character](../modules/character.md) page.

## Locale {#locale}

`lib/shared/locale.lua`, both sides. Language catalogues. English (`en`) is always the fallback. The active language comes from [`LOCALE`](core-config.md#config-shared-locale).

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-locale-register"></a>`OPX.Locale.Register` | both | `code, strings` — `table<key, text>` | — | Merges keys into that language; existing keys are replaced. |
| <a id="opx-locale-set"></a>`OPX.Locale.Set` | both | `code` | `boolean` | Changes the active language. `false` for a non-string or empty code. |
| <a id="opx-locale-current"></a>`OPX.Locale.Current` | both | — | `string` | The active language code. |
| <a id="opx-locale-exists"></a>`OPX.Locale.Exists` | both | `key` | `boolean` | In the active or the fallback catalogue. |
| <a id="opx-locale-text"></a>`OPX.Locale.Text` | both | `key, params?` | `string` | Active language, then English, then the key itself. `{name}` placeholders are filled from `params`. |
| <a id="opx-locale-catalogue"></a>`OPX.Locale.Catalogue` | both | — | `table<key, text>` | A flat copy: English with the active language on top. Sent to the WebUI page. |

The global function `locale(key, params)` is `OPX.Locale.Text`.

## CitizenId {#citizenid}

`lib/shared/citizenid.lua`, both sides. A citizen id is seven symbols from `34679ACDEFGHJKMNPRTWXYZ`, written `XXX-XXXX`. The seventh is a check symbol (weighted sum modulo 23), so one wrong symbol or two swapped neighbours are caught.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-citizenid-build"></a>`OPX.CitizenId.Build` | both | `values` — six integers | `string` | Builds the id from six values (each taken modulo 23) and adds the check symbol. |
| <a id="opx-citizenid-generate"></a>`OPX.CitizenId.Generate` | both | `rng?(low, high)` | `string` | A random id. `rng` defaults to `math.random`. Does not check the database for collisions. |
| <a id="opx-citizenid-parse"></a>`OPX.CitizenId.Parse` | both | `input` | Result, value is the grouped id | Case-insensitive; spaces, `-` and `_` are ignored. Codes: `type`, `length` (more than 32 bytes, or not 7 symbols), `alphabet`, `checksum`. |

`OPX.CitizenId.ALPHABET` holds the symbol set. Changing it invalidates every id already issued.

## Anchors {#anchors}

`lib/shared/anchors.lua`, both sides. One set of screen positions for floating surfaces.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-anchors-resolve"></a>`OPX.Anchors.Resolve` | both | `value, fallback, where` | `string` | `value` if it is one of the nine positions, else `fallback` (or `'center'` if `fallback` is not valid either). A wrong non-nil value is logged, naming `where`. |

`OPX.Anchors.ALL`: `top-left`, `top-center`, `top-right`, `left`, `center`, `right`, `bottom-left`, `bottom-center`, `bottom-right`. Not every module uses this set yet; check each module's `ANCHOR` key.

## JobGate {#jobgate}

`lib/shared/jobgate.lua`, both sides. Decides whether a character may use something gated by job. Used by `elevators`, `gunsmith`, `hauling`, `teleports` and `blips`; `shops` asks the character module instead.

### The JOBS format {#jobs-format}

In a module config, a gated thing carries:

```lua
JOBS = { ncpd = 2, medic = 0 },  -- job name -> minimum grade level
ON_DUTY = true,                  -- optional: must be on duty in that job
```

- One matching job is enough. A minimum of `0` means "anyone holding the job".
- No `JOBS`, or an empty one, means public: always open, even with no character data.
- A minimum that is not a number never matches (the gate stays shut), and `Problems` reports it.

The module turns this into a requirement `{ jobs = JOBS, onDuty = ON_DUTY }` and passes a snapshot of the character:

```lua
{ job  = { name = 'ncpd', grade = { level = 2 }, onDuty = true },
  jobs = { ncpd = 2, fixer = 0 },  -- every membership, grade only
  atMs = OPX.Now() }               -- when the snapshot was read
```

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-jobgate-evaluate"></a>`OPX.JobGate.Evaluate` | both | `requirement, snapshot, nowMs, policy?` | `allowed, code?` | `policy`: `{ maxAgeMs = 0, membership = 'primary' }`. With `membership = 'primary'` only the worked job counts; `'any'` also counts other memberships for the grade (never for on-duty). A gated requirement fails on any doubt. Codes, nearest miss first: `off_duty`, `grade_too_low`, `job_required`; also `no_character` and `job_stale` (snapshot older than `maxAgeMs`, from the future, or a clock that cannot be read). |
| <a id="opx-jobgate-problems"></a>`OPX.JobGate.Problems` | both | `jobs, where, lines?` | `string[]` | Appends one line per malformed `JOBS` entry (not a table, or a name/grade that is not string → number). Job names are not checked against the character config. |

## Spots {#spots}

`lib/shared/spots.lua`, both sides. The shared format for places an operator writes down as coordinates and a player walks to. Used by `garages`, `dealership` and `clothing` (full record), and by `teleports`, `elevators`, `gunsmith` and `hauling` (coordinate box and marker look).

### The spot format {#spot-format}

In a config file, spots are a table keyed by spot key, with upper-case fields:

```lua
SPOTS = {
  watson_kabuki = { KIND = 'garage', LABEL = 'Kabuki', X = -1442.2, Y = 127.4, Z = 18.0,
                    HEADING = 90.0, BUCKET = 0 },
}
```

| Field | Rule |
|---|---|
| key | String, 1 to `spec.maxKey` characters. |
| `KIND` | Required only when the module has kinds; one of `spec.kinds`, case-insensitive. |
| `LABEL` | Optional string; defaults to the key. |
| `X`, `Y`, `Z` | Finite numbers within ±1 000 000 (`OPX.Spots.BOUND`). |
| `HEADING` | Only for modules whose spec has `heading`; finite number, default `0.0`. |
| `BUCKET` | Whole number `>= 0`, default `0`. |

A spot that breaks a rule is refused with a message and skipped. On the wire (server to client) the same record uses lower-case fields: `key, label, kind, x, y, z, heading, bucket`.

A module's **spec** says how its spots differ: `{ noun, maxKey, kinds?, kindNames?, heading? }`. `noun` is the word used in refusals (`'spot'`, `'dealer'`, `'store'`).

### The marker format {#marker-format}

```lua
MARKER = { shape = 'ring', style = 'interaction', RADIUS = 1.5 },
MAX_DISTANCE = 60,     -- metres a marker is drawn from
GROUND_OFFSET = 0.06,  -- metres the marker sits above the floor
```

| Field | Allowed | Bad value |
|---|---|---|
| `shape` | `ring`, `cylinder` | the module's default shape |
| `style` | `interaction`, `objective`, `spawn`, `danger` | the module's default style |
| `RADIUS` | 0.1–50 | the module's default radius |
| `MAX_DISTANCE` | 1–500 m | the module's default |
| `GROUND_OFFSET` | 0–2 m | `0.06` |

Each field falls back on its own, so one typo does not reset the others.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-spots-coordinate"></a>`OPX.Spots.Coordinate` | both | `value` | `number\|nil` | Finite and within `BOUND`. |
| <a id="opx-spots-integer"></a>`OPX.Spots.Integer` | both | `value` | `integer\|nil` | A whole `Coordinate`. |
| <a id="opx-spots-marker"></a>`OPX.Spots.Marker` | both | `declared, fallback` — `{ shape, style, RADIUS }`, `groundOffset` | `{ shape, style, radius, lift }` | Resolves the marker look per field. |
| <a id="opx-spots-maxdistance"></a>`OPX.Spots.MaxDistance` | both | `value, fallback` | `number` | `value` if 1–500, else `fallback`. |
| <a id="opx-spots-markerproblems"></a>`OPX.Spots.MarkerProblems` | both | `declared, label, lines` | `string[]` | Appends what is wrong with a marker block, using `label` (e.g. `MARKER.avpad`). |
| <a id="opx-spots-drawproblems"></a>`OPX.Spots.DrawProblems` | both | `maxDistance, groundOffset, lines` | `string[]` | Appends what is wrong with `MAX_DISTANCE` and `GROUND_OFFSET`. |
| <a id="opx-spots-fromdefinition"></a>`OPX.Spots.FromDefinition` | both | `spec, key, raw` | `spot\|nil, why?` | One config or database row (upper-case fields). |
| <a id="opx-spots-fromwire"></a>`OPX.Spots.FromWire` | both | `spec, raw` | `spot\|nil, why?` | One wire record (lower-case fields). |
| <a id="opx-spots-serialise"></a>`OPX.Spots.Serialise` | both | `spot` | `table` | The wire record. |
| <a id="opx-spots-coerce"></a>`OPX.Spots.Coerce` | both | `spec, definitions, problems?` | `table<key, spot>` | Builds every spot; refusals are appended to `problems`. |
| <a id="opx-spots-spot"></a>`OPX.Spots.Spot` | both | `spots, key` | `spot\|nil` | Exact key match. |
| <a id="opx-spots-inbucket"></a>`OPX.Spots.InBucket` | both | `spots, bucket` | `spot[]` | Every spot in a bucket, sorted by key. |
| <a id="opx-spots-flatdistancesquared"></a>`OPX.Spots.FlatDistanceSquared` | both | `spot, x, y` | `number\|nil` | Squared horizontal distance (Z ignored). |
| <a id="opx-spots-nearest"></a>`OPX.Spots.Nearest` | both | `spots, x, y, radiusSq` | `spot\|nil, distanceSq?` | Nearest spot within the squared radius; ties go to the lower key. |

`OPX.Spots.SHAPES` and `OPX.Spots.STYLES` hold the two allowed sets.

## Vehicle {#vehicle}

`lib/shared/vehicle.lua`, both sides.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-vehicle-isavrecord"></a>`OPX.Vehicle.IsAvRecord` | both | `record` — TweakDB record name | `boolean` | Whether the record starts with one of [`AV_PREFIXES`](core-config.md#config-shared-av-prefixes), lower-cased. The one rule `garages`, `dealership` and `admin` share. |
| <a id="opx-vehicle-avlift"></a>`OPX.Vehicle.AvLift` | both | `value` — a module's `AV_LIFT` | `number` | Metres above ground an AV is created at. `value` if 0–10, else `1.2`. |
| <a id="opx-vehicle-avliftproblem"></a>`OPX.Vehicle.AvLiftProblem` | both | `value, lines` | `string[]` | Appends a line when `AV_LIFT` is not 0–10. |

## Storage {#storage}

`lib/server/storage.lua`, server only. The only door to the database (the MySQL bridge, which needs the `database.access` permission). Every call **yields**: call it from a thread, never at file scope. Every call answers a [Result](#result) and never raises.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-storage-query"></a>`OPX.Storage.Query` | server | `sql, params?` | Result: list of rows | |
| <a id="opx-storage-single"></a>`OPX.Storage.Single` | server | `sql, params?` | Result: one row or `nil` | `nil` means no row, not a failure. |
| <a id="opx-storage-scalar"></a>`OPX.Storage.Scalar` | server | `sql, params?` | Result: one value | |
| <a id="opx-storage-insert"></a>`OPX.Storage.Insert` | server | `sql, params?` | Result: inserted id | |
| <a id="opx-storage-update"></a>`OPX.Storage.Update` | server | `sql, params?` | Result: rows affected | Also for DDL. |
| <a id="opx-storage-execute"></a>`OPX.Storage.Execute` | server | `sql, params?` | Result: rows affected | Same as `Update`. |
| <a id="opx-storage-transaction"></a>`OPX.Storage.Transaction` | server | `statements` — `{ { query, parameters }, … }` | Result: `true` | All or nothing. Codes: `no-database`, `transaction-raised`, `transaction-failed` (rolled back). |
| <a id="opx-storage-decode"></a>`OPX.Storage.Decode` | server | `value, fallback?` | `table\|fallback` | Decodes a JSON column (string or already a table). A bad value answers `fallback`. |
| <a id="opx-storage-nullable"></a>`OPX.Storage.Nullable` | server | `value` | `string` | JSON-encodes `value`, or `''` for `nil`. Pair it with `NULLIF(@x, '')` in the SQL: the bridge drops `nil` parameters. |
| <a id="opx-storage-ready"></a>`OPX.Storage.Ready` | server | — | `boolean, reason` | Probes `SELECT 1` once and remembers the answer for the life of the resource. |
| <a id="opx-storage-applyschema"></a>`OPX.Storage.ApplySchema` | server | `statements` — `string[]` | Result: count | Runs each statement in order; stops at the first failure with `schema-failed` and the table name as `detail`. Use [`OPX.Schema.Add`](core.md#opx-schema-add) rather than calling it. |

Codes for the single-statement calls: `no-database` (bridge not installed), `query-failed` (`detail` holds the raw database error; log it, never show it to a player). Use named parameters (`@citizen`), and never put a SQL comment inside a statement.

## Carry {#carry}

`lib/server/storage.lua`, server only. State that survives a resource reload, kept in the host's one-value-per-resource store (`Open77.state`) and split into namespaces so modules do not overwrite each other.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-carry-load"></a>`OPX.Carry.Load` | server | `namespace` | `any` | What that namespace carried across the last reload, or `nil`. |
| <a id="opx-carry-save"></a>`OPX.Carry.Save` | server | `namespace, value` | `ok, reason?` | Stores a JSON-encodable value; `nil` clears that namespace only. Reasons: `bad-namespace`, `no-state-api`, or the host's refusal. |

## Audit {#audit}

`lib/server/audit.lua`, server only. Writes one greppable line per entry to the server log: `[audit] event=… severity=… citizen=… user=… player=… message="…" data=…`. Text is stripped of control characters and cut. Never raises.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-audit-log"></a>`OPX.Audit.Log` | server | `entry` — `{ event, severity?, message?, data?, source?, citizenId?, userId? }` | — | `severity`: `debug`, `info` (default), `warn`, `error`. `message` and `data` are cut to 200 characters. The same event from the same owner within 10 s is collapsed; the next line says `[+N suppressed]`. `info`/`debug` events starting `money.` or `character.` are never collapsed. |
| <a id="opx-audit-player"></a>`OPX.Audit.Player` | server | `player, event, message?, data?` | — | `Log` with `source`, `citizenId` and `userId` taken from `player.PlayerData`. |
| <a id="opx-audit-security"></a>`OPX.Audit.Security` | server | `event, message?, data?, source?` | — | A `warn` entry for a refused or suspicious request. Pass `source`, or one player's spam hides everyone else's. |
| <a id="opx-audit-safe"></a>`OPX.Audit.Safe` | server | `value, maximum?` | `string` | Any value as log-safe text: control characters become spaces, cut to `maximum` characters (default 64) with `...`. Use it on any text a client sent before you log it. |
| <a id="opx-audit-forget"></a>`OPX.Audit.Forget` | server | `source, citizenId?` | — | Drops a departing player's dedupe windows. |

## OPX.Lib {#opx-lib}

`lib/client/lib.lua`, client only. Loads [`opx_lib`](opx-lib.md) once with `require('@opx_lib')` and stores it as `OPX.Lib`. Raises at load if `opx_lib` is not running. Inside `opx_infinity`, use `OPX.Lib.Input`, `OPX.Lib.Rpc` and the rest instead of requiring it again. The server has no `require`, so `OPX.Lib` is `nil` there.

## Surface {#surface}

`lib/client/surface.lua`, client only. A thin wrapper over one WebUI page. The core builds the runtime's page with it; modules use [`OPX.UI`](core.md#ui) instead. Channel names are given without the `<id>:` prefix.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-surface-create"></a>`OPX.Surface.Create` | client | `spec` — `{ id, entry, layer?, zIndex?, fps?, width?, height?, transparent?, visible? }` | `surface\|nil, why?` | Defaults: layer `hud`, 1920×1080, 30 fps, zIndex 700, transparent, visible. Wires `ready` and `diag`. Reasons: `bad_spec`, `no_webui`, or the host's. |
| <a id="opx-surface-on"></a>`OPX.Surface.On` | client | `surface, channel, handler?` | remover function, or `boolean` | Adds a handler (several may listen). `nil` clears the channel. Payloads that arrived before any handler (up to 8) are replayed to the first one. Handlers run under `pcall`. |
| <a id="opx-surface-send"></a>`OPX.Surface.Send` | client | `surface, channel, payload?` | `sent, refused` | `false` before `ready` or after `Destroy`. `refused` is `true` when the host rejected the payload; that is also sent once per channel to the server journal with `OPX.Note`. |
| <a id="opx-surface-wire"></a>`OPX.Surface.Wire` | client | `surface, channel` | `boolean` | Registers the host listener for a channel before any handler exists, so early payloads are held, not lost. |
| <a id="opx-surface-focus"></a>`OPX.Surface.Focus` | client | `surface, keyboard, cursor` | `boolean` | Gives the page the keyboard and/or the cursor. |
| <a id="opx-surface-hasfocus"></a>`OPX.Surface.HasFocus` | client | `surface` | `boolean` | |
| <a id="opx-surface-visible"></a>`OPX.Surface.Visible` | client | `surface, visible` | `boolean` | Shows or hides the page without destroying it. |
| <a id="opx-surface-destroy"></a>`OPX.Surface.Destroy` | client | `surface` | — | Destroys the page; later `Send` and `Focus` answer `false`. |
