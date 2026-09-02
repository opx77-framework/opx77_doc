---
title: Identity — accounts, sessions, players and citizen ids
description: The four identifiers OPX//77 works with — userId, playerId, displayName and citizenId — the difference between a session and a player, and why the citizen id carries a check symbol computed modulo a prime.
---

# Identity

Four values name a person on an OPX//77 server, and they are not
interchangeable. Three come from the platform and one is the framework's own.
Confusing any two of them produces a bug that looks like something else.

## The platform's three values {#platform-values}

| Value | Lifetime | What it is |
|---|---|---|
| `userId` | Durable | The account. Issued by the Master, stable across sessions and reinstalls, cryptographically signed. Persist this. |
| `playerId` (also `source`) | One connection | The slot. **Recycled** — the number that was yours last night belongs to somebody else tonight. |
| `displayName` | Editable | A profile field the player changes when they like. Presentation only. |

`userId` is the key to everything durable: characters, bans, ACL entries, slot
limits. `playerId` is a lookup key and nothing more.

### The certificate {#certificate}

The Master issues an Ed25519 certificate covering all three public profile
values at once:

```text
userId || P-256 public key || displayName
```

During connection the game server verifies that certificate together with a
fresh P-256 session proof bound to its own challenge. Changing only the name in
a modified client invalidates the certificate, so the forged name is rejected
**before the session becomes active** — which is why a server resource may treat
`GetPlayerName` as verified rather than as a claim.

`GetPlayerIdentifier(playerId)` returns the durable `userId`;
`GetPlayerName(playerId)` returns the Master-verified `displayName`.

!!! warning
    `source` is **not** populated in `onPlayerConnected`. It is set only in
    handlers reached through a network event, from the authenticated connection.
    In `onPlayerConnected` the player id arrives as the first argument, and as a
    **string** — every OPX//77 handler starts with `tonumber` for that reason.

## Sessions and players are different things {#session-vs-player}

A **session** is a connected machine. It exists from `onPlayerConnected` and
carries the Master-signed `userId`.

A **player** is a loaded character. It exists only between the moment somebody
chooses one and the moment they disconnect.

Somebody sitting in the character selection screen has a session and **no
player**. Confusing the two ends one of two ways: refusing a legitimate
connection, or trusting a character that was never loaded.

| | Session | Player |
|---|---|---|
| Exists from | `onPlayerConnected` | character selection |
| Server table | `OPX.Sessions[source]` | `OPX.Players[source]` |
| Fields | `source`, `userId`, `displayName`, `connectedAt`, `gateSession`, `charactersSent` | `PlayerData`, `Functions`, `Offline` |

### Why every read re-checks the account {#ensure-session}

Because `playerId` is recycled and `userId` is not, a session is only as good as
the account behind its slot. `OPX.EnsureSession` is the single doorway that
every entry point goes through, and it does two things nothing else does:

- It refuses a slot with **no verified identity** at all, so nothing can be
  attributed to a connection the platform has not vouched for.
- It **evicts** a session whose slot now belongs to a different `userId`, logging
  the character out on the way rather than dropping it, so what was in the roster
  is written rather than lost.

The effect is that a departure nobody reported becomes a non-event instead of a
security hole: the next thing that touches that slot notices the account behind
it changed and clears the old session. That net matters, because
`onPlayerDisconnected` is the platform's only departure event and it is
undocumented — see
[the platform corrections](the-platform.md#corrections).

A `Player` also exists in an **offline** form — `Offline = true` and
`PlayerData.source = nil` — so a staff command can act on a character who is not
connected. The money mutators refuse an offline player rather than pretending;
`money.offline` is the code they answer with.

## The citizen id {#citizen-id}

A citizen id looks like `H7K-M4X3`: six payload symbols plus one check symbol,
rendered with a hyphen after the third.

It is OPX//77's own identifier, and it names a **character** — not an account
and not a connection. It is the primary key of the character row, the key a
transfer is addressed to, and the string a player reads out loud over voice
while somebody else types it.

That last use is what the format is built for.

### The alphabet has 23 symbols and no ambiguous glyph {#alphabet}

```text
34679ACDEFGHJKMNPRTWXYZ
```

No `0` against `O`, no `1` against `I` or `L`, no `5` against `S`, no `2`
against `Z`, no `8` against `B`. A code read aloud in a noisy bar and typed by
somebody who has never seen it written down cannot produce a different valid
code by a glyph confusion, because the confusable glyphs are not in the
alphabet.

### The check symbol is a weighted sum modulo a prime {#check-symbol}

The six payload positions carry weights `2, 3, 4, 5, 6, 7`; the check symbol
carries weight `1` and is chosen so that the whole weighted sum is zero modulo
23.

Because 23 is **prime** and the weights are **distinct**, this catches **every**
single-symbol substitution and **every** transposition of two adjacent symbols
— the two errors a human actually makes when copying a code.

!!! warning
    Do not change the alphabet size or the weights. The guarantee comes from the
    modulus being prime and from the weights being distinct; change either and
    the check silently stops catching the errors it exists for. Nothing fails
    loudly, nothing logs, and the first symptom is somebody else's money.

Why it exists at all: without a check symbol a typo produces another **valid**
code, belonging to a real stranger. The transfer succeeds, the screen shows no
error, and the only way to find out is that the money never arrived. With it,
the typo is rejected at the point of entry.

### Parsing is forgiving about form, strict about content {#parsing}

Input is upper-cased, and whitespace, hyphens and underscores are stripped. An
unknown symbol is **rejected, never dropped** — dropping turns `AO2C-D3F` into
somebody else's id, which is the exact failure the check symbol exists to
prevent, reintroduced by a tidy-up.

```lua
local parsed = OPX.CitizenId.parse(input)
if not parsed.ok then
  -- parsed.error is one of: "type", "length", "alphabet", "checksum"
  return
end
local citizenId = parsed.value -- normalised and grouped: "H7K-M4X3"
```

`OPX.CitizenId.isValid(value)` is the boolean form, for guarding an internal
call site where there is no user to explain anything to. Use `parse` on player
input, so the caller learns **why** it was refused and can say so.

`OPX.CitizenId.generate(rng)` accepts an optional `fun(low, high): integer`, so
generation can be made deterministic in a test.

### One identity, not two {#character-key}

The grouped citizen id is the one key every satellite addresses a character by.
`opx77_status` keys its `opx77_character_status` rows on it, the core's own
`appearance` column hangs off the same row, and
[`opx77_appearance`](../reference/opx77_appearance/index.md) names the character
it is dressing with it. That is deliberate: one identity instead of two means
there is no state in which a character's face and their money disagree about who
they are.

## Where to go next {#next}

- [The entry gate](entry-gate.md) — how a session becomes a player, and what may
  not touch them until it has.
- [Persistence](persistence.md#schema) — the rows these identifiers key.
- [The OPEN//77 platform](the-platform.md#identity) — the platform's half of
  this, and its certificate.
