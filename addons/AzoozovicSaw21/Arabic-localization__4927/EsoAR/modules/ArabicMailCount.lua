-- Keep the minimized chat mail count on one line at any digit count.
local function ResizeMailCount(chat)
    local label = chat.mailLabel
    if not label or not chat.mailButton then return end
    local scale = GetUIGlobalScale()
    local width = math.max(32, label:GetStringWidth(label:GetText() or "") / scale + 8)
    label:SetMaxLineCount(1)
    label:ClearAnchors()
    label:SetWidth(width)
    if chat.isMinimized then
        label:SetAnchor(TOPLEFT, chat.mailButton, BOTTOMLEFT, 0, -5)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    else
        label:SetAnchor(LEFT, chat.mailButton, RIGHT, 2)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end
end

if ZO_ChatSystem and SecurePostHook then
    SecurePostHook(ZO_ChatSystem, "ShowMinBar", ResizeMailCount)
    SecurePostHook(ZO_ChatSystem, "HideMinBar", ResizeMailCount)
    SecurePostHook(ZO_ChatSystem, "OnNumUnreadMailChanged", ResizeMailCount)
    EVENT_MANAGER:RegisterForEvent("EsoARMailCount", EVENT_PLAYER_ACTIVATED, function()
        if CHAT_SYSTEM then ResizeMailCount(CHAT_SYSTEM) end
    end)
end
