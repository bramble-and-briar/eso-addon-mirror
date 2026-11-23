# Survey Sidekick 0.6.0

Developed with AI-assisted coding and documentation using OpenAI ChatGPT.
Author and maintainer: FoulMouthxAmazon. See CREDITS.md for acknowledgments.

## Install or update

Replace the existing SurveySidekick folder in your ESO live/AddOns directory
with the SurveySidekick folder from this ZIP. Keep your SavedVariables.
Use /reloadui after updating. Do not install multiple copies of the addon.

## Surveys and treasure maps

Use /surveys to open the manager. Click a zone to expand its surveys and maps.
Filter by item type, storage or survey type; Reset Filters shows everything again.
Unidentified surveys and unopened treasure maps appear in their own group.
Open those containers manually from your backpack to identify them.

Select an item to see its available actions. Hint shows details. Open Survey /
Open Map shows the carried item's original picture. Map Pin marks its location.
The coin previews travel cost; the wayshrine travels to the nearest unlocked
wayshrine at normal ESO cost. Location actions require LibTreasure data.
Withdraw bank-only items before opening or traveling with them. Open your bank
to update its last-seen snapshot; closed-bank counts are not live.

Treasure Detour lists carried treasure maps in the selected survey's zone.
It does not calculate a route or automatically open items.

## Track a run

Open Current Run (bag icon in the journal). Play starts or resumes, Pause pauses,
and Stop finishes and saves the report. Optional material goals track gathering.
All item drops received during an active run are recorded: materials are kept
separate from Other Loot, including gear, recipes and motifs. Start your run
before opening treasure chests. Gold currency is not part of item-loot totals.

The Hoard Report keeps the last 30 runs and supports copying, detailed exports
and comparisons. Petty Accountant compares materials, time and estimated values.
Commentary On/Off controls its 32 rotating sayings. Historical runs cannot gain
loot that was never recorded. Survey/Large classifications and gold values are
estimates; unusually large regular drops may be included. Unpriced items are
excluded from value estimates. TTC estimates are not actual sale proceeds.

## Extended Journal (optional)

With LibExtendedJournal enabled, use /surveys journal or select Survey Sidekick
inside Extended Journal. Its pages use a fixed native presentation with no color,
opacity or size controls. Back returns from utility pages. ESO's Exit leaves the
journal. Standalone appearance settings do not change the journal layout.
LibExtendedJournal is also supplied by some addons, including Loot Log and
Collectibles Tracker. No third-party library code is bundled here.

## Standalone appearance

The standalone Colors & Size menu has color presets, independent Background
Opacity and Button Opacity sliders, and size controls. Minimize keeps tracking.
Settings save per character. Recovery commands:
/surveys opacity 100 — restore background opacity
/surveys buttons 100 — restore button opacity
/surveys scale 80 — restore default standalone size

## Commands

/surveys — standalone manager
/surveys journal — Extended Journal tab (when available)
/surveys inventory — survey and map list
/surveys start, /surveys pause, /surveys finish — run controls
/surveys detour — treasure detours
/surveys compare — run comparisons
/surveys colors — standalone appearance menu
/surveys help — instructions
/surveyport — travel using the selected carried item

Optional libraries: LibTreasure for locations; Tamriel Trade Centre for prices;
LibExtendedJournal for journal integration. Each is installed separately.
Automated checks passed; compatibility with every addon combination still
depends on in-game testing. Report errors with the full stack and addon version.
