-- BGFC_Init.lua
-- Ways to open the console screen:
--   * a "Better Group Finder" button (R3) on the game's Activity Finder and
--     Group Finder screens,
--   * an entry in the gamepad main menu (inserted after Activity Finder),
--   * /bgf in chat, and an optional keybind.

local BGF = BetterGroupFinderConsole
local GP = BGF.GP

ZO_CreateStringId("SI_BINDING_NAME_BGFC_TOGGLE", "Toggle Better Group Finder (Console)")

function BGF.OpenUI(tab)
    local page = ({ browse = "categories", create = "create", mine = "mine" })[tab or ""] or "main"
    if page == "create" then GP:EnsureDraft() end
    GP:Show(page)
end
function BGF.CloseUI() GP:Close() end
function BGF.ToggleUI(tab)
    if GP:IsShowing() then GP:Close() else BGF.OpenUI(tab) end
end

---------------------------------------------------------------------------
-- Keybind button on the game's own finder screens
---------------------------------------------------------------------------
local openDescriptor = {
    alignment = KEYBIND_STRIP_ALIGN_RIGHT,
    {
        name = "Better Group Finder",
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        callback = function() BGF.OpenUI("browse") end,
    },
}

local function HookScene(scene)
    if not scene or scene.bgfcHooked then return end
    scene.bgfcHooked = true
    scene:RegisterCallback("StateChange", function(_, newState)
        if not KEYBIND_STRIP then return end
        if newState == SCENE_SHOWN then
            pcall(KEYBIND_STRIP.AddKeybindButtonGroup, KEYBIND_STRIP, openDescriptor)
        elseif newState == SCENE_HIDING then
            pcall(KEYBIND_STRIP.RemoveKeybindButtonGroup, KEYBIND_STRIP, openDescriptor)
        end
    end)
end

local function HookNativeScenes()
    if GROUP_FINDER_SCENE_GAMEPAD then HookScene(GROUP_FINDER_SCENE_GAMEPAD) end
    if ZO_GAMEPAD_ACTIVITY_FINDER_ROOT_SCENE_NAME and SCENE_MANAGER:GetScene(ZO_GAMEPAD_ACTIVITY_FINDER_ROOT_SCENE_NAME) then
        HookScene(SCENE_MANAGER:GetScene(ZO_GAMEPAD_ACTIVITY_FINDER_ROOT_SCENE_NAME))
    end
end

---------------------------------------------------------------------------
-- Gamepad main menu entry
---------------------------------------------------------------------------
-- The gamepad main menu is built from the global ZO_MENU_ENTRIES table on
-- every refresh. We add one entry, built the same way the game builds its
-- own, right after Activity Finder. Pressing it calls activatedCallback.
local function InsertMainMenuEntry()
    if type(ZO_MENU_ENTRIES) ~= "table" or not ZO_GamepadEntryData then return false end
    for _, entry in ipairs(ZO_MENU_ENTRIES) do
        if entry.data and entry.data.bgfcEntry then return true end
    end
    local data = {
        bgfcEntry = true,
        name = "Better Group Finder",
        icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_activityFinder.dds",
        activatedCallback = function() BGF.OpenUI() end,
    }
    local entry = ZO_GamepadEntryData:New(data.name, data.icon)
    entry:SetIconTintOnSelection(true)
    if entry.SetIconDisabledTintOnSelection then entry:SetIconDisabledTintOnSelection(true) end
    entry.data = data
    entry.id = 9000
    entry:SetEnabled(true)

    local insertAt = #ZO_MENU_ENTRIES + 1
    local activityScene = ZO_GAMEPAD_ACTIVITY_FINDER_ROOT_SCENE_NAME
    for i, e in ipairs(ZO_MENU_ENTRIES) do
        if e.data and activityScene and e.data.scene == activityScene then
            insertAt = i + 1
            break
        end
    end
    table.insert(ZO_MENU_ENTRIES, insertAt, entry)
    if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.RefreshLists and MAIN_MENU_GAMEPAD.mainList then
        pcall(MAIN_MENU_GAMEPAD.RefreshLists, MAIN_MENU_GAMEPAD)
    end
    return true
end

BGF:OnInitialize(function()
    pcall(HookNativeScenes)
    pcall(InsertMainMenuEntry)
end)
