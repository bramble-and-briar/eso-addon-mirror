# Per-Character Mounts

An Elder Scrolls Online addon that gives each character its own favourite mounts.

ESO shares favourite mounts across your whole account, so **Random Favorite Mount** picks from the same list on every character. With this addon, each character keeps its own list.

## Install (Windows)

1. Copy the `PerCharacterMounts` folder into
   `Documents\Elder Scrolls Online\live\AddOns\`
   (if your Documents folder is synced by OneDrive, it's under `OneDrive\Documents\...`).
   You should end up with `AddOns\PerCharacterMounts\PerCharacterMounts.addon`.
2. In game, on the character select screen, open **Add-Ons** and make sure **Per-Character Mounts** is ticked.

## Use

- It's on for every character by default, and each character starts with a clean slate: no favourite mounts.
- Star the mounts you want on that character (**Collections → Mounts**, right-click, **Add to Favorites**, or the settings menu below). Adding a mount switches the character to **Random Favorite Mount**. If you then pick one mount to ride yourself, that sticks until you add another. Its list is put back every time you log in to it.
- Turn it off for a character in the settings menu (below) or with `/pcm off`. That character then shows your normal favourites, and stars you change there are saved as your normal favourites. `/pcm on` turns it back on, with the character's own list as you left it. Chat reminds you whenever you log in to a character that's off.
- Your normal favourites are the ones you had when you installed the addon. The first time it runs, it saves them and reloads the UI once so they're stored safely.

## Settings menu

**Settings → Add-Ons → Per-Character Mounts**:

- **Mounts** shows the character's favourites in the panel on the right. Press it to open a list of every mount you own: the character's favourites at the top, then all of them in the same categories and order as Collections, each favourite with a star. **Triangle** adds or removes the highlighted mount without moving the cursor, and **Circle** goes back. To preview a mount, use Collections: the game doesn't let add-ons preview.
- **Clear all favourites** empties the list. Press it twice: the first press asks, the second clears.
- **Own favourite mounts for this character** is the on/off switch.

On PC with LibAddonMenu-2.0 the same page has a mount picker with Add, Remove and Preview buttons, next to the character's list.

It uses LibHarvensAddonSettings on console and LibAddonMenu-2.0 on PC. Without them, everything still works through Collections and `/pcm`.

## Commands

- `/pcm` shows whether it's on for this character, and its favourites.
- `/pcm on` and `/pcm off` turn it on or off for this character.
- `/pcm copy` adds your normal favourites to this character's list.
- `/pcm clear` empties this character's list.
- `/pcm apply` puts this character's favourites back if something didn't stick.

## Good to know

- Nothing gets lost. A favourite is only un-starred once it's saved somewhere (a character's list or your normal favourites), and a favourite nobody had saved is added to your normal favourites.
- ESO only saves addon data when you log out, switch characters or `/reloadui`. If the game crashes, star changes from that session may be undone, but nothing is lost.
- If the last character you played had no favourites, the game switches you to Random Mount at login; the addon switches you back to Random Favorite Mount.
- Swaps run in the background at about five changes a second, and chat confirms when they're done. Turning it on or off mid-swap takes effect as soon as the swap finishes.
- Lists are saved on this PC. Only mounts are affected; pets and other favourites stay account-wide.
- To uninstall, turn it off (`/pcm off`) on the character you're on so your normal favourites are showing, then delete the folder.

## License

Copyright (c) 2026 the author of Per-Character Mounts. All rights reserved. You may run it for personal use; copying, modifying, reusing or redistributing any part of it isn't allowed without written permission. See `LICENSE.md`.

---

Developer note: `tests/PerCharacterMounts_test.lua` (at the repository root) simulates the game client and server to test the addon's logic. Run the fixed scenarios with `lua5.1 tests/PerCharacterMounts_test.lua`, and random play-throughs with `lua5.1 tests/PerCharacterMounts_test.lua --fuzz <seed> <runs>`.
