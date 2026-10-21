KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local ADDON_NAME = KRT.name

local DEFAULTS = {
    kws = {
        enabled = true,
        enableAutoLead = true,
        enableChat = true,
        debug = false,
        kickingPerson = "",
        actualLead = "",
        kickDelay = 2,
        returnDelay = 2,
        kalPhase = 0, -- 0 idle, 1 waiting for drop, 2 waiting for rebuild/return
        knownAccounts = {},
        profiles = {},
        lastProfile = "",
        offsetX = 150,
        offsetY = 150,
    }
}

KRT.KWS = {
    id = "kws",
    defaults = DEFAULTS.kws,
    ui = nil,
    rows = {},
    selectedPlayers = {},
    selectedKicker = "",
    selectedLead = "",
    selectedProfile = "",
    leadHeader = nil,
    kickerLabel = nil,
    kickerControl = nil,
    kickerComboBox = nil,
    leadLabel = nil,
    leadControl = nil,
    leadComboBox = nil,
    profilesHeader = nil,
    comboBox = nil,
    editBox = nil,
    kickBtn = nil,
    fragment = nil,
    pendingInvites = {},
    pendingKicksCount = 0,
    inviteTimeoutTimer = nil,
    isProcessing = false,
    isPopulating = false,
    myDisplayNameLower = "",
}
local mod = KRT.KWS

local function SV()
    return KRT.GetModuleSV("kws", DEFAULTS.kws)
end

-- Backwards-compatible SavedVariables migration from standalone KAL
local function MigrateSV()
    local sv = SV()
    if KRT.sv and KRT.sv.kal then
        local old = KRT.sv.kal
        if (sv.kickingPerson == nil or sv.kickingPerson == "") and old.kickingPerson and old.kickingPerson ~= "" then
            sv.kickingPerson = old.kickingPerson
        end
        if (sv.actualLead == nil or sv.actualLead == "") and old.actualLead and old.actualLead ~= "" then
            sv.actualLead = old.actualLead
        end
        if sv.kickDelay == nil and old.kickDelay ~= nil then
            sv.kickDelay = old.kickDelay
        end
        if sv.returnDelay == nil and old.returnDelay ~= nil then
            sv.returnDelay = old.returnDelay
        end
        if sv.enableChat == nil and old.enableChat ~= nil then
            sv.enableChat = old.enableChat
        end
        if sv.enableAutoLead == nil and old.enabled ~= nil then
            sv.enableAutoLead = old.enabled
        end
        if old.knownAccounts and type(old.knownAccounts) == "table" then
            sv.knownAccounts = sv.knownAccounts or {}
            for acc, val in pairs(old.knownAccounts) do
                if sv.knownAccounts[acc] == nil then
                    sv.knownAccounts[acc] = val
                end
            end
        end
        if (sv.profiles == nil or next(sv.profiles) == nil) and old.profiles and type(old.profiles) == "table" then
            sv.profiles = ZO_DeepTableCopy(old.profiles)
        end
        if (sv.lastProfile == nil or sv.lastProfile == "") and old.lastProfile and old.lastProfile ~= "" then
            sv.lastProfile = old.lastProfile
        end
    end
    if sv.knownAccounts == nil then
        sv.knownAccounts = {}
    end
    if sv.kickingPerson and sv.kickingPerson ~= "" then
        sv.knownAccounts[sv.kickingPerson] = true
    end
    if sv.actualLead and sv.actualLead ~= "" then
        sv.knownAccounts[sv.actualLead] = true
    end
    -- Keep backwards-compatible alias so anything referencing KRT.sv.kal points directly here
    if KRT.sv then
        KRT.sv.kal = sv
    end
    return sv
end

-- =========================================================
-- Auto Lead Passing State & Logic
-- =========================================================

local POLL_UPDATE_NAME = ADDON_NAME .. "_KWS_Poll"

local kalState = {
    lastDifficultyKey = nil,
    isZoning = false,
    lastActivationTime = 0,

    kickPassTimer = nil,
    returnPassTimer = nil,

    preKickGroupSize = 0,
    expectedGroupSize = 0,
    lowestObservedGroupSize = 0,
    lastObservedGroupSize = -1,
    highWaterGroupSize = 0,
    lastSizeChangeMs = 0,
    polling = false,
}

local function Lower(value)
    return string.lower(value or "")
end

local Now = GetGameTimeMilliseconds

local function Notice(msg)
    local sv = SV()
    if sv and sv.enabled and sv.enableChat then
        d("[Kwibus Spaulder] " .. tostring(msg))
    end
end

local function ClearTimer(timerId)
    if timerId then
        zo_removeCallLater(timerId)
    end
    return nil
end

local function StopPolling()
    if kalState.polling then
        EM:UnregisterForUpdate(POLL_UPDATE_NAME)
        kalState.polling = false
    end
end

local function StartPolling(pollFunc)
    if kalState.polling then return end
    kalState.polling = true
    EM:RegisterForUpdate(POLL_UPDATE_NAME, 1000, pollFunc)
end

local function ClearAllTimers()
    kalState.kickPassTimer = ClearTimer(kalState.kickPassTimer)
    kalState.returnPassTimer = ClearTimer(kalState.returnPassTimer)
end

local function ResetWorkflow()
    ClearAllTimers()
    StopPolling()

    local sv = SV()
    if sv then sv.kalPhase = 0 end
    kalState.preKickGroupSize = 0
    kalState.expectedGroupSize = 0
    kalState.lowestObservedGroupSize = 0
    kalState.lastObservedGroupSize = -1
    kalState.lastSizeChangeMs = 0
end

local function UpdateObservedGroupSize(currentSize)
    currentSize = currentSize or (GetGroupSize() or 0)

    if currentSize > kalState.highWaterGroupSize then
        kalState.highWaterGroupSize = currentSize
    end

    if currentSize ~= kalState.lastObservedGroupSize then
        kalState.lastObservedGroupSize = currentSize
        kalState.lastSizeChangeMs = Now()
    end
end

local function GetDifficultyKey()
    if IsGroupUsingVeteranDifficulty ~= nil then
        return IsGroupUsingVeteranDifficulty() and 2 or 1
    end
    return nil
end

local function OnPlayerDeactivated()
    kalState.isZoning = true
end

local function OnPlayerActivated()
    kalState.isZoning = false
    kalState.lastActivationTime = Now()
end

local function RememberAccount(name)
    if not name or name == "" or name == "None" or name == "Select" then return end
    local sv = SV()
    if sv then
        if not sv.knownAccounts then sv.knownAccounts = {} end
        sv.knownAccounts[name] = true
    end
end

local function FindGroupUnitTagByName(targetName)
    if not targetName or targetName == "" then return nil end
    local targetLower = Lower(targetName)

    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag then
            local accName = Lower(GetUnitDisplayName(unitTag) or "")
            if accName == targetLower then
                return unitTag
            end

            local rawCharName = GetUnitName(unitTag) or ""
            local charName = Lower(zo_strformat("<<1>>", rawCharName))
            if charName == targetLower then
                return unitTag
            end
        end
    end
    return nil
