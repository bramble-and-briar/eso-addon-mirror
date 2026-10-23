-- Test-only observation of final engine results, independent of shipping chat/report features.
return function()
    local engine = LiveBuffUptimeEngine
    local calculate = engine.Calculate
    local records, seen = {}, setmetatable({}, { __mode = "k" })
    engine.Calculate = function(fight, tracker, playerId, targetId, report)
        local result = calculate(fight, tracker, playerId, targetId, report)
        if fight and not fight.running and result.starts and result.ends then
            seen[fight] = seen[fight] or {}
            if not seen[fight][tracker] then
                seen[fight][tracker] = true
                local record = calculate(fight, tracker, playerId, targetId, true)
                record.fightStarts, record.fightEnds = record.starts, record.ends
                record.combatDuration = record.ends - record.starts
                if #records >= 12 then table.remove(records, 1) end
                records[#records + 1] = record
            end
        end
        return result
    end
    return records
end
