
-- doesn't work in zone 809 (The Wailing Prison)
function FrankGrinder:ListingsEqual(a, b)
    if not a or not b then return false end
    return a.title == b.title
        and a.trial == b.trial
        and a.tankReq == b.tankReq and a.tankAct == b.tankAct
        and a.healReq == b.healReq and a.healAct == b.healAct
        and a.dpsReq == b.dpsReq and a.dpsAct == b.dpsAct
end

function FrankGrinder:IsGroupFinderTrialIncluded(trialName)
    local key = self.Trials[trialName] and trialName or self.ZoneNameToTrial[trialName]
    if not key then return true end
    return self:GetSettingGroupFinderTrials(key)
end

function FrankGrinder:IsTrial(text)
    return self.Trials[text] ~= nil or self.ZoneNameToTrial[text] ~= nil
end

-- The background check rewrites the player's Group Finder filters. Don't do
-- that while they have the Group Finder open and are setting filters by hand.
function FrankGrinder:IsGroupFinderUIShowing()
    if GROUP_FINDER_KEYBOARD_SCENE and GROUP_FINDER_KEYBOARD_SCENE:IsShowing() then return true end
    if GROUP_FINDER_GAMEPAD_SCENE and GROUP_FINDER_GAMEPAD_SCENE:IsShowing() then return true end

    if SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName then
        local sceneName = SCENE_MANAGER:GetCurrentSceneName()
        if sceneName and zo_strlower(sceneName):find("groupfinder", 1, true) then
            return true
        end
    end

    return false
end

function FrankGrinder:GroupFinderCheck()

    -- Silent skip: NM automation owns Group Finder while active
    if self.IsNMKeyFarmEnabled and self:IsNMKeyFarmEnabled() then
        return
    end

    -- Silent skip: don't clobber filters the player is editing
    if self:IsGroupFinderUIShowing() then
        return
    end

    self:DebugMsg("GroupFinderCheck called")

    -- HARDENING: Check if Group Finder is available at all
    local status = GetGroupFinderStatusReason()
    if status ~= GROUP_FINDER_ACTION_RESULT_SUCCESS then
        self:DebugMsg("GroupFinder unavailable: " .. GetString("SI_GROUPFINDERACTIONRESULT", status))
        return
    end

    -- Check if the user already has a listing
    self._GFUserType = GetCurrentGroupFinderUserType()
    if self._GFUserType == GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING then
        self:DebugMsg("User has an active Group Listing, skipping search.")
        return
    end

    -- Check cooldowns and PvP restrictions
    if not (IsGroupFinderSearchOnCooldown() or IsPlayerInAvAWorld() or IsActiveWorldBattleground()) then
        ResetGroupFinderFilterOptionsToDefault()
        SetGroupFinderFilterCategory(GROUP_FINDER_CATEGORY_TRIAL, true)
        if GetGroupFinderFilterNumPrimaryOptions() == 2 then
            SetGroupFinderFilterPrimaryOptionByIndex(2, true) -- Veteran
        end
        SetGroupFinderFilterEnforceRoles(false)
        self._groupFinderSearchID = RequestGroupFinderSearch()
        self:DebugMsg("GroupFinderCheck SearchID: " .. tostring(self._groupFinderSearchID))
        return
    end

    -- Logging for blocked states
    if IsGroupFinderSearchOnCooldown() then
        self:DebugMsg("GroupFinderCheck: search on cooldown")
    end
    if IsPlayerInAvAWorld() or IsActiveWorldBattleground() then
        self:DebugMsg("GroupFinderCheck: player in AvA/Battleground")
    end
end

