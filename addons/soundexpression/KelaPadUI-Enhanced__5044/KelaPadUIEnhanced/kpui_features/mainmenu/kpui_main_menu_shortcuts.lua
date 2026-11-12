-- KelaPadUI main-menu quick access
-- The tertiary (Options/triangle) keybind on the menu root opens a Quick Access
-- submenu built from the gamepad main menu's own sublist. No main-menu row is added.

local QUICK_ACCESS_SETTING = KELA_SETTING_PANEL_FEATURES_MAIN_MENU_SHORTCUTS
local QUICK_ACCESS_HEADER_PADDING = GAMEPAD_HEADER_DEFAULT_PADDING or 80

local keybindAdded = false
local submenuCallbackRegistered = false
local refreshHooksInstalled = false
local quickAccessEntry = nil
local quickAccessSubMenu = nil
local quickAccessOpen = false
local quickAccessSelectedIndex = nil
local applyingQuickAccess = false
local IsQuickAccessSubmenuShowing

local function IsQuickAccessEnabled()
    return KelaGetSetting_Bool(SETTING_TYPE_KELA, QUICK_ACCESS_SETTING)
end

local function ShowGroupFinder()
    if not GROUP_FINDER_GAMEPAD or not ZO_ACTIVITY_FINDER_ROOT_GAMEPAD then
        return
    end

    local categoryData = GROUP_FINDER_GAMEPAD.GetCategoryData and GROUP_FINDER_GAMEPAD:GetCategoryData()
    if not categoryData then
        return
    end

    -- Set the mode before showing so OnShowing consumes it without an overview flash.
    if GROUP_FINDER_GAMEPAD.SetMode and ZO_GROUP_FINDER_MODES then
        GROUP_FINDER_GAMEPAD:SetMode(ZO_GROUP_FINDER_MODES.SEARCH)
    end

    ZO_ACTIVITY_FINDER_ROOT_GAMEPAD:ShowCategory(categoryData)
end

local function ShowDungeonFinder()
    if not DUNGEON_FINDER_MANAGER or not ZO_ACTIVITY_FINDER_ROOT_GAMEPAD then
        return
    end

    local categoryData = DUNGEON_FINDER_MANAGER.GetCategoryData and DUNGEON_FINDER_MANAGER:GetCategoryData()
    if categoryData then
        ZO_ACTIVITY_FINDER_ROOT_GAMEPAD:ShowCategory(categoryData)
    end
end

local function ShowBattlegroundFinder()
    if not BATTLEGROUND_FINDER_MANAGER or not ZO_ACTIVITY_FINDER_ROOT_GAMEPAD then
        return
    end

    local categoryData = BATTLEGROUND_FINDER_MANAGER.GetCategoryData and BATTLEGROUND_FINDER_MANAGER:GetCategoryData()
    if categoryData then
        ZO_ACTIVITY_FINDER_ROOT_GAMEPAD:ShowCategory(categoryData)
    end
end

local function IsRumoursAvailable()
    return QUEST_JOURNAL_GAMEPAD ~= nil and QUEST_JOURNAL_GAMEPAD.SetMode ~= nil
        and ZO_QUEST_JOURNAL_MODE ~= nil and ZO_QUEST_JOURNAL_MODE.RUMORS ~= nil
        and SCENE_MANAGER ~= nil and SCENE_MANAGER.CreateStackFromScratch ~= nil
end

local function ShowRumours()
    if IsRumoursAvailable() then
        QUEST_JOURNAL_GAMEPAD:SetMode(ZO_QUEST_JOURNAL_MODE.RUMORS)
        SCENE_MANAGER:CreateStackFromScratch("mainMenuGamepad", "gamepad_quest_journal")
    end
end

local function ShowGroupList()
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.ShowGroupMenu then
        MAIN_MENU_GAMEPAD:ShowGroupMenu()
    end
end

local function ShowMail()
    if SCENE_MANAGER and SCENE_MANAGER.CreateStackFromScratch then
        SCENE_MANAGER:CreateStackFromScratch("mainMenuGamepad", "mailGamepad")
    end
end

local function ShowScryableAntiquities()
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.ShowScryableAntiquities then
        MAIN_MENU_GAMEPAD:ShowScryableAntiquities()
    end
end

local function ShowStickerBook()
    if SCENE_MANAGER and SCENE_MANAGER.CreateStackFromScratch then
        SCENE_MANAGER:CreateStackFromScratch("mainMenuGamepad", "gamepadItemSetsBook")
    end
