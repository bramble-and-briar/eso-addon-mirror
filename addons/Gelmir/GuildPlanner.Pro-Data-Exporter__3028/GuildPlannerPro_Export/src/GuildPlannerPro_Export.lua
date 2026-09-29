GuildPlannerPro_Export = {}

GuildPlannerPro_Export.Name = "GuildPlannerPro_Export"
GuildPlannerPro_Export.DisplayName = "GuildPlanner.Pro Export"
GuildPlannerPro_Export.AddonVersion = "2.21.0"
GuildPlannerPro_Export.PlayerDataExportSavedVariablesName = "GuildPlannerPro_PlayerDataExport"
GuildPlannerPro_Export.GameDataExportSavedVariablesName = "GuildPlannerPro_GameDataExport"
GuildPlannerPro_Export.VariableVersion = 221000001
GuildPlannerPro_Export.ScanIntervalEveryMinute = 60000

local characterDefault = GuildPlannerPro_Character:New()
local accountDefault = GuildPlannerPro_Account:New()
local gameDefault = {
    Achievements = {},
    Activities = {},
    ChampionPoints = {},
    Constants = {},
    ItemSetCollectionSets = {},
    Scribables={},
    SkillAliases = {},
    SkillLines = {},
    Stories = {},
}

local character -- SavedVariable for exported character data
local account -- SavedVariable for exported account data
local game -- SavedVariable for exported game data

function GuildPlannerPro_Export:ExportGameData()
    game.Achievements = GuildPlannerPro_Achievements:MapAllAchievements()
    GuildPlannerPro_Utils:PrintMessage("PveAchievements exported.")
    game.ChampionPoints = GuildPlannerPro_Skills:MapChampionPoints()
    GuildPlannerPro_Utils:PrintMessage("Champion Points exported.")
    game.Stories = GuildPlannerPro_Collectibles:MapStoriesCollectibles()
    GuildPlannerPro_Utils:PrintMessage("Stories exported.")
    game.Activities = GuildPlannerPro_Collectibles:ExportActivities()
    GuildPlannerPro_Utils:PrintMessage("Activities exported.")
    game.ItemSetCollectionSets = GuildPlannerPro_Sets:MapItemSetCollectionSets()
    GuildPlannerPro_Utils:PrintMessage("ItemSetCollectionSets exported.")
    game.SkillLines = GuildPlannerPro_Skills:MapSkillLines()
    GuildPlannerPro_Utils:PrintMessage("SkillLines exported.")
    game.SkillAliases = GuildPlannerPro_Skills:CollectSkillAliasIds()
    GuildPlannerPro_Utils:PrintMessage("SkillAliases exported.")
    game.Scribables = GuildPlannerPro_Skills:MapScribables()
    GuildPlannerPro_Utils:PrintMessage("Scribables exported.")
    game.Constants = GuildPlannerPro_Const
end

function GuildPlannerPro_Export:ClearGameData()
    game.ChampionPoints = {}
    game.Constants = {}
    game.ItemSetCollectionSets = {}
    game.Achievements = {}
    game.SkillLines = {}
    game.SkillAliases = {}
    game.Scribables = {}
    game.Stories = {}
    game.Activities = {}
end

function GuildPlannerPro_Export:Init()
    GuildPlannerPro_Account.Initialize(account)
    GuildPlannerPro_Character.Initialize(character)
end

local function UpdateEveryMinute()
    character.DefaultSetup.Stats = GuildPlannerPro_Character:ExportCharacterStats()
    account.ItemSetCollectionSets = GuildPlannerPro_Sets:ExportItemSetCollectionSets()
end

local function OnEventAchievementAwarded(_, _, _, achievementId)
    character.AchievementPoints = GetEarnedAchievementPoints()
    local completionData = GuildPlannerPro_Achievements:ParseAchievementCompletionData(achievementId)
    if completionData then
        local persistenceLevel = GetAchievementPersistenceLevel(achievementId)
        if persistenceLevel == ACHIEVEMENT_PERSISTENCE_CHARACTER then
            character.Achievements[achievementId] = completionData
        elseif persistenceLevel == ACHIEVEMENT_PERSISTENCE_ACCOUNT then
            account.Achievements[achievementId] = completionData
        end
    end
end

local function OnEventActionSlotsAllHotbarsUpdated()
    character.DefaultSetup.Hotbars = GuildPlannerPro_Skills:ExportCharacterHotbars()
