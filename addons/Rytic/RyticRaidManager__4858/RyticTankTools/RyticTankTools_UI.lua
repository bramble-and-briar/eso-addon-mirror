-- One scene-fragment owner for each Rytic top-level window.
local RyticTank=RyticTank
local UI={entries={}}
RyticTank.UI=UI

local function hudContext()
    if not SCENE_MANAGER then return false end
    local scene=SCENE_MANAGER:GetNextScene() or SCENE_MANAGER:GetCurrentScene()
    local name=scene and scene:GetName()
    return name=="hud" or name=="hudui"
end

function UI.Refresh(control)
    local entry=UI.entries[control]
    if not entry or entry.refreshing then return false end
    entry.refreshing=true
    entry.fragment:Refresh()
    entry.refreshing=false
    return entry.fragment:IsShowing()
end

function UI.RefreshAll()
    for control in pairs(UI.entries) do UI.Refresh(control) end
end

function UI.Attach(control,eligible,onShown)
    if UI.entries[control] then return UI.entries[control].fragment end
    control:SetHidden(true)
    local fragment=ZO_SimpleSceneFragment:New(control)
    local entry={fragment=fragment,eligible=eligible}
    UI.entries[control]=entry
    fragment:SetConditional(function() return eligible() end)
    fragment:RegisterCallback("StateChange",function(_,state)
        if state==SCENE_FRAGMENT_SHOWN and onShown then
            zo_callLater(function()
                if fragment:IsShowing() then onShown() end
            end,0)
        elseif state==SCENE_FRAGMENT_HIDDEN and entry.modal and entry.open then
            UI.CloseModal(control)
        end
    end)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    UI.Refresh(control)
    return fragment
end

function UI.AttachModal(control,enabled,onClose,onShown)
    local fragment=UI.Attach(control,function()
        local entry=UI.entries[control]
        return entry and entry.open==true and (not enabled or enabled())
    end,onShown)
    local entry=UI.entries[control]
    entry.modal=true
    entry.onClose=onClose
    entry.keybinds={alignment=KEYBIND_STRIP_ALIGN_RIGHT,{
        name="Close",keybind="UI_SHORTCUT_NEGATIVE",
        callback=function() UI.CloseModal(control) end,
    }}
    return fragment
end

function UI.OpenModal(control)
    local entry=UI.entries[control]
    if not entry or not entry.modal then return false end
    if not hudContext() then
        d("|cFFAA00Rytic: close the current menu before opening this window.|r")
        return false
    end
    if UI.activeModal and UI.activeModal~=control then UI.CloseModal(UI.activeModal) end
    if entry.open then return true end
    entry.open=true
    if not entry.eligible() then entry.open=false; return false end
    UI.activeModal=control
    entry.ownsCursor=not IsGameCameraUIModeActive()
    if entry.ownsCursor then SetGameCameraUIMode(true) end
    if KEYBIND_STRIP then
        KEYBIND_STRIP:AddKeybindButtonGroup(entry.keybinds)
        entry.keybindAdded=true
    end
    UI.Refresh(control)
    return true
end

function UI.CloseModal(control)
    local entry=UI.entries[control]
    if not entry or not entry.modal or not entry.open then return end
    entry.open=false
    if entry.keybindAdded and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(entry.keybinds)
        entry.keybindAdded=false
    end
    if UI.activeModal==control then UI.activeModal=nil end
    UI.Refresh(control)
    if entry.onClose then entry.onClose() end
    -- Do not steal the cursor from the menu that replaced this modal.
    if entry.ownsCursor and hudContext() then SetGameCameraUIMode(false) end
    entry.ownsCursor=false
end

local events={EVENT_PLAYER_ACTIVATED,EVENT_PLAYER_COMBAT_STATE,EVENT_PLAYER_DEAD,EVENT_PLAYER_ALIVE}
for i,event in ipairs(events) do
    EVENT_MANAGER:RegisterForEvent("RyticUIState"..i,event,UI.RefreshAll)
end
