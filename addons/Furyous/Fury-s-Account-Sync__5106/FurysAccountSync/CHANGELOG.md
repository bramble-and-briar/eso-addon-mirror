# Changelog

## 0.6.4
- **Smaller version number.** The version in the title bar is now in small print, the same in every Fury window, so the name and your other Fury addons' icons stand out.

## 0.6.3
- **Title-bar icons moved to the left.** The row of your other Fury addons' icons now sits on the left of the title bar, between the addon's name and its version, the same in every Fury window. On the right it could cover other controls, such as Invite by code on the Guild Toolset's Events tab.

## 0.6.2
- **The sidebar shows only with your cursor out.** The Fury sidebar can only be clicked in cursor mode, so it now hides while you play without the cursor and comes back when the cursor does. A new box in the list (`/fury menu`), "Show the sidebar without the cursor too", keeps it on screen all the time.

## 0.6.1
- **Your other Fury addons in the title bar.** Every Fury addon's window now has a row of small icons in its title bar, one per other Fury addon you have installed. Left-click an icon to open that addon, right-click for its settings. Icons that don't fit in a narrow window are left out.
- **Slimmer sidebar.** The Fury sidebar is now about half as wide, with small icons. A new box in the list (`/fury menu`), "Bigger sidebar icons", brings the big ones back.

