local A, C, S = DeskUI, DeskUI.Core, DeskUI.Style
local P = S.palette
A.JournalPages = {Quests = true, ["Lore Library"] = true, Achievements = true}
A.journalTabs = {"Quests", "Antiquities Codex", "Cadwell's Almanac", "Lore Library", "Achievements", "Leaderboards"}

local function Status(text) A.shellStatus:SetText(text or "") end

-- Own controls and direct font recipes avoid keyboard-only templates on Xbox.
function S.MenuIcon(parent, x, y, size, label, icons, callback)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    button:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y); button:SetDimensions(size, size)
    button.label = S.Label(button, 0, size, size, 1, "") -- common selection interface
    button.icon = S.Icon(button, 0, 0, size, icons.normal)
    button.available, button.icons = callback ~= nil, icons
    function button:Paint(hover)
        local path = not self.available and self.icons.disabled
            or (self.selected and self.icons.pressed) or (hover and self.icons.highlight) or self.icons.normal
        self.icon:SetTexture(path or self.icons.normal)
        self.icon:SetColor(unpack(self.available and P.text or P.muted))
    end
    button:SetMouseEnabled(true)
    button:SetHandler("OnClicked", function()
        if callback then callback() else Status(label .. " - not available in DeskUI 0.6.0") end
    end)
    button:SetHandler("OnMouseEnter", function()
        button:Paint(true); Status(label .. (callback and "" or " - not available in DeskUI 0.6.0"))
    end)
    button:SetHandler("OnMouseExit", function() button:Paint(false); Status(A.ShellHint()) end)
    button:Paint(false)
    return button
end

function A.ShellHint()
    return "Alt: close    /    Drag panel headers to arrange    /    System: settings and log out"
end

function A.BuildShell()
    A.shellStatus = S.Label(A.root, 420, 80, 1135, 28, A.ShellHint(), P.muted, 17)
    A.childBars, A.rootIcons = {}, {}
    local callbacks = {Inventory = function() A.SetPage("Inventory") end,
        Character = function() A.SetPage("Character") end, Journal = function() A.SetPage("Journal") end,
        Map = function() A.SetPage("Map") end}
    for category in pairs(A.RootDefaults) do
        local target = category
        callbacks[target] = function() A.SetPage(target) end
    end
    for index, definition in ipairs(A.MenuDefinitions) do
        local button = S.MenuIcon(A.root, 410 + (index - 1) * 67, 18, 51,
            definition.label, definition.icons, callbacks[definition.label])
        A.rootIcons[definition.label] = button
        if callbacks[definition.label] then A.navigation[definition.label] = button end
    end
    S.Button(A.root, 1585, 24, 130, 35, "System", function() A.OpenSystem() end)
    S.Button(A.root, 1726, 24, 98, 35, "Close", A.Close)
    S.Button(A.root, 1585, 78, 130, 32, "Refresh", A.RefreshCurrentPage)
    S.Button(A.root, 1726, 78, 98, 32, "Original", A.OpenOriginalCurrentMenu)
    local journalBar = WINDOW_MANAGER:CreateControl(nil, A.root, CT_CONTROL)
    journalBar:SetAnchor(TOPLEFT, A.root, TOPLEFT, 420, 133); journalBar:SetDimensions(1404, 44)
    A.childBars.Journal = journalBar; A.journalButtons = {}
    for index, name in ipairs(A.journalTabs) do
        local target = name
        local button = S.Button(journalBar, (index - 1) * 234, 0, 226, 38, name, function()
            if A.JournalPages[target] then A.SetPage(target)
            else Status(target .. " - not available in DeskUI 0.6.0") end
        end)
        A.journalButtons[name] = button
    end
    A.familyButtons = {}
    for category, tabs in pairs(A.FamilyTabs) do
        local bar = WINDOW_MANAGER:CreateControl(nil, A.root, CT_CONTROL)
        bar:SetAnchor(TOPLEFT, A.root, TOPLEFT, 420, 133); bar:SetDimensions(1404, 44)
        A.childBars[category], A.familyButtons[category] = bar, {}
        local step = 1404 / #tabs
        for index, tab in ipairs(tabs) do
            local target, label = tab[2], tab[1]
            local button = S.Button(bar, (index - 1) * step, 0, step - 8, 38, label, function()
                if target then A.SetPage(target)
                else Status(label .. " - not available in DeskUI " .. A.version) end
            end)
            A.familyButtons[category][index] = {control = button, target = target}
        end
    end
    -- Filter textures come from ZOS's itemfilterutils.lua, including irregular jewelry names.
    A.filterIcons = {}
    for index, definition in ipairs(A.FilterDefinitions) do
        local target = definition.label
        local button = S.MenuIcon(A.inventoryPanel, 16 + (index - 1) * 58, 51, 40,
            target, definition.icons, function() A.category = target; A.Filter(true); A.UpdateShell() end)
        A.filterIcons[target] = button
    end
    A.UpdateShell()
