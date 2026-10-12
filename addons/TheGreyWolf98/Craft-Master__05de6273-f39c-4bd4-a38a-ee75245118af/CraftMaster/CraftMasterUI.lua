local CM = CraftMaster
local WM = WINDOW_MANAGER
local FONT = "$(MEDIUM_FONT)|26|soft-shadow-thin"
local TITLE_FONT = "$(BOLD_FONT)|34|soft-shadow-thick"
local ROW = 43
local QUALITY = { [0] = "999999", [1] = "eeeeee", [2] = "70d85a", [3] = "66b7ff", [4] = "c38bff", [5] = "ffd45c" }
local FILTERS = { "All", "Learned", "Missing", "Not checked" }
local TABS = { "Housing", "Recipes", "Motifs" }
local KINDS = { "housing", "recipes", "motifs" }
local function label(parent, text, x, y, w, h, font)
    local c = WM:CreateControl(nil, parent, CT_LABEL)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(w, h)
    c:SetFont(font or FONT)
    c:SetText(text or "")
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return c
end
local function backdrop(parent, x, y, w, h, r, g, b, a)
    local c = WM:CreateControl(nil, parent, CT_BACKDROP)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(w, h)
    c:SetCenterColor(r, g, b, a)
    c:SetEdgeColor(.3, .4, .5, .7)
    return c
end
local function button(parent, text, x, y, w, callback)
    local c = WM:CreateControl(nil, parent, CT_BUTTON)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(w, 42)
    backdrop(c, 0, 0, w, 42, .13, .18, .24, 1)
    local t = label(c, text, 8, 0, w - 16, 42)
    t:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c:SetHandler("OnClicked", callback)
    return c, t
end
function CM:Characters()
    local ids = {}
    for id in pairs(self.sv.characters) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return self.sv.characters[a].name < self.sv.characters[b].name end)
    return ids
