-- ============================================================================
-- ConsoleCPQoL - Fully Automatic Gamepad CP Addon (Sub-Menu & Cluster Fix v1.3)
-- ============================================================================

local ConsoleCPQoL = {}
ConsoleCPQoL.name = "ConsoleCPQoL"

local activeLabels = {}
local labelPool = {}
local isCPUIOpen = false
local SV

-- Default Saved Variables
local defaultSettings = {
    fontColorR = 1.0,
    fontColorG = 0.9,
    fontColorB = 0.2,
    fontColorA = 1.0,
    fontSize = 24,
}

local function ClearPerkLabels()
    for _, label in pairs(activeLabels) do
        if label then
            label:SetHidden(true)
            label:SetText("")
            table.insert(labelPool, label)
        end
    end
    activeLabels = {}
end

local function GetPooledLabel(index)
    local label = table.remove(labelPool)
    if not label then
        local labelName = "ConsoleCPQoL_StarLabel_" .. index
        label = WINDOW_MANAGER:CreateControl(labelName, ZO_ChampionPerksCanvas, CT_LABEL)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawLevel(2)
        label:SetDrawTier(DT_HIGH)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    
    if SV then
        label:SetColor(SV.fontColorR, SV.fontColorG, SV.fontColorB, SV.fontColorA)
    end
    
    return label
end

local function RefreshPerkLabels()
    if not isCPUIOpen then return end
    if not ZO_ChampionPerksCanvas then return end

    ClearPerkLabels()

    local fontSize = (SV and SV.fontSize) or 24
    local fontString = string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", fontSize)

    local childCount = ZO_ChampionPerksCanvas:GetNumChildren()
    local pooledIndex = 1

    for i = 1, childCount do
        local child = ZO_ChampionPerksCanvas:GetChild(i)
        
        if child and child.star and not child:IsHidden() then
            local skillName = nil

            if child.star.championSkillData then
                local id = child.star.championSkillData.championSkillId
                if id then 
                    skillName = GetChampionSkillName(id) 
                end
            elseif child.star.championClusterData and child.star.championClusterData.clusterChildren then
                local firstChild = child.star.championClusterData.clusterChildren[1]
                if firstChild and firstChild.GetFormattedName then
                    skillName = firstChild:GetFormattedName()
                end
            end

            if skillName and skillName ~= "" then
                local n = GetPooledLabel(pooledIndex)
                pooledIndex = pooledIndex + 1

                n:SetFont(fontString)
                n:ClearAnchors()
                n:SetAnchor(CENTER, child, CENTER, 0, -35)
                n:SetText(zo_strformat("<<C:1>>", skillName))
                n:SetHidden(false)
                
                table.insert(activeLabels, n)
            end
        end
    end
end

-- Secure hooks for Gamepad Tooltips and Navigation
local function InitializeHooks()
    if GAMEPAD_TOOLTIPS then
        if GAMEPAD_TOOLTIPS.LayoutChampionPerkSkill and not GAMEPAD_TOOLTIPS._ccpHooked then
            SecurePostHook(GAMEPAD_TOOLTIPS, "LayoutChampionPerkSkill", function()
                ClearPerkLabels()
                if ZO_ChampionPerksCanvas then
                    ZO_ChampionPerksCanvas:SetHidden(true)
                end
            end)
            GAMEPAD_TOOLTIPS._ccpHooked = true
        end

        if GAMEPAD_TOOLTIPS.ClearTooltip and not GAMEPAD_TOOLTIPS._ccpClearHooked then
            SecurePostHook(GAMEPAD_TOOLTIPS, "ClearTooltip", function()
                if ZO_ChampionPerksCanvas then
                    ZO_ChampionPerksCanvas:SetHidden(false)
                end
                if isCPUIOpen then
                    zo_callLater(RefreshPerkLabels, 50)
                end
            end)
            GAMEPAD_TOOLTIPS._ccpClearHooked = true
        end
    end

    if ZO_ChampionPerks_Gamepad and not ZO_ChampionPerks_Gamepad._ccpNavHooked then
        -- Hook selection changes so entering/exiting sub-menus refreshes labels instantly
        if ZO_ChampionPerks_Gamepad.OnSelectionChanged then
            SecurePostHook(ZO_ChampionPerks_Gamepad, "OnSelectionChanged", function()
                if isCPUIOpen then
                    zo_callLater(RefreshPerkLabels, 30)
                end
            end)
        end
        if ZO_ChampionPerks_Gamepad.Update then
            SecurePostHook(ZO_ChampionPerks_Gamepad, "Update", function()
                if isCPUIOpen then
                    zo_callLater(RefreshPerkLabels, 30)
                end
            end)
        end
        ZO_ChampionPerks_Gamepad._ccpNavHooked = true
    end