## 0.6.0
- **The Fury sidebar.** A slim bar of icons, one per Fury addon you have installed, that can stay on screen: left-click an icon to open that addon, right-click for its settings. Type `/fury` or press the key (Controls > Keybindings > Fury's Addons, now named "Show or hide the Fury sidebar") to show or hide it, and drag its violet line to move it. The gear on it, or `/fury menu`, opens the list of your Fury addons with the sidebar's options: a row or a column, lock in place, hide in combat. The sidebar starts turned off.

## 0.5.9
- **One key for the Fury addons menu.** "Open the Fury addons menu" now shows once in Controls > Keybindings, under Fury's Addons, instead of once under every Fury addon. If you had set a key for it, set it again there.
- Fury's Guild Management Toolset is now called **Fury's Guild Toolset**; More from Fury and the Fury addons menu show the new name.

## 0.5.8
- **More from Fury** now lists Fury's Quality of Life, a new addon of small comforts: Select all on the deconstruct screens, a fishing bite alert with the right bait, a queue alert and a lock for everything you wear.

## 0.5.7
- **Same keybinds on all your characters.** The game keeps keybinds per character, so a key you set on one character is missing on your other characters, even on the same account. New tickbox on the main account: "Same keybinds on all this account's characters". With it on, every other character on the main account takes the main character's keybinds when you log in on it, game and addon keys alike. Only keybinds change. Starts turned off. `/fas keys` or the "Copy keybinds to this character" button does it right away.
- **The main character.** The character you press Take snapshot on is the main character, shown in the settings. Automatic snapshots now only come from it. Before, every character on the main account took one at logout, so logging out on a character without your addon keys could take them out of the snapshot your other accounts copy.

## 0.5.6
- **The Fury addons menu.** Type `/fury`, or set the key "Open the Fury addons menu" (under this addon in Controls > Keybindings), for a small window that lists every Fury addon you have installed, each with an Open and a Settings button.

## 0.5.5
- **Make this account the main** always asks first now, also the first time you pick a main.

## 0.5.4
- **One shared library file.** Chat lines, the welcome line and confirm pop-ups now come from the same file every Fury addon carries, next to the look, Start here and More from Fury, so all of them stay identical. Nothing changes in how the addon works, and it still needs no other addon.

## 0.5.3
- **More from Fury.** The Start here page and the settings page now end with a short list of my other addons, with a button in the settings that opens each one's ESOUI page (the game asks first). No chat lines, no pop-ups.

## 0.5.2
- **One look across all of Fury's addons.** Every window now has the same header as the Guild Toolset: the name with its version, a **Start here** button right after it, the settings gear and the close button at the right, and a hover tip on each.
- **New: Start here page** (the button in the window, or `/fas start`): how it works in one page, from picking the main account to undo.
- The version moved from the line under the title into the title itself.
- `/fas help` lists the commands one per line, like the other Fury addons.
- The keybind is named "Open/close the window". The settings page links to the addon's ESOUI page.

## 0.5.1
- HarvestMap's settings are now copied: which pins show on the map, compass and in the world, the filters, pin sizes and colors. It is on the "Which addons" list as Harvest_SavedVars. HarvestMap keeps them in its own layout, so before this they were never copied. It needs "account-wide settings" turned on in HarvestMap on the main, and the copy turns it on for the other accounts. The gathered pin locations are not touched; every account on the PC already shares those.

## 0.5.0
Copying addon settings is now done with care, a few addons at a time.
- "Which addons" in the settings has a tickbox for every addon on the list. On a new install only a small set of well-known addons is ticked. Tick more one at a time: copy, check that addon in game, then tick the next. An install that already copied addon settings keeps every addon ticked.
- The list of changes says how many listed addons are running but not ticked.
- "Undo one addon" in the settings (or `/fas undo NAME`) puts back just that addon's own settings and unticks it. Every other addon stays copied. A pop-up asks before the reload.
- "Make a report line" in the settings (or `/fas report`) gives one line to copy into a comment when something goes wrong: the version, what is ticked, which addons were copied and how the last copy went. It holds no account or character names.

## 0.4.2
- A clear warning wherever addon settings are copied: it can break an addon, so copy with care, check your addons afterwards and use "Undo addon copies" if one misbehaves. It shows in the settings, in the list of changes and in the reload pop-up.

## 0.4.1
- Urich's Skill Point Finder is never copied. Copying its settings stopped it from working. If it broke on an account, "Undo addon copies" in the settings puts its own settings back.

## 0.4.0
- Builds keep gear. Save build stores the armor, jewelry and weapons the character wears, and a **Gear** tickbox next to Load build puts them on from the bag. A piece of the same item, trait and quality counts. What isn't in the bag is listed. Starts turned off. Builds saved before this version hold no gear until you save them again.
- Share a build as text. **Show as text** puts the chosen build into a box as one line to copy with Ctrl+C. **Add from text** adds a build you pasted there. It never replaces a build.
- On the main, the window lists your other accounts: how many characters have the current snapshot, which accounts are behind, and what each does at login.
- With "Addon settings" ticked, the list of changes now names the running addons that aren't on the built-in list, so it is plain what was left out.
- New settings section "Addons that aren't on the list": add an addon by its saved-data name and it is copied with the others. Everything that addon keeps for the whole account is copied, so only add addons that hold settings. Starts empty.

## 0.3.0
Easier first setup. Nothing changes for accounts that are already set up.
- The window shows the setup as three numbered steps, each marked Done, Next or Later, until the account is set up.
- The first button does what the account needs: **Make this account the main** while there is no main, **Take snapshot** on the main, and **At login: Off / Ask me / Automatic** on every other account. Before, both of those were only in the settings.
- A greyed-out button says why when you hover it.
- On the main, the window says how many things changed since the snapshot and lists them, so you know when to take a new one.
- Changing the main account asks first. The old main's snapshot is removed, because it describes the old main.
- The list of changes reads "Off > On" for tickbox settings and uses the game's own words for choices, where the game has them.
- Save build asks before it replaces a build with the same name.
- The first time an account logs in with the addon, one chat line says how to open it.
- `/fas help` lists the commands, and a mistyped command shows that list.
- The window opens where you last left it.
- Settings page: "Open the window" is at the top, and greyed-out options say why.

## 0.2.4
- Nothing reloads the UI without asking. After Apply copies addon settings or window layout (also with "Automatically when I log in"), a pop-up asks to reload, with Reload now and Cancel. With Cancel, the copied settings load at your next /reloadui or login.
- Undo addon copies (and `/fas undo`) asks first too, and changes nothing if you cancel.

## 0.2.3
- The game language is never copied between accounts. This also clears a note from the ESOUI addon check.

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
