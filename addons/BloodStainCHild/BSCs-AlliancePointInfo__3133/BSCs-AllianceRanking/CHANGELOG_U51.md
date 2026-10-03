# BSCs-AllianceRanking 2.3.35-u51

## 2.3.35-u51
- Fixed Veterancy cap calculations so rank 100 is treated as the final rank and not as another required progress tier.
- Veterancy Ranking now stops adding "You need" progress at rank 100.
- Veterancy total progress bars now calculate max progress only up to the tier before rank 100.

## 2.3.34-u51
- Updated manifest/API version for Update 51 only.
- Removed API 101050 from the manifest.
- Made the Settings panel background transparent.
## 2.3.33-u51
- Updated manifest/API version for Update 51.


## 2.3.30-u50
- Replaced the native HUD backdrop edge rendering with four solid texture edges so the selected Edge Color fills the complete configured Edge Size.
- Avoided SetEdgeTexture for HUD edge scaling because decorative backdrop edge textures only tint part of the border at larger sizes.

## 2.3.28-u50
- Fixed HUD Bar Edge Size application by using the native backdrop edge-size call pattern: `SetEdgeTexture(nil, 0, 0, edgeSize, 0)`.
- Kept AP HUD default color green and preserved Center/Edge Color handling via `SetCenterColor` / `SetEdgeColor`.

# 2.3.24-u50
- Added HUD bar appearance settings for AP and Veterancy HUD bars.
- Added shared HUD bar opacity and edge size settings.
- Added separate AP HUD bar and Veterancy HUD bar color settings.


## 2.3.15-u50

- Removed the settings menu hint text from the custom Settings tab.


## 2.3.6-u50

- Moved the complete custom Alliance Ranking layout up by 40px.
- Meter container offsetY changed from 68 to 28.
- Navigation/content offsetY changed from 142 to 102.


## 2.3.5-u50

- Moved AP/Veterancy meters into a full-width top container.
- Navigation and right-side views now start below the meter container.
- Meter widths are now calculated dynamically from the available scene width.

# BSCs-AllianceRanking U50 Patch Notes

## 2.3.1-u50

- Fixed ESO runtime error when opening the new single top tab.
- CampaignTierView, CampaignAPView and CampaignVeterancyView remain TopLevelControls parented to GuiRoot; they are now only anchored to the custom content area.
- Sub views are hidden explicitly when the BSCs-AllianceRanking scene hides, because they are no longer child controls of the main tab container.

# BSCs-AllianceRanking 2.1.0-u50

Static Update 50 compatibility pass. Not runtime-tested in ESO.

## Changed
- Updated manifest to API 101050.
- Reworked campaign overview integration for Update 50: the addon now injects AP Ranking and Char Tier Info into `ZO_CAMPAIGN_OVERVIEW_TYPE_INFO` instead of rebuilding the old navigation tree.
- Removed the old `CAMPAIGN_OVERVIEW:ChangeCategory` hook path, which is no longer valid in Update 50.
- Uses ESO rank point API for AP rank table and max-rank progress instead of relying only on hardcoded totals.
- Added saved-variable migration/default helper so missing `TRO_Y` and future defaults are filled safely.
- Added guards for missing/zero assigned campaign data.
- Fixed AP bonus equipment reset when no shoulder item is equipped and guarded against division by zero.
- Fixed wrong event unregister in the AP buff tracker.
- Reduced AP buff UI update interval from 200 ms to 500 ms.
- Fixed XML anchor pointing to a non-existing `$(parent)Frame2`.
- Fixed XML typo `aplha` -> `alpha`.

## Note
The new top-level Veterancy tab in Update 50 is scene-group based and more fragile to inject into than the campaign overview category tree. This patch keeps the addon inside the campaign overview list for stability.


## 2.2.0-u50

- Added two native Alliance War top tabs for the addon pages:
  - AP Ranking
  - Char Tier Info
- The addon pages are now reachable from the Alliance War top tab bar even if no home campaign is selected.
- Kept the Update 50 Campaign Overview category integration as fallback/secondary access.


## 2.3.0-u50

- Replaced the two Alliance War top tabs with one top tab: `BSCs-AllianceRanking`.
- Added internal left-side tabs: `Char Tier Info`, `AP Ranking`, `Veterancy Ranking`.
- Added `Veterancy Ranking`, using the active AVA Veterancy reward track/rank progress data.
- Disabled automatic injection of the old Campaign Overview fallback categories during player activation to avoid duplicate navigation.


## 2.3.3-u50

- Fixed the single top-tab layout.
- Reverted the bad GuiRoot anchoring from 2.3.2.
- The custom main view now uses the native `ZO_RightPanelFootPrint` layout.
- Left subtabs use the same base position as the campaign overview category list.
- The content area uses the same offsets as `ZO_CampaignOverviewSubwindow`, so AP/Tier/Veterancy views are no longer pushed too far right.


## 2.3.4-u50

- Added two progress bars to the custom `BSCs-AllianceRanking` Alliance War top tab:
  - Alliance Rank/AP total progress from 0 to max AvA rank.
  - Veterancy total season progress with turquoise bar.
- Moved the left subtab navigation 10px further left.
- Widened the right content panel by moving it 30px left.


## 2.3.8-u50

- Restricted the AP Bonus Info window to the custom Settings subtab only.
- Prevented the old HUD/AvA visibility callbacks from showing AP Bonus Info outside the Settings page.

## 2.3.7-u50
- Added native Settings subtab inside the BSCs-AllianceRanking Alliance War tab.
- Removed LibAddonMenu dependency from the manifest.
- Moved existing AP/Buff/HUD bar settings into the new in-panel settings page.

## 2.3.9-u50
- Added new `PvP Styles` subtab below `AP Ranking`.
- Replaced old `bgstylesview.lua/xml` with a native Alliance-War-tab view.
- Removed per-collectible hard-coded IDs for PvP style pages. The new view scans Collections outfit-style data dynamically and filters PvP styles by style/source text.
- PvP style rows show unlocked/total counts; missing pieces are red and have collectible tooltips.


## 2.3.10-u50

- Reworked PvP Styles to use manual ID tables instead of automatic PvP detection.
- Added internal PvP Styles subtabs: Cyrodiil, Imperial City, Battleground.
- Rebuilt the PvP Styles layout closer to BattlegroundCoffers_HM: style-name rows with collectible icons.
- Added private helper function `/bscarstyleids` / `BSCAllianceRanking:DumpPvPStyleCandidateIds()` to print candidate collectible IDs filtered by Cyrodiil, Imperial City and Battleground source text.


## 2.3.12-u50
- Added Veterancy tab to PvP Styles.
- Added Veterancy keyword bucket to /bscarstyleids dump.

# BSCs-AllianceRanking 2.3.20-u50

- Added the current AvA rank number to the AP to Next Rank HUD bar label.
- Fixed the Settings tab "Preview Buff UI" button so it can show the Buff UI preview even outside Cyrodiil, without adding the HUD scene fragments.


## 2.3.22-u50
- Removed the native campaign leaderboard query wrapper.
- Disabled automatic campaign queries on login and Cyrodiil activation.
- Guarded LowPop/LowScore event handling so it does not run while the Alliance War UI is open or outside Cyrodiil.
