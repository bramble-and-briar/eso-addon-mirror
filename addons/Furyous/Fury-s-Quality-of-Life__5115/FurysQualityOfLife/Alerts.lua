-- Fury's Quality of Life - alerts
-- The shared alert: a sound and a short line of big text over a violet wash across the screen.
-- Used by the fishing bite alert and the queue alert, plus the queue alert itself.

local QOL = FurysQualityOfLife

-- Sounds an alert can play: { saved key, name in the settings }. The key is a SOUNDS entry.
QOL.ALERT_SOUNDS = {
    { "DUEL_START", "Duel horn" },
    { "NEW_NOTIFICATION", "Notification" },
    { "QUEST_COMPLETED", "Quest complete" },
    { "LEVEL_UP", "Level up" },
    { "ACHIEVEMENT_AWARDED", "Achievement" },
    { "NONE", "No sound" },
}

local flash, flashLabel
local flashUntil = 0   -- a later alert keeps the flash up past an earlier one's end

local function HideFlash()
    if GetGameTimeMilliseconds() >= flashUntil then flash:SetHidden(true) end
end

-- Plays the sound (a key from ALERT_SOUNDS) and shows the text for `ms` milliseconds.
function QOL.Alert(text, soundKey, ms)
    local T = QOL.Theme
    if not flash then
        flash = WINDOW_MANAGER:CreateTopLevelWindow("FurysQualityOfLife_Flash")
        flash:SetAnchorFill(GuiRoot)
        flash:SetMouseEnabled(false)
        flash:SetDrawTier(DT_HIGH)
        local wash = T.Rect("FurysQualityOfLife_FlashWash", flash, T.VIOLET, DL_BACKGROUND, 1)
        wash:SetAnchorFill(flash)
        wash:SetAlpha(0.22)
        flashLabel = WINDOW_MANAGER:CreateControl("FurysQualityOfLife_FlashLabel", flash, CT_LABEL)
        flashLabel:SetFont("$(ANTIQUE_FONT)|48|outline")
        flashLabel:SetAnchor(CENTER, flash, CENTER, 0, -160)
        T.Paint(flashLabel, T.TEXT)
    end
    if soundKey ~= "NONE" then PlaySound(SOUNDS[soundKey]) end
    flashLabel:SetText(text)
    flash:SetHidden(false)
    ms = ms or 900
    flashUntil = GetGameTimeMilliseconds() + ms
    zo_callLater(HideFlash, ms + 20)
end

------------------------------------------------------------------------------
-- Queue alert: the dungeon, battleground or group finder asks if you are ready.
------------------------------------------------------------------------------
local QUEUE_EVENT = QOL.name .. "Queue"
local wasReady = false

function QOL.QueueAlert()
    QOL.Alert("Your queue is ready!", QOL.SV().queueSound, 2500)
end

local function OnFinderStatus(_, status)
    local ready = status == ACTIVITY_FINDER_STATUS_READY_CHECK
    if ready and not wasReady then QOL.QueueAlert() end
    wasReady = ready
end

function QOL.RefreshQueueAlert()
    EVENT_MANAGER:UnregisterForEvent(QUEUE_EVENT, EVENT_ACTIVITY_FINDER_STATUS_UPDATE)
    if QOL.SV().queueAlert then
        wasReady = false
        EVENT_MANAGER:RegisterForEvent(QUEUE_EVENT, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, OnFinderStatus)
    end
end