end

local function PassLeadTo(targetName)
    if not IsUnitGroupLeader("player") then
        return false, "I am not the group leader"
    end

    local currentSize = GetGroupSize() or 0
    if currentSize <= 6 then
        return false, "Group size is 6 or less"
    end

    if not targetName or targetName == "" then
        return false, "Target name is empty"
    end

    local unitTag = FindGroupUnitTagByName(targetName)
    if not unitTag then
        return false, "Target not found in current group"
    end

    GroupPromote(unitTag)
    return true, nil
end

local function IsLocalPlayerConfiguredKicker()
    local kicker = SV().kickingPerson or ""
    return kicker ~= "" and Lower(kicker) == Lower(GetDisplayName() or "")
end

local function ArmPhase(phase, targetSize, observedSize)
    ClearAllTimers()

    SV().kalPhase = phase
    kalState.preKickGroupSize = targetSize
    kalState.expectedGroupSize = targetSize
    kalState.lowestObservedGroupSize = observedSize
    kalState.lastObservedGroupSize = observedSize
    kalState.lastSizeChangeMs = Now()
end

local PollWorkflow

local function EnsureLocalKickerWorkflow()
    local sv = SV()
    if not (sv and sv.enabled and sv.enableAutoLead) then return end
    if (sv.kalPhase or 0) ~= 0 then return end
    if not IsUnitGroupLeader("player") then return end
    if not IsLocalPlayerConfiguredKicker() then return end

    local actualLead = sv.actualLead or ""
    if actualLead == "" then return end

    local currentSize = GetGroupSize() or 0
    if currentSize <= 6 then return end

    UpdateObservedGroupSize(currentSize)

    ArmPhase(1, currentSize, currentSize)
    StartPolling(PollWorkflow)
end

local function ScheduleKickPass(delayMs, kicker)
    local currentSize = GetGroupSize() or 0
    if currentSize <= 6 then return end

    if kalState.kickPassTimer then return end

    kalState.kickPassTimer = zo_callLater(function()
        kalState.kickPassTimer = nil

        local sv = SV()
        if not (sv and sv.enabled and sv.enableAutoLead) then return end
        if (GetGroupSize() or 0) <= 6 then return end

        local ok = PassLeadTo(kicker)
        if ok then
            Notice("Passed lead to Kicking Person: " .. tostring(kicker))
        else
            Notice("Could not pass lead to Kicking Person (" .. tostring(kicker) .. ").")
        end
    end, delayMs)
end

local function ScheduleReturnPass(delayMs)
    local currentSize = GetGroupSize() or 0
    if currentSize <= 6 then return end

    if kalState.returnPassTimer then return end

    kalState.returnPassTimer = zo_callLater(function()
        kalState.returnPassTimer = nil

        local sv = SV()
        if not (sv and sv.enabled and sv.enableAutoLead) then return end

        local phase = sv.kalPhase or 0
        local nowSize = GetGroupSize() or 0
        local requiredSize = kalState.preKickGroupSize or 0

        if phase ~= 2 then return end

        if nowSize <= 6 or requiredSize <= 6 or nowSize < requiredSize then return end

        local actualLead = sv.actualLead or ""
        if actualLead == "" then return end

        if Lower(actualLead) == Lower(GetDisplayName() or "") then
            ResetWorkflow()
            return
        end

        local ok = PassLeadTo(actualLead)
        if ok then
            Notice("Passed lead back to Actual Lead: " .. tostring(actualLead))
        else
            Notice("Could not pass lead back to Actual Lead (" .. tostring(actualLead) .. ").")
        end
        ResetWorkflow()
    end, delayMs)
end

PollWorkflow = function()
    local sv = SV()
    if not (sv and sv.enabled and sv.enableAutoLead) then
        StopPolling()
        return
    end

    EnsureLocalKickerWorkflow()

    local phase = sv.kalPhase or 0
    if phase == 0 then
        StopPolling()
        return
    end

    local currentSize = GetGroupSize() or 0
    UpdateObservedGroupSize(currentSize)

    if (kalState.preKickGroupSize or 0) <= 6 or not IsUnitGrouped("player") then
        ResetWorkflow()
        return
    end

    if phase == 1 then
        if kalState.preKickGroupSize > 6 and currentSize < kalState.preKickGroupSize then
            kalState.lowestObservedGroupSize = currentSize
            sv.kalPhase = 2
        end
        return
    end

    if phase == 2 then
        if kalState.lowestObservedGroupSize == 0 or currentSize < kalState.lowestObservedGroupSize then
            kalState.lowestObservedGroupSize = currentSize
        end

        if kalState.preKickGroupSize > 6 and currentSize >= kalState.preKickGroupSize then
            ScheduleReturnPass((sv.returnDelay or 2) * 1000)
        else
            kalState.returnPassTimer = ClearTimer(kalState.returnPassTimer)
        end
    end
end

local function CheckGroupState()
    local sv = SV()
    if not (sv and sv.enabled and sv.enableAutoLead) then return end

    local currentSize = GetGroupSize() or 0
    if not IsUnitGrouped("player") or currentSize <= 1 then
        ResetWorkflow()
        return
    end

    if (sv.kalPhase or 0) == 0 and currentSize <= 6 then
        return
    end

    UpdateObservedGroupSize(currentSize)

    EnsureLocalKickerWorkflow()

    if (sv.kalPhase or 0) ~= 0 then
        StartPolling(PollWorkflow)
        PollWorkflow()
    end
end

local function OnDifficultyChanged()
    local sv = SV()
    if not (sv and sv.enabled and sv.enableAutoLead) then return end

    local newKey = GetDifficultyKey()
    if newKey == nil then return end

    if kalState.isZoning or (Now() - kalState.lastActivationTime < 2500) then
        kalState.lastDifficultyKey = newKey
        return
    end

    local prevKey = kalState.lastDifficultyKey
    kalState.lastDifficultyKey = newKey
    if prevKey == nil or prevKey == newKey then return end

    local currentSize = GetGroupSize() or 0
    if currentSize <= 6 then return end

    UpdateObservedGroupSize(currentSize)

    kalState.preKickGroupSize = currentSize

    if IsLocalPlayerConfiguredKicker() then
        ArmPhase(1, currentSize, currentSize)
        StartPolling(PollWorkflow)
        PollWorkflow()
        return
    end

    local kicker = sv.kickingPerson or ""
    if kicker == "" then return end

    if not IsUnitGroupLeader("player") then return end

    ScheduleKickPass((sv.kickDelay or 2) * 1000, kicker)
end

-- =========================================================
-- Shared Dropdown Choices (LAM & In-Game UI)
-- =========================================================

