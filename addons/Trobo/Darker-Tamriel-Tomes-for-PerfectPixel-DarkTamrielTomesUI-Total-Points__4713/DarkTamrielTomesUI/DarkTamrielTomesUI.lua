--[[
-------------------------------------------------------------------------------
-- Dark Tamriel Tomes UI, by @Trobo, @Masteroshi430 (EU)
-------------------------------------------------------------------------------
]]

local ADDON_NAME = "DarkTamrielTomesUI"

DarkTamrielTomesUI = DarkTamrielTomesUI or {}
local addon = DarkTamrielTomesUI

local WHITE_HEX = "FFFFFF"
local GREEN_HEX = "00FF00"
local RED_HEX = "FF0000"

local POINT_OVERVIEW_ENTRIES =
{
    { key = "pageFree", stringId = SI_DTTUI_PAGE_FREE, column = 1, row = 1 },
    { key = "pagePremium", stringId = SI_DTTUI_PAGE_PREMIUM, column = 1, row = 2 },
    { key = "allFree", stringId = SI_DTTUI_ALL_FREE, column = 2, row = 1 },
    { key = "allPremium", stringId = SI_DTTUI_ALL_PREMIUM, column = 2, row = 2 },
    { key = "pageTotal", stringId = SI_DTTUI_PAGE_TOTAL, column = 3, row = 1 },
    { key = "allTotal", stringId = SI_DTTUI_ALL_TOTAL, column = 3, row = 2 },
}

local POINT_OVERVIEW_LAYOUTS =
{
    keyboard =
    {
        x = { 25, 175, 380 },
        y = { 0, 23 },
        width = { 175, 210, 205 },
        height = 23,
        font = "$(BOLD_FONT)|$(KB_16)|soft-shadow-thick",
    },
    gamepad =
    {
        x = { 280, 460, 680 },
        y = { 12, 39 },
        width = { 175, 210, 215 },
        height = 25,
        font = "$(GAMEPAD_MEDIUM_FONT)|$(GP_22)|soft-shadow-thick",
    },
}

local function IsGamepadScreen(screen)
    local controlName = screen and screen.control and screen.control:GetName()
    return controlName and string.find(controlName, "Gamepad", 1, true) ~= nil
end

local function SetPointOverviewHidden(screen, hidden)
    if not screen or not screen.dttuPointOverviewLabels then
        return
    end

    for _, label in pairs(screen.dttuPointOverviewLabels) do
        label:SetHidden(hidden)
    end
end

local function CreatePointOverviewControls(screen)
    if not screen or screen.dttuPointOverviewLabels then
        return
    end

    local bookControl = screen.control and screen.control:GetNamedChild("Book")
    if not bookControl then
        return
    end

    local layout = IsGamepadScreen(screen) and POINT_OVERVIEW_LAYOUTS.gamepad or POINT_OVERVIEW_LAYOUTS.keyboard
    local screenName = screen.control:GetName() or ADDON_NAME
    local labels = {}

    for entryIndex, entry in ipairs(POINT_OVERVIEW_ENTRIES) do
        local controlName = string.format("%sDTTUPointOverview%d", screenName, entryIndex)
        local label = WINDOW_MANAGER:CreateControl(controlName, bookControl, CT_LABEL)
        label:SetAnchor(TOPLEFT, bookControl, TOPLEFT, layout.x[entry.column], layout.y[entry.row])
        label:SetDimensions(layout.width[entry.column], layout.height)
        label:SetFont(layout.font)
        label:SetColor(1, 1, 1, 1)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetHidden(true)
        labels[entry.key] = label
    end

    screen.dttuPointOverviewLabels = labels
end

local function AddTierPointCosts(rewardTrackType, tomeIndex, rewardTrackId, tierIndex, rewardComponent)
    local spentPoints = 0
    local totalPoints = 0
    local numRewards = GetNumRewardsAtRewardTrackTier(rewardTrackId, tierIndex, rewardComponent)

    for rewardIndex = 1, numRewards do
        local _, _, rewardCost = GetTamrielTomesRewardInfo(rewardTrackId, tierIndex, rewardComponent, rewardIndex)
        rewardCost = rewardCost or 0
        totalPoints = totalPoints + rewardCost

        local isClaimed = GetRewardTrackRewardClaimedState(rewardTrackType, tomeIndex, tierIndex, rewardComponent, rewardIndex)
        if isClaimed then
            spentPoints = spentPoints + rewardCost
        end
    end

    return spentPoints, totalPoints
end


