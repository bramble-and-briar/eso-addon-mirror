GULDGRYDEN 0.5.1
By Punk & Nova

Turn surplus provisioning ingredients into gold at NPC merchants.

INSTALLATION AND UPDATES
Extract the Guldgryden folder into:
Documents\Elder Scrolls Online\live\AddOns
Replace the existing addon files when updating, then type /reloadui.
Existing settings and tracked products from versions 0.3.0 onward are retained.
If updating from 0.2.x, sell any tracked products before reloading.
LibAddonMenu-2.0 is optional and provides Settings > Addons > Guldgryden.
Without it, use /gg keep 1000 to change the reserve. /gg toggles the window.
The old /gg behold 1000 command still works.

WHAT IS NEW IN 0.5.1
- Added recipes worth 1 gold per portion as the final price tier.
- Higher-value recipes still receive ingredients first; reserves and protections apply.

WHAT IS NEW IN 0.5.0
- English interface, settings, chat messages and documentation.
- Full bags display a clear message rather than an empty crafting plan.
- Planning is independent of the game's current bag-limited crafting maximum.
- Existing partial stacks can still be filled when no bag slots are free.
- Removed Find Recipes. The plan refreshes when you visit a cooking fire
  and whenever you press Start crafting.

HOW TO USE
Visit a cooking fire and press Start crafting. The addon crafts in batches
of up to 999, limited by available ingredients, bag space and the game.
Stop crafting allows an already requested batch to finish.
When your started production finishes or runs out of room, the addon leaves
the cooking fire automatically, provided it produced tracked items.
Visit an NPC merchant to sell the tracked products. The addon waits for each
sale to be confirmed, reports one total, and leaves when all tracked products
have been sold. Ordinary visits, errors and manual stops do not trigger exits.
Return to the cooking fire and press Start crafting to continue.

RECIPES AND INGREDIENTS
Uses known green food/drink recipes with two white ingredients, one of each.
Plans higher sale prices first: 5, then 4, 3, 2 and 1 gold per portion.
Any recipes above 5 gold take priority. Recipes worth 0 gold are excluded.
Each price tier receives only ingredients left over from the previous tier.
Keeps 1,000 of each ingredient by default; the reserve is configurable.
These 11 special ingredients are always excluded by item ID:
Aetherial Dust (115026), Animus Stone (120894), Bervez Juice (27059),
Cyrodiil Citrus (171326), Diminished Aetherial Dust (120078),
Frost Mirriam (26802), Mourning Dew (171433), Perfect Roe (64222),
Portent of Curiosity (224836), Red Lichen (225210), Rubyblosson Extract (171328).

SKILLS
The addon identifies Recipe Improvement or Recipe Quality requirements
blocking known eligible recipes with ingredients above the reserve.
Chef 3/3 maximizes food yield; Brewer 3/3 maximizes drink yield.
Lower ranks do not prevent crafting. The plan uses your actual yield.
Green recipes do not require Recipe Quality 4/4.

TRACKED SALES
Only observed Guldgryden production is authorized for sale. Other food does
not increase the authorized quantity. Locked or stolen items are skipped.
Tracking is saved per character and server across /reloadui and normal logout.
Moving or consuming food reduces the tracked quantity conservatively.
If a sale cannot be confirmed, selling stops and that product loses its
authorization. This may leave products for manual sale rather than oversell.
Do not run another sales addon on the same products at the same time.
The addon does not mark anything as junk.

PLAN AND DISPLAY
Window position and expanded recipe details are remembered.
Details show portions, expected gold and ingredient balances after the plan.
Recipe and ingredient names follow the game language; addon text is English.
The planner compares three allocations within each price tier; it does not
guarantee a global optimum. Ingredients are not double-booked.
Expected income is vendor revenue, not profit after ingredient market value.
The first batch can be smaller while the addon learns a product's stack size.

VALIDATION
Lua simulations cover reserves, price order, full and partially filled bags,
skill requirements, batch limits, stop behaviour, tracked sales and reloads.
Version 0.5.0 was confirmed working by Punk in the live ESO client.
Version 0.5.1 needs live confirmation of the new 1-gold tier.
API version: 101050.
