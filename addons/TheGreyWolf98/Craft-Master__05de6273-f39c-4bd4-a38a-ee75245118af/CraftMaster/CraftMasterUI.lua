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
    self.focus = "categories"
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
            if (e.resultType or GetItemLinkItemType(e.resultLink or self:Link(e.resultId))) ~= self.category then return false end
        end
    end
    local known = self:Knowledge(e.key, self.viewCharacter)
    if self.filter == 2 then return known == true end
    if self.filter == 3 then return known == false end
    if self.filter == 4 then return known == nil end
    return true
end
function CM:MotifGroup(entry)
    local number, tail = entry.name:match("[Cc]rafting [Mm]otif%s+(%d+):%s*(.+)")
    if not number then return entry.key, entry.name, nil, entry.name end
    local chapter = tail:match("%s+(%S+)$")
    local chapters = {Axes=true, Belts=true, Boots=true, Bows=true, Chests=true,
        Daggers=true, Gloves=true, Helmets=true, Legs=true, Maces=true,
        Shields=true, Shoulders=true, Staves=true, Swords=true, Style=true}
    local style = tail
    if chapters[chapter] then style = tail:sub(1, #tail - #chapter - 1)
    else chapter = tail end
    if chapter == "Style" then chapter = "Full style book" end
    return "group:" .. number, "Motif " .. number .. ": " .. style, tonumber(number), chapter
end
function CM:BuildResults()
    local results, query = {}, self:Lower(self.search:GetText()):match("^%s*(.-)%s*$")
    if self.tab == 3 then
        self.expandedMotifs = self.expandedMotifs or {}
        local groups = {}
        for _, entry in pairs(self.sv.catalog) do
            if entry.kind == "motifs" then
                local key, name, number, chapter = self:MotifGroup(entry)
                local g = groups[key]
                if not g then
                    g = {key=key, name=name, number=number, isGroup=true, kind="motifs",
                        quality=4, children={}, total=0, learned=0, missing=0, unchecked=0}
                    groups[key] = g
                end
                entry.chapterName = chapter
                g.total = g.total + 1
                local known = self:Knowledge(entry.key, self.viewCharacter)
                if known == true then g.learned = g.learned + 1
                elseif known == false then g.missing = g.missing + 1
                else g.unchecked = g.unchecked + 1 end
                if self:Matches(entry, query) then g.children[#g.children+1] = entry end
            end
        end
        local ordered = {}
        for _, g in pairs(groups) do if #g.children > 0 then ordered[#ordered+1] = g end end
        table.sort(ordered, function(a,b)
            if a.number and b.number and a.number ~= b.number then return a.number < b.number end
            return a.name < b.name
        end)
        for _, g in ipairs(ordered) do
            table.sort(g.children, function(a,b) return a.chapterName < b.chapterName end)
            results[#results+1] = g
            if self.expandedMotifs[g.key] then
                for _, child in ipairs(g.children) do results[#results+1] = child end
            end
        end
    else
        for _, entry in pairs(self.sv.catalog) do
            if self:Matches(entry, query) then results[#results + 1] = entry end
        end
        table.sort(results, function(a, b) return a.name < b.name end)
    end
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
    self.focusLabel:SetText(self.focus == "results" and "Results [left stick]" or "Categories [left stick]")
    self.pages:SetText(#self.results .. " results  |  Page " .. self.page .. "/" .. math.max(1, math.ceil(#self.results / self.rowCount)))
    local offset = math.max(0, self.categorySelected - self.rowCount)
    for i, row in ipairs(self.categoryRows) do
        local cat = self.categories[offset + i]
        row.index = offset + i
        row.control:SetHidden(cat == nil)
        if cat then
            local selected = self.focus == "categories" and row.index == self.categorySelected
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
            row.background:SetCenterColor(self.focus == "results" and index == self.selected and .16 or .055, self.focus == "results" and index == self.selected and .24 or .075, self.focus == "results" and index == self.selected and .32 or .105, 1)
            local displayName = e.name
            if e.isGroup then displayName = (self.expandedMotifs[e.key] and "[-] " or "[+] ") .. e.name
            elseif self.tab == 3 then displayName = "    " .. (e.chapterName or e.name) end
            row.text:SetText("|c" .. (QUALITY[e.quality] or "eeeeee") .. displayName .. "|r")
            if e.isGroup then row.status:SetText(e.learned .. "/" .. e.total)
            else row.status:SetText(self:Status(e.key, self.viewCharacter, false)) end
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
    if e.isGroup then
        self.detail:SetText(e.name .. "\n" .. e.learned .. " learned / " .. e.missing .. " missing / " .. e.unchecked .. " not checked.  A: expand/collapse chapters.")
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
    local planType = self:PlanType(e)
    if planType then location = planType .. (location ~= "" and "  |  " .. location or "") end
    if location ~= "" then text = text .. "\n" .. location end
    if e.kind ~= "motifs" then
        text = text .. "\nLearned status records the plan; materials and crafting passives still apply."
    end
    self.detail:SetText(text)
end
function CM:MoveSelection(delta)
    if self.focus == "results" then
        self.selected = math.max(1, math.min(#self.results, self.selected + delta))
    else self.categorySelected = math.max(1, math.min(#self.categories, self.categorySelected + delta)) end
    self:Refresh(false)
end
function CM:Page(delta)
    local lastPage = math.max(1, math.ceil(#self.results / self.rowCount))
    local page = math.max(1, math.min(lastPage, self.page + delta))
    self.selected = (page - 1) * self.rowCount + 1
    self.focus = "results"
    self:Refresh(false)
end
function CM:Select()
    if self.focus == "results" then
        local entry = self.results[self.selected]
        if entry and entry.isGroup then
            local key = entry.key
            self.expandedMotifs[key] = not self.expandedMotifs[key]
            self:Refresh()
            for i, e in ipairs(self.results) do if e.key == key then self.selected = i; break end end
            self:Refresh(false)
        else self:OpenItemActions() end
        return
    end
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
        GAMEPAD_TOOLTIPS:LayoutItem(GAMEPAD_RIGHT_TOOLTIP, e.resultLink or self:Link(e.resultId))
    elseif PopupTooltip then
        InitializeTooltip(PopupTooltip, self.window, RIGHT, 12, 0, LEFT)
        PopupTooltip:SetLink(e.resultLink or self:Link(e.resultId))
    end
end
function CM:SelectedItemLinks(e)
    if not e or e.isGroup or e.kind == "motifs" then return end
    local result = e.resultLink or (e.resultId and self:Link(e.resultId))
    local plan
    if e.planId then
        for _,variant in ipairs({{1,1},{0,0},{5,1}}) do
            local candidate = self:Link(e.planId,variant[1],variant[2])
            if GetItemLinkItemType(candidate) == ITEMTYPE_RECIPE then plan = candidate; break end
        end
    end
    return result, plan
end
function CM:PlanType(e)
    local _, plan = self:SelectedItemLinks(e)
    if not plan then return end
    local name = self:Clean(GetItemLinkName(plan))
    return name:match("^([^:]+):")
end
function CM:CloseItemActions(leaving)
    if not self.itemActionsOpen then return end
    self.itemActionsOpen = false
    self.itemActions:SetHidden(true)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.itemActionKeys)
    if not leaving then KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds) end
end
function CM:OpenItemActions()
    local e = self.results[self.selected]
    if not e or e.isGroup then return end
    if e.kind == "motifs" then self:ShowSelectedDetail(); return end
    if not self.itemActions then
        local w = WM:CreateControl(nil, self.window, CT_CONTROL)
        w:SetDimensions(610, 250); w:SetAnchor(CENTER, self.window, CENTER)
        w:SetMouseEnabled(true); w:SetDrawTier(DT_HIGH); w:SetDrawLevel(100)
        backdrop(w, 0, 0, 610, 250, .025, .035, .055, 1)
        self.itemActions = w
        self.itemActionTitle = label(w, "", 24, 14, 562, 64)
        self.itemActionTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        button(w, "Preview furnishing", 24, 88, 562, function() self:PreviewSelectedItem() end)
        button(w, "Link", 24, 138, 562, function() self:DraftItemLink() end)
        button(w, "Back", 24, 188, 562, function() self:CloseItemActions() end)
        self.itemActionKeys = {
            alignment = KEYBIND_STRIP_ALIGN_CENTER,
            {name="Preview",keybind="UI_SHORTCUT_PRIMARY",callback=function() self:PreviewSelectedItem() end},
            {name="Link",keybind="UI_SHORTCUT_SECONDARY",callback=function() self:DraftItemLink() end},
            {name="Back",keybind="UI_SHORTCUT_NEGATIVE",callback=function() self:CloseItemActions() end},
        }
    end
    self.itemActionTitle:SetText(e.name .. (self:PlanType(e) and "  |  " .. self:PlanType(e) or ""))
    self.itemActionsOpen = true; self.itemActions:SetHidden(false)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.itemActionKeys)
end
function CM:DraftItemLink()
    local e = self.results[self.selected]
    local _, link = self:SelectedItemLinks(e)
    if not link then self:Message("No verified plan link for this entry."); return end
    local chat = ZO_GetChatSystem and ZO_GetChatSystem()
    if not chat or type(chat.StartTextEntry) ~= "function" or (IsChatSystemAvailableForCurrentPlatform and not IsChatSystemAvailableForCurrentPlatform()) then
        self:Message("Chat is unavailable here."); return
    end
    local entry = chat.textEntry
    if entry and entry.GetText and entry:GetText() ~= "" then
        self:Message("Send or clear your existing chat draft first."); return
    end
    local name = self:Clean(GetItemLinkName(link))
    if name == "" then name = e.name end
    local data = link:match("|H%d+:item:([^|]+)|h")
    if not data or not ZO_LinkHandler_CreateLink then self:Message("Cannot format this plan's chat link."); return end
    local fields = {}; for field in data:gmatch("[^:]+") do fields[#fields + 1] = field end
    link = ZO_LinkHandler_CreateLink(name, nil, ITEM_LINK_TYPE or "item", (unpack or table.unpack)(fields))
    self:CloseItemActions(true)
    SCENE_MANAGER:ShowBaseScene()
    zo_callLater(function()
        -- StartChatInput uses the gamepad default path, which calls private
        -- SetSetting even when the HUD is already enabled. The fourth argument
        -- skips that path; native text-entry Open still focuses the edit box.
        if chat.textEntry and chat.textEntry.GetText and chat.textEntry:GetText() ~= "" then
            self:Message("Your existing chat draft was kept."); return
        end
        -- Native item linking inserts markup into the focused edit control;
        -- SetText passes the encoded link straight to the console keyboard.
        chat:StartTextEntry("", nil, nil, true)
        if chat.textEntry and chat.textEntry.InsertText then chat.textEntry:InsertText(link)
        else self:Message("Chat link insertion is unavailable here.") end
    end, 250)
end
function CM:StopItemPreview()
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "PreviewReady")
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "PreviewCheck")
    self.previewSceneShown = false
    if self.previewModeOwned then
        if EndItemPreviewSpin then EndItemPreviewSpin() end
        EndCurrentItemPreview(); DisablePreviewMode()
        self.previewModeOwned = false
    end
    self.previewLink = nil; self.previewSpinning = false
end
function CM:ApplyItemPreview()
    if not self.previewModeOwned or not self.previewSceneShown or not GetPreviewModeEnabled() then return end
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "PreviewReady")
    SetPreviewDynamicFramingOpening(GuiRoot:GetWidth(), GuiRoot:GetHeight() - 180, -.4)
    SetPreviewInEmptyWorld(math.rad(135), math.rad(45))
    local ok = pcall(function()
        PreviewItemLink(self.previewLink, 1)
        -- PreviewItemLink queues a collection element. ESO's native preview
        -- system commits it separately; without this the scene stays empty.
        ApplyChangesToPreviewCollectionShown()
    end)
    if not ok then
        self:Message("ESO could not preview this furnishing here.")
        SCENE_MANAGER:PopScenes(1)
    elseif IsCurrentlyPreviewing then
        EVENT_MANAGER:RegisterForUpdate(self.name .. "PreviewCheck",1500,function()
            EVENT_MANAGER:UnregisterForUpdate(self.name .. "PreviewCheck")
            if self.previewModeOwned and not IsCurrentlyPreviewing() then
                self:Message("ESO did not start this furnishing preview; returned to catalogue.")
                SCENE_MANAGER:PopScenes(1)
            end
        end)
    end
end
function CM:PreviewSelectedItem()
    local e = self.results[self.selected]
    local link = self:SelectedItemLinks(e)
    if not e or e.kind ~= "housing" or not link or type(CanItemLinkBePreviewed) ~= "function" or not CanItemLinkBePreviewed(link) then
        self:Message("ESO does not offer a furnishing preview for this entry."); return
    end
    if IsUnitInCombat("player") or GetPreviewModeEnabled() then
        self:Message("Close the current preview or leave combat before previewing."); return
    end
    if not self.previewScene then
        local w = WM:CreateTopLevelWindow("CraftMasterPreview")
        w:SetDimensions(GuiRoot:GetWidth(), GuiRoot:GetHeight()); w:SetAnchor(CENTER, GuiRoot, CENTER); w:SetHidden(true)
        self.previewTitle = label(w, "", 40, 30, GuiRoot:GetWidth() - 80, 60, TITLE_FONT)
        local scene = ZO_Scene:New("craftMasterPreview", SCENE_MANAGER)
        self.previewScene = scene
        scene:AddFragment(ZO_SimpleSceneFragment:New(w))
        -- The native preview camera only renders the collection while the
        -- player-framing camera is active. Release it when the scene hides.
        if FRAME_TARGET_CENTERED_FRAGMENT then scene:AddFragment(FRAME_TARGET_CENTERED_FRAGMENT) end
        if FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT then scene:AddFragment(FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT) end
        if GAMEPAD_UI_MODE_FRAGMENT then scene:AddFragment(GAMEPAD_UI_MODE_FRAGMENT) end
        if KEYBIND_STRIP_GAMEPAD_FRAGMENT then scene:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT) end
        if KEYBIND_STRIP_GAMEPAD_BACKDROP_FRAGMENT then scene:AddFragment(KEYBIND_STRIP_GAMEPAD_BACKDROP_FRAGMENT) end
        if UI_SHORTCUTS_ACTION_LAYER_FRAGMENT then scene:AddFragment(UI_SHORTCUTS_ACTION_LAYER_FRAGMENT) end
        self.previewKeys = {
            alignment=KEYBIND_STRIP_ALIGN_CENTER,
            {name="Rotate / stop",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()
                if not self.previewModeOwned or not GetPreviewModeEnabled() then return end
                self.previewSpinning = not self.previewSpinning
                if self.previewSpinning then BeginItemPreviewSpin() else EndItemPreviewSpin() end
            end},
            {name="Back to catalogue",keybind="UI_SHORTCUT_NEGATIVE",callback=function() SCENE_MANAGER:PopScenes(1) end},
        }
        scene:RegisterCallback("StateChange",function(_,state)
            if state == SCENE_SHOWING then
                KEYBIND_STRIP:AddKeybindButtonGroup(self.previewKeys)
                self.previewSceneShown = false
                self.previewModeOwned = true; EnablePreviewMode(false)
                local started = GetFrameTimeMilliseconds()
                EVENT_MANAGER:RegisterForUpdate(self.name .. "PreviewReady",100,function()
                    if self.previewSceneShown and GetPreviewModeEnabled() then self:ApplyItemPreview()
                    elseif GetFrameTimeMilliseconds() - started > 5000 then
                        self:Message("Preview could not start here. Try again outside combat or an interaction.")
                        SCENE_MANAGER:PopScenes(1)
                    end
                end)
            elseif state == SCENE_SHOWN then
                self.previewSceneShown = true
            elseif state == SCENE_HIDING then
                self:StopItemPreview()
                KEYBIND_STRIP:RemoveKeybindButtonGroup(self.previewKeys)
            end
        end)
    end
    self:CloseItemActions()
    self.previewLink = link; self.previewTitle:SetText(e.name)
    self.returningFromPreview = true
    SCENE_MANAGER:Push("craftMasterPreview")
end
function CM:UpdateDirectionalInput()
    if self.itemActionsOpen or self.search:HasFocus() then return end
    local now = GetFrameTimeMilliseconds()
    local x, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK_NO_KEYBOARD)
    DIRECTIONAL_INPUT:Consume(ZO_DI_LEFT_STICK)
    if math.abs(x) < .35 and math.abs(y) < .35 then self.nextInput = 0; return end
    if now < (self.nextInput or 0) then return end
    self.nextInput = now + 180
    if math.abs(x) > math.abs(y) then
        self.focus = x > 0 and "results" or "categories"
        self:Refresh(false)
    else self:MoveSelection(y > 0 and -1 or 1) end
end
function CM:SearchFocus()
    self.search:TakeFocus()
end
function CM:CreateWindow()
    self.tab, self.filter, self.selected, self.page, self.categorySelected = 1, 1, 1, 1, 1
    self.focus = "categories"
    local w = math.min(1450, GuiRoot:GetWidth() - 80)
    local h = math.min(870, GuiRoot:GetHeight() - 180)
    local left, gap = 300, 18
    local listX, listY = left + gap + 20, 228
    self.rowCount = math.max(4, math.floor((h - listY - 168) / ROW))
    local panel = WM:CreateTopLevelWindow("CraftMasterWindow")
    self.window = panel
    panel:SetDimensions(w, h)
    -- Reserve the lower screen for ESO's controller button strip.
    panel:SetAnchor(CENTER, GuiRoot, CENTER, 0, -60)
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
            self.selected = result.index; self.focus = "results"; self:Refresh(false)
        end)
        self.resultRows[i] = result
    end
    local detailY = listY + self.rowCount * ROW + 7
    self.detail = label(panel, "", 24, detailY, w - 48, 112, "$(MEDIUM_FONT)|24|soft-shadow-thin")
    self.detail:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label(panel, "Stick left/right: categories/results  |  A: select  |  LT: change section  |  LB/RB: pages", 24, h - 35, w - 48, 30, "$(MEDIUM_FONT)|21|soft-shadow-thin")
    panel:SetHandler("OnMouseWheel", function(_, delta) self:MoveSelection(-delta) end)
    self.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        { name = "Select", keybind = "UI_SHORTCUT_PRIMARY", callback = function() self:Select() end },
        { name = "Filter", keybind = "UI_SHORTCUT_SECONDARY", callback = function() self:CycleFilter() end },
        { name = "Character", keybind = "UI_SHORTCUT_TERTIARY", callback = function() self:CycleCharacter() end },
        { name = "Search", keybind = "UI_SHORTCUT_QUATERNARY", callback = function() self:SearchFocus() end },
        { name = "Prev", keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() self:Page(-1) end },
        { name = "Next", keybind = "UI_SHORTCUT_RIGHT_SHOULDER", callback = function() self:Page(1) end },
        { name = "Housing / Recipes / Motifs", keybind = "UI_SHORTCUT_LEFT_TRIGGER", callback = function() self:CycleTab() end },
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
            if not self.returningFromPreview then self.viewCharacter = self.sv.main or self.viewCharacter end
            self.returningFromPreview = false
            self:Refresh()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
            DIRECTIONAL_INPUT:Activate(self, panel)
        elseif state == SCENE_HIDING then
            self:CloseItemActions(true)
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
