-- Tamriel Text Studio
-- Console-conscious ESO text composer for fields which support ESO inline markup.
-- Developer: CRY | Version 2.4.3
-- Lives 100% inside Settings > Add-ons > Tamriel Text Studio with zero floating windows.
-- Key architecture rules for ESO Console security sandbox (APIVersion 101051):
-- 1) Setting callbacks update SavedVariables / plain Lua state only. They must never refresh, rebuild,
--    or otherwise touch the LibHarvensAddonSettings panel or its controls.
-- 2) Do not schedule a delayed panel:UpdateControls() either. A timer can fire after the player has
--    left the add-on settings page and while another Gamepad screen/dialog is being shown; refreshing
--    the inactive settings panel can re-enter ESO's shared keybind/dialog machinery and taint its stack.
-- 3) Let LibHarvensAddonSettings perform its normal refresh when the player reopens the panel. This
--    deliberately trades instant in-place preview refresh for avoiding private-function UI errors.
-- 4) Keep long ST_EDIT fields at or below 2000 characters for the PS5 on-screen keyboard.

local ADDON_NAME = "TamrielTextStudio"
local TTS = {}
local DEFAULT_COLOR = "FFD700"
local DEFAULT_TEXTURE_PATH = "esoui/art/icons/pet_081.dds"
local CONSOLE_MAX_EDIT_CHARS = 2000

local COLOR_TARGETS = { "All text", "Heading", "Message", "Divider" }
local TARGETS = {
    { name = "Guild MOTD", limit = 2048 },
    { name = "Guild About Us", limit = 2048 },
    { name = "Guild Member Note", limit = 254 },
    { name = "Custom / Other", limit = 2048 },
}
local CATEGORIES = {
    "All textures", "Icons & Skills", "Map & Travel", "Factions",
    "Pets & Creatures", "Services", "Crafting & Items", "Decorative / UI", "Favorites",
    "Skills & Abilities", "Trials & Achievements", "Skins & Collectibles",
    "Mounts & Companions", "Artwork & UI", "Achievements & Rewards",
}
local SIZES = { 16, 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 80, 96, 112, 120, 128, 144, 160, 192, 256 }
local POSITIONS = { "Start", "End", "Both" }
local SEPARATORS = { "None", "-----", "* * *", "=====", "- - -", "< > < >" }

local function Trim(value)
    if type(value) ~= "string" then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeHex(value)
    if type(value) ~= "string" then value = tostring(value or "") end
    value = value:gsub("#", ""):gsub("%s", ""):upper()
    if #value == 8 then
        value = value:sub(1, 6)
    end
    if #value == 6 and value:match("^%x%x%x%x%x%x$") then return value end
    return nil
end

local function HexToRGB(hex)
    hex = NormalizeHex(hex) or DEFAULT_COLOR
    return tonumber(hex:sub(1, 2), 16) / 255,
           tonumber(hex:sub(3, 4), 16) / 255,
           tonumber(hex:sub(5, 6), 16) / 255
end

local function WrapColor(text, hex)
    if text == nil or text == "" then return "" end
    return "|c" .. (NormalizeHex(hex) or DEFAULT_COLOR) .. text .. "|r"
end

-- Pure ASCII display formatter so ESO's CT_LABEL shows the literal markup tags on screen
-- for manual reading/writing down without using any non-ASCII or invisible UTF-8 characters.
-- Replaces "|" with "| " for visual display and reminds the user to omit the space after "|" if typing by hand.
local function FormatVisibleMarkupForDisplay(rawText)
    rawText = tostring(rawText or "")
    if rawText == "" then return "(No output generated yet)" end
    return (rawText:gsub("|", "| "))
end

local function NormalizeSearchText(value)
    value = string.lower(tostring(value or ""))
    value = value:gsub("[%._%-%/\\]+", " ")
    value = value:gsub("[^%w%s]", " ")
    value = value:gsub("%s+", " ")
    return value
end

local function InferTextureCategory(path)
    local lower = string.lower(path or "")
    if lower:find("/icons/poi/", 1, true) or lower:find("wayshrine", 1, true) or lower:find("mapkey", 1, true) or lower:find("servicemappin", 1, true) then
        return "Map & Travel"
    elseif lower:find("pet", 1, true) or lower:find("creature", 1, true) or lower:find("vanity", 1, true) then
        return "Pets & Creatures"
    elseif lower:find("mount", 1, true) or lower:find("companion", 1, true) or lower:find("assistant", 1, true) then
        return "Mounts & Companions"
    elseif lower:find("skin", 1, true) or lower:find("costume", 1, true) or lower:find("polymorph", 1, true) or lower:find("personality", 1, true) or lower:find("collectible", 1, true) then
        return "Skins & Collectibles"
    elseif lower:find("ability", 1, true) or lower:find("skill", 1, true) or lower:find("class", 1, true) or lower:find("weapon", 1, true) then
        return "Skills & Abilities"
    elseif lower:find("achievement", 1, true) or lower:find("trial", 1, true) or lower:find("dungeon", 1, true) or lower:find("arena", 1, true) then
        return "Achievements & Rewards"
    elseif lower:find("/art/icons/", 1, true) then
        return "Icons & Skills"
    elseif lower:find("/art/ava/", 1, true) or lower:find("alliance", 1, true) or lower:find("banner", 1, true) then
        return "Factions"
    end
    return "Artwork & UI"
end

local function FriendlyNameFromPath(path)
    path = tostring(path or "")
    local filename = path:match("([^/]+)$") or path
    filename = filename:gsub("%.[Dd][Dd][Ss]$", ""):gsub("_", " "):gsub("%-", " ")
    filename = filename:gsub("%s+", " ")
    return filename
end

local function AddSearchCache(texture)
    if type(texture) ~= "table" then return texture end
    texture._ttsSearchText = NormalizeSearchText(
        (texture.name or "") .. " " .. (texture.keywords or "") .. " " ..
        (texture.category or "") .. " " .. (texture.path or "") .. " " ..
        FriendlyNameFromPath(texture.path or "")
    )
    return texture
end

