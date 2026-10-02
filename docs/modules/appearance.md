---
title: appearance module
description: The character's face, the clothes it wears, the fitting room, and the looks other players are drawn from.
---

# appearance

The `appearance` module owns a character's face and clothes. At join it decides which body the world loads with, puts the stored face and clothes on, and sends the announcement that lets the player into the world. It opens the game's own mirror to edit a face, runs the **fitting room** where a player picks clothes slot by slot, and hands every player's look to the other players so they are drawn at all. A player opens their appearance panel with `/opx.appearance`; the fitting room opens at a clothing store, a shop, from staff, or once after character creation. Other modules use its contract to dress, preview or bill clothing.

| | |
|---|---|
| Side | both |
| Requires | `character` (hard) |
| Optional | `menu`, `panel` (they draw the panel and the fitting room) |
| Configuration | `config/appearance.lua` (shared script) |
| Contract | `appearance` v1 — server, client |
| Data | `opx77_character_clothing` (owned); the `appearance` column of `opx77_characters` (row owned by `character`) |

!!! warning "Fatal module"
    The module is declared `fatal = true`. Its client sends `open77:session:gameplayReady`, the only thing that clears the platform's join hold. With it stopped, no player gets into the world.

## Commands {#commands}

| Command | Access | Arguments | What it does |
|---|---|---|---|
| <a id="opx-appearance"></a>`/opx.appearance` | everyone | none | Toggles the caller's appearance panel. Cooldown 2 s. |

There is no fitting-room command. Staff open the room for a player with `/opx.admin.player.wardrobe` (owned by `admin`).

### What the panel offers

- **Looks**: put the stored face back on (**Wear it**), open the mirror on the face (**Edit face**, `ripperdoc` mode) or the hair (**Hair only**, `hairdresser` mode).
- **Body**: shows the body type. It cannot be changed: it belongs to the character.
- **Outfits**: opens the fitting room. A room opened this way has no server grant, so its save is refused with `clothing.noFittingRoom` unless another door granted one in the last 10 minutes.

## Server contract {#server-contract}

`local appearance = OPX.Api.Get('appearance')` on the server, from code inside opx_infinity. `identifier` is a player table, a server id or a citizen id.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="server-appearance-getappearance"></a>`GetAppearance` | `identifier` | Result `{ok, value = snapshot or nil}` | Online: reads memory. Offline (citizen id string): reads the database, so it yields. |
| <a id="server-appearance-saveappearance"></a>`SaveAppearance` | `identifier, snapshot` | Result `{ok, value = canonical}` or `{ok=false, error, detail}` | Yields: call from a thread. The character must be loaded. Validates, stores, tells the client (`faceSaved`). Errors: `error.notLoggedIn`, `appearance.invalid` (detail = validation code), `appearance.tooLarge`. |
| <a id="server-appearance-getclothing"></a>`GetClothing` | `identifier` | Result `{ok, value}` | `value` is the record, `false` when nothing is stored, `nil` when the stored row could not be read. Offline reads yield. Error `clothing.unreadable`. |
| <a id="server-appearance-saveclothing"></a>`SaveClothing` | `identifier, clothing` | Result | Yields. The character must be loaded. Does not check a fitting-room grant. Errors: `error.notLoggedIn`, `clothing.invalid` (detail = code), `error.unavailable` (`clothing_unavailable`: stored record unreadable this session), `clothing.tooLarge`. |
| <a id="server-appearance-openwardrobe"></a>`OpenWardrobe` | `playerId` | `true` or `false, 'invalid_player'` | Asks the player's client to open the fitting room and grants a clothing save. `true` means the ask went out, not that a room opened. The caller checks permission. |
| <a id="server-appearance-allowclothingsave"></a>`AllowClothingSave` | `playerId, owner` | `true` or `false, 'invalid_player'` | Lets the player's client save clothing for the next 10 minutes. For doors that put clothes on without a room (a bought uniform, a saved outfit). `owner` is only logged. |

### The clothing record

```lua
{
  schemaVersion = 1,
  equipment = { Head = 'Items.…' or false, Face, InnerChest, OuterChest, Legs, Feet,
                Outfit, UnderwearTop, UnderwearBottom },
  wardrobe = { active = 0..6 or nil, outfits = { ['0'] = { Head = 'Items.…', … }, … } },
}
```

Every item must match `^Items%.[%w_%.%-]+$` and be at most 160 bytes. Outfits are indexed `0` to `6` and may override the seven visible slots only (not underwear).

