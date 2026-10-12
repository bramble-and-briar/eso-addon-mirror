local Hermes = _G['Hermes']

local LCM = LibCustomMenu
local GroupNames = {}

function Hermes:UpdateGroupMembers()
    ZO_ClearTable(GroupNames)

    for i = 1, GetGroupSize() do
        local tag = "group" .. i
        local unitName = GetUnitName(tag)
        local displayName = GetUnitDisplayName(tag)

        if unitName ~= "" and displayName ~= "" then
            GroupNames[unitName] = displayName
            GroupNames[zo_strformat(SI_UNIT_NAME, unitName)] = displayName
        end
    end
end

local function getAccountName(name)
    if not name or name == "" then
        return nil
    end

    if zo_strsub(name, 1, 1) == "@" then
        return name
    end

    return GroupNames[name]
end

function Hermes:IsGuildMember(accountName)
    for index = 1, GetNumGuilds() do
        if GetGuildMemberIndexFromDisplayName(GetGuildId(index), accountName) then
            return true
        end
    end
    return false
end

function Hermes:InitializeChatMenu()
    LCM:RegisterPlayerContextMenu(function(playerName, rawName)
        local accountName = getAccountName(playerName) or getAccountName(rawName)

        if not accountName then
            return
        end

        if self.db.showMail then
            AddCustomMenuItem(GetString(SI_SOCIAL_MENU_SEND_MAIL), function()
                if MAIL_SEND:IsHidden() then
                    MAIL_SEND:ComposeMailTo(accountName)
                else
                    MAIL_SEND:SetReply(accountName)
                end
            end)
        end

        if self.db.showTeleport then
            if IsPlayerInGroup(accountName) then
                AddCustomMenuItem(GetString(SI_SOCIAL_MENU_JUMP_TO_PLAYER), function()
                    JumpToGroupMember(accountName)
                end)
            elseif IsFriend(accountName) then
                AddCustomMenuItem(GetString(SI_SOCIAL_MENU_JUMP_TO_PLAYER), function()
                    JumpToFriend(accountName)
                end)
            elseif self:IsGuildMember(accountName) then
                AddCustomMenuItem(GetString(SI_SOCIAL_MENU_JUMP_TO_PLAYER), function()
                    JumpToGuildMember(accountName)
                end)
            end
        end

        if self.db.showHouse then
            AddCustomMenuItem(GetString(SI_SOCIAL_MENU_VISIT_HOUSE), function()
                JumpToHouse(accountName)
            end)
        end
    end, LCM.CATEGORY_LATE)
end