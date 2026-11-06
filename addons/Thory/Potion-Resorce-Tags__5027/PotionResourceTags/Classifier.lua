PotionResourceTags = {}
local PRT = PotionResourceTags

PRT.SOURCE_API_VERSION = 101051
PRT.CLASSIFICATION_STATUS = "icon-and-link-recovery-ids"
PRT.TARGET_ICON = "/esoui/art/icons/consumable_potion_005_type_005.dds"
PRT.Classifier = {}
local Classifier = PRT.Classifier

-- API failures are a classification failure, never an absent opposite effect.
local function Read(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then
        return false, "api-unavailable:" .. name
    end
    local ok, first, second = pcall(fn, ...)
    if not ok then
        return false, "api-error:" .. name
    end
    return true, first, second
end

local function NormalizeIcon(icon)
    return icon:lower():gsub("\\", "/"):gsub("^/+", "")
end

function Classifier.ParseLink(link)
    if type(link) ~= "string" then
        return nil
    end
    local payload = link:match("|H%d+:item:([^|]+)|h")
    if not payload then
        return nil
    end
    local fields = {}
    -- Preserve empty fields, including a trailing empty field, on Lua 5.1.
    for field in (payload .. ":"):gmatch("(.-):") do
        fields[#fields + 1] = field
    end
    return { payload = payload, fields = fields }
end

-- Independently implemented arithmetic; no library code or bit masking.
-- Recovery IDs 3/5 match the acquired samples. High-bit meanings remain unknown.
function Classifier.DecodeEffects(link)
    local parsed = Classifier.ParseLink(link)
    if not parsed then
        return nil, "unrecognized-link"
    elseif #parsed.fields ~= 21 then
        return nil, "unexpected-field-count:" .. #parsed.fields
    end
    local raw = parsed.fields[21]
    if not raw:match("^%d+$") then
        return nil, "invalid-effect-value"
    end
    local value = tonumber(raw)
    if not value or value > 16777215 then
        return nil, "effect-value-out-of-range"
    end

    local effects = { value = value, bytes = {}, magicka = false, stamina = false, hasHighBit = false }
    local remaining, firstHighByte = value, nil
    for index = 1, 3 do
        local byte = remaining % 256
        remaining = math.floor(remaining / 256)
        effects.bytes[index] = byte
        effects.magicka = effects.magicka or byte == 3
        effects.stamina = effects.stamina or byte == 5
        if byte >= 128 then
            effects.hasHighBit = true
            firstHighByte = firstHighByte or index
        end
    end
    if value == 0 then
        -- Nothing can be inferred about provenance (purchased, reward, etc.).
        return effects, "effect-value-zero"
    elseif firstHighByte then
        return effects, "unverified-high-bit:byte=" .. firstHighByte
    end
    return effects
end

function Classifier.Classify(link)
    if not link or link == "" then
        return nil, "empty"
    end
    local ok, api = Read("GetAPIVersion")
    if not ok then
        return nil, api
    elseif api ~= PRT.SOURCE_API_VERSION then
        return nil, "unsupported-api"
    end
    local itemType
    ok, itemType = Read("GetItemLinkItemType", link)
    if not ok then
        return nil, itemType
    elseif type(itemType) ~= "number" then
        return nil, "incomplete-item-type"
    elseif itemType ~= ITEMTYPE_POTION then
        return nil, "not-potion"
    end
    local icon
    ok, icon = Read("GetItemLinkIcon", link)
    if not ok then
        return nil, icon
    elseif type(icon) ~= "string" or icon == "" then
        return nil, "incomplete-icon"
    elseif NormalizeIcon(icon) ~= NormalizeIcon(PRT.TARGET_ICON) then
        return nil, "different-icon"
    end

    local effects, problem = Classifier.DecodeEffects(link)
    if problem then
        return nil, problem
    elseif effects.magicka and effects.stamina then
        return nil, "both-resources"
    elseif effects.magicka then
        return "M", "magicka-only"
    elseif effects.stamina then
        return "S", "stamina-only"
    end
    return nil, "no-recovery-id"
end
