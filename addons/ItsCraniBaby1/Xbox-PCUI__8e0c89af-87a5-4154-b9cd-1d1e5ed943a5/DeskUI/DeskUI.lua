local A = DeskUI
local C = A.Core
A.name, A.version = "DeskUI", "0.6.0"
local SCENE = "deskUIInventory"
local ROWS = 8
local palette = A.Style.palette
local function Print(message) if d then d("DeskUI: " .. tostring(message)) end end

function A.Diagnostics()
    local function Value(name)
        if type(_G[name]) ~= "function" then return "unavailable" end
        local ok, value = pcall(_G[name]); return ok and tostring(value) or "error"
    end
    Print("v" .. A.version .. " | API " .. Value("GetAPIVersion")
        .. " | console=" .. Value("IsConsoleUI") .. " | gamepad=" .. Value("IsInGamepadPreferredMode"))
    Print("scene=" .. tostring(ZO_Scene ~= nil) .. " | cursor fragment=" .. tostring(MOUSE_UI_MODE_FRAGMENT ~= nil)
        .. " | inventory=" .. tostring(type(GetItemInfo) == "function"))
    Print("keyboard UI supported=" .. Value("IsKeyboardUISupported")
        .. " | native PC inventory available=" .. tostring(A.NativeCapabilities())
        .. " | Alt registered=" .. tostring(A.menuKeyInstalled == true))
    Print("shell=PC hierarchy | silhouette API=" .. tostring(type(GetUnitSilhouetteTexture) == "function")
        .. " | item filters=" .. tostring(type(ZO_InventoryUtils_DoesNewItemMatchFilterType) == "function")
        .. " | character stats=" .. tostring(type(GetPlayerStat) == "function"))
    Print("menu replacement=" .. tostring(A.settings.replaceMenus ~= false)
        .. " | layer=" .. tostring(A.replacementLayerActive == true)
        .. " | inherited inventory action=" .. tostring(C.Try("GetActionIndicesFromName", "DESKUI_REPLACE_INVENTORY") ~= nil))
    if A.lastError then Print("Last error: " .. A.lastError) end
end

function A.Close()
    A.StopDragging()
    A.LoseSearchFocus()
    if SCENE_MANAGER:IsShowing(SCENE) then SCENE_MANAGER:HideCurrentScene() end
end

function A.Select(item)
    A.selectedSlot = item and item.slot or nil
    A.selectedBag = item and item.bag or nil
    A.Style.FillCard(A.itemCard, item, "Select an item")
    A.Style.FillCard(A.compareCard, C.Comparison(item, A.equipment), "No matching worn item")
end