local function GetPointOverviewValues(screen)
    local tomeId = screen.selectedTomeId
    local rewardTrackId = screen.currentRewardTrackId
    local currentTierIndex = screen.currentTierIndex
    if not tomeId or not rewardTrackId or not currentTierIndex then
        return nil
    end

    local rewardTrackType = REWARD_TRACK_TYPE_TAMRIEL_TOMES
    local tomeIndex = GetReferenceTrackIndex(rewardTrackType, tomeId)
    local numTiers = GetTotalNumTiersForRewardTrack(rewardTrackId)
    if not tomeIndex or tomeIndex <= 0 or not numTiers or numTiers <= 0 then
        return nil
    end

    currentTierIndex = zo_clamp(currentTierIndex, 1, numTiers)

    local values =
    {
        pageFree = { 0, 0 },
        pagePremium = { 0, 0 },
        allFree = { 0, 0 },
        allPremium = { 0, 0 },
        pageTotal = { 0, 0 },
        allTotal = { 0, 0 },
    }

    for tierIndex = 1, numTiers do
        local freeSpent, freeTotal = AddTierPointCosts(rewardTrackType, tomeIndex, rewardTrackId, tierIndex, REWARD_TRACK_COMPONENT_PRIMARY)
        local premiumSpent, premiumTotal = AddTierPointCosts(rewardTrackType, tomeIndex, rewardTrackId, tierIndex, REWARD_TRACK_COMPONENT_SECONDARY)

        values.allFree[1] = values.allFree[1] + freeSpent
        values.allFree[2] = values.allFree[2] + freeTotal
        values.allPremium[1] = values.allPremium[1] + premiumSpent
        values.allPremium[2] = values.allPremium[2] + premiumTotal

        if tierIndex == currentTierIndex then
            values.pageFree[1] = freeSpent
            values.pageFree[2] = freeTotal
            values.pagePremium[1] = premiumSpent
            values.pagePremium[2] = premiumTotal
        end
    end

    values.pageTotal[1] = values.pageFree[1] + values.pagePremium[1]
    values.pageTotal[2] = values.pageFree[2] + values.pagePremium[2]
    values.allTotal[1] = values.allFree[1] + values.allPremium[1]
    values.allTotal[2] = values.allFree[2] + values.allPremium[2]

    return values
end


local function FormatPointOverviewText(labelText, spentPoints, totalPoints)
    local spentColor = WHITE_HEX
    if totalPoints > 0 and spentPoints >= totalPoints then
        spentColor = RED_HEX
    end

    return string.format("%s |c%s%d|r/|c%s%d|r", labelText, spentColor, spentPoints, GREEN_HEX, totalPoints)
end


function addon.UpdatePointOverview(screen)
    CreatePointOverviewControls(screen)
    if not screen or not screen.dttuPointOverviewLabels then
        return
    end

    local values = GetPointOverviewValues(screen)
    if not values then
        SetPointOverviewHidden(screen, true)
        return
    end

    for _, entry in ipairs(POINT_OVERVIEW_ENTRIES) do
        local value = values[entry.key]
        local label = screen.dttuPointOverviewLabels[entry.key]
        local labelText = GetString(entry.stringId)
        label:SetText(FormatPointOverviewText(labelText, value[1], value[2]))
        label:SetHidden(false)
    end
end


local function RefreshAllPointOverviews()
    if TAMRIEL_TOMES_SCREEN_KEYBOARD then
        addon.UpdatePointOverview(TAMRIEL_TOMES_SCREEN_KEYBOARD)
    end
    if TAMRIEL_TOMES_SCREEN_GAMEPAD then
        addon.UpdatePointOverview(TAMRIEL_TOMES_SCREEN_GAMEPAD)
    end
end


local function InstallPointOverviewHooks()
    if addon.pointOverviewHooksInstalled or not ZO_TamrielTomesScreen_Shared then
        return
    end

    addon.pointOverviewHooksInstalled = true

    SecurePostHook(ZO_TamrielTomesScreen_Shared, "OnShowing", function(screen)
        addon.UpdatePointOverview(screen)
    end)

    SecurePostHook(ZO_TamrielTomesScreen_Shared, "OnPageChanged", function(screen)
        addon.UpdatePointOverview(screen)
    end)

    SecurePostHook(ZO_TamrielTomesScreen_Shared, "RebuildGridList", function(screen)
        addon.UpdatePointOverview(screen)
    end)

    if TAMRIEL_TOMES_MANAGER then
        TAMRIEL_TOMES_MANAGER:RegisterCallback("RewardsUpdated", RefreshAllPointOverviews)
        TAMRIEL_TOMES_MANAGER:RegisterCallback("ProgressUpdated", RefreshAllPointOverviews)
        TAMRIEL_TOMES_MANAGER:RegisterCallback("SelectedTomeChanged", RefreshAllPointOverviews)
    end
end

