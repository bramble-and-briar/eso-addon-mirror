-- English-client reward detection; no external libraries required.
-- AI-assisted code (ChatGPT/Codex); see CREDITS.txt for sources and review credits.
local A = {}
local VERSION = "1.1.2"
A.name = "GoldenSkullTracker"
local DAY = 86400
local CATEGORIES = {
    {key="delve", label="Delve", tip="Any delve boss."},
    {key="public", label="Public dungeon / IC Sweeper", tip="Any public dungeon boss OR Imperial City Sweeper. Shared category."},
    {key="world", label="World boss", tip="Any overland world boss."},
    {key="dungeon", label="Group dungeon", tip="The FINAL boss of a group dungeon."},
    {key="incursion", label="Incursion / world event", tip="Dolmen, Geyser, Harrowstorm, Dragon, Volcanic Vent, Mosaic or Siege Camp. Shared category."},
    {key="archive", label="Infinite Archive", tip="Tho'at Replicanum."},
    {key="crow", label="Crowborne Horror", tip="Defeat the Crowborne Horror, then TURN IN Plucking the Crow."},
    {key="hollowjack", label="Lord Hollowjack", tip="Defeat Lord Hollowjack, then TURN IN The Lord of Fear."},
    {key="trial", label="Trial", tip="The FINAL boss of a trial."},
    {key="arena", label="Arena", tip="The FINAL boss of Maelstrom, Vateshran, Dragonstar or Blackrose Prison."},
}
local SKULL_ALIASES = {
    {"crowborne", "crow"}, {"crownborne", "crow"},
    {"hollowjack", "hollowjack"}, {"public", "public"},
    {"sweeper", "public"}, {"infinite", "archive"},
    {"endless", "archive"}, {"insurgent", "incursion"},
    {"incursion", "incursion"}, {"delve", "delve"},
    {"dungeon", "dungeon"}, {"world", "world"},
    {"trial", "trial"}, {"arena", "arena"},
}

local function Normalize(text)
    -- Let ESO handle grammatical suffixes rather than parsing them ourselves.
    return zo_strlower(zo_strformat("<<1>>", text or ""))
end

local function Chat(message)
    d("|cEBC66DGolden Skulls:|r " .. message)
end

-- Fixed server reset, never the login-reward claim timer.
-- NA 10:00 UTC = 20:00 Australia/Brisbane, year round.
function A:GetResetOffset()
    local world = GetWorldName() or ""
    return world:find("EU", 1, true) and 10800 or 36000
end

function A:EnsureDay()
    local day = math.floor((GetTimeStamp() - self.resetOffset) / DAY)
    if self.saved.day ~= day then
        self.saved.day = day
        self.saved.completed = {}
        return true
    end
    return false
end

function A:Record(key, source)
    self:EnsureDay()
    if self.saved.completed[key] then return end
    self.saved.completed[key] = {
        character = zo_strformat("<<1>>", GetUnitName("player")),
        timestamp = GetTimeStamp(),
        manual = source == "manual",
        source = source,
    }
    self:Refresh()
    if source ~= "manual" then
        for _, category in ipairs(CATEGORIES) do
            if category.key == key then
                Chat(category.label .. " completed by " .. self.saved.completed[key].character .. ".")
                break
            end
        end
    end
end

function A:CategoryForName(name)
    name = Normalize(name)
    -- Require the golden container's name, not a motif or an ordinary skull.
    if not name:find("dremora plunder skull", 1, true) then return nil end
    -- The skull name may have punctuation, suffixes or wording variants.
    -- Check specific categories before the generic word 'dungeon'.
    for _, alias in ipairs(SKULL_ALIASES) do
        if name:find(alias[1], 1, true) then return alias[2] end
    end
end

function A:NameFromLinkOrText(value)
    if not value or value == "" then return "" end
    if value:find("|H", 1, true) then
        local name = GetItemLinkName(value)
        if name and name ~= "" then return name end
        return value:match("|h(.-)|h") or ""
    end
    return value
end

function A:Observe(value, source)
    local name = self:NameFromLinkOrText(value)
    if not Normalize(name):find("plunder skull", 1, true) then return end
    self.lastReward = name .. " [" .. source .. "]"
    local key = self:CategoryForName(name)
    if key then
        self:Record(key, source)
    elseif Normalize(name):find("dremora", 1, true) and self.lastUnknown ~= name then
        self.lastUnknown = name
        Chat("Unrecognised golden skull: " .. name .. ". /skulls debug shows detection details.")
    end
end

