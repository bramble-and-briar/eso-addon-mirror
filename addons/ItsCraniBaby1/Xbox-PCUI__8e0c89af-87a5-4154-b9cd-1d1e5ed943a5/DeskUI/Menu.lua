local A, C = DeskUI, DeskUI.Core
local LAYER = "DeskUIMenu"
local function Print(text) if d then d("DeskUI: " .. text) end end

function A.InitializeSettings()
    DeskUI_Saved = type(DeskUI_Saved) == "table" and DeskUI_Saved or {}
    DeskUI_Saved.positions = type(DeskUI_Saved.positions) == "table" and DeskUI_Saved.positions or {}
    A.settings = DeskUI_Saved
    A.movable = A.movable or {}
end

function A.MakeMovable(control, id, parent, x, y, w)
    control:SetMovable(true); control:SetClampedToScreen(true)
    local entry = {control = control, id = id, parent = parent, x = x, y = y}
    A.movable[#A.movable + 1] = entry
    local saved = A.settings.positions[id]
    if saved and type(saved.x) == "number" and type(saved.y) == "number" then
        local sw, sh = GuiRoot:GetDimensions()
        control:ClearAnchors()
        control:SetAnchor(CENTER, GuiRoot, TOPLEFT, math.max(0, math.min(1, saved.x)) * sw,
            math.max(0, math.min(1, saved.y)) * sh)
    end
    local function Save()
        if not entry.dragging then return end
        entry.dragging = false; control:StopMovingOrResizing()
        local cx, cy = control:GetCenter()
        local sw, sh = GuiRoot:GetDimensions()
        if cx and cy and sw > 0 and sh > 0 then
            A.settings.positions[id] = {x = cx / sw, y = cy / sh}
        end
    end
    entry.stop = Save
    local header = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
    header:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0); header:SetDimensions(w, 44)
    header:SetMouseEnabled(true)
    header:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local cx, cy = control:GetCenter()
        local rx, ry = GuiRoot:GetCenter()
        control:ClearAnchors(); control:SetAnchor(CENTER, GuiRoot, CENTER, cx - rx, cy - ry)
        entry.dragging = control:StartMoving()
    end)
    header:SetHandler("OnMouseUp", function(_, button) if button == MOUSE_BUTTON_INDEX_LEFT then Save() end end)
    control:SetHandler("OnMoveStop", Save)
    entry.header = header
end

function A.StopDragging()
    for _, entry in ipairs(A.movable or {}) do entry.stop() end
end

function A.ResetPositions()
    A.StopDragging(); A.settings.positions = {}
    for _, entry in ipairs(A.movable) do
        entry.control:ClearAnchors()
        entry.control:SetAnchor(TOPLEFT, entry.parent, TOPLEFT, entry.x, entry.y)
    end
    Print("Panel positions reset.")
end

function A.Progression()
    local level = C.Try("GetUnitLevel", "player") or 0
    local champion = C.Try("IsUnitChampion", "player")
    if champion == nil then champion = level >= (C.Try("GetMaxLevel") or 50) end
    local points = C.Try("GetPlayerChampionPointsEarned")
    if champion and points ~= nil then
        return "CHAMPION " .. points, C.Try("GetPlayerChampionXP"), C.Try("GetNumChampionXPInChampionPoint", points)
    end
    return "LEVEL " .. level, C.Try("GetUnitXP", "player"), C.Try("GetUnitXPMax", "player")
end

function A.UpdateProgression()
    if not A.level then return end
    local title, xp, maxXP = A.Progression()
    A.level:SetText(title)
    A.experience:SetDimensions(xp and maxXP and maxXP > 0 and math.max(1, 250 * math.min(1, xp / maxXP)) or 1, 5)
end

function A.NativeCapabilities()
    local scene = SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene("inventory")
    return scene ~= nil and ZO_PlayerInventory ~= nil and PLAYER_INVENTORY ~= nil and ItemTooltip ~= nil
end

function A.OpenSettings()
    if not A.ready or not SCENE_MANAGER:IsShowing("deskUIInventory") then A.Toggle() end
    if A.ready then A.SetPage("Settings") end
end

function A.RequestLogout()
    A.StopDragging()
    local name = C.Try("IsInGamepadPreferredMode") and "GAMEPAD_LOG_OUT" or "LOG_OUT"
    -- Use registered native dialogs only; their confirmation performs logout.
    if ESO_Dialogs and ESO_Dialogs[name] then
        if name == "GAMEPAD_LOG_OUT" and ZO_Dialogs_ShowGamepadDialog then ZO_Dialogs_ShowGamepadDialog(name)
        elseif ZO_Dialogs_ShowDialog then ZO_Dialogs_ShowDialog(name)
        else Print("Logout dialog unavailable. Use ESO's Esc menu.") end
    else Print("Logout dialog unavailable. Use ESO's Esc menu.") end
end

function A.OpenOriginalInventory()
    A.StopDragging()
    local name = C.Try("IsInGamepadPreferredMode") and "gamepad_inventory_root" or "inventory"
    if SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(name) then SCENE_MANAGER:Show(name)
    else Print("Original inventory scene unavailable; use ESO's inventory key.") end
