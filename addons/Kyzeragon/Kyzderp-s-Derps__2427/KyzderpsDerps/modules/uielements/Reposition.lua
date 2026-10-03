KyzderpsDerps = KyzderpsDerps or {}
KyzderpsDerps.UIElements = KyzderpsDerps.UIElements or {}
local UIE = KyzderpsDerps.UIElements

--[[
/script
local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", ZO_LootHistoryControl_Keyboard, CT_BACKDROP)
bg:SetAnchorFill(ZO_LootHistoryControl_Keyboard)
bg:SetCenterColor(0, 0, 0, 0.5)
bg:SetEdgeColor(0,0,0,1)
]]
local function Reposition()

    -- Attributes: move health up a bit to put stam and mag in pyramid
    ZO_PlayerAttributeHealth:SetAnchor(CENTER, ZO_PlayerAttribute, CENTER, 0, -33)
    ZO_PlayerAttributeStamina:SetAnchor(LEFT, ZO_PlayerAttribute, CENTER, 2, -6)
    ZO_PlayerAttributeMagicka:SetAnchor(RIGHT, ZO_PlayerAttribute, CENTER, -2, -6)

    -- Loot History: move up above minimap
    if (ZO_LootHistoryControl_Keyboard) then
        ZO_LootHistoryControl_Keyboard:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, -290)
    end

    -- Synergies: move up a bit
    ZO_SynergyTopLevelContainer:SetAnchor(BOTTOM, ZO_SynergyTopLevel, BOTTOM, 0, -300)

    -- Player Interaction: move up a bit
    ZO_PlayerToPlayerAreaPromptContainer:SetAnchor(BOTTOM, ZO_PlayerToPlayerArea, BOTTOM, 0, -350)

    -- Subtitles: is anchored to ZO_PlayerToPlayerAreaPromptContainerTarget so should be fine

    -- Ram Siege: move up a bit
    ZO_RamTopLevel:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -300)

    -- AvA Meter
    ZO_ObjectiveCaptureMeter:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -300)

    -- Combat Tips
    ZO_ActiveCombatTipsTip:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -300)
end
UIE.Reposition = Reposition -- /script KyzderpsDerps.UIElements.Reposition()

local function ToggleQuestPanel()
    local isInTrial = KyzderpsDerps.TRIAL_ZONEIDS[tostring(GetZoneId(GetUnitZoneIndex("player")))] ~= nil

    SetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER, isInTrial and "false" or "true", SETTINGS_SET_OPTION_DO_NOT_SAVE_TO_PERSISTED_DATA)
    -- ZO_FocusedQuestTrackerPanel:SetHidden(isInTrial)
end

function UIE.Initialize()
    -- Personal UI elements repositioning
    -- if (KyzderpsDerps.savedOptions.ui.reposition) then
    --     Reposition()
    --     ZO_PlatformStyle:New(Reposition)
    -- end

    -- Hiding quest tracker while in a trial
    if (KyzderpsDerps.savedOptions.ui.hideQuestInTrial) then
        EVENT_MANAGER:RegisterForEvent(KyzderpsDerps.name .. "UIEActivated", EVENT_PLAYER_ACTIVATED, ToggleQuestPanel)
    else
        EVENT_MANAGER:UnregisterForEvent(KyzderpsDerps.name .. "UIEActivated", EVENT_PLAYER_ACTIVATED)
    end
    ToggleQuestPanel()
end

---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
function UIE.GetSettings()
    return {
        {
            type = "checkbox",
            name = "Hide quest tracker in trials",
            tooltip = "Hides the quest tracker panel when in any trials. Use |c99FF99/kdd questtracker|r to toggle it manually",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.ui.hideQuestInTrial end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.ui.hideQuestInTrial = value
                UIE.Initialize()
            end,
            width = "full",
        },
        -- {
        --     type = "checkbox",
        --     name = "Reposition UI elements KyzerStyle™",
        --     tooltip = "Repositions UI elements to my personal preference. This moves the attribute bars into a pyramid, some elements up a bit to accommodate the pyramid, and loot log up to be above where my minimap is. These positions are hardcoded and likely won't work for everyone, they're intended to be a lightweight way of repositioning elements. If you want to make minor adjustments, you can edit KyzderpsDerps/modules/uielements/Reposition.lua, but you would have to restore the changes every time the addon is updated. If you want to adjust your UI more, I would recommend an addon like Azurah instead",
        --     default = false,
        --     getFunc = function() return KyzderpsDerps.savedOptions.ui.reposition end,
        --     setFunc = function(value)
        --         KyzderpsDerps.savedOptions.ui.reposition = value
        --         UIE.Initialize()
        --     end,
        --     width = "full",
        --     requiresReload = true,
        -- },
        {
            type = "checkbox",
            name = "Set specific AOE colors",
            tooltip = "Always sets your enemy AOE colors to be |c00ffffbright cyan|r, except on Lokkestiiz and Pinnacle Factotum, where they are |cc800ffmagenta|r instead. These are my personal preferences for having highly visible colors. If you turn this back off, you'll have to restore your colors manually",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.ui.aoeColors end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.ui.aoeColors = value
                KyzderpsDerps.InitializeAOE()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "In-combat reticle",
            tooltip = "Turn the reticle red while you are in combat",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.misc.combatReticle end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.misc.combatReticle = value
            end,
            width = "full",
        },
    }
end
