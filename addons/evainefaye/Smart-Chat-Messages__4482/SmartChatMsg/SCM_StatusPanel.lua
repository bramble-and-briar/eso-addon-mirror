SmartChatMsg = SmartChatMsg or {}

-- Status panel state accessors and UI helpers extracted from the main addon files.
-- This file keeps status-panel creation, layout, persistence accessors, and refresh logic together
-- without changing the existing SmartChatMsg method names or behavior.

function SmartChatMsg:NormalizeOpenStatusPanelOnRun(value)
    return value == true
end


function SmartChatMsg:GetGuildOpenStatusPanelOnRun(commandId, guildName)
    local settings = self:GetCommandGuildSettings(commandId, guildName, false)
    if settings and settings.openStatusPanelOnRun ~= nil then
        return self:NormalizeOpenStatusPanelOnRun(settings.openStatusPanelOnRun)
    end

    return false
end


function SmartChatMsg:SetGuildOpenStatusPanelOnRun(commandId, guildName, openStatusPanelOnRun)
    local command = self:GetCommandById(commandId)
    if not command then
        return false, "The selected Command no longer exists."
    end

    local settings = self:GetCommandGuildSettings(commandId, guildName, true)
    if not settings then
        return false, "Select a Guild first."
    end

    settings.openStatusPanelOnRun = self:NormalizeOpenStatusPanelOnRun(openStatusPanelOnRun)
    return true
end


function SmartChatMsg:GetStatusPanelState()
    local state = self.savedVars.statusPanelState
    if type(state) ~= "table" then
        self.savedVars.statusPanelState = {
            visible = false,
            offsetX = -40,
            offsetY = 180,
        }
        state = self.savedVars.statusPanelState
    end

    state.visible = state.visible == true
    state.offsetX = type(state.offsetX) == "number" and math.floor(state.offsetX) or -40
    state.offsetY = type(state.offsetY) == "number" and math.floor(state.offsetY) or 180
    return state
end


function SmartChatMsg:GetStatusPanelVisiblePreference()
    return self:GetStatusPanelState().visible == true
end


function SmartChatMsg:SetStatusPanelVisiblePreference(visible)
    self:GetStatusPanelState().visible = visible == true
end


function SmartChatMsg:GetStatusPanelAnchorOffsets()
    local state = self:GetStatusPanelState()
    return state.offsetX, state.offsetY
end


function SmartChatMsg:SetStatusPanelAnchorOffsets(offsetX, offsetY)
    local state = self:GetStatusPanelState()
    state.offsetX = type(offsetX) == "number" and math.floor(offsetX) or -40
    state.offsetY = type(offsetY) == "number" and math.floor(offsetY) or 180
end


function SmartChatMsg:ShouldOpenStatusPanelOnRun(commandId, guildName)
    if self:GetGuildOpenStatusPanelOnRun(commandId, guildName) ~= true then
        return false
    end

    if self:GetGuildAutoPopulateOnZone(commandId, guildName) == true then
        return true
    end

    local repeatMinutes = self:GetGuildReminderMinutes(commandId, guildName)
    return type(repeatMinutes) == "number" and repeatMinutes > 0
end


function SmartChatMsg:OpenStatusPanelOnRunIfConfigured(commandId, guildName)
    if self:ShouldOpenStatusPanelOnRun(commandId, guildName) then
        self:SetStatusPanelVisible(true)
    end
end


function SmartChatMsg:FormatStatusDuration(secondsRemaining)
    if type(secondsRemaining) ~= "number" or secondsRemaining <= 0 then
        return "Ready"
    end

    local total = math.max(0, math.floor(secondsRemaining))
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local seconds = total % 60

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, seconds)
    end

    return string.format("%02d:%02d", minutes, seconds)
end


function SmartChatMsg:GetStatusPanelZoneTimerText(zoneId, secondsRemaining, isCurrent)
    if isCurrent then
        if not self:IsAutoPopulateEligibleZone(zoneId) then
            return "N/A", false
        end
    else
        if type(zoneId) ~= "number" or zoneId == 0 then
            return "N/A", false
        end
    end

    return self:FormatStatusDuration(secondsRemaining), true
end


function SmartChatMsg:GetStatusPanelMaxVisibleCooldownRows()
    return 10
end


function SmartChatMsg:GetStatusPanelRepeatSectionMaxHeight()
    return 400
end


function SmartChatMsg:GetStatusPanelRepeatCardHeight()
    return 164
end

function SmartChatMsg:GetStatusSectionExpanded(section,hasContent)
    self.statusSectionStates=self.statusSectionStates or {}
    local state=self.statusSectionStates[section]
    if not state or state.hasContent~=hasContent then
        state={hasContent=hasContent,expanded=hasContent};self.statusSectionStates[section]=state
    end
    return state.expanded
end

function SmartChatMsg:ToggleStatusSection(section)
    local state=self.statusSectionStates and self.statusSectionStates[section]
    if not state then return end
    state.expanded=not state.expanded
    if self.statusPanelVisible then self:RefreshStatusPanel() end
end

function SmartChatMsg:GetRepeatCardTimingText(row)
    local text="Last Sent: "..tostring(row.lastSentText)
    if row.isActive then text=text.." | Next Send: "..tostring(row.nextSendText) end
    return text
end

function SmartChatMsg:GetReminderPanelControlState(commandId,guildName)
    if self:GetGuildRunAt(commandId,guildName)=="SCHEDULED" then
        local schedule=self:GetGuildSchedule(commandId,guildName)
        if not schedule then return "OFF","ON" end
        if schedule.paused then return "PAUSED","OFF" end
        return schedule.enabled and "ON" or "OFF",schedule.enabled and "PAUSED" or "ON"
    end
    local key=self:GetReminderStateKey(commandId,guildName)
    local paused=self.repeatPanelPaused and self.repeatPanelPaused[key]
    if paused then return "PAUSED","OFF" end
    local pending=self.pendingRestoreState and self.pendingRestoreState.metadata
    local queued=self.chatPopulationQueue and self.chatPopulationQueue[key]
    local preparing=(pending and pending.commandId==commandId and self:StringsEqualIgnoreCase(pending.guildName or "",guildName)) or queued
    local active=self:IsReminderAutomationActive(commandId,guildName) or preparing
    return active and "ON" or "OFF",active and "PAUSED" or "ON"
end

function SmartChatMsg:IsScheduledOccurrenceCurrent(commandId,guildName)
    local schedule=self:GetGuildSchedule(commandId,guildName)
    local occurrence=schedule and self:GetScheduleOccurrence(schedule,GetTimeStamp())
    return occurrence and GetTimeStamp()>=occurrence.startsAtUtc and GetTimeStamp()<occurrence.endsAtUtc or false
end

function SmartChatMsg:GetScheduledCardDetails(commandId,guildName,controlState)
    if controlState=="PAUSED" then return "Paused","Paused" end
    if controlState=="OFF" then return "Inactive","Off" end
    local wait=self:GetScheduleChatWaitText(commandId,guildName)
    if wait then return "Active — "..wait,wait end
    local pacingAt,pacingReason=self:GetSchedulePacingDelay(commandId,guildName)
    local schedule=self:GetGuildSchedule(commandId,guildName)
    local phase=self:GetSchedulePhase(schedule,GetTimeStamp())
    local due=self:GetScheduledDueAt(commandId,guildName,phase)
    if due==math.huge then return "Active — Complete for this occurrence","No further delivery" end
    if pacingAt then return "Active — "..(self.scheduleStartupEndsAt==pacingAt and "Startup delay" or "5-minute pause"),
        self:FormatStatusDuration(math.max(due,pacingAt)-GetTimeStamp()) end
    if due>GetTimeStamp() then return "Active — Cooldown",self:FormatStatusDuration(due-GetTimeStamp()) end
    local runtime=self.scheduleRuntime and self.scheduleRuntime[self:GetReminderStateKey(commandId,guildName)]
    if runtime and runtime.reason then return "Active — "..runtime.reason,runtime.reason end
    if schedule.delivery=="ZONE" then return "Active — Waiting for zone arrival","On zone arrival" end
    return "Active — Waiting","Ready for next message"
end


function SmartChatMsg:GetStatusPanelRepeatCardGap()
    return 8
end


