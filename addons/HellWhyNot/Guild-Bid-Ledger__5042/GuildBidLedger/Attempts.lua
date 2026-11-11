local A = GuildBidLedger
local WEEK, GRACE = 604800, 3600

function A:Migrate()
    -- Keep the original account/world namespace and every raw kiosk observation.
    self.sv.history = self.sv.history or {}
    self.sv.cycles = self.sv.cycles or {}
    self.sv.liveBids = self.sv.liveBids or {}
    self.sv.rentalCosts = self.sv.rentalCosts or {}
    self.sv.redactions = self.sv.redactions or {}
    self.sv.schema = 2
    self.sv.quantity = nil
end

function A:ObserveCycle()
    if not GetGuildKioskCycleTimes then return end
    local _, ending = GetGuildKioskCycleTimes()
    if type(ending) == "number" and ending > 0 then
        self.sv.anchor = ending
        self.sv.cycles[tostring(ending)] = true
    end
end

function A:CycleFor(timestamp, kind)
    local anchor = self.sv.anchor
    if not anchor or not timestamp then return nil, false end
    if kind == "Bid" then
        local best
        for key in pairs(self.sv.cycles) do
            local boundary=tonumber(key)
            if boundary and boundary>=timestamp and boundary-timestamp<=WEEK+GRACE
                and (not best or boundary<best) then best=boundary end
        end
        if best then return best,true end
        return anchor+math.ceil((timestamp-anchor)/WEEK)*WEEK,false
    end
    -- A historical schedule shift can put settlement just before a projected
    -- boundary. Prefer saved actual boundaries, then a nearby projected one.
    local best,distance
    for key in pairs(self.sv.cycles) do
        local boundary=tonumber(key)
        local delta=boundary and timestamp-boundary
        if delta and delta>=0 and delta<=GRACE and (not distance or delta<distance) then best=boundary;distance=delta end
    end
    if best then return best,true end
    local nearest=anchor+math.floor((timestamp-anchor)/WEEK+0.5)*WEEK
    if math.abs(timestamp-nearest)<=GRACE then return nearest,false end
    return anchor+math.floor((timestamp-anchor)/WEEK)*WEEK,false
end

function A:ObserveBid(ctx)
    self:ObserveCycle()
    local ending = self.sv.anchor
    if not ending or not ctx then return end
    local bank, amount = GetKioskGuildInfo(ctx.guildId)
    if not bank then return end
    local cost = GetKioskPurchaseCost()
    if cost and cost > 0 then self.sv.rentalCosts[tostring(ending)] = cost end
    if not amount or amount <= 0 then return end
    local guild = tostring(ctx.guildId)
    self.sv.liveBids[guild] = self.sv.liveBids[guild] or {}
    self.sv.liveBids[guild][tostring(ending) .. ":" .. self:KioskKey(ctx.kiosk)] = {
        ending = ending, kiosk = ctx.kiosk, amount = amount, observed = GetTimeStamp(),
    }
end

