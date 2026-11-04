-- Imperial City uses an explicit map allowlist, including its shared sewer atlas.
-- Sources and coordinate precision are documented in docs/imperial-city.md.
local ImperialCity = {}
EOTU.internal.bossData.ImperialCity = ImperialCity

local SEWER_MAPS = {
    imperialsewer_daggerfall1_base_0 = true,
    imperialsewer_daggerfall2_base_0 = true,
    imperialsewer_daggerfall3_base_0 = true,
    imperialsewer_dagfall3b_base_0 = true,
    imperialsewers_aldmeri1_base_0 = true,
    imperialsewers_aldmeri2_base_0 = true,
    imperialsewers_aldmeri3_base_0 = true,
    imperialsewers_ebon1_base_0 = true,
    imperialsewers_ebon2_base_0 = true,
    imperialsewer_ebonheart3_base_0 = true,
    imperialsewer_ebonheart3b_base_0 = true,
    imperialsewershub_base_0 = true,
    imperialsewershub_0 = true, -- Legacy hub texture name.
}

local DISTRICT_PATROLS = {
    { .658, .383, "Arena: Glorgoloch the Destroyer / King Khrogo" },
    { .682, .615, "Arboretum: Lady Malygda / Ysenda Resplendent" },
    { .505, .833, "Temple: Immolator Charr / Mazaluhad" },
    { .206, .679, "Nobles: Amoncrul" },
    { .182, .634, "Nobles: Baron Thirsk" },
    { .236, .359, "Elven Gardens: Zoal the Ever-Wakeful / The Screeching Matron" },
    { .496, .295, "Memorial: Nunatak / Volghass" },
}

-- Native sewer POI indices (zone ID 643), with static map references as fallback.
-- Discovery and map filters must not hide an otherwise valid boss location.
local SEWER_CHAMPIONS = {
    { .355, .397, "Ebral the Betrayer", 25 },
    { .779, .535, "Emperor Leovic", 26 },
    { .139, .560, "Gati the Storm Sister", 27 },
    { .797, .647, "Hzu-Hakan", 28 },
    { .635, .559, "Lady of the Depths", 29 },
    { .272, .502, "Otholug gro-Goldfolly", 30 },
    { .430, .475, "Secundinus the Despoiler", 31 },
    { .402, .569, "Taebod the Gatekeeper", 32 },
    { .435, .266, "Wadracki", 33 },
    { .469, .332, "General Nazenaechar", 44 },
    { .691, .535, "General Kryozote", 45 },
    { .194, .711, "General Zamachar", 46 },
}

-- One approximate reference on each of the nine patrol routes. Names rotate;
-- assigning a particular general to a permanent location would be misleading.
local SEWER_PATROLS = {
    { .846, .646, "Irrigation Tunnels: Training Grounds" },
    { .709, .543, "Abyssal Depths: Lost Tombs" },
    { .760, .592, "Abyssal Depths: The Hatchery" },
    { .106, .623, "Lambent Passage: Battle Gates" },
    { .167, .600, "Lambent Passage: Nocere Oblitus" },
    { .284, .520, "Vile Drainage: Bloodworks" },
    { .481, .260, "Harena Hypogeum: Buried Artifact" },
    { .381, .376, "Antediluvian Vaults: Betrayer's Catacombs" },
    { .440, .417, "Antediluvian Vaults: Feeding Pits" },
}

local CENTRAL_ENCOUNTER = {
    { .525, .560, "Simulacrum of Molag Bal\nBarathrum Centrata encounter area. Defeat the three central Coldharbour Elite Guards to summon him." },
    { .518, .554, "Coldharbour Elite Guard\nBarathrum Centrata: western summoning portal (encounter reference)." },
    { .532, .554, "Coldharbour Elite Guard\nBarathrum Centrata: eastern summoning portal (encounter reference)." },
    { .525, .566, "Coldharbour Elite Guard\nBarathrum Centrata: southern summoning portal (encounter reference)." },
}

local function ValidCoordinate(value)
    return type(value) == "number" and value > 0 and value < 1
end

function ImperialCity:IsSupportedMap(mapName)
    return mapName == "imperialcity_base_0" or SEWER_MAPS[mapName] == true
end

function ImperialCity:BuildPins(mapName, place, current, showPatrols)
    if not self:IsSupportedMap(mapName) then return end
    if mapName == "imperialcity_base_0" then
        if showPatrols then
            for _, row in ipairs(DISTRICT_PATROLS) do
                if not place({ row[1], row[2], row[3] .. "\nPatrol reference; the boss moves within the district. Not a live location or spawn status." }) then return end
            end
        end
        return
    end
    local zoneIndex = GetZoneIndex and GetZoneIndex(643)
    for _, row in ipairs(SEWER_CHAMPIONS) do
        if not current() then return end
        local x, y = row[1], row[2]
        if zoneIndex and zoneIndex > 0 and GetPOIMapInfo then
            local nativeX, nativeY = GetPOIMapInfo(zoneIndex, row[4])
            -- Bound even native API reads, including when no location is returned.
            coroutine.yield()
            if not current() then return end
            if ValidCoordinate(nativeX) and ValidCoordinate(nativeY) then x, y = nativeX, nativeY end
        end
        if not place({ x, y, row[3] }) then return end
    end
    for _, row in ipairs(CENTRAL_ENCOUNTER) do if not place(row) then return end end
    if showPatrols then
        for _, row in ipairs(SEWER_PATROLS) do
            if not place({ row[1], row[2], "Coldharbour Elite Guard\n" .. row[3]
                .. "\nApproximate patrol reference. The general's name varies; this is not a live position or spawn status." }) then return end
        end
    end
end