local function OnAddonLoaded(event, addonName)

    if addonName == ADDON_NAME then
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    
		-- black
		RedirectTexture("/esoui/art/tamrieltomes/tome_page_selection_bg.dds", "DarkTamrielTomesUI/black/tome_page_selection_bg_blk.dds")
		RedirectTexture("/esoui/art/tamrieltomes/tome_slot_bg.dds", "DarkTamrielTomesUI/black/tome_slot_bg_blk.dds")
		RedirectTexture("/esoui/art/tamrieltomes/tome_slot_bg_solid.dds", "DarkTamrielTomesUI/black/tome_slot_bg_solid_blk.dds")
		
		-- khaki
		RedirectTexture("/esoui/art/tamrieltomes/selected_page_outline.dds", "DarkTamrielTomesUI/khaki/selected_page_outline_khk.dds")
		RedirectTexture("/esoui/Art/TamrielTomes/single_side_full_tome.dds", "DarkTamrielTomesUI/khaki/single_side_full_tome_khk.dds")
		RedirectTexture("/esoui/art/tamrieltomes/tome_group_premium_slots_border.dds", "DarkTamrielTomesUI/khaki/tome_group_premium_slots_border_khk.dds")
		RedirectTexture("/esoui/art/tamrieltomes/tome_slot_outline.dds", "DarkTamrielTomesUI/khaki/tome_slot_outline_khk.dds")
		RedirectTexture("/esoui/art/tamrieltomes/tome_slot_outline_square.dds", "DarkTamrielTomesUI/khaki/tome_slot_outline_square_khk.dds")
		RedirectTexture("/esoui/art/tamrieltomes/two_page_open_tome.dds", "DarkTamrielTomesUI/khaki/two_page_open_tome_khk.dds")
		RedirectTexture("/esoui/art/tamrieltomes/upgrade_tome_bg.dds", "DarkTamrielTomesUI/khaki/upgrade_tome_bg_khk.dds")
		RedirectTexture("/esoui/art/tamrieltomes/upgrade_tome_item_divider.dds", "DarkTamrielTomesUI/khaki/upgrade_tome_item_divider_khk.dds")
		
		-- orange
		RedirectTexture("/esoui/art/tamrieltomes/tome_premium_bg.dds", "DarkTamrielTomesUI/orange/tome_premium_bg_org.dds")
		
		-- transparent
		RedirectTexture("/esoui/art/tamrieltomes/tome_currency_backdrop.dds", "DarkTamrielTomesUI/trans/tome_currency_backdrop_tra.dds")
		RedirectTexture("/esoui/art/tamrieltomes/tome_points_remaining_to_unlock_page_bg.dds", "DarkTamrielTomesUI/trans/tome_points_remaining_to_unlock_page_bg_tra.dds")
        RedirectTexture("/esoui/art/tamrieltomes/tome_rewards_title_bg.dds", "DarkTamrielTomesUI/trans/tome_rewards_title_bg_tra.dds")
        RedirectTexture("/esoui/art/tamrieltomes/tome_slot_currency_bg.dds", "DarkTamrielTomesUI/trans/tome_slot_currency_bg_tra.dds")
		RedirectTexture("/esoui/art/tamrieltomes/upgrade_tome_item_container.dds", "DarkTamrielTomesUI/trans/upgrade_tome_item_container_tra.dds")
        RedirectTexture("/esoui/art/tamrieltomes/upgrade_tome_titlebar_bg.dds", "DarkTamrielTomesUI/trans/upgrade_tome_titlebar_bg_tra.dds")
		
		SecurePostHook(ZO_TamrielTomesIntroScreen_Shared, "OnShowing", DarkTamrielTomesUI.ChangeFontColorsForIntro)
        InstallPointOverviewHooks()
    end
end


local function ColorEntries(scrollChild, r, g, b, a)
    if not scrollChild then return end

    local numChildren = scrollChild:GetNumChildren()
    for i = 0, numChildren  do
        local entry = scrollChild:GetChild(i)
        if entry then
            local title = entry:GetNamedChild("Title")
            if title then
                title:SetColor(r, g, b, a)
            end

            local bodyText = entry:GetNamedChild("BodyText")
            if bodyText then
                bodyText:SetColor(r, g, b, a)
            end
        end
    end
end

function DarkTamrielTomesUI.ChangeFontColorsForIntro()

    local r, g, b, a = GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_HIGHLIGHT)

    local titleLabelKB = WINDOW_MANAGER:GetControlByName("ZO_TamrielTomesIntro_KeyboardTLTitle")
    if titleLabelKB then
        titleLabelKB:SetColor(r, g, b, a)
    end

    local titleLabelGP = WINDOW_MANAGER:GetControlByName("ZO_TamrielTomesIntro_GamepadTLTitle")
    if titleLabelGP then
        titleLabelGP:SetColor(r, g, b, a)
    end

    local rightPageTextControlKB = WINDOW_MANAGER:GetControlByName("ZO_TamrielTomesIntro_KeyboardTLHighlightsScrollChild")
    ColorEntries(rightPageTextControlKB, r, g, b, a)

    local rightPageTextControlGP = WINDOW_MANAGER:GetControlByName("ZO_TamrielTomesIntro_GamepadTLHighlightsScrollChild")
    ColorEntries(rightPageTextControlGP, r, g, b, a)

end 


EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
