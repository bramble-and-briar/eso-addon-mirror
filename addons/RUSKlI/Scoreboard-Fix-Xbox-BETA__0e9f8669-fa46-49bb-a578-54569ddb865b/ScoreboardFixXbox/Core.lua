ScoreboardFixXboxCore = {}
local C = ScoreboardFixXboxCore
function C.Number(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return string.format('%.2fm', n / 1000000) end
    if n >= 1000 then return tostring(math.floor(n / 1000)) .. 'k' end
    return tostring(n)
end
function C.Ratio(k, d) return k / math.max(d, 1) end
function C.RatioText(k, d) return string.format('%.1f', C.Ratio(k,d)) end
-- Capacity is configuration-driven, never the current number of occupants.
function C.Layout(teamCount, capacity, rowHeight, headerHeight, gap, padding)
    return headerHeight + teamCount * (capacity * rowHeight + gap) + padding
end
function C.Key(p) return p.displayName .. '\031' .. p.characterName end
function C.Time(ms)
    local s = math.max(0, math.ceil((ms or 0) / 1000))
    return string.format('%d:%02d', math.floor(s / 60), s % 60)
end

-- Build a fresh total so repeated scoreboard updates never add a round twice.
-- Player identity, rather than row position, survives native reordering and replacements.
function C.Total(match)
    local last=match.rounds[match.currentRound]
    if not last then return nil end
    local total={teams={},gameType=last.gameType,title=last.title,
        objectiveTitle=last.objectiveTitle,showLives=last.showLives,isTotal=true}
    local fields={'kills','deaths','assists','damage','healing','medals','objective','lives'}
    local lookup={}
    for _,team in ipairs(match.teamIds) do
        total.teams[team]={players={},score=0,won=false};lookup[team]={}
    end
    for round=1,match.currentRound do
        local snapshot=match.rounds[round]
        if snapshot then
            for _,team in ipairs(match.teamIds) do
                local source=snapshot.teams[team]
                local target=total.teams[team]
                if source then
                    if source.won then target.score=target.score+1 end
                    for _,p in ipairs(source.players) do
                        local key=C.Key(p)
                        local entry=lookup[team][key]
                        if not entry then
                            entry={displayName=p.displayName,characterName=p.characterName,
                                team=team,classId=p.classId,isLocalPlayer=p.isLocalPlayer}
                            for _,field in ipairs(fields) do entry[field]=0 end
                            lookup[team][key]=entry;table.insert(target.players,entry)
                        end
                        entry.entryIndex=p.entryIndex;entry.roundIndex=p.roundIndex
                        for _,field in ipairs(fields) do entry[field]=entry[field]+(p[field] or 0) end

                    end
                end
            end
        end
    end
    return total
end
