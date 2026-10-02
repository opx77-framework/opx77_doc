---
title: dealership module
description: Vehicle dealers — buy a car from a marker, dress a showroom with locked preview cars, and let a salesperson sell to another player for a company account.
---

# dealership

`dealership` sells vehicles. A player stands on a dealer marker and presses the key (**E** by default): a centred list shows the stock of that dealer's kind, grouped by class, then asks which of their garages to file the car under. The money is taken, the car is registered through [`vehicles`](vehicles.md) and, by default, handed over on the marker. A dealer can also show locked **preview cars** on its floor, and inside a dealer's **zone** a salesperson can offer a car to another player, who must accept it on their own screen.

| | |
|---|---|
| Side | both |
| Requires | `character` (hard) |
| Optional | `vehicles`, `garages`, `prompts`, `menu`, `target`, `vehiclekeys` |
| Configuration | `config/dealership.lua` (shared script) |
| Contract | `dealership` v1 — server, client |
| Data | `opx77_company_accounts` (company balances); `opx77_dealerships`, `opx77_dealership_previews` (legacy, read-only) |

Without `vehicles` nothing can be sold. Without `garages` every car is filed under the vehicles `DEFAULT_GARAGE` and no destination can be chosen. Without `menu` there is no list, but `/opx.dealership.buy` still works. Without `target` there is no "sell a vehicle" row. With [`vehiclekeys`](vehiclekeys.md) the buyer receives a key with every sale (a full bag is said to the buyer and does not undo the sale).

## How a sale works

1. The server re-checks everything: the dealer exists, the player is within `USE_RADIUS` in the same bucket, the dealer's kind sells that row (`garage` sells ground vehicles, `avpad` sells AVs), the currency is valid and the player can afford it. A chosen garage must be a garage of the same kind with a location in the player's bucket.
2. The price is taken with `character.RemoveMoney`.
3. The vehicle is registered with `vehicles.Register`. If that fails (`vehicle.limit`, …) the price is refunded. If the refund also fails, the log says so and it must be settled by hand.
4. A key is cut (`vehiclekeys.Ensure`), when that module is running.
5. With `HAND_OVER = true` the car is created on the dealer marker, facing its `HEADING` (AVs `AV_LIFT` m higher). A refused hand-over does not undo the sale: the car stays owned and filed.

### Selling to another player

Inside `ZONE_RADIUS` of a dealer, the target eye shows **Sell a vehicle** on every other player. The seller picks a model; the buyer receives an offer and must accept it within `OFFER_TIMEOUT_MS`. Both must still be in the zone when the buyer answers. On a yes the buyer pays the full price and the sale runs the same steps as above, except that the car is filed under the vehicles `DEFAULT_GARAGE` (there is no garage choice). The seller's **company** receives the price minus the commission, and the seller receives `SELLER_CUT_PERCENT` (rounded down). A commission that cannot be paid to the seller goes to the company.

The company is the seller's job (when `COMPANY.JOBS` is on and the job is not in `EXCLUDED`), otherwise their gang (when `COMPANY.GANGS` is on). A seller with neither is refused `dealership.noCompany`. Balances live in `opx77_company_accounts` (`kind` = `job` or `gang`, `group_key`, `balance`). Only deposits exist; the module has no withdraw path. Read a balance with [`Balance`](#server-dealership-balance).

!!! danger
    A company deposit that fails is logged as an error and is not retried: the buyer has paid, the car exists, and the company did not receive the money.

### Showroom previews

Each row of `PREVIEW.POINTS` stands one stock model, created **locked** and **persistent**, at most `PREVIEW.LIMIT` per dealer. A point naming a dealer that does not exist is skipped with a log line. A point whose `ENTRY` is not a stock key is reported at boot.

### Legacy tables

`/opx.dealership.add`, `/opx.dealership.remove` and the placement path for previews (with its ACL right `opx.dealership.place`) **no longer exist**. At every boot the server reads `opx77_dealerships` and `opx77_dealership_previews`, adopts every row whose key is not in the config (config wins), and prints each one to the log as a `[dealership] config line: ...` ready to paste into `SPOTS` or `PREVIEW.POINTS`. Nothing writes to these two tables any more. A role that still holds `opx.dealership.place` holds a right nothing checks.

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-dealership-list"></a>`/opx.dealership.list` | ACL `command.opx.dealership.list` | — | Lists every dealer (kind, label, position, heading, bucket, config or legacy) and every showroom car with whether it is standing. |
| <a id="opx-dealership-stock"></a>`/opx.dealership.stock` | everyone | — | Lists every stock row: kind, class, key, label, price. |
| <a id="opx-dealership-buy"></a>`/opx.dealership.buy` | everyone | `<key> [garage]` | Buys the stock row `key` at the dealer the caller stands on, filed under `garage` if given. Same checks as the list. Cooldown `COOLDOWN_MS`. |

