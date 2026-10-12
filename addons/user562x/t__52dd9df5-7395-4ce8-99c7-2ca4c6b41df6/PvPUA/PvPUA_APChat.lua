local PvPUA = PvPUA
local U = PvPUA.util
local SAVED_ACCOUNT_TIP = U.SAVED_ACCOUNT_TIP

--------------------------------------------------
-- AP In Chat
--------------------------------------------------
local function FormatAP(amount)
    if amount >= 1000000 then return string.format("%.1fM", amount / 1000000)
    elseif amount >= 1000 then return string.format("%.1fK", amount / 1000)
    else return tostring(amount) end
end

local AP_REASONS = {
    [CURRENCY_CHANGE_REASON_KILL]                  = "Combat",
    [CURRENCY_CHANGE_REASON_OFFENSIVE_KEEP_REWARD] = "Capture",
    [CURRENCY_CHANGE_REASON_DEFENSIVE_KEEP_REWARD] = "D-Tick",
    [CURRENCY_CHANGE_REASON_KEEP_REPAIR]           = "Repair",
    [CURRENCY_CHANGE_REASON_PVP_RESURRECT]         = "Rez",
    [CURRENCY_CHANGE_REASON_MEDAL]                 = "Medal",
    [CURRENCY_CHANGE_REASON_BATTLEGROUND]          = "BG",
    [CURRENCY_CHANGE_REASON_QUESTREWARD]           = "Quest",
}

local apBuckets = {}

local function FlushAPBucket(reason)
    local bucket = apBuckets[reason]
    if not bucket or bucket.total <= 0 then return end
    local source = AP_REASONS[reason]
    local alliance = GetUnitAlliance("player")
    local aColor = GetAllianceColor(alliance):ToHex()
    local msg = "|c00FF00+" .. FormatAP(bucket.total) .. " AP|r"
    if source then msg = msg .. " |c" .. aColor .. "(" .. source .. ")|r" end
    d(msg)
    bucket.total = 0
end

local function OnAPGain(eventCode, alliancePoints, playSound, difference, reason)
    PvPUA:RefreshRankLabel()
    if reason == CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
    or reason == CURRENCY_CHANGE_REASON_VENDOR
    or reason == CURRENCY_CHANGE_REASON_TRADE
    or difference <= 0 then return end
    if not PvPUA.savedVariables or not PvPUA.savedVariables.enableAPChat then return end

    local source = AP_REASONS[reason]
    local alliance = GetUnitAlliance("player")
    local aColor = GetAllianceColor(alliance):ToHex()

    if PvPUA.savedVariables.consolidateAPChat
    and (reason == CURRENCY_CHANGE_REASON_KILL or reason == CURRENCY_CHANGE_REASON_KEEP_REPAIR) then
        if not apBuckets[reason] then
            apBuckets[reason] = { total = 0 }
        end
        apBuckets[reason].total = apBuckets[reason].total + difference
        EVENT_MANAGER:UnregisterForUpdate("PvPUA_APFlush_" .. tostring(reason))
        local delay = (reason == CURRENCY_CHANGE_REASON_KEEP_REPAIR)
            and (PvPUA.savedVariables.consolidateRepairDelay or 5) * 1000
            or  (PvPUA.savedVariables.consolidateCombatDelay or 10) * 1000
        EVENT_MANAGER:RegisterForUpdate("PvPUA_APFlush_" .. tostring(reason), delay, function()
            EVENT_MANAGER:UnregisterForUpdate("PvPUA_APFlush_" .. tostring(reason))
            FlushAPBucket(reason)
        end)
    else
        local msg = "|c00FF00+" .. FormatAP(difference) .. " AP|r"
        if source then msg = msg .. " |c" .. aColor .. "(" .. source .. ")|r" end
        d(msg)
    end
end

EVENT_MANAGER:RegisterForEvent(PvPUA.name .. "_AP", EVENT_ALLIANCE_POINT_UPDATE, OnAPGain)

--------------------------------------------------
-- Menu
--------------------------------------------------
function PvPUA:APChatMenu()
    return { type = "submenu",
          name = "|c00FF00AP in Chat|r",
          tooltip = SAVED_ACCOUNT_TIP,
          icon = "EsoUI/Art/HUD/Gamepad/gp_HUDNotification_notification.dds",
          options = {
        { type = "toggle", name = "Enabled", preset = "YES_NO",
          tooltip = "Prints the AP you earn to chat.",
          default = PvPUA.defaults.enableAPChat,
          getFunc = function() return self.savedVariables.enableAPChat end,
          setFunc = function(v) self.savedVariables.enableAPChat = v end },
        { type = "toggle", name = "Consolidate", preset = "YES_NO",
          tooltip = "Consolidates Repair and Combat AP instead of printing each one individually.\nPrints after the last gain of that type based on the duration set below.",
          default = PvPUA.defaults.consolidateAPChat,
          getFunc = function() return self.savedVariables.consolidateAPChat end,
          setFunc = function(v) self.savedVariables.consolidateAPChat = v end },
        { type = "slider", name = "Repair Duration", min = 5, max = 60, step = 1,
          tooltip = "How long to wait before printing consolidated Repair AP (seconds).",
          default = PvPUA.defaults.consolidateRepairDelay,
          getFunc = function() return self.savedVariables.consolidateRepairDelay end,
          setFunc = function(v) self.savedVariables.consolidateRepairDelay = v end },
        { type = "slider", name = "Combat Duration", min = 5, max = 60, step = 1,
          tooltip = "How long to wait before printing consolidated Combat AP (seconds).",
          default = PvPUA.defaults.consolidateCombatDelay,
          getFunc = function() return self.savedVariables.consolidateCombatDelay end,
          setFunc = function(v) self.savedVariables.consolidateCombatDelay = v end },
          } }
end
