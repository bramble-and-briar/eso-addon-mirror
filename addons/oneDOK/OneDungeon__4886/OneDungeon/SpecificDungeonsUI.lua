local A = OneDungeon
local statusStrings = { completed = ONEDUNGEON_COMPLETED, incomplete = ONEDUNGEON_INCOMPLETE,
    unavailable = ONEDUNGEON_UNAVAILABLE, unknown = ONEDUNGEON_UNKNOWN }
local categories = { { "Clear", "veteranClear", ONEDUNGEON_VETERAN_CLEAR }, { "HardMode", "hardMode", ONEDUNGEON_HARD_MODE_TITLE }, { "Trifecta", "trifecta", ONEDUNGEON_TRIFECTA } }

function A:Tooltip(control, text)
    if not text or text == "" then return end
    InitializeTooltip(InformationTooltip, control, TOPRIGHT, 0, 0, TOPLEFT)
    SetTooltipText(InformationTooltip, text)
end

function A:InitializeRow(control)
    control.normal = control:GetNamedChild("Normal")
    control.veteran = control:GetNamedChild("Veteran")
    for _, field in ipairs({ "normal", "veteran" }) do
        local difficulty = field
        ZO_CheckButton_SetToggleFunction(control[field], function(_, checked)
            if control.data then self:Select(control.data[difficulty], checked) end
        end)
    end
    local quest = control:GetNamedChild("Quest")
    quest:SetHandler("OnMouseEnter", function(c) self:Tooltip(c, GetString(ONEDUNGEON_QUEST_LEGEND)) end)
    quest:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    for _, category in ipairs(categories) do
        local cell = control:GetNamedChild(category[1])
        cell:SetHandler("OnMouseEnter", function(c)
            if c.achievementId then
                InitializeTooltip(AchievementTooltip, c, TOPRIGHT, 0, 0, TOPLEFT)
                AchievementTooltip:SetAchievement(c.achievementId)
            else
                self:Tooltip(c, c.tooltip)
            end
        end)
        cell:SetHandler("OnMouseExit", function() self:ClearTooltips() end)
    end
end

function A:ClearTooltips()
    ClearTooltip(InformationTooltip)
    ClearTooltip(AchievementTooltip)
end

function A:SetupQuestIcons(control, data)
    local story, pledge, glow = control:GetNamedChild("Story"), control:GetNamedChild("Pledge"), control:GetNamedChild("PledgeGlow")
    story:SetColor(1, 1, 1, 1)
    story:SetHidden(data.story ~= "unfinished" and data.story ~= "active")
    pledge:SetColor(0.35, 0.7, 1, 1)
    pledge:SetHidden(data.today ~= true and data.active ~= true)
    glow:SetColor(0.35, 0.7, 1, 0.65)
    glow:SetHidden(data.active ~= true)
end

function A:SetupDifficulty(button, location, title)
    ZO_CheckButton_SetCheckState(button, location and location:IsSelected() or false)
    ZO_CheckButton_SetEnableState(button, self:CanSelect(location))
    local detail
    if not location then detail = GetString(ONEDUNGEON_MISSING)
    elseif location:IsLocked() then detail = location:GetLockReasonText()
    elseif IsCurrentlySearchingForGroup() then detail = GetString(ONEDUNGEON_SEARCHING)
    else detail = location:GetNameKeyboard() end
    ZO_CheckButton_SetTooltipText(button, title .. "\n" .. (detail or ""))
end