local KWSChoices = { "Select" }
local KWSValues = { "" }

local function RefreshDropdownControl(control)
    if not control then return end
    if control.UpdateChoices then
        control:UpdateChoices(KWSChoices, KWSValues)
    end
    if control.UpdateValue then
        control:UpdateValue(false)
    end
end

local function RebuildGroupRosterChoices()
    ZO_ClearTable(KWSChoices)
    ZO_ClearTable(KWSValues)

    table.insert(KWSChoices, "Select")
    table.insert(KWSValues, "")

    local added = {}
    local sv = SV()
    local gs = GetGroupSize() or 0

    for i = 1, gs do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag and DoesUnitExist(unitTag) then
            local acc = GetUnitDisplayName(unitTag) or ""
            if acc ~= "" and not added[acc] then
                table.insert(KWSChoices, acc)
                table.insert(KWSValues, acc)
                added[acc] = true
            end
        end
    end

    local savedNames = {}
    if sv and sv.knownAccounts then
        for acc, flag in pairs(sv.knownAccounts) do
            if flag and acc ~= "" and not added[acc] then
                table.insert(savedNames, acc)
            end
        end
    end
    table.sort(savedNames)

    for _, acc in ipairs(savedNames) do
        table.insert(KWSChoices, acc .. " (Saved)")
        table.insert(KWSValues, acc)
        added[acc] = true
    end

    if sv then
        if sv.kickingPerson and sv.kickingPerson ~= "" and not added[sv.kickingPerson] then
            table.insert(KWSChoices, sv.kickingPerson .. " (Saved)")
            table.insert(KWSValues, sv.kickingPerson)
            added[sv.kickingPerson] = true
        end

        if sv.actualLead and sv.actualLead ~= "" and not added[sv.actualLead] then
            table.insert(KWSChoices, sv.actualLead .. " (Saved)")
            table.insert(KWSValues, sv.actualLead)
            added[sv.actualLead] = true
        end
    end

    RefreshDropdownControl(KRT_KWS_Kicker_Dropdown)
    RefreshDropdownControl(KRT_KWS_Lead_Dropdown)
end

-- =========================================================
-- Profile Management
-- =========================================================

local function SaveProfileData(pName)
    local sv = SV()
    if not sv.profiles then
        sv.profiles = {}
    end
    sv.profiles[pName] = {
        selectedPlayers = ZO_DeepTableCopy(mod.selectedPlayers),
        kicker = mod.selectedKicker,
        lead = mod.selectedLead,
    }
    sv.lastProfile = pName
    mod.selectedProfile = pName
    mod:UpdateProfileDropdown(pName)
    if mod.editBox then
        mod.editBox:SetText(pName)
    end
end

local function RegisterOverwriteDialog()
    ZO_Dialogs_RegisterCustomDialog("KWS_CONFIRM_OVERWRITE", {
        title = { text = "Overwrite Profile?" },
        mainText = { text = "A profile named '<<1>>' already exists. Do you want to overwrite it?" },
        buttons = {
            [1] = {
                text = SI_DIALOG_YES,
                callback = function(dialog)
                    if dialog.data and dialog.data.profileName then
                        SaveProfileData(dialog.data.profileName)
                    end
                end,
            },
            [2] = {
                text = SI_DIALOG_NO,
            },
        },
    })
end

-- =========================================================
-- In-Game Lead / Kicker Dropdowns
-- =========================================================

function KRT.KWS:PopulateLeadKickerDropdowns(members)
    if not self.kickerComboBox or not self.leadComboBox or not members then return end

    local sv = SV()
    if (not self.selectedLead or self.selectedLead == "") and sv.actualLead then
        self.selectedLead = sv.actualLead
    end
    if (not self.selectedKicker or self.selectedKicker == "") and sv.kickingPerson then
        self.selectedKicker = sv.kickingPerson
    end

    KRT.DebounceNextFrame(ADDON_NAME .. "_PopulateDropdowns", function()
        if not self.kickerComboBox or not self.leadComboBox then return end

        self.isPopulating = true

        self.kickerComboBox:ClearItems()
        self.leadComboBox:ClearItems()

        local kickerIndex = 1
        local leadIndex = 1
        local index = 1

        local noneEntry1 = self.kickerComboBox:CreateItemEntry("None", function()
            self.selectedKicker = ""
            SV().kickingPerson = ""
            RebuildGroupRosterChoices()
            if self.kickerComboBox and self.kickerComboBox.HideDropdown then
                self.kickerComboBox:HideDropdown()
            end
        end)
        self.kickerComboBox:AddItem(noneEntry1, ZO_COMBOBOX_SUPPRESS_UPDATE)

        local noneEntry2 = self.leadComboBox:CreateItemEntry("None", function()
            self.selectedLead = ""
            SV().actualLead = ""
            RebuildGroupRosterChoices()
            if self.leadComboBox and self.leadComboBox.HideDropdown then
                self.leadComboBox:HideDropdown()
            end
        end)
        self.leadComboBox:AddItem(noneEntry2, ZO_COMBOBOX_SUPPRESS_UPDATE)

        local addedAccounts = {}

        for i = 1, #members do
            local displayName = members[i].displayName
            if displayName and displayName ~= "" and not addedAccounts[displayName] then
                addedAccounts[displayName] = true
                index = index + 1
                local displayNameLower = string.lower(displayName)

                local kickerEntry = self.kickerComboBox:CreateItemEntry(displayName, function()
                    self.selectedKicker = displayName
                    SV().kickingPerson = displayName
                    RememberAccount(displayName)
                    RebuildGroupRosterChoices()
                    EnsureLocalKickerWorkflow()
                    if self.kickerComboBox and self.kickerComboBox.HideDropdown then
                        self.kickerComboBox:HideDropdown()
                    end
                end)
                self.kickerComboBox:AddItem(kickerEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)

                if string.lower(self.selectedKicker) == displayNameLower then
                    kickerIndex = index
                end

                local leadEntry = self.leadComboBox:CreateItemEntry(displayName, function()
                    self.selectedLead = displayName
                    SV().actualLead = displayName
                    RememberAccount(displayName)
                    RebuildGroupRosterChoices()
                    EnsureLocalKickerWorkflow()
                    if self.leadComboBox and self.leadComboBox.HideDropdown then
                        self.leadComboBox:HideDropdown()
                    end
                end)
                self.leadComboBox:AddItem(leadEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)

                if string.lower(self.selectedLead) == displayNameLower then
                    leadIndex = index
                end
            end
        end

        -- Add any saved accounts that are not currently in the group
        if sv.knownAccounts then
            local savedList = {}
            for acc, flag in pairs(sv.knownAccounts) do
                if flag and acc ~= "" and not addedAccounts[acc] then
                    table.insert(savedList, acc)
                end
            end
            table.sort(savedList)

            for _, acc in ipairs(savedList) do
                index = index + 1
                local accLower = string.lower(acc)
                local displayLabel = acc .. " (Saved)"

                local kickerEntry = self.kickerComboBox:CreateItemEntry(displayLabel, function()
                    self.selectedKicker = acc
                    SV().kickingPerson = acc
                    RememberAccount(acc)
                    RebuildGroupRosterChoices()
                    EnsureLocalKickerWorkflow()
                    if self.kickerComboBox and self.kickerComboBox.HideDropdown then
                        self.kickerComboBox:HideDropdown()
                    end
                end)
                self.kickerComboBox:AddItem(kickerEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)

                if string.lower(self.selectedKicker) == accLower then
                    kickerIndex = index
                end

                local leadEntry = self.leadComboBox:CreateItemEntry(displayLabel, function()
                    self.selectedLead = acc
                    SV().actualLead = acc
                    RememberAccount(acc)
                    RebuildGroupRosterChoices()
                    EnsureLocalKickerWorkflow()
                    if self.leadComboBox and self.leadComboBox.HideDropdown then
                        self.leadComboBox:HideDropdown()
                    end
                end)
                self.leadComboBox:AddItem(leadEntry, ZO_COMBOBOX_SUPPRESS_UPDATE)

                if string.lower(self.selectedLead) == accLower then
                    leadIndex = index
                end
            end
        end

        self.kickerComboBox:UpdateItems()
        self.leadComboBox:UpdateItems()

        self.kickerComboBox:SelectItemByIndex(kickerIndex)
        self.leadComboBox:SelectItemByIndex(leadIndex)

        self.isPopulating = false
    end)
