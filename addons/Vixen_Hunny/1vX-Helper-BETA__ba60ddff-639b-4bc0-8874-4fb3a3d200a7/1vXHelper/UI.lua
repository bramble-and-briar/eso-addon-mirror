-- 1vX Helper - shared UI helpers (movable HUD windows)
local addon = OneVXHelper
local UI = {}
addon.UI = UI

local WM = WINDOW_MANAGER
UI.windows = {}

function UI.Font(face, size, effect)
    return string.format("$(%s)|%d|%s", face, size, effect or "soft-shadow-thick")
end

function UI.Label(name, parent, font, r, g, b, a)
    local l = WM:CreateControl(name, parent, CT_LABEL)
    l:SetFont(font)
    l:SetColor(r or 1, g or 1, b or 1, a or 1)
    return l
end

local function SavePosition(win)
    addon.sv.ui.positions[win.id] = { x = win.tlw:GetLeft(), y = win.tlw:GetTop() }
end

function UI.Restore(win)
    local p = addon.sv.ui.positions[win.id]
    win.tlw:ClearAnchors()
    if p then
        win.tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, p.x, p.y)
    else
        win.tlw:SetAnchor(CENTER, GuiRoot, CENTER, win.defX, win.defY)
    end
end

---------------------------------------------------------------------------
-- Visibility
-- Windows are shown/hidden by the add-on itself (not scene fragments), so they
-- can't get stuck hidden. Visible when: enabled AND (UI unlocked OR the current
-- scene is the HUD, HUD-with-cursor, or a siege weapon view).
---------------------------------------------------------------------------
local HUD_SCENE_NAMES = { hud = true, hudui = true, siegeBar = true, siegeBarUI = true }

local function IsHudScene(scene)
    if not scene then return false end
    if scene == HUD_SCENE or scene == HUD_UI_SCENE then return true end
    if SIEGE_BAR_SCENE and scene == SIEGE_BAR_SCENE then return true end
    if SIEGE_BAR_UI_SCENE and scene == SIEGE_BAR_UI_SCENE then return true end
    local name = scene.GetName and scene:GetName()
    return name ~= nil and HUD_SCENE_NAMES[name] == true
end

function UI.IsHudShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    if scene then return IsHudScene(scene) end
    -- no scene yet (very early in loading): fall back to the HUD scene states
    return (HUD_SCENE and HUD_SCENE:IsShowing()) or (HUD_UI_SCENE and HUD_UI_SCENE:IsShowing()) or false
end

function UI.UpdateVisibility(win)
    local visible = win.enabled and (addon.unlocked or UI.IsHudShowing())
    win.tlw:SetHidden(not visible)
end

function UI.UpdateVisibilityAll()
    for _, win in pairs(UI.windows) do UI.UpdateVisibility(win) end
end

function UI.ApplyLock(win)
    local unlocked = (addon.unlocked and win.enabled) and true or false
    local movable = (unlocked or (win.opts.alwaysMovable and win.enabled)) and true or false
    win.tlw:SetMovable(movable)
    win.tlw:SetMouseEnabled(movable)
    win.bg:SetHidden(not unlocked)
    win.tag:SetHidden(not unlocked)
    UI.UpdateVisibility(win)
    if win.onPreview then win.onPreview(unlocked) end
end

function UI.ApplyLockAll()
    for _, win in pairs(UI.windows) do UI.ApplyLock(win) end
end

function UI.SetEnabled(win, enabled)
    win.enabled = enabled and true or false
    win.content:SetHidden(not win.enabled)
    UI.ApplyLock(win)
end

function UI.ResetPositions()
    addon.sv.ui.positions = {}
    for _, win in pairs(UI.windows) do UI.Restore(win) end
end

-- Re-anchor and re-show everything (called after every loading screen)
function UI.Refresh()
    for _, win in pairs(UI.windows) do
        UI.Restore(win)
        UI.ApplyLock(win)
    end
end

local callbacksRegistered = false
local function RegisterCallbacks()
    if callbacksRegistered then return end
    callbacksRegistered = true
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
        UI.UpdateVisibilityAll()
    end)
end

-- Creates a top-level HUD window. opts: title, alwaysMovable
function UI.CreateWindow(id, width, height, defX, defY, opts)
    opts = opts or {}
    local name = "OneVXHelper_" .. id
    local tlw = WM:CreateTopLevelWindow(name)
    tlw:SetDimensions(width, height)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetHidden(true)

    local bg = WM:CreateControl(name .. "_UnlockBG", tlw, CT_TEXTURE)
    bg:SetAnchorFill()
    bg:SetColor(0.8, 0.1, 0.1, 0.25)
    bg:SetHidden(true)

    local tag = UI.Label(name .. "_Tag", tlw, UI.Font("BOLD_FONT", 13, "soft-shadow-thin"), 1, 0.85, 0.3, 1)
    tag:SetText(opts.title or id)
    tag:SetAnchor(BOTTOMLEFT, tlw, TOPLEFT, 0, -2)
    tag:SetHidden(true)

    local content = WM:CreateControl(name .. "_Content", tlw, CT_CONTROL)
    content:SetAnchorFill()

    local win = {
        id = id, tlw = tlw, bg = bg, tag = tag, content = content,
        defX = defX, defY = defY, opts = opts, enabled = true,
    }

    tlw:SetHandler("OnMoveStop", function() SavePosition(win) end)

    RegisterCallbacks()
    UI.windows[id] = win
    UI.Restore(win)
    UI.ApplyLock(win)
    return win
end
