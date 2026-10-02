---
title: Server authority
description: The server decides; a client only asks. How opx_infinity treats network events, staff powers, money and positions so that a modified client cannot cheat.
---

# Server authority

In `opx_infinity` **the server decides and the client asks.** Anything that
arrives on an `opx:net:` event comes from a machine the player owns and may have
modified. The server re-checks it before believing it. Follow the same rules in
any module you write.

## The rules {#rules}

| Rule | How the framework does it |
|---|---|
| Identity comes from the connection. | A `RegisterNetEvent` handler reads `source`, set by the platform. A player id, citizen id or plate in the payload is never trusted to say *who* is asking. |
| Re-derive, do not accept. | The client says "buy this at that dealer"; the server re-checks the distance across the ground, the routing bucket, that the dealer sells that row and that the money is there (see [dealership](../modules/dealership.md)). |
| Staff powers are ACL rights, checked on the server. | Staff commands are registered *restricted*, so the host checks `command.<name>` before the handler runs. The admin module re-checks with `Open77.acl.isAllowed` when a staff action arrives another way. Hiding a menu row is never the check. |
| Shared world things are created by the server. | Vehicles, showroom cars and other persistent entities are created by server code. A client-only preview stays on the client. |
| Money moves first, then the side effect, with a refund on failure. | A purchase charges first, because the vehicles contract can refund but cannot un-create. A failed registration after payment is refunded and logged. |
| Rate limits are comfort, not security. | [`OPX.Cooling`](../reference/core.md#opx-cooling) limits how often one player repeats one operation. Ownership checks are the security boundary. |
| A refusal names a code, not a reason. | [`OPX.Refuse`](../reference/core.md#opx-refuse) tells the client which request failed and a stable code, nothing more. |

## Client hints {#hints}

Some modules compute an answer on the client too — for example whether a
job may use an elevator floor — so the screen can grey out a row. That answer is
a **hint**. The server runs the same check again (the shared
[`OPX.JobGate`](../reference/lib.md#opx-jobgate-evaluate) code) and its answer is
the one that counts.

## Audit {#audit}

Actions an operator may have to account for later (money, character changes,
staff actions) are written with [`OPX.Audit`](../reference/lib.md#opx-audit-log)
as one greppable line in the server journal:

```text
[audit] event=... severity=... citizen=... user=... player=... message="..." data=...
```

Text that came from a client is stripped of control characters and cut to a
safe length first, so a player cannot forge a log line.