end

-- =========================================================
-- UI Creation
-- =========================================================

function KRT.KWS:CreateUI()
    if self.ui and self.ui:GetNamedChild("Title") and #self.rows == 12 then
        return
    end

    local win = _G["KwibusSpaulderUI"]
    if not win then
        win = WM:CreateTopLevelWindow("KwibusSpaulderUI")
    end

    win:SetDimensions(320, 650)
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV().offsetX or 150, SV().offsetY or 150)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetHandler("OnMoveStop", function(control)
        SV().offsetX = control:GetLeft()
        SV().offsetY = control:GetTop()
    end)

    if not win:GetNamedChild("Backdrop") then
        local bg = WM:CreateControlFromVirtual("$(parent)Backdrop", win, "ZO_DefaultBackdrop")
        if bg then bg:SetAnchorFill() end
    end

    if not win:GetNamedChild("Title") then
        local title = WM:CreateControl("$(parent)Title", win, CT_LABEL)
        if title then
            title:SetFont("ZoFontWinH2")
            title:SetText("Kwibus Spaulder")
            title:SetAnchor(TOP, win, TOP, 0, 10)
        end
    end

    for i = 1, 12 do
        local row = self.rows[i]
        if not row or not (row.cb and row.role and row.nameLabel and row.zoneIcon) then
            row = WM:CreateControl(nil, win, CT_CONTROL)
            row:SetDimensions(300, 26)
            row:SetAnchor(TOPLEFT, win, TOPLEFT, 10, 40 + ((i - 1) * 26))

            local cb = WM:CreateControl(nil, row, CT_BUTTON)
            cb:SetDimensions(20, 20)
            cb:SetAnchor(LEFT, row, LEFT, 5, 0)
            cb:SetNormalTexture("esoui/art/buttons/checkbox_unchecked.dds")
            cb:SetMouseOverTexture("esoui/art/buttons/checkbox_mouseover.dds")
            cb:SetPressedTexture("esoui/art/buttons/checkbox_checked.dds")
            cb:SetDisabledTexture("esoui/art/buttons/checkbox_disabled.dds")
            cb.checked = false

            local role = WM:CreateControl(nil, row, CT_TEXTURE)
            role:SetDimensions(24, 24)
            role:SetAnchor(LEFT, cb, RIGHT, 5, 0)

            local rr, rg, rb, ra = role:GetColor()
            row.roleOriginalColor = { rr, rg, rb, ra }

            local nameLabel = WM:CreateControl(nil, row, CT_LABEL)
            nameLabel:SetFont("ZoFontGame")
            nameLabel:SetAnchor(LEFT, role, RIGHT, 5, 0)
            nameLabel:SetDimensions(190, 24)

            local zoneIcon = WM:CreateControl(nil, row, CT_TEXTURE)
            zoneIcon:SetDimensions(24, 24)
            zoneIcon:SetAnchor(LEFT, nameLabel, RIGHT, 5, 0)

            cb:SetHandler("OnClicked", function(control)
                if row.isSelf or self.isProcessing then return end
                control.checked = not control.checked
                if control.checked then
                    control:SetNormalTexture("esoui/art/buttons/checkbox_checked.dds")
                    control:SetMouseOverTexture("esoui/art/buttons/checkbox_checked_mouseover.dds")
                else
                    control:SetNormalTexture("esoui/art/buttons/checkbox_unchecked.dds")
                    control:SetMouseOverTexture("esoui/art/buttons/checkbox_mouseover.dds")
                end
                if row.displayName then
                    self.selectedPlayers[row.displayName] = control.checked
                end
            end)

            row.cb = cb
            row.role = role
            row.nameLabel = nameLabel
            row.zoneIcon = zoneIcon
            self.rows[i] = row
        end
    end

    if not self.kickBtn then
        local kickBtn = WM:CreateControlFromVirtual(nil, win, "ZO_DefaultButton")
        if kickBtn then
            kickBtn:SetAnchor(TOP, win, TOP, 0, 360)
            kickBtn:SetWidth(230)
            kickBtn:SetText("Kick & Re-invite Selected")
            kickBtn:SetHandler("OnClicked", function() self:KickAndReinvite() end)
            local isLeader = IsUnitGrouped("player") and IsUnitGroupLeader("player")
            kickBtn:SetEnabled(isLeader and not self.isProcessing)
            self.kickBtn = kickBtn
        end
    end

    if not self.kickerComboBox then
        local leadHeader = WM:CreateControl("$(parent)LeadHeader", win, CT_LABEL)
        if leadHeader then
            leadHeader:SetFont("ZoFontWinH3")
            leadHeader:SetText("Lead Passing Settings")
            leadHeader:SetAnchor(TOPLEFT, win, TOPLEFT, 15, 400)
            self.leadHeader = leadHeader
        end

        local kickerLabel = WM:CreateControl("$(parent)KickerLabel", win, CT_LABEL)
        if kickerLabel then
            kickerLabel:SetFont("ZoFontGame")
            kickerLabel:SetText("Kicker:")
            kickerLabel:SetAnchor(TOPLEFT, leadHeader, BOTTOMLEFT, 0, 8)
            self.kickerLabel = kickerLabel
        end

        local kickerCtrl = WM:CreateControlFromVirtual("KwibusKickerComboBox", win, "ZO_ComboBox")
        if kickerCtrl and kickerLabel then
            kickerCtrl:SetDimensions(210, 24)
            kickerCtrl:SetAnchor(LEFT, kickerLabel, RIGHT, 10, 0)
            self.kickerControl = kickerCtrl
            self.kickerComboBox = ZO_ComboBox_ObjectFromContainer(kickerCtrl)
            if self.kickerComboBox then
                self.kickerComboBox:SetSortsItems(false)
            end
        end

        local leadLabel = WM:CreateControl("$(parent)LeadLabel", win, CT_LABEL)
        if leadLabel and kickerLabel then
            leadLabel:SetFont("ZoFontGame")
            leadLabel:SetText("Lead:")
            leadLabel:SetAnchor(TOPLEFT, kickerLabel, BOTTOMLEFT, 0, 12)
            self.leadLabel = leadLabel
        end

        local leadCtrl = WM:CreateControlFromVirtual("KwibusLeadComboBox", win, "ZO_ComboBox")
        if leadCtrl and leadLabel then
            leadCtrl:SetDimensions(210, 24)
            leadCtrl:SetAnchor(LEFT, leadLabel, RIGHT, 22, 0)
            self.leadControl = leadCtrl
            self.leadComboBox = ZO_ComboBox_ObjectFromContainer(leadCtrl)
            if self.leadComboBox then
                self.leadComboBox:SetSortsItems(false)
            end
        end
    end

    if not self.comboBox then
        local pTitle = WM:CreateControl(nil, win, CT_LABEL)
        if pTitle then
            pTitle:SetFont("ZoFontWinH3")
            pTitle:SetText("Profiles")
            pTitle:SetAnchor(TOPLEFT, win, TOPLEFT, 15, 510)
            self.profilesHeader = pTitle
        end

        local editBg = WM:CreateControlFromVirtual(nil, win, "ZO_EditBackdrop")
        if editBg then
            editBg:SetDimensions(190, 26)
            editBg:SetAnchor(TOPLEFT, pTitle, BOTTOMLEFT, 0, 8)
            self.editBox = WM:CreateControlFromVirtual(nil, editBg, "ZO_DefaultEditForBackdrop")
        end

        local saveBtn = WM:CreateControlFromVirtual(nil, win, "ZO_DefaultButton")
        if saveBtn and editBg then
            saveBtn:SetDimensions(80, 28)
            saveBtn:SetAnchor(LEFT, editBg, RIGHT, 10, 0)
            saveBtn:SetText("Save")
            saveBtn:SetHandler("OnClicked", function()
                if self.editBox then
                    local pName = self.editBox:GetText()
                    if pName and pName ~= "" then
                        if SV().profiles and SV().profiles[pName] ~= nil then
                            ZO_Dialogs_ShowDialog("KWS_CONFIRM_OVERWRITE", { profileName = pName }, { mainTextParams = { pName } })
                        else
                            SaveProfileData(pName)
                        end
                    end
                end
            end)
        end

        local comboCtrl = WM:CreateControlFromVirtual("KwibusProfileComboBox", win, "ZO_ComboBox")
        if comboCtrl and editBg then
            comboCtrl:SetDimensions(130, 26)
            comboCtrl:SetAnchor(TOPLEFT, editBg, BOTTOMLEFT, 0, 15)
            self.comboBox = ZO_ComboBox_ObjectFromContainer(comboCtrl)
            if self.comboBox then
                self.comboBox:SetSortsItems(false)
            end
        end

        local loadBtn = WM:CreateControlFromVirtual(nil, win, "ZO_DefaultButton")
        if loadBtn and comboCtrl then
            loadBtn:SetDimensions(70, 28)
            loadBtn:SetAnchor(LEFT, comboCtrl, RIGHT, 10, 0)
            loadBtn:SetText("Load")
            loadBtn:SetHandler("OnClicked", function()
                local sv = SV()
                local selected = self.comboBox and self.comboBox:GetSelectedItemData()
                local pName = (selected and selected.name) or (self.editBox and self.editBox:GetText()) or self.selectedProfile or sv.lastProfile
                if pName and pName ~= "" then
                    local profData = sv.profiles and sv.profiles[pName]
                    if not profData and sv.profiles then
                        for k, v in pairs(sv.profiles) do
                            if string.lower(k) == string.lower(pName) then
                                pName = k
                                profData = v
                                break
                            end
                        end
                    end

                    if profData then
                        self.selectedProfile = pName
                        sv.lastProfile = pName
                        if self.editBox then
                            self.editBox:SetText(pName)
                        end
                        if self.comboBox and (not selected or selected.name ~= pName) then
                            self:UpdateProfileDropdown(pName)
                        end

                        if profData.selectedPlayers then
                            self.selectedPlayers = ZO_DeepTableCopy(profData.selectedPlayers)
                        else
                            self.selectedPlayers = ZO_DeepTableCopy(profData)
                        end

                        if profData.kicker and profData.kicker ~= "" then
                            self.selectedKicker = profData.kicker
                            sv.kickingPerson = profData.kicker
                            RememberAccount(profData.kicker)
                        end

                        if profData.lead and profData.lead ~= "" then
                            self.selectedLead = profData.lead
                            sv.actualLead = profData.lead
                            RememberAccount(profData.lead)
                        end

                        RebuildGroupRosterChoices()
                        EnsureLocalKickerWorkflow()
                        self:RefreshRows()
                    end
                end
            end)
        end

        local deleteBtn = WM:CreateControlFromVirtual(nil, win, "ZO_DefaultButton")
        if deleteBtn and loadBtn then
            deleteBtn:SetDimensions(70, 28)
            deleteBtn:SetAnchor(LEFT, loadBtn, RIGHT, 10, 0)
            deleteBtn:SetText("Delete")
            deleteBtn:SetHandler("OnClicked", function()
                local selected = self.comboBox and self.comboBox:GetSelectedItemData()
                local pName = (selected and selected.name) or (self.editBox and self.editBox:GetText()) or self.selectedProfile
                if pName and pName ~= "" then
                    local sv = SV()
                    if sv.profiles then
                        if sv.profiles[pName] then
                            sv.profiles[pName] = nil
                        else
                            for k in pairs(sv.profiles) do
                                if string.lower(k) == string.lower(pName) then
                                    sv.profiles[k] = nil
                                    break
                                end
                            end
                        end
                    end
                    if string.lower(sv.lastProfile or "") == string.lower(pName) then
                        sv.lastProfile = ""
                    end
                    if string.lower(self.selectedProfile or "") == string.lower(pName) then
                        self.selectedProfile = ""
                    end
                    if self.editBox and string.lower(self.editBox:GetText() or "") == string.lower(pName) then
                        self.editBox:SetText("")
                    end
                    self:UpdateProfileDropdown()
                end
            end)
        end
    end

    self.ui = win
    self:UpdateProfileDropdown()
