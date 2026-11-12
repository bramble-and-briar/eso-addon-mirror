# Changelog

Two things ship together: the addon in this repository, and the website it feeds at
https://itemshare.perdues.me ([ItemShare-Web](https://github.com/skperdue68/ItemShare-Web)).
The addon has version numbers; the website does not, so its history is grouped by what
it does rather than by release.

Newest first. The addon's version is the one in `ItemShare.txt`, and the same number is
in the addon's status messages.

## Addon

### 1.11.31
- A shared copy can no longer be posted to the guild store by dragging it. Posting was refused
  from the item's menu and from a click, but the listing is filed from a drop, and a drop never
  goes through the slot menu the lock watches - so dragging the row onto the sell tab got it
  through. The pickup itself is now refused while that tab is open, which stops it before
  anything is filed.
- Only the guild store's sell tab is affected, and only for an item nobody shared is dragged
  freely. Mail and trade drags are untouched, and so is every other window.

### 1.11.30
- A share now follows its copy into another place. Bank something that was shared from your bags,
  move a piece from a chest to the furnishing vault, and the row re-files itself where the item
  went instead of dropping off the list at the next pass because its old place held nothing.
  Standing offers do the same, and carry the count of the place the item moved to rather than
  falling to zero.
- The move only happens when exactly one place holds the item. Three swords split across two bags
  and the bank is not an item that moved, and guessing there would put a lock on a copy nobody
  shared, so the row stays where it was until you say otherwise. A place that cannot be read this
  session still proves nothing, so nothing moves out of a shut bank.

### 1.11.29
- A shared copy can now be banked and taken back out, put into a house storage chest or the
  furnishing vault and retrieved again, and placed as furniture and picked up. Every one of those
  moves was refused along with selling and destroying, which made the vaults unusable for exactly
  the items the share list is about. The lock is keyed to the place a copy was shared from, so the
  copy stays protected at both ends of the trip.
- The refusal line now reads "mailing, trading or storing it is all it will allow", so what it
  says is allowed matches what is.

### 1.11.28
- The share badge now appears at the ragpicker's sell and launder tabs, and in any other window
  that draws your own items. The badge used to be created by a list's row-setup callback, and the
  fence paints its rows through a repaint path that callback did not reach, so a shared item went
  unmarked in the window where it was about to be sold.
- Rows are now marked from `ZO_Inventory_BindSlot`, the client call that binds every item control
  to its bag item - its own comment lists "trade, mail, store, backpack, bank, crafting" - so the
  badge follows the item rather than a list, and a window the addon has never heard of needs no
  new hook.

### 1.11.27
- The line printed when a shared copy refuses an action no longer ends by sending you to
  `/ishare list` to right-click a row. It names the item and the place, says mailing or trading is
  all it will allow, and stops there: "Remove the share to use it", or "Stop always sharing it to
  use it" for a standing offer.

### 1.11.26
- Two keybinds, in the game's own list under Controls - Keybinds - **ItemShare**: **Toggle share**
  and **Toggle always share**. Both act on the item you hovered last, since a keybind has no row
  to click, and pressing the same key again turns the state back off.
- Turning one on turns the other off, which is what the menus already do: sharing a copy replaces
  a standing offer of the same item, and making an offer replaces the share.
- The addon now ships `Bindings.xml`. Without that file - named exactly that - the client does not
  load addon keybinds at all, however the Lua is written.

### 1.11.25
- A standing offer now holds the copy it is counted from. Marking "Always Share This Item" clears
  any share of the same item, so it used to be the one state where an item was on your list, was
  offered to everyone, and was protected by nothing: the offer survived the sale that the share
  would have refused. The offer is looked up in the place it was marked in and locked the same
  way, so only mailing and trading are left.
- Stopping the offer releases the copy, exactly as removing a share does, and `/ishare protect`
  still turns the whole lock off.
- The refusal message now says which of the two is holding the item - "shared from" or "always
  shared from" - because the two are released from the same row but not by the same click.

### 1.11.24
- The lock on a shared copy now covers everything the game can be asked to do with it, not just
  selling and deconstruction. While the share stands, the only things left are mailing it and
  trading it: destroying, deconstructing, refining, researching, enchanting, charging, repairing,
  using, equipping, laundering, banking, guild bank, guild store, the craft bag, quickslots and
  placing it as furniture are all refused.
