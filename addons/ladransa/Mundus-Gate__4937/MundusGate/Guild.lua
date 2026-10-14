-- Гильдии: перемещение к гильдейскому торговцу и в гильдхолл.
--
-- У каждой гильдии два «места» — их можно добавить в «Мои места», вынести
-- кнопкой на экран, положить в колесо, как любое другое место:
--   • "trader:<guildId>" — торговец гильдии: перемещение к ближайшему
--     святилищу. Игра сообщает только имя торговца, поэтому святилище ищется
--     по названию: сначала в имени торговца («Доннейлайн в Белкарте»), потом
--     в описании и сообщении дня гильдии (там обычно пишут, где торговец).
--     Не нашлось или нашлось не то — святилище выбирается вручную (ПКМ).
--   • "hall:<guildId>" — гильдхолл: дом игрока. По умолчанию — основной дом
--     главы гильдии; владельца и конкретный дом можно указать (ПКМ).
-- На вкладке гильдии «Главная»: под торговцем — кнопка «Перемещение к
-- торговцу», ниже — раздел «Гильдейский холл» со значком и кнопкой
-- «Перемещение в холл» (ПКМ по кнопкам — действия).
local QTM  = MundusGate
local L    = QTM.L
local Data = QTM.Data

local Guild = {}
QTM.Guild = Guild

local ICON_TRADER = "EsoUI/Art/Guild/ownership_icon_guildTrader.dds"
local ICON_HALL   = "/esoui/art/icons/poi/poi_group_house_owned.dds"
local MIN_MATCH   = 4   -- столько первых букв слова должно совпасть

local lower = LocaleAwareToLower or zo_strlower or string.lower

