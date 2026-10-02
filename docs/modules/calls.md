---
title: calls module
description: Holocalls between players — ring, answer, decline, hang up, add a third participant, and swap contacts face to face.
---

# calls

The `calls` module adds player-to-player holocalls. A player presses the holo key (`H` by default) to open a centred hologram listing their contacts and recent calls, and calls someone from it. The other player hears the game's incoming-call sound and the hologram pops up with the caller; they answer with `Y` or refuse with `X` (`X` also hangs up a live call or withdraws a call you placed). During a call both players' eyes carry the game's blue holocall glow and they share a voice channel. A third player can be added. Contacts are swapped face to face through a row on the [target](target.md) eye, and only contacts appear in the hologram. The server owns every call; the client only asks.

| | |
|---|---|
| Side | both |
| Requires | `character` (hard) |
| Optional | `target`, `menu` |
| Configuration | `config/calls.lua` (shared script) |
| Contract | `calls` v1 — server |
| Data | character metadata keys `callContacts` (up to `MAX_CONTACTS` rows `{ citizenId, name }`) and `callRecent` (last 20 outcomes) |

One player is in at most one call, has at most one invite out and one invite waiting. An invite has a `kind`: `call` (start a call), `join` (the sender is in a call; accepting adds you) or `contact` (swap contact rows; no call). The kind is decided by the server.

## Server contract {#server-contract}

`local calls = OPX.Api.Get('calls')` on the server, from code inside opx_infinity. Each function answers a Result. Error codes are `calls.error.<reason>`.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-calls-isoncall"></a>`IsOnCall` | `playerId` | `{ onCall = false }` or `{ onCall = true, callId, founder, participants, elapsedMs }` | `participants` is a list of player ids. |
| <a id="server-calls-list"></a>`List` | — | `{ calls = { { id, participants = { { id, name } } } } }` | Every live call. |
| <a id="server-calls-hangup"></a>`HangUp` | `playerId, caller` | `{ callId, ended }` | Takes the player off their call (the call ends if fewer than two remain). `caller` is only written to the audit line. Does not notify the other participants with a toast. |
| <a id="server-calls-eyes"></a>`Eyes` | `playerId` | `{ lit, ours }` | Whether the holocall eye glow is on, and whether this module holds it. Error `calls.error.unreadable`. |
| <a id="server-calls-contacts"></a>`Contacts` | `playerId` | `{ contacts = { { citizenId, name } } }` | The player's stored contacts. |

There is no client contract. Commands: none.

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-calls-state"></a>`opx:net:calls:state` | server → client | `{ call?, invite?, outgoing? }` | The player's whole call state, pushed on every change. `call = { id, founder, elapsedMs, participants = { { id, name, self } } }`; `invite = { id, kind, from, fromName, expiresInMs }`; `outgoing = { id, kind, to, toName, expiresInMs }`. |
| <a id="opx-net-calls-ready"></a>`opx:net:calls:ready` | client → server | — | Ask for the state again. 1 per second. |
| <a id="opx-net-calls-invite"></a>`opx:net:calls:invite` | client → server | `targetId, kind?` | Call (or add to the current call) a player; `kind = 'contact'` offers a contact swap instead. |
| <a id="opx-net-calls-accept"></a>`opx:net:calls:accept` | client → server | `inviteId` | Answer the waiting invite. |
| <a id="opx-net-calls-decline"></a>`opx:net:calls:decline` | client → server | `inviteId` | Refuse the waiting invite. |
| <a id="opx-net-calls-hangup"></a>`opx:net:calls:hangup` | client → server | — | Leave the current call, or withdraw an outgoing invite when not on a call. |
| <a id="opx-net-calls-roster"></a>`opx:net:calls:roster` | client → server | — | Ask for the hologram list. 1 per second. |
| <a id="opx-net-calls-contacts"></a>`opx:net:calls:contacts` | server → client | `{ rows, recent, onCall }` | `rows` = online contacts `{ id, name, kind, refusal }` (callable ones first; `refusal` is why one cannot be called now); `recent` = newest first `{ outcome, name, citizenId, atMs }`, `outcome` being `declined`, `refused`, `missed` or `unanswered`. |
| <a id="opx-on-calls-view"></a>`opx:on:calls:view` | client local | `{ kind, ... }` | The state half talking to the view. `kind = 'state'` or `'holo'` (see page channels). |

