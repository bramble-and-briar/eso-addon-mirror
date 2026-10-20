FrankGrinder.charList = FrankGrinder.charList or {}
FrankGrinder.lastListings = FrankGrinder.lastListings or {}

function FrankGrinder:IsWindowOpen()
    return FrankGrinder_GUI and not FrankGrinder_GUI:IsHidden()
end

function FrankGrinder:SetWindowOpen(open)
    open = open and true or false
    self.active = open
    FrankGrinder_GUI:SetHidden(not open)
    if open then
        self:UpdateDataLines()
    end
end

function FrankGrinder:ToggleWindow()
    if FrankGrinder.A() then
        self:SetWindowOpen(not self:IsWindowOpen())
    end
end

function FrankGrinder:RequestUIRefresh(reason)
    if self._uiRefreshQueued then return end
    self._uiRefreshQueued = true

    zo_callLater(function()
        self._uiRefreshQueued = false
        if self:IsWindowOpen() then
            self:UpdateDataLines()
        end
    end, 50)
end

local function GCCId() return GetCurrentCharacterId() end

function FrankGrinder:GetLastTrialTime(trialKey, charId)
    if not self.Trials[trialKey] then
        self:DebugMsg("GetLastTrialTime: invalid trial: " .. tostring(trialKey))
        return 0
    end

    local charData = self.SV.timeData[charId]
    if not charData then
        self:DebugMsg("GetLastTrialTime: missing timeData for charId " .. tostring(charId))
        return 0
    end

    if charData[trialKey] == nil then
        charData[trialKey] = 0
    end

    return charData[trialKey] or 0
end

function FrankGrinder:SetTrialTime(trialKey)
    if not self.Trials[trialKey] then
        self:DebugMsg("SetTrialTime: invalid trial: " .. tostring(trialKey))
        return
    end

    local charId = GCCId()
    self.SV.timeData[charId] = self.SV.timeData[charId] or {}
    self.SV.timeData[charId][trialKey] = GetTimeStamp()    
end

function FrankGrinder:UpdateTime(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questID)
    if not isCompleted then return end

    local charId = GCCId()
    self:DebugMsg("QuestId: " .. tostring(questID))

    for trialKey, trialData in pairs(self.Trials) do
        if questID == trialData.questId then
            local lastTime = self:GetLastTrialTime(trialKey, charId)
            if FrankGrinder.GetTimeRemaining(lastTime) <= 0 then
                self:SetTrialTime(trialKey)
                self:RequestUIRefresh("trial completion")
                return
            end
        end
    end
end

function FrankGrinder:FillLine(currLine, currItem)
    currLine.name:SetText(currItem and currItem.name or "")

    local function SafeSet(ctrl, value)
        if not ctrl then return end
        local yes = ctrl:GetNamedChild("Yes")
        local no  = ctrl:GetNamedChild("No")
        if yes then yes:SetHidden(not value) end
        if no  then no:SetHidden(value) end
    end

    if not currItem then
        for trialKey in pairs(self.Trials) do
            SafeSet(currLine[trialKey], false)
        end
        return
    end

    for trialKey in pairs(self.Trials) do
        SafeSet(currLine[trialKey], currItem[trialKey] == true)
    end
end

function FrankGrinder:InitialiseTimeLines()
    -- Iterate the rows that actually exist, not the current character count:
    -- rows are built once and the count can drift if a character is created
    -- or deleted mid-session.
    local lines = FrankGrinder_GUI_ListHolder.lines or {}

    for i = 1, #lines do
        local currLine = lines[i]
        local currData = FrankGrinder_GUI_ListHolder.dataLines[i]

        if currLine then
            self:FillLine(currLine, currData)

            local isCurrent = currData and currData.name == self._currentCharacterName
            currLine:GetNamedChild("_TopDiv"):SetHidden(not isCurrent)
            currLine:GetNamedChild("_BottomDiv"):SetHidden(not isCurrent)
        end
    end

    FrankGrinder_GUI_TimeUntilReset:SetText(FrankGrinder.SecondsToClock(FrankGrinder.GetTimeRemaining(GetTimeStamp()), "first_two"))
