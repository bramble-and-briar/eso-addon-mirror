-- LazyConfirmPatchCooldownUtils.lua: which button waits are cut short, and to what (pure)
local CooldownUtils = {}

-- What a wait is cut to, in seconds. Above zero on purpose: the keybind strip redraws a button whose wait
-- runs out (the count leaves its label, the button is enabled again) only when the whole seconds left
-- change, and from this value they change on its next update.
CooldownUtils.END_NOW_SECONDS = 0.001

---Whether a wait the game just started is the fixed "are you sure" delay of a prompt. That delay is a
---number of milliseconds on the prompt's button; a wait given as a function follows something real (the
---armory's build cooldown) and is left alone.
---@param descriptor any The button the wait was started on
---@param duration any What the game passed as the wait
---@return boolean
function CooldownUtils.IsConfirmDelay(descriptor, duration)
    return type(descriptor) == "table" and type(duration) == "number"
end

---The wait a button should be left with: END_NOW_SECONDS for one still running, nil for no change.
---@param cooldown any The button's cooldown field, in seconds
---@return number|nil
function CooldownUtils.Shortened(cooldown)
    if type(cooldown) == "number" and cooldown > CooldownUtils.END_NOW_SECONDS then
        return CooldownUtils.END_NOW_SECONDS
    end
    return nil
end

LazyConfirmPatch.CooldownUtils = CooldownUtils