end

function A.UpdateShell()
    local category = A.PageCategory(A.activePage)
    for name, button in pairs(A.rootIcons) do button.selected = name == category; button:Paint(false) end
    for name, bar in pairs(A.childBars) do bar:SetHidden(name ~= category) end
    for name, button in pairs(A.journalButtons) do
        button.label:SetColor(unpack(A.JournalPages[name] and (name == A.activePage and P.accent or P.text) or P.muted))
    end
    for name, button in pairs(A.filterIcons) do button.selected = name == A.category; button:Paint(false) end
    for _, buttons in pairs(A.familyButtons) do
        for _, entry in ipairs(buttons) do
            entry.control.label:SetColor(unpack(entry.target and (entry.target == A.activePage and P.accent or P.text) or P.muted))
        end
    end
    Status(A.ShellHint())
end

function A.OpenSystem()
    if not A.ready or not SCENE_MANAGER:IsShowing("deskUIInventory") then A.Toggle() end
    if A.ready then
        if A.activePage ~= "System" and A.activePage ~= "Settings" then A.resumePage = A.activePage end
        A.SetPage("System")
    end
end

function A.Back()
    if A.activePage == "Settings" then A.SetPage("System")
    elseif A.activePage == "System" then A.SetPage(A.resumePage or "Inventory")
    else A.Close() end
end

function A.BuildSystemPage()
    local root = WINDOW_MANAGER:CreateControl(nil, A.root, CT_CONTROL)
    root:SetAnchor(TOPLEFT, A.root, TOPLEFT, 700, 238); root:SetDimensions(440, 630)
    S.Panel(root, 0, 0, 440, 630, nil, true)
    S.Label(root, 30, 10, 380, 38, "SYSTEM", P.text, 30, true)
    local entries = {{"Resume DeskUI", function() A.SetPage(A.resumePage or "Inventory") end},
        {"Settings", A.OpenSettings}, {"Reset panel positions", A.ResetPositions},
        {"Original inventory", A.OpenOriginalInventory}, {"Log Out", A.RequestLogout}, {"Return to game", A.Close}}
    for index, entry in ipairs(entries) do S.Button(root, 35, 76 + (index - 1) * 65, 370, 48, entry[1], entry[2]) end
    S.Label(root, 35, 487, 370, 110, "Log Out opens ESO's confirmation. Full game settings and controls remain in ESO's Esc menu.", P.muted, 19)
    A.MakeMovable(root, "system", A.root, 700, 238, 440)
    return {root = root}
end

function A.BuildCharacterPage()
    local root = WINDOW_MANAGER:CreateControl(nil, A.root, CT_CONTROL)
    root:SetAnchor(TOPLEFT, A.root, TOPLEFT, 1200, 238); root:SetDimensions(624, 660)
    S.Panel(root, 0, 0, 624, 660, nil, true)
    local title = S.Label(root, 24, 12, 576, 66, "CHARACTER", P.text, 26, true)
    S.Rule(root, 24, 90, 576)
    local body = S.Label(root, 24, 115, 576, 510, "", P.accent, 21)
    A.MakeMovable(root, "character", A.root, 1200, 238, 624)
    return {root = root, title = title, body = body}
end

