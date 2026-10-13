Restyle Helper v1.13.2 - Outfit station helper for The Elder Scrolls Online
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
  This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
