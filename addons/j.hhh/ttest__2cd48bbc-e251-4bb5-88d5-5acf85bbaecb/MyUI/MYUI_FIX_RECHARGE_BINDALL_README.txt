Console hotfix:
- BindAll: absent BAG_DELETE and other BAG_* constants do not crash at addon load.
- Auto Recharge and Repair: only two checkboxes in My UI. Fixed 5% threshold, never during combat.
- Old saved percentages and combat toggles are normalized on addon load.
- Existing other My UI features remain unchanged.

Console runtime validation is still required.

2026-11-25: 2 additional opt-in checkboxes in 19 Auto Recharge & Repair:
- Crown repair kits allowed (default OFF; old settings retained if already explicitly allowed).
- Impresario group repair kits allowed (default OFF), only grouped/out of combat, <=5%, last resort if no normal repair kits.
Both settings leave charging and repair thresholds fixed at <=5%.
