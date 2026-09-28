-- Settings panel (LibHarvensAddonSettings). A live preview at the top, then everything on one page,
-- except the titles to rotate: the last entry opens a list of the character's titles, each with
-- its own on/off switch. On console a dropdown is a left/right selector that picks on every move,
-- so a list of titles to add or remove can't be a dropdown.
local FT = Flexatron
local L = FT.L
local Settings = {}
FT.Settings = Settings

local LIST_SETTLE_MS = 2000 -- after switching titles on or off, before the title changes
local EMOTE_EVERY = { 0, 30, 60, 120, 300, -1 } -- the "how often" choices, in seconds
local PREVIEW_MS = 1000     -- how often the preview updates while it's on screen
local PREVIEW_LIST_CHARS = 40 -- titles named at the top, so its text keeps a readable size
local CURRENT_COLOR = "FFD700"
local SETTINGS_SCENE = "LibHarvensAddonSettingsScene"
local CHECK_ICON = "EsoUI/Art/Miscellaneous/check_icon_32.dds" -- the game's check mark

local LHAS
local listed = {}   -- [title name] = true for titles that have a switch in the list
local preview = {}  -- the preview's rows
local pickRows = {} -- the quick picks' rows
local panelText     -- the rotation as last put in the info panel, while the preview is selected

-- Shows changed values in the panel. On console the library builds its screen the first time the
-- main menu opens, and refreshing before then is an error, so wait until it exists.
function Settings.Refresh()
    if Settings.panel and LHAS and LHAS.scrollList then
        Settings.panel:UpdateControls()
    end
end

-- Redraws these rows if they're on screen. The library drops a row's control when it scrolls away
-- or the page changes, so this costs nothing the rest of the time.
local function UpdateRows(settingRows)
    for _, row in ipairs(settingRows) do
        if row.UpdateControl then
            row:UpdateControl()
        end
    end
end

-- Every row is centred except the preview at the top, which is drawn on the left. Label and button
-- rows share their controls with each other and with other add-ons' pages, so Flexatron's set their
-- alignment each time they're drawn, and a control left on the left is centred again when another
-- page opens.
local leftAligned = {} -- [label control] = true while set to the left

local function Aligned(alignment, text)
    return function(setting)
        local control = setting and setting.control
        local label = control and (control.label or control:GetNamedChild("Name"))
        if label then
            label:SetHorizontalAlignment(alignment)
            leftAligned[label] = alignment == TEXT_ALIGN_LEFT or nil
        end
        if type(text) == "function" then
            return text()
        end
        return text
    end
end

local function Left(text)
    return Aligned(TEXT_ALIGN_LEFT, text)
end

local function Centred(text)
    return Aligned(TEXT_ALIGN_CENTER, text)
end

local function OnPageOpened(_, panel)
    if panel ~= Settings.panel then
        for label in pairs(leftAligned) do
            label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        end
        leftAligned = {}
    end
end

local function Toggle(label, tooltip, key, onChange)
    return {
        type = LHAS.ST_CHECKBOX,
        label = label,
        tooltip = tooltip,
        default = FT.defaults[key],
        getFunction = function() return FT.sv[key] end,
        setFunction = function(value)
            FT.sv[key] = value
            if onChange then
                onChange()
            end
        end,
    }
end

-- A value picker: items are { name, data }; getName returns the name to show, and onPick gets the
-- picked item's data. The library passes the whole picked item, not its data; if it ever passes
-- something without our data, the item is found again by name.
local function Dropdown(label, tooltip, items, getName, onPick, disable)
    return {
        type = LHAS.ST_DROPDOWN,
        label = label,
        tooltip = tooltip,
        items = items,
        getFunction = getName,
        setFunction = function(_, name, item)
            if type(item) == "table" and item.data ~= nil then
                return onPick(item.data)
            end
            for _, entry in ipairs(type(items) == "function" and items() or items) do
                if entry.name == name then
                    return onPick(entry.data)
                end
            end
        end,
        disable = disable,
    }
end

-- A "how often" choice as the player reads it.
local function EveryName(seconds)
    if seconds == 0 then
        return L.EMOTE_EVERY_CHANGE
    elseif seconds < 0 then
        return L.EMOTE_EVERY_NEW
    elseif seconds == 60 then
        return L.EMOTE_EVERY_MINUTE
    elseif seconds % 60 == 0 then
        return string.format(L.EMOTE_EVERY_MINUTES, seconds / 60)
    end
    return string.format(L.EMOTE_EVERY_SECONDS, seconds)
end

local function InRotation(name)
    for _, listedName in ipairs(FT.sv.titles) do
        if listedName == name then
            return true
        end
    end
    return false
