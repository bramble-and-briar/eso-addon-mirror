# Implementation references

- ESO UI API reference and in-game data: companion collectible reference IDs,
  GetCompanionIntroQuestId, HasCompletedQuest, journal conditions, rapport APIs,
  companion inventory bag, companion skill lines and hotbar, achievement rewards.
- ESO game UI source: https://github.com/esoui/esoui
- Official companion systems/progression:
  https://forums.elderscrollsonline.com/en-gb/discussion/576619/xbox-patch-notes-v1-24-2-0-blackwood-update-30
- Official permanent-perk explanation:
  https://help.elderscrollsonline.com/app/answers/detail/a_id/70494/
- Quest identifier cross-check, dataset rather than bundled code:
  https://github.com/hatedman95/LibQuestData/blob/master/quest_names/LibQuestData_QuestNames_en.lua

Story-title mappings are verified against actual GetQuestName results at runtime;
unknown titles are not assigned fabricated numeric identifiers. The addon does
not include, modify, or require any other author's addon code.