end

local function OnEventArmoryBuildUpdated(_, result, buildIndex)
    if result == ARMORY_BUILD_RESTORE_RESULT_SUCCESS or result == ARMORY_BUILD_SAVE_RESULT_SUCCESS then
        character.Builds[buildIndex] = GuildPlannerPro_Armory:ParseArmoryBuild(buildIndex, true)
    end
end

local function OnEventChampionPointUpdate(_, unitTag, _, _)
    if unitTag == 'player' then
        account.ChampionLevel = GuildPlannerPro_Character:ExportChampionRank()
    end
end

local function OnEventChampionPurchaseResult(_ , result)
    if result == CHAMPION_PURCHASE_SUCCESS then
        character.ChampionPoints = GuildPlannerPro_Skills:ExportChampionPoints()
        character.DefaultSetup.Stats = GuildPlannerPro_Character:ExportCharacterStats()
    end
end

local function OnEventCollectionUpdated(_)
    account.Stories = GuildPlannerPro_Collectibles:ExportStoriesCollectibles()
end

local function OnEventCurrencyUpdate(_, _, currencyLocation)
    if currencyLocation == CURRENCY_LOCATION_CHARACTER then
        character.Wallet = GuildPlannerPro_Character:GetCurrencyAmountForGivenWallet(currencyLocation)
    end
    if currencyLocation == CURRENCY_LOCATION_BANK then
        account.BankWallet = GuildPlannerPro_Character:GetCurrencyAmountForGivenWallet(currencyLocation)
    end
    if currencyLocation == CURRENCY_LOCATION_ACCOUNT then
        account.Wallet = GuildPlannerPro_Character:GetCurrencyAmountForGivenWallet(currencyLocation)
    end
    if currencyLocation == CURRENCY_LOCATION_GUILD_BANK then
        local guildId = GetSelectedGuildBankId()
        if guildId then
            account.Guilds[guildId]["BankedGold"] = GuildPlannerPro_Guilds:GetSelectedGuildBankedGold()
        end
    end
end

local function OnEventGuildBankSelected(_, guildId)
    account.Guilds[guildId]["BankedGold"] = GuildPlannerPro_Guilds:GetSelectedGuildBankedGold()
end

local function OnEventGuildUpdate()
    account.Guilds = GuildPlannerPro_Guilds:GetGuilds()
end

local function OnEventInventorySingleSlotUpdate(_, bagId, _, _, _, _, stackCountChange)
    if stackCountChange ~= 0 then
        if bagId == BAG_WORN then
            character.DefaultSetup.Equipment = GuildPlannerPro_Character:CheckEquipment()
        elseif bagId == BAG_BACKPACK then
            character.CarriedSets = GuildPlannerPro_Character:CheckBackpackForSets()
        elseif GuildPlannerPro_Utils:TableKeyExists(bagId, account.BankedSets) then
            account.BankedSets[bagId] = GuildPlannerPro_Character:CheckBankForSets(bagId)
            if bagId == BAG_BANK then
                account.BankedSets[BAG_SUBSCRIBER_BANK] = GuildPlannerPro_Character:CheckBankForSets(BAG_SUBSCRIBER_BANK)
            end
        end
    end
end

local function OnEventItemSetCollectionUpdated(_, itemSetId)
    account.ItemSetCollectionSets[itemSetId] = GuildPlannerPro_Sets:ExportItemSetCollectionSet(itemSetId)
end

local function OnEventLevelUpdate()
    character.Level = GuildPlannerPro_Character:ExportLevel()
    character.DefaultSetup.Stats = GuildPlannerPro_Character:ExportCharacterStats()
end

local function OnEventOpenBank(_, bagId)
    if IsBankOpen() then
        account.BankedSets[bagId] = GuildPlannerPro_Character:CheckBankForSets(bagId)
        if bagId == BAG_BANK then
            account.BankedSets[BAG_SUBSCRIBER_BANK] = GuildPlannerPro_Character:CheckBankForSets(BAG_SUBSCRIBER_BANK)
            account.BankWallet = GuildPlannerPro_Character:GetCurrencyAmountForGivenWallet(CURRENCY_LOCATION_BANK)
        end
    end
end

local function OnEventOpenArmoryMenu()
    GuildPlannerPro_Utils:PrintMessage("|c80D020ARMORY OPENED|r: To export your builds, please Equip/Save each build once. This needs to be done everytime you upgrade GuildPlanner.Pro addon.")
