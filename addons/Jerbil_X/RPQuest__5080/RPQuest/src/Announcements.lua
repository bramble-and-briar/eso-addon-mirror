-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.Announcements = {}
local Announcements = Addon.Announcements

function Announcements:ShowAlert(message, isError)
    if not message or message == "" then return end

    local soundId = nil
    local category = UI_ALERT_CATEGORY_ALERT
    if isError then
        category = UI_ALERT_CATEGORY_ERROR or UI_ALERT_CATEGORY_ALERT
        soundId = SOUNDS and SOUNDS.GENERAL_ALERT_ERROR or nil
    else
        soundId = SOUNDS and SOUNDS.QUEST_OBJECTIVE_INCREMENT or nil
    end

    if ZO_Alert then
        ZO_Alert(category, soundId, message)
    elseif d then
        d(tostring(message))
    end
end

function Announcements:AnnounceQuestProgress(quest, matchedTarget)
    if not quest then return end

    local fallbackTarget = quest.targets and quest.targets[1]
    local target = matchedTarget or fallbackTarget
    local tName = (target and target.name) or ""
    local tCur = (target and target.currentCount) or 0
    local tReq = (target and target.requiredCount) or 1

    local text = Addon.Locale:Get("CSA_QUEST_PROGRESS", tName, tCur, tReq)
    local soundId = SOUNDS and SOUNDS.QUEST_OBJECTIVE_INCREMENT or nil

    if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams and CENTER_SCREEN_ANNOUNCE.AddMessageWithParams then
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, soundId)
        params:SetText(text)
        if CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED then
            params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED)
        end
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    elseif CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.AddMessage then
        CENTER_SCREEN_ANNOUNCE:AddMessage(nil, CSA_CATEGORY_SMALL_TEXT, soundId, text)
    else
        self:ShowAlert(text, false)
    end
end

local function emitLargeBanner(mainText, subText, soundId, csaType)
    if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams and CENTER_SCREEN_ANNOUNCE.AddMessageWithParams then
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, soundId)
        params:SetText(mainText, subText)
        if csaType then
            params:SetCSAType(csaType)
        end
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    elseif CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.AddMessage then
        CENTER_SCREEN_ANNOUNCE:AddMessage(nil, CSA_CATEGORY_LARGE_TEXT, soundId, mainText)
        if PlaySound and soundId then
            PlaySound(soundId)
        end
    else
        if PlaySound and soundId then
            PlaySound(soundId)
        end
        Announcements:ShowAlert(mainText, false)
    end
end

function Announcements:AnnounceQuestAccepted(quest)
    if not quest then return end

    local questTitle = quest.title or ""
    local mainText
    if zo_strformat and SI_NOTIFYTEXT_QUEST_ACCEPT then
        mainText = zo_strformat(SI_NOTIFYTEXT_QUEST_ACCEPT, questTitle)
    else
        mainText = Addon.Locale:Get("CSA_QUEST_ACCEPTED", questTitle)
    end

    local soundId = SOUNDS and SOUNDS.QUEST_ACCEPTED or nil
    emitLargeBanner(mainText, nil, soundId, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED)
end

function Announcements:AnnounceQuestCompleted(quest, matchedTarget)
    if not quest then return end

    local mainText = Addon.Locale:Get("CSA_QUEST_COMPLETED", quest.title or "")
    local customMsg = type(quest.completionMessage) == "string"
        and quest.completionMessage:gsub("^%s+", ""):gsub("%s+$", "")
        or ""
    local subText = (customMsg ~= "") and customMsg or nil
    local soundId = SOUNDS and SOUNDS.QUEST_COMPLETED or nil

    emitLargeBanner(mainText, subText, soundId, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_COMPLETED)
end

function Announcements:AnnounceDiscovery(quest, point)
    if not point or type(point.message) ~= "string" or point.message == "" then
        return
    end

    local text = point.message
    local soundId = SOUNDS and (SOUNDS.QUEST_OBJECTIVE_INCREMENT or SOUNDS.BOOK_PAGE_TURN) or nil

    if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams and CENTER_SCREEN_ANNOUNCE.AddMessageWithParams then
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, soundId)
        params:SetText(text)
        if CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED then
            params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED)
        end
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    elseif CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.AddMessage then
        CENTER_SCREEN_ANNOUNCE:AddMessage(nil, CSA_CATEGORY_SMALL_TEXT, soundId, text)
    else
        self:ShowAlert(text, false)
    end

    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(Addon.Constants.UI.CHAT_PREFIX .. text)
    elseif d then
        d(Addon.Constants.UI.CHAT_PREFIX .. text)
    end
end