function A:SetupRow(control, row)
    control.data = row
    self:SetupDifficulty(control.normal, row.normal, GetString(ONEDUNGEON_NORMAL))
    self:SetupDifficulty(control.veteran, row.veteran, GetString(ONEDUNGEON_VETERAN))
    local name = control:GetNamedChild("Name")
    name:SetText(row.name)
    local color = (self:CanSelect(row.normal) or self:CanSelect(row.veteran)) and ZO_NORMAL_TEXT or ZO_DISABLED_TEXT
    name:SetColor(color:UnpackRGBA())
    control:SetHandler("OnMouseExit", function()
        name:SetColor(color:UnpackRGBA())
    end)
    control:SetHandler("OnMouseEnter", function() name:SetColor(ZO_SELECTED_TEXT:UnpackRGBA()) end)
    local quest = control:GetNamedChild("Quest")
    self:SetupQuestIcons(quest, row.quest)
    for _, category in ipairs(categories) do
        local cell = control:GetNamedChild(category[1])
        local data = row.achievements[category[2]]
        local icon, state = cell:GetNamedChild("Icon"), cell:GetNamedChild("State")
        local hasIcon = (data.state == "completed" or data.state == "incomplete") and data.icon and data.icon ~= ""
        cell.achievementId = hasIcon and data.id or nil
        icon:SetHidden(not hasIcon)
        state:SetHidden(hasIcon == true)
        if hasIcon then
            icon:SetTexture(data.icon)
            icon:SetDesaturation(data.state == "completed" and 0 or 1)
            icon:SetAlpha(data.state == "completed" and 1 or 0.3)
            state:SetText("")
        else
            state:SetText(GetString(data.state == "unavailable" and ONEDUNGEON_UNAVAILABLE_SYMBOL or ONEDUNGEON_UNKNOWN_SYMBOL))
            state:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
        end
        cell.tooltip = GetString(category[3]) .. "\n" .. GetString(statusStrings[data.state])
        if data.name then cell.tooltip = cell.tooltip .. "\n\n" .. data.name .. "\n" .. (data.description or "") .. "\n\n" .. GetString(ONEDUNGEON_SCOPE) end
        if data.state == "unknown" then cell.tooltip = cell.tooltip .. "\n\n" .. GetString(ONEDUNGEON_ACHIEVEMENT_UNKNOWN) end
    end
end

function A:CreateUI()
    local wm = WINDOW_MANAGER
    self.panel = wm:CreateControl("OneDungeonPanel", self.finder.control, CT_CONTROL)
    self.panel:SetAnchor(TOPLEFT, self.finder.listSection, TOPLEFT)
    self.panel:SetAnchor(BOTTOMRIGHT, self.finder.listSection, BOTTOMRIGHT)
    self.panel:SetHidden(true)
    self.list = wm:CreateControlFromVirtual("OneDungeonList", self.panel, "ZO_ScrollList")
    self.list:SetAnchor(TOPLEFT, self.panel, TOPLEFT, 0, 32)
    self.list:SetAnchor(BOTTOMRIGHT, self.panel, BOTTOMRIGHT)
    ZO_ScrollList_AddDataType(self.list, 1, "OneDungeonRow", 32, function(c, row)
        self:Guard(function() self:SetupRow(c, row) end)
    end, function() self:ClearTooltips() end)
    local headers = { { GetString(ONEDUNGEON_NORMAL_SHORT), 2 }, { GetString(ONEDUNGEON_VETERAN_SHORT), 34 }, { GetString(ONEDUNGEON_DUNGEON), 68 },
        { GetString(ONEDUNGEON_QUEST), -270 }, { GetString(ONEDUNGEON_CLEAR), -144 }, { GetString(ONEDUNGEON_HARD_MODE), -96 }, { GetString(ONEDUNGEON_TRI_HEADER), -48 } }
    for index, entry in ipairs(headers) do
        local label = wm:CreateControl("OneDungeonHeader" .. index, self.panel, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        label:SetAnchor(TOPLEFT, self.panel, entry[2] < 0 and TOPRIGHT or TOPLEFT, entry[2] < 0 and entry[2] - ZO_SCROLL_BAR_WIDTH or entry[2], 4)
        label:SetText(entry[1])
    end
end

function A:RefreshVisible()
    if self.panel and not self.panel:IsHidden() and not self.failed then
        self:Guard(function() ZO_ScrollList_RefreshVisible(self.list) end)
    end
end

function A:BuildList()
    local rows = self:Discover(self.finder)
    for _, row in ipairs(rows) do self:Enrich(row) end
    ZO_ScrollList_Clear(self.list)
    local data = ZO_ScrollList_GetDataList(self.list)
    for _, row in ipairs(rows) do data[#data + 1] = ZO_ScrollList_CreateDataEntry(1, row) end
    ZO_ScrollList_Commit(self.list)
    self.rows = rows
end