end

function KRT.KWS:UpdateProfileDropdown(preferredProfileName)
    if not self.comboBox then return end
    self.comboBox:ClearItems()

    local sv = SV()
    if not sv.profiles then
        sv.profiles = {}
    end

    local profileNames = {}
    for pName, _ in pairs(sv.profiles) do
        if type(pName) == "string" and pName ~= "" then
            table.insert(profileNames, pName)
        end
    end
    table.sort(profileNames, function(a, b) return string.lower(a) < string.lower(b) end)

    if #profileNames == 0 then
        self.selectedProfile = ""
        sv.lastProfile = ""
        if self.editBox then
            self.editBox:SetText("")
        end
        return
    end

    local targetName = preferredProfileName
    if not targetName or targetName == "" then
        targetName = self.selectedProfile
    end
    if not targetName or targetName == "" then
        targetName = sv.lastProfile
    end

    local matchedName = nil
    if targetName and targetName ~= "" then
        local targetLower = string.lower(targetName)
        for _, name in ipairs(profileNames) do
            if string.lower(name) == targetLower then
                matchedName = name
                break
            end
        end
    end

    if not matchedName then
        matchedName = profileNames[1]
    end

    local targetEntry = nil
    for _, name in ipairs(profileNames) do
        local entry = self.comboBox:CreateItemEntry(name, function()
            self.selectedProfile = name
            SV().lastProfile = name
            if self.editBox then
                self.editBox:SetText(name)
            end
            if self.comboBox and self.comboBox.HideDropdown then
                self.comboBox:HideDropdown()
            end
        end)
        if entry then
            self.comboBox:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
            if name == matchedName then
                targetEntry = entry
            end
        end
    end

    self.comboBox:UpdateItems()

    if targetEntry then
        self.comboBox:SelectItem(targetEntry, true)
        self.selectedProfile = matchedName
        sv.lastProfile = matchedName
        if self.editBox then
            self.editBox:SetText(matchedName)
        end
    end