- It is written as a list of what is still allowed rather than a list of what is not, so an
  action this version has never heard of is refused too instead of slipping through.
- Looking at the item still works - linking it in chat, previewing it, the map and quest entries,
  marking it as junk or locked, reporting it - and splitting a stack is allowed, because both
  halves carry the same item link and stay protected.
- The message names the item and the place it is shared from, and says the way out: remove the
  share in `/ishare list`.

### 1.11.23
- A share actually refuses to be sold now. The guard asked the game for
  `ZO_InventorySlot_GetBagAndIndex`, which is not a client function - the helper is
  `ZO_Inventory_GetBagAndIndex` - so every lookup came back empty, the guard decided nothing in
  front of it was shared, and a copy shared from your bags went to the merchant.
- Selling is refused at the click as well as at the menu. With a store open the primary action
  on a bag slot is the sale itself, decided inside a local function no addon can hook, so that
  action is stopped for a protected copy instead of relying only on the sell entry never being
  added.
- Deconstruction went through the same missing function, so its guard was passing everything
  through as well; it now reads the slot the way the client does.

### 1.11.22
- The in-game command list is printed from one function instead of two identical copies, so a
  command can no longer work but be missing from the help. `guildbank` was exactly that: it has
  always toggled guild bank sharing, and it was in the README and the ESOUI description but not
  in the help.
- The last line of the help was `Right-click an item - Share Reserve asks for a number to keep
  back`, which reads as nonsense on its own. It now names the menu items as they appear:
  `Add to Share`, `Always Share This Item`, `Share Reserve`.

### 1.11.21
- The `Rebuild complete. Updated: N, Removed: N, Unchanged: N` line is no longer printed, for
  either a rebuild or a sync, and neither is the duplicate copy of it that followed the save
  reminder. The automatic pass on login, bank access, bag changes and trades no longer
  announces `Shared items refreshed after <reason>` either.
- Both lines are kept in the source, commented out, so they can be turned back on without
  being rewritten. The `Use /ishare save or /reloadui` reminder after an explicit
  `/ishare rebuild` still prints.

### 1.11.20
- `/ishare scan` says "Scanning, one moment..." before it reads the house, so the pause on a
  full house is not a silent one, and finishes with "Scan complete: N unbound items found in
  <house>", naming bound, collectible and unreadable pieces on the same line when there are any.
- The one-line-per-piece output is gone, and with it the per-piece placed id and bound state.
  Bound, collectible and unreadable pieces are counted, not narrated.
- The bag index a placed piece falls back to is built once per scan instead of once per piece,
  which was most of the pause on a big house.
- `/ishare scan clear` (or `scan reset`) removes every share filed as `Placed (<house>)` for the
  house you are standing in, so a house scanned by mistake, or one that is no longer the storage
  house, can be taken back out of the file in one go. Other houses and bag rows are left alone.
- The house messages no longer say "nothing was scanned" when the command was a clear, and the
  documentation covers `/ishare scan` and `/ishare scan clear` together: one house kept as an
  item dump, scanned to offer what is in it, cleared when it should not be offered any more.

### 1.11.17
- Bound state is read again. `GetItemLinkBoundStatus` is not in the client's API, so the
  link check answered "not bound" for every link and bound furnishings were offered as if
  they were free to give away. The client's own `IsItemLinkBound` is now the test.
- `GetPlacedFurnitureLink` returns the item link *and* a collectible link. A collectible
  furnishing has no item link at all, and reading only the first return made every one of
  them look like a failed lookup; they are now counted as collectible, apart from pieces
  whose link genuinely could not be read.
- A piece with no link now says what the link call answered, so an empty result is
  distinguishable from a call that was never made or one that raised.

### 1.11.16
- `/ishare scan` reads placed furniture the way the housing API actually works: pieces are
  enumerated by id with `GetNextPlacedHousingFurnitureId`, and each id is asked for its own
  name, icon, furniture data id and link. The old code counted with a `GetPlacedFurnitureCount`
  pair that does not exist, then read the data id out of the icon's slot, so every piece was
  reported as unidentified with a data id of 0.
