Restyle Helper v1.15.37 (test) - Outfit station helper for The Elder Scrolls Online
Author: PUYO

INSTALL
  Put the RestyleHelper folder in  Documents\Elder Scrolls Online\live\AddOns\  and enable it in the add-on list.
  No libraries required. Keep only ONE copy of the folder (remove old copies such as "RestyleHelper - Copy").

BASICS
  The panel appears when you open the outfit station (/rsh toggles it; drag to move).
  Select the Outfit slot on the left of the station first. All changes are PENDING (preview) -
  confirm them with the station's own Apply button. The 3D preview refreshes automatically.

RANDOMIZE
  Randomize All    styles + dyes
  Styles Only / Dyes Only (3)   Dyes Only uses three dyes (primary/secondary/accent) for the whole outfit.
  Unify Style      picks one style that covers at least N armor slots you own and applies it everywhere.
                   Set N with the -/+ buttons in the Options ("Unify: minimum slots covered", 1-7, default 5).
                   Locked slots are excluded from the count. Dyes are not touched.
  Shuffle Dye Order  keeps the colors, only changes which dye goes to primary/secondary/accent.
                   "Shuffle order per slot" off = every slot uses the same swap, on = each slot is swapped differently.
                   Slots with only one dyeable channel take one of the colors already used on the outfit.
  All Different Dyes every part and channel gets a different dye.
  Undo             up to 10 steps.

COLORS (button "Colors")
  - Color families: red / orange / yellow / green / blue / purple / pink / brown / black / white / grey.
    When some are selected, dye randomization only draws from those families (none selected = all dyes).
    Families are derived from each dye's RGB value.
  - Required colors: click dyes to mark them. They are always included when randomizing
    (Dyes Only / Randomize All: up to 3 of them in the three channels; All Different Dyes: dealt first).
  - Excluded colors: right-click a dye to never use it (red x, dimmed). Right-click again to undo.
    Left-click turns it into a required color. A required color is never excluded.

DYE CHANNEL LOCK
  On the station's normal screen, Ctrl+Click one of a part's three dye swatches to lock that channel
  (a lock icon appears). Locked channels are not changed by randomize or shuffle. Ctrl+Click again to unlock.

LOCKS / OPTIONS
  Tick a slot to exclude it from randomizing. Options: apply style / dye changes to weapons, one armor weight,
  locked slots keep their dyes, favorites only, hide slots the style lacks, etc.

ALL-SLOT APPLY (right-click)
  Right-click a style in the style list: "Apply this style to all slots", "... (skip locked)", "Add to Favorites".
  Same armor weight is preferred; another weight is used when missing. Slots a style cannot cover are shown as
  x in the panel's "Style coverage" row and can optionally be hidden.

FAVORITES
  Favorited styles show a star in the style list; "Favorites only" filters the list.
  The Favorites window lets you wear a piece or apply the whole set.

SHARE / PRESETS
  Save presets, post a clickable link to chat (other users of this add-on can click it), or create Discord-friendly
  text and paste messages you received. Unowned styles and unknown dyes are skipped.

SLASH COMMANDS
  /rsh  /rsh share  /rsh fav  /rsh random|style|dye|theme|chaos|order  /rsh undo
  /rsh save <name>  /rsh chat (toggle chat messages)  /rsh stats  /rsh dump

NOTES
  - Chat messages are off by default; use /rsh chat to enable them.
  - Share import / inspect results are shown by default (option "Show share import / inspect results").
  - The add-on language follows the game client (Japanese or English).
  - Settings are account-wide and kept separately per server (NA / EU / PTS) in SavedVariables\RestyleHelperSV.lua. Settings from older versions are copied once on first launch on each server.

CREDITS
  The favorites star / "Favorites only" idea was inspired by OutfitStylesFavorites by @timere-nemo.
  The code in this add-on is an independent implementation.

LICENSE
  Free for personal, non-commercial use with ESO (see LICENSE.txt). No selling or commercial use.

DISCLAIMER

CHANGES v1.15.37 (test)
 - Fewer split style groups: jerkin ("shirt") icons join their set; sets are also merged by common
   piece name regardless of ID distance (no merge if the same slot x weight would clash).

CHANGES v1.15.36 (test)
  - Fixed /rsh dump being captured by an old diagnostic (capped at 120 entries); it now writes every style (styleDump). The old command is /rsh dumpold.

CHANGES v1.15.35 (test)
  - /rsh dump now starts with a header line (game total / indexed / excluded counts); excluded items are listed in styleDumpSkipped.

CHANGES v1.15.34 (test)
  - Added /rsh dump: writes every style (id, name, slots, weight, game style id, add-on group, owned, icon) and the group merge log to SavedVariables.

CHANGES v1.15.33 (test)
  - Preset window: Apply is green, Delete is red.
  - Favorites window: detail text uses the same colour as names/buttons.
  - Style grouping: besides the group name, the first piece name and icon name prefix are used to decide that two groups are the same set (fix for light/medium/heavy being split). /rsh find now also lists the merge decisions.

CHANGES v1.15.32 (test)
  - Preset names with Japanese text fixed again: character handling no longer uses patterns, and the typed name is used as-is if cleaning leaves it empty.

CHANGES v1.15.31 (test)
  - Diagnostics: when a preset name falls back to the default, the name field length and first bytes are printed. The weight trace now includes the style name.

