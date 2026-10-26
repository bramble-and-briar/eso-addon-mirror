ALTHarvestItems = ALTHarvestItems or {}
ALTHarvestItems.name, ALTHarvestItems.version, ALTHarvestItems.offset = "ALTHI", "0.9.4", 0
local A = ALTHarvestItems
A.title = "ALTHI – Advanced Logging & Tracking of Harvested Items"
A.authors = "Althi & Roman (@namorstradam & @bakaroobanzai)"
local function L(key) return A:T(key) end
function A.ValidId(value)
    local id = tonumber(value)
    if id and id > 0 and id < math.huge and id == math.floor(id) then return id end
end
function A.Link(id)
    return "|H1:item:" .. id .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
end
function A.Now() return GetGameTimeMilliseconds() / 1000 end
function A.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = A.Copy(item) end
    return copy
end
function A:Say(text) d(self:GoldText("ALTHI") .. ": " .. text) end
function A.Integer(value)
    local text = string.format("%.0f", value or 0)
    local separator = (A.locale == "de" or A.locale == "es") and "."
        or (A.locale == "fr" or A.locale == "ru") and " " or ","
    local formatted = text:reverse():gsub("(%d%d%d)", "%1" .. separator):reverse()
    if formatted:sub(1, 1) == separator then formatted = formatted:sub(2) end
    return formatted
end
local moneyIcon = GetCurrencyKeyboardIcon and CURT_MONEY and GetCurrencyKeyboardIcon(CURT_MONEY)
A.coin = "|t16:16:" .. (moneyIcon or "EsoUI/Art/currency/currency_gold.dds") .. "|t"
function A.Gold(value) return A.Integer(value) .. " " .. A.coin end
function A.UnitGold(value)
    if value == math.floor(value) then return A.Gold(value) end
    local decimal = (A.locale == "de" or A.locale == "fr" or A.locale == "es" or A.locale == "ru") and "," or "."
    return (string.format("%.2f", value):gsub("%.", decimal)) .. " " .. A.coin
end
function A.Time(value)
    value = math.floor(value or 0)
    return string.format("%02d:%02d:%02d", math.floor(value / 3600), math.floor(value / 60) % 60, value % 60)
end
function A:QueueRefresh()
    if self.refreshQueued then return end
    self.refreshQueued = true
    EVENT_MANAGER:RegisterForUpdate("ALTHIRefresh", 100, function()
        EVENT_MANAGER:UnregisterForUpdate("ALTHIRefresh")
        self.refreshQueued = false
        self:Refresh()
        if self.settingsWindow and not self.settingsWindow:IsHidden() and (self.settingsDirty or self.settingsRevision ~= self.catalogRevision) then
            self:RefreshSettings()
        end
    end)
end
function A:Migrate()
    if self.db.schema ~= 3 then
        if next(self.db.counts) and not self.db.legacyCounts then
            self.db.legacyCounts = self.Copy(self.db.counts)
        end
        -- Pre-0.3 counts have neither reliable provenance nor active-time data.
        self.db.session = { counts = {}, elapsed = 0, state = "stopped" }
        self.db.schema = 3
    end
    if self.db.session.state == "running" then self.db.session.state = "paused" end
    if not self.db.ui.layoutVersion then
        self.db.width = self.db.ui.showStock and 900 or 620
        self.db.ui.layoutVersion = 4
    end
    self.runningAt = nil
end
function A:Command(text)
    local command, rest = text:match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command)
    local id = self.ValidId(rest)
    if command == "" or command == "show" then self:ToggleWindow(true)
    elseif command == "home" then
        self.window:ClearAnchors(); self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 60, 100)
        self.db.x, self.db.y = 60, 100; self:ToggleWindow(true)
    elseif command == "settings" then self:OpenMainSettings()
    elseif command == "version" then
        self:Say(self.version.." · ESO API "..GetAPIVersion().." · "..self.locale.." / "..self:ClientLanguage())
    elseif command == "catalog" then self:OpenSettings()
    elseif command == "debug" then
        self.db.debug = not self.db.debug; self:Say(L("DIAGNOSTICS") .. (self.db.debug and L("ON") or L("OFF")))
    elseif command == "testfund" then self:NotifyRare(self.Link(45854),1,true)
    elseif command == "id" and id then
        self:Observe(self.Link(id))
        local item = self.db.catalog[id]
        self:Say(item and string.format("%s · ID %d · %s", item.name, id,
            self:IsEnabled(id) and L("ENABLED") or L("DISABLED_OUTSIDE_RESOURCE_SCOPE")) or L("ID_COULD_NOT_BE_RESOLVED_AS_A_RESOURCE"))
    elseif command == "reset" then ZO_Dialogs_ShowDialog("ALTHI_RESET")
    else self:Say("/althi · show · home · settings · catalog · version · debug · testfund · id <ID> · reset") end
