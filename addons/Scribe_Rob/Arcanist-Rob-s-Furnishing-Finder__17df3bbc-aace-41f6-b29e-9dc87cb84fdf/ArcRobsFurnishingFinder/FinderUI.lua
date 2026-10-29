local F = ARFF
local U = { sceneName = "arffScene", visible = false, selected = 1, offset = 0,
    rows = {}, pool = {}, query = "", filter = 1, sortKey = "name", descending = false }
F.UI = U
local WM, EM = WINDOW_MANAGER, EVENT_MANAGER
local GOLD = { 0.91, 0.75, 0.36, 1 }
local GRAY = { 0.65, 0.65, 0.65, 1 }
local WHITE = { 0.93, 0.93, 0.90, 1 }
local FILTERS = { { "All locations", "all" }, { "Houses", "house" },
    { "Character inventories", "inventory" }, { "Bank", "bank" },
    { "Storage chests / coffers", "storage" }, { "Furniture Vault", "vault" } }
local ROWS, HEIGHT = 17, 30
local COLUMNS = { { "FURNISHING", "name", 42, 360 }, { "QTY", "count", 410, 60 },
    { "LOCATION", "location", 485, 315 }, { "CHARACTER", "character", 815, 175 },
    { "CHECKED", "checked", 1000, 125 } }

local function control(name, parent, kind, x, y, width, height)
    local c = WM:CreateControl(name, parent, kind)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, height)
    return c
end

local function label(name, parent, text, x, y, width, height, size, color, bold)
    local c = control(name, parent, CT_LABEL, x, y, width, height)
    c:SetFont((bold and "$(BOLD_FONT)|" or "$(MEDIUM_FONT)|") .. (size or 22) .. "|soft-shadow-thin")
    c:SetColor(unpack(color or WHITE))
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c:SetMaxLineCount(1)
    c:SetText(text)
    return c
end

local function button(name, parent, text, x, y, width, height, callback)
    local c = control(name, parent, CT_BUTTON, x, y, width, height)
    c:SetMouseEnabled(true)
    local bg = control(name .. "BG", c, CT_TEXTURE, 0, 0, width, height)
    bg:SetColor(0.91, 0.75, 0.36, 0.10)
    bg:SetMouseEnabled(false)
    c.text = label(name .. "Text", c, text, 5, 0, width - 10, height, 21, GOLD, true)
    c.text:SetMouseEnabled(false)
    c.text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c:SetHandler("OnClicked", callback)
    c:SetHandler("OnMouseEnter", function() bg:SetColor(0.91, 0.75, 0.36, 0.22) end)
    c:SetHandler("OnMouseExit", function() bg:SetColor(0.91, 0.75, 0.36, 0.10) end)
    return c
end

local function line(parent, y, gold)
    local c = control(nil, parent, CT_TEXTURE, 20, y, 1160, 1)
    if gold then c:SetColor(0.91, 0.75, 0.36, 0.4) else c:SetColor(0.27, 0.27, 0.27, 1) end
end

function U:Age(timestamp)
    local seconds = math.max(0, GetTimeStamp() - (timestamp or 0))
    if seconds < 60 then return "Just now" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "m ago" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. "h ago" end
    return math.floor(seconds / 86400) .. "d ago"
end

function U:CycleFilter()
    self.filter = self.filter % #FILTERS + 1
    self.selected, self.offset = 1, 0
    self:Rebuild()
end

function U:Sort(key)
    if self.sortKey == key then self.descending = not self.descending
    else self.sortKey, self.descending = key, false end
    self.selected, self.offset = 1, 0
    self:Rebuild()
end

