function FrankGrinder:LeadWarnings_ResetState()
    self._leadState = self._leadState or {}
    self._leadState.lastZoneId = -1
    self._leadState.lastLeadNotify = 0
end

function FrankGrinder:UpdateLeadWarningLabel(label, antiquityId)
    local state = self:GetSettingLeadWarningState(antiquityId)

    local text = state and GetString(GG_LE_REMIND) or GetString(GG_LE_IGNORE)
    local r, g, b, a = state and 0 or 1, state and 1 or 0, 0, 1

    label:SetText(text)

    if label.SetColor then
        label:SetColor(r, g, b, a)
        return
    end

    if label.SetNormalFontColor then
        label:SetNormalFontColor(r, g, b, a)
        return
    end

    self:DebugMsg("FG WARNING: Label has no color API")
end

function FrankGrinder:HookRBKeybind_Gamepad()
    local class = ZO_AntiquityJournalListGamepad
    if class._FrankGrinder_RBHooked then return end
    class._FrankGrinder_RBHooked = true

    local originalActivate = class.Activate
    class.Activate = function(selfObj, ...)
        FrankGrinder:InjectRBKeybind_Gamepad(selfObj)
        originalActivate(selfObj, ...)
    end
end

function FrankGrinder:InjectRBKeybind_Gamepad(selfObj)
    if selfObj._FrankGrinder_RBAdded then return end
    selfObj._FrankGrinder_RBAdded = true

    table.insert(selfObj.keybindStripDescriptor, {
        order = 25,
        keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
        name = function()
            local antiquityData = selfObj:GetCurrentAntiquityData()
            if antiquityData then
                local state = self:GetSettingLeadWarningState(antiquityData:GetId())
                return state and GetString(GG_LE_DISABLE_REMINDER) or GetString(GG_LE_ENABLE_REMINDER)
            end
            return GetString(GG_LE_TOGGLE_REMINDER)
        end,
        callback = function()
            local antiquityData = selfObj:GetCurrentAntiquityData()
            if not antiquityData then return end

            local id = antiquityData:GetId()
            local current = self:GetSettingLeadWarningState(id)
            self:SetSettingLeadWarningState(id, not current)

            selfObj:RefreshVisible()
            selfObj:RefreshAntiquity(antiquityData)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(selfObj.keybindStripDescriptor)
        end,
        visible = function()
            local categoryData = selfObj:GetCurrentSubcategoryData()
            local antiquityData = selfObj:GetCurrentAntiquityData()
            return ZO_IsAntiquityScryableSubcategory(categoryData) and antiquityData ~= nil
        end,
        sound = SOUNDS.GAMEPAD_MENU_FORWARD,
    })
end

function FrankGrinder:HookScryableRows_Gamepad()
    local class = ZO_AntiquityJournalListGamepad
    if class._FrankGrinder_Hooked then return end
    class._FrankGrinder_Hooked = true

    local original = class.SetupScryableAntiquityRow
    class.SetupScryableAntiquityRow = function(selfObj, control, data)
        original(selfObj, control, data)
        FrankGrinder:SetupScryableRow_Gamepad(control, data)
    end

    local originalNear = class.SetupScryableAntiquityNearExpirationRow
    class.SetupScryableAntiquityNearExpirationRow = function(selfObj, control, data)
        originalNear(selfObj, control, data)
        FrankGrinder:SetupScryableRow_Gamepad(control, data)
    end
end

function FrankGrinder:SetupScryableRow_Gamepad(control, data)
    if not control or not data then return end
    local antiquityId = data:GetId()
    if not antiquityId then return end

    if not control._FrankGrinder_ReminderLabel then
        local label = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        label:SetFont("ZoFontGamepad34")
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        label:SetAnchor(RIGHT, control, RIGHT, -20, 0)
        control._FrankGrinder_ReminderLabel = label
    end

    self:UpdateLeadWarningLabel(control._FrankGrinder_ReminderLabel, antiquityId)
end

