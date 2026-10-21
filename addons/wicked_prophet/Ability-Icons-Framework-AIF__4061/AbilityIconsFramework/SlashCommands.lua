-- =============================================================================
-- Ability Icons Framework (AIF) - Slash Commands & In-Game Diagnostic Tools
-- =============================================================================
-- Ever spent twenty minutes wondering why your backbar skill icon looks like a
-- 2014 potato while your frontbar looks like 4K IMAX? Or tried to figure out why
-- your newly scribed Trample isn't showing the Flame icon you swore you slotted?
--
-- This file provides the `/aif` chat command suite. It lets players and addon
-- devs inspect action bar slots, see raw ability IDs vs base morph IDs, verify
-- active texture redirection, dump SavedVariables straight to chat, and toggle
-- addon options on the fly without navigating the labyrinth of ESO's settings UI.
-- =============================================================================

--- @class (partial) AbilityIconsFramework
AbilityIconsFramework = AbilityIconsFramework or {}
local AbilityIconsFramework = AbilityIconsFramework

-- -----------------------------------------------------------------------------
-- Localized API Cache: Squeezing every microsecond out of the Lua VM
-- -----------------------------------------------------------------------------
local pairs                             = pairs
local tonumber                          = tonumber
local tostring                          = tostring
local zo_strformat                      = zo_strformat
local GetString                         = GetString
local GetActiveHotbarCategory           = GetActiveHotbarCategory
local GetCraftedAbilityActiveScriptIds   = GetCraftedAbilityActiveScriptIds
local GetCraftedAbilityScriptDisplayName = GetCraftedAbilityScriptDisplayName
local GetCraftedAbilityLink             = GetCraftedAbilityLink
local ZO_LinkHandler_CreateChatLink     = ZO_LinkHandler_CreateChatLink
local GetAbilityName                    = GetAbilityName
local GetAbilityIcon                    = GetAbilityIcon
local GetCurrentCharacterId             = GetCurrentCharacterId
local GetDisplayName                    = GetDisplayName

-- -----------------------------------------------------------------------------
-- Internal Chat Helpers
-- -----------------------------------------------------------------------------

--- Prints a formatted message to the player's chat frame with the standard [AIF] prefix.
--- Crucial for making our debug output stand out against the endless wall of
--- Craglorn trial recruitment and Belkarth zone banter.
--- @param text string|number The message payload to output.
local function PrintMsg(text)
    d("[AIF] " .. tostring(text))
end

--- Parses string arguments from chat into valid action bar slot and hotbar category parameters.
---
--- Why default to slot 3? Because ESO action bar slots 1 and 2 are hardcoded internally
--- to Light Attack and Heavy Attack (the sacred twin pillars of weaving). Normal slotted
--- abilities live exclusively in slots 3 through 8 (with 8 being your Ultimate).
---
--- The `inactiveParam` allows inspecting the player's inactive/backup weapon bar
--- without forcing them to manually weapon-swap (and potentially breaking stealth,
--- dropping pre-buffs, or alarming innocent mudcrabs).
---
--- @param slotParam string|nil The slot number passed from chat (e.g. "3", "7"). Defaults to 3.
--- @param inactiveParam string|nil "1" to inspect the backup hotbar, or "0"/nil for the active one.
--- @return number skillIndex The validated slot index (defaults to 3).
--- @return number hotbarCategory The resolved HOTBAR_CATEGORY_PRIMARY or HOTBAR_CATEGORY_BACKUP.
local function ParseSlotAndHotbar(slotParam, inactiveParam)
    local skillIndex = tonumber(slotParam) or 3
    local inactive = inactiveParam or "0"

    local hotbarCategory = GetActiveHotbarCategory()
    if inactive == "1" then
        hotbarCategory = (hotbarCategory == HOTBAR_CATEGORY_PRIMARY) and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
    end

    return skillIndex, hotbarCategory
end

--- Normalizes user-entered boolean strings into true, false, or nil.
--- Players type all manner of things into chat ("on", "1", "false", "potato").
--- We handle common human affirmative and negative variants while cleanly
--- rejecting gibberish.
--- @param option string|nil The chat argument string.
--- @return boolean|nil parsedValue True, false, or nil if invalid input.
local function ParseBooleanOption(option)
    local opt = string.lower(option or "")
    if opt == "false" or opt == "0" or opt == "off" then
        return false
    elseif opt == "true" or opt == "1" or opt == "on" then
        return true
    end
    return nil
end

-- -----------------------------------------------------------------------------
-- Diagnostic Subcommands
-- -----------------------------------------------------------------------------

