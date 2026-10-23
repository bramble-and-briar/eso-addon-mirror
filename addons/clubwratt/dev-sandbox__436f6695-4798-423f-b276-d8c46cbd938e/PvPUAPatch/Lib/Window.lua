local L = PvPUAPatchLib
if not (L and L.IsSupported()) then return end

local S = {}
L.window = S

--------------------------------------------------
-- Config
--------------------------------------------------
local SCENE_PREFIX = "PvPUAPatchLib_"

local CATEGORY_TEMPLATE = "PvPUAPatchLib_WindowCategoryRow"
local ROW_TEMPLATE      = "PvPUAPatchLib_WindowRow"

local SELECT_DIALOG    = "PVPUAPATCHLIB_SELECT"
local CHECKLIST_DIALOG = "PVPUAPATCHLIB_CHECKLIST"
local TEXT_DIALOG      = "PVPUAPATCHLIB_TEXT"
local DEFAULTS_DIALOG  = "PVPUAPATCHLIB_DEFAULTS"
local CONFIRM_DIALOG   = "PVPUAPATCHLIB_CONFIRM"

local PANE_CATEGORIES = 1
local PANE_SETTINGS   = 2

local PANE_CENTER         = { 0.02, 0.02, 0.03, 0.70 }
local HEADER_EDGE         = { 1, 0.533, 0, 1 }
local ROW_CENTER          = { 0.08, 0.09, 0.11, 0.55 }
local DEFAULT_OPACITY     = 70

S.paneAlpha = PANE_CENTER[4]
S.rowAlpha  = ROW_CENTER[4]
local ROW_EDGE            = { 0.22, 0.24, 0.28, 0.6 }
local TRACK_CENTER        = { 0.12, 0.13, 0.15, 0.95 }
local TEXT_FOCUSED        = { 1, 1, 1, 1 }
local TEXT_NORMAL         = { 0.82, 0.85, 0.9, 1 }
local INACTIVE_EDGE_ALPHA = 0.7
local DETAILS_EDGE_ALPHA  = 1
local DISABLED_ALPHA      = 0.4

local NAME_WIDTH        = 470
local NAME_WIDTH_WIDE   = 820
local SLIDER_TRACK_W    = 240
local SLIDER_BIG_STEPS  = 10
local TEXT_MAX_CHARS    = 200
local CATEGORY_ROW_HEIGHT = 58
local SETTING_ROW_HEIGHT  = 62
local ROW_GAP             = 16
local REFRESH_THROTTLE_MS = 100
local REFRESH_UPDATE_NAME = "PvPUAPatchLib_WindowRefresh"

local FRAME_WIDTH          = 1792
local FRAME_TOP            = 34
local FRAME_SIDE_MARGIN    = 32
local FRAME_FOOTER_GAP     = 25
local PANE_TOP             = 124
local PANE_MIN_HEIGHT      = 560
local LIST_INSET           = 80

local CHECKED_ICON   = "EsoUI/Art/Buttons/Gamepad/gp_checkBox_downOver.dds"
local UNCHECKED_ICON = "EsoUI/Art/Buttons/Gamepad/gp_checkBox_upOver.dds"
local CURRENT_ICON   = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds"

local SUPPORTED = {
    toggle = true, slider = true, dropdown = true, selector = true, checklist = true,
    colorpicker = true, iconpicker = true, editbox = true, button = true, submenu = true,
    stylecolor = true, header = true,
}

local HORIZONTAL = { toggle = true, slider = true, selector = true, iconpicker = true, stylecolor = true }

local DETAILS_WIDTH      = 337
local DETAILS_ICON_SIZE  = 128
local SAMPLE_ICON_MIN    = 24
local SWATCH_ROW_OFFSET  = -34

local function AllianceColor(alliance)
    local c = GetAllianceColor(alliance)
    return { c.r, c.g, c.b }
end

local COLOR_DC = AllianceColor(ALLIANCE_DAGGERFALL_COVENANT)
local COLOR_AD = AllianceColor(ALLIANCE_ALDMERI_DOMINION)
local COLOR_EP = AllianceColor(ALLIANCE_EBONHEART_PACT)

local ACCENT = { 1, 1, 1 }

local DEFAULT_TEXT_SIZE = 27
local TEXT_SIZE_MIN     = 18
local TEXT_SIZE_MAX     = 44
local DETAILS_NAME_SIZE = 34
local DETAILS_BODY_SIZE = 25

S.fontSize = DEFAULT_TEXT_SIZE
S.fonts    = {}

local function GamepadFont(size)
    return "$(GAMEPAD_MEDIUM_FONT)|" .. tostring(size) .. "|soft-shadow-thick"
end

local function RefreshAccent()
    local custom = S.menu and S.menu.accentColor
    if type(custom) == "function" then
        local r, g, b = custom()
        if r and g and b then
            ACCENT[1], ACCENT[2], ACCENT[3] = r, g, b
            return
        end
    end
    local c = GetAllianceColor(GetUnitAlliance("player"))
    ACCENT[1], ACCENT[2], ACCENT[3] = c.r, c.g, c.b
end

--------------------------------------------------
-- State
--------------------------------------------------
S.panel         = nil
S.menu          = nil
S.categories    = {}
S.stack         = {}
S.pane          = PANE_CATEGORIES
S.categoryIndex = 1
S.raised        = {}
S.waitRelease   = false
S.keybindsAdded = false
S.inputActive   = false
S.registered    = false
S.valueVersion  = 1
S.pageEntries   = {}
S.rootPages     = {}
S.categoryEntries = {}
S.lastRefreshMs = 0
S.refreshPending = false
S.detailsOption = nil
S.keybindState  = {}

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function Resolve(value, ...)
    if type(value) == "function" then return value(...) end
    return value
end

local function ResolveText(value)
    local v = Resolve(value)
    if v == nil then return "" end
    if type(v) == "number" then return GetString(v) end
    return tostring(v)
end

local function IsDisabled(opt)
    return opt ~= nil and Resolve(opt.disabled) == true
end

local function GetValue(opt)
    if opt and type(opt.getFunc) == "function" then return opt.getFunc() end
    return nil
end

local function GetChoices(opt)
    local choices = Resolve(opt and opt.choices)
    if type(choices) ~= "table" then return {} end
    return choices
end

local function ChoiceValue(choice)
    if type(choice) == "table" then
        if choice.value ~= nil then return choice.value end
        return choice.name
    end
    return choice
end

local function ChoiceName(choice)
    if type(choice) == "table" then
        if choice.name ~= nil then return ResolveText(choice.name) end
        return tostring(choice.value)
    end
    return tostring(choice)
end

local function FindChoiceIndex(opt, value)
    local choices = GetChoices(opt)
    for i = 1, #choices do
        if ChoiceValue(choices[i]) == value then return i end
    end
    for i = 1, #choices do
        if ChoiceName(choices[i]) == value then return i end
    end
    return nil
end

local function IsCustomStyle(opt)
    return opt ~= nil and opt.type == "stylecolor" and GetValue(opt) == opt.customValue
end

local function GetStyleColor(opt)
    if opt and type(opt.getColor) == "function" then
        local r, g, b = opt.getColor()
        return r or 1, g or 1, b or 1
    end
    return 1, 1, 1
end

local function SelectedSet(opt)
    local set = {}
    local values = GetValue(opt)
    if type(values) == "table" then
        for _, v in ipairs(values) do set[v] = true end
    end
    return set
end

local function ToggleText(opt, value)
    if opt.preset == "YES_NO" then
        return GetString(value and SI_YES or SI_NO)
    end
    if opt.preset == "SHOW_HIDE" then
        return value and "Show" or "Hide"
    end
    return GetString(value and SI_CHECK_BUTTON_ON or SI_CHECK_BUTTON_OFF)
end

local function ChecklistText(opt)
    local set = SelectedSet(opt)
    local names = {}
    local choices = GetChoices(opt)
    for i = 1, #choices do
        if set[ChoiceValue(choices[i])] then names[#names + 1] = ChoiceName(choices[i]) end
    end
    if #names == 0 then return ResolveText(opt.noSelectionText or "None") end
    return table.concat(names, ", ")
end

local function SliderNumberText(opt, value)
    local step = opt.step or 1
    if step >= 1 and math.floor(step) == step then
        return tostring(math.floor((tonumber(value) or 0) + 0.5))
    end
    return string.format("%.2f", tonumber(value) or 0)
end

local function SliderStep(opt, value, steps)
    local min, max, step = opt.min or 0, opt.max or 100, opt.step or 1
    local v = (tonumber(value) or min) + steps * step
    if v < min then v = min end
    if v > max then v = max end
    v = min + math.floor((v - min) / step + 0.5) * step
    if v > max then v = max end
    return v
end

local function SetLabelColor(label, focused)
    local c = focused and TEXT_FOCUSED or TEXT_NORMAL
    label:SetColor(c[1], c[2], c[3], c[4])
end

local function ApplyRowBackdrop(bg, selected, active, color)
    if selected then
        bg:SetCenterColor(color[1] * 0.3, color[2] * 0.3, color[3] * 0.3, active and 0.85 or 0.6)
        bg:SetEdgeColor(color[1], color[2], color[3], active and 1 or 0.55)
    else
        bg:SetCenterColor(ROW_CENTER[1], ROW_CENTER[2], ROW_CENTER[3], S.rowAlpha)
        bg:SetEdgeColor(ROW_EDGE[1], ROW_EDGE[2], ROW_EDGE[3], ROW_EDGE[4])
    end
end

local function ApplyPane(control, color, edgeAlpha)
    if not control then return end
    control:SetCenterColor(PANE_CENTER[1], PANE_CENTER[2], PANE_CENTER[3], S.paneAlpha)
    control:SetEdgeColor(color[1], color[2], color[3], edgeAlpha)
end

local function ColorHex(color)
    return string.format("%02X%02X%02X",
        math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5),
        math.floor(color[3] * 255 + 0.5))
end

local function Tint(text, color)
    return "|c" .. ColorHex(color) .. text .. "|r"
end

--------------------------------------------------
-- Lists
--------------------------------------------------
local function SetReleasable(texture)
    if texture and texture.SetTextureReleaseOption and RELEASE_TEXTURE_AT_ZERO_REFERENCES then
        texture:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
    end
end

local function ReleaseTexture(texture)
    if texture then
        texture:SetTexture(nil)
        texture:SetHidden(true)
    end
end

local FixedList = {}
FixedList.__index = FixedList

