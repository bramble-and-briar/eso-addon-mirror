--[[
    Small helpers shared by the other modules.
]]

local ADDON = "WeylandHuntsmansWarmaskTracker"
local HMK = _G[ADDON]

local SOUND_CANDIDATES = HMK.SOUND_CANDIDATES

local function AvailableSounds()
    local list = {}
    if type(SOUNDS) ~= "table" then return list end
    for _, snd in ipairs(SOUND_CANDIDATES) do
        if SOUNDS[snd.id] then list[#list + 1] = snd end
    end
    return list
end

local function PlayWarnSound(id)
    if type(SOUNDS) == "table" and SOUNDS[id] then PlaySound(SOUNDS[id]) end
end

local function Msg(text)
    d("|c9ad0ff[WarmaskTracker]|r " .. tostring(text))
end

local function CleanName(name)
    if not name then return "" end
    return (zo_strlower((name:gsub("%^.*$", ""))))
end

local function FindById(list, id)
    for _, v in ipairs(list) do
        if v.id == id then return v end
    end
    return list[1]
end

local function HasId(list, id)
    for _, v in ipairs(list) do
        if v.id == id then return true end
    end
    return false
end

local function NowSec()
    -- GetUnitBuffInfo timeEnding uses the frame-time clock. Keep countdown
    -- arithmetic on that same clock, as ESO's own buff UI does.
    return GetFrameTimeSeconds()
end

local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = DeepCopy(v) end
    return copy
end

HMK.AvailableSounds = AvailableSounds
HMK.PlayWarnSound = PlayWarnSound
HMK.Msg = Msg
HMK.CleanName = CleanName
HMK.FindById = FindById
HMK.HasId = HasId
HMK.NowSec = NowSec
HMK.DeepCopy = DeepCopy
