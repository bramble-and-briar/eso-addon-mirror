-- Tamriel Text Studio
-- Console-conscious ESO text composer for fields which support ESO inline markup.
-- Developer: CRY | Version 2.3.6 uses ESO console chat text-entry from the HUD and avoids refreshing settings while the color picker is active.
-- It never edits or sends guild data on its own. LibVotans (console package name) supplies the Settings menu.

local ADDON_NAME = "TamrielTextStudio"
local TTS = {}
local RefreshNativeSettings
local OpenOutputInNativeTextEntry
local WM = WINDOW_MANAGER
local PANEL_W, PANEL_H = 1180, 840
local DEFAULT_COLOR = "FFD700"
local DEFAULT_TEXTURE_PATH = "esoui/art/icons/pet_081.dds"
local VISIBLE_TEXTURES = 12

local COLOR_TARGETS = { "All text", "Heading", "Message", "Divider" }
local TARGETS = {
    { name = "Guild MOTD", limit = 2048 },
    { name = "Guild About Us", limit = 2048 },
    { name = "Guild Member Note", limit = 255 },
    { name = "Custom / Other", limit = 2048 },
}
local CATEGORIES = {
    -- Keep the original first nine positions so existing saved category settings stay valid.
    "All textures", "Icons & Skills", "Map & Travel", "Factions",
    "Pets & Creatures", "Services", "Crafting & Items", "Decorative / UI", "Favorites",
    "Skills & Abilities", "Trials & Achievements", "Skins & Collectibles",
    "Mounts & Companions", "Artwork & UI", "Achievements & Rewards",
}
local SIZES = { 16, 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 80, 96, 112, 120, 128, 144, 160, 192, 256 }
local POSITIONS = { "Start", "End", "Both" }
local SEPARATORS = { "None", "-----", "* * *", "=====", "- - -", "< > < >" }

-- Named swatches mean the user does not need to source hex codes. A custom HEX field
-- remains available for exact colors that are not in the preset palette.
local COLORS = {
    {name="White",hex="FFFFFF"}, {name="Snow",hex="FFF7F0"}, {name="Cream",hex="FFF1CC"}, {name="Gold",hex="FFD700"},
    {name="Amber",hex="FFB000"}, {name="Orange",hex="FF8C42"}, {name="Coral",hex="FF7F50"}, {name="Peach",hex="FFBFA3"},
    {name="Red",hex="FF4545"}, {name="Crimson",hex="DC143C"}, {name="Rose",hex="FF6688"}, {name="Pink",hex="FF69B4"},
    {name="Hot Pink",hex="FF3FA4"}, {name="Magenta",hex="D94BFF"}, {name="Violet",hex="A66BFF"}, {name="Purple",hex="9B59B6"},
    {name="Indigo",hex="5C6BC0"}, {name="Royal Blue",hex="4169E1"}, {name="Blue",hex="448AFF"}, {name="Sky",hex="65BFFF"},
    {name="Cyan",hex="36D6E7"}, {name="Teal",hex="20CFCF"}, {name="Mint",hex="68E7C1"}, {name="Emerald",hex="00C781"},
    {name="Green",hex="48C774"}, {name="Lime",hex="A3E635"}, {name="Yellow",hex="FFE66D"}, {name="Olive",hex="A6A63B"},
    {name="Brown",hex="A66A3F"}, {name="Copper",hex="B87333"}, {name="Tan",hex="D2B48C"}, {name="Sand",hex="DCC9A5"},
    {name="Silver",hex="C0C0C0"}, {name="Slate",hex="8796A5"}, {name="Gray",hex="9E9E9E"}, {name="Charcoal",hex="525760"},
    {name="Lavender",hex="D8B4FE"}, {name="Ice Blue",hex="B7E9FF"}, {name="Blood Red",hex="8B0000"}, {name="Dark Green",hex="176B3A"},
}

local function SafeCall(control, methodName, ...)
    if control and type(control[methodName]) == "function" then
        return pcall(control[methodName], control, ...)
    end
    return false
end

local function Trim(value)
    if type(value) ~= "string" then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function NormalizeHex(value)
    if type(value) ~= "string" then value = tostring(value or "") end
    value = value:gsub("#", ""):gsub("%s", ""):upper()
    if #value == 6 and value:match("^%x%x%x%x%x%x$") then return value end
    return nil
end

local function HexToRGB(hex)
    hex = NormalizeHex(hex) or DEFAULT_COLOR
    return tonumber(hex:sub(1, 2), 16) / 255,
           tonumber(hex:sub(3, 4), 16) / 255,
           tonumber(hex:sub(5, 6), 16) / 255
end

local function RGBToHSL(r, g, b)
    local maximum = math.max(r, g, b)
    local minimum = math.min(r, g, b)
    local delta = maximum - minimum
    local h, s = 0, 0
    local l = (maximum + minimum) / 2
    if delta ~= 0 then
        if l > 0.5 then s = delta / (2 - maximum - minimum) else s = delta / (maximum + minimum) end
        if maximum == r then
            h = (g - b) / delta + (g < b and 6 or 0)
        elseif maximum == g then
            h = (b - r) / delta + 2
        else
            h = (r - g) / delta + 4
        end
        h = h / 6
    end
    return h, s, l
end