function FixedList.New(control, template, rowHeight, rowGap, upArrow, downArrow)
    local list = setmetatable({}, FixedList)
    list.control = control
    list.template = template
    list.rowHeight = rowHeight
    list.rowGap = rowGap
    list.upArrow = upArrow
    list.downArrow = downArrow
    list.rows = {}
    list.entries = {}
    list.selectedIndex = 0
    list.firstIndex = 1
    list.visibleRows = 1
    list.active = false
    list.canSelect = nil
    return list
end

function FixedList:SetCanSelect(callback)
    self.canSelect = callback
end

function FixedList:IsSelectable(index)
    local data = self.entries[index]
    if data == nil then return false end
    if self.canSelect then return self.canSelect(data) == true end
    return true
end

function FixedList:FindSelectable(index, step)
    local count = #self.entries
    while index >= 1 and index <= count do
        if self:IsSelectable(index) then return index end
        index = index + step
    end
    return nil
end

function FixedList:SetSetup(setup)
    self.setup = setup
end

function FixedList:SetOnRowCreated(callback)
    self.onRowCreated = callback
end

function FixedList:SetOnSelectedDataChangedCallback(callback)
    self.onSelected = callback
end

function FixedList:EnsureRow(index)
    local row = self.rows[index]
    if row then return row end
    row = WINDOW_MANAGER:CreateControlFromVirtual(self.control:GetName() .. "Row" .. index, self.control, self.template)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, self.control, TOPLEFT, 0, (index - 1) * (self.rowHeight + self.rowGap))
    row:SetHidden(true)
    if self.onRowCreated then self.onRowCreated(row) end
    self.rows[index] = row
    return row
end

function FixedList:SetHeight(height)
    self.control:SetHeight(height)
    local count = math.floor((height + self.rowGap) / (self.rowHeight + self.rowGap))
    if count < 1 then count = 1 end
    for i = count + 1, #self.rows do
        self.rows[i]:SetHidden(true)
    end
    self.visibleRows = count
    self:KeepSelectionVisible()
    self:RefreshVisible()
end

function FixedList:Clear()
    for i = #self.entries, 1, -1 do
        self.entries[i] = nil
    end
    self.selectedIndex = 0
    self.firstIndex = 1
end

