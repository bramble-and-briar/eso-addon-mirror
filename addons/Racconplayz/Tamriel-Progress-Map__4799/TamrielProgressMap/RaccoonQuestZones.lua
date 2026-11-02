-- Stable zone-ID classification. Localized zone or quest names are never used.
local RQD = _G.RaccoonQuestData
if type(RQD) ~= "table" then return end

RQD.dataRevision = "2026-10-31-api101051"

local ZONES = {
    -- Base game story zones and shared base-game regions.
    [3] = { kind = "base" }, [19] = { kind = "base" }, [20] = { kind = "base" },
    [41] = { kind = "base" }, [57] = { kind = "base" }, [58] = { kind = "base" },
    [92] = { kind = "base" }, [101] = { kind = "base" }, [103] = { kind = "base" },
    [104] = { kind = "base" }, [108] = { kind = "base" }, [117] = { kind = "base" },
    [181] = { kind = "base" }, [280] = { kind = "base" }, [281] = { kind = "base" },
    [347] = { kind = "base" }, [381] = { kind = "base" }, [382] = { kind = "base" },
    [383] = { kind = "base" }, [534] = { kind = "base" }, [535] = { kind = "base" },
    [537] = { kind = "base" }, [888] = { kind = "base" },

    -- Permanently free story areas, kept with the base/free side-quest statistic.
    [584] = { kind = "free" }, [849] = { kind = "free" },

    -- Chapter and DLC story zones.
    [684] = { kind = "dlc" }, [726] = { kind = "dlc" }, [816] = { kind = "dlc" },
    [823] = { kind = "dlc" }, [980] = { kind = "dlc" }, [1011] = { kind = "dlc" },
    [1086] = { kind = "dlc" }, [1133] = { kind = "dlc" }, [1160] = { kind = "dlc" },
    [1207] = { kind = "dlc" }, [1261] = { kind = "dlc" }, [1282] = { kind = "dlc" },
    [1318] = { kind = "dlc" }, [1383] = { kind = "dlc" }, [1414] = { kind = "dlc" },
    [1443] = { kind = "dlc" }, [1502] = { kind = "dlc" },
}

for zoneId, definition in pairs(ZONES) do RQD:RegisterZoneContent(zoneId, definition) end

