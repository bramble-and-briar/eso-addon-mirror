local AlabuzyaUI = AlabuzyaUI
-- Fit the native guild background to an addon-expanded roster, only in this scene.
AlabuzyaUI.Compatibility = {}
local M = AlabuzyaUI.Compatibility
local original, active
function M.RestoreGuildBackground()
    if not original then return end
    original.control:SetWidth(original.width)
    original.left:SetWidth(original.leftWidth)
    original=nil
end
function M.UpdateGuildBackground()
    if not active then return end
    if (AlabuzyaUI.Settings and not AlabuzyaUI.Settings.Enabled('guildBackground')) or IsInGamepadPreferredMode() then
        M.RestoreGuildBackground() return
    end
    local background, roster = ZO_SharedRightBackground, ZO_GuildRoster
    local left = background and background:GetNamedChild('Left')
    if not left or not roster then return end
    if not original then
        original={control=background,left=left,width=background:GetWidth(),leftWidth=left:GetWidth()}
    end
    -- Native background: 960 wide; native right-panel roster: 930 wide.
    -- Both are right-anchored. Extend the left texture by the same amount so
    -- its right edge and the narrow right texture stay in their original place.
    local width=math.max(original.width,roster:GetWidth()+30)
    background:SetWidth(width)
    left:SetWidth(original.leftWidth+width-original.width)
end
function M.GuildSceneState(_, state)
    if state==SCENE_SHOWING or state==SCENE_SHOWN then
        active=true
        M.UpdateGuildBackground()
        EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIGuildBackground',250,M.UpdateGuildBackground)
    elseif state==SCENE_HIDING or state==SCENE_HIDDEN then
        active=false
        EVENT_MANAGER:UnregisterForUpdate('AlabuzyaUIGuildBackground')
        M.RestoreGuildBackground()
    end
end
function AlabuzyaUI.Compatibility.Initialize()
    if AlabuzyaUI.Settings and not AlabuzyaUI.Settings.StyleEnabled() then return end
    if GUILD_ROSTER_SCENE then GUILD_ROSTER_SCENE:RegisterCallback('StateChange',M.GuildSceneState) end
end
