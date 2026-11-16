# Guilds Bounty

An ESO addon that marks tradeable items as shareable and writes them to `GuildsBounty.lua' in your SavedVariables Directory, which the Guilds Bounty website reads. This repository holds the addon only; the website is a separate project.

Requires LibCustomMenu

The upload site that turns your saved file into a shareable list is a separate
project: https://github.com/skperdue68/GuildsBounty-Web. Nothing in this repository
needs it; the addon only writes GuildsBountySavedVars.lua.

Download and extract to your ESO AddOns Directory, so that the folder is `GuildsBounty` with
`GuildsBounty.txt` inside it. 
Ensure Add on is loaded at startup


You can use commands 

/gbounty or /guildsbounty to control functionality - both are the same command, and the
examples below use the short one.

/gbounty list - opens or closes the shared items window. Right-click a row there to cycle it: share it, make it a standing offer, or stop offering it.
/gbounty reset (or clear) - clears every share and every standing offer.
/gbounty sync (or cleanup, reconcile) - recounts your shares against the bags that are readable now and drops the ones you no longer have. Standing offers are left alone, because an offer is meant to outlive the copy. Shares filed by `/gbounty scan` are left alone too: they stand in a house, and no bag can confirm or deny them.
/gbounty rebuild - rewrites every share from your current bags; it also runs at login (a reload says so, instead of pretending to be a login), on a zone change, when a storage closes (the bank, a house chest, the furnishing vault, and the guild bank only while guild bank sharing is on), and at logout. Every read opens by naming the bags it can see.
/gbounty scan - in a house you own, shares every unbound furnishing placed there as `Placed (<house>)` and takes back the ones no longer standing there. `/gbounty scan house` means the same thing.
/gbounty autoscan [on|off] - turns the reads that happen on their own off or on: at login (a reload is named as one), on a zone change, when a storage closes, and at logout. With them off, `/gbounty sync` and `/gbounty rebuild` are the only things that read your bags.
/gbounty scan clear - in a house you own, clears every share filed as `Placed (<house>)` for that house.
/gbounty protect - turns off (or back on) the lock on a copy shared from the place you are acting in. With it on, that copy can be mailed or traded, or put into storage and taken back out, and nothing else.
/gbounty save - rebuilds and then offers to reload the UI, which is what writes the file to disk.
/gbounty guilds - lists the guilds captured for the current character.
/gbounty always - lists the items you always offer, whether or not a copy is in your bags.
/gbounty noalways <part of the name> - stops always sharing one item.
/gbounty reserve <amount> <part of the name> - keeps that many back and offers the rest.
/gbounty noreserve <part of the name> - shares the whole stack again.
/gbounty reserves - lists every item with a reserve, and what it is offering.
/gbounty expire <days> - marks shares that have been on offer that many days or more with a stopwatch badge; `0` turns it off.
/gbounty guildbank - toggles sharing from the guild bank.
/gbounty server - shows the platform and megaserver this file is recorded for.

Guild bank shares and reserves are filed against the guild's id, and the file records all five guild slots for the character, writing `0` in every slot with no guild in it. That is what makes a dropped guild visible in the file itself, and on login the addon removes any share or reserve filed against a guild you are no longer in - those banks cannot be opened again, so nothing else would ever clear them. A guild's name is forgotten once no character on the account is in it any more. `/gbounty guilds` shows all five slots, empty ones included.

The window and the item menus cover the same ground without typing:

- Right-click an item in a bag, the bank, house storage or the furnishing vault: **Add to Share**, **Remove from Shared List**, **Always Share This Item**, **Stop Always Sharing**, **Share Reserve** (asks for a number of at least 1) and, when a reserve is set, **Share Reserve: Keep N Back...** and **Clear Share Reserve**.
- In `/gbounty list`, right-click a row to walk it through the three states and back: not shared, shared, always shared.

You may add items to the shared list from Inventory, House Storage, Your Bank, or the Furnishings Vault, just right click the item and select "Add to Share" or "Remove from Share" as you desire.

Two keybinds do the same two things without opening a menu. They are in the game's own keybind list - **ESC, Controls, Keybinds**, in the **Guilds Bounty** category - and both act on the item you hovered last, so hover it first. **Toggle share** shares that item from the place you are looking at, and pressing it again takes the share back off. **Toggle always share** makes it a standing offer for that place, and pressing it again stops the offer. Turning one on turns the other off, which is what the menu already does: sharing a copy replaces a standing offer of the same item, and making an offer replaces the share.

Home storage and the furnishing vault are labelled with the nickname you gave them: a row reads `Housing Storage (Materials)` or `Furnishing Vault (Lumber)`, and the nickname is saved with the share, so it still reads that way while you are away from home. A chest you have not renamed reads `Housing Storage` with no brackets, and the vault never shows the zone you happened to stand in. Rename a chest and the next rebuild relabels its shares; two chests given the same name stay separate rows, because the chest itself is recorded as well.

Nothing in a house is read from outside it. A chest and the vault only hold anything while you are standing in a house, and the game can keep reporting the last size it knew for them once you leave, so a pass run anywhere else leaves those rows alone rather than deciding their items are gone. A share filed in a chest is also only moved to another place when that chest has been read and the item genuinely is not in it.

Furnishings you set aside for sharing live in a house, not in a bag, so they are filed by hand rather than inferred. Keep one house as your dump and put the furnishings you are willing to give away in it.

`/gbounty scan` - stand in that house (it has to be one you own) and run it. Every furnishing placed there is read, and every piece that is not bound to you is offered as `Placed (<house>)`, one row per furnishing carrying the number of copies standing there. Bound furnishings are counted and skipped, and so are collectible furnishings: they are not items, so there is no link to offer and nothing to hand over. Running the scan again is the record for that house - a piece you picked up is taken back and one carried in is added. It says only what it needs to: a line before it starts, and a line when it finishes with how many unbound items it found and what it skipped. Only the house you are standing in can be read, so a scan never touches another house, and furnishings in the vault or in a bag are shared the usual way, with no scan needed.

`/gbounty scan clear` - stand in the same house and run it to take all of those rows back out of the file at once, which is what you want for a house you scanned by mistake or have stopped using for sharing. It removes only the rows filed as `Placed (<house>)` for that house: shares filed under another house, or under a bag, are left alone. It reports how many were cleared, and `/gbounty save` or `/reloadui` writes the change to disk.

Rows an older version saved under its own placed-furniture label are discarded, at login and again whenever the addon rewrites the file, so nothing stale is written back out.

Items that are bound to you cannot be shared, and neither can items the game only lets you hand to your group for a short while (bind on pickup, still tradeable). The addon refuses both with a message instead of adding them, and it checks again when an item is re-added from the share list window, because an item can become bound after it was filed.

Right-click an item and choose "Always Share This Item" to make it a standing offer: it stays offered even when you no longer have a copy, and `/gbounty sync` never removes it. The number beside a standing offer is the count in the place it was marked in: mark the last Companion's Cuirass in your bags, hand it over and sync, and the row says 0 offered - and the site shows no Request button - until one is back in that bag and you sync again. The count keeps up on its own: trade away or mail the last copy - selling and deconstructing it are refused while the offer stands - and it is rewritten a few seconds later, without a reload or a sync. A standing offer belongs to the place it was marked in: mark a stack of lockpicks in your bags and the stack in your bank stays unmarked, and each place offers and counts only what it holds. That place is also the one it locks, so an offer is not a way to hand something over by accident. A normally shared item is different - it is only offered while it is in a bag the addon can read, and it disappears from the list once it is gone.

The badge on an item icon shows which of the two it is. A green gift means it is shared right now; the same gift in gold with a closed ring means it is always shared, and that gold badge stays on the item even when you have none in your bags. A small amber padlock tag is added to either badge when the item has a share reserve. An item that has a reserve but is not shared at all shows the padlock on its own, so a reserve left behind on something you stopped sharing is still visible - and can be cleared - instead of being forgotten. Hovering the badge says which state it is in and, when there is a reserve, how much is being kept back. The badge is attached to the item control the moment the game binds a bag item to it, so it appears wherever your items are drawn: your bags, the bank, house storage, the furnishing vault, the deconstruction and refinement panels, a merchant's sell list, the ragpicker's sell and launder tabs, a mail attachment and a trade - and in a window the addon has never heard of, because there is no list of windows to add it to. The ragpicker used to be the exception: it paints its rows through a repaint path the wrapped list callback did not reach, so a shared piece went unmarked exactly where it was about to be sold.

An item shared from a place is locked while the share stands. From that place it can be mailed or traded, and it can be stored, and nothing else: not sold, destroyed, deconstructed, refined, researched, enchanted, used, equipped, laundered, listed in a guild store, put on a quickslot or moved into a craft bag. Storage means the bank, a house storage chest and the furnishing vault, in both directions, plus placing a shared furnishing in a house and picking it up again - the lock is keyed to the place a copy was shared from, so it stays protected while it sits somewhere else. The lock is written as a list of what is still allowed, so anything the game adds later is refused too rather than slipping through. A share is filed against the place it was made from, and it travels with the copy: empty that place and the share re-files itself where the item now is at the next read of your bags - at login, on a zone change, when you open a storage, or when you run `/gbounty sync` - as long as exactly one place holds it. When the same item sits in two places the addon will not guess, and the row stays where it was. A copy in a place nothing was shared from is not locked at all. Standing offers lock the place they were marked in, because that place is what they count, and an offer moves with its copy the same way a share does. Looking at a locked item still works - linking it in chat, previewing it, the map and quest entries, marking it as junk or locked, reporting it, and splitting a stack, which keeps both halves shared. Removing the share - or stopping the standing offer - is the only way to get that copy back: right-click the row in `/gbounty list`, or use the item's own menu. `/gbounty protect` turns the whole lock off if it ever gets in the way.

`/gbounty expire 30` puts a stopwatch badge on every share that has been on offer for 30 days or more. It is the same size as the other badges and sits in the same corner, taking the place of the share gift rather than being added beside it, so an item that has quietly become clutter is obvious in your bags, the bank, house storage and the window. The number is one setting for the whole file and is saved with your shares, so it keeps applying after a reload and to anything you look at next; `/gbounty expire 0` clears it. An item's clock starts when it was first shared. It belongs to the item rather than to a place: sharing the same thing from a second bag, moving a copy between the bank and a house chest, re-sharing it or syncing all leave the date alone, because the same sword on offer twice is one thing on offer. The date is only dropped once the item is offered nowhere at all - no share in any place and no standing offer - and sharing it again after that starts a new clock. Nothing is hidden or removed by the limit - the stopwatch is a nudge to sell, not a rule. Hovering it says how long the share has been on offer.

`/gbounty list` shows what is on offer right now: every share with something above its reserve, plus any standing offer that has a copy in your bags even if that copy was never marked by hand. A row that offers nothing is not listed at all, a row with a reserve says `keep N` beside its location, and right-clicking a row steps it on to the next state: not shared, shared, always shared, and back to not shared. There is one row per item per place: stacks of the same thing in one bag are added together - two stacks of 200 soul gems in the bank are 400 on offer - but a share in your bags and a share in the bank stay two rows, each naming its own place and counting only what is there, so the row you want to take back is the row you right-click. The window reads the counts saved with your shares rather than measuring the bags again, which is why the bank's row is still there while the bank is shut.

### Share reserve: share only what you have above a number

If you want to keep some of a stack for yourself, give it a share reserve. The addon then offers only the quantity above that number, and the share list recalculates whenever your inventory changes:

```
/guildsbounty reserve 12 soul gem     keep 12, so 20 held shares 8
/guildsbounty reserve 12 soul gem     used 15 later, so 3 are shared
/guildsbounty reserve 12 soul gem     used down to 10 later, so nothing is shared
/guildsbounty reserves               list everything that has a reserve
/guildsbounty noreserve soul gem     share the whole stack again
```

The same reserve can be set from the item's right-click menu: **Share Reserve** opens a number box with the item already chosen, refuses anything that is not a whole number of at least 1, and offers **Clear Reserve** once something is kept back.

The menu only offers a reserve on an item that can actually be shared: a bound item has no reserve option, because a reserve on it would never count. An old reserve left on an item that has since become bound can still be cleared from the same menu.

A reserve belongs to the item **in one place**. Set 50 on the soul gems in your bank and the stack in your bags keeps its own number, so the bank can hold some back while you offer everything on you. The right-click menu and the number box always speak for the bag you opened them on, and each row in `/gbounty list` subtracts only its own place's reserve - the bank row and the bag row never share one number. `/guildsbounty reserve` sets the reserve for the place the item is shared from when that is a single place, and tells you to use the right-click menu when it is in several. A reserve set before places existed still applies everywhere the item is, until you set one in a bag.

The name only has to be part of the item name, and it is refused if it matches more than one shared item. A share that is entirely inside its reserve stays marked at zero, so it comes back on its own when you acquire more - nothing has to be re-marked. Items with no reserve behave exactly as before. A reserve covers standing offers too: the list only shows one while you hold more than the reserve, and the offer comes back by itself once you do.

The file also records which platform and which megaserver the account plays on; `/gbounty server` shows what was captured. They are written once for the whole account rather than onto each share, because that is what they describe, and the Guilds Bounty site matches on them: a file written on the North American megaserver is only ever offered to readers on the same platform and megaserver, because nothing trades between them. The megaserver's own name is kept as the game reports it for display, and the site matches on the short form - `na`, `eu` or `pts` - since the game's name is translated into the client's language.

Once Everything is as you want it, save the file by doing /gbounty save or typing /reloadui

Then open the Guilds Bounty site and upload the file there. The item list, the requests and everything that becomes of them happen on the site.