function A.RefreshCharacter()
    local page = A.pages.Character
    page.title:SetText((C.Try("GetUnitName", "player") or "Character") .. "\n" .. A.Progression())
    local lines = {"Class: " .. (C.Try("GetUnitClass", "player") or "Unavailable"),
        "Race: " .. (C.Try("GetUnitRace", "player") or "Unavailable"), ""}
    for _, stat in ipairs({{"Maximum Magicka", "MAGICKA_MAX"}, {"Magicka Recovery", "MAGICKA_REGEN_COMBAT"},
        {"Maximum Health", "HEALTH_MAX"}, {"Health Recovery", "HEALTH_REGEN_COMBAT"},
        {"Maximum Stamina", "STAMINA_MAX"}, {"Stamina Recovery", "STAMINA_REGEN_COMBAT"},
        {"Spell Damage", "SPELL_POWER"}, {"Weapon Damage", "POWER"},
        {"Spell Resistance", "SPELL_RESIST"}, {"Physical Resistance", "PHYSICAL_RESIST"}}) do
        local id = _G["STAT_" .. stat[2]]
        local value = id and C.Try("GetPlayerStat", id, STAT_BONUS_OPTION_APPLY_BONUS)
        lines[#lines + 1] = stat[1] .. ": " .. tostring(value or "Unavailable")
    end
    page.body:SetText(table.concat(lines, "\n")); A.UpdateProgression()
end

-- Source-derived icon registry, API 101051.
A.MenuDefinitions = {
    {label = "Crown Store", id = "MENU_CATEGORY_MARKET", icons = {normal = "EsoUI/Art/MainMenu/menuBar_market_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_market_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_market_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_market_disabled.dds"}},
    {label = "Crown Crates", id = "MENU_CATEGORY_CROWN_CRATES", icons = {normal = "EsoUI/Art/MainMenu/menuBar_crownCrates_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_crownCrates_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_crownCrates_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_crownCrates_disabled.dds"}},
    {label = "Tamriel Tomes", id = "MENU_CATEGORY_TAMRIEL_TOMES", icons = {normal = "EsoUI/Art/MainMenu/menuBar_tamrielTomes_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_tamrielTomes_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_tamrielTomes_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_tamrielTomes_disabled.dds"}},
    {label = "Inventory", id = "MENU_CATEGORY_INVENTORY", icons = {normal = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_inventory_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_inventory_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_inventory_disabled.dds"}},
    {label = "Character", id = "MENU_CATEGORY_CHARACTER", icons = {normal = "EsoUI/Art/MainMenu/menuBar_character_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_character_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_character_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_character_disabled.dds"}},
    {label = "Skills", id = "MENU_CATEGORY_SKILLS", icons = {normal = "EsoUI/Art/MainMenu/menuBar_skills_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_skills_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_skills_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_skills_disabled.dds"}},
    {label = "Champion", id = "MENU_CATEGORY_CHAMPION", icons = {normal = "EsoUI/Art/MainMenu/menuBar_champion_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_champion_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_champion_over.dds"}},
    {label = "Journal", id = "MENU_CATEGORY_JOURNAL", icons = {normal = "EsoUI/Art/MainMenu/menuBar_journal_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_journal_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_journal_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_journal_disabled.dds"}},
    {label = "Collections", id = "MENU_CATEGORY_COLLECTIONS", icons = {normal = "EsoUI/Art/MainMenu/menuBar_collections_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_collections_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_collections_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_collections_disabled.dds"}},
    {label = "Map", id = "MENU_CATEGORY_MAP", icons = {normal = "EsoUI/Art/MainMenu/menuBar_map_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_map_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_map_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_map_disabled.dds"}},
    {label = "Group & Activity Finder", id = "MENU_CATEGORY_GROUP", icons = {normal = "EsoUI/Art/MainMenu/menuBar_group_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_group_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_group_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_group_disabled.dds"}},
    {label = "Friends", id = "MENU_CATEGORY_CONTACTS", icons = {normal = "EsoUI/Art/MainMenu/menuBar_social_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_social_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_social_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_social_disabled.dds"}},
    {label = "Guilds", id = "MENU_CATEGORY_GUILDS", icons = {normal = "EsoUI/Art/MainMenu/menuBar_guilds_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_guilds_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_guilds_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_guilds_disabled.dds"}},
    {label = "Alliance War", id = "MENU_CATEGORY_ALLIANCE_WAR", icons = {normal = "EsoUI/Art/MainMenu/menuBar_ava_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_ava_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_ava_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_ava_disabled.dds"}},
    {label = "Mail", id = "MENU_CATEGORY_MAIL", icons = {normal = "EsoUI/Art/MainMenu/menuBar_mail_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_mail_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_mail_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_mail_disabled.dds"}},
    {label = "Notifications", id = "MENU_CATEGORY_NOTIFICATIONS", icons = {normal = "EsoUI/Art/MainMenu/menuBar_notifications_up.dds", pressed = "EsoUI/Art/MainMenu/menuBar_notifications_down.dds", highlight = "EsoUI/Art/MainMenu/menuBar_notifications_over.dds", disabled = "EsoUI/Art/MainMenu/menuBar_notifications_disabled.dds"}},
    {label = "Help", id = "MENU_CATEGORY_HELP", icons = {normal = "EsoUI/Art/MenuBar/menuBar_help_up.dds", pressed = "EsoUI/Art/MenuBar/menuBar_help_down.dds", highlight = "EsoUI/Art/MenuBar/menuBar_help_over.dds", disabled = "EsoUI/Art/MenuBar/menuBar_help_disabled.dds"}},
}
A.FilterDefinitions = {
    {label = "All", icons = {normal = "EsoUI/Art/Inventory/inventory_tabIcon_all_up.dds", pressed = "EsoUI/Art/Inventory/inventory_tabIcon_all_down.dds", highlight = "EsoUI/Art/Inventory/inventory_tabIcon_all_over.dds", disabled = "EsoUI/Art/Inventory/inventory_tabIcon_all_disabled.dds"}},
    {label = "Weapons", icons = {normal = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_up.dds", pressed = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_down.dds", highlight = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_over.dds"}},
    {label = "Armor", icons = {normal = "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds", pressed = "EsoUI/Art/Inventory/inventory_tabIcon_armor_down.dds", highlight = "EsoUI/Art/Inventory/inventory_tabIcon_armor_over.dds"}},
    {label = "Jewelry", icons = {normal = "EsoUI/Art/Crafting/jewelry_tabIcon_icon_up.dds", pressed = "EsoUI/Art/Crafting/jewelry_tabIcon_down.dds", highlight = "EsoUI/Art/Crafting/jewelry_tabIcon_icon_over.dds"}},
    {label = "Consumables", icons = {normal = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_up.dds", pressed = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_down.dds", highlight = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_over.dds"}},
    {label = "Crafting", icons = {normal = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_up.dds", pressed = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_down.dds", highlight = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_over.dds"}},
    {label = "Furnishing", icons = {normal = "EsoUI/Art/Crafting/provisioner_indexIcon_furnishings_up.dds", pressed = "EsoUI/Art/Crafting/provisioner_indexIcon_furnishings_down.dds", highlight = "EsoUI/Art/Crafting/provisioner_indexIcon_furnishings_over.dds"}},
    {label = "Companion", icons = {normal = "EsoUI/Art/Inventory/inventory_tabIcon_companion_up.dds", pressed = "EsoUI/Art/Inventory/inventory_tabIcon_companion_down.dds", highlight = "EsoUI/Art/Inventory/inventory_tabIcon_companion_over.dds"}},
    {label = "Miscellaneous", icons = {normal = "EsoUI/Art/Inventory/inventory_tabIcon_misc_up.dds", pressed = "EsoUI/Art/Inventory/inventory_tabIcon_misc_down.dds", highlight = "EsoUI/Art/Inventory/inventory_tabIcon_misc_over.dds"}},
    {label = "Junk", icons = {normal = "EsoUI/Art/Inventory/inventory_tabIcon_junk_up.dds", pressed = "EsoUI/Art/Inventory/inventory_tabIcon_junk_down.dds", highlight = "EsoUI/Art/Inventory/inventory_tabIcon_junk_over.dds"}},
}
