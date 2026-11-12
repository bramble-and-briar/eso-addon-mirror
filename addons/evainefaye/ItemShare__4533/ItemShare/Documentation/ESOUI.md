# ESOUI addon page

The addon's page on ESOUI carries two pieces of text: a short description and a full
description written in ESOUI's BBCode. Both are kept here so the page can be rewritten
when the addon changes, instead of drifting away from it. The full description
describes behaviour, so a change to a command, a badge, a location or the website
belongs here too.

The site the addon feeds is https://itemshare.perdues.me; its source is
https://github.com/skperdue68/ItemShare-Web.

## Short description

Mark items in your bags, bank, house storage or furnishing vault as shareable, then
upload the file the addon writes to itemshare.perdues.me so guild members can see what
you are offering and request it.

## Full description

Uses `[b]`, `[i]`, `[size]`, `[color=#hex]`, `[url]`, `[list]` with `[*]`, `[code]` and
`[hr]` only, all of which ESOUI renders. Paste the block as it stands into the
description field.

```bbcode
[b][size=5][color=#D4AF37]ItemShare[/color][/size][/b]
[color=#9AA0A6][i]Track what you are willing to give away. Let the website handle who asks for it.[/i][/color]

[hr]

ItemShare keeps track of the tradeable items you are willing to hand out, so you do not have to leave things in a guild bank, post lists in chat, or remember what you promised whom. You mark an item with one right-click, the addon records it in a saved file, and you upload that file to [url=https://itemshare.perdues.me]itemshare.perdues.me[/url], where other players browse what is on offer and request what they need.

[color=#E3B341][b]Requires LibCustomMenu.[/b][/color] Please install it first. The right-click entries that do all the work come from that library, and without it the addon has very little it can do.

[hr]

[b][size=4][color=#D4AF37]How it works[/color][/size][/b]

[list]
[*]Right-click an item in your bags, your bank, a house storage chest or the furnishing vault and choose [b]Add to Share[/b].
[*]The item goes into [b]ItemShareSavedVars[/b], an account-wide saved-variables file, along with its link, name, quality, trait, type, stack count, where it is, the character it came from and that character's guilds.
[*]The addon keeps that file current by itself. It rewrites your shares a few seconds after a character loads and whenever a bank opens or closes, and it drops shares it can prove are gone from a bag it is able to read.
[*]When the list is the way you want it, [b]/ishare save[/b] (or /reloadui) writes the file to disk.
[*]Upload the file at [url=https://itemshare.perdues.me]itemshare.perdues.me[/url]. Browsing, requests and everything that follows a request happen on the site. The addon does not handle requests in game.
[/list]

[b][size=4][color=#D4AF37]What can be shared, and from where[/color][/size][/b]

[list]
[*][b]Inventory[/b] - recorded per character, so each character keeps its own rows.
[*][b]Bank[/b] and [b]Craft Bag[/b].
[*][b]House storage[/b] - recorded under the name of the chest, not its number.
[*][b]Furnishing vault[/b].
[*][b]Guild bank[/b] - off by default. /ishare guildbank toggles it.
[/list]

[b]House storage by name.[/b] ESO lets you rename each of the ten storage chests, so a row reads [i]Materials[/i] instead of [i]House Storage 8[/i]. The chest's own name is used when you have not renamed it, and the slot number only when neither is available. Rename a chest and the next rebuild relabels its shares, and two chests given the same name stay separate rows.

[b]Furnishings for sharing live in your storage house.[/b] Keep one house as your dump and put the furnishings you are willing to give away in it.

[b]/ishare scan[/b] - stand in that house (it has to be one you own) and run it. Every furnishing placed there is read, and every piece that is not bound to you is offered as [i]Placed (<house>)[/i], one row per furnishing carrying the number of copies standing there. Bound furnishings are counted and skipped, and so are collectible furnishings: they are not items, so there is no link to offer. Running the scan again is the record for that house - a piece you picked up is taken back and one carried in is added. It says a line before it starts and a line when it finishes with how many unbound items it found and what it skipped. Only the house you are standing in can be read, so no other house is ever changed, and furnishings in the vault or in a bag are shared the usual way.

[b]/ishare scan clear[/b] - stand in the same house and run it to remove every row filed as [i]Placed (<house>)[/i] for that house at once, which is what you want for a house scanned by mistake or one you have stopped using for sharing. Shares filed under another house, or under a bag, are left alone, and the run reports how many were cleared. [b]/ishare save[/b] or a reload writes the change to disk.

[b]Bound items are refused[/b], and so are items the game only lets you hand to your group for a short while (bind on pickup, still tradeable). The addon says so instead of adding them, and checks again when an item is re-added from the shared window, because an item can become bound after it was filed.

[b][size=4][color=#D4AF37]The shared items window[/color][/size][/b]

[b]/ishare list[/b] opens a movable, resizable window that remembers its position and size.

[list]
[*]One row per item per place. Stacks of the same thing in one bag are added together, so two stacks of 200 soul gems in the bank are 400 on offer, but a share in your bags and a share in the bank stay two rows, each naming its own place and counting only what is there.
[*]Left-click an item name for its full tooltip.
[*]Right-click a row to step it on: not shared, shared, always shared, and back to not shared.
[*]A row that offers nothing is not listed at all, and a row with a reserve says [i]keep N[/i] beside its location.
[*]The window reads the counts saved with your shares rather than measuring the bags again, which is why the bank's row is still there while the bank is shut.
[/list]

[b][size=4][color=#D4AF37]Keybinds[/color][/size][/b]

Two keybinds do the same two things as the menu, on the item you hovered last: [b]Toggle share[/b] and [b]Toggle always share[/b]. Both are listed under ESC - Controls - Keybinds, in the [b]ItemShare[/b] category. Hover an item and press the key to share it or make it a standing offer; press the same key again to take that back off. Turning one on turns the other off, exactly as the menu does.

[b][size=4][color=#D4AF37]Standing offers[/color][/size][/b]

[color=#E3B341][b]Always Share This Item[/b][/color] on an item's menu makes it a standing offer. It stays offered even when you hold no copy, and [b]/ishare sync[/b] never removes it. The number beside it is the count in the place you marked it: mark a Companion's Cuirass in your bags, hand the last one over and run [b]/ishare sync[/b], and its row reads 0 offered - the site offers no Request button for it - until one is back in that bag and you sync again, when the row reads 1. The count keeps up on its own: trade away or mail the last copy - selling and deconstructing it are refused while the offer stands - and it is rewritten a few seconds later, with no reload and no sync. A standing offer belongs to the place it was marked in: mark a stack of lockpicks in your bags and the stack in your bank stays unmarked, and each place offers and counts only what it holds. That place is the one it locks too, so an offer is not a way to hand something over by accident. A normally shared item is different: it is offered only while it is in a bag the addon can read, and it disappears from the list once it is gone.

[b]/ishare always[/b] lists your standing offers, and [b]/ishare noalways <part of the name>[/b] ends one.

[b][size=4][color=#D4AF37]Share reserve: offer only what you have above a number[/color][/size][/b]

Keep part of a stack for yourself and offer the rest:

[code]/ishare reserve 12 soul gem    keep 12, so holding 20 shares 8
/ishare reserve 12 soul gem    used 15 later, so 3 are shared
/ishare reserve 12 soul gem    used down to 10 later, so nothing is shared
/ishare noreserve soul gem     share the whole stack again[/code]

The same thing is on the item's right-click menu as [b]Share Reserve[/b], which asks for a number of at least 1. A reserve belongs to the item in one place, so the stack in your bank and the stack in your bags keep their own numbers. A share entirely inside its reserve stays marked at zero and comes back by itself when you acquire more, so nothing has to be re-marked. The name only has to be part of the item name, and is refused if it matches more than one shared item.

[b][size=4][color=#D4AF37]Badges[/color][/size][/b]

[list]
[*]A [color=#5BA85B][b]green gift[/b][/color] on an item icon means it is shared right now.
[*]The same gift in [color=#D4AF37][b]gold[/b][/color], with a closed ring, means it is always shared, and the badge stays on the item even when you hold none.
[*]A small [color=#E3B341][b]amber padlock[/b][/color] tag is added to either badge when the item has a share reserve. An item with a reserve that is not shared at all shows the padlock on its own, so a reserve left behind can be seen and cleared instead of forgotten.
[*]A [color=#D9534F][b]red-ringed stopwatch[/b][/color] takes the gift's place when a share has been on offer longer than the limit set with [b]/ishare expire[/b], so an offer that has quietly become clutter is obvious at a glance.
[*]The badge is attached when the game binds a bag item to an item control, so it appears wherever your items are drawn: your bags, the bank, house storage, the furnishing vault, the deconstruction and refinement panels, a merchant's sell list, the ragpicker's sell and launder tabs, a mail attachment and a trade, and in windows the addon has never heard of - there is no list of windows to keep up to date. The ragpicker used to be the exception, because it paints its rows through a repaint path the addon's wrapped list callback did not reach.
[*]Hovering a badge says which state the item is in and, with a reserve, how much is being kept back.
[/list]

[b][size=4][color=#D4AF37]Old shares: the expire stopwatch[/color][/size][/b]

Things that sit in the list for months stop being offers worth making, and nothing on the icon used to say so. Set a limit once and the addon marks them:

[code]/ishare expire 30    shares 30 days or older show the stopwatch
/ishare expire 0     turn the marking off[/code]

The stopwatch is the same size as the other badges and sits in the same corner, taking the place of the share gift rather than being drawn beside it, so an old offer reads as old in your bags, the bank, house storage and the shared items window. The limit is one number for the whole file and is saved with your shares, so it keeps applying after a reload and to whatever you look at next - you set it once, not item by item. [b]/ishare expire[/b] with no number reports the limit and how many shares are past it. Hovering the badge says how many days the share has been on offer.

An item's age starts when it was first shared. Re-sharing it, moving it to another bag or running [b]/ishare sync[/b] keeps the original date, so only removing it from the list and sharing it again starts the clock over. Nothing is hidden, removed or dropped by the limit: a share past it is still offered normally, and the stopwatch is a nudge to sell or give the thing away. A share with no recorded date, one carried over from an older version of the file, is never treated as old.

[b][size=4][color=#D4AF37]Shared items are protected[/color][/size][/b]

[b]An item shared from a place is locked while the share stands.[/b] From that place it can be mailed or traded, and it can be stored, and nothing else: not sold, destroyed, deconstructed, refined, researched, enchanted, used, equipped, laundered, listed in a guild store, put on a quickslot or moved into a craft bag. Storage means the bank, a house storage chest and the furnishing vault, in both directions, plus placing a shared furnishing in a house and picking it up again - the lock is keyed to the place a copy was shared from, so it stays protected while it sits somewhere else. The lock is written as a list of what is still allowed, so anything the game adds later is refused too rather than slipping through. A share is filed against the place it was made from, and it travels with the copy: empty that place and the share re-files itself where the item now is, as long as exactly one place holds it. When the same item sits in two places the addon will not guess, and the row stays where it was. A copy in a place nothing was shared from is not locked at all. Standing offers lock the place they were marked in, because that place is what they count, and an offer moves with its copy the same way a share does. Looking at a locked item still works - linking it in chat, previewing it, the map and quest entries, marking it as junk or locked, reporting it, and splitting a stack, which keeps both halves shared. Remove the share - or stop the standing offer - to get that copy back: right-click its row in [b]/ishare list[/b], or use the item's own menu. [b]/ishare protect[/b] turns the lock off and on.

[b][size=4][color=#D4AF37]Guilds and server[/color][/size][/b]

[list]
[*]Shares are filed against the guild's id, and the file records all five guild slots for each character, writing 0 in every slot with no guild in it.
[*]On login the addon removes shares and reserves filed against a guild you are no longer in, since those banks can never be opened again. A guild's name is forgotten once no character on the account is still in it.
[*][b]/ishare guilds[/b] shows all five slots, empty ones included.
[*]The file records which platform and which megaserver the account plays on, and the site matches on them. A file written on the North American megaserver is only offered to readers on the same platform and megaserver, because nothing trades between them.
[/list]

[hr]

[b][size=4][color=#D4AF37]Commands[/color][/size][/b]

[b]/itemshare[/b] or [b]/ishare[/b]

[list]
[*][b]list[/b] - open or close the shared items window
[*][b]reset[/b] (or clear) - clear every share and every standing offer
[*][b]sync[/b] (cleanup, reconcile) - recount shares against the bags readable now and drop the ones you no longer have. Standing offers are left alone.
[*][b]rebuild[/b] - rewrite every share from your current bags. Also runs on login and when a bank opens or closes.
[*][b]scan[/b] - share every unbound furnishing placed in the house you own and are standing in, and take back the ones no longer there
[*][b]scan clear[/b] - clear every share filed as [i]Placed (<house>)[/i] for the house you are standing in
[*][b]protect[/b] - turn the share lock off (or back on): a shared copy can be mailed or traded or stored, nothing else
[*][b]save[/b] - rebuild, then offer to reload the UI, which writes the file to disk
[*][b]guilds[/b] - list the guilds captured for the current character
[*][b]always[/b] - list the items you always offer
[*][b]noalways <name>[/b] - stop always sharing one item
[*][b]reserve <n> <name>[/b] - keep n back and offer the rest
[*][b]noreserve <name>[/b] - share the whole stack again
[*][b]reserves[/b] - list every item with a reserve
[*][b]expire <n>[/b] - mark shares on offer n days or more with the stopwatch; no number reports the limit, 0 turns it off
[*][b]guildbank[/b] - toggle sharing from the guild bank
[*][b]server[/b] - show the platform and megaserver this file is recorded for
[/list]

[hr]

[b][size=4][color=#D4AF37]The website[/color][/size][/b]

[url=https://itemshare.perdues.me]itemshare.perdues.me[/url] is open to anyone. Upload your ItemShareSavedVars.lua, then browse what other players are offering and request what you need. There is a demo mode if you want to look around before uploading your own file.

If you would rather run your own copy, the site's source is at [url=https://github.com/skperdue68/ItemShare-Web]github.com/skperdue68/ItemShare-Web[/url]. Nothing in the addon needs it. The addon only writes the saved file.

[b]Google Sheets:[/b] earlier versions of ItemShare exported to Google Sheets. That is gone and is not supported. The addon now writes ItemShareSavedVars.lua and the website does the rest.

[b][size=4][color=#D4AF37]Notes[/color][/size][/b]

[list]
[*]Version 1.11.31, API 101051. Requires LibCustomMenu 7.3.0 or newer.
[*]The saved file has a format version, and a file written by another one is not carried forward. Your shares come back from your bags on the next rebuild, but standing offers and reserves are set by hand rather than read from a bag, so they start empty.
[*]Parts of the addon were written with AI assistance and it is still being tidied up.
[*]Addon source: [url=https://github.com/skperdue68/ItemShare]github.com/skperdue68/ItemShare[/url]
[/list]
```
