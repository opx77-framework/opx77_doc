---
title: shops module
description: Clothing shops that open the fitting room, bill per changed clothing slot, offer ready-made looks and keep saved outfits with share codes.
---

# shops

The shops module places clothing shops in the world. At a shop a player picks "Try clothes on" on the target eye, and the `appearance` fitting room opens. When the room closes, the player pays for each clothing slot that changed. Inside the room the shop adds four groups: ready-made looks (uniforms), saved outfits, "Save outfit" and "Outfit code". Saved outfits can be shared with an 8-character code that another player types in. Use it to sell clothes; it stocks no garments of its own.

| | |
|---|---|
| Side | both |
| Requires | `character`, `appearance` (hard) |
| Optional | `target` (the shop row), `menu` (looks and outfit lists), `form` (outfit name and code entry) |
| Configuration | `config/shops.lua` (shared script) |
| Contract | none |
| Data | `opx77_saved_outfits` |

## How a bill works {#billing}

The server cannot see the clothing catalogue (it is client-only), so it prices **slots**, not garments.

- The client reports which of the nine slots changed between entering and leaving the room: `Head`, `Face`, `InnerChest`, `OuterChest`, `Legs`, `Feet`, `Outfit`, `UnderwearTop`, `UnderwearBottom`. Taking a garment off counts as a change.
- The server adds up the shop's price for each changed slot and takes it from [`CURRENCY`](#config-shops-currency). The client never sends a price.
- A slot without a price is free. Underwear is free by default.
- If the bill cannot be paid, the server sends back the player's stored look and the client puts it back on.
- The server re-checks reach and the job gate before opening the room, billing, or dressing.

!!! warning
    Payment and the clothing save are not one transaction. The clothing is saved by `appearance`; the bill is taken after the room closes. If the bill fails, the old look is restored afterwards.

## Ready-made looks {#looks}

