local A = OneDungeon

function A:IsSpecificVisible()
    local finder = self.finder
    local entry = finder.filterComboBox:GetSelectedItemData()
    return finder.fragment:IsShowing() and entry and entry.data and not entry.data.singular
        and finder.lfmPromptSection:IsHidden()
end

function A:Guard(callback)
    if self.failed then return end
    local ok, err = pcall(callback)
    if not ok then
        self.failed = true
        self.errors.integration = tostring(err)
        if self.panel then self.panel:SetHidden(true) end
        EVENT_MANAGER:UnregisterForUpdate(self.name .. "DailyReset")
        self.finder.listSection:SetHidden(not self:IsSpecificVisible())
        d(GetString(ONEDUNGEON_FALLBACK))
        self:Log(err)
    end
end

function A:Sync()
    if self.failed then return end
    self:Guard(function()
        local visible = self:IsSpecificVisible()
        if visible then
            self:Invalidate()
            self:BuildList()
            if self.failed then return end
            self.finder.listSection:SetHidden(true)
        end
        self.panel:SetHidden(not visible)
        self:Optional("daily reset timer", function() self:ScheduleDailyRefresh() end)
    end)
end

function A:RefreshInformation()
    self:Invalidate()
    if self.panel and not self.panel:IsHidden() and not self.failed then
        self:Guard(function()
            for _, row in ipairs(self.rows or {}) do self:Enrich(row) end
            ZO_ScrollList_RefreshVisible(self.list)
        end)
    end
end

function A:Dump()
    d("OneDungeon " .. self.version .. "; API " .. GetAPIVersion())
    for key, value in pairs(self.errors) do d(key .. ": " .. value) end
    for _, row in ipairs(self.rows or {}) do
        local q, achievements = row.quest, row.achievements
        local parts = { row.name, "zone=" .. tostring(row.zoneId), "N=" .. tostring(row.normalActivityId), "V=" .. tostring(row.veteranActivityId),
            "story=" .. tostring(q.story), "today=" .. tostring(q.today), "active=" .. tostring(q.active) }
        for _, category in ipairs({ "veteranClear", "hardMode", "trifecta" }) do
            local info = achievements[category]
            parts[#parts + 1] = category .. "=" .. (info.ids and table.concat(info.ids, ",") or tostring(info.id)) .. "/" .. info.state
        end
        d(table.concat(parts, " | "))
    end
end

function A:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("OneDungeonSavedVariables", 1, nil, { debug = false })
    SLASH_COMMANDS["/onedungeon"] = function(command)
        if command == "debug" then
            self.saved.debug = not self.saved.debug
            d("OneDungeon debug: " .. tostring(self.saved.debug))
            for key, value in pairs(self.errors) do d(key .. ": " .. value) end
        elseif command == "dump" then self:Dump()
        elseif command == "refresh" then self:RefreshInformation()
        else d(GetString(ONEDUNGEON_COMMAND_HELP)) end
    end
    self.finder = DUNGEON_FINDER_KEYBOARD
    if not self.finder or not self.finder.listSection or not self.finder.navigationTree then
        self.errors.integration = "Unsupported Dungeon Finder structure; vanilla retained."
        return
    end
    self:Guard(function()
        self:CreateUI()
        SecurePostHook(self.finder, "RefreshView", function() self:Sync() end)
        SecurePostHook(self.finder, "ShowPrimaryControls", function() self:Sync() end)
        SecurePostHook(self.finder, "HidePrimaryControls", function()
            self.panel:SetHidden(true)
            EVENT_MANAGER:UnregisterForUpdate(self.name .. "DailyReset")
        end)
        ZO_ACTIVITY_FINDER_ROOT_MANAGER:RegisterCallback("OnSelectionsChanged", function() self:RefreshVisible() end)
        self.finder.fragment:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_FRAGMENT_SHOWN then self:Sync()
            elseif newState == SCENE_FRAGMENT_HIDDEN then
                self.panel:SetHidden(true)
                EVENT_MANAGER:UnregisterForUpdate(self.name .. "DailyReset")
            end
        end)
        for _, event in ipairs({ EVENT_QUEST_ADDED, EVENT_QUEST_REMOVED, EVENT_QUEST_COMPLETE,
            EVENT_ACHIEVEMENT_AWARDED, EVENT_ACHIEVEMENT_UPDATED, EVENT_ACHIEVEMENTS_UPDATED, EVENT_PLAYER_ACTIVATED }) do
            EVENT_MANAGER:RegisterForEvent(self.name, event, function() self:RefreshInformation() end)
        end
        self:Sync()
    end)
end

EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A:Initialize()
end)