function FrankGrinder:SetupTileHook_Keyboard(tile, tileData, control)
    if not tile or not control then return end

    local antiquityData = tile.tileData
    if not antiquityData or not antiquityData.GetId then return end

    local antiquityId = antiquityData:GetId()
    if type(antiquityId) ~= "number" then return end

    local icon = control:GetNamedChild("Icon")
    if not icon then return end

    if not control._FrankGrinder_ReminderToggle then
        local btn = WINDOW_MANAGER:CreateControl(nil, control, CT_BUTTON)
        btn:SetDimensions(60, 20)
        btn:SetFont("ZoFontGameSmall")
        btn:SetAnchor(TOP, icon, BOTTOM, 0, 4)

        btn:SetHandler("OnClicked", function()
            local current = self:GetSettingLeadWarningState(antiquityId)
            self:SetSettingLeadWarningState(antiquityId, not current)
            self:UpdateLeadWarningLabel(btn, antiquityId)
        end)

        control._FrankGrinder_ReminderToggle = btn
    end

    self:UpdateLeadWarningLabel(control._FrankGrinder_ReminderToggle, antiquityId)
end

function FrankGrinder:InitializeLeadWarningHook_Keyboard()
    local class = ZO_ScryableAntiquityTile_Keyboard
    if class._FrankGrinder_Hooked then return end
    class._FrankGrinder_Hooked = true

    local originalLayout = class.Layout
    class.Layout = function(selfObj, tileData)
        originalLayout(selfObj, tileData)
        FrankGrinder:SetupTileHook_Keyboard(selfObj, tileData, selfObj.control)
    end
end

function FrankGrinder:InitializeLeadWarningHook()
    self:InitializeLeadWarningHook_Keyboard()
    self:HookScryableRows_Gamepad()
    self:HookRBKeybind_Gamepad()
end

function FrankGrinder:GetMinLeadRemainingTime()
    local leadWarningPeriodSeconds = self:GetSettingLeadWarningPeriod() * 24 * 60 * 60

    local remainingTime = {
        anyLead = leadWarningPeriodSeconds,
        undugLead = leadWarningPeriodSeconds,
        noLoreLead = leadWarningPeriodSeconds,
    }

    local i = GetNextAntiquityId()
    while i do
        if DoesAntiquityHaveLead(i) then
            local leadtimeleft = GetAntiquityLeadTimeRemainingSeconds(i)

            if leadtimeleft == 0 then
                leadtimeleft = 33 * 24 * 60 * 60
            end

            if leadtimeleft > 0 and leadtimeleft <= leadWarningPeriodSeconds then
                if self:GetSettingLeadWarningState(i) then
                    local aquality = GetAntiquityQuality(i) or 0
                    local azoneid = GetAntiquityZoneId(i)
                    local aname = ZO_CachedStrFormat("<<C:1>>", GetAntiquityName(i))
                    local azone = ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(azoneid))

                    local numrecovered = GetNumAntiquitiesRecovered(i)
                    local loreleft = GetNumAntiquityLoreEntries(i) - GetNumAntiquityLoreEntriesAcquired(i)

                    if leadtimeleft < remainingTime.anyLead then
                        remainingTime.anyLead = leadtimeleft
                        remainingTime.anyLeadZone = azone
                        remainingTime.anyLeadQuality = aquality
                        remainingTime.anyLeadName = aname
                    end

                    if numrecovered == 0 and leadtimeleft < remainingTime.undugLead then
                        remainingTime.undugLead = leadtimeleft
                        remainingTime.undugLeadZone = azone
                        remainingTime.undugLeadQuality = aquality
                        remainingTime.undugLeadName = aname
                    end

                    if loreleft > 0 and leadtimeleft < remainingTime.noLoreLead then
                        remainingTime.noLoreLead = leadtimeleft
                        remainingTime.noLoreLeadZone = azone
                        remainingTime.noLoreLeadQuality = aquality
                        remainingTime.noLoreLeadName = aname
                    end
                end
            end
        end
        i = GetNextAntiquityId(i)
    end

    return remainingTime
end