end

local function RestoreRoleColor(row)
    if not row or not row.role then return end
    local c = row.roleOriginalColor
    if c then
        row.role:SetColor(c[1], c[2], c[3], c[4])
    else
        row.role:SetColor(1, 1, 1, 1)
    end
end

local function SortGroupMembers(a, b)
    if not a or not b then return false end
    if a.roleWeight ~= b.roleWeight then
        return a.roleWeight < b.roleWeight
    end
    return (a.displayName or "") < (b.displayName or "")
end

local _refreshMembers = {}

function KRT.KWS:RefreshRows()
    if not self.ui then
        self:CreateUI()
    end

    if not self.ui or self.ui:IsHidden() then return end

    if self.comboBox and (not self.comboBox:GetSelectedItemData() or self.comboBox:GetNumItems() == 0) then
        self:UpdateProfileDropdown()
    end

    local sv = SV()
    local isAutoLeadEnabled = sv.enabled and (sv.enableAutoLead ~= false)

    if self.leadHeader then self.leadHeader:SetHidden(not isAutoLeadEnabled) end
    if self.kickerLabel then self.kickerLabel:SetHidden(not isAutoLeadEnabled) end
    if self.kickerControl then self.kickerControl:SetHidden(not isAutoLeadEnabled) end
    if self.leadLabel then self.leadLabel:SetHidden(not isAutoLeadEnabled) end
    if self.leadControl then self.leadControl:SetHidden(not isAutoLeadEnabled) end

    if self.profilesHeader then
        self.profilesHeader:ClearAnchors()
        if isAutoLeadEnabled then
            self.profilesHeader:SetAnchor(TOPLEFT, self.ui, TOPLEFT, 15, 510)
            self.ui:SetHeight(650)
        else
            self.profilesHeader:SetAnchor(TOPLEFT, self.ui, TOPLEFT, 15, 400)
            self.ui:SetHeight(540)
        end
    end

    local isLeader = IsUnitGrouped("player") and IsUnitGroupLeader("player")
    if self.kickBtn then
        self.kickBtn:SetEnabled(isLeader and not self.isProcessing)
    end

    local isGrouped = IsUnitGrouped("player")
    local groupSize = isGrouped and GetGroupSize() or 1
    local myZoneId = GetUnitZoneIndex("player")
    local members = _refreshMembers

    for i = 1, groupSize do
        local tag = isGrouped and GetGroupUnitTagByIndex(i) or "player"
        local displayName = GetUnitDisplayName(tag)
        local role = GetGroupMemberSelectedRole(tag)
        local unitZoneId = GetUnitZoneIndex(tag)
        local roleWeight = 3

        if role == LFG_ROLE_TANK then
            roleWeight = 1
        elseif role == LFG_ROLE_HEAL then
            roleWeight = 2
        elseif role == LFG_ROLE_DPS then
            roleWeight = 3
        end

        local isSelf = AreUnitsEqual(tag, "player") or (displayName and string.lower(displayName) == self.myDisplayNameLower)

        local member = members[i]
        if not member then
            member = {}
            members[i] = member
        end
        member.tag = tag
        member.displayName = displayName
        member.role = role
        member.roleWeight = roleWeight
        member.inMyZone = (unitZoneId == myZoneId)
        member.isOnline = IsUnitOnline(tag)
        member.isSelf = isSelf
    end

    for j = groupSize + 1, #members do
        members[j] = nil
    end

    table.sort(members, SortGroupMembers)

    if isAutoLeadEnabled then
        self:PopulateLeadKickerDropdowns(members)
    end

    for i = 1, 12 do
        local row = self.rows[i]
        local member = members[i]

        if row and row.cb and row.nameLabel and row.role and row.zoneIcon then
            if member then
                row.displayName = member.displayName
                row.isSelf = member.isSelf
                row.nameLabel:SetText(member.displayName or "")

                if member.isSelf then
                    row.cb:SetEnabled(false)
                    row.cb.checked = false
                    row.cb:SetNormalTexture("esoui/art/buttons/checkbox_disabled.dds")
                    row.cb:SetMouseOverTexture("esoui/art/buttons/checkbox_disabled.dds")
                    row.nameLabel:SetColor(0.5, 0.5, 0.5, 1)
                    if member.displayName then
                        self.selectedPlayers[member.displayName] = false
                    end
                else
                    row.cb:SetEnabled(not self.isProcessing)
                    row.nameLabel:SetColor(1, 1, 1, 1)
                    local isChecked = (member.displayName and self.selectedPlayers[member.displayName]) or false
                    row.cb.checked = isChecked
                    if isChecked then
                        row.cb:SetNormalTexture("esoui/art/buttons/checkbox_checked.dds")
                        row.cb:SetMouseOverTexture("esoui/art/buttons/checkbox_checked_mouseover.dds")
                    else
                        row.cb:SetNormalTexture("esoui/art/buttons/checkbox_unchecked.dds")
                        row.cb:SetMouseOverTexture("esoui/art/buttons/checkbox_mouseover.dds")
                    end
                end

                if member.role == LFG_ROLE_TANK then
                    row.role:SetTexture("esoui/art/lfg/lfg_tank_down.dds")
                    if member.isOnline then
                        row.role:SetColor(1, 0.2, 0.2, 1)
                    else
                        RestoreRoleColor(row)
                    end
                elseif member.role == LFG_ROLE_HEAL then
                    row.role:SetTexture("esoui/art/lfg/lfg_healer_down.dds")
                    if member.isOnline then
                        row.role:SetColor(0.2, 0.6, 1, 1)
                    else
                        RestoreRoleColor(row)
                    end
                elseif member.role == LFG_ROLE_DPS then
                    row.role:SetTexture("esoui/art/lfg/lfg_dps_down.dds")
                    if member.isOnline then
                        row.role:SetColor(0.2, 1, 0.2, 1)
                    else
                        RestoreRoleColor(row)
                    end
                else
                    row.role:SetTexture("esoui/art/lfg/lfg_dps_down.dds")
                    RestoreRoleColor(row)
                end

                if member.inMyZone then
                    row.zoneIcon:SetTexture("esoui/art/buttons/accept_up.dds")
                    row.zoneIcon:SetColor(0.2, 1, 0.2, 1)
                else
                    row.zoneIcon:SetTexture("esoui/art/buttons/decline_up.dds")
                    row.zoneIcon:SetColor(1, 0.2, 0.2, 1)
                end

                row.zoneIcon:SetHidden(false)
                row:SetHidden(false)
            else
                row:SetHidden(true)
                row.displayName = nil
                row.isSelf = false
            end
        end
    end