--- Inspects an action bar slot and dumps diagnostic ability IDs, plus Focus, Signature,
--- and Affix scripts if the slotted skill is a Scribing crafted ability.
---
--- Usage: `/aif details [slotIndex] [isInactive]`
--- Example: `/aif details 3 0` (inspect active bar slot 3)
--- Example: `/aif details 5 1` (inspect backup bar slot 5)
---
--- If the slotted skill is Scribed, this also builds a fully interactive clickable
--- chat link (`ZO_LinkHandler_CreateChatLink`) so you can click it right in chat
--- to verify tooltips, morph costs, or brag to your trial group about your spicy off-meta build.
---
--- @param slotParam string|nil The slot index (3-8).
--- @param inactiveParam string|nil "1" for backbar, "0" for frontbar.
function AbilityIconsFramework.PrintAbilityDetails(slotParam, inactiveParam)
    local skillIndex, hotbarCategory = ParseSlotAndHotbar(slotParam, inactiveParam)

    local baseAbilityId = AbilityIconsFramework.GetBaseAbilityId(skillIndex, hotbarCategory)
    PrintMsg("Base Ability ID: " .. tostring(baseAbilityId or -1))
    local abilityId = AbilityIconsFramework.GetAbilityId(skillIndex, hotbarCategory)
    PrintMsg("Ability ID: " .. tostring(abilityId or -1))

    if abilityId and abilityId > 0 then
        local primaryScriptId, secondaryScriptId, tertiaryScriptId = GetCraftedAbilityActiveScriptIds(abilityId)
        if primaryScriptId ~= 0 or secondaryScriptId ~= 0 or tertiaryScriptId ~= 0 then
            PrintMsg("Focus Script: " .. GetCraftedAbilityScriptDisplayName(primaryScriptId) .. " (" .. primaryScriptId .. ")")
            PrintMsg("Signature Script: " .. GetCraftedAbilityScriptDisplayName(secondaryScriptId) .. " (" .. secondaryScriptId .. ")")
            PrintMsg("Affix Script: " .. GetCraftedAbilityScriptDisplayName(tertiaryScriptId) .. " (" .. tertiaryScriptId .. ")")
            if primaryScriptId ~= 0 and secondaryScriptId ~= 0 and tertiaryScriptId ~= 0 then
                local scriptLink = ZO_LinkHandler_CreateChatLink(GetCraftedAbilityLink, abilityId, primaryScriptId, secondaryScriptId, tertiaryScriptId)
                PrintMsg("Scribed Skill Link: " .. scriptLink)
            end
        end
    end
end

--- Reports the exact texture path assigned to an ability, and checks if it is actively
--- being redirected by AIF or an installed icon pack.
---
--- Usage: `/aif icons [slotIndex] [isInactive]`
---
--- Extremely helpful when an icon isn't behaving and you want to know whether ESO is
--- loading the vanilla `.dds` file or if one of our registered packs redirected it.
---
--- @param slotParam string|nil The slot index (3-8).
--- @param inactiveParam string|nil "1" for backbar, "0" for frontbar.
function AbilityIconsFramework.PrintIcons(slotParam, inactiveParam)
    local skillIndex, hotbarCategory = ParseSlotAndHotbar(slotParam, inactiveParam)

    local abilityId = AbilityIconsFramework.GetAbilityId(skillIndex, hotbarCategory)
    if not abilityId or abilityId <= 0 then
        PrintMsg(zo_strformat(GetString(SI_AIF_SLOT_EMPTY), skillIndex, hotbarCategory))
        return
    end

    local abilityName = GetAbilityName(abilityId)
    local baseTexture = GetAbilityIcon(abilityId)
    PrintMsg("Slot " .. tostring(skillIndex) .. ": " .. tostring(abilityName) .. " (" .. tostring(abilityId) .. ")")
    PrintMsg("  Base Texture: " .. tostring(baseTexture))

    local redirectedTexture = AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE[baseTexture]
    if redirectedTexture then
        PrintMsg("  Redirected to: " .. tostring(redirectedTexture))
    else
        PrintMsg(GetString(SI_AIF_SLOT_REDIRECT_NONE))
    end
end

