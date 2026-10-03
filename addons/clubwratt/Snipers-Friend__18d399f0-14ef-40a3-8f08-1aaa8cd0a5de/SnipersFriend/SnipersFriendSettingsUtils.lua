-- SnipersFriendSettingsUtils.lua: Pure helpers for building the settings menu

local SettingsUtils = {}

---@param label string
---@param tooltip string|nil
---@param range {min: number, max: number, step: number}
---@param fmt string
---@param getFn fun(): number
---@param setFn fun(v: number)
---@return table
function SettingsUtils.SliderParams(label, tooltip, range, fmt, getFn, setFn)
    local LAS = _G["LibHarvensAddonSettings"]
    return {
        type = LAS.ST_SLIDER,
        label = label,
        tooltip = tooltip,
        min = range.min,
        max = range.max,
        step = range.step,
        format = fmt,
        getFunction = getFn,
        setFunction = setFn,
    }
end

---@param label string
---@param tooltip string|nil
---@param getFn fun(): boolean
---@param setFn fun(v: boolean)
---@return table
function SettingsUtils.CheckboxParams(label, tooltip, getFn, setFn)
    local LAS = _G["LibHarvensAddonSettings"]
    return {
        type = LAS.ST_CHECKBOX,
        label = label,
        tooltip = tooltip,
        getFunction = getFn,
        setFunction = setFn,
    }
end

---@param label string
---@param tooltip string|nil
---@param getFn fun(): number, number, number, number
---@param setFn fun(r: number, g: number, b: number, a: number)
---@return table
function SettingsUtils.ColorParams(label, tooltip, getFn, setFn)
    local LAS = _G["LibHarvensAddonSettings"]
    return {
        type = LAS.ST_COLOR,
        label = label,
        tooltip = tooltip,
        getFunction = getFn,
        setFunction = setFn,
    }
end

SnipersFriend.SettingsUtils = SettingsUtils