function SmartChatMsg:FormatStatusTimeOfDay(timestamp)
    local when = tonumber(timestamp)
    if not when or when <= 0 then
        return "Never"
    end

    local formatted = os.date("%I:%M:%S %p", when) or "Unknown time"
    formatted = formatted:gsub("^0", "")
    return formatted
end


function SmartChatMsg:GetRepeatStatusPanelRows()
    local rows = {}
    local now = GetTimeStamp()

    for _, command in ipairs(self:GetCommands() or {}) do
        if type(command) == "table" and type(command.id) == "string" and command.id ~= "" then
            local byGuild = self.savedVars and self.savedVars.commandGuildSettings and self.savedVars.commandGuildSettings[command.id] or nil
            if type(byGuild) == "table" then
                for guildKey, _ in pairs(byGuild) do
                    local guildName = nil
                    for guildIndex = 1, 5 do
                        local candidateName = self:GetGuildNameByIndex(guildIndex)
                        if candidateName and self:NormalizeKey(candidateName) == guildKey then
                            guildName = candidateName
                            break
                        end
                    end

                    guildName = guildName or tostring(guildKey)
                    local reminderMinutes = self:GetGuildReminderMinutes(command.id, guildName)
                    local scheduled=self:GetGuildRunAt(command.id,guildName)=="SCHEDULED"
                    local controlState,nextState=self:GetReminderPanelControlState(command.id,guildName)
                    if (scheduled and self:IsScheduledOccurrenceCurrent(command.id,guildName))
                        or (not scheduled and reminderMinutes and reminderMinutes>0 and controlState~="OFF") then
                        local isActive = self:IsReminderAutomationActive(command.id, guildName)
                        local nextTriggerAt = self:GetReminderNextTriggerAt(command.id, guildName)
                        local lastUsedAt = self:GetGuildLastUsedAt(command.id, guildName)
                        local nextSendText = "—"
                        local nextSendSeconds = nil

                        if isActive then
                            if type(nextTriggerAt) == "number" and nextTriggerAt > 0 then
                                nextSendSeconds = math.max(0, nextTriggerAt - now)
                                nextSendText = self:FormatStatusDuration(nextSendSeconds)
                            else
                                nextSendText = "Ready for next message"
                            end
                        end

                        local statusText=controlState=="PAUSED" and "Paused" or controlState=="ON" and "Active" or "Inactive"
                        if scheduled then statusText,nextSendText=self:GetScheduledCardDetails(command.id,guildName,controlState)
                        elseif controlState=="PAUSED" then nextSendText="Paused" end
                        isActive=controlState=="ON"
                        local schedule=scheduled and self:GetGuildSchedule(command.id,guildName)
                        local occurrence=schedule and self:GetScheduleOccurrence(schedule,now)
                        if schedule then
                            local description=self:GetSchedulePhaseDescription(command.id,guildName)
                            statusText=statusText.." — "..description
                        elseif reminderMinutes then statusText=statusText.." — every "..tostring(reminderMinutes).." minutes" end
                        local displayName=scheduled and (command.name or "Scheduled message") or (self:BuildSlashCommandName(command.name or "command") or "/command")
                        local runAt=self:GetGuildRunAt(command.id,guildName)
                        displayName=displayName..(scheduled and " (Scheduled)" or runAt=="STARTUP" and " (Startup)" or " (On Demand)")
                        if occurrence and type(occurrence.eventAtUtc)=="number" then
                            displayName=displayName.." "..(occurrence.eventAtUtc>now and ("Starts in "..self:FormatStatusDuration(occurrence.eventAtUtc-now)) or "Started")
                        end

                        table.insert(rows, {
                            commandId = command.id,
                            commandName = command.name or "command",
                            slashCommand = self:BuildSlashCommandName(command.name or "command") or "/command",
                            displayName = displayName,
                            promotionText = occurrence and (self:FormatScheduleDateTime(occurrence.startsAtUtc,occurrence).." → "..self:FormatScheduleDateTime(occurrence.endsAtUtc,occurrence)) or nil,
                            guildName = guildName,
                            channelText = self:GetAutoPopulateChannelStatusText(command.id, guildName),
                            reminderMinutes = reminderMinutes,
                            isActive = isActive,
                            statusText = statusText,
                            controlState = controlState,
                            lastUsedAt = lastUsedAt,
                            lastSentText = self:FormatStatusTimeOfDay(lastUsedAt),
                            nextSendText = nextSendText,
                            nextSendSeconds = nextSendSeconds,
                            toggleText = nextState=="PAUSED" and "Pause" or nextState=="ON" and "Enable" or "Disable",
                        })
                    end
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.isActive ~= b.isActive then
            return a.isActive == true
        end

        local aName = zo_strlower(tostring(a.commandName or ""))
        local bName = zo_strlower(tostring(b.commandName or ""))
        if aName ~= bName then
            return aName < bName
        end

        return zo_strlower(tostring(a.guildName or "")) < zo_strlower(tostring(b.guildName or ""))
    end)

    return rows
end


function SmartChatMsg:ToggleReminderAutomationFromStatusPanel(commandId, guildName)
    local slashCommandName = self:BuildSlashCommandName(self:GetCommandNameById(commandId) or "command") or "/command"
    local guildSlot = self:GetGuildSlotByName(guildName)

    if not guildSlot then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, string.format("Could not resolve guild slot for %s.", tostring(guildName)))
        return
    end

    if self:GetGuildRunAt(commandId,guildName)=="SCHEDULED" then
        if not self:IsScheduledOccurrenceCurrent(commandId,guildName) then return end
        local schedule=self:GetGuildSchedule(commandId,guildName)
        local _,nextState=self:GetReminderPanelControlState(commandId,guildName)
        if nextState=="ON" then
            if schedule.delivery=="ZONE" and not schedule.enabled then
                local key=self:GetReminderStateKey(commandId,guildName)
                for id,byGuild in pairs(self.savedVars.commandGuildSettings or {}) do
                    for otherGuild,settings in pairs(byGuild) do
                        local other=settings.schedule
                        if self:GetReminderStateKey(id,otherGuild)~=key and settings.runAt=="SCHEDULED"
                            and other and other.enabled and other.delivery=="ZONE" then
                            self:ShowStatusMessage("Only one enabled scheduled Zone combination is supported. Turn off the other Zone schedule first.")
                            return
                        end
                    end
                end
            end
            schedule.enabled=true;schedule.paused=false
        elseif nextState=="OFF" then
            schedule.enabled=false;schedule.paused=false;self:StopScheduledDelivery(commandId,guildName)
        else
            schedule.paused=true;self:StopScheduledDelivery(commandId,guildName)
        end
        self:ShowStatusMessage(slashCommandName.." / "..guildName..": "..(nextState=="ON" and "Enabled" or nextState=="OFF" and "Disabled" or "Paused")..".")
        self:TickSchedules()
        if self.statusPanelVisible then self:RefreshStatusPanel() end
        return
    end
    local reminderMinutes = self:GetGuildReminderMinutes(commandId, guildName)
    if not reminderMinutes or reminderMinutes <= 0 then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, string.format("%s does not have Repeat Every configured for %s.", slashCommandName, tostring(guildName)))
        return
    end

    local _,nextState=self:GetReminderPanelControlState(commandId,guildName)
    local key=self:GetReminderStateKey(commandId,guildName)
    self.repeatPanelPaused=self.repeatPanelPaused or {}
    if nextState=="PAUSED" or nextState=="OFF" then
        self:DeactivateReminderAutomation(commandId,guildName,"status panel "..nextState)
        self:CancelQueuedChatPopulation(commandId,guildName)
        self:WithdrawObservedChatDuplicate(commandId,guildName)
        self:ToggleOffActiveAutoPopulateIfMatching(commandId,guildName)
        self.repeatPanelPaused[key]=nextState=="PAUSED" and {} or nil
        self:ShowStatusMessage(slashCommandName.." / "..guildName..": "..(nextState=="PAUSED" and "Paused" or "Disabled")..".")
        if self.statusPanelVisible then self:RefreshStatusPanel() end
        return
    end
    self.repeatPanelPaused[key]=nil
    self:SetReminderAutomationActive(commandId,guildName,true)
    local paramText=tostring(guildSlot)

    self:DebugLog(string.format(
        "Status panel repeat toggle: invoking slash command handler commandId=%s slashCommand=%s guildName=%s guildSlot=%s paramText=%s",
        tostring(commandId),
        tostring(slashCommandName),
        tostring(guildName),
        tostring(guildSlot),
        tostring(paramText)
    ))

    self:HandleDynamicSlashCommand(commandId, slashCommandName, paramText)

    if self.statusPanelVisible then
        zo_callLater(function()
            if SmartChatMsg.statusPanelVisible then
                SmartChatMsg:RefreshStatusPanel()
            end
        end, 50)
    end
