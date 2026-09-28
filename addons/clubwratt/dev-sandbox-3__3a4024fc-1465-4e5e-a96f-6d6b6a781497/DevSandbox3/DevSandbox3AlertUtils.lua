-- DevSandbox3AlertUtils.lua: Pure helpers for the on-screen detection alert (no side effects)

local AlertUtils = {}

AlertUtils.FONT_FACE = "EsoUI/Common/Fonts/univers67.otf"
AlertUtils.CONFIRMED_COLOR = { 0.35, 1.0, 0.35, 1.0 }
AlertUtils.CANDIDATE_COLOR = { 1.0, 0.85, 0.3, 1.0 }

---@param fontSize integer
---@return string
function AlertUtils.BuildFont(fontSize)
    return string.format("%s|%d|outline", AlertUtils.FONT_FACE, fontSize)
end

---@param name string
---@param distanceText string|nil
---@param candidate boolean
---@return string
function AlertUtils.BuildText(name, distanceText, candidate)
    local head = candidate and "UNRECOGNIZED NODE" or "WAR TORTE RECIPE DETECTED"
    local where = distanceText and (" @ " .. distanceText) or ""
    return string.format("%s\n%s%s", head, name, where)
end

---@param alert DevSandbox3Alert|nil
---@param autoDismissSeconds integer
---@param now integer
---@return boolean expired
function AlertUtils.IsExpired(alert, autoDismissSeconds, now)
    if not alert then return false end
    if not autoDismissSeconds or autoDismissSeconds <= 0 then return false end
    return now - alert.at >= autoDismissSeconds
end

DevSandbox3.AlertUtils = AlertUtils