`command.opx.dealership.*` grants all three. Command names come from `COMMANDS` in the config.

## Server contract {#server-contract}

`local dealership = OPX.Api.Get('dealership')` on the server, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-dealership-buy"></a>`Buy` | `source, dealerKey?, entryKey, garageKey?` | Result `{ok, value = {plate, entry, model, dealer, label, garage?, price, currency, spawned, keyed}}` | Yields. Takes the money. `dealerKey` nil means the dealer underfoot. `spawned`: handed over; `keyed`: a key was cut or already held. |
| <a id="server-dealership-offer"></a>`Offer` | `seller, buyer, entryKey` | Result `{ok, value = {buyer, token, entry, price, cut, company, dealer}}` | Records an offer and sends it to the buyer. One pending offer per buyer; a new one replaces it. |
| <a id="server-dealership-accept"></a>`Accept` | `buyer, token, yes` | Result: the `Buy` value plus `commission`, `banked`, `paid` | Yields. `yes ~= true` declines. Charges the buyer, banks the company share, pays the seller. |
| <a id="server-dealership-balance"></a>`Balance` | `kind, group` | Result `{ok, value = {kind, group, balance}}` | Yields. `kind` is `job` or `gang`. `0` when no row. |
| <a id="server-dealership-stock"></a>`Stock` | — | Result `{ok, value = {currency, stock}}` | `stock[key] = {label, class, price, av}`. |
| <a id="server-dealership-previews"></a>`Previews` | — | Result `{ok, value = {previews}}` | `{key, dealer, entry, model, standing}[]`. |
| <a id="server-dealership-spots"></a>`Spots` | — | table | Not a Result. Every dealer by key. |
| <a id="server-dealership-state"></a>`State` | — | Result `{ok, value = {dealers, stock, currency, previews, standing}}` | `dealers[key] = {kind, label, adopted}`; the rest are counts. |

## Client contract {#client-contract}

`local dealership = OPX.Api.Get('dealership')` on the client, from code inside opx_infinity.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-dealership-open"></a>`Open` | `origin?` | Result | Same as pressing the key: opens the list for the dealer underfoot, or closes it if open. |
| <a id="client-dealership-close"></a>`Close` | — | Result `{ok, value = true}` | Closes the list. Refused when none is open. |
| <a id="client-dealership-isopen"></a>`IsOpen` | — | boolean | Whether the list is open. |
| <a id="client-dealership-decide"></a>`Decide` | `yes` | Result | Answers the offer waiting for this player. `dealership.noOffer` when none. |
| <a id="client-dealership-nearest"></a>`Nearest` | — | Result `{key, label, kind}` | `dealership.noSuchSpot` when not on a dealer. |
| <a id="client-dealership-spots"></a>`Spots` | — | Result `{spots}` | Dealers this client was sent (its own bucket). |
| <a id="client-dealership-state"></a>`State` | — | Result | Diagnostic: dealers, markers, nearest, open screen, stock count. |

## Events {#events}

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-dealership-ask"></a>`opx:net:dealership:ask` | client → server | — | Ask for the dealers of the caller's bucket and the stock. Sent at start and every `POLL_MS`. |
| <a id="opx-net-dealership-sync"></a>`opx:net:dealership:sync` | server → client | `{ spots }` | Dealers of the bucket: `key, label, kind, x, y, z, heading, bucket`. |
| <a id="opx-net-dealership-stock"></a>`opx:net:dealership:stock` | server → client | `{ kinds = { garage = rows, avpad = rows } }` | Stock per kind; each row `key, label, class, price, text` (`text` is the formatted price). |
| <a id="opx-net-dealership-buy"></a>`opx:net:dealership:buy` | client → server | `dealerKey, entryKey, garageKey?` | Buy. Cooldown `COOLDOWN_MS` plus the request window. |
| <a id="opx-net-dealership-answer"></a>`opx:net:dealership:answer` | server → client | `ok, error?, entryKey?, value?` | Verdict of a buy or an accepted offer; `value` is the `Buy` value. |
| <a id="opx-net-dealership-offer"></a>`opx:net:dealership:offer` | client → server | `buyerId, entryKey` | A salesperson offers a car to a player. |
| <a id="opx-net-dealership-offered"></a>`opx:net:dealership:offered` | server → client | `{ token, entry, model, price, text, seller, dealer, label, timeoutMs }` | Sent to the buyer: the offer to answer. |
| <a id="opx-net-dealership-decide"></a>`opx:net:dealership:decide` | client → server | `token, yes` | The buyer's answer. |
| <a id="opx-net-dealership-settled"></a>`opx:net:dealership:settled` | server → client | `{ ok, error?, entry, model?, cut?, company?, banked? }` | Sent to the seller (or the buyer if the seller left): what became of the offer. |
| <a id="opx-on-dealership-decision"></a>`opx:on:dealership:decision` | client local | `{ ok, error?, entry?, plate?, model?, dealer?, garage?, price?, queued?, commission?, banked?, source }` | Every verdict, local refusals included. `source` is `key`, `server`, `client`, `target`, `offer`, `sale` or the caller's `origin`. Only handlers inside opx_infinity's client hear it. |