end


function SmartChatMsg:GetStatusPanelScrollOffset()
    local panel = self.statusPanel
    if not panel then
        return 0
    end
    local value = tonumber(panel.cooldownScrollOffset) or 0
    return math.max(0, math.floor(value))
end


function SmartChatMsg:SetStatusPanelScrollOffset(offset, totalRows)
    local panel = self.statusPanel
    if not panel then
        return
    end
    local maxVisible = self:GetStatusPanelMaxVisibleCooldownRows()
    local maxOffset = math.max(0, (tonumber(totalRows) or 0) - maxVisible)
    local clamped = math.max(0, math.min(maxOffset, math.floor(tonumber(offset) or 0)))
    panel.cooldownScrollOffset = clamped
end


function SmartChatMsg:AdjustStatusPanelScrollOffset(delta, totalRows)
    local current = self:GetStatusPanelScrollOffset()
    self:SetStatusPanelScrollOffset(current + (delta or 0), totalRows)
end


function SmartChatMsg:GetAutoPopulateStatusRows(commandId, guildName)
    local rows = {}
    local seenZoneKeys = {}
    local currentZoneId = GetZoneId(GetUnitZoneIndex("player"))
    local currentTrackedZoneId = self:GetEffectiveAutoPopulateZoneId(currentZoneId)
    local otherRows = {}

    local function buildRow(zoneId, isCurrent)
        if type(zoneId) ~= "number" or zoneId == 0 then
            return nil
        end

        local zoneKey = tostring(zoneId)
        if seenZoneKeys[zoneKey] then
            return nil
        end
        seenZoneKeys[zoneKey] = true

        local zoneName = self:GetAutoPopulateZoneDisplayName(zoneId)
        local cooldownEndsAt = self:GetAutoPopulateCooldownEndsAt(commandId, guildName, zoneId)
        local secondsRemaining = nil
        if type(cooldownEndsAt) == "number" and cooldownEndsAt > 0 then
            secondsRemaining = cooldownEndsAt - GetTimeStamp()
        end

        local statusText, isApplicable = self:GetStatusPanelZoneTimerText(zoneId, secondsRemaining, isCurrent)

        return {
            zoneId = zoneId,
            zoneName = zoneName,
            isCurrent = isCurrent == true,
            secondsRemaining = secondsRemaining,
            statusText = statusText,
            isApplicable = isApplicable,
            isReady = isApplicable and (type(secondsRemaining) ~= "number" or secondsRemaining <= 0) or false,
        }
    end

    local currentRow = buildRow(currentTrackedZoneId or currentZoneId, true)
    if currentRow then
        table.insert(rows, currentRow)
    end

    local settings = self:GetCommandGuildSettings(commandId, guildName, false)
    local byZone = settings and settings.lastAutoPopulateSentAtByZone or nil
    if type(byZone) == "table" then
        for zoneKey, timestamp in pairs(byZone) do
            if type(timestamp) == "number" and timestamp > 0 then
                local zoneId = tonumber(zoneKey)
                local row = buildRow(zoneId, false)
                if row then
                    table.insert(otherRows, row)
                end
            end
        end
    end

    table.sort(otherRows, function(a, b)
        if a.isApplicable ~= b.isApplicable then
            return a.isApplicable == true
        end

        if a.isReady ~= b.isReady then
            return a.isReady == true
        end

        if a.isReady and b.isReady then
            local aName = zo_strlower(a.zoneName or "")
            local bName = zo_strlower(b.zoneName or "")
            if aName == bName then
                return (a.zoneId or 0) < (b.zoneId or 0)
            end
            return aName < bName
        end

        local aSeconds = math.max(0, math.floor(tonumber(a.secondsRemaining) or 0))
        local bSeconds = math.max(0, math.floor(tonumber(b.secondsRemaining) or 0))
        if aSeconds == bSeconds then
            local aName = zo_strlower(a.zoneName or "")
            local bName = zo_strlower(b.zoneName or "")
            if aName == bName then
                return (a.zoneId or 0) < (b.zoneId or 0)
            end
            return aName < bName
        end
        return aSeconds < bSeconds
    end)

    for _, row in ipairs(otherRows) do
        table.insert(rows, row)
    end

    return rows
end


function SmartChatMsg:GetStatusPanelTimerColor(secondsRemaining, isApplicable)
    if isApplicable == false then
        return 0.70, 0.70, 0.70, 1
    end

    if type(secondsRemaining) ~= "number" or secondsRemaining <= 0 then
        return 0.32, 0.86, 0.45, 1
    end

    if secondsRemaining <= 60 then
        return 0.92, 0.28, 0.22, 1
    end

    return 0.95, 0.62, 0.24, 1
end


function SmartChatMsg:EstimateStatusPanelTextWidth(text)
    local value = tostring(text or "")
    local length = zo_strlen(value)
    local bonus = 0
    if value:find("%u%u") then
        bonus = bonus + 8
    end
    if value:find("[/():]", 1) then
        bonus = bonus + 10
    end
    return math.floor((length * 7.4) + bonus)
end


function SmartChatMsg:GetStatusPanelMeasuredTextWidth(control, fallbackText)
    if control and control.GetTextDimensions then
        local measuredWidth = select(1, control:GetTextDimensions())
        if type(measuredWidth) == "number" and measuredWidth > 0 then
            return math.floor(measuredWidth + 0.5)
        end
    end

    if control and control.GetTextWidth then
        local measuredWidth = control:GetTextWidth()
        if type(measuredWidth) == "number" and measuredWidth > 0 then
            return math.floor(measuredWidth + 0.5)
        end
    end

    return self:EstimateStatusPanelTextWidth(fallbackText)
end


function SmartChatMsg:GetStatusPanelMeasuredTextHeight(control, fallbackHeight)
    if control and control.GetTextDimensions then
        local _, measuredHeight = control:GetTextDimensions()
        if type(measuredHeight) == "number" and measuredHeight > 0 then
            return math.floor(measuredHeight + 0.5)
        end
    end

    return fallbackHeight or 24
end


