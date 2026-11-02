# ALTHI Suite 2.0.0

AI disclosure: developed with OpenAI ChatGPT/Codex assistance for code, documentation and translation drafts. Roman directs development and tests ALTHI in ESO. This does not claim an independent human code audit.

A farming toolkit for gathering, fishing, crafting surveys, refining results and gold tracking. Authors: Althi & Roman (@namorstradam & @bakaroobanzai). ESO API 101051.

## Gathering and fishing

Track resources and fishing in one session. Show quantities, estimated material values and gold per total session hour. The total timer includes travel while running; active gathering and pure fishing time are separate. Pause/Resume controls the session; optional Resume on find can be toggled in the header. Reload/login pauses the session and excludes offline time.

Only materials acquired in this session appear as rows. Existing stock is shown separately and valued only for item types acquired in the session. Shared profession icons toggle complete categories; use the searchable Filter List for individual items. Names, icons and quality colors follow the ESO client. Documented origins are information, not proof of a particular find.

Fishing includes session/lifetime statistics, bait stock/use, catches/hour, white fish/hour, Perfect Roe and observed filleting yield. Optional bait selection supports recognized waters; casting and reeling are manual. Player-started sequential filleting processes eligible unlocked white fish and respects native restrictions.

## Survey overview

An independent, resizable window groups carried surveys by area and sums selected professions. Sort by quantity, then available free player travel, then area name. Current-area counts distinguish active and inactive surveys. Bank counts use the latest captured bank inventory; unidentified envelopes are shown separately. Six profession filters share the main selection.

Open one or all selected professions’ usable inventory envelopes with native cooldown/result checks. Clicking an area opens its map. Travel buttons request a native journey to an eligible friend/guild member or an unlocked wayshrine. Paid recall has an optional confirmation and checks current carried gold; bank funds are not spendable travel money. Displayed costs update only for visible, previously resolved targets. No automatic invitations, retries or paid fallback after failed player travel. No promise that a shrine is closest to the survey.

The compact view offers the next suggested area. Position, size, requested visibility and fold state are saved. X or the bound visibility key closes the window; ESO menus temporarily hide it according to the setting.

## Refining

Observe refining performed in ESO’s normal crafting window; ALTHI does not perform crafting. Current shows consumed materials, results and estimated values. Lifetime shows accumulated base/improvement-material yields per 100 raw materials, with collapsible profession and input details. Crafting passives and Champion abilities can affect results. Yield is not drop probability.

Auxiliary trait/style conversions appear in Current; they do not dilute core-raw lifetime yields. Ambiguous mixed improvement-material conversions are excluded from that sample. Gathering Reset also clears Current refining; confirmed lifetime resets are separate in Settings. Refining is recorded independently of gathering pause and does not become a new farming find.

## Gold

See current-character cash, bank, last-known account holdings and mail status. Overview shows account-wide guild sales, purchases and trade balance for the selected period, including the current trading week. Guild headings expand gross sales, guild tax and expected net proceeds. Character details show personal in-game income and expenses, separate from account-wide guild sales.

LibHistoire can supply available own guild-sale history before mail is collected. It is optional. Historical import is available in Settings and never creates new cash income. Older purchases/fees are not reconstructed. Mail gold is shown separately from holdings; opening the mailbox once may be needed to learn actual amounts. An envelope alone does not promise gold.

## Prices and optional integrations

No mandatory library. Optional LibAddonMenu-2.0 supplies integrated ESO settings; standalone settings remain available without it. Optional price priority: custom ALTHI price → Awesome Guild Store (AGS) → Tamriel Trade Centre (TTC) → Arkadius’ Trade Tools (ATT) → Master Merchant (MM) → NPC base value. AGS means your last own listing price, not a confirmed sale. LibHistoire>=1105 supports guild history. Third-party addons/libraries are not bundled.

Stored prices are gross. The optional guild-trader deduction shows 93% of gross material estimates, including custom/NPC fallback prices. The separately paid 1% listing fee is not deducted again. Actual gold accounting records real movements. Estimates are not guaranteed proceeds.

## Installation and updating

Extract the single ALTHI folder into ESO’s live/AddOns folder. Correct path: live/AddOns/ALTHI/ALTHI.txt. Use a single ALTHI folder. Keep SavedVariables when updating; no reset is required. With ESO closed, copy live/SavedVariables/ALTHI.lua if you want a backup; do not move or delete it. Internal addon/storage names remain ALTHI/ALTHISavedVariables.

On first launch, choose a language in the English welcome screen. German and English are maintained; French, Spanish, Russian, Simplified Chinese and Japanese are draft translations. All are included, with no language packs needed. The interface language can be chosen independently; native item/area names follow ESO’s client language.

## Commands and controls

- /althi or /althi show — show the main overview.
- /althi home — restore its default position.
- /althi settings — settings; /althi catalog — material filters.
- /althi version — addon/API and interface/client languages.
- /althi reset — confirmed session reset; /althi debug — diagnostics.
- /althi id <ID> — inspect an item ID; /althi testfund — preview a rare-find notification.

Optional ESO keybindings cover main-window visibility, filters, Pause/Resume, confirmed Reset, fish filleting, mouse release, main folding, survey visibility and survey folding. Resize, scroll, sort, adjust columns and opacity, or minimize while tracking continues. Tracking does not depend on the HUD being visible.

For reports, include /althi version, ESO client/interface language, reproduction steps and any Lua error. See KNOWN_ISSUES.md, AUTHORS.md and source acknowledgements. Original ALTHI content: all rights reserved; personal use permitted. Reuse, modification or redistribution requires Roman’s prior permission; see LICENSE.txt. Third-party rights remain with their owners.