end

local function FindCompanionCollectibleId()
    local companionId = GetActiveCompanionDefId()
    if companionId and companionId ~= 0 then
        local collectibleId = GetCompanionCollectibleId(companionId)
        if collectibleId and collectibleId ~= 0 then
            return collectibleId
        end
    end

    -- No companion is summoned, so use any companion collectible to land on the
    -- Allies > Companions page.
    for _, collectibleData in ipairs(ZO_COLLECTIBLE_DATA_MANAGER:GetAllCollectibleDataObjects()) do
        if collectibleData:GetCategoryType() == COLLECTIBLE_CATEGORY_TYPE_COMPANION then
            return collectibleData:GetId()
        end
    end

    return nil
end

local function ShowCompanions()
    if not GAMEPAD_COLLECTIONS_BOOK then
        return
    end

    -- BrowseToCollectible opens the Collections book directly on the companion's
    -- category and selects its entry.
    local collectibleId = FindCompanionCollectibleId()
    if collectibleId then
        GAMEPAD_COLLECTIONS_BOOK:BrowseToCollectible(collectibleId)
    end
end

local function TravelToPrimaryHouse()
    if not GetHousingPrimaryHouse or not RequestJumpToHouse then
        return
    end

    local houseId = GetHousingPrimaryHouse()
    if not houseId or houseId == 0 then
        return
    end

    if CanJumpToHouseFromCurrentLocation and not CanJumpToHouseFromCurrentLocation() then
        return
    end

    SCENE_MANAGER:ShowBaseScene()
    RequestJumpToHouse(houseId, false)
end

local function IsGroupFinderAvailable()
    return GROUP_FINDER_GAMEPAD ~= nil and ZO_ACTIVITY_FINDER_ROOT_GAMEPAD ~= nil
end

local function IsDungeonFinderAvailable()
    return DUNGEON_FINDER_MANAGER ~= nil and ZO_ACTIVITY_FINDER_ROOT_GAMEPAD ~= nil
end

local function IsBattlegroundFinderAvailable()
    return BATTLEGROUND_FINDER_MANAGER ~= nil and ZO_ACTIVITY_FINDER_ROOT_GAMEPAD ~= nil
end

local function ShowTomeChallenges()
    if TIMED_ACTIVITIES_MANAGER and TIMED_ACTIVITIES_MANAGER.ShowTimedActivitiesScene then
        TIMED_ACTIVITIES_MANAGER:ShowTimedActivitiesScene()
    end
end

local function IsTomeChallengesAvailable()
    return TIMED_ACTIVITIES_MANAGER ~= nil and TIMED_ACTIVITIES_MANAGER.ShowTimedActivitiesScene ~= nil
end

local function IsVeterancyAvailable()
    return type(IsVeterancySeasonActive) == "function" and IsVeterancySeasonActive()
        and type(QueryCampaignSelectionData) == "function"
        and GAMEPAD_AVA_BROWSER ~= nil and GAMEPAD_AVA_BROWSER.SetSelectVeterancy ~= nil
        and MAIN_MENU_GAMEPAD ~= nil and MAIN_MENU_GAMEPAD.SelectMenuEntry ~= nil
        and ZO_MENU_MAIN_ENTRIES ~= nil and ZO_MENU_MAIN_ENTRIES.CAMPAIGN ~= nil
        and VETERANCY_SCENE_GAMEPAD ~= nil
        and SCENE_MANAGER ~= nil and SCENE_MANAGER.CreateStackFromScratch ~= nil
end

local function ShowVeterancy()
    if IsVeterancyAvailable() then
        -- Match the game's notification route, including its campaign selection
        -- and intermediate scene so Back returns to the campaign browser.
        QueryCampaignSelectionData()
        GAMEPAD_AVA_BROWSER:SetSelectVeterancy()
        MAIN_MENU_GAMEPAD:SelectMenuEntry(ZO_MENU_MAIN_ENTRIES.CAMPAIGN)
        SCENE_MANAGER:CreateStackFromScratch("mainMenuGamepad", "gamepad_campaign_root", "VeterancySceneGamepad")
    end
end

