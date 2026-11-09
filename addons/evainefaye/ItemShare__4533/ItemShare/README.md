# ItemShare

An ESO addon that marks tradeable items as shareable and writes them to `ItemShareSavedVars`, which the ItemShare website reads. This repository holds the addon only; the website is a separate project.

Requires LibCustomMenu

The upload site that turns your saved file into a shareable list is a separate
project: https://github.com/skperdue68/ItemShare-Web. Nothing in this repository
needs it; the addon only writes ItemShareSavedVars.lua.

`tools/make_reserve_only_badge.py` redraws `media/itemshare_reserve_only.dds`, the badge for a reserve left on an item that is not shared at all. It needs Python 3 and Pillow; run it from the repository root with `python3 tools/make_reserve_only_badge.py`. The game never loads it.

Download and extract to your ESO AddOns Directory
Ensure Add on is loaded at startup


You can use commands 

/ishare or /itemshare to control functionality

/ishare list - opens or closes the shared items window. Right-click a row there to cycle it: share it, make it a standing offer, or stop offering it.
/ishare reset (or clear) - clears every share and every standing offer.
/ishare sync (or cleanup, reconcile) - recounts your shares against the bags that are readable now and drops the ones you no longer have. Standing offers are left alone, because an offer is meant to outlive the copy. Its summary's `Kept furnishings` count is shares of furniture that the readable bags no longer held: they are kept rather than deleted, because a furnishing may be placed in a house.
/ishare rebuild - rewrites every share from your current bags; it also runs on login and when a bank opens or closes.
/ishare save - rebuilds and then offers to reload the UI, which is what writes the file to disk.
/ishare debug - turns the addon's own status messages on or off.
/ishare guilds - lists the guilds captured for the current character.
/ishare always - lists the items you always offer, whether or not a copy is in your bags.
/ishare noalways <part of the name> - stops always sharing one item.
/ishare reserve <amount> <part of the name> - keeps that many back and offers the rest.
/ishare noreserve <part of the name> - shares the whole stack again.
/ishare reserves - lists every item with a reserve, and what it is offering.
/ishare guildbank - toggles sharing from the guild bank.
/ishare server - shows the platform and megaserver this file is recorded for.

Guild bank shares and reserves are filed against the guild's id, and the file records all five guild slots for the character, writing `0` in every slot with no guild in it. That is what makes a dropped guild visible in the file itself, and on login the addon removes any share or reserve filed against a guild you are no longer in - those banks cannot be opened again, so nothing else would ever clear them. A guild's name is forgotten once no character on the account is in it any more. `/ishare guilds` shows all five slots, empty ones included.

The window and the item menus cover the same ground without typing:

- Right-click an item in a bag, the bank, house storage or the furnishing vault: **Add to Share**, **Remove from Shared List**, **Always Share This Item**, **Stop Always Sharing**, **Share Reserve** (asks for a number of at least 1) and, when a reserve is set, **Share Reserve: Keep N Back...** and **Clear Share Reserve**.
- In `/ishare list`, right-click a row to walk it through the three states and back: not shared, shared, always shared.

You may add items to the shared list from Inventory, House Storage, Your Bank, or the Furnishings Vault, just right click the item and select "Add to Share" or "Remove from Share" as you desire.

Home storage is recorded under the name of the chest, not its number: ESO lets you rename each of the ten storage chests, and the addon reads that name, falling back to the chest's own collectible name and then to `House Storage N`. A row therefore says `Materials` or `Gear I might keep` instead of `House Storage 8`, and the name is saved with the share, so it still reads that way while you are away from home. Rename a chest and the next rebuild relabels its shares; two chests given the same name stay separate rows, because the slot is recorded as well.

Items that are bound to you cannot be shared, and neither can items the game only lets you hand to your group for a short while (bind on pickup, still tradeable). The addon refuses both with a message instead of adding them, and it checks again when an item is re-added from the share list window, because an item can become bound after it was filed.

Right-click an item and choose "Always Share This Item" to make it a standing offer: it stays offered even when you no longer have a copy, and `/ishare sync` never removes it. A normally shared item is different - it is only offered while it is in a bag the addon can read, and it disappears from the list once it is gone.

The badge on an item icon shows which of the two it is. A green gift means it is shared right now; the same gift in gold with a closed ring means it is always shared, and that gold badge stays on the item even when you have none in your bags. A small amber padlock tag is added to either badge when the item has a share reserve. An item that has a reserve but is not shared at all shows the padlock on its own, so a reserve left behind on something you stopped sharing is still visible - and can be cleared - instead of being forgotten. Hovering the badge says which state it is in and, when there is a reserve, how much is being kept back.

`/ishare list` shows what is on offer right now: every share with something above its reserve, plus any standing offer that has a copy in your bags even if that copy was never marked by hand. A row that offers nothing is not listed at all, a row with a reserve says `keep N` beside its location, and right-clicking a row steps it on to the next state: not shared, shared, always shared, and back to not shared. There is one row per item per place: stacks of the same thing in one bag are added together - two stacks of 200 soul gems in the bank are 400 on offer - but a share in your bags and a share in the bank stay two rows, each naming its own place and counting only what is there, so the row you want to take back is the row you right-click. The window reads the counts saved with your shares rather than measuring the bags again, which is why the bank's row is still there while the bank is shut.

### Share reserve: share only what you have above a number

If you want to keep some of a stack for yourself, give it a share reserve. The addon then offers only the quantity above that number, and the share list recalculates whenever your inventory changes:

```
/itemshare reserve 12 soul gem     keep 12, so 20 held shares 8
/itemshare reserve 12 soul gem     used 15 later, so 3 are shared
/itemshare reserve 12 soul gem     used down to 10 later, so nothing is shared
/itemshare reserves               list everything that has a reserve
/itemshare noreserve soul gem     share the whole stack again
```

The same reserve can be set from the item's right-click menu: **Share Reserve** opens a number box with the item already chosen, refuses anything that is not a whole number of at least 1, and offers **Clear Reserve** once something is kept back.

The menu only offers a reserve on an item that can actually be shared: a bound item has no reserve option, because a reserve on it would never count. An old reserve left on an item that has since become bound can still be cleared from the same menu.

A reserve belongs to the item **in one place**. Set 50 on the soul gems in your bank and the stack in your bags keeps its own number, so the bank can hold some back while you offer everything on you. The right-click menu and the number box always speak for the bag you opened them on, and each row in `/ishare list` subtracts only its own place's reserve - the bank row and the bag row never share one number. `/itemshare reserve` sets the reserve for the place the item is shared from when that is a single place, and tells you to use the right-click menu when it is in several. A reserve set before places existed still applies everywhere the item is, until you set one in a bag.

The name only has to be part of the item name, and it is refused if it matches more than one shared item. A share that is entirely inside its reserve stays marked at zero, so it comes back on its own when you acquire more - nothing has to be re-marked. Items with no reserve behave exactly as before. A reserve covers standing offers too: the list only shows one while you hold more than the reserve, and the offer comes back by itself once you do.

The file also records which platform and which megaserver the account plays on; `/ishare server` shows what was captured. They are written once for the whole account rather than onto each share, because that is what they describe, and the ItemShare site matches on them: a file written on the North American megaserver is only ever offered to readers on the same platform and megaserver, because nothing trades between them. The megaserver's own name is kept as the game reports it for display, and the site matches on the short form - `na`, `eu` or `pts` - since the game's name is translated into the client's language.

Once Everything is as you want it, save the file by doing /ishare save or typing /reloadui

Then open the ItemShare site and upload the file there. The item list, the requests and everything that becomes of them happen on the site.