function SmartChatMsg:GetStatusPanelTargetSize(active, rows)
    local panel = self.statusPanel
    local repeatRows = (panel and panel.repeatDataRows) or self:GetRepeatStatusPanelRows() or {}
    local hasRepeatRows = #repeatRows > 0
    local minWidth = hasRepeatRows and 640 or 460
    local maxWidth = 980
    local contentWidth = 0

    local function measured(control, fallback)
        return self:GetStatusPanelMeasuredTextWidth(control, fallback)
    end

    if active and panel then
        local firstLineWidth = 0
        local firstLineControls = {
            panel.statusLabel,
            panel.commandLabel,
            panel.guildLabel,
            panel.channelLabel,
        }

        for _, control in ipairs(firstLineControls) do
            if control and not control:IsHidden() then
                firstLineWidth = firstLineWidth + measured(control, control.GetText and control:GetText() or "")
            end
        end
        if firstLineWidth > 0 then
            firstLineWidth = firstLineWidth + 54
            contentWidth = math.max(contentWidth, firstLineWidth)
        end

        local stackedControls = {
            panel.titleLabel,
            panel.listHeader,
            panel.currentLabel,
            panel.footerLabel,
            panel.repeatHeader,
            panel.repeatEmptyLabel,
        }

        for _, control in ipairs(stackedControls) do
            if control and not control:IsHidden() then
                contentWidth = math.max(contentWidth, measured(control, control.GetText and control:GetText() or ""))
            end
        end

        for _, row in ipairs(panel.rows or {}) do
            if row and not row:IsHidden() then
                local rowWidth = 0
                if row.zone1 and not row.zone1:IsHidden() then
                    rowWidth = rowWidth + measured(row.zone1, row.zone1:GetText())
                end
                if row.timer1 and not row.timer1:IsHidden() then
                    rowWidth = rowWidth + 14 + measured(row.timer1, row.timer1:GetText())
                end
                if row.zone2 and not row.zone2:IsHidden() then
                    rowWidth = rowWidth + 30 + measured(row.zone2, row.zone2:GetText())
                end
                if row.timer2 and not row.timer2:IsHidden() then
                    rowWidth = rowWidth + 14 + measured(row.timer2, row.timer2:GetText())
                end
                contentWidth = math.max(contentWidth, rowWidth)
            end
        end

        for _, row in ipairs(panel.repeatRows or {}) do
            if row and not row:IsHidden() then
                local rowWidth = 0
                rowWidth = math.max(rowWidth, measured(row.commandLabel, row.commandLabel:GetText()) + 120)
                rowWidth = math.max(rowWidth, measured(row.detailsLabel, row.detailsLabel:GetText()) + 140)
                rowWidth = math.max(rowWidth, measured(row.timingLabel, row.timingLabel:GetText()) + 140)
                contentWidth = math.max(contentWidth, rowWidth)
            end
        end
    elseif active then
        local commandName = self:BuildSlashCommandName(self:GetCommandNameById(active.commandId) or "") or "/command"
        contentWidth = math.max(contentWidth, self:EstimateStatusPanelTextWidth("SmartChatMsg Status"))
        contentWidth = math.max(contentWidth, self:EstimateStatusPanelTextWidth("Zone Cooldowns"))
        contentWidth = math.max(contentWidth, self:EstimateStatusPanelTextWidth("Tracked Zones: 0 | Showing 0-0"))
        contentWidth = math.max(contentWidth,
            self:EstimateStatusPanelTextWidth("Auto: Active") +
            self:EstimateStatusPanelTextWidth(tostring(commandName)) +
            self:EstimateStatusPanelTextWidth(tostring(active.guildName)) +
            self:EstimateStatusPanelTextWidth(tostring(self:GetAutoPopulateChannelStatusText(active.commandId, active.guildName))) +
            54
        )
    else
        contentWidth = math.max(
            self:EstimateStatusPanelTextWidth("Auto: Inactive"),
            self:EstimateStatusPanelTextWidth("Tracked Zones: 0 | Showing 0-0")
        )
    end

    if hasRepeatRows then
        for _, rowData in ipairs(repeatRows) do
            local detailText = string.format("%s | %s", tostring(rowData.guildName), tostring(rowData.channelText))
            local timingText = self:GetRepeatCardTimingText(rowData)
            contentWidth = math.max(contentWidth, self:EstimateStatusPanelTextWidth(tostring(rowData.slashCommand or rowData.commandName or "/command")) + 180)
            contentWidth = math.max(contentWidth, self:EstimateStatusPanelTextWidth(detailText) + 160)
            contentWidth = math.max(contentWidth, self:EstimateStatusPanelTextWidth(timingText) + 160)
        end
    else
        contentWidth = math.max(contentWidth, self:EstimateStatusPanelTextWidth("Repeat Commands"))
        contentWidth = math.max(contentWidth, self:EstimateStatusPanelTextWidth("No repeat commands configured."))
    end

    local width = math.max(minWidth, math.min(maxWidth, contentWidth + 72))

    local height = 58
    if panel then
        local visibleControls = {
            panel.titleLabel,
            panel.statusLabel,
            panel.commandLabel,
            panel.guildLabel,
            panel.channelLabel,
            panel.listHeader,
            panel.currentLabel,
            panel.footerLabel,
            panel.repeatHeader,
            panel.repeatEmptyLabel,
        }

        for _, control in ipairs(visibleControls) do
            if control and not control:IsHidden() then
                height = height + self:GetStatusPanelMeasuredTextHeight(control, 18) + 4
            end
        end

        if panel.divider and not panel.divider:IsHidden() then
            height = height + 6
        end
        if panel.repeatDivider and not panel.repeatDivider:IsHidden() then
            height = height + 8
        end

        local visibleRowCount = 0
        for _, row in ipairs(panel.rows or {}) do
            if row and not row:IsHidden() then
                visibleRowCount = visibleRowCount + 1
            end
        end

        if panel.currentRow and not panel.currentRow:IsHidden() then
            height = height + 14 + 6
        end

        height = height + (visibleRowCount * 14) + math.max(0, visibleRowCount - 1) * 2 + 4

        if panel.repeatScroll and not panel.repeatScroll:IsHidden() then
            height = height + (panel.repeatSectionHeight or self:GetStatusPanelRepeatSectionMaxHeight()) + 12
        end
    else
        local visibleRowCount = math.min(#(rows or {}), self:GetStatusPanelMaxVisibleCooldownRows())
        height = active and (150 + (visibleRowCount * 16)) or 120
        height = height + (hasRepeatRows and self:GetStatusPanelRepeatSectionMaxHeight() or 72)
    end

    -- Account for the final anchored viewport, including its bottom padding.
    if panel and panel.GetTop then
        local top=panel:GetTop()
        local bottom=top
        if type(top)=="number" then
            for _,control in ipairs({panel.statusLabel,panel.footerLabel,panel.repeatHeader,panel.repeatEmptyLabel,panel.repeatScroll}) do
                if control and not control:IsHidden() and control.GetBottom then
                    local edge=control:GetBottom()
                    if type(edge)=="number" then bottom=math.max(bottom,edge) end
                end
            end
            height=bottom-top+20
        end
    end
    height = math.max(110, math.min(760, height))
    return width, height
end


function SmartChatMsg:ApplyStatusPanelLayout(panel, width)
    if not panel then
        return
    end

    local contentWidth = math.max(372, width - 48)
    local timerWidth = 70
    local columnGap = 24
    local pairGap = 12
    local singleLineHeight = 14
    local halfWidth = math.floor((contentWidth - columnGap) / 2)
    local zoneWidth = math.max(90, halfWidth - timerWidth - pairGap)

    local closeButtonReserve = 30

    panel.dragBar:SetWidth(math.max(120, contentWidth - closeButtonReserve))
    panel.titleLabel:SetWidth(math.max(120, contentWidth - closeButtonReserve))
    panel.divider:SetWidth(contentWidth)
    panel.listHeader:SetWidth(contentWidth)
    panel.currentLabel:SetWidth(contentWidth)
    panel.footerLabel:SetWidth(contentWidth)
    panel.repeatDivider:SetWidth(contentWidth)
    panel.repeatHeader:SetWidth(contentWidth)
    panel.repeatScroll:SetDimensions(contentWidth, panel.repeatSectionHeight or self:GetStatusPanelRepeatSectionMaxHeight())
    panel.repeatEmptyLabel:SetWidth(contentWidth)

    local firstLineGap = 3
    local statusWidth = math.max(60, self:EstimateStatusPanelTextWidth(panel.statusLabel:GetText()))
    local commandWidth = math.max(110, self:EstimateStatusPanelTextWidth(panel.commandLabel:GetText()))
    local guildWidth = math.max(110, self:EstimateStatusPanelTextWidth(panel.guildLabel:GetText()))
    local remainingWidth = contentWidth - statusWidth - commandWidth - guildWidth - (firstLineGap * 3)
    local channelWidth = math.max(110, remainingWidth)

    panel.statusLabel:SetDimensions(statusWidth, singleLineHeight)
    panel.commandLabel:SetDimensions(commandWidth, singleLineHeight)
    panel.guildLabel:SetDimensions(guildWidth, singleLineHeight)
    panel.channelLabel:SetDimensions(channelWidth, singleLineHeight)

    panel.statusLabel:ClearAnchors()
    panel.commandLabel:ClearAnchors()
    panel.guildLabel:ClearAnchors()
    panel.channelLabel:ClearAnchors()
    panel.divider:ClearAnchors()
    panel.listHeader:ClearAnchors()
    panel.currentLabel:ClearAnchors()
    panel.footerLabel:ClearAnchors()
    panel.repeatDivider:ClearAnchors()
    panel.repeatHeader:ClearAnchors()
    panel.repeatScroll:ClearAnchors()
    panel.repeatEmptyLabel:ClearAnchors()

    panel.statusLabel:SetAnchor(TOPLEFT, panel.titleLabel, BOTTOMLEFT, 0, 8)
    panel.commandLabel:SetAnchor(TOPLEFT, panel.statusLabel, TOPRIGHT, firstLineGap, 0)
    panel.guildLabel:SetAnchor(TOPLEFT, panel.commandLabel, TOPRIGHT, firstLineGap, 0)
    panel.channelLabel:SetAnchor(TOPLEFT, panel.guildLabel, TOPRIGHT, firstLineGap, 0)

    panel.divider:SetAnchor(TOPLEFT, panel.statusLabel, BOTTOMLEFT, 0, 8)
    panel.listHeader:SetAnchor(TOPLEFT, panel.divider, BOTTOMLEFT, 0, 8)
    panel.currentLabel:SetAnchor(TOPLEFT, panel.listHeader, BOTTOMLEFT, 0, 6)

    if panel.currentRow then
        panel.currentRow:SetDimensions(contentWidth, singleLineHeight)
        panel.currentRow:ClearAnchors()
        panel.currentRow:SetAnchor(TOPLEFT, panel.currentLabel, BOTTOMLEFT, 0, 2)

        panel.currentRow.zone:ClearAnchors()
        panel.currentRow.timer:ClearAnchors()

        local currentZoneWidth = math.max(90, contentWidth - timerWidth - pairGap)
        panel.currentRow.zone:SetDimensions(currentZoneWidth, singleLineHeight)
        panel.currentRow.timer:SetDimensions(timerWidth, singleLineHeight)

        panel.currentRow.zone:SetAnchor(TOPLEFT, panel.currentRow, TOPLEFT, 0, 0)
        panel.currentRow.timer:SetAnchor(TOPLEFT, panel.currentRow.zone, TOPRIGHT, pairGap, 0)

        panel.currentRow.zone:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        panel.currentRow.timer:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        if panel.currentRow.zone.SetMaxLineCount then panel.currentRow.zone:SetMaxLineCount(1) end
        if panel.currentRow.timer.SetMaxLineCount then panel.currentRow.timer:SetMaxLineCount(1) end
        panel.currentRow.zone:SetHeight(singleLineHeight)
        panel.currentRow.timer:SetHeight(singleLineHeight)
    end

    for index, row in ipairs(panel.rows or {}) do
        row:SetDimensions(contentWidth, singleLineHeight)
        row:ClearAnchors()
        local previous = index == 1 and panel.currentRow or panel.rows[index - 1]
        row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, index == 1 and 6 or 2)

        row.zone1:ClearAnchors()
        row.timer1:ClearAnchors()
        row.zone2:ClearAnchors()
        row.timer2:ClearAnchors()

        if row.isSingleSpan then
            local spanZoneWidth = math.max(90, contentWidth - timerWidth - pairGap)
            row.zone1:SetDimensions(spanZoneWidth, singleLineHeight)
            row.timer1:SetDimensions(timerWidth, singleLineHeight)
            row.zone2:SetDimensions(0, singleLineHeight)
            row.timer2:SetDimensions(0, singleLineHeight)

            row.zone1:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
            row.timer1:SetAnchor(TOPLEFT, row.zone1, TOPRIGHT, pairGap, 0)
        else
            row.zone1:SetDimensions(zoneWidth, singleLineHeight)
            row.timer1:SetDimensions(timerWidth, singleLineHeight)
            row.zone2:SetDimensions(zoneWidth, singleLineHeight)
            row.timer2:SetDimensions(timerWidth, singleLineHeight)

            row.zone1:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
            row.timer1:SetAnchor(TOPLEFT, row.zone1, TOPRIGHT, pairGap, 0)
            row.zone2:SetAnchor(TOPLEFT, row.timer1, TOPRIGHT, columnGap, 0)
            row.timer2:SetAnchor(TOPLEFT, row.zone2, TOPRIGHT, pairGap, 0)
        end

        row.zone1:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.timer1:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.zone2:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.timer2:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

        if row.zone1.SetMaxLineCount then row.zone1:SetMaxLineCount(1) end
        if row.timer1.SetMaxLineCount then row.timer1:SetMaxLineCount(1) end
        if row.zone2.SetMaxLineCount then row.zone2:SetMaxLineCount(1) end
        if row.timer2.SetMaxLineCount then row.timer2:SetMaxLineCount(1) end

        row.zone1:SetHeight(singleLineHeight)
        row.timer1:SetHeight(singleLineHeight)
        row.zone2:SetHeight(singleLineHeight)
        row.timer2:SetHeight(singleLineHeight)
    end

    local lastControl = panel.statusLabel

    if panel.channelLabel and not panel.channelLabel:IsHidden() then
        lastControl = panel.channelLabel
    elseif panel.guildLabel and not panel.guildLabel:IsHidden() then
        lastControl = panel.guildLabel
    elseif panel.commandLabel and not panel.commandLabel:IsHidden() then
        lastControl = panel.commandLabel
    end

    if panel.currentRow and not panel.currentRow:IsHidden() then
        lastControl = panel.currentRow
    elseif panel.currentLabel and not panel.currentLabel:IsHidden() then
        lastControl = panel.currentLabel
    elseif panel.listHeader and not panel.listHeader:IsHidden() then
        lastControl = panel.listHeader
    elseif panel.divider and not panel.divider:IsHidden() then
        lastControl = panel.divider
    end

    for _, row in ipairs(panel.rows or {}) do
        if row and not row:IsHidden() then
            lastControl = row
        end
    end

    panel.footerLabel:SetAnchor(TOPLEFT, lastControl, BOTTOMLEFT, 0, 8)
    local autoExpanded=self:GetStatusSectionExpanded("auto",self:GetActiveAutoPopulate()~=nil)
    panel.repeatDivider:SetAnchor(TOPLEFT, autoExpanded and panel.footerLabel or panel.statusLabel, BOTTOMLEFT, 0, 10)
    panel.repeatHeader:SetAnchor(TOPLEFT, panel.repeatDivider, BOTTOMLEFT, 0, 8)

    if panel.repeatEmptyLabel and not panel.repeatEmptyLabel:IsHidden() then
        panel.repeatEmptyLabel:SetAnchor(TOPLEFT, panel.repeatHeader, BOTTOMLEFT, 0, 6)
    end

    panel.repeatScroll:SetAnchor(TOPLEFT, panel.repeatHeader, BOTTOMLEFT, 0, 6)

    local childWidth = math.max(300, contentWidth - 32)
    if panel.repeatScrollChild then
        panel.repeatScrollChild:SetWidth(childWidth)
    end

    local cardHeight = self:GetStatusPanelRepeatCardHeight()
    local cardGap = self:GetStatusPanelRepeatCardGap()
    local buttonWidth = 88
    local textWidth = math.max(160, childWidth - buttonWidth - 18)

    for index, row in ipairs(panel.repeatRows or {}) do
        row:SetDimensions(childWidth, cardHeight)
        row:ClearAnchors()
        if index == 1 then
            row:SetAnchor(TOPLEFT, panel.repeatScrollChild, TOPLEFT, 0, 0)
        else
            row:SetAnchor(TOPLEFT, panel.repeatRows[index - 1], BOTTOMLEFT, 0, cardGap)
        end

        row.backdrop:SetAnchorFill(row)
        row.toggleButton:SetDimensions(buttonWidth, 28)
        row.toggleButton:ClearAnchors()
        row.toggleButton:SetAnchor(TOPRIGHT, row, TOPRIGHT, -8, 8)

        row.commandLabel:SetDimensions(textWidth, 40)
        row.commandLabel:ClearAnchors()
        row.commandLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 8, 8)

        row.statusLabel:SetDimensions(childWidth-16, 60)
        row.statusLabel:ClearAnchors()
        row.statusLabel:SetAnchor(TOPLEFT, row.commandLabel, BOTTOMLEFT, 0, 2)

        row.detailsLabel:SetDimensions(childWidth-16, 20)
        row.detailsLabel:ClearAnchors()
        row.detailsLabel:SetAnchor(TOPLEFT, row.statusLabel, BOTTOMLEFT, 0, 2)

        row.timingLabel:SetDimensions(childWidth-16, 20)
        row.timingLabel:ClearAnchors()
        row.timingLabel:SetAnchor(TOPLEFT, row.detailsLabel, BOTTOMLEFT, 0, 2)

        row.commandLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.statusLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.detailsLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.timingLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

        if row.commandLabel.SetMaxLineCount then row.commandLabel:SetMaxLineCount(2) end
        if row.statusLabel.SetMaxLineCount then row.statusLabel:SetMaxLineCount(2) end
        if row.detailsLabel.SetMaxLineCount then row.detailsLabel:SetMaxLineCount(1) end
        if row.timingLabel.SetMaxLineCount then row.timingLabel:SetMaxLineCount(1) end
    end