function U:Rebuild()
    local old = self.rows[self.selected]
    local oldLocation, oldItem = old and old[1], old and old[2]
    self.rows, self.total = F:GetRows(self.query, FILTERS[self.filter][2], self.sortKey, self.descending, self.rows)
    if old then
        for i, row in ipairs(self.rows) do
            if row[1] == oldLocation and row[2] == oldItem then self.selected = i; break end
        end
    end
    self.selected = math.max(1, math.min(self.selected, #self.rows))
    self.offset = math.max(0, math.min(self.offset, #self.rows - ROWS))
    self:KeepSelectionVisible()
    self:Render()
end

function U:KeepSelectionVisible()
    if self.selected <= self.offset then self.offset = self.selected - 1 end
    if self.selected > self.offset + ROWS then self.offset = self.selected - ROWS end
    self.offset = math.max(0, self.offset)
end

function U:Move(delta)
    if #self.rows == 0 then return end
    self.selected = math.max(1, math.min(#self.rows, self.selected + delta))
    self:KeepSelectionVisible()
    self:Render()
end

function U:Render()
    if not self.window then return end
    self.filterButton.text:SetText(FILTERS[self.filter][1] .. "  >")
    for index, column in ipairs(COLUMNS) do
        local arrow = self.sortKey == column[2] and (self.descending and " v" or " ^") or ""
        self.headers[index].text:SetText(column[1] .. arrow)
    end
    for i = 1, ROWS do
        local slot, entry = self.pool[i], self.rows[self.offset + i]
        slot.root:SetHidden(not entry)
        if entry then
            slot.selection:SetHidden(self.offset + i ~= self.selected)
            slot.icon:SetTexture(entry.icon or "EsoUI/Art/Icons/icon_missing.dds")
            local quality = GetItemQualityColor(entry.quality or 1)
            slot.labels[1]:SetText(entry.name)
            slot.labels[1]:SetColor(quality:UnpackRGBA())
            slot.labels[2]:SetText(tostring(entry.count))
            slot.labels[3]:SetText(entry.location)
            slot.labels[4]:SetText(entry.character == "Account" and "--" or entry.character)
            slot.labels[5]:SetText(self:Age(entry.checked))
        end
    end
    local locations, houses, characters = 0, 0, 0
    for _, location in pairs(F.db.locations) do
        locations = locations + 1
        if location.kind == "house" then houses = houses + 1 end
        if location.kind == "inventory" then characters = characters + 1 end
    end
    self.empty:SetHidden(#self.rows > 0)
    self.empty:SetText(locations == 0 and "No locations recorded yet.\nVisit your houses, open your bank and storage, and log into each character."
        or "No matching furnishings in recorded locations.\nTry another name or location filter. Visit unrecorded locations to add their contents.")
    self.footer:SetText(string.format("|cE8C05C%d|r furnishings   |cE8C05C%d|r results   %d houses   %d characters   [%d/%d]",
        self.total or 0, #self.rows, houses, characters, #self.rows > 0 and self.selected or 0, #self.rows))
    local row = self.rows[self.selected]
    self.detail:SetText(row and (row.name .. "  |cE8C05Cx" .. row.count .. "|r  |cAAAAAA" .. row.location .. "|r") or "")
end

function U:FocusSearch()
    self.search:TakeFocus()
end

function U:Hide()
    self.search:LoseFocus()
    if SCENE_MANAGER:IsShowing(self.sceneName) then SCENE_MANAGER:HideCurrentScene() end
end

function U:Toggle()
    if SCENE_MANAGER:IsShowing(self.sceneName) then self:Hide()
    else SCENE_MANAGER:Show(self.sceneName) end
end

function U:TryRegisterHub()
    if not F.uiReady then return end
    -- Reuse the existing Tracking Tools hub when one of the user's trackers supplies it.
    local hub = ELDIBABALO_TRACKING_TOOLS
    if not self.hubRegistered and hub and hub.Register then
        hub:Register("Arc Rob's Furnishing Finder", "EsoUI/Art/TreeIcons/Gamepad/gp_tutorial_idexIcon_guilds.dds", self.sceneName)
        self.hubRegistered = true
    end
end

function U:UpdateDirectionalInput()
    if self.search:HasFocus() then return end
    -- The D-pad device calls private IsKeyDown on managed clients. The stick-only
    -- device uses GetGamepadLeftStickY without querying keyboard key states.
    local y = DIRECTIONAL_INPUT:GetY(ZO_DI_LEFT_STICK_NO_KEYBOARD)
    local direction = y > 0.45 and -1 or y < -0.45 and 1 or 0
    if direction == 0 then self.stickDirection = 0; return end
    local now = GetFrameTimeMilliseconds()
    if self.stickDirection ~= direction or now - (self.lastStickMove or 0) >= 160 then
        self:Move(direction)
        self.stickDirection, self.lastStickMove = direction, now
    end
end

function U:Initialize()
    local win = WM:CreateTopLevelWindow("ARFF_Window")
    self.window = win
    win:SetDimensions(1200, 800)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetHidden(true)
    win:SetDrawLayer(DL_OVERLAY)
    -- Keep the complete table visible at smaller UI resolutions.
    win:SetScale(math.min(1, (GuiRoot:GetWidth() - 40) / 1200, (GuiRoot:GetHeight() - 90) / 800))
    local bg = control("ARFF_Background", win, CT_TEXTURE, 0, 0, 1200, 800)
    bg:SetColor(0.05, 0.05, 0.05, 0.97)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetMouseEnabled(false)
    local border = control("ARFF_Border", win, CT_BACKDROP, 0, 0, 1200, 800)
    border:SetCenterColor(0, 0, 0, 0)
    border:SetEdgeColor(unpack(GOLD))
    border:SetEdgeTexture(nil, 1, 1, 2)
    border:SetDrawLayer(DL_BACKGROUND)
    border:SetDrawLevel(1)
    border:SetMouseEnabled(false)
    local title = label("ARFF_Title", win, "Arc Rob's Furnishing Finder", 60, 14, 1080, 42, 32, GOLD, true)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    button("ARFF_Close", win, "X", 1150, 10, 34, 34, function() U:Hide() end)
    line(win, 64, true)

    self.filterButton = button("ARFF_Filter", win, "All locations  >", 20, 76, 340, 32, function() U:CycleFilter() end)
    label("ARFF_SearchLabel", win, "Search name:", 380, 76, 125, 32, 21, GRAY)
    local searchBG = WM:CreateControlFromVirtual("ARFF_SearchBG", win, "ZO_EditBackdrop")
    searchBG:SetAnchor(TOPLEFT, win, TOPLEFT, 510, 76)
    searchBG:SetDimensions(395, 32)
    self.search = WM:CreateControlFromVirtual("ARFF_Search", searchBG, "ZO_DefaultEditForBackdrop")
    self.search:SetAnchor(TOPLEFT, searchBG, TOPLEFT, 6, 2)
    self.search:SetAnchor(BOTTOMRIGHT, searchBG, BOTTOMRIGHT, -6, -2)
    self.search:SetFont("$(MEDIUM_FONT)|22|soft-shadow-thin")
    self.search:SetMaxInputChars(100)
    self.search:SetDefaultText("Furnishing name...")
    self.search:SetHandler("OnFocusLost", function(edit)
        if U.gamepadSearchFocused then ZO_GamepadEditBox_FocusLost(edit) end
        U.gamepadSearchFocused = false
    end)
    self.search:SetHandler("OnFocusGained", function(edit)
        U.gamepadSearchFocused = IsInGamepadPreferredMode()
        if U.gamepadSearchFocused then ZO_GamepadEditBox_FocusGained(edit) end
    end)
    self.search:SetHandler("OnTextChanged", function(edit)
        U.query, U.selected, U.offset = edit:GetText(), 1, 0
        U:Rebuild()
    end)
    self.search:SetHandler("OnEnter", function(edit) edit:LoseFocus() end)
    self.search:SetHandler("OnEscape", function(edit) edit:LoseFocus() end)
    button("ARFF_Clear", win, "Clear", 915, 76, 100, 32, function() U.search:SetText("") end)
    button("ARFF_Scan", win, "Scan", 1025, 76, 155, 32, function() F:Scan() end)
    line(win, 120)

    self.headers = {}
    for i, column in ipairs(COLUMNS) do
        local key = column[2]
        self.headers[i] = button("ARFF_Header" .. i, win, column[1], 20 + column[3], 128,
            column[4], 30, function() U:Sort(key) end)
    end
    line(win, 164)
    local list = control("ARFF_List", win, CT_CONTROL, 20, 170, 1160, ROWS * HEIGHT)
    list:SetMouseEnabled(true)
    list:SetHandler("OnMouseWheel", function(_, delta) U:Move(delta > 0 and -3 or 3) end)
    for i = 1, ROWS do
        local slotIndex = i
        local root = control("ARFF_Row" .. i, list, CT_CONTROL, 0, (i - 1) * HEIGHT, 1130, HEIGHT)
        root:SetMouseEnabled(true)
        local selected = control(nil, root, CT_TEXTURE, 0, 0, 1130, HEIGHT)
        selected:SetColor(0.91, 0.75, 0.36, 0.22)
        selected:SetDrawLayer(DL_BACKGROUND)
        selected:SetMouseEnabled(false)
        local icon = control(nil, root, CT_TEXTURE, 7, 3, 24, 24)
        icon:SetMouseEnabled(false)
        local labels = {}
        for j, column in ipairs(COLUMNS) do
            labels[j] = label(nil, root, "", column[3], 0, column[4], HEIGHT, 22, j == 5 and GRAY or WHITE)
            labels[j]:SetMouseEnabled(false)
            if j == 2 then labels[j]:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
        end
        self.pool[i] = { root = root, selection = selected, icon = icon, labels = labels }
        root:SetHandler("OnMouseUp", function(_, mouseButton)
            if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then return end
            U.selected = U.offset + slotIndex
            U:Render()
        end)
        root:SetHandler("OnMouseEnter", function()
            local entry = U.rows[U.offset + slotIndex]
            if not entry then return end
            InitializeTooltip(InformationTooltip, root, RIGHT, 0, 0, LEFT)
            InformationTooltip:AddLine(entry.name)
            InformationTooltip:AddLine(entry.location .. " - " .. entry.count)
            InformationTooltip:AddLine(entry.character .. " | Checked " .. U:Age(entry.checked))
        end)
        root:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        root:SetHandler("OnMouseWheel", function(_, delta) U:Move(delta > 0 and -3 or 3) end)
    end
    self.empty = label("ARFF_Empty", list, "", 70, 130, 1000, 140, 24, GRAY)
    self.empty:SetMaxLineCount(4)
    self.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    button("ARFF_Up", win, "^", 1155, 170, 25, 30, function() U:Move(-1) end)
    button("ARFF_Down", win, "v", 1155, 650, 25, 30, function() U:Move(1) end)
    line(win, 688)
    self.detail = label("ARFF_Detail", win, "", 24, 695, 1150, 30, 20, WHITE)
    self.footer = label("ARFF_Footer", win, "", 24, 733, 1150, 28, 21, GRAY)
    label("ARFF_Hint", win, "Saved locations update when visited. /ff to open. Assign a key or controller button in Controls.",
        24, 766, 1150, 22, 18, GRAY)

    self.keybinds = { alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { keybind = "UI_SHORTCUT_NEGATIVE", name = "Back", callback = function() U:Hide() end },
        { keybind = "UI_SHORTCUT_PRIMARY", name = "Search", callback = function() U:FocusSearch() end },
        { keybind = "UI_SHORTCUT_SECONDARY", name = "Scan", callback = function() F:Scan() end },
        { keybind = "UI_SHORTCUT_TERTIARY", name = "Next location type", callback = function() U:CycleFilter() end },
        { keybind = "UI_SHORTCUT_LEFT_TRIGGER", name = "Page up", callback = function() U:Move(-ROWS) end },
        { keybind = "UI_SHORTCUT_RIGHT_TRIGGER", name = "Page down", callback = function() U:Move(ROWS) end },
        { keybind = "UI_SHORTCUT_RIGHT_STICK", name = "Clear search", callback = function() U.search:SetText("") end },
        { keybind = "UI_SHORTCUT_LEFT_STICK", name = "Sort name / location", callback = function()
            U:Sort(U.sortKey == "name" and "location" or "name") end },
    }
    local scene = ZO_Scene:New(self.sceneName, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    if MOUSE_UI_MODE_FRAGMENT then scene:AddFragment(MOUSE_UI_MODE_FRAGMENT) end
    scene:AddFragment(ZO_SimpleSceneFragment:New(win))
    scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            U.visible = true
            F:Scan()
            U:Rebuild()
            KEYBIND_STRIP:AddKeybindButtonGroup(U.keybinds)
            DIRECTIONAL_INPUT:Activate(U, win)
            EM:RegisterForUpdate(F.name .. "Ages", 60000, function() U:Render() end)
        elseif state == SCENE_HIDDEN then
            U.visible = false
            U.search:LoseFocus()
            ClearTooltip(InformationTooltip)
            KEYBIND_STRIP:RemoveKeybindButtonGroup(U.keybinds)
            DIRECTIONAL_INPUT:Deactivate(U)
            EM:UnregisterForUpdate(F.name .. "Ages")
        end
    end)
    self:Rebuild()
    F.uiReady = true
end