end
function CM:CycleCharacter()
    local ids = self:Characters()
    for i, id in ipairs(ids) do
        if id == self.viewCharacter then self.viewCharacter = ids[i % #ids + 1]; self:Refresh(); return end
    end
    self.viewCharacter = ids[1]
    self:Refresh()
end
function CM:CycleFilter()
    self.filter = self.filter % #FILTERS + 1
    self.selected, self.page = 1, 1
    self:Refresh()
end
function CM:CycleTab()
    self.tab = self.tab % #TABS + 1
    self.category, self.selected, self.page, self.categorySelected, self.expandedCategory = nil, 1, 1, 1, nil
    self:Refresh()
end
function CM:Categories()
    local items = { { name = "All " .. TABS[self.tab]:lower(), id = nil } }
    if self.tab == 1 then
        local parents = {}
        for i = 1, GetNumFurnitureCategories() do
            local id = GetFurnitureCategoryId(i)
            local name = GetFurnitureCategoryInfo(id)
            if name and name ~= "" then parents[#parents + 1] = { id = id, name = name, categoryIndex = i } end
        end
        table.sort(parents, function(a, b) return a.name < b.name end)
        for _, parent in ipairs(parents) do
            items[#items + 1] = parent
            if self.expandedCategory == parent.id then
                local children = {}
                for j = 1, GetNumFurnitureSubcategories(parent.categoryIndex) do
                    local id = GetFurnitureSubcategoryId(parent.categoryIndex, j)
                    local name = GetFurnitureCategoryInfo(id)
                    if name and name ~= "" then children[#children + 1] = { id = id, name = "  " .. name, parent = parent.id } end
                end
                table.sort(children, function(a, b) return a.name < b.name end)
                for _, child in ipairs(children) do items[#items + 1] = child end
            end
        end
        items[#items + 1] = { id = -1, name = "Uncategorised" }
    elseif self.tab == 2 then
        items[#items + 1] = { id = ITEMTYPE_FOOD, name = "Food" }
        items[#items + 1] = { id = ITEMTYPE_DRINK, name = "Drink" }
    end
    return items
end
function CM:Matches(e, query)
    if e.kind ~= KINDS[self.tab] then return false end
    if query ~= "" then
        if not (self.searchNames[e.key] or self:Lower(e.name)):find(query, 1, true) then return false end
    elseif self.category then
        if self.tab == 1 then
            if self.category == -1 then
                if e.category then return false end
            elseif e.category ~= self.category and e.subcategory ~= self.category then return false end
        elseif self.tab == 2 then
            if GetItemLinkItemType(self:Link(e.resultId)) ~= self.category then return false end
        end
    end
    local known = self:Knowledge(e.key, self.viewCharacter)
    if self.filter == 2 then return known == true end
    if self.filter == 3 then return known == false end
    if self.filter == 4 then return known == nil end
    return true
end
function CM:BuildResults()
    local results, query = {}, self:Lower(self.search:GetText()):match("^%s*(.-)%s*$")
    for _, entry in pairs(self.sv.catalog) do
        if self:Matches(entry, query) then results[#results + 1] = entry end
    end
    table.sort(results, function(a, b) return a.name < b.name end)
    self.results = results
    self.selected = math.max(1, math.min(self.selected, #results))
    self.page = math.floor((self.selected - 1) / self.rowCount) + 1
end
function CM:UpdateSummary()
    local c = self.sv.characters[self.viewCharacter]
    local main = self.sv.characters[self.sv.main]
    self.characterLabel:SetText("Viewing: " .. (c and c.name or "none") .. (self.viewCharacter == self.sv.main and " |c66ee88[Main]|r" or ""))
    local stamp = c and c.lastScan and GetDateStringFromTimestamp(c.lastScan) or "not scanned"
    if self.scanning then stamp = "Scanning " .. (self.sv.characters[self.scanCharacter].name or "") .. ": " .. self.scanCount end
    self.summary:SetText("Trader main: " .. (main and main.name or "none") .. "  |  " .. stamp)
end
function CM:Refresh(rebuild)
    if not self.window then return end
    if rebuild ~= false then
        self.categories = self:Categories()
        self:BuildResults()
    end
    self.page = math.floor((self.selected - 1) / self.rowCount) + 1
    self:UpdateSummary()
    self.filterLabel:SetText("Filter: " .. FILTERS[self.filter])
    self.tabLabel:SetText(TABS[self.tab])
    self.focusLabel:SetText("Categories [left stick]")
    self.pages:SetText(#self.results .. " results  |  Page " .. self.page .. "/" .. math.max(1, math.ceil(#self.results / self.rowCount)))
    local offset = math.max(0, self.categorySelected - self.rowCount)
    for i, row in ipairs(self.categoryRows) do
        local cat = self.categories[offset + i]
        row.index = offset + i
        row.control:SetHidden(cat == nil)
        if cat then
            local selected = row.index == self.categorySelected
            row.background:SetCenterColor(selected and .16 or .06, selected and .25 or .09, selected and .34 or .13, 1)
            row.text:SetText((self.category == cat.id and "|c80c8ff> " or "") .. cat.name .. "|r")
        end
    end
    for i, row in ipairs(self.resultRows) do
        local index = (self.page - 1) * self.rowCount + i
        local e = self.results[index]
        row.index = index
        row.control:SetHidden(e == nil)
        if e then
            row.background:SetCenterColor(index == self.selected and .16 or .055, index == self.selected and .24 or .075, index == self.selected and .32 or .105, 1)
            row.text:SetText("|c" .. (QUALITY[e.quality] or "eeeeee") .. e.name .. "|r")
            row.status:SetText(self:Status(e.key, self.viewCharacter, false))
        end
    end
    self:UpdateDetail()
end
function CM:UpdateDetail()
    local e = self.results[self.selected]
    if not e then
        self.detail:SetText(self.scanning and "Building the catalogue. Scanning pauses during combat."
            or "No matches. Try All, clear the search, or log in the crafter and use /cm scan.")
        return
    end
    local location = ""
    if e.category then
        local name = GetFurnitureCategoryInfo(e.category)
        location = name or ""
        if e.subcategory and e.subcategory ~= e.category then
            local sub = GetFurnitureCategoryInfo(e.subcategory)
            if sub and sub ~= "" then location = location .. " / " .. sub end
        end
    end
    local text = e.name .. "  -  " .. self:Status(e.key, self.viewCharacter, true)
    if location ~= "" then text = text .. "\n" .. location end
    if e.kind ~= "motifs" then
        text = text .. "\nLearned status records the plan; materials and crafting passives still apply."
    end
    self.detail:SetText(text)
end
function CM:MoveSelection(delta)
    self.categorySelected = math.max(1, math.min(#self.categories, self.categorySelected + delta))
    self:Refresh(false)
end
function CM:Page(delta)
    local lastPage = math.max(1, math.ceil(#self.results / self.rowCount))
    local page = math.max(1, math.min(lastPage, self.page + delta))
    self.selected = (page - 1) * self.rowCount + 1
    self:Refresh(false)
end
function CM:Select()
    local cat = self.categories[self.categorySelected]
    if not cat then return end
    self.category, self.selected = cat.id, 1
    if self.tab == 1 and cat.id and cat.id > 0 then self.expandedCategory = cat.parent or cat.id end
    self.search:SetText("")
    self:Refresh()
    -- Expanded children change list indices. Keep the cursor on the chosen category.
    for i, candidate in ipairs(self.categories) do
        if candidate.id == cat.id then self.categorySelected = i; break end
    end
    self:Refresh(false)
end
function CM:ShowSelectedDetail()
    local e = self.results[self.selected]
    if not e then return end
    if e.kind == "motifs" then
        self:Message(e.name .. " - " .. self:Status(e.key, self.viewCharacter, false))
    elseif GAMEPAD_TOOLTIPS and IsInGamepadPreferredMode() then
        GAMEPAD_TOOLTIPS:LayoutItem(GAMEPAD_RIGHT_TOOLTIP, self:Link(e.resultId))
    elseif PopupTooltip then
        InitializeTooltip(PopupTooltip, self.window, RIGHT, 12, 0, LEFT)
        PopupTooltip:SetLink(self:Link(e.resultId))
    end
end
function CM:UpdateDirectionalInput()
    if self.search:HasFocus() then return end
    local now = GetFrameTimeMilliseconds()
    -- Only the physical left stick is queried. Its navigation stays in categories.
    local _, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK_NO_KEYBOARD)
    DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK)
    if math.abs(y) < .35 then self.nextInput = 0; return end
    if now < (self.nextInput or 0) then return end
    self.nextInput = now + 180
    self:MoveSelection(y > 0 and -1 or 1)
end
function CM:SearchFocus()
    self.search:TakeFocus()
end
function CM:CreateWindow()
    self.tab, self.filter, self.selected, self.page, self.categorySelected = 1, 1, 1, 1, 1
    self.focus = "categories"
    local w = math.min(1450, GuiRoot:GetWidth() - 80)
    local h = math.min(870, GuiRoot:GetHeight() - 90)
    local left, gap = 300, 18
    local listX, listY = left + gap + 20, 228
    self.rowCount = math.max(4, math.floor((h - listY - 168) / ROW))
    local panel = WM:CreateTopLevelWindow("CraftMasterWindow")
    self.window = panel
    panel:SetDimensions(w, h)
    panel:SetAnchor(CENTER, GuiRoot, CENTER)
    panel:SetHidden(true)
    panel:SetMouseEnabled(true)
    backdrop(panel, 0, 0, w, h, .025, .035, .055, .98)
    label(panel, "CRAFT MASTER", 24, 12, 500, 48, TITLE_FONT)
    label(panel, "by @TheGreyWolf98", w - 370, 16, 345, 40)
    self.characterLabel = label(panel, "", 24, 63, w - 470, 36)
    self.characterLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.summary = label(panel, "", 24, 99, w - 48, 35, "$(MEDIUM_FONT)|23|soft-shadow-thin")
    self.summary:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    button(panel, "Character", w - 434, 62, 180, function() self:CycleCharacter() end)
    button(panel, "Set as main", w - 244, 62, 220, function() self:SetMain(self.viewCharacter) end)
    backdrop(panel, 24, 148, w - 445, 44, .11, .15, .20, 1)
    local search = WM:CreateControl("CraftMasterSearch", panel, CT_EDITBOX)
    self.search = search
    search:SetAnchor(TOPLEFT, panel, TOPLEFT, 35, 150)
    search:SetDimensions(w - 470, 40)
    search:SetFont(FONT)
    search:SetMaxInputChars(120)
    search:SetMouseEnabled(true)
    self.searchHint = label(panel, "Search furnishings or recipes...", 35, 150, w - 470, 40)
    self.searchHint:SetColor(.6, .65, .7, 1)
    search:SetHandler("OnTextChanged", function()
        self.searchHint:SetHidden(search:GetText() ~= "" or search:HasFocus())
        local EM = EVENT_MANAGER -- debounce using the game's scheduler
        EM:UnregisterForUpdate(self.name .. "Search")
        EM:RegisterForUpdate(self.name .. "Search", 150, function()
            EM:UnregisterForUpdate(self.name .. "Search")
            self.selected = 1
            self:RefreshIfVisible()
        end)
    end)
    search:SetHandler("OnFocusGained", function()
        self.searchHint:SetHidden(true)
        if IsInGamepadPreferredMode() then ZO_GamepadEditBox_FocusGained(search) end
    end)
    search:SetHandler("OnFocusLost", function()
        if IsInGamepadPreferredMode() then ZO_GamepadEditBox_FocusLost(search) end
        self.searchHint:SetHidden(search:GetText() ~= "")
    end)
    search:SetHandler("OnEnter", function() search:LoseFocus(); self:Refresh() end)
    search:SetHandler("OnEscape", function() search:LoseFocus() end)
    local _, filterLabel = button(panel, "", w - 410, 148, 235, function() self:CycleFilter() end)
    self.filterLabel = filterLabel
    local _, tabLabel = button(panel, "Housing", w - 165, 148, 141, function() self:CycleTab() end)
    self.tabLabel = tabLabel
    self.focusLabel = label(panel, "", 24, 197, left, 30, "$(MEDIUM_FONT)|23|soft-shadow-thin")
    self.pages = label(panel, "", listX, 197, w - listX - 24, 30, "$(MEDIUM_FONT)|23|soft-shadow-thin")
    self.categoryRows, self.resultRows = {}, {}
    for i = 1, self.rowCount do
        local y = listY + (i - 1) * ROW
        local row = {}
        row.control = WM:CreateControl(nil, panel, CT_BUTTON)
        row.control:SetAnchor(TOPLEFT, panel, TOPLEFT, 24, y)
        row.control:SetDimensions(left, ROW - 3)
        row.background = backdrop(row.control, 0, 0, left, ROW - 3, .06, .09, .13, 1)
        row.text = label(row.control, "", 10, 0, left - 20, ROW - 3)
        row.text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.control:SetHandler("OnClicked", function()
            self.categorySelected = row.index; self.focus = "categories"; self:Select()
        end)
        self.categoryRows[i] = row
        local result = {}
        result.control = WM:CreateControl(nil, panel, CT_BUTTON)
        result.control:SetAnchor(TOPLEFT, panel, TOPLEFT, listX, y)
        local width = w - listX - 24
        result.control:SetDimensions(width, ROW - 3)
        result.background = backdrop(result.control, 0, 0, width, ROW - 3, .05, .075, .105, 1)
        result.text = label(result.control, "", 12, 0, width - 170, ROW - 3)
        result.text:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        result.status = label(result.control, "", width - 155, 0, 145, ROW - 3)
        result.control:SetHandler("OnClicked", function()
            self.selected = result.index; self:Refresh(false)
        end)
        self.resultRows[i] = result
    end
    local detailY = listY + self.rowCount * ROW + 7
    self.detail = label(panel, "", 24, detailY, w - 48, 112, "$(MEDIUM_FONT)|24|soft-shadow-thin")
    self.detail:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label(panel, "Stick: categories  |  A: choose  |  LT: tab  |  RT: set main  |  LB/RB: pages", 24, h - 35, w - 48, 30, "$(MEDIUM_FONT)|21|soft-shadow-thin")
    panel:SetHandler("OnMouseWheel", function(_, delta) self:MoveSelection(-delta) end)
    self.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        { name = "Category", keybind = "UI_SHORTCUT_PRIMARY", callback = function() self:Select() end },
        { name = "Filter", keybind = "UI_SHORTCUT_SECONDARY", callback = function() self:CycleFilter() end },
        { name = "Character", keybind = "UI_SHORTCUT_TERTIARY", callback = function() self:CycleCharacter() end },
        { name = "Search", keybind = "UI_SHORTCUT_QUATERNARY", callback = function() self:SearchFocus() end },
        { name = "Prev", keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() self:Page(-1) end },
        { name = "Next", keybind = "UI_SHORTCUT_RIGHT_SHOULDER", callback = function() self:Page(1) end },
        { name = "Tab", keybind = "UI_SHORTCUT_LEFT_TRIGGER", callback = function() self:CycleTab() end },
        { name = "Set main", keybind = "UI_SHORTCUT_RIGHT_TRIGGER", callback = function() self:SetMain(self.viewCharacter) end },
        { name = "Back", keybind = "UI_SHORTCUT_NEGATIVE", callback = function() SCENE_MANAGER:HideCurrentScene() end },
    }
    local scene = ZO_Scene:New("craftMaster", SCENE_MANAGER)
    self.scene = scene
    scene:AddFragment(ZO_SimpleSceneFragment:New(panel))
    if IsInGamepadPreferredMode() then
        if GAMEPAD_UI_MODE_FRAGMENT then scene:AddFragment(GAMEPAD_UI_MODE_FRAGMENT) end
        if KEYBIND_STRIP_GAMEPAD_FRAGMENT then scene:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) end
        if KEYBIND_STRIP_GAMEPAD_BACKDROP_FRAGMENT then scene:AddFragment(KEYBIND_STRIP_GAMEPAD_BACKDROP_FRAGMENT) end
    else
        if MOUSE_UI_MODE_FRAGMENT then scene:AddFragment(MOUSE_UI_MODE_FRAGMENT) end
        if KEYBIND_STRIP_FADE_FRAGMENT then scene:AddFragment(KEYBIND_STRIP_FADE_FRAGMENT) end
    end
    -- Action layers are pushed in fragment order. GamepadUIMode blocks
    -- fallthrough, so the shortcut layer must be pushed after that blocker.
    if UI_SHORTCUTS_ACTION_LAYER_FRAGMENT then scene:AddFragment(UI_SHORTCUTS_ACTION_LAYER_FRAGMENT) end
    scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            self.viewCharacter = self.sv.main or self.viewCharacter
            self:Refresh()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
            DIRECTIONAL_INPUT:Activate(self, panel)
        elseif state == SCENE_HIDING then
            search:LoseFocus()
            DIRECTIONAL_INPUT:Deactivate(self)
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
            if GAMEPAD_TOOLTIPS then GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP) end
            if PopupTooltip then ClearTooltip(PopupTooltip) end
        end
    end)
end
function CM:Toggle()
    if not self.sv then return end
    if not self.window then self:CreateWindow() end
    if SCENE_MANAGER:IsShowing("craftMaster") then SCENE_MANAGER:HideCurrentScene()
    else SCENE_MANAGER:Show("craftMaster") end
end
