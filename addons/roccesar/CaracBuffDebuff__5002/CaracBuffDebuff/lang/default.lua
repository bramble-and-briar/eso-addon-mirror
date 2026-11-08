-- Default strings (English). Other languages override them with SafeAddString in lang/<code>.lua

ZO_CreateStringId("CARACBUFFDEBUFF_GEAR_TIP", "Panel settings.")
SafeAddVersion(CARACBUFFDEBUFF_GEAR_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_ACCOUNT_LABEL", "Account-wide settings.")
SafeAddVersion(CARACBUFFDEBUFF_ACCOUNT_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_ACCOUNT_TIP", "Checked: panel position and settings are shared account-wide; Unchecked: panel position and settings are specific to this character.")
SafeAddVersion(CARACBUFFDEBUFF_ACCOUNT_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_PLAYERBUFFS_LABEL", "Show the player's buffs.")
SafeAddVersion(CARACBUFFDEBUFF_PLAYERBUFFS_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_PLAYERBUFFS_TIP", "Checked: shows all of the player's buffs; Unchecked: does not show the player's buffs.")
SafeAddVersion(CARACBUFFDEBUFF_PLAYERBUFFS_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_HAWKEYE_LABEL", "Hawk Eye (bow).")
SafeAddVersion(CARACBUFFDEBUFF_HAWKEYE_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_HAWKEYE_TIP", "Checked: the Hawk Eye (bow) passive buff is shown in a different color, even if 'Show the player's buffs' is unchecked, and the color changes when the maximum stack count is reached. Unchecked: it is shown like the other buffs.")
SafeAddVersion(CARACBUFFDEBUFF_HAWKEYE_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_OTHERSBUFFS_LABEL", "Show buffs from other players.")
SafeAddVersion(CARACBUFFDEBUFF_OTHERSBUFFS_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_OTHERSBUFFS_TIP", "Checked: shows all buffs given by other players; Unchecked: does not show buffs given by other players.")
SafeAddVersion(CARACBUFFDEBUFF_OTHERSBUFFS_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_FOODDRINK_LABEL", "Food & drink buffs.")
SafeAddVersion(CARACBUFFDEBUFF_FOODDRINK_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_FOODDRINK_TIP", "Checked: shows the food or drink buff; Unchecked: does not show the food or drink buff.")
SafeAddVersion(CARACBUFFDEBUFF_FOODDRINK_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_LONGBUFFS_LABEL", "Long buffs.")
SafeAddVersion(CARACBUFFDEBUFF_LONGBUFFS_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_LONGBUFFS_TIP", "Checked: shows long buffs; Unchecked: does not show long buffs.")
SafeAddVersion(CARACBUFFDEBUFF_LONGBUFFS_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_VAMPLYCAN_LABEL", "Vampirism & Lycanthropy.")
SafeAddVersion(CARACBUFFDEBUFF_VAMPLYCAN_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_VAMPLYCAN_TIP", "Checked: shows the vampirism level and lycanthropy; Unchecked: shows neither vampirism nor lycanthropy.")
SafeAddVersion(CARACBUFFDEBUFF_VAMPLYCAN_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_MUNDUS_LABEL", "Mundus Stone.")
SafeAddVersion(CARACBUFFDEBUFF_MUNDUS_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_MUNDUS_TIP", "Checked: shows the Mundus Stone; Unchecked: does not show the Mundus Stone.")
SafeAddVersion(CARACBUFFDEBUFF_MUNDUS_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_ESOPLUS_LABEL", "ESO Plus subscription.")
SafeAddVersion(CARACBUFFDEBUFF_ESOPLUS_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_ESOPLUS_TIP", "Checked: shows the ESO Plus subscription if it is active; Unchecked: does not show it.")
SafeAddVersion(CARACBUFFDEBUFF_ESOPLUS_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_PERMOTHERS_LABEL", "Other permanent effects.")
SafeAddVersion(CARACBUFFDEBUFF_PERMOTHERS_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_PERMOTHERS_TIP", "Checked: shows other permanent effects (passives, mythics); Unchecked: does not show them.")
SafeAddVersion(CARACBUFFDEBUFF_PERMOTHERS_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_SHOWDEBUFFS_LABEL", "Show debuffs.")
SafeAddVersion(CARACBUFFDEBUFF_SHOWDEBUFFS_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_SHOWDEBUFFS_TIP", "Checked: shows all debuffs; Unchecked: does not show debuffs.")
SafeAddVersion(CARACBUFFDEBUFF_SHOWDEBUFFS_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_TAUNT_LABEL", "Taunt (special color).")
SafeAddVersion(CARACBUFFDEBUFF_TAUNT_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_TAUNT_TIP", "Checked: the Taunt debuff on the target is shown in a different color, even if 'Show debuffs' is unchecked; Unchecked: it is shown like the other debuffs.")
SafeAddVersion(CARACBUFFDEBUFF_TAUNT_TIP, 1)

ZO_CreateStringId("CARACBUFFDEBUFF_RESET_LABEL", "Reset")
SafeAddVersion(CARACBUFFDEBUFF_RESET_LABEL, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_RESET_TIP", "Resets the panel to its original position and the checkboxes to their initial values.")
SafeAddVersion(CARACBUFFDEBUFF_RESET_TIP, 1)

-- Decimal separator for durations (6.3)
ZO_CreateStringId("CARACBUFFDEBUFF_DECIMAL", ".")
SafeAddVersion(CARACBUFFDEBUFF_DECIMAL, 1)

-- /caracids and /caracidscible commands
ZO_CreateStringId("CARACBUFFDEBUFF_TAG_LYCAN", "[LYCANTHROPY]")
SafeAddVersion(CARACBUFFDEBUFF_TAG_LYCAN, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_TAG_VAMP", "[VAMPIRISM]")
SafeAddVersion(CARACBUFFDEBUFF_TAG_VAMP, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_TAG_FOOD", "[FOOD]")
SafeAddVersion(CARACBUFFDEBUFF_TAG_FOOD, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_TAG_LONG", "[LONG]")
SafeAddVersion(CARACBUFFDEBUFF_TAG_LONG, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_TAG_PERM", "[PERMANENT]")
SafeAddVersion(CARACBUFFDEBUFF_TAG_PERM, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_IDS_FORMAT", "%s : %s (stacks: %d, remaining: %ds, total duration: %ds) %s%s")
SafeAddVersion(CARACBUFFDEBUFF_IDS_FORMAT, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_TARGET_PROMPT", "Aim at the target: reading in 5 seconds...")
SafeAddVersion(CARACBUFFDEBUFF_TARGET_PROMPT, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_TARGET_NONE", "No target aimed at.")
SafeAddVersion(CARACBUFFDEBUFF_TARGET_NONE, 1)
ZO_CreateStringId("CARACBUFFDEBUFF_TARGET_FORMAT", "%s : %s (type: %s, cast by me: %s, stacks: %d, remaining: %ds) %s")
SafeAddVersion(CARACBUFFDEBUFF_TARGET_FORMAT, 1)