function FixedList:AddEntry(data)
    self.entries[#self.entries + 1] = data
end

function FixedList:FireSelected()
    if self.onSelected then
        self.onSelected(self, self.entries[self.selectedIndex])
    end
end

function FixedList:Commit()
    self.selectedIndex = self:FindSelectable(1, 1) or 0
    self.firstIndex = 1
    self:RefreshVisible()
    self:FireSelected()
end

function FixedList:GetNumItems()
    return #self.entries
end

function FixedList:GetSelectedIndex()
    return self.selectedIndex
end

function FixedList:GetSelectedData()
    return self.entries[self.selectedIndex]
end

function FixedList:Activate()
    if self.active then return end
    self.active = true
    self:RefreshVisible()
end

function FixedList:Deactivate()
    if not self.active then return end
    self.active = false
    self:RefreshVisible()
end

function FixedList:KeepSelectionVisible()
    local selected = self.selectedIndex
    if selected < 1 then
        self.firstIndex = 1
        return
    end
    if selected < self.firstIndex then
        self.firstIndex = selected
    elseif selected >= self.firstIndex + self.visibleRows then
        self.firstIndex = selected - self.visibleRows + 1
    end
    if selected > 1 and selected == self.firstIndex and not self:IsSelectable(selected - 1) then
        self.firstIndex = selected - 1
    end
    local maxFirst = #self.entries - self.visibleRows + 1
    if maxFirst < 1 then maxFirst = 1 end
    if self.firstIndex > maxFirst then self.firstIndex = maxFirst end
    if self.firstIndex < 1 then self.firstIndex = 1 end
end

function FixedList:SetSelectedIndexWithoutAnimation(index)
    local count = #self.entries
    if count == 0 then return end
    if index < 1 then index = 1 end
    if index > count then index = count end
    index = self:FindSelectable(index, 1) or self:FindSelectable(index, -1)
    if not index then return end
    local changed = index ~= self.selectedIndex
    self.selectedIndex = index
    self:KeepSelectionVisible()
    self:RefreshVisible()
    if changed then self:FireSelected() end
end

function FixedList:Move(delta)
    local index = self:FindSelectable(self.selectedIndex + delta, delta > 0 and 1 or -1)
    if not index then return false end
    self:SetSelectedIndexWithoutAnimation(index)
    PlaySound(delta > 0 and SOUNDS.GAMEPAD_MENU_DOWN or SOUNDS.GAMEPAD_MENU_UP)
    return true
end

function FixedList:RefreshVisible()
    local setup = self.setup
    local first = self.firstIndex
    for i = 1, self.visibleRows do
        local dataIndex = first + i - 1
        local data = self.entries[dataIndex]
        if data then
            local row = self:EnsureRow(i)
            row:SetHidden(false)
            setup(row, data, dataIndex == self.selectedIndex, false, true, self.active)
        else
            local row = self.rows[i]
            if row then row:SetHidden(true) end
        end
    end
    if self.upArrow then self.upArrow:SetHidden(first <= 1) end
    if self.downArrow then self.downArrow:SetHidden(first + self.visibleRows - 1 >= #self.entries) end
end

function FixedList:Release(releaseRow)
    self:Clear()
    for i = 1, #self.rows do
        local row = self.rows[i]
        row:SetHidden(true)
        if releaseRow then releaseRow(row) end
    end
    if self.upArrow then self.upArrow:SetHidden(true) end
    if self.downArrow then self.downArrow:SetHidden(true) end
end

--------------------------------------------------
-- Pages
--------------------------------------------------
function S.CurrentPage()
    return S.stack[#S.stack]
end

local NO_OPTIONS = {}

function S.PageOptions(page)
    if not page then return NO_OPTIONS end
    local options = Resolve(page.option.options)
    if type(options) ~= "table" then return NO_OPTIONS end
    return options
end

function S.PageTitle()
    local title = ""
    for i = 1, #S.stack do
        local name = ResolveText(S.stack[i].option.name)
        if i == 1 then title = name else title = title .. "  >  " .. name end
    end
    return title
end

function S.PageEntries(page)
    if not page then return NO_OPTIONS end
    local entries = S.pageEntries[page.option]
    if entries then return entries end
    entries = {}
    local options = S.PageOptions(page)
    for i = 1, #options do
        local opt = options[i]
        if type(opt) == "table" and SUPPORTED[opt.type] then
            entries[#entries + 1] = { libOption = opt }
        end
    end
    S.pageEntries[page.option] = entries
    return entries
end

function S.PageHasDefaults()
    local options = S.PageOptions(S.CurrentPage())
    for i = 1, #options do
        local opt = options[i]
        if type(opt) == "table" and opt.default ~= nil and opt.type ~= "submenu" and opt.type ~= "button" then
            return true
        end
    end
    return false
end

function S.SelectedOption()
    if not S.settingsList then return nil end
    local data = S.settingsList:GetSelectedData()
    return data and data.libOption
end

function S.BuildSettings()
    local list = S.settingsList
    if not list then return end
    local page = S.CurrentPage()
    list:Clear()
    local entries = S.PageEntries(page)
    for i = 1, #entries do
        list:AddEntry(entries[i])
    end
    list:Commit()
    local count = list:GetNumItems()
    if page and count > 0 then
        local index = page.index or 1
        if index < 1 then index = 1 end
        if index > count then index = count end
        list:SetSelectedIndexWithoutAnimation(index)
    end
    S.RefreshPageTitle()
end

function S.ResetToCategory(index)
    local category = S.categories[index]
    S.categoryIndex = index
    for i = #S.stack, 1, -1 do S.stack[i] = nil end
    if category then
        local page = S.rootPages[index]
        if not page or page.option ~= category then
            page = { option = category, index = 1 }
            S.rootPages[index] = page
        end
        page.index = 1
        S.stack[1] = page
    end
    S.BuildSettings()
end

function S.PushPage(opt)
    local top = S.CurrentPage()
    if top then top.index = S.settingsList:GetSelectedIndex() end
    S.stack[#S.stack + 1] = { option = opt, index = 1 }
    S.BuildSettings()
    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    S.RefreshAll()
end

function S.PopPage()
    if #S.stack <= 1 then return end
    S.stack[#S.stack] = nil
    S.BuildSettings()
    PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    S.RefreshAll()
end

--------------------------------------------------
-- Values
--------------------------------------------------
function S.InvalidateOption(opt)
    local entries = S.PageEntries(S.CurrentPage())
    for i = 1, #entries do
        if entries[i].libOption == opt then
            entries[i].libVersion = nil
        end
    end
end

function S.InvalidateAll()
    S.valueVersion = S.valueVersion + 1
    S.detailsOption = nil
end

function S.RefreshValues()
    S.lastRefreshMs = GetFrameTimeMilliseconds()
    if not S.IsShowing() then return end
    if S.settingsList then S.settingsList:RefreshVisible() end
    S.detailsOption = nil
    S.RefreshDetails()
    S.RefreshKeybinds()
end

local function OnDeferredRefresh()
    EVENT_MANAGER:UnregisterForUpdate(REFRESH_UPDATE_NAME)
    S.refreshPending = false
    S.RefreshValues()
end

function S.RequestRefresh(throttled)
    if not throttled then
        if S.refreshPending then
            EVENT_MANAGER:UnregisterForUpdate(REFRESH_UPDATE_NAME)
            S.refreshPending = false
        end
        S.RefreshValues()
        return
    end
    local elapsed = GetFrameTimeMilliseconds() - S.lastRefreshMs
    if elapsed >= REFRESH_THROTTLE_MS and not S.refreshPending then
        S.RefreshValues()
        return
    end
    if not S.refreshPending then
        S.refreshPending = true
        local delay = REFRESH_THROTTLE_MS - elapsed
        if delay < 1 then delay = 1 end
        EVENT_MANAGER:RegisterForUpdate(REFRESH_UPDATE_NAME, delay, OnDeferredRefresh)
    end
end

function S.SetOption(opt, ...)
    if opt and type(opt.setFunc) == "function" then
        opt.setFunc(...)
    end
    S.InvalidateOption(opt)
    S.RequestRefresh(false)
end

function S.SetColorThrottled(opt, r, g, b)
    if opt and type(opt.setColor) == "function" then
        opt.setColor(r, g, b, 1)
    end
    S.InvalidateOption(opt)
    S.RequestRefresh(true)
end

function S.SetOptionThrottled(opt, ...)
    if opt and type(opt.setFunc) == "function" then
        opt.setFunc(...)
    end
    S.InvalidateOption(opt)
    S.RequestRefresh(true)
end

function S.Adjust(delta, steps)
    local opt = S.SelectedOption()
    if not opt or IsDisabled(opt) then return end
    local kind = opt.type

    if kind == "slider" then
        local current = tonumber(GetValue(opt)) or opt.min or 0
        local value = SliderStep(opt, current, delta * (steps or 1))
        if value ~= current then S.SetOptionThrottled(opt, value) end

    elseif kind == "toggle" then
        local want = delta > 0
        if (GetValue(opt) == true) ~= want then
            S.SetOption(opt, want)
            PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
        end

    elseif kind == "selector" or kind == "stylecolor" then
        local choices = GetChoices(opt)
        local count = #choices
        if count == 0 then return end
        local index = FindChoiceIndex(opt, GetValue(opt)) or 1
        index = ((index - 1 + delta) % count) + 1
        S.SetOption(opt, ChoiceValue(choices[index]))
        PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)

    elseif kind == "iconpicker" then
        local count = #GetChoices(opt)
        if count == 0 then return end
        local index = tonumber(GetValue(opt)) or 1
        index = ((index - 1 + delta) % count) + 1
        S.SetOption(opt, index)
        PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
    end
end

function S.ResetPage()
    local options = S.PageOptions(S.CurrentPage())
    for i = 1, #options do
        local opt = options[i]
        if type(opt) == "table" and opt.default ~= nil and type(opt.setFunc) == "function" then
            local kind = opt.type
            local d = opt.default
            if kind == "checklist" then
                local copy = {}
                if type(d) == "table" then
                    for j = 1, #d do copy[j] = d[j] end
                end
                pcall(opt.setFunc, copy)
            elseif kind == "colorpicker" then
                if type(d) == "table" then
                    pcall(opt.setFunc, d.r or d[1] or 1, d.g or d[2] or 1, d.b or d[3] or 1, d.a or d[4] or 1)
                end
            elseif kind == "stylecolor" then
                pcall(opt.setFunc, d)
                local c = opt.colorDefault
                if type(c) == "table" and type(opt.setColor) == "function" then
                    pcall(opt.setColor, c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, 1)
                end
            elseif kind ~= "submenu" and kind ~= "button" then
                pcall(opt.setFunc, d)
            end
        end
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    S.InvalidateAll()
    S.RefreshAll()
end

--------------------------------------------------
-- Rows
--------------------------------------------------
local function RowParts(control)
    local parts = control.libParts
    if parts then return parts end
    local area = control:GetNamedChild("Value")
    local track = area:GetNamedChild("Track")
    parts = {
        bg      = control:GetNamedChild("Bg"),
        icon    = control:GetNamedChild("RowIcon"),
        name    = control:GetNamedChild("Label"),
        chevron = control:GetNamedChild("Chevron"),
        left    = area:GetNamedChild("Left"),
        right   = area:GetNamedChild("Right"),
        text    = area:GetNamedChild("Text"),
        track   = track,
        fill    = track:GetNamedChild("Fill"),
        number  = area:GetNamedChild("Number"),
        swatch  = area:GetNamedChild("Swatch"),
        preview = area:GetNamedChild("Preview"),
    }
    parts.track:SetCenterColor(TRACK_CENTER[1], TRACK_CENTER[2], TRACK_CENTER[3], TRACK_CENTER[4])
    parts.track:SetEdgeColor(0, 0, 0, 0)
    parts.fill:SetEdgeColor(0, 0, 0, 0)
    parts.swatch:SetEdgeColor(1, 1, 1, 0.9)
    control.libParts = parts
    return parts
end

local function HideValueParts(parts)
    parts.left:SetHidden(true)
    parts.right:SetHidden(true)
    parts.text:SetHidden(true)
    parts.track:SetHidden(true)
    parts.number:SetHidden(true)
    parts.swatch:SetHidden(true)
    parts.preview:SetHidden(true)
    parts.chevron:SetHidden(true)
end

local function ShowValueText(parts, text, focused)
    parts.text:SetText(text or "")
    SetLabelColor(parts.text, focused)
    parts.text:SetHidden(false)
end

local function RowCache(data)
    if data.libVersion == S.valueVersion then return end
    local opt = data.libOption
    local kind = opt.type
    data.libVersion = S.valueVersion
    data.libName = ResolveText(opt.name)
    if opt.namePrefix ~= nil then
        data.libName = ResolveText(Resolve(opt.namePrefix, opt)) .. data.libName
    end
    data.libIcon = kind == "submenu" and Resolve(opt.icon) or nil
    data.libText = nil
    data.libPct = nil
    data.libTexture = nil
    data.libDetails = nil
    data.libCustom = nil

    if kind == "toggle" then
        data.libText = ToggleText(opt, GetValue(opt) == true)

    elseif kind == "slider" then
        local min, max = opt.min or 0, opt.max or 100
        local value = tonumber(GetValue(opt)) or min
        local pct = 0
        if max > min then pct = (value - min) / (max - min) end
        if pct < 0 then pct = 0 end
        if pct > 1 then pct = 1 end
        data.libPct = pct
        data.libText = SliderNumberText(opt, value)

    elseif kind == "dropdown" or kind == "selector" or kind == "stylecolor" then
        local value = GetValue(opt)
        local index = FindChoiceIndex(opt, value)
        local choices = GetChoices(opt)
        data.libText = index and ChoiceName(choices[index]) or ResolveText(value)
        if kind == "stylecolor" and value == opt.customValue then
            data.libCustom = true
            data.libR, data.libG, data.libB = GetStyleColor(opt)
        end

    elseif kind == "checklist" then
        data.libText = ChecklistText(opt)

    elseif kind == "editbox" then
        data.libText = ResolveText(GetValue(opt))

    elseif kind == "colorpicker" then
        local r, g, b = GetValue(opt)
        data.libR, data.libG, data.libB = r or 1, g or 1, b or 1

    elseif kind == "iconpicker" then
        local choices = GetChoices(opt)
        local texture = choices[tonumber(GetValue(opt)) or 1]
        if type(texture) == "string" and texture ~= "" then data.libTexture = texture end
    end
end

local function SettingRowSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    RowCache(data)
    local parts = RowParts(control)
    local rowFont = S.fonts.row
    if rowFont and control.libFont ~= rowFont then
        control.libFont = rowFont
        parts.name:SetFont(rowFont)
        parts.text:SetFont(rowFont)
        parts.number:SetFont(rowFont)
    end
    local opt = data.libOption
    local kind = opt.type
    local disabled = IsDisabled(opt)
    local focused = selected and active

    ApplyRowBackdrop(parts.bg, selected, active, ACCENT)
    control:SetAlpha(disabled and DISABLED_ALPHA or 1)

    local iconTexture = data.libIcon
    if control.libIconShown ~= (iconTexture ~= nil) or control.libIconShown == nil then
        control.libIconShown = iconTexture ~= nil
        parts.name:ClearAnchors()
        if iconTexture then
            parts.name:SetAnchor(LEFT, parts.icon, RIGHT, 14, 0)
        else
            parts.name:SetAnchor(LEFT, control, LEFT, 20, 0)
        end
    end
    if iconTexture then
        parts.icon:SetTexture(iconTexture)
        parts.icon:SetHidden(false)
    else
        parts.icon:SetHidden(true)
    end
    local wide = kind == "submenu" or kind == "button" or kind == "header"
    parts.name:SetWidth(wide and NAME_WIDTH_WIDE or NAME_WIDTH)
    parts.name:SetText(data.libName)
    SetLabelColor(parts.name, focused)

    HideValueParts(parts)

    if kind == "header" then
        parts.bg:SetCenterColor(0, 0, 0, 0)
        parts.bg:SetEdgeColor(0, 0, 0, 0)
        parts.name:SetColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        return
    end

    local swatchRight = kind == "stylecolor"
    if control.libSwatchRight ~= swatchRight then
        control.libSwatchRight = swatchRight
        parts.swatch:ClearAnchors()
        if swatchRight then
            parts.swatch:SetAnchor(RIGHT, parts.swatch:GetParent(), RIGHT, SWATCH_ROW_OFFSET, 0)
        else
            parts.swatch:SetAnchor(CENTER, parts.swatch:GetParent(), CENTER, 0, 0)
        end
    end

    local showArrows = focused and HORIZONTAL[kind] and not disabled
    parts.left:SetHidden(not showArrows)
    parts.right:SetHidden(not showArrows)

    if kind == "slider" then
        local width = math.floor(SLIDER_TRACK_W * (data.libPct or 0) + 0.5)
        parts.fill:SetCenterColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        parts.fill:SetWidth(width > 0 and width or 1)
        parts.fill:SetHidden(width <= 0)
        parts.track:SetHidden(false)
        parts.number:SetText(data.libText or "")
        SetLabelColor(parts.number, focused)
        parts.number:SetHidden(false)

    elseif kind == "colorpicker" then
        parts.swatch:SetCenterColor(data.libR or 1, data.libG or 1, data.libB or 1, 1)
        parts.swatch:SetHidden(false)

    elseif kind == "iconpicker" then
        if data.libTexture then
            parts.preview:SetTexture(data.libTexture)
            parts.preview:SetHidden(false)
        end

    elseif kind == "stylecolor" then
        ShowValueText(parts, data.libText, focused)
        if data.libCustom then
            parts.swatch:SetCenterColor(data.libR or 1, data.libG or 1, data.libB or 1, 1)
            parts.swatch:SetHidden(false)
        end

    elseif kind == "submenu" then
        parts.chevron:SetHidden(false)

    elseif data.libText then
        ShowValueText(parts, data.libText, focused)
    end
end

local CATEGORY_ROW_WIDTH  = 353
local CATEGORY_ICON_SIZE  = 38
local CATEGORY_ICON_GAP   = 12
local CATEGORY_LABEL_MAX  = 279

local function CenterCategoryRow(control, parts, hasIcon)
    parts.label:SetWidth(CATEGORY_LABEL_MAX)
    local width = math.ceil(parts.label:GetTextWidth() or 0) + 2
    if width > CATEGORY_LABEL_MAX then width = CATEGORY_LABEL_MAX end
    if width < 1 then width = 1 end
    local total = width
    if hasIcon then total = total + CATEGORY_ICON_SIZE + CATEGORY_ICON_GAP end
    local startX = math.floor((CATEGORY_ROW_WIDTH - total) / 2 + 0.5)
    if control.libStartX == startX and control.libLabelW == width and control.libHasIcon == hasIcon then return end
    control.libStartX, control.libLabelW, control.libHasIcon = startX, width, hasIcon
    parts.label:SetWidth(width)
    parts.label:ClearAnchors()
    if hasIcon then
        parts.icon:ClearAnchors()
        parts.icon:SetAnchor(LEFT, control, LEFT, startX, 0)
        parts.label:SetAnchor(LEFT, parts.icon, RIGHT, CATEGORY_ICON_GAP, 0)
    else
        parts.label:SetAnchor(LEFT, control, LEFT, startX, 0)
    end
end

local function CategoryParts(control)
    local parts = control.libParts
    if parts then return parts end
    parts = {
        bg    = control:GetNamedChild("Bg"),
        icon  = control:GetNamedChild("RowIcon"),
        label = control:GetNamedChild("Label"),
    }
    control.libParts = parts
    return parts
end

local function CategoryRowSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    local parts = CategoryParts(control)
    local bg, icon, label = parts.bg, parts.icon, parts.label
    local opt = data.libOption
    local rowFont = S.fonts.row
    if rowFont and control.libFont ~= rowFont then
        control.libFont = rowFont
        label:SetFont(rowFont)
    end

    ApplyRowBackdrop(bg, selected, active, ACCENT)
    control:SetAlpha(IsDisabled(opt) and DISABLED_ALPHA or 1)

    local texture = Resolve(opt.icon)
    local hasIcon = type(texture) == "string" and texture ~= ""
    if hasIcon then
        icon:SetTexture(texture)
        icon:SetHidden(false)
    else
        icon:SetHidden(true)
    end

    label:SetText(ResolveText(opt.name))
    SetLabelColor(label, selected and active)
    CenterCategoryRow(control, parts, hasIcon)
end

--------------------------------------------------
-- Visuals
--------------------------------------------------
function S.UpdateFonts()
    local size = tonumber(S.menu and Resolve(S.menu.textSize)) or DEFAULT_TEXT_SIZE
    size = math.floor(size + 0.5)
    if size < TEXT_SIZE_MIN then size = TEXT_SIZE_MIN end
    if size > TEXT_SIZE_MAX then size = TEXT_SIZE_MAX end
    if size == S.fontSize and S.fonts.row then return false end
    S.fontSize = size
    local delta = size - DEFAULT_TEXT_SIZE
    local fonts = S.fonts
    fonts.row = GamepadFont(size)
    fonts.name = GamepadFont(DETAILS_NAME_SIZE + delta)
    fonts.body = GamepadFont(DETAILS_BODY_SIZE + delta)
    PvPUAPatchLib_WindowRootFrameCategoriesTitle:SetFont(fonts.row)
    PvPUAPatchLib_WindowRootFrameSettingsTitle:SetFont(fonts.row)
    PvPUAPatchLib_WindowRootFrameDetailsTitle:SetFont(fonts.row)
    PvPUAPatchLib_WindowRootFrameDetailsName:SetFont(fonts.name)
    PvPUAPatchLib_WindowRootFrameDetailsNumber:SetFont(fonts.name)
    PvPUAPatchLib_WindowRootFrameDetailsBody:SetFont(fonts.body)
    return true
end

function S.UpdateOpacity()
    local pct = tonumber(S.menu and Resolve(S.menu.windowOpacity)) or DEFAULT_OPACITY
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    S.paneAlpha = pct / 100
    local row = ROW_CENTER[4] * pct / DEFAULT_OPACITY
    if row > 1 then row = 1 end
    S.rowAlpha = row
end

function S:ApplyOpacity()
    S.UpdateOpacity()
    if not S.IsShowing() then return end
    S.RefreshPaneVisuals()
    if S.categoryList then S.categoryList:RefreshVisible() end
end

function S:ApplyAccent()
    RefreshAccent()
    if not S.IsShowing() then return end
    if S.categoryList then S.categoryList:RefreshVisible() end
end

function S:ApplyTextSize()
    if not S.UpdateFonts() then return end
    if not S.IsShowing() then return end
    if S.categoryList then S.categoryList:RefreshVisible() end
    S.detailsOption = nil
end

local FRAME_COLOR = { 1, 1, 1 }

local function PaneColors()
    local custom = S.menu and Resolve(S.menu.frameColor)
    if type(custom) == "table" then
        FRAME_COLOR[1] = custom.r or custom[1] or 1
        FRAME_COLOR[2] = custom.g or custom[2] or 1
        FRAME_COLOR[3] = custom.b or custom[3] or 1
        return FRAME_COLOR, FRAME_COLOR, FRAME_COLOR, FRAME_COLOR
    end
    return COLOR_DC, COLOR_AD, COLOR_EP, HEADER_EDGE
end

function S.RefreshHeader()
    local menu = S.menu or {}
    local left, _, right = PaneColors()
    PvPUAPatchLib_WindowRootFrameHeaderTitle:SetText(ResolveText(menu.title))
    PvPUAPatchLib_WindowRootFrameHeaderVersion:SetText("Version " .. ResolveText(menu.version))
    PvPUAPatchLib_WindowRootFrameHeaderAuthor:SetText(ResolveText(menu.author))
    PvPUAPatchLib_WindowRootFrameCategoriesTitle:SetText(Tint("Categories", left))
    PvPUAPatchLib_WindowRootFrameDetailsTitle:SetText(Tint("Details", right))
end

local STRIPS

function S.RefreshPaneVisuals()
    local left, middle, right, header = PaneColors()
    ApplyPane(PvPUAPatchLib_WindowRootFrameHeader, header, HEADER_EDGE[4])
    ApplyPane(PvPUAPatchLib_WindowRootFrameCategories, left, S.pane == PANE_CATEGORIES and 1 or INACTIVE_EDGE_ALPHA)
    ApplyPane(PvPUAPatchLib_WindowRootFrameSettings, middle, S.pane == PANE_SETTINGS and 1 or INACTIVE_EDGE_ALPHA)
    ApplyPane(PvPUAPatchLib_WindowRootFrameDetails, right, DETAILS_EDGE_ALPHA)

    if not STRIPS then
        STRIPS = {
            PvPUAPatchLib_WindowRootFrameStripDC,
            PvPUAPatchLib_WindowRootFrameStripAD,
            PvPUAPatchLib_WindowRootFrameStripEP,
        }
    end
    local colors = { left, middle, right }
    for i = 1, #STRIPS do
        local control, color = STRIPS[i], colors[i]
        control:SetCenterColor(color[1], color[2], color[3], 1)
        control:SetEdgeColor(0, 0, 0, 0)
    end
end

function S.RefreshPageTitle()
    local title = S.PageTitle()
    if title == "" then title = "Settings" end
    local suffix = S.menu and ResolveText(S.menu.titleSuffix)
    if suffix and suffix ~= "" then title = title .. "  " .. suffix end
    PvPUAPatchLib_WindowRootFrameSettingsTitle:SetText(title)
end

--------------------------------------------------
-- Item Tooltip
--------------------------------------------------
local function ItemTip()
    if S.itemTip then return S.itemTip end
    if not (ZO_ScrollTooltip_Gamepad and ZO_TOOLTIP_STYLES and WINDOW_MANAGER) then return nil end
    local pane = PvPUAPatchLib_WindowRootFrameDetails
    local ok, control = pcall(function()
        return WINDOW_MANAGER:CreateControlFromVirtual("PvPUAPatchLib_WindowItemTip", pane, "ZO_ScrollTooltip_Gamepad")
    end)
    if not (ok and control) then return nil end
    control:SetAnchor(TOPLEFT, PvPUAPatchLib_WindowRootFrameDetailsTitle, BOTTOMLEFT, 0, 22)
    control:SetAnchor(BOTTOMRIGHT, pane, BOTTOMRIGHT, -24, -20)

    local style = {}
    local base = ZO_TOOLTIP_STYLES.tooltip
    if type(base) == "table" then
        for k, v in pairs(base) do style[k] = v end
    end
    style.width = DETAILS_WIDTH
    local styles = setmetatable({ libUser562Tip = style }, { __index = ZO_TOOLTIP_STYLES })

    local initOk = pcall(function() ZO_ScrollTooltip_Gamepad:Initialize(control, styles, "libUser562Tip") end)
    if not initOk then
        control:SetHidden(true)
        return nil
    end
    local indicator = control.scrollIndicator or control:GetNamedChild("ScrollIndicator")
    if indicator then
        indicator:ClearAnchors()
        indicator:SetAnchor(CENTER, pane, RIGHT, 0, 0)
        if indicator.SetDrawLayer and DL_OVERLAY then indicator:SetDrawLayer(DL_OVERLAY) end
    end
    control:SetHidden(true)
    S.itemTip = control
    return control
end

local function HideItemTip()
    local tip = S.itemTip
    if not tip then return end
    if not tip:IsHidden() then tip:SetHidden(true) end
    if S.itemTipLink then
        S.itemTipLink = nil
        if tip.tooltip and tip.tooltip.ClearLines then pcall(tip.tooltip.ClearLines, tip.tooltip) end
    end
end

local function ShowItemTip(itemLink)
    local tip = ItemTip()
    if not (tip and tip.tooltip) then return false end
    if S.itemTipLink ~= itemLink then
        pcall(tip.tooltip.ClearLines, tip.tooltip)
        local ok = pcall(tip.tooltip.LayoutItem, tip.tooltip, itemLink, false)
        if not ok then
            pcall(tip.tooltip.ClearLines, tip.tooltip)
            S.itemTipLink = nil
            tip:SetHidden(true)
            return false
        end
        S.itemTipLink = itemLink
    end
    tip:SetHidden(false)
    return true
end

local function ChecklistDetails(opt)
    local set = SelectedSet(opt)
    local choices = GetChoices(opt)
    local text = ""
    for i = 1, #choices do
        local icon = set[ChoiceValue(choices[i])] and CHECKED_ICON or UNCHECKED_ICON
        local line = zo_iconTextFormat(icon, 28, 28, ChoiceName(choices[i]))
        if i == 1 then text = line else text = text .. "\n" .. line end
    end
    return text
end

local function ShowSampleIcon(preview, texture, size, alpha, r, g, b)
    if type(texture) ~= "string" or texture == "" then return false end
    size = tonumber(size) or DETAILS_ICON_SIZE
    if size > DETAILS_ICON_SIZE then size = DETAILS_ICON_SIZE end
    if size < SAMPLE_ICON_MIN then size = SAMPLE_ICON_MIN end
    preview:SetTexture(texture)
    preview:SetDimensions(size, size)
    preview:SetAlpha(tonumber(alpha) or 1)
    preview:SetColor(r or 1, g or 1, b or 1, 1)
    preview:SetHidden(false)
    return true
end

local BAR_FONT = "EsoUI/Common/Fonts/FTN57.otf|20|outline"

local function BarParts()
    local parts = S.barParts
    if parts then return parts end
    local bar = PvPUAPatchLib_WindowRootFrameDetailsBar
    parts = {
        bar   = bar,
        icon  = bar:GetNamedChild("Icon"),
        bg    = bar:GetNamedChild("Bg"),
        fill  = bar:GetNamedChild("Fill"),
        left  = bar:GetNamedChild("Left"),
        right = bar:GetNamedChild("Right"),
    }
    parts.bg:SetCenterColor(0.1, 0.1, 0.1, 0.9)
    parts.bg:SetEdgeColor(0, 0, 0, 1)
    parts.fill:SetMinMax(0, 100)
    parts.left:SetFont(BAR_FONT)
    parts.right:SetFont(BAR_FONT)
    parts.left:SetColor(1, 1, 1, 1)
    parts.right:SetColor(1, 1, 1, 1)
    SetReleasable(parts.icon)
    S.barParts = parts
    return parts
end

local function ShowSampleBar(icon, ir, ig, ib, pct, leftText, rightText, br, bg, bb)
    local parts = BarParts()
    if type(icon) == "string" and icon ~= "" then
        parts.icon:SetTexture(icon)
        parts.icon:SetColor(ir or 1, ig or 1, ib or 1, 1)
        parts.icon:SetHidden(false)
    else
        parts.icon:SetHidden(true)
    end
    pct = tonumber(pct) or 0
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    parts.fill:SetValue(pct)
    parts.fill:SetColor(br or 1, bg or 1, bb or 1, 1)
    parts.left:SetText(leftText or "")
    parts.right:SetText(rightText or "")
    parts.bar:SetHidden(false)
    return parts.bar
end

local function HideSampleBar()
    if S.barParts then S.barParts.bar:SetHidden(true) end
end

local function ShowSample(label, anchorTo, text, font, r, g, b)
    if type(text) ~= "string" or text == "" then return false end
    label:SetScale(1)
    label:SetFont(font or "ZoFontGamepad34")
    label:SetText(text)
    label:SetColor(r or 1, g or 1, b or 1, 1)
    label:ClearAnchors()
    label:SetAnchor(TOP, anchorTo, BOTTOM, 0, 18)
    local width = label:GetTextWidth()
    if width and width > DETAILS_WIDTH then
        label:SetScale(DETAILS_WIDTH / width)
    end
    label:SetHidden(false)
    return true
end

function S.RefreshDetails()
    local data
    if S.pane == PANE_CATEGORIES then
        data = S.categoryList and S.categoryList:GetSelectedData()
    else
        data = S.settingsList and S.settingsList:GetSelectedData()
    end
    local opt = data and data.libOption
    if opt == S.detailsOption and opt ~= nil then return end
    S.detailsOption = opt

    local nameLabel = PvPUAPatchLib_WindowRootFrameDetailsName
    local body = PvPUAPatchLib_WindowRootFrameDetailsBody
    local preview = PvPUAPatchLib_WindowRootFrameDetailsPreview
    local swatch = PvPUAPatchLib_WindowRootFrameDetailsSwatch
    local sample = PvPUAPatchLib_WindowRootFrameDetailsSample

    preview:SetHidden(true)
    swatch:SetHidden(true)
    sample:SetHidden(true)
    HideSampleBar()

    if not opt then
        HideItemTip()
        nameLabel:SetText("")
        body:SetText("")
        PvPUAPatchLib_WindowRootFrameDetailsNumber:SetHidden(true)
        return
    end

    if S.pane == PANE_SETTINGS then
        RowCache(data)
        local itemLink = Resolve(opt.itemLink, opt)
        if type(itemLink) == "string" and itemLink ~= "" and ShowItemTip(itemLink) then
            nameLabel:SetText("")
            body:SetText("")
            PvPUAPatchLib_WindowRootFrameDetailsNumber:SetHidden(true)
            return
        end
    end
    HideItemTip()

    local number = PvPUAPatchLib_WindowRootFrameDetailsNumber
    local numbered = S.pane == PANE_SETTINGS and opt.detailsNumber ~= nil
    if numbered then
        nameLabel:SetText(ResolveText(opt.detailsTitle or opt.name))
        number:SetText(ResolveText(opt.detailsNumber))
        number:SetHidden(false)
    else
        nameLabel:SetText(data.libName or ResolveText(opt.name))
        number:SetHidden(true)
    end
    if nameLabel.libNumbered ~= numbered then
        nameLabel.libNumbered = numbered
        nameLabel:ClearAnchors()
        if numbered then
            nameLabel:SetAnchor(TOPLEFT, number, BOTTOMLEFT, 0, 6)
        else
            nameLabel:SetAnchor(TOPLEFT, PvPUAPatchLib_WindowRootFrameDetailsTitle, BOTTOMLEFT, 0, 22)
        end
    end

    local inSettings = S.pane == PANE_SETTINGS
    local text = inSettings and data.libDetails or nil
    local anchorTo = nameLabel

    if inSettings then
        if opt.type == "iconpicker" then
            if ShowSampleIcon(preview, data.libTexture, DETAILS_ICON_SIZE, 1) then
                anchorTo = preview
            end
        elseif opt.type == "colorpicker" or (opt.type == "stylecolor" and data.libCustom) then
            swatch:SetCenterColor(data.libR or 1, data.libG or 1, data.libB or 1, 1)
            swatch:SetEdgeColor(1, 1, 1, 0.9)
            swatch:SetHidden(false)
            anchorTo = swatch
        end

        if type(opt.sampleBar) == "function" and anchorTo == nameLabel then
            anchorTo = ShowSampleBar(opt.sampleBar())
        end

        if type(opt.sampleIcon) == "function" and anchorTo == nameLabel then
            if ShowSampleIcon(preview, opt.sampleIcon()) then
                anchorTo = preview
            end
        end

        if type(opt.sample) == "function" then
            if ShowSample(sample, anchorTo, opt.sample()) then
                anchorTo = sample
            end
        end
    end

    if not text then
        text = ""
        if opt.type == "checklist" and inSettings then
            text = ChecklistDetails(opt)
        end
        local tooltip = ResolveText(opt.tooltip)
        if tooltip ~= "" then
            if text ~= "" then text = text .. "\n\n" .. tooltip else text = tooltip end
        end
        if inSettings then data.libDetails = text end
    end

    if inSettings and opt.details ~= nil then
        local extra = ResolveText(opt.details)
        if extra ~= "" then
            if text ~= "" then text = extra .. "\n\n" .. text else text = extra end
        end
    end

    if body.libAnchor ~= anchorTo then
        body.libAnchor = anchorTo
        body:ClearAnchors()
        body:SetAnchor(TOP, anchorTo, BOTTOM, 0, 18)
    end
    body:SetText(text)
end

function S.RefreshKeybinds()
    if not S.keybindsAdded then return end
    local state = S.keybindState
    local primaryVisible = S.PrimaryVisible() == true
    local primaryName = primaryVisible and S.PrimaryName() or ""
    local primaryEnabled = primaryVisible and S.PrimaryEnabled() == true
    local defaultsVisible = S.PageHasDefaults()
    local sliderVisible = S.IsSliderSelected()
    local hasItems = S.settingsList ~= nil and S.settingsList:GetNumItems() > 0
    local canPage = S.CanPage()
    local always = S.panel ~= nil and S.panel.hasExtraKeybinds == true
    if not always
        and state.pane == S.pane
        and state.canPage == canPage
        and state.primaryVisible == primaryVisible
        and state.primaryName == primaryName
        and state.primaryEnabled == primaryEnabled
        and state.defaultsVisible == defaultsVisible
        and state.sliderVisible == sliderVisible
        and state.hasItems == hasItems then
        return
    end
    state.pane = S.pane
    state.primaryVisible = primaryVisible
    state.primaryName = primaryName
    state.primaryEnabled = primaryEnabled
    state.defaultsVisible = defaultsVisible
    state.sliderVisible = sliderVisible
    state.hasItems = hasItems
    state.canPage = canPage
    KEYBIND_STRIP:UpdateKeybindButtonGroup(S.activeKeybinds)
end

function S.RefreshAll()
    if not S.IsShowing() then return end
    S.lastRefreshMs = GetFrameTimeMilliseconds()
    S.RefreshPageTitle()
    if S.settingsList then S.settingsList:RefreshVisible() end
    if S.categoryList then S.categoryList:RefreshVisible() end
    S.detailsOption = nil
    S.RefreshDetails()
    S.RefreshKeybinds()
end

--------------------------------------------------
-- Focus
--------------------------------------------------
function S.FocusSettings()
    if S.pane == PANE_SETTINGS then return end
    if not S.settingsList or S.settingsList:GetNumItems() == 0 then return end
    S.pane = PANE_SETTINGS
    S.categoryList:Deactivate()
    S.settingsList:Activate()
    S.waitRelease = true
    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    S.RefreshPaneVisuals()
    S.RefreshAll()
end

function S.FocusCategories()
    if S.pane == PANE_CATEGORIES then return end
    local top = S.CurrentPage()
    if top then top.index = S.settingsList:GetSelectedIndex() end
    S.pane = PANE_CATEGORIES
    S.settingsList:Deactivate()
    S.categoryList:Activate()
    PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    S.RefreshPaneVisuals()
    S.RefreshAll()
end

function S.OnCategorySelected(data)
    if not data then return end
    if S.pane ~= PANE_CATEGORIES then return end
    if data.libIndex ~= S.categoryIndex or #S.stack == 0 then
        S.ResetToCategory(data.libIndex)
    end
    S.RefreshDetails()
    S.RefreshKeybinds()
end

--------------------------------------------------
-- Primary
--------------------------------------------------
function S.PrimaryVisible()
    if S.pane == PANE_CATEGORIES then
        return S.settingsList ~= nil and S.settingsList:GetNumItems() > 0
    end
    local opt = S.SelectedOption()
    if not opt then return false end
    if opt.type == "header" then return false end
    if opt.type == "button" and type(opt.func) ~= "function" then return false end
    return opt.type == "toggle" or IsCustomStyle(opt) or not HORIZONTAL[opt.type]
end

function S.PrimaryName()
    if S.pane == PANE_CATEGORIES then return GetString(SI_GAMEPAD_SELECT_OPTION) end
    local opt = S.SelectedOption()
    if not opt then return "" end
    if opt.type == "toggle" then return GetString(SI_GAMEPAD_TOGGLE_OPTION) end
    if opt.type == "button" then return ResolveText(opt.buttonText or opt.name) end
    if opt.type == "stylecolor" then return "Edit Color" end
    return GetString(SI_GAMEPAD_SELECT_OPTION)
end

function S.PrimaryEnabled()
    if S.pane == PANE_CATEGORIES then return true end
    local opt = S.SelectedOption()
    return opt ~= nil and not IsDisabled(opt)
end

function S.OnPrimary()
    if S.pane == PANE_CATEGORIES then
        S.FocusSettings()
        return
    end
    local opt = S.SelectedOption()
    if not opt or IsDisabled(opt) then return end
    local kind = opt.type

    if kind == "toggle" then
        PlaySound(SOUNDS.DEFAULT_CLICK)
        S.SetOption(opt, not (GetValue(opt) == true))
    elseif kind == "button" then
        if type(opt.func) ~= "function" then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        if opt.confirm ~= nil then
            S.confirmOption = opt
            ZO_Dialogs_ShowGamepadDialog(CONFIRM_DIALOG)
            return
        end
        if type(opt.func) == "function" then opt.func() end
        S.RefreshAll()
    elseif kind == "submenu" then
        S.PushPage(opt)
    elseif kind == "dropdown" then
        ZO_Dialogs_ShowGamepadDialog(SELECT_DIALOG, { libOption = opt, title = ResolveText(opt.name) })
    elseif kind == "checklist" then
        ZO_Dialogs_ShowGamepadDialog(CHECKLIST_DIALOG, { libOption = opt, title = ResolveText(opt.name) })
    elseif kind == "editbox" then
        ZO_Dialogs_ShowGamepadDialog(TEXT_DIALOG, { libOption = opt, title = ResolveText(opt.name), text = ResolveText(GetValue(opt)) })
    elseif kind == "colorpicker" then
        local r, g, b = GetValue(opt)
        SYSTEMS:GetObject("colorPicker"):Show(function(nr, ng, nb, na)
            S.SetOptionThrottled(opt, nr, ng, nb, na or 1)
        end, r or 1, g or 1, b or 1)
    elseif kind == "stylecolor" and IsCustomStyle(opt) then
        local r, g, b = GetStyleColor(opt)
        SYSTEMS:GetObject("colorPicker"):Show(function(nr, ng, nb)
            S.SetColorThrottled(opt, nr, ng, nb)
        end, r, g, b)
    end
end

function S.OnBack()
    if S.pane == PANE_SETTINGS then
        if #S.stack > 1 then
            S.PopPage()
        else
            S.FocusCategories()
        end
        return
    end
    SCENE_MANAGER:HideCurrentScene()
end

--------------------------------------------------
-- Keybinds
--------------------------------------------------
function S.IsSliderSelected()
    if S.pane ~= PANE_SETTINGS then return false end
    local opt = S.SelectedOption()
    return opt ~= nil and opt.type == "slider" and not IsDisabled(opt)
end

function S.CanPage()
    if S.pane ~= PANE_SETTINGS then return false end
    local list = S.settingsList
    return list ~= nil and list:GetNumItems() > list.visibleRows
end

function S.PageMove(direction)
    local list = S.settingsList
    if not list then return end
    local step = list.visibleRows - 1
    if step < 1 then step = 1 end
    local before = list:GetSelectedIndex()
    local target = before + direction * step
    local count = list:GetNumItems()
    if target < 1 then target = 1 end
    if target > count then target = count end
    target = list:FindSelectable(target, direction) or list:FindSelectable(target, -direction)
    if not target or target == before then return end
    list:SetSelectedIndexWithoutAnimation(target)
    PlaySound(direction > 0 and SOUNDS.GAMEPAD_MENU_DOWN or SOUNDS.GAMEPAD_MENU_UP)
end

S.keybinds = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = function() return S.PrimaryName() end,
        keybind = "UI_SHORTCUT_PRIMARY",
        visible = function() return S.PrimaryVisible() end,
        enabled = function() return S.PrimaryEnabled() end,
        callback = function() S.OnPrimary() end,
    },
    {
        name = GetString(SI_OPTIONS_DEFAULTS),
        keybind = "UI_SHORTCUT_TERTIARY",
        visible = function() return S.PageHasDefaults() end,
        callback = function() ZO_Dialogs_ShowGamepadDialog(DEFAULTS_DIALOG) end,
    },
    {
        name = "Categories",
        keybind = "UI_SHORTCUT_LEFT_SHOULDER",
        visible = function() return S.pane == PANE_SETTINGS end,
        callback = function() S.FocusCategories() end,
    },
    {
        name = "Settings",
        keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
        visible = function()
            return S.pane == PANE_CATEGORIES and S.settingsList ~= nil and S.settingsList:GetNumItems() > 0
        end,
        callback = function() S.FocusSettings() end,
    },
    {
        name = function()
            if S.IsSliderSelected() then return "Decrease" end
            return "Scroll Up"
        end,
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        visible = function() return S.IsSliderSelected() or S.CanPage() end,
        callback = function()
            if S.IsSliderSelected() then S.Adjust(-1, SLIDER_BIG_STEPS) else S.PageMove(-1) end
        end,
    },
    {
        name = function()
            if S.IsSliderSelected() then return "Increase" end
            return "Scroll Down"
        end,
        keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
        visible = function() return S.IsSliderSelected() or S.CanPage() end,
        callback = function()
            if S.IsSliderSelected() then S.Adjust(1, SLIDER_BIG_STEPS) else S.PageMove(1) end
        end,
    },
    {
        name = GetString(SI_GAMEPAD_BACK_OPTION),
        keybind = "UI_SHORTCUT_NEGATIVE",
        callback = function() S.OnBack() end,
    },
}

local function ExtraOn(extra)
    if extra.visible == nil then return true end
    return Resolve(extra.visible) == true
end

local function MergeKeybind(base, extra)
    return {
        alignment = extra.alignment or base.alignment,
        keybind = base.keybind,
        name = function()
            if ExtraOn(extra) then return ResolveText(extra.name) end
            return ResolveText(base.name)
        end,
        visible = function()
            if ExtraOn(extra) then return true end
            if base.visible == nil then return true end
            return Resolve(base.visible) == true
        end,
        enabled = function()
            if ExtraOn(extra) then
                if extra.enabled == nil then return true end
                return Resolve(extra.enabled) == true
            end
            if base.enabled == nil then return true end
            return Resolve(base.enabled) == true
        end,
        callback = function()
            if ExtraOn(extra) then
                if type(extra.callback) == "function" then extra.callback() end
            elseif type(base.callback) == "function" then
                base.callback()
            end
        end,
    }
end

function S.PanelKeybinds(panel)
    if panel.keybindGroup then return panel.keybindGroup end
    local group = { alignment = S.keybinds.alignment }
    for i = 1, #S.keybinds do group[i] = S.keybinds[i] end
    local extras = Resolve(panel.menu.keybinds)
    if type(extras) == "table" then
        for i = 1, #extras do
            local extra = extras[i]
            if type(extra) == "table" and extra.keybind then
                local merged = false
                for j = 1, #group do
                    if group[j].keybind == extra.keybind then
                        group[j] = MergeKeybind(group[j], extra)
                        merged = true
                        break
                    end
                end
                if not merged then group[#group + 1] = extra end
                panel.hasExtraKeybinds = true
            end
        end
    end
    panel.keybindGroup = group
    return group
end

--------------------------------------------------
-- Directional Input
--------------------------------------------------
local function VerticalMove(delta)
    if ZO_Dialogs_IsShowingDialog() then return end
    local list = S.pane == PANE_CATEGORIES and S.categoryList or S.settingsList
    list:Move(delta)
end

local function IsFreshPress(controller)
    return controller ~= nil and type(controller.debt) == "number" and controller.debt > 0
end

local function HorizontalMove(delta)
    if S.waitRelease then
        if not IsFreshPress(S.horizontal) then return end
        S.waitRelease = false
    end

    if ZO_Dialogs_IsShowingDialog() then return end
    if S.pane ~= PANE_SETTINGS then return end

    local opt = S.SelectedOption()
    if not opt or not HORIZONTAL[opt.type] then return end

    S.Adjust(delta, 1)
end

local function RunMove(move, delta)
    if not S.inputActive then return end
    pcall(move, delta)
end

local function StockUpdate()
    return ZO_GamepadFocus and ZO_GamepadFocus.UpdateDirectionalInput
end

S.inputVertical = {
    UpdateDirectionalInput = StockUpdate(),
    MoveNext = function() RunMove(VerticalMove, 1) end,
    MovePrevious = function() RunMove(VerticalMove, -1) end,
}

S.inputHorizontal = {
    UpdateDirectionalInput = StockUpdate(),
    MoveNext = function() RunMove(HorizontalMove, 1) end,
    MovePrevious = function() RunMove(HorizontalMove, -1) end,
}

function S.ActivateInput()
    if S.inputActive or not S.inputVertical.UpdateDirectionalInput then return end
    S.inputVertical.movementController = S.vertical
    S.inputHorizontal.movementController = S.horizontal
    DIRECTIONAL_INPUT:Activate(S.inputVertical, PvPUAPatchLib_WindowRoot)
    DIRECTIONAL_INPUT:Activate(S.inputHorizontal, PvPUAPatchLib_WindowRoot)
    S.inputActive = true
end

function S.DeactivateInput()
    if not S.inputActive then return end
    DIRECTIONAL_INPUT:Deactivate(S.inputVertical)
    DIRECTIONAL_INPUT:Deactivate(S.inputHorizontal)
    S.inputActive = false
end

--------------------------------------------------
-- Previews
--------------------------------------------------
function S.RaisePreviews(raise)
    if raise then
        S.raised = {}
        local controls = S.menu and Resolve(S.menu.previewControls)
        if type(controls) ~= "table" then return end
        for i = 1, #controls do
            local control = controls[i]
            if control and control.GetDrawTier and control.SetDrawTier then
                S.raised[#S.raised + 1] = { control = control, tier = control:GetDrawTier() }
                control:SetDrawTier(DT_MEDIUM)
            end
        end
    else
        for i = 1, #S.raised do
            local entry = S.raised[i]
            entry.control:SetDrawTier(entry.tier)
        end
        S.raised = {}
    end
end

--------------------------------------------------
-- Dialogs
--------------------------------------------------
local function ReleaseDialog(name)
    if ZO_Dialogs_ReleaseDialogOnButtonPress then
        ZO_Dialogs_ReleaseDialogOnButtonPress(name)
    else
        ZO_Dialogs_ReleaseDialog(name)
    end
end

local function DialogTitle(dialog)
    return dialog and dialog.data and dialog.data.title or ""
end

local function SelectTargetIndex(dialog, index)
    local list = dialog.entryList
    if not list then return end
    if list.SetTargetIndex then
        list:SetTargetIndex(index)
    elseif list.SetSelectedIndexWithoutAnimation then
        list:SetSelectedIndexWithoutAnimation(index)
    end
end

local function DialogPrimaryButton()
    return {
        keybind = "DIALOG_PRIMARY",
        text = SI_GAMEPAD_SELECT_OPTION,
        callback = function(dialog)
            local targetData = dialog.entryList and dialog.entryList:GetTargetData()
            if targetData and targetData.callback then
                targetData.callback(dialog)
            end
        end,
    }
end

local function SelectEntrySetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    local label = control.label or control:GetNamedChild("Label")
    if not label then return end
    local text = data.baseText or ""
    if data.isCurrent then
        text = zo_iconTextFormat(CURRENT_ICON, 24, 24, text)
    end
    label:SetText(text)
end

local function ChecklistEntrySetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    local label = control.label or control:GetNamedChild("Label")
    if not label then return end
    local checked = SelectedSet(data.libOption)[data.libValue] == true
    label:SetText(zo_iconTextFormat(checked and CHECKED_ICON or UNCHECKED_ICON, 32, 32, data.baseText or ""))
end

local function RegisterSelectDialog()
    ZO_Dialogs_RegisterCustomDialog(SELECT_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = DialogTitle },
        setup = function(dialog)
            local opt = dialog.data and dialog.data.libOption
            local choices = GetChoices(opt)
            local currentIndex = FindChoiceIndex(opt, GetValue(opt))
            local list = {}
            for i = 1, #choices do
                local choice = choices[i]
                local name = ChoiceName(choice)
                list[#list + 1] = {
                    template = "ZO_GamepadMenuEntryTemplate",
                    templateData = {
                        text = name,
                        baseText = name,
                        isCurrent = (i == currentIndex),
                        setup = SelectEntrySetup,
                        callback = function()
                            ReleaseDialog(SELECT_DIALOG)
                            S.SetOption(opt, ChoiceValue(choice))
                        end,
                    },
                }
            end
            dialog.info.parametricList = list
            dialog:setupFunc()
            SelectTargetIndex(dialog, currentIndex or 1)
        end,
        blockDialogReleaseOnPress = true,
        buttons = {
            DialogPrimaryButton(),
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function() ReleaseDialog(SELECT_DIALOG) end,
            },
        },
    })
end

local function RegisterChecklistDialog()
    ZO_Dialogs_RegisterCustomDialog(CHECKLIST_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = DialogTitle },
        setup = function(dialog)
            local opt = dialog.data and dialog.data.libOption
            local choices = GetChoices(opt)
            local list = {}
            for i = 1, #choices do
                local choice = choices[i]
                local name = ChoiceName(choice)
                local value = ChoiceValue(choice)
                list[#list + 1] = {
                    template = "ZO_GamepadMenuEntryTemplate",
                    templateData = {
                        text = name,
                        baseText = name,
                        libOption = opt,
                        libValue = value,
                        setup = ChecklistEntrySetup,
                        callback = function(dialogRef)
                            local set = SelectedSet(opt)
                            if set[value] then set[value] = nil else set[value] = true end
                            local values = {}
                            for j = 1, #choices do
                                local v = ChoiceValue(choices[j])
                                if set[v] then values[#values + 1] = v end
                            end
                            PlaySound(SOUNDS.DEFAULT_CLICK)
                            S.SetOption(opt, values)
                            if dialogRef and dialogRef.entryList then
                                dialogRef.entryList:RefreshVisible()
                            end
                        end,
                    },
                }
            end
            dialog.info.parametricList = list
            dialog:setupFunc()
            SelectTargetIndex(dialog, 1)
        end,
        blockDialogReleaseOnPress = true,
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_TOGGLE_OPTION,
                callback = function(dialog)
                    local targetData = dialog.entryList and dialog.entryList:GetTargetData()
                    if targetData and targetData.callback then
                        targetData.callback(dialog)
                    end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_GAMEPAD_BACK_OPTION,
                callback = function() ReleaseDialog(CHECKLIST_DIALOG) end,
            },
        },
    })
