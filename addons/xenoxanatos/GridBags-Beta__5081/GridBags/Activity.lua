GridBagsActivity = {}
local A = GridBagsActivity
local REPORT_CODES = {}
for code in ("RECIPE_GATHER_RESERVED RECIPE_GATHER_CONFIRMED RECIPE_GATHER_INVALID RECIPE_GATHER_STALE FURNITURE_KEEPER CROSS_PROFESSION_MATERIAL DECONSTRUCTION_UNAVAILABLE PROFILE_NOT_ASSIGNED RULE_CREATED RULE_EDITED RULE_DELETED RULE_RESTORED SHARED_CATEGORY_CHANGED PROTECTION_REMOVED PROTECTION_UPDATED PAUSED RESUMED REQUESTED VERIFIED_MOVE RESULT_UNCERTAIN RELOAD_UNCERTAIN BANK_CLOSED_UNCERTAIN TIMEOUT_UNCERTAIN REQUEST_REJECTED REQUEST_CALL_ERROR WAITING_CHARACTER RULE_PAUSED USER_CANCEL RULE_CHANGED SOURCE_PROTECTED TARGET_INELIGIBLE RESERVATION_MISSING NEEDS_REVIEW SOURCE_CHANGED ITEM_MISSING ITEM_LOCKED ITEM_STOLEN CHARACTER_BOUND KEEP_OR_ALLOCATION_LIMIT QUANTITY_CHANGED_OR_FRAGMENTED SOURCE_ALLOCATED PLAN_CHANGED SOURCE_ALREADY_USED KEEP_LIMIT STALE_SNAPSHOT DESTINATION_ALREADY_USED BANK_FRAGMENTED INVENTORY_FRAGMENTED BANK_FULL INVENTORY_FULL BANK_UNAVAILABLE USER_SKIP USER_SKIP_ALL GOLD_BANK_RESERVE GOLD_NOT_DUE GOLD_BALANCES_CHANGED GOLD_DAY_CHANGED GOLD_CAPACITY GOLD_RESULT_UNCERTAIN GOLD_RELOAD_UNCERTAIN GOLD_VALIDATION GOLD_REQUESTED GOLD_REQUEST_REJECTED GOLD_CALL_ERROR GOLD_VERIFIED GOLD_TIMEOUT_UNCERTAIN GOLD_LIMITS GOLD_BANK_CLOSED_UNCERTAIN NATIVE_CURRENCY CONFIG_BACKUP CONFIG_IMPORTED LUA_ERROR CRAFT_DATA_MISSING RECIPE_DATA_MISSING NO_CRAFTABLE_RECIPE MATERIAL_CHECK_UNSUPPORTED SOURCE_IS_CRAFTER MATERIAL_TIER_UNUSABLE KNOWLEDGE_NO_DATA ALREADY_KNOWN RESEARCH_IN_PROGRESS NOT_LEARNABLE DUPLICATE_DELIVERY GOLD_NOT_OBSERVED GOLD_REFILL_DISABLED GOLD_DAILY_ALREADY_DONE GOLD_BELOW_THRESHOLD GOLD_MIN_PROTECTED GOLD_WITHIN_LIMITS LEARNING_RULE_WAITING RULE_NO_ELIGIBLE_BATCH RULE_WAITING"):gmatch("%S+") do REPORT_CODES[code] = true end
for code in ("RECIPIENT_ALREADY_HAS_ITEM AUTO_MOVER_CONFLICT GOLD_POLICY_DISABLED GOLD_POLICY_CHANGED WRONG_CHARACTER GOLD_REVIEW_HOLD ITEM_QUEUE_BUSY"):gmatch("%S+")do REPORT_CODES[code]=true end

function A:SafeCode(code)
    return REPORT_CODES[code] and code or "UNCLASSIFIED"
end

function A:IsPaused()
    return self.owner ~= nil and self.owner.saved.transfersPaused == true
end

function A:SetPaused(value)
    if not self.owner then return end
    local changed = self:IsPaused() ~= (value == true)
    self.owner.saved.transfersPaused = value == true
    if changed then self:Append({ kind = "control", outcome = "control", code = value and "PAUSED" or "RESUMED",
        reason = value and "New planned transfers paused; any in-flight receipt will still be checked." or "Planned transfers resumed; existing limits and review holds still apply." }) end
    if GridBagsRouting.data then GridBagsRouting:Notify() end
    if GridBagsGold.data then GridBagsGold:Notify() end
    self.owner:QueueRefresh()
end

