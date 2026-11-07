local IMP_STATS_SHARED = IMP_STATS_SHARED

local errors = {}

function errors:Initialize(settings)
    local sv = ImpressiveStatsErrors or {
        errors = {},
    }
    ImpressiveStatsErrors = sv

    self.errors = sv.errors

    self.enabled     = settings.enabled
    self.allowCSA    = settings.allowCSA
    self.allowAlerts = settings.allowAlerts

    local now = GetTimeStamp32()
    local thirtyDaysAgo = now - 30 * 24 * 60 * 60

    for _, moduleErrors in pairs(self.errors) do
        while moduleErrors[1] and moduleErrors[1][3] < thirtyDaysAgo do
            -- this is called every load, so it should not accumulate many old errors
            -- so, it should be fast cleaning, but still not ideal
            -- TODO: better approach
            -- TODO: limit amount of errors in buffer with circle buffer
            table.remove(moduleErrors, 1)
            moduleErrors.firstUnread = moduleErrors.firstUnread - 1
        end
    end
end

function errors:AddError(module, message, traceback)
    if not self.enabled then return end

    local errorsList = self.errors[module]
    if not errorsList then
        errorsList = {
            firstUnread = 1,
        }
        self.errors[module] = errorsList
    end
    errorsList[#errorsList+1] = {message, traceback, GetTimeStamp32()}

    IMP_STATS_SHARED.Notifications.UpdateNotifications()

    if CENTER_SCREEN_ANNOUNCE and self.allowCSA then
        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
        messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_BATTLEGROUND_MINUTE_WARNING)

        messageParams:SetText(message, '(check notifications)')
        messageParams:SetSound(SOUNDS.BATTLEGROUND_ROUND_STARTING)

        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
    end

    if self.allowAlerts then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, message..' (check notifications)')
    end
end

function errors:GetErrors()
    local output = {}

    for _, moduleErrors in pairs(self.errors) do
        for e = moduleErrors.firstUnread, #moduleErrors do
            output[#output+1] = moduleErrors[e][1]
        end
    end

    return output
end

function errors:Ack()
    for _, moduleErrors in pairs(self.errors) do
        moduleErrors.firstUnread = #moduleErrors + 1
    end
end

-- function errors:ClearErrors()
--     ZO_ClearNumericallyIndexedTable(self.errors)
-- end


IMP_STATS_SHARED.Errors = errors