end

local function RegisterTextDialog()
    ZO_Dialogs_RegisterCustomDialog(TEXT_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = DialogTitle },
        setup = function(dialog)
            dialog.info.parametricList = {
                {
                    template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                    templateData = {
                        nameField = true,
                        textChangedCallback = function(control)
                            if dialog.data then
                                dialog.data.text = control:GetText()
                            end
                        end,
                        setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                            control.highlight:SetHidden(not selected)
                            control.editBoxControl.textChangedCallback = data.textChangedCallback
                            if control.editBoxControl.SetMaxInputChars then
                                control.editBoxControl:SetMaxInputChars(TEXT_MAX_CHARS)
                            end
                            if control.editBoxControl.SetDefaultText then
                                control.editBoxControl:SetDefaultText("")
                            end
                            control.editBoxControl:SetText((dialog.data and dialog.data.text) or "")
                            data.control = control
                        end,
                        callback = function(dialogRef)
                            local targetData = dialogRef.entryList:GetTargetData()
                            if targetData and targetData.control and targetData.control.editBoxControl and targetData.control.editBoxControl.TakeFocus then
                                targetData.control.editBoxControl:TakeFocus()
                            end
                        end,
                        narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
                    },
                },
                {
                    template = "ZO_GamepadTextFieldSubmitItem",
                    templateData = {
                        text = "Apply",
                        setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                            ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
                        end,
                        callback = function(dialogRef)
                            local opt = dialogRef.data and dialogRef.data.libOption
                            local text = (dialogRef.data and dialogRef.data.text) or ""
                            ReleaseDialog(TEXT_DIALOG)
                            S.SetOption(opt, text)
                        end,
                    },
                },
            }
            dialog:setupFunc()
        end,
        blockDialogReleaseOnPress = true,
        buttons = {
            DialogPrimaryButton(),
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function() ReleaseDialog(TEXT_DIALOG) end,
            },
        },
    })