end


function SmartChatMsg:StartStatusPanelSizeAnimation(targetWidth, targetHeight)
    local panel = self.statusPanel
    if not panel then
        return
    end

    panel.targetWidth = math.floor(targetWidth or panel:GetWidth())
    panel.targetHeight = math.floor(targetHeight or panel:GetHeight())

    if panel.isAnimatingSize then
        return
    end

    panel.isAnimatingSize = true
    EVENT_MANAGER:RegisterForUpdate(self.name .. "_StatusPanelResize", 16, function()
        local activePanel = SmartChatMsg.statusPanel
        if not activePanel then
            EVENT_MANAGER:UnregisterForUpdate(SmartChatMsg.name .. "_StatusPanelResize")
            return
        end

        local currentWidth = activePanel:GetWidth()
        local currentHeight = activePanel:GetHeight()
        local targetW = activePanel.targetWidth or currentWidth
        local targetH = activePanel.targetHeight or currentHeight

        local nextWidth = currentWidth + ((targetW - currentWidth) * 0.30)
        local nextHeight = currentHeight + ((targetH - currentHeight) * 0.30)

        if math.abs(targetW - nextWidth) < 2 then
            nextWidth = targetW
        end
        if math.abs(targetH - nextHeight) < 2 then
            nextHeight = targetH
        end

        nextWidth = math.floor(nextWidth + 0.5)
        nextHeight = math.floor(nextHeight + 0.5)

        activePanel:SetDimensions(nextWidth, nextHeight)
        SmartChatMsg:ApplyStatusPanelLayout(activePanel, nextWidth)

        if nextWidth == targetW and nextHeight == targetH then
            activePanel.isAnimatingSize = false
            EVENT_MANAGER:UnregisterForUpdate(SmartChatMsg.name .. "_StatusPanelResize")
        end
    end)
