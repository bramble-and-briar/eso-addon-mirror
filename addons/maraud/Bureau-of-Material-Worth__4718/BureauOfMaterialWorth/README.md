# Bureau of Material Worth

A lightweight inventory addon for *The Elder Scrolls Online*. It sums the
**market value of everything in your Craft Bag** and shows the total - with an
optional breakdown by crafting profession - in a small panel beside the bag.
It also lets you **search** your whole Craft Bag and **withdraw materials**
straight into your backpack, one at a time or in batches. The game itself only
knows the worthless vendor price; this addon reads real trading prices through
**LibPrice**, which transparently pulls from whichever price source you have
installed (Master Merchant, Tamriel Trade Centre, or Arkadius' Trade Tools).

> **Compatibility:** API: LIVE 101050 / PTS 101051 · Requires [LibPrice](https://www.esoui.com/downloads/info2753.html) (>= 70530)
> (and a price source such as Master Merchant or Tamriel Trade Centre to read
> prices from) and [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html)
> (>= 43) for the settings panel.

---

## What it does

Open your Craft Bag and a slim panel appears beside it: a prominent **grand
total** in gold at the top, a subtitle with the slot, stack, and item counts, then
a **per-profession breakdown** (Blacksmithing, Clothier, Woodworking, Jewelry,
Alchemy, Enchanting, Provisioning, and an "Other" bucket). Hover any category for
its value, slot count, stack count, item count, and how many slots have no price -
or **click a category** to open a scrollable table of every material in it. From
that table you can **search across the whole Craft Bag** and **withdraw materials
into your backpack** - one material at a time with quantity presets, or several at
once through a withdraw queue. A footer shows **how long ago** the figures were
computed and whether **every slot has a price**. As you deposit or withdraw
materials the total updates on its own.

> **A note on counts:** the Craft Bag stores each material in a single
> unbounded slot, so the panel reports two distinct figures. **Slots** is the
> number of occupied Craft Bag slots - i.e. how many *distinct materials* you
> hold. **Stacks** is the classic count of 200-item stacks that volume would
> occupy (`ceil(items / 200)`). One slot holding 350,000 of a material is
> *1 slot*, *1,750 stacks*, and *350,000 items*.

---

## Features

### Craft Bag valuation
- Sums the LibPrice market value of every slot in the Craft Bag, accounting for
  stack sizes (price × count per slot).
- A **prominent grand total** with a subtitle showing total slots, stacks, and
  items.
- A **per-profession breakdown** beneath it, which you can turn off to show just
  the total. Each row carries a **profession icon**, a subtle **share bar**, the
  category's **share of the grand total** (e.g. "Blacksmithing 42%"), and you can
  **sort rows by value** so your biggest holdings float to the top.
- **Hover tooltips** on each category reveal its value, slot count (distinct
  materials), stack count (in classic 200-item stacks), item count, and how many
  of its slots have no price.
- Values are formatted with thousands separators and the gold icon, and can be
  **tinted by magnitude** (a subtle dim-to-bright gold scale) so the largest
  figures stand out. Both the icons and the color scale can be toggled off.

### Per-category material table
- A shared **Guild Bureau** appearance across all windows: graphite surfaces,
  brass rules, turquoise actions, flat controls, and persistent
  **Materials / Changes / Dynamics** tabs. Choose **Comfortable** or **Compact**
  interface density in settings; changing density requires a UI reload.
- **Click any category row** to open a separate, scrollable window listing *every
  individual material* in that profession - handy for "Other", which can hold
  hundreds of distinct materials.
- **Click the grand total** to open the whole Craft Bag as one material list.
- Each row shows the material's **icon**, its **name** (tinted by quality), a
  compact **price-source badge** (MM / TTC / ATT and other LibPrice sources), the
  **quantity** you hold, and its **total value**. Hover the **icon** for the
  game's own item tooltip. **Shift-click** a row to insert the item link in chat.
  **Click any column header** to
  sort by it (click again to flip direction), including Price dynamics and
  **Since snapshot**. A category list still opens on **value, highest first** - the "what
  to sell right now" order - so the stacks that make up most of the bag's worth
  sit at the top.
- Choose a compact **Basic** table (material, quantity, value) for everyday
  scanning, or **Analytics** to additionally show cumulative share and price
  change. The switch sits on the table toolbar as well as in settings. The
  **Since snapshot** view always retains its delta, share, and status columns.
- **Escape** closes the material table and the withdraw window. If the search box
  has text, the first Escape clears it.
- A **cumulative-share column** ("Cum %") shows the running share of the list's
  total value read top-down, so you can see at a glance that "the top few stacks
  are 80% of the worth" - haul those to the guild and skip the long tail. A
  **gold marker** identifies the single material where that cumulative share
  first reaches the 80% threshold.
- A **price-change column** (▲/▼ with a percentage) shows how each material's
  price has moved since it was last refreshed from a price source. The addon keeps
  its own compact price history for this - a material shows "-" until a price
  refresh has established a baseline, then a real change once a later refresh
  observes it. A point is added once per login or `/reloadui`; later Craft Bag
  opens in the same session update that point. Opening, sorting, or searching
  the table never changes that history.
- The window is **movable** and closes with Escape or with the Craft Bag, so it
  never lingers over the rest of your UI.

### Seven-day price dynamics
- A **Price dynamics** row appears immediately below **Other**.
  Its `up / down` counters and a compact threshold suffix (e.g. `20%`) show how
  many held materials crossed the configured significant-movement threshold.
- Clicking it opens a whole-bag analysis with the current unit price, net movement
  from the oldest observation in the trailing seven days, maximum rise, maximum
  fall, and a sortable **Value impact** column. Value impact multiplies the net
  unit-price movement by the quantity currently held, revealing which market
  changes actually gained or lost meaningful Craft Bag value. Every earlier/later
  pair is analyzed, so a sharp one- or two-day move remains visible even if the
  price later returns near its starting point.
- Price-source changes are treated as a new comparable series: an MM-to-TTC/ATT
  switch is not reported as a market move. Important and Detailed notification
  modes announce new significant signals, direction reversals, or materially
  stronger moves without repeating the same signal on every Craft Bag open.
- Historical prices cannot be recovered retroactively from LibPrice. The row is
  available immediately, but a material needs at least two recorded observations
  before it can produce a signal; the full seven-day window fills over normal use.

### Search the current list
- The material table has a **search box** that filters the rows already on
  screen: the open category, the whole-bag list, **Since snapshot**, or Price dynamics.
  Type a name, a price source (`mm`, `ttc`), `unpriced`, or a quality word
  (`epic`, `gold`). Clearing the box (or pressing Escape) restores the current
  view. Withdraw and queue still work from the filtered rows.
- Compact **All / Priced / No price** filters narrow the category or whole-bag
  list. Clicking the main panel's Coverage row opens the whole-bag **No price**
  view directly. Sort order and the price filter persist while you move between
  categories, **Since snapshot**, and Price dynamics in the same session.

### Snapshot and changes

- The material table has snapshot controls beside its view tabs. **Remember** saves a
  snapshot of the Craft Bag's current composition; the **Changes** tab shows a
  per-material diff against it - what was added, removed, or changed in quantity.
  Replacing an existing snapshot requires confirmation, preventing an accidental
  click from silently resetting the comparison baseline.
- The diff list repurposes the columns: **Qty +/-** and **Value +/-** show the
  signed change (green for gains, red for losses), **Share** shows each move's
  portion of the total change, and **Status** reads "new", "gone", "added", or
  "reduced".
  Rows are sorted by the biggest gold movement first.
- There is **one snapshot** and it persists across sessions. The addon creates a
  one-time automatic baseline when you first open a **non-empty** Craft Bag after
  installing it and LibPrice has settled, so **Since snapshot** starts collecting useful
  information immediately.
  Pressing Remember at any time replaces that baseline with a snapshot you chose.
  Clearing the snapshot leaves **Since snapshot** empty until you press Remember again.
- As with the footer's value-change line, the diff counts **only real stock
  changes**: a material whose quantity did not move is omitted, so a price-source
  reimport that merely re-values the same materials never shows a phantom change.

### Withdraw materials into your backpack
- **Hover a material** (in a category or in search results) to reveal explicit
  actions: **withdraw** opens a popup where you can pick a quantity with presets
  (1, 10, 100, and stack multiples) or type an exact amount, while **add to
  queue** collects the material for a batch. The withdraw popup shows your **free
  backpack slots**, the **maximum you can withdraw** (clamped to what you hold and
  to backpack space), and the **total gold value** of the amount chosen.
- A **progress bar** tracks large withdrawals as the items actually arrive in your
  backpack. Once the protected move requests have been issued, the popup's Cancel
  button becomes **Hide**: hiding it does not pretend to cancel an in-flight move,
  and reopening the popup shows the final observed result.
- The **withdraw queue** expands inside that same withdraw window after using a
  row's queue action or **Add to queue**. There you can set a per-material
  quantity, see the total value and how many backpack slots the queue needs, and
  **withdraw everything at once**.
  Its quantities, capacity, and current prices refresh while it is open.
- The **default quantity is keyed to item quality**, so a careless click cannot
  dump a whole stack of something precious: cheap bulk mats default high, valuable
  mats low. A **Max** preset fills the current withdrawable amount, and you can
  always raise a quantity up to that limit.

### Honest about its data
- The footer separates **Inventory** (when the bag valuation last changed) from
  **Prices** (when LibPrice was last queried), so a deposit never masquerades as
  fresh market data. Click **Market prices** to clear the session cache and
  re-query LibPrice - the same action as `/bmw refresh`. The row shows when the
  refresh is in progress, blocks duplicate clicks, and briefly confirms when the
  current refresh cycle is complete.
- **Coverage** reports how many slots are priced and the corresponding percentage
  (e.g. "468/469 priced · 99%"), plus the **price source** it drew from, shown
  compactly (MM / TTC / ATT, with a "+" when several contributed). When more than
  half the slots are unpriced the row turns to a loud "unpriced!" warning, so the
  total never silently pretends to be complete. Click Coverage to inspect the
  materials missing a price.
- A **value-change row** (▲/▼) shows how your Craft Bag's value changed - labeled
  "This visit" or "This session". Hover it to split the change into material
  movement and price revaluation; click it to inspect the materials whose
  quantities changed in the existing detail window.
- An optional **value-history sparkline** beneath the footer plots your total
  over time. Its newest sample is explicitly marked, and the header shows the
  overall percentage trend across the visible history. One point is recorded per
  login or `/reloadui` (later Craft Bag opens in the same session do not add
  another point), keeping the last 90; hover it for the oldest, newest, and net-change
  figures. The graph appears once you have at least two points and fills in
  over several days of play.
- An optional **chat announcement** prints the bag's value the first time you open
  it each session, with the since-last-visit change when your stock moved.
- `/bmw refresh` re-queries prices - handy after Master Merchant or Tamriel Trade
  Centre finishes importing fresh data. The panel's **Market prices** row does
  the same thing without opening settings.

> **How the value-change delta works.** Craft Bag market prices do **not** update
> live - a price source (Master Merchant / TTC / ATT) only refreshes its data
> across a game restart and reimport. The row appears only when a material's
> quantity changed since the baseline, so a restart-and-reimport that only
> re-values an unchanged bag does not show a misleading "+2M". When stock *did*
> change,
> however, the displayed total naturally includes both the value of material
> movement and any simultaneous price revaluation. Hover the row for that split;
> click it to list the materials whose quantities changed. You choose the baseline
> in settings: **Each visit** compares against the previous time you opened the
> bag (persists across restarts), while **Each session** compares against the first
> open after login/`/reloadui`, so the change accumulates until you log out. On the
> first open with no baseline yet, and when nothing changed, no delta is shown.

### Lives with the Craft Bag
- The panel is anchored to the Craft Bag and is only on screen while the bag is
  open. The configurable horizontal/vertical offset lets you nudge it to taste.

### Settings & localization
- A clean **LibAddonMenu** panel: toggle the category breakdown, profession
  icons, the gold color scale, and value sorting; choose the value-change
  baseline (per visit or per session); show/hide the value-history sparkline and
  the chat announcement; show/hide the background and border; set the panel width
  and offset; choose chat-debug verbosity; and force a price refresh.
- **Current settings**, **Appearance**, and **Diagnostics and saved data** stay
  visible without opening a submenu. Summary width defaults to **460 px**, with
  a **460-600 px** range and more room for category names and percentages.
- Full **English and Russian** localization.
- Slash commands for everything (see below).

---

## Why it's built well - the performance story

The Craft Bag can hold **hundreds of distinct materials**, and a market
price lookup is not free. The naïve approach - loop every slot and query the
price addon, on every inventory event - is exactly what causes the multi-second
freezes you may have seen elsewhere. This addon is built specifically to avoid
that:

- **Zero work while the bag is closed.** Inventory changes that arrive while the
  Craft Bag is shut do nothing but mark the valuation *dirty*. No scanning, no
  price lookups, no UI work happens in the background.
- **Lazy, one-shot scan on open.** A full rescan runs only when the bag becomes
  visible *and* something changed since last time. If nothing changed, opening
  the bag costs nothing.
- **One price lookup per material, per session.** Each distinct item's price is
  cached by item id (including a cached "no price available" verdict), so a
  given material costs **at most one** LibPrice call for the whole session.
  Repeat opens are effectively instant.
- **Incremental updates.** Depositing or withdrawing a stack while the bag is
  open updates only *that one slot's* contribution to the running total - an
  O(1) adjustment, never a full rescan.
- **Coalesced refreshes.** A burst of slot updates (e.g. dumping a 200-item
  stack, which fires many per-slot events) collapses into a single window
  redraw via a short debounce timer.
- **Empty-slot safe.** The Craft Bag keeps a slot around after its material is
  fully removed; every slot is guarded on stack size *and* item id before any
  pricing, so emptied slots never cause errors or phantom values.

### Robust categorization

Items are mapped to a crafting profession by their `ITEMTYPE_*`, resolved from
the game's own constants at load. Each constant is looked up by name and skipped
if a given client build doesn't define it, so an unexpected client never crashes
the addon - an unmapped material simply falls into "Other".

---

## Architecture at a glance

The addon is split into small, single-responsibility modules under one global
namespace, mirroring the structure of its sibling *Bureau of Acceptable Views*.

```
            Settings.lua          UI + SavedVariables
                 │
   BureauOfMaterialWorth.lua      Core: logging, chat, event wiring, slash command
                 │
        ┌────────┼────────────┬──────────────────┐
        ▼        ▼            ▼                  ▼
  Valuation.lua  Window.lua  DetailWindow.lua  WithdrawDialog.lua
  scan · prices  anchored    per-category +     withdraw popup +
  aggregates     panel       search table       queue + move engine
```

- **`Valuation.lua`** owns all scanning, the per-item price cache, the per-slot
  contribution cache, the running category/grand totals, the per-material
  price history, the whole-bag search, and the backpack-capacity math. It is the
  only module that touches LibPrice or the Craft Bag contents.
- **`Window.lua`** is pure presentation: it reads already-computed totals and
  lays out the panel. It never scans or prices anything.
- **`DetailWindow.lua`** is the scrollable per-category material table (with the
  whole-bag search box), opened by clicking a category row; it reads its rows from
  `Valuation.lua` on demand and routes clicks to the withdraw dialog.
- **`WithdrawDialog.lua`** is the single-material withdraw popup and the
  multi-material withdraw queue, plus the shared move engine. It is the only
  module that moves items (`RequestMoveItem` via `CallSecureProtected`, issued
  synchronously from the confirming click).
- The **core** wires the Craft Bag fragment's visibility to the valuation and
  window, filters the inventory update event to the Craft Bag, and exposes the
  `/bmw` slash command via an O(1) dispatch table.

---

## Module overview

| Module | Responsibility |
| --- | --- |
| `BureauOfMaterialWorth.lua` | Core: logging, chat, event wiring, Craft Bag visibility, slash commands. |
| `Valuation.lua` | Craft Bag scan, LibPrice integration, price/slot caches, category aggregation, per-material price history. |
| `Window.lua` | The panel anchored to the Craft Bag; renders the total and category rows. |
| `DetailWindow.lua` | The scrollable per-category material table (with whole-bag search) opened by clicking a category row. |
| `WithdrawDialog.lua` | The single-material withdraw popup, the multi-material withdraw queue, and the shared item-move engine. |
| `Settings.lua` | SavedVariables, defaults, and the LibAddonMenu panel. |

---

## Slash commands

Everything the settings panel does is also reachable from chat.

```
/bmw                  Quick status (current Craft Bag value, debug level)
/bmw status           Same as above
/bmw refresh          Clear cached prices and recompute the value
/bmw settings         Open the settings panel  (aliases: /bmw ui, /bmw panel)
/bmw debug <0-4>      Set debug verbosity (off → verbose)
/bmw help             List all commands
```
