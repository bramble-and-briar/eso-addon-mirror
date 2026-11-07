local CB = ERUI_CustomBuffs

local FILTER_SECTIONS = {
    {
        id = "Buff",
        header = "Filter: Buffs",
        label = "Buff",
        labelPlural = "Buffs",
        showAllKey = "showAllBuffs",
        listKey = "buffWhitelist",
        recentKey = "recentBuffs",
        showAllTooltip = "When enabled, every buff is shown (just like the default UI). When disabled, only buffs from the whitelist below are shown.",
        recentTooltip = "Pick any buff that has recently been on you this session, then press Apply to add it to the whitelist.",
    },
    {
        id = "Debuff",
        header = "Filter: Debuffs on Player",
        label = "Debuff on Player",
        labelPlural = "Debuffs on Player",
        showAllKey = "showAllDebuffs",
        listKey = "debuffWhitelist",
        recentKey = "recentDebuffs",
        showAllTooltip = "When enabled, every debuff on you is shown. When disabled, only debuffs from the whitelist below are shown.",
        recentTooltip = "Pick any debuff that has recently been on you this session, then press Apply to add it to the whitelist.",
    },
    {
        id = "TargetDebuff",
        header = "Filter: Debuffs on Boss",
        label = "Debuff on Boss",
        labelPlural = "Debuffs on Boss",
        showAllKey = "showAllTargetDebuffs",
        listKey = "targetDebuffWhitelist",
        recentKey = "recentTargetDebuffs",
        showAllTooltip = "When enabled, every debuff on the boss you are targeting is shown. When disabled, only debuffs from the whitelist below are shown.",
        recentTooltip = "Pick any debuff that has recently been on anything you targeted this session, then press Apply to add it to the whitelist.",
    },
}

for _, s in ipairs(FILTER_SECTIONS) do
    s.pendingText = ""
    s.pendingRecent = nil
    s.selected = nil
    s.listChoices = {}
    s.recentChoices = {}
end

local function Ref(s, kind)
    return "ERUI_CB_" .. s.id .. kind
end

local function GetRef(s, kind)
    return _G[Ref(s, kind)]
end

local function AddToWhitelist(tableRef, rawInput)
    if not rawInput or rawInput == "" then return end

    local bracketID = string.match(rawInput, "^%[(%d+)%]")
    if bracketID then
        rawInput = bracketID
    end

    local numID = tonumber(rawInput)
    if numID then
        local name = DoesAbilityExist(numID) and CB.FormatName(GetAbilityName(numID)) or "Unknown"
        tableRef[numID] = string.format("[%d] %s", numID, name)
    else
        local cleanName = CB.FormatName(rawInput)
        tableRef[cleanName] = cleanName
    end
end

local function RemoveFromWhitelist(tableRef, displayStr)
    if not displayStr then return end
    for k, v in pairs(tableRef) do
        if v == displayStr then
            tableRef[k] = nil
            break
        end
    end
end

local function RebuildDropdownLists()
    for _, s in ipairs(FILTER_SECTIONS) do
        ZO_ClearNumericallyIndexedTable(s.listChoices)
        for _, displayStr in pairs(CB.db[s.listKey]) do
            table.insert(s.listChoices, displayStr)
        end
        table.sort(s.listChoices)

        ZO_ClearNumericallyIndexedTable(s.recentChoices)
        for id, name in pairs(CB[s.recentKey]) do
            table.insert(s.recentChoices, string.format("[%d] %s", id, name))
        end
        table.sort(s.recentChoices)
    end
end

local function RefreshUIControls()
    RebuildDropdownLists()
    for _, s in ipairs(FILTER_SECTIONS) do
        local edit = GetRef(s, "Editbox")
        if edit then
            edit:UpdateValue()
        end

        local recent = GetRef(s, "RecentDropdown")
        if recent then
            recent:UpdateChoices(s.recentChoices)
            recent:UpdateValue()
        end

        local list = GetRef(s, "ListDropdown")
        if list then
            list:UpdateChoices(s.listChoices)
            list:UpdateValue()
        end
    end
end

local function AlignEditboxToDropdown(editControl, dropdownControl)
    if not (editControl and editControl.container and dropdownControl and dropdownControl.combobox) then return end
    local container = editControl.container
    container:ClearAnchors()
    container:SetAnchor(RIGHT, editControl, RIGHT, 0, 0)
    container:SetWidth(dropdownControl.combobox:GetWidth())
