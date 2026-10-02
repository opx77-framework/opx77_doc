---
title: Core runtime (OPX.*)
description: Every function the opx_infinity core puts on the OPX table — modules, contracts, events, scheduler, commands, refusals, the readiness gate, sessions, buckets, tunables, schema, notes, the WebUI bridge and toasts.
---

# Core runtime (`OPX.*`)

The core is the part of `opx_infinity` under `core/`. It loads before every module and gives them one shared `OPX` table: the module registry, contracts, event names, the scheduler, chat commands, refusals and toasts, the readiness gate, routing buckets, tunables and the WebUI bridge. Use this page when you write a module, or code that runs inside `opx_infinity`. Nothing here is reachable from another resource: `opx_infinity` publishes no Open77 exports.

The helpers under `lib/` (`OPX.Result`, `OPX.Storage`, `OPX.Hooks`, `OPX.Locale` and the rest) are on [the library page](lib.md). Config keys are on [Core configuration](core-config.md). Event and page channel names are on [Runtime events](runtime-events.md).

**Side** says where the function exists. A server-only function is `nil` on the client, and the other way round.

## Values {#values}

| Name | Side | Type | Notes |
|---|---|---|---|
| <a id="opx-version"></a>`OPX.VERSION` | both | `string` | The manifest version, read from the host (`Open77.resource.version()` on the client, the manifest metadata on the server). Falls back to the literal in `core/shared/main.lua`. |
| <a id="opx-isserver"></a>`OPX.IsServer` | both | `boolean` | `true` in the server VM (`TriggerClientEvent` exists). |
| <a id="opx-isclient"></a>`OPX.IsClient` | both | `boolean` | `true` in the client VM (`TriggerServerEvent` exists). |
| <a id="opx-booted"></a>`OPX.Booted` | server | `boolean` | `false` until the server boot has run every phase, then `true` whatever the outcome. |
| <a id="opx-booterror"></a>`OPX.BootError` | server | `string\|nil` | Why the server is degraded: `'no database'`, `'schema failed: <table>'` or `'module failed: <id>'`. Set once, never cleared. A database that comes back later needs a resource restart. |
| <a id="opx-config"></a>`OPX.Config` | both | `table` | `SHARED`, `MODULES`, and `SERVER` (server only) or `CLIENT` (client only). See [Core configuration](core-config.md). |
| <a id="opx-channel"></a>`OPX.Channel` | both | `table` | `{ NET = 'net', LOCAL = 'on', INTERNAL = 'in' }`. Pass one to [`OPX.Event`](#opx-event). |
| <a id="opx-host"></a>`OPX.Host` | both | `table` | Host event names. See [Runtime events](runtime-events.md#host). |
| <a id="opx-glyphs"></a>`OPX.Glyphs` | both | `table<string, true>` | The closed set of icon names the page can draw (`interact`, `person`, `vehicle`, `lock`, `money`, `warning`, …). Toasts, refusals and command notices only accept these. |
| <a id="opx-sessions"></a>`OPX.Sessions` | server | `table<integer, table>` | Live sessions by player id: `source`, `userId`, `displayName`, `connectedAt`, `gateSession`, plus `departing`, `heldAt`, `released` when set. Read it; create and drop sessions only with the functions below. |
| <a id="opx-lib"></a>`OPX.Lib` | client | `table` | The [`opx_lib`](opx-lib.md) library, loaded once with `require('@opx_lib')` by `lib/client/lib.lua`. Loading raises if `opx_lib` is not running. |

## Modules {#modules}

A module declares itself in `modules/<id>/module.lua` and hangs `Init`, `Api`, `Start` and `Stop` on the table it gets back. See [Modules and contracts](../how-it-works/modules-and-contracts.md).

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-modules-declare"></a>`OPX.Modules.Declare` | both | `spec` — `{ id, side?, requires?, optional?, fatal? }` | `table` the module namespace | `side` is `'server'`, `'client'` or `'both'` (default). Raises on a missing id, a duplicate id, an unknown side, or a call after the modules were resolved. A module with `enabled = false` in its config is marked `disabled`; one for the other side is `absent`. |
| <a id="opx-modules-get"></a>`OPX.Modules.Get` | both | `id` | `table\|nil` | The module's namespace (what its files write into). |
| <a id="opx-modules-record"></a>`OPX.Modules.Record` | both | `id` | `table\|nil` | The runtime's record: `Id`, `Side`, `Requires`, `Optional`, `Fatal`, `Module`, `State`, `Reason`. |
| <a id="opx-modules-all"></a>`OPX.Modules.All` | both | — | `table[]` | Every record, in declaration order. |
| <a id="opx-modules-isrunning"></a>`OPX.Modules.IsRunning` | both | `id` | `boolean` | `true` only when the module's state is `started` in this VM. |
| <a id="opx-modules-settings"></a>`OPX.Modules.Settings` | both | `id` | `table` | `OPX.Config.MODULES[id]`, read now, never `nil`. |
| <a id="opx-modules-rebind"></a>`OPX.Modules.Rebind` | both | — | — | Points every module's `Settings` field at its live config. Called once by `Resolve`. |
| <a id="opx-modules-resolve"></a>`OPX.Modules.Resolve` | both | — | `table[]` records in dependency order | Memoised. Raises on a dependency cycle. Marks `disabled` and `unavailable` modules. |
| <a id="opx-modules-resolved"></a>`OPX.Modules.Resolved` | both | — | `boolean` | Whether `Resolve` has run. |
| <a id="opx-modules-run"></a>`OPX.Modules.Run` | both | `between?` — function | `ok, failure?` | Runs `Init`, `Api`, `Start` over every runnable module. Yields between modules, so call it from a thread. `between` runs after `Api` and before `Start`. Answers `false, 'already ran'` on a second call, `false, <id>` when a fatal module failed. Boot calls it; a module never does. |
| <a id="opx-modules-stop"></a>`OPX.Modules.Stop` | both | — | — | Calls `Stop` on every `started` or `failed` module, newest dependency first, and marks it `stopped`. |
| <a id="opx-modules-report"></a>`OPX.Modules.Report` | both | — | `string[]` | One line per module: id, state, reason. |

Module states: `declared`, `started`, `failed`, `disabled`, `absent`, `unavailable`, `stopped`.

## Contracts {#contracts}

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-api-provide"></a>`OPX.Api.Provide` | both | `name, version, implementation` | — | Call from a module's `Api` phase. Raises if two modules provide the same name. |
| <a id="opx-api-get"></a>`OPX.Api.Get` | both | `name, minimum?` | `table\|nil, version?` | `nil` when nobody provides it, or the version is below `minimum`. Use it for an optional dependency. |
| <a id="opx-api-require"></a>`OPX.Api.Require` | both | `name, minimum?` | `table` | Like `Get` but raises when absent. For a module that lists the provider in `requires`. |
| <a id="opx-api-versions"></a>`OPX.Api.Versions` | both | — | `table<string, integer>` | Every published contract, name → version. |
| <a id="opx-api-withdraw"></a>`OPX.Api.Withdraw` | both | `owner` — module id | `string[]` names withdrawn | Called by the lifecycle when a module fails. |

## Events {#events}

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-publish"></a>`OPX.Publish` | server | `name, source, payload` | `boolean` | Raises a **public** server event for every resource on the host: `TriggerEvent(name, source, payload)`. `name` must start with `opx:on:` (anything else raises). `source` is the player id or `nil`; `payload` a plain table built for the event, never a live record. A refusal by the host is logged once per name and answered `false`; it never raises. See [Public server events](../creators/server-events.md). |
| <a id="opx-event"></a>`OPX.Event` | both | `channel, module, verb` | `string` | Builds `opx:<channel>:<module>:<verb>`. `channel` must be `'net'`, `'on'` or `'in'` (use `OPX.Channel`); anything else raises. See [Events and channels](../how-it-works/events.md). |

## Time {#time}

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-now"></a>`OPX.Now` | both | — | `integer` ms | Monotonic milliseconds: `GetGameTimer()` when present, else `Open77.time.monotonic() * 1000`. Not wall-clock time. |

## Scheduler {#scheduler}

The two sides share the names but behave differently. See [The scheduler](../how-it-works/scheduler.md).

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-scheduler-every"></a>`OPX.Scheduler.Every` | both | `name, intervalMs, step` | `integer` handle | **Server:** one thread per job; `intervalMs` is a number or a function re-read every pass; floor 50 ms; first pass one interval after registration; a raising job is logged once per run of failures and never suspended. **Client:** one shared loop, at most 4 due jobs per pass; `intervalMs` must be a number `>= 0` (a function or bad value raises; `0` = every pass); a job that raises 3 times in a row is suspended. |
| <a id="opx-scheduler-cancel"></a>`OPX.Scheduler.Cancel` | both | `handle` | — | Safe on a handle already cancelled. |
| <a id="opx-scheduler-report"></a>`OPX.Scheduler.Report` | both | — | `string[]` | One line per job: name, interval, state. |
| <a id="opx-scheduler-stop"></a>`OPX.Scheduler.Stop` | both | — | — | Stops every job and drops the list. Boot calls it on resource stop. |
| <a id="opx-scheduler-start"></a>`OPX.Scheduler.Start` | client | — | — | Starts the client loop. Called once by client boot; further calls are ignored. |

## Commands {#commands}

Register chat commands here, not with `RegisterCommand`. The host checks the ACL right `command.<name>` before the handler runs.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-command-register"></a>`OPX.Command.Register` | server | `name, opts, handler(source, args, raw)` | — | `opts`: `restricted` (boolean), `help` (locale key), `params` (list of `{ name, help?, optional? }`, passed through as written), `cooldownMs`, `key` (cooldown key, default `command.<name>`). Raises on a duplicate name (case-blind) or a `cooldownMs` that is not a number `>= 0`. Also registers the alias from [`COMMAND_ALIASES`](core-config.md#config-server-command-aliases), if any; a refused alias is logged and skipped. |
| <a id="opx-command-suggestions"></a>`OPX.Command.Suggestions` | server | `source` | `{ name, help?, params }[]` sorted by name | Commands this player may run. An aliased command is listed under its alias. `help` is resolved through the locale now. |
| <a id="opx-command-known"></a>`OPX.Command.Known` | server | `name` — command or alias | `registered, restricted` | Case-blind. An alias answers its command's `restricted` flag. |
| <a id="opx-command-aliases"></a>`OPX.Command.Aliases` | server | — | `table<alias, command>, count` | The aliases that were actually registered. |

### Aliases and the ACL {#aliases}

An alias is registered unrestricted on the host, then checks the ACL right of the **full** command name (`command.opx.admin.self.noclip` for `noclip`) itself. Grant only the long name in `acl.jsonc`. The console (source `0`) is always allowed. A host without `Open77.acl` makes every restricted alias refuse with `error.noPermission`, while the long name still works. An alias may not start with `opx.`, must be 1–64 characters of letters, digits, `_ . : -`, and must not be taken by another resource.

## Answers, refusals and cooldowns {#answers}

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-notify"></a>`OPX.Notify` | server | `source, message, kind?, durationMs?` | `ok, reason?` | Sends a toast through `Open77.notifications.send` (the platform's `open77_notifications` package), titled `SERVER_NAME`, at `NOTIFY_POSITION`, 5000 ms by default. `kind`: `info`, `success`, `warning`, `error`. An identical toast to the same player within 2 s is dropped with `'duplicate'`. Other reasons: `'invalid_source'`, or the host's own refusal. Takes no icon. |
| <a id="opx-notifylocale"></a>`OPX.NotifyLocale` | server | `source, key, params?, kind?` | `ok, reason?` | `OPX.Notify` with the text of a locale key (through `RefusalKey`). |
| <a id="opx-refusalkey"></a>`OPX.RefusalKey` | server | `code` | `string` | `code` if it is a locale key that exists, else `'error.unavailable'` (and a warning in the log). |
| <a id="opx-refuse"></a>`OPX.Refuse` | server | `source, code, operation?, icon?` | — | Sends [`opx:net:runtime:notify`](runtime-events.md#opx-net-runtime-notify) to one player: an error toast with the text of `RefusalKey(code)`. `operation` defaults to `'unknown'`. `icon` is a name from `OPX.Glyphs`; the client drops an unknown one. Does nothing for source `<= 0`. |
| <a id="opx-commandresult"></a>`OPX.CommandResult` | server | `source, accepted, message` | — | Answers a command that reads something back (a list, a dump). Sends [`opx:net:runtime:commandResult`](runtime-events.md#opx-net-runtime-commandresult); the chat module draws it. Cut to 8192 bytes. Source `nil`/`0` prints to the console. |
| <a id="opx-commandnotice"></a>`OPX.CommandNotice` | server | `source, raw, kind, message, toasted?, icon?` | — | One-line toast saying what a command did. Sends [`opx:net:runtime:commandAnswer`](runtime-events.md#opx-net-runtime-commandanswer). `message` is stripped of control characters and cut to 240 characters. `toasted = true` means the action already showed a toast, so the client shows none. An `icon` outside `OPX.Glyphs` is dropped. Source `nil`/`0` prints. |
| <a id="opx-cooling"></a>`OPX.Cooling` | server | `source, key, everyMs` | `boolean` | `true` if `key` was used by this player less than `everyMs` ago; otherwise records the use and answers `false`. The console is never cooled. Not a security check. |
| <a id="opx-forgetcooldowns"></a>`OPX.ForgetCooldowns` | server | `source` | — | Drops a player's cooldowns and toast dedupe windows. The core also does this on disconnect. |

## Readiness gate {#gate}

No player may be moved, spawned, killed or respawned before their gate opens. The core takes part in the gate at load, so every new connection is held in its name. The `character` module drives entry with these functions.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-gate-participate"></a>`OPX.Gate.Participate` | server | — | `boolean` | Declares the core's participation with the [`ENTRY.GATE_MS`](core-config.md#config-server-entry) liveness interval. Called once at load. Logs a warning if no resource emits `open77:session:gameplayReady`. |
| <a id="opx-gate-hold"></a>`OPX.Gate.Hold` | server | `source, reason?` | `boolean` | Takes the hold and stores its session token. `false` with no session or when the host refuses. Raises `opx:in:gate:held`. |
| <a id="opx-gate-release"></a>`OPX.Gate.Release` | server | `source, note?, expectedUserId?` | `boolean` | Releases the hold. `note` reaches every resource as the `onPlayerReady` detail, prefixed `opx_infinity:`. With `expectedUserId`, refuses if the slot now belongs to another account. On a host with no readiness API, answers `true`. Raises `opx:in:gate:released`. |
| <a id="opx-gate-isready"></a>`OPX.Gate.IsReady` | server | `source` | `boolean` | Whether the gate is open. A host read that raises counts as open. |
| <a id="opx-gate-watch"></a>`OPX.Gate.Watch` | server | `source, timeoutMs?, onGiveUp?(source)` | `boolean` started | One thread per player. At the deadline (clamped below `ENTRY.GATE_MS`, default `ENTRY.WATCH_MS`) it calls `onGiveUp`; if that returns `false` the watch stops and leaves the hold to the caller, otherwise the core releases with note `watch-timeout`. Stops early if the slot empties, changes account or is released. |

## Sessions {#sessions}

A session is a connected machine, keyed by the account the host vouches for. A character is loaded onto a session by the `character` module.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-useridof"></a>`OPX.UserIdOf` | server | `playerId` | `string\|nil` | The durable account id (`GetPlayerIdentifier`). `nil` once the player has gone. |
| <a id="opx-displaynameof"></a>`OPX.DisplayNameOf` | server | `playerId` | `string\|nil` | The player's verified display name (`GetPlayerName`). |
| <a id="opx-ensuresession"></a>`OPX.EnsureSession` | server | `playerId` (number or string) | `table\|nil` | The session on a slot, created if needed. If the slot now belongs to another account the old session is dropped first. `nil` when the host vouches for no account. |
| <a id="opx-forgetsession"></a>`OPX.ForgetSession` | server | `playerId` | — | Marks the session `departing`, raises `opx:in:session:forgotten`, then drops it. The core does this itself one frame after a disconnect if no module did. |
| <a id="opx-sessionholds"></a>`OPX.SessionHolds` | server | `playerId` | `boolean` | Whether the slot still belongs to the account the session was made for. |

## Routing buckets {#buckets}

Each player can wait in their own selection bucket (`ENTRY.BUCKET.BASE + playerId`) before a character is placed. A bucket move writes no position and is allowed while the gate is closed. Settings: [`ENTRY.BUCKET`](core-config.md#config-server-entry).

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-buckets-isselection"></a>`OPX.Buckets.IsSelection` | server | `bucket` | `boolean` | Whether the id is in `BASE+1 .. BASE+65535`, even with isolation off. |
| <a id="opx-buckets-placementof"></a>`OPX.Buckets.PlacementOf` | server | `stored` | `integer` | The bucket a stored position places someone in. A selection bucket or an invalid id reads as `WORLD`. |
| <a id="opx-buckets-move"></a>`OPX.Buckets.Move` | server | `source, bucket, why?` | `boolean` | Moves one player. `true` if already there. |
| <a id="opx-buckets-isolate"></a>`OPX.Buckets.Isolate` | server | `source, why?, expectedUserId?` | `boolean` | Moves a player into their own selection bucket and applies the population and lockdown settings to it. `false` when isolation is off, there is no session, the session is departing, or the account does not match. Do not call it for a player with a loaded character. |
| <a id="opx-buckets-release"></a>`OPX.Buckets.Release` | server | `source, why?, expectedUserId?` | `ok, moved` | Moves a player out of a selection bucket into `WORLD`. Leaves any other bucket alone (`true, false`). On resource stop the core releases every session. |

## Tunables {#tunables}

Values an operator can change from the host's tunables panel while the server runs. Server only.

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-tune-declare"></a>`OPX.Tune.Declare` | server | `block` — `table<key, spec>` | — | Call from `Init`. A spec is what the host panel takes, e.g. `{ value = 1000, type = 'integer', min = 250, max = 600000 }`; `value` is the default. Raises on a key declared twice, or after publishing. |
| <a id="opx-tune-publish"></a>`OPX.Tune.Publish` | server | — | `boolean` panel is live | Declares every collected key to the host in one call. Boot calls it between `Api` and `Start`. On a host with no panel, or a refusal, every key reads its default. |
| <a id="opx-tune-get"></a>`OPX.Tune.Get` | server | `key` | `any` | The live value, or the declared default. |
| <a id="opx-tune-number"></a>`OPX.Tune.Number` | server | `key, floor` | `number` | The value as a finite number, never below `floor`. Answers `floor` for an unknown key or a bad value. Read it at the moment of use; do not store it. |
| <a id="opx-tune-known"></a>`OPX.Tune.Known` | server | `key` | `boolean` | Whether anyone declared the key. |

A change raises `opx:in:tune:changed` with the key.

## Schema {#schema}

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-schema-add"></a>`OPX.Schema.Add` | server | `list` — `string[]` | — | Adds `CREATE TABLE IF NOT EXISTS` statements, in foreign-key order. Call from `Init`. |
| <a id="opx-schema-apply"></a>`OPX.Schema.Apply` | server | — | `ok, failedTable?` | Runs every statement through [`OPX.Storage.ApplySchema`](lib.md#opx-storage-applyschema), stopping at the first failure. Boot calls it before `Start`; a failure sets `OPX.BootError`. |

## Notes to the server journal {#note}

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-note"></a>`OPX.Note` | client | `module, text` | `boolean` sent | Writes one line to the **server** journal as `[note] <module> from player <id>: <text>`, and to the client log. For failures and decisions, not ticks: one net event per call, 60 per session (the last one says the budget is spent). Text is cut to 400 characters. Never raises. The server also limits each player to 12 notes per 10 s and 60 per session. |

## WebUI bridge {#ui}

There is one WebUI page (`web/index.html`, id `opx`) for the whole client. `target` is `'overlay'` or `'interactive'`; both name the same page. Channel names are `<module>:<verb>`; the page sees them as `opx:<module>:<verb>`. See [The WebUI page](../how-it-works/webui.md).

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-ui-surface"></a>`OPX.UI.Surface` | client | — | `table\|nil` | The page, created on first call from [`SURFACE`](core-config.md#config-client-surface). `nil` if it could not be built. |
| <a id="opx-ui-overlay"></a>`OPX.UI.Overlay` | client | — | `table\|nil` | Same function as `Surface`. |
| <a id="opx-ui-interactive"></a>`OPX.UI.Interactive` | client | — | `table\|nil` | Same function as `Surface`. |
| <a id="opx-ui-send"></a>`OPX.UI.Send` | client | `target, channel, payload?` | `sent, refused` | `sent` is `false` until the page has said `ready`. `refused` is `true` when the host rejected the payload (too large or not serialisable). |
| <a id="opx-ui-on"></a>`OPX.UI.On` | client | `target, channel, handler(payload)` | `function\|boolean` | Adds a handler. Non-table payloads are dropped. Treat a payload as a request, never as a fact. |
| <a id="opx-ui-answer"></a>`OPX.UI.Answer` | client | `target, ref, payload` | `sent, refused` | Sends `payload` with `ref` on the `reply` channel. If the host refuses it, sends `{ ref, ok = false, error = 'error.payloadRefused' }` instead. |
| <a id="opx-ui-serve"></a>`OPX.UI.Serve` | client | `target, channel, handler(payload) → table` | — | A request handler: the return value is sent back with `Answer` under `payload.ref`. A handler that raises answers `{ ok = false, error = 'error.unavailable' }`. |
| <a id="opx-ui-acquirefocus"></a>`OPX.UI.AcquireFocus` | client | `owner, wants?` — `{ keyboard?, cursor? }` | `boolean` | Pushes `owner` on the focus stack. `keyboard` defaults to `true`, `cursor` to `false`. |
| <a id="opx-ui-releasefocus"></a>`OPX.UI.ReleaseFocus` | client | `owner` | — | Removes `owner`; focus goes to the next owner down, or is dropped. Safe for an owner that never held it. |
| <a id="opx-ui-focusowner"></a>`OPX.UI.FocusOwner` | client | — | `string\|nil` | The owner on top of the stack. |
| <a id="opx-ui-teardown"></a>`OPX.UI.Teardown` | client | — | — | Drops focus and destroys the page. Called on resource stop. |

The page itself can clear the stack: see [`focus:set`](runtime-events.md#page-focus-set).

## Toasts {#toasts}

Client-side toasts drawn on the runtime's own page. To toast a player from the server, use [`OPX.Refuse`](#opx-refuse), [`OPX.CommandNotice`](#opx-commandnotice) or [`OPX.Notify`](#opx-notify).

| Function | Side | Parameters | Returns | Notes |
|---|---|---|---|---|
| <a id="opx-toast-show"></a>`OPX.Toast.Show` | client | `definition` — `{ message, kind?, title?, icon?, durationMs?, id?, stinger? }` | `id\|nil, reason?` | `kind`: `info` (default), `success`, `warning`, `error`. `durationMs` default 5000. Pass `id` to replace a toast already up. `icon` must be in `OPX.Glyphs`. `stinger`: `{ open?, close?, volume? }`, bare audio file names; a bad name is dropped. Reasons: `toast_must_be_a_table`, `invalid_toast_message`, `invalid_toast_icon`, `payload_refused`, `surface_unavailable`. |
| <a id="opx-toast-locale"></a>`OPX.Toast.Locale` | client | `key, params?, kind?, icon?` | `id\|nil, reason?` | `Show` with the text of a locale key. |
| <a id="opx-toast-update"></a>`OPX.Toast.Update` | client | `id, patch` | `ok, reason?` | Changes fields of a toast still up. `icon = ''` removes the icon. A refused patch is rolled back. Reasons: `no_such_toast`, `patch_must_be_a_table`, `invalid_toast_icon`, `payload_refused`, `surface_unavailable`. |
| <a id="opx-toast-dismiss"></a>`OPX.Toast.Dismiss` | client | `id` | — | Takes one toast down early. |
| <a id="opx-toast-clear"></a>`OPX.Toast.Clear` | client | — | — | Takes every toast down. |
| <a id="opx-toast-setdown"></a>`OPX.Toast.SetDown` | client | `down` | — | Hides (`true`) or shows the toast stacks without losing them. The `downed` module calls it. |
| <a id="opx-toast-attach"></a>`OPX.Toast.Attach` | client | — | — | Wires `notify:gone`, `notify:ready` and the two server answer events. Called once by client boot. |

`OPX.Toast.ICONS` is the same table as `OPX.Glyphs`.

## Boot order {#boot}

| Side | Sequence |
|---|---|
| server | Placement-conflict warning → database probe (`OPX.Storage.Ready`) → `Init` → `Api` → `OPX.Tune.Publish` and `OPX.Schema.Apply` → `Start` → `OPX.Booted = true` → module report in the log. On resource stop: `OPX.Scheduler.Stop`, `OPX.Modules.Stop`, then every player is released from a selection bucket. |
| client | On `onClientResourceStart`: `OPX.UI.Surface`, `OPX.Toast.Attach` → `OPX.Modules.Run` → `OPX.Scheduler.Start` → module report. On stop: `OPX.Scheduler.Stop`, `OPX.Modules.Stop`, `OPX.UI.Teardown`. |
