local A, C, S = DeskUI, DeskUI.Core, DeskUI.Style
local P = S.palette

local function RequireAPI(name)
    assert(type(_G[name]) == "function", name .. " is unavailable in this client")
end

function A.ReadQuests(assistedOnly)
    RequireAPI("IsValidQuestIndex"); RequireAPI("GetJournalQuestInfo")
    local rows = {}
    -- Journal indices have holes after quests are removed; never loop only to quest count.
    for index = 1, MAX_JOURNAL_QUESTS or 25 do
        if IsValidQuestIndex(index) then
            local name, background, active, _, override, complete, _, level = GetJournalQuestInfo(index)
            local zone = C.Try("GetJournalQuestLocationInfo", index) or ""
            local assisted = C.Try("GetTrackedIsAssisted", TRACK_TYPE_QUEST, index, 0) == true
            if not assistedOnly or assisted then
                rows[#rows + 1] = {id = "quest:" .. (C.Try("GetJournalQuestId", index) or index),
                    index = index, questId = C.Try("GetJournalQuestId", index), kind = "quest", name = name,
                    subtitle = zone .. (assisted and " / Assisted" or "") .. (complete and " / Complete" or ""),
                    background = background, active = override ~= "" and override or active, level = level, assisted = assisted}
            end
        end
    end
    return rows
end