function A.Render()
    local selected
    A.offset = C.ClampOffset(A.offset, #A.filtered, ROWS)
    if A.selectedBag == BAG_WORN then selected = A.equipment[A.selectedSlot]
    else
        for _, item in ipairs(A.filtered) do if item.slot == A.selectedSlot then selected = item; break end end
    end
    if not selected then selected = A.filtered[1] end
    A.Select(selected)
    for i, row in ipairs(A.rows) do
        local item = A.filtered[A.offset + i]
        row.item = item; row:SetHidden(item == nil)
        if item then
            row.icon:SetTexture(item.icon)
            row.nameLabel:SetText(item.name)
            row.nameLabel:SetColor(C.QualityColor(item.quality))
            row.stackLabel:SetText(tostring(item.stack)); row.valueLabel:SetText(tostring(item.value))
            local active = item.slot == A.selectedSlot and A.selectedBag == BAG_BACKPACK
            row.selection:SetHidden(not active)
            if active then row.background:SetCenterColor(0.19, 0.39, 0.42, 0.72)
            else row.background:SetCenterColor(0, 0, 0, 0.10) end
        end
    end
    local first = #A.filtered > 0 and A.offset + 1 or 0
    local gold = C.Try("GetCurrencyAmount", CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
    A.count:SetText(string.format("Inventory space: %d/%d    |    %d-%d of %d\nGold: %s",
        #A.items, GetBagSize(BAG_BACKPACK), first, math.min(A.offset + ROWS, #A.filtered), #A.filtered, tostring(gold or "-")))
    for _, button in ipairs(A.gearSlots) do
        local item = A.equipment[button.slot]
        button.icon:SetTexture(item and item.icon or button.fallback)
    end
    A.empty:SetHidden(#A.filtered > 0)
    A.empty:SetText(#A.items == 0 and "Your backpack is empty." or "No items match your search.")
    for name, button in pairs(A.categories) do
        button.label:SetColor(unpack(name == A.category and palette.accent or palette.text))
    end
    for key, button in pairs(A.sortButtons) do
        local titles = {name = "NAME", stack = "QTY", value = "VALUE"}
        button.label:SetText(titles[key] .. (key == A.sortKey and (A.descending and " -" or " +") or ""))
    end
end

function A.Filter(reset)
    if reset then A.offset = 0 end
    A.filtered = C.Filter(A.items, A.search:GetText(), A.category, A.sortKey, A.descending)
    A.Render()
end

function A.Refresh()
    local ok, result = pcall(C.ReadBackpack)
    if not ok then A.lastError = tostring(result); Print("Could not read backpack: " .. A.lastError); return end
    A.items = result
    A.detailRevision = (A.detailRevision or 0) + 1
    local equipmentOK, equipment = pcall(C.ReadEquipment)
    A.equipment = equipmentOK and equipment or {}
    if not equipmentOK then A.lastError = tostring(equipment); Print("Equipment details unavailable: " .. A.lastError) end
    A.UpdateProgression()
    A.Filter(false)
end

function A.Scroll(delta)
    A.offset = C.ClampOffset(A.offset - delta * 3, #A.filtered, ROWS); A.Render()
end

function A.CreateUI()
    A.BuildLayout()
    local root = A.root
    A.scene = ZO_Scene:New(SCENE, SCENE_MANAGER)
    A.scene:AddFragment(ZO_SimpleSceneFragment:New(root))
    -- Shared scene fragments work without loading the keyboard inventory scene.
    A.scene:AddFragment(MOUSE_UI_MODE_FRAGMENT)
    if UI_SHORTCUTS_ACTION_LAYER_FRAGMENT then A.scene:AddFragment(UI_SHORTCUTS_ACTION_LAYER_FRAGMENT) end
    A.backKeys = {{name = "Back", keybind = "UI_SHORTCUT_NEGATIVE", ethereal = true, callback = A.Back}}
    A.scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            A.EnterMenuPage(A.activePage, nil)
            A.RefreshCurrentPage()
            A.SetMenuKeyActive(true)
            if KEYBIND_STRIP then KEYBIND_STRIP:AddKeybindButtonGroup(A.backKeys) end
        elseif state == SCENE_HIDING then
            A.CloseDeskMailbox()
            A.StopDragging()
            A.SetMenuKeyActive(false)
            A.LoseSearchFocus()
            if KEYBIND_STRIP then KEYBIND_STRIP:RemoveKeybindButtonGroup(A.backKeys) end
        end
    end)
    A.ready = true
end

function A.Toggle()
    if not A.ready then
        if not (ZO_Scene and ZO_SimpleSceneFragment and SCENE_MANAGER and MOUSE_UI_MODE_FRAGMENT) then
            Print("Required scene/cursor APIs unavailable. Run /deskui diag."); return
        end
        local ok, err = pcall(A.CreateUI)
        if not ok then
            A.lastError = tostring(err)
            if A.root then A.root:SetHidden(true) end
            Print("Could not initialize: " .. A.lastError .. ". Reload UI before retrying.")
            A.failed = true; return
        end
    end
    if SCENE_MANAGER:IsShowing(SCENE) then A.Close() else SCENE_MANAGER:Show(SCENE) end
end

local function OnLoaded(_, name)
    if name ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A.InitializeSettings()
    A.InstallMenuEvents()
    ZO_CreateStringId("SI_BINDING_NAME_DESKUI_MENU_ALT", "Open DeskUI menu with Alt")
    ZO_CreateStringId("SI_BINDING_NAME_DESKUI_TOGGLE", "Open DeskUI interface")
    SLASH_COMMANDS["/deskui"] = function(argument)
        argument = string.lower(argument or "")
        if argument == "diag" then A.Diagnostics()
        elseif argument == "shortcuts off" or argument == "shortcuts on" then
            A.settings.replaceMenus = argument == "shortcuts on"; A.UpdateReplacementLayer()
            Print("Menu shortcut replacement " .. (A.settings.replaceMenus and "enabled." or "disabled."))
        elseif argument == "reset" then A.ResetPositions()
        elseif argument == "settings" then A.OpenSettings()
        elseif argument == "quests" or argument == "journal" then
            if not A.ready or not SCENE_MANAGER:IsShowing(SCENE) then A.Toggle() end
            if A.ready then A.SetPage(argument == "quests" and "Quests" or "Journal") end
        elseif argument == "logout" then A.RequestLogout()
        elseif argument == "original" then A.OpenOriginalInventory()
        elseif argument == "native" then A.OpenNativePCInventory()
        elseif A.failed then Print("Initialization failed; reload UI before retrying.")
        else A.Toggle() end
    end
    EVENT_MANAGER:RegisterForEvent(A.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bag)
        if (bag == BAG_BACKPACK or bag == BAG_WORN) and A.ready and SCENE_MANAGER:IsShowing(SCENE) then
            EVENT_MANAGER:UnregisterForUpdate("DeskUIRefresh")
            EVENT_MANAGER:RegisterForUpdate("DeskUIRefresh", 100, function()
                EVENT_MANAGER:UnregisterForUpdate("DeskUIRefresh")
                if SCENE_MANAGER:IsShowing(SCENE) then A.Refresh() end
            end)
        end
    end)
    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent("DeskUIMenuKey", EVENT_PLAYER_ACTIVATED, A.InstallMenuKey)
    end
    A.InstallMenuKey()
    for _, name in ipairs({"EVENT_EXPERIENCE_UPDATE", "EVENT_LEVEL_UPDATE", "EVENT_CHAMPION_POINT_UPDATE", "EVENT_CHAMPION_POINT_GAINED"}) do
        if _G[name] then
            EVENT_MANAGER:RegisterForEvent("DeskUIProgress", _G[name], function()
                if A.ready and SCENE_MANAGER:IsShowing(SCENE) then A.UpdateProgression() end
            end)
        end
    end
    for _, event in ipairs({"EVENT_QUEST_ADDED", "EVENT_QUEST_REMOVED", "EVENT_QUEST_ADVANCED", "EVENT_QUEST_CONDITION_COUNTER_CHANGED", "EVENT_QUEST_ASSISTED_STATE_CHANGED", "EVENT_LORE_BOOK_LEARNED", "EVENT_ACHIEVEMENT_AWARDED"}) do
        if _G[event] then
            EVENT_MANAGER:RegisterForEvent("DeskUIJournal", _G[event], function()
                if A.ready and SCENE_MANAGER:IsShowing(SCENE) and A.JournalPages[A.activePage] then
                    EVENT_MANAGER:UnregisterForUpdate("DeskUIJournalRefresh")
                    EVENT_MANAGER:RegisterForUpdate("DeskUIJournalRefresh", 150, function()
                        EVENT_MANAGER:UnregisterForUpdate("DeskUIJournalRefresh")
                        if SCENE_MANAGER:IsShowing(SCENE) then A.RefreshCurrentPage() end
                    end)
                end
            end)
        end
    end
    Print("v" .. A.version .. " loaded. Type /deskui to open; /deskui diag for diagnostics.")
end
EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, OnLoaded)