-- The dashboard's Golden Pursuit row uses the first promotional campaign; use
-- the same campaign here instead of the unrelated returning-player announcement.
local function GetGoldenPursuitCampaign()
    local manager = PROMOTIONAL_EVENT_MANAGER
    if not manager or not manager.GetNumActiveCampaigns or not manager.GetCampaignDataByIndex
        or not manager.ShowPromotionalEventScene
        or not PROMOTIONAL_EVENTS_GAMEPAD or not PROMOTIONAL_EVENTS_GAMEPAD.GetCategoryData
        or not ZO_ACTIVITY_FINDER_ROOT_GAMEPAD or not ZO_ACTIVITY_FINDER_ROOT_GAMEPAD.ShowCategory
        or type(IsPromotionalEventSystemLocked) ~= "function" or IsPromotionalEventSystemLocked() then
        return nil
    end
    local count = manager:GetNumActiveCampaigns() or 0
    if count == 0 or not PROMOTIONAL_EVENTS_GAMEPAD:GetCategoryData() then
        return nil
    end
    if count > 1 and (not PROMOTIONAL_EVENTS_LIST_GAMEPAD or not PROMOTIONAL_EVENTS_LIST_GAMEPAD.SelectCampaign) then
        return nil
    end
    local campaign = manager:GetCampaignDataByIndex(1)
    if campaign and campaign.ShouldCampaignBeVisible and campaign:ShouldCampaignBeVisible() then
        return campaign
    end
    return nil
end

local function IsGoldenPursuitAvailable()
    return GetGoldenPursuitCampaign() ~= nil
end

local function ShowGoldenPursuit()
    local campaign = GetGoldenPursuitCampaign()
    if campaign then
        PROMOTIONAL_EVENT_MANAGER:ShowPromotionalEventScene(false, campaign)
    end
end

local function IsGroupAvailable()
    return MAIN_MENU_GAMEPAD ~= nil and MAIN_MENU_GAMEPAD.ShowGroupMenu ~= nil
end

local function IsMailAvailable()
    return SCENE_MANAGER ~= nil
end

local function IsScryableAntiquitiesAvailable()
    return MAIN_MENU_GAMEPAD ~= nil and MAIN_MENU_GAMEPAD.ShowScryableAntiquities ~= nil
end

local function IsStickerBookAvailable()
    return SCENE_MANAGER ~= nil
end

local function IsCompanionsAvailable()
    return GAMEPAD_COLLECTIONS_BOOK ~= nil and ZO_COLLECTIBLE_DATA_MANAGER ~= nil
end

local function IsPrimaryHouseAvailable()
    if not GetHousingPrimaryHouse then
        return false
    end
    local houseId = GetHousingPrimaryHouse()
    return houseId ~= nil and houseId ~= 0
end

