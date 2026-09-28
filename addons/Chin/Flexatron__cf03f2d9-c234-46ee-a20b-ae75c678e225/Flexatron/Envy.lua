-- Title envy: aim at a player wearing a title you don't have, and a quiet chat line says so,
-- with a link to the achievement that grants it. Only you see it; nothing goes to the server.
local FT = Flexatron
local L = FT.L
local Envy = {}
FT.Envy = Envy

local GAP_MS = 10000   -- at most one line this often
local STABLE_MS = 500  -- a changing title (someone's roll) must settle first

local told = {}        -- [title] = true once mentioned this session
local lastAt
local token = 0

function Envy.Check()
    if not FT.sv.titleEnvy or IsUnitInCombat("player") or not IsUnitPlayer("reticleover") then
        return
    end
    local title = GetUnitTitle("reticleover")
    if not title or title == "" or told[title] then
        return
    end
    local now = GetGameTimeMilliseconds()
    if lastAt and now - lastAt < GAP_MS then
        return
    end
    local ids = FT.TitleIndex.Lookup(title)
    if not ids or FT.TitleIndex.Owns(ids) then
        return -- yours already, or a title the index can't place: say nothing
    end
    told[title] = true
    lastAt = now
    CHAT_ROUTER:AddSystemMessage(string.format(L.ENVY, title, GetAchievementLink(ids[1], LINK_STYLE_BRACKETS)))
end

local function OnTitleUpdate(_, unitTag)
    if unitTag ~= "reticleover" then
        return
    end
    token = token + 1
    local mine = token
    zo_callLater(function()
        if mine == token then
            Envy.Check()
        end
    end, STABLE_MS)
end

function Envy.Init()
    local name = FT.name .. "Envy"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_RETICLE_TARGET_CHANGED, function() Envy.Check() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_TITLE_UPDATE, OnTitleUpdate)
    EVENT_MANAGER:AddFilterForEvent(name, EVENT_TITLE_UPDATE, REGISTER_FILTER_UNIT_TAG, "reticleover")
end