end

function KRT.KWS:ExecuteInvites()
    if self.inviteTimeoutTimer then
        zo_removeCallLater(self.inviteTimeoutTimer)
        self.inviteTimeoutTimer = nil
    end

    if self.pendingInvites and #self.pendingInvites > 0 then
        for _, name in ipairs(self.pendingInvites) do
            if name and name ~= "" then
                GroupInviteByName(name)
            end
        end
        Notice("Re-invited " .. #self.pendingInvites .. " players.")
    end

    self.pendingInvites = {}
    self.pendingKicksCount = 0
    self.isProcessing = false
    self:RefreshRows()
end

function KRT.KWS:KickAndReinvite()
    if self.isProcessing then
        return
    end

    local sv = SV()
    if not (IsUnitGrouped("player") and IsUnitGroupLeader("player")) then
        d("[Kwibus Spaulder] You must be the group leader to kick players!")
        return
    end

    local groupSize = GetGroupSize() or 0

    -- Arm auto lead workflow if configured (only for raid groups > 6 players)
    if sv and sv.enabled and sv.enableAutoLead and IsLocalPlayerConfiguredKicker() then
        if groupSize > 6 then
            if (kalState.preKickGroupSize or 0) <= 6 then
                kalState.preKickGroupSize = groupSize
            end
            ArmPhase(1, kalState.preKickGroupSize, groupSize)
            StartPolling(PollWorkflow)
        end
    end

    self.isProcessing = true
    self.pendingInvites = {}
    self.pendingKicksCount = 0

    if self.kickBtn then
        self.kickBtn:SetEnabled(false)
    end

    for i = 1, groupSize do
        local tag = GetGroupUnitTagByIndex(i)
        if tag then
            local displayName = GetUnitDisplayName(tag)

            if displayName and self.selectedPlayers[displayName] and not AreUnitsEqual(tag, "player") then
                table.insert(self.pendingInvites, displayName)
                GroupKick(tag)
                self.pendingKicksCount = self.pendingKicksCount + 1
            end
        end
    end

    if self.pendingKicksCount > 0 then
        if self.inviteTimeoutTimer then
            zo_removeCallLater(self.inviteTimeoutTimer)
        end

        self.inviteTimeoutTimer = zo_callLater(function()
            if self.pendingKicksCount > 0 then
                d("[Kwibus Spaulder] Kick confirmation timeout reached. Forcing invites.")
                self:ExecuteInvites()
            end
        end, 3000)
    else
        self.isProcessing = false
        self:RefreshRows()
    end
end

function KRT.KWS:ToggleFragment()
    local groupScene = SCENE_MANAGER and SCENE_MANAGER:GetScene("groupMenuKeyboard")
    if groupScene and self.fragment then
        local groupSize = IsUnitGrouped("player") and GetGroupSize() or 0
        local shouldShow = SV().enabled and (SV().debug or groupSize >= 5)

        if shouldShow then
            if not groupScene:HasFragment(self.fragment) then
                groupScene:AddFragment(self.fragment)
            end
        else
            if groupScene:HasFragment(self.fragment) then
                groupScene:RemoveFragment(self.fragment)
            end
        end
    end
end

function KRT.KWS:Initialize()
    local sv = MigrateSV()
    self.myDisplayNameLower = string.lower(GetDisplayName() or "")

    self.selectedLead = sv.actualLead or ""
    self.selectedKicker = sv.kickingPerson or ""
    self.selectedProfile = sv.lastProfile or ""

    ResetWorkflow()
    kalState.lastDifficultyKey = GetDifficultyKey()
    UpdateObservedGroupSize(GetGroupSize() or 0)

    RegisterOverwriteDialog()
    self:CreateUI()
    self:UpdateProfileDropdown()

    self.ui = _G["KwibusSpaulderUI"] or self.ui
    if not self.ui or not self.ui.SetHidden then
        d("[KWS] ERROR: KwibusSpaulderUI is not a valid UI control (missing SetHidden).")
        return
    end

    if not self.fragment then
        self.fragment = ZO_SimpleSceneFragment:New(self.ui)
        self.fragment:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_FRAGMENT_SHOWN or newState == SCENE_FRAGMENT_SHOWING then
                self:RefreshRows()
                self:UpdateProfileDropdown()
            end
        end)
    end

    self:ToggleFragment()

    local function OnGroupUpdate()
        if not SV().enabled then return end
        self:ToggleFragment()
        if self.ui and not self.ui:IsHidden() then
            self:RefreshRows()
        end
        if SV().enableAutoLead then
            CheckGroupState()
        end
    end

    local function OnGroupMemberLeft(eventCode, memberCharacterName, reason, isLocalPlayer, isLeader, memberDisplayName, actionRequiredVote)
        if not SV().enabled then return end
        OnGroupUpdate()

        if self.pendingKicksCount > 0 then
            for _, pendingName in ipairs(self.pendingInvites) do
                if pendingName and memberDisplayName and pendingName == memberDisplayName then
                    self.pendingKicksCount = self.pendingKicksCount - 1
                    break
                end
            end

            if self.pendingKicksCount <= 0 then
                zo_callLater(function()
                    self:ExecuteInvites()
                end, 2000)
            end
        end
    end

    EM:RegisterForEvent(ADDON_NAME .. "_KWSJoin", EVENT_GROUP_MEMBER_JOINED, OnGroupUpdate)
    EM:RegisterForEvent(ADDON_NAME .. "_KWSLeft", EVENT_GROUP_MEMBER_LEFT, OnGroupMemberLeft)
    EM:RegisterForEvent(ADDON_NAME .. "_KWSRole", EVENT_GROUP_MEMBER_ROLE_CHANGED, OnGroupUpdate)
    EM:RegisterForEvent(ADDON_NAME .. "_KWSLeader", EVENT_LEADER_UPDATE, OnGroupUpdate)

    EM:RegisterForEvent(ADDON_NAME .. "_KWS_Deactivated", EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
    EM:RegisterForEvent(ADDON_NAME .. "_KWS_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EM:RegisterForEvent(ADDON_NAME .. "_KWS_VetChanged", EVENT_VETERAN_DIFFICULTY_CHANGED, OnDifficultyChanged)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel and panel.GetName and panel:GetName() == ADDON_NAME .. "_Panel" then
            RebuildGroupRosterChoices()
        end
    end)

    RebuildGroupRosterChoices()

    zo_callLater(function()
        EnsureLocalKickerWorkflow()
    end, 1500)
end

function KRT.KWS:GetLAMSubmenu()
    return {
        type = "submenu",
        name = "Kwibus Spaulder",
        controls = {
            {
                type = "checkbox",
                name = "Enable Module",
                tooltip = "Master switch for the Spaulder kicking UI and automated lead passing.",
                getFunc = function()
                    local sv = SV()
                    if sv.enabled == nil then return true else return sv.enabled end
                end,
                setFunc = function(value)
                    SV().enabled = value
                    self:ToggleFragment()
                    if not value then
                        ResetWorkflow()
                        if self.inviteTimeoutTimer then
                            zo_removeCallLater(self.inviteTimeoutTimer)
                            self.inviteTimeoutTimer = nil
                        end
                        self.pendingInvites = {}
                        self.pendingKicksCount = 0
                        self.isProcessing = false
                        if self.ui then
                            self.ui:SetHidden(true)
                        end
                    else
                        EnsureLocalKickerWorkflow()
                    end
                    self:RefreshRows()
                end,
                width = "full",
            },
            {
                type = "checkbox",
                name = "Enable Auto Lead Passing",
                tooltip = "Automatically passes lead to the kicker upon instance reset, and returns lead to actual lead once group is rebuilt.",
                getFunc = function()
                    local sv = SV()
                    if sv.enableAutoLead == nil then return true else return sv.enableAutoLead end
                end,
                setFunc = function(value)
                    SV().enableAutoLead = value
                    if not value then
                        ResetWorkflow()
                    else
                        EnsureLocalKickerWorkflow()
                    end
                    self:RefreshRows()
                end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Enable Chat Notifications",
                tooltip = "Show lead-pass and re-invite messages in chat.",
                getFunc = function()
                    local sv = SV()
                    if sv.enableChat == nil then return true else return sv.enableChat end
                end,
                setFunc = function(value)
                    SV().enableChat = value
                end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "dropdown",
                name = "Kicking Person (Pick from group or saved)",
                tooltip = "Who should receive lead after difficulty changes? Saves AccountName.",
                choices = KWSChoices,
                choicesValues = KWSValues,
                getFunc = function()
                    return SV().kickingPerson or ""
                end,
                setFunc = function(value)
                    if value and value ~= "" then
                        SV().kickingPerson = value
                        self.selectedKicker = value
                        RememberAccount(value)
                        RebuildGroupRosterChoices()
                        EnsureLocalKickerWorkflow()
                        self:RefreshRows()
                    end
                end,
                reference = "KRT_KWS_Kicker_Dropdown",
                width = "full",
                disabled = function()
                    return not SV().enabled or not SV().enableAutoLead
                end,
            },
            {
                type = "slider",
                name = "Delay: Pass to Kicker",
                tooltip = "Seconds to wait after difficulty change before passing lead to the kicker.",
                min = 1,
                max = 10,
                step = 1,
                getFunc = function()
                    return SV().kickDelay or 2
                end,
                setFunc = function(value)
                    SV().kickDelay = value
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled or not SV().enableAutoLead
                end,
            },
            {
                type = "dropdown",
                name = "Actual Lead (Pick from group or saved)",
                tooltip = "Who should receive lead back after reinvites/rebuild? Saves AccountName.",
                choices = KWSChoices,
                choicesValues = KWSValues,
                getFunc = function()
                    return SV().actualLead or ""
                end,
                setFunc = function(value)
                    if value and value ~= "" then
                        SV().actualLead = value
                        self.selectedLead = value
                        RememberAccount(value)
                        RebuildGroupRosterChoices()
                        EnsureLocalKickerWorkflow()
                        self:RefreshRows()
                    end
                end,
                reference = "KRT_KWS_Lead_Dropdown",
                width = "full",
                disabled = function()
                    return not SV().enabled or not SV().enableAutoLead
                end,
            },
            {
                type = "slider",
                name = "Delay: Return to Lead",
                tooltip = "Seconds to wait after rebuild before returning lead.",
                min = 1,
                max = 10,
                step = 1,
                getFunc = function()
                    return SV().returnDelay or 2
                end,
                setFunc = function(value)
                    SV().returnDelay = value
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled or not SV().enableAutoLead
                end,
            },
            {
                type = "button",
                name = "Reset Horizontal Position",
                func = function()
                    if KRT.KWS.ui then
                        local rootW = GuiRoot:GetWidth()
                        local w = KRT.KWS.ui:GetWidth()
                        SV().offsetX = (rootW - w) / 2
                        KRT.KWS.ui:ClearAnchors()
                        KRT.KWS.ui:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV().offsetX, SV().offsetY or 150)
                    end
                end,
                width = "half",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "button",
                name = "Reset Vertical Position",
                func = function()
                    if KRT.KWS.ui then
                        local rootH = GuiRoot:GetHeight()
                        local h = KRT.KWS.ui:GetHeight()
                        SV().offsetY = (rootH - h) / 2
                        KRT.KWS.ui:ClearAnchors()
                        KRT.KWS.ui:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV().offsetX or 150, SV().offsetY)
                    end
                end,
                width = "half",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "checkbox",
                name = "Enable Debug Mode (Force UI Visible)",
                tooltip = "Force UI overlay to show in group menu regardless of group status or group size.",
                getFunc = function()
                    return SV().debug or false
                end,
                setFunc = function(value)
                    SV().debug = value
                    self:ToggleFragment()
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "description",
                text = "Both kicking player and actual lead need to have addon installed. When instance difficulty is reset, lead is auto-passed to the kicking player. Once the spaulder kicks and reinvites are complete and the group is full, lead is automatically returned to the actual lead.",
                width = "full",
            },
        }
    }
end

KRT:RegisterModule(KRT.KWS)