end

-- Create LAM2 Settings Menu
local function CreateSettingsPanel()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = "ConsoleCPQoL_OptionsPanel"
    local panelData = {
        type = "panel",
        name = "Console CP QoL",
        displayName = "|cFFD700Console CP |c00CCFFQoL Settings|r",
        author = "|c00FFCCtheWiz|r",
        version = "1.3",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel(panelName, panelData)

    local optionsData = {
        {
            type = "description",
            text = "|cFFD700Customize the appearance of the star skill labels in the Champion Points gamepad UI.|r",
        },
        {
            type = "slider",
            name = "|cFFFFFFFont Size|r",
            tooltip = "Adjust the text size for the champion skill labels.",
            min = 12,
            max = 36,
            step = 1,
            getFunc = function() return SV.fontSize end,
            setFunc = function(value)
                SV.fontSize = value
                RefreshPerkLabels()
            end,
            default = defaultSettings.fontSize,
        },
        {
            type = "colorpicker",
            name = "|cFFFFFFStar Label Color|r",
            tooltip = "Choose the text color for the champion skill names.",
            getFunc = function() 
                return SV.fontColorR, SV.fontColorG, SV.fontColorB, SV.fontColorA 
            end,
            setFunc = function(r, g, b, a)
                SV.fontColorR = r
                SV.fontColorG = g
                SV.fontColorB = b
                SV.fontColorA = a
                RefreshPerkLabels()
            end,
            default = {
                r = defaultSettings.fontColorR,
                g = defaultSettings.fontColorG,
                b = defaultSettings.fontColorB,
                a = defaultSettings.fontColorA,
            },
        },
    }

    LAM:RegisterOptionControls(panelName, optionsData)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ConsoleCPQoL.name then return end
    EVENT_MANAGER:UnregisterForEvent(ConsoleCPQoL.name, EVENT_ADD_ON_LOADED)
    
    SV = ZO_SavedVars:NewAccountWide("ConsoleCPQoL_SavedVars", 1, nil, defaultSettings)

    InitializeHooks()
    CreateSettingsPanel()

    if SCENE_MANAGER then
        local cpScene = SCENE_MANAGER:GetScene("gamepad_championPerks_root")
        if cpScene then
            cpScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    isCPUIOpen = true
                    InitializeHooks()
                    zo_callLater(RefreshPerkLabels, 150)
                    zo_callLater(RefreshPerkLabels, 400)
                    zo_callLater(RefreshPerkLabels, 800)
                elseif newState == SCENE_HIDDEN or newState == SCENE_HIDING then
                    isCPUIOpen = false
                    ClearPerkLabels()
                end
            end)
        end
    end
end

EVENT_MANAGER:RegisterForEvent(ConsoleCPQoL.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

-- Active background update ticker while CP menu is open to guarantee sub-menus display labels
EVENT_MANAGER:RegisterForUpdate(ConsoleCPQoL.name .. "_Ticker", 250, function()
    if isCPUIOpen then
        RefreshPerkLabels()
    end
end)

SLASH_COMMANDS["/ccptest"] = function()
    isCPUIOpen = true
    RefreshPerkLabels()
end

SLASH_COMMANDS["/ccpclear"] = function()
    ClearPerkLabels()
    if ZO_ChampionPerksCanvas then
        ZO_ChampionPerksCanvas:SetHidden(true)
    end
end