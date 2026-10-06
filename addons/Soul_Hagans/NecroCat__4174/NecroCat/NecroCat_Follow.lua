NecroCat = NecroCat or {}
NecroCat.Follow = NecroCat.Follow or {}
local FM = NecroCat.Follow

---------------------------------------------------------
-- 1. ФУНКЦИИ (Будут вызваны через Bindings.xml)
---------------------------------------------------------

function NecroCat.Follow.AcceptDialog()
    if NecroCat.Follow.Dialog and not NecroCat.Follow.Dialog:IsHidden() then
        if NecroCat.Follow.Dialog.leader then
            JumpToGroupMember(NecroCat.Follow.Dialog.leader)
            d(zo_strformat(GetString(SI_NC_FOLLOW_JUMPING), NecroCat.Follow.Dialog.leader))
        end
        FM.CloseDialog()
    end
end

function NecroCat.Follow.CloseDialog()
    if NecroCat.Follow.Dialog then
        NecroCat.Follow.Dialog:SetHidden(true)
    end
end

---------------------------------------------------------
-- 2. СОЗДАНИЕ UI
---------------------------------------------------------

local function CreateDialog()
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_FollowDialog")
    frame:SetDimensions(350, 220)
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NecroCat.savedVars.followDialogLeft or 500, NecroCat.savedVars.followDialogTop or 300)
    frame:SetHidden(true)
    frame:SetMouseEnabled(true)
    frame:SetMovable(true)

    frame:SetHandler("OnMoveStop", function(self)
        NecroCat.savedVars.followDialogLeft = self:GetLeft()
        NecroCat.savedVars.followDialogTop = self:GetTop()
    end)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.1, 0.1, 0.1, 0.9)
    bg:SetEdgeColor(0.8, 0.5, 0.1, 1)
    bg:SetEdgeTexture("", 8, 2, 2)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", frame, CT_LABEL)
    label:SetAnchor(TOP, frame, TOP, 0, 20)
    label:SetDimensions(340, 160)
    label:SetFont("ZoFontWinH3")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local btnYes = WINDOW_MANAGER:CreateControl("$(parent)BtnYes", frame, CT_BUTTON)
    btnYes:SetDimensions(100, 30)
    btnYes:SetAnchor(BOTTOM, frame, BOTTOM, -60, -10)
    btnYes:SetNormalTexture("/esoui/art/buttons/btn_up.dds")
    btnYes:SetText(GetString(SI_NC_FOLLOW_YES))
    btnYes:SetFont("ZoFontWinH3")
    btnYes:SetHandler("OnClicked", NecroCat.Follow.AcceptDialog)

    local btnNo = WINDOW_MANAGER:CreateControl("$(parent)BtnNo", frame, CT_BUTTON)
    btnNo:SetDimensions(100, 30)
    btnNo:SetAnchor(BOTTOM, frame, BOTTOM, 60, -10)
    btnNo:SetNormalTexture("/esoui/art/buttons/btn_up.dds")
    btnNo:SetText(GetString(SI_NC_FOLLOW_NO))
    btnNo:SetFont("ZoFontWinH3")
    btnNo:SetHandler("OnClicked", NecroCat.Follow.CloseDialog)

    NecroCat.Follow.Dialog = frame
    NecroCat.Follow.Label = label
end

---------------------------------------------------------
-- 3. ЛОГИКА
---------------------------------------------------------

function FM.OpenDialog(leader, zone)
    local frame = NecroCat.Follow.Dialog
    if not frame then CreateDialog() frame = NecroCat.Follow.Dialog end

    local header = GetString(SI_NC_FOLLOW_DIALOG_HEADER)
    local question = GetString(SI_NC_FOLLOW_DIALOG_QUESTION)
    local text = header .. "\n\n" .. leader .. "\n" .. zone .. "\n\n" .. question

    NecroCat.Follow.Label:SetText(text)

    frame.leader = leader
    frame:SetHidden(false)
end

function FM.SendBeacon()
    if not IsUnitGrouped("player") then return end
    local name = GetUnitName("player") or ""
    local zone = GetUnitZone("player") or GetPlayerLocationName() or "???"
    local msg = string.format("FM:%s:%s", zo_strtrim(name), zo_strtrim(zone))
    StartChatInput("/p " .. msg, CHAT_CHANNEL_PARTY)
end

