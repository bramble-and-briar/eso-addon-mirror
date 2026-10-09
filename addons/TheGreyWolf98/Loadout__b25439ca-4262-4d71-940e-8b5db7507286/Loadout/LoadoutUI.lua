local L = Loadout
local W, H = 1740, 950
local gold, muted, white = { 0.95, 0.73, 0.35 }, { 0.65, 0.69, 0.76 }, { 0.94, 0.95, 0.98 }

local function label(parent, x, y, width, height, font, color)
    local c = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(width, height)
    c:SetFont("$(BOLD_FONT)|" .. font .. "|soft-shadow-thin")
    c:SetColor(unpack(color or white))
    c:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return c
end

local function icon(parent, x, y, size)
    local c = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    c:SetDimensions(size, size)
    return c
end

local function section(parent, text, x, y, width)
    local c = label(parent, x, y, width, 30, 22, gold)
    c:SetText(text)
    return c
end

function L.Resize()
    if not L.window then return end
    L.window:SetScale(math.min(GuiRoot:GetWidth() * 0.94 / W, GuiRoot:GetHeight() * 0.88 / H))
end

function L.CreateUI()
    local root = WINDOW_MANAGER:CreateTopLevelWindow("LoadoutWindow")
    L.window = root
    root:SetDimensions(W, H)
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, -15)
    root:SetHidden(true)
    local bg = WINDOW_MANAGER:CreateControl(nil, root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.025, 0.035, 0.05, 1)
    bg:SetEdgeColor(0.55, 0.36, 0.13, 1)
    bg:SetEdgeTexture(nil, 1, 1, 2)
    L.heading = label(root, 30, 18, 1160, 40, 32, gold)
    L.identity = label(root, 30, 64, 1680, 32, 25)
    L.lines = label(root, 30, 101, 1030, 28, 20, muted)
    L.mundus = label(root, 1080, 101, 630, 28, 20, gold)
    local version = label(root, 1520, 24, 190, 25, 18, muted)
    version:SetText("Loadout " .. L.version)
    local author = label(root, 1230, 26, 270, 24, 18, muted)
    author:SetText("by @TheGreyWolf98")

    L.pages = {}
    for i = 1, 3 do
        local page = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
        page:SetAnchorFill(root)
        page:SetHidden(i ~= 1)
        L.pages[i] = page
    end
    local main = L.pages[1]
    L.statLabels = {}
    for i = 1, 14 do
        local x = 30 + ((i - 1) % 7) * 240
        local y = 139 + math.floor((i - 1) / 7) * 40
        L.statLabels[i] = label(main, x, y, 230, 36, 19)
    end
    section(main, "EQUIPPED GEAR", 30, 225, 840)
    L.gearLabels = {}
    for i = 1, 14 do
        local y = 260 + (i - 1) * 43
        L.gearLabels[i] = {
            slot = label(main, 30, y + 1, 120, 28, 19, muted),
            icon = icon(main, 154, y + 3, 32),
            name = label(main, 199, y, 666, 24, 20),
            detail = label(main, 199, y + 23, 666, 20, 16, muted),
        }
    end
    L.barHeadings = {
        section(main, "FRONT BAR", 900, 225, 385),
        section(main, "BACK BAR", 1310, 225, 390),
    }
    L.barLabels = { {}, {} }
    for bar = 1, 2 do
        local x = bar == 1 and 900 or 1310
        for i = 1, 6 do
            local y = 264 + (i - 1) * 42
            L.barLabels[bar][i] = {
                icon = icon(main, x, y + 1, 34),
                name = label(main, x + 43, y, 347, 26, 20),
                scripts = label(main, x + 43, y + 24, 347, 18, 15, muted),
            }
        end
    end
    section(main, "SLOTTED CHAMPION POINTS", 900, 520, 800)
    L.cpLabels = {}
    local trees = { { "Warfare", CHAMPION_DISCIPLINE_TYPE_COMBAT, {0.35, 0.7, 1} },
        { "Fitness", CHAMPION_DISCIPLINE_TYPE_CONDITIONING, {1, 0.45, 0.45} },
        { "Craft", CHAMPION_DISCIPLINE_TYPE_WORLD, {0.4, 0.85, 0.5} } }
    for treeIndex, tree in ipairs(trees) do
        local x = 900 + (treeIndex - 1) * 274
        section(main, tree[1], x, 555, 260):SetColor(unpack(tree[3]))
        L.cpLabels[tree[2]] = {}
        for i = 1, 4 do
            L.cpLabels[tree[2]][i] = label(main, x, 590 + (i - 1) * 44, 260, 42, 18, tree[3])
        end
    end
    section(main, "CLASS MASTERY", 900, 780, 800)
    L.masteryLabels = {}
    for i = 1, 2 do
        local x = i == 1 and 900 or 1310
        L.masteryLabels[i] = {
            icon = icon(main, x, 818, 34),
            name = label(main, x + 43, 815, 347, 28, 20, gold),
            rank = label(main, x + 43, 843, 347, 22, 16, muted),
        }
    end

    -- Detail pages keep complete enchantment descriptions and long scripts readable.
    L.detailHeading = section(L.pages[2], "GEAR DETAILS", 30, 145, 1680)
    L.detailLabels = {}
    for i = 1, 7 do
        local y = 194 + (i - 1) * 93
        L.detailLabels[i] = {
            name = label(L.pages[2], 30, y, 1680, 27, 23, gold),
            detail = label(L.pages[2], 30, y + 29, 1680, 25, 20),
            enchant = label(L.pages[2], 30, y + 55, 1680, 35, 18, muted),
        }
    end
    L.buffHeading = section(L.pages[3], "ACTIVE EFFECTS", 30, 145, 1680)
    L.buffLabels = {}
    for i = 1, 18 do
        L.buffLabels[i] = label(L.pages[3], 30, 191 + (i - 1) * 36, 1680, 32, 22)
    end
    L.poisons = label(main, 30, 856, 835, 24, 18, muted)
    L.note = label(root, 30, 883, 1680, 25, 18, muted)

    L.scene = ZO_Scene:New("loadout", SCENE_MANAGER)
    L.scene:AddFragment(ZO_SimpleSceneFragment:New(root))
    -- Stock fragments supply UI input routing, including gamepad shortcuts.
    L.scene:AddFragmentGroup(IsInGamepadPreferredMode() and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    L.keys = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { name = "Close", keybind = "UI_SHORTCUT_NEGATIVE", callback = function() SCENE_MANAGER:Hide("loadout") end },
        { name = "Next view", keybind = "UI_SHORTCUT_SECONDARY", callback = function() L.NextView() end },
        { name = "Refresh", keybind = "UI_SHORTCUT_TERTIARY", callback = function() L.Refresh() end },
    }
    L.scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            L.view = 1
            L.Resize()
            L.Refresh()
            KEYBIND_STRIP:AddKeybindButtonGroup(L.keys)
        elseif state == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(L.keys)
        end
    end)
    root:RegisterForEvent(EVENT_SCREEN_RESIZED, L.Resize)
    L.Resize()
