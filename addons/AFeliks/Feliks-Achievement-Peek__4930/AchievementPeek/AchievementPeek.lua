AchievementPeek = AchievementPeek or {}
local AchievementPeek = AchievementPeek

local MENU_LABEL = "View my progress"

-- Show the game's floating achievement popup (the one a left-click on a chat
-- link opens) fed with our own progress instead of the sender's. Our own link
-- is built and parsed so progress/timestamp arrive in the exact format the
-- popup expects from a link.
local function ShowMine(id)
    local achievements = SYSTEMS:GetObject("achievements")
    if not achievements then return end
    local myLink = GetAchievementLink(id, LINK_STYLE_BRACKETS)
    local _, _, _, _, progress, timestamp = ZO_LinkHandler_ParseLink(myLink)
    achievements:ShowAchievementPopup(id, progress, timestamp)
end

-- Signature: (link, button, text, linkStyle, linkType, ...). Never return true:
-- the game's own handler (and any other addon's menu) must still run.
function AchievementPeek.OnLinkMouseUp(link, button, text, linkStyle, linkType, ...)
    if linkType ~= ACHIEVEMENT_LINK_TYPE or button ~= MOUSE_BUTTON_INDEX_RIGHT then return end
    local id = tonumber((...))
    if not id or IsInGamepadPreferredMode() then return end

    -- Defer one frame so any menu another handler builds for this click exists
    -- first; we then append to it rather than wiping it.
    zo_callLater(function()
        AddMenuItem(MENU_LABEL, function() ShowMine(id) end)
        ShowMenu()
    end, 1)
end

LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, AchievementPeek.OnLinkMouseUp)
