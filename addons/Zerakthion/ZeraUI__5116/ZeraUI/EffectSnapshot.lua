-- A read-only, tick-scoped view of the native player/reticle effect lists.
-- All consumers retain their own filtering, clocks and gameplay state.
ZeraUIEffectSnapshot={}
local MAX_CACHED_ROWS=256

local function newUnit()
    local unit={rows={}}
    local function count(tag)
        if unit.count==nil then
            unit.count=GetNumBuffs(tag) or 0
            -- Keep the bounded high-water pool across target loss and list
            -- size changes. The new generation invalidates every old row;
            -- a zero-count target never exposes a retained row to consumers.
            -- Avoid recreating up to 256 tables on the next populated target.
        end
        return unit.count
    end
    local function info(tag,i)
        if i>MAX_CACHED_ROWS then return GetUnitBuffInfo(tag,i) end
        local row=unit.rows[i]
        if not row then row={}; unit.rows[i]=row end
        if row.generation~=unit.generation then
            row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10],row[11],row[12],row[13]=GetUnitBuffInfo(tag,i)
            row.generation=unit.generation
        end
        -- Preserve positional nils and false (not cast by the player).
        return row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10],row[11],row[12],row[13]
    end
    unit.generation=0; unit.readCount=count; unit.readInfo=info
    return unit
end

function ZeraUIEffectSnapshot.New()
    local units={player=newUnit(),reticleover=newUnit()}
    local snapshot={}
    function snapshot:Begin()
        for _,unit in pairs(units) do
            unit.count=nil; unit.generation=unit.generation+1
        end
    end
    function snapshot:Readers(tag)
        local unit=units[tag]
        if not unit then return GetNumBuffs,GetUnitBuffInfo end
        return unit.readCount,unit.readInfo
    end
    return snapshot
end
