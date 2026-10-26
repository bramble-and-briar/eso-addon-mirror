BF.BuildExport = {}

local MAX_URL_LENGTH = 7800
local DEFAULT_ENDPOINT = "https://publishers-cuisine-gadgets-concerned.trycloudflare.com/ingest"

local function UrlEncode(value)
    value = tostring(value or "")
    value = string.gsub(value, "\n", "\r\n")
    value = string.gsub(value, "([^%w%-_%.~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
    return value
end

local function EscapeField(value)
    value = tostring(value or "")
    value = string.gsub(value, "\\", "\\\\")
    value = string.gsub(value, "|", "\\p")
    value = string.gsub(value, "~", "\\t")
    value = string.gsub(value, ",", "\\c")
    value = string.gsub(value, "\n", "\\n")
    value = string.gsub(value, "\r", "")
    return value
end

local function SerializeBuild(build)
    local parts = {}
    table.insert(parts, "BFv1")
    table.insert(parts, table.concat({
        "META",
        EscapeField(build.id),
        EscapeField(build.name),
        EscapeField(build.author),
        EscapeField(build.characterName),
        EscapeField(build.className),
        EscapeField(build.raceName),
        tostring(build.level or 0),
        tostring(build.championPoints or 0),
        tostring(build.timestamp or 0),
        tostring(build.gearCount or (build.gear and #build.gear) or 0),
    }, "|"))

    local attrs = build.attributes or {}
    table.insert(parts, table.concat({ "ATTR", tostring(attrs.health or 0), tostring(attrs.magicka or 0), tostring(attrs.stamina or 0) }, "|"))

    for _, mundus in ipairs(build.mundus or {}) do
        table.insert(parts, table.concat({ "MUNDUS", tostring(mundus.mundusStone or 0), tostring(mundus.abilityId or 0), EscapeField(mundus.name) }, "|"))
    end

    for _, item in ipairs(build.gear or {}) do
        table.insert(parts, table.concat({
            "GEAR",
            tostring(item.equipSlot or 0),
            EscapeField(item.slotName),
            tostring(item.itemId or 0),
            EscapeField(item.itemName),
            tostring(item.setId or 0),
            EscapeField(item.setName),
            tostring(item.traitType or 0),
            tostring(item.enchantId or 0),
            tostring(item.armorType or 0),
            tostring(item.weaponType or 0),
            tostring(item.equipType or 0),
            tostring(item.functionalQuality or 0),
            EscapeField(item.link),
        }, "|"))
    end

    for _, skill in ipairs(build.skills or {}) do
        table.insert(parts, table.concat({ "SKILL", EscapeField(skill.hotbar), tostring(skill.hotbarCategory or 0), tostring(skill.slotIndex or 0), tostring(skill.actionId or 0), tostring(skill.actionType or 0), tostring(skill.skillType or 0), tostring(skill.skillLineIndex or 0), tostring(skill.skillIndex or 0), tostring(skill.morphChoice or 0), tostring(skill.rank or 0), EscapeField(skill.name) }, "|"))
    end

    for _, cp in ipairs(build.championSlots or {}) do
        table.insert(parts, table.concat({ "CP", tostring(cp.slotIndex or 0), tostring(cp.championSkillId or 0), EscapeField(cp.name) }, "|"))
    end

    for _, cpSkill in ipairs(build.championSkills or {}) do
        table.insert(parts, table.concat({ "CPSKILL", tostring(cpSkill.championSkillId or 0), tostring(cpSkill.disciplineId or 0), tostring(cpSkill.points or 0), EscapeField(cpSkill.name) }, "|"))
    end

    return table.concat(parts, "\n")
end

local function BuildUrls(endpoint, build, payload)
    local urls = {}
    local sessionId = string.format("%s-%d", tostring(build.id or "build"), GetTimeStamp())
    local sep = string.find(endpoint, "?", 1, true) and "&" or "?"
    local meta = string.format("%skind=build&sid=%s&buildId=%s&name=%s&author=%s&class=%s&format=BFv1",
        sep,
        UrlEncode(sessionId),
        UrlEncode(build.id or ""),
        UrlEncode(build.name or ""),
        UrlEncode(build.author or ""),
        UrlEncode(build.className or "")
    )
    local encodedPayload = UrlEncode(payload)
    local maxChunkSize = MAX_URL_LENGTH - #endpoint - #meta - 80
    if maxChunkSize < 500 then maxChunkSize = 500 end
    local chunks = {}
    local pos = 1
    while pos <= #encodedPayload do
        table.insert(chunks, string.sub(encodedPayload, pos, pos + maxChunkSize - 1))
        pos = pos + maxChunkSize
    end
    if #chunks == 0 then table.insert(chunks, "") end
    for i, chunk in ipairs(chunks) do
        urls[i] = string.format("%s%s&i=%d&n=%d&d=%s", endpoint, meta, i, #chunks, chunk)
    end
    return urls, sessionId
end

function BF.BuildExport.GetEndpoint()
    return (BF.savedVars and BF.savedVars.settings and BF.savedVars.settings.exportEndpoint) or DEFAULT_ENDPOINT
end

function BF.BuildExport.SetEndpoint(endpoint)
    if not endpoint or endpoint == "" then
        BF.Chat("Usage: /bf endpoint https://your-server/ingest")
        return false
    end
    endpoint = string.match(endpoint, "^%s*(.-)%s*$") or endpoint
    if not string.find(endpoint, "/ingest", 1, true) then endpoint = endpoint .. "/ingest" end
    BF.savedVars.settings.exportEndpoint = endpoint
    BF.Chat("Export endpoint set to: " .. endpoint)
    return true
end

function BF.BuildExport.ExportBuild(build)
    if not build then
        BF.Chat("No build selected to export.")
        return false
    end
    if not RequestOpenUnsafeURL then
        BF.Chat("RequestOpenUnsafeURL is unavailable on this client.")
        return false
    end
    local payload = SerializeBuild(build)
    local urls, sessionId = BuildUrls(BF.BuildExport.GetEndpoint(), build, payload)
    BF.Chat(string.format("Exporting '%s' in %d request(s).", build.name or build.id or "build", #urls))
    for i, url in ipairs(urls) do
        zo_callLater(function() RequestOpenUnsafeURL(url) end, (i - 1) * 400)
    end
    BF.Chat("Export session: " .. tostring(sessionId))
    return true
end
