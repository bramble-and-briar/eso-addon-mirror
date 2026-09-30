local A = OneDungeon

function A:Discover(finder)
    local root = ZO_ACTIVITY_FINDER_ROOT_MANAGER
    local modes = finder.dataManager:GetFilterModeData()
    local rows, byZone = {}, {}
    for _, activityType in ipairs({ LFG_ACTIVITY_DUNGEON, LFG_ACTIVITY_MASTER_DUNGEON }) do
        local field = activityType == LFG_ACTIVITY_DUNGEON and "normal" or "veteran"
        for _, location in ipairs(root:GetLocationsData(activityType) or {}) do
            if location:IsSpecificEntryType() and modes:IsEntryTypeVisible(location:GetEntryType())
                and location:IsActive() and not location:ShouldForceFullPanelKeyboard() then
                local zoneId = location:GetZoneId()
                local key = zoneId and zoneId > 0 and ("zone:" .. zoneId) or ("activity:" .. location:GetId())
                local row = byZone[key]
                if not row then
                    row = { key = key, zoneId = zoneId, name = zo_strformat(SI_LFG_ACTIVITY_NAME, location:GetRawName()) }
                    rows[#rows + 1], byZone[key] = row, row
                end
                -- Never silently lose a selectable activity when upstream identity becomes ambiguous.
                assert(not row[field], "Ambiguous dungeon zone " .. tostring(zoneId))
                row[field] = location
                row[field .. "ActivityId"] = location:GetId()
                if field == "normal" then row.name = zo_strformat(SI_LFG_ACTIVITY_NAME, location:GetRawName()) end
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.name == b.name then return a.key < b.key end
        return a.name < b.name
    end)
    return rows
end

function A:CanSelect(location)
    if not location or not location:IsActive() or location:IsLocked() or IsCurrentlySearchingForGroup() then return false end
    local locked = self.finder:GetLevelLockInfoByActivity(location:GetActivityType())
    return not locked
end

function A:Select(location, selected)
    if self:CanSelect(location) then
        ZO_ACTIVITY_FINDER_ROOT_MANAGER:SetLocationSelected(location, selected)
    end
    self:RefreshVisible()
end