function FrankGrinder:ShowLeadExpiryWarning()
    EVENT_MANAGER:UnregisterForUpdate(self.name .. ".LeadExpiryWarningDisplay")

    local remainingTime = self:GetMinLeadRemainingTime()
    local currentTime = GetTimeStamp()

    local leadWarningPeriodSeconds = self:GetSettingLeadWarningPeriod() * 24 * 60 * 60
    local leadNoWarningPeriodSeconds = self:GetSettingLeadNoWarningPeriod() * 60

    self._leadState = self._leadState or { lastLeadNotify = 0, lastZoneId = -1 }

    if remainingTime.anyLead < leadWarningPeriodSeconds
        and self._leadState.lastLeadNotify < (currentTime - leadNoWarningPeriodSeconds)
    then
        self._leadState.lastLeadNotify = currentTime

        local function SafeMeta(timeKey, nameKey, zoneKey, qualityKey)
            return {
                time    = remainingTime[timeKey],
                name    = remainingTime[nameKey]    or GetString(GG_LE_UNKNOWN_NAME),
                zone    = remainingTime[zoneKey]    or GetString(GG_LE_UNKNOWN_ZONE),
                quality = remainingTime[qualityKey] or 0,
            }
        end

        local anyLead   = SafeMeta("anyLead",   "anyLeadName",   "anyLeadZone",   "anyLeadQuality")
        local undugLead = SafeMeta("undugLead", "undugLeadName", "undugLeadZone", "undugLeadQuality")
        local noLore    = SafeMeta("noLoreLead","noLoreLeadName","noLoreLeadZone","noLoreLeadQuality")

        if self:GetSettingLeadWarningChatWindow() then
            if undugLead.time < leadWarningPeriodSeconds then
                local c = GetAntiquityQualityColor(undugLead.quality)
                self:ChatMsg(c:Colorize(GetString(GG_LE_NEW_LEAD)) .. GetString(GG_LE_EXPIRY_IN)
                    .. FrankGrinder.SecondsToClock(undugLead.time, "first_two") .. " (" .. undugLead.zone .. ")")
            end

            do
                local c = GetAntiquityQualityColor(anyLead.quality)
                self:ChatMsg(c:Colorize(GetString(GG_LE_LEAD)) .. GetString(GG_LE_EXPIRY_IN)
                    .. FrankGrinder.SecondsToClock(anyLead.time, "first_two") .. " (" .. anyLead.zone .. ")")
            end

            if noLore.time < leadWarningPeriodSeconds then
                local c = GetAntiquityQualityColor(noLore.quality)
                self:ChatMsg(c:Colorize(GetString(GG_LE_LORE_LEAD)) .. GetString(GG_LE_EXPIRY_IN)
                    .. FrankGrinder.SecondsToClock(noLore.time, "first_two") .. " (" .. noLore.zone .. ")")
            end
        end

        if self:GetSettingLeadWarningAnnounce() then
            local c = GetAntiquityQualityColor(anyLead.quality)
            local t = c:Colorize(anyLead.name)

            local announceText = GetString(GG_LE_EXPIRING_IN) .. FrankGrinder.SecondsToClock(anyLead.time, "first_two")

            -- Create message params
            local msg = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.LEVEL_UP)

            msg:SetText(
                announceText,
                t .. GetString(GG_LE_FOUND_IN) .. anyLead.zone
            )

            -- Optional: use a built‑in CSA visual style
            msg:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_CHAMPION_POINT_GAINED)

            -- Optional: suppress the icon frame
            msg:MarkSuppressIconFrame()

            -- IMPORTANT: enqueue instead of forcing display
            CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(msg)
        end        
    end
end

function FrankGrinder:InitializeLeadWarningDisplay()
    EVENT_MANAGER:RegisterForUpdate(self.name .. ".LeadExpiryWarningDisplay", 10000, function() self:ShowLeadExpiryWarning() end)
end

function FrankGrinder:PlayerZoneChange(eventCode, zoneName, subZoneName, newSubzone, zoneId, subZoneId)
    local zid = GetZoneId(GetUnitZoneIndex("player"))
    self._leadState = self._leadState or { lastLeadNotify = 0, lastZoneId = -1 }

    if self._leadState.lastZoneId ~= zid then
        self:InitializeLeadWarningDisplay()
        self._leadState.lastZoneId = zid
    end
end

function FrankGrinder:InitializeLeadWarning()
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ZONE_CHANGED)

    if self:GetSettingLeadWarningEnabled() then
        EVENT_MANAGER:RegisterForEvent(self.name, EVENT_ZONE_CHANGED, function(...) self:PlayerZoneChange(...) end)
        self:PlayerZoneChange()
    end
end
