-- CaracTracker : English strings (default language, loaded first)
-- Each string is created once here (ZO_CreateStringId) and registered at version 1.
-- Other languages (fr.lua, ...) only override them with SafeAddString(..., version 2).

local function Add(id, text)
    ZO_CreateStringId(id, text)
    SafeAddVersion(_G[id], 1)
end

---------------------------------------------------------------
-- Interface
---------------------------------------------------------------
Add("CARACTRACKER_UI_YES",       "Yes")
Add("CARACTRACKER_UI_NO",        "No")
Add("CARACTRACKER_UI_NA",        "N/A")
Add("CARACTRACKER_UI_COLON",     ":")          -- added after each label (French uses " :")
Add("CARACTRACKER_UI_TIMEFMT",   "[%H:%M]")    -- os.date format of the clock
Add("CARACTRACKER_UI_GEAR",      "Choose the stats to display")
Add("CARACTRACKER_UI_OPAC_UP",   "Increase opacity")
Add("CARACTRACKER_UI_OPAC_DOWN", "Decrease opacity")

---------------------------------------------------------------
-- Labels (short, to keep the panel narrow)
---------------------------------------------------------------
Add("CARACTRACKER_L_INCOMBAT",   "In combat")
Add("CARACTRACKER_L_DPS",        "DPS")
Add("CARACTRACKER_L_HPS",        "HPS")
Add("CARACTRACKER_L_HPSRAW",     "Raw HPS")

Add("CARACTRACKER_L_POWERP",     "Weapon Dmg.")
Add("CARACTRACKER_L_POWERM",     "Spell Dmg.")

Add("CARACTRACKER_L_PENP",       "Phys. Pen.")
Add("CARACTRACKER_L_PENM",       "Spell Pen.")

Add("CARACTRACKER_L_CRITP",      "Weapon Crit. %")
Add("CARACTRACKER_L_CRITM",      "Spell Crit. %")
Add("CARACTRACKER_L_CRITDMG",    "+ Crit. Dmg.")

Add("CARACTRACKER_L_MAGREGEN",   "Magicka Rec.")
Add("CARACTRACKER_L_HEALTHREGEN","Health Rec.")
Add("CARACTRACKER_L_STAMREGEN",  "Stamina Rec.")

Add("CARACTRACKER_L_CRITHEAL",   "+ Crit. Heal.")
Add("CARACTRACKER_L_HEALDONE",   "+ Heal Done")
Add("CARACTRACKER_L_HEALTAKEN",  "+ Heal Taken")

Add("CARACTRACKER_L_BLOCK",      "Block Mitig.")
Add("CARACTRACKER_L_BLOCKCOST",  "Block Cost")
Add("CARACTRACKER_L_BASHDMG",    "Bash Dmg.")
Add("CARACTRACKER_L_BASHCOST",   "Bash Cost")

Add("CARACTRACKER_L_SPELLRES",   "Spell Resist.")
Add("CARACTRACKER_L_SPELLABS",   "Spell Mitig.")
Add("CARACTRACKER_L_PHYSRES",    "Phys. Resist.")
Add("CARACTRACKER_L_PHYSABS",    "Phys. Mitig.")
Add("CARACTRACKER_L_CRITRES",    "Crit. Resist.")
Add("CARACTRACKER_L_CRITABS",    "Crit. Mitig.")

Add("CARACTRACKER_L_SHIELD",     "Shield")

Add("CARACTRACKER_L_SPRINT",     "Sprint Speed")
Add("CARACTRACKER_L_SNEAK",      "Sneak Speed")

---------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------
Add("CARACTRACKER_T_INCOMBAT",    "Shows whether the player is in combat. While in combat, you cannot use your mount, open a chest, etc.")

Add("CARACTRACKER_T_DPS",         "Damage per second of the last fight (player & pets).")
Add("CARACTRACKER_T_HPS",         "Healing per second of the last fight (player & pets) without overhealing: if the target is at 100% health, the healing is not counted.")
Add("CARACTRACKER_T_HPSRAW",      "Healing per second of the last fight (player & pets) with overhealing: excess healing is counted, so the value will be inflated when several targets are at full health.")

Add("CARACTRACKER_T_POWERP",      "Weapon Damage.")
Add("CARACTRACKER_T_POWERM",      "Spell Damage.")
Add("CARACTRACKER_T_PENP",        "Physical Penetration.")
Add("CARACTRACKER_T_PENM",        "Spell Penetration.")

Add("CARACTRACKER_T_CRITP",       "Weapon Critical chance.")
Add("CARACTRACKER_T_CRITM",       "Spell Critical chance.")
Add("CARACTRACKER_T_CRITDMG",     "Additional critical damage bonus.")

Add("CARACTRACKER_T_MAGREGEN",    "Magicka Recovery.")
Add("CARACTRACKER_T_HEALTHREGEN", "Health Recovery.")
Add("CARACTRACKER_T_STAMREGEN",   "Stamina Recovery.")

Add("CARACTRACKER_T_CRITHEAL",    "Additional critical healing bonus.")
Add("CARACTRACKER_T_HEALDONE",    "Healing Done bonus.")
Add("CARACTRACKER_T_HEALTAKEN",   "Healing Taken bonus.")

Add("CARACTRACKER_T_BLOCK",       "Percentage of damage blocked.")
Add("CARACTRACKER_T_BLOCKCOST",   "Cost of blocking.")
Add("CARACTRACKER_T_BASHDMG",     "Bash damage.")
Add("CARACTRACKER_T_BASHCOST",    "Cost of bashing.")

Add("CARACTRACKER_T_SPELLRES",    "Spell Resistance. The resistance cap is reached at 33,000.")
Add("CARACTRACKER_T_PHYSRES",     "Physical Resistance. The resistance cap is reached at 33,000.")
Add("CARACTRACKER_T_CRITRES",     "Resistance to critical strikes from enemy players. The resistance cap is reached at 3,300.")

Add("CARACTRACKER_T_SPELLABS",    "Spell damage reduction (mitigation), calculated from Spell Resistance. Capped at 50%.")
Add("CARACTRACKER_T_PHYSABS",     "Physical damage reduction (mitigation), calculated from Physical Resistance. Capped at 50%.")
Add("CARACTRACKER_T_CRITABS",     "Critical damage reduction (mitigation), calculated from Critical Resistance. Capped at 50%.")

Add("CARACTRACKER_T_SHIELD",      "Total of all damage shields. It works like a second health bar.")

Add("CARACTRACKER_T_SPRINT",      "Sprint speed bonus.")
Add("CARACTRACKER_T_SNEAK",       "Movement speed while sneaking.")
