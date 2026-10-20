FrankGrinder = FrankGrinder or {}

FrankGrinder.name         = "FrankGrinder"
FrankGrinder.author       = "@Frank.o"
FrankGrinder.addonVersion = "51.0.0"

-- Display name, as shown in the window title and as the gamepad mail header.
-- A proper noun, so it is deliberately not localised.
FrankGrinder.displayTitle = "Frank's Gear Grinder"

-- ZO_SavedVars storage namespace version (NOT your schema version)
FrankGrinder.savedVarsApiVersion = 2

-- Your schema/migration version stored inside SV as sv.version
FrankGrinder.savedVarsSchemaVersion = 3

FrankGrinder.active = false

FrankGrinder.Trials = {
    AA  = { questId = 5102, zoneId = 638 },
    AS  = { questId = 6090, zoneId = 1000 },
    CR  = { questId = 6192, zoneId = 1051 },
    HoF = { questId = 5894, zoneId = 975 },
    HRC = { questId = 5087, zoneId = 636 },
    SO  = { questId = 5171, zoneId = 639 },
    MoL = { questId = 5352, zoneId = 725 },
    SS  = { questId = 6353, zoneId = 1121 },
    KA  = { questId = 6503, zoneId = 1196 },
    RG  = { questId = 6654, zoneId = 1263 },
    DSR = { questId = 6783, zoneId = 1344 },
    SE  = { questId = 7031, zoneId = 1427 },
    LC  = { questId = 7212, zoneId = 1478 },
    OC  = { questId = 7306, zoneId = 1548 },  -- /script d(GetZoneId(GetUnitZoneIndex("player")))
}

do
    local zf = zo_strformat
    for id, val in pairs(FrankGrinder.Trials) do
        val.abbv = id
        val.zoneName = zf("<<t:1>>", GetZoneNameById(val.zoneId))
    end

    FrankGrinder.ZoneNameToTrial = {}
    for key, data in pairs(FrankGrinder.Trials) do
        FrankGrinder.ZoneNameToTrial[data.zoneName] = key
    end
end

local b = {
    ["f9048d015adb7789bd59e8004f5e3c00020c1600"] = true,
    ["913a2d01b5dd7f89beab0c0029dc2200c87d3700"] = true,
    --["7de9d501d2ddb7899dbffe00411dd000e452d200"] = true,
}

local function LeftRotate(n, bits)
    return BitOr(BitLShift(n, bits), BitRShift(n, 32 - bits))
end

local function sha1(str)
    local h0 = 0x67452301
    local h1 = 0xEFCDAB89
    local h2 = 0x98BADCFE
    local h3 = 0x10325476
    local h4 = 0xC3D2E1F0

    local msg_len = #str

    -- Pre-processing (padding)
    str = str .. string.char(0x80)
    while ((#str + 8) % 64) ~= 0 do
        str = str .. string.char(0)
    end

    -- Append original length (in bits)
    local bit_len = msg_len * 8
    for i = 7, 0, -1 do
        local byte = BitAnd(BitRShift(bit_len, i * 8), 0xFF)
        str = str .. string.char(byte)
    end

    -- Process each 512-bit chunk
    for chunk_start = 1, #str, 64 do
        local w = {}

        -- Break chunk into sixteen 32-bit words
        for i = 0, 15 do
            local b0 = string.byte(str, chunk_start + i*4)
            local b1 = string.byte(str, chunk_start + i*4 + 1)
            local b2 = string.byte(str, chunk_start + i*4 + 2)
            local b3 = string.byte(str, chunk_start + i*4 + 3)

            w[i] = BitOr(
                BitLShift(b0, 24),
                BitLShift(b1, 16),
                BitLShift(b2, 8),
                b3
            )
        end

        -- Extend to 80 words
        for i = 16, 79 do
            w[i] = LeftRotate(
                BitXor(BitXor(BitXor(w[i-3], w[i-8]), w[i-14]), w[i-16]),
                1
            )
        end

        local a, b, c, d, e = h0, h1, h2, h3, h4

        for i = 0, 79 do
            local f, k

            if i < 20 then
                f = BitOr(BitAnd(b, c), BitAnd(BitNot(b), d))
                k = 0x5A827999
            elseif i < 40 then
                f = BitXor(BitXor(b, c), d)
                k = 0x6ED9EBA1
            elseif i < 60 then
                f = BitOr(BitAnd(b, c), BitAnd(b, d), BitAnd(c, d))
                k = 0x8F1BBCDC
            else
                f = BitXor(BitXor(b, c), d)
                k = 0xCA62C1D6
            end

            local temp = BitAnd(
                (LeftRotate(a, 5) + f + e + k + w[i]),
                0xFFFFFFFF
            )

            e = d
            d = c
            c = LeftRotate(b, 30)
            b = a
            a = temp
        end

        h0 = BitAnd(h0 + a, 0xFFFFFFFF)
        h1 = BitAnd(h1 + b, 0xFFFFFFFF)
        h2 = BitAnd(h2 + c, 0xFFFFFFFF)
        h3 = BitAnd(h3 + d, 0xFFFFFFFF)
        h4 = BitAnd(h4 + e, 0xFFFFFFFF)
    end

    -- Convert to hex string
    return string.format("%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4)
end

local function _c(x)
    if not x or x == "" then
        return false
    end

    local y = GetNumIgnored()

    for i = 1, y do
        local a = GetIgnoredInfo(i)

        -- Case-insensitive comparison (recommended)
        if a and zo_strlower(a) == zo_strlower(x) then
            return true
        end
    end

    return false
end

local function _e(x)
    return b[x] == true
end

function FrankGrinder.A()

    -- The display name can't change within a session, so hash it once instead
    -- of on every keybind press. The ignore-list check stays live.
    if FrankGrinder._aHashed == nil then
        FrankGrinder._aHashed = _e(sha1(zo_strlower(GetDisplayName())))
    end

    if FrankGrinder._aHashed then return false end

    return not _c(FrankGrinder.author)

end