function A.QuestBody(row)
    if not IsValidQuestIndex(row.index) then return "This quest is no longer in your journal. Refresh the list." end
    local lines = {row.subtitle, row.background or "", "CURRENT OBJECTIVE", row.active or ""}
    for step = 1, C.Try("GetJournalQuestNumSteps", row.index) or 0 do
        local _, visibility, _, _, count = C.Try("GetJournalQuestStepInfo", row.index, step)
        if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN or QUEST_STEP_VISIBILITY_HIDDEN == nil then
            for condition = 1, count or 0 do
                local text, current, maximum, fail, complete, _, visible = C.Try("GetJournalQuestConditionInfo", row.index, step, condition)
                if visible and not fail and text and text ~= "" and (not complete or A.settings.showCompletedObjectives) then
                    local progress = maximum and maximum > 1 and string.format(" (%d/%d)", current or 0, maximum) or ""
                    lines[#lines + 1] = (complete and "[Complete] " or "- ") .. text .. progress
                end
            end
        end
    end
    return table.concat(lines, "\n\n")
end

function A.ReadJournal(page)
    local rows, path = {}, page.path
    if page.section == "Lorebooks" then
        RequireAPI("GetNumLoreCategories")
        if not path.category then
            for category = 1, GetNumLoreCategories() do
                local name, count = GetLoreCategoryInfo(category)
                rows[#rows + 1] = {id = "lore:" .. category, kind = "folder", name = name,
                    subtitle = count .. " collections", path = {category = category}}
            end
        elseif not path.collection then
            local _, count = GetLoreCategoryInfo(path.category)
            for collection = 1, count do
                local name, description, known, total, hidden = GetLoreCollectionInfo(path.category, collection)
                if not hidden then
                    rows[#rows + 1] = {id = "collection:" .. collection, kind = "folder", name = name,
                        subtitle = string.format("%d/%d books known", known, total), body = description,
                        path = {category = path.category, collection = collection}}
                end
            end
        else
            local _, _, _, total = GetLoreCollectionInfo(path.category, path.collection)
            for book = 1, total do
                local title, _, known = GetLoreBookInfo(path.category, path.collection, book)
                rows[#rows + 1] = {id = "book:" .. book, kind = "book", name = title,
                    subtitle = known and "Collected" or "Not collected", known = known,
                    category = path.category, collection = path.collection, book = book}
            end
        end
    else
        RequireAPI("GetNumAchievementCategories")
        if not path.category then
            for category = 1, GetNumAchievementCategories() do
                local name, _, _, earned, total = GetAchievementCategoryInfo(category)
                rows[#rows + 1] = {id = "achievementcategory:" .. category, kind = "folder", name = name,
                    subtitle = string.format("%d/%d points", earned, total), path = {category = category}}
            end
        else
            local _, subcategories, count = GetAchievementCategoryInfo(path.category)
            if not path.subcategory then
                for subcategory = 1, subcategories do
                    local name, _, earned, total = GetAchievementSubCategoryInfo(path.category, subcategory)
                    rows[#rows + 1] = {id = "subcategory:" .. subcategory, kind = "folder", name = name,
                        subtitle = string.format("%d/%d points", earned, total), path = {category = path.category, subcategory = subcategory}}
                end
            else
                local _, total = GetAchievementSubCategoryInfo(path.category, path.subcategory); count = total
            end
            for index = 1, count do
                local id = GetAchievementId(path.category, path.subcategory, index)
                local name, description, points, _, complete = GetAchievementInfo(id)
                rows[#rows + 1] = {id = "achievement:" .. id, achievementId = id, kind = "achievement", name = name,
                    subtitle = points .. " points / " .. (complete and "Complete" or "In progress"), body = description}
            end
        end
    end
    return rows
end

local function Body(row)
    if row.kind == "mail" then return A.MailBody(row) end
    if row.kind == "quest" then return A.QuestBody(row) end
    if row.kind == "book" then
        if not row.known then return "This book has not been collected. Its text is not available in your journal." end
        RequireAPI("ReadLoreBook")
        return ReadLoreBook(row.category, row.collection, row.book)
    end
    local lines = {row.subtitle, row.body or ""}
    if row.kind == "achievement" then
        for index = 1, C.Try("GetAchievementNumCriteria", row.achievementId) or 0 do
            local description, current, required = C.Try("GetAchievementCriterion", row.achievementId, index)
            if description then lines[#lines + 1] = string.format("%s (%d/%d)", description, current or 0, required or 0) end
        end
    elseif row.kind == "folder" then lines[#lines + 1] = "Select Open to browse this category." end
    return table.concat(lines, "\n\n")
end

local function Select(page, row)
    local changed = page.selectedId ~= (row and row.id)
    page.selected, page.selectedId = row, row and row.id
    page.detailTitle:SetText(row and row.name or "No entries")
    local ok, text = true, "No matching entries. Clear the search or select another category."
    if row then ok, text = pcall(Body, row) end
    page.body:SetText(ok and (text or "No text available.") or ("Could not read details: " .. tostring(text)))
    page.body:SetHeight(math.max(490, page.body:GetTextHeight()))
    page.maxScroll = math.max(0, page.body:GetTextHeight() - 490)
    if changed then page.detailOffset = 0 end
    page.detailOffset = math.min(page.detailOffset or 0, page.maxScroll)
    page.viewport:SetVerticalScroll(page.detailOffset)
    page.action:SetHidden(not row or (row.kind ~= "folder" and row.kind ~= "quest" and row.kind ~= "mail"))
    page.action.label:SetText(row and row.kind == "quest" and (row.assisted and "Stop assisting" or "Assist quest")
        or (row and row.kind == "mail" and "Read message" or "Open"))
end

local function Render(page)
    page.offset = C.ClampOffset(page.offset or 0, #page.filtered, 12)
    local selected
    for _, row in ipairs(page.filtered) do if row.id == page.selectedId then selected = row; break end end
    Select(page, selected or page.filtered[1])
    for index, control in ipairs(page.rows) do
        local row = page.filtered[page.offset + index]
        control.row = row; control:SetHidden(not row)
        if row then
            control.nameLabel:SetText((row.kind == "folder" and "> " or "") .. row.name); control.subtitle:SetText(row.subtitle)
            control.selection:SetHidden(row.id ~= page.selectedId)
            control.icon:SetHidden(not row.icon)
            if row.icon then control.icon:SetTexture(row.icon) end
            if row.id == page.selectedId then control.background:SetCenterColor(0.19, 0.39, 0.42, 0.72)
            else control.background:SetCenterColor(0, 0, 0, 0.15) end
        end
    end
    page.count:SetText(#page.filtered .. " entries / " .. page.section)
    page.back:SetHidden(next(page.path) == nil)
    if page.location then page.location:SetText(page.path.label or page.section) end
end

function A.FilterBrowser(page)
    local query = string.lower(page.search:GetText())
    page.filtered = {}
    for _, row in ipairs(page.source or {}) do
        if string.find(string.lower(row.name .. " " .. row.subtitle), query, 1, true) then page.filtered[#page.filtered + 1] = row end
    end
    if not (A.BrowserPages[page.name] and A.BrowserPages[page.name].preserveOrder) then
        table.sort(page.filtered, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    end
    Render(page)
end

function A.RefreshBrowser(page)
    local ok, rows
    if A.BrowserPages[page.name] then ok, rows = pcall(A.BrowserPages[page.name].read, page)
    elseif page.name == "Quests" then ok, rows = pcall(A.ReadQuests, page.section == "Assisted")
    else ok, rows = pcall(A.ReadJournal, page) end
    page.source = ok and rows or {}
    A.FilterBrowser(page)
    if not ok then page.detailTitle:SetText(A.BrowserPages[page.name] and "Menu data unavailable" or "Journal data unavailable"); page.body:SetText(tostring(rows))
    elseif #rows == 0 and A.BrowserPages[page.name] then
        page.detailTitle:SetText("No entries")
        page.body:SetText(A.BrowserPages[page.name].empty or "There are no entries available here.")
    end
end

function A.BuildBrowser(name)
    local page = {name = name, section = name == "Quests" and "All quests" or (name == "Achievements" and "Achievements" or "Lorebooks"), path = {}, rows = {}, source = {}, filtered = {}}
    local definition = A.BrowserPages[name]
    if definition then page.section = definition.section or name end
    page.history = {}
    local root = WINDOW_MANAGER:CreateControl(nil, A.root, CT_CONTROL)
    root:SetAnchor(TOPLEFT, A.root, TOPLEFT, 420, 238); root:SetDimensions(1404, 734)
    page.root = root
    S.Panel(root, 0, 0, 1404, 734, nil, true)
    S.Label(root, 18, 10, 900, 31, string.upper(name), P.text, 24, true)
    local sections = name == "Quests" and {"All quests", "Assisted"} or {}
    if definition then
        page.location = S.Label(root, 18, 58, 396, 36, page.section, P.accent, 18, true)
        S.Label(root, 454, 55, 918, 38, definition.notice or "Browse categories and select an entry to inspect its details.", P.muted, 17)
    end
    for index, section in ipairs(sections) do
        local value = section
        S.Button(root, 18 + (index - 1) * 178, 53, 166, 35, section, function()
            page.section, page.path, page.offset, page.history = value, {}, 0, {}
            page.search:SetText(""); A.RefreshBrowser(page)
        end)
    end
    S.Rule(root, 18, 98, 1368)
    S.Panel(root, 18, 110, 396, 34, {0.14, 0.14, 0.10, 0.55}, true)
    S.Label(root, 28, 115, 65, 25, "Search", P.muted, 16)
    page.search = WINDOW_MANAGER:CreateControl(nil, root, CT_EDITBOX)
    page.search:SetAnchor(TOPLEFT, root, TOPLEFT, 100, 115); page.search:SetDimensions(303, 27)
    page.search:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thin"); page.search:SetColor(unpack(P.text))
    page.search:SetMouseEnabled(true); page.search:SetEditEnabled(true); page.search:SetMaxInputChars(100)
    A.ConfigureMenuEditBox(page.search)
    page.search:SetHandler("OnTextChanged", function() page.offset = 0; A.FilterBrowser(page) end)
    page.search:SetHandler("OnEnter", function(box) box:LoseFocus() end)
    page.search:SetHandler("OnEscape", function(box) box:LoseFocus(); A.Close() end)
    local function Scroll(delta) page.offset = (page.offset or 0) - delta * 3; Render(page) end
    for index = 1, 12 do
        local row = S.Button(root, 18, 155 + (index - 1) * 40, 396, 39, "", function() end)
        row.selection = S.Texture(row, 0, 0, 396, 39, "EsoUI/Art/Miscellaneous/listItem_selectedHighlight.dds")
        row.selection:SetHidden(true)
        row.nameLabel = S.Label(row, 9, 0, 378, 24, "", P.text, 18, true)
        row.nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.subtitle = S.Label(row, 9, 22, 378, 18, "", P.muted, 13)
        row.icon = S.Icon(row, 362, 3, 32)
        row.icon:SetHidden(true)
        row.nameLabel:SetDimensions(347, 24); row.subtitle:SetDimensions(347, 18)
        row:SetHandler("OnClicked", function(control) if control.row then Select(page, control.row); Render(page) end end)
        row:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
        page.rows[index] = row
    end
    page.count = S.Label(root, 18, 646, 390, 28, "", P.muted, 16)
    page.back = S.Button(root, 18, 685, 102, 33, "Back", function()
        if #page.history > 0 then page.path = table.remove(page.history)
        elseif page.path.collection or page.path.subcategory then page.path = {category = page.path.category}
        else page.path = {} end
        page.offset = 0; page.search:SetText(""); A.RefreshBrowser(page)
    end)
    S.Button(root, 130, 685, 133, 33, "Previous", function() Scroll(4) end)
    S.Button(root, 275, 685, 139, 33, "Next", function() Scroll(-4) end)
    page.detailTitle = S.Label(root, 454, 112, 918, 68, "", P.accent, 25, true)
    page.viewport = WINDOW_MANAGER:CreateControl(nil, root, CT_SCROLL)
    page.viewport:SetAnchor(TOPLEFT, root, TOPLEFT, 454, 192); page.viewport:SetDimensions(918, 490)
    page.viewport:SetMouseEnabled(true)
    page.body = S.Label(page.viewport, 0, 0, 900, 490, "", P.text, 20)
    local function ScrollDetails(delta)
        page.detailOffset = math.max(0, math.min(page.maxScroll or 0, (page.detailOffset or 0) - delta * 60))
        page.viewport:SetVerticalScroll(page.detailOffset)
    end
    page.viewport:SetHandler("OnMouseWheel", function(_, delta) ScrollDetails(delta) end)
    page.action = S.Button(root, 454, 690, 178, 33, "Open", function()
        local row = page.selected
        if not row then return end
        if row.kind == "folder" then
            page.history[#page.history + 1] = page.path
            page.path, page.offset = row.path, 0; page.search:SetText(""); A.RefreshBrowser(page)
        elseif row.kind == "mail" then A.RequestMailBody(page, row)
        elseif row.kind == "quest" then
            if not SetTrackedIsAssisted or not TRACK_TYPE_QUEST then
                page.body:SetText("Quest assisting is unavailable in this client. You can still browse quests here.")
                return
            end
            local stillValid = IsValidQuestIndex(row.index) and (not row.questId or C.Try("GetJournalQuestId", row.index) == row.questId)
            if stillValid and SetTrackedIsAssisted and TRACK_TYPE_QUEST then
                local ok, err = pcall(SetTrackedIsAssisted, TRACK_TYPE_QUEST, not row.assisted, row.index, 0)
                if not ok then page.body:SetText("Could not assist quest: " .. tostring(err)); return end
            end
            A.RefreshBrowser(page)
        end
    end)
    S.Button(root, 1034, 690, 158, 33, "Details up", function() ScrollDetails(4) end)
    S.Button(root, 1204, 690, 168, 33, "Details down", function() ScrollDetails(-4) end)
    A.MakeMovable(root, name, A.root, 420, 238, 1404)
    return page
end

function A.BuildSettingsPage()
    local root = WINDOW_MANAGER:CreateControl(nil, A.root, CT_CONTROL)
    local page = {root = root, toggles = {}, audio = {}}
    root:SetAnchor(TOPLEFT, A.root, TOPLEFT, 490, 238); root:SetDimensions(1334, 670)
    S.Panel(root, 0, 0, 1334, 670, nil, true)
    S.Label(root, 20, 12, 900, 36, "SETTINGS", P.text, 24, true)
    S.Label(root, 20, 65, 1260, 50, "DeskUI preferences and audio controls. Changes here stay inside DeskUI.", P.muted, 20)
    local function Toggle(y, label, field, default, changed)
        S.Label(root, 24, y + 6, 710, 34, label, P.text, 21)
        local button
        local function Text() return (A.settings[field] == nil and default or A.settings[field]) and "On" or "Off" end
        button = S.Button(root, 820, y, 140, 37, Text(), function()
            local enabled = A.settings[field]; if enabled == nil then enabled = default end
            A.settings[field] = not enabled; button.label:SetText(Text())
            if changed then changed() end
        end)
        page.toggles[field] = button
    end
    Toggle(140, "Select inventory items on hover", "hoverSelection", true)
    Toggle(198, "Show completed quest objectives", "showCompletedObjectives", false)
    Toggle(256, "Replace supported menu shortcuts", "replaceMenus", true, A.UpdateReplacementLayer)
    S.Button(root, 24, 314, 230, 38, "Reset panel positions", A.ResetPositions)
    S.Rule(root, 24, 380, 1286)
    local audio = {{"Master volume", "AUDIO_SETTING_AUDIO_VOLUME"}, {"Music volume", "AUDIO_SETTING_MUSIC_VOLUME"}, {"Effects volume", "AUDIO_SETTING_SFX_VOLUME"}}
    for index, setting in ipairs(audio) do
        local id = _G[setting[2]]
        local y = 410 + (index - 1) * 65
        local value = S.Label(root, 24, y + 4, 740, 36, "", P.text, 21)
        local function Refresh()
            local volume = id and C.Try("GetSetting", SETTING_TYPE_AUDIO, id)
            value:SetText(setting[1] .. ": " .. (volume or "Unavailable"))
            return tonumber(volume)
        end
        local function Change(delta)
            local current = Refresh()
            if current and SetSetting then
                local ok, err = pcall(SetSetting, SETTING_TYPE_AUDIO, id, tostring(math.max(0, math.min(100, current + delta))))
                if not ok then value:SetText("Could not change volume: " .. tostring(err)); return end
                Refresh()
            end
        end
        local down = S.Button(root, 820, y, 66, 37, "-", function() Change(-5) end)
        local up = S.Button(root, 896, y, 66, 37, "+", function() Change(5) end)
        page.audio[index] = {down = down, up = up, refresh = Refresh}
        Refresh()
    end
    S.Label(root, 24, 586, 1270, 56, "This page covers DeskUI preferences and audio. Other game settings remain available through ESO's Esc menu.", P.muted, 18)
    A.MakeMovable(root, "settings", A.root, 490, 238, 1334)
    return page
end

function A.SetPage(name)
    if not A.ready then return end
    name = A.ResolvePage(name)
    if name == "Journal" then name = A.journalPage or "Quests" end
    if A.JournalPages[name] then A.journalPage = name end
    if A.BrowserPages[name] then A.lastFamilyPage[A.BrowserPages[name].category] = name end
    A.StopDragging(); A.LoseSearchFocus()
    if not A.pages[name] then
        if name == "Settings" then A.pages[name] = A.BuildSettingsPage()
        elseif A.JournalPages[name] or A.BrowserPages[name] then A.pages[name] = A.BuildBrowser(name)
        elseif name == "System" then A.pages[name] = A.BuildSystemPage()
        elseif name == "Character" then A.pages[name] = A.BuildCharacterPage()
        elseif name == "Map" then A.pages[name] = A.BuildMapPage()
        else return end
    end
    local previous = A.activePage
    A.activePage = name; A.pageTitle:SetText(string.upper(name))
    A.EnterMenuPage(name, previous)
    for key, page in pairs(A.pages) do
        for _, root in ipairs(page.controls or {page.root}) do root:SetHidden(key ~= name) end
    end
    A.UpdateShell()
    if name == "Inventory" then A.Refresh()
    elseif name == "Settings" then
        for _, audio in ipairs(A.pages.Settings.audio) do audio.refresh() end
    elseif A.JournalPages[name] or A.BrowserPages[name] then A.RefreshBrowser(A.pages[name])
    elseif name == "Character" then A.RefreshCharacter()
    elseif name == "Map" then A.RefreshMap() end
end

function A.LoseSearchFocus()
    if A.search then A.search:LoseFocus() end
    for _, page in pairs(A.pages or {}) do if page.search then page.search:LoseFocus() end end
end

function A.RefreshCurrentPage()
    if A.activePage == "Inbox" and not A.mailboxOwned then A.EnterMenuPage("Inbox", nil) end
    if A.JournalPages[A.activePage] or A.BrowserPages[A.activePage] then A.RefreshBrowser(A.pages[A.activePage])
    elseif A.activePage == "Inventory" then A.Refresh() end
    if A.activePage == "Character" then A.RefreshCharacter() end
    if A.activePage == "Map" then A.RefreshMap() end
end
