-- Group actions are performed only after an explicit menu click.
DIAhelpGroupMenu={}
local M=DIAhelpGroupMenu
local function FindMember(account)
    for i=1,GROUP_SIZE_MAX do
        local tag=GetGroupUnitTagByIndex(i)
        if tag and GetUnitDisplayName(tag)==account then return tag end
    end
end
function M.Show(control,tag,companion)
    if companion or not tag then return end
    local account=GetUnitDisplayName(tag)
    if not account or account=='' then return end
    local self=AreUnitsEqual(tag,'player')
    local leader=IsUnitGroupLeader('player')
    local ru=GetCVar('language.2')=='ru'
    ClearMenu()
    local function Add(russian,english,action,needsLeader,needsMember)
        AddMenuItem(ru and russian or english,function()
            -- Group slots can change while a context menu is open.
            if not IsUnitGrouped('player') then return end
            if needsLeader and not IsUnitGroupLeader('player') then return end
            local current=FindMember(account)
            if needsMember and (not current or AreUnitsEqual(current,'player')) then return end
            action(current)
        end)
    end
    if not self then
        Add('Переместиться к игроку','Travel to player',function() JumpToGroupMember(account) end,false,true)
        Add('Добавить в друзья','Add friend',function() RequestFriend(account,'') end,false,true)
        Add('Предложить обмен','Invite to trade',function(current) TradeInvite(current) end,false,true)
        if leader then
            Add('Сделать лидером','Promote to leader',GroupPromote,true,true)
            Add('Исключить из группы','Remove from group',GroupKick,true,true)
        end
    end
    if leader then Add('Распустить группу','Disband group',function() GroupDisband() end,true,false) end
    Add('Покинуть группу','Leave group',function() GroupLeave() end,false,false)
    ShowMenu(control)
end