end

local function RegisterDefaultsDialog()
    ZO_Dialogs_RegisterCustomDialog(DEFAULTS_DIALOG, {
        mustChoose = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = SI_OPTIONS_RESET_TITLE },
        mainText = {
            text = function()
                return "Reset the settings on " .. S.PageTitle() .. " to their defaults?"
            end,
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_OPTIONS_RESET,
                callback = function() S.ResetPage() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
            },
        },
    })
end

local function RegisterConfirmDialog()
    ZO_Dialogs_RegisterCustomDialog(CONFIRM_DIALOG, {
        mustChoose = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = SI_OPTIONS_RESET_TITLE },
        mainText = {
            text = function()
                return ResolveText(S.confirmOption and S.confirmOption.confirm)
            end,
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_OPTIONS_RESET,
                callback = function()
                    local opt = S.confirmOption
                    S.confirmOption = nil
                    if opt and type(opt.func) == "function" then opt.func() end
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                    S.InvalidateAll()
                    S.RefreshAll()
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function() S.confirmOption = nil end,
            },
        },
    })
end

--------------------------------------------------
-- Last Page
--------------------------------------------------
local function LastPageStore()
    local menu = S.menu
    if not menu or Resolve(menu.rememberPage) ~= true then return nil end
    local store = Resolve(menu.lastPage)
    if type(store) ~= "table" then return nil end
    return store
