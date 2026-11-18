-- KelaPadUI: names and lead acquisition information for hidden Antiquities
-- Journal entries (gamepad). The lead data tables (KELA_ANTIQUITY_LEAD_SOURCES,
-- KELA_ANTIQUITY_LEAD_SOURCE_OVERRIDES) live in kpui_data/kpui_antiquity_lead_data.lua.


local kelaLeadTooltipShown = false
local kelaAntiquityLeadSetupDone = false

local function GetAntiquityDisplayName(data)
    if data.GetColorizedFormattedName then
        return data:GetColorizedFormattedName()
    end
    if data.GetName then
        return data:GetName()
    end
end

local function GetAntiquityLeadSource(antiquityData)
    local antiquityId = antiquityData:GetId()
    local overrides = KELA_ANTIQUITY_LEAD_SOURCE_OVERRIDES and KELA_ANTIQUITY_LEAD_SOURCE_OVERRIDES[antiquityId]
    if overrides then
        local name = antiquityData.GetName and antiquityData:GetName()
        return name and overrides[name]
    end
    if KELA_ANTIQUITY_LEAD_SOURCES then
        return KELA_ANTIQUITY_LEAD_SOURCES[antiquityId]
    end
end

local function GetLeadSourceLines(source)
    local lines = {}
    if type(source) ~= "string" then
        return lines
    end

    for line in source:gmatch("[^\r\n]+") do
        local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" then
            table.insert(lines, trimmed)
        end
    end

    return lines
end

local function AddLeadSourceLines(lines, source)
    local sourceLines = GetLeadSourceLines(source)
    if #sourceLines == 0 then
        return false
    end

    table.insert(lines, zo_strformat(SI_ANTIQUITY_LEAD_NAME_FORMATTER, sourceLines[1]))
    for i = 2, #sourceLines do
        table.insert(lines, sourceLines[i])
    end

    return true
end

local function BuildAntiquityLeadTooltipText(antiquityData, includeSetDescriptor)
    local source = GetAntiquityLeadSource(antiquityData)
    if not source then
        return nil
    end

    local name = GetAntiquityDisplayName(antiquityData) or GetString(SI_ANTIQUITY_NAME_HIDDEN)
    local lines = { name }

    if includeSetDescriptor and antiquityData.GetAntiquitySetData then
        local setData = antiquityData:GetAntiquitySetData()
        if setData then
            table.insert(lines, zo_strformat(SI_ANTIQUITY_FRAGMENT_SET_DESCRIPTOR, setData:GetNumAntiquities(), GetAntiquityDisplayName(setData)))
        end
    end

    if not AddLeadSourceLines(lines, source) then
        return nil
    end

    return table.concat(lines, "\n")
end

local function BuildAntiquitySetLeadTooltipText(setData)
    local lines = { GetAntiquityDisplayName(setData) or GetString(SI_ANTIQUITY_NAME_HIDDEN) }
    local hasSource = false

    for _, antiquityData in setData:AntiquityIterator() do
        local isHidden = not antiquityData:MeetsLeadRequirements() and not antiquityData:HasRecovered()
        if isHidden then
            local source = GetAntiquityLeadSource(antiquityData)
            if source then
                if hasSource then
                    table.insert(lines, "")
                end
                table.insert(lines, GetAntiquityDisplayName(antiquityData) or GetString(SI_ANTIQUITY_NAME_HIDDEN))
                AddLeadSourceLines(lines, source)
                hasSource = true
            end
        end
    end

    if not hasSource then
        return nil
    end

    return table.concat(lines, "\n")
end

local function ShowRightTooltip(text)
    if not GAMEPAD_TOOLTIPS or not GAMEPAD_RIGHT_TOOLTIP then
        return false
    end
    GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(GAMEPAD_RIGHT_TOOLTIP, text)
    return true
end

local function ClearRightTooltip()
    if GAMEPAD_TOOLTIPS and GAMEPAD_RIGHT_TOOLTIP then
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
    end
end

local function ApplyHiddenEntryName(control, data)
    if not control or not control.titleLabel or not data or not data.HasDiscovered then
        return
    end
    if data:HasDiscovered() then
        return
    end

    local name = GetAntiquityDisplayName(data)
    if name and name ~= "" then
        control.titleLabel:SetText(name)
    end
end

function KelaSetupAntiquityLeadInfo()
    if kelaAntiquityLeadSetupDone then return end
    if not ZO_AntiquityJournalListGamepad then return end

    kelaAntiquityLeadSetupDone = true

    SecurePostHook(ZO_AntiquityJournalListGamepad, "SetupBaseRow", function(listObject, control, data)
        ApplyHiddenEntryName(control, data)
    end)

    -- Core lays out the right tooltip for discovered entries with a reward or
    -- set fragment, which replaces the lead tooltip. Anything else leaves the
    -- previous lead text on screen, so clear it here. (A secure post-hook keeps
    -- the core selection handler off the add-on callstack.)
    local function CoreLaysOutTooltip(data)
        if not data.HasDiscovered or not data:HasDiscovered() then
            return false
        end
        if data:GetType() == ZO_ANTIQUITY_TYPE_INDIVIDUAL then
            return data:GetAntiquitySetData() ~= nil or data:HasReward()
        end
        return data:HasReward()
    end

    SecurePostHook(ZO_AntiquityJournalListGamepad, "OnSelectionChanged", function(listObject, oldData, newData)
        if kelaLeadTooltipShown then
            if not newData or not CoreLaysOutTooltip(newData) then
                ClearRightTooltip()
            end
            kelaLeadTooltipShown = false
        end
        if not newData or not newData.HasDiscovered or newData:HasDiscovered() then
            return
        end

        local text
        if newData:GetType() == ZO_ANTIQUITY_TYPE_SET then
            text = BuildAntiquitySetLeadTooltipText(newData)
        elseif newData:GetType() == ZO_ANTIQUITY_TYPE_INDIVIDUAL then
            text = BuildAntiquityLeadTooltipText(newData, false)
        end

        if text then
            kelaLeadTooltipShown = ShowRightTooltip(text)
        end
    end)

    SecurePostHook(ZO_AntiquityJournalListGamepad, "OnAntiquitySetFragmentSelectionChanged", function(listObject, oldData, newData)
        if not newData then return end

        local isHidden = not newData:MeetsLeadRequirements() and not newData:HasRecovered()
        if not isHidden then
            kelaLeadTooltipShown = false
            return
        end

        local text = BuildAntiquityLeadTooltipText(newData, true)
        if text then
            kelaLeadTooltipShown = ShowRightTooltip(text)
        else
            kelaLeadTooltipShown = false
        end
    end)

    SecurePostHook(ZO_AntiquityJournalListGamepad, "ClearAntiquityTooltip", function()
        kelaLeadTooltipShown = false
    end)

    SecurePostHook(ZO_AntiquityJournalListGamepad, "ClearActiveFragmentList", function()
        if kelaLeadTooltipShown then
            ClearRightTooltip()
            kelaLeadTooltipShown = false
        end
    end)
end