end


function SmartChatMsg:SaveStatusPanelPosition(panel)
    if not panel or not panel.GetLeft or not panel.GetTop then
        return
    end

    local left = panel:GetLeft()
    local top = panel:GetTop()
    if type(left) ~= "number" or type(top) ~= "number" then
        return
    end

    self:SetStatusPanelAnchorOffsets(math.floor(left + 0.5), math.floor(top + 0.5))
end


function SmartChatMsg:CreateStatusPanelRepeatCard(panel, index)
    if not panel or not panel.repeatScrollChild then
        return nil
    end

    panel.repeatRows = panel.repeatRows or {}
    if panel.repeatRows[index] then
        return panel.repeatRows[index]
    end

    local row = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRepeatRow" .. tostring(index), panel.repeatScrollChild, CT_CONTROL)
    row:SetMouseEnabled(true)

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("SCM_StatusPanelRepeatRowBackdrop" .. tostring(index), row, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(row)
    backdrop:SetCenterColor(0.11, 0.11, 0.11, 0.88)
    backdrop:SetEdgeColor(0.38, 0.38, 0.38, 0.95)

    local commandLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRepeatRowCommand" .. tostring(index), row, CT_LABEL)
    commandLabel:SetFont("ZoFontGameBold")
    commandLabel:SetColor(0.95, 0.83, 0.46, 1)

    local statusLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRepeatRowStatus" .. tostring(index), row, CT_LABEL)
    statusLabel:SetFont("ZoFontGameSmall")

    local detailsLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRepeatRowDetails" .. tostring(index), row, CT_LABEL)
    detailsLabel:SetFont("ZoFontGameSmall")
    detailsLabel:SetColor(0.88, 0.88, 0.88, 1)

    local timingLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRepeatRowTiming" .. tostring(index), row, CT_LABEL)
    timingLabel:SetFont("ZoFontGameSmall")
    timingLabel:SetColor(0.82, 0.82, 0.82, 1)

    local toggleButton = WINDOW_MANAGER:CreateControlFromVirtual("SCM_StatusPanelRepeatRowButton" .. tostring(index), row, "ZO_DefaultButton")
    toggleButton:SetFont("ZoFontGameSmall")
    toggleButton:SetNormalFontColor(0.92, 0.92, 0.92, 1)
    toggleButton:SetMouseOverFontColor(0.95, 0.83, 0.46, 1)
    toggleButton:SetPressedFontColor(0.70, 0.70, 0.70, 1)
    toggleButton:SetHandler("OnClicked", function(control)
        local data = control.data
        if type(data) == "table" then
            SmartChatMsg:ToggleReminderAutomationFromStatusPanel(data.commandId, data.guildName)
        end
    end)

    row.backdrop = backdrop
    row.commandLabel = commandLabel
    row.statusLabel = statusLabel
    row.detailsLabel = detailsLabel
    row.timingLabel = timingLabel
    row.toggleButton = toggleButton

    panel.repeatRows[index] = row
    return row
end


function SmartChatMsg:CreateStatusPanel()
    if self.statusPanel then
        return self.statusPanel
    end

    local offsetX, offsetY = self:GetStatusPanelAnchorOffsets()

    local panel = WINDOW_MANAGER:CreateTopLevelWindow("SCM_StatusPanel")
    panel:SetDimensions(640, 220)
    panel:SetHidden(true)
    panel:SetMovable(true)
    panel:SetMouseEnabled(true)
    panel:SetClampedToScreen(true)
    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, offsetX, offsetY)
    panel.cooldownScrollOffset = 0
    panel.currentCooldownRows = {}
    panel.repeatRows = {}
    panel.repeatDataRows = {}
    panel.repeatSectionHeight = self:GetStatusPanelRepeatSectionMaxHeight()

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("SCM_StatusPanelBackdrop", panel, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(panel)
    backdrop:SetCenterColor(0.05, 0.05, 0.05, 0.90)
    backdrop:SetEdgeColor(0.75, 0.62, 0.28, 0.95)
    backdrop:SetMouseEnabled(true)

    local dragBar = WINDOW_MANAGER:CreateControl("SCM_StatusPanelDragBar", panel, CT_CONTROL)
    dragBar:SetDimensions(412, 22)
    dragBar:SetAnchor(TOPLEFT, panel, TOPLEFT, 16, 10)
    dragBar:SetMouseEnabled(true)

    local title = WINDOW_MANAGER:CreateControl("SCM_StatusPanelTitle", panel, CT_LABEL)
    title:SetFont("ZoFontWinH4")
    title:SetColor(0.95, 0.83, 0.46, 1)
    title:SetText("SmartChatMsg Status")
    title:SetAnchor(TOPLEFT, dragBar, TOPLEFT, 0, 0)

    local closeButton = WINDOW_MANAGER:CreateControl("SCM_StatusPanelCloseButton", panel, CT_BUTTON)
    closeButton:SetDimensions(24, 24)
    closeButton:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -10, 8)
    closeButton:SetFont("ZoFontWinH3")
    closeButton:SetText("X")
    closeButton:SetNormalFontColor(0.92, 0.92, 0.92, 1)
    closeButton:SetMouseOverFontColor(1, 0.35, 0.35, 1)
    closeButton:SetPressedFontColor(0.75, 0.75, 0.75, 1)
    closeButton:SetHandler("OnClicked", function()
        SmartChatMsg:SetStatusPanelVisible(false)
    end)
    closeButton:SetHandler("OnMouseEnter", function(control)
        InitializeTooltip(InformationTooltip, control, TOP, 0, 8)
        SetTooltipText(InformationTooltip, "Close Status Panel")
    end)
    closeButton:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    local statusLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelState", panel, CT_LABEL)
    statusLabel:SetFont("ZoFontGameSmall")
    statusLabel:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 8)
    statusLabel:SetMouseEnabled(true)
    statusLabel:SetHandler("OnMouseUp",function(_,button,upInside)
        if button==MOUSE_BUTTON_INDEX_LEFT and upInside then SmartChatMsg:ToggleStatusSection("auto") end
    end)

    local commandLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelCommand", panel, CT_LABEL)
    commandLabel:SetFont("ZoFontGameSmall")
    commandLabel:SetAnchor(TOPLEFT, statusLabel, TOPRIGHT, 18, 0)

    local guildLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelGuild", panel, CT_LABEL)
    guildLabel:SetFont("ZoFontGameSmall")
    guildLabel:SetAnchor(TOPLEFT, commandLabel, TOPRIGHT, 18, 0)

    local channelLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelChannel", panel, CT_LABEL)
    channelLabel:SetFont("ZoFontGameSmall")
    channelLabel:SetAnchor(TOPLEFT, guildLabel, TOPRIGHT, 18, 0)

    local divider = WINDOW_MANAGER:CreateControl("SCM_StatusPanelDivider", panel, CT_BACKDROP)
    divider:SetDimensions(412, 2)
    divider:SetAnchor(TOPLEFT, statusLabel, BOTTOMLEFT, 0, 8)
    divider:SetCenterColor(0.35, 0.35, 0.35, 0.9)
    divider:SetEdgeColor(0, 0, 0, 0)

    local listHeader = WINDOW_MANAGER:CreateControl("SCM_StatusPanelListHeader", panel, CT_LABEL)
    listHeader:SetFont("ZoFontGameSmall")
    listHeader:SetColor(0.95, 0.83, 0.46, 1)
    listHeader:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 0, 8)

    local currentLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelCurrentLabel", panel, CT_LABEL)
    currentLabel:SetFont("ZoFontGameSmall")
    currentLabel:SetColor(0.95, 0.83, 0.46, 1)
    currentLabel:SetText("Current Zone")
    currentLabel:SetAnchor(TOPLEFT, listHeader, BOTTOMLEFT, 0, 6)

    local currentRow = WINDOW_MANAGER:CreateControl("SCM_StatusPanelCurrentRow", panel, CT_CONTROL)
    currentRow:SetDimensions(412, 16)
    currentRow:SetAnchor(TOPLEFT, currentLabel, BOTTOMLEFT, 0, 2)

    local currentZone = WINDOW_MANAGER:CreateControl("SCM_StatusPanelCurrentZone", currentRow, CT_LABEL)
    currentZone:SetFont("ZoFontGameSmall")
    currentZone:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    local currentTimer = WINDOW_MANAGER:CreateControl("SCM_StatusPanelCurrentTimer", currentRow, CT_LABEL)
    currentTimer:SetFont("ZoFontGameSmall")
    currentTimer:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    currentRow.zone = currentZone
    currentRow.timer = currentTimer

    local rows = {}
    local previous = currentRow
    for index = 1, 10 do
        local row = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRow" .. tostring(index), panel, CT_CONTROL)
        row:SetDimensions(412, 16)
        row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, index == 1 and 6 or 2)

        local zone1 = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRowZone1" .. tostring(index), row, CT_LABEL)
        zone1:SetFont("ZoFontGameSmall")
        zone1:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

        local timer1 = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRowTimer1" .. tostring(index), row, CT_LABEL)
        timer1:SetFont("ZoFontGameSmall")
        timer1:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        local zone2 = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRowZone2" .. tostring(index), row, CT_LABEL)
        zone2:SetFont("ZoFontGameSmall")
        zone2:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

        local timer2 = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRowTimer2" .. tostring(index), row, CT_LABEL)
        timer2:SetFont("ZoFontGameSmall")
        timer2:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        row.zone1 = zone1
        row.timer1 = timer1
        row.zone2 = zone2
        row.timer2 = timer2
        rows[index] = row
        previous = row
    end

    local footerLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelFooter", panel, CT_LABEL)
    footerLabel:SetFont("ZoFontGameSmall")
    footerLabel:SetColor(0.80, 0.80, 0.80, 1)
    footerLabel:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 8)

    local repeatDivider = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRepeatDivider", panel, CT_BACKDROP)
    repeatDivider:SetDimensions(412, 2)
    repeatDivider:SetCenterColor(0.35, 0.35, 0.35, 0.9)
    repeatDivider:SetEdgeColor(0, 0, 0, 0)

    local repeatHeader = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRepeatHeader", panel, CT_LABEL)
    repeatHeader:SetFont("ZoFontGameSmall")
    repeatHeader:SetColor(0.95, 0.83, 0.46, 1)
    repeatHeader:SetText("Repeat Commands")
    repeatHeader:SetMouseEnabled(true)
    repeatHeader:SetHandler("OnMouseUp",function(_,button,upInside)
        if button==MOUSE_BUTTON_INDEX_LEFT and upInside then SmartChatMsg:ToggleStatusSection("repeat") end
    end)

    local repeatScroll = WINDOW_MANAGER:CreateControlFromVirtual("SCM_StatusPanelRepeatScroll", panel, "ZO_ScrollContainer")
    repeatScroll:SetMouseEnabled(true)
    local repeatScrollChild = repeatScroll:GetNamedChild("ScrollChild")

    local repeatEmptyLabel = WINDOW_MANAGER:CreateControl("SCM_StatusPanelRepeatEmpty", panel, CT_LABEL)
    repeatEmptyLabel:SetFont("ZoFontGameSmall")
    repeatEmptyLabel:SetColor(0.82, 0.82, 0.82, 1)
    repeatEmptyLabel:SetText("No current schedules or running repeats.")

    local function beginMove(control)
        if not panel.isMoving and control == panel.dragBar then
            panel.isMoving = true
            panel:StartMoving()
        end
    end

    local function endMove(control)
        if panel.isMoving then
            panel.isMoving = false
            panel:StopMovingOrResizing()
            SmartChatMsg:SaveStatusPanelPosition(panel)
        end
    end

    dragBar:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            beginMove(control)
        end
    end)
    dragBar:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            endMove(control)
        end
    end)
    panel:SetHandler("OnMoveStop", function()
        panel.isMoving = false
        SmartChatMsg:SaveStatusPanelPosition(panel)
    end)
    panel:SetHandler("OnMouseWheel", function(_, delta)
        local currentRows = panel.currentCooldownRows or {}
        if #currentRows <= SmartChatMsg:GetStatusPanelMaxVisibleCooldownRows() then
            return
        end
        SmartChatMsg:AdjustStatusPanelScrollOffset(delta > 0 and -1 or 1, #currentRows)
        SmartChatMsg:RefreshStatusPanel()
    end)

    panel.backdrop = backdrop
    panel.dragBar = dragBar
    panel.titleLabel = title
    panel.closeButton = closeButton
    panel.statusLabel = statusLabel
    panel.commandLabel = commandLabel
    panel.guildLabel = guildLabel
    panel.channelLabel = channelLabel
    panel.divider = divider
    panel.listHeader = listHeader
    panel.currentLabel = currentLabel
    panel.currentRow = currentRow
    panel.footerLabel = footerLabel
    panel.rows = rows
    panel.repeatDivider = repeatDivider
    panel.repeatHeader = repeatHeader
    panel.repeatScroll = repeatScroll
    panel.repeatScrollChild = repeatScrollChild
    panel.repeatEmptyLabel = repeatEmptyLabel

    self.statusPanel = panel
    self:ApplyStatusPanelLayout(panel, panel:GetWidth())
    return panel
end


function SmartChatMsg:RefreshStatusPanel()
    local panel = self:CreateStatusPanel()
    if not panel or panel:IsHidden() then
        return
    end

    local active = self:GetActiveAutoPopulate()
    local rows = {}

    if not active then
        panel.statusLabel:SetColor(0.82, 0.82, 0.82, 1)
        panel.statusLabel:SetText("Auto: Inactive")
        panel.commandLabel:SetHidden(true)
        panel.guildLabel:SetHidden(true)
        panel.channelLabel:SetHidden(true)
        panel.divider:SetHidden(true)
        panel.listHeader:SetHidden(true)
        panel.currentLabel:SetHidden(true)
        panel.currentRow:SetHidden(true)
        panel.footerLabel:SetHidden(false)
        panel.footerLabel:SetText("Tracked Zones: 0 | Showing 0-0")

        for _, row in ipairs(panel.rows) do
            row:SetHidden(true)
        end

        panel.currentCooldownRows = {}
        self:SetStatusPanelScrollOffset(0, 0)
    else
        local commandName = self:BuildSlashCommandName(self:GetCommandNameById(active.commandId) or "") or "/command"
        panel.statusLabel:SetColor(0.32, 0.86, 0.45, 1)
        panel.statusLabel:SetText("Auto: Active")

        panel.commandLabel:SetHidden(false)
        panel.guildLabel:SetHidden(false)
        panel.channelLabel:SetHidden(false)
        panel.divider:SetHidden(false)
        panel.listHeader:SetHidden(false)
        panel.currentLabel:SetHidden(false)
        panel.currentRow:SetHidden(false)
        panel.footerLabel:SetHidden(false)

        panel.commandLabel:SetText(tostring(commandName))
        panel.guildLabel:SetText(tostring(active.guildName))
        panel.channelLabel:SetText(tostring(self:GetAutoPopulateChannelStatusText(active.commandId, active.guildName)))
        panel.listHeader:SetText("Zone Cooldowns")
        panel.currentLabel:SetText("Current Zone")

        rows = self:GetAutoPopulateStatusRows(active.commandId, active.guildName)

        local currentRowData = nil
        local scrollRows = {}
        for _, rowData in ipairs(rows) do
            if rowData.isCurrent and not currentRowData then
                currentRowData = rowData
            else
                table.insert(scrollRows, rowData)
            end
        end

        if currentRowData then
            panel.currentRow:SetHidden(false)
            panel.currentRow.zone:SetText(tostring(currentRowData.zoneName))
            panel.currentRow.zone:SetColor(1, 1, 1, 1)
            panel.currentRow.timer:SetText(tostring(currentRowData.statusText))
            panel.currentRow.timer:SetColor(self:GetStatusPanelTimerColor(currentRowData.secondsRemaining, currentRowData.isApplicable))
        else
            panel.currentRow:SetHidden(true)
            panel.currentRow.zone:SetText("")
            panel.currentRow.timer:SetText("")
        end

        panel.currentCooldownRows = scrollRows

        local maxVisible = self:GetStatusPanelMaxVisibleCooldownRows()
        self:SetStatusPanelScrollOffset(self:GetStatusPanelScrollOffset(), #scrollRows)
        local startIndex = self:GetStatusPanelScrollOffset() + 1
        local endIndex = math.min(#scrollRows, startIndex + maxVisible - 1)

        local rowIndex = 1
        local dataIndex = startIndex
        while dataIndex <= endIndex and rowIndex <= #panel.rows do
            local row = panel.rows[rowIndex]
            local first = scrollRows[dataIndex]
            local second = nil

            local candidate = scrollRows[dataIndex + 1]
            if candidate and (dataIndex + 1) <= endIndex then
                second = candidate
            end

            row:SetHidden(false)
            row.isSingleSpan = false

            row.zone1:SetHidden(false)
            row.timer1:SetHidden(false)
            row.zone1:SetText(tostring(first.zoneName))
            row.zone1:SetColor(0.92, 0.92, 0.92, 1)
            row.timer1:SetText(tostring(first.statusText))
            row.timer1:SetColor(self:GetStatusPanelTimerColor(first.secondsRemaining, first.isApplicable))

            if second and not row.isSingleSpan then
                row.zone2:SetHidden(false)
                row.timer2:SetHidden(false)
                row.zone2:SetText(tostring(second.zoneName))
                row.zone2:SetColor(0.92, 0.92, 0.92, 1)
                row.timer2:SetText(tostring(second.statusText))
                row.timer2:SetColor(self:GetStatusPanelTimerColor(second.secondsRemaining, second.isApplicable))
            else
                row.zone2:SetHidden(true)
                row.timer2:SetHidden(true)
                row.zone2:SetText("")
                row.timer2:SetText("")
            end

            dataIndex = dataIndex + (second and 2 or 1)
            rowIndex = rowIndex + 1
        end

        for index = rowIndex, #panel.rows do
            local row = panel.rows[index]
            row:SetHidden(true)
            row.isSingleSpan = false
            row.zone1:SetText("")
            row.timer1:SetText("")
            row.zone2:SetText("")
            row.timer2:SetText("")
        end

        local showingFrom = #scrollRows > 0 and startIndex or 0
        local showingTo = #scrollRows > 0 and endIndex or 0
        local moreText = #scrollRows > maxVisible and " | Mouse wheel to scroll" or ""
        local totalTracked = #scrollRows + (currentRowData and 1 or 0)
        panel.footerLabel:SetText(string.format("Tracked Zones: %d | Other Zones %d-%d%s", totalTracked, showingFrom, showingTo, moreText))
    end

    local autoExpanded=self:GetStatusSectionExpanded("auto",active~=nil)
    panel.statusLabel:SetText((autoExpanded and "[-] " or "[+] ")..(active and "Auto: Active" or "Auto: Inactive"))
    if not autoExpanded then
        for _,control in ipairs({panel.commandLabel,panel.guildLabel,panel.channelLabel,panel.divider,panel.listHeader,panel.currentLabel,panel.currentRow,panel.footerLabel}) do control:SetHidden(true) end
        for _,row in ipairs(panel.rows) do row:SetHidden(true) end
    end
    local repeatRows = self:GetRepeatStatusPanelRows()
    local repeatExpanded=self:GetStatusSectionExpanded("repeat",#repeatRows>0)
    panel.repeatHeader:SetText((repeatExpanded and "[-] " or "[+] ").."Repeat Commands ("..tostring(#repeatRows)..")")
    panel.repeatDataRows = repeatRows
    panel.repeatDivider:SetHidden(false)
    panel.repeatHeader:SetHidden(false)

    if #repeatRows == 0 or not repeatExpanded then
        panel.repeatSectionHeight = 0
        panel.repeatScroll:SetHidden(true)
        panel.repeatEmptyLabel:SetHidden(not repeatExpanded)
        for _, row in ipairs(panel.repeatRows or {}) do
            row:SetHidden(true)
        end
    else
        panel.repeatEmptyLabel:SetHidden(true)
        panel.repeatScroll:SetHidden(false)

        local maxVisibleCards = 3
        local cardHeight = self:GetStatusPanelRepeatCardHeight()
        local cardGap = self:GetStatusPanelRepeatCardGap()
        local visibleCards = math.min(#repeatRows, maxVisibleCards)
        panel.repeatSectionHeight = math.min(self:GetStatusPanelRepeatSectionMaxHeight(), (visibleCards * cardHeight) + math.max(0, visibleCards - 1) * cardGap + 10)

        for index, rowData in ipairs(repeatRows) do
            local row = self:CreateStatusPanelRepeatCard(panel, index)
            row:SetHidden(false)
            row.commandLabel:SetText(tostring(rowData.displayName))
            if rowData.isActive then
                row.statusLabel:SetColor(0.32, 0.86, 0.45, 1)
            else
                row.statusLabel:SetColor(0.82, 0.82, 0.82, 1)
            end
            row.statusLabel:SetText(string.format("Status: %s", tostring(rowData.statusText))..(rowData.promotionText and "\nPromotion: "..rowData.promotionText or ""))
            row.detailsLabel:SetText(string.format("%s | %s", tostring(rowData.guildName), tostring(rowData.channelText)))
            row.timingLabel:SetText(self:GetRepeatCardTimingText(rowData))
            row.toggleButton:SetText(tostring(rowData.toggleText))
            row.toggleButton.data = {
                commandId = rowData.commandId,
                guildName = rowData.guildName,
            }
        end

        for index = #repeatRows + 1, #(panel.repeatRows or {}) do
            panel.repeatRows[index]:SetHidden(true)
            panel.repeatRows[index].toggleButton.data = nil
        end

        if panel.repeatScrollChild then
            local childHeight = (#repeatRows * cardHeight) + math.max(0, #repeatRows - 1) * cardGap
            panel.repeatScrollChild:SetHeight(math.max(childHeight, panel.repeatSectionHeight))
        end
    end

    self:ApplyStatusPanelLayout(panel, panel:GetWidth())

    local width, height = self:GetStatusPanelTargetSize(active, rows)
    self:StartStatusPanelSizeAnimation(width, height)
end


function SmartChatMsg:SetStatusPanelVisible(shouldShow)
    local panel = self:CreateStatusPanel()
    local visible = shouldShow == true
    self.statusPanelVisible = visible
    self:SetStatusPanelVisiblePreference(visible)
    panel:SetHidden(not visible)

    EVENT_MANAGER:UnregisterForUpdate(self.statusPanelRefreshName)
    if visible then
        self:RefreshStatusPanel()
        EVENT_MANAGER:RegisterForUpdate(self.statusPanelRefreshName, 1000, function()
            SmartChatMsg:RefreshStatusPanel()
        end)
    end
end


function SmartChatMsg:ToggleStatusPanel()
    self:SetStatusPanelVisible(not self.statusPanelVisible)
end