function Guild:Initialize()
    ZO_Dialogs_RegisterCustomDialog("MUNDUSGATE_GUILD_HALL", {
        title    = { text = L.GUILD_HALL_DIALOG_TITLE },
        mainText = { text = L.GUILD_HALL_DIALOG_TEXT },
        editBox  = { defaultText = "", maxInputCharacters = 40, selectAll = true },
        buttons  = {
            {
                text     = L.RENAME_SAVE,
                callback = function(dialog)
                    self:SetHallOwner(dialog.data.guildId, ZO_Dialogs_GetEditBoxText(dialog))
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })

    -- Состав гильдий изменился — пересобрать места
    local function OnGuildsChanged()
        Data:Invalidate()
        if QTM.RefreshAllViews then QTM.RefreshAllViews() end
        self:RefreshHomeButtons()
    end
    local em = EVENT_MANAGER
    local name = QTM.name .. "Guild"
    for _, eventName in ipairs({ "EVENT_GUILD_SELF_JOINED_GUILD", "EVENT_GUILD_SELF_LEFT_GUILD" }) do
        if _G[eventName] then em:RegisterForEvent(name, _G[eventName], OnGuildsChanged) end
    end
    if EVENT_GUILD_TRADER_HIRED_UPDATED then
        em:RegisterForEvent(name, EVENT_GUILD_TRADER_HIRED_UPDATED, function()
            if QTM.RefreshTravelState then QTM.RefreshTravelState() end
            self:RefreshHomeButtons()
        end)
    end

    self:CreateHomeButtons()
end

---------------------------------------------------------------------------
-- Места гильдий для списка мест (Data:BuildNodes)
---------------------------------------------------------------------------
function Guild:GetGuildIds()
    local ids = {}
    for index = 1, (GetNumGuilds and GetNumGuilds() or 0) do
        local guildId = GetGuildId(index)
        if guildId and guildId ~= 0 then ids[#ids + 1] = guildId end
    end
    return ids
end

function Guild:MakeNodes()
    local nodes = {}
    for _, guildId in ipairs(self:GetGuildIds()) do
        local guildName = zo_strformat("<<1>>", GetGuildName(guildId) or "")
        local hall = self:GetHall(guildId)
        nodes[#nodes + 1] = {
            nodeIndex     = "trader:" .. guildId,
            isGuildTrader = true,
            guildId       = guildId,
            originalName  = zo_strformat(L.GUILD_TRADER_NAME, guildName),
            zoneName      = L.GUILDS_ZONE,
            icon          = ICON_TRADER,
            type          = Data.TYPE_GUILD,
        }
        nodes[#nodes + 1] = {
            nodeIndex     = "hall:" .. guildId,
            isGuildHall   = true,
            isPlayerHouse = true,       -- перемещение как в дом игрока: бесплатно, без бесплатного пути
            guildId       = guildId,
            displayName   = hall.owner,
            originalName  = zo_strformat(L.GUILD_HALL_NAME, guildName),
            zoneName      = L.GUILDS_ZONE,
            icon          = ICON_HALL,
            type          = Data.TYPE_GUILD,
        }
    end
    return nodes
end

---------------------------------------------------------------------------
-- Торговец: святилище в городе торговца
---------------------------------------------------------------------------
function Guild:GetKioskName(guildId)
    local name = GetGuildOwnedKioskInfo and GetGuildOwnedKioskInfo(guildId)
    if name and name ~= "" then return zo_strformat("<<1>>", name) end
    return nil
end

-- Слова текста в нижнем регистре, по буквам (UTF-8)
local function Words(text)
    local words = {}
    for word in lower(text or ""):gmatch("[^%s%p]+") do
        local chars = {}
        for char in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = char end
        if #chars >= MIN_MATCH then words[#words + 1] = chars end
    end
    return words
end

-- Сколько первых букв совпадает (окончания могут отличаться: «Белкарте» и «Белкарта»)
local function MatchScore(a, b)
    local common = 0
    for index = 1, zo_min(#a, #b) do
        if a[index] ~= b[index] then break end
        common = common + 1
    end
    if common < MIN_MATCH or common < zo_min(#a, #b) - 2 then return 0 end
    return common
end

-- Слова в названиях святилищ без общих («святилище», «wayshrine»):
-- слово, которое есть в каждом четвёртом названии, ничего не различает
function Guild:GetWayshrineWords()
    local nodes = Data:GetNodes()
    if self.matchNodes == nodes then return self.wayshrineWords end
    self.matchNodes, self.matchCache = nodes, {}

    local entries, seen, total = {}, {}, 0
    for _, node in ipairs(nodes) do
        if node.type == Data.TYPE_WAYSHRINE then
            total = total + 1
            local words = Words(node.originalName)
            entries[#entries + 1] = { nodeIndex = node.nodeIndex, words = words }
            for _, word in ipairs(words) do
                local key = table.concat(word)
                seen[key] = (seen[key] or 0) + 1
            end
        end
    end
    local limit = zo_max(3, total / 4)
    for _, entry in ipairs(entries) do
        local distinct = {}
        for _, word in ipairs(entry.words) do
            if seen[table.concat(word)] <= limit then distinct[#distinct + 1] = word end
        end
        entry.words = distinct
    end
    self.wayshrineWords = entries
    return entries
end

-- Убрать из текста цвета и ссылки чата
local function PlainText(text)
    text = text or ""
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H[^|]*|h(.-)|h", "%1"):gsub("|t[^|]*|t", "")
    return text
end

-- Святилище, название которого упомянуто в тексте (или nil)
function Guild:FindWayshrine(text)
    text = PlainText(text)
    if text == "" then return nil end
    local entries = self:GetWayshrineWords()
    local cached = self.matchCache[text]
    if cached ~= nil then return cached or nil end

    local textWords = Words(text)
    local best, bestScore, bestPos = nil, 0, nil
    for _, entry in ipairs(entries) do
        local score, firstPos = 0, nil
        for _, nodeWord in ipairs(entry.words) do
            local wordBest, wordPos = 0, nil
            for pos, textWord in ipairs(textWords) do
                local match = MatchScore(nodeWord, textWord)
                if match > wordBest then wordBest, wordPos = match, pos end
            end
            score = score + wordBest
            if wordPos and (not firstPos or wordPos < firstPos) then firstPos = wordPos end
        end
        -- больше совпавших букв; при равенстве — то, что упомянуто раньше
        if score > bestScore or (score == bestScore and score > 0 and firstPos < bestPos) then
            best, bestScore, bestPos = entry.nodeIndex, score, firstPos
        end
    end
    self.matchCache[text] = best or false
    return best
end

-- Строки описания, где речь о торговце
local TRADER_HINTS = { "торгов", "киоск", "trader", "kiosk", "store", "händler", "marchand", "comerciante", "mercante" }

local function TraderLines(text)
    local lines = {}
    for line in (text or ""):gmatch("[^\n]+") do
        local low = lower(line)
        for _, hint in ipairs(TRADER_HINTS) do
            if low:find(hint, 1, true) then lines[#lines + 1] = line; break end
        end
    end
    return table.concat(lines, "\n")
end

-- Святилище у торговца гильдии (или nil, причина).
-- Второе значение при успехе — откуда взято: "manual", "kiosk", "description"
function Guild:GetTraderWayshrine(guildId)
    local kiosk = self:GetKioskName(guildId)
    if not kiosk then return nil, L.REASON_NO_TRADER end

    local nodeIndex, source = QTM.sv.traderShrines[kiosk], "manual"
    if not nodeIndex then
        nodeIndex, source = self:FindWayshrine(kiosk), "kiosk"
    end
    if not nodeIndex then
        local about = (GetGuildDescription and GetGuildDescription(guildId) or "") .. "\n"
            .. (GetGuildMotD and GetGuildMotD(guildId) or "")
        nodeIndex = self:FindWayshrine(TraderLines(about)) or self:FindWayshrine(about)
        source = "description"
    end
    local node = nodeIndex and Data:GetNode(nodeIndex)
    if not node then return nil, L.REASON_TRADER_UNKNOWN end
    return node, source
end

function Guild:PickTraderWayshrine(guildId)
    local kiosk = self:GetKioskName(guildId)
    if not kiosk then
        Data.Alert(L.REASON_NO_TRADER)
        return
    end
    QTM.PlacePicker:Open(function(nodeIndex)
        local node = Data:GetNode(nodeIndex)
        if not node or node.type ~= Data.TYPE_WAYSHRINE then
            Data.Alert(L.GUILD_PICK_WAYSHRINE)
            return
        end
        QTM.sv.traderShrines[kiosk] = nodeIndex
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.GUILD_TRADER_SET, kiosk, node.name))
        self:Changed()
    end, nil, "")
end

function Guild:ResetTraderWayshrine(guildId)
    local kiosk = self:GetKioskName(guildId)
    if kiosk then QTM.sv.traderShrines[kiosk] = nil end
    self:Changed()
end

---------------------------------------------------------------------------
-- Гильдхолл: владелец (по умолчанию глава гильдии) и дом (по умолчанию основной)
---------------------------------------------------------------------------
function Guild:GetLeader(guildId)
    local _, _, leader = GetGuildInfo(guildId)
    return leader
end

function Guild:GetHall(guildId)
    local saved = QTM.sv.guildHalls[guildId]
    local owner = saved and saved.owner
    local isDefault = owner == nil or owner == ""
    if isDefault then owner = self:GetLeader(guildId) end
    return { owner = owner, houseId = saved and saved.houseId or nil, isDefault = isDefault }
end

function Guild:SetHallOwner(guildId, text)
    text = zo_strtrim(text or "")
    local saved = QTM.sv.guildHalls[guildId] or {}
    if text == "" then
        saved.owner = nil
    else
        if text:sub(1, 1) ~= "@" then text = "@" .. text end
        saved.owner = text
    end
    QTM.sv.guildHalls[guildId] = saved
    self:Changed()
end

function Guild:ShowHallOwnerDialog(guildId)
    local saved = QTM.sv.guildHalls[guildId]
    ZO_Dialogs_ShowDialog("MUNDUSGATE_GUILD_HALL", { guildId = guildId }, {
        mainTextParams  = { zo_strformat("<<1>>", GetGuildName(guildId) or ""), self:GetLeader(guildId) or "" },
        initialEditText = saved and saved.owner or "",
    })
end

function Guild:PickHallHouse(guildId)
    QTM.PlacePicker:Open(function(nodeIndex)
        local node = Data:GetNode(nodeIndex)
        if not node or node.type ~= Data.TYPE_HOUSE then
            Data.Alert(L.GUILD_PICK_HOUSE)
            return
        end
        local saved = QTM.sv.guildHalls[guildId] or {}
        saved.houseId = Data:GetHouseId(node)
        QTM.sv.guildHalls[guildId] = saved
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.GUILD_HALL_HOUSE_SET, node.originalName))
        self:Changed()
    end, nil, "")
end

function Guild:ResetHallHouse(guildId)
    local saved = QTM.sv.guildHalls[guildId]
    if saved then saved.houseId = nil end
    self:Changed()
end

function Guild:JumpToHall(guildId)
    local hall = self:GetHall(guildId)
    if not hall.owner or hall.owner == "" then
        Data.Alert(L.REASON_NO_HALL)
        return nil
    end
    if hall.owner == GetDisplayName() then
        -- Свой дом: напрямую (не выбран — основной)
        local houseId = hall.houseId or (GetHousingPrimaryHouse and GetHousingPrimaryHouse()) or 0
        if houseId ~= 0 and RequestJumpToHouse then
            RequestJumpToHouse(houseId, QTM.sv.houseOutside)
        else
            Data.Alert(L.GUILD_HALL_OWN)
            return nil
        end
    elseif hall.houseId and JumpToSpecificHouse then
        JumpToSpecificHouse(hall.owner, hall.houseId)
    else
        JumpToHouse(hall.owner)
    end
    return "started"
end

---------------------------------------------------------------------------
-- Доступность (Data:GetNodeStatus)
---------------------------------------------------------------------------
function Guild:GetStatus(node)
    if node.isGuildHall then
        local hall = self:GetHall(node.guildId)
        if not hall.owner or hall.owner == "" then return false, L.REASON_NO_HALL end
        return true
    end
    local target, reason = self:GetTraderWayshrine(node.guildId)
    if not target then return false, reason end
    return Data:GetNodeStatus(target)
end

-- Подпись под названием: куда ведёт место
function Guild:Describe(node)
    if node.isGuildHall then
        local hall = self:GetHall(node.guildId)
        local text = zo_strformat(L.GUILD_HALL_OWNER, hall.owner or "?")
        if hall.isDefault then text = text .. " " .. L.GUILD_HALL_DEFAULT end
        if hall.houseId then
            local houseName = GetCollectibleName and GetCollectibleIdForHouse and GetCollectibleName(GetCollectibleIdForHouse(hall.houseId))
            if houseName and houseName ~= "" then text = text .. "\n" .. zo_strformat("<<1>>", houseName) end
        end
        return text
    end
    local kiosk = self:GetKioskName(node.guildId)
    if not kiosk then return L.REASON_NO_TRADER end
    local target, source = self:GetTraderWayshrine(node.guildId)
    local text = kiosk
    if target then
        text = text .. "\n" .. zo_strformat(L.GUILD_TRADER_SHRINE, target.name)
        if source == "description" then text = text .. " " .. L.GUILD_TRADER_FROM_DESC end
        if source == "manual" then text = text .. " " .. L.GUILD_TRADER_MANUAL end
    end
    return text
end

function Guild:Changed()
    self.matchNodes = nil
    Data:Invalidate()
    if QTM.RefreshAllViews then QTM.RefreshAllViews() end
    if QTM.Buttons and QTM.Buttons.RefreshAll then QTM.Buttons:RefreshAll() end
    self:RefreshHomeButtons()
end

---------------------------------------------------------------------------
-- Действия с местом гильдии (ПКМ по кнопке на вкладке гильдии)
---------------------------------------------------------------------------
function Guild:GetNode(kind, guildId)
    return Data:GetNode(kind .. ":" .. guildId)
end

function Guild:Travel(kind, guildId)
    local node = self:GetNode(kind, guildId)
    if not node then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    if Data:Travel(node, false, "Menu") == "started" then
        SCENE_MANAGER:ShowBaseScene()
    end
end

function Guild:ShowMenu(control, kind, guildId)
    local node = self:GetNode(kind, guildId)
    if not node then return end
    ClearMenu()
    local available = Data:GetNodeStatus(node)
    if available then
        AddMenuItem(L.CTX_TRAVEL, function() self:Travel(kind, guildId) end)
    end
    if Data:IsFavorite(node.nodeIndex) then
        AddMenuItem(L.MAP_REMOVE, function() Data:SetFavorite(node.nodeIndex, false); self:Changed() end)
    else
        AddMenuItem(L.MAP_ADD, function()
            Data:SetFavorite(node.nodeIndex, true)
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.MAP_ADDED, node.name))
            self:Changed()
        end)
    end
    AddMenuItem(L.CTX_ADD_BUTTON, function()
        QTM.Buttons:Add(node.nodeIndex)
        QTM.Buttons:UpdateVisibility()
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ALERT_BUTTON_ADDED, node.name))
    end)
    AddMenuItem(L.CTX_ADD_WHEEL, function()
        if QTM.Wheel:AddSlot(node.nodeIndex) then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DEFAULT_CLICK, zo_strformat(L.ALERT_WHEEL_ADDED, node.name))
        end
    end)
    if kind == "trader" then
        AddMenuItem(L.GUILD_CTX_PICK_SHRINE, function() self:PickTraderWayshrine(guildId) end)
        local kiosk = self:GetKioskName(guildId)
        if kiosk and QTM.sv.traderShrines[kiosk] then
            AddMenuItem(L.GUILD_CTX_AUTO_SHRINE, function() self:ResetTraderWayshrine(guildId) end)
        end
    else
        AddMenuItem(L.GUILD_CTX_HALL_OWNER, function() self:ShowHallOwnerDialog(guildId) end)
        AddMenuItem(L.GUILD_CTX_HALL_HOUSE, function() self:PickHallHouse(guildId) end)
        if self:GetHall(guildId).houseId then
            AddMenuItem(L.GUILD_CTX_HALL_PRIMARY, function() self:ResetHallHouse(guildId) end)
        end
    end
    ShowMenu(control)
