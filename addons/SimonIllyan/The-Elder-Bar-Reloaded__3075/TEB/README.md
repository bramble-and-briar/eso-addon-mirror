# The Elder Bar Reloaded

The Elder Bar Reloaded is an addon for Elder Scrolls Online. This addon adds an information bar on the screen, chocked full of information gadgets that update in real-time. The gadgets can be placed on the bar in any order and there are lots of options to configure each one. Last but not least, the bar can also indicate when in combat.

## Features

* The Elder Bar can be unlocked, dragged, and dropped wherever you'd like it. You can assign a hotkey to lock/unlock the bar.
* Individual gadgets can be unlocked, dragged, and dropped in any order. You can assign a hotkey to lock/unlock the gadgets.
* There is a separate mode for PvE and PvP -- the bar switches automatically. You can have different gadgets on the PvP bar than you do on the PvE bar.
* Almost every gadget has options for coloration, warning thresholds, and different options for displaying the data just how you like it.
* All timers can be automatically hidden when not in use.
* Every gadget has a tooltip that can display additional information.
* The Elder Bar can hide itself automatically when you choose. Choices include talking to NPCs, visiting the bank, crafting, and more.
* The bar can be scaled from 50% to 150% of its normal size.
* An optional setting turns the bar red when you are in combat.
* Track mount training times across multiple characters. You can choose whether to track a character or not. Automatically stops tracking characters with mounts at maximum.
* Track gold and other currencies across multiple characters. You can choose whether to track a character or not.
* Icons come in two variations: 
	* monochrome
	* full color
* Gadgets can pulse to draw the player's attention to them. They have five different modes: 
	* fade in
	* fade out
	* fade in/out
	* slow blink
	* fast blink.

## Gadgets

 1. Alliance Points
 2. Bag Space
 3. Bank Space
 4. Blacksmithing Research Timer
 5. Bounty/Heat Timer
 6. Clock
 7. Clothing Research Timer
 8. Companion
 9.	Crown Gems
10. Crowns
11. Durability
12. Endeavor Seals
13. Enlightenment
14. Experience
15. Fast Travel Timer
16. Food Buff Timer
17. Frames Per Second
18. Gold
19. Jewelry Crafting Research Timer
20. Junk
21. Kill Counter
22. Latency
23. Level / Champion Points
24. Location (Zone Name / Coordinates)
25. Lock/Unlock Bar & Gadgets
26. Memory
27. Mount Timer
28. Mundus Stone
29. Outfit Change Tokens
30. Sky Shards
31. Soul Gems
32. Tel Var Stones
33. Thief's Tools
34. Tome Tokens
35. Tome Points
36. Trade Bars
37. Transmute Crystals
38. Undaunted Keys
39. Unread Mail
40. Vampirism
41. Weapon Charge
42. Woodworking Research Timer
43. Writ Vouchers

## Change Log
Changes in version 12.1.3 (2026-09-28)
	- updated for API 101051
	- updated dependencies
	
	Changes in version 12.1.2 (2026-06-08)
	- updated for API 101050
	- Endeavor Seals became just Seals

Changes in version 12.1.1 (2026-03-14)
	- this time fixed it for good, I swear...
	- added controls for gadgets added in 12.1.0

Changes in version 12.1.0 (2026-03-13)
	- fixed (?) problem with SavedVariables
    - added gadgets for Outfit Change Tokens, Trade Bars, Tome Points, and Premium Tome Tokens

Changes in version 12.0.1 (2026-03-10)
	- fixed upper limit for Transmute Crystals (1000 -> 3000)
    - removed settings for (already removed) Event Tickets widget
    - added Trade Bars to the list of currencies

Changes in version 12.0.0 (2026-03-03)
	- updated for API 101049
	- removed gadgets for event tickets and endeavors

Changes in version 11.9.2 (2025-11-01)
	- updated for API 101048

Changes in version 11.9.1 (2025-08-18)
	- updated for API 101047

Changes in version 11.9.0 (2025-06-11)
	- updated dependencies (thanks, Baertram)

Changes in version 11.8.9 (2025-06-01)
	- updated for API 101046

Changes in version 11.8.8 (2025-04-06)
	- fixed CurrentlyEquipped widget

Changes in version 11.8.7 (2025-03-25)
	- updated for API 101045

Changes in version 11.8.6 (2025-01-05)
	- long overdue addition of Imperial Fragments to the list of currencies

Changes in version 11.8.5 (2024-10-28)
	- updated for API 101044

