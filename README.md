# dj-comms

QBX community service resource. Admins send a player to sweep plaza spots, progress is saved on the character, and finishing teleports them back to the courthouse.

## Dependencies

- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [ox_inventory](https://github.com/overextended/ox_inventory)

Base QBX food/drink items (`sandwich`, `tosti`, `twerks_candy`, `snikkel_candy`, `water_bottle`, `kurkakola`, `coffee`) must exist in `ox_inventory`.

## Install

1. Drop this folder in your resources (for example `[standalone]/dj-comms`).
2. Add `ensure dj-comms` to `server.cfg` **after** the dependencies above.
3. Discord webhook is already set in `Config.Webhook`.
4. Confirm the start / ped coords in `config.lua` sit where you want them in the plaza. Task and finish coords are the ones you provided.

## Commands

| Command | Permission | Usage |
| --- | --- | --- |
| `sendcomms` | `group.admin` | `/sendcomms [id] [amount] [reason]` |
| `removecomms` | `group.admin` | `/removecomms [id]` |
| `checkcomms` | `group.admin` | `/checkcomms [id]` |

- `amount` is `1` to `150`. There is no higher minimum.
- If the player is already serving, the new amount is **added** (still capped at 150).
- Reason can be multiple words.

## How it works

- Player is teleported to `Config.StartCoords`.
- Up to 4 sweep arrows and map blips are shown at a time.
- Walk to an arrow, press **E**, sweep for **12 seconds**.
- That spot disappears and a new unused spot appears until the assigned total is done.
- 3rd-eye the supervisor ped to see completed / remaining / total / reason.
- 3rd-eye the shop ped to buy base QBX food and drinks so they can stay alive.
- Leaving the comms zone teleports them back and (by default) adds 1 extra task.
- Progress is stored in player metadata, so reconnecting puts them back on comms.
- Finishing (or `/removecomms`) teleports them to `237.15, -406.08, 47.92`.
- Discord webhook logs sends and completions.

## ox_lib

This resource is built on ox_lib, not QB notify/menu/progress:

- `lib.addCommand` for `/sendcomms`, `/removecomms`, `/checkcomms`
- `lib.callback` for starting, cancelling, and completing sweeps
- `lib.notify` for all player/admin messages
- `lib.progressCircle` for the 12-second broom sweep
- `lib.points` + `lib.showTextUI` for the **E** prompt
- `lib.zones.sphere` to keep players in the comms area
- `lib.registerContext` for the 3rd-eye progress menu
- `lib.locale` via `locales/en.json` for all user-facing text
- `cache.ped` / `cache.vehicle` for player entity access

## Exports

```lua
exports['dj-comms']:SendToComms(targetSrc, amount, reason)
exports['dj-comms']:RemoveFromComms(targetSrc)
exports['dj-comms']:IsInComms(targetSrc)
exports['dj-comms']:GetCommsStatus(targetSrc)
```

## Config you may still want to change

These were not in the coords you sent, so defaults were placed in the same plaza:

- `Config.StartCoords` — where they land when sent
- `Config.StatusPed.coords` — progress ped
- `Config.ShopPed.coords` — commissary ped
- `Config.Webhook` — Discord log URL
- `Config.EscapePenaltyTasks` — set `0` if you do not want extra tasks for leaving
- Shop prices / items in `Config.Shop.items`

If a ped is clipped into a wall or floating, nudge those four values in `config.lua` and restart the resource.