local function HSLToHex(h, s, l)
    local function HueToRGB(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    local r, g, b
    if s == 0 then
        r, g, b = l, l, l
    else
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        r = HueToRGB(p, q, h + 1 / 3)
        g = HueToRGB(p, q, h)
        b = HueToRGB(p, q, h - 1 / 3)
    end
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function WrapColor(text, hex)
    if text == nil or text == "" then return "" end
    return "|c" .. (NormalizeHex(hex) or DEFAULT_COLOR) .. text .. "|r"
end

local function CreateBackdrop(name, parent, x, y, w, h, isPanel)
    local back = WM:CreateControl(name, parent, CT_BACKDROP)
    back:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    back:SetDimensions(w, h)
    if isPanel then
        back:SetCenterColor(0.035, 0.035, 0.045, 0.98)
        back:SetEdgeColor(0.70, 0.53, 0.20, 0.98)
    else
        back:SetCenterColor(0.018, 0.020, 0.028, 0.98)
        back:SetEdgeColor(0.34, 0.34, 0.37, 1)
    end
    return back
end

local function CreateLabel(parent, name, text, x, y, w, h, font, color)
    local control = WM:CreateControl(name, parent, CT_LABEL)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(w, h)
    control:SetFont(font or "ZoFontGame")
    control:SetText(text or "")
    local c = color or 0.92
    control:SetColor(c, c, c, 1)
    control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return control
end

local function CreateButton(parent, name, text, x, y, w, h, callback)
    local back = CreateBackdrop(name .. "Backdrop", parent, x, y, w, h, false)
    local button = WM:CreateControl(name, parent, CT_BUTTON)
    button:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    button:SetDimensions(w, h)
    button:SetFont("ZoFontGame")
    button:SetText(text or "")
    button:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    button:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    button:SetNormalFontColor(0.96, 0.90, 0.76, 1)
    button:SetMouseEnabled(true)
    button:SetHandler("OnClicked", function() if callback then callback() end end)
    return button, back
end

local function CreateEdit(parent, name, text, x, y, w, h, maxChars, multiline)
    CreateBackdrop(name .. "Backdrop", parent, x, y, w, h, false)
    local edit = WM:CreateControl(name, parent, CT_EDITBOX)
    edit:SetAnchor(TOPLEFT, parent, TOPLEFT, x + 7, y + 3)
    edit:SetDimensions(w - 14, h - 6)
    edit:SetFont("ZoFontGame")
    edit:SetText(text or "")
    edit:SetMaxInputChars(maxChars or 2048)
    SafeCall(edit, "SetEditEnabled", true)
    SafeCall(edit, "SetMouseEnabled", true)
    SafeCall(edit, "SetKeyboardEnabled", true)
    SafeCall(edit, "SetMultiLine", multiline == true)
    return edit
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
    -- A complete, offline-extracted ESO path database can be placed in
    -- TTS_FULL_TEXTURE_PATHS. Add-ons cannot scan the game's MNF archives at runtime.
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
    -- Migrate settings from the earlier first build without losing the user's text.
    if type(saved) ~= "table" and type(GuildMarkupStudioSaved) == "table" then
        saved = GuildMarkupStudioSaved
    end
    if type(saved) ~= "table" then saved = {} end
    saved.target = math.max(1, math.min(#TARGETS, tonumber(saved.target) or 1))
    saved.colorTarget = math.max(1, math.min(#COLOR_TARGETS, tonumber(saved.colorTarget) or 1))
    saved.titleHex = NormalizeHex(saved.titleHex or saved.colorHex) or DEFAULT_COLOR
    saved.bodyHex = NormalizeHex(saved.bodyHex or saved.colorHex) or "FFFFFF"
    saved.dividerHex = NormalizeHex(saved.dividerHex or saved.colorHex) or DEFAULT_COLOR
    saved.activeHex = NormalizeHex(saved.activeHex or saved.colorHex) or DEFAULT_COLOR
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
    local target = TTS.saved.colorTarget
    if target == 2 then return TTS.saved.titleHex end
    if target == 3 then return TTS.saved.bodyHex end
    if target == 4 then return TTS.saved.dividerHex end
    return TTS.saved.activeHex
end

local function ApplyHexToTarget(hex)
    hex = NormalizeHex(hex)
    if not hex then return false end
    TTS.saved.activeHex = hex
    local target = TTS.saved.colorTarget
    if target == 1 then
        TTS.saved.titleHex, TTS.saved.bodyHex, TTS.saved.dividerHex = hex, hex, hex
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
    local title = Trim(TTS.titleEdit and TTS.titleEdit:GetText() or saved.title)
    local body = Trim(TTS.bodyEdit and TTS.bodyEdit:GetText() or saved.body)
    local separator = SEPARATORS[saved.separator] or "None"
    local icon = ""
    if saved.iconEnabled then
        local size = tonumber(saved.iconSize) or 32
        icon = string.format("|t%d:%d:%s|t", size, size, CurrentPath())
    end

    local lines = {}
    local function AddLine(line)
        if line and line ~= "" then lines[#lines + 1] = line end
    end
    if saved.iconEnabled and (saved.iconPosition == 1 or saved.iconPosition == 3) then
        if title ~= "" then
            AddLine(icon .. " " .. WrapColor(title, saved.titleHex))
        else
            AddLine(icon)
        end
    elseif title ~= "" then
        AddLine(WrapColor(title, saved.titleHex))
    end
    if separator ~= "None" then AddLine(WrapColor(separator, saved.dividerHex)) end
    if body ~= "" then AddLine(WrapColor(body, saved.bodyHex)) end
    if saved.iconEnabled and (saved.iconPosition == 2 or saved.iconPosition == 3) then
        AddLine(icon)
    end
    return table.concat(lines, "\n")
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

local function BuildFilteredTextureList()
    -- Only materialize the visible page, not every search match. This keeps RAM
    -- predictable when a full ~100,000-path index is bundled with the add-on.
    local results = {}
    local category = CATEGORIES[TTS.saved.textureCategory] or CATEGORIES[1]
    local rawQuery = Trim(TTS.searchEdit and TTS.searchEdit:GetText() or TTS.saved.search or "")
    local normalizedQuery = NormalizeSearchText(rawQuery)
    local queryWords = {}
    for word in normalizedQuery:gmatch("%S+") do queryWords[#queryWords + 1] = word end
    local page = math.max(1, tonumber(TTS.saved.texturePage) or 1)
    local startMatch = (page - 1) * VISIBLE_TEXTURES + 1
    local endMatch = startMatch + VISIBLE_TEXTURES - 1
    local totalCount = 0
    -- A seen-path map is only needed for Favorites; avoid allocating a 100k-key
    -- temporary table on every ordinary search when the full path index is enabled.
    local listedPaths = category == "Favorites" and {} or nil

    local function Consider(index, texture, custom)
        if listedPaths then listedPaths[texture.path] = true end
        if MatchesCategory(texture, category) and QueryMatches(texture._ttsSearchText or AddSearchCache(texture)._ttsSearchText, queryWords) then
            totalCount = totalCount + 1
            if totalCount >= startMatch and totalCount <= endMatch then
                results[#results + 1] = { index = index, texture = texture, custom = custom == true }
            end
        end
    end

    for index, texture in ipairs(TTS.textures) do Consider(index, texture, false) end

    -- Custom paths favorited in Advanced Path remain browsable in Favorites.
    if category == "Favorites" then
        for path, favorite in pairs(TTS.saved.favorites or {}) do
            if favorite and not listedPaths[path] then
                local texture = AddSearchCache({ name = "Saved: " .. FriendlyNameFromPath(path), path = path, category = "Favorites", keywords = "custom favorite saved" })
                Consider(0, texture, true)
            end
        end
    end

    local totalPages = math.max(1, math.ceil(totalCount / VISIBLE_TEXTURES))
    if page > totalPages then
        TTS.saved.texturePage = totalPages
        return BuildFilteredTextureList()
    end
    return results, totalCount
end

local function UpdateTexturePreview()
    local path = CurrentPath()
    if TTS.texturePreview then TTS.texturePreview:SetTexture(path) end
    if TTS.currentTextureName then TTS.currentTextureName:SetText(CurrentTextureName()) end
    if TTS.currentTextureHint then
        if Trim(TTS.saved.customPath or "") ~= "" then
            TTS.currentTextureHint:SetText("Custom path active")
        else
            TTS.currentTextureHint:SetText("Built-in / indexed ESO asset")
        end
    end
    if TTS.favoriteButton then
        local isFav = IsFavorite(path)
        TTS.favoriteButton:SetText(isFav and "REMOVE FAVORITE" or "ADD FAVORITE")
    end
end

local function SelectTexture(index)
    if not index or not TTS.textures[index] then return end
    TTS.saved.textureIndex = index
    TTS.saved.customPath = ""
    TTS.saved.customTextureName = nil
    if TTS.pathEdit then
        TTS.pathEdit:SetText("")
        TTS.pathEdit:SetHidden(not TTS.advancedPathVisible)
    end
    if TTS.searchEdit then TTS.saved.search = TTS.searchEdit:GetText() end
    UpdateTexturePreview()
    TTS.UpdateAll()
end

local function RefreshTextureGallery()
    if not TTS.textureTiles then return end
    local results, totalCount = BuildFilteredTextureList()
    TTS.filteredTextures = results
    totalCount = tonumber(totalCount) or 0
    local totalPages = math.max(1, math.ceil(totalCount / VISIBLE_TEXTURES))
    if TTS.saved.texturePage > totalPages then TTS.saved.texturePage = totalPages end
    if TTS.saved.texturePage < 1 then TTS.saved.texturePage = 1 end
    local startIndex = (TTS.saved.texturePage - 1) * VISIBLE_TEXTURES

    for slot = 1, VISIBLE_TEXTURES do
        local tile = TTS.textureTiles[slot]
        local result = results[slot]
        if result then
            local texture = result.texture
            tile.button:SetHidden(false)
            tile.label:SetText(texture.name)
            tile.image:SetTexture(texture.path)
            tile.image:SetHidden(false)
            tile.itemIndex = result.index
            tile.itemPath = texture.path
            local isSelected = texture.path == CurrentPath()
            tile.back:SetEdgeColor(isSelected and 0.98 or 0.30,
                                   isSelected and 0.72 or 0.30,
                                   isSelected and 0.22 or 0.34, 1)
            tile.label:SetColor(0.94, 0.92, 0.86, 1)
        else
            tile.button:SetHidden(true)
            tile.image:SetHidden(true)
            tile.label:SetText("")
            tile.itemIndex = nil
        end
    end

    local first = totalCount == 0 and 0 or startIndex + 1
    local last = math.min(startIndex + #results, totalCount)
    if TTS.texturePageStatus then
        TTS.texturePageStatus:SetText(string.format("%d–%d of %d  |  Page %d / %d", first, last, totalCount, TTS.saved.texturePage, totalPages))
    end
    if TTS.categoryButton then TTS.categoryButton:SetText("CATEGORY: " .. (CATEGORIES[TTS.saved.textureCategory] or CATEGORIES[1])) end
    UpdateTexturePreview()
    Persist()
end

local function UpdatePreviewAndOutput()
    if not TTS.preview then return end
    local title = Trim(TTS.titleEdit and TTS.titleEdit:GetText() or TTS.saved.title)
    local body = Trim(TTS.bodyEdit and TTS.bodyEdit:GetText() or TTS.saved.body)
    local separator = SEPARATORS[TTS.saved.separator] or "None"
    local previewLines = {}
    if title ~= "" then previewLines[#previewLines + 1] = WrapColor(title, TTS.saved.titleHex) end
    if separator ~= "None" then previewLines[#previewLines + 1] = WrapColor(separator, TTS.saved.dividerHex) end
    if body ~= "" then previewLines[#previewLines + 1] = WrapColor(body, TTS.saved.bodyHex) end
    TTS.preview:SetText(#previewLines > 0 and table.concat(previewLines, "\n") or "Your formatted message preview will appear here.")
    local rgbR, rgbG, rgbB = HexToRGB(TTS.saved.activeHex)
    if TTS.activeColorSample then TTS.activeColorSample:SetCenterColor(rgbR, rgbG, rgbB, 1) end
    if TTS.activeColorName then
        local foundName = "Custom color"
        for _, color in ipairs(COLORS) do
            if color.hex == TTS.saved.activeHex then foundName = color.name break end
        end
        TTS.activeColorName:SetText(foundName .. "  (#" .. TTS.saved.activeHex .. ")")
    end
    if TTS.outputEdit then TTS.outputEdit:SetText(CreateOutputText()) end
    local output = CreateOutputText()
    local target = CurrentTarget()
    local status = string.format("Length estimate: %d / %d  |  Field: %s  |  Texture: %s", #output, target.limit, target.name, CurrentTextureName())
    if #output > target.limit then status = status .. "  |  OVER ESTIMATE" else status = status .. "  |  Within estimate" end
    if TTS.status then TTS.status:SetText(status) end
    Persist()
end

function TTS.UpdateAll()
    if TTS.saved then
        TTS.saved.title = TTS.titleEdit and TTS.titleEdit:GetText() or TTS.saved.title
        TTS.saved.body = TTS.bodyEdit and TTS.bodyEdit:GetText() or TTS.saved.body
        UpdateTexturePreview()
        UpdatePreviewAndOutput()
        Persist()
    end
end

local function UpdateCaptions()
    if TTS.targetButton then TTS.targetButton:SetText("FIELD: " .. CurrentTarget().name) end
    if TTS.colorTargetButton then TTS.colorTargetButton:SetText("COLOR FOR: " .. (COLOR_TARGETS[TTS.saved.colorTarget] or "All text")) end
    if TTS.sizeButton then TTS.sizeButton:SetText("ICON SIZE: " .. tostring(TTS.saved.iconSize)) end
    if TTS.positionButton then TTS.positionButton:SetText("ICON: " .. (POSITIONS[TTS.saved.iconPosition] or "Start")) end
    if TTS.iconButton then TTS.iconButton:SetText(TTS.saved.iconEnabled and "ICON: ON" or "ICON: OFF") end
    if TTS.separatorButton then TTS.separatorButton:SetText("DIVIDER: " .. (SEPARATORS[TTS.saved.separator] or "None")) end
    if TTS.hexEdit then TTS.hexEdit:SetText(CurrentTargetHex()) end
    if TTS.advancedPathButton then TTS.advancedPathButton:SetText(TTS.advancedPathVisible and "HIDE CUSTOM PATH" or "ADVANCED PATH") end
end

local function ChangeHexTarget(step)
    local value = TTS.saved.colorTarget + (step or 1)
    if value > #COLOR_TARGETS then value = 1 end
    if value < 1 then value = #COLOR_TARGETS end
    TTS.saved.colorTarget = value
    TTS.saved.activeHex = CurrentTargetHex()
    UpdateCaptions()
    UpdatePreviewAndOutput()
end

local function ApplySelectedHex()
    local hex = NormalizeHex(TTS.hexEdit and TTS.hexEdit:GetText() or "")
    if not hex then
        if TTS.hexHint then TTS.hexHint:SetText("Use 6 HEX digits, e.g. FFCC55") end
        return
    end
    ApplyHexToTarget(hex)
    if TTS.hexHint then TTS.hexHint:SetText("Applied #" .. hex) end
    UpdatePreviewAndOutput()
end

local function ApplySwatch(index)
    local color = COLORS[index]
    if not color then return end
    ApplyHexToTarget(color.hex)
    if TTS.hexEdit then TTS.hexEdit:SetText(color.hex) end
    if TTS.hexHint then TTS.hexHint:SetText("Applied " .. color.name .. " (#" .. color.hex .. ")") end
    UpdatePreviewAndOutput()
end

local function AdjustActiveColor(component, amount)
    local r, g, b = HexToRGB(TTS.saved.activeHex)
    local h, saturation, lightness = RGBToHSL(r, g, b)
    if component == "hue" then
        h = (h + (amount / 360)) % 1
        -- A neutral gray has no hue, so the hue controls make it colorful on first use.
        if saturation < 0.08 then saturation = 0.75 end
    elseif component == "saturation" then
        saturation = math.max(0, math.min(1, saturation + amount))
    elseif component == "lightness" then
        lightness = math.max(0.04, math.min(0.96, lightness + amount))
    end
    local hex = HSLToHex(h, saturation, lightness)
    ApplyHexToTarget(hex)
    if TTS.hexEdit then TTS.hexEdit:SetText(hex) end
    if TTS.hexHint then TTS.hexHint:SetText("Fine-tuned color: #" .. hex) end
    UpdatePreviewAndOutput()
end

local function CycleSetting(key, maxValue, step)
    local value = tonumber(TTS.saved[key]) or 1
    value = value + (step or 1)
    if value > maxValue then value = 1 end
    if value < 1 then value = maxValue end
    TTS.saved[key] = value
    UpdateCaptions()
    UpdatePreviewAndOutput()
end

local function CycleSize(step)
    local currentIndex = 1
    for i, size in ipairs(SIZES) do if size == TTS.saved.iconSize then currentIndex = i break end end
    currentIndex = currentIndex + (step or 1)
    if currentIndex > #SIZES then currentIndex = 1 end
    if currentIndex < 1 then currentIndex = #SIZES end
    TTS.saved.iconSize = SIZES[currentIndex]
    UpdateCaptions()
    UpdatePreviewAndOutput()
end

local function CycleCategory(step)
    local value = TTS.saved.textureCategory + (step or 1)
    if value > #CATEGORIES then value = 1 end
    if value < 1 then value = #CATEGORIES end
    TTS.saved.textureCategory = value
    TTS.saved.texturePage = 1
    RefreshTextureGallery()
end

local function ChangeTexturePage(step)
    local _, totalCount = BuildFilteredTextureList()
    local totalPages = math.max(1, math.ceil((tonumber(totalCount) or 0) / VISIBLE_TEXTURES))
    local page = TTS.saved.texturePage + (step or 1)
    if page > totalPages then page = 1 end
    if page < 1 then page = totalPages end
    TTS.saved.texturePage = page
    RefreshTextureGallery()
end

local function ToggleFavorite()
    local path = CurrentPath()
    if IsFavorite(path) then
        TTS.saved.favorites[path] = nil
    else
        TTS.saved.favorites[path] = true
    end
    RefreshTextureGallery()
    UpdatePreviewAndOutput()
end

local function BuildOutput()
    if TTS.outputEdit then TTS.outputEdit:SetText(CreateOutputText()) end
    UpdatePreviewAndOutput()
    if TTS.buildHint then TTS.buildHint:SetText("OUTPUT UPDATED — focus the output box and select all to transfer it manually.") end
end

local function ToggleAdvancedPath()
    TTS.advancedPathVisible = not TTS.advancedPathVisible
    if TTS.pathEdit then TTS.pathEdit:SetHidden(not TTS.advancedPathVisible) end
    UpdateCaptions()
    if TTS.pathEdit and TTS.advancedPathVisible then SafeCall(TTS.pathEdit, "SetFocus") end
end

local function CreateColorSwatches()
    TTS.colorSwatches = {}
    local cellW, cellH, gapX, gapY = 57, 20, 4, 4
    local startX, startY, columns = 24, 139, 8
    for index, color in ipairs(COLORS) do
        local row = math.floor((index - 1) / columns)
        local col = (index - 1) % columns
        local x, y = startX + col * (cellW + gapX), startY + row * (cellH + gapY)
        local back = CreateBackdrop("TTSColorSwatchBackdrop" .. index, TTS.window, x, y, cellW, cellH, false)
        local r, g, b = HexToRGB(color.hex)
        back:SetCenterColor(r, g, b, 1)
        back:SetEdgeColor(0.56, 0.56, 0.58, 1)
        local button = WM:CreateControl("TTSColorSwatch" .. index, TTS.window, CT_BUTTON)
        button:SetAnchor(TOPLEFT, TTS.window, TOPLEFT, x, y)
        button:SetDimensions(cellW, cellH)
        button:SetFont("ZoFontGameSmall")
        button:SetText(color.name)
        button:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        button:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local luminance = (r * 0.299) + (g * 0.587) + (b * 0.114)
        if luminance > 0.62 then button:SetNormalFontColor(0.08, 0.08, 0.09, 1) else button:SetNormalFontColor(1, 1, 1, 1) end
        button:SetMouseEnabled(true)
        button:SetHandler("OnClicked", function() ApplySwatch(index) end)
        TTS.colorSwatches[index] = { back = back, button = button, color = color }
    end
end

local function CreateTextureTile(slot)
    local columns = 6
    local tileW, tileH, gapX, gapY = 146, 60, 7, 7
    local startX, startY = 24, 322
    local row = math.floor((slot - 1) / columns)
    local col = (slot - 1) % columns
    local x, y = startX + col * (tileW + gapX), startY + row * (tileH + gapY)
    local name = "TTSTextureTile" .. slot
    local back = CreateBackdrop(name .. "Backdrop", TTS.window, x, y, tileW, tileH, false)
    local button = WM:CreateControl(name, TTS.window, CT_BUTTON)
    button:SetAnchor(TOPLEFT, TTS.window, TOPLEFT, x, y)
    button:SetDimensions(tileW, tileH)
    button:SetText("")
    button:SetMouseEnabled(true)
    local image = WM:CreateControl(name .. "Image", TTS.window, CT_TEXTURE)
    image:SetAnchor(TOPLEFT, TTS.window, TOPLEFT, x + 6, y + 8)
    image:SetDimensions(40, 40)
    image:SetMouseEnabled(false)
    local label = CreateLabel(TTS.window, name .. "Label", "", x + 50, y + 5, tileW - 55, tileH - 10, "ZoFontGameSmall", 0.92)
    SafeCall(label, "SetWrapMode", TEXT_WRAP_MODE_WORD)
    SafeCall(label, "SetMouseEnabled", false)
    button:SetHandler("OnClicked", function()
        local tile = TTS.textureTiles[slot]
        if tile and tile.itemIndex and tile.itemIndex > 0 then
            SelectTexture(tile.itemIndex)
        elseif tile and tile.itemPath then
            TTS.saved.customPath = tile.itemPath
            TTS.saved.customTextureName = "Saved: " .. FriendlyNameFromPath(tile.itemPath)
            if TTS.pathEdit then
                TTS.pathEdit:SetText(tile.itemPath)
                TTS.pathEdit:SetHidden(not TTS.advancedPathVisible)
            end
            UpdateTexturePreview()
            TTS.UpdateAll()
        end
    end)
    button:SetHidden(true)
    image:SetHidden(true)
    return { button = button, back = back, image = image, label = label }
end

local function MakeWindow()
    if TTS.window then return end
    TTS.saved = GetSaved()
    -- OnAddonLoaded may already have appended live ESO API assets. Preserve that expanded
    -- table here; rebuilding it would silently discard collectible/achievement entries.
    if type(TTS.textures) ~= "table" or #TTS.textures == 0 then
        TTS.textures = BuildUniqueCatalog()
    end
    MigrateTextureSelection(TTS.saved, TTS.textures)
    TTS.advancedPathVisible = Trim(TTS.saved.customPath or "") ~= ""
    if #TTS.textures == 0 then
        TTS.textures = { { name = "Baby Netch", path = DEFAULT_TEXTURE_PATH, category = "Pets & Creatures", keywords = "pet netch" } }
    end
    if TTS.saved.textureIndex > #TTS.textures then TTS.saved.textureIndex = 1 end

    local root = WM:CreateTopLevelWindow("TamrielTextStudioWindow")
    TTS.window = root
    root:SetDimensions(PANEL_W, PANEL_H)
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    root:SetMouseEnabled(true)
    SafeCall(root, "SetClampedToScreen", true)
    SafeCall(root, "SetMovable", true)
    root:SetHidden(true)

    CreateBackdrop("TTSPanelBackdrop", root, 0, 0, PANEL_W, PANEL_H, true)
    local header = CreateLabel(root, "TTSHeader", "TAMRIEL TEXT STUDIO", 24, 12, 830, 34, "ZoFontWinH1", 1)
    header:SetColor(0.95, 0.78, 0.36, 1)
    CreateLabel(root, "TTSHelp", "Pick a color, browse ESO icons by name, preview the texture, build formatted text, then transfer it to the target field.", 24, 48, 1080, 30, "ZoFontGame", 0.87)
    CreateButton(root, "TTSCloseTop", "CLOSE", 1067, 14, 87, 31, function() root:SetHidden(true) end)

    TTS.targetButton = CreateButton(root, "TTSTargetButton", "FIELD: Guild MOTD", 24, 86, 170, 32, function() CycleSetting("target", #TARGETS, 1) end)
    TTS.colorTargetButton = CreateButton(root, "TTSColorTargetButton", "COLOR FOR: All text", 202, 86, 155, 32, function() ChangeHexTarget(1) end)
    TTS.sizeButton = CreateButton(root, "TTSSizeButton", "ICON SIZE: 32", 365, 86, 110, 32, function() CycleSize(1) end)
    TTS.positionButton = CreateButton(root, "TTSPositionButton", "ICON: Start", 483, 86, 112, 32, function() CycleSetting("iconPosition", #POSITIONS, 1) end)
    TTS.iconButton = CreateButton(root, "TTSIconButton", "ICON: ON", 603, 86, 100, 32, function() TTS.saved.iconEnabled = not TTS.saved.iconEnabled; UpdateCaptions(); UpdatePreviewAndOutput() end)
    TTS.separatorButton = CreateButton(root, "TTSSeparatorButton", "DIVIDER: None", 711, 86, 142, 32, function() CycleSetting("separator", #SEPARATORS, 1) end)
    TTS.advancedPathButton = CreateButton(root, "TTSAdvancedPathButton", "ADVANCED PATH", 861, 86, 160, 32, ToggleAdvancedPath)
    TTS.favoriteButton = CreateButton(root, "TTSFavoriteButton", "ADD FAVORITE", 1029, 86, 125, 32, ToggleFavorite)

    CreateLabel(root, "TTSColorPaletteLabel", "COLOR PALETTE — choose where the color applies above, then pick a swatch", 24, 119, 500, 18, "ZoFontGameSmall", 0.88)
    CreateColorSwatches()
    TTS.hexEdit = CreateEdit(root, "TTSHexEdit", CurrentTargetHex(), 530, 136, 95, 31, 7, false)
    TTS.applyHexButton = CreateButton(root, "TTSApplyHexButton", "APPLY HEX", 633, 136, 104, 31, ApplySelectedHex)
    TTS.activeColorSample = CreateBackdrop("TTSActiveColorSample", root, 530, 177, 52, 44, false)
    TTS.activeColorName = CreateLabel(root, "TTSActiveColorName", "Gold (#FFD700)", 590, 177, 208, 22, "ZoFontGame", 0.95)
    TTS.hexHint = CreateLabel(root, "TTSHexHint", "Swatch or HEX", 590, 198, 208, 22, "ZoFontGameSmall", 0.82)
    CreateButton(root, "TTSHueMinus", "HUE -10", 805, 176, 105, 20, function() AdjustActiveColor("hue", -10) end)
    CreateButton(root, "TTSHuePlus", "HUE +10", 916, 176, 105, 20, function() AdjustActiveColor("hue", 10) end)
    CreateButton(root, "TTSSatPlus", "SAT +10%", 1027, 176, 105, 20, function() AdjustActiveColor("saturation", 0.10) end)
    CreateButton(root, "TTSSatMinus", "SAT -10%", 805, 199, 105, 20, function() AdjustActiveColor("saturation", -0.10) end)
    CreateButton(root, "TTSLightPlus", "LIGHTER", 916, 199, 105, 20, function() AdjustActiveColor("lightness", 0.05) end)
    CreateButton(root, "TTSLightMinus", "DARKER", 1027, 199, 105, 20, function() AdjustActiveColor("lightness", -0.05) end)
    TTS.pathEdit = CreateEdit(root, "TTSAdvancedPathEdit", TTS.saved.customPath, 530, 220, 624, 27, 300, false)
    TTS.pathEdit:SetHidden(not TTS.advancedPathVisible)

    CreateLabel(root, "TTSTextureBrowserLabel", "TEXTURE LIBRARY — searchable bundled paths + live ESO collectible, skill and achievement art", 24, 258, 600, 18, "ZoFontGameSmall", 0.90)
    TTS.searchEdit = CreateEdit(root, "TTSTextureSearch", TTS.saved.search, 24, 279, 330, 31, 120, false)
    TTS.categoryButton = CreateButton(root, "TTSTextureCategoryButton", "CATEGORY: All textures", 362, 279, 181, 31, function() CycleCategory(1) end)
    TTS.prevTextureButton = CreateButton(root, "TTSTexturePrevButton", "‹ PREVIOUS", 551, 279, 111, 31, function() ChangeTexturePage(-1) end)
    TTS.nextTextureButton = CreateButton(root, "TTSTextureNextButton", "NEXT ›", 670, 279, 90, 31, function() ChangeTexturePage(1) end)
    TTS.texturePageStatus = CreateLabel(root, "TTSTexturePageStatus", "0 of 0", 768, 279, 160, 31, "ZoFontGameSmall", 0.9)
    CreateBackdrop("TTSCurrentTextureBackdrop", root, 946, 316, 208, 132, false)
    TTS.texturePreview = WM:CreateControl("TTSCurrentTexturePreview", root, CT_TEXTURE)
    TTS.texturePreview:SetAnchor(CENTER, root, TOPLEFT, 1050, 359)
    TTS.texturePreview:SetDimensions(64, 64)
    TTS.texturePreview:SetMouseEnabled(false)
    TTS.currentTextureName = CreateLabel(root, "TTSCurrentTextureName", "Baby Netch", 954, 397, 192, 23, "ZoFontGame", 0.92)
    TTS.currentTextureHint = CreateLabel(root, "TTSCurrentTextureHint", "Built-in / indexed ESO asset", 954, 420, 192, 21, "ZoFontGameSmall", 0.78)
    TTS.textureTiles = {}
    for slot = 1, VISIBLE_TEXTURES do TTS.textureTiles[slot] = CreateTextureTile(slot) end

    CreateLabel(root, "TTSTitleLabel", "HEADING (optional)", 24, 465, 400, 18, "ZoFontGameSmall", 0.88)
    TTS.titleEdit = CreateEdit(root, "TTSTitleEdit", TTS.saved.title, 24, 484, 1130, 31, 500, false)
    CreateLabel(root, "TTSBodyLabel", "MESSAGE", 24, 521, 400, 18, "ZoFontGameSmall", 0.88)
    TTS.bodyEdit = CreateEdit(root, "TTSBodyEdit", TTS.saved.body, 24, 540, 1130, 46, 2048, true)

    CreateLabel(root, "TTSPreviewLabel", "LIVE PREVIEW — rendered text colors are shown here; texture is previewed in the library panel", 24, 592, 1100, 18, "ZoFontGameSmall", 0.88)
    CreateBackdrop("TTSPreviewBackdrop", root, 24, 611, 1130, 48, false)
    TTS.preview = CreateLabel(root, "TTSPreview", "Your formatted message preview will appear here.", 36, 615, 1100, 40, "ZoFontGame", 1)
    SafeCall(TTS.preview, "SetWrapMode", TEXT_WRAP_MODE_WORD)

    CreateLabel(root, "TTSOutputLabel", "OUTPUT — generate, then use SELECT / COPY OUTPUT to open the PS5 text-entry keyboard", 24, 666, 1100, 18, "ZoFontGameSmall", 0.88)
    TTS.outputEdit = CreateEdit(root, "TTSOutputEdit", "", 24, 686, 1130, 72, 4096, true)
    TTS.status = CreateLabel(root, "TTSStatus", "Length estimate", 24, 761, 1125, 18, "ZoFontGameSmall", 0.87)
    TTS.buildButton = CreateButton(root, "TTSBuildButton", "REFRESH OUTPUT", 24, 784, 170, 33, BuildOutput)
    TTS.focusOutputButton = CreateButton(root, "TTSFocusOutputButton", "SELECT / COPY OUTPUT", 202, 784, 186, 33, function()
        OpenOutputInNativeTextEntry()
        if TTS.buildHint then TTS.buildHint:SetText("Output opened in ESO text entry. Use the PS5 on-screen keyboard to select and copy, then paste into the destination field.") end
    end)
    CreateButton(root, "TTSResetButton", "RESET SAMPLE", 396, 784, 150, 33, function()
        TTS.saved.title = "Welcome to our guild!"
        TTS.saved.body = "Add your message here."
        TTS.titleEdit:SetText(TTS.saved.title)
        TTS.bodyEdit:SetText(TTS.saved.body)
        BuildOutput()
    end)
    CreateButton(root, "TTSCloseBottom", "CLOSE", 554, 784, 110, 33, function() root:SetHidden(true) end)
    TTS.buildHint = CreateLabel(root, "TTSBuildHint", "Tip: markup counts toward field limits. The add-on does not save guild fields automatically.", 24, 821, 1125, 18, "ZoFontGameSmall", 0.80)

    local function OnComposerChanged()
        if TTS.titleEdit then TTS.saved.title = TTS.titleEdit:GetText() end
        if TTS.bodyEdit then TTS.saved.body = TTS.bodyEdit:GetText() end
        UpdatePreviewAndOutput()
    end
    TTS.titleEdit:SetHandler("OnTextChanged", OnComposerChanged)
    TTS.bodyEdit:SetHandler("OnTextChanged", OnComposerChanged)
    TTS.hexEdit:SetHandler("OnTextChanged", function()
        local hex = NormalizeHex(TTS.hexEdit:GetText())
        if hex then
            ApplyHexToTarget(hex)
            if TTS.hexHint then TTS.hexHint:SetText("Current custom color: #" .. hex) end
            UpdatePreviewAndOutput()
        end
    end)
    TTS.searchGeneration = 0
    TTS.searchEdit:SetHandler("OnTextChanged", function()
        TTS.saved.search = TTS.searchEdit:GetText()
        TTS.saved.texturePage = 1
        TTS.searchGeneration = TTS.searchGeneration + 1
        local generation = TTS.searchGeneration
        if type(zo_callLater) == "function" then
            zo_callLater(function()
                if TTS.searchGeneration == generation then RefreshTextureGallery() end
            end, 120)
        else
            RefreshTextureGallery()
        end
    end)
    TTS.pathEdit:SetHandler("OnTextChanged", function()
        TTS.saved.customPath = Trim(TTS.pathEdit:GetText())
        TTS.saved.customTextureName = TTS.saved.customPath ~= "" and ("Custom: " .. FriendlyNameFromPath(TTS.saved.customPath)) or nil
        UpdateTexturePreview()
        UpdatePreviewAndOutput()
    end)

    TTS.UpdateAll = function()
        UpdateCaptions()
        RefreshTextureGallery()
        UpdatePreviewAndOutput()
    end
    UpdateCaptions()
    RefreshTextureGallery()
    UpdateTexturePreview()
    UpdatePreviewAndOutput()
    Persist()
end

function TTS.Toggle()
    MakeWindow()
    TTS.window:SetHidden(not TTS.window:IsHidden())
    if not TTS.window:IsHidden() then
        SafeCall(TTS.window, "BringWindowToTop")
        TTS.UpdateAll()
    end
end

function TTS.Show()
    MakeWindow()
    TTS.window:SetHidden(false)
    SafeCall(TTS.window, "BringWindowToTop")
    TTS.UpdateAll()
end

-- Runtime catalogue expansion: use ESO's own current collectible and achievement APIs for
-- exact paths/names. This is especially valuable for mounts, pets, skins, costumes,
-- polymorphs and trial/dungeon achievement art, whose asset names change between updates.
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
    -- Current collectible icons (real names and paths directly from ESO, case preserved for console).
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
                        -- Add collectible background art too where the client exposes it. These
                        -- paths are returned by ESO itself, so no manual path entry is needed.
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

    -- Index all achievement icons, not just trial achievements. Each item is read
    -- gradually in ProcessBatch below to avoid a large one-frame spike.
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

    -- Discover actual skill names and icon paths from the active client API. This
    -- complements the static catalog's convenient search aliases with real skill art.
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
        if TTS.settingsPanel and (TTS.runtimeScanBatches % 8 == 0 or TTS.runtimeQueueIndex > #TTS.runtimeQueue) then
            if RefreshNativeSettings then RefreshNativeSettings() end
        end
        if TTS.runtimeQueueIndex <= #TTS.runtimeQueue and type(zo_callLater) == "function" then
            zo_callLater(ProcessBatch, 15)
        elseif TTS.runtimeQueueIndex > #TTS.runtimeQueue then
            TTS.runtimeQueue = nil
            TTS.runtimeIndexComplete = true
            -- The dedupe map is only needed while runtime discovery is running.
            TTS.texturePathSet = nil
            if TTS.settingsPanel and RefreshNativeSettings then RefreshNativeSettings() end
        end
    end

    if #queue == 0 then
        TTS.runtimeIndexComplete = true
        if TTS.settingsPanel and RefreshNativeSettings then RefreshNativeSettings() end
        return
    end
    if type(zo_callLater) == "function" then
        zo_callLater(ProcessBatch, 250)
    else
        -- Fallback for nonstandard clients without the scheduler; process safely in one pass.
        while TTS.runtimeQueue and TTS.runtimeQueueIndex <= #TTS.runtimeQueue do ProcessBatch() end
    end
end

-- Native, controller-friendly settings-menu experience.
-- The old free-floating mouse-oriented window is intentionally no longer opened.
local MAX_MENU_TEXTURES = 72
local COMMON_COLOR_PRESETS = {
    {name="White", hex="FFFFFF"}, {name="Gold", hex="FFD700"},
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
    Persist()
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

    -- Let custom paths saved as favorites participate in the Favorites category too.
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
    for _, color in ipairs(COMMON_COLOR_PRESETS) do
        items[#items + 1] = { name = color.name, data = color.hex }
        if color.hex == CurrentTargetHex() then found = true end
    end
    if not found then
        items[#items + 1] = { name = "Custom (#" .. CurrentTargetHex() .. ")", data = CurrentTargetHex() }
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
    local lines = {}
    if title ~= "" then
        if saved.iconEnabled and (saved.iconPosition == 1 or saved.iconPosition == 3) then
            lines[#lines + 1] = icon .. " " .. WrapColor(title, saved.titleHex)
        else
            lines[#lines + 1] = WrapColor(title, saved.titleHex)
        end
    elseif saved.iconEnabled and (saved.iconPosition == 1 or saved.iconPosition == 3) then
        lines[#lines + 1] = icon
    end
    local separator = SEPARATORS[saved.separator] or "None"
    if separator ~= "None" then lines[#lines + 1] = WrapColor(separator, saved.dividerHex) end
    if body ~= "" then lines[#lines + 1] = WrapColor(body, saved.bodyHex) end
    if saved.iconEnabled and (saved.iconPosition == 2 or saved.iconPosition == 3) then lines[#lines + 1] = icon end
    if #lines == 0 then return "|cAAAAAAYour live preview will appear here as you compose a message.|r" end
    return "|cD9B45BLIVE PREVIEW|r\n" .. table.concat(lines, "\n")
end

local function BuildNativeStatus()
    local results, total = GetMenuTextureResults()
    local output = CreateOutputText()
    local discovery = TTS.runtimeIndexComplete and "ESO asset discovery complete" or "discovering additional ESO assets in background"
    local showing = math.min(total or 0, MAX_MENU_TEXTURES)
    return string.format("Search matches: %d | thumbnails available here: %d | indexed paths: %d | %s\nGenerated output estimate: %d / %d characters for %s.",
        tonumber(total) or 0, showing, #(TTS.textures or {}), discovery, #output, CurrentTarget().limit, CurrentTarget().name)
end

-- Console text entry is the only supported ESO route that can hand text to the
-- platform keyboard. It must be called from the HUD context: on console, calling
-- StartTextEntry from the full-screen menu can silently do nothing. The button in
-- Add-ons settings therefore queues the request until the HUD scene returns.
local function SafeStartChatInput(text)
    if type(IsChatSystemAvailableForCurrentPlatform) ~= "function"
        or not IsChatSystemAvailableForCurrentPlatform()
        or type(ZO_GetChatSystem) ~= "function" then
        return false
    end
    local ok, chatSystem = pcall(ZO_GetChatSystem)
    if not ok or not chatSystem or type(chatSystem.StartTextEntry) ~= "function" then
        return false
    end
    local started = pcall(chatSystem.StartTextEntry, chatSystem, text, nil, nil, true)
    return started == true
end

local function OnHudSceneStateChanged(oldState, newState)
    if not TTS.pendingOutputEntry then return end
    if newState ~= SCENE_SHOWN then return end

    -- Let ESO finish returning to the HUD before asking the console to create its
    -- native text-entry UI. Do not fall back to a fake dialog if this fails.
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if not TTS.pendingOutputEntry then return end
            TTS.pendingOutputEntry = false
            local output = TTS.saved and TTS.saved.output or ""
            if SafeStartChatInput(output) then
                if TTS.buildHint then
                    TTS.buildHint:SetText("ESO console text entry requested. The PS5 keyboard should open with the generated text. Do not send it as chat; back out after copying.")
                end
            elseif TTS.buildHint then
                TTS.buildHint:SetText("ESO did not expose console text entry in this scene. The generated text remains saved in the Output setting. This is a platform/API limitation, not a clipboard action.")
            end
        end, 300)
    else
        TTS.pendingOutputEntry = false
        SafeStartChatInput(TTS.saved and TTS.saved.output or "")
    end
end

OpenOutputInNativeTextEntry = function()
    local output = CreateOutputText()
    TTS.saved.output = output
    Persist()
    if RefreshNativeSettings then RefreshNativeSettings() end

    -- The current button lives in the full-screen Add-ons settings menu. Queue the
    -- handoff and start it only after the player backs out to the normal HUD.
    TTS.pendingOutputEntry = true
    if TTS.buildHint then
        TTS.buildHint:SetText("Output is saved. Back out of Add-ons settings to return to the HUD; Tamriel Text Studio will then request ESO's PS5 text-entry keyboard with the output prefilled. Back out of the keyboard without sending chat after copying.")
    end
    return true
end

local function StoreOutput()
    TTS.saved.output = CreateOutputText()
    Persist()
    if RefreshNativeSettings then RefreshNativeSettings() end
    OpenOutputInNativeTextEntry()
end

local function ResetComposerText()
    TTS.saved.title = "Welcome to our guild!"
    TTS.saved.body = "Add your message here."
    TTS.saved.output = CreateOutputText()
    Persist()
    if RefreshNativeSettings then RefreshNativeSettings() end
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
    if RefreshNativeSettings then RefreshNativeSettings() end
end

local function ApplyPickedColor(r, g, b, a)
    -- LibHarvensAddonSettings ST_COLOR documents setFunction(newR,newG,newB,newA).
    -- Accept normalized channels and defensively handle 0..255 channels, but never
    -- substitute white for missing/invalid callback values.
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not r or not g or not b then return false end
    if r > 1 or g > 1 or b > 1 then
        r, g, b = r / 255, g / 255, b / 255
    end
    r = math.max(0, math.min(1, r))
    g = math.max(0, math.min(1, g))
    b = math.max(0, math.min(1, b))
    local hex = string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))

    if not ApplyHexToTarget(hex) then return false end
    TTS.saved.activeHex = hex
    Persist()
    if TTS.hexEdit then TTS.hexEdit:SetText(hex) end
    if TTS.hexHint then TTS.hexHint:SetText("Saved color: #" .. hex) end
    TTS.menuResultCache = nil
    UpdatePreviewAndOutput()
    -- Important: do NOT refresh/rebuild the native settings panel inside the color
    -- picker callback. That can recreate the picker control and reset its UI value.
    -- getFunction reads the persisted target color when the picker is next opened.
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
            TTS.saved.bodyHex = "FFFFFF"
            TTS.saved.dividerHex = DEFAULT_COLOR
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
            TTS.saved.output = CreateOutputText()
            TTS.menuResultCache = nil
            Persist()
        end,
    })
    if not panel or type(panel.AddSetting) ~= "function" then return false end
    TTS.settingsPanel = panel

    local function Add(settingType, params)
        params.type = settingType
        panel:AddSetting(params)
    end
    local function DropdownData(name, item)
        -- LibHarvensAddonSettings/LibVotans passes (control, displayName, itemTable).
        -- Accept the item table as well as plain values for compatibility with test tools.
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
        Persist()
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
        Persist()
    end
    local function SetColorTargetByName(_, name, item)
        local wanted = tostring(DropdownData(name, item) or "All text")
        for index, target in ipairs(COLOR_TARGETS) do
            if target == wanted then TTS.saved.colorTarget = index break end
        end
        TTS.saved.activeHex = CurrentTargetHex()
        Persist()
    end
    local function SetSearch(value)
        TTS.saved.search = Trim(tostring(value or ""))
        TTS.saved.texturePage = 1
        TTS.menuResultCache = nil
        local results = GetMenuTextureResults()
        if results[1] then SetSelectedCatalogPath(results[1].path) end
        Persist()
    end

    Add(settingsLib.ST_SECTION, {
        label = "START HERE — FOLLOW THESE STEPS",
        tooltip = "This tool now lives entirely in Settings > Add-ons. You do not need a chat command or a separate pop-up window.",
    })
    Add(settingsLib.ST_LABEL, {
        label = "1. Choose a destination.  2. Enter a heading/message.  3. Search and select artwork.  4. Choose colors and style.  5. Select Generate Output, then transfer the result into the ESO field and save it yourself.",
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
        setFunction = function(value) TTS.saved.title = tostring(value or ""); Persist() end,
        default = "Welcome to our guild!",
    })
    Add(settingsLib.ST_EDIT, {
        label = "Message text",
        tooltip = "Enter your main message. This is a single-line settings field; keep line breaks for the destination editor if it supports them.",
        maxChars = 2048, getFunction = function() return TTS.saved.body end,
        setFunction = function(value) TTS.saved.body = tostring(value or ""); Persist() end,
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
                Persist()
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
            Persist()
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
            Persist()
            RefreshNativeSettings()
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
    Add(settingsLib.ST_COLOR, {
        label = "Choose custom color",
        tooltip = "Use the ESO color picker instead of entering HEX codes manually.",
        getFunction = function()
            local r, g, b = HexToRGB(CurrentTargetHex())
            return r, g, b, 1
        end,
        setFunction = function(...)
            ApplyPickedColor(...)
        end,
        default = {1, 0.843, 0, 1},
    })
    Add(settingsLib.ST_DROPDOWN, {
        label = "Quick color preset",
        tooltip = "Optional named colors. Use Choose custom color above for any shade.",
        items = GetColorPresetItems,
        getFunction = CurrentColorName,
        setFunction = function(_, name, item)
            local normalized = NormalizeHex(DropdownData(name, item))
            if normalized then ApplyHexToTarget(normalized); TTS.saved.activeHex = normalized; Persist(); RefreshNativeSettings() end
        end,
        default = "Gold",
    })
    Add(settingsLib.ST_CHECKBOX, {
        label = "Include selected image in message",
        tooltip = "Turn the inline texture on or off without changing your selected artwork.",
        getFunction = function() return TTS.saved.iconEnabled end,
        setFunction = function(value) TTS.saved.iconEnabled = value == true; Persist() end,
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
            Persist()
            RefreshNativeSettings()
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
                Persist()
                UpdateCaptions()
                UpdatePreviewAndOutput()
                RefreshNativeSettings()
            else
                if TTS.buildHint then TTS.buildHint:SetText("Custom image size must be a whole number from 8 to 256 pixels.") end
                RefreshNativeSettings()
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
            Persist()
            RefreshNativeSettings()
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
            Persist()
            RefreshNativeSettings()
        end,
        default = "None",
    })

    Add(settingsLib.ST_SECTION, { label = "4 — LIVE PREVIEW AND OUTPUT" })
    Add(settingsLib.ST_LABEL, {
        label = BuildNativePreview,
        tooltip = "This shows a short preview of the selected color, image and message styling. Test the generated result in the destination field before saving.",
    })
    Add(settingsLib.ST_LABEL, {
        label = BuildNativeStatus,
        tooltip = "The output count is an estimate. The target game's exact limit and inline markup behavior can differ by field.",
    })
    Add(settingsLib.ST_BUTTON, {
        label = "Generate final markup",
        buttonText = "GENERATE / REFRESH OUTPUT",
        tooltip = "Build the formatted text in the output field below. This does not save or post to a guild automatically.",
        clickHandler = StoreOutput,
    })
    Add(settingsLib.ST_BUTTON, {
        label = "Open output in console text entry",
        buttonText = "QUEUE OUTPUT FOR SELECT / COPY",
        tooltip = "Choose this, then back out of Add-ons settings to the normal HUD. The add-on will request ESO's native console chat text-entry with the generated markup prefilled. Back out without sending chat after copying.",
        clickHandler = OpenOutputInNativeTextEntry,
    })
    Add(settingsLib.ST_EDIT, {
        label = "Generated markup — select and transfer manually",
        tooltip = "This is the saved generated markup. Choose Queue Output for Select / Copy, then back out to the HUD for ESO's native console text-entry. The add-on cannot directly write to the PS5 system clipboard.",
        maxChars = 4096,
        getFunction = function()
            if TTS.saved.output == "" then TTS.saved.output = CreateOutputText() end
            return TTS.saved.output
        end,
        setFunction = function(value) TTS.saved.output = tostring(value or ""); Persist() end,
        default = "",
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
    TTS.saved.output = TTS.saved.output ~= "" and TTS.saved.output or CreateOutputText()
    Persist()
    return true
end

RefreshNativeSettings = function()
    local panel = TTS.settingsPanel
    if not panel then return end
    local function refresh()
        if TTS.settingsPanel and type(TTS.settingsPanel.UpdateControls) == "function" then
            pcall(TTS.settingsPanel.UpdateControls, TTS.settingsPanel)
        end
        local lib = TTS.settingsLib
        if lib and type(lib.RefreshAddonSettings) == "function" then
            pcall(lib.RefreshAddonSettings, lib)
        end
    end
    if type(zo_callLater) == "function" then
        zo_callLater(refresh, 50)
    else
        refresh()
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    TTS.saved = GetSaved()
    TTS.textures = BuildUniqueCatalog()
    MigrateTextureSelection(TTS.saved, TTS.textures)
    TTS.favoriteRevision = 0
    RegisterNativeSettingsMenu()
    if SCENE_MANAGER and type(SCENE_MANAGER.GetScene) == "function" then
        for _, sceneName in ipairs({ "hud", "hudui" }) do
            local scene = SCENE_MANAGER:GetScene(sceneName)
            if scene and type(scene.RegisterCallback) == "function" then
                scene:RegisterCallback("StateChange", OnHudSceneStateChanged)
            end
        end
    end
    StartRuntimeTextureIndex()
    -- No slash commands are registered. The primary interface is Settings > Add-ons > Tamriel Text Studio.
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