end

local function SetInRotation(name, on)
    local titles = FT.sv.titles
    for i = #titles, 1, -1 do
        if titles[i] == name then
            table.remove(titles, i)
        end
    end
    if on then
        titles[#titles + 1] = name
    end
    FT.Rotation.Resume(LIST_SETTLE_MS)
    UpdateRows(pickRows) -- the quick pick in use may have changed
end

-- ---- Quick picks: set the rotation to a kind of title in one press. The one in use is checked.

local QUICK_PICKS = {
    { id = "trifectas", label = L.PICK_TRIFECTAS, tooltip = L.PICK_DETECTED,
      wants = function(name) return FT.TitleIndex.KindOf(name) == "trifecta" end },
    { id = "hard", label = L.PICK_HARD, tooltip = L.PICK_DETECTED,
      wants = function(name) return FT.TitleIndex.KindOf(name) ~= nil end },
    { id = "all", label = L.PICK_ALL, tooltip = L.PICK_REPLACES, wants = function() return true end },
    { id = "none", label = L.PICK_NONE, wants = function() return false end, uncounted = true },
}

-- This character's titles a quick pick would switch on.
local function Picked(wants)
    local names = {}
    for _, title in ipairs(FT.Titles.GetOwned()) do
        if wants(title.name) then
            names[#names + 1] = title.name
        end
    end
    return names
end

-- This character's titles that are switched on, as [name] = true, and how many. A saved name
-- matches like Titles.IndexOf: as it is, or as the player reads it.
local function SwitchedOn()
    local byName, byDisplay = {}, {}
    for _, title in ipairs(FT.Titles.GetOwned()) do
        byName[title.name] = true
        byDisplay[FT.Titles.Format(title.name)] = title.name
    end
    local on, count = {}, 0
    for _, name in ipairs(FT.sv.titles) do
        local owned = byName[name] and name or byDisplay[FT.Titles.Format(name)]
        if owned and not on[owned] then
            on[owned] = true
            count = count + 1
        end
    end
    return on, count
end

-- Whether a pick would switch on exactly the titles that are on. With nothing on, only
-- "Switch all off" does: a pick with no titles of its kind isn't in use.
local function Matches(pick, on, count)
    if count == 0 then
        return pick.id == "none"
    end
    local names = Picked(pick.wants)
    if #names ~= count then
        return false
    end
    for _, name in ipairs(names) do
        if not on[name] then
            return false
        end
    end
    return true
end

-- The quick pick in use, or nil. When two picks switch on the same titles, the one pressed last.
local function PickInUse()
    local on, count = SwitchedOn()
    local found
    for _, pick in ipairs(QUICK_PICKS) do
        if Matches(pick, on, count) then
            if pick.id == FT.sv.quickPick then
                return pick
            end
            found = found or pick
        end
    end
    return found
end

local function PickLabel(pick)
    local text = pick.uncounted and pick.label or string.format(pick.label, #Picked(pick.wants))
    if PickInUse() == pick then
        return zo_iconFormat(CHECK_ICON, "100%", "100%") .. " " .. text
    end
    return text
end

-- Switches on exactly the picked titles, in alphabetical order. Titles this character doesn't own
-- stay as they are, so another character's picks survive (the list is account-wide).
local function ApplyPick(pick)
    local titles = {}
    for _, name in ipairs(FT.sv.titles) do
        if not FT.Titles.IndexOf(name) then
            titles[#titles + 1] = name
        end
    end
    local picked = Picked(pick.wants)
    table.sort(picked, function(a, b) return FT.Titles.Format(a) < FT.Titles.Format(b) end)
    for _, name in ipairs(picked) do
        titles[#titles + 1] = name
    end
    FT.sv.titles = titles
    FT.sv.quickPick = pick.id
    FT.Rotation.Resume(LIST_SETTLE_MS)
    Settings.Refresh()
end

local function AddQuickPicks(panel)
    for _, pick in ipairs(QUICK_PICKS) do
        pickRows[#pickRows + 1] = panel:AddSetting({
            type = LHAS.ST_BUTTON,
            label = Centred(function() return PickLabel(pick) end),
            buttonText = L.PICK_BUTTON,
            tooltip = pick.tooltip,
            clickHandler = function() ApplyPick(pick) end,
        })
    end
end

-- How many of this character's titles are switched on.
local function CountOn()
    local _, count = SwitchedOn()
    return count
end

local function TitleSwitch(name)
    listed[name] = true
    return {
        type = LHAS.ST_CHECKBOX,
        label = FT.Titles.Format(name),
        default = false,
        getFunction = function() return InRotation(name) end,
        setFunction = function(value) SetInRotation(name, value) end,
    }
end

-- ---- The live preview: what's worn now, what comes next, and the rotation in order.

local function TitleName(index)
    return index and FT.Titles.Format(GetTitle(index)) or L.PREVIEW_NO_TITLE
end

local function NowText()
    return string.format(L.PREVIEW_NOW, TitleName(GetCurrentTitleIndex()))
end

local function StatusText()
    local status = FT.Rotation.Status()
    local kind = status.kind
    if kind == "new" then
        local seconds = math.ceil(status.endsInMs / 1000)
        return string.format(L.PREVIEW_NEW, math.floor(seconds / 60), seconds % 60)
    elseif kind == "paused" then
        return L.PREVIEW_PAUSED
    elseif kind == "best" then
        return string.format(L.PREVIEW_BEST, GetUnitZone("player"))
    elseif kind == "off" then
        return L.PREVIEW_OFF
    elseif kind == "empty" or not status.nextIndex then
        return L.PREVIEW_EMPTY
    elseif status.swapping then
        return L.PREVIEW_CHANGING
    elseif status.combat then
        return L.PREVIEW_COMBAT
    elseif status.nextIndex == GetCurrentTitleIndex() then
        return L.PREVIEW_ONE
    elseif status.nextInMs then
        return string.format(L.PREVIEW_NEXT, TitleName(status.nextIndex), math.ceil(status.nextInMs / 1000))
    end
    return string.format(L.PREVIEW_NEXT_SOON, TitleName(status.nextIndex))
end

-- This character's titles in the rotation, in order, as the player reads them; the one worn in gold.
local function RotationNames()
    local current, names = GetCurrentTitleIndex(), {}
    for _, name in ipairs(FT.sv.titles) do
        local index = FT.Titles.IndexOf(name)
        if index then
            local text = FT.Titles.Format(name)
            local shown = index == current and ("|c" .. CURRENT_COLOR .. text .. "|r") or text
            names[#names + 1] = { text = text, shown = shown }
        end
    end
    return names
end

-- The rotation at the top: as many titles as fit, then how many more. The library shrinks a row's
-- text to fit more lines, so a long list there would come out tiny; the info panel has them all.
local function RotationText()
    local names = RotationNames()
    if #names == 0 then
        return L.PREVIEW_LIST_NONE
    end
    local shown, length = {}, 0
    for i, name in ipairs(names) do
        length = length + #name.text + (i > 1 and 2 or 0)
        if i > 1 and length > PREVIEW_LIST_CHARS then
            break
        end
        shown[i] = name.shown
    end
    local text = string.format(L.PREVIEW_LIST, table.concat(shown, ", "))
    if #shown < #names then
        text = string.format(L.PREVIEW_MORE, text, #names - #shown)
    end
    return text
end

-- The whole rotation, one title per line, for the info panel beside the list.
local function RotationPanelText()
    local names = RotationNames()
    if #names == 0 then
        return L.PREVIEW_LIST_NONE
    end
    local lines = { string.format(L.PANEL_LIST, #names) }
    for _, name in ipairs(names) do
        lines[#lines + 1] = name.shown
    end
    return table.concat(lines, "\n")
end

-- The library shows the selected row's tooltip in the info panel, laid out when the row is
-- selected. While the preview is selected, lay the rotation out again whenever it changes (a title
-- comes up, the list changes), keeping where the player has scrolled to.
local function UpdatePanel()
    local list = LHAS.list
    local selected = list and list.GetSelectedData and list:GetSelectedData()
    if not selected or selected ~= preview[1] or not SCENE_MANAGER:IsShowing(SETTINGS_SCENE) then
        panelText = nil
        return
    end
    local text = RotationPanelText()
    if text ~= panelText then
        panelText = text
        GAMEPAD_TOOLTIPS:SetTooltipResetScrollOnClear(GAMEPAD_LEFT_TOOLTIP, false)
        GAMEPAD_TOOLTIPS:LayoutSettingTooltip(GAMEPAD_LEFT_TOOLTIP, text, "")
        GAMEPAD_TOOLTIPS:SetTooltipResetScrollOnClear(GAMEPAD_LEFT_TOOLTIP, true)
    end
end

local function UpdatePreview()
    UpdateRows(preview)
    UpdatePanel()
end

-- One row, three lines. The list keeps the selected row at a fixed height and draws the rows
-- above it upwards, under the header's fade, so the preview is selectable: the page opens on it,
-- with the whole rotation in the info panel.
local function AddPreview(panel)
    preview[#preview + 1] = panel:AddSetting({
        type = LHAS.ST_LABEL,
        label = Left(function() return NowText() .. "\n" .. StatusText() .. "\n" .. RotationText() end),
        tooltip = RotationPanelText,
        canSelect = true,
    })
end

local function ByDisplayName(a, b)
    return FT.Titles.Format(a.name) < FT.Titles.Format(b.name)
end

-- Titles not in the list yet go at the end of it, sorted among themselves: ones earned this session
-- until the next login sorts them in, or all of them if the titles hadn't loaded when the panel was
-- built.
local function AddNewTitles()
    if not Settings.panel then
        return
    end
    local new = {}
    for _, title in ipairs(FT.Titles.GetOwned()) do
        if not listed[title.name] then
            new[#new + 1] = title
        end
    end
    table.sort(new, ByDisplayName)
    for _, title in ipairs(new) do
        Settings.panel:AddSetting(TitleSwitch(title.name))
    end
end

local function AddOptions(panel)
    panel:AddSetting(Toggle(L.ROTATE_LABEL, L.ROTATE_TOOLTIP, "rotate", function() FT.Rotation.Resume() end))
    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = L.HOLD_LABEL,
        min = 3,
        max = 30,
        step = 1,
        format = "%d",
        unit = L.UNIT_SECONDS,
        default = FT.defaults.holdTime,
        getFunction = function() return FT.sv.holdTime end,
        setFunction = function(value) FT.sv.holdTime = value end,
        disable = function() return not FT.sv.rotate end,
    })
    panel:AddSetting(Toggle(L.AUTO_LABEL, nil, "autoMode", function() FT.Rotation.Resume() end))
    panel:AddSetting(Toggle(L.CELEBRATE_LABEL, L.CELEBRATE_TOOLTIP, "celebrate"))
    panel:AddSetting(Dropdown(L.EMOTE_LABEL, nil, function()
        local items = { { name = L.EMOTE_OFF, data = 0 } }
        for _, emote in ipairs(FT.Emote.Choices()) do
            items[#items + 1] = { name = emote.name, data = emote.id }
        end
        return items
    end, function()
        for _, emote in ipairs(FT.Emote.Choices()) do
            if emote.id == FT.sv.emoteId then
                return emote.name
            end
        end
        return L.EMOTE_OFF
    end, function(id)
        FT.sv.emoteId = id
    end))
    panel:AddSetting(Dropdown(L.EMOTE_EVERY_LABEL, L.EMOTE_EVERY_TOOLTIP, function()
        local items = {}
        for _, seconds in ipairs(EMOTE_EVERY) do
            items[#items + 1] = { name = EveryName(seconds), data = seconds }
        end
        return items
    end, function() return EveryName(FT.sv.emoteEvery) end, function(seconds)
        FT.sv.emoteEvery = seconds
    end, function() return FT.sv.emoteId == 0 end))
    panel:AddSetting(Toggle(L.ENVY_LABEL, L.ENVY_TOOLTIP, "titleEnvy", function() FT.TitleIndex.Warm() end))
    panel:AddSetting({
        type = LHAS.ST_BUTTON,
        label = Centred(L.NEXT_LABEL),
        buttonText = L.NEXT_BUTTON,
        clickHandler = function()
            FT.NextTitles.Show()
            Settings.Refresh()
        end,
    })
    panel:AddSetting({ type = LHAS.ST_LABEL, label = Centred(function() return FT.NextTitles.Text() end) })
end

-- The last entry: opens the list of titles. Everything after it belongs to that list.
local function AddTitleList(panel)
    panel:AddSetting({
        type = LHAS.ST_SECTION,
        label = function() return string.format(L.TITLES_SECTION, CountOn()) end,
    })
    AddQuickPicks(panel)
    AddNewTitles()
end

-- Built on the first loading screen, once the character's titles are known.
function Settings.Init()
    LHAS = LibHarvensAddonSettings
    if not LHAS then
        CHAT_ROUTER:AddSystemMessage(L.NO_SETTINGS_LIB)
        return
    end
    local panel = LHAS:AddAddon("Flexatron", { allowDefaults = true, allowRefresh = true })
    Settings.panel = panel
    AddPreview(panel)
    AddOptions(panel)
    AddTitleList(panel)
    EVENT_MANAGER:RegisterForEvent(FT.name .. "Settings", EVENT_PLAYER_TITLES_UPDATE, AddNewTitles)
    EVENT_MANAGER:RegisterForUpdate(FT.name .. "Preview", PREVIEW_MS, UpdatePreview)
    CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", OnPageOpened)
end