end

local function OnEventSkillPointsChanged()
    character.AvailableSkillPoints = GetAvailableSkillPoints()
end

local function OnEventSkillRankUpdate()
    character.DefaultSetup.SkillLines = GuildPlannerPro_Skills:ExportCharacterSkillLines()
end

local function OnEventTitleUpdate(_, unitTag)
    if unitTag == "player" then
        character.Title = GetUnitTitle("player")
    end
end

local function OnEventTradeSucceeded()
    character.CarriedSets = GuildPlannerPro_Character:CheckBackpackForSets()
end

local function OnEventLogoutDeferred()
    GuildPlannerPro_Export:Init()
end

local function OnEventPlayerActivated()
    GuildPlannerPro_Export:ClearGameData()
end

local function OnEventAddOnLoaded(_, addonName)
    if (addonName ~= GuildPlannerPro_Export.Name) then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)

    -- Register saved variables
    character = ZO_SavedVars:NewCharacterIdSettings(GuildPlannerPro_Export.PlayerDataExportSavedVariablesName, GuildPlannerPro_Export.VariableVersion, nil, characterDefault, GetWorldName())
    account = ZO_SavedVars:NewAccountWide(GuildPlannerPro_Export.PlayerDataExportSavedVariablesName, GuildPlannerPro_Export.VariableVersion, nil, accountDefault, GetWorldName())
    game = ZO_SavedVars:NewAccountWide(GuildPlannerPro_Export.GameDataExportSavedVariablesName, GuildPlannerPro_Export.VariableVersion, nil, gameDefault, GetWorldName())

    GuildPlannerPro_Export:Init()

    ----
    --  Register Events
    ----
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ACHIEVEMENT_AWARDED, OnEventAchievementAwarded)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnEventActionSlotsAllHotbarsUpdated)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, OnEventArmoryBuildUpdated)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ARMORY_BUILD_SAVE_RESPONSE, OnEventArmoryBuildUpdated)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_CHAMPION_POINT_UPDATE, OnEventChampionPointUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_CHAMPION_PURCHASE_RESULT, OnEventChampionPurchaseResult)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_COLLECTION_UPDATED, OnEventCollectionUpdated)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_CURRENCY_UPDATE, OnEventCurrencyUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_BANK_SELECTED, OnEventGuildBankSelected)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_DESCRIPTION_CHANGED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_ID_CHANGED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_KEEP_CLAIM_UPDATED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_LEVEL_CHANGED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_MEMBER_ADDED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_MEMBER_DEMOTE_SUCCESSFUL, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_MEMBER_NOTE_CHANGED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_MEMBER_PROMOTE_SUCCESSFUL, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_MEMBER_RANK_CHANGED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_MEMBER_REMOVED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_MOTD_CHANGED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_PLAYER_RANK_CHANGED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_RANKS_CHANGED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_RECRUITMENT_INFO_UPDATED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_SELF_JOINED_GUILD, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_SELF_LEFT_GUILD, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_GUILD_TRADER_HIRED_UPDATED, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnEventInventorySingleSlotUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ITEM_SET_COLLECTION_UPDATED, OnEventItemSetCollectionUpdated)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_KEEP_GUILD_CLAIM_UPDATE, OnEventGuildUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_LEVEL_UPDATE, OnEventLevelUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_LOGOUT_DEFERRED, OnEventLogoutDeferred)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_OPEN_ARMORY_MENU, OnEventOpenArmoryMenu)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_OPEN_BANK, OnEventOpenBank)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_PLAYER_ACTIVATED, OnEventPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_SKILL_POINTS_CHANGED, OnEventSkillPointsChanged)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_SKILL_RANK_UPDATE, OnEventSkillRankUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_TITLE_UPDATE, OnEventTitleUpdate)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_TRADE_SUCCEEDED, OnEventTradeSucceeded)

    ----
    -- Register Updates
    ----
    EVENT_MANAGER:RegisterForUpdate(addonName, GuildPlannerPro_Export.ScanIntervalEveryMinute, UpdateEveryMinute)
end

----
-- AddOn init
----
EVENT_MANAGER:RegisterForEvent(GuildPlannerPro_Export.Name, EVENT_ADD_ON_LOADED, OnEventAddOnLoaded)
SLASH_COMMANDS["/gppro"] = GuildPlannerPro_Command.Handle
