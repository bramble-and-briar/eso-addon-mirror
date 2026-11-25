-- LazyConfirmPatchCooldownActions.lua: the 2 second wait on a prompt's button ends at once
--
-- A prompt that asks "are you sure" (destroy item, ready check, enchant a locked item) starts a wait on its
-- confirm button through ZO_KeybindStrip:TriggerCooldown, and the strip counts it down every frame.
--
-- No game function is wrapped or replaced. Code the game runs inside an add-on's function builds buttons
-- the game no longer trusts, and such a button fails wherever it ends in a private call: withdrawing from
-- the craft bag, accepting a ready check. So this follows TriggerCooldown with a SecurePostHook, which runs
-- after the game's function has returned, and writes one number: the seconds left. The strip's own update
-- then ends the wait on its next frame and redraws the button itself.
local CooldownActions = {}

local CooldownUtils = LazyConfirmPatch.CooldownUtils

---After ZO_KeybindStrip:TriggerCooldown.
---@param _strip table
---@param descriptor any
---@param duration any
function CooldownActions.OnCooldownTriggered(_strip, descriptor, duration)
    if not CooldownUtils.IsConfirmDelay(descriptor, duration) then
        return
    end
    local shortened = CooldownUtils.Shortened(descriptor.cooldown)
    if shortened then
        descriptor.cooldown = shortened
    end
end

---@return boolean placed
function CooldownActions.Install()
    if type(SecurePostHook) ~= "function" then
        return false
    end
    if type(ZO_KeybindStrip) ~= "table" or type(ZO_KeybindStrip.TriggerCooldown) ~= "function" then
        return false
    end
    SecurePostHook(ZO_KeybindStrip, "TriggerCooldown", CooldownActions.OnCooldownTriggered)
    return true
end

LazyConfirmPatch.CooldownActions = CooldownActions