end

---------------------------------------------------------------------------
-- Вкладка гильдии «Главная»: кнопка под торговцем и раздел «Гильдейский холл»
-- в том же виде, что «Владения» и «Торговец»: заголовок, значок, подпись, кнопка
---------------------------------------------------------------------------
local WM = WINDOW_MANAGER

local function NormalTextColor()
    if GetInterfaceColor and INTERFACE_COLOR_TYPE_TEXT_COLORS then
        return GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL)
    end
    return 0.77, 0.76, 0.62, 1
end

function Guild:MakeTravelButton(name, parent, kind, text)
    local button = WM:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    button:SetDimensions(200, 28)
    button:SetText(text)
    button.kind = kind
    button:SetHandler("OnClicked", function(c)
        local guildId = self:GetHomeGuildId()
        if guildId then self:Travel(c.kind, guildId) end
    end)
    -- ПКМ — действия (своё имя обработчика, чтобы не заменить обработчики кнопки)
    button:SetHandler("OnMouseUp", function(c, mouseButton, upInside)
        local guildId = self:GetHomeGuildId()
        if upInside and guildId and mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
            ZO_Tooltips_HideTextTooltip()
            self:ShowMenu(c, c.kind, guildId)
        end
    end, QTM.name)
    button:SetHandler("OnMouseEnter", function(c) self:OnButtonEnter(c) end, QTM.name)
    button:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end, QTM.name)
    return button