end
function A:Initialize()
    self.db = ZO_SavedVars:NewAccountWide("ALTHISavedVariables", 1, nil, {
        counts = {}, whitelist = {}, catalog = {}, categoryEnabled = {}, manualPrices = {}, diagnostics = {},
        session = { counts = {}, elapsed = 0, state = "stopped" },
        x = 60, y = 100, width = 1120, height = 650, hidden = false, debug = false,
        options = { guildTrader = false, hideInMenus = true, autoStart = true, autoResume = true, useAGS = true, useTTC = true, useATT = true, useMM = true },
        ui = { showStock = true, backgroundAlpha = 0.94, frameAlpha = 1, sortKey = "name", sortDescending = false,
            columnWidths = {}, expanded = {}, sourceFilter = "all" },
        sectionEnabled = {}, subgroupEnabled = {},
    }, GetWorldName())
    self:InitializeLanguage()
    self:Migrate()
    self.stock, self.stockSlots, self.priceCache = {}, {}, {}
    self:BuildMaterialTypes()
    self:HydrateCatalog()
    ZO_Dialogs_RegisterCustomDialog("ALTHI_RESET", {
        title = { text = L("ALTHI_RESET_SESSION") },
        mainText = { text = L("RESET_THIS_SESSION_AND_ITS_ACTIVE_TIME_MATERIAL_FILTER_LIST_AND_CUSTOM") },
        buttons = {
            { text = L("RESET"), callback = function() self:ResetSession() end },
            { text = L("CANCEL") },
        },
    })
    self:CreateWindow()
    self:RegisterLAM()
    if TakeMailAttachedItems and ZO_PreHook then
        ZO_PreHook("TakeMailAttachedItems", function(mailId) self:SnapshotMail(mailId); return false end)
    end
    SLASH_COMMANDS["/althi"] = function(text) self:Command(text) end
    local function Event(event, callback)
        if event then EVENT_MANAGER:RegisterForEvent(self.name, event, callback) end
    end
    Event(EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, function(_, mailId) self:MailReceived(mailId) end)
    Event(EVENT_LOOT_RECEIVED, function(...) self:Loot(...) end)
    Event(EVENT_LOOT_UPDATED, function() self:LootOpened() end)
    Event(EVENT_LOOT_CLOSED, function() self:LootClosed() end)
    Event(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(...) self:StockSlotChanged(...) end)
    EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_VIRTUAL,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    Event(EVENT_PLAYER_ACTIVATED, function()
        if not self.db.languageChosen and not self.languageWindow then self:OpenLanguagePicker(true) end
        if not self.stockReady then self:ScanStock() end
        self:RefreshPrices()
        if not self.catalogStarted then self.catalogStarted = true; self:LoadCatalog() end
        EVENT_MANAGER:RegisterForUpdate("ALTHIInteraction", 100, function() self:PollInteraction() end)
    end)
    Event(EVENT_PLAYER_DEACTIVATED, function()
        self:Pause(); self:ClearHarvest()
        self:ClearNotices()
        EVENT_MANAGER:UnregisterForUpdate("ALTHIInteraction")
    end)
    for _, eventName in ipairs({ "EVENT_MAIL_OPEN_MAILBOX",
        "EVENT_OPEN_BANK", "EVENT_OPEN_GUILD_BANK", "EVENT_OPEN_STORE", "EVENT_OPEN_TRADING_HOUSE",
        "EVENT_TRADE_INVITE_ACCEPTED", "EVENT_TRADE_SUCCEEDED", "EVENT_CRAFTING_STATION_INTERACT", "EVENT_CRAFT_STARTED" }) do
        Event(_G[eventName], function() self:BlockTransfer() end)
    end
    Event(EVENT_CLOSE_TRADING_HOUSE, function() self:RefreshPrices() end)
    if FISHING_MANAGER and type(FISHING_MANAGER.StartInteraction) == "function" and ZO_PreHook then
        ZO_PreHook(FISHING_MANAGER, "StartInteraction", function()
            self:MarkWorldNode()
            return false -- let ESO execute the original interaction unchanged
        end)
        self.worldNodeHook = true
    end
    EVENT_MANAGER:RegisterForUpdate("ALTHITime", 1000, function()
        self:AccrueTime()
        if not self.window:IsHidden() then self:Refresh() end
        if self.settingsWindow and not self.settingsWindow:IsHidden() and self.Now() - (self.filterPricesAt or 0) >= 60 then
            self:RefreshSettings()
        end
    end)
    self:Say(L("RESOURCES_READY_YOUR_FIRST_VALID_HARVEST_STARTS_THE_SESSION_AUTOMATICA"))
    if self.db.legacyCounts then self:Say(L("OLD_0_2_X_COUNTERS_ARE_PRESERVED_SEPARATELY_FROM_VERIFIED_SESSION_HARV")) end
end
EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A:Initialize()
end)