local function BuildUniqueCatalog()
    local unique, seen = {}, {}
    local function Add(texture)
        if type(texture) == "table" and type(texture.path) == "string" and texture.path ~= "" and not seen[texture.path] then
            seen[texture.path] = true
            unique[#unique + 1] = AddSearchCache(texture)
        end
    end
    if type(TTS_TEXTURES) == "table" then
        for _, texture in ipairs(TTS_TEXTURES) do Add(texture) end
    end
    if type(TTS_FULL_TEXTURE_PATHS) == "table" then
        for _, path in ipairs(TTS_FULL_TEXTURE_PATHS) do
            if type(path) == "string" and string.lower(path):match("%.dds$") then
                local category = InferTextureCategory(path)
                local name = FriendlyNameFromPath(path)
                Add({ name = name, path = path, category = category,
                      keywords = NormalizeSearchText(name .. " " .. category .. " " .. path) })
            end
        end
    end
    return unique
end

local function MigrateTextureSelection(saved, textures)
    if saved.textureLibraryMigrated then return end
    local oldPath = Trim(saved.texturePath or "")
    if oldPath ~= "" then
        local found = false
        for index, texture in ipairs(textures) do
            if texture.path == oldPath then
                saved.textureIndex = index
                saved.customPath = ""
                found = true
                break
            end
        end
        if not found then saved.customPath = oldPath end
    end
    saved.textureLibraryMigrated = true
end

local function GetSaved()
    local saved = TamrielTextStudioSaved
    if type(saved) ~= "table" and type(GuildMarkupStudioSaved) == "table" then
        saved = GuildMarkupStudioSaved
    end
    if type(saved) ~= "table" then saved = {} end
    saved.target = math.max(1, math.min(#TARGETS, tonumber(saved.target) or 1))
    saved.colorTarget = math.max(1, math.min(#COLOR_TARGETS, tonumber(saved.colorTarget) or 1))
    saved.activeHex = NormalizeHex(saved.activeHex or saved.colorHex) or DEFAULT_COLOR
    saved.titleHex = NormalizeHex(saved.titleHex or saved.activeHex) or DEFAULT_COLOR
    saved.bodyHex = NormalizeHex(saved.bodyHex or saved.activeHex) or DEFAULT_COLOR
    saved.dividerHex = NormalizeHex(saved.dividerHex or saved.activeHex) or DEFAULT_COLOR

    if not saved.colorMigration240 then
        if saved.activeHex == "FFFFFF" then saved.activeHex = DEFAULT_COLOR end
        if saved.titleHex == "FFFFFF" then saved.titleHex = saved.activeHex end
        if saved.bodyHex == "FFFFFF" then saved.bodyHex = saved.activeHex end
        if saved.dividerHex == "FFFFFF" then saved.dividerHex = saved.activeHex end
        saved.explicitWhiteSelected = false
        saved.colorMigration240 = true
    end

    saved.textureIndex = math.max(1, tonumber(saved.textureIndex) or 1)
    saved.customPath = tostring(saved.customPath or "")
    saved.textureCategory = math.max(1, math.min(#CATEGORIES, tonumber(saved.textureCategory) or 1))
    saved.texturePage = math.max(1, tonumber(saved.texturePage) or 1)
    saved.iconSize = tonumber(saved.iconSize) or 32
    saved.iconEnabled = saved.iconEnabled ~= false
    saved.iconPosition = math.max(1, math.min(#POSITIONS, tonumber(saved.iconPosition) or 1))
    saved.separator = math.max(1, math.min(#SEPARATORS, tonumber(saved.separator) or 1))
    saved.title = tostring(saved.title or "Welcome to our guild!")
    saved.body = tostring(saved.body or "Add your message here.")
    saved.output = tostring(saved.output or "")
    saved.search = tostring(saved.search or "")
    saved.favorites = type(saved.favorites) == "table" and saved.favorites or {}
    TamrielTextStudioSaved = saved
    return saved
end

local function Persist()
    if TTS.saved then TamrielTextStudioSaved = TTS.saved end
end

local function CurrentTarget()
    return TARGETS[TTS.saved.target] or TARGETS[1]
end

local function CurrentTexture()
    return TTS.textures[TTS.saved.textureIndex] or TTS.textures[1]
end

local function CurrentPath()
    local custom = Trim(TTS.saved.customPath or "")
    if custom ~= "" then return custom end
    local texture = CurrentTexture()
    if texture then return texture.path end
    return DEFAULT_TEXTURE_PATH
end

local function CurrentTextureName()
    if Trim(TTS.saved.customPath or "") ~= "" then
        return TTS.saved.customTextureName or ("Custom: " .. FriendlyNameFromPath(TTS.saved.customPath))
    end
    local texture = CurrentTexture()
    return texture and texture.name or "Baby Netch"
end

local function CurrentTargetHex()
    if not TTS.saved then return DEFAULT_COLOR end
    local target = TTS.saved.colorTarget
    local hex
    if target == 2 then
        hex = NormalizeHex(TTS.saved.titleHex)
    elseif target == 3 then
        hex = NormalizeHex(TTS.saved.bodyHex)
    elseif target == 4 then
        hex = NormalizeHex(TTS.saved.dividerHex)
    else
        hex = NormalizeHex(TTS.saved.activeHex) or NormalizeHex(TTS.saved.titleHex)
    end
    if not hex then return DEFAULT_COLOR end
    if hex == "FFFFFF" and not TTS.saved.explicitWhiteSelected then
        return DEFAULT_COLOR
    end
    return hex
end

local function ApplyHexToTarget(hex, allowWhite)
    hex = NormalizeHex(hex)
    if not hex or not TTS.saved then return false end
    if hex == "FFFFFF" and not allowWhite then
        return false
    end
    TTS.saved.explicitWhiteSelected = (hex == "FFFFFF" and allowWhite == true)
    TTS.saved.activeHex = hex
    local target = TTS.saved.colorTarget
    if target == 1 then
        TTS.saved.titleHex = hex
        TTS.saved.bodyHex = hex
        TTS.saved.dividerHex = hex
    elseif target == 2 then
        TTS.saved.titleHex = hex
    elseif target == 3 then
        TTS.saved.bodyHex = hex
    elseif target == 4 then
        TTS.saved.dividerHex = hex
    end
    return true
end

local function CreateOutputText()
    local saved = TTS.saved
    if not saved then return "" end
    local title = Trim(saved.title)
    local body = Trim(saved.body)
    local separator = SEPARATORS[saved.separator] or "None"
    local icon = ""
    if saved.iconEnabled then
        local size = tonumber(saved.iconSize) or 32
        icon = string.format("|t%d:%d:%s|t", size, size, CurrentPath())
    end

    local titleColor = (saved.titleHex == "FFFFFF" and not saved.explicitWhiteSelected) and DEFAULT_COLOR or saved.titleHex
    local dividerColor = (saved.dividerHex == "FFFFFF" and not saved.explicitWhiteSelected) and DEFAULT_COLOR or saved.dividerHex
    local bodyColor = (saved.bodyHex == "FFFFFF" and not saved.explicitWhiteSelected) and DEFAULT_COLOR or saved.bodyHex

    local lines = {}
    local function AddLine(line)
        if line and line ~= "" then lines[#lines + 1] = line end
    end
    if saved.iconEnabled and (saved.iconPosition == 1 or saved.iconPosition == 3) then
        if title ~= "" then
            AddLine(icon .. " " .. WrapColor(title, titleColor))
        else
            AddLine(icon)
        end
    elseif title ~= "" then
        AddLine(WrapColor(title, titleColor))
    end
    if separator ~= "None" then AddLine(WrapColor(separator, dividerColor)) end
    if body ~= "" then AddLine(WrapColor(body, bodyColor)) end
    if saved.iconEnabled and (saved.iconPosition == 2 or saved.iconPosition == 3) then
        AddLine(icon)
    end
    local joiner = (saved.target == 3) and " " or "\n"
    return table.concat(lines, joiner)
end

local function SyncGeneratedOutput()
    if not TTS.saved then return "" end
    local output = CreateOutputText()
    -- Strip any accidental invisible UTF-8 zero-width spaces if previously saved in SavedVariables
    output = output:gsub("\226\128\139", "")
    TTS.saved.output = output
    Persist()
    return output
end

local function IsFavorite(path)
    return TTS.saved.favorites and TTS.saved.favorites[path] == true
end

local function MatchesCategory(texture, category)
    if category == "All textures" then return true end
    if category == "Favorites" then return IsFavorite(texture.path) end
    if category == "Icons & Skills" then
        return texture.category == "Icons & Skills" or texture.category == "Skills & Abilities"
    end
    if category == "Artwork & UI" then
        return texture.category == "Decorative / UI" or texture.category == "Trials & Achievements" or texture.category == "Artwork & UI"
    end
    if category == "Achievements & Rewards" then
        return texture.category == "Achievements & Rewards" or texture.category == "Trials & Achievements"
    end
    return texture.category == category
end

local function QueryMatches(searchText, queryWords)
    if #queryWords == 0 then return true end
    for _, word in ipairs(queryWords) do
        if not string.find(searchText or "", word, 1, true) then return false end
    end
    return true
end

-- Runtime catalogue expansion (runs quietly in the background without rebuilding or refreshing active settings rows)
local function RuntimeAddTexture(name, path, category, keywords)
    if type(path) ~= "string" or path == "" then return false end
    if not string.lower(path):match("%.dds$") then return false end
    if string.lower(path):find("icon_missing.dds", 1, true) then return false end
    TTS.texturePathSet = TTS.texturePathSet or {}
    if TTS.texturePathSet[path] then return false end
    TTS.texturePathSet[path] = true
    TTS.textures[#TTS.textures + 1] = {
        name = tostring(name or FriendlyNameFromPath(path)),
        path = path,
        category = category,
        keywords = tostring(keywords or "") .. " " .. tostring(category or "") .. " " .. path,
    }
    AddSearchCache(TTS.textures[#TTS.textures])
    return true
end

local function SafeAPICall(functionName, ...)
    local api = _G[functionName]
    if type(api) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(api, ...)
    if not ok then return nil end
    return a, b, c, d, e, f
end

local RUNTIME_COLLECTIBLE_TYPES = {
    { constant = "COLLECTIBLE_CATEGORY_TYPE_VANITY_PET", category = "Pets & Creatures", keywords = "pet vanity pet companion creature" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_MOUNT", category = "Mounts & Companions", keywords = "mount horse senche guar camel wolf riding" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_ASSISTANT", category = "Mounts & Companions", keywords = "assistant banker merchant fence armorer" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_COMPANION", category = "Mounts & Companions", keywords = "companion ally follower" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_SKIN", category = "Skins & Collectibles", keywords = "skin body appearance trial reward" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_COSTUME", category = "Skins & Collectibles", keywords = "costume outfit appearance" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_PERSONALITY", category = "Skins & Collectibles", keywords = "personality animation idle emote" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_POLYMORPH", category = "Skins & Collectibles", keywords = "polymorph transformation appearance" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_HAT", category = "Skins & Collectibles", keywords = "hat headwear cosmetic" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_HAIR", category = "Skins & Collectibles", keywords = "hair hairstyle cosmetic" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_HEAD_MARKING", category = "Skins & Collectibles", keywords = "head marking face cosmetic" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_BODY_MARKING", category = "Skins & Collectibles", keywords = "body marking tattoo cosmetic" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_FACIAL_HAIR_HORNS", category = "Skins & Collectibles", keywords = "facial hair horns cosmetic" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_FACIAL_ACCESSORY", category = "Skins & Collectibles", keywords = "facial accessory cosmetic" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_PIERCING_JEWELRY", category = "Skins & Collectibles", keywords = "piercing jewelry cosmetic" },
    { constant = "COLLECTIBLE_CATEGORY_TYPE_MEMENTO", category = "Skins & Collectibles", keywords = "memento collectible effect" },
}

local TRIAL_TOPIC_WORDS = {
    "trial", "dungeon", "arena", "undaunted", "dragonstar", "maelstrom", "vateshran",
    "black rose", "blackrose", "sunspire", "cloudrest", "sanctum ophidia", "hel ra",
    "aetherian archive", "maw of lorkhaj", "asylum sanctorium", "kynes aegis", "rockgrove",
    "dreadsail reef", "lucent citadel", "sanity's edge", "endless archive", "white-gold tower",
    "white gold tower", "city of ash", "crypt of hearts", "vaults of madness", "falkreath hold",
    "moon hunter keep", "march of sacrifices", "scalecaller peak", "fang lair", "bloodroot forge",
    "depths of malatar", "black drake villa", "red petal bastion", "coral aerie", "shipwright's regret",
    "shipwrights regret", "scrivener's hall", "scriveners hall", "bal sunnar", "castle thorn",
    "cradle of shadows", "direfrost keep", "volenfell", "selene's web", "spindleclutch",
    "wayrest sewers", "eldengrove", "tempest island", "arx corinium", "banished cells",
}

local function IsTrialTopic(value)
    value = string.lower(tostring(value or ""))
    for _, word in ipairs(TRIAL_TOPIC_WORDS) do
        if string.find(value, word, 1, true) then return true end
    end
    return false
end

local function BuildRuntimeTextureQueue()
    local queue = {}
    if type(GetTotalCollectiblesByCategoryType) == "function" and type(GetCollectibleIdFromType) == "function" and type(GetCollectibleInfo) == "function" then
        for _, descriptor in ipairs(RUNTIME_COLLECTIBLE_TYPES) do
            local typeValue = _G[descriptor.constant]
            if typeValue ~= nil then
                local count = tonumber(SafeAPICall("GetTotalCollectiblesByCategoryType", typeValue)) or 0
                count = math.min(count, 5000)
                for index = 1, count do
                    local id = SafeAPICall("GetCollectibleIdFromType", typeValue, index)
                    if type(id) == "number" and id > 0 then
                        queue[#queue + 1] = { kind = "collectible", id = id, category = descriptor.category, keywords = descriptor.keywords }
                        if type(GetCollectibleGamepadBackgroundImage) == "function" then
                            queue[#queue + 1] = { kind = "collectible_background", id = id, apiName = "GetCollectibleGamepadBackgroundImage", variant = "gamepad", category = descriptor.category, keywords = descriptor.keywords }
                        end
                        if type(GetCollectibleKeyboardBackgroundImage) == "function" then
                            queue[#queue + 1] = { kind = "collectible_background", id = id, apiName = "GetCollectibleKeyboardBackgroundImage", variant = "keyboard", category = descriptor.category, keywords = descriptor.keywords }
                        end
                    end
                end
            end
        end
    end

    if type(GetNumAchievementCategories) == "function" and type(GetAchievementCategoryInfo) == "function" and
       type(GetAchievementSubCategoryInfo) == "function" and type(GetAchievementId) == "function" and type(GetAchievementInfo) == "function" then
        local topCount = tonumber(SafeAPICall("GetNumAchievementCategories")) or 0
        topCount = math.min(topCount, 100)
        for top = 1, topCount do
            local topName, subCount, directCount = SafeAPICall("GetAchievementCategoryInfo", top)
            subCount = math.min(tonumber(subCount) or 0, 100)
            directCount = math.min(tonumber(directCount) or 0, 5000)
            for achievementIndex = 1, directCount do
                local id = SafeAPICall("GetAchievementId", top, nil, achievementIndex)
                if type(id) == "number" and id > 0 then
                    queue[#queue + 1] = { kind = "achievement", id = id, categoryName = tostring(topName or "") }
                end
            end
            for sub = 1, subCount do
                local subName, numAchievements = SafeAPICall("GetAchievementSubCategoryInfo", top, sub)
                for achievementIndex = 1, math.min(tonumber(numAchievements) or 0, 5000) do
                    local id = SafeAPICall("GetAchievementId", top, sub, achievementIndex)
                    if type(id) == "number" and id > 0 then
                        queue[#queue + 1] = { kind = "achievement", id = id, categoryName = tostring(topName or "") .. " / " .. tostring(subName or "") }
                    end
                end
            end
        end
    end

    if type(GetNumSkillTypes) == "function" and type(GetNumSkillLines) == "function" and
       type(GetSkillLineInfo) == "function" and type(GetNumSkillAbilities) == "function" and
       type(GetSkillAbilityInfo) == "function" then
        local skillTypeCount = math.min(tonumber(SafeAPICall("GetNumSkillTypes")) or 0, 20)
        for skillType = 1, skillTypeCount do
            local skillTypeName = tostring(SafeAPICall("GetSkillTypeName", skillType) or ("Skill Type " .. skillType))
            local lineCount = math.min(tonumber(SafeAPICall("GetNumSkillLines", skillType)) or 0, 100)
            for lineIndex = 1, lineCount do
                local lineName = tostring(SafeAPICall("GetSkillLineInfo", skillType, lineIndex) or ("Skill Line " .. lineIndex))
                local abilityCount = math.min(tonumber(SafeAPICall("GetNumSkillAbilities", skillType, lineIndex)) or 0, 250)
                for abilityIndex = 1, abilityCount do
                    queue[#queue + 1] = {
                        kind = "skill", skillType = skillType, lineIndex = lineIndex,
                        abilityIndex = abilityIndex, skillTypeName = skillTypeName,
                        lineName = lineName,
                    }
                end
            end
        end
    end
    return queue
end

local function StartRuntimeTextureIndex()
    if TTS.runtimeScanStarted then return end
    TTS.runtimeScanStarted = true
    TTS.texturePathSet = {}
    for _, texture in ipairs(TTS.textures or {}) do
        if type(texture.path) == "string" then TTS.texturePathSet[texture.path] = true end
    end
    local queue = BuildRuntimeTextureQueue()
    TTS.runtimeQueue = queue
    TTS.runtimeQueueIndex = 1
    TTS.runtimeScanBatches = 0

    local function ProcessBatch()
        local last = math.min(TTS.runtimeQueueIndex + 79, #TTS.runtimeQueue)
        while TTS.runtimeQueueIndex <= last do
            local item = TTS.runtimeQueue[TTS.runtimeQueueIndex]
            TTS.runtimeQueueIndex = TTS.runtimeQueueIndex + 1
            if item.kind == "collectible" then
                local name, description, icon = SafeAPICall("GetCollectibleInfo", item.id)
                if type(name) == "string" and type(icon) == "string" then
                    RuntimeAddTexture(name, icon, item.category, tostring(description or "") .. " " .. item.keywords)
                end
            elseif item.kind == "collectible_background" then
                local name, description = SafeAPICall("GetCollectibleInfo", item.id)
                local artwork = SafeAPICall(item.apiName, item.id)
                if type(artwork) == "string" and artwork ~= "" then
                    local suffix = item.variant == "gamepad" and " — Gamepad Artwork" or " — Keyboard Artwork"
                    RuntimeAddTexture(tostring(name or "Collectible") .. suffix, artwork, item.category,
                        tostring(description or "") .. " " .. item.keywords .. " collectible background artwork")
                end
            elseif item.kind == "achievement" then
                local name, description, _, icon = SafeAPICall("GetAchievementInfo", item.id)
                local categoryLabel = item.categoryName or ""
                if type(name) == "string" and type(icon) == "string" and icon ~= "" then
                    local searchable = categoryLabel .. " " .. name .. " " .. tostring(description or "")
                    local category = IsTrialTopic(searchable) and "Trials & Achievements" or "Achievements & Rewards"
                    RuntimeAddTexture(name, icon, category, searchable .. " achievement trophy reward emblem")
                end
            elseif item.kind == "skill" then
                local name, icon = SafeAPICall("GetSkillAbilityInfo", item.skillType, item.lineIndex, item.abilityIndex)
                if type(icon) == "string" and icon ~= "" then
                    local skillName = type(name) == "string" and name ~= "" and name or ("Skill " .. item.abilityIndex)
                    local searchable = skillName .. " " .. item.skillTypeName .. " " .. item.lineName .. " ability skill combat"
                    RuntimeAddTexture(skillName, icon, "Skills & Abilities", searchable)
                end
            end
        end
        TTS.runtimeScanBatches = TTS.runtimeScanBatches + 1
        if TTS.runtimeQueueIndex <= #TTS.runtimeQueue and type(zo_callLater) == "function" then
            zo_callLater(ProcessBatch, 15)
        elseif TTS.runtimeQueueIndex > #TTS.runtimeQueue then
            TTS.runtimeQueue = nil
            TTS.runtimeIndexComplete = true
            TTS.texturePathSet = nil
            TTS.menuResultCache = nil
        end
    end

    if #queue == 0 then
        TTS.runtimeIndexComplete = true
        return
    end
    if type(zo_callLater) == "function" then
        zo_callLater(ProcessBatch, 250)
    else
        while TTS.runtimeQueue and TTS.runtimeQueueIndex <= #TTS.runtimeQueue do ProcessBatch() end
    end
end

-- Native, controller-friendly settings-menu experience.
local MAX_MENU_TEXTURES = 72
local COMMON_COLOR_PRESETS = {
    {name="Gold", hex="FFD700"}, {name="White", hex="FFFFFF"},
    {name="Amber", hex="FFB000"}, {name="Orange", hex="FF8C42"},
    {name="Red", hex="FF4545"}, {name="Crimson", hex="DC143C"},
    {name="Pink", hex="FF69B4"}, {name="Magenta", hex="D94BFF"},
    {name="Purple", hex="9B59B6"}, {name="Royal Blue", hex="4169E1"},
    {name="Sky Blue", hex="65BFFF"}, {name="Cyan", hex="36D6E7"},
    {name="Teal", hex="20CFCF"}, {name="Emerald", hex="00C781"},
    {name="Green", hex="48C774"}, {name="Lime", hex="A3E635"},
    {name="Silver", hex="C0C0C0"}, {name="Charcoal", hex="525760"},
}

local function StripTextureSlash(path)
    path = Trim(tostring(path or ""))
    path = path:gsub("^[/\\]+", "")
    path = path:gsub("\\", "/")
    return path
end

local function EnsurePathLookup()
    if TTS.pathIndexByPath and TTS.pathIndexCount == #(TTS.textures or {}) then return end
    TTS.pathIndexByPath = {}
    for index, texture in ipairs(TTS.textures or {}) do
        if type(texture.path) == "string" and not TTS.pathIndexByPath[StripTextureSlash(texture.path)] then
            TTS.pathIndexByPath[StripTextureSlash(texture.path)] = index
        end
    end
    TTS.pathIndexCount = #(TTS.textures or {})
end

local function FindTextureIndexByPath(path)
    EnsurePathLookup()
    return TTS.pathIndexByPath[StripTextureSlash(path)]
end

local function SetSelectedCatalogPath(path)
    local index = FindTextureIndexByPath(path)
    if not index then return false end
    TTS.saved.textureIndex = index
    TTS.saved.customPath = ""
    TTS.saved.customTextureName = nil
    TTS.menuResultCache = nil
    SyncGeneratedOutput()
    return true
end

local function MenuQueryWords()
    local normalized = NormalizeSearchText(TTS.saved.search or "")
    local words = {}
    for word in normalized:gmatch("%S+") do words[#words + 1] = word end
    return words
end

local function GetMenuTextureResults()
    local category = CATEGORIES[TTS.saved.textureCategory] or CATEGORIES[1]
    local query = NormalizeSearchText(TTS.saved.search or "")
    local favoriteRevision = tonumber(TTS.favoriteRevision) or 0
    local key = query .. "\31" .. category .. "\31" .. tostring(#(TTS.textures or {})) .. "\31" .. tostring(favoriteRevision)
    if TTS.menuResultCache and TTS.menuResultCache.key == key then
        return TTS.menuResultCache.results, TTS.menuResultCache.total
    end

    local results, total = {}, 0
    local words, seen = MenuQueryWords(), {}
    local function Consider(texture)
        if type(texture) ~= "table" or type(texture.path) ~= "string" or texture.path == "" then return end
        local path = StripTextureSlash(texture.path)
        if seen[path] then return end
        seen[path] = true
        if MatchesCategory(texture, category) and QueryMatches(texture._ttsSearchText or AddSearchCache(texture)._ttsSearchText, words) then
            total = total + 1
            if #results < MAX_MENU_TEXTURES then results[#results + 1] = texture end
        end
    end

    for _, texture in ipairs(TTS.textures or {}) do Consider(texture) end

    if category == "Favorites" then
        for path, favorite in pairs(TTS.saved.favorites or {}) do
            local normalizedPath = StripTextureSlash(path)
            if favorite and not seen[normalizedPath] then
                local texture = AddSearchCache({
                    name = "Saved texture: " .. FriendlyNameFromPath(normalizedPath),
                    path = normalizedPath, category = "Favorites", keywords = "saved custom favorite",
                })
                Consider(texture)
            end
        end
    end

    TTS.menuResultCache = { key = key, results = results, total = total }
    return results, total
end

local function GetCategoryItems()
    local items = {}
    for _, category in ipairs(CATEGORIES) do items[#items + 1] = { name = category, data = category } end
    return items
end

local function GetTargetItems()
    local items = {}
    for _, target in ipairs(TARGETS) do items[#items + 1] = { name = target.name, data = target.name } end
    return items
end

local function GetColorTargetItems()
    local items = {}
    for _, target in ipairs(COLOR_TARGETS) do items[#items + 1] = { name = target, data = target } end
    return items
end

local function GetSizeItems()
    local items = {}
    for _, size in ipairs(SIZES) do items[#items + 1] = { name = tostring(size) .. " px", data = size } end
    return items
end

local function GetPositionItems()
    local items = {}
    for _, position in ipairs(POSITIONS) do items[#items + 1] = { name = position, data = position } end
    return items
end

local function GetSeparatorItems()
    local items = {}
    for _, separator in ipairs(SEPARATORS) do items[#items + 1] = { name = separator, data = separator } end
    return items
end

local function CurrentColorName()
    local hex = CurrentTargetHex()
    for _, color in ipairs(COMMON_COLOR_PRESETS) do
        if color.hex == hex then return color.name end
    end
    return "Custom (#" .. hex .. ")"
end

local function GetColorPresetItems()
    local items, found = {}, false
    local currentHex = CurrentTargetHex()
    for _, color in ipairs(COMMON_COLOR_PRESETS) do
        items[#items + 1] = { name = color.name, data = color.hex }
        if color.hex == currentHex then found = true end
    end
    if not found then
        items[#items + 1] = { name = "Custom (#" .. currentHex .. ")", data = currentHex }
    end
    return items
end

local function GetPickerPaths()
    local results = GetMenuTextureResults()
    local paths = {}
    for _, texture in ipairs(results) do
        paths[#paths + 1] = "/" .. StripTextureSlash(texture.path)
    end
    return paths
end

local function GetPickerSelectedIndex()
    local results = GetMenuTextureResults()
    local currentPath = StripTextureSlash(CurrentPath())
    for index, texture in ipairs(results) do
        if StripTextureSlash(texture.path) == currentPath then return index end
    end
    return 1
end

local function BuildNativePreview()
    local saved = TTS.saved
    local title = Trim(saved.title or "")
    local body = Trim(saved.body or "")
    if #body > 150 then body = body:sub(1, 147) .. "..." end
    local icon = saved.iconEnabled and string.format("|t%d:%d:%s|t", math.min(64, tonumber(saved.iconSize) or 32), math.min(64, tonumber(saved.iconSize) or 32), CurrentPath()) or ""
    local titleColor = (saved.titleHex == "FFFFFF" and not saved.explicitWhiteSelected) and DEFAULT_COLOR or saved.titleHex
    local dividerColor = (saved.dividerHex == "FFFFFF" and not saved.explicitWhiteSelected) and DEFAULT_COLOR or saved.dividerHex
    local bodyColor = (saved.bodyHex == "FFFFFF" and not saved.explicitWhiteSelected) and DEFAULT_COLOR or saved.bodyHex

    local lines = {}
    if title ~= "" then
        if saved.iconEnabled and (saved.iconPosition == 1 or saved.iconPosition == 3) then
            lines[#lines + 1] = icon .. " " .. WrapColor(title, titleColor)
        else
            lines[#lines + 1] = WrapColor(title, titleColor)
        end
    elseif saved.iconEnabled and (saved.iconPosition == 1 or saved.iconPosition == 3) then
        lines[#lines + 1] = icon
    end
    local separator = SEPARATORS[saved.separator] or "None"
    if separator ~= "None" then lines[#lines + 1] = WrapColor(separator, dividerColor) end
    if body ~= "" then lines[#lines + 1] = WrapColor(body, bodyColor) end
    if saved.iconEnabled and (saved.iconPosition == 2 or saved.iconPosition == 3) then lines[#lines + 1] = icon end
    if #lines == 0 then return "|cAAAAAAYour live preview will appear here as you compose a message.|r" end
    return "|cD9B45BLIVE FORMATTED PREVIEW|r\n" .. table.concat(lines, "\n")
end

local function BuildVisibleRawMarkupBox()
    local output = SyncGeneratedOutput()
    local escaped = FormatVisibleMarkupForDisplay(output)
    return "|cD9B45BVISIBLE RAW MARKUP BOX (FOR MANUAL WRITE-DOWN — OMIT SPACE AFTER '|')|r\n|cFFFFFF" .. escaped .. "|r"
end

local function BuildNativeStatus()
    local results, total = GetMenuTextureResults()
    local output = SyncGeneratedOutput()
    local discovery = TTS.runtimeIndexComplete and "ESO asset discovery complete" or "discovering additional ESO assets in background"
    local showing = math.min(total or 0, MAX_MENU_TEXTURES)
    return string.format("Search matches: %d | thumbnails available here: %d | indexed paths: %d | %s\nGenerated output length: %d / %d characters for %s  |  Active Color: #%s (Heading #%s, Message #%s, Divider #%s)",
        tonumber(total) or 0, showing, #(TTS.textures or {}), discovery, #output, CurrentTarget().limit, CurrentTarget().name,
        CurrentTargetHex(), TTS.saved.titleHex or DEFAULT_COLOR, TTS.saved.bodyHex or DEFAULT_COLOR, TTS.saved.dividerHex or DEFAULT_COLOR)
end

local function StoreOutput()
    SyncGeneratedOutput()
end

local function ResetComposerText()
    TTS.saved.title = "Welcome to our guild!"
    TTS.saved.body = "Add your message here."
    SyncGeneratedOutput()
end

local function ToggleCurrentFavorite()
    local path = StripTextureSlash(CurrentPath())
    if path == "" then return end
    TTS.saved.favorites = TTS.saved.favorites or {}
    if TTS.saved.favorites[path] then
        TTS.saved.favorites[path] = nil
    else
        TTS.saved.favorites[path] = true
    end
    TTS.favoriteRevision = (TTS.favoriteRevision or 0) + 1
    TTS.menuResultCache = nil
    Persist()
end

local function ExtractRGBFromArgs(...)
    local argc = select("#", ...)
    if argc == 0 then return nil end
    local a1, a2, a3, a4 = ...

    if type(a1) == "table" then
        if type(a1.UnpackRGB) == "function" then
            local ok, r, g, b = pcall(a1.UnpackRGB, a1)
            if ok and tonumber(r) and tonumber(g) and tonumber(b) then
                return tonumber(r), tonumber(g), tonumber(b)
            end
        end
        local tr = tonumber(a1.r or a1[1])
        local tg = tonumber(a1.g or a1[2])
        local tb = tonumber(a1.b or a1[3])
        if tr and tg and tb then return tr, tg, tb end
        if type(a2) == "table" then
            if type(a2.UnpackRGB) == "function" then
                local ok, r, g, b = pcall(a2.UnpackRGB, a2)
                if ok and tonumber(r) and tonumber(g) and tonumber(b) then
                    return tonumber(r), tonumber(g), tonumber(b)
                end
            end
            local r2 = tonumber(a2.r or a2[1])
            local g2 = tonumber(a2.g or a2[2])
            local b2 = tonumber(a2.b or a2[3])
            if r2 and g2 and b2 then return r2, g2, b2 end
        end
        if tonumber(a2) and tonumber(a3) and tonumber(a4) then
            return tonumber(a2), tonumber(a3), tonumber(a4)
        end
    elseif type(a1) == "userdata" then
        if tonumber(a2) and tonumber(a3) and tonumber(a4) then
            return tonumber(a2), tonumber(a3), tonumber(a4)
        end
    elseif type(a1) == "string" then
        local hex = NormalizeHex(a1)
        if hex then
            return HexToRGB(hex)
        end
    end

    local r, g, b = tonumber(a1), tonumber(a2), tonumber(a3)
    if r and g and b then
        return r, g, b
    end
    return nil
end

local function ApplyPickedColor(...)
    local r, g, b = ExtractRGBFromArgs(...)
    if not r or not g or not b then return false end
    if r > 1 or g > 1 or b > 1 then
        r, g, b = r / 255, g / 255, b / 255
    end
    r = math.max(0, math.min(1, r))
    g = math.max(0, math.min(1, g))
    b = math.max(0, math.min(1, b))
    local hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))

    if hex == "FFFFFF" then
        return false
    end

    if not ApplyHexToTarget(hex, false) then return false end
    TTS.saved.activeHex = hex
    SyncGeneratedOutput()
    TTS.menuResultCache = nil

    -- Do not refresh the panel from this callback. It is invoked by ESO's shared Gamepad color dialog.
    -- The saved color and generated output are updated immediately; the panel's controls are rebuilt
    -- naturally the next time the user opens Tamriel Text Studio.
    return true
end

local function RegisterNativeSettingsMenu()
    local settingsLib = _G.LibHarvensAddonSettings or _G.LibVotans
    if not settingsLib or type(settingsLib.AddAddon) ~= "function" then
        TTS.menuReady = false
        return false
    end
    TTS.settingsLib = settingsLib
    local panel = settingsLib:AddAddon("Tamriel Text Studio", {
        allowDefaults = true,
        allowRefresh = true,
        defaultsFunction = function()
            TTS.saved.target = 1
            TTS.saved.colorTarget = 1
            TTS.saved.activeHex = DEFAULT_COLOR
            TTS.saved.titleHex = DEFAULT_COLOR
            TTS.saved.bodyHex = DEFAULT_COLOR
            TTS.saved.dividerHex = DEFAULT_COLOR
            TTS.saved.explicitWhiteSelected = false
            TTS.saved.title = "Welcome to our guild!"
            TTS.saved.body = "Add your message here."
            TTS.saved.search = ""
            TTS.saved.textureCategory = 1
            TTS.saved.iconSize = 32
            TTS.saved.iconEnabled = true
            TTS.saved.iconPosition = 1
            TTS.saved.separator = 1
            TTS.saved.customPath = ""
            TTS.saved.customTextureName = nil
            TTS.saved.texturePage = 1
            TTS.menuResultCache = nil
            SyncGeneratedOutput()
        end,
    })
    if not panel or type(panel.AddSetting) ~= "function" then return false end
    TTS.settingsPanel = panel

    local function Add(settingType, params)
        params.type = settingType
        return panel:AddSetting(params)
    end
    local function DropdownData(name, item)
        if type(item) == "table" then
            if item.data ~= nil then return item.data end
            if item.name ~= nil then return item.name end
        end
        if item ~= nil then return item end
        return name
    end

    local function SetTargetByName(_, name, item)
        local selectedName = tostring(DropdownData(name, item) or "Guild MOTD")
        for index, target in ipairs(TARGETS) do
            if target.name == selectedName then TTS.saved.target = index break end
        end
        SyncGeneratedOutput()
    end
    local function SetCategoryByName(_, name, item)
        local wanted = tostring(DropdownData(name, item) or "All textures")
        for index, category in ipairs(CATEGORIES) do
            if category == wanted then TTS.saved.textureCategory = index break end
        end
        TTS.saved.texturePage = 1
        TTS.menuResultCache = nil
        local results = GetMenuTextureResults()
        if results[1] then SetSelectedCatalogPath(results[1].path) end
        SyncGeneratedOutput()
    end
    local function SetColorTargetByName(_, name, item)
        local wanted = tostring(DropdownData(name, item) or "All text")
        for index, target in ipairs(COLOR_TARGETS) do
            if target == wanted then TTS.saved.colorTarget = index break end
        end
        TTS.saved.activeHex = CurrentTargetHex()
        SyncGeneratedOutput()
    end
    local function SetSearch(value)
        TTS.saved.search = Trim(tostring(value or ""))
        TTS.saved.texturePage = 1
        TTS.menuResultCache = nil
        local results = GetMenuTextureResults()
        if results[1] then SetSelectedCatalogPath(results[1].path) end
        SyncGeneratedOutput()
    end

    Add(settingsLib.ST_SECTION, {
        label = "START HERE — FOLLOW THESE STEPS",
        tooltip = "This tool lives entirely in Settings > Add-ons. You do not need a chat command or any separate pop-up window.",
    })
    Add(settingsLib.ST_LABEL, {
        label = "1. Choose a destination.  2. Enter a heading/message.  3. Search and select artwork.  4. Choose colors and style.  5. Highlight 'Output markup (press X to select / copy)' below and press X on your PS5 controller to open the on-screen keyboard and copy your text, or read the Visible Raw Markup box below it.",
        tooltip = "Settings controls are controller-friendly. The add-on never changes guild information without your action.",
    })

    Add(settingsLib.ST_SECTION, { label = "1 — MESSAGE" })
    Add(settingsLib.ST_DROPDOWN, {
        label = "Destination field",
        tooltip = "Choose a field so the add-on can estimate the output length. The add-on will not edit the field automatically.",
        items = GetTargetItems,
        getFunction = function() return CurrentTarget().name end,
        setFunction = SetTargetByName,
        default = "Guild MOTD",
    })
    Add(settingsLib.ST_EDIT, {
        label = "Heading (optional)", tooltip = "Short heading displayed above the message.", maxChars = 500,
        getFunction = function() return TTS.saved.title end,
        setFunction = function(value)
            TTS.saved.title = tostring(value or "")
            SyncGeneratedOutput()
        end,
        default = "Welcome to our guild!",
    })
    Add(settingsLib.ST_EDIT, {
        label = "Message text",
        tooltip = "Enter your main message. Press X on your PS5 controller to edit with the on-screen keyboard.",
        maxChars = CONSOLE_MAX_EDIT_CHARS,
        getFunction = function() return TTS.saved.body end,
        setFunction = function(value)
            TTS.saved.body = tostring(value or "")
            SyncGeneratedOutput()
        end,
        default = "Add your message here.",
    })

    Add(settingsLib.ST_SECTION, { label = "2 — FIND AND PREVIEW ARTWORK" })
    Add(settingsLib.ST_EDIT, {
        label = "Search texture names",
        tooltip = "Search by ordinary words such as pet, mount, skin, trial, Cloudrest, dragonknight, or wayshrine. Search updates the icon picker below.",
        maxChars = 120,
        getFunction = function() return TTS.saved.search or "" end,
        setFunction = SetSearch,
        default = "",
    })
    Add(settingsLib.ST_DROPDOWN, {
        label = "Artwork category",
        tooltip = "Filter by skills, pets, mounts, collectibles, achievements, travel icons, interface art, or favorites.",
        items = GetCategoryItems,
        getFunction = function() return CATEGORIES[TTS.saved.textureCategory] or CATEGORIES[1] end,
        setFunction = SetCategoryByName,
        default = "All textures",
    })
    Add(settingsLib.ST_LABEL, {
        label = function()
            local _, total = GetMenuTextureResults()
            if total == 0 then return "|cFF7777No matching textures. Clear Search or choose All textures.|r" end
            return string.format("|cD9B45BARTWORK PICKER|r — select a thumbnail below. Showing up to %d of %d matches.", math.min(total, MAX_MENU_TEXTURES), total)
        end,
    })
    Add(settingsLib.ST_ICONPICKER, {
        label = "Select artwork thumbnail",
        tooltip = "Choose a picture from the filtered thumbnail grid. The selected image is shown in the preview below and can be inserted into generated text.",
        items = GetPickerPaths,
        getFunction = GetPickerSelectedIndex,
        setFunction = function(_, iconIndex, iconPath)
            if iconPath and SetSelectedCatalogPath(iconPath) then
                TTS.menuResultCache = nil
                SyncGeneratedOutput()
            end
        end,
        default = 1,
    })
    Add(settingsLib.ST_LABEL, {
        label = function()
            local path = CurrentPath()
            local name = CurrentTextureName()
            return "|cD9B45BSELECTED TEXTURE|r\n|t56:56:" .. path .. "|t   |cFFFFFF" .. tostring(name) .. "|r\n|cAAAAAA" .. StripTextureSlash(path) .. "|r"
        end,
        tooltip = "This is the actual selected texture path. The image preview is generated by the ESO client.",
    })
    Add(settingsLib.ST_BUTTON, {
        label = "Favorites",
        buttonText = function() return IsFavorite(StripTextureSlash(CurrentPath())) and "REMOVE SELECTED FROM FAVORITES" or "SAVE SELECTED AS FAVORITE" end,
        tooltip = "Save the selected texture so you can find it under the Favorites category.",
        clickHandler = ToggleCurrentFavorite,
    })
    Add(settingsLib.ST_EDIT, {
        label = "Advanced texture path (optional)",
        tooltip = "Most players never need this. Use only if you already know a valid ESO texture path. Selecting a thumbnail clears this custom path.",
        maxChars = 300,
        getFunction = function() return TTS.saved.customPath or "" end,
        setFunction = function(value)
            TTS.saved.customPath = StripTextureSlash(value)
            TTS.saved.customTextureName = TTS.saved.customPath ~= "" and ("Custom: " .. FriendlyNameFromPath(TTS.saved.customPath)) or nil
            SyncGeneratedOutput()
        end,
        default = "",
    })
    Add(settingsLib.ST_BUTTON, {
        label = "Use selected gallery texture",
        buttonText = "CLEAR ADVANCED PATH",
        tooltip = "Return to the texture chosen from the visual gallery.",
        clickHandler = function()
            TTS.saved.customPath = ""
            TTS.saved.customTextureName = nil
            SyncGeneratedOutput()
        end,
    })

    Add(settingsLib.ST_SECTION, { label = "3 — COLOR AND STYLE" })
    Add(settingsLib.ST_DROPDOWN, {
        label = "Apply color to",
        tooltip = "Choose which part of the generated message the color picker changes.",
        items = GetColorTargetItems,
        getFunction = function() return COLOR_TARGETS[TTS.saved.colorTarget] or COLOR_TARGETS[1] end,
        setFunction = SetColorTargetByName,
        default = "All text",
    })
    TTS.colorSetting = Add(settingsLib.ST_COLOR, {
        label = "Choose custom color (Color Wheel)",
        tooltip = "Open the ESO color wheel, pick your shade, and press X. The selected HEX and generated markup are saved immediately. Back out and reopen this panel to refresh the visible preview.",
        getFunction = function()
            local hex = CurrentTargetHex()
            if hex == "FFFFFF" and not TTS.saved.explicitWhiteSelected then
                hex = DEFAULT_COLOR
            end
            local r, g, b = HexToRGB(hex)
            return r, g, b, 1
        end,
        setFunction = function(...)
            ApplyPickedColor(...)
        end,
        default = {1, 0.843, 0, 1},
    })
    Add(settingsLib.ST_DROPDOWN, {
        label = "Quick color preset",
        tooltip = "Named color presets (including Gold and White). Use Choose custom color above for any custom shade on the color wheel.",
        items = GetColorPresetItems,
        getFunction = CurrentColorName,
        setFunction = function(_, name, item)
            local normalized = NormalizeHex(DropdownData(name, item))
            if normalized then
                ApplyHexToTarget(normalized, true)
                TTS.saved.activeHex = normalized
                SyncGeneratedOutput()
            end
        end,
        default = "Gold",
    })
    Add(settingsLib.ST_EDIT, {
        label = "Custom color HEX code",
        tooltip = "Shows the current 6-digit HEX color (such as FFD700 or 448AFF). You can also press X here to type any 6-digit HEX color directly.",
        maxChars = 7,
        getFunction = function() return CurrentTargetHex() end,
        setFunction = function(value)
            local normalized = NormalizeHex(value)
            if normalized then
                ApplyHexToTarget(normalized, true)
                TTS.saved.activeHex = normalized
                SyncGeneratedOutput()
            end
        end,
        default = DEFAULT_COLOR,
    })
    Add(settingsLib.ST_CHECKBOX, {
        label = "Include selected image in message",
        tooltip = "Turn the inline texture on or off without changing your selected artwork.",
        getFunction = function() return TTS.saved.iconEnabled end,
        setFunction = function(value)
            TTS.saved.iconEnabled = value == true
            SyncGeneratedOutput()
        end,
        default = true,
    })
    Add(settingsLib.ST_DROPDOWN, {
        label = "Image size",
        tooltip = "Set the inline texture dimensions in the generated message.",
        items = GetSizeItems,
        getFunction = function() return tostring(TTS.saved.iconSize or 32) .. " px" end,
        setFunction = function(_, name, item)
            local value = DropdownData(name, item)
            TTS.saved.iconSize = tonumber(value) or tonumber(tostring(name):match("%d+")) or 32
            SyncGeneratedOutput()
        end,
        default = "32 px",
    })
    Add(settingsLib.ST_EDIT, {
        label = "Custom image size (pixels)",
        tooltip = "Enter a square inline image size from 8 to 256 pixels. The default remains 32 px unless you change it. This setting affects generated markup, not the preview panel dimensions.",
        maxChars = 3,
        getFunction = function() return tostring(TTS.saved.iconSize or 32) end,
        setFunction = function(value)
            local size = tonumber(tostring(value or ""):match("^%s*(%d+)%s*$"))
            if size and size >= 8 and size <= 256 then
                TTS.saved.iconSize = math.floor(size)
                SyncGeneratedOutput()
            end
        end,
        default = "32",
    })

    Add(settingsLib.ST_DROPDOWN, {
        label = "Image placement",
        tooltip = "Put the image at the start, end, or both positions in the generated message.",
        items = GetPositionItems,
        getFunction = function() return POSITIONS[TTS.saved.iconPosition] or "Start" end,
        setFunction = function(_, name, item)
            local wanted = tostring(DropdownData(name, item) or "Start")
            for index, position in ipairs(POSITIONS) do if position == wanted then TTS.saved.iconPosition = index break end end
            SyncGeneratedOutput()
        end,
        default = "Start",
    })
    Add(settingsLib.ST_DROPDOWN, {
        label = "Decorative divider",
        tooltip = "Optional separator between heading and message.",
        items = GetSeparatorItems,
        getFunction = function() return SEPARATORS[TTS.saved.separator] or "None" end,
        setFunction = function(_, name, item)
            local wanted = tostring(DropdownData(name, item) or "None")
            for index, divider in ipairs(SEPARATORS) do if divider == wanted then TTS.saved.separator = index break end end
            SyncGeneratedOutput()
        end,
        default = "None",
    })

    Add(settingsLib.ST_SECTION, { label = "4 — PREVIEW AND OUTPUT (REOPEN PANEL TO REFRESH)" })
    Add(settingsLib.ST_LABEL, {
        label = BuildNativePreview,
        tooltip = "This shows a live rendered preview of your selected colors, image and message styling.",
    })
    Add(settingsLib.ST_LABEL, {
        label = BuildNativeStatus,
        tooltip = "Shows your character count estimate and currently active HEX colors.",
    })
    -- Primary Output Text Field: maxChars = 2000 (<= 2048 console VirtualKeyboard limit) so pressing X on PS5
    -- opens the native PS5 on-screen popup keyboard directly.
    -- Note: setFunction does NOT call synchronously so closing the PS5 keyboard never taints ESOUI dialogs.
    Add(settingsLib.ST_EDIT, {
        label = "Output markup (press X to select / copy)",
        tooltip = "Highlight this row and press X on your PS5 controller to open the native PS5 on-screen popup keyboard with your generated markup prefilled. Select All and Copy it to your clipboard, then back out.",
        maxChars = CONSOLE_MAX_EDIT_CHARS,
        getFunction = function()
            return SyncGeneratedOutput()
        end,
        setFunction = function(value)
            local trimmed = Trim(tostring(value or ""))
            if trimmed ~= "" then
                TTS.saved.output = trimmed:gsub("\226\128\139", "")
            else
                TTS.saved.output = CreateOutputText()
            end
            Persist()
        end,
        default = "",
    })
    -- Second separate visible box showing the unrendered literal raw markup text for manual reading/writing down
    Add(settingsLib.ST_LABEL, {
        label = BuildVisibleRawMarkupBox,
        tooltip = "Displays the exact raw markup code with all |cHEX, |r, and |t...:...|t tags visible on screen in case you want to read it or write it down by hand.",
    })
    Add(settingsLib.ST_BUTTON, {
        label = "Rebuild generated markup",
        buttonText = "REBUILD OUTPUT DATA",
        tooltip = "Rebuild and save the generated markup. To refresh the visible preview and labels, back out of Tamriel Text Studio and reopen it. This button does not touch ESO Gamepad UI controls.",
        clickHandler = StoreOutput,
    })
    Add(settingsLib.ST_BUTTON, {
        label = "Start over with sample text",
        buttonText = "RESET HEADING AND MESSAGE",
        tooltip = "Reset only the heading and message text. Your favorite textures and other choices are preserved.",
        clickHandler = ResetComposerText,
    })
    Add(settingsLib.ST_LABEL, {
        label = "Developer: CRY | Tamriel Text Studio does not automatically edit or save guild fields.",
    })

    TTS.menuReady = true
    SyncGeneratedOutput()
    return true
end

-- No add-on-driven settings-panel refresh is performed. See the security rules at the top of this file.

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    TTS.saved = GetSaved()
    TTS.textures = BuildUniqueCatalog()
    MigrateTextureSelection(TTS.saved, TTS.textures)
    TTS.favoriteRevision = 0
    RegisterNativeSettingsMenu()
    StartRuntimeTextureIndex()
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
