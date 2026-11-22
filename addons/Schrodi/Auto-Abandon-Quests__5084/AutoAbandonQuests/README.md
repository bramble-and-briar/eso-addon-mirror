# Auto Abandon Quests

Abandons unwanted repeatable quests the moment they land in your journal, so you can talk to the quest giver again and get a different one.

Each category has a multi-select of the quests to **keep**; everything else in that category is abandoned. Nothing selected (or everything selected) means nothing is abandoned.

| Category | Choices | Kept by default |
|---|---|---|
| Dark Brotherhood Contracts | Normal contracts, Killing Sprees | Killing Sprees |
| Daily Battleground Quests (Battlemaster Rivyn) | Let the Games Begin, Test of Mettle, To the Victor | Test of Mettle, To the Victor |
| Cyrodiil Bounty Missions | Kill Enemy Players + the seven class bounties | Kill Enemy Players |
| Cyrodiil Conquest Missions | Capture All 3 Towns, Capture Any Nine Resources, Capture Any Three Keeps, Kill 150 Enemy Players | Resources, Keeps |

![Settings with the keep-list dropdown for Conquest Missions open](../_screenshots/AutoAbandonQuests/AutoAbandonQuests.png)

In the daily categories the kept quests count as equal. Once every kept quest has been turned in on the current character since the last daily reset, the others are kept too and a chat note says so. The reset time comes from the daily Endeavors timer. If that isn't available, the addon uses 03:00 UTC on EU and 10:00 UTC on NA. Dark Brotherhood contracts can be repeated right away, so they have no daily limit.

- **Elder Scroll Missions** (toggle, off by default): when someone from your alliance is carrying an Elder Scroll in your campaign, missions from your Grand Warlord for other scrolls are abandoned, so you end up with the one already on its way to a keep. If nobody is carrying one (or only scrolls you've already done today), any mission is kept.
- **Accept quests automatically** (optional): opening the Marked for Death ledger, talking to Battlemaster Rivyn or using a Bounty / Conquest Missions board accepts the quest straight away, so you only press the interact key. With Elder Scroll Missions on, Elder Scroll missions from your Grand Warlord are accepted too (his other quests are left to you). Unwanted quests are still abandoned; interact again for another one.
- **Skip dialogue in Cyrodiil** / **Skip dialogue in Imperial City** (two separate toggles, off by default): in that zone, talking to a quest giver or using a mission board goes straight through. A finished repeatable quest is turned in and a new quest offer is accepted. The game doesn't say whether an offer is a daily before you accept it, so every offer in the zone is accepted; turn-ins only happen for repeatable quests. A turn-in whose reward would go over a currency cap (e.g. Tel Var stones) is left to you.
- Chat messages start with `[AAQ]` and show Abandoned (red) for every abandoned quest and Accepted (green) for every quest you wanted. **Show accepted quests** turns the green ones off; notes about an unwanted quest that was kept anyway are always shown.
- Hold **Shift** while accepting a quest to keep it anyway, or while interacting to skip auto-accept.
- *Contract: Kvatch* (the first Dark Brotherhood contract, part of the story) and *For Glory* (the Battleground introduction) are never abandoned.
- `/aaq` opens the settings. `/aaq info` shows which of the daily quests the current character has turned in today, and which Elder Scrolls your alliance is carrying.

Limitations: quest names are matched in English, so it only works with the English client. Turn-ins are only recorded while the addon is enabled.

Based on [Auto Abandon Not Killing Spree Contracts](https://www.esoui.com/downloads/info4481-AutoAbandonNotKillingSpreeContracts.html) by @Furious_Sniper, whose idea this was and who gave it his blessing. Disable that addon when you use this one.