end

function A.OpenNativePCInventory()
    if C.Try("IsKeyboardUISupported") == false or not A.NativeCapabilities() then
        Print("Native PC inventory controls are unavailable in this client. Run /deskui diag to report capabilities.")
        return
    end
    A.StopDragging(); SCENE_MANAGER:Show("inventory")
end

function A.OpenOriginalCurrentMenu()
    local category, callback = A.PageCategory(A.activePage), nil
    if (category == "System" or category == "Settings") and type(ZO_SceneManager_ToggleGameMenuBinding) == "function" then
        callback = ZO_SceneManager_ToggleGameMenuBinding
    elseif category == "Help" and HELP_MANAGER and type(HELP_MANAGER.ToggleHelp) == "function" then
        callback = function() HELP_MANAGER:ToggleHelp() end
    elseif SYSTEMS and type(SYSTEMS.GetObject) == "function" then
        local ok, menu = pcall(SYSTEMS.GetObject, SYSTEMS, "mainMenu")
        if ok and menu and type(menu.ToggleCategory) == "function" then
            for _, definition in ipairs(A.MenuDefinitions) do
                if definition.label == category and _G[definition.id] ~= nil then
                    local id = _G[definition.id]
                    callback = function() menu:ToggleCategory(id) end
                    break
                end
            end
        end
    end
    if not callback then
        if category == "Inventory" then A.OpenOriginalInventory()
        else Print("Original menu unavailable here. Use /deskui shortcuts off, then your normal menu key.") end
        return
    end
    A.Close()
    local ok, err = pcall(callback)
    if not ok then Print("Could not open original menu: " .. tostring(err) .. ". Use /deskui shortcuts off to restore normal menu keys.") end
end

function A.SetMenuKeyActive(active)
    if active and not A.menuKeyActive and PushActionLayerByName then
        PushActionLayerByName(LAYER); A.menuKeyActive = true
    elseif not active and A.menuKeyActive and RemoveActionLayerByName then
        RemoveActionLayerByName(LAYER); A.menuKeyActive = false
    end
    A.UpdateReplacementLayer()
end

function A.UpdateReplacementLayer()
    local enabled = A.menuKeyActive and A.settings.replaceMenus ~= false and not A.menuTextFocus
    if enabled and not A.replacementLayerActive and PushActionLayerByName then
        PushActionLayerByName("DeskUIReplacements"); A.replacementLayerActive = true
    elseif not enabled and A.replacementLayerActive and RemoveActionLayerByName then
        RemoveActionLayerByName("DeskUIReplacements"); A.replacementLayerActive = false
    end
    local page = A.pages and A.pages.Settings
    if page and page.toggles.replaceMenus then page.toggles.replaceMenus.label:SetText(A.settings.replaceMenus ~= false and "On" or "Off") end
end

function A.ConfigureMenuEditBox(box)
    box:SetHandler("OnFocusGained", function() A.menuTextFocus = true; A.UpdateReplacementLayer() end)
    box:SetHandler("OnFocusLost", function() A.menuTextFocus = false; A.UpdateReplacementLayer() end)
end

function A.DefaultMenuKey(category)
    if A.failed or A.settings.replaceMenus == false or A.menuTextFocus then return false end
    if C.Try("ZO_Dialogs_IsShowingDialog") then return false end
    if not (SCENE_MANAGER:IsShowing("deskUIInventory") or SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")) then return false end
    if WINDOW_MANAGER.GetFocusControl and WINDOW_MANAGER:GetFocusControl() then return false end
    if SCENE_MANAGER:IsShowing("deskUIInventory") and A.PageCategory(A.activePage) == category then A.Close(); return true end
    if not A.ready or not SCENE_MANAGER:IsShowing("deskUIInventory") then A.Toggle() end
    if A.ready and SCENE_MANAGER:IsShowing("deskUIInventory") then A.SetPage(category); return true end
    return false
end

function A.InstallMenuKey()
    if not A.menuKeyInstalled and CreateDefaultActionBind and KEY_ALT then
        local ok, err = pcall(CreateDefaultActionBind, "DESKUI_MENU_ALT", KEY_ALT)
        if not ok then Print("Alt binding unavailable: " .. tostring(err)); return end
        A.menuKeyInstalled = true
        for _, name in ipairs({"hud", "hudui"}) do
            local scene = SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(name)
            if scene then
                scene:RegisterCallback("StateChange", function(_, state)
                    if state == SCENE_SHOWING then A.SetMenuKeyActive(true)
                    elseif state == SCENE_HIDING then A.SetMenuKeyActive(false) end
                end)
            end
        end
    end
    if SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui") then A.SetMenuKeyActive(true) end
end

function A.MenuKey()
    -- Chat, dialogs, and native settings retain their own input layers.
    if A.failed or C.Try("ZO_Dialogs_IsShowingDialog") then return end
    if SCENE_MANAGER:IsShowing("deskUIInventory") or SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui") then
        A.Toggle()
    end
end
