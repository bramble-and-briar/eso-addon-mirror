local A = GuildBidLedger

function A:ReportFault(stage, err)
    self.faults = self.faults or {}
    local message = tostring(err)
    if self.faults[stage] ~= message then
        self.faults[stage] = message
        d("|cE8B06BGuild Bid Ledger: " .. stage .. " failed:|r " .. message)
    end
end
function A:Safe(stage, fn)
    local ok, result = pcall(fn)
    if not ok then self:ReportFault(stage, result) end
    return ok, result
end
function A:EnsureUI()
    if self.uiReady then return true end
    if self.uiBuilding then return false end
    -- ESO UI objects can become available after addon initialization; retry later.
    if self.uiFailed and GetTimeStamp() < (self.nextUiRetry or 0) then return false end
    self.uiBuilding = true
    local ok = self:Safe("create panel", function() self:CreateUI() end)
    self.uiBuilding = false
    self.uiReady = ok
    self.uiFailed = not ok
    if not ok then self.nextUiRetry = GetTimeStamp() + 5 end
    if not ok and self.panel then self.panel:SetHidden(true) end
    return ok
end
function A:OpenBid(object, guildId, mode)
    if not guildId then return end
    -- Amount entry and observation remain usable even if supplementary UI fails.
    local kiosk = zo_strformat("<<1>>", GetUnitName("interact"))
    local changed = not self.context or self.context.guildId ~= guildId or self.context.kiosk ~= kiosk
    self.context = { object=object, guildId=guildId, mode=mode, kiosk=kiosk }
    self:Safe("observe bid", function() self:ObserveBid(self.context) end)
    self:Safe("autofill", function() self:TryFill(self.context) end)
    if changed then self:Safe("request history", function() self:RequestHistory(guildId) end) end
    if self:EnsureUI() then
        self:Safe("open panel", function() self:SetContext(object, guildId, mode) end)
    end
end
function A:CloseBid()
    if self.panel then self.panel:SetHidden(true) end
    self.context = nil
end
-- Hook each callback separately. One missing method must never prevent the others.
function A:HookMethod(object, method, callback)
    if not object or type(object[method]) ~= "function" then return false end
    self.hookRegistry = self.hookRegistry or {}
    local key = tostring(object) .. ":" .. method
    if self.hookRegistry[key] then return true end
    local ok, err = pcall(function()
        ZO_PostHook(object, method, function(...)
            local args = {...}
            self:Safe("hook " .. method, function() callback(unpack(args)) end)
        end)
    end)
    if not ok then self:ReportFault("hook " .. method, err); return false end
    self.hookRegistry[key] = true
    return true
end
function A:InstallHooks()
    local keyboard = BID_ON_KIOSK_DIALOG
    if keyboard then
        self:HookMethod(keyboard, "OnGuildSelected", function(object, guildId)
            self:OpenBid(object, guildId, "keyboard")
        end)
        self:HookMethod(keyboard, "OnGuildKioskConsiderBidStart", function(object)
            self:ApplyDefaultGuild(object, "keyboard")
            local id = object.dialog and object.dialog.GetSelectedGuildId and object.dialog:GetSelectedGuildId()
            self:OpenBid(object, id, "keyboard")
        end)
        self:HookMethod(keyboard, "OnGuildKioskConsiderBidStop", function() self:CloseBid() end)
        self.hookedKeyboard = keyboard
    end
    local gamepad = GUILD_KIOSK_BID_WINDOW_GAMEPAD
    if gamepad then
        self:HookMethod(gamepad, "OnShowing", function(object)
            self:ApplyDefaultGuild(object, "gamepad")
        end)
        self:HookMethod(gamepad, "OnGuildKioskConsiderBidStart", function(object)
            self:ApplyDefaultGuild(object, "gamepad")
            self:OpenBid(object, object.guildId, "gamepad")
        end)
        self:HookMethod(gamepad, "OnGuildSelected", function(object, entry)
            self:OpenBid(object, entry and entry.guildId, "gamepad")
        end)
        self:HookMethod(gamepad, "OnHiding", function() self:CloseBid() end)
        self.hookedGamepad = gamepad
    end