- The link comes from `GetPlacedFurnitureLink`, and a housing id prints through
  `Id64ToString` instead of showing as a raw 64-bit number.

### 1.11.15
- The addon now loads from a folder whose name is not exactly `ItemShare`, which is what a
  GitHub zip produces (`ItemShare-main`). The name check was an exact match, so those copies
  loaded the file, showed their version in the addon list, and then returned before
  registering any command or event - the addon appeared to be running but answered nothing.
- The commands are registered outside the load handler, and say so if the addon has not
  finished loading, so a failure during setup cannot leave a slash command that is silent.
- A load line now prints before any setup work, naming the folder it loaded from.
- If that setup throws, the handler reports the error in chat instead of aborting silently,
  which is what left the addon looking installed, current and mute.

### 1.11.14
- Removed code nothing calls: two helpers that were never used, the local character name
  built at load, and two saved fields written on every platform capture and guild refresh
  but never read. Saved files keep the old keys harmlessly; new files no longer create them.

### 1.11.13
- Every message goes through one function that posts a coloured `[ItemShare]` system
  message, the way GuildSync does. The old sink was gated on `/ishare debug` and called a
  `d()` helper this file no longer defines, so command output was being dropped instead of
  shown - a command that printed nothing really had printed nothing.
- The scan report uses the same function now, so a scan, a sync, a reserve change and the
  command list all appear in chat without any setting to find first.
- `/ishare debug` is gone, along with the saved `debugEnabled` flag it set: messages are
  always shown now, so the command had nothing left to control.

### 1.11.12
- `/ishare scan` now says why it did nothing: outside a house it reports that it only
  reads the house you are standing in, and in someone else's house it names the owner and
  refuses, since a piece there is not yours to offer. Both checks use the house id and
  the house owner, not the zone name.
- The scan report no longer depends on `/ishare debug` being on. It was being written
  through the debug-only message path, which is why a scan in a house could look like it
  had not run at all.

### 1.11.11
- A standing offer's number is rewritten within a few seconds of items leaving a bag.
  Selling, deconstructing, trading away, mailing or destroying the last copy now leaves
  0 behind instead of the count from the last sync or reload, and a completed trade is
  caught even when it moves a stack without a slot update.

### 1.11.10
- A standing offer belongs to the place it was marked in. Marking lockpicks in your bags
  leaves the stack in the bank unmarked, each place carries its own offer, count and
  reserve, and stopping one place leaves the others standing.
- Offers saved by an earlier version are moved onto a place key the first time the addon
  loads, so nothing has to be marked again.

### 1.11.9
- Marking an item for always share writes down the place it was marked in and how many
  that place holds at that moment, so the very first upload carries a number instead of
  waiting for the next sync to work one out.
- A standing offer now counts one place: the place it was marked in. Mark a
  Companion's Cuirass in your bags and it offers what that bag holds; hand the last one
  over and the next sync leaves the row at 0 offered instead of keeping the old number,
  and pick one up again and a sync brings it back to 1.
- The row stays at the place it was marked rather than following the item to whichever
  bag it turns up in, and a place that cannot be read keeps the number it had, so a shut
  bank never zeroes an offer.
- The website only shows a Request button while the marked place holds more than the
  reserve keeps back, so an offer with nothing behind it cannot be asked for. The demo
  seed carries both states - one offer with copies and one with none - so the difference
  is visible without a second player.

### 1.11.8
- Share badges now appear in the deconstruction and refinement panels and at the
  ragpicker, not only in the bags and the bank. Those lists belong to the crafting UI
  and were never hooked, so a shared piece looked unmarked exactly where it was about
  to be destroyed.
- The crafting lists are hooked as each panel opens, and a share toggled while one is
  open repaints there immediately.
- An item shared from a place now refuses to be sold or deconstructed from that same
  place, so an offer cannot be destroyed by accident while it is on the list. The guard
  is per location: a copy shared from the bags can still be sold out of the bank, and a
  copy nothing was shared from is untouched. Standing offers lock nothing.
- Selling is refused at the slot action the vendor builds, and deconstruction at the
  primary action the panel runs, so a shared piece cannot be added to the
  deconstruction selection. `/ishare protect` turns the guard off.

