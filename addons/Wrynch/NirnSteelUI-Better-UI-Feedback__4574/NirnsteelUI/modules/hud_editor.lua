Nirnsteel_UI = Nirnsteel_UI or {}
local Editor = { entries = {} }
Nirnsteel_UI.HUDEditor = Editor

function Editor:IsAvailable()
    return HUD_MANAGER and type(HUD_MANAGER.RegisterKeyboardElement) == "function"
        and ZO_HUDEditor_Keyboard ~= nil
end

local function Platform()
    return IsInGamepadPreferredMode() and "gamepad" or "keyboard"
end

local function ReadAnchor(control)
    local valid,point,relative,relativePoint,x,y = control:GetAnchor(0)
    if valid then return ZO_Anchor:New(point,relative,relativePoint,x,y) end
end

function Editor:Refresh(entry, platform)
    if entry.refreshing or not HUD_MANAGER.savedVars then return end
    platform = platform or Platform()
    local element = entry.elements[platform]
    if not element then return end
    entry.refreshing = true
    local options = entry.options
    local position = options.position
    if position and options.enabled() then
        local migrated = position.hudMigrated or {}
        if not migrated[platform] then
            if HUD_MANAGER:GetSavedAnchorOffsets(element) == nil and entry.legacy[platform] then
                entry.legacy[platform]:Set(entry.control)
                local _,x,y = element:GetConvertedRefControlAnchorInfo()
                -- Native elements can use a different primary point (e.g. gamepad
                -- loot uses BOTTOMLEFT). Convert the captured ref position using
                -- that native point, not the legacy control's anchor point.
                element:RevertOffsetModifications()
                element:ApplyOffset(x,y)
            end
            migrated[platform] = true
            position.hudMigrated = migrated
        end
    end
    element:RevertOffsetModifications()
    entry.refreshing = false
end

function Editor:HideReplacedElements(entry)
    if not entry.options.replaces then return end
    for _,iterator in ipairs({ HUD_MANAGER.KeyboardElementIterator, HUD_MANAGER.GamepadElementIterator }) do
        for _,element in iterator(HUD_MANAGER) do
            if not entry.stock[element] and entry.options.replaces(element:GetControl()) then
                entry.stock[element] = true
                local previous = element.config.isValid
                element.config.isValid = function(data)
                    if entry.options.enabled() then return false end
                    return previous == nil or ZO_Eval(previous,data)
                end
            end
        end
    end
end

-- Called after a module lays out its legacy position. ESO owns all subsequent
-- positions, including reset, resolution changes, and keyboard/gamepad profiles.
function Editor:Apply(key,control,options)
    if not self:IsAvailable() then return false end
    local entry = self.entries[key]
    if not entry then
        entry = {control=control,options=options,elements={},legacy={},stock={}}
        self.entries[key] = entry
        if options.native then
            entry.elements.keyboard = HUD_MANAGER:GetKeyboardElementForControl(control)
            entry.elements.gamepad = HUD_MANAGER:GetGamepadElementForControl(control)
        else
            local ref = WINDOW_MANAGER:CreateControl(nil,control,CT_CONTROL)
            ref:SetAnchorFill(control)
            ref:SetMouseEnabled(false)
            control.hudElementRef = ref
            for _,platform in ipairs({"keyboard","gamepad"}) do
                local config = {
                    defaultAnchor = options.defaultAnchor(platform),
                    isValid = function() return entry.options.enabled() end,
                }
                local register = platform == "keyboard" and HUD_MANAGER.RegisterKeyboardElement or HUD_MANAGER.RegisterGamepadElement
                entry.elements[platform] = register(HUD_MANAGER,control,options.name,config)
            end
            self:HideReplacedElements(entry)
        end
    end
    entry.options = options
    local platform = options.platform or Platform()
    entry.legacy[platform] = entry.legacy[platform] or ReadAnchor(control)
    self:Refresh(entry,platform)
    return true
end

function Editor:ImportTrackerOffset(control,settings,amount)
    if not HUD_MANAGER.savedVars or not HUD_TRACKER_MANAGER.isFullyLoaded then return end
    local platform = Platform()
    local migrated = settings.hudOffsetMigrated or {}
    if migrated[platform] then return end
    local element = HUD_TRACKER_MANAGER:GetPlatformHUDElement()
    if not element then return end
    if amount > 0 and HUD_MANAGER:GetSavedAnchorOffsets(element) == nil then
        local _,x,y = element:GetConvertedRefControlAnchorInfo()
        element:ApplyOffset(x,y + amount)
    end
    migrated[platform] = true
    settings.hudOffsetMigrated = migrated
end

function Editor:SetEditing(active)
    self.editing = active
    for _,entry in pairs(self.entries) do
        self:HideReplacedElements(entry)
        local options = entry.options
        if active and options.enabled() and options.preview then
            entry.previousPreview = options.isPreviewActive and options.isPreviewActive() or false
            entry.previewing = true
            options.preview(true)
        elseif not active and entry.previewing then
            entry.previewing = false
            options.preview(entry.previousPreview)
        end
    end
end

-- Only modules with a native counterpart delegate placement to Edit HUD.
-- The minimap, werewolf rage, damage minigame and other standalone widgets keep
-- their existing movement controls.
function Editor:ConfigureSettings(options)
    if not self:IsAvailable() then return end
    local menus = { ["Quest Tracker"]=true, ["Group Frames"]=true, ["Target Frame"]=true,
        ["Resource Bars"]=true, ["Loot History"]=true, ["Misc"]=true }
    for _,menu in ipairs(options) do
        if menu.controls then
            if menus[menu.name] then
                for i=#menu.controls,1,-1 do
                    local name = menu.controls[i].name or ""
                    if name:find("^Unlock") or name == "Reset Position" then table.remove(menu.controls,i) end
                end
                table.insert(menu.controls,1,{type="description",text="Move and reset this element in the game's Edit HUD. Appearance settings remain here."})
            elseif menu.name == "Minimap" then
                for i=#menu.controls,1,-1 do
                    if menu.controls[i].name == "Quest Tracker Vertical Offset" then table.remove(menu.controls,i) end
                end
            end
        end
    end
end

if Editor:IsAvailable() then
    HUD_MANAGER:RegisterCallback("SavedVarsReady",function()
        for _,entry in pairs(Editor.entries) do Editor:Refresh(entry,entry.options.platform) end
    end)
    ZO_PreHook(ZO_HUDEditor_Keyboard,"OnShowing",function() Editor:SetEditing(true); return false end)
    ZO_PostHook(ZO_HUDEditor_Keyboard,"OnHidden",function() Editor:SetEditing(false) end)
end
