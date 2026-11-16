# Guilds Bounty changelog

## Add-on

### 1.12.0
- Renamed to Guilds Bounty: the folder, the addon file and the saved file are `GuildsBounty`, `GuildsBounty.lua` and `GuildsBountySavedVars`. The badges, keybind actions, chat prefix and window names followed the name.
- The commands are `/gbounty` and `/guildsbounty`. Both do the same thing; the old command is gone, so a macro that types it needs one of the two names.
- The saved file from before is not read: shares rebuild from your bags at login, standing offers and reserves start empty, and a key you bound yourself has to be bound again.
- Fixed items in the house storage chests and the furnishing vault going missing from the list while you were away from the house. Housing storage and the vault now read `Housing Storage (Kitchen)` and `Furnishing Vault (Lumber)`, or just the first two words when the chest has no nickname.

### 1.11.43
- Resolved issue with incorrectly removing items from list, or setting incorrect offered date
- Processing after scan was still causing slowness / lockups.   Should not be locking up now during this added slices to processing.

### 1.11.35
- Adjusted how often bag scans happen was causing lockups

### 1.11.31
- Fixed shared items being listed in a guild store by dragging them onto the sell tab.

### 1.11.30
- Shares and Always Share offers now follow items moved to another storage location when there is one clear destination.
- When matching copies are in several locations, the original location is kept rather than guessing.

### 1.11.29
- Protected items can now be moved into and out of banks, house storage, and the furnishing vault.
- Shared furnishings can be placed in a house and picked up again.

### 1.11.28
- Sharing badges now appear in more item screens, including the ragpicker's sell and launder tabs.

### 1.11.27
- Protection messages now explain whether to remove a share or stop Always Share before using an item.

### 1.11.26
- Added **Toggle share** and **Toggle always share** shortcuts under **Controls > Keybinds > Guilds Bounty**. Hover over an item, then press your assigned key to toggle its sharing mode.

### 1.11.25
- Always Share items now receive the same protection as ordinary shared items. Stop Always Share to release them.

### 1.11.24
- Expanded protection to prevent accidental destruction, crafting, use, equipping, guild-store listings, and other actions that could consume or change shared items.
- Viewing details, linking items in chat, and splitting stacks remain available.

### 1.11.23
- Fixed protection that was allowing shared items to be sold or deconstructed.

### 1.11.22
- Updated command help to include guild bank sharing and clearer descriptions of the item menu options.

### 1.11.21
- Reduced repeated chat messages when shared items are refreshed.

### 1.11.20
- House scans now show a short progress message and a summary when finished.
- Added `/gbounty scan clear` (or `/gbounty scan reset`) to stop sharing scanned furnishings from your current house.

### 1.11.12–1.11.17
- Improved add-on startup and house scanning reliability.
- House scans explain when they cannot run, such as when you are outside a house or visiting someone else's.
- Removed the old `/gbounty debug` command.

### 1.11.9–1.11.11
- Always Share offers now track their storage location and available quantity more accurately.
- Quantities update shortly after items are removed from storage.

### 1.11.8
- Added sharing badges to more crafting and deconstruction screens, including the ragpicker.
- Added `/gbounty protect` to toggle protection against selling or deconstructing shared items.

### 1.11.7
- Added house scanning for placed furnishings you want to share, replacing automatic furniture detection.

### 1.11.6
- Added `/gbounty expire <days>` to mark older shares with a stopwatch badge. This is a reminder only; items remain shared.
- Use `/gbounty expire` to check the setting and older-share count, or `/gbounty expire 0` to turn it off.
- Moving or re-sharing an item keeps its original sharing date.

### 1.11.3–1.11.5
- Storage chests now display their names instead of numbers. Renamed chests update the next time shares are refreshed.
- Improved tracking of furniture locations across houses.

### 1.11.1
- Shares and reserves for guilds you have left are cleared when you log in.

### 1.11.0
- Added platform and megaserver tracking so shares are matched to the correct players.

### 1.10.4–1.10.7
- Improved counting across stacks and storage locations.
- Shares and reserves are tracked separately for each location, such as your bags and bank.
- Bound items can no longer receive new share reserves. Existing reserves can still be cleared.

### 1.10.2–1.10.3
- Improved sharing and reserve badges.
- Right-clicking a row in the shared-items window cycles between Shared, Always Share, and Not Shared.

### 1.10.1
- **Upgrade note:** This release resets sharing data from older versions.
- Items with a reserve are listed even when they are not shared.

### 1.9.0–1.10.0
- Made reserves easier to identify, including when nothing remains available to share.
- Removed Google Sheets export.
