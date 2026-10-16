The Profit
==========

A lightweight personal trade ledger for The Elder Scrolls Online.

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls(R) and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

Version 1.1.1
-------------

* Track, Select, and Open actions from an item's context menu now open the Price
  view for that item.
* Untracked items offer "Show Sales in My Guilds", which opens All Deals with an
  item-name search without adding the item to the portfolio.
* An empty All Deals search now clearly says that no sales of the item were found
  in the configured guilds and highlights the message separately from loading.
* Truncated item links in Stock now retain the same mouse actions and context menu
  as fully visible item links.

License
-------

Copyright (c) 2026 manukartofanu. All rights reserved.
Redistribution, modification, re-uploading, sale, monetization, and creation of
derivative works are prohibited without prior written permission. See LICENSE.

Dependencies
------------

The following libraries and addons must be installed and enabled:

* LibHistoire
* LibAsync
* LibCustomMenu
* LibAddonMenu-2.0
* Tamriel Trade Centre

AwesomeGuildStore is optional. When it is installed, The Profit can add a margin
filter and deal indicators to its search results.

LibGroupBroadcast is optional. It enables private sharing of tracked items and
matching guild-store deals with other group members who also use The Profit.

Usage
-----

* Right-click an item or item link and choose "Track in The Profit".
* For an untracked item, choose "Show Sales in My Guilds" to open All Deals
  filtered by that item's name without adding it to the portfolio.
* Use /theprofit to open or close the ledger.
* Track up to ten items and switch the active item by clicking its table row.
* The add-on settings can open the ledger automatically with mail or guild stores.
* When AwesomeGuildStore is installed, choose the Simple or Proficient margin
  filter under Settings > Addons > The Profit. Changing the filter reloads the UI.
* Hover the active item for a quick tooltip, or left-click it to open ESO's
  persistent item popup with information added by other addons.
* The addon records purchases itself and imports personal sales from every guild
  through LibHistoire. Portfolio, Price, Stock, Ledger, My Deals, All Deals,
  and Stats views separate comparison, market history, stock control, accounting,
  personal history, guild history, and weekly reporting workflows.

The Profit does not provide a supported public API. Functions and data available
through the global TheProfit table are implementation details and may change or
be removed without notice.

Purchases are recorded when they are submitted through ESO's guild store,
including purchases made through AwesomeGuildStore when it is installed.

AwesomeGuildStore filters
-------------------------

The optional AwesomeGuildStore integration uses Tamriel Trade Centre prices and
adds a colored deal indicator to guild-store result rows.

Simple compares each listing's unit price with the TTC suggested price. It shows
the discount percentage and groups results into five ranges: below 1%, 1%-15%,
15%-40%, 40%-90%, and 90% or more.

Proficient uses five selectable deal categories. It marks especially deep TTC
discounts with minimum absolute-profit thresholds, accepts a 25% return only
when the TTC price has enough supporting sales, and marks a tracked item as BUY
when The Profit's market model considers it ready to purchase. That model uses
recent LibHistoire sales, liquidity, current tracked stock, price trend, and
volatility. Listings without enough data remain in Other.

Group deal sharing
------------------

Group sharing is disabled by default. Install LibGroupBroadcast, then enable
"Share tracked items with group" under Settings > Addons > The Profit > Group.
Group members running The Profit exchange the identities of their tracked items
and the highest unit prices their market models currently consider safe buys.

When AwesomeGuildStore receives search results, The Profit checks only those
results for lots wanted by another active group member. It never starts guild-
store searches itself. Matching deals are sent when the store is closed, except
for lots bought by the reporting player. The recipient evaluates the complete
stack with their own current model before accepting and displaying the report.

Accepted reports appear as a temporary HUD alert. An optional Group deals window
can also be shown beside ESO's group window. Reports expire after thirty minutes,
or one minute after the recipient visits the reported guild store. Alert color,
size, locking, preview, and both window positions are available in the Group
settings. `/theprofit group` prints the current sharing and peer state for
diagnostics.

Active listings are captured when an item is posted, but are saved only after
ESO confirms the request. Whenever the current guild's listing page is loaded,
the saved state is reconciled against ESO's real listing list after a short
delay, keeping the list-opening frame free of addon work. Repeated server
updates are coalesced so only the latest delayed check runs. Confirmed
cancellations, matched personal sales, and expiry move a listing out of the
active set. A listing absent from one refresh is kept as "missing" until a sale,
cancellation, expiry, or a later store refresh resolves it; this avoids treating
a temporarily stale response as a definite cancellation.

Profit is calculated as:

    matched gross sales - proportional listing fees
                        - proportional trading-house cut
                        - all purchase spending

The full cost of purchased stock is counted even when some of it remains unsold.
If ESO never answers a submitted purchase, it remains "uncertain" and is still
counted as an expense. Only an explicit rejection excludes it from the total.

Sales are matched newest-first against purchases that already existed when the
sale happened. A sale cannot cover a later purchase, and sales beyond the
recorded purchased quantity are ignored for position profit and personal sales
velocity. If only part of a sold stack can be matched, its revenue and fees are
included proportionally. This keeps pre-existing inventory and older unmatched
sales from hiding the obligation created by a new purchase.