-- Seeing a category-specific golden reward in your own boss loot confirms
-- that the eligible boss has been killed, even before you take the skull.
function A:OnLootUpdated()
    for index = 1, GetNumLootItems() do
        local lootId, name, _, count = GetLootItemInfo(index)
        if (count or 0) > 0 then
            local link = GetLootItemLink(lootId, LINK_STYLE_DEFAULT)
            self:Observe((link and link ~= "") and link or name, "boss loot")
        end
    end
end

function A:BackpackSkullCounts()
    local totals, slots = {}, {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local link = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
        local name = self:NameFromLinkOrText(link)
        if Normalize(name):find("dremora plunder skull", 1, true) then
            local stack = GetSlotStackSize(BAG_BACKPACK, slot)
            local key = Normalize(name)
            totals[key] = (totals[key] or 0) + stack
            slots[slot] = key
        end
    end
    return totals, slots
end

function A:OnInventoryUpdate(bag, slot, change)
    -- Bag and reason are already restricted by native event filters.
    local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
    local name = self:NameFromLinkOrText(link)
    local key = Normalize(name)
    if not key:find("dremora plunder skull", 1, true) and not (self.bagSlots and self.bagSlots[slot]) then return end
    -- Net backpack quantities distinguish newly awarded skulls from simply
    -- rearranging a bag. A bank withdrawal must never tick an old skull.
    local current, slots = self:BackpackSkullCounts()
    if self.bagCounts and not self.bankOpen and (change or 0) > 0 then
        if (current[key] or 0) > (self.bagCounts[key] or 0) then
            self:Observe(link, "inventory")
        end
    end
    self.bagCounts = current
    self.bagSlots = slots
end

function A:Debug()
    Chat("v" .. VERSION .. ". Last skull: " .. (self.lastReward or "none observed this session"))
    if not self.englishClient then Chat("Automatic tracking requires the English client; manual checklist only.") end
    Chat("Reset: " .. (self.resetOffset == 36000 and "8:00 pm Brisbane (NA)." or "03:00 UTC (EU)."))
    for _, category in ipairs(CATEGORIES) do
        local entry = self.saved.completed[category.key]
        if entry then Chat(category.label .. ": " .. (entry.source or "earlier version")) end
    end
end

function A:OnLoot(itemLink, quantity, isSelf)
    if not isSelf or (quantity or 0) <= 0 then return end
    self:Observe(itemLink, "loot received")
end

function A:OnQuestComplete(questName)
    -- Quest rewards are not guaranteed to raise EVENT_LOOT_RECEIVED.
    local name = Normalize(questName)
    if name == "plucking the crow" then self:Record("crow", "quest") end
    if name == "the lord of fear" then self:Record("hollowjack", "quest") end
end

local function Label(parent, text, x, y, width, font)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, 28)
    control:SetFont(font or "ZoFontGame")
    control:SetText(text)
    return control
end

local function Backdrop(parent, x, y, width, height, r, g, b)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, height)
    control:SetCenterColor(r, g, b, 0.94)
    control:SetEdgeColor(0.35, 0.31, 0.22, 0.8)
    control:SetEdgeTexture(nil, 1, 1, 1)
    return control
end

function A:SetVisible(visible)
    self.saved.visible = visible
    self.window:SetHidden(not visible)
    if visible then self:Refresh() end
end

function A:CreateWindow()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("GoldenSkullTrackerWindow")
    self.window = window
    window:SetDimensions(690, 510)
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    if self.saved.x and self.saved.y then
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.x, self.saved.y)
    else
        window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    window:SetHandler("OnMoveStop", function(control)
        self.saved.x, self.saved.y = control:GetLeft(), control:GetTop()
    end)
    Backdrop(window, 0, 0, 690, 510, 0.065, 0.065, 0.075)
    Label(window, "Golden Plunder Skulls", 18, 12, 530, "ZoFontWinH2")
    local versionLabel = Label(window, "v" .. VERSION, 568, 18, 68, "ZoFontGameSmall")
    versionLabel:SetColor(0.65, 0.65, 0.65, 1)
    Label(window, self.englishClient and "TODAY - shared by all characters on this account and server"
        or "English client required for automatic tracking - manual checklist only", 18, 48, 650)
    local close = WINDOW_MANAGER:CreateControlFromVirtual(nil, window, "ZO_DefaultButton")
    close:SetAnchor(TOPRIGHT, window, TOPRIGHT, -12, 10)
    close:SetDimensions(38, 30)
    close:SetText("X")
    close:SetHandler("OnClicked", function() self:SetVisible(false) end)
    Backdrop(window, 14, 84, 662, 30, 0.19, 0.16, 0.09)
    Label(window, "BOSS CATEGORY", 24, 86, 318, "ZoFontGameBold")
    Label(window, "DONE", 350, 86, 65, "ZoFontGameBold")
    Label(window, "COLLECTED BY", 432, 86, 230, "ZoFontGameBold")
    self.rows = {}
    for index, category in ipairs(CATEGORIES) do
        local cat = category
        local y = 116 + (index - 1) * 31
        Backdrop(window, 14, y, 662, 30, index % 2 == 0 and 0.11 or 0.085, 0.09, 0.10)
        Label(window, cat.label, 24, y + 2, 318)
        local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, window, "ZO_DefaultButton")
        button:SetAnchor(TOPLEFT, window, TOPLEFT, 350, y)
        button:SetDimensions(62, 29)
        button:SetHandler("OnClicked", function()
            self:EnsureDay()
            if self.saved.completed[cat.key] then
                self.saved.completed[cat.key] = nil
                self:Refresh()
            else
                self:Record(cat.key, "manual")
            end
        end)
        button:SetHandler("OnMouseEnter", function(control)
            InitializeTooltip(InformationTooltip, control, TOPRIGHT, 0, 0, BOTTOMLEFT)
            SetTooltipText(InformationTooltip, cat.tip .. "\nClick to toggle a manual correction. * = manually recorded.")
        end)
        button:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        local character = Label(window, "-", 432, y + 2, 230)
        self.rows[cat.key] = {status=button, character=character}
    end
    self.summary = Label(window, "", 20, 435, 650)
    Label(window, "Click Y/N to correct a row. Drag the title to move. /skulls to toggle.", 20, 466, 650)
    window:SetHidden(not self.saved.visible)
