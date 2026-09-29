GuildPlannerPro_Account = {}
GuildPlannerPro_Account.__index = GuildPlannerPro_Account

function GuildPlannerPro_Account:New()
    local newObj = setmetatable({}, self)
    newObj.Language = GetCVar("language.2")
    newObj.TimeStamp = GetTimeStamp()
    newObj.FormattedTime = GetFormattedTime()
    newObj.SecondsSinceMidnight = GetSecondsSinceMidnight()
    newObj.IsESOPlusSubscriber = IsESOPlusSubscriber()
    newObj.ChampionLevel = {}
    newObj.Guilds = {}
    newObj.ItemSetCollectionSets = {}
    newObj.Achievements = {}
    newObj.Stories = {}
    newObj.Wallet = {}
    newObj.BankWallet = {}
    newObj.PlatformDisplayName = {}
    newObj.DecoratedPlatformDisplayName = {}
    newObj.CrossPlayDisplayName = {}
    newObj.DecoratedCrossPlayDisplayName = {}

    newObj.BankedSets = {
        [BAG_BANK] = {},
        [BAG_SUBSCRIBER_BANK] = {},
        [BAG_HOUSE_BANK_ONE] = {},
        [BAG_HOUSE_BANK_TWO] = {},
        [BAG_HOUSE_BANK_THREE] = {},
        [BAG_HOUSE_BANK_FOUR] = {},
        [BAG_HOUSE_BANK_FIVE] = {},
        [BAG_HOUSE_BANK_SIX] = {},
        [BAG_HOUSE_BANK_SEVEN] = {},
        [BAG_HOUSE_BANK_EIGHT] = {},
        [BAG_HOUSE_BANK_NINE] = {},
        [BAG_HOUSE_BANK_TEN] = {},
    }

    return newObj
end

function GuildPlannerPro_Account:Initialize()
    self.TimeStamp = GetTimeStamp()
    self.IsESOPlusSubscriber = IsESOPlusSubscriber()
    self.ChampionLevel = GuildPlannerPro_Character:ExportChampionRank()
    self.Guilds = GuildPlannerPro_Guilds:GetGuilds()
    self.ItemSetCollectionSets = GuildPlannerPro_Sets:ExportItemSetCollectionSets()
    self.Achievements = GuildPlannerPro_Achievements:ExportAchievementsCompletionData(ACHIEVEMENT_PERSISTENCE_ACCOUNT)
    self.Stories = GuildPlannerPro_Collectibles:ExportStoriesCollectibles()
    self.Wallet = GuildPlannerPro_Character:GetCurrencyAmountForGivenWallet(CURRENCY_LOCATION_ACCOUNT)
    self.PlatformDisplayName = GetPlatformDisplayName()
    self.DecoratedPlatformDisplayName = DecorateDisplayName(GetPlatformDisplayName())
    self.CrossPlayDisplayName = GetCrossplayDisplayName()
    self.DecoratedCrossPlayDisplayName = DecorateDisplayName(GetCrossplayDisplayName())

    GuildPlannerPro_Account.GetFriendList(self)
    GuildPlannerPro_Account.GetIgnoredList(self)
end

function GuildPlannerPro_Account:GetFriendList()
    self.FriendList = {}
    for friendIndex = 1, GetNumFriends() do
        local displayName, note, _, secsSinceLogoff = GetFriendInfo(friendIndex)
        table.insert(self.FriendList, {
            DisplayName = displayName,
            Note = note,
            SecsSinceLogoff = secsSinceLogoff,
        })
    end
end

function GuildPlannerPro_Account:GetIgnoredList()
    self.IgnoredList = {}
    for ignoredIndex = 1, GetNumIgnored() do
        local displayName, note = GetIgnoredInfo(ignoredIndex)
        table.insert(self.IgnoredList, {
            DisplayName = displayName,
            Note = note,
        })
    end
end
