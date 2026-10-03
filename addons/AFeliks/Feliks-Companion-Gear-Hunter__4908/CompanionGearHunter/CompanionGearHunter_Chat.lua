CompanionGearHunter = CompanionGearHunter or {}
local CompanionGearHunter = CompanionGearHunter -- local reference, faster than repeated _G lookups

-- Tags companion gear item links in incoming chat with the same companion icon
-- as the list badges (green = wanted, yellow = quality upgrade) by wrapping the
-- game's own formatter for chat messages, so the marker is part of the one
-- line that's displayed - no extra chat line. Same mechanism LootLog uses
-- for its own uncollected-item flags (read from its LootLogTrade.lua).
--
-- A message formatter is a single registered function per event
-- (ZO_ChatRouter:RegisterMessageFormatter replaces whatever was there), so
-- this captures the formatter that's registered when it installs and calls
-- it first. If another addon wraps the same event it just nests with this
-- one; either order works because each wrapper receives the other's output.
local ITEM_LINK_PATTERN = "|H%d:item:[%w:]+|h|h"
local ICON_SIZE = 30

-- Icon and colors come from CompanionGearHunter.Data (shared with the list
-- badges and the companion dropdown). Tinted by wrapping it in a |c color:
-- with inheritcolor the texture's own (light, near-neutral) pixels take that
-- color. See project/CLAUDE.md for why this replaced a tinted star.

local function TagLink(itemLink)
    local kind = CompanionGearHunter.Data.GetMatchKind(itemLink)
    if kind == nil then
        return itemLink
    end
    return string.format("|c%s%s|r%s", CompanionGearHunter.Data.GetMarkerColorHex(kind), zo_iconFormatInheritColor(CompanionGearHunter.Data.MARKER_ICON, ICON_SIZE, ICON_SIZE), itemLink)
end

-- Only the first return value (the formatted text) is edited; everything the
-- original formatter returned after it passes through untouched. Any error
-- while tagging falls back to the original, unmodified text - chat must
-- never break because of this addon.
local function ApplyTags(text, ...)
    if type(text) == "string" and CompanionGearHunter.Data.GetChatTaggingEnabled() then
        local ok, tagged = pcall(string.gsub, text, ITEM_LINK_PATTERN, TagLink)
        if ok and type(tagged) == "string" then
            text = tagged
        end
    end
    return text, ...
end

-- Chat addons that rebuild messages from scratch (pChat registers its own
-- formatter for this event and never calls the previous one) overwrite
-- whatever was registered before them, and they do it during their own
-- login setup. Installing immediately on login lost that race and this
-- wrapper was silently discarded, so installation waits (LootLog waits
-- 750ms for the same reason) and is checked again a little later.
local INSTALL_DELAYS_MS = { 1500, 6000 }

local ourFormatter = nil
local insideOurFormatter = false

-- Two wrappers of ours can end up in one chain (the second check re-wraps if
-- something replaced the first). Only the outermost one tags, so a link is
-- never tagged twice; the inner one just passes through.
local function Finish(ok, ...)
    insideOurFormatter = false
    if not ok then
        error((...), 0)
    end
    return ...
end

local function EnsureChatTaggingInstalled()
    local formatters = CHAT_ROUTER and CHAT_ROUTER:GetRegisteredMessageFormatters()
    local current = formatters and formatters[EVENT_CHAT_MESSAGE_CHANNEL]
    if current == nil or current == ourFormatter then
        return
    end

    local previousFormatter = current
    ourFormatter = function(...)
        if insideOurFormatter then
            return previousFormatter(...)
        end
        insideOurFormatter = true
        return ApplyTags(Finish(pcall(previousFormatter, ...)))
    end
    CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, ourFormatter)
end

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent("CompanionGearHunter_Chat", EVENT_PLAYER_ACTIVATED)
    for _, delay in ipairs(INSTALL_DELAYS_MS) do
        zo_callLater(EnsureChatTaggingInstalled, delay)
    end
end

EVENT_MANAGER:RegisterForEvent("CompanionGearHunter_Chat", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