end

function S.SaveLastPage()
    local store = LastPageStore()
    if not store or not S.settingsList then return end
    store.cat = S.categoryIndex
    store.pane = S.pane
    local rows = store.rows
    if type(rows) ~= "table" then
        rows = {}
        store.rows = rows
    end
    for i = #rows, 1, -1 do rows[i] = nil end
    local depth = #S.stack
    for i = 1, depth - 1 do
        rows[i] = S.stack[i].index or 1
    end
    if depth > 0 then
        rows[depth] = S.settingsList:GetSelectedIndex()
    end
end

function S.RestoreLastPage()
    local store = LastPageStore()
    if not store then return false end
    local cat = tonumber(store.cat)
    if not cat or cat < 1 or cat > #S.categories then return false end
    if cat ~= S.categoryIndex then
        S.categoryIndex = cat
        S.BuildCategories()
    end
    local rows = type(store.rows) == "table" and store.rows or {}
    local depth = #rows
    for level = 1, depth - 1 do
        local page = S.CurrentPage()
        local entry = S.PageEntries(page)[tonumber(rows[level]) or 0]
        local opt = entry and entry.libOption
        if not (opt and opt.type == "submenu" and not IsDisabled(opt)) then break end
        page.index = rows[level]
        S.stack[#S.stack + 1] = { option = opt, index = 1 }
    end
    local top = S.CurrentPage()
    if top and #S.stack == depth then
        top.index = tonumber(rows[depth]) or 1
    end
    S.BuildSettings()
    return store.pane == PANE_SETTINGS and S.settingsList:GetNumItems() > 0
end

--------------------------------------------------
-- Scene
--------------------------------------------------
function S.IsShowing()
    local panel = S.panel
    return panel ~= nil and panel.scene ~= nil and panel.scene:IsShowing()
end

function S.Activate(panel)
    S.panel = panel
    S.menu = panel.menu
    S.categories = panel.categories
    S.categoryIndex = panel.categoryIndex or 1
end

function S.BuildCategories()
    local list = S.categoryList
    list:Clear()
    for i = 1, #S.categories do
        local data = S.categoryEntries[i]
        if not data then
            data = { libOption = S.categories[i], libIndex = i }
            S.categoryEntries[i] = data
        end
        list:AddEntry(data)
    end
    local wanted = S.categoryIndex
    list:Commit()
    if wanted < 1 or wanted > #S.categories then wanted = 1 end
    if #S.categories > 0 then
        list:SetSelectedIndexWithoutAnimation(wanted)
    end
    S.ResetToCategory(wanted)
end

function S.OnShowing()
    RefreshAccent()
    S.pane = PANE_CATEGORIES
    S.waitRelease = false
    S.InvalidateAll()
    S.UpdateFonts()
    S.UpdateOpacity()
    S.ApplyLayout()
    S.RefreshHeader()
    S.RefreshPaneVisuals()
    S.RaisePreviews(true)
    S.settingsList:Deactivate()
    S.BuildCategories()
    if S.RestoreLastPage() then
        S.pane = PANE_SETTINGS
        S.RefreshPaneVisuals()
        S.settingsList:Activate()
    else
        S.categoryList:Activate()
    end
    S.ActivateInput()
    if not S.keybindsAdded then
        S.activeKeybinds = S.PanelKeybinds(S.panel)
        KEYBIND_STRIP:AddKeybindButtonGroup(S.activeKeybinds)
        S.keybindsAdded = true
        ZO_ClearTable(S.keybindState)
    end
    S.RefreshAll()
end

function S.OnHidden()
    S.SaveLastPage()
    if S.panel then S.panel.categoryIndex = S.categoryIndex end
    if S.categoryList then S.categoryList:Deactivate() end
    if S.settingsList then S.settingsList:Deactivate() end
    S.DeactivateInput()
    if S.keybindsAdded then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(S.activeKeybinds)
        S.keybindsAdded = false
    end
    S.RaisePreviews(false)
    if S.refreshPending then
        EVENT_MANAGER:UnregisterForUpdate(REFRESH_UPDATE_NAME)
        S.refreshPending = false
    end
    S.ReleaseData()
end

local function ReleaseSettingRow(row)
    local parts = row.libParts
    if not parts then return end
    ReleaseTexture(parts.icon)
    ReleaseTexture(parts.preview)
    row.libIconShown = nil
end

local function ReleaseCategoryRow(row)
    ReleaseTexture(CategoryParts(row).icon)
end

function S.ReleaseData()
    S.detailsOption = nil
    HideItemTip()
    if S.categoryList then S.categoryList:Release(ReleaseCategoryRow) end
    if S.settingsList then S.settingsList:Release(ReleaseSettingRow) end
    ReleaseTexture(PvPUAPatchLib_WindowRootFrameDetailsPreview)
    PvPUAPatchLib_WindowRootFrameDetailsSample:SetText("")
    PvPUAPatchLib_WindowRootFrameDetailsSample:SetHidden(true)
    if S.barParts then
        ReleaseTexture(S.barParts.icon)
        S.barParts.left:SetText("")
        S.barParts.right:SetText("")
        S.barParts.bar:SetHidden(true)
    end
    PvPUAPatchLib_WindowRootFrameDetailsName:SetText("")
    PvPUAPatchLib_WindowRootFrameDetailsNumber:SetText("")
    PvPUAPatchLib_WindowRootFrameDetailsNumber:SetHidden(true)
    PvPUAPatchLib_WindowRootFrameDetailsBody:SetText("")
    for i = #S.stack, 1, -1 do S.stack[i] = nil end
    ZO_ClearTable(S.pageEntries)
    ZO_ClearTable(S.rootPages)
    ZO_ClearTable(S.categoryEntries)
    ZO_ClearTable(S.keybindState)
end

function S.ApplyLayout()
    local frame = PvPUAPatchLib_WindowRootFrame
    local rootW, rootH = GuiRoot:GetDimensions()
    if type(rootW) ~= "number" or rootW <= 0 then rootW = 1920 end
    if type(rootH) ~= "number" or rootH <= 0 then rootH = 1080 end

    local availW = rootW - FRAME_SIDE_MARGIN * 2
    local footer = (tonumber(ZO_KEYBIND_STRIP_GAMEPAD_VISUAL_HEIGHT) or 125) + FRAME_FOOTER_GAP
    local availH = rootH - FRAME_TOP - footer

    local scale = 1
    if availW < FRAME_WIDTH then scale = availW / FRAME_WIDTH end
    if availH < (PANE_TOP + PANE_MIN_HEIGHT) * scale then
        scale = availH / (PANE_TOP + PANE_MIN_HEIGHT)
    end

    local frameH = availH / scale
    local paneH = frameH - PANE_TOP
    local listH = paneH - LIST_INSET

    frame:SetScale(scale)
    frame:SetDimensions(FRAME_WIDTH, frameH)

    PvPUAPatchLib_WindowRootFrameCategories:SetHeight(paneH)
    PvPUAPatchLib_WindowRootFrameSettings:SetHeight(paneH)
    PvPUAPatchLib_WindowRootFrameDetails:SetHeight(paneH)
    S.categoryList:SetHeight(listH)
    S.settingsList:SetHeight(listH)
end

local function CreateLists()
    S.categoryList = FixedList.New(PvPUAPatchLib_WindowRootFrameCategoriesList, CATEGORY_TEMPLATE,
        CATEGORY_ROW_HEIGHT, ROW_GAP, PvPUAPatchLib_WindowRootFrameCategoriesUpArrow, PvPUAPatchLib_WindowRootFrameCategoriesDownArrow)
    S.categoryList:SetSetup(CategoryRowSetup)
    S.categoryList:SetOnRowCreated(function(row)
        SetReleasable(CategoryParts(row).icon)
    end)
    S.categoryList:SetOnSelectedDataChangedCallback(function(_, data)
        S.OnCategorySelected(data)
    end)

    S.settingsList = FixedList.New(PvPUAPatchLib_WindowRootFrameSettingsList, ROW_TEMPLATE,
        SETTING_ROW_HEIGHT, ROW_GAP, PvPUAPatchLib_WindowRootFrameSettingsUpArrow, PvPUAPatchLib_WindowRootFrameSettingsDownArrow)
    S.settingsList:SetSetup(SettingRowSetup)
    S.settingsList:SetCanSelect(function(data)
        return data.libOption == nil or data.libOption.type ~= "header"
    end)
    S.settingsList:SetOnRowCreated(function(row)
        local parts = RowParts(row)
        SetReleasable(parts.icon)
        SetReleasable(parts.preview)
    end)
    S.settingsList:SetOnSelectedDataChangedCallback(function()
        if S.pane == PANE_SETTINGS then
            S.RefreshDetails()
            S.RefreshKeybinds()
        end
    end)

    SetReleasable(PvPUAPatchLib_WindowRootFrameDetailsPreview)
end


local function EnsureShared()
    if S.registered then return end
    S.registered = true
    S.horizontal = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)
    S.vertical = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_VERTICAL)
    S.fragment = ZO_FadeSceneFragment:New(PvPUAPatchLib_WindowRoot)
    CreateLists()
    RegisterSelectDialog()
    RegisterChecklistDialog()
    RegisterTextDialog()
    RegisterDefaultsDialog()
    RegisterConfirmDialog()