### 1.11.7
- Placed furniture is no longer inferred. The addon used to guess, on every sync, that
  a furnishing missing from a readable bag might be standing in whichever house you
  happened to be in, and it relabelled shares on that guess. That is gone.
- `/ishare scan` replaces it, and it is explicit: stand in your storage house and run
  it, and every non-bound furnishing placed in that house is shared as
  `Placed (<house>)`, one row per furnishing with the number of copies standing there.
- The scan is the record for that house, so a piece you picked up is taken back by the
  next scan, while every other house is left alone because nothing can read it.
- Bound furnishings are counted and skipped. Rows written by an older version under the
  old placed-furniture key are discarded at login and again whenever the addon rewrites
  the file, with a message on login saying to scan again, because there is no way any
  more to tell a piece that had been picked up from one that was never placed.

### 1.11.6
- `/ishare expire <days>` puts a stopwatch badge on every share that has been on offer
  that many days or more. It takes the share gift's place in the icon's corner instead
  of being drawn beside it, in the bags, the bank, house storage and the shared items
  window.
- The limit is one saved setting, read whenever a badge is painted, so it applies by
  itself after a reload and to whatever you open next. `/ishare expire 0` turns it off,
  and `/ishare expire` on its own reports the limit and how many shares are past it.
- Age comes from the date a share was first made, which survives re-sharing, moving and
  syncing: only removing a share and making it again restarts the clock. Nothing is
  hidden or removed by the limit.
- New badge art, `media/itemshare_expired.dds`, drawn by `tools/make_expired_badge.py`.

### 1.11.5
- Placed furnishings are tracked per house. A piece on display in two homes is two rows,
  one per house, and a sync inside one of them never renames the other.
- A row whose named house no longer holds the piece keeps its share and stops naming the
  house, rather than being dropped.

### 1.11.4
- The ESOUI page text - the short description and the full BBCode description - is kept
  in `Documentation/ESOUI.md`, so it is rewritten with the addon instead of drifting
  away from it.
- The two HTML documentation pages were removed: they described behaviour the addon no
  longer has.

### 1.11.3
- Home storage is recorded under the chest's name, so a row reads `Materials` instead of
  `House Storage 8`. Renaming a chest relabels its shares on the next rebuild.
- The `/ishare sync` summary says what its kept-furnishings count means.

### 1.11.2
- The reserve-only badge generator (`tools/make_reserve_only_badge.py`) is kept in the
  repository, so that badge can be redrawn rather than hunted for.

### 1.11.1
- All five guild slots are written for each character, empty ones included, so a guild
  that has gone is visible in the file itself. Shares and reserves filed against a guild
  you have left are removed on login.

### 1.11.0
- The file records the platform and megaserver it was written on, and the site matches on
  them: a file written on the North American megaserver is only offered to readers on the
  same platform and megaserver.

### 1.10.7
- A bound item is not offered a share reserve, because a reserve on it could never count.
  A reserve left on an item that has since become bound can still be cleared.

### 1.10.6
- Share reserves are kept per storage location: the stack in your bank and the stack in
  your bags hold their own numbers.

### 1.10.5
- Each storage location keeps its own count, so a share in your bags and a share in the
  bank stay two rows, each naming its own place.

### 1.10.4
- The share list counts every stack of an item rather than only the marked one, names
  every place the count came from, and reads its numbers from the saved shares instead of
  measuring the bags again - which is why the bank's row survives with the bank shut.

### 1.10.3
- Sharing and always sharing became one choice per item, and right-clicking a list row
  cycles it: not shared, shared, always shared, and back.

### 1.10.2
- The share badge was redrawn, and a reserve was given its own corner instead of having
  to be drawn into the same badge.

### 1.10.1
- The compatibility layer for older saved files was dropped so stored data starts over,
  and a reserve set on an item that was never shared is now listed.

### 1.10.0
- Guilds are stored once by id rather than copied onto every share, and counts, reserves
  and location keys are derived when they are needed instead of being stored.

### 1.9.0
- The website moved to its own repository; this one is the addon only.
- Reserves are shown both where they are set and where they are seen, and a reserve that
  leaves nothing to share is badged as such.