## Client contract {#client-contract}

`local appearance = OPX.Api.Get('appearance')` on the client, from code inside opx_infinity. Every function answers a Result and never raises. A write answers that it was **queued**; the outcome arrives on [`opx:on:appearance:decision`](#opx-on-appearance-decision). Every function except `State`, `ClosePanel`, `CloseWardrobe`, `OfferWardrobeGroups` and `EndClothingPreview` answers `appearance_unavailable` when the client has no native appearance API.

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| <a id="client-appearance-getskin"></a>`GetSkin` | none | `{citizenId, family, snapshot}` | The stored face as the server holds it. `no_character` without a character. |
| <a id="client-appearance-captureskin"></a>`CaptureSkin` | none | `{snapshot, citizenId}` | What the puppet wears now. Error: the capture failure, e.g. `capture_failed`. |
| <a id="client-appearance-getfamily"></a>`GetFamily` | none | `{family, citizenId}` | `'female'` or `'male'`. |
| <a id="client-appearance-setskin"></a>`SetSkin` | `snapshot` | `{queued = true, citizenId}` | Puts a face on the puppet; stores nothing. Raises `applied`. Errors: `no_character`, `appearance_busy`, `stored_build_mismatch`, snapshot validation codes. |
| <a id="client-appearance-saveskin"></a>`SaveSkin` | `snapshot?` | `{queued = true, citizenId}` | Sends a face to the server; a capture when `snapshot` is nil. Raises `saved`. Errors: `no_character`, `appearance_busy`, `stored_build_mismatch`. |
| <a id="client-appearance-openeditor"></a>`OpenEditor` | `mode?` | `{queued = true, citizenId}` | Opens the game's mirror. `mode` is `'ripperdoc'` (default) or `'hairdresser'`. Errors: `invalid_mode`, `player_down`, `character_creation_in_progress`, `appearance_busy`, `no_character`. |
| <a id="client-appearance-opencreator"></a>`OpenCreator` | none | `{queued = true, citizenId}` | Answers `needsCreation`: opens the creation editor on the character's body. Errors: `player_down`, `no_character`, `appearance_busy`, `creation_refused`, `already_has_a_face`. |
| <a id="client-appearance-isopen"></a>`IsOpen` | none | `{open, editing, creating, panel, wardrobe}` | `open` is whether a native modal is on screen. |
| <a id="client-appearance-issettled"></a>`IsSettled` | none | `{settled, announced, waiting, citizenId}` | `waiting` is `creator`, `creation`, `server`, `body`, `restore` or nil. While `settled` is false the player is not in the world. |
| <a id="client-appearance-state"></a>`State` | none | table | Diagnostic snapshot: face state, `body`, `panel`, `wardrobe`, `wardrobeOwed`, `wardrobePolicy`, `clothing` (`waiting`, `worn`, `previewing`, `saving`, `unsaved`…), `available`. |
| <a id="client-appearance-openpanel"></a>`OpenPanel` | `owner` | `{queued = true, citizenId}` | Opens the appearance panel for a named caller; the same owner again redraws it. Errors: `invalid_caller`, `player_down`, `no_character`, `appearance_busy`, `panel_busy`. |
| <a id="client-appearance-closepanel"></a>`ClosePanel` | `owner` | `true` | Errors: `no_panel_open`, `not_owner`. |
| <a id="client-appearance-openwardrobe"></a>`OpenWardrobe` | `owner` | `{queued = true, citizenId}` | Opens the fitting room for a named caller, on a thread. Does **not** grant a server save. Errors: `invalid_caller`, `wardrobe_busy`, `equipment_api_unavailable`, `player_down`, `player_unavailable` (not alive on foot, or in a vehicle), `spawn_up`, `input_captured`. A later failure raises `wardrobeOpened` with `ok = false`. |
| <a id="client-appearance-closewardrobe"></a>`CloseWardrobe` | `owner` | `true` | Closes the room and puts back what the puppet wore. Errors: `no_wardrobe_open`, `not_owner`. |
| <a id="client-appearance-offerwardrobegroups"></a>`OfferWardrobeGroups` | `owner, groups` | `true` | Adds a strip of buttons to the open room: `groups` is an array of `{id, label, disabled}`; an empty list removes the caller's strip. A press raises `wardrobeGroup`. The strip goes when the room closes. Errors: `no_wardrobe_open`, `invalid_caller`, `invalid_groups`. |
| <a id="client-appearance-dresswardrobe"></a>`DressWardrobe` | `records` | `true` | Puts a look (slot → record name, or `false`) on the open room's draft. Slots this body's catalogue lacks are skipped. Errors: `no_wardrobe_open`, `wardrobe_closed`, `invalid_look`, `nothing_wearable`. |
| <a id="client-appearance-beginclothingpreview"></a>`BeginClothingPreview` | `owner` | `{clothing, family, citizenId}` | Borrows the puppet: nothing is saved or shown to others while it is lent. Refused while the fitting room holds it. Errors: `player_down`, `invalid_caller`, `preview_busy`, `no_character`, `clothing_unavailable`, `clothing_not_saved`, `clothing_not_ready`, `clothing_saving`. |
| <a id="client-appearance-endclothingpreview"></a>`EndClothingPreview` | `owner, keep?, records?` | `true` | Gives the puppet back. `keep = true` saves what it wears; otherwise the stored record goes back on. `records` lists record names put on. Errors: `no_preview`, `not_owner`. |

## Events {#events}

`opx:in:appearance:face` and `opx:in:appearance:clothing` are private server events.

| Event | Direction | Arguments | Meaning |
|---|---|---|---|
| <a id="opx-net-appearance-saveface"></a>`opx:net:appearance:saveFace` | client → server | `{snapshot, citizenId?, family?}` | Store this face. `family` is sent by a creation only and is written once to the character. Cooldown 2 s. |
| <a id="opx-net-appearance-saveclothing"></a>`opx:net:appearance:saveClothing` | client → server | `{clothing, citizenId}` | Store this clothing record. Refused with `clothing.noFittingRoom` unless a grant is live. Cooldown 2 s. |
| <a id="opx-net-appearance-facesaved"></a>`opx:net:appearance:faceSaved` | server → client | `snapshot` | The face was stored. |
| <a id="opx-net-appearance-clothingsaved"></a>`opx:net:appearance:clothingSaved` | server → client | `record` | The clothing was stored. |
| <a id="opx-net-appearance-refused"></a>`opx:net:appearance:refused` | server → client | `code, operation` | A save was refused. `operation` is `appearance.saveFace` or `appearance.saveClothing`. |
| <a id="opx-net-appearance-show"></a>`opx:net:appearance:show` | server → client | `kind` | `/opx.appearance` ran: toggle the `panel`. |
| <a id="opx-net-appearance-openwardrobe"></a>`opx:net:appearance:openWardrobe` | server → client | none | Sent by the server `OpenWardrobe`: open the fitting room. |
| <a id="opx-net-appearance-openpanel"></a>`opx:net:appearance:openPanel` | server → client | none | Opens the appearance panel. The client listens; nothing in opx_infinity sends it. |
| <a id="opx-net-appearance-present"></a>`opx:net:appearance:present` | client → server | `body, equipment, wardrobe, sequence` | This player's look, for the others. Floor 500 ms. |
| <a id="opx-net-appearance-presentack"></a>`opx:net:appearance:presentAck` | server → client | `sequence, accepted` | Whether the body could be read. |
| <a id="opx-net-appearance-replay"></a>`opx:net:appearance:replay` | client → server | `sequence` | Send me everybody else's look. Floor 500 ms. |
| <a id="opx-net-appearance-replayed"></a>`opx:net:appearance:replayed` | server → client | `sequence` | Every held look was sent. |
| <a id="opx-net-appearance-look"></a>`opx:net:appearance:look` | server → client | `playerId, look` | Another player's look, or `false` while their body is away. |
| <a id="opx-net-appearance-absent"></a>`opx:net:appearance:absent` | client → server | none | My body is going (reload or unload). |
| <a id="opx-net-appearance-resend"></a>`opx:net:appearance:resend` | server → all clients | none | The server half started: publish and ask again. |
| <a id="opx-on-appearance-decision"></a>`opx:on:appearance:decision` | client, local | `{ok, event, error?, citizenId?, …}` | Raised after every decision. See the table below. |
| <a id="opx-on-appearance-view"></a>`opx:on:appearance:view` | client, local | `{kind, …}` | The view seam: what the panel and the room should draw. Read by `client/view.lua`. |

### Decision events

`opx:on:appearance:decision` is raised with `TriggerEvent` on the client, so only code inside opx_infinity hears it. Branch on `event`.

| `event` | Extra fields | Raised when |
|---|---|---|
| `gameplayReady` | | The join announcement went out. |
| `restored` | | A stored face was applied (`ok`), or the apply failed (`error`). |
| `settled` | | `ok = false`, `error = 'stored_build_mismatch'`: the stored face is from another game build; the player enters on the default face. |
| `needsCreation` | `family` | The character has no face. Nothing opens the creator until a caller calls `OpenCreator`. |
| `applied` | | A face from `SetSkin` or **Wear it** reached the puppet, or did not. |
| `created` | | The creation's face was stored, or not (`error`). |
| `saved` | `unchanged?` | An edit was stored, or refused (`error`). `unchanged = true` when it matched the stored face. |
| `characterChanged` | | The live character changed. |
| `panelOpened` / `panelClosed` | `reason` on close | The panel went up or down. |
| `wardrobeWanted` | | `ok = true`: the join owes a fitting room. `ok = false`: no longer owed (`error` says why). |
| `wardrobeOpened` | `creation` | The room opened, or failed to open (`ok = false`, `error`). |
| `wardrobeClosed` | `reason, kept, creation, slots` | The room closed. `slots` lists the slots changed when kept, for billing. |
| `wardrobeGroup` | `owner, group` | A button from `OfferWardrobeGroups` was pressed. |
| `clothingRestored` | | Stored clothing read back on the puppet, or did not (`clothing_not_restored`, `clothing_gate_shut`). |
| `clothingSaved` | | A clothing save was stored, or refused (`error` is the server code). |

## Garment names and pictures {#garments}

The fitting room shows each piece of clothing with its real name and a picture of it on the player's body family. The data is generated; nothing here is a setting.

| Piece | What it is |
|---|---|
| `modules/appearance/data/garments-1.lua` … `garments-5.lua` | Generated tables: `["Items.<record>"] = { NAME, FEMALE, MALE }`, the item's name and the picture file for each body family. Either picture may be missing. Do not edit by hand. |
| `modules/appearance/client/garments.lua` | Loaded before the parts; reads them. Exposes `M.Garments.Describe` (client, inside the module). |
| `web/images/clothing/*.webp` | The pictures (160 px WebP), shipped to every client. Built from `ui/public/images/clothing/` by `npm run build`. |
| `web/images/clothing/ATTRIBUTION.md` | Where they come from: pictures © CD PROJEKT RED (in-game renders, collected from the Cyberpunk Wiki, not covered by this repository's licence); names from the Cyberpunk Wiki, CC BY-SA. |
| `tools/generate-garments.mjs` | Rebuilds pictures, attribution and the `garments-*.lua` parts from a staged clothing collection: `npm i --no-save sharp`, then `node tools/generate-garments.mjs <collection-dir>`. Only records the server's items table knows (with a wardrobe slot) are kept. If it writes a different number of parts, update the `garments-*.lua` lines in `open77.lua`. |

| Function | Parameters | Returns | Notes |
|---|---|---|---|
| `M.Garments.Describe` | `record, family` | `name, picture` (each may be nil) | `record` is an `Items.*` name, `family` is `'female'` or `'male'`. The picture is the family's own, else the other body's, else nil. A malformed row is reported once with `OPX.Note` and treated as missing. Not on the contract. |

Each box in the room is drawn through the [panel](panel.md) `tiles` spec with `labels` (the garment name, or a name made from the record when there is none) and `images` (the picture, or `''`, which draws a monogram).

The category names are the `wardrobe.slot.*` locale keys: *Head*, *Face*, *Top* (`InnerChest`), *Jacket* (`OuterChest`), *Pants* (`Legs`), *Shoes* (`Feet`), *Outfit*; in French *Tête*, *Visage*, *Haut*, *Veste*, *Pantalon*, *Chaussures*, *Tenue*.

## Configuration {#configuration}

`config/appearance.lua` sets `OPX.Config.MODULES.appearance`. Shared script. `enabled = false` switches the module off. Nothing else in opx_infinity sends the join announcement, so only do this when another resource does (see the warning above).

| Key | Default | What it does |
|---|---|---|
| <a id="config-appearance-enabled"></a>`enabled` | `true` | Switches the module on or off. |
| <a id="config-appearance-game-builds"></a>`GAME_BUILDS` | `{ ['2.31'] = true }` | Game builds a stored face may be read back on. A face from another build is refused, not applied. |
| <a id="config-appearance-max-json-bytes"></a>`MAX_JSON_BYTES` | `49152` | Largest encoded face stored. Values under 1024 fall back to 49152. The clothing limit is fixed at 16384. |
| <a id="config-appearance-present-bodies"></a>`PRESENT_BODIES` | `true` | Hand every player's look to everyone else. `false` only when another resource does it; otherwise nobody sees anybody. |
| <a id="config-appearance-commit-ms"></a>`COMMIT_MS` | `20000` | How long the client waits for the server to answer a face or clothing save. |
| <a id="config-appearance-save-cooldown-ms"></a>`SAVE_COOLDOWN_MS` | `2000` | Client-side wait between two saves. The server's own cooldown is fixed at 2 s. |
| <a id="config-appearance-clothing"></a>`CLOTHING` | table | `PERSIST = true`: put stored clothing on and save changes (`false` leaves clothing to something else). `SAVE_DEBOUNCE_MS = 2000`: how long a change must hold before it is saved. |
| <a id="config-appearance-restore-retries"></a>`RESTORE_RETRIES` | `3` | Re-tries of a join-time face restore the mirror aborted. |
| <a id="config-appearance-family-retries"></a>`FAMILY_RETRIES` | `2` | World reloads onto the character's body family before the player keeps the body they are on. |
| <a id="config-appearance-body-reload-settle-ms"></a>`BODY_RELOAD_SETTLE_MS` | `10000` | After a body reload, how long a face waits for the respawn to finish. |
| <a id="config-appearance-body-reload-timeout-ms"></a>`BODY_RELOAD_TIMEOUT_MS` | `30000` | After this, a reload is ended if the puppet is attached, alive and in the world. Not a positive number: recovery off. |
| <a id="config-appearance-creation-wait-ms"></a>`CREATION_WAIT_MS` | `15000` | How long a character with no face waits for something to answer `needsCreation` before entering on the default face. |
| <a id="config-appearance-bootstrap"></a>`BOOTSTRAP` | table | `CHOICE_WAIT_MS = 15000`: how long the join waits for a character choice while nothing is on screen. `CHOICE_CEILING_MS = 45000`: the whole wait, screen or not (`0` turns it off). `DEFAULT_FAMILY = 'female'`: the body loaded when no character is known in time. |
| <a id="config-appearance-wardrobe"></a>`WARDROBE` | table | See below. |

### WARDROBE

| Sub-key | Default | What it does |
|---|---|---|
| `OFFER_POLICY` | `'first'` | Which world entries get the fitting room. `'first'`: only a character just built in the creator. `'always'`: every world entry. `'never'`: none. An unknown value logs a warning and reads `'first'`. |
| `CREATION_WAIT_MS` | `60000` | How long the join retries opening the owed room before moving on. |
| `CAMERA_OFFSET` | `{ X = 0.0, Y = 2.6, Z = 1.1 }` | Camera position in the room, in metres, in the puppet's space (X across, Y in front, Z up). |
| `CAMERA_FOV` | `95` | Field of view used only when the camera cannot be moved to `CAMERA_OFFSET`. `nil` leaves the player's own. |

The join order for a new character is name → fitting room → spawn menu. A player dressing is inside the spawn module's `HOLD_MAX_SECONDS`; keep that longer than a player needs to dress.

## Refusal codes {#codes}

Codes the server sends on `opx:net:appearance:refused`. Face refusals are also shown to the player through the locale catalogue; clothing refusals are only published and logged.

| Code | Meaning |
|---|---|
| `error.badRequest` | The payload was not a table. |
| `error.tooFast` | Inside the 2 s cooldown. The client retries a clothing save. |
| `error.notLoggedIn` | No character loaded on the connection. |
| `appearance.stale` / `clothing.stale` | The save was captured for another character. |
| `appearance.invalid` / `clothing.invalid` | The face or record failed validation. |
| `appearance.tooLarge` / `clothing.tooLarge` | Over the size limit. |
| `clothing.noFittingRoom` | No server door granted a clothing save in the last 10 minutes. |
| `error.unavailable` | The stored clothing could not be read at login; saves are off this session. |

Validation details on `appearance.invalid` include `unsupported_schema`, `unsupported_game_build`, `invalid_catalog_digest`, `invalid_gender`, `invalid_option_count`, `option_out_of_range`, `duplicate_option` and `sparse_options`. On `clothing.invalid`: `unknown_field`, `invalid_slot`, `invalid_item`, `invalid_active`, `invalid_outfit`, `invalid_outfit_slot`.
