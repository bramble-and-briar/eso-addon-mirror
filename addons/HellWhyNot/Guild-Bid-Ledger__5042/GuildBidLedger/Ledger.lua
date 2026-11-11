GuildBidLedger = { name = "GuildBidLedger", page = 1 }
local A = GuildBidLedger

function A:Kind(eventType)
    if eventType == GUILD_HISTORY_BANKED_CURRENCY_EVENT_KIOSK_BID then return "Bid" end
    if eventType == GUILD_HISTORY_BANKED_CURRENCY_EVENT_KIOSK_BID_REFUND then return "Refund" end
    if eventType == GUILD_HISTORY_BANKED_CURRENCY_EVENT_KIOSK_PURCHASED then return "Hired" end
end

function A:Store(guildId, info)
    if not info.eventId then return end
    local key = tostring(guildId)
    self.sv.history[key] = self.sv.history[key] or {}
    local records = self.sv.history[key]
    local id = tostring(info.eventId)
    -- Redaction can replace previously visible data; never retain its amount.
    if info.isRedacted then
        records[id] = nil
        self.sv.redactions = self.sv.redactions or {}
        self.sv.redactions[key] = self.sv.redactions[key] or {}
        self.sv.redactions[key][id] = { time=info.timestampS }
        self.dirty = true; return
    end
    if self.sv.redactions and self.sv.redactions[key] then self.sv.redactions[key][id]=nil end
    local kind = self:Kind(info.eventType)
    if not kind or info.currencyType ~= CURT_MONEY or type(info.amount) ~= "number" then return end
    records[id] = { id = info.eventId, time = info.timestampS, kind = kind,
        amount = info.amount, kiosk = info.kioskName or "", actor = info.displayName or "" }
    self.dirty = true
end

function A:KioskKey(name)
    name = tostring(name or "")
    name = name:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    if zo_strformat then name = zo_strformat("<<1>>", name) end
    name = name:gsub("%^.*$", ""):gsub("^[%s%-]+", ""):gsub("[%s%-]+$", ""):gsub("%s+", " ")
    return zo_strlower and zo_strlower(name) or string.lower(name)
end

-- Guild history can store "Trader in Location" while the interaction supplies
-- only "Trader". Match the complete normalized name plus the location delimiter.
-- Keep the original strings and event ids in saved history for display/deduplication.
function A:KioskMatches(historyName, interactionName)
    local historyKey = self:KioskKey(historyName)
    local interactionKey = self:KioskKey(interactionName)
    if interactionKey == "" then return false end
    if historyKey == interactionKey then return true end
    local prefix = interactionKey .. " in "
    return #historyKey > #prefix and historyKey:sub(1, #prefix) == prefix
end

function A:GetRecords(guildId, kiosk)
    local result = {}
    for _, record in pairs(self.sv.history[tostring(guildId)] or {}) do
        if not kiosk or self:KioskMatches(record.kiosk, kiosk) then result[#result + 1] = record end
    end
    table.sort(result, function(a, b)
        if a.time == b.time then return a.id > b.id end
        return a.time > b.time
    end)
    return result
end

function A:Statistics(records)
    local s = { bids = 0, bidSum = 0, hires = 0, hireSum = 0, refunds = 0 }
    for _, r in ipairs(records) do
        if r.kind == "Bid" then s.bids = s.bids + 1; s.bidSum = s.bidSum + r.amount
        elseif r.kind == "Hired" then s.hires = s.hires + 1; s.hireSum = s.hireSum + r.amount
        elseif r.kind == "Refund" then s.refunds = s.refunds + 1 end
    end
    s.bidAverage = s.bids > 0 and s.bidSum / s.bids or nil
    s.hireAverage = s.hires > 0 and s.hireSum / s.hires or nil
    return s
end

function A:TryFill(ctx, previousAmount)
    if not ctx or not ctx.guildId or ctx.kiosk == "" then return end
    if not DoesPlayerHaveGuildPermission(ctx.guildId, GUILD_PERMISSION_GUILD_KIOSK_BID)
        or not DoesGuildHavePrivilege(ctx.guildId, GUILD_PRIVILEGE_TRADING_HOUSE) then return end
    local bank, existing, count = GetKioskGuildInfo(ctx.guildId)
    if not bank or not existing or not count then return end
    if existing == 0 and count >= GetMaxKioskBidsPerGuild() then return end
    local minimum = existing > 0 and existing + 1 or GetKioskPurchaseCost()
    local amount = self.sv.amount
    if amount < minimum or amount > bank + existing then
        self.autofillStatus = "Saved amount is outside this trader’s valid bid limits."
        return
    end
    if ctx.mode == "keyboard" then
        if ctx.object.bidControls:IsHidden() or ctx.object.control:IsHidden() then return end
        -- Never overwrite an amount the user has already edited.
        local current = ZO_DefaultCurrencyInputField_GetCurrency(ctx.object.newBidInput)
        if current ~= minimum and current ~= previousAmount then return end
        ZO_DefaultCurrencyInputField_SetCurrencyAmount(ctx.object.newBidInput, amount)
    else
        if not GUILD_KIOSK_BID_GAMEPAD_SCENE or not GUILD_KIOSK_BID_GAMEPAD_SCENE:IsShowing()
            or ctx.object.hasError then return end
        if ctx.object.bidAmount ~= minimum and ctx.object.bidAmount ~= previousAmount then return end
        ctx.object:SetBidAmount(amount)
        KEYBIND_STRIP:UpdateKeybindButtonGroup(ctx.object.keybindStripDescriptor)
    end
    self.autofillStatus = "Amount filled. Review it and submit with ESO’s Bid button."
end