## Configuration {#configuration}

`config/dealership.lua` sets `OPX.Config.MODULES.dealership`. Shared script.

| Key | Default | What it does |
|---|---|---|
| <a id="config-dealership-enabled"></a>`enabled` | `true` | `false` switches the module off. |
| <a id="config-dealership-currency"></a>`CURRENCY` | `'EDDIES'` | Money type prices are in. An unknown type refuses every sale (boot error). |
| <a id="config-dealership-hand-over"></a>`HAND_OVER` | `true` | Create the bought car on the dealer marker. `false` only files it. |
| <a id="config-dealership-use-radius"></a>`USE_RADIUS` | `4.0` | Flat metres from a dealer within which it can be used. |
| <a id="config-dealership-marker"></a>`MARKER` | `garage = cylinder/interaction/2.5`, `avpad = ring/interaction/3.5` | Marker look per kind: `{ shape, style, RADIUS }`. |
| <a id="config-dealership-max-distance"></a>`MAX_DISTANCE` | `150.0` | Metres beyond which a marker is not drawn (1–500). |
| <a id="config-dealership-ground-offset"></a>`GROUND_OFFSET` | `0.06` | Marker lift off Z (0–2). |
| <a id="config-dealership-av-lift"></a>`AV_LIFT` | `1.2` | Metres above the dealer an AV is handed over (0–10). |
| <a id="config-dealership-scan-ms"></a>`SCAN_MS` | `500` | Client marker and zone scan interval. |
| <a id="config-dealership-poll-ms"></a>`POLL_MS` | `15000` | How often the client re-asks for dealers. |
| <a id="config-dealership-request-window-ms"></a>`REQUEST_WINDOW_MS` | `10000` | Per-player request window. |
| <a id="config-dealership-requests-per-window"></a>`REQUESTS_PER_WINDOW` | `6` | Requests allowed per window (buy, offer, decide). |
| <a id="config-dealership-cooldown-ms"></a>`COOLDOWN_MS` | `3000` | Minimum gap between two purchases. |
| <a id="config-dealership-key"></a>`KEY` | `{ ID = 'opx.dealership.use', NAME = 'dealership.key.use', DEFAULT = 'E' }` | The key mapping. A separate mapping from the garages key. `DEFAULT = false` registers none. |
| <a id="config-dealership-menu"></a>`MENU` | `{ ANCHOR = 'center', WIDTH = 708, HEIGHT = 708, MAX_HEIGHT_VH = 88, VISIBLE_ROWS = 15 }` | Size of the list panel; clamped by the menu module. |
| <a id="config-dealership-commands"></a>`COMMANDS` | `{ list = 'opx.dealership.list', stock = 'opx.dealership.stock', buy = 'opx.dealership.buy' }` | Command names. |
| <a id="config-dealership-preview"></a>`PREVIEW` | `{ ENABLED = true, LIMIT = 12, LOCKED = true, LIFT = 0.1, POINTS = {} }` | Showroom cars. `LIMIT` per dealer; `LIFT` metres added to Z (0–2). See below for `POINTS`. |
| <a id="config-dealership-zone-radius"></a>`ZONE_RADIUS` | `30.0` | Flat metres around a dealer where the "sell a vehicle" row appears. Must be ≥ `USE_RADIUS`. |
| <a id="config-dealership-offer-timeout-ms"></a>`OFFER_TIMEOUT_MS` | `30000` | How long a buyer has to answer an offer. |
| <a id="config-dealership-seller-cut-percent"></a>`SELLER_CUT_PERCENT` | `10` | Seller's commission, 0–100, rounded down. The rest goes to the company. |
| <a id="config-dealership-company"></a>`COMPANY` | `{ JOBS = true, GANGS = true, EXCLUDED = { unemployed = true, none = true } }` | Which groups have a company account. Both off means nobody can sell to another player. |
| <a id="config-dealership-stock"></a>`STOCK` | 30 rows in classes Street, Sport, Utility, Bikes, Air | What is sold. See below. |
| <a id="config-dealership-spots"></a>`SPOTS` | `garage1` (one `garage` dealer) | Every dealer. See below. |