end

function A:Refresh()
    self:EnsureDay()
    if not self.rows then return end
    self.lastDisplayMinute = math.floor(GetTimeStamp() / 60)
    local count = 0
    for _, category in ipairs(CATEGORIES) do
        local completed = self.saved.completed[category.key]
        local row = self.rows[category.key]
        row.status:SetText(completed and "|c65DE88Y|r" or "|cF08080N|r")
        row.character:SetText(completed and (completed.character .. (completed.manual and " *" or "")) or "-")
        if completed then count = count + 1 end
    end
    local seconds = DAY - ((GetTimeStamp() - self.resetOffset) % DAY)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    self.summary:SetText(string.format("%d / 10 today | Reset in %02dh %02dm | %s", count, hours, minutes,
        self.resetOffset == 36000 and "8 pm Brisbane (NA)" or "03:00 UTC (EU)"))
end

function A:OnTimer()
    local changedDay = self:EnsureDay()
    if changedDay or (not self.window:IsHidden()
        and self.lastDisplayMinute ~= math.floor(GetTimeStamp() / 60)) then
        self:Refresh()
    end
end

function A:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("GoldenSkullTrackerSaved", 1, nil,
        {day=-1, completed={}, visible=true}, GetWorldName())
    self.resetOffset = self:GetResetOffset()
    self.englishClient = GetCVar("language.2") == "en"
    self:EnsureDay()
    self:CreateWindow()
    self:Refresh()
    SLASH_COMMANDS["/skulls"] = function(args)
        if Normalize(args) == "debug" then self:Debug() else self:SetVisible(self.window:IsHidden()) end
    end
    SLASH_COMMANDS["/goldenskulls"] = SLASH_COMMANDS["/skulls"]
    -- English text matching is deliberately disabled on other client languages.
    if self.englishClient then
        EVENT_MANAGER:RegisterForEvent(self.name, EVENT_LOOT_RECEIVED,
            function(_, _, itemLink, quantity, _, _, isSelf) self:OnLoot(itemLink, quantity, isSelf) end)
        EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_COMPLETE,
            function(_, questName) self:OnQuestComplete(questName) end)
        EVENT_MANAGER:RegisterForEvent(self.name, EVENT_LOOT_UPDATED, function() self:OnLootUpdated() end)
        EVENT_MANAGER:RegisterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            function(_, bag, slot, _, _, _, change) self:OnInventoryUpdate(bag, slot, change) end)
        EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
        EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
        EVENT_MANAGER:RegisterForEvent(self.name, EVENT_OPEN_BANK, function() self.bankOpen = true end)
        EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CLOSE_BANK, function()
            self.bankOpen = false
            self.bagCounts, self.bagSlots = self:BackpackSkullCounts()
        end)
    end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        self.resetOffset = self:GetResetOffset()
        self.bankOpen = false
        if self.englishClient then
            self.bagCounts, self.bagSlots = self:BackpackSkullCounts()
        end
        self:Refresh()
    end)
    -- A light timer: also resets correctly while the window is closed.
    EVENT_MANAGER:RegisterForUpdate(self.name, 1000, function() self:OnTimer() end)
end

EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A:Initialize()
end)