-- The first entry of each group carries the section header text.
-- Search Icon: EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_activityFinder.dds
local QUICK_ACCESS_ENTRIES =
{
    { label = KELA_SHORTCUT_GROUP_FINDER, icon = "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_groupFinder.dds", action = ShowGroupFinder, enabled = IsGroupFinderAvailable, header = KELA_SHORTCUT_HEADER_ACTIVITIES },
    { label = KELA_SHORTCUT_DUNGEON_FINDER, icon = "EsoUI/Art/LFG/Gamepad/gp_LFG_menuIcon_Dungeon.dds", action = ShowDungeonFinder, enabled = IsDungeonFinderAvailable },
    { label = KELA_SHORTCUT_BATTLEGROUNDS, icon = "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_battlegrounds.dds", action = ShowBattlegroundFinder, enabled = IsBattlegroundFinderAvailable },
    { label = KELA_SHORTCUT_RUMOURS, icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_quests.dds", action = ShowRumours, enabled = IsRumoursAvailable },
    { label = KELA_SHORTCUT_GROUP, icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_groups.dds", action = ShowGroupList, enabled = IsGroupAvailable, header = KELA_SHORTCUT_HEADER_SHORTCUTS },
    { label = KELA_SHORTCUT_MAIL, icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_mail.dds", action = ShowMail, enabled = IsMailAvailable },
    { label = KELA_SHORTCUT_SCRYABLE_ANTIQUITIES, icon = "EsoUI/Art/Journal/Gamepad/GP_journal_tabIcon_antiquities.dds", action = ShowScryableAntiquities, enabled = IsScryableAntiquitiesAvailable },
    { label = KELA_SHORTCUT_STICKER_BOOK, icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_itemSetCollections.dds", action = ShowStickerBook, enabled = IsStickerBookAvailable },
    { label = KELA_SHORTCUT_COMPANIONS, icon = "EsoUI/Art/Companion/Gamepad/gp_companion_icon_overview.dds", action = ShowCompanions, enabled = IsCompanionsAvailable },
    { label = KELA_SHORTCUT_TOME_CHALLENGES, icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_tamrielTomes.dds", action = ShowTomeChallenges, enabled = IsTomeChallengesAvailable, header = KELA_SHORTCUT_HEADER_EVENTS },
    { label = KELA_SHORTCUT_VETERANCY, icon = "EsoUI/Art/Campaign/Gamepad/gp_campaign_menuIcon_veterancy.dds", action = ShowVeterancy, enabled = IsVeterancyAvailable },
    { label = KELA_SHORTCUT_GOLDEN_PURSUIT, icon = "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_PromotionalEvents.dds", action = ShowGoldenPursuit, enabled = IsGoldenPursuitAvailable },
    { label = KELA_SHORTCUT_PRIMARY_HOUSE, icon = "EsoUI/Art/Collections/PrimaryHouse.dds", action = TravelToPrimaryHouse, enabled = IsPrimaryHouseAvailable, header = KELA_SHORTCUT_HEADER_ACTIONS },
}

local function BuildQuickAccessSubmenu()
    if quickAccessEntry then
        return
    end

    local subMenu = {}
    for index, quickEntry in ipairs(QUICK_ACCESS_ENTRIES) do
        local nextEntry = QUICK_ACCESS_ENTRIES[index + 1]
        local data =
        {
            name = GetString(quickEntry.label),
            icon = quickEntry.icon,
            header = quickEntry.header and GetString(quickEntry.header) or nil,
            quickAccess = true,
            shouldDisableFunction = function()
                return not quickEntry.enabled()
            end,
            activatedCallback = function(...)
                -- The action may deliberately replace this sublist (for example,
                -- the Group shortcut opens the Social submenu). Do not restore
                -- Quick Access over that navigation.
                quickAccessOpen = false
                quickEntry.action(...)

                -- If the action did nothing (for example, the primary house
                -- cannot be reached right now), keep guarding the list that is
                -- still open against background refreshes.
                if IsQuickAccessSubmenuShowing() and PLAYER_SUBMENU_SCENE:IsShowing() then
                    quickAccessOpen = true
                end
            end,
        }

        if nextEntry and nextEntry.header then
            -- The main menu passes postPadding = 0 for every entry, which also
            -- suppresses the automatic header padding. Reserve the header space
            -- ourselves so the next section title does not overlap this line.
            data.postPadding = QUICK_ACCESS_HEADER_PADDING
        end

        local entry = KelaCreateMainMenuEntry(data)
        entry:SetEnabled(quickEntry.enabled())
        entry.id = index
        subMenu[index] = entry
    end

    quickAccessSubMenu = subMenu
    quickAccessEntry =
    {
        data = { subMenu = subMenu },
        subMenu = subMenu,
    }
end

-- The menu entry does not live in ZO_MENU_ENTRIES; the Options keybind builds
-- and shows its sublist directly.
local function RefreshQuickAccessEntryStates()
    for index, quickEntry in ipairs(QUICK_ACCESS_ENTRIES) do
        local entry = quickAccessSubMenu and quickAccessSubMenu[index]
        if entry then
            entry:SetEnabled(quickEntry.enabled())
        end
    end
end

local function IsMainMenuRootShowing()
    local manager = MAIN_MENU_GAMEPAD
    if manager and manager.GetCurrentList and manager.mainList then
        return manager:GetCurrentList() == manager.mainList
    end
    return true
end

local function ApplyQuickAccessSubmenu(selectedIndex)
    local manager = MAIN_MENU_GAMEPAD
    if not quickAccessEntry or not manager then
        return
    end
    if not manager.RefreshSubList or not manager.SetCurrentList or not manager.subList then
        return
    end

    applyingQuickAccess = true
    manager:RefreshSubList(quickAccessEntry)
    if selectedIndex and manager.subList.SetSelectedIndexWithoutAnimation then
        manager.subList:SetSelectedIndexWithoutAnimation(selectedIndex, true)
    end
    applyingQuickAccess = false

    if manager:GetCurrentList() ~= manager.subList then
        manager:SetCurrentList(manager.subList)
    end
end

IsQuickAccessSubmenuShowing = function()
    local manager = MAIN_MENU_GAMEPAD
    local targetData = manager and manager.subList and manager.subList.GetTargetData and manager.subList:GetTargetData()
    return targetData ~= nil and targetData.data ~= nil and targetData.data.quickAccess == true
end

-- The main menu rebuilds its sublist from the selected main-list entry whenever
-- an inventory, mail, level, or daily-reward update marks it dirty. That refresh
-- replaces the Quick Access entries while the submenu is open. ESO does not
-- expose a pre-hook for core functions, so the selected row is tracked
-- continuously instead and restored once the core rebuild has finished.
local function OnMainMenuSelectionChanged(_, list, selectedData)
    if applyingQuickAccess or not quickAccessOpen then
        return
    end

    local manager = MAIN_MENU_GAMEPAD
    if not manager or list ~= manager.subList then
        return
    end

    -- A core refresh reports the selection of the entry it just rebuilt, which
    -- is not a Quick Access row. Ignore those so the tracked index survives.
    if not IsQuickAccessSubmenuShowing() then
        return
    end

    if selectedData and selectedData.data and selectedData.data.quickAccess then
        local subList = manager.subList
        if subList.GetSelectedIndex then
            quickAccessSelectedIndex = subList:GetSelectedIndex()
        end
    end
end

local function OnMainMenuRefreshPost()
    if applyingQuickAccess or not quickAccessOpen then
        return
    end

    if not IsQuickAccessSubmenuShowing() then
        ApplyQuickAccessSubmenu(quickAccessSelectedIndex)
    end
end

local function InstallRefreshHooks()
    local manager = MAIN_MENU_GAMEPAD
    if refreshHooksInstalled or not manager or not manager.RefreshLists then
        return
    end

    refreshHooksInstalled = true
    SecurePostHook(manager, "OnSelectionChanged", OnMainMenuSelectionChanged)
    SecurePostHook(manager, "RefreshLists", OnMainMenuRefreshPost)
end

local function OnPlayerSubmenuStateChange(_, newState)
    if newState == SCENE_SHOWING then
        if quickAccessOpen and not IsQuickAccessSubmenuShowing() then
            -- Run after the main menu's own callback has built the sublist for
            -- whichever main-list entry was selected.
            ApplyQuickAccessSubmenu()
        end
    elseif newState == SCENE_SHOWN then
        -- Safety net if the main menu rebuilds its submenu after our callback.
        if quickAccessOpen and not IsQuickAccessSubmenuShowing() then
            ApplyQuickAccessSubmenu()
        end
    elseif newState == SCENE_HIDING then
        quickAccessOpen = false
        quickAccessSelectedIndex = nil
    end
end

local function ShowQuickAccessSubmenu()
    local manager = MAIN_MENU_GAMEPAD
    if not quickAccessEntry or not manager then
        return
    end
    if not IsMainMenuRootShowing() then
        return
    end

    RefreshQuickAccessEntryStates()

    -- The main menu builds its sublist when the playerSubmenu scene is shown,
    -- so flag the override and let the scene callback replace that sublist.
    quickAccessOpen = true
    SCENE_MANAGER:Push("playerSubmenu")
end

local function RegisterSubmenuCallback()
    if submenuCallbackRegistered or not PLAYER_SUBMENU_SCENE then
        return
    end
    submenuCallbackRegistered = true
    PLAYER_SUBMENU_SCENE:RegisterCallback("StateChange", OnPlayerSubmenuStateChange)
end

local function AddQuickAccessKeybind()
    local manager = MAIN_MENU_GAMEPAD
    if keybindAdded or not manager or not manager.keybindStripDescriptor then
        return
    end
    keybindAdded = true

    table.insert(manager.keybindStripDescriptor,
    {
        name = GetString(KELA_SHORTCUT_TITLE),
        keybind = "UI_SHORTCUT_TERTIARY",
        callback = ShowQuickAccessSubmenu,
        visible = function()
            -- Add-ons run on PC, where the console voice-chat shortcut is not shown.
            if not IsQuickAccessEnabled() then
                return false
            end
            if ZO_IsConsoleOrGameCoreUI and ZO_IsConsoleOrGameCoreUI() then
                return false
            end
            return IsMainMenuRootShowing()
        end,
    })
end

function KelaSetupMainMenuShortcuts()
    if not IsQuickAccessEnabled() then
        return
    end

    if not KelaCreateMainMenuEntry or not PLAYER_SUBMENU_SCENE then
        return
    end

    BuildQuickAccessSubmenu()
    InstallRefreshHooks()
    RegisterSubmenuCallback()
    AddQuickAccessKeybind()
end