end

function L.Paint()
    local d = L.snapshot
    if not d then return end
    L.heading:SetText(L.customTitle and L.customTitle ~= "" and L.customTitle or "LOADOUT")
    local a = d.attributes
    L.identity:SetText(string.format("%s  |  %s %s  |  Level %s / CP %s  |  Attributes H %s · M %s · S %s",
        d.name, d.race, d.class, d.level, d.cp, a[1] or "?", a[2] or "?", a[3] or "?"))
    L.lines:SetText("Class lines: " .. (d.lines ~= "" and d.lines or "Unavailable"))
    L.mundus:SetText("Mundus: " .. d.mundus)
    for i, stat in ipairs(d.stats) do L.statLabels[i]:SetText(stat.name .. ": " .. stat.value) end
    for i, row in ipairs(d.gear) do
        local c = L.gearLabels[i]
        c.slot:SetText(row.slot)
        c.name:SetText(row.setName and row.setName ~= "No set" and (row.setName .. " · " .. row.name) or row.name)
        c.detail:SetText(row.detail)
        c.icon:SetHidden(not row.icon)
        if row.icon then c.icon:SetTexture(row.icon) end
        local quality = row.quality and L.Read("GetItemQualityColor", row.quality)
        if quality then c.name:SetColor(quality:UnpackRGB()) else c.name:SetColor(unpack(white)) end
    end
    L.poisons:SetText("Poisons — Front: " .. d.poisons[1] .. "  |  Back: " .. d.poisons[2])
    for i, c in ipairs(L.masteryLabels) do
        local row = d.masteries[i]
        c.name:SetText(row and row.name or (d.masteryReadable and "None purchased" or "Not available"))
        c.rank:SetText(row and row.rank and row.maxRank and row.maxRank > 1 and ("Rank " .. row.rank .. "/" .. row.maxRank) or "")
        c.icon:SetHidden(not (row and row.icon and row.icon ~= ""))
        if row and row.icon and row.icon ~= "" then c.icon:SetTexture(row.icon) end
    end
    for barIndex, rows in ipairs({d.front, d.back}) do
        local active = d.activeCategory == (barIndex == 1 and HOTBAR_CATEGORY_PRIMARY or HOTBAR_CATEGORY_BACKUP)
        L.barHeadings[barIndex]:SetText((barIndex == 1 and "FRONT BAR" or "BACK BAR") .. (active and "  [ACTIVE]" or "")
            .. (d.pairLocked and not active and " [SWAP LOCKED]" or ""))
        for i, row in ipairs(rows) do
            local c = L.barLabels[barIndex][i]
            c.name:SetText((row.ultimate and "ULT · " or "") .. row.name)
            c.scripts:SetText(row.scripts or "")
            c.icon:SetHidden(not row.icon)
            if row.icon then c.icon:SetTexture(row.icon) end
        end
    end
    for _, labels in pairs(L.cpLabels) do for _, c in ipairs(labels) do c:SetText("Empty") end end
    local indices = {}
    for _, row in ipairs(d.champion) do
        local labels = row.discipline and L.cpLabels[row.discipline]
        if labels then
            indices[row.discipline] = (indices[row.discipline] or 0) + 1
            local c = labels[indices[row.discipline]]
            if c then c:SetText(row.name .. (row.points and (" · " .. row.points) or "")) end
        end
    end
    if #d.champion == 0 then
        for _, labels in pairs(L.cpLabels) do for _, c in ipairs(labels) do c:SetText("Unavailable") end end
    end
    local view = L.view or 1
    local page = view == 1 and 1 or view <= 3 and 2 or 3
    for i, c in ipairs(L.pages) do c:SetHidden(i ~= page) end
    if page == 2 then
        local offset = (view - 2) * 7
        L.detailHeading:SetText("GEAR DETAILS  " .. (view - 1) .. "/2  —  Full set names and enchantments")
        for i, c in ipairs(L.detailLabels) do
            local row = d.gear[offset + i]
            c.name:SetText(row.slot .. "  ·  " .. row.name)
            c.detail:SetText((row.setName or "") .. "  |  " .. row.detail)
            c.enchant:SetText(row.enchantDescription or "")
        end
    elseif page == 3 then
        local offset = (view - 4) * 18
        L.buffHeading:SetText("SCRIBING & ACTIVE EFFECTS  " .. (view - 3) .. "/" .. math.max(1, math.ceil(#d.buffs / 18))
            .. "  —  Food/drink and other effects as reported by the game")
        for i, c in ipairs(L.buffLabels) do
            local row = d.buffs[offset + i]
            c:SetText(row and row.name or (i == 1 and #d.buffs == 0 and "None detected" or ""))
        end
    end
    local special = d.activeCategory ~= HOTBAR_CATEGORY_PRIMARY and d.activeCategory ~= HOTBAR_CATEGORY_BACKUP
    L.note:SetText("Stats captured at " .. d.timestamp .. " · Active bar and buffs apply. "
        .. (special and "Special hotbar active; normal build bars shown. " or "")
        .. "Use your console's capture controls to share this build.")
end

function L.Refresh()
    L.snapshot = L.Capture()
    L.Paint()
end

function L.NextView()
    local maxView = 3 + math.max(1, math.ceil(#L.snapshot.buffs / 18))
    L.view = (L.view or 1) % maxView + 1
    L.Paint()
end

function L.Toggle()
    if not L.scene then L.CreateUI() end
    if L.scene:IsShowing() then SCENE_MANAGER:Hide("loadout") else SCENE_MANAGER:Show("loadout") end
end

local function loaded(_, name)
    if name ~= L.name then return end
    EVENT_MANAGER:UnregisterForEvent(L.name, EVENT_ADD_ON_LOADED)
    ZO_CreateStringId("SI_BINDING_NAME_LOADOUT_TOGGLE", "Open / close Loadout")
    SLASH_COMMANDS["/loadout"] = function(text)
        text = zo_strtrim(text or "")
        if text == "refresh" then
            if not L.scene or not L.scene:IsShowing() then L.Toggle() else L.Refresh() end
        elseif text:sub(1, 6) == "title " then
            L.customTitle = text:sub(7, 100)
            if L.scene and L.scene:IsShowing() then L.Paint() end
        elseif text == "title" then
            L.customTitle = nil
            if L.scene and L.scene:IsShowing() then L.Paint() end
        else L.Toggle() end
    end
end
EVENT_MANAGER:RegisterForEvent(L.name, EVENT_ADD_ON_LOADED, loaded)