- The saved-variables file is found from the home directory, and removing an item from
  the site's basket no longer crashes.
- The Google Sheets export was removed.

### 1.8.8
- Icons are found for set items, standing offers are listed in the window, and reserves
  are badged.

### 1.8.7
- The window repaints after an always-share changes, the list badge is set from the share
  on every refresh, and the badge tooltip no longer flashes.

### 1.8.6
- Share reserve: only the quantity held above the reserve is offered.

### 1.8.5
- Bound items are refused when they are marked, and standing offers are badged in the bag.

### 1.8.4
- No addon changes; this release carried the website's request work - holds, history,
  emails and list polish.

### 1.8.3
- The shared badge was redrawn and put on the item icon, and a Scroll collision was fixed.

### 1.8.2
- Mostly website: icons are no longer lost, sign-in holds, pages share the site's shell,
  open pages update live, and the list gains filters and tabs.

### 1.8.1
- Guilds are stamped onto shares that predate guild capture, and a share with no item link
  stays visible to its owner.

### 1.8.0
- Items that are not in your bags can be offered, which is what standing offers are for.

### 1.7.0
- A share names the exact place it is stored, not just the container.

### 1.6.0
- Shares are refreshed from your live bags on login and when a bank is accessed.

### 1.5.0
- Every item field the game client exposes is captured, so the site has the whole item.

### 1.4.0
- Item icons are captured natively and items are browsed by type; the site shows the item
  detail it already stores.

### 1.3.0
- Uploaded files feed a guild-aware database, several ESO accounts can sit under one
  login, and sign-in covers Discord and Google.

### 1.2.7
- The file name the upload instructions ask for was corrected, `/ishare debug` was fixed,
  and dead code was removed.

### 1.2.6
- Early saved-variables housekeeping; the leftover `SampleData` folder was removed from
  the download.

### 1.2.5
- Search for the same item in a different bag or location when you sync or save, and sync
  automatically when saving.
- A line in the shared-items window saying you can right-click to add or remove an item
  from sharing.

### 1.2.3
- Corrected an issue with an additional anchor listing that stopped the list window
  displaying properly.
- Guild bank sharing turned off while it was refined, behind the toggle it now uses.
- Row striping and active-row highlighting in the list window for readability.
- The shared item icon was changed to represent a shared item better.

### 1.2.2
- Found an issue with the sample data, corrected it, and repackaged.

### 1.2.1
- Added sample data, and a link to a template Google Sheet for easier setup.

## Companion website (ItemShare-Web)

The site is what turns the saved file into something other people can use, and it is
where most of the work has gone since it became a repository of its own. It has no
version numbers, so this is grouped by what it does.

- **Accounts.** Sign in with Discord, with Google, or with an email address and a
  password. One login can hold several ESO accounts, and the list can be browsed as any
  of them, with requests made on behalf of that character. Account controls sit behind
  the avatar, and a password can be set through the request flow.
- **Browsing without uploading.** Visitors can read what is shared before they sign in,
  and a new sign-in can look around before uploading a file. A demo mode shows the site
  with sample offers.
- **The list.** Items carry the game's own quality colours and real icons, and can be
  filtered live, sorted by column, and read with a tooltip that says what each item is
  and where it is stored.
- **Requests.** Ask for one copy or a stack; a basket collects what you are asking for.
  A request is held on a clock so two people cannot be promised the same copy, and the
  number held is counted rather than hidden. Both sides keep a history, an owner answers
  a row at a time, and an answer can be reopened. Guests can ask without signing in and
  are given a password afterwards.
- **Mail.** The owner is mailed when something is asked for, and the asker when it is
  answered; both name the storage location the copy is in. Mail can be rendered to a file
  for inspection, pointed at a single address, or turned off.
- **Data.** Uploaded files are imported into a guild-aware database: guilds, ESO accounts
  and per-location reserves are read from the file's own schema. Item icons are only
  fetched from UESP when the database is missing one, with a backfill command and a retry
  timer for the rest.
- **Holding it up.** A request simulator for testing without a second player, a
  one-command check for the email setup, a reset for a sign-in that is stuck, and test
  scripts for grouping, sort order, reserves, guild codes, server identity and demo mode.
