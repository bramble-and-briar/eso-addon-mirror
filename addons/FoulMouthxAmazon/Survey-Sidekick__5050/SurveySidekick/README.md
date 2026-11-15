# Survey Sidekick

Developed with ChatGPT-assisted code generation. Maintained by FoulMouthxAmazon.
Public beta: in-game testing and community feedback are ongoing.

Version: 0.2.3-beta
Author: FoulMouthxAmazon  
Platform: ESO PC/Mac; English interface

Keep your surveys organized, track the materials you gather, set a collection goal,
and finish each run with The Hoard Report.

## Color choices

Click **Colors** in the title bar (also available when minimized), or type
`/surveys colors`. Choose Plum, Emerald, Ocean, Ember, Midnight or Rose as a preset,
or mix separate background, title bar and border choices. Changes apply instantly
and save per character. **Reset Colors** restores the default Plum preset.
The minimized tracker, quantity box, help/report copy window and color menu match.

## Optional addons

No library is required for gathering totals and collection goals.

| Addon | Enables |
| --- | --- |
| [LibTreasure](https://www.esoui.com/downloads/info3227-LibTreasure.html) | Survey locations, map waypoints and wayshrine selection |
| [Tamriel Trade Centre](https://www.esoui.com/downloads/info1245-TamrielTradeCentre.html) | Estimated values when TTC price data is available |

Install optional addons and their own dependencies separately through Minion or ESOUI.
Their files are not bundled with Survey Sidekick.

## Install or update

Extract the SurveySidekick folder into Documents/Elder Scrolls Online/live/AddOns/.
You should have AddOns/SurveySidekick/SurveySidekick.txt. Enable the addon in ESO's Add-Ons
menu and use /reloadui. For an update, replace the addon folder; keep your saved variables.
Existing runs, reports, material goals and preferences are retained.

## Start gathering

1. Type /surveys and open Current Run.
2. Click Start / Resume, then gather materials.
3. Click Pause for a break; Start / Resume continues the same run.
4. Click Finish Run to save your results in The Hoard Report.

All supported crafting materials looted while running count, whether from surveys,
regular nodes, containers or creatures. Inventory transfers are not counted. You do not
need to disable the Craft Bag. Recording continues when the window is closed or minimized.

## Set a collection goal

In Current Run, choose Survey Type, choose Material by name, enter Quantity and click
Set Goal. Click inside the quantity box to type. Progress includes that material already
collected during the current run. A message and sound announce when the goal is reached.
Setting a goal starts a new run if there is no run yet.

## Find your surveys

Put surveys in your backpack, then open My Surveys. Duplicate copies are combined into
one row. Survey Type beside The Hoard Report cycles through crafting types. Selecting
one brings you back to My Surveys with that type selected.

- Map icon: show the survey map and replace your current waypoint with its location.
- Wayshrine icon: request travel to the closest unlocked wayshrine shown on that map.
- Gold coin icon: preview the destination and recall quote without traveling.
- Circular arrow: refresh survey quantities. The list also updates automatically.

Normal ESO travel costs and restrictions apply. The closest shrine is based on map distance;
roads, cliffs and entrances can affect the actual walk. PvP travel networks are unsupported.
LibTreasure supplies location coverage; surveys without coordinates remain listed.

Backpack quantities update live. Bank quantities are last-seen snapshots refreshed while
the bank is open. Surveys on other characters are not scanned.

## Read and share results

Finish Run opens The Hoard Report. Newer / Older browse the last 30 saved runs. Copy Summary
opens a short message; Export Details opens the full material list and quantities. Select
the text, press Ctrl+A and Ctrl+C, and paste it where you want. Nothing is sent automatically.

Regular-sized and Survey/Large are estimated loot categories. Survey/Large may also include
Cyrodiil pulls or other unusually large material drops. Other contains materials that do
not have a classification rule, plus historical loot whose original split is unavailable.
The overall total includes all three categories.

Values use current price data or manual overrides. Unpriced quantities are shown separately
and excluded from the estimate. Estimates are not guaranteed sale prices and do not deduct
fees. Older reports recalculate values using current prices.

## Window controls

Drag the window to move it. Minus minimizes to a live tracker bar; plus restores it. Close
hides the window; /surveys reopens it. Position, open/closed state, size and minimized mode
are remembered per character. On a fresh installation the window opens once so you can
find it. It will remain closed after reload/login if you closed it.

Use /surveys scale 70 for a smaller window or /surveys scale 80 for the default. Sizes
from 60 to 120 are accepted. The default main window is about 736 x 560 UI units.
Button descriptions appear on hover. Survey rows and collection dropdowns have no tooltip.

After login or /reloadui, an unfinished gathering run is restored paused. Use Start / Resume
to continue it. Zone transfers keep a running session active and exclude loading time.

## Commands

| Command | Action |
| --- | --- |
| /surveys | Open or close the window |
| /surveys help | Show the how-to guide |
| /surveys start | Start or resume gathering |
| /surveys pause | Pause gathering |
| /surveys finish | Save the run |
| /surveys goal | Open collection setup; restores the full window if minimized |
| /surveyport | Travel to the selected backpack survey |
| /surveys scale 60-120 | Set window size as a percentage |

Advanced optional pricing: /surveys price ITEM_ID GOLD_EACH sets a manual unit estimate;
use 0 to clear it. Item IDs are not needed for normal collection goals.

## Public beta support

Report the addon version, what you clicked, what you expected and what happened. Include
the exact Lua error or a screenshot, and say whether LibTreasure and TTC are installed.
Please use the comments on the addon download page.

This release has automated Lua and simulated ESO checks. Live game behavior still needs
the checks in PUBLIC_BETA_TESTING.md. CREDITS.md lists integrations and asset acknowledgments.
