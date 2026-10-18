-- My UI chat layout. Preserve gamepad controls; never replace chat handlers.
BUI.MyUIChatLayout = BUI.MyUIChatLayout or {}
local Chat = BUI.MyUIChatLayout

function Chat.GetControl()
    -- The PlayStation diagnosis identified this concrete control.
    -- It is known to belong to the opened gamepad chat; HUD behavior needs testing.
    local system=rawget(_G,'GAMEPAD_CHAT_SYSTEM')
    local primary=system and system.primaryContainer
    local candidate=(system and system.control) or (primary and primary.control) or rawget(_G,'ZO_GamepadTextChat')
    if not candidate or not candidate.GetDimensions or not candidate.SetDimensions
        or not candidate.GetCenter or not candidate.ClearAnchors or not candidate.SetAnchor then
        return nil
    end
    local ok,w,h=pcall(candidate.GetDimensions,candidate)
    if not ok or type(w)~='number' or type(h)~='number' or w<=0 or h<=0 then return nil end
    return candidate
end

function Chat.Apply()
    local control=Chat.GetControl()
    if not control or not BUI.Vars then return end
    if not Chat.originalWidth then
        local width,height=control:GetDimensions()
        if not width or not height or width<=0 or height<=0 then return end
        Chat.originalWidth=width
        Chat.originalHeight=height
    end
    -- Apply absolute dimensions based on the session's original game UI,
    -- not the already-enlarged dimensions, avoiding growth on repeated calls.
    control:SetDimensions(Chat.originalWidth+100,Chat.originalHeight+50)
    local pos=BUI.Vars.MyUI_ChatPosition
    if type(pos)=='table' and type(pos[1])=='number' and type(pos[2])=='number' then
        control:ClearAnchors()
        control:SetAnchor(CENTER,GuiRoot,CENTER,pos[1],pos[2])
    end
end

local function onPlayerActivated()
    if zo_callLater then
        zo_callLater(function() Chat.Apply() end,700)
        zo_callLater(function() Chat.Apply() end,2400)
        zo_callLater(function() Chat.Apply() end,5500)
    else
        Chat.Apply()
    end
end
if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED then
    EVENT_MANAGER:RegisterForEvent('MyUI_ChatLayout',EVENT_PLAYER_ACTIVATED,onPlayerActivated)
end
