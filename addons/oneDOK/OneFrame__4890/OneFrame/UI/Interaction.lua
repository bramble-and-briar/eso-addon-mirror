local A = OneFrame
local I = { menuRevision = 0 }
A.Interaction = I
function I:Resolve(control, expected)
    if not A.active or not A.sv.interaction or not A.sv.contextMenu or control:IsHidden() then return end
    local tag = control.m_unitTag -- Resolve on EVERY click/action, never at attachment time.
    local frame = tag and UNIT_FRAMES:GetFrame(tag)
    if not A.GroupData:IsPlayerFrame(frame) or frame.frame ~= control or not DoesUnitExist(tag) then return end
    local identity = { account = GetUnitDisplayName(tag), character = GetRawUnitName(tag) }
    if identity.account == "" or identity.character == "" then return end
    if expected and (expected.account ~= identity.account or expected.character ~= identity.character) then return end
    return tag, identity
end
function I:CanRemove(tag)
    return not AreUnitsEqual(tag, "player") and IsUnitGroupLeader("player")
        and IsGroupModificationAvailable() and not DoesGroupModificationRequireVote()
end
function I:CanPromote(tag)
    -- Matches the native group list: promotion is independent of kick/vote rules.
    return IsUnitGroupLeader("player") and not AreUnitsEqual(tag, "player") and IsUnitOnline(tag)
end
function I:Open(control)
    local tag, identity = self:Resolve(control)
    if not tag then return end
    ClearMenu()
    if IsChatSystemAvailableForCurrentPlatform() then
        AddMenuItem(GetString(ONEFRAME_WHISPER), function()
            if self:Resolve(control, identity) then StartChatInput("", CHAT_CHANNEL_WHISPER, identity.account) end
        end)
    end
    AddMenuItem(GetString(ONEFRAME_TRAVEL), function()
        -- GetRawUnitName is for identity comparison, not a travel address. Account
        -- names are accepted by the native API and do not contain name grammar suffixes.
        if self:Resolve(control, identity) then JumpToGroupMember(identity.account) end
    end)
    if AreUnitsEqual(tag, "player") then
        AddMenuItem(GetString(SI_GROUP_LIST_MENU_LEAVE_GROUP), function()
            local currentTag = self:Resolve(control, identity)
            if currentTag and AreUnitsEqual(currentTag, "player") and GetGroupSize() > 0 then
                ZO_Dialogs_ShowDialog("GROUP_LEAVE_DIALOG")
            end
        end)
    end
    if self:CanPromote(tag) then
        AddMenuItem(GetString(SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER), function()
            local currentTag = self:Resolve(control, identity)
            if currentTag and self:CanPromote(currentTag) then GroupPromote(currentTag) end
        end)
    end
    if self:CanRemove(tag) then
        AddMenuItem(GetString(ONEFRAME_REMOVE), function()
            local currentTag = self:Resolve(control, identity)
            if currentTag and self:CanRemove(currentTag) then GroupKick(currentTag) end
        end)
    end
    ShowMenu(control)
end
function I:Attach(frame)
    local control = frame.frame
    -- The verified native template already enables mouse input on the whole frame.
    -- Record cursor state BEFORE vanilla clears it; never turn a cancelled drag into a menu.
    local eligible, menuRevision
    ZO_PreHookHandler(control, "OnMouseUp", function(_, button, upInside)
        eligible = button == MOUSE_BUTTON_INDEX_RIGHT and upInside
            and GetCursorContentType() == MOUSE_CONTENT_EMPTY
        menuRevision = self.menuRevision
        -- nil: always run the original handler.
    end)
    ZO_PostHookHandler(control, "OnMouseUp", function()
        if eligible and self.menuRevision == menuRevision then self:Open(control) end
        eligible = false
    end)
end
function I:Initialize()
    -- Respect a native/other-addon menu even when it has the same number of entries.
    for _, name in ipairs({ "ClearMenu", "AddMenuItem", "ShowMenu" }) do
        ZO_PostHook(name, function() self.menuRevision = self.menuRevision + 1 end)
    end
end
