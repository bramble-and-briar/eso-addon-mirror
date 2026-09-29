This addon will provide an overview of many things that you might want to check before going in a trial or a dungeon conveniently gathered in a single window. Its name comes from another game, one that I have never played, but this quote became a meme in its own right: https://www.youtube.com/watch?v=JAVr0mKFoeE

If you ever:
- had "an accident" with armory, and found yourself running without mundus / attributes / passives etc. for Mad God only knows how long…
- discovered mid-trial that you had Ring of Pale Order on…
- equipped some trash item instead of selling / banking / deconstructing it, and didn't notice…
- had your food expire mid-run only to discover you didn't have any more on you…
- …or you simply wished you could actually check all the things your raid leader asks you to check before run,
  but clicking through all the necessary menus to do so would take ages…
then this addon is for you.

What it does:
1. Checks your inventory for foods and drinks (three largest stacks), potions (three largest stacks), soul gems and repair kits.
2. Checks your active food (with timer) and mundus stone.
3. Checks attribute points.
4. Checks how many unspent skill points you have.
5. Checks what you have slotted in the main wheel of quickslots, as well as number of the items slotted.
6. Checks your selected role.
7. Checks your currently equipped gear and completion of sets.
8. Checks the state of your armor and weapons.
9. Checks which CP perks you have slotted, as well as how many champion points remain unspent.

What it does NOT:
1. Fix anything automatically.
2. Interpret the data - while some of the data is presented in colors that might give out the aura of danger / warning it's ultimately up to you to decide if you want to remedy the situation or if you're fine with leaving it as is.
Examples:
- Ring of Pale Order always shows up in red for added visibility, but if you're checking before going into Infinite Archive you probably actually want it on,
- gear durability and weapon charges will show in red if not 100%, but if you have addons that handle repairs and charges automatically you might prefer to leave it for them to handle when the right time comes - you might want to have a closer look on your repair kits and soul gems stacks instead,
- unspent skill points - if this number looks suspiciously high you might want to check (manually) if you have all passives you think you have.
3. Check if your skills are correctly slotted. If you often find yourself with wrong skills consider turning the visibility of your skill bars to always on. 

To bring up the window use chat command /yanp but you can also use a keybind (assign it in Controls/Addons menu).

Mandatory dependencies:
- LibAddonMenu-2.0
- LibFoodDrinkBuff
- LibSavedVars
- LibSetDetection
- LibSets

RECENT CHANGES LOG
Version 1.13 (2026-09-28)
  - update for API 101051

  Version 1.12 (2026-06-08)
  - update for API 101050

Version 1.11 (2026-03-03)
  - update for API 101049

Version 1.10 (2025-11-01)
  - update for API 101048

Version 1.9 (2025-08-18)
  - update for API 101047

Version 1.8 (2025-06-11)
  - updated dependencies (thanks, Baertram)

Version 1.7 (2025-06-01)
  - update for API 101046

Version 1.6 (2025-04-06)
  - fixed list of equipped sets, broken after U45

Version 1.5 (2025-03-25)
  - update for API 101045

Version 1.4 (2024-10-28)
  - update for API 101044

Version 1.3 (2024-07-15)
	- CP names were swapped too…
	
Version 1.2 (2024-06-20)
	- health and stamina attributes were swapped, now corrected
	- added unregistering EVENT_ADD_ON_LOADED
	
Version 1.1 (2024-05-05)
	- fix for reticle missing after closing the YANP window with ESC
	
Version 1.0 (2024-04-02)
	- first public release
