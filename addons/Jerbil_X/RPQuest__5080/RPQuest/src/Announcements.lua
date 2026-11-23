-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.Announcements = {}
local Announcements = Addon.Announcements

function Announcements:ShowAlert(message, isError)
    if not message or message == "" then return end

    local category = isError and UI_ALERT_CATEGORY_ERROR or UI_ALERT_CATEGORY_ALERT
    local soundId = isError and SOUNDS.GENERAL_ALERT_ERROR or SOUNDS.QUEST_OBJECTIVE_INCREMENT
    ZO_Alert(category, soundId, message)
end

local function emitSmallBanner(text, soundId)
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, soundId)
    params:SetText(text)
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED)
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

function Announcements:AnnounceQuestProgress(quest, matchedTarget)
    if not quest then return end

    local fallbackTarget = quest.targets and quest.targets[1]
    local target = matchedTarget or fallbackTarget
    local tName = (target and target.name) or ""
    local tCur = (target and target.currentCount) or 0
    local tReq = (target and target.requiredCount) or 1

    local text = Addon.Locale:Get("CSA_QUEST_PROGRESS", tName, tCur, tReq)
    emitSmallBanner(text, SOUNDS.QUEST_OBJECTIVE_INCREMENT)
end

local function emitLargeBanner(mainText, subText, soundId, csaType)
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, soundId)
    params:SetText(mainText, subText)
    if csaType then
        params:SetCSAType(csaType)
    end
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

function Announcements:AnnounceQuestAccepted(quest)
    if not quest then return end

    local questTitle = quest.title or ""
    local mainText = zo_strformat(SI_NOTIFYTEXT_QUEST_ACCEPT, questTitle)
    emitLargeBanner(mainText, nil, SOUNDS.QUEST_ACCEPTED, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED)
end

function Announcements:AnnounceQuestReceived(quest)
    if not quest then return end

    local mainText = Addon.Locale:Get("CSA_QUEST_RECEIVED")
    local subText = (type(quest.title) == "string" and quest.title ~= "") and quest.title or nil
    local soundId = SOUNDS.QUEST_OBJECTIVE_INCREMENT or SOUNDS.BOOK_PAGE_TURN
    emitLargeBanner(mainText, subText, soundId, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED)
end

function Announcements:AnnounceQuestCompleted(quest, _matchedTarget)
    if not quest then return end

    local mainText = Addon.Locale:Get("CSA_QUEST_COMPLETED", quest.title or "")
    local customMsg = type(quest.completionMessage) == "string"
        and quest.completionMessage:gsub("^%s+", ""):gsub("%s+$", "")
        or ""
    local subText = (customMsg ~= "") and customMsg or nil

    emitLargeBanner(mainText, subText, SOUNDS.QUEST_COMPLETED, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_COMPLETED)
end

local function emitDiscoveryStyleMessage(text)
    local soundId = SOUNDS.QUEST_OBJECTIVE_INCREMENT or SOUNDS.BOOK_PAGE_TURN
    emitSmallBanner(text, soundId)
    CHAT_SYSTEM:AddMessage(Addon.Constants.UI.CHAT_PREFIX .. text)
end

function Announcements:AnnounceDiscovery(_quest, point)
    if not point or type(point.message) ~= "string" or point.message == "" then
        return
    end
    emitDiscoveryStyleMessage(point.message)
end

function Announcements:AnnounceTargetCustomMessage(_quest, target)
    if not target or type(target.customMessage) ~= "string" then
        return
    end
    local text = target.customMessage:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return end
    emitDiscoveryStyleMessage(text)
end

function Announcements:AnnounceQuestFailed(quest, target)
    if not quest then return end

    local mainText = Addon.Locale:Get("CSA_QUEST_FAILED", quest.title or "")
    local subText = nil
    if target and target.name and target.name ~= "" then
        subText = Addon.Locale:Get("ALERT_QUEST_FAILED_LOCATION", target.name)
    end
    local soundId = SOUNDS.QUEST_STEP_FAILED or SOUNDS.GENERAL_ALERT_ERROR

    emitLargeBanner(mainText, subText, soundId, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_PROGRESSION_CHANGED)

    local chatText = subText and (mainText .. " — " .. subText) or mainText
    CHAT_SYSTEM:AddMessage(Addon.Constants.UI.CHAT_PREFIX .. "|cFF4444" .. chatText .. "|r")
end

function Announcements:AnnounceMailDecodeError(message, senderDisplayName)
    if type(message) ~= "string" or message == "" then return end

    local mainText = Addon.Locale:Get("CSA_MAIL_DECODE_ERROR")
    local hasSender = type(senderDisplayName) == "string" and senderDisplayName ~= ""
    local subText = hasSender
        and Addon.Locale:Get("ALERT_MAIL_DECODE_ERROR_FROM", senderDisplayName, message)
        or message

    emitLargeBanner(mainText, subText, SOUNDS.GENERAL_ALERT_ERROR, CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_PROGRESSION_CHANGED)

    local chatText = mainText .. " — " .. subText
    CHAT_SYSTEM:AddMessage(Addon.Constants.UI.CHAT_PREFIX .. "|cFF4444" .. chatText .. "|r")
end