function A:BuildAttempts(guildId, kiosk, now)
    now = now or GetTimeStamp()
    local all = self:GetRecords(guildId)
    table.sort(all, function(a,b) return a.time == b.time and a.id < b.id or a.time < b.time end)
    local buckets, batches = {}, {}
    local function bucket(ending, name, fallback)
        -- Qualified history names stay intact; a live unqualified name joins a unique match.
        local nameKey = self:KioskKey(name)
        for _, b in pairs(buckets) do
            if b.ending == ending and (self:KioskMatches(b.kiosk,name) or self:KioskMatches(name,b.kiosk)) then return b end
        end
        local key = tostring(ending or fallback) .. ":" .. nameKey
        local b = { ending=ending, kiosk=name, bids={}, hires={}, refunds={}, evidence={}, first=math.huge }
        buckets[key]=b
        return b
    end
    for _, r in ipairs(all) do
        local ending, observed = self:CycleFor(r.time,r.kind)
        local b = bucket(ending,r.kiosk,r.time)
        b.projected = not observed
        b.first = math.min(b.first,r.time)
        b.evidence[#b.evidence+1]=r
        if r.kind == "Bid" then b.bids[#b.bids+1]=r
        elseif r.kind == "Refund" then
            b.refunds[#b.refunds+1]=r
            if ending and r.time-ending <= GRACE then
                batches[ending]=batches[ending] or {};batches[ending][self:KioskKey(r.kiosk)]=true
            end
        elseif r.kind == "Hired" then b.hires[#b.hires+1]=r end
    end
    for _, snap in pairs(self.sv.liveBids[tostring(guildId)] or {}) do
        local b = bucket(snap.ending,snap.kiosk,snap.observed)
        b.snapshot=snap;b.first=math.min(b.first,snap.observed)
        b.projected=not self.sv.cycles[tostring(snap.ending)]
    end
    local attempts={}
    for _, b in pairs(buckets) do
        local e=b.ending
        b.date=e or b.first
        b.outcome="Unknown";b.reason="The available records do not establish a completed auction outcome."
        b.amount=nil;b.amountBasis="Observed amount; final amount is unavailable."
        local lastBid=b.bids[#b.bids]
        if b.snapshot then b.amount=b.snapshot.amount;b.amountBasis="Amount read from ESO's current bid state, at the time shown." end
        if lastBid and not b.amount then b.amount=lastBid.amount;b.amountBasis="Amount reported by a bid history event; increases may be missing. This is not a verified final bid." end
        local refund=b.refunds[#b.refunds]
        local hire=b.hires[#b.hires]
        local closeRefund=refund and e and refund.time-e <= GRACE and (refund.time>=e or b.projected)
        local closeHire=hire and e and hire.time-e <= GRACE and (hire.time>=e or b.projected)
        local cost=e and self.sv.rentalCosts[tostring(e)]
        if refund then
            b.amount=refund.amount;b.amountBasis="Refunded total recorded by ESO; original submission may be missing."
            if closeRefund and not hire then
                b.outcome="Unsuccessful"
                b.reason="This attempt did not result in hiring this trader. A refund alone does not prove that another guild outbid it."
                b.final=true
            else b.reason="Refund timing or conflicting hire evidence prevents a reliable auction classification." end
        elseif hire then
            b.amount=hire.amount;b.amountBasis="Hire cost recorded by ESO."
            local bidMatches=(lastBid and lastBid.amount==hire.amount) or (b.snapshot and b.snapshot.amount==hire.amount)
            local otherRefund=false
            for name in pairs(batches[e] or {}) do if name~=self:KioskKey(b.kiosk) then otherRefund=true end end
            -- No auction-win flag exists. Require matching bid + rollover timing + corroboration.
            -- A contemporaneous flat-fee match stays a rental/unknown, even in a batch.
            if closeHire and bidMatches and not (cost and cost==hire.amount)
                and ((cost and hire.amount>cost and not b.projected) or otherRefund) then
                b.outcome="Won";b.final=true
                b.reason="Matching bid and hire amount at auction rollover, corroborated by another trader's settlement or a contemporaneous rental fee. Classified from associated events, not an explicit win flag."
                b.competitiveEligible=not b.projected and cost and hire.amount>cost or false
            else
                b.rental=not closeHire or (cost and cost==hire.amount) or false
                b.reason=b.rental and "Hire outside the auction settlement window, or matching the observed flat rental fee. Kept separate from competitive results."
                    or "Hire recorded, but the available bid/settlement evidence cannot reliably distinguish an auction award from a direct rental."
            end
        elseif e and now < e then
            b.outcome="Pending";b.reason="Bidding has not closed. The amount is the latest observed value, not a settled final bid."
        elseif e and now < e+GRACE then
            b.outcome="Pending";b.reason="Bidding closed; waiting for settlement evidence."
        end
        -- ESO returns unsuccessful (including backup) bids to the guild bank.
        -- An observed bid without a refund after settlement is therefore a
        -- plausible award, even if no explicit KIOSK_PURCHASED event was retained.
        -- This is *inferred* from an absence and cannot prove complete history.
        -- Never promote a snapshot during an open/unsettled auction or a known
        -- direct rental. A missing or mismatched hire alone is not a loss.
        local placed = (#b.bids > 0 or b.snapshot ~= nil)
        local settled = e and now >= e + GRACE
        local directRental = b.rental or (hire and cost and hire.amount == cost)
        if b.outcome == "Unknown" and placed and settled and not refund
            and not directRental then
            b.outcome = "Won"
            b.inferred = true
            b.final = true
            b.competitiveEligible = false
            b.reason = "Inferred win: a bid was recorded for this trader, the auction has settled, and no refund for this trader appears in retained guild history. ESO refunds losing and unused backup bids. This is not independently confirmed: an absent or unloaded refund, an incorrect historical cycle, or incomplete history could change this result."
        end
        if not e then b.outcome="Unknown";b.reason="Auction timing is unavailable. Records are not assigned an invented calendar week." end
        for _, marker in pairs(self.sv.redactions[tostring(guildId)] or {}) do
            local redactedEnd = marker.time and self:CycleFor(marker.time,"Refund")
            if redactedEnd == e then
                b.competitiveEligible=false
                if b.inferred then
                    b.outcome="Unknown"; b.final=false; b.inferred=false
                    b.reason="A bid is recorded, but redacted history in this auction cycle prevents treating the absence of a refund as a win."
                end
                b.reason=b.reason.." Redacted history exists around this cycle; competitive bounds are withheld."
                b.redacted=true
            end
        end
        if b.projected then b.reason=b.reason.." This week is projected from ESO's current seven-day auction cycle; older schedule changes cannot be ruled out." end
        if #b.bids>1 then b.reason=b.reason.." Multiple bid records are consolidated; they are not summed because the API does not document increase accounting." end
        b.reason=b.reason.." "..b.amountBasis
        attempts[#attempts+1]=b
    end
    -- A larger refunded bid than a known award could not be a lower-priority backup.
    for _, b in ipairs(attempts) do
        if b.outcome=="Unsuccessful" then
            for _, win in ipairs(attempts) do
                if win.ending==b.ending and win.outcome=="Won" then
                    if b.amount>win.amount and win.competitiveEligible and not b.projected and not b.redacted then
                        b.outbid=true;b.reason=b.reason.." A smaller bid won elsewhere in this same observed cycle, providing evidence this larger bid was outbid. Ties remain possible."
                    else b.reason=b.reason.." The guild won another trader; this may be a refunded backup." end
                end
            end
        end
    end
    local result={}
    for _, b in ipairs(attempts) do if not kiosk or self:KioskMatches(b.kiosk,kiosk) then result[#result+1]=b end end
    table.sort(result,function(a,b)return a.date>b.date end)
    return result
end

function A:AttemptSummary(attempts, now)
    local s={wins=0,inferredWins=0,losses=0,winSum=0,lossSum=0,bounds={},samples=0}
    now=now or GetTimeStamp()
    for _, b in ipairs(attempts) do
        if not s.latest and (b.outcome=="Won" or b.outcome=="Unsuccessful") then s.latest=b end
        if b.outcome=="Won" and b.final then
            s.lastWin=s.lastWin or b;s.wins=s.wins+1;s.winSum=s.winSum+b.amount
            if b.inferred then s.inferredWins=s.inferredWins+1 end
            s.minWin=math.min(s.minWin or b.amount,b.amount);s.maxWin=math.max(s.maxWin or b.amount,b.amount)
        elseif b.outcome=="Unsuccessful" and b.final then s.losses=s.losses+1;s.lossSum=s.lossSum+b.amount end
        if b.final and b.date>=now-56*86400 and (b.competitiveEligible or b.outbid) then
            s.samples=s.samples+1
            local side=b.outbid and "floor" or "ceiling"
            s[side]=s[side] or b
            s.bounds[#s.bounds+1]={side=side,amount=b.amount,date=b.date}
            s.oldest=math.min(s.oldest or b.date,b.date);s.newest=math.max(s.newest or b.date,b.date)
        end
    end
    s.winAverage=s.wins>0 and s.winSum/s.wins or nil
    s.lossAverage=s.losses>0 and s.lossSum/s.losses or nil
    return s
end
