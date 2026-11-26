-- shared
-- What the whole account shares, read from whichever character is logged in: Champion Points,
-- the achievement total, every character on the account (for the rows of characters not read
-- yet), the item set collection and outfit styles. They show on the brag card.
local CT = FurysCharacterTracker

CT.Track({
    id = "account",
    read = function(_, account)
        account.championPoints = GetPlayerChampionPointsEarned()
        account.achievementTotal = GetTotalAchievementPoints()
        local roster = {}
        for index, info in ipairs(CT.Roster:GameCharacters()) do roster[index] = CT.Roster.RosterLine(info) end
        account.roster, account.characterNames = roster, nil
        account.lastScan = GetTimeStamp()
    end,
    events = { EVENT_CHAMPION_POINT_GAINED },
})

-- The item set collection ("sticker book"): set pieces unlocked.
CT.Track({
    id = "setItems",
    read = function(_, account)
        local pieces, piecesTotal = 0, 0
        local setId = GetNextItemSetCollectionId()
        while setId do
            piecesTotal = piecesTotal + GetNumItemSetCollectionPieces(setId)
            pieces = pieces + GetNumItemSetCollectionSlotsUnlocked(setId)
            setId = GetNextItemSetCollectionId(setId)
        end
        account.setPieces, account.setPiecesTotal = pieces, piecesTotal
    end,
    events = { EVENT_ITEM_SET_COLLECTION_UPDATED, EVENT_ITEM_SET_COLLECTIONS_UPDATED },
})

CT.Track({
    id = "outfitStyles",
    read = function(_, account)
        local styles, stylesTotal = 0, 0
        local categoryType = COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE
        for index = 1, GetTotalCollectiblesByCategoryType(categoryType) do
            stylesTotal = stylesTotal + 1
            if IsCollectibleUnlocked(GetCollectibleIdFromType(categoryType, index)) then styles = styles + 1 end
        end
        account.outfitStyles, account.outfitStylesTotal = styles, stylesTotal
    end,
    -- Collectibles change for many reasons (a pet summoned, a hat hidden): only outfit styles matter here.
    start = function(queue)
        EVENT_MANAGER:RegisterForEvent(CT.name .. "OutfitStyle", EVENT_COLLECTIBLE_UPDATED, function(_, collectibleId)
            if GetCollectibleCategoryType(collectibleId) == COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE then queue() end
        end)
        EVENT_MANAGER:RegisterForEvent(CT.name .. "OutfitStyles", EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, queue)
    end,
})