function A:Append(entry)
    if not self.data or (self.previewDepth or 0) > 0 then return end
    self.data.nextEvent = (self.data.nextEvent or 0) + 1
    entry.id, entry.at = self.data.nextEvent, GetTimeStamp()
    entry.clock = GetTimeString and GetTimeString() or nil
    entry.reason = entry.reason or entry.code or "No reason recorded"
    self.data.history[#self.data.history + 1] = entry
    if #self.data.history > 300 then table.remove(self.data.history, 1) end
    if GridBagsToolsUI and GridBagsToolsUI.Update then
        local ok,err=pcall(GridBagsToolsUI.Update,GridBagsToolsUI)
        if not ok and not self.data.uiProblem then
            self.data.uiProblem=true
            self.data.errors[#self.data.errors+1]={at=GetTimeStamp(),text=tostring(err):sub(1,8000)}
            if #self.data.errors>10 then table.remove(self.data.errors,1)end
            d("GridBags: history display could not refresh. Transfer verification continues; a diagnostic frame was saved.")
        end
    end
    return entry
end

function A:Item(op, outcome, reason, code)
    if not self.data or (self.previewDepth or 0) > 0 then return end
    op.activityEvents = op.activityEvents or {}
    local key = outcome .. ":" .. (code or "")
    if op.activityEvents[key] then return end
    op.activityEvents[key] = true
    local R, allocations = GridBagsRouting, {}
    for _, part in ipairs(op.allocations or {}) do
        local p = R:Plan(part.plan)
        allocations[#allocations + 1] = { plan = part.plan, quantity = part.qty, destination = p and p.dest,
            observedAt = p and p.observedAt }
    end
    self:Append({ kind = "item", outcome = outcome, code = code, reason = reason, item = op.name or op.link,
        quantity = op.qty, source = op.source, destination = op.phase == "source" and R.BANK or R.character,
        allocations = allocations, requestedSourceCount = op.before, requestedDestinationCount = op.destBefore,
        observedSourceCount = op.observedSourceCount, observedDestinationCount = op.observedDestinationCount })
end

function A:Plan(p, outcome, reason, code)
    if not self.data or (self.previewDepth or 0) > 0 then return end
    local visit = GridBagsRouting.data.visit or {}
    local visitKey = tostring(visit.id or visit.at or 0)
    if p.activityVisit ~= visitKey then p.activityEvents = {}; p.activityVisit = visitKey end
    local key = outcome .. ":" .. (code or "")
    p.activityEvents = p.activityEvents or {}
    if p.activityEvents[key] then return end
    p.activityEvents[key] = true
    self:Append({ kind = "item", outcome = outcome, reason = reason, code = code, item = p.name or p.link,
        quantity = p.remaining, source = p.source, destination = p.dest, plan = p.id, observedAt = p.observedAt })
end

function A:Gold(op, outcome, reason, code)
    if not self.data or (self.previewDepth or 0) > 0 then return end
    op.activityEvents = op.activityEvents or {}
    local key = outcome .. ":" .. (code or "")
    if op.activityEvents[key] then return end
    op.activityEvents[key] = true
    local deposit = op.direction == "deposit"
    self:Append({ kind = "gold", outcome = outcome, reason = reason, code = code, quantity = op.amount,
        source = deposit and op.character or GridBagsRouting.BANK,
        destination = deposit and GridBagsRouting.BANK or op.character,
        beforeChar = op.beforeChar, beforeBank = op.beforeBank, afterChar = op.afterChar, afterBank = op.afterBank })
end

function A:Rule(rule, reason, code)
    if not self.data or (self.previewDepth or 0) > 0 then return end
    local visit = GridBagsRouting.data.visit or {}
    local key = tostring(visit.id or visit.at or 0)
    if rule.activityVisit == key then return end
    rule.activityVisit = key
    self:Append({kind="rule",outcome="waiting",reason=reason,code=code or "RULE_WAITING",item=rule.name,
        source=rule.source,destination=rule.dest,rule=rule.id})
end

function A:GoldVisit(visit, reason, code)
    if not visit or visit.activityLogged then return end
    visit.activityLogged = true
    self:Append({ kind = "gold", outcome = "skipped", source = visit.character, reason = reason, code = code })
end

function A:Initialize(owner)
    self.owner = owner
    owner.saved.transferTools = owner.saved.transferTools or {}
    local world = GetWorldName()
    owner.saved.transferTools[world] = owner.saved.transferTools[world] or {}
    self.data = owner.saved.transferTools[world]
    self.data.uiProblem = false
    for _, name in ipairs({ "history", "errors", "backups" }) do self.data[name] = self.data[name] or {} end
    if EVENT_LUA_ERROR then
        EVENT_MANAGER:RegisterForEvent("GridBagsActivity", EVENT_LUA_ERROR, function(_, message)
            if self.recordingError or type(message) ~= "string" or not message:find("GridBags", 1, true) then return end
            self.recordingError = true
            -- ESO cannot persist individual strings of 2000 bytes or more.
            local entry={at=GetTimeStamp(),text=message:sub(1,1900),continuation={}}
            for offset=1901,math.min(#message,8000),1900 do
                entry.continuation[#entry.continuation+1]=message:sub(offset,math.min(offset+1899,8000))
            end
            self.data.errors[#self.data.errors + 1] = entry
            if #self.data.errors > 10 then table.remove(self.data.errors, 1) end
            pcall(function() self:Append({kind="error",outcome="failed",code="LUA_ERROR",reason="GridBags Lua error recorded locally; troubleshooting report includes safe error frames"}) end)
            self.recordingError = false
        end)
    end
end
