# Changelog

## 0.2.2
- Clearer wording: the settings and tooltips now say "starts turned off".
- The addon list shows the right version next to the name again.

## 0.2.1
- Front bar and Back bar are one tickbox again: "Skill bars".
- "Get the Windows tool" opens the project page on GitHub.

## 0.2.0
- Addon settings are copied in game. Tick "Addon settings" under What to copy: Apply then also copies the main's settings for every addon on the list that is turned on for the account, and reloads the UI so they load. Stats, logs and collected data stay as each account has them, and data addons are never touched. Starts turned off.
- The base game's chat window, meters and quest tracker positions can be copied too ("Chat window, meters and quest tracker"). Starts turned off.
- "Undo addon copies" in the settings (or `/fas undo`) puts back the addon settings the account had before it first copied, for a month.
- With "Automatically when I log in", addon settings are copied once per account for each snapshot.
- After the reload the window shows the report of what was copied.

## 0.1.4
- Tickboxes next to Load build choose what gets loaded: front bar, back bar, champion stars, quickslots. Before, that choice was only in the settings and both skill bars were one choice.

## 0.1.3
- Saving a build no longer stops with an error. The quickslot wheel was looked up with a game value that no longer exists.
- Loading a build lists the quickslots it can't carry over (emotes, quick chat and quest items).
- The line under the window title shows its separators again.

## 0.1.2
- A key that is in the way on the character is cleared first, even when it is held by an addon the main doesn't run. The preview shows it.
- After copying, anything that didn't land is tried once more before it is reported.
- The main account now warns while Synced Account Settings is syncing there. That addon puts its saved keybinds back after every login, which can erase a change before the snapshot is taken.
- The snapshot stores only the keys that are bound, which makes the saved file about ten times smaller.
- The window shows the version.

## 0.1.1
- Each character now copies the snapshot once. The game keeps settings, keybinds and chat colors per character, and 0.1.0 treated the whole account as done after one character.
- Nothing is copied while Synced Account Settings is active on the account, and the window says why. That addon puts its own saved settings and keybinds back after every login, which undid the copy.
- Keybinds are sent a few at a time, not all at once.
- After copying, the window lists what was copied and anything the game didn't accept.
- Windows tool: each account is listed once, spelled the way the game spells it. Its window now reports its own errors.

## 0.1.0
- First version.
- Snapshot on the main account, apply on other accounts (ask or automatic): game settings by page, keybinds, chat colors, size and fade.
- Preview of every change before applying.
- Character builds: save and load skill bars, champion stars and quickslots across characters and accounts, skipping what doesn't fit.
- Windows tool (separate download) for addon settings, chat tabs and window positions.
