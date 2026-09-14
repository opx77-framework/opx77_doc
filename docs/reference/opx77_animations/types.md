---
title: opx77_animations types
description: The shapes opx77_animations reads and answers with — AnimationError and what each code shows the player, the options play accepts, every export response, the result and change payloads, the catalogue entry, the command entry, and the platform service's playback state as far as it is read.
---

# Types

The annotations in `types.lua`, as the code actually uses them. Nothing here is
loaded at runtime: Lua tables carry no schema, and these are the shapes the
resource reads and answers with.

## AnimationError {#animationerror}

The `error` code on any refusal. A `snake_case` code meant for branching, never
text for a player to read.

```lua
---@alias AnimationError string
```

The first group is this resource's own; the second is decided by its server half
or its client; the last is the platform service's, passed through exactly as it
answered. **Shown as** is what a player who asked directly — a command, the
picker — sees, in `en`; an export caller is shown nothing.

| Code | Decided by | Meaning | Shown as |
|---|---|---|---|
| `export_call_required` | export | no invoking resource | — |
| `internal_error` | export | the export raised; the log names it | — |
| `unknown_animation` | client, server | not in the catalogue, disabled, or missing on this build | *That animation is not available here.* |
| `invalid_variant` | client, server | no such variant, or not offered on this build | *That animation has no such variant.* |
| `invalid_options` | client, server | `options` is not a table, or a field in it is out of range | *That animation request is malformed.* |
| `unknown_category` | export | not one of the six categories | — |
| `invalid_player` | export | `state` was given something that is not a player id | — |
| `presentation_unavailable` | export | this client has no presentation natives | — |
| `menu_not_running` | client | `opx77_menu` is not running | *The animation picker is unavailable. Type /e followed by a name instead.* |
| `picker_not_open` | export | `closePicker`, with no picker of this resource's on screen | — |
| `not_sent` | client | the net event was not accepted | *That request could not be sent.* |
| `request_timeout` | client | no verdict within 15 s | *The animation did not start in time. Try again.* |
| `presentation_failed` | client | the local body could not be posed, with no more specific code | *Your animation could not be shown and was stopped.* |
| `rate_limited` | server | past [`RATE_LIMIT`](config.md#rate-limit) | *Slow down a little.* |
| `player_not_ready` | server | the readiness gate is still closed | *Wait until your character has finished loading.* |
| `service_unavailable` | server | `Open77.animations.play` or `stop` is missing | *Animations are unavailable right now.* |
| `play_raised` | server | the native play raised; the log has it | *That animation could not be played.* |
| `stop_raised` | server | the native stop raised | *That animation could not be played.* |
| `play_refused` | server | the native play refused without a code | *That animation could not be played.* |
| `player_not_alive` | service | the player is dead | *You must be alive to play an animation.* |
| `player_in_vehicle` | service | the player is in a vehicle | *Get out of the vehicle first.* |
| `animation_owned` | service | another owner's playback is running | *Stop what you are doing before starting another one.* |
| `interrupted` | service | the playback was interrupted | *Animation interrupted.* |
| `timeout` | service | the service's own timeout | *The animation did not start in time. Try again.* |
| `resource_stopped` | service | not in `types.lua`'s list; the client maps it to a message all the same | *Animations are unavailable right now.* |

A code with no row of its own — another code the service answers, or a
presentation code from the natives — is shown as *That animation could not be
played.*, except on the local player's failed pose, which is shown as
*Your animation could not be shown and was stopped.* The *picker unavailable*
line names the first of `EMOTE` and `ANIM` whose `NAME` is set, and drops the
hint when neither is.

A typed command shows `unknown_animation` and `invalid_variant` as a warning
toast of its own, sent by the server rather than mapped by the client, followed
by a hint naming `opx77.anim.list` — see [Commands](commands.md#opx77-anim).

## AnimationOrigin {#animationorigin}

Who a request came from, as `source` on [`AnimationResult`](#animationresult).

```lua
---@alias AnimationOrigin "command"|"picker"|"export"|"presenter"|"owner_stopped"
```

| Value | The request came from |
|---|---|
| `"command"` | a typed command; `requestId` is `0` |
| `"picker"` | a picker row |
| `"export"` | [`play`](exports.md#play) or [`stop`](exports.md#stop) |
| `"presenter"` | the stop this resource sends when the local body could not be posed |
| `"owner_stopped"` | the stop this resource sends when the resource that started the playback stopped |

## AnimationEntry {#animationentry}

One entry of the catalogue, as `shared/catalogue.lua` builds it. Internal and
read-only; an export caller is given an [`AnimationListing`](#animationlisting)
instead.

| Field | Type | Meaning |
|---|---|---|
| `name` | `string` | the platform's profile id, and what a player types |
| `category` | `string` | one of the six categories |
| `prop` | `string\|nil` | what the platform puts in hand |
| `placement` | `string` | `"standing"` or `"ground"` |
| `clips` | `string[]` | the engine clip of each variant, 1-based |
| `words` | `string[]` | the same, reduced to the words shown beside a number |
| `variantOf` | `table<string, integer>` | clip to variant |

## AnimationOptions {#animationoptions}

What [`play`](exports.md#play) accepts as its second argument.

| Field | Type | Meaning |
|---|---|---|
| `variant` | `integer\|nil` | 1-based. Wins over `clip` |
| `clip` | `string\|nil` | an engine clip of this animation, when `variant` is absent |
| `loop` | `boolean\|nil` | `nil` takes [`LOOP_BY_DEFAULT`](config.md#loop-by-default) |
| `durationMs` | `integer\|nil` | 1000 to [`MAX_DURATION_MS`](config.md#max-duration-ms). A playback that does not loop and names none plays [`ONE_SHOT_MS`](config.md#one-shot-ms) |

Both `variant` and `clip` default to the first variant offered on this build,
which need not be variant 1.

## AnimationResponse {#animationresponse}

What every export answers, at least. Never raised.

| Field | Type | Meaning |
|---|---|---|
| `ok` | `boolean` | |
| `error` | [`AnimationError`](#animationerror)`\|nil` | on `ok = false` |

## AnimationRequest {#animationrequest}

What `play`, `stop`, `openPicker` and `closePicker` answer. `ok = true` means
**asked**, not done.

Extends [`AnimationResponse`](#animationresponse).

| Field | Type | Meaning |
|---|---|---|
| `queued` | `boolean\|nil` | the request went out, or the menu call was queued |
| `requestId` | `integer\|nil` | matches `requestId` on [`opx77:animations:result`](events.md#result); `play` and `stop` only |
| `animation` | `string\|nil` | the resolved name; `play` only, and on some of its refusals |
| `variant` | `integer\|nil` | the variant named; `play` only |

## AnimationResult {#animationresult}

The payload of [`opx77:animations:result`](events.md#result): the verdict on one
request.

| Field | Type | Meaning |
|---|---|---|
| `requestId` | `integer` | `0` for a typed command |
| `action` | `"play"\|"stop"` | |
| `ok` | `boolean` | |
| `error` | [`AnimationError`](#animationerror)`\|nil` | on `ok = false` |
| `animation` | `string\|nil` | |
| `variant` | `integer\|nil` | |
| `playbackId` | `string\|nil` | the service's id for the playback that started |
| `source` | [`AnimationOrigin`](#animationorigin) | |
| `owner` | `string\|nil` | the export caller's resource name, when there was one |

## AnimationChange {#animationchange}

The payload of [`opx77:animations:changed`](events.md#changed), and the body of
what [`state`](exports.md#state) answers.

| Field | Type | Meaning |
|---|---|---|
| `playerId` | `integer\|nil` | absent only on the local player's state before the world is ready |
| `active` | `boolean` | |
| `playbackId` | `string\|nil` | |
| `animation` | `string\|nil` | the profile id, which may be one this catalogue does not carry |
| `clip` | `string\|nil` | |
| `variant` | `integer\|nil` | `nil` when the clip is not one of this catalogue's |
| `known` | `boolean\|nil` | whether this catalogue carries the profile |
| `step` | `integer\|nil` | 1-based, within a multi-step playback |
| `steps` | `integer\|nil` | |
| `cycle` | `integer\|nil` | how many times it has looped |

Every field but `playerId` and `active` is present only while `active` is `true`.

## AnimationStateResponse {#animationstateresponse}

What [`state`](exports.md#state) answers.

Extends [`AnimationResponse`](#animationresponse) and
[`AnimationChange`](#animationchange).

| Field | Type | Meaning |
|---|---|---|
| `presenting` | `boolean` | whether this client is the one posing bodies |

## AnimationListing {#animationlisting}

One animation as an export caller is given it.

| Field | Type | Meaning |
|---|---|---|
| `name` | `string` | |
| `label` | `string` | in the configured locale |
| `category` | `string` | |
| `categoryLabel` | `string` | in the configured locale |
| `prop` | `string\|nil` | |
| `placement` | `string` | |
| `variants` | `{ variant: integer, clip: string, words: string }[]` | only the offered ones, ascending |

## AnimationListResponse {#animationlistresponse}

What [`list`](exports.md#list) answers. Extends
[`AnimationResponse`](#animationresponse).

| Field | Type |
|---|---|
| `animations` | [`AnimationListing`](#animationlisting)`[]\|nil` |

## AnimationCategoriesResponse {#animationcategoriesresponse}

What [`categories`](exports.md#categories) answers. Extends
[`AnimationResponse`](#animationresponse).

| Field | Type |
|---|---|
| `categories` | `{ name: string, label: string, count: integer }[]\|nil` |

## AnimationGetResponse {#animationgetresponse}

What [`get`](exports.md#get) answers. Extends
[`AnimationResponse`](#animationresponse).

| Field | Type |
|---|---|
| `animation` | [`AnimationListing`](#animationlisting)`\|nil` |

## AnimationRequestResult {#animationrequestresult}

What `server/service.lua` answers for one request, internally. It becomes an
[`AnimationResult`](#animationresult) on the client.

| Field | Type | Meaning |
|---|---|---|
| `ok` | `boolean` | |
| `error` | [`AnimationError`](#animationerror)`\|nil` | |
| `quiet` | `boolean\|nil` | a repeat `rate_limited` refusal: no answer is sent |
| `animation` | `string\|nil` | |
| `variant` | `integer\|nil` | |
| `clip` | `string\|nil` | |
| `playbackId` | `string\|nil` | |

## ServicePlaybackState {#serviceplaybackstate}

One playback state on the platform service's wire, `open77:animations:state` and
the pages of `open77:animations:snapshot`. **The service's shape**, reproduced as
far as this resource reads it — observed in the platform's own client, not
documented by it.

| Field | Type | Meaning |
|---|---|---|
| `epoch` | `string` | which incarnation of the service |
| `playbackId` | `string` | |
| `revision` | `integer` | ordering; an older revision than the mirror holds is dropped |
| `playerId` | `integer` | |
| `active` | `boolean` | |
| `bucket` | `integer` | |
| `steps` | `{ profile: string, clip: string, durationMs: integer }[]` | 1 to 16 steps |
| `step` | `integer` | 0-based |
| `cycle` | `integer` | |
| `clientRequestId` | `string\|nil` | |

## AnimationCommand {#animationcommand}

One entry of [`COMMANDS`](config.md#commands).

| Field | Type | Meaning |
|---|---|---|
| `NAME` | `string\|false` | the registered name; `false` registers nothing at all |
| `RESTRICTED` | `boolean` | `true` gates `command.<NAME>` against the ACL before the handler |
