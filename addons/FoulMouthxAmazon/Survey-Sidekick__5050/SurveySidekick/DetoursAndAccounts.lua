-- Treasure Detour and Petty Accountant. Draft integration; runtime tests pending.
local S=SurveySidekick
local math=math
local T=S.Text
local pairs, ipairs, tonumber, type = pairs, ipairs, tonumber, type
local sort, format, concat = table.sort, string.format, table.concat
local function nonnegative(value)
    value=tonumber(value)
    if not value or value~=value or value==math.huge or value<0 then return 0 end
    return value
end

function S.DetourEntries()
    local survey=S.selected and S.inventory and S.inventory[S.selected]
    if not survey then return {}, "Select a survey to see its treasure detours." end
    local location=S.locations and S.locations[survey.id]
    if not location then return {}, "Install/update LibTreasure for survey and treasure locations." end
    local entries={}
    for id,item in pairs(S.treasureInventory or {})do
        local treasure=S.treasureLocations and S.treasureLocations[id]
        if not item.unidentified and treasure and treasure.mapId==location.mapId and (item.count or 0)>0 then
            entries[#entries+1]=item
        end
    end
    sort(entries,function(a,b)return a.name<b.name end)
    return entries,nil,location.zone
end

function S.PinTreasure(id)
    -- Recheck the backpack after bank transfers or consuming a map.
    S.Scan()
    local item=S.treasureInventory and S.treasureInventory[id]
    local location=S.treasureLocations and S.treasureLocations[id]
    if not item or item.unidentified or item.count<1 or not location then
        S.Say("That treasure map is no longer in your backpack.")
        return
    end
    S.ShowMap(location)
end

function S.CompareRuns(a,b)
    if not a or not b then return nil,"Finish two runs before comparing them." end
    if a==b then return nil,"Choose two different runs." end
    local result={
        a={total=nonnegative(a.total),seconds=nonnegative(a.seconds),value=0,unpriced=0},
        b={total=nonnegative(b.total),seconds=nonnegative(b.seconds),value=0,unpriced=0},
        materials={}
    }
    -- One unit price per item, shared by both runs; unavailable prices are not zero prices.
    local ids={}
    for id in pairs(a.materials or {})do ids[id]=true end
    for id in pairs(b.materials or {})do ids[id]=true end
    for id in pairs(ids)do
        local left=(a.materials or {})[id]
        local right=(b.materials or {})[id]
        local item=right or left
        local quantityA=nonnegative(left and left.count)
        local quantityB=nonnegative(right and right.count)
        local price=S.UnitPrice(id,item.link or S.Link(id))
        if type(price)~="number" or price~=price or price<=0 or price==math.huge then price=nil end
        if price then
            result.a.value=result.a.value+quantityA*price
            result.b.value=result.b.value+quantityB*price
        else
            result.a.unpriced=result.a.unpriced+quantityA
            result.b.unpriced=result.b.unpriced+quantityB
        end
        result.materials[#result.materials+1]={
            id=id,name=S.MaterialName(item),a=quantityA,b=quantityB,
            delta=quantityB-quantityA,unitPrice=price
        }
    end
    sort(result.materials,function(left,right)return left.name<right.name end)
    for _,run in ipairs({result.a,result.b})do
        if run.seconds>0 then
            run.materialsPerHour=run.total*3600/run.seconds
            run.valuePerHour=run.value*3600/run.seconds
        end
    end
    return result
end

-- Rotate within the relevant category. Disabled commentary does not advance it.
-- These cursors are session-only; saved histories and prices are never changed.
local quips={
    noTime={
        "No active time recorded. The accountant refuses to divide by zero.",
        "You gathered outside the boundaries of time. Payroll is confused.",
        "No timer, no hourly rate. I am petty, not psychic.",
        "Time is money. Apparently you have misplaced both the paperwork and the clock.",
    },
    empty={
        "An empty bag. A full sightseeing itinerary.",
        "Zero materials. I have filed this under 'a lovely walk.'",
        "The nodes have retained all their assets.",
        "You brought back memories. The crafting station does not accept those.",
    },
    wandering={
        "Excellent haul. Financially questionable wandering.",
        "More materials, slower pace. Did every butterfly need a personal interview?",
        "The bag got fuller. So did the scenic route.",
        "A larger haul, with a generous investment in looking at rocks.",
    },
    faster={
        "More materials per hour. Someone finally stopped sightseeing.",
        "Your gathering rate improved. I will try to sound less surprised.",
        "The nodes barely had time to update their wills.",
        "Excellent pace. I have reduced your wandering allowance.",
    },
    slower={
        "Fewer materials per hour. Were the flowers negotiating?",
        "Your gathering rate dipped. I am billing the distractions separately.",
        "The scenic route has submitted another expense claim.",
        "A slower pace. The nodes appreciate your commitment to work-life balance.",
    },
    unpriced={
        "Some materials have no price. Your optimism is not an accepted valuation method.",
        "Missing prices. I cannot appraise vibes, even excellent ones.",
        "Part of this haul is unpriced. I have marked it 'potentially shiny.'",
        "The bag has assets. The ledger has questions.",
    },
    value={
        "Estimated value per hour is up. Please do not spend the estimate twice.",
        "A shinier estimate per hour. Actual buyers remain annoyingly necessary.",
        "The estimated hourly value improved. The gold is still theoretical.",
        "A better hourly estimate. I have approved one smug nod.",
    },
    steady={
        "The numbers are in. Your crafting bag would like a word.",
        "Your gathering is consistent. The accountant reluctantly approves.",
        "Another report. Another suspiciously heavy bag.",
        "I counted everything. Including the time you called this 'just one more node.'",
    },
}
local quipCursor={}
function S.AccountantQuip(result)
    if S.character.accountantCommentary~=true then return end
    local left,right=result.a,result.b
    local category="steady"
    if not left.materialsPerHour or not right.materialsPerHour then category="noTime"
    elseif right.total==0 then category="empty"
    elseif right.total>left.total and right.materialsPerHour<left.materialsPerHour then category="wandering"
    elseif right.materialsPerHour>left.materialsPerHour*1.1 then category="faster"
    elseif right.materialsPerHour<left.materialsPerHour*.9 then category="slower"
    elseif left.unpriced>0 or right.unpriced>0 then category="unpriced"
    elseif right.valuePerHour>left.valuePerHour*1.1 then category="value" end
    local pool=quips[category]
    local index=(quipCursor[category] or 0)%#pool+1
    quipCursor[category]=index
    return T(pool[index])
end

function S.AccountantText(a,b)
    local result,reason=S.CompareRuns(a,b)
    if not result then return T(reason)end
    local left,right=result.a,result.b
    local function rate(value)
        return value and format("%.1f",value) or T("Unavailable (no active time)")
    end
    local rows={
        T("PETTY ACCOUNTANT"),
        T("Comparison: B minus A."),
        T("Materials: A %d | B %d | Change %+d",left.total,right.total,right.total-left.total),
        T("Active time: A %s | B %s",S.Time(left.seconds),S.Time(right.seconds)),
        T("Materials/hour: A %s | B %s",rate(left.materialsPerHour),rate(right.materialsPerHour)),
        T("Estimated value: A %.0fg | B %.0fg | Change %+.0fg",left.value,right.value,right.value-left.value),
        T("Estimated gold/hour: A %s | B %s",rate(left.valuePerHour),rate(right.valuePerHour)),
        T("Unpriced quantities: A %d | B %d (excluded from values)",left.unpriced,right.unpriced),
        T("Both runs use the same current unit prices. Estimates are not actual gold earned."),
        "",T("MATERIAL BREAKDOWN")
    }
    for _,item in ipairs(result.materials)do
        rows[#rows+1]=T("%s | A %d | B %d | Change %+d",item.name,item.a,item.b,item.delta)
            ..(item.unitPrice and "" or T(" | Unpriced"))
    end
    local comment=S.AccountantQuip(result)
    if comment then
        rows[#rows+1]=""
        rows[#rows+1]=comment
    end
    return concat(rows,"\n")
end