end

function FrankGrinder:UpdateDataLines()
    local dataLines = {}

    self:GetCharacterListInOrder()

    if GetNumCharacters() > 0 and self.SV.numChars and self.SV.numChars > 0 then
        self:DebugMsg("UpdateDataLines: charlist count = " .. tostring(#self.charList))

        for _, v in pairs(self.charList) do
            local entry = { name = v.charName }

            for trialKey in pairs(self.Trials) do
                local lastTime = self:GetLastTrialTime(trialKey, v.charId)
                entry[trialKey] = FrankGrinder.GetTimeRemaining(lastTime) > 0
            end

            table.insert(dataLines, entry)
        end
    end

    FrankGrinder_GUI_ListHolder.dataLines = dataLines
    self:InitialiseTimeLines()
end

function FrankGrinder:CreateLine(i, predecessor, parent)
    local record = CreateControlFromVirtual("FrankGrinder_Row_", parent, "FrankGrinder_SlotTemplate", i)

    record.name = record:GetNamedChild("_Name")

    for trialKey in pairs(self.Trials) do
        record[trialKey] = record:GetNamedChild("_Time" .. trialKey)
    end

    record:SetHidden(false)
    record:SetMouseEnabled(true)
    record:SetHeight(26)

    if i == 1 then
        record:SetAnchor(TOPLEFT,  FrankGrinder_GUI_ListHolder, TOPLEFT,  0, 0)
        record:SetAnchor(TOPRIGHT, FrankGrinder_GUI_ListHolder, TOPRIGHT, 0, 0)
    else
        record:SetAnchor(TOPLEFT,  predecessor, BOTTOMLEFT,  0, FrankGrinder_GUI_ListHolder.rowHeight)
        record:SetAnchor(TOPRIGHT, predecessor, BOTTOMRIGHT, 0, FrankGrinder_GUI_ListHolder.rowHeight)
    end

    record:SetParent(FrankGrinder_GUI_ListHolder)
    return record
end

function FrankGrinder:CreateListHolder()
    FrankGrinder_GUI_ListHolder.dataLines = {}
    FrankGrinder_GUI_ListHolder.lines = {}

    local predecessor = nil
    for i = 1, GetNumCharacters() do
        FrankGrinder_GUI_ListHolder.lines[i] = self:CreateLine(i, predecessor, FrankGrinder_GUI_ListHolder)
        predecessor = FrankGrinder_GUI_ListHolder.lines[i]
    end
end

function FrankGrinder:GetCharacterListInOrder()
    local zf = zo_strformat
    local LCK = LibCharacterKnowledge
    local LCK_IsLoaded = self._lckIsLoaded == true

    local zosIndex = {}
    local zosCount = 0
    local charCount = 0
    local charList = {}

    if LCK_IsLoaded and LCK then
        for i = 1, GetNumCharacters() do
            local name, _, _, _, _, _, id = GetCharacterInfo(i)
            zosIndex[id] = { charId = id, idx = i, charName = zf("<<t:1>>", name) }
            zosCount = zosCount + 1
        end

        local lckList = LCK.GetCharacterList()

        for _, v in pairs(lckList) do
            if (v.account == GetDisplayName()) and zosIndex[v.id] then
                local _, _, _, class, _, alliance = GetCharacterInfo(zosIndex[v.id].idx)
                charCount = charCount + 1
                charList[charCount] = {
                    charId = v.id,
                    charName = v.name,
                    classId = class,
                    allianceId = alliance,
                    idx = zosIndex[v.id].idx
                }
                zosIndex[v.id] = nil
                zosCount = zosCount - 1
            end
        end

        if zosCount > 0 then
            local leftovers = {}
            for _, v in pairs(zosIndex) do table.insert(leftovers, v) end
            table.sort(leftovers, function(a, b) return a.charName < b.charName end)

            for _, v in ipairs(leftovers) do
                local _, _, _, class, _, alliance = GetCharacterInfo(v.idx)
                charCount = charCount + 1
                charList[charCount] = {
                    charId = v.charId,
                    charName = v.charName,
                    classId = class,
                    allianceId = alliance,
                    idx = v.idx
                }
            end
        end

    else
        for i = 1, GetNumCharacters() do
            local name, _, _, class, _, alliance, id = GetCharacterInfo(i)
            table.insert(charList, {
                charId = id,
                charName = zf("<<t:1>>", name),
                classId = class,
                allianceId = alliance
            })
        end
        table.sort(charList, function(a, b) return a.charName < b.charName end)
    end

    self.charList = ZO_DeepTableCopy(charList)
    return self.charList
end

function FrankGrinder:UpdateCharList()
    self.SV.charInfo = nil
    self:GetCharacterListInOrder()

    if #self.charList == 0 then
        self:DebugMsg("No characters found in charList.")
        return
    end

    self.SV.timeData = self.SV.timeData or {}

    -- Drive off charList, not GetNumCharacters(): if the two ever disagree
    -- this would index past the end of the list.
    for i = 1, #self.charList do
        local entry = self.charList[i]
        local id = entry.charId

        if self.SV.timeData[id] == nil then
            self.SV.timeData[id] = ZO_DeepTableCopy(self.timeDataDefaults)
        end

        self.SV.timeData[id].charName = entry.charName

        if GCCId() == id then
            self._currentCharacterName = entry.charName
        end
    end

    self.SV.numChars = GetNumCharacters()
end

function FrankGrinder:PrintTrialTimes(trialKey, charId)
    local lastTime = self:GetLastTrialTime(trialKey, charId)
    local elapsed  = FrankGrinder.SecondsToClock(FrankGrinder.GetTimeElapsed(lastTime))
    local remain   = FrankGrinder.SecondsToClock(FrankGrinder.GetTimeRemaining(lastTime))

    self:ChatMsg(string.format("%s: %s", trialKey .. GetString(GG_ELAPSED), elapsed))
    self:ChatMsg(string.format("%s: %s", trialKey .. GetString(GG_REMAINING), remain))
end

function FrankGrinder:OnStart()
    local firstRun = ((self.SV.firstRun or self.SV.numChars == 0) and true or false)

    self:GetCharacterListInOrder()

    if firstRun then
        self.SV.numChars = GetNumCharacters()
        for _, v in pairs(self.charList) do
            self.SV.timeData[v.charId] = ZO_DeepTableCopy(self.timeDataDefaults)
            self.SV.timeData[v.charId].charName = v.charName
        end
        self.SV.firstRun = false
    else
        self:UpdateCharList()
    end

    for i = 1, GetNumCharacters() do
        local _, _, _, _, _, _, id = GetCharacterInfo(i)
        self.SV.timeData[id] = self.SV.timeData[id] or ZO_DeepTableCopy(self.timeDataDefaults)
        for k, v in pairs(self.timeDataDefaults) do
            if self.SV.timeData[id][k] == nil then
                self.SV.timeData[id][k] = v
            end
        end
    end

    FrankGrinder_GUI:ClearAnchors()
    FrankGrinder_GUI:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    FrankGrinder_GUI:SetHeight(GetNumCharacters() * 26 + FrankGrinder_GUI_Header:GetHeight() + 18)

    FrankGrinder_GUI_TimeUntilReset:SetText(FrankGrinder.SecondsToClock(FrankGrinder.GetTimeRemaining(GetTimeStamp()), "first_two"))

    self:CreateListHolder()

    FrankGrinder_GUI_Header_Title:SetText(self.displayTitle)
    FrankGrinder_GUI_Header_HeaderName:SetText(GetString(GG_CHARACTERS))

    for trialKey in pairs(self.Trials) do
        local headerCtrl = _G["FrankGrinder_GUI_Header_Header" .. trialKey]
        if headerCtrl then
            headerCtrl:SetText(zo_strformat("<<t:1>>", trialKey))
        else
            self:DebugMsg("Missing header control for trial: " .. tostring(trialKey))
        end
    end
end