### A stock row

```lua
{ KEY = 'hella', LABEL = 'Archer Hella', CLASS = 'Street',
  RECORD = 'Vehicle.v_standard2_archer_hella_player', PRICE = 29000 },
```

`KEY` 1–48 characters and unique; `LABEL` 1–64; `CLASS` 1–32; `RECORD` a TweakDB record (≤ 256); `PRICE` a whole number above zero. Whether a row is an AV is derived from `RECORD` and `AV_PREFIXES` in `config/shared.lua`. A bad row is skipped with a boot warning.

### A dealer and a preview point

```lua
SPOTS = {
    watson_autos = { LABEL = 'WATSON AUTOS', KIND = 'garage',
        X = -1771.79, Y = -77.30, Z = 7.53, HEADING = 90.0, BUCKET = 0 },
},
PREVIEW = { POINTS = {
    show_hella_1 = { X = -1536.1, Y = -205.9, Z = 7.86, HEADING = 52.0,
        BUCKET = 0, DEALER = 'watson_autos', ENTRY = 'hella' },
} },
```

Both follow the shared spot rules (see [the spot helpers](../reference/lib.md)): key 1–48 characters; `X`, `Y`, `Z` finite within ±1,000,000; `HEADING` finite (default `0`); `BUCKET` whole ≥ 0 (default `0`); `LABEL` defaults to the key. A dealer needs `KIND` `garage` or `avpad`. A preview needs `DEALER` (a key in `SPOTS`) and `ENTRY` (a key in `STOCK`). Only X and Y are measured. To capture a position and heading, stand there facing the right way and run `/opx.admin.self.pos`.

## Refusal codes {#codes}

| Code | Meaning |
|---|---|
| `dealership.noVehicles` | No `vehicles` contract. |
| `dealership.noCharacter` | No character loaded (or it changed before the answer). |
| `dealership.noPosition` | Position could not be read. |
| `dealership.noSuchSpot` | No dealer underfoot or by that key. |
| `dealership.wrongBucket` | The dealer is in another routing bucket. |
| `dealership.tooFar` | Further than `USE_RADIUS`. |
| `dealership.noSuchEntry` | No stock row by that key (or its price changed since the offer). |
| `dealership.notSold` | This dealer's kind does not sell that row. |
| `dealership.noCurrency` | `CURRENCY` is not a money type. |
| `dealership.cannotAfford` | Not enough money. |
| `dealership.noSuchGarage` | The chosen garage is not one of this kind in this bucket. |
| `dealership.paymentFailed` | The charge was refused (or the character module's own code). |
| `dealership.registerFailed` | `vehicles.Register` failed unexpectedly; the price was refunded. |
| `dealership.noCompany` | The seller has no job or gang with an account. |
| `dealership.noSuchBuyer` | Bad buyer id, or the seller targeted themself. |
| `dealership.notInZone` / `dealership.buyerNotInZone` | Seller or buyer outside `ZONE_RADIUS`. |
| `dealership.buyerCannotAfford` | The buyer cannot afford the offer. |
| `dealership.noOffer` | No offer waiting, or the token does not match. |
| `dealership.offerDeclined` / `dealership.offerExpired` | The buyer said no, or did not answer in time. |
| `dealership.sellerGone` / `dealership.buyerGone` | The other side left or walked out of the zone. |
| `dealership.nothingForSale` / `dealership.noList` | Client only: empty stock, or the menu could not open. |
| `error.noPermission` | Client only: another surface holds the keyboard. |
| `error.tooFast`, `error.badRequest` | Cooldown or request window; malformed request. |

Codes from [`vehicles.Register`](vehicles.md#codes) (for example `vehicle.limit`) pass through after a refund. Each code is also a locale key.