end

local function BuildPanelCategories(panel)
    local categories = {}
    local loose = {}
    local options = Resolve(panel.menu.options) or {}
    for i = 1, #options do
        local opt = options[i]
        if type(opt) == "table" then
            if opt.type == "submenu" then
                categories[#categories + 1] = opt
            elseif SUPPORTED[opt.type] then
                loose[#loose + 1] = opt
            end
        end
    end
    if #loose > 0 then
        table.insert(categories, 1, { type = "submenu", name = "General", options = loose })
    end
    panel.categories = categories
end

local function CreateScene(panel)
    local scene = SCENE_MANAGER:GetScene(panel.SCENE_NAME)
    if not scene then
        scene = ZO_Scene:New(panel.SCENE_NAME, SCENE_MANAGER)
    end
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_OPTIONS)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(S.fragment)
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            if type(panel.menu.options) == "function" then BuildPanelCategories(panel) end
            S.Activate(panel)
            S.OnShowing()
        elseif newState == SCENE_HIDDEN then
            if S.panel == panel then S.OnHidden() end
            local onHidden = panel.menu.onHidden
            if type(onHidden) == "function" then pcall(onHidden) end
        end
    end)
    panel.scene = scene
end

--------------------------------------------------
-- Panel
--------------------------------------------------
local Panel = {}
Panel.__index = Panel