end
-- Native bidding callbacks are not guaranteed to fire in every loading order.
-- Detect the visible native dialog directly, including after /reloadui.
function A:DetectBidWindow()
    local keyboard = BID_ON_KIOSK_DIALOG
    if keyboard and keyboard.control and keyboard.control.IsHidden
        and not keyboard.control:IsHidden() then
        local id = keyboard.dialog and keyboard.dialog.GetSelectedGuildId and keyboard.dialog:GetSelectedGuildId()
        if not id and self:EligibleDefaultGuild(self.sv.defaultGuildId) then id = self.sv.defaultGuildId end
        if id then
            local kiosk = GetUnitName("interact") or ""
            if not self.context or self.context.object ~= keyboard or self.context.guildId ~= id
                or self.context.kiosk ~= kiosk or not self.panel or self.panel:IsHidden() then
                self:OpenBid(keyboard, id, "keyboard")
            end
        end
        return
    end
    if self.context and self.context.mode == "keyboard" then self:CloseBid() end
end
function A:Status()
    d("Guild Bid Ledger 1.0 | " .. (self.sv and "settings loaded" or "settings unavailable")
        .. " | keyboard hook: " .. (self.hookedKeyboard and "ready" or "waiting")
        .. " | gamepad hook: " .. (self.hookedGamepad and "ready" or "waiting")
        .. " | panel: " .. (self.uiReady and "ready" or (self.uiFailed and "failed" or "created on opening bids")))
    for stage,err in pairs(self.faults or {}) do d("GBL "..stage..": "..err) end
end
function A:Initialize()
    if self.initialized then return end
    self.initialized = true
    -- Register diagnostics before settings, UI or history can fail.
    SLASH_COMMANDS["/gbl"] = function(command)
        self:Safe("command",function()
            if command=="show" then
                self:ShowPanelTest()
            elseif command=="hide" then
                if self.panel then self.panel:SetHidden(true) end
            elseif command=="retry" then
                if not self.sv then self:Status();return end
                if self.panel then self.panel:SetHidden(true) end
                self.uiReady=false;self.uiFailed=false
                if self.context then self:OpenBid(self.context.object,self.context.guildId,self.context.mode) end
            elseif command=="refresh" and self.context then self:RequestHistory(self.context.guildId,true)
            elseif command=="debug" then self:Status();if self.sv then self:DebugHistory() end
            else self:Status() end
            if self.uiReady then self:RefreshUI() end
        end)
    end
    local ok=self:Safe("settings",function()
        self.sv=ZO_SavedVars:NewAccountWide("GuildBidLedgerSavedVariables",1,GetWorldName(),{amount=10000,history={}})
        self:Migrate()
    end)
    if not ok then return end
    self:Safe("install hooks",function() self:InstallHooks() end)
    self:Safe("observe cycle",function() self:ObserveCycle() end)
    self:Safe("initialize history",function() self:InitializeHistory() end)
    EVENT_MANAGER:RegisterForUpdate(self.name,1000,function()
        self:Safe("detect bid window",function()self:DetectBidWindow()end)
        self:Safe("install hooks",function() self:InstallHooks() end)
        self:Safe("history queue",function() self:PumpRequests() end)
        if self.context then
            local now=GetTimeStamp()
            if not self.nextVisibleScan or now>=self.nextVisibleScan then
                self.nextVisibleScan=now+15
                self:Safe("history scan",function()
                    self:ObserveCycle();self:ObserveBid(self.context);self:Scan(self.context.guildId)
                    if self.libReady and not self.processors[self.context.guildId] then self:StartProcessor(self.context.guildId) end
                end)
                self.dirty=true
            end
        end
        if self.dirty then
            self.dirty=false
            if self.uiReady then self:Safe("refresh panel",function() self:RefreshUI() end) end
        end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name,EVENT_GUILD_SELF_JOINED_GUILD,function(_,guildId)
        self:Safe("joined guild",function() self:Scan(guildId);self:StartProcessor(guildId) end)
    end)
end
function A:EligibleDefaultGuild(guildId)
    if not guildId then return false end
    for i=1,GetNumGuilds() do
        if GetGuildId(i)==guildId then return DoesPlayerHaveGuildPermission(guildId,GUILD_PERMISSION_GUILD_KIOSK_BID) end
    end
    return false
end
function A:ApplyDefaultGuild(object,mode)
    local guildId=self.sv.defaultGuildId
    if not self:EligibleDefaultGuild(guildId) then return end
    if mode=="keyboard" and object.dialog and object.dialog.SelectGuildById then object.dialog:SelectGuildById(guildId)
    elseif mode=="gamepad" and object.dropDown and object.dropDown.entries then
        local entry=object.dropDown.entries[guildId]
        if entry then object.dropDown:SelectItem(entry) end
    end
end
EVENT_MANAGER:RegisterForEvent(A.name,EVENT_ADD_ON_LOADED,function(_,addonName)
    if addonName~=A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name,EVENT_ADD_ON_LOADED)
    A:Safe("startup",function() A:Initialize() end)
end)