Changes in version 11.8.4 (2024-07-16)
	- updated for API 101043

Changes in version 11.8.3 (2024-04-22)
	- fixed a bug causing error message "Control [ZO_PlayerAttributeHealth] already has two anchors,
	  adding another will have no effect." to sometimes appear 
	- changed "Location" gadget to show X, Y coords with two digits after decimal point

Changes in version 11.8.2 (2024-04-06)
	- all obsolete repair kits removed from Durability gadget - only equipment, crown, group repair kits remain

Changes in version 11.8.1 (2024-03-10)
	- bug manifesting upon attempt to change Auto-hide settings likely fixed

Changes in version 11.8.0 (2024-02-29)
	- added gadget for equipped sets, inspired by Currently Equipped addon - see 
	  https://www.esoui.com/downloads/info3524-CurrentlyEquipped--EquippedSetDisplay.html
	- lists of characters in tooltips for widgets that have trackers
	  (like "Gold", "AP", "Tel Var", "Writs", "Mount", "Mundus")
	  now can be sorted by creation order (oldest on top) rather than
	  alphabetically by name (option "Sort Characters" in "General")
	- ESO+ gadget now shows also subscription's ending date in customizable format
	
Changes in version 11.7.0 (2024-01-01)
	- added Archival Fortunes to displayed currencies
	- added gadget for expiring ESO+ subscription (requested by daimon)
	- …which created a new optional dependency
	  (the addon works without it, but ESO+ gadget is not available), see 
	  https://www.esoui.com/downloads/info2932-LibAddonMenu-DatePickerwidget.html
	- Mount Timer gadget shall now signal if any (i.e. other than current)
	  tracked character can train the mount
	- unspent Champion Points to display in Level widget can be selected
	  individually per category (craft/warfare/fitness) 
	
Changes in version 11.6.2 (2023-11-03)
	- added slider to set the frequency for blinking widgets
	  (the frequency is now independent of frame rate)
	- performance optimisations
	
Changes in version 11.6.1 (2023-09-26)
	- improved gadget for leads (added settings)
	
Changes in version 11.6.0 (2023-09-24)
	- updated for API 101040
	- added a gadget for antiquity leads
	- reworked the autohide code, so that Pacrouti (crates)
	  and CP screens are treated like other menu screens
	- minor cleanup
	
Changes in version 11.5.2 (2023-08-20)
	- updated for API 101039 
	- tweaked the blinking indicators

Changes in version 11.5.1 (2023-06-15)
	- arcanist icon added
	
Changes in version 11.5.0 (2023-04-22)
	- updated for API 101038 (Necrom)
	- possibly finally fixed the bug preventing gadgets from being reordered
	- probably introduced many new bugs

Changes in version 11.4.9 (2023-02-26)
	- updated for API 101037 (Scribes of Fate)

Changes in version 11.4.8 (2022-06-25)
	- mouseover popups work again
	
Changes in version 11.4.7 (2022-05-12)
	- don't show "XP % for next level" if companion already at level 20
	- updated for API 101034 (High Isle)

Changes in version 11.4.6 (2022-02-22)
	- updated for API 101033 (Ascending Tide)

Changes in version 11.4.5 (2022-01-21)
	- changed behaviour of Mount gadget
	
Changes in version 11.4.4 (2021-11-01)
	- updated for API 101032 (Deadlands)
	- minor fixes

Changes in version 11.4.3 (2021-08-18)
	- updated for API 101031 (Waking Flame)
	- minor fixes

Changes in version 11.4.2 (2021-07-23)
	- fixed missing check in CheckThreshold

Changes in version 11.4.1 (2021-07-21)
	- added text to Lock/Unlock gadget
	- modified Endeavor Progress gadget (added selection of remaining time display format)
	- fixed colour for research timers