function Panel:IsActive()
    return S.panel == self
end

function Panel:IsShowing()
    return self.scene ~= nil and self.scene:IsShowing()
end

function Panel:Open()
    if SCENE_MANAGER and self.scene then
        SCENE_MANAGER:Push(self.SCENE_NAME)
    end
end

function Panel:Refresh()
    if S.panel ~= self then return end
    S.InvalidateAll()
    S.RefreshAll()
end

function Panel:SelectRow(index)
    if S.panel ~= self then return end
    local list = S.settingsList
    if not list or not S.IsShowing() then return end
    local count = list:GetNumItems()
    if count == 0 then return end
    if index < 1 then index = 1 end
    if index > count then index = count end
    list:SetSelectedIndexWithoutAnimation(index)
    S.RefreshAll()
end

function Panel:ApplyTextSize()
    if S.panel ~= self then return end
    S:ApplyTextSize()
end

function Panel:ApplyOpacity()
    if S.panel ~= self then return end
    S:ApplyOpacity()
end

function Panel:GetSelectedOption()
    if S.panel ~= self or not S.IsShowing() or S.pane ~= PANE_SETTINGS then return nil end
    return S.SelectedOption()
end

function Panel:RefreshKeybinds()
    if S.panel ~= self or not S.keybindsAdded then return end
    KEYBIND_STRIP:UpdateKeybindButtonGroup(S.activeKeybinds)
end

function Panel:RefreshPages()
    if S.panel ~= self or not S.IsShowing() then return end
    ZO_ClearTable(S.pageEntries)
    local top = S.CurrentPage()
    if top and S.settingsList then top.index = S.settingsList:GetSelectedIndex() end
    S.InvalidateAll()
    S.BuildSettings()
    S.RefreshAll()
end

function Panel:SelectNextHeader()
    if S.panel ~= self or not S.IsShowing() then return false end
    local list = S.settingsList
    if not list then return false end
    local entries = list.entries
    local count = #entries
    local current = list:GetSelectedIndex()
    local function IsHeader(index)
        local data = entries[index]
        return data ~= nil and data.libOption ~= nil and data.libOption.type == "header"
    end
    local target
    for i = current + 1, count do
        if IsHeader(i) then target = i break end
    end
    if not target then
        for i = 1, current do
            if IsHeader(i) then target = i break end
        end
    end
    if not target then return false end
    local row = list:FindSelectable(target, 1)
    if not row then return false end
    list:SetSelectedIndexWithoutAnimation(row)
    list.firstIndex = target
    list:KeepSelectionVisible()
    list:RefreshVisible()
    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    S.RefreshAll()
    return true
end

function Panel:ApplyAccent()
    if S.panel ~= self then return end
    S:ApplyAccent()
end

--------------------------------------------------
-- API
--------------------------------------------------
L.panels = L.panels or {}
L.panelList = L.panelList or {}

function L:RegisterSettings(menuData)
    if type(menuData) ~= "table" then return nil end
    local name = menuData.name
    if type(name) ~= "string" or name == "" then return nil end
    if L.panels[name] then return L.panels[name] end

    EnsureShared()

    local panel = setmetatable({
        name = name,
        menu = menuData,
        SCENE_NAME = SCENE_PREFIX .. name,
        categoryIndex = 1,
    }, Panel)
    BuildPanelCategories(panel)
    CreateScene(panel)

    L.panels[name] = panel
    L.panelList[#L.panelList + 1] = panel
    if L.PlaceInMenu then L.PlaceInMenu(panel) end
    return panel
end
