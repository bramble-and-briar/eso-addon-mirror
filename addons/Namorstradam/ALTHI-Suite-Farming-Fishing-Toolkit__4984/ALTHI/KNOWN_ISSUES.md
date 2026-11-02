# ALTHI Suite 2.0.0 – Scope and limitations

- Prices and gold/hour are estimates. Listing data, market changes, rounding and relisting costs can differ from actual sale proceeds. AGS is your last own listing price. The optional 7% deduction is applied consistently even to NPC fallback values.
- Loot identity comes from ESO item IDs. Source detection uses actual interaction evidence; delayed or unusual loot sequences may be missed. Mail, banking, trade, equipment and ordinary crafting/refining outputs are not new resource finds. Player-started fish filleting is handled separately.
- The catalog combines seed IDs, client style/trait APIs, recipes and observed supported materials. It does not promise every current/future special material or every origin in advance. Unknown fishing catches can be discovered on capture; the prepopulated rare-fish list is not exhaustive.
- Automatic bait selection supports recognized water labels. Unrecognized water types require manual bait choice; casting and reeling are manual. Some international water/special-node labels still need further testing.
- White filetable fish are identified through native type, quality and use information. Filleting is player-started and can stop on combat, menu changes, lack of space, cooldowns or native API refusal. Protected/locked and rare/trophy fish are not processed.
- Filleting previously owned fish does not create new session catches or profit. Mixed old/new batches with ambiguous provenance can undercount session output value. Roe statistics use observed processing results; they do not predict future drop rates or reconstruct unknown within-batch order.
- Shared session time includes travel while running; active fishing time is separate. A reload pauses the session and excludes offline time. Automatic resuming is controlled by the saved Resume on find option.
- German and English texts are maintained. French, Spanish, Russian, Simplified Chinese and Japanese translations are drafts; longer labels, native font rendering and controller layouts need broader community testing.

For a report, include `/althi version`, ESO client/interface language, exact steps and any Lua error text. Screenshots help with layout issues.

- Gold on other characters is the last recorded balance; log in to each character to capture it. Bank transfers are not income/expenses. Historical trading data can be incomplete, delayed or unavailable; importing own sales does not reconstruct old purchases or listing costs.
- Mail notifications may precede actual attachment data. Gold amounts require mail headers ESO makes available; the icon alone does not mean gold is attached.
- Survey bank counts are snapshots from the last bank access. Travel availability may change before a click; all actual requests are revalidated. Existing unlocked wayshrines are used; a default entry shrine or nearest-to-survey destination is not guaranteed.
- Refining yield is an observed average, not a future probability. Champion abilities and crafting passives affect results. Auxiliary conversions are shown in Current; ambiguous mixed improvement conversions are excluded from lifetime improvement samples.