end

function Guild:CreateHomeButtons()
    local trader = ZO_GuildHomeTrader
    local traderName = ZO_GuildHomeTraderName
    if not (trader and traderName) then return end
    local home = trader:GetParent()
    self.traderName = traderName
    self.bidsButton = ZO_GuildHomeTraderViewWeeklyBids

    -- Под торговцем: «Перемещение к торговцу»
    local traderButton = self:MakeTravelButton("MundusGateGuildTraderTravel", trader, "trader", L.GUILD_BUTTON_TRADER)

    -- Раздел «Гильдейский холл»: заголовок, значок, подпись, кнопка
    local hall = WM:CreateControl("MundusGateGuildHall", home, CT_CONTROL)
    hall:SetDimensions(200, 230)
    hall:SetAnchor(TOP, traderButton, BOTTOM, 0, 30)

    local header = WM:CreateControl("MundusGateGuildHallOwnership", hall, CT_LABEL)
    header:SetFont("ZoFontHeader2")
    header:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    header:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    header:SetAnchor(TOPLEFT, hall, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, hall, TOPRIGHT, 0, 0)
    header:SetText(L.GUILD_HALL_HEADER)

    local icon = WM:CreateControl("MundusGateGuildHallIcon", hall, CT_TEXTURE)
    icon:SetDimensions(96, 96)
    icon:SetAnchor(TOP, header, BOTTOM, 0, 6)
    icon:SetTexture(ICON_HALL)
    icon:SetMouseEnabled(true)
    icon.kind = "hall"
    icon:SetHandler("OnMouseEnter", function(c) self:OnButtonEnter(c) end)
    icon:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end)
    icon:SetHandler("OnMouseUp", function(c, mouseButton, upInside)
        local guildId = self:GetHomeGuildId()
        if upInside and guildId and mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
            ZO_Tooltips_HideTextTooltip()
            self:ShowMenu(c, "hall", guildId)
        end
    end)

    local name = WM:CreateControl("MundusGateGuildHallName", hall, CT_LABEL)
    name:SetFont("ZoFontHeader2")
    name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    name:SetColor(NormalTextColor())
    name:SetAnchor(TOPLEFT, hall, TOPLEFT, 0, 132)
    name:SetAnchor(TOPRIGHT, hall, TOPRIGHT, 0, 132)

    local hallButton = self:MakeTravelButton("MundusGateGuildHallTravel", hall, "hall", L.GUILD_BUTTON_HALL)
    hallButton:SetAnchor(TOP, name, BOTTOM, 0, 10)

    self.home = { traderButton = traderButton, hall = hall, hallIcon = icon, hallName = name, hallButton = hallButton }

    if GUILD_HOME_SCENE then
        GUILD_HOME_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then self:RefreshHomeButtons() end
        end)
    end
    if GUILD_HOME and (SecurePostHook or ZO_PostHook) then
        local hook = SecurePostHook or ZO_PostHook
        -- RefreshAll вызывается при смене гильдии, RefreshPermissions — когда меняется видимость «Ставок»
        for _, method in ipairs({ "RefreshAll", "RefreshPermissions", "RefreshTraderOwnership" }) do
            if GUILD_HOME[method] then hook(GUILD_HOME, method, function() self:RefreshHomeButtons() end) end
        end
    end
    self:RefreshHomeButtons()
