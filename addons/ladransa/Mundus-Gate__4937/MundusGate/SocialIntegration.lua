-- Дома других игроков: пункт в меню ПКМ в списках друзей, гильдии и группы.
--
-- Эти списки собирают меню через AddMenuItem и показывают его методом
-- self:ShowMenu(control). Аддон оборачивает ShowMenu у каждого списка:
-- перед показом добавляет свой пункт для игрока в выбранной строке.
local QTM  = MundusGate
local L    = QTM.L
local Data = QTM.Data

local SocialIntegration = {}
QTM.SocialIntegration = SocialIntegration

local function AddPlayerHouseItem(displayName)
    if not displayName or displayName == "" or displayName == GetDisplayName() then return end

    if Data:HasPlayerHouse(displayName) then
        AddMenuItem(L.SOCIAL_REMOVE_HOUSE, function()
            Data:RemovePlayerHouse(displayName)
            QTM.Buttons:RefreshAll()
            QTM.Menu:RefreshIfShown()
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ALERT_HOUSE_REMOVED, displayName))
        end)
    else
        AddMenuItem(L.SOCIAL_ADD_HOUSE, function()
            Data:AddPlayerHouse(displayName)
            QTM.Menu:RefreshIfShown()
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ALERT_HOUSE_ADDED, displayName))
        end)
    end
end

local function Install(list)
    if not list or not list.ShowMenu or list.qtmInstalled then return end
    list.qtmInstalled = true

    local originalShowMenu = list.ShowMenu
    function list:ShowMenu(control, ...)
        -- В строке списка лежат данные игрока; если это не строка — ничего не добавляем
        local ok, data = pcall(ZO_ScrollList_GetData, control)
        if ok and type(data) == "table" and data.displayName and not data.isPlayer then
            AddPlayerHouseItem(data.displayName)
        end
        return originalShowMenu(self, control, ...)
    end
end

function SocialIntegration:Initialize()
    Install(FRIENDS_LIST)
    Install(GUILD_ROSTER_KEYBOARD)
    Install(GROUP_LIST)
end