Changes in version 11.4.0 (2021-07-16)
	- added a gadget for endeavor progress (number of completed endeavors and remaining time)
	- added an option for all non-global currencies to have different display formats for the gadget 
	  and for the global currencies tooltip
	- added an option to hide companion rapport if maxed out
	- fixed AP gadget (I hope…)
	- changed format of SavedVariables so that Trackers are a separate subtree
	  to make it easier to copy settings between accounts
	- another internal change - gadget icons are now of CT_TEXTURE rather than CT_BUTTON type;
	  it means they can be painted any colour, so "Icons inherit color" option finally works
	  as intended (except for the Lock/Unlock gadget - can't be helped)
	- other fixes

Changes in version 11.3.4 (2021-07-01)
	- modified tooltips for all non-global currency gadgets to show the amount of currency
	  on each character and in bank (gadgets for global currencies, i.e. crowns, crown gems,
	  undaunted keys and transmute crystals work as before, except the non-global currencies are presented
	  in tooltips in the format selected for their respective gadgets)
	- research sloths should be more diligent now
	- fixed misaligned tooltip for Bounty and Heat gadget
	- fixed Transmute Crystals gadget being always white
	- possibly fixed some other bugs

Changes in version 11.3.3 (2021-06-26)
	- circumvented the ZoS bug with companion reporting 0 XP while swimming

Changes in version 11.3.2 (2021-06-25)
	- added options to show appriopriate gadgets only when research/horse training is possible
	- fixed a bug causing companion gadget's disappearance
	- added more options to companion gadget (taken from CompanionInfo addon)
	- fixed lock gadget icon not changing on unlocking
	- fixed enlightenment gadget 

Changes in version 11.3.1 (2021-06-14)
	- added option for icons inheriting (or not) status color (warning etc.) from their labels
	- added Companion gadget
	- fixed kill counter
	
Changes in version 11.3.0 (2021-06-12)
	- added gadget for locking/unlocking bar & gadgets
	- made another attempt at fixing "Avoiding anchor cycle from [X] to [Y]" warning
	- corrected checking thresholds (changed strong inequality to weak )
	- changed SavedVars structure again (now it is v10)
	- a lot of internal changes to make it less of a CPU hog

Changes in version 11.2.2 (2021-06-03)
	- fixed disappearing pulsing items
	- added gadgets for crowns and crown gems (also added these to the currencies tooltip)
	
Changes in version 11.2.1 (2021-06-02)
	- fixed event tickets & food buff gadgets not showing up
	- fixed another problem with upgrading from earlier version (thanks to shadowcep)
	
Changes in version 11.2.0 (2021-06-01)
	- fixed research timers showing only shortest timer regardless of the settings
	- fixed problem (one of…) with upgrading from the original TEB version
	- fixed champion points mismatch
	- changed SavedVars structure again (now it is v9)
	
Changes in version 11.1.4 (2021-05-31)
	- fixed problem with slotted poison (I think…)
	- fixed problem with research timers not showing
	- fixed problem with Thief's Tools (when set to "total stolen")
	
Changes in version 11.1.3 (2021-05-30)
	- removed another overlooked debugging message
	
Changes in version 11.1.2 (2021-05-30)
	- fixed coloring of Thieves Tools and Soulgems
	- fixed mail gadget pulsing
	- Undaunted keys and Endeavor Seals now have proper icons (but no monochrome version!)
	- added "Junk" gadget
	- Tamriel time and date now rely on LibClockTST (optional dependency,
	  but without it Tamriel time is not available)
	- changed colors in the Settings menu a bit
	- removed unnecessary debugging
	
Changes in version 11.1.1 (2021-05-28)
	- fixed coloring of some items (like non-gold currencies) on the bar
	- fixed uneven transparency of the bar's background
	- fixed levels of Enlightement
	- added option for bar autohide speed
	- added widget for endeavor seals (currently works on PTS only)
	- added sorting of characters in Mundus tooltip
	- restored multiple items/times in research widgets
	- scaling the bar is now in steps of 5
	
Changes in version 11.1.0 (2021-05-25)
	- Undaunted keys gadget 
	- Transmute Crystals gadget has warning/danger levels
	- Mundus stone buff is tracked like mounts and gold, unset Mundus colored as Danger
	- option to auto-hide bar while digging for antiquities
	- full customization of 14 colors via color pickers
	- restored on popular demand: bar can be moved so high/low that part of its edge is off screen
	- changed internal data structures for storing gadget order in PvE/PvP
	- changed the format of SavedVariables again (please backup your SavedVariables if you think
	  you may want to go back to previous version)

Changes in version 11.0.3 (2021-05-20)
	- fixed some of the bugs related to settings initialization
	- moved background settings to "General Settings" section
	- added some new settings ("Spacing between gadgets","Draw a border around the bar")
	- some preparations for full color customization
	
Changes in version 11.0.2 (2021-05-18)
	- added color picker for the default color of text and icons
	
Changes in version 11.0.1 (2021-05-17)
	- fixed converting settings from the old version to the new one, using LibSavedVars
	
Changes in version 11.0.0 (2021-05-16)
	- first version of The Elder Bar Reloaded;
	version numbering continues from the original The Elder Bar by Eldrni