end

function Guild:GetHomeGuildId()
    return GUILD_HOME and GUILD_HOME.guildId or nil
end

-- Подпись под значком гильдхолла: дом и владелец
function Guild:GetHallCaption(guildId)
    local hall = self:GetHall(guildId)
    if not hall.owner or hall.owner == "" then return L.REASON_NO_HALL end
    local houseName
    if hall.houseId and GetCollectibleIdForHouse and GetCollectibleName then
        houseName = zo_strformat("<<1>>", GetCollectibleName(GetCollectibleIdForHouse(hall.houseId)) or "")
    end
    if not houseName or houseName == "" then houseName = L.GUILD_HALL_PRIMARY end
    return zo_strformat(L.GUILD_HALL_CAPTION, houseName, hall.owner)
end

function Guild:RefreshHomeButtons()
    local home = self.home
    local guildId = self:GetHomeGuildId()
    if not home or not guildId then return end

    -- Кнопка торговца — под «Ставками за неделю», если они видны, иначе под именем торговца
    local below = (self.bidsButton and not self.bidsButton:IsHidden()) and self.bidsButton or self.traderName
    home.traderButton:ClearAnchors()
    home.traderButton:SetAnchor(TOP, below, BOTTOM, 0, 10)

    local traderNode = self:GetNode("trader", guildId)
    home.traderButton:SetHidden(GetGuildOwnedKioskInfo(guildId) == nil)
    home.traderButton:SetAlpha((traderNode and Data:GetNodeStatus(traderNode)) and 1 or 0.6)

    local hallNode = self:GetNode("hall", guildId)
    local hallAvailable = hallNode and Data:GetNodeStatus(hallNode)
    home.hallIcon:SetAlpha(hallAvailable and 1 or 0.2)
    home.hallName:SetText(self:GetHallCaption(guildId))
    home.hallButton:SetAlpha(hallAvailable and 1 or 0.6)
end

function Guild:OnButtonEnter(control)
    local guildId = self:GetHomeGuildId()
    local node = guildId and self:GetNode(control.kind, guildId)
    if not node then return end
    local title = control.kind == "trader" and L.GUILD_TRAVEL_TRADER or L.GUILD_TRAVEL_HALL
    local available, reason = Data:GetNodeStatus(node)
    local lines = { title, self:Describe(node) }
    if available then
        lines[#lines + 1] = Data:GetPriceLine(node, "Menu")
    elseif reason then
        lines[#lines + 1] = "|cFF6060" .. reason .. "|r"
    end
    lines[#lines + 1] = "|c8A8A8A" .. L.GUILD_BUTTON_HINT .. "|r"
    QTM.ShowTip("guild", control, RIGHT, table.concat(lines, "\n"))
end
