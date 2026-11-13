# LibGamepadContextMenuBridge

**AI disclosure:** AI was used to generate and refactor code and documentation, through Hermes Agent using an OpenAI model. Author and maintainer: **Azmail**. See [full credits](CREDITS.md).

Use inventory actions from compatible keyboard/mouse addons in ESO's gamepad item-action menu.

## Requirements

- Required: **LibCustomMenu 7.3.0 or newer** (`LibCustomMenu>=730`).
- Optional: **LibAddonMenu-2.0** for the settings panel.
- Optional: **Tamriel Trade Centre and its price data** for market prices and material cost estimates.

Install these separately. The bridge targets the desktop client and ESO API **101051**; console support is not claimed.

## What it does

- Adds compatible inventory actions registered through LibCustomMenu.
- Shows supported submenu entries as `Parent: Child`, including checkbox toggles.
- Adds mark/unmark as junk for eligible items.
- Offers optional TTC prices, vendor value and item-status information.
- Estimates crafting material costs and marks missing prices as incomplete. Market comparisons are not net profit.
- Keeps account-wide settings separately for EU and NA.

## Install and use

Place the `LibGamepadContextMenuBridge` folder in your ESO `live/AddOns` directory. Enable it and LibCustomMenu, then open the inventory in gamepad mode.

With LibAddonMenu, open **Settings > Addon Settings > LibGamepadContextMenuBridge**. Without it, use `/lgcmb on` or `/lgcmb off`. `/lgcmb status` shows the current state.

## Compatibility

Submenu entries appear as flat actions, not nested menus. Headers, dividers and disabled actions are omitted. Some mouse-only actions are not supported: clicks on submenu titles, top-level checkboxes and dynamically built submenu entries. The bridge does not convert arbitrary keyboard interfaces.

Compatibility with every LibCustomMenu addon is not guaranteed.

## Credits

Thanks to votan (LibCustomMenu), sirinsidiator (LibAddonMenu-2.0), cyxui / TamrielTradeCentre.com (TTC), ESOUI / ZeniMax Online Studios (UI source and documentation), and Baertram (review feedback).

This add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates.
