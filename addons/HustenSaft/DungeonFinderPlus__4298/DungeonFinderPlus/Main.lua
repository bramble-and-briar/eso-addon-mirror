-- Main.lua – DungeonFinderPlus
DungeonFinderPlus = DungeonFinderPlus or {}
local DFP = DungeonFinderPlus

local ADDON_NAME   = "DungeonFinderPlus"
local SV_NAMESPACE = "DungeonFinderPlus_SV"
local SV_VERSION   = 1

-- ──────────────────────────────────────────────────────────────
-- Keybinding-Strings
-- ──────────────────────────────────────────────────────────────
ZO_CreateStringId("SI_KEYBINDINGS_CATEGORY_DUNGEONFINDERPLUS", "DungeonFinderPlus")
ZO_CreateStringId("SI_BINDING_NAME_DFP_TOGGLE", "open / close")

local SV_DEFAULTS = {
    queueVeteran = false,
    lastSearch   = "",
    hidden       = false,
    autoPledge   = { enabled = true, openChest = true },
}

-- Reguläre SavedVars 
local function LoadSavedVars()
    DFP.sv = ZO_SavedVars:NewAccountWide(SV_NAMESPACE, SV_VERSION, nil, SV_DEFAULTS)
    DFP.sv.autoPledge = DFP.sv.autoPledge or {}
    if DFP.sv.autoPledge.enabled   == nil then DFP.sv.autoPledge.enabled   = SV_DEFAULTS.autoPledge.enabled end
    if DFP.sv.autoPledge.openChest == nil then DFP.sv.autoPledge.openChest = SV_DEFAULTS.autoPledge.openChest end
end

-- Scene
DFP._openedOnce  = false
DFP._scene       = nil
DFP._wndFragment = nil
DFP.controls     = DFP.controls or {}

local function EnsureScene()
    if not DFP_Window or not SCENE_MANAGER or DFP._scene then return end

    DFP.controls.DFP_Window = DFP_Window

    local wndFrag = ZO_FadeSceneFragment:New(DFP_Window)
    DFP._wndFragment = wndFrag

    local scene = ZO_Scene:New("dfp_scene", SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    scene:AddFragment(KEYBIND_STRIP_FADE_FRAGMENT)
    scene:AddFragment(wndFrag)
    if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    end
    DFP._scene = scene
end

function DFP.ShowWindow()
    if not DFP_Window then return end
    EnsureScene()
    if SCENE_MANAGER and DFP._scene then
        SCENE_MANAGER:Show("dfp_scene")
    end
    if not DFP._openedOnce then
        if DFP.Finder then
            if DFP.Finder.EnsureInit   then DFP.Finder:EnsureInit()   end
            if DFP.Finder.RebuildData  then DFP.Finder:RebuildData()  end
            if DFP.Finder.SetSearchText and DFP.sv then
                DFP.Finder:SetSearchText(DFP.sv.lastSearch or "")
            end
        end
        DFP._openedOnce = true
    end
end

function DFP.HideWindow()
    if SCENE_MANAGER and DFP._scene then
        SCENE_MANAGER:Hide("dfp_scene")
    end
    if DFP_Window then DFP_Window:SetHidden(true) end
    if DFP.sv then DFP.sv.hidden = true end
end

function DFP.Toggle()
    if not DFP_Window then
        if DFP.Finder and DFP.Finder.Open then DFP.Finder:Open() end
        return
    end
    if DFP_Window:IsHidden() then
        DFP.ShowWindow()
    else
        DFP.HideWindow()
    end
end

-- Globaler Wrapper für bindings.xml
DungeonFinderPlus.Toggle = DFP.Toggle

-- UI-Handler
function DFP.OnToolbarClose() DFP.HideWindow() end
function DFP.OnSelectAll() if DFP.Finder and DFP.Finder.BtnSelectAll then DFP.Finder:BtnSelectAll() end end
function DFP.OnClearSel()  if DFP.Finder and DFP.Finder.BtnClearSelection then DFP.Finder:BtnClearSelection() end end
function DFP.OnAllNormal() if DFP.Finder and DFP.Finder.BtnAllNormal then DFP.Finder:BtnAllNormal() end end
function DFP.OnAllVet()    if DFP.Finder and DFP.Finder.BtnAllVet    then DFP.Finder:BtnAllVet()    end end
function DFP.OnQueue()     if DFP.Finder and DFP.Finder.QueueSelection then DFP.Finder:QueueSelection() end end

function DFP.OnSearchTextChanged()
    if not DFP.Finder or not DFP.Finder.OnSearchChanged then return end
    if DFP.sv and DFP_WindowSearchRowSearchBackdropEdit then
        DFP.sv.lastSearch = DFP_WindowSearchRowSearchBackdropEdit:GetText() or ""
    end
    DFP.Finder:OnSearchChanged()
end

-- Slash-Commands
SLASH_COMMANDS["/dfp"] = function() DFP.Toggle() end

-- Lifecycle
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
    if DFP.sv and DFP.sv.hidden == false then
        DFP.ShowWindow()
    end
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    DFP.name    = ADDON_NAME
    DFP.version = DFP.version or ""

    LoadSavedVars()

    DFP.Finder = DFP.Finder or {}
    if DFP.SettingsInit then
        DFP.SettingsInit()
    end

    -- Events 
    if DFP.Pledges and DFP.Pledges.RegisterEvents then
        DFP.Pledges.RegisterEvents()
    end
    if DFP.Update and DFP.Update.RegisterEvents then
        DFP.Update.RegisterEvents()
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)