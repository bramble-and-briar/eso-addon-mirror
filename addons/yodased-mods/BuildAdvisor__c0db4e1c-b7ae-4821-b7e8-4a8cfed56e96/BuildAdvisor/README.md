# ESO Build Advisor (PS5-first)

Examines the character as it is (gear, stats, mundus, champion points, skills) and says what to keep and what to change for the role and activity the player wants. Works on any build, including theorycrafted ones that aren't working.

## Packaging
- `BuildAdvisor.addon` is the console manifest. **Lua scripts remain `.lua` files.**
- **No XML.** Console addons cannot ship GuiXml or Bindings.xml; all controls are created in Lua, and there are no addon keybinds.
- Requires **LibConsoleMenu** (`## ConsoleDependsOn`).
- Exact path/filename capitalization is essential on PlayStation.
- Packaging and upload require Bethesda's console developer uploader. Its validation rules and the required current `## APIVersion` should be confirmed before publishing.
- `## APIVersion: 101050 101051` (live as of Sept 2026). Confirm in game with `/script d(GetAPIVersion())` and bump each major update.

## Using it
- The menu lives in **Settings > Addons > Build Advisor** (LibConsoleMenu, same pattern as PullCard). Everything is read by highlighting a row; pressing rows does nothing, since the tooltip is already showing.
- **Role** and **Activity** pickers (saved per character). "Auto (guess)" guesses role from gear and activity from location.
- Analysis rows: **Summary** (top 3 changes), **Group Support**, **Damage**, **Survivability**, **Gear & Traits**, **Mundus & Champion**. Every highlight rescans, so gear swaps show up immediately.
- Submenus: **Character Scan** (the raw data), **Reference Builds**, **Gear Sources**, **Settings**.
- `/buildadvisor` or `/badv` shows the Summary as a native gamepad dialog (◯ closes it; confirmed on PS5).

## How the advisor works
1. `Systems/CharacterScanner.lua` reads gear (sets, traits, enchants, weights), stats, attributes, mundus, slotted CP and both skill bars. Each section is read separately, so one console-private API can't break the rest.
2. `Systems/Advisor.lua` picks the role and activity (player's pick, or guessed) and runs the checks.
3. Targets live in `Data/Targets/`, one file per content tier so each can be kept up to date with the meta (each file header says which patch it was last checked against). Each file registers its activities; manifest order is the picker order.
   - `Common.lua`: shared buff values (Major/Minor Breach, Crusher), resistance cap, field docs.
   - `Solo.lua` (overland, solo arena, Infinite Archive solo/duo), `FourManPug.lua`, `FourManOrganized.lua`, `FourManTrifecta.lua`, `TwelveManPug.lua`, `TwelveManOrganized.lua`, `TwelveManScore.lua`, `PvP.lua`.
   - Each tier lists the debuffs a group can be assumed to keep up (`BA.DEBUFFS` in `Common.lua`); penetration and status counts are worked out from that list.
     - PUG (4- and 12-man): Major Breach, Sundered (Minor Breach), Crusher, Off Balance, Bleeding, Burning. Crusher comes from the tank in 4-man and the off tank in 12-man; tanks are checked for a Crusher weapon enchant.
     - Known comp / trifecta / score: the PUG set plus Brittle, Chilled, Diseased, Poisoned (score adds an estimate for extra debuff sets).
   - Penetration target = enemy resistance (8,000 overland, 18,200 veteran/solo) minus the group's debuff penetration, minus Force of Nature (penetration per status effect) when the player has it slotted. Above the target is wasted and should move into crit and damage.
   - Off Balance assumed → suggest the Exploiter CP star; Brittle/Chilled → note that less self crit damage is needed for the 125% cap.
   - Auto-guess picks the PUG tier in veteran instances (location can't tell PUG from organized); players pick Organized / Trifecta / Score themselves.
   - Health ranges per role. A tank above the max with no group-support sets is flagged as a selfish setup and pointed at support sets and debuff skills.
   - Resistance targets (tank cap 33,100; PvP minimums).
4. `Data/Tags.lua` tags sets and skills as group support or selfish, plus mundus advice per role.

All numbers and tag lists are starting values that need checking against the current patch.

## Console findings
- `IsKeyDown` is private and no other button-state query exists, so D-pad/face-button combos are impossible without keybinds. Trigger magnitudes are readable, but an L2 + R2 hold was dropped because it's bash in combat.
- Pushing the `UIShortcuts` layer + a `KEYBIND_STRIP` group did not make ◯ work; the native gamepad dialog does.
- Walking `_G` errors on console when it reaches a private function.

## Remaining milestones
1. Confirm on PS5 which scan sections read correctly (Character Scan rows).
2. Validate the target numbers, set/skill tags and mundus buff IDs in game; extend the tag lists. Check: Force of Nature's per-status value, which effects it counts (Off Balance? Brittle?), and whether it and Exploiter are slottable stars (the advisor only sees slotted stars).
3. Effective penetration per attack (class and staff passives), crit damage (not readable from the sheet yet).
4. More activities: normal dungeons/trials, Battlegrounds, Imperial City, trial dummy, farming.
5. Consider porting the native dialog popup to PullCard.

Roles: Damage, Tank, Healer (PvP may add ganker / brawler / support).

## Design decisions
- No automatic equipping, inventory manipulation, network traffic, external links, or click-only interactions.
- Do not score solo builds from trial dummy expectations.
- No fabricated overall score: findings are specific changes with reasons.
- Set compositions and acquisition strings are preliminary; all require in-game validation.

## Reference
Bethesda console developer uploader: https://help.bethesda.net/app/answers/detail/a_id/69621/