A look from [`LOOKS`](#config-shops-looks) is a partial outfit with its own `COST`. It sets the slots it names and leaves the others as they are; `false` empties a slot. Looks are filtered by job before the list is sent, so a player only sees what they may take.

## Saved outfits and share codes {#outfits}

- "Save outfit" stores the clothing currently saved for the character (not the unsaved preview) under a name. If the room is open, the save happens when the room closes.
- A character keeps up to `OUTFITS.MAX_PER_CHARACTER` outfits.
- "Get a share code" gives the outfit a code made from `23456789ABCDEFGHJKLMNPQRSTUVWXYZ` (no `I`, `O`, `0`, `1`). Typing is case-insensitive and ignores dashes and spaces. A code is not a secret.
- Wearing a saved or shared outfit is free.
- Deleting a character deletes its saved outfits.

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-shops-open"></a>`opx:net:shops:open` | client → server | `shopKey` | Open the fitting room at this shop. |
| <a id="opx-net-shops-bill"></a>`opx:net:shops:bill` | client → server | `{ shop, slots }` | The room closed with these slots changed. Ignored when `CHARGE` is off. |
| <a id="opx-net-shops-wear"></a>`opx:net:shops:wear` | client → server | `{ shop, look }` | Buy and put on a ready-made look. |
| <a id="opx-net-shops-save"></a>`opx:net:shops:save` | client → server | `{ name }` | Save the current clothing as an outfit. |
| <a id="opx-net-shops-list"></a>`opx:net:shops:list` | client → server | — | Send my saved outfits. |
| <a id="opx-net-shops-load"></a>`opx:net:shops:load` | client → server | `{ id }` | Put on a saved outfit. |
| <a id="opx-net-shops-delete"></a>`opx:net:shops:delete` | client → server | `{ id }` | Delete a saved outfit. |
| <a id="opx-net-shops-share"></a>`opx:net:shops:share` | client → server | `{ id }` | Get (or mint) the outfit's share code. |
| <a id="opx-net-shops-redeem"></a>`opx:net:shops:redeem` | client → server | `{ code }` | Put on the outfit behind a code. |
| <a id="opx-net-shops-looks"></a>`opx:net:shops:looks` | server → client | `{ shop, looks = { { id, label, cost } } }` | Looks this player may take here. |
| <a id="opx-net-shops-puton"></a>`opx:net:shops:putOn` | server → client | `{ look, wear }` | Dress in this (already paid and checked). |
| <a id="opx-net-shops-restore"></a>`opx:net:shops:restore` | server → client | clothing record | The bill failed: put this look back on. |
| <a id="opx-net-shops-saved"></a>`opx:net:shops:saved` | server → client | `{ outfits = { { id, name, code? } }, max }` | The saved outfit list. |
| <a id="opx-net-shops-code"></a>`opx:net:shops:code` | server → client | `{ id, code }` | A share code. |
| <a id="opx-on-shops-state"></a>`opx:on:shops:state` | client local | `{ saved }` or `{ code, id }` | The outfit list arrived, or a code was minted. |

## Configuration {#configuration}

`config/shops.lua` sets `OPX.Config.MODULES.shops`. Shared script. `enabled = false` switches the module off.

| Key | Default | What it does |
|---|---|---|
| <a id="config-shops-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-shops-prices"></a>`PRICES` | `Head 250, Face 250, InnerChest 400, OuterChest 600, Legs 450, Feet 300, Outfit 900` | Price per changed slot. A slot not listed is free. Unknown slot names are dropped with a boot warning. |
| <a id="config-shops-charge"></a>`CHARGE` | `true` | `false` makes every shop free (prices and look costs). |
| <a id="config-shops-currency"></a>`CURRENCY` | `'EDDIES'` | Money type a bill is taken from. |
| <a id="config-shops-reach"></a>`REACH` | `3.0` | Metres from the shop. Re-measured on the server. Also the target sphere radius. |
| <a id="config-shops-shops"></a>`SHOPS` | `jinguji`, `thrift_watson` | The shops, keyed by slug. See below. |
| <a id="config-shops-outfits"></a>`OUTFITS` | `{ MAX_PER_CHARACTER = 24, MAX_NAME_BYTES = 48, SHARING = true, CODE_LENGTH = 8 }` | Saved outfits. `SHARING = false` stops minting and redeeming codes. `CODE_LENGTH` 4–16. |
| <a id="config-shops-looks"></a>`LOOKS` | `ncpd_patrol`, `corpo_black` | Ready-made looks. See below. |

### A shop entry

| Field | What it does |
|---|---|
| `LABEL` | Name used in bills and audit. Defaults to the key. |
| `X`, `Y`, `Z` | Position. Required. |
| `BUCKET` | Routing bucket. The server treats `nil` as bucket 0. |
| `PRICES` | Override merged over the default `PRICES`. `{}` keeps the defaults; set a slot to `0` to make it free. |
| `JOBS` | `{ job = minimumGrade }`. `nil` = anybody. |
| `ON_DUTY` | `true` = the job must be on duty. |

### A look entry

| Field | What it does |
|---|---|
| `LABEL` | Shown in the list. |
| `COST` | One price for the whole look. `0` is free. |
| `JOBS`, `ON_DUTY` | Same as a shop. |
| `AT` | List of shop keys that offer it. `nil` = every shop. |
| `WEAR` | `{ Slot = 'Items.Record' \| false }`. Slots not named are left unchanged. |

## Refusal codes {#codes}

Every refusal is a toast with locale key `shops.<code>`. The bill and look purchase can also show the `character` module's money key (for example `money.insufficient`).

| Code | Meaning |
|---|---|
| `no_such_shop` | No shop with that key. |
| `too_far` | Out of reach, or another bucket. |
| `position_unknown` | The server cannot read the player's position. |
| `not_for_you` | The shop's job gate refused. |
| `unavailable` | `appearance` cannot open the room or dress the player. |
| `cannotPay` | The bill or look cost could not be taken. |
| `noSuchLook` | No look with that key. |
| `notForYou` | The look's job gate refused. |
| `notHere` | This shop does not carry that look. |
| `noCharacter` | No character loaded. |
| `nameNeeded` | Empty outfit name. |
| `tooMany` | Outfit limit reached. |
| `nothingWorn` | No stored clothing to save. |
| `saveFailed` | Database write failed. |
| `listFailed` | Database read failed. |
| `noSuchOutfit` | Not one of this character's outfits. |
| `outfitUnreadable` | The stored outfit could not be decoded. |
| `sharingOff` | `OUTFITS.SHARING` is off. |
| `badCode` | Not a valid code. |
| `noSuchCode` | No outfit has that code. |
| `codeFailed` | No unique code after five tries. |