--- Safely prints active in-memory SavedVariables keys for debugging config corruption.
---
--- Usage: `/aif vars` or `/aif savedvars`
---
--- When a user reports that "settings didn't save," this allows instant triage in chat
--- without forcing them to Alt-Tab, navigate to Documents/Elder Scrolls Online/live/SavedVariables,
--- and decipher raw Lua tables in Notepad while praying ESO doesn't overwrite it on logout.
function AbilityIconsFramework.PrintSavedVars()
    PrintMsg("----------------------------------")
    local displayName = GetDisplayName()

    if AbilityIconsFramework_SavedVariables and AbilityIconsFramework_SavedVariables["Default"] and AbilityIconsFramework_SavedVariables["Default"][displayName] then
        local svAccount = AbilityIconsFramework_SavedVariables["Default"][displayName]["$AccountWide"]
        if svAccount then
            PrintMsg("AbilityIconsFramework_SavedVariables ($AccountWide):")
            for key, value in pairs(svAccount) do
                if type(value) == "table" then
                    PrintMsg("  [" .. tostring(key) .. "] -> (table)")
                else
                    PrintMsg("  [" .. tostring(key) .. "] -> " .. tostring(value))
                end
            end
        end

        local charId = GetCurrentCharacterId()
        local svChar = AbilityIconsFramework_SavedVariables["Default"][displayName][charId]
        if svChar then
            PrintMsg("AbilityIconsFramework_SavedVariables (Character " .. tostring(charId) .. "):")
            for key, value in pairs(svChar) do
                if type(value) == "table" then
                    PrintMsg("  [" .. tostring(key) .. "] -> (table)")
                else
                    PrintMsg("  [" .. tostring(key) .. "] -> " .. tostring(value))
                end
            end
        end
    else
        PrintMsg("SavedVariables have not been written to disk yet.")
    end

    PrintMsg("----------------------------------")
end

-- -----------------------------------------------------------------------------
-- Command Router Registration
-- -----------------------------------------------------------------------------

--- Registers the unified `/aif` slash command handler with ESO's engine.
---
--- Supported subcommands:
--- - `details [slot] [inactive]` : Dumps ability IDs and Scribing scripts
--- - `icons [slot] [inactive]`   : Dumps texture paths and redirection targets
--- - `vars` | `savedvars`        : Inspects SavedVariables state
--- - `global [on|off]`           : Toggles account-wide vs per-character settings
--- - `scribing [on|off]`         : Toggles custom Scribing dynamic icons
--- - `mismatched [on|off]`       : Toggles HD mismatched base-game icon replacements
--- - `reload` | `rl`             : Triggers ReloadUI("ingame") because /rl is every ESO dev's true reflex
function AbilityIconsFramework.CreateSlashCommands()
    SLASH_COMMANDS["/aif"] = function(strInput)
        local params = {}
        for word in (strInput or ""):gmatch("%S+") do
            table.insert(params, word)
        end

        local subCmd = string.lower(params[1] or "")
        if subCmd == "details" then
            AbilityIconsFramework.PrintAbilityDetails(params[2], params[3])
        elseif subCmd == "icons" then
            AbilityIconsFramework.PrintIcons(params[2], params[3])
        elseif subCmd == "vars" or subCmd == "savedvars" then
            AbilityIconsFramework.PrintSavedVars()
        elseif subCmd == "global" then
            local val = ParseBooleanOption(params[2])
            if val ~= nil then
                AbilityIconsFramework.SetOptionGlobalIcons(val)
                PrintMsg("Global (Account Wide) Icons are now " .. (val and "ON" or "OFF"))
            else
                PrintMsg("Usage: /aif global [on|off]")
            end
        elseif subCmd == "scribing" or subCmd == "custom" then
            local val = ParseBooleanOption(params[2])
            if val ~= nil then
                AbilityIconsFramework.SetOptionCustomIcons(val)
                PrintMsg("Custom Scribed Ability Icons are now " .. (val and "ON" or "OFF"))
            else
                PrintMsg("Usage: /aif scribing [on|off]")
            end
        elseif subCmd == "mismatched" then
            local val = ParseBooleanOption(params[2])
            if val ~= nil then
                AbilityIconsFramework.SetOptionMismatchedIcons(val)
                PrintMsg("Mismatched Skill Icon replacements are now " .. (val and "ON" or "OFF"))
            else
                PrintMsg("Usage: /aif mismatched [on|off]")
            end
        elseif subCmd == "reload" or subCmd == "rl" then
            ReloadUI("ingame")
        else
            PrintMsg(GetString(SI_AIF_COMMANDS_HEADER))
            PrintMsg("/aif details [slot] [inactive]")
            PrintMsg("/aif icons [slot] [inactive]")
            PrintMsg("/aif vars")
            PrintMsg("/aif global [on|off]")
            PrintMsg("/aif scribing [on|off]")
            PrintMsg("/aif mismatched [on|off]")
            PrintMsg("/aif reload | rl")
        end
    end
end
