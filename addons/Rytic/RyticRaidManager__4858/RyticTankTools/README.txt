Rytic Combat & Raid Tools 3.1.0

AI-assisted development. Rytic maintains and tests this addon in ESO. The new
Action Bar hover, 4-DD team import, and resurrection indicators in this version
still need live validation on the release build.

WHAT'S NEW IN 3.1.0
- Group Frames show DEAD, REZZING, and REZ PENDING with an elapsed pending timer.
  That timer starts when this client first observes the pending resurrection;
  /reloadui starts a fresh local count.
- DD Positions imports genuine two-side 4-DD mechanics into Team A/B, balances
  support roles, and keeps the Rytic/Wifey pair together when not manually set.
  The Raid Lead mechanic menu uses the same selection and import path.
- Group management defaults eligible party members to assistant; the leader
  can revoke or restore access for the current group session.
- Custom Action Bar hover uses full-slot mouse targets and slot assignment
  tooltip lookup, while its visibility follows the Rytic HUD rather than
  native action-bar visibility. Skill, ultimate, and quickslot interactions
  require live testing with ESO's own action bar disabled.
- TankStats Buffs uses a wheel-scrolling, fixed-column list like Debuffs.
- Group Frames no longer scan/display Major Slayer every 250 ms.
- Block HUD shows blocking state and mitigation without block-cost sampling;
  its refresh is 100 ms. RSS numeric labels show values without percentages.

REQUIRED LIBRARIES (install separately)
LibAddonMenu-2.0 >= 43; LibCombat >= 89; LibGroupBroadcast >= 95.
Optional: LibGroupCombatStats for shared DPS; LibGroupUIReload >= 91 for
additional group reload recovery.
Recipients need compatible Rytic versions for shared group state and notices.

INSTALL
With ESO closed, back up the RyticTankTools addon folder and
RyticTankSavedVariables.lua, then replace the folder with this ZIP's
RyticTankTools folder. Do not run two copies. Keep your SavedVariables.

CREDITS
Hyperioxes - Hyper Tanking Tools: reference for shield/resource tracking.
Hoft and secretrob - Bandits User Interface: reference for group frame and
attribute-visualizer behavior. No affiliation is implied.

ZOS DISCLOSURE
This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc.
or its affiliates. The Elder Scrolls® and related logos are registered trademarks
or trademarks of ZeniMax Media Inc. in the United States and/or other countries.
All rights reserved.
https://account.elderscrollsonline.com/add-on-terms
