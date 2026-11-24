-- TravelWheelMenuActions.lua: A settings section whose rows follow the state.
--
-- LibHarvensAddonSettings draws a page from a fixed list of rows. A section
-- made here has a layout function instead: it names, in order, the rows that
-- apply now, and the section keeps the page's list in step with it.
--
-- What keeps a change from flickering on the console:
--   - A row is made once per key and kept, so the list's selection, which
--     follows the row object, stays where it was when rows around it change.
--   - The section's heading is kept too: the open submenu is the heading
--     object, so the list never has to go back to the page and in again.
--   - A change of rows is one redraw of the open list (the library's
--     CreateControls), on the next frame, outside the callback of the row
--     that caused it; several changes in a frame are still one redraw.
--   - A change of values only redraws the rows themselves, with no list work.
--   - Nothing is drawn while the section is not the one on screen: the list
--     is put in order and the library draws it when the section is opened.
--     That includes the time before the menu was ever opened and the time
--     after it closed, when the library still marks the page selected.

local TravelWheelMenuActions = {}

---@class TravelWheelMenuSection
---@field panel table The library's page
---@field header table The library's row for the section heading
---@field layout fun(): string[] The keys of the rows that apply now, in order
---@field makeRow fun(key: string): table The library's parameters for the row with this key
---@field rows table<string, table> The library's rows made so far, by key
---@field keys string[] The rows the page's list holds now
---@field redrawPending boolean
local Section = {}
Section.__index = Section

---@param a string[]
---@param b string[]
---@return boolean
local function SameKeys(a, b)
    if #a ~= #b then
        return false
    end
    for index = 1, #a do
        if a[index] ~= b[index] then
            return false
        end
    end
    return true
end

---@return boolean open The section's rows are the list on screen
function Section:IsOpen()
    local LAS = LibHarvensAddonSettings
    local scene, screen = LAS.scene, LAS.scrollList
    -- The library builds its scene the first time the menu opens, and leaves
    -- a page marked selected after the menu closes: the scene says whether
    -- anything is on screen.
    if not scene or not screen or not self.panel.selected or not scene:IsShowing() then
        return false
    end
    local list = screen:GetCurrentList() or screen:GetMainList()
    return list.currentSection == self.header
end

---The library's row for a key, made on first use and kept.
---@param key string
---@return table row
function Section:Row(key)
    local row = self.rows[key]
    if not row then
        local params = self.makeRow(key)
        row = LibHarvensAddonSettings.AddonSettingsControl:New(self.panel.callbackManager, params.type)
        row:SetupControl(params)
        self.rows[key] = row
    end
    return row
end

---Put the page's list of rows in order: the rows after the heading become
---the ones these keys name.
---@param keys string[]
function Section:Apply(keys)
    local settings = self.panel.settings
    local first
    for index, setting in ipairs(settings) do
        if setting == self.header then
            first = index + 1
        end
    end
    for _ = 1, #self.keys do
        -- A row leaving the list gives its control back as the library expects it.
        table.remove(settings, first):CleanUp()
    end
    for offset, key in ipairs(keys) do
        table.insert(settings, first + offset - 1, self:Row(key))
    end
    self.keys = keys
    self.panel:SetupSections()
end

---Redraw the open list once, with the rows that apply by now.
function Section:Redraw()
    local keys = self.layout()
    if SameKeys(keys, self.keys) then
        self:UpdateRows(nil)
        return
    end
    if not self:IsOpen() then
        self:Apply(keys)
        return
    end
    self.panel:CleanUp()
    self:Apply(keys)
    self.panel:CreateControls()
    -- The row under the cursor has a new control: the key strip gives it the
    -- stick again and shows its info.
    LibHarvensAddonSettings.scrollList:RefreshKeybinds()
end

---Redraw the values of the rows on screen. Off screen there is nothing to
---redraw: the library draws every row when the section is opened.
---@param source table|nil The row whose own callback is running: it is showing its new value already
function Section:UpdateRows(source)
    if not self:IsOpen() then
        return
    end
    for _, key in ipairs(self.keys) do
        local row = self.rows[key]
        if row ~= source then
            row:UpdateControl()
        end
    end
end

---Bring the rows in step with the layout, when it names other rows than the
---list holds. On screen that is one redraw on the next frame.
---@return boolean changed The layout names other rows
function Section:Relayout()
    local keys = self.layout()
    if SameKeys(keys, self.keys) then
        return false
    end
    if not self:IsOpen() then
        self:Apply(keys)
        return true
    end
    if not self.redrawPending then
        self.redrawPending = true
        zo_callLater(function()
            self.redrawPending = false
            self:Redraw()
        end, 0)
    end
    return true
end

---The state behind the rows changed: bring the rows in step with the layout,
---or, when the same rows apply, redraw their values.
---@param source table|nil The row whose own callback is running
function Section:Refresh(source)
    if not self:Relayout() then
        self:UpdateRows(source)
    end
end

---Add a section to a page: its heading. Its rows come with the first
---Refresh, which the caller makes once the layout can be worked out (the
---game's lists are not ready while addons load).
---@param panel table The library's page
---@param headerParams table The library's parameters for the heading (ST_SECTION)
---@param layout fun(): string[] The keys of the rows that apply now, in order
---@param makeRow fun(key: string): table The library's parameters for the row with this key
---@return TravelWheelMenuSection section
function TravelWheelMenuActions.AddSection(panel, headerParams, layout, makeRow)
    local section = setmetatable({
        panel = panel,
        header = panel:AddSetting(headerParams),
        layout = layout,
        makeRow = makeRow,
        rows = {},
        keys = {},
        redrawPending = false,
    }, Section)
    return section
end

TravelWheel.MenuActions = TravelWheelMenuActions