local function OnChatMessage(eventCode, channelType, fromName, messageText, isCustomerService, fromDisplayName)
    if channelType ~= CHAT_CHANNEL_PARTY then return end
    if not messageText or type(messageText) ~= "string" or messageText:sub(1, 3) ~= "FM:" then return end

    local cmd, leader, zone = zo_strsplit(":", messageText)
    if not cmd or cmd:upper() ~= "FM" then return end

    local myChar = zo_strformat("<<1>>", GetUnitName("player") or "")
    local cleanFromName = zo_strformat("<<1>>", fromName or "")
    local senderIsSelf = (cleanFromName == myChar)

    if senderIsSelf and not NecroCat.savedVars.followShowOwn then return end

    if NecroCat.savedVars.followAutoAccept then
        JumpToGroupMember(leader)
    else
        FM.OpenDialog(leader, zone)
    end
end

-- Переключение авторежима
function FM.ToggleAutoPrepare()
    NecroCat.savedVars.followAutoPrepare = not NecroCat.savedVars.followAutoPrepare
    FM.UpdateChatButtonColor()

    if NecroCat.savedVars.followAutoPrepare then
        d(GetString(SI_NC_FOLLOW_AUTO_ON))
    else
        d(GetString(SI_NC_FOLLOW_AUTO_OFF))
    end
end

function FM.UpdateChatButtonColor()
    if not FM.ChatButton then return end
    FM.ChatButton:SetNormalTexture("/esoui/art/buttons/accept_up.dds")

    if NecroCat.savedVars.followAutoPrepare then
        FM.ChatButton:SetAlpha(1.0)
    else
        FM.ChatButton:SetAlpha(0.35)
    end
end

local isFirstLoad = true
local isChatHooked = false

local function OnPlayerActivated(eventCode)
    -- Глушим чат, когда он уже 100% проснулся в мире
    if not isChatHooked and CHAT_SYSTEM and CHAT_SYSTEM.primaryContainer then
        ZO_PreHook(CHAT_SYSTEM.primaryContainer, "AddEventMessageToContainer", function(self, message)
            if type(message) == "string" and message:find("FM:") then
                return true
            end
        end)
        isChatHooked = true
    end

    if isFirstLoad then
        isFirstLoad = false
        return
    end

    if not (NecroCat.savedVars and NecroCat.savedVars.followAutoPrepare) then return end
    if not IsUnitGrouped("player") then return end

    zo_callLater(function()
        FM.SendBeacon()
    end, 500)
end

EVENT_MANAGER:RegisterForEvent("NecroCat_Follow_Load", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

-- Обновление позиции кнопки в чате
function FM.UpdateButtonPosition()
    if not FM.ChatButton then return end
    local x = (NecroCat.savedVars and NecroCat.savedVars.followButtonX) or 177
    FM.ChatButton:ClearAnchors()
    FM.ChatButton:SetAnchor(TOPLEFT, ZO_ChatWindow, TOPLEFT, x, 10)
end

-- Сброс позиции кнопки на 177
function FM.ResetButtonPosition()
    if not NecroCat.savedVars then return end
    NecroCat.savedVars.followButtonX = 177
    FM.UpdateButtonPosition()
end

function FM.Init()
    CreateDialog()
    EVENT_MANAGER:RegisterForEvent("NecroCat_Follow", EVENT_CHAT_MESSAGE_CHANNEL, OnChatMessage)
    SLASH_COMMANDS["/fm"] = function() FM.SendBeacon() end
    SLASH_COMMANDS["/fmdemo"] = function()
        FM.OpenDialog(GetString(SI_NC_FOLLOW_DEMO_PLAYER), GetString(SI_NC_FOLLOW_DEMO_ZONE))
    end

    local btn = WINDOW_MANAGER:CreateControl("NecroCat_FollowChatBtn", ZO_ChatWindow, CT_BUTTON)
    btn:SetDimensions(28, 28)
    btn:SetAnchor(TOPLEFT, ZO_ChatWindow, TOPLEFT, NecroCat.savedVars.followButtonX or 177, 10)
    btn:SetNormalTexture("/esoui/art/buttons/accept_up.dds")

    btn:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside then
            if button == MOUSE_BUTTON_INDEX_LEFT then
                FM.SendBeacon()
            elseif button == MOUSE_BUTTON_INDEX_RIGHT then
                FM.ToggleAutoPrepare()
            end
        end
    end)

    btn:SetHidden(not NecroCat.savedVars.followShowButton)
    FM.ChatButton = btn

    FM.UpdateChatButtonColor()
end