CHANGES v1.15.30 (test)
  - Fixed weight mismatches in style unify etc.: when the chest was a robe (a weight value other than light/medium/heavy), no other slot matched it and every slot was treated as another weight. Robes now count as light.
  - If a style truly lacks that weight for a slot, it is still substituted as before.

CHANGES v1.15.29 (test)
  - Diagnostics: while /rsh trace is on, a weight substitution prints the style, slot and candidate list to chat.

CHANGES v1.15.28 (test)
  - Fixed preset names with Japanese text being replaced by the default name (name cleaning is now byte-based).
  - /rsh find now also saves its output to SavedVariables (findLog).

CHANGES v1.15.27 (test)
  - Slot names and weight letters in the status row use the same colour as the style name.
  - Weight unify: pieces without weight data are now treated as usable for any weight instead of falling back to another weight.

CHANGES v1.15.26 (test)
  - Removed the 0.05 s periodic check. The add-on now reacts to the game's change notifications and checks once at the scheduled restore time (0.1 s later).

CHANGES v1.15.25 (test)
  - Fixed the resize triangle not showing (it was hidden behind the window background); now drawn as a yellow triangle at the bottom-right.
  - Widening the Favorites window now widens the name column and moves details/buttons right so hidden text becomes visible.
  - Load fix: the weight display in the status row was triggering a full style-index build; it now uses a light query.

CHANGES v1.15.24 (test)
  - The armor weight of each slot (L/M/H) is now shown under the status squares.

CHANGES v1.15.23 (test)
  - Every slot that cannot be applied (unowned / no piece / hidden) now shows a red x.

CHANGES v1.15.22 (test)
  - Dye shuffle (shared order): pieces with only some dyeable channels now receive colours using the same permutation as the whole body; hidden leftover colours are not used.
  - A triangle grip at each window's bottom-right resizes the window itself (not the display scale). Double-click resets. Text areas in the Share window grow with it.
  - Main panel status squares now show ownership: green = owned, red = unowned style in use.

CHANGES v1.15.21 (test)
  - Loading a preset / shared outfit now updates the main panel's style status (name and per-slot result).

CHANGES v1.15.20 (test)
  - New option "Prefer robe over jerkin for chest": styles with both a jerkin and a robe always use the robe.
  - The red warning (unowned items included) now lists which slots / how many dyes are unowned. The green square only means the style has that slot, not that you own it.
  - New "Overwrite selected" button in the Share / Presets window: overwrites the selected preset with the current outfit.

CHANGES v1.15.19 (test)
  - Removed the "(test)" label from "Preview unowned styles / dyes"; they are now regular features.
  - Windows can be resized (0.6x-2.0x) by dragging the bottom-right corner; double-click it to reset. The scale is saved.
  - Hovering an option shows a box with a detailed description.
  - Removed the dye watch window: colours are restored once, 0.1 s after a style change (colours the game writes later are not undone).

CHANGES v1.15.18 (test)
  - Applied (visible) colours now carry over to another style even if you never changed colours in the preview. The hidden old colours the game keeps for non-dyeable channels are not used; those channels are filled from the nearest visible channel.

CHANGES v1.15.17 (test)
  - Dye overwrite now runs for 0.1 s starting 0.1 s after a style change (check interval 0.05 s).

CHANGES v1.15.16 (test)
  - Fixed styles that exist in only one weight being shown as "other weight" (~). Slots without weight variants are no longer treated as substituted, and the Light/Medium/Heavy buttons leave them as they are.

CHANGES v1.15.15 (test)
  - Removed the chat warning when the weapon options are turned on (menu label only).

CHANGES v1.15.14 (test)
  - Added a cost warning to the "apply to weapons" options.

CHANGES v1.15.13 (test)
  - Dye overwrite now runs for 0.3 s starting 0.3 s after a style change (previously until 1.5 s).

CHANGES v1.15.12 (test)
  - Colours given to non-dyeable channels are remembered too and applied when a style with that channel is chosen. Empty (undyed) channels are filled from the nearest remembered channel of that part.

CHANGES v1.15.11 (test)
  - Improved style set grouping (icon abbreviations hvy/med/lgt, singular piece names, auto-merge of split sets). Fixes shoulders being treated as a separate set (x marks, weight switching).

CHANGES v1.15.10 (test)
  - Added diagnostic command /rsh find <name> (to inspect style set grouping).

CHANGES v1.15.9 (test)
  - Detects the game's own Revert (no pending changes left) and discards the dye memory.

CHANGES v1.15.8 (test)
  - Keeps your current dyes when you change a style at the station (the game otherwise mixes in dyes previously saved for that style). Option "Keep current dyes when changing style", default ON.
  - Dye overwrite now starts 0.3 s after a style change, and the preview is refreshed once when watching ends (fixes unpainted parts).
  - The game's own Revert (back to the applied state) is no longer overridden.
  - Single-dye-channel parts use that part's remembered colour. Watch time extended to 1.5 s.
  - Remembers your dyes per slot even when passing through styles with fewer dye channels. Added /rsh trace and /rsh slots diagnostics.

CHANGES v1.15.0 (test)
  - New options "Preview unowned styles" / "Preview unowned dyes" (default OFF). They include unowned items in random, favorites, presets and dye choices.
    Note: while unowned items are included, the station's Apply is blocked by the game (a red warning is shown).
    Note: whether the game accepts unowned dyes in preview is unverified in-game.
  - "Favorite current styles" button: registers the styles of all slots currently previewed/worn.
  - "Light / Medium / Heavy" buttons: switch current armor to another weight of the same style (locks ignored; slots without a match are left unchanged).

  This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