`invite`, `accept`, `decline` and `hangup` are each limited to one per `REQUEST_MS` per player; a refusal is shown to the player as a toast. Audit entries: `calls.invite`, `calls.accept`, `calls.decline`, `calls.cancel`, `calls.hangUp`, `calls.contact`, `calls.unanswered`, `calls.eyes`, `calls.voice`.

A call is dropped when a participant disconnects, is no longer in the world or is no longer alive (checked every `SCAN_MS` and on life-state changes).

## Page channels {#page-channels}

The hologram is on the `interactive` surface and takes keyboard and cursor while open. `Escape` (the platform's pause key) closes it.

| Channel | Direction | Payload | Meaning |
|---|---|---|---|
| <a id="page-calls-ready"></a>`calls:ready` | page → Lua | `{}` | The hologram mounted. Lua asks the server for the state. |
| <a id="page-calls-close"></a>`calls:close` | page → Lua | `{}` | Close the hologram. |
| <a id="page-calls-toggle"></a>`calls:toggle` | page → Lua | `{}` | Open or close the hologram. Not sent by the shipped page. |
| <a id="page-calls-call"></a>`calls:call` | page → Lua | `{ id }` | Call that player. |
| <a id="page-calls-share"></a>`calls:share` | page → Lua | `{ id }` | Offer a contact swap. Not sent by the shipped page (the eye row does it). |
| <a id="page-calls-accept"></a>`calls:accept` | page → Lua | `{}` | Answer the waiting invite. |
| <a id="page-calls-decline"></a>`calls:decline` | page → Lua | `{}` | Refuse the waiting invite. |
| <a id="page-calls-hangup"></a>`calls:hangUp` | page → Lua | `{}` | Hang up or withdraw. |
| <a id="page-calls-dismiss"></a>`calls:dismiss` | page → Lua | `{}` | Hide the incoming card locally (the call keeps ringing). Not sent by the shipped page. |
| <a id="page-calls-repop"></a>`calls:repop` | page → Lua | `{}` | Bring the incoming card back. Not sent by the shipped page. |
| <a id="page-calls-diag"></a>`calls:diag` | page → Lua | `{ detail }` | A view-side message, relayed with `OPX.Note`. Not sent by the shipped page. |
| `calls:holo` | Lua → page | `{ open, rows, recent, call, invite, outgoing, anchor, answerKey, declineKey }` | The hologram. Sent on open/close and on every state change, also while closed (`open = false`), so the page can show a ringing call without taking focus. |
| `calls:view` | Lua → page | `{ kind = 'state', call, invite, invitePending, outgoing, dismissed }` | Card state on the `overlay` surface. The shipped page has no listener for it. |

## Key bindings {#keys}

| Mapping id | Default | Label key | Action |
|---|---|---|---|
| `opx.calls.holo` | `H` | `calls.key.holo` | Open or close the hologram. |
| `opx.calls.answer` | `Y` | `calls.key.answer` | Answer the waiting invite. Does nothing when nothing rings. |
| `opx.calls.decline` | `X` | `calls.key.decline` | Refuse the waiting invite; otherwise hang up or withdraw. |

`Y` is also the inventory hotbar peek and `X` stops an emote. Both actions fire; outside a call the calls handlers do nothing.

!!! warning "Missing labels"
    `calls.key.answer`, `calls.key.decline`, `calls.row.share` and `calls.group` have no entry in `modules/calls/locales.lua`, so the pause menu and the eye row show the raw keys.

## Configuration {#configuration}

`config/calls.lua` sets `OPX.Config.MODULES.calls`. Shared script. `enabled = false` switches the module off. Numbers are clamped to the ranges shown.

| Key | Default | What it does |
|---|---|---|
| <a id="config-calls-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-calls-max-participants"></a>`MAX_PARTICIPANTS` | `3` | People on one call (2–3; 3 is a hard ceiling). |
| <a id="config-calls-invite-ttl-s"></a>`INVITE_TTL_S` | `30` | Seconds an unanswered invite rings (5–300). It holds both players' invite slots meanwhile. |
| <a id="config-calls-request-ms"></a>`REQUEST_MS` | `1500` | Minimum milliseconds between two requests of one kind from one player (0–60000). |
| <a id="config-calls-contact-range"></a>`CONTACT_RANGE` | `6.0` | Metres between the two players for a contact swap, same bucket (0.5–50). Calls themselves have no range. |
| <a id="config-calls-max-contacts"></a>`MAX_CONTACTS` | `64` | Contact rows per character (1–512). The oldest is dropped past it. |
| <a id="config-calls-eyes"></a>`EYES` | `{ LEASE_MS = 30000, RENEW_MS = 10000 }` | Eye-glow lease in ms (1000–600000), renewed every `SCAN_MS`. `RENEW_MS` is not read by the code. |
| <a id="config-calls-scan-ms"></a>`SCAN_MS` | `2000` | Milliseconds between sweeps: expire invites, drop unreachable participants, renew leases (250–30000). |
| <a id="config-calls-sound"></a>`SOUND` | game `ui_phone_*` events | `INCOMING`, `INCOMING_STOP`, `ACCEPTED`, `DECLINED`, `OUTGOING`, `OUTGOING_STOP`, `HANG_UP`: Wwise event names played with `Open77.sfx.play2d`. `''` switches one off. |
| <a id="config-calls-card-dwell-s"></a>`CARD_DWELL_S` | `8` | Seconds before the incoming card marks itself `dismissed` in `calls:view` (2–60). The call keeps ringing. |
| <a id="config-calls-ring-every-ms"></a>`RING_EVERY_MS` | `3500` | Milliseconds between two plays of the ring (1000–60000). |
| <a id="config-calls-key"></a>`KEY` | `{ ID = 'opx.calls.holo', NAME = 'calls.key.holo', DEFAULT = 'H' }` | The hologram key. `false` (or no `DEFAULT`) binds no key. |
| <a id="config-calls-anchor"></a>`ANCHOR` | `'bottom-center'` | Where the hologram sits: one of `top-left`, `top-center`, `top-right`, `left`, `center`, `right`, `bottom-left`, `bottom-center`, `bottom-right`. An unknown name is logged and falls back to `bottom-center`. |
| <a id="config-calls-answer-key"></a>`ANSWER_KEY` | `{ ID = 'opx.calls.answer', NAME = 'calls.key.answer', DEFAULT = 'Y' }` | The answer key. |
| <a id="config-calls-decline-key"></a>`DECLINE_KEY` | `{ ID = 'opx.calls.decline', NAME = 'calls.key.decline', DEFAULT = 'X' }` | The refuse / hang-up key. |

## Refusal codes {#codes}

Shown to the player as `calls.error.<code>`.

| Code | Meaning |
|---|---|
| `badRequest` | Malformed request. |
| `tooFast` | Within `REQUEST_MS` of the last one. |
| `self` | Calling yourself. |
| `noSuchPlayer` | The target is not connected. |
| `notReady` / `targetNotReady` | You / they are not in the world with a character. |
| `notAlive` / `targetNotAlive` | You / they are down or dead. |
| `alreadyInCall` / `targetInCall` | You / they are already on a call. |
| `alreadyPending` / `targetPending` | You already have an invite out / they already have one waiting. |
| `notInCall` | Hang up or add with no call. |
| `callFull` | The call has `MAX_PARTICIPANTS`. |
| `alreadyParticipant` | They are already on this call. |
| `noSuchInvite` | No such invite waiting (or nothing to withdraw). |
| `expired` | The invite rang out. |
| `tooFar` | Contact swap outside `CONTACT_RANGE`. |
| `unreadable` | A host read failed. |