end

local function ApplyLayoutFixes()
    for _, s in ipairs(FILTER_SECTIONS) do
        AlignEditboxToDropdown(GetRef(s, "Editbox"), GetRef(s, "RecentDropdown"))
    end
end

local function BuildFilterSection(s)
    local function isDisabled() return CB.db[s.showAllKey] end

    return {
        {
            type = "header",
            name = s.header,
        },
        {
            type = "checkbox",
            name = "Show All " .. s.labelPlural,
            tooltip = s.showAllTooltip,
            getFunc = function() return CB.db[s.showAllKey] end,
            setFunc = function(v)
                CB.db[s.showAllKey] = v
                CB:RefreshAllAuras()
            end,
        },
        {
            type = "editbox",
            name = "Add " .. s.label .. " (ID or exact name)",
            reference = Ref(s, "Editbox"),
            isMultiline = false,
            getFunc = function() return s.pendingText end,
            setFunc = function(v) s.pendingText = v or "" end,
            disabled = isDisabled,
        },
        {
            type = "dropdown",
            name = "Quick Add from Recent " .. s.labelPlural,
            tooltip = s.recentTooltip,
            reference = Ref(s, "RecentDropdown"),
            choices = s.recentChoices,
            scrollable = true,
            getFunc = function() return s.pendingRecent or "" end,
            setFunc = function(v) s.pendingRecent = v end,
            disabled = isDisabled,
        },
        {
            type = "button",
            name = "Apply",
            tooltip = "Add the entered and/or selected entry to the whitelist.",
            func = function()
                AddToWhitelist(CB.db[s.listKey], s.pendingText)
                AddToWhitelist(CB.db[s.listKey], s.pendingRecent)
                s.pendingText = ""
                s.pendingRecent = nil
                CB:RefreshAllAuras()
                RefreshUIControls()
            end,
            disabled = function()
                local hasPending = (s.pendingText ~= "") or (s.pendingRecent ~= nil and s.pendingRecent ~= "")
                return isDisabled() or not hasPending
            end,
        },
        {
            type = "dropdown",
            name = "Whitelisted " .. s.labelPlural,
            reference = Ref(s, "ListDropdown"),
            choices = s.listChoices,
            scrollable = true,
            getFunc = function() return s.selected end,
            setFunc = function(v) s.selected = v end,
            disabled = isDisabled,
        },
        {
            type = "button",
            name = "Remove Selected",
            func = function()
                if not s.selected then return end
                RemoveFromWhitelist(CB.db[s.listKey], s.selected)
                s.selected = nil
                CB:RefreshAllAuras()
                RefreshUIControls()
            end,
            disabled = isDisabled,
        },
    }
end

local function BuildScoreSection()
    return {
        {
            type = "header",
            name = "Trial Score (Runes)",
        },
        {
            type = "dropdown",
            name = "Score Display",
            tooltip = "Raw: the trial score exactly as the game reports it.\nAdjusted: (score - 36000) × 3.\nHidden: the score is not shown.",
            choices = { "Raw", "Adjusted", "Hidden" },
            choicesValues = { 1, 2, 3 },
            getFunc = function() return ERUI_RunesScore.db.mode end,
            setFunc = function(v)
                ERUI_RunesScore.db.mode = v
                ERUI_RunesScore.ApplyMode()
            end,
        },
    }
end

local function AppendAll(target, controls)
    for _, control in ipairs(controls) do
        table.insert(target, control)
    end
end

function CB:InitializeSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panel = LAM:RegisterAddonPanel("ERUI_SettingsPanel", {
        type = "panel",
        name = "Elden Ring UI",
        displayName = "Elden Ring UI",
        author = "Geldis1306",
        registerForRefresh = true,
    })

    local optionsData = {}
    for _, s in ipairs(FILTER_SECTIONS) do
        AppendAll(optionsData, BuildFilterSection(s))
    end
    AppendAll(optionsData, BuildScoreSection())

    RebuildDropdownLists()
    LAM:RegisterOptionControls("ERUI_SettingsPanel", optionsData)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(createdPanel)
        if createdPanel == panel then
            ApplyLayoutFixes()
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(openedPanel)
        if openedPanel == panel then
            RefreshUIControls()
        end
    end)
end