The projected result uses recent guild-sale history for each tracked item. The
sample size follows one quarter of the observed 24-hour volume, with a minimum
of 30 trades when enough history is available. The lowest and highest 15% of
item quantity is discarded; a boundary stack is trimmed only by the required
number of units instead of being removed as a whole. The forecast unit price is
the quantity-weighted mean of the remaining volume minus one weighted standard
deviation.

    projected profit = current profit + forecast stock revenue
                       - future listing fee - future sale cut

General market history is not duplicated in SavedVariables. LibHistoire remains
the persistent source; The Profit builds only a seven-day session cache for the
guilds selected as trading guilds. Personal sales discovered in those selected
guilds remain stored because My Deals and the ledger need them across sessions.

The Profit does not start its sales processors during addon loading or after an
arbitrary startup delay. It registers lightweight interest in the trader
category, waits for LibHistoire to start its own requests, and begins reading
sales only when LibHistoire's status is green for every selected trading guild:
all active categories are linked, no request is pending, and internal event
processing has finished. Unselected guilds neither block startup nor receive a
sales processor. The completed sync time is saved per guild, so later sessions
only process the
previous trading week and events received since the last successful sync. Full
selected-guild history is loaded lazily when All Deals is first opened. If
LibHistoire loses a managed range, The Profit restarts that guild's processor
from the corresponding CATEGORY_LINKED callback. UI refresh requests are
suppressed during a bulk pass and coalesced into one refresh after processing
and snapshot building finish.

Window views
------------

Portfolio shows all ten tracked items in a Stock-style table. Stock % is each
item's remaining FIFO purchase cost divided by the total remaining FIFO purchase
cost of the portfolio; ROI keeps the projected-return calculation. Clicking a
row selects the item for the Forecast Price and Projected Profit cards. A third
card shows aggregate Portfolio Profit and ROI. Portfolio monetary values are
shown without currency icons, and the selected item can be removed with the
button below the cards.

Ledger presents recorded purchases for the currently tracked items newest-first
and allocates personal sales to purchase lots using FIFO. Partial matches are
shown separately, while an unsold remainder has no corresponding sale. Item
links retain their hover and link actions. The view keeps seventeen rows visible
and scrolls through older records.

My Deals is a chronological, non-FIFO journal of personal trading. Purchases and
sales have separate in-view tabs and can be filtered by ESO trading week. Each
table shows item, guild, quantity × unit price, and transaction time. The current
and previous week boundaries follow the Tuesday reset: 14:00 UTC on EU and 19:00
UTC on NA. An all-time option shows every transaction stored by The Profit.

All Deals shows one chronological list of LibHistoire sale events available to
the account for the guilds configured from the Price view. It can be narrowed by guild and
by partial item, seller, and buyer names. Text searches are applied on Enter. If
a seller or buyer has an exact name match, only that exact player is shown;
otherwise the filter uses partial matches. The compact table shows item, guild,
seller, buyer, quantity x unit price, and sale time. The first visit starts a
lazy full-history pass for the selected guilds and builds a session cache of
every event LibHistoire makes available. ESO exposes only guilds the player
belongs to and only the history LibHistoire has received, so it cannot reconstruct
a person's purchases across the whole game world. Filter changes reuse the
completed snapshot, scrolling only changes the visible rows, and Refresh rebuilds
the snapshot manually with a one-minute cooldown. Snapshot construction and
sorting are time-sliced through LibAsync to keep frames responsive.

Stats compares each selected guild's turnover in the current and previous
ESO trading weeks and shows the week-over-week percentage change. Its seller
table aggregates by the exact seller-and-guild pair, defaults to descending gold
turnover, includes the number of sale events (lots), and switches between the
current and previous week. Stats is calculated once after LibHistoire
finishes its initial cached-history pass. Scrolling and switching weeks reuse
that snapshot; Refresh rebuilds it manually and has a one-minute cooldown. Week
boundaries are the same Tuesday EU/NA resets used by My Deals.

Stock treats purchases of the ten currently tracked Portfolio items as the
source of owned resale quantity; purchases of every other item are ignored by
this view. It never reads backpack, bank, or craft-bag counts. Matched personal
sales reduce that tracked stock. Only confirmed active listings are grouped by
guild; listings no longer observed during reconciliation are withheld until a
sale or cancellation resolves them. Active listings are not capped by tracked
stock because they can legitimately include items owned before The Profit began
tracking purchases. The listing table shows stack quantity, unit and total price,
and remaining duration. Native and AwesomeGuildStore cancellation, sale matching, expiry, and
store reconciliation refresh the view. Receiving a returned attachment does not
change the logical tracked stock because it was never derived from inventory.

The Price view stays synchronized with the item selected in Portfolio and also provides an
alphabetical dropdown for switching between tracked items. Two rows of tabs select
All Guilds or one configured trading guild. The sales grid then shows twelve recent
sales from all participants, with guild, quantity x unit price, and sale time; the
All Guilds tab combines the history from every configured guild. The configuration
dialog controls which account guilds are loaded from LibHistoire and used for both
this history and market calculations.