function FrankGrinder:GroupFinderSearchComplete(eventCode, result, searchId)
    -- Silent skip: NM automation active
    if self.IsNMKeyFarmEnabled and self:IsNMKeyFarmEnabled() then
        return
    end

    self:DebugMsg("GroupFinderSearchComplete called")
    if self._groupFinderSearchID ~= searchId then return end

    local newSnapshot = {}
    local oldSnapshot = self.lastListings or {}

    self:DebugMsg(tostring(GetGroupFinderSearchNumListings()) .. " group listings found.")

    if GetGroupFinderSearchNumListings() > 0 then
        for i = 1, GetGroupFinderSearchNumListings() do
            -- Any of these can come back nil for a malformed listing, and they
            -- all get concatenated into the chat output below.
            local title = GetGroupFinderSearchListingTitleByIndex(i) or ""
            local leader = GetGroupFinderSearchListingLeaderDisplayNameByIndex(i)
            local _, secondary = GetGroupFinderSearchListingOptionsSelectionTextByIndex(i)
            secondary = secondary or ""

            local tankReq, tankAct = GetGroupFinderSearchListingRoleStatusCount(i, LFG_ROLE_TANK)
            local healReq, healAct = GetGroupFinderSearchListingRoleStatusCount(i, LFG_ROLE_HEAL)
            local dpsReq, dpsAct = GetGroupFinderSearchListingRoleStatusCount(i, LFG_ROLE_DPS)

            local listing =
            {
                leader = leader,
                title = title,
                trial = secondary,
                tankReq = tankReq, tankAct = tankAct,
                healReq = healReq, healAct = healAct,
                dpsReq = dpsReq, dpsAct = dpsAct,
            }

            -- leader keys the snapshot; without it we can't diff the listing
            if leader and leader ~= "" and self:IsGroupFinderTrialIncluded(secondary) then
                newSnapshot[leader] = listing

                local old = oldSnapshot[leader]
                if not old then
                    self:ChatMsg("|c00ff00" .. GetString(GG_GF_NEW_LISTING) .. " " .. i .. ":|r |cffffff[" .. leader .. "]|r " .. title .. "|r (" .. secondary .. ")"
                        .. " T:|c" .. FrankGrinder.RedGreenGradient(tankAct, tankReq) .. tostring(tankAct) .. "/" .. tostring(tankReq) .. "|r"
                        .. " H:|c" .. FrankGrinder.RedGreenGradient(healAct, healReq) .. tostring(healAct) .. "/" .. tostring(healReq) .. "|r"
                        .. " D:|c" .. FrankGrinder.RedGreenGradient(dpsAct, dpsReq) .. tostring(dpsAct) .. "/" .. tostring(dpsReq) .. "|r")
                elseif not self:ListingsEqual(old, listing) then
                    self:ChatMsg("|cffff00" .. GetString(GG_GF_UPDATED_LISTING) .. " " .. i .. ":|r |cffffff[" .. leader .. "]|r " .. title .. "|r (" .. secondary .. ")"
                        .. " T:|c" .. FrankGrinder.RedGreenGradient(tankAct, tankReq) .. tostring(tankAct) .. "/" .. tostring(tankReq) .. "|r"
                        .. " H:|c" .. FrankGrinder.RedGreenGradient(healAct, healReq) .. tostring(healAct) .. "/" .. tostring(healReq) .. "|r"
                        .. " D:|c" .. FrankGrinder.RedGreenGradient(dpsAct, dpsReq) .. tostring(dpsAct) .. "/" .. tostring(dpsReq) .. "|r")
                end
            end
        end
    end

    for leader, oldListing in pairs(oldSnapshot) do
        if not newSnapshot[leader] then
            self:ChatMsg("|cFF0000" .. GetString(GG_GF_REMOVED_LISTING) .. ":|r |cffffff[" .. leader .. "]|r " .. (oldListing.title or "") .. "|r (" .. (oldListing.trial or "") .. ")")
        end
    end

    self.lastListings = newSnapshot

    local filteredCount = 0
    for _ in pairs(newSnapshot) do filteredCount = filteredCount + 1 end

    if filteredCount == 0 and (self.GFcount == nil or self.GFcount > 0) then
        self:ChatMsg("|cffffff" .. GetString(GG_GF_NO_LISTING))
    end

    self.GFcount = filteredCount
    self._groupFinderSearchID = nil
end

--------------------------------------------------------------------------------
-- Initialiser: registers normal search 
--------------------------------------------------------------------------------

function FrankGrinder:InitializeGroupFinderNotifications()
    local EM = EVENT_MANAGER

    -- Existing search notification loop
    EM:UnregisterForUpdate(self.name .. ".GroupFinderCheck")
    EM:UnregisterForEvent(self.name, EVENT_GROUP_FINDER_SEARCH_COMPLETE)

    if self:GetSettingGroupFinderEnabled() then
        EM:RegisterForUpdate(self.name .. ".GroupFinderCheck", self:GetSettingGroupFinderCheckInterval() * 1000, function()
            self:GroupFinderCheck()
        end)
        EM:RegisterForEvent(self.name, EVENT_GROUP_FINDER_SEARCH_COMPLETE, function(...)
            self:GroupFinderSearchComplete(...)
        end)
        self:GroupFinderCheck()
    end

end

