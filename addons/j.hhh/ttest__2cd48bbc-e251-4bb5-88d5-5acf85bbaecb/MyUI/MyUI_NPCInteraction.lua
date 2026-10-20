-- Scale and position the NPC interaction prompt (X TALK), separate from player-to-player.
BUI.NPCInteraction = BUI.NPCInteraction or {}
local M=BUI.NPCInteraction
local function getControl()
    local reticle=rawget(_G,'RETICLE')
    return reticle and reticle.interact
end
function M.Apply()
    local c=getControl()
    if not c or not BUI or not BUI.Vars then return end
    if c.SetScale then c:SetScale(0.90) end
    local a=BUI.Vars.MyUI_NPCInteraction
    if type(a)=='table' and tonumber(a[3]) and tonumber(a[4]) and c.ClearAnchors then
        c:ClearAnchors()
        c:SetAnchor(CENTER,GuiRoot,CENTER,tonumber(a[3]),tonumber(a[4]))
    end
end
EVENT_MANAGER:RegisterForEvent('MyUI_NPCInteractReady',EVENT_PLAYER_ACTIVATED,function()
    if zo_callLater then zo_callLater(M.Apply,300) else M.Apply() end
    local reticle=rawget(_G,'RETICLE')
    if reticle and type(reticle.UpdateInteractText)=='function' and type(SecurePostHook)=='function' then
        SecurePostHook(reticle,'UpdateInteractText',function() M.Apply() end)
    end
end)
