# Schrodi's Housing Tools

Small quality-of-life fixes for houses: assistants from your quickslots, storage chests on demand, the keyboard housing editor and the Furniture Vault.

## Housing editor

![Retrieve list with sort headers, filters, right-click to store and Retrieve To in the footer](../_screenshots/SchrodisHousingTools/SchrodisHousingTools.png)

**Sortable Retrieve list.** The Retrieve tab gets *Name* and *Distance* column headers. Click a header to sort by it; click again to reverse the order. The default is *Distance*, nearest first, the same as the game. Your choice is remembered.

**"Retrieve To" next to the list.** The game shows the *Retrieve To* bag selector in a separate box in the top-left corner of the screen. This addon moves it into the footer of the Retrieve list, where the "Bag: x/y" line used to be. The bag list opens upwards.

**Right-click to store** *(off by default)*. With this checkbox on, right-clicking a furnishing in the Retrieve list puts it away into the *Retrieve To* bag. Path nodes are ignored. The checkbox sits next to the filter dropdown above the list.

**Bound items to Vault** *(off by default)*. Bound furnishings always go to the Furnishing Vault when you put them away, whatever bag is selected. Everything else still goes to the selected bag. This works for every way of putting furniture away: the list, right-click, and the keybind in the world (keyboard and gamepad). It does nothing if the Furnishing Vault is not available (it needs ESO+ and the vault collectible).

**Smarter category jumps.** When you place or retrieve the last item in a category, the game jumps back to the first category in the list. With this addon it moves to the next non-empty category instead, or to the previous one if there is no next one. This applies to the Place and Retrieve tabs. The Crown Store tab is left alone.

## Furniture Vault

Both the **Withdraw** and **Deposit** panels of the Furniture Vault get the same filter dropdown as the housing editor:

- **Bound state:** Bound / Unbound
- **Furnishing limit type:** the four placement limit groups (traditional furnishings, special furnishings, collectible furnishings, special collectibles)

The dropdown is created by the game's own housing editor code, so the options and their names are the same. Filters reset when you reload the UI, as in the housing editor.

## Assistants from your quickslots

Put an assistant collectible (banker, merchant, armory assistant, deconstruction assistant, smuggler) or the **Aetherial Well** in your quickslots and use it inside a house:

- If that type of assistant is already placed in the house, it is **moved in front of you**. Use it again to **send it back** to where it was.
- If there isn't one and it's your own house, it is **placed** in front of you, and removed again on the next use.
- In someone else's house without one placed, the game summons the assistant as usual.

So you can keep assistants tucked away in a corner and still have them at hand.

![A banker brought in front of the player from the quickslot](../_screenshots/SchrodisHousingTools/SchrodisHousingTools-assistant.png)

**Not loaded when Essential Housing Tools is enabled**, which has its own version of this.

Moving or placing furniture needs **decorating permission** in the house: you have to be the owner, or have Decorate access there. Without it you get "Insufficient permissions." in chat (in someone else's house without a placed assistant, the game's normal summon still works). The same applies to `/storage`.

## /storage

`/storage` brings every storage chest and coffer in the house in front of you, in rows of four, coffers first. Run it again to put them all back.

## Settings

There is no settings menu. The two checkboxes in the housing editor and the sort order are saved account-wide.

## Upgrading from HousingRetrieveSort / FurnitureVaultFilters

This addon replaces both of them. Disable or delete the old ones. If either is still enabled, its part of this addon is turned off and you get a reminder in chat.

Settings are not carried over. Set the sort order and the two checkboxes again once.

## Upgrading from EssentialSnugpodTools

The quickslot assistants and `/storage` moved here from Essential Snugpod Tools 1.0. Update that addon to 2.0 (which keeps only the Snugpod magic), otherwise both would react to the same quickslot.

## Known limitations

- Keyboard UI only (except for *Bound items to Vault*, which also works on gamepad).
- With *Bound items to Vault* on, the in-world keybind label still says "Put Away to <selected bag>" for bound furnishings, even though they go to the vault.
