-- ESO Adventurer Suite
-- v0.29.81 - canonical runtime asset-root resolver for all custom DDS art
-- v0.29.48 - direct ESO companion collectible portraits in the Companions gallery
-- v0.29.39 - fixed Tribute requirement wrapping and clipping
-- v0.29.33 - expanded Finder rail with ESO-style activity access (no Golden Pursuits)
-- v0.29.32 - guild leader home selector for all joined guilds
-- v0.29.31 - travel zone headers use a distinct gold treatment
-- v0.29.30 - default window now starts at the minimum readable size
-- The old Codex/book shell is not created by this module. Journal.lua remains
-- loaded as the data/action layer only; every visible Suite page is rebuilt here.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Journal then return end

local J = EPC.Journal
EPC.ModernAppUI = EPC.ModernAppUI or {}
local M = EPC.ModernAppUI
local wm = WINDOW_MANAGER

local BASE_W, BASE_H = 1260, 780
local RAIL_W, TOP_H = 84, 72
local SHELL_PAD = 0
local CONTENT_W, CONTENT_H = 1166, 660
local ROUND_RADIUS = 18

-- Resolve Suite artwork from the exact folder ESO is executing this file from.
-- A protected Lua error includes user:/AddOns/.../ModernAppUI.lua even on clients
-- that do not expose the add-on manager/root-directory APIs.
local function suiteAsset02926(relativePath)
    -- v0.29.125: keep the canonical addon root, but route custom artwork through
    -- the versioned art directory so stale ESO shader-cache entries cannot make
    -- an updated Suite texture render transparent.
    local relative = tostring(relativePath or ""):gsub("^/+", "")
    if string.sub(relative, 1, 4) == "Art/" then
        relative = "Art029125/" .. string.sub(relative, 5)
    end
    return "ESOAdventurerSuite/" .. relative
end

local ROUND_SOLID = suiteAsset02926("Art/Modern/Rounded/solid.dds")
local ROUND_CORNER = suiteAsset02926("Art/Modern/Rounded/corner_fill.dds")
local ROUND_BORDER = suiteAsset02926("Art/Modern/Rounded/corner_border.dds")
local ROUND_PANEL_ROOT = suiteAsset02926("Art/eas_round_panel.dds")
local ROUND_SHELL_ROOT = suiteAsset02926("Art/eas_round_shell.dds")
local ROUND_PILL_ROOT = suiteAsset02926("Art/eas_round_pill.dds")

local function preloadSuiteUiArt029125()
    if type(PreloadTexture) ~= "function" then return end
    local paths = { ROUND_SOLID, ROUND_CORNER, ROUND_BORDER, ROUND_PANEL_ROOT, ROUND_SHELL_ROOT, ROUND_PILL_ROOT }
    local classes = { "dragonknight","sorcerer","nightblade","warden","necromancer","templar","arcanist" }
    local companions = { "azandar","bastian","ember","isobel","mirri","sharp","tanlorin","zerithvar" }
    for i = 1, #classes do
        paths[#paths + 1] = suiteAsset02926("Art/eas_class_" .. classes[i] .. ".dds")
    end
    for i = 1, #companions do
        paths[#paths + 1] = suiteAsset02926("Art/eas_companion_" .. companions[i] .. ".dds")
    end
    for _, path in ipairs(paths) do
        if path and path ~= "" then pcall(PreloadTexture, path) end
    end
end
preloadSuiteUiArt029125()
local ACCENT = {0.49, 0.36, 1.00, 1}
local ACCENT_SOFT = {0.23, 0.16, 0.46, 0.94}
-- v0.28.95: ESO-inspired high-contrast palette.  The shell stays nearly black,
-- while cards step through cool blue-charcoal values so every surface reads
-- clearly over the game world. Alliance color remains reserved for selection.
local BG = {0.010, 0.016, 0.026, 0.992}
local GLASS_BG = {0.006, 0.010, 0.018, 0.80}
local SURFACE = {0.024, 0.036, 0.052, 0.995}
local SURFACE_2 = {0.038, 0.052, 0.073, 0.995}
local SURFACE_3 = {0.056, 0.073, 0.098, 0.995}
local EDGE = {0.31, 0.43, 0.57, 0.78}
local EDGE_SOFT = {0.22, 0.32, 0.44, 0.62}
local TEXT = {1.00, 1.00, 1.00, 1}
local MUTED = {0.86, 0.89, 0.94, 1}
local ESO_GOLD = {0.91, 0.83, 0.64, 1}
local GREEN = {0.36, 0.86, 0.58, 1}
local RED = {0.92, 0.35, 0.40, 1}

-- v0.28.83: the modern app follows the live character alliance automatically.
-- The base surfaces stay neutral/dark; alliance color is reserved for accents,
-- selected navigation, borders, progress, and primary actions.
local ALLIANCE_THEMES = {
    [ALLIANCE_ALDMERI_DOMINION or 1] = { name = "Aldmeri Dominion", accent = {0.95, 0.77, 0.16, 1}, soft = {0.34, 0.25, 0.055, 0.96} },
    [ALLIANCE_EBONHEART_PACT or 2] = { name = "Ebonheart Pact", accent = {0.88, 0.22, 0.20, 1}, soft = {0.34, 0.07, 0.065, 0.96} },
    [ALLIANCE_DAGGERFALL_COVENANT or 3] = { name = "Daggerfall Covenant", accent = {0.22, 0.50, 0.96, 1}, soft = {0.065, 0.15, 0.34, 0.96} },
}

-- Prefer ESO's large alliance crest artwork so the rail emblem stays crisp
-- instead of enlarging the smaller campaign-overview icon. Stats badges are
-- used only as a final base-game fallback.
local ALLIANCE_SYMBOL_ICONS = {
    [ALLIANCE_ALDMERI_DOMINION or 1] = "EsoUI/Art/Stats/allianceBadge_aldmeri.dds",
    [ALLIANCE_EBONHEART_PACT or 2] = "EsoUI/Art/Stats/allianceBadge_ebonheart.dds",
    [ALLIANCE_DAGGERFALL_COVENANT or 3] = "EsoUI/Art/Stats/allianceBadge_daggerfall.dds",
}

local function allianceSymbolPath(alliance)
    alliance = tonumber(alliance) or 0
    local helpers = {
        ZO_GetLargeAllianceSymbolIcon,
        ZO_GetPlatformAllianceSymbolIcon,
        GetAllianceSymbolIcon,
        ZO_GetAllianceSymbolIcon,
    }
    for _, helper in ipairs(helpers) do
        if type(helper) == "function" then
            local ok, path = pcall(helper, alliance)
            if ok and path and path ~= "" then return path end
        end
    end
    return ALLIANCE_SYMBOL_ICONS[alliance]
end

local function updateAlliancePalette()
    local alliance = 0
    if type(GetUnitAlliance) == "function" then
        local ok, value = pcall(GetUnitAlliance, "player")
        if ok then alliance = tonumber(value) or 0 end
    end
    local theme = ALLIANCE_THEMES[alliance] or { name = "Tamriel", accent = {0.49,0.36,1.00,1}, soft = {0.23,0.16,0.46,0.94} }
    for i=1,4 do ACCENT[i] = theme.accent[i] end
    for i=1,4 do ACCENT_SOFT[i] = theme.soft[i] end
    return alliance, theme.name
end

local TAB_LABELS = {
    INDEX="Home", CHARACTER="Character", COMPANIONS="Companions", BUILD="Build", GEAR="Gear & Sets",
    SKILLS="Skills & CP", COMBAT="Combat", STATS="Character Stats", ACHIEVEMENTS="Achievements",
    QUESTS="Quest Finder", PURSUITS="Golden Pursuits", ACTIVITY="Activities", TRAVEL="Map / Travel",
    GROUPFINDER="Group Finder", ZONEGUIDE="Zone Guide",
    DUNGEONS="Dungeon Finder", BATTLEGROUNDS="Battleground Finder", TRIBUTE="Tales of Tribute", HOMETOURS="Home Tours",
    NOTES="Notes", PINS="Checkpoints", TOOLS="Utilities", CODEX="Crafting Codex", DICE="Dice & Coin", SETTINGS="Settings",
}

local GROUPS = {
    HOME = {"INDEX"},
    CHARACTER = {"CHARACTER","COMPANIONS","BUILD","GEAR","SKILLS","COMBAT","STATS","ACHIEVEMENTS"},
    ADVENTURE = {"QUESTS","PURSUITS","ACTIVITY","TRAVEL"},
    FINDERS = {"GROUPFINDER","ZONEGUIDE","DUNGEONS","BATTLEGROUNDS","TRIBUTE","HOMETOURS"},
    TOOLS = {"NOTES","PINS","TOOLS","CODEX","DICE","SETTINGS"},
}
local GROUP_ORDER = {"HOME","CHARACTER","ADVENTURE","FINDERS","TOOLS"}

-- v0.29.35: Finder entries are rendered and operated inside the Suite.
-- No Finder rail entry closes the Suite or hands off to ESO's native menu.

local ICONS = {
    INDEX="home", CHARACTER="character", COMPANIONS="companions", BUILD="build", GEAR="gear", SKILLS="skills",
    COMBAT="combat", STATS="stats", ACHIEVEMENTS="achievements", QUESTS="quests", PURSUITS="pursuits",
    ACTIVITY="activity", TRAVEL="travel", GROUPFINDER="groupfinder", ZONEGUIDE="travel",
    DUNGEONS="dungeons", BATTLEGROUNDS="battlegrounds", TRIBUTE="activity", HOMETOURS="travel",
    NOTES="notes", PINS="pins", TOOLS="tools", CODEX="codex", DICE="dice", SETTINGS="tools",
}

local CLASS_CARDS = {
    {key="dragonknight", label="Dragonknight", path=suiteAsset02926("Art/eas_class_dragonknight.dds")},
    {key="sorcerer", label="Sorcerer", path=suiteAsset02926("Art/eas_class_sorcerer.dds")},
    {key="nightblade", label="Nightblade", path=suiteAsset02926("Art/eas_class_nightblade.dds")},
    {key="warden", label="Warden", path=suiteAsset02926("Art/eas_class_warden.dds")},
    {key="necromancer", label="Necromancer", path=suiteAsset02926("Art/eas_class_necromancer.dds")},
    {key="templar", label="Templar", path=suiteAsset02926("Art/eas_class_templar.dds")},
    {key="arcanist", label="Arcanist", path=suiteAsset02926("Art/eas_class_arcanist.dds")},
}
local COMPANION_CARDS = {
    -- v0.29.48: Use the actual ESO companion collectible IDs.  The gallery
    -- resolves its art directly from each collectible instead of depending on
    -- a name scan or the addon's install-folder name for custom DDS paths.
    {key="azandar", label="Azandar", collectibleId=11114, path=suiteAsset02926("Art/eas_companion_azandar.dds")},
    {key="bastian", label="Bastian Hallix", collectibleId=9245, path=suiteAsset02926("Art/eas_companion_bastian.dds")},
    {key="ember", label="Ember", collectibleId=9911, path=suiteAsset02926("Art/eas_companion_ember.dds")},
    {key="isobel", label="Isobel Veloise", collectibleId=9912, path=suiteAsset02926("Art/eas_companion_isobel.dds")},
    {key="mirri", label="Mirri Elendis", collectibleId=9353, path=suiteAsset02926("Art/eas_companion_mirri.dds")},
    {key="sharp", label="Sharp-as-Night", collectibleId=11113, path=suiteAsset02926("Art/eas_companion_sharp.dds")},
    {key="tanlorin", label="Tanlorin", collectibleId=12172, path=suiteAsset02926("Art/eas_companion_tanlorin.dds")},
    {key="zerithvar", label="Zerith-var", collectibleId=12173, path=suiteAsset02926("Art/eas_companion_zerithvar.dds")},
}

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return fallback end
    if a == nil then a = fallback end
    return a, b, c, d, e
end

local function clean(text)
    text = tostring(text or "")
    if type(zo_strformat) == "function" then
        local ok, value = pcall(zo_strformat, "<<C:1>>", text)
        if ok and value and value ~= "" then text = value end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    return text
end

local function lowerKey(text)
    return string.lower(clean(text)):gsub("[^%a]", "")
end

local function appIconPath(key)
    local icon = ICONS[key] or "home"
    return suiteAsset02926("Art/eas_appicon_"..tostring(icon)..".dds")
end

-- v0.28.92: the custom rail DDS files are kept in the package, but the live
-- rail uses ESO-shipped menu art so it remains visible on every client.
local NATIVE_RAIL_ICONS = {
    INDEX="EsoUI/Art/MainMenu/menubar_journal_up.dds",
    CHARACTER="EsoUI/Art/MainMenu/menubar_character_up.dds",
    COMPANIONS="EsoUI/Art/MainMenu/menubar_social_up.dds",
    BUILD="EsoUI/Art/MainMenu/menubar_skills_up.dds",
    GEAR="EsoUI/Art/MainMenu/menubar_inventory_up.dds",
    SKILLS="EsoUI/Art/MainMenu/menubar_skills_up.dds",
    COMBAT="EsoUI/Art/MainMenu/menubar_champion_up.dds",
    STATS="EsoUI/Art/MainMenu/menubar_champion_up.dds",
    ACHIEVEMENTS="EsoUI/Art/MainMenu/menubar_journal_up.dds",
    QUESTS="EsoUI/Art/MainMenu/menubar_journal_up.dds",
    PURSUITS="EsoUI/Art/MainMenu/menubar_journal_up.dds",
    ACTIVITY="EsoUI/Art/MainMenu/menubar_social_up.dds",
    TRAVEL="EsoUI/Art/MainMenu/menubar_map_up.dds",
    GROUPFINDER="EsoUI/Art/MainMenu/menubar_social_up.dds",
    ZONEGUIDE="EsoUI/Art/MainMenu/menubar_map_up.dds",
    DUNGEONS="EsoUI/Art/MainMenu/menubar_social_up.dds",
    BATTLEGROUNDS="EsoUI/Art/MainMenu/menubar_social_up.dds",
    TRIBUTE="EsoUI/Art/MainMenu/menubar_journal_up.dds",
    HOMETOURS="EsoUI/Art/MainMenu/menubar_map_up.dds",
    NOTES="EsoUI/Art/MainMenu/menubar_journal_up.dds",
    PINS="EsoUI/Art/MainMenu/menubar_map_up.dds",
    TOOLS="EsoUI/Art/MainMenu/menubar_champion_up.dds",
    CODEX="EsoUI/Art/MainMenu/menubar_journal_up.dds",
    DICE="EsoUI/Art/MainMenu/menubar_champion_up.dds",
    SETTINGS="EsoUI/Art/MainMenu/menubar_champion_up.dds",
}
local RAIL_SHORT_LABELS = {
    INDEX="HOME", CHARACTER="CHAR", COMPANIONS="COMP", BUILD="BUILD", GEAR="GEAR",
    SKILLS="SKILL", COMBAT="COMBAT", STATS="STATS", ACHIEVEMENTS="ACH",
    QUESTS="QUEST", PURSUITS="PUR", ACTIVITY="ACT", TRAVEL="MAP",
    GROUPFINDER="GROUP", ZONEGUIDE="ZONE", DUNGEONS="DUNG",
    BATTLEGROUNDS="BG", TRIBUTE="TRIB", HOMETOURS="HOME", NOTES="NOTE",
    PINS="PIN", TOOLS="UTIL", CODEX="CODEX", DICE="DICE", SETTINGS="SET"
}

local function tint(texture, color)
    if not texture or not color then return end
    texture:SetColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4])
end

-- v0.29.123: label colors must always be numeric. ESO's LabelControlSetColorLua
-- throws a protected Lua argument error when a stale/foreign UI value reaches
-- SetColor. Keep the modern Suite UI defensive so hover/refresh paths can never
-- spam the error handler or cost FPS.
local function safeColorChannel029123(value, fallback)
    local n = tonumber(value)
    if n == nil then n = tonumber(fallback) or 1 end
    if n < 0 then return 0 end
    if n > 1 then return 1 end
    return n
end

local function setLabelColor029123(control, color, fallback)
    if not control or type(control.SetColor) ~= "function" then return end
    color = type(color) == "table" and color or fallback
    fallback = type(fallback) == "table" and fallback or TEXT
    control:SetColor(
        safeColorChannel029123(color and color[1], fallback[1]),
        safeColorChannel029123(color and color[2], fallback[2]),
        safeColorChannel029123(color and color[3], fallback[3]),
        safeColorChannel029123(color and color[4], fallback[4] or 1)
    )
end

local function setPanelVisual(c, center, edge)
    if not c then return end
    center = center or SURFACE
    edge = edge or EDGE
    local a = center[4] == nil and 1 or center[4]
    local ea = edge[4] == nil and 0.72 or edge[4]
    -- The rounded DDS supplies the single visible frame. The native center is
    -- only a visibility fallback; no second edge is drawn on top of it.
    if c.SetCenterColor then
        local fallback = 0
        if not c._shellSurface02890 and a > 0.01 then
            fallback = math.max(0.72, math.min(0.94, a * 0.92))
        end
        c:SetCenterColor(center[1] or 0, center[2] or 0, center[3] or 0, fallback)
    end
    if c.SetEdgeColor then
        c:SetEdgeColor(edge[1] or 0, edge[2] or 0, edge[3] or 0, ea)
    end
    if c.roundTex02890 then
        c.roundTex02890:SetHidden(false)
        c.roundTex02890:SetColor(center[1] or 1, center[2] or 1, center[3] or 1, a)
    end
    -- v0.28.95: no second highlight line on top of the rounded frame.
    if c.esoTopHighlight02894 then c.esoTopHighlight02894:SetHidden(true) end
    if c.SetAlpha then c:SetAlpha(1) end
    c._roundCenterColor = center
    c._roundEdgeColor = edge
end

local function keepTextureResident029116(textureControl)
    if textureControl and type(textureControl.SetTextureReleaseOption) == "function" and KEEP_TEXTURE_AT_ZERO_REFERENCES ~= nil then
        pcall(textureControl.SetTextureReleaseOption, textureControl, KEEP_TEXTURE_AT_ZERO_REFERENCES)
    end
end

local function addRoundTexture(name, parent, texturePath, coords)
    local t = wm:CreateControl(name, parent, CT_TEXTURE)
    t:SetTexture(texturePath)
    keepTextureResident029116(t)
    if coords then t:SetTextureCoords(coords[1],coords[2],coords[3],coords[4]) end
    t:SetDrawLevel(0)
    return t
end

local function buildRoundedSkin(c, name, radius)
    radius = math.max(8, tonumber(radius) or ROUND_RADIUS)
    c._roundFill, c._roundEdge = {}, {}
    local fill = c._roundFill
    local edge = c._roundEdge

    -- Fill: one center, four edge strips, four quarter-circle corners.
    local center = addRoundTexture(name.."_RoundFillCenter", c, ROUND_SOLID)
    center:SetAnchor(TOPLEFT,c,TOPLEFT,radius,radius); center:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-radius,-radius); fill[#fill+1]=center
    local top = addRoundTexture(name.."_RoundFillTop", c, ROUND_SOLID); top:SetAnchor(TOPLEFT,c,TOPLEFT,radius,0); top:SetAnchor(TOPRIGHT,c,TOPRIGHT,-radius,0); top:SetHeight(radius); fill[#fill+1]=top
    local bottom = addRoundTexture(name.."_RoundFillBottom", c, ROUND_SOLID); bottom:SetAnchor(BOTTOMLEFT,c,BOTTOMLEFT,radius,0); bottom:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-radius,0); bottom:SetHeight(radius); fill[#fill+1]=bottom
    local left = addRoundTexture(name.."_RoundFillLeft", c, ROUND_SOLID); left:SetAnchor(TOPLEFT,c,TOPLEFT,0,radius); left:SetAnchor(BOTTOMLEFT,c,BOTTOMLEFT,0,-radius); left:SetWidth(radius); fill[#fill+1]=left
    local right = addRoundTexture(name.."_RoundFillRight", c, ROUND_SOLID); right:SetAnchor(TOPRIGHT,c,TOPRIGHT,0,radius); right:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,0,-radius); right:SetWidth(radius); fill[#fill+1]=right
    local cornerData = {
        {"TL",TOPLEFT,TOPLEFT,0,0,{0,1,0,1}},
        {"TR",TOPRIGHT,TOPRIGHT,0,0,{1,0,0,1}},
        {"BL",BOTTOMLEFT,BOTTOMLEFT,0,0,{0,1,1,0}},
        {"BR",BOTTOMRIGHT,BOTTOMRIGHT,0,0,{1,0,1,0}},
    }
    for _,d in ipairs(cornerData) do
        local t = addRoundTexture(name.."_RoundFill"..d[1],c,ROUND_CORNER,d[6]); t:SetAnchor(d[2],c,d[3],d[4],d[5]); t:SetDimensions(radius,radius); fill[#fill+1]=t
    end

    -- Border: thin straight strips plus matching rounded corner arcs.
    local bt = addRoundTexture(name.."_RoundEdgeTop",c,ROUND_SOLID); bt:SetAnchor(TOPLEFT,c,TOPLEFT,radius,0); bt:SetAnchor(TOPRIGHT,c,TOPRIGHT,-radius,0); bt:SetHeight(1); edge[#edge+1]=bt
    local bb = addRoundTexture(name.."_RoundEdgeBottom",c,ROUND_SOLID); bb:SetAnchor(BOTTOMLEFT,c,BOTTOMLEFT,radius,0); bb:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-radius,0); bb:SetHeight(1); edge[#edge+1]=bb
    local bl = addRoundTexture(name.."_RoundEdgeLeft",c,ROUND_SOLID); bl:SetAnchor(TOPLEFT,c,TOPLEFT,0,radius); bl:SetAnchor(BOTTOMLEFT,c,BOTTOMLEFT,0,-radius); bl:SetWidth(1); edge[#edge+1]=bl
    local br = addRoundTexture(name.."_RoundEdgeRight",c,ROUND_SOLID); br:SetAnchor(TOPRIGHT,c,TOPRIGHT,0,radius); br:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,0,-radius); br:SetWidth(1); edge[#edge+1]=br
    for _,d in ipairs(cornerData) do
        local t = addRoundTexture(name.."_RoundEdge"..d[1],c,ROUND_BORDER,d[6]); t:SetAnchor(d[2],c,d[3],d[4],d[5]); t:SetDimensions(radius,radius); edge[#edge+1]=t
    end
end

local function panel(name, parent, x, y, w, h, color, radius)
    local isShell = tostring(name or "") == "EAS_ModernShell02890"
    -- v0.29.10: the outside shell must NOT be an ESO CT_BACKDROP. Even with a
    -- transparent edge, a native backdrop can expose its rectangular bounds
    -- around the rounded DDS. Use a plain control for the shell and let the
    -- rounded texture be the only thing that draws the outside surface.
    local c = wm:CreateControl(name, parent, isShell and CT_CONTROL or CT_BACKDROP)
    if not isShell then
        c:SetCenterTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds")
        c:SetEdgeTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds",1,1,1)
        if c.SetInsets then c:SetInsets(1,1,-1,-1) end
    end
    c:ClearAnchors()
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x or 0, y or 0)
    if w and h then c:SetDimensions(w, h) else c:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0) end

    local r = tonumber(radius) or 18
    -- Only the true outside shell suppresses the native center fallback.
    -- Large content cards must not be mistaken for the shell.
    c._shellSurface02890 = isShell
    if isShell then
        local fallback = wm:CreateControl(name.."_NativeFallback029116", c, CT_BACKDROP)
        fallback:SetAnchor(TOPLEFT, c, TOPLEFT, 14, 14)
        fallback:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -14, -14)
        fallback:SetCenterTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds")
        fallback:SetEdgeTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds", 1, 1, 1)
        if fallback.SetInsets then fallback:SetInsets(1,1,-1,-1) end
        fallback:SetCenterColor(BG[1], BG[2], BG[3], 0.96)
        fallback:SetEdgeColor(EDGE_SOFT[1], EDGE_SOFT[2], EDGE_SOFT[3], 0.42)
        fallback:SetDrawLevel(0)
        c.nativeFallback029116 = fallback
    end
    local rt = wm:CreateControl(name.."_Rounded02890", c, CT_TEXTURE)
    rt:SetAnchorFill(c)
    rt:SetTexture(c._shellSurface02890 and ROUND_SHELL_ROOT or ROUND_PANEL_ROOT)
    keepTextureResident029116(rt)
    rt:SetTextureCoords(0,1,0,1)
    if rt.SetDrawLayer and DL_BACKGROUND then rt:SetDrawLayer(DL_BACKGROUND) end
    rt:SetDrawLevel(0)
    if rt.SetPixelRoundingEnabled then rt:SetPixelRoundingEnabled(false) end
    c.roundTex02890 = rt
    c.esoTopHighlight02894 = nil
    local defaultEdge = c._shellSurface02890 and {0.12,0.20,0.30,0.46} or EDGE_SOFT
    setPanelVisual(c, color or SURFACE, defaultEdge)
    return c
end

local function flatPanel(name, parent, x, y, w, h, color, edge)
    local c = wm:CreateControl(name, parent, CT_BACKDROP)
    c:SetCenterTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds")
    c:SetEdgeTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds",1,1,1)
    if c.SetInsets then c:SetInsets(1,1,-1,-1) end
    c:ClearAnchors()
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x or 0, y or 0)
    if w and h then c:SetDimensions(w, h) else c:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0) end
    c.roundTex02890 = nil
    c.esoTopHighlight02894 = nil
    setPanelVisual(c, color or SURFACE, edge or EDGE_SOFT)
    return c
end

local function label(name, parent, text, x, y, w, h, font, color)
    local l = wm:CreateControl(name, parent, CT_LABEL)
    l:SetAnchor(TOPLEFT, parent, TOPLEFT, x or 0, y or 0)
    l:SetDimensions(w or 200, h or 28)
    l:SetFont(font or "ZoFontGame")
    l:SetColor(unpack(color or TEXT))
    l:SetText(text or "")
    l:SetVerticalAlignment(TEXT_ALIGN_TOP)
    if l.SetMaxLineCount then l:SetMaxLineCount(0) end
    return l
end

local function constrainLabel(l, maxLines, ellipsis)
    if not l then return end
    if l.SetMaxLineCount then l:SetMaxLineCount(maxLines or 0) end
    if ellipsis and l.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
end

local function splitButtonCaption(text)
    text=tostring(text or "")
    if not text:find(" ",1,true) then return text end
    local words={}
    for word in text:gmatch("%S+") do words[#words+1]=word end
    if #words<2 then return text end
    local best,bestScore=nil,math.huge
    for cut=1,#words-1 do
        local left=table.concat(words," ",1,cut)
        local right=table.concat(words," ",cut+1,#words)
        local score=math.max(#left,#right)*10+math.abs(#left-#right)
        if score<bestScore then bestScore=score; best=left.."\n"..right end
    end
    return best or text
end

local function fitButtonText(b)
    if not b then return end
    local raw = tostring(b._buttonText or (type(b.GetText) == "function" and b:GetText()) or "")
    local width = type(b.GetWidth) == "function" and tonumber(b:GetWidth()) or 0
    local height = type(b.GetHeight) == "function" and tonumber(b:GetHeight()) or 0
    local usable = math.max(24, width - 18)
    local chars = #clean(raw)
    local display = raw
    local font = "ZoFontGameBold"
    local lines = 1
    local scale = 1

    -- v0.29.67: honor manual line breaks.  The previous fitter reset the
    -- caption to one line even when a button was intentionally given two
    -- lines, which is why HOST CURRENT DUNGEON still clipped at DUNGE.
    if raw:find("\n",1,true) then
        local longest=0
        lines=0
        for line in raw:gmatch("[^\n]+") do
            lines=lines+1
            longest=math.max(longest,#clean(line))
        end
        lines=math.max(1,lines)
        font = longest * 6.0 <= usable and "ZoFontGame" or "ZoFontGameSmall"
        if longest * 5.2 > usable then scale=0.90 end
        if longest * 4.8 > usable then scale=0.82 end
    else
        -- First prefer a single readable line. If it will not fit, split only at
        -- word boundaries so button commands never lose or clip a word.
        if chars * 7.0 > usable then font = "ZoFontGame" end
        if chars * 6.1 > usable then
            if height >= 32 and raw:find(" ",1,true) then
                display = splitButtonCaption(raw)
                lines = 2
                local longest=0
                for line in display:gmatch("[^\n]+") do longest=math.max(longest,#clean(line)) end
                font = longest * 6.0 <= usable and "ZoFontGame" or "ZoFontGameSmall"
                if longest * 5.2 > usable then scale=0.90 end
                if longest * 4.8 > usable then scale=0.82 end
            else
                font = "ZoFontGameSmall"
                if chars * 5.2 > usable then scale=0.90 end
                if chars * 4.8 > usable then scale=0.82 end
            end
        end
    end

    if b.caption02895 then
        b.caption02895:SetText(display)
        b.caption02895:SetFont(font)
        if b.caption02895.SetMaxLineCount then b.caption02895:SetMaxLineCount(lines) end
        if b.caption02895.SetScale then b.caption02895:SetScale(scale) end
        b.caption02895:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    elseif b.SetFont then
        b:SetFont(font)
    end
end

local function fitRailLabel(l, text, maxWidth)
    if not l then return end
    text = tostring(text or "")
    maxWidth = tonumber(maxWidth) or 54
    l:SetText(text)
    l:SetFont("ZoFontGameSmall")
    if l.SetMaxLineCount then l:SetMaxLineCount(1) end
    if l.SetScale then l:SetScale(1) end

    -- Rail buttons never abbreviate a label because of clipping. Measure the
    -- actual rendered text when ESO exposes GetTextWidth(), otherwise use a
    -- conservative character estimate, then scale only the caption as needed.
    local textWidth = 0
    if l.GetTextWidth then
        local ok, value = pcall(l.GetTextWidth, l)
        if ok then textWidth = tonumber(value) or 0 end
    end
    if textWidth <= 0 then textWidth = #clean(text) * 6.0 end
    if textWidth > maxWidth and l.SetScale then
        l:SetScale(math.max(0.78, math.min(1.0, maxWidth / textWidth)))
    end
end

local function setButtonText(b, text)
    if not b then return end
    text = tostring(text or "")
    b._buttonText = text
    if b.caption02895 then
        if b.SetText then b:SetText("") end
    elseif b.SetText then
        b:SetText(text)
    end
    fitButtonText(b)
end

local function setButtonAlignment(b, align)
    if not b then return end
    align = align or TEXT_ALIGN_CENTER
    if b.caption02895 then b.caption02895:SetHorizontalAlignment(align) end
    if b.SetHorizontalAlignment then b:SetHorizontalAlignment(align) end
end

local function setButtonTextColor(b, r, g, bl, a)
    if not b then return end
    if b.SetNormalFontColor then b:SetNormalFontColor(r,g,bl,a) end
    if b.caption02895 then b.caption02895:SetColor(r,g,bl,a) end
end

local function styleButton(b, selected, primary)
    if not b or not b.bg then return end
    fitButtonText(b)
    b._selected = selected == true
    b._primary = primary == true
    -- v0.28.96: the alliance-colored frame/fill is the one selection cue.
    -- The older extra bottom rail created a doubled line on selected buttons.
    if b.stateRail02892 then b.stateRail02892:SetColor(0,0,0,0) end

    -- v0.28.95: one clear framed state plus one bottom state rail. Text is
    -- drawn by a fitted child label so no command word is clipped by the
    -- native button label bounds.
    if b._topNav02889 then
        if selected then
            setPanelVisual(b.bg,
                {ACCENT[1] * 0.28, ACCENT[2] * 0.28, ACCENT[3] * 0.28, 0.995},
                {ACCENT[1], ACCENT[2], ACCENT[3], 0.98})
            setButtonTextColor(b,1,1,1,1)
        else
            setPanelVisual(b.bg, {0.028,0.041,0.058,0.97}, {0.24,0.34,0.46,0.64})
            setButtonTextColor(b,0.98,0.985,1.00,1)
        end
        return
    end

    if selected then
        setPanelVisual(b.bg,
            {ACCENT[1] * 0.34, ACCENT[2] * 0.34, ACCENT[3] * 0.34, 0.995},
            {ACCENT[1], ACCENT[2], ACCENT[3], 1})
        setButtonTextColor(b,1,1,1,1)
    elseif primary then
        setPanelVisual(b.bg,
            {ACCENT[1] * 0.22, ACCENT[2] * 0.22, ACCENT[3] * 0.22, 0.995},
            {ACCENT[1], ACCENT[2], ACCENT[3], 0.94})
        setButtonTextColor(b,1,1,1,1)
    else
        setPanelVisual(b.bg, {0.048,0.064,0.086,0.995}, {0.30,0.40,0.52,0.76})
        setButtonTextColor(b,0.99,0.995,1.00,1)
    end
end

local function button(name, parent, text, x, y, w, h, handler, primary)
    local bw, bh = w or 120, h or 36
    local b = wm:CreateControl(name, parent, CT_BUTTON)
    b:SetAnchor(TOPLEFT, parent, TOPLEFT, x or 0, y or 0)
    b:SetDimensions(bw, bh)
    b:SetFont("ZoFontGameBold")
    b:SetText("")
    if b.SetHorizontalAlignment then b:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    if b.SetVerticalAlignment then b:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
    b:SetMouseEnabled(true)
    local bg = panel(name.."_BG", b, 0, 0, nil, nil, SURFACE_2, math.min(18, math.floor(bh/2)))
    bg:ClearAnchors(); bg:SetAnchor(TOPLEFT,b,TOPLEFT,0,0); bg:SetAnchor(BOTTOMRIGHT,b,BOTTOMRIGHT,0,0); bg:SetDrawLevel(0)
    if bg.roundTex02890 then bg.roundTex02890:SetTexture(ROUND_PILL_ROOT) end
    b.bg = bg

    local caption=label(name.."_Caption02895",b,"",8,3,math.max(20,bw-16),math.max(18,bh-6),"ZoFontGameBold",TEXT)
    caption:ClearAnchors(); caption:SetAnchor(TOPLEFT,b,TOPLEFT,8,3); caption:SetAnchor(BOTTOMRIGHT,b,BOTTOMRIGHT,-8,-3)
    caption:SetHorizontalAlignment(TEXT_ALIGN_CENTER); caption:SetVerticalAlignment(TEXT_ALIGN_CENTER); caption:SetDrawLevel(12)
    if caption.SetMouseEnabled then caption:SetMouseEnabled(false) end
    if caption.SetMaxLineCount then caption:SetMaxLineCount(2) end
    b.caption02895=caption

    local stateRail=wm:CreateControl(name.."_StateRail02892",b,CT_TEXTURE)
    stateRail:SetAnchor(BOTTOMLEFT,b,BOTTOMLEFT,8,-2); stateRail:SetAnchor(BOTTOMRIGHT,b,BOTTOMRIGHT,-8,-2)
    stateRail:SetHeight(3); stateRail:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds")
    stateRail:SetColor(0,0,0,0); stateRail:SetDrawLevel(8); b.stateRail02892=stateRail
    b._primary = primary == true
    setButtonText(b,text or "")
    styleButton(b, false, b._primary)
    if b.SetMouseOverFontColor then b:SetMouseOverFontColor(1,1,1,1) end
    if handler then b:SetHandler("OnClicked", handler) end
    b:SetHandler("OnMouseEnter", function(c)
        if c.bg then setPanelVisual(c.bg, {ACCENT[1]*0.18,ACCENT[2]*0.18,ACCENT[3]*0.18,0.995}, {ACCENT[1],ACCENT[2],ACCENT[3],1}) end
        if c.caption02895 then c.caption02895:SetColor(1,1,1,1) end
    end)
    b:SetHandler("OnMouseExit", function(c)
        styleButton(c, c._selected == true, c._primary == true)
    end)
    return b
end

local function editBox(name, parent, x, y, w, h, multi)
    local host = panel(name.."_Host", parent, x, y, w, h, SURFACE_2)
    local e = wm:CreateControl(name, host, CT_EDITBOX)
    e:SetAnchor(TOPLEFT, host, TOPLEFT, 12, 8)
    e:SetAnchor(BOTTOMRIGHT, host, BOTTOMRIGHT, -12, -8)
    e:SetFont("ZoFontGame")
    e:SetColor(unpack(TEXT))

    -- v0.29.41: make the full visible input field focus the edit control.
    -- Some single-line fields (notably CHECKPOINT NAME) could display text but
    -- fail to take keyboard focus when the backdrop area was clicked.
    e:SetMouseEnabled(true)
    if e.SetKeyboardEnabled then e:SetKeyboardEnabled(true) end
    if e.SetEditEnabled then e:SetEditEnabled(true) end
    if e.SetCopyEnabled then e:SetCopyEnabled(true) end
    if e.SetPasteEnabled then e:SetPasteEnabled(true) end
    if e.SetTextType and TEXT_TYPE_ALL then e:SetTextType(TEXT_TYPE_ALL) end
    if e.SetMaxInputChars then e:SetMaxInputChars(multi == true and 12000 or 120) end
    if e.SetMultiLine then e:SetMultiLine(multi == true) end
    if multi == true and e.SetNewLineEnabled then e:SetNewLineEnabled(true) end

    local function focusEdit(edit)
        if edit and edit.TakeFocus then edit:TakeFocus() end
    end
    e:SetHandler("OnMouseDown", function(edit) focusEdit(edit) end)
    e:SetHandler("OnMouseUp", function(edit, button, upInside)
        if upInside ~= false then focusEdit(edit) end
    end)

    -- v0.29.45: CT_EDITBOX owns keyboard focus while Notes or Checkpoints are
    -- being edited, which prevents ESO's normal action-layer keybind from
    -- reaching the Suite toggle. Capture the raw key on every modern editor so
    -- the same hotkey always closes the Suite, even while the cursor is active.
    e:SetHandler("OnKeyDown", function(edit, key, ctrl, alt, shift, command)
        if M.window and not M.window:IsHidden()
            and J.RawKeyMatchesAction
            and J:RawKeyMatchesAction("ESO_PROGRESSION_COACH_TOGGLE", key, ctrl, alt, shift, command) then
            if edit.LoseFocus then edit:LoseFocus() end
            M:Hide()
        end
    end)

    -- The backdrop is what visually fills the entire input rectangle. Route
    -- clicks on its padding into the child edit box as well.
    host:SetMouseEnabled(true)
    host:SetHandler("OnMouseDown", function() focusEdit(e) end)
    host:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside ~= false then focusEdit(e) end
    end)
    return e, host
end

local function setEnabled(b, enabled)
    if not b then return end
    if b.SetEnabled then b:SetEnabled(enabled == true) end
    if b.SetMouseEnabled then b:SetMouseEnabled(enabled == true) end
    if enabled then
        b:SetAlpha(1)
        styleButton(b, b._selected == true, b._primary == true)
    else
        -- Disabled controls stay visibly present so the user can understand
        -- the available action without mistaking it for missing UI.
        b:SetAlpha(0.84)
        if b.bg then setPanelVisual(b.bg,{0.034,0.046,0.063,0.98},{0.22,0.30,0.40,0.58}) end
        setButtonTextColor(b,0.76,0.79,0.84,1)
    end
end

local function groupForTab(tab)
    for group, tabs in pairs(GROUPS) do
        for _, value in ipairs(tabs) do if value == tab then return group end end
    end
    return "HOME"
end

local function trimLine(text)
    text=tostring(text or "")
    text=text:gsub("^%s+",""):gsub("%s+$","")
    return text
end

local function isInfoHeading(line)
    line=trimLine(clean(line))
    if line=="" then return false end
    if #line<=44 and line:match("^[A-Z][A-Z%s/&%+%-%(%)]+$") then return true end
    if #line<=44 and line:sub(-1)==":" then return true end
    return false
end

local function organizeInfoText(text, defaultTitle)
    local out={}
    if defaultTitle and tostring(defaultTitle)~="" then out[#out+1]=string.upper(clean(defaultTitle)) end
    local lastWasHeading=defaultTitle and true or false
    for raw in tostring(text or ""):gmatch("[^\n]+") do
        local line=trimLine(clean(raw))
        if line~="" then
            if isInfoHeading(line) then
                if #out>0 and out[#out]~="" then out[#out+1]="" end
                out[#out+1]=line:gsub(":$","")
                lastWasHeading=true
            else
                if line:sub(1,3)=="• " or line:sub(1,2)=="- " then
                    out[#out+1]=line
                else
                    out[#out+1]="• "..line
                end
                lastWasHeading=false
            end
        elseif not lastWasHeading and #out>0 and out[#out]~="" then
            out[#out+1]=""
        end
    end
    return table.concat(out,"\n")
end

local function infoSections(sections)
    local out={}
    for _,section in ipairs(sections or {}) do
        local head=trimLine(section[1])
        local items=section[2] or {}
        if head~="" then
            if #out>0 then out[#out+1]="" end
            out[#out+1]=string.upper(head)
        end
        for _,item in ipairs(items) do
            item=trimLine(clean(item))
            if item~="" then out[#out+1]="• "..item end
        end
    end
    return table.concat(out,"\n")
end

local function wrapTextWords(text, maxChars)
    maxChars=math.max(24,tonumber(maxChars) or 68)
    local out={}
    local source=tostring(text or "")
    local bulletPrefix="• "
    for raw in (source.."\n"):gmatch("(.-)\n") do
        local line=trimLine(raw)
        if line=="" or #line<=maxChars then
            out[#out+1]=line
        else
            local prefix=""
            local content=line
            -- The bullet is UTF-8. Use the byte length of the full prefix instead
            -- of sub(1,3), which only captured the bullet bytes and dropped the
            -- following space. That old test caused wrapped bullets to run into
            -- the next item in ESO labels.
            if line:sub(1,#bulletPrefix)==bulletPrefix then
                prefix=bulletPrefix
                content=line:sub(#bulletPrefix+1)
            end
            local current=prefix
            for word in content:gmatch("%S+") do
                local spacer=(current=="" or current==prefix) and "" or " "
                local candidate=current..spacer..word
                if #candidate>maxChars and current~=prefix and current~="" then
                    out[#out+1]=current
                    current=(prefix~="" and "  " or "")..word
                else
                    current=candidate
                end
            end
            if current~="" then out[#out+1]=current end
        end
    end
    while #out>1 and out[#out]=="" do table.remove(out) end
    return table.concat(out,"\n")
end

local function textLines(text)
    local lines={}
    text=tostring(text or "")
    if text=="" then return {""} end
    for line in (text.."\n"):gmatch("(.-)\n") do
        lines[#lines+1]=line
    end
    while #lines>1 and lines[#lines]=="" do table.remove(lines) end
    if #lines==0 then lines[1]="" end
    return lines
end

local function viewStat(view, label, fallback)
    label=string.upper(tostring(label or ""))
    for _,stat in ipairs((view and view.stats) or {}) do
        if string.upper(tostring(stat.label or ""))==label then return clean(stat.value or fallback or "") end
    end
    return clean(fallback or "")
end

local function appendInfo(items, label, value)
    value=trimLine(clean(value))
    if value~="" then items[#items+1]=tostring(label)..": "..value end
end

local function paginateInfoSections(sections, page, maxLines, maxChars)
    maxLines=math.max(6,tonumber(maxLines) or 9)
    maxChars=math.max(24,tonumber(maxChars) or 46)
    local pages={{}}

    local function currentPage()
        return pages[#pages]
    end
    local function newPage()
        if #currentPage()==0 then return currentPage() end
        pages[#pages+1]={}
        return currentPage()
    end
    local function addLine(line)
        currentPage()[#currentPage()+1]=line
    end
    local function wrappedItem(item)
        local lines=textLines(wrapTextWords("• "..trimLine(clean(item)),maxChars))
        if #lines==0 then lines={"• "..trimLine(clean(item))} end
        return lines
    end

    for _,section in ipairs(sections or {}) do
        local head=string.upper(trimLine(section[1] or ""))
        local items=section[2] or {}
        if head~="" then
            -- Keep a heading with at least one item whenever possible. This
            -- prevents pages from ending on a lonely heading such as HOW TO USE.
            if #currentPage()>0 then
                local firstLines=(#items>0 and wrappedItem(items[1])) or {}
                local needed=1 + (#firstLines>0 and #firstLines or 0) + 1
                if #currentPage()+needed>maxLines then newPage() end
                if #currentPage()>0 then addLine("") end
            end
            addLine(head)
        end

        for _,item in ipairs(items) do
            item=trimLine(clean(item))
            if item~="" then
                local lines=wrappedItem(item)
                -- Never split one information bullet across pages unless the
                -- bullet itself is taller than an entire page.
                if #currentPage()>0 and (#currentPage()+#lines)>maxLines then
                    newPage()
                    if head~="" then addLine(head.." (CONT.)") end
                end
                for _,line in ipairs(lines) do
                    if #currentPage()>=maxLines then
                        newPage()
                        if head~="" then addLine(head.." (CONT.)") end
                    end
                    addLine(line)
                end
            end
        end
    end

    -- Remove empty trailing lines so the pagination controls always have a
    -- clean gap above them.
    for _,pg in ipairs(pages) do
        while #pg>0 and pg[#pg]=="" do table.remove(pg) end
    end
    if #pages==0 then pages={{"No information available."}} end
    page=math.max(1,math.min(#pages,tonumber(page) or 1))
    return table.concat(pages[page],"\n"),page,#pages
end

local function questOverviewSections(view)
    view=view or {}
    local search=trimLine(clean(view.searchText or ""))
    local filter=viewStat(view,"FILTER",view.filter or "NOT STARTED")
    local indexValue=viewStat(view,"INDEX",view.scanProgress or tostring(view.indexed or 0))
    local page=tonumber(view.page) or 1
    local pageCount=tonumber(view.pageCount) or 1
    return {
        {"CURRENT VIEW",{
            "Filter: "..(filter~="" and filter or "NOT STARTED"),
            "Matches: "..tostring(tonumber(view.total) or 0),
            "List page: "..tostring(page).." / "..tostring(pageCount),
            "Quest index: "..(indexValue~="" and indexValue or "Unavailable"),
            "Search: "..(search~="" and search or "None"),
        }},
        {"HOW TO USE",{
            "Select a quest to show its complete available record.",
            "ROUTE QUEST: set the Suite route to the resolved quest zone.",
            "TRAVEL WAYSHRINE: travel toward the nearest resolved wayshrine.",
        }},
        {"INDEX NOTE",{
            "ESO does not expose one global list of every quest obtainable right now.",
            "The Suite scans runtime quest records and filters retired or internal records on a best-effort basis.",
        }},
    }
end

local function questOverviewText(view)
    return infoSections(questOverviewSections(view))
end

local function gearOverviewSections(view)
    view=view or {}
    local search=trimLine(clean(view.searchText or ""))
    local filter=viewStat(view,"FILTER",view.filter or "ALL")
    local page=tonumber(view.page) or 1
    local pageCount=tonumber(view.pageCount) or 1
    local sections = {
        {"CURRENT VIEW",{
            "Filter: "..(filter~="" and filter or "ALL"),
            "Matches: "..tostring(tonumber(view.total) or 0),
            "List page: "..tostring(page).." / "..tostring(pageCount),
            "Search: "..(search~="" and search or "None"),
        }},
        {"HOW TO USE",{
            "Select a set to show its collection, piece mix, source, and routing details.",
            "SEARCH: find a set by name or source category.",
            "Use ALL, OVERLAND, DUNGEON, or TRIAL to narrow the list.",
        }},
        {"ACTION GUIDE",{
            "EQUIP BEST: use the Suite's general owned-gear scoring.",
            "BEST ENDGAME: compare worn + backpack gear to the curated live meta snapshot for your class, role, resource, and preset.",
            "BEST ENDGAME prints any missing meta pieces in chat instead of pretending an unavailable item is owned.",
            "FAST TRAVEL / ROUTE SOURCE / ZONE QUESTS: navigate toward the selected set source.",
        }},
    }
    if EPC.GearOptimizer and type(EPC.GearOptimizer.GetMetaSummaryLines)=="function" then
        sections[#sections+1]={"ENDGAME META",EPC.GearOptimizer:GetMetaSummaryLines()}
    end
    return sections
end

local function gearSelectedSections(view,sel)
    view=view or {}
    sel=sel or {}
    local collected=string.format("%d / %d",tonumber(sel.unlocked) or 0,tonumber(sel.total) or 0)
    local pieces=trimLine(clean(sel.kindText or viewStat(view,"PIECES","Set pieces")))
    local source=trimLine(clean(sel.sourceText or "Source category unavailable"))
    local setId=tonumber(sel.setId) or 0
    local collectionItems={
        "Collected: "..collected,
        "Pieces: "..(pieces~="" and pieces or "Set pieces"),
    }
    if setId>0 then collectionItems[#collectionItems+1]="Set ID: "..tostring(setId) end
    local sections = {
        {"COLLECTION",collectionItems},
        {"SOURCE",{
            source,
        }},
        {"ROUTING",{
            "FAST TRAVEL: use a matching discovered wayshrine when available.",
            "ROUTE SOURCE: route toward the closest matching source area.",
            "ZONE QUESTS: browse quests from the closest matching source zone.",
        }},
        {"OPTIMIZATION",{
            "Use the buttons below for saved builds, weapons, jewelry, potions, Light/Medium/Heavy armor, companion tools, and the Endgame optimizer.",
            "Use MAX POWER BUILD on the Skills page for content-aware abilities, morphs, passives, and both weapon bars.",
            "BEST ENDGAME uses the curated live meta snapshot when one exists for your class, role, resource, and selected preset.",
        }},
    }
    if EPC.GearOptimizer and type(EPC.GearOptimizer.GetMetaSummaryLines)=="function" then
        sections[#sections+1]={"ENDGAME META",EPC.GearOptimizer:GetMetaSummaryLines()}
    end
    return sections
end

local function getLiveQuestJournalSections(sel)
    local qIndex=tonumber(sel and sel.questIndex) or 0
    if qIndex<=0 then return {},{} end

    local journalItems={}
    local objectiveItems={}
    local seenObjectives={}
    local backgroundText=""

    if type(GetJournalQuestInfo)=="function" then
        local ok,_,background,activeStepText,_,activeOverride,completed,tracked,questLevel=pcall(GetJournalQuestInfo,qIndex)
        if ok then
            if tracked~=nil then appendInfo(journalItems,"Tracked",tracked and "Yes" or "No") end
            if tonumber(questLevel) and tonumber(questLevel)>0 then appendInfo(journalItems,"Quest level",tostring(questLevel)) end
            if completed~=nil then appendInfo(journalItems,"Completed",completed and "Yes" or "No") end
            local step=trimLine(clean(activeOverride or ""))
            if step=="" then step=trimLine(clean(activeStepText or "")) end
            if step~="" then appendInfo(journalItems,"Current step",step) end
            backgroundText=trimLine(clean(background or ""))
        end
    end

    if type(GetJournalQuestLocationInfo)=="function" then
        local ok,locationName,objectiveName=pcall(GetJournalQuestLocationInfo,qIndex)
        if ok then
            locationName=trimLine(clean(locationName or ""))
            objectiveName=trimLine(clean(objectiveName or ""))
            if locationName~="" then appendInfo(journalItems,"Journal location",locationName) end
            if objectiveName~="" and objectiveName~=locationName then appendInfo(journalItems,"Objective area",objectiveName) end
        end
    end

    local numSteps=0
    if type(GetJournalQuestNumSteps)=="function" then
        local ok,value=pcall(GetJournalQuestNumSteps,qIndex)
        if ok then numSteps=tonumber(value) or 0 end
    end
    if numSteps>0 and type(GetJournalQuestNumConditions)=="function" and type(GetJournalQuestConditionInfo)=="function" then
        for stepIndex=1,numSteps do
            local visibleStep=true
            if type(GetJournalQuestStepInfo)=="function" then
                local ok,_,visibility=pcall(GetJournalQuestStepInfo,qIndex,stepIndex)
                if ok and rawget(_G,"QUEST_STEP_VISIBILITY_HIDDEN")~=nil and visibility==QUEST_STEP_VISIBILITY_HIDDEN then visibleStep=false end
            end
            if visibleStep then
                local okCount,count=pcall(GetJournalQuestNumConditions,qIndex,stepIndex)
                count=okCount and (tonumber(count) or 0) or 0
                for conditionIndex=1,count do
                    local ok,text,current,maximum,isFail,isComplete,_,isVisible=pcall(GetJournalQuestConditionInfo,qIndex,stepIndex,conditionIndex,true)
                    if ok and isVisible~=false and isFail~=true and isComplete~=true then
                        text=trimLine(clean(text or ""))
                        if text~="" and not seenObjectives[text] then
                            seenObjectives[text]=true
                            local progress=""
                            current=tonumber(current); maximum=tonumber(maximum)
                            if current and maximum and maximum>1 then
                                local token=tostring(current).."/"..tostring(maximum)
                                if not text:find(token,1,true) then progress=" ("..token..")" end
                            end
                            objectiveItems[#objectiveItems+1]=text..progress
                        end
                    end
                end
            end
        end
    end

    if #objectiveItems==0 then
        local stepValue=""
        for _,item in ipairs(journalItems) do
            if tostring(item):find("Current step:",1,true)==1 then stepValue=tostring(item):sub(#"Current step:"+2); break end
        end
        if stepValue~="" then objectiveItems[#objectiveItems+1]=stepValue end
    end

    local extraSections={}
    if #journalItems>0 then extraSections[#extraSections+1]={"LIVE JOURNAL",journalItems} end
    if #objectiveItems>0 then extraSections[#extraSections+1]={"CURRENT OBJECTIVES",objectiveItems} end
    if backgroundText~="" then extraSections[#extraSections+1]={"QUEST BACKGROUND",{backgroundText}} end
    return extraSections,objectiveItems
end

local function questSelectedSections(sel)
    sel=sel or {}
    local statusItems={}
    appendInfo(statusItems,"Status",sel.status or (sel.completed and "COMPLETED" or "UNKNOWN"))
    if sel.questIndex then
        appendInfo(statusItems,"Journal","Accepted / active")
    elseif sel.completed then
        appendInfo(statusItems,"Journal","Completed")
    else
        appendInfo(statusItems,"Journal","Not accepted")
    end
    if sel.chainOrder then appendInfo(statusItems,"Chain position",tostring(sel.chainOrder)) end
    if sel.objectiveProgress then appendInfo(statusItems,"Objective progress",sel.objectiveProgress) end

    local locationItems={}
    appendInfo(locationItems,"Zone",sel.zone or sel.zoneName)
    appendInfo(locationItems,"Quest starter",sel.starter)
    appendInfo(locationItems,"Quest giver",sel.questGiver)
    appendInfo(locationItems,"Accept at",sel.acceptAt)

    local recordItems={}
    appendInfo(recordItems,"Type",sel.type)
    appendInfo(recordItems,"Access",sel.access)
    if sel.dlc~=nil then appendInfo(recordItems,"DLC",sel.dlc and "Yes" or "No") end
    if tonumber(sel.questId) and tonumber(sel.questId)>0 then appendInfo(recordItems,"Quest ID",tostring(sel.questId)) end
    if tonumber(sel.zoneId) and tonumber(sel.zoneId)>0 then appendInfo(recordItems,"Zone ID",tostring(sel.zoneId)) end
    if tonumber(sel.rawZoneId) and tonumber(sel.rawZoneId)>0 and tonumber(sel.rawZoneId)~=tonumber(sel.zoneId) then appendInfo(recordItems,"Raw zone ID",tostring(sel.rawZoneId)) end

    local routeItems={}
    appendInfo(routeItems,"Prerequisite",sel.prerequisite)
    appendInfo(routeItems,"Route note",sel.routeNote)
    if sel.targetQuestName then appendInfo(routeItems,"Next target",sel.targetQuestName) end

    local sections={{"QUEST STATUS",statusItems}}
    local liveSections=getLiveQuestJournalSections(sel)
    for _,section in ipairs(liveSections or {}) do sections[#sections+1]=section end
    sections[#sections+1]={"LOCATION & START",locationItems}
    sections[#sections+1]={"QUEST RECORD",recordItems}
    if #routeItems>0 then sections[#sections+1]={"ROUTE / PROGRESSION",routeItems} end

    if sel.objectiveQuests and tostring(sel.objectiveQuests)~="" then
        local questLines={}
        for line in tostring(sel.objectiveQuests):gmatch("[^\n]+") do
            line=trimLine(line)
            if line~="" then questLines[#questLines+1]=line end
        end
        if #questLines>0 then sections[#sections+1]={"OBJECTIVE QUESTS",questLines} end
    end

    if not sel.questIndex and not sel.completed then
        sections[#sections+1]={"DATA AVAILABILITY",{
            "This is an unaccepted quest record, so ESO does not expose live step or condition text yet.",
            "Live journal objectives and exact current objective details appear after the quest is accepted.",
        }}
    end
    return sections
end

local function questSelectedText(sel)
    return infoSections(questSelectedSections(sel))
end

local function paginateColumns(text, page, linesPerColumn)
    local lines=textLines(text)
    local per=math.max(8,tonumber(linesPerColumn) or 16)
    local pageSize=per*2
    local pages=math.max(1,math.ceil(#lines/pageSize))
    page=math.max(1,math.min(pages,tonumber(page) or 1))
    local first=(page-1)*pageSize+1
    local left,right={},{}
    for i=0,pageSize-1 do
        local line=lines[first+i]
        if not line then break end
        if i<per then left[#left+1]=line else right[#right+1]=line end
    end
    return table.concat(left,"\n"),table.concat(right,"\n"),page,pages,#lines
end

local function paginateSingle(text, page, linesPerPage)
    local lines=textLines(text)
    local per=math.max(6,tonumber(linesPerPage) or 18)
    local pages=math.max(1,math.ceil(#lines/per))
    page=math.max(1,math.min(pages,tonumber(page) or 1))
    local first=(page-1)*per+1
    local out={}
    for i=0,per-1 do
        if not lines[first+i] then break end
        out[#out+1]=lines[first+i]
    end
    return table.concat(out,"\n"),page,pages,#lines
end

local function EAS_CreateShellCore(self)
    if self.window then return end
    local allianceId, allianceName = updateAlliancePalette()
    self.allianceId, self.allianceName = allianceId, allianceName
    local s = J:EnsureSaved()
    -- v0.29.30: make the minimum readable size the default starting size.
    -- Migrate once so existing installs also start this version at 980x600,
    -- then preserve whatever size the player chooses afterward.
    if not s.modernAppDefaultMinSize02930 then
        s.modernAppWidth02880 = 980
        s.modernAppHeight02880 = 600
        s.modernAppDefaultMinSize02930 = true
    end
    -- v0.29.363: the 980x600 migration made the modern Suite unnecessarily
    -- small on 1440p/4K displays. Enlarge only installs that are still sitting
    -- at that old minimum; preserve any size the player already chose.
    if not s.modernAppReadableDefault029363 then
        local oldW = tonumber(s.modernAppWidth02880) or 980
        local oldH = tonumber(s.modernAppHeight02880) or 600
        if oldW <= 990 and oldH <= 610 then
            s.modernAppWidth02880 = 1260
            s.modernAppHeight02880 = 780
        end
        s.modernAppReadableDefault029363 = true
    end
    local w = tonumber(s.modernAppWidth02880) or 1260
    local h = tonumber(s.modernAppHeight02880) or 780
    w = math.max(980, math.min(1600, w))
    h = math.max(600, math.min(1000, h))

    local root = wm:CreateTopLevelWindow("EAS_ModernApplication02880")
    root:SetDimensions(w,h)
    root:SetDimensionConstraints(980,600,1600,1000)
    root:SetAnchor(CENTER,GuiRoot,CENTER,0,-4)
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:SetMouseEnabled(true)
    -- 0.29.09: disable ESO's native resize boundary/handle. On the modern
    -- application it renders as a bright white outline/bracket around the
    -- outside of the rounded shell. The Suite window remains movable.
    root:SetResizeHandleSize(0)
    root:SetHidden(true)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetDrawTier(DT_HIGH)
    if tonumber(s.modernAppLeft02880) and tonumber(s.modernAppTop02880) then
        root:ClearAnchors(); root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,s.modernAppLeft02880,s.modernAppTop02880)
    end
    self.window=root

    -- v0.29.10: no rectangular fallback/backdrop behind the rounded shell.
    -- The rounded shell texture is the complete outer background. This removes
    -- the transparent rectangular area/outline visible around the application.
    self.shellFallback=nil
    self.glassBackdrop02899=nil
    local shell=panel("EAS_ModernShell02890",root,0,0,nil,nil,BG,34)
    shell:ClearAnchors(); shell:SetAnchorFill(root); shell:SetDrawLevel(1)
    -- Keep the rounded shell visible above the shared glass backing. The shell
    -- itself still has no native edge, so there is no outside black perimeter.
    shell:SetHidden(false)
    self.shell=shell

    -- Integrated icon rail, visually part of the shell rather than a box.
    local rail=wm:CreateControl("EAS_ModernRail02890",root,CT_CONTROL)
    rail:SetAnchor(TOPLEFT,root,TOPLEFT,0,0); rail:SetAnchor(BOTTOMLEFT,root,BOTTOMLEFT,0,0); rail:SetWidth(RAIL_W)
    rail:SetDrawLevel(10); self.rail=rail

    -- v0.28.93: no full-height rectangle behind the icon rail.  The rail is
    -- part of the main shell; only the individual icon buttons carry surfaces.
    self.railShade=nil

    local vline=wm:CreateControl("EAS_ModernRailDivider02890",root,CT_TEXTURE)
    vline:SetAnchor(TOPLEFT,root,TOPLEFT,RAIL_W,20); vline:SetAnchor(BOTTOMLEFT,root,BOTTOMLEFT,RAIL_W,-20); vline:SetWidth(1)
    vline:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds"); vline:SetColor(EDGE[1],EDGE[2],EDGE[3],0.48); vline:SetDrawLevel(8); vline:SetHidden(true)

    local top=wm:CreateControl("EAS_ModernTop02890",root,CT_CONTROL)
    top:SetAnchor(TOPLEFT,root,TOPLEFT,RAIL_W,0); top:SetAnchor(TOPRIGHT,root,TOPRIGHT,0,0); top:SetHeight(TOP_H)
    top:SetDrawLevel(10); self.top=top

    local topLine=wm:CreateControl("EAS_ModernTopDivider02890",root,CT_TEXTURE)
    topLine:SetAnchor(TOPLEFT,root,TOPLEFT,RAIL_W+22,TOP_H); topLine:SetAnchor(TOPRIGHT,root,TOPRIGHT,-22,TOP_H); topLine:SetHeight(1)
    topLine:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds"); topLine:SetColor(EDGE[1],EDGE[2],EDGE[3],0.48); topLine:SetDrawLevel(8); topLine:SetHidden(true)

    -- v0.29.27: show the live player's highest-resolution ESO alliance crest
    -- instead of scaling up the smaller campaign symbol.
    local logoGlow=wm:CreateControl("EAS_ModernLogoGlow02890",rail,CT_TEXTURE)
    logoGlow:SetAnchor(TOP,rail,TOP,0,16); logoGlow:SetDimensions(44,44); logoGlow:SetTexture("EsoUI/Art/Champion/champion_point_glow.dds")
    logoGlow:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],0.20); logoGlow:SetDrawLevel(3); self.logoGlow=logoGlow
    local logoIcon=wm:CreateControl("EAS_ModernAllianceLogo02927",rail,CT_TEXTURE)
    logoIcon:SetAnchor(TOP,rail,TOP,0,19); logoIcon:SetDimensions(40,40); logoIcon:SetDrawLevel(10)
    local initialAllianceIcon=allianceSymbolPath(allianceId)
    if initialAllianceIcon then logoIcon:SetTexture(initialAllianceIcon) end
    logoIcon:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],1); logoIcon:SetHidden(not initialAllianceIcon); self.logoIcon=logoIcon
    local logoText=label("EAS_ModernLogoText02890",rail,"A",0,24,RAIL_W,28,"ZoFontWinH2",ACCENT)
    logoText:SetHorizontalAlignment(TEXT_ALIGN_CENTER); logoText:SetHidden(initialAllianceIcon ~= nil); self.logoText=logoText

    self.brand=label("EAS_ModernBrand02890",top,"ESO ADVENTURER SUITE",24,18,270,28,"ZoFontWinH2")
    self.sectionCrumb=label("EAS_ModernCrumb02890",top,"HOME",26,44,250,16,"ZoFontGameSmall",MUTED)

    self.groupButtons={}
    local gx=310
    for i,group in ipairs(GROUP_ORDER) do
        local b=button("EAS_ModernGroup02890_"..group,top,group,gx+(i-1)*106,15,98,40,function()
            -- Keep FINDERS opening inside the Suite on Dungeon Finder; the rail
            -- then exposes the full ESO-style finder choices.
            self:SetTab(group=="FINDERS" and "GROUPFINDER" or GROUPS[group][1])
        end)
        b._topNav02889=true; self.groupButtons[group]=b
    end

    -- v0.29.13: remove the compact character/profile block from the top-right.
    -- It crowded the close button and was often clipped at smaller Suite widths.
    self.profileName=nil
    self.profileSub=nil
    self.closeButton=button("EAS_ModernClose02890",top,"X",0,0,38,38,function() J:Hide() end)
    self.closeButton:ClearAnchors(); self.closeButton:SetAnchor(TOPRIGHT,top,TOPRIGHT,-16,16)

    -- Kept only for compatibility with older references.  Rail names now use
    -- the existing header crumb instead of floating over page content.
    self.railTip=label("EAS_ModernRailTip02890",root,"",0,0,190,30,"ZoFontGameBold")
    self.railTip:SetHidden(true); self.railTip:SetDrawLevel(100)

    local bodyViewport=wm:CreateControl("EAS_ModernBodyViewport02890",root,CT_CONTROL)
    bodyViewport:SetAnchor(TOPLEFT,root,TOPLEFT,RAIL_W+26,TOP_H+20)
    bodyViewport:SetAnchor(BOTTOMRIGHT,root,BOTTOMRIGHT,-22,-22)
    self.bodyViewport=bodyViewport
    local body=wm:CreateControl("EAS_ModernBody02890",bodyViewport,CT_CONTROL)
    body:SetDimensions(CONTENT_W,CONTENT_H); body:SetAnchor(CENTER,bodyViewport,CENTER,0,0); self.body=body

    self.pages={}; self.railButtons={}; self:BuildRail()

    -- v0.29.14: invisible resize hit zones. There is no visible grip/button;
    -- drag the right edge, bottom edge, or bottom-right corner directly.
    self.resizeGrip=nil
    self.resizeHit=nil

    local function resizeOnUpdate029315()
        if not self._resizing02911 then return end
        local mx,my=GetUIMousePosition()
        local dw=(tonumber(mx) or 0)-(tonumber(self._resizeStartMouseX) or 0)
        local dh=(tonumber(my) or 0)-(tonumber(self._resizeStartMouseY) or 0)
        local mode=self._resizeMode02914 or "BOTH"
        local currentW=root:GetWidth() or 980
        local currentH=root:GetHeight() or 600
        local newW=currentW
        local newH=currentH
        if mode=="RIGHT" or mode=="BOTH" then
            newW=math.max(980,math.min(1600,(tonumber(self._resizeStartW) or currentW)+dw))
        end
        if mode=="BOTTOM" or mode=="BOTH" then
            newH=math.max(600,math.min(1000,(tonumber(self._resizeStartH) or currentH)+dh))
        end
        if newW~=currentW or newH~=currentH then
            root:SetDimensions(newW,newH)
            self._lastReflowW,self._lastReflowH=newW,newH
            self:Reflow()
        end
    end

    local function beginInvisibleResize(mode)
        self._resizing02911=true
        self._resizeMode02914=mode
        self._resizeStartMouseX,self._resizeStartMouseY=GetUIMousePosition()
        self._resizeStartW=root:GetWidth()
        self._resizeStartH=root:GetHeight()
        root:SetHandler("OnUpdate",resizeOnUpdate029315)
    end

    local function finishInvisibleResize()
        if not self._resizing02911 then return end
        self._resizing02911=false
        self._resizeMode02914=nil
        root:SetHandler("OnUpdate",nil)
        local sv=J:EnsureSaved()
        sv.modernAppWidth02880=root:GetWidth()
        sv.modernAppHeight02880=root:GetHeight()
        self:Reflow()
    end

    local function makeInvisibleResizeZone(name, mode, anchor1, relative1, relativePoint1, x1, y1, anchor2, relative2, relativePoint2, x2, y2)
        local hit=wm:CreateControl(name,root,CT_BUTTON)
        hit:ClearAnchors()
        hit:SetAnchor(anchor1,relative1,relativePoint1,x1,y1)
        hit:SetAnchor(anchor2,relative2,relativePoint2,x2,y2)
        hit:SetMouseEnabled(true)
        hit:SetDrawLevel(200)
        hit:SetHandler("OnMouseDown",function(_,button)
            if button==MOUSE_BUTTON_INDEX_LEFT then beginInvisibleResize(mode) end
        end)
        hit:SetHandler("OnMouseUp",function(_,button)
            if button==MOUSE_BUTTON_INDEX_LEFT then finishInvisibleResize() end
        end)
        return hit
    end

    -- Keep these narrow so they don't interfere with normal controls near the edge.
    self.resizeRight02914=makeInvisibleResizeZone("EAS_ModernResizeRight02914","RIGHT",TOPRIGHT,root,TOPRIGHT,-7,74,BOTTOMRIGHT,root,BOTTOMRIGHT,0,-22)
    self.resizeBottom02914=makeInvisibleResizeZone("EAS_ModernResizeBottom02914","BOTTOM",BOTTOMLEFT,root,BOTTOMLEFT,74,-7,BOTTOMRIGHT,root,BOTTOMRIGHT,-22,0)
    self.resizeCorner02914=wm:CreateControl("EAS_ModernResizeCorner02914",root,CT_BUTTON)
    self.resizeCorner02914:SetDimensions(24,24)
    self.resizeCorner02914:SetAnchor(BOTTOMRIGHT,root,BOTTOMRIGHT,0,0)
    self.resizeCorner02914:SetMouseEnabled(true)
    self.resizeCorner02914:SetDrawLevel(201)
    self.resizeCorner02914:SetHandler("OnMouseDown",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then beginInvisibleResize("BOTH") end
    end)
    self.resizeCorner02914:SetHandler("OnMouseUp",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then finishInvisibleResize() end
    end)

    root:SetHandler("OnMoveStop",function()
        local sv=J:EnsureSaved(); sv.modernAppLeft02880=root:GetLeft(); sv.modernAppTop02880=root:GetTop()
    end)
    root:SetHandler("OnResizeStop",function()
        local sv=J:EnsureSaved(); sv.modernAppWidth02880=root:GetWidth(); sv.modernAppHeight02880=root:GetHeight(); self:Reflow()
    end)


    self:Reflow(); self:ApplyWindowAppearance029363(); self:RefreshProfile()
end

function M:Reflow()
    if not self.window or not self.bodyViewport or not self.body then return end
    local rootW=self.window:GetWidth() or BASE_W
    local rootH=self.window:GetHeight() or BASE_H

    -- The slim icon rail is always functional in the reference layout, so it is
    -- always present; there is never an empty decorative left panel.
    if self.rail then self.rail:SetHidden(false) end
    if self.top then
        self.top:ClearAnchors(); self.top:SetAnchor(TOPLEFT,self.window,TOPLEFT,RAIL_W,0); self.top:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,0,0); self.top:SetHeight(TOP_H)
    end
    self.bodyViewport:ClearAnchors(); self.bodyViewport:SetAnchor(TOPLEFT,self.window,TOPLEFT,RAIL_W+26,TOP_H+20); self.bodyViewport:SetAnchor(BOTTOMRIGHT,self.window,BOTTOMRIGHT,-22,-22)

    local vw,vh=self.bodyViewport:GetWidth(),self.bodyViewport:GetHeight()
    if not vw or not vh or vw<=0 or vh<=0 then return end
    local scale=math.min(vw/CONTENT_W,vh/CONTENT_H); scale=math.max(0.64,math.min(1.18,scale))
    self.body:SetScale(scale); self.body:ClearAnchors(); self.body:SetAnchor(CENTER,self.bodyViewport,CENTER,0,0)

    local tw=self.top and self.top:GetWidth() or 0
    if tw>0 then
        -- v0.29.25: top navigation always keeps the full group names visible.
        -- Instead of abbreviating CHARACTER / ADVENTURE / FINDERS when the
        -- window narrows, reclaim space from secondary header information and
        -- let the fitted button caption scale down only as much as necessary.
        local compact=rootW<1260
        local startX=compact and 225 or 310
        -- v0.29.13: only reserve space for the close button in the top-right.
        local rightReserve=58
        if self.brand then
            self.brand:SetText(compact and "ESO ADVENTURER" or "ESO ADVENTURER SUITE")
            self.brand:SetDimensions(compact and 195 or 270,28)
        end
        if self.sectionCrumb then self.sectionCrumb:SetHidden(rootW<1180) end
        local gap=compact and 5 or 8
        local available=math.max(420,tw-startX-rightReserve)
        local bw=math.max(80,math.floor((available-gap*(#GROUP_ORDER-1))/#GROUP_ORDER))
        for i,grp in ipairs(GROUP_ORDER) do
            local b=self.groupButtons and self.groupButtons[grp]
            if b then
                b:ClearAnchors(); b:SetAnchor(TOPLEFT,self.top,TOPLEFT,startX+(i-1)*(bw+gap),15); b:SetDimensions(bw,40)
                setButtonText(b,grp)
                if b.caption02895 and b.caption02895.SetMaxLineCount then b.caption02895:SetMaxLineCount(1) end
                fitButtonText(b)
            end
        end
    end
end

function M:RefreshProfile()
    if not self.window then return end
    local oldAlliance = self.allianceId
    local allianceId, allianceName = updateAlliancePalette()
    self.allianceId, self.allianceName = allianceId, allianceName
    local name = clean(safe(GetUnitName, "Adventurer", "player"))
    local class = clean(safe(GetUnitClass, "", "player"))
    local level = tonumber(safe(GetUnitLevel, 0, "player")) or 0
    local cp = tonumber(safe(GetUnitChampionPoints, 0, "player")) or 0
    -- v0.29.13: profile text was removed from the top-right header.
    if self.logoGlow then self.logoGlow:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],0.20) end
    local allianceIcon = allianceSymbolPath(allianceId)
    if self.logoIcon then
        if allianceIcon then self.logoIcon:SetTexture(allianceIcon) end
        self.logoIcon:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
        self.logoIcon:SetHidden(not allianceIcon)
    end
    if self.logoText then
        self.logoText:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
        self.logoText:SetHidden(allianceIcon ~= nil)
    end
    if self.shell then
        self.shell:SetHidden(false)
        setPanelVisual(self.shell, BG, {0,0,0,0})
    end
    if self.glassBackdrop02899 then
        self.glassBackdrop02899:SetHidden(false)
        self.glassBackdrop02899:SetCenterColor(GLASS_BG[1],GLASS_BG[2],GLASS_BG[3],GLASS_BG[4])
    end
    if self.shellAccent and self.shellAccent.SetCenterColor then
        self.shellAccent:SetCenterColor(ACCENT[1],ACCENT[2],ACCENT[3],0.24)
    end
    if self.ambientA then self.ambientA:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],0.055) end
    if self.ambientB then self.ambientB:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],0.030) end
    if oldAlliance ~= allianceId then
        for key,b in pairs(self.groupButtons or {}) do styleButton(b, key == groupForTab(self.activeTab or "INDEX"), false) end
        self:BuildRail()
    end
end

function M:BuildRail()
    if not self.rail then return end
    for _,b in pairs(self.railButtons or {}) do b:SetHidden(true) end
    local tab=self.activeTab or "INDEX"
    local group=groupForTab(tab)
    local tabs=GROUPS[group] or GROUPS.HOME
    for i,key in ipairs(tabs) do
        local b=self.railButtons[key]
        if not b then
            b=wm:CreateControl("EAS_ModernRailBtn02892_"..key,self.rail,CT_BUTTON)
            -- v0.29.28: shift each rail button slightly to the right inside the
            -- rail so the icon stack no longer hugs the left side visually.
            -- Icons stay fixed-size and do not inherit the content-area scale.
            b:SetDimensions(60,50); b:SetMouseEnabled(true)
            local bg=panel("EAS_ModernRailBtnBG02892_"..key,b,0,0,nil,nil,{0.030,0.043,0.060,0.98},20)
            bg:ClearAnchors(); bg:SetAnchorFill(b); bg:SetDrawLevel(0); b.bg=bg

            local selectRail=wm:CreateControl("EAS_ModernRailSelected02892_"..key,b,CT_TEXTURE)
            selectRail:SetAnchor(LEFT,b,LEFT,2,0); selectRail:SetDimensions(3,30)
            selectRail:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds"); selectRail:SetColor(0,0,0,0); selectRail:SetDrawLevel(12)
            b.selectRail02892=selectRail

            local icon=wm:CreateControl("EAS_ModernRailNativeIcon02892_"..key,b,CT_TEXTURE)
            icon:SetAnchor(TOP,b,TOP,0,4); icon:SetDimensions(27,27); icon:SetTexture(NATIVE_RAIL_ICONS[key] or NATIVE_RAIL_ICONS.INDEX)
            icon:SetColor(0.94,0.95,0.98,1); icon:SetDrawLevel(10); b.icon02890=icon

            local railLabel=RAIL_SHORT_LABELS[key] or key
            local short=label("EAS_ModernRailShort02892_"..key,b,railLabel,2,32,56,14,"ZoFontGameSmall",MUTED)
            short:SetHorizontalAlignment(TEXT_ALIGN_CENTER); short:SetVerticalAlignment(TEXT_ALIGN_CENTER); short:SetDrawLevel(14)
            fitRailLabel(short,railLabel,56); b.short02892=short

            b:SetHandler("OnClicked",function()
                self:SetTab(key)
            end)
            b:SetHandler("OnMouseEnter",function(c)
                if c.icon02890 then c.icon02890:SetColor(1,1,1,1) end
                if c.short02892 then c.short02892:SetColor(1,1,1,1) end
                setPanelVisual(c.bg,{ACCENT[1]*0.20,ACCENT[2]*0.20,ACCENT[3]*0.20,0.995},{ACCENT[1],ACCENT[2],ACCENT[3],0.88})
                if self.sectionCrumb then self.sectionCrumb:SetText(string.upper(TAB_LABELS[key] or key)) end
                if self.railTip then self.railTip:SetHidden(true) end
            end)
            b:SetHandler("OnMouseExit",function(c)
                local selected=self.activeTab==key
                if c.icon02890 then c.icon02890:SetColor(selected and ACCENT[1] or 0.94,selected and ACCENT[2] or 0.95,selected and ACCENT[3] or 0.98,1) end
                if c.short02892 then c.short02892:SetColor(selected and 1 or MUTED[1],selected and 1 or MUTED[2],selected and 1 or MUTED[3],1) end
                if c.selectRail02892 then c.selectRail02892:SetColor(0,0,0,0) end
                setPanelVisual(c.bg,selected and {ACCENT[1]*0.30,ACCENT[2]*0.30,ACCENT[3]*0.30,0.995} or {0.030,0.043,0.060,0.98},selected and {ACCENT[1],ACCENT[2],ACCENT[3],1} or {0.22,0.32,0.44,0.58})
                if self.sectionCrumb then self.sectionCrumb:SetText(string.upper(TAB_LABELS[self.activeTab] or self.activeTab or "HOME")) end
            end)
            self.railButtons[key]=b
        end
        b:ClearAnchors(); b:SetAnchor(TOP,self.rail,TOP,8,92+(i-1)*54); b:SetHidden(false)
        if b.short02892 then fitRailLabel(b.short02892,RAIL_SHORT_LABELS[key] or key,56) end
        local selected=self.activeTab==key
        if b.icon02890 then b.icon02890:SetColor(selected and ACCENT[1] or 0.94,selected and ACCENT[2] or 0.95,selected and ACCENT[3] or 0.98,1) end
        if b.short02892 then b.short02892:SetColor(selected and 1 or MUTED[1],selected and 1 or MUTED[2],selected and 1 or MUTED[3],1) end
        if b.selectRail02892 then b.selectRail02892:SetColor(0,0,0,0) end
        setPanelVisual(b.bg,selected and {ACCENT[1]*0.30,ACCENT[2]*0.30,ACCENT[3]*0.30,0.995} or {0.030,0.043,0.060,0.98},selected and {ACCENT[1],ACCENT[2],ACCENT[3],1} or {0.22,0.32,0.44,0.58})
    end
end

-- Native Finder handoff helpers removed in v0.29.35.
-- Every Finder category now remains inside the Suite.

local function EAS_UpdateTopNavigationCore(self)
    local group = groupForTab(self.activeTab or "INDEX")
    for key,b in pairs(self.groupButtons or {}) do
        b._selected = key == group
        styleButton(b, b._selected, false)
    end
    if self.sectionCrumb then self.sectionCrumb:SetText(string.upper(TAB_LABELS[self.activeTab] or self.activeTab or "HOME")) end
    self:BuildRail()
    self:Reflow()
    self:RefreshProfile()
end

function M:PageRoot(tab)
    local p = self.pages[tab]
    if p then return p end
    p = wm:CreateControl("EAS_ModernPage02880_"..tab, self.body, CT_CONTROL)
    p:SetAnchorFill(self.body); p:SetHidden(true); p.tab = tab
    self.pages[tab] = p
    return p
end

local function pageHeader(p, key, titleText, subText)
    if p._headerCreated then
        if p.title then p.title:SetText(titleText or TAB_LABELS[key] or key) end
        if p.sub then p.sub:SetText(subText or "") end
        return
    end
    p._headerCreated = true
    p.title = label("EAS_ModernPageTitle02880_"..key,p,titleText or TAB_LABELS[key] or key,8,2,700,42,"ZoFontWinH1",TEXT)
    p.sub = label("EAS_ModernPageSub02880_"..key,p,subText or "",10,46,930,30,"ZoFontGame",MUTED)
    -- v0.28.95: one section rule only. The previous neutral rule plus accent
    -- rule overlapped and could read as a doubled line.
    p.headerRule = wm:CreateControl("EAS_ModernHeaderRule02895_"..key,p,CT_TEXTURE)
    p.headerRule:SetAnchor(TOPLEFT,p,TOPLEFT,8,78); p.headerRule:SetDimensions(1150,2)
    p.headerRule:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds")
    p.headerRule:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],0.72)
    p.headerAccent = nil
end

local function builtinClassIconForLabel(labelText)
    if type(GetNumClasses) ~= "function" or type(GetClassInfo) ~= "function" then return nil end
    local wanted = lowerKey(labelText)
    local count = tonumber(safe(GetNumClasses, 0)) or 0
    for i=1,count do
        local classId, _, normalIcon, _, _, _, ingameIcon = safe(GetClassInfo, nil, i)
        if classId then
            local className = type(GetClassName) == "function" and clean(safe(GetClassName, "", GENDER_MALE or 1, classId)) or ""
            if lowerKey(className) == wanted then
                return (ingameIcon and ingameIcon ~= "" and ingameIcon) or normalIcon
            end
        end
    end
    return nil
end

local companionNativeArtCache = nil
local function buildCompanionNativeArtCache()
    if companionNativeArtCache then return companionNativeArtCache end
    companionNativeArtCache = {}
    if COLLECTIBLE_CATEGORY_TYPE_COMPANION == nil or type(GetTotalCollectiblesByCategoryType) ~= "function" or type(GetCollectibleIdFromType) ~= "function" then
        return companionNativeArtCache
    end
    local count = tonumber(safe(GetTotalCollectiblesByCategoryType, 0, COLLECTIBLE_CATEGORY_TYPE_COMPANION)) or 0
    for i=1,count do
        local collectibleId = tonumber(safe(GetCollectibleIdFromType, 0, COLLECTIBLE_CATEGORY_TYPE_COMPANION, i)) or 0
        if collectibleId > 0 then
            local name, _, icon = safe(GetCollectibleInfo, "", collectibleId)
            name = clean(name)
            -- v0.29.48: use the companion collectible icon, never the large
            -- collectible background (the latter is the red ? placeholder on
            -- these companion collectibles on some clients).
            local companionIcon = type(GetCollectibleIcon) == "function" and safe(GetCollectibleIcon, "", collectibleId) or ""
            if not companionIcon or companionIcon == "" then companionIcon = icon or "" end
            local key = lowerKey(name)
            if key ~= "" then
                companionNativeArtCache[key] = { path = companionIcon or "", collectibleId = collectibleId, name = name }
            end
        end
    end
    return companionNativeArtCache
end

local function companionNativeArtForLabel(labelText)
    local wanted = lowerKey(labelText)
    if wanted == "" then return nil end
    local cache = buildCompanionNativeArtCache()
    if cache[wanted] then return cache[wanted].path end
    for key, data in pairs(cache) do
        if key:find(wanted,1,true) or wanted:find(key,1,true) then return data.path end
    end
    return nil
end

local function companionNativeArtForEntry(entry)
    if not entry then return nil end

    -- v0.29.28: the collectible icons are technically correct, but at card
    -- size they read as tiny glowing silhouettes and are barely recognizable.
    -- Prefer the Suite's full companion portrait art for the gallery, then
    -- fall back to ESO collectible imagery only if a custom portrait is
    -- missing.
    local customPath = tostring(entry.path or "")
    if customPath ~= "" then return customPath end

    local collectibleId = tonumber(entry.collectibleId) or 0
    local path = ""
    if collectibleId > 0 and type(GetCollectibleIcon) == "function" then
        path = safe(GetCollectibleIcon, "", collectibleId) or ""
    end
    if (not path or path == "") and collectibleId > 0 and type(GetCollectibleInfo) == "function" then
        local _, _, icon = safe(GetCollectibleInfo, "", collectibleId)
        path = icon or ""
    end
    if not path or path == "" then
        path = companionNativeArtForLabel(entry.label) or ""
    end
    return path ~= "" and path or nil
end

local function currentPlayerClassIcon()
    local classId = type(GetUnitClassId)=="function" and safe(GetUnitClassId,nil,"player") or nil
    if classId and type(GetClassIndexById)=="function" and type(GetClassInfo)=="function" then
        local idx=safe(GetClassIndexById,nil,classId)
        if idx then
            local _,_,normalIcon,_,_,_,ingameIcon=safe(GetClassInfo,nil,idx)
            return (ingameIcon and ingameIcon~="" and ingameIcon) or normalIcon
        end
    end
    return builtinClassIconForLabel(clean(safe(GetUnitClass,"","player")))
end

local function currentClassPath()
    local class = lowerKey(safe(GetUnitClass,"","player"))
    for _, entry in ipairs(CLASS_CARDS) do if class:find(entry.key,1,true) then return entry.path, entry.label end end
    return suiteAsset02926("Art/eas_class_sorcerer.dds"), clean(safe(GetUnitClass,"Character","player"))
end

function M:CreateHome()
    local p=self:PageRoot("INDEX")
    -- Home uses the same ESO framed language as every other page, with a
    -- stronger adventure card so the character/quest information never melts
    -- into the world scene behind the addon.
    local hero=panel("EAS_ModernHomeHero02894",p,8,4,782,356,{0.018,0.032,0.048,0.998},24); p.hero=hero
    setPanelVisual(hero,{0.018,0.032,0.048,0.998},{0.30,0.46,0.64,0.84})

    local art=wm:CreateControl("EAS_ModernHomeHeroArt02894",hero,CT_TEXTURE)
    art:SetAnchor(TOPRIGHT,hero,TOPRIGHT,0,0); art:SetAnchor(BOTTOMRIGHT,hero,BOTTOMRIGHT,0,0); art:SetWidth(330); art:SetTextureCoords(0,1,0,1); art:SetAlpha(0.18); art:SetDrawLevel(8); keepTextureResident029116(art); p.heroArt=art
    local artShade=wm:CreateControl("EAS_ModernHomeHeroShade02894",hero,CT_TEXTURE)
    artShade:SetAnchor(TOPLEFT,hero,TOPLEFT,420,0); artShade:SetAnchor(BOTTOMRIGHT,hero,BOTTOMRIGHT,0,0); artShade:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds"); artShade:SetColor(0.004,0.008,0.014,0.62); artShade:SetDrawLevel(12)
    local artDivider=wm:CreateControl("EAS_ModernHomeHeroArtDivider02894",hero,CT_TEXTURE)
    artDivider:SetAnchor(TOPLEFT,hero,TOPLEFT,446,22); artDivider:SetAnchor(BOTTOMLEFT,hero,BOTTOMLEFT,446,-22); artDivider:SetWidth(1); artDivider:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds"); artDivider:SetColor(EDGE[1],EDGE[2],EDGE[3],0.42); artDivider:SetDrawLevel(14)
    local glow=wm:CreateControl("EAS_ModernHomeHeroIconGlow02894",hero,CT_TEXTURE)
    glow:SetAnchor(RIGHT,hero,RIGHT,-92,-3); glow:SetDimensions(190,190); glow:SetTexture("EsoUI/Art/Champion/champion_point_glow.dds"); glow:SetColor(ESO_GOLD[1],ESO_GOLD[2],ESO_GOLD[3],0.24); glow:SetDrawLevel(15); p.heroIconGlow=glow
    local fallback=wm:CreateControl("EAS_ModernHomeHeroFallback02894",hero,CT_TEXTURE)
    fallback:SetAnchor(RIGHT,hero,RIGHT,-92,-3); fallback:SetDimensions(142,142); fallback:SetAlpha(0.98); fallback:SetColor(unpack(ESO_GOLD)); fallback:SetDrawLevel(18); p.heroFallback=fallback

    p.heroEyebrow=label("EAS_ModernHomeEyebrow02894",hero,"CURRENT ADVENTURE",28,24,360,24,"ZoFontGameBold",ACCENT)
    p.heroName=label("EAS_ModernHomeName02894",hero,"Adventurer",28,54,398,48,"ZoFontWinH1",TEXT)
    p.heroMetaHead=label("EAS_ModernHomeMetaHead02896",hero,"CHARACTER",30,108,390,20,"ZoFontGameBold",ACCENT)
    p.heroMeta=label("EAS_ModernHomeMeta02894",hero,"",30,132,394,62,"ZoFontGame",TEXT); constrainLabel(p.heroMeta,3,false)
    p.heroQuestHead=label("EAS_ModernHomeQuestHead02894",hero,"ACTIVE QUEST",30,204,390,20,"ZoFontGameBold",ACCENT)
    p.heroQuest=label("EAS_ModernHomeQuest02894",hero,"• No assisted quest selected",30,228,390,46,"ZoFontGame",TEXT); constrainLabel(p.heroQuest,2,false)
    p.continueButton=button("EAS_ModernContinueQuest02894",hero,"CONTINUE QUEST",30,292,176,46,function() self:SetTab("QUESTS") end,true)
    p.findButton=button("EAS_ModernFindActivity02894",hero,"FIND ACTIVITY",220,292,164,46,function() self:SetTab("DUNGEONS") end)

    local profile=panel("EAS_ModernHomeProfile02894",p,808,4,350,356,{0.022,0.036,0.052,0.998},24); p.profile=profile
    setPanelVisual(profile,{0.022,0.036,0.052,0.998},{0.28,0.42,0.58,0.78})
    label("EAS_ModernHomeProfileHead02894",profile,"CURRENT SESSION",24,24,250,22,"ZoFontGameBold",ACCENT)
    p.sessionDetails=label("EAS_ModernHomeSessionDetails02896",profile,"",24,58,300,264,"ZoFontGame",MUTED); constrainLabel(p.sessionDetails,0,false)

    p.quickCards={}
    local cards={{"QUEST FINDER","QUESTS"},{"GOLDEN PURSUITS","PURSUITS"},{"DUNGEONS","DUNGEONS"},{"BATTLEGROUNDS","BATTLEGROUNDS"},{"GEAR & SETS","GEAR"},{"MAP / TRAVEL","TRAVEL"}}
    -- v0.29.00: the six Home dashboard cards use a darker local glass layer than
    -- the shared shell. This preserves the transparent Suite aesthetic while
    -- preventing the live game scene from competing with compact card text.
    local QUICK_BG={0.008,0.014,0.024,0.999}
    local QUICK_BG_HOVER={0.018,0.032,0.050,0.999}
    local QUICK_EDGE={0.24,0.42,0.60,0.86}
    local QUICK_VALUE={0.97,0.98,1.00,1}
    for i,entry in ipairs(cards) do
        local col=(i-1)%3; local row=math.floor((i-1)/3)
        local c=panel("EAS_ModernHomeQuick02894_"..i,p,8+col*386,382+row*128,366,114,QUICK_BG,20)
        setPanelVisual(c,QUICK_BG,QUICK_EDGE)
        -- Strengthen the local center fill without changing the global glass
        -- opacity. The single rounded frame remains the only visible edge.
        if c.SetCenterColor then c:SetCenterColor(0.004,0.008,0.014,0.965) end
        c:SetMouseEnabled(true); c:SetHandler("OnMouseDown",function() self:SetTab(entry[2]) end)
        c:SetHandler("OnMouseEnter",function(card)
            setPanelVisual(card,QUICK_BG_HOVER,{ACCENT[1],ACCENT[2],ACCENT[3],0.96})
            if card.SetCenterColor then card:SetCenterColor(0.006,0.012,0.022,0.975) end
        end)
        c:SetHandler("OnMouseExit",function(card)
            setPanelVisual(card,QUICK_BG,QUICK_EDGE)
            if card.SetCenterColor then card:SetCenterColor(0.004,0.008,0.014,0.965) end
        end)
        local ico=wm:CreateControl("EAS_ModernHomeQuickIcon02894_"..i,c,CT_TEXTURE)
        ico:SetAnchor(TOPLEFT,c,TOPLEFT,18,18); ico:SetDimensions(32,32)
        ico:SetTexture(NATIVE_RAIL_ICONS[entry[2]] or appIconPath(entry[2])); ico:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
        local qt=label("EAS_ModernHomeQuickTitle02894_"..i,c,entry[1],62,14,286,30,"ZoFontWinH4",TEXT)
        constrainLabel(qt,1,true)
        local v=label("EAS_ModernHomeQuickValue02894_"..i,c,"• Open",62,52,286,50,"ZoFontGameBold",QUICK_VALUE)
        constrainLabel(v,2,false)
        p.quickCards[i]={control=c,value=v,key=entry[2]}
    end
    return p
end

function M:RefreshHome(p)
    local name=clean(safe(GetUnitName,"Adventurer","player")); local class=clean(safe(GetUnitClass,"Character","player"))
    local level=tonumber(safe(GetUnitLevel,0,"player")) or 0; local cp=tonumber(safe(GetUnitChampionPoints,0,"player")) or 0
    local zone=clean(safe(GetUnitZone,"Unknown zone","player")); local path=currentClassPath(); p.heroArt:SetTexture(path); p.heroArt:SetAlpha(0.18); p.heroArt:SetDrawLevel(10)
    if p.heroFallback then local fallbackPath=currentPlayerClassIcon(); if fallbackPath and fallbackPath~="" then p.heroFallback:SetTexture(fallbackPath); p.heroFallback:SetColor(unpack(ESO_GOLD)); p.heroFallback:SetAlpha(0.98); p.heroFallback:SetHidden(false) else p.heroFallback:SetHidden(true) end end
    p.heroName:SetText(name ~= "" and name or "Adventurer")
    p.heroMeta:SetText(table.concat({
        "• "..(class ~= "" and class or "Character"),
        "• "..(cp>0 and ("Champion "..cp) or ("Level "..level))
    },"\n"))
    local quest="No assisted quest selected"
    if EPC.ActiveQuest and EPC.ActiveQuest.GetActiveQuestIndex then
        local ok,idx=pcall(EPC.ActiveQuest.GetActiveQuestIndex,EPC.ActiveQuest); if ok and tonumber(idx) and tonumber(idx)>0 then
            local q=safe(GetJournalQuestName,"",tonumber(idx)); if q and q~="" then quest=clean(q) end
        end
    end
    p.heroQuest:SetText("• "..quest)
    local hp,maxhp=safe(GetUnitPower,0,"player",POWERTYPE_HEALTH); local mp,maxmp=safe(GetUnitPower,0,"player",POWERTYPE_MAGICKA); local sp,maxsp=safe(GetUnitPower,0,"player",POWERTYPE_STAMINA)
    local companion="No active companion"; if safe(DoesUnitExist,false,"companion") then companion=clean(safe(GetUnitName,"Companion","companion")) end
    p.sessionDetails:SetText(infoSections({
        {"LOCATION",{zone}},
        {"RESOURCES",{
            "Health: "..tostring(maxhp or hp or "--"),
            "Magicka: "..tostring(maxmp or mp or "--"),
            "Stamina: "..tostring(maxsp or sp or "--")
        }},
        {"COMPANION",{companion}}
    }))
    local pursuit="No active campaign"; if J.BuildGoldenPursuitsView2494 then local ok,v=pcall(J.BuildGoldenPursuitsView2494,J); if ok and v and v.rows and v.rows[1] then local r=v.rows[1]; pursuit=tostring(r.name or "Golden Pursuit") end end
    local queue="Not queued"; if EPC.BattlegroundFinder and EPC.BattlegroundFinder:IsQueued() then queue="Battleground queue active" elseif EPC.DungeonFinder and EPC.DungeonFinder:IsQueued() then queue="Dungeon queue active" end
    local values={quest,pursuit,queue,queue,"Build tools ready",zone}
    for i,v in ipairs(values) do if p.quickCards[i] then p.quickCards[i].value:SetText("• "..clean(v)) end end
end

local function EAS_CreateCardGalleryCore(self,tab,cards,titleText,subText)
    local p=self:PageRoot(tab); pageHeader(p,tab,titleText,subText); p.cardEntries={}
    local cardW,cardH,gapX,gapY=174,236,14,16
    for i,entry in ipairs(cards) do
        local col=(i-1)%4; local row=math.floor((i-1)/4); local x=8+col*(cardW+gapX); local y=94+row*(cardH+gapY)
        local c=panel("EAS_ModernGallery02890_"..tab.."_"..i,p,x,y,cardW,cardH,{0.036,0.052,0.073,0.995},22)
        local fallback=nil
        if tab=="CHARACTER" then
            local fallbackPath=builtinClassIconForLabel(entry.label)
            if fallbackPath and fallbackPath~="" then
                fallback=wm:CreateControl("EAS_ModernGalleryFallback02890_"..tab.."_"..i,c,CT_TEXTURE); fallback:SetAnchor(TOPLEFT,c,TOPLEFT,10,10); fallback:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-10,-50); fallback:SetTexture(fallbackPath); fallback:SetTextureCoords(0,1,0,1); fallback:SetAlpha(0.92); fallback:SetColor(1,1,1,1); fallback:SetDrawLevel(5)
            end
        end
        local companionFallback=nil
        if tab=="COMPANIONS" then
            local nativeFallback = companionNativeArtForLabel(entry.label) or NATIVE_RAIL_ICONS.COMPANIONS
            if nativeFallback and nativeFallback ~= "" then
                companionFallback=wm:CreateControl("EAS_ModernGalleryFallback028113_"..tab.."_"..i,c,CT_TEXTURE)
                companionFallback:SetAnchor(TOPLEFT,c,TOPLEFT,10,10)
                companionFallback:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-10,-50)
                companionFallback:SetTexture(nativeFallback)
                companionFallback:SetTextureCoords(0,1,0,1)
                companionFallback:SetAlpha(0.90)
                companionFallback:SetDrawLevel(5)
            end
        end
        local tex=wm:CreateControl("EAS_ModernGalleryArt02890_"..tab.."_"..i,c,CT_TEXTURE)
        tex:SetAnchor(TOPLEFT,c,TOPLEFT,4,4); tex:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-4,-44)
        if tab=="COMPANIONS" then
            -- v0.29.28: use the Suite's portrait-style companion artwork so
            -- each card is recognizable at a glance, while still filling the
            -- full card art area.
            tex:ClearAnchors()
            tex:SetAnchor(TOPLEFT,c,TOPLEFT,4,4)
            tex:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-4,-44)
            local nativePath=companionNativeArtForEntry(entry)
            if nativePath and nativePath~="" then
                tex:SetTexture(nativePath)
            else
                tex:SetTexture(NATIVE_RAIL_ICONS.COMPANIONS or "EsoUI/Art/MainMenu/menubar_social_up.dds")
            end
            tex:SetAlpha(1)
            if tex.SetPixelRoundingEnabled then tex:SetPixelRoundingEnabled(true) end
        elseif tab=="CHARACTER" then
            -- v0.29.11: allow the class art to cover the card area instead of
            -- rendering as a small centered square.
            tex:ClearAnchors()
            tex:SetAnchor(TOPLEFT,c,TOPLEFT,4,4)
            tex:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-4,-44)
            tex:SetTexture(entry.path)
            tex:SetAlpha(1)
            if tex.SetPixelRoundingEnabled then tex:SetPixelRoundingEnabled(true) end
        else
            tex:SetTexture(entry.path)
            tex:SetAlpha(1)
        end
        tex:SetTextureCoords(0,1,0,1); tex:SetColor(1,1,1,1); keepTextureResident029116(tex); tex:SetDrawLevel(10)
        if tex.SetPixelRoundingEnabled then tex:SetPixelRoundingEnabled(tab=="COMPANIONS" or tab=="CHARACTER") end
        if tab=="CHARACTER" and fallback then
            fallback:SetAlpha(0.92); fallback:SetColor(1,1,1,1); fallback:SetDrawLevel(6)
        end
        local shade=wm:CreateControl("EAS_ModernGalleryShade02890_"..tab.."_"..i,c,CT_TEXTURE); shade:SetAnchor(BOTTOMLEFT,c,BOTTOMLEFT,4,-4); shade:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-4,-4); shade:SetHeight(42); shade:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds"); shade:SetColor(0.01,0.01,0.015,0.94); shade:SetDrawLevel(12)
        local n=label("EAS_ModernGalleryName02890_"..tab.."_"..i,c,entry.label,8,198,158,28,"ZoFontGameBold"); constrainLabel(n,1,true); n:SetHorizontalAlignment(TEXT_ALIGN_CENTER); n:SetDrawLevel(20)
        local selectedBar=wm:CreateControl("EAS_ModernGallerySelected02890_"..tab.."_"..i,c,CT_TEXTURE); selectedBar:SetAnchor(TOPLEFT,c,TOPLEFT,14,2); selectedBar:SetAnchor(TOPRIGHT,c,TOPRIGHT,-14,2); selectedBar:SetHeight(3); selectedBar:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds"); selectedBar:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],0); selectedBar:SetDrawLevel(30)
        local selectedRail=wm:CreateControl("EAS_ModernGallerySelectedRail02893_"..tab.."_"..i,c,CT_TEXTURE); selectedRail:SetAnchor(LEFT,c,LEFT,4,0); selectedRail:SetDimensions(5,178); selectedRail:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds"); selectedRail:SetColor(ACCENT[1],ACCENT[2],ACCENT[3],0); selectedRail:SetDrawLevel(30)
        c:SetMouseEnabled(true); c:SetHandler("OnMouseDown",function() if tab=="CHARACTER" then self:SetTab("BUILD") end end)
        c:SetHandler("OnMouseEnter",function(card) if not card._selected02893 then setPanelVisual(card,{ACCENT[1]*0.16,ACCENT[2]*0.16,ACCENT[3]*0.16,0.998},{ACCENT[1],ACCENT[2],ACCENT[3],0.90}) end end)
        c:SetHandler("OnMouseExit",function() self:RefreshGallery(tab,p) end)
        p.cardEntries[i]={control=c,key=entry.key,label=entry.label,art=tex,fallback=fallback,path=entry.path,selectedBar=selectedBar,selectedRail=selectedRail}
    end
    local side=panel("EAS_ModernGallerySide02890_"..tab,p,770,94,388,488,{0.024,0.038,0.055,0.998},22)
    p.sideTitle=label("EAS_ModernGallerySideTitle02904_"..tab,side,tab=="CHARACTER" and "CURRENT CLASS" or "CURRENT COMPANION",24,24,340,22,"ZoFontGameBold",ACCENT)
    p.sideValue=label("EAS_ModernGallerySideValue02904_"..tab,side,"",24,54,340,42,"ZoFontWinH2")

    -- v0.29.04: split the old paragraph-style side summary into fixed sections.
    -- This keeps every item on its own readable line and prevents long tool prose
    -- from wrapping into a dense block on narrower UI scales.
    p.sideSection1Title=label("EAS_ModernGallerySideSection1Title02904_"..tab,side,"",24,112,340,22,"ZoFontGameBold",ACCENT)
    p.sideSection1Body=label("EAS_ModernGallerySideSection1Body02904_"..tab,side,"",24,138,340,28,"ZoFontGame",TEXT)
    p.sideSection2Title=label("EAS_ModernGallerySideSection2Title02904_"..tab,side,"",24,178,340,22,"ZoFontGameBold",ACCENT)
    p.sideSection2Body=label("EAS_ModernGallerySideSection2Body02904_"..tab,side,"",24,204,340,128,"ZoFontGame",TEXT)
    p.sideSection3Title=label("EAS_ModernGallerySideSection3Title02904_"..tab,side,"",24,342,340,22,"ZoFontGameBold",ACCENT)
    p.sideSection3Body=label("EAS_ModernGallerySideSection3Body02904_"..tab,side,"",24,368,340,34,"ZoFontGame",TEXT)

    p.sideButton=nil
    if tab=="CHARACTER" then
        p.sideButton=button("EAS_ModernGallerySideButton02904_"..tab,side,"OPEN BUILD TOOLS",24,414,340,46,function() self:SetTab("GEAR") end,true)
    end
    return p
end

local function EAS_RefreshGalleryCore(self,tab,p)
    local current = tab=="CHARACTER" and clean(safe(GetUnitClass,"Unknown class","player")) or (safe(DoesUnitExist,false,"companion") and clean(safe(GetUnitName,"Companion","companion")) or "No active companion")
    local key=lowerKey(current)
    for _,entry in ipairs(p.cardEntries or {}) do
        local selected=key:find(entry.key,1,true)~=nil
        entry.control._selected02893=selected
        setPanelVisual(entry.control, selected and {ACCENT[1]*0.32,ACCENT[2]*0.32,ACCENT[3]*0.32,0.998} or {0.036,0.052,0.073,0.995}, selected and {ACCENT[1],ACCENT[2],ACCENT[3],1} or {0.27,0.38,0.51,0.72})
        if entry.selectedBar then entry.selectedBar:SetColor(0,0,0,0) end
        if entry.selectedRail then entry.selectedRail:SetColor(0,0,0,0) end
        if entry.fallback and tab=="CHARACTER" then
            entry.fallback:SetAlpha(selected and 1 or 0.92)
            entry.fallback:SetColor(selected and 1 or 0.92, selected and 1 or 0.90, selected and 1 or 0.82, 1)
        end
    end
    p.sideValue:SetText(current)
    if tab=="CHARACTER" then
        local cp=tonumber(safe(GetUnitChampionPoints,0,"player")) or 0; local lvl=tonumber(safe(GetUnitLevel,0,"player")) or 0
        p.sideSection1Title:SetText("PROGRESSION")
        p.sideSection1Body:SetText("• "..(cp>0 and ("Champion "..cp) or ("Level "..lvl)))
        p.sideSection2Title:SetText("AVAILABLE TOOLS")
        p.sideSection2Body:SetText(table.concat({
            "• Build",
            "• Gear & Sets",
            "• Skills & Champion Points",
            "• Combat",
            "• Character Stats"
        },"\n"))
        p.sideSection3Title:SetText("DISPLAY")
        p.sideSection3Body:SetText("• Active class uses alliance color")
    else
        local level=tonumber(safe(GetUnitLevel,0,"companion")) or 0
        p.sideSection1Title:SetText("LEVEL")
        p.sideSection1Body:SetText("• "..tostring(level))
        p.sideSection2Title:SetText("AVAILABLE TOOLS")
        p.sideSection2Body:SetText(table.concat({
            "• Companion Optimization",
            "• Active companion details"
        },"\n"))
        p.sideSection3Title:SetText("DISPLAY")
        p.sideSection3Body:SetText("• Active companion card is highlighted")
    end
end

local INTERACTIVE = {GEAR=true,QUESTS=true,TRAVEL=true,ACTIVITY=true,DUNGEONS=true,BATTLEGROUNDS=true,GROUPFINDER=true,ZONEGUIDE=true,TRIBUTE=true,HOMETOURS=true}

function M:CreateInteractive(tab)
    local p=self:PageRoot(tab)
    pageHeader(p,tab,TAB_LABELS[tab],"Browse live ESO data, inspect details, and launch available actions.")

    -- A single soft command shelf replaces the row of tiny floating rectangles.
    p.commandShelf=flatPanel("EAS_ModernCommandShelf02884_"..tab,p,8,88,1150,52,{0.030,0.045,0.064,0.995},{0.27,0.39,0.53,0.72})
    p.filterButtons={}; p.secondaryButtons={}
    for i=1,4 do
        p.filterButtons[i]=button("EAS_ModernFilter02884_"..tab.."_"..i,p.commandShelf,"",10+(i-1)*132,7,124,38,function() self:RunInteractiveFilter(tab,i) end)
    end
    for i=1,4 do
        p.secondaryButtons[i]=button("EAS_ModernSecondary02884_"..tab.."_"..i,p.commandShelf,"",612+(i-1)*132,7,124,38,function() self:RunInteractiveSecondary(tab,i) end)
    end

    p.listPanel=flatPanel("EAS_ModernListPanel02884_"..tab,p,8,154,680,490,{0.020,0.034,0.049,0.998},{0.28,0.41,0.56,0.70})
    p.detailPanel=flatPanel("EAS_ModernDetailPanel02884_"..tab,p,704,154,454,490,{0.024,0.038,0.055,0.998},{0.28,0.41,0.56,0.74})

    p.rows={}
    for i=1,10 do
        local row=wm:CreateControl("EAS_ModernRow02884_"..tab.."_"..i,p.listPanel,CT_BUTTON)
        row:SetAnchor(TOPLEFT,p.listPanel,TOPLEFT,14,8+(i-1)*44)
        row:SetDimensions(652,41); row:SetMouseEnabled(true)
        local bg=flatPanel("EAS_ModernRowBG02884_"..tab.."_"..i,row,0,0,nil,nil,SURFACE_2,{0.25,0.36,0.49,0.68})
        bg:ClearAnchors(); bg:SetAnchorFill(row); bg:SetDrawLevel(0)
        setPanelVisual(bg,{0.043,0.059,0.081,0.995},{0.25,0.36,0.49,0.68})
        local rail=wm:CreateControl("EAS_ModernRowRail02884_"..tab.."_"..i,row,CT_TEXTURE)
        rail:SetAnchor(LEFT,row,LEFT,5,0); rail:SetDimensions(5,27); rail:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_floating_center.dds"); rail:SetColor(0,0,0,0); rail:SetDrawLevel(5)
        local t=label("EAS_ModernRowTitle02895_"..tab.."_"..i,row,"",16,3,620,19,"ZoFontGameBold"); constrainLabel(t,1,false)
        local d=label("EAS_ModernRowDetail02895_"..tab.."_"..i,row,"",16,22,620,16,"ZoFontGameSmall",MUTED); constrainLabel(d,1,false)
        row.bg,row.title,row.detail,row.accentRail=bg,t,d,rail
        row:SetHandler("OnClicked",function() self:SelectInteractiveRow(tab,i) end)
        row:SetHandler("OnMouseEnter",function(c)
            if c.bg then setPanelVisual(c.bg,{ACCENT[1]*0.18,ACCENT[2]*0.18,ACCENT[3]*0.18,0.98},{ACCENT[1],ACCENT[2],ACCENT[3],0.90}) end
        end)
        row:SetHandler("OnMouseExit",function(c)
            -- Hover changes only the row background. Do not touch label colors
            -- here: the extra SetColor calls were unnecessary and could spam
            -- LabelControlSetColorLua while rapidly crossing NOT STARTED rows.
            if c.bg and c._easBaseCenter029122 and c._easBaseEdge029122 then
                setPanelVisual(c.bg,c._easBaseCenter029122,c._easBaseEdge029122)
            end
        end)
        p.rows[i]=row
    end
    p.pageLabel=label("EAS_ModernPageLabel02895_"..tab,p.listPanel,"",14,454,652,22,"ZoFontGameSmall",MUTED); p.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local questDetail=(tab=="QUESTS")
    local gearDetail=(tab=="GEAR")
    local zoneDetail=(tab=="ZONEGUIDE")
    local finderCardDetail=(tab=="TRIBUTE" or tab=="HOMETOURS")
    -- v0.29.37: Tribute and Home Tours used the compact generic detail layout,
    -- which packed status/requirements onto a few lines and left PAGE 1/1
    -- sitting directly on top of the action area. Give these finder cards a
    -- proper reading region with the same deliberate spacing used elsewhere.
    local detailBodyHeight=questDetail and 242 or (zoneDetail and 224 or (finderCardDetail and 178 or (gearDetail and 120 or 106)))
    local detailNavY=questDetail and 326 or (zoneDetail and 316 or (finderCardDetail and 270 or (gearDetail and 204 or 190)))
    local actionHeadY=questDetail and 366 or (zoneDetail and 352 or (finderCardDetail and 372 or (gearDetail and 238 or 226)))
    local actionStartY=questDetail and 396 or (zoneDetail and 382 or (finderCardDetail and 400 or (gearDetail and 266 or 254)))
    -- v0.29.67: Group Finder has longer action captions such as
    -- HOST CURRENT DUNGEON. Give those buttons enough height for the fitted
    -- two-line caption instead of clipping the final word.
    local actionHeight=questDetail and 38 or (zoneDetail and 32 or (gearDetail and 28 or (tab=="GROUPFINDER" and 42 or 32)))
    local actionStep=questDetail and 43 or (zoneDetail and 36 or (gearDetail and 30 or (tab=="GROUPFINDER" and 47 or 37)))
    p.detailTitle=label("EAS_ModernDetailTitle02895_"..tab,p.detailPanel,"Select an entry",24,22,406,48,"ZoFontWinH2"); constrainLabel(p.detailTitle,2,false)
    p.detailBody=label("EAS_ModernDetailBody02895_"..tab,p.detailPanel,"",24,78,406,detailBodyHeight,"ZoFontGame",(questDetail or gearDetail or finderCardDetail) and TEXT or MUTED); constrainLabel(p.detailBody,0,false)
    if (questDetail or gearDetail or finderCardDetail) and p.detailBody.SetLineSpacing then p.detailBody:SetLineSpacing(finderCardDetail and 3 or 2) end

    -- v0.29.39: Tribute and Home Tours use true multi-line section labels.
    -- Do not apply ESO's TRUNCATE/ELLIPSIS wrap modes here: those modes clip
    -- long requirement text instead of letting the manual line breaks render.
    p.finderDetailSections=nil
    if finderCardDetail then
        p.finderDetailSections={}
        local sectionY={78,130,182,234}
        local bodyHeights={30,30,30,112}
        for i=1,4 do
            local head=label("EAS_ModernFinderDetailHead02939_"..tab.."_"..i,p.detailPanel,"",24,sectionY[i],406,18,"ZoFontGameBold",ACCENT)
            local body=label("EAS_ModernFinderDetailBody02939_"..tab.."_"..i,p.detailPanel,"",24,sectionY[i]+20,406,bodyHeights[i],"ZoFontGame",TEXT)
            constrainLabel(body,0,false)
            -- Leave the wrap mode at ESO's normal multi-line behavior.
            -- TEXT_WRAP_MODE_TRUNCATE/ELLIPSIS clips the requirement field.
            if body.SetMaxLineCount then body:SetMaxLineCount(0) end
            if body.SetLineSpacing then body:SetLineSpacing(2) end
            head:SetHidden(true); body:SetHidden(true)
            p.finderDetailSections[i]={head=head,body=body}
        end
    end
    p.detailPage=1
    p.detailPrev=button("EAS_ModernDetailPrev02895_"..tab,p.detailPanel,"< PREV",24,detailNavY,86,28,function() p.detailPage=math.max(1,(tonumber(p.detailPage) or 1)-1); self:RefreshInteractive(tab,p) end)
    p.detailPageLabel=label("EAS_ModernDetailPage02895_"..tab,p.detailPanel,"PAGE 1 / 1",116,detailNavY+6,222,18,"ZoFontGameSmall",MUTED); p.detailPageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    p.detailNext=button("EAS_ModernDetailNext02895_"..tab,p.detailPanel,"NEXT >",344,detailNavY,86,28,function() p.detailPage=(tonumber(p.detailPage) or 1)+1; self:RefreshInteractive(tab,p) end)
    p.actionHead=label("EAS_ModernActionHead02895_"..tab,p.detailPanel,"AVAILABLE ACTIONS",24,actionHeadY,406,22,"ZoFontGameBold",ACCENT)
    p.actionButtons={}
    for i=1,14 do
        local col=(i-1)%2; local r=math.floor((i-1)/2)
        local b=button("EAS_ModernAction02895_"..tab.."_"..i,p.detailPanel,"",24+col*203,actionStartY+r*actionStep,193,actionHeight,function() self:RunAction(tab,i) end,i==1)
        b:SetHidden(true); p.actionButtons[i]=b
    end
    return p
end

function M:GetInteractiveView(tab)
    if tab=="GEAR" and EPC.SetJournal then return EPC.SetJournal:BuildView() end
    if tab=="QUESTS" and EPC.QuestFinder then return EPC.QuestFinder:BuildView() end
    if tab=="TRAVEL" and EPC.Travel then return EPC.Travel:BuildView(EPC.lastSnapshot or {}, EPC.Travel.BOOK_PAGE_SIZE or 10) end
    if tab=="ACTIVITY" and EPC.Activities then return EPC.Activities:BuildView(EPC.lastSnapshot or {}) end
    if tab=="DUNGEONS" and EPC.DungeonFinder then EPC.DungeonFinder:SetViewMode("DUNGEONS"); return EPC.DungeonFinder:BuildView() end
    if tab=="BATTLEGROUNDS" and EPC.BattlegroundFinder then return EPC.BattlegroundFinder:BuildView(false) end
    if tab=="GROUPFINDER" and EPC.DungeonFinder then EPC.DungeonFinder:SetViewMode("LIVE"); return EPC.DungeonFinder:BuildLiveView() end
    if EPC.FinderSuite and EPC.FinderSuite.Handles and EPC.FinderSuite:Handles(tab) then return EPC.FinderSuite:BuildView(tab) end
    return {rows={}}
end

local function rowTitleDetail(tab,row)
    if not row then return "","" end
    if tab=="GROUPFINDER" then return tostring(row.title or row.owner or "Listing"), tostring(row.roles or row.description or "") end
    local title=tostring(row.name or row.displayText or row.title or row.label or "Entry")
    local detail=tostring(row.detail or row.detailText or row.zone or row.zoneName or row.sourceText or row.status or row.kindText or "")
    if tab=="GEAR" and row.unlocked then detail=string.format("%d/%d  •  %s",tonumber(row.unlocked) or 0,tonumber(row.total) or 0,tostring(row.sourceText or "")) end
    if tab=="QUESTS" then detail=tostring(row.zone or "")..((row.status or row.type) and ("  •  "..tostring(row.status or row.type)) or "") end
    if tab=="BATTLEGROUNDS" then detail=tostring(row.detail or "") end
    return clean(title), clean(detail)
end

local function selectedMatches(tab,view,row)
    if not view or not row then return false end
    if tab=="DUNGEONS" and EPC.DungeonFinder and EPC.DungeonFinder.IsEntrySelected then return EPC.DungeonFinder:IsEntrySelected(row) end
    local s=view.selected; if not s then return false end
    if tab=="GEAR" then return s.setId and row.setId and s.setId==row.setId end
    if tab=="QUESTS" then return s.key and row.key and s.key==row.key end
    if tab=="TRAVEL" or tab=="ACTIVITY" then return s.key and row.key and s.key==row.key end
    if tab=="BATTLEGROUNDS" then return s.id and row.id and s.id==row.id end
    if tab=="GROUPFINDER" then return s==row.data or (row.data and s==row.data) end
    if (tab=="ZONEGUIDE" or tab=="TRIBUTE" or tab=="HOMETOURS") then return s.key and row.key and s.key==row.key end
    return s==row
end

function M:FilterLabels(tab,view)
    if tab=="GEAR" then return {"ALL","OVERLAND","DUNGEON","TRIAL"},{"SEARCH","CLEAR","< PREV","NEXT >"} end
    if tab=="QUESTS" then return {"NOT STARTED","ACTIVE","MAIN QUEST","CADWELL"},{"SEARCH","< PREV","NEXT >","REFRESH"} end
    if tab=="TRAVEL" then return {"SHRINES","FRIENDS","GUILD","GROUP"},{"< PREV","NEXT >","REFRESH",""} end
    if tab=="ACTIVITY" then return {"BALANCED","XP","GOLD",""},{"REFRESH","","",""} end
    if tab=="DUNGEONS" then return {"NORMAL","VETERAN","ROLE: "..tostring(view.role or "DPS"),"REFRESH"},{"< PREV","NEXT >","AUTO: "..((view.autoAccept==true) and "ON" or "OFF"),"ROLES: "..((view.enforceRoles==true) and "ON" or "OFF")} end
    if tab=="BATTLEGROUNDS" then return {"AVAILABLE","ALL","REFRESH",""},{"< PREV","NEXT >","",""} end
    if tab=="GROUPFINDER" then return {tostring(view.categoryName or "CATEGORY"),"ALL","NORMAL","VETERAN"},{"","","CHANGE DIFFICULTY","CHANGE FINDER STYLE"} end
    if tab=="ZONEGUIDE" then return {"CURRENT","< ZONE","ZONE >","REFRESH"},{"< PREV","NEXT >","",""} end
    if tab=="TRIBUTE" then return {"ALL","CASUAL","COMPETITIVE","REFRESH"},{"< PREV","NEXT >","",""} end
    if tab=="HOMETOURS" then return {"PUBLIC","OWNED","ALL HOMES","REFRESH"},{"< PREV","NEXT >","",""} end
    return {"","","",""},{"","","",""}
end

local function interactiveStateSelected(tab, view, secondary, index)
    view = view or {}
    if not secondary then
        if tab=="GEAR" then local vals={"ALL","OVERLAND","DUNGEON","TRIAL"}; return tostring(view.filter or "ALL")==vals[index] end
        if tab=="QUESTS" then local vals={"NOT_STARTED","ACTIVE","MAIN_QUEST","CADWELL"}; return tostring(view.filter or "NOT_STARTED")==vals[index] end
        if tab=="TRAVEL" then local vals={"SHRINES","FRIENDS","GUILD","GROUP"}; return tostring(view.mode or "SHRINES")==vals[index] end
        if tab=="ACTIVITY" then local vals={"BALANCED","XP","GOLD"}; return index<=3 and tostring(view.goal or "BALANCED")==vals[index] end
        if tab=="DUNGEONS" then return (index==1 and view.difficulty=="NORMAL") or (index==2 and view.difficulty=="VETERAN") or index==3 end
        if tab=="BATTLEGROUNDS" then return (index==1 and view.showLocked~=true) or (index==2 and view.showLocked==true) end
        if tab=="GROUPFINDER" then
            local diff=tostring(view.difficulty or "ALL")
            return index==1 or (index==2 and diff=="ALL") or (index==3 and diff=="NORMAL") or (index==4 and diff=="VETERAN")
        end
        if tab=="ZONEGUIDE" then return index==1 and view.isCurrentZone==true end
        if tab=="TRIBUTE" then local f=tostring(view.filter or "ALL"); return (index==1 and f=="ALL") or (index==2 and f=="CASUAL") or (index==3 and f=="COMPETITIVE") end
        if tab=="HOMETOURS" then local f=tostring(view.filter or "PUBLIC"); return (index==1 and f=="PUBLIC") or (index==2 and f=="OWNED") or (index==3 and f=="ALL") end
    else
        if tab=="DUNGEONS" then return (index==3 and view.autoAccept==true) or (index==4 and view.enforceRoles==true) end
    end
    return false
end

function M:ActionsFor(tab,view)
    if tab=="GEAR" then return {
        {"EQUIP BEST",function() J:RunInteractiveGearOptimizer("GEAR") end,true},
        {"FAST TRAVEL",function() J:RunInteractivePrimary("GEAR") end},
        {"ROUTE SOURCE",function() J:RunInteractiveSecondaryAction("GEAR") end},
        {"ZONE QUESTS",function() J:RunInteractiveTertiaryAction("GEAR") end},
        {"OPEN BUILDS",function() if EPC.LoadoutManager then EPC.LoadoutManager:Show() end end},
        {"BEST COMPANION",function() if EPC.CompanionOptimizer then EPC.CompanionOptimizer:EquipBestAbilities() end end},
        {"BEST WEAPONS",function() if EPC.GearOptimizer then EPC.GearOptimizer:EquipBestWeapons() end end},
        {"BEST JEWELRY",function() if EPC.GearOptimizer then EPC.GearOptimizer:EquipBestJewelry() end end},
        {"BEST POTIONS",function() if EPC.GearOptimizer then EPC.GearOptimizer:EquipBestPotions() end end},
        {"BEST LIGHT",function() if EPC.GearOptimizer then EPC.GearOptimizer:EquipBestArmorWeight("LIGHT") end end},
        {"BEST MEDIUM",function() if EPC.GearOptimizer then EPC.GearOptimizer:EquipBestArmorWeight("MEDIUM") end end},
        {"BEST HEAVY",function() if EPC.GearOptimizer then EPC.GearOptimizer:EquipBestArmorWeight("HEAVY") end end},
        {"BEST ENDGAME",function() if EPC.GearOptimizer and EPC.GearOptimizer.EquipBestRecommended then EPC.GearOptimizer:EquipBestRecommended() end end},
    } end
    if tab=="QUESTS" then return {
        {"ROUTE QUEST",function() J:RunInteractivePrimary("QUESTS") end,true},
        {"TRAVEL WAYSHRINE",function() J:RunInteractiveSecondaryAction("QUESTS") end},
    } end
    if tab=="TRAVEL" then return {
        {"TRAVEL SELECTED",function() J:RunInteractivePrimary("TRAVEL") end,true},
        {"MERCHANT",function() J:RunInteractiveSecondaryAction("TRAVEL") end},
        {"GUILD STORE",function() J:RunInteractiveTertiaryAction("TRAVEL") end},
        {"STABLEMASTER",function() if EPC.Travel then EPC.Travel:TravelToNearestService("STABLE") end end},
        {"PLEDGE MASTER",function() if EPC.Travel then EPC.Travel:TravelToPledgeMaster() end end},
        {"GUILD LEADER HOME",function()
            local travelPage=self.pages and self.pages.TRAVEL
            local anchor=travelPage and travelPage.actionButtons and travelPage.actionButtons[6]
            if J and J.ShowGuildLeaderHomeDropdown and anchor then
                J:ShowGuildLeaderHomeDropdown({
                    guildLeaderSelect=anchor,
                    guildLeaderTravelOnSelect=true,
                    guildLeaderAnchorAbove=true,
                })
            elseif EPC.Travel then
                EPC.Travel:TravelToSelectedGuildLeaderHome()
            end
        end},
    } end
    if tab=="ACTIVITY" then return {{"REFRESH",function() if EPC.RefreshNow then EPC:RefreshNow("modern-activity") end end,true}} end
    if tab=="DUNGEONS" then return {
        {view.queued and "QUEUED" or "QUEUE SELECTED",function() J:RunInteractiveGearOptimizer("DUNGEONS") end,true},
        {"HOST CURRENT",function() J:RunInteractivePrimary("DUNGEONS") end},
        {"FIND REPLACEMENT",function() J:RunInteractiveSecondaryAction("DUNGEONS") end},
        {"CANCEL QUEUE",function() J:RunInteractiveTertiaryAction("DUNGEONS") end},
        {"RANDOM NORMAL",function() if EPC.DungeonFinder then EPC.DungeonFinder:QueueRandom("NORMAL") end end},
        {"RANDOM VETERAN",function() if EPC.DungeonFinder then EPC.DungeonFinder:QueueRandom("VETERAN") end end},
    } end
    if tab=="BATTLEGROUNDS" then return {
        {view.queued and "QUEUED" or "QUEUE SELECTED",function() if EPC.BattlegroundFinder then EPC.BattlegroundFinder:QueueSelected() end end,true},
        {"CANCEL QUEUE",function() if EPC.BattlegroundFinder then EPC.BattlegroundFinder:CancelQueue() end end},
        {"REFRESH",function() if EPC.BattlegroundFinder then EPC.BattlegroundFinder:BuildLocations(true) end end},
    } end
    if tab=="GROUPFINDER" then return {
        {"APPLY",function() J:RunInteractiveGearOptimizer("GROUPFINDER") end,true},
        {"WHISPER",function() J:RunInteractivePrimary("GROUPFINDER") end},
        {"RESCIND",function() J:RunInteractiveSecondaryAction("GROUPFINDER") end},
        {"HOST DUNGEON",function() J:RunInteractiveTertiaryAction("GROUPFINDER") end},
        {"REFRESH GROUPS",function() if EPC.DungeonFinder then EPC.DungeonFinder:RefreshLiveListings(true) end end},
    } end
    if tab=="ZONEGUIDE" and EPC.FinderSuite then return {
        {"TRACK / START",function() EPC.FinderSuite:TrackSelectedZoneGuide() end,true},
        {"STOP TRACKING",function() EPC.FinderSuite:StopZoneGuideTracking() end},
        {"QUEST FINDER",function() self:SetTab("QUESTS") end},
        {"MAP / TRAVEL",function() self:SetTab("TRAVEL") end},
        {"REFRESH",function() end},
    } end
    if tab=="TRIBUTE" and EPC.FinderSuite then return {
        {view.queued and "QUEUED" or "QUEUE SELECTED",function() EPC.FinderSuite:QueueSelectedTribute() end,true},
        {"CANCEL QUEUE",function() EPC.FinderSuite:CancelActivityQueue() end},
        {"REFRESH",function() end},
    } end
    if tab=="HOMETOURS" and EPC.FinderSuite then return {
        {"VISIT SELECTED",function() EPC.FinderSuite:VisitSelectedHome() end,true},
        {"REFRESH",function() end},
    } end
    return {}
end

function M:RunInteractiveFilter(tab,index)
    local p=self.pages and self.pages[tab]; if p then p.detailPage=1 end
    if EPC.FinderSuite and EPC.FinderSuite.Handles and EPC.FinderSuite:Handles(tab) then
        if index==4 then
            -- Refresh is a live rebuild; no external scene is opened.
        else
            EPC.FinderSuite:RunFilter(tab,index)
        end
    else
        J:RunInteractiveControl(tab,index)
    end
    self:RefreshCurrent()
end
function M:RunInteractiveSecondary(tab,index)
    local p=self.pages and self.pages[tab]; if p then p.detailPage=1 end
    if EPC.FinderSuite and EPC.FinderSuite.Handles and EPC.FinderSuite:Handles(tab) then
        EPC.FinderSuite:RunSecondary(tab,index)
    else
        J:RunInteractiveSecondary(tab,index)
    end
    self:RefreshCurrent()
end
function M:SelectInteractiveRow(tab,index)
    local p=self.pages and self.pages[tab]; if p then p.detailPage=1 end
    if tab=="GROUPFINDER" then
        local view=self:GetInteractiveView(tab)
        local row=view and view.rows and view.rows[index]
        if row and row.placeholder then return end
    end
    if EPC.FinderSuite and EPC.FinderSuite.Handles and EPC.FinderSuite:Handles(tab) then
        EPC.FinderSuite:SelectVisibleRow(tab,index)
    else
        J:SelectInteractiveRow(tab,index)
    end
    self:RefreshCurrent()
end
function M:RunAction(tab,index)
    if not (tab=="TRAVEL" and index==6) and J.HideGuildLeaderHomeDropdown then
        J:HideGuildLeaderHomeDropdown()
    end
    local view=self:GetInteractiveView(tab); local actions=self:ActionsFor(tab,view); local a=actions[index]
    if a and type(a[2])=="function" then a[2](); self:RefreshCurrent() end
end

local function finderCardSections(tab,sel)
    if not sel then return nil end

    if tab=="TRIBUTE" then
        local mode=sel.competitive and "Competitive" or "Casual"
        local status=sel.locked and "Locked" or "Available"
        local sections={}
        local about=trimLine(clean(sel.description or ""))
        if about~="" then sections[#sections+1]={"MATCHMAKING",{about}} end

        local stateItems={
            "Mode: "..mode,
            "Queue status: "..status,
        }
        if sel.dailyReady then stateItems[#stateItems+1]="Daily reward: Available" end
        sections[#sections+1]={"STATUS",stateItems}

        local reason=trimLine(clean(sel.lockReason or ""))
        if reason~="" then
            sections[#sections+1]={"REQUIREMENT",{reason}}
        elseif not sel.locked then
            sections[#sections+1]={"ACCESS",{"Ready to queue directly from the Suite."}}
        end
        return sections
    end

    if tab=="HOMETOURS" then
        local sections={}
        local about=trimLine(clean(sel.description or ""))
        if about~="" then sections[#sections+1]={"ABOUT",{about}} end

        local statusItems={}
        if sel.publicTour then
            statusItems[#statusItems+1]="Type: Public Home Tour"
            local owner=trimLine(clean(sel.owner or ""))
            if owner~="" then statusItems[#statusItems+1]="Host: "..owner end
        else
            statusItems[#statusItems+1]="Ownership: "..(sel.owned and "Owned" or "Not owned")
            if sel.primary then statusItems[#statusItems+1]="Residence: Primary" end
        end
        sections[#sections+1]={"HOME STATUS",statusItems}

        if sel.publicTour then
            sections[#sections+1]={"VISIT",{"This Home Tours listing can be visited from the Suite when ESO exposes a valid visit action."}}
        elseif sel.owned then
            sections[#sections+1]={"VISIT",{"Owned home available through the Suite housing browser."}}
        end
        return sections
    end

    return nil
end

local function setFinderDetailSection(controlPair,heading,body,maxChars)
    if not controlPair then return end
    heading=trimLine(clean(heading or ""))
    body=trimLine(clean(body or ""))
    -- Force real newline characters before handing text to ESO's label renderer.
    -- The requirement section uses a narrower character target so it remains
    -- readable even at the Suite's 980px minimum width.
    body=wrapTextWords(body,maxChars or 38)
    local visible=(heading~="" or body~="")
    controlPair.head:SetHidden(not visible)
    controlPair.body:SetHidden(not visible)
    if visible then
        controlPair.head:SetText(string.upper(heading))
        controlPair.body:SetText(body)
    else
        controlPair.head:SetText("")
        controlPair.body:SetText("")
    end
end

local function refreshFinderDetailSections(tab,p,sel)
    local controls=p and p.finderDetailSections
    if not controls then return false end
    for i=1,4 do setFinderDetailSection(controls[i],"","") end
    if not sel then return false end

    if tab=="TRIBUTE" then
        local mode=sel.competitive and "Competitive" or "Casual"
        local queueType=sel.competitive and "Ranked matchmaking" or "Unranked matchmaking"
        local status=sel.locked and "Locked" or "Available"
        if sel.dailyReady and not sel.locked then status=status.."\nDaily reward available" end
        local requirement=trimLine(clean(sel.lockReason or ""))
        if requirement=="" then requirement=sel.locked and "This queue is currently locked." or "Ready to queue directly from the Suite." end
        setFinderDetailSection(controls[1],"MATCH TYPE",mode.." Tales of Tribute")
        setFinderDetailSection(controls[2],"MATCHMAKING",queueType)
        setFinderDetailSection(controls[3],"STATUS",status)
        setFinderDetailSection(controls[4],sel.locked and "REQUIREMENT" or "ACCESS",requirement,30)
        return true
    end

    if tab=="HOMETOURS" then
        local about=trimLine(clean(sel.description or ""))
        if about=="" then about=sel.publicTour and "Public Home Tours listing." or "Owned home available through the Suite housing browser." end
        local ownership
        if sel.publicTour then
            local owner=trimLine(clean(sel.owner or ""))
            ownership=owner~="" and ("Public listing\nHost: "..owner) or "Public listing"
        else
            ownership=sel.owned and "Owned" or "Not owned"
        end
        local residence=sel.primary and "Primary residence" or (sel.owned and "Owned residence" or "Not a primary residence")
        local visit=sel.publicTour and "Visit this Home Tours listing directly from the Suite." or (sel.owned and "Visit this owned home directly from the Suite." or "This home is not currently owned.")
        setFinderDetailSection(controls[1],"ABOUT",about)
        setFinderDetailSection(controls[2],"OWNERSHIP",ownership)
        setFinderDetailSection(controls[3],"RESIDENCE",residence)
        setFinderDetailSection(controls[4],"VISIT",visit)
        return true
    end
    return false
end


function M:RefreshInteractive(tab,p)
    local view=self:GetInteractiveView(tab) or {rows={}}
    local f,s=self:FilterLabels(tab,view)
    for i=1,4 do
        local b=p.filterButtons[i]
        setButtonText(b,f[i] or "")
        b:SetHidden((f[i] or "")=="")
        styleButton(b, interactiveStateSelected(tab,view,false,i), false)
        local sb=p.secondaryButtons[i]
        setButtonText(sb,s[i] or "")
        sb:SetHidden((s[i] or "")=="")
        styleButton(sb, interactiveStateSelected(tab,view,true,i), false)
    end
    for i,rowControl in ipairs(p.rows) do
        local row=view.rows and view.rows[i]
        if row then
            rowControl:SetHidden(false); local t,d=rowTitleDetail(tab,row); rowControl.title:SetText(t); rowControl.detail:SetText(d ~= "" and ("• "..d) or "")
            local selected=selectedMatches(tab,view,row)
            local isTravelZone = tab=="TRAVEL" and tostring(view.mode or "") == "SHRINES" and row.kind == "ZONE_HEADER"
            local isTravelShrine = tab=="TRAVEL" and tostring(view.mode or "") == "SHRINES" and row.kind == "SHRINE"

            -- v0.29.31: zone headers and actual wayshrine destinations must not
            -- visually merge together. Zone rows use ESO-style gold while
            -- wayshrines remain cool neutral rows; a selected shrine still uses
            -- the normal alliance accent so the active destination is obvious.
            if isTravelZone then
                rowControl._easBaseCenter029122={0.115,0.090,0.035,0.985}
                rowControl._easBaseEdge029122={0.82,0.64,0.24,0.82}
                rowControl._easBaseTitle029122={0.96,0.80,0.36,1}
                rowControl._easBaseDetail029122={0.74,0.65,0.43,1}
            elseif isTravelShrine and not selected then
                rowControl._easBaseCenter029122={0.050,0.057,0.073,0.985}
                rowControl._easBaseEdge029122={0.25,0.30,0.38,0.58}
                rowControl._easBaseTitle029122={0.93,0.95,0.98,1}
                rowControl._easBaseDetail029122={0.57,0.66,0.76,1}
            else
                rowControl._easBaseCenter029122=selected and {ACCENT[1]*0.40,ACCENT[2]*0.40,ACCENT[3]*0.40,0.99} or {0.078,0.082,0.106,0.98}
                rowControl._easBaseEdge029122=selected and {ACCENT[1],ACCENT[2],ACCENT[3],1} or {0.28,0.30,0.38,0.46}
                rowControl._easBaseTitle029122={selected and 1 or 0.95,selected and 1 or 0.96,selected and 1 or 0.99,1}
                rowControl._easBaseDetail029122=selected and {0.94,0.96,1,1} or {MUTED[1],MUTED[2],MUTED[3],MUTED[4] or 1}
            end
            setPanelVisual(rowControl.bg,rowControl._easBaseCenter029122,rowControl._easBaseEdge029122)
            setLabelColor029123(rowControl.title,rowControl._easBaseTitle029122,TEXT)
            setLabelColor029123(rowControl.detail,rowControl._easBaseDetail029122,MUTED)
            if rowControl.accentRail then rowControl.accentRail:SetColor(0,0,0,0) end
        else rowControl:SetHidden(true) end
    end
    if tab=="GROUPFINDER" then
        p.pageLabel:SetText(string.format("%d RESULTS",tonumber(view.total) or #(view.rows or {})))
    else
        p.pageLabel:SetText(string.format("%d RESULTS  •  PAGE %d / %d",tonumber(view.total) or #(view.rows or {}),tonumber(view.page) or 1,tonumber(view.pageCount) or 1))
    end
    local sel=view.selected
    local titleText,bodyText,questSections,gearSections
    if tab=="QUESTS" then
        if sel then
            titleText=clean(sel.name or "Selected quest")
            questSections=questSelectedSections(sel)
            bodyText=infoSections(questSections)
        else
            titleText=clean(view.title or "Quest Finder")
            questSections=questOverviewSections(view)
            bodyText=infoSections(questSections)
        end
    elseif tab=="GEAR" then
        if sel then
            titleText=clean(sel.name or "Selected set")
            gearSections=gearSelectedSections(view,sel)
        else
            titleText=clean(view.title or "Find an armor or weapon set")
            gearSections=gearOverviewSections(view)
        end
        bodyText=infoSections(gearSections)
    elseif sel then
        titleText=clean(sel.name or sel.title or sel.displayText or sel.owner or "Selected")
        local finderSections=finderCardSections(tab,sel)
        if finderSections then
            bodyText=infoSections(finderSections)
        else
        local parts,seen={},{}
        local keys
        if tab=="ZONEGUIDE" then
            -- Zone Guide already identifies the selected zone in its surrounding
            -- view. Avoid a stray bare zone-name bullet and duplicate progress.
            if sel.kind=="COMPLETION" then
                keys={"description","detailText"}
            elseif sel.kind=="FEATURED_ACHIEVEMENT" then
                keys={"description","detail"}
            else
                keys={"description","detailText"}
            end
        else
            keys={"description","detailText","detail","sourceText","hint","statusText","zone","zoneName","owner","roles","lockReason"}
        end
        for _,k in ipairs(keys) do
            local v=sel[k]
            if v and tostring(v)~="" then
                local item=clean(v)
                if item~="" and not seen[item] then seen[item]=true; parts[#parts+1]=item end
            end
        end
        if tab=="ZONEGUIDE" and sel.kind=="SUMMARY" and view.completionSummary then
            local mapLines={"MAP COMPLETION"}
            for _,line in ipairs(view.completionSummary) do mapLines[#mapLines+1]=line end
            local mapText=table.concat(mapLines,"\n")
            if not seen[mapText] then parts[#parts+1]=mapText; seen[mapText]=true end
        end
        if tab=="GEAR" and sel.unlocked then local item=string.format("Collection: %d / %d",tonumber(sel.unlocked) or 0,tonumber(sel.total) or 0); if not seen[item] then parts[#parts+1]=item; seen[item]=true end end
        if tab=="BATTLEGROUNDS" and sel.minGroupSize then local item=string.format("Team size: %s",tostring(sel.maxGroupSize or sel.minGroupSize)); if not seen[item] then parts[#parts+1]=item; seen[item]=true end end
        bodyText=infoSections({{tab=="ZONEGUIDE" and "ZONE DETAILS" or "DETAILS",parts}})
        end
    else
        titleText=clean(view.title or view.header or TAB_LABELS[tab] or tab)
        bodyText=infoSections({{"OVERVIEW",{clean(view.description or view.hint or "Select a card to see details and available actions.")}}})
    end
    p.detailTitle:SetText(titleText)
    local structuredFinder=refreshFinderDetailSections(tab,p,sel)
    if p.detailBody then p.detailBody:SetHidden(structuredFinder) end
    local detailBody,detailPage,detailPages
    if structuredFinder then
        detailBody,detailPage,detailPages="",1,1
    elseif tab=="QUESTS" then
        -- Quest details use section-aware pagination. A heading and its first
        -- bullet stay together, and long bullets are never visually clipped by
        -- the PREV/NEXT row. This also keeps every available record field
        -- reachable through paging instead of truncating the bottom of the label.
        detailBody,detailPage,detailPages=paginateInfoSections(questSections,p.detailPage,9,46)
    elseif tab=="GEAR" then
        -- Gear & Sets uses the same readable section model as Quest Finder.
        -- The detail area is taller, headings stay attached to their first bullet,
        -- and PREV/NEXT exposes every collection/source/action-guide detail.
        detailBody,detailPage,detailPages=paginateInfoSections(gearSections,p.detailPage,6,44)
    elseif tab=="ZONEGUIDE" then
        bodyText=wrapTextWords(bodyText,48)
        detailBody,detailPage,detailPages=paginateSingle(bodyText,p.detailPage,9)
    elseif tab=="TRIBUTE" or tab=="HOMETOURS" then
        -- Keep headings and their bullets together so status, requirements,
        -- ownership, and visit information read as separate blocks instead of
        -- one compressed paragraph.
        if sel then
            detailBody,detailPage,detailPages=paginateInfoSections(finderCardSections(tab,sel),p.detailPage,8,46)
        else
            bodyText=wrapTextWords(bodyText,46)
            detailBody,detailPage,detailPages=paginateSingle(bodyText,p.detailPage,8)
        end
    else
        bodyText=wrapTextWords(bodyText,52)
        detailBody,detailPage,detailPages=paginateSingle(bodyText,p.detailPage,4)
    end
    p.detailPage=detailPage
    if p.detailBody then
        if not structuredFinder then p.detailBody:SetHidden(false); p.detailBody:SetText(detailBody) end
    end
    p.detailPageLabel:SetText(string.format("PAGE %d / %d",detailPage,detailPages))
    local hideSingleFinderPage=structuredFinder or ((tab=="TRIBUTE" or tab=="HOMETOURS") and detailPages<=1)
    p.detailPageLabel:SetHidden(hideSingleFinderPage)
    p.detailPrev:SetHidden(structuredFinder or detailPages<=1); p.detailNext:SetHidden(structuredFinder or detailPages<=1); setEnabled(p.detailPrev,detailPage>1); setEnabled(p.detailNext,detailPage<detailPages)
    local actions=self:ActionsFor(tab,view)
    for i,b in ipairs(p.actionButtons) do
        local a=actions[i]; if a then b:SetHidden(false); setButtonText(b,a[1]); b._primary=a[3]==true; styleButton(b,false,b._primary); b:SetHandler("OnClicked",function() self:RunAction(tab,i) end) else b:SetHidden(true) end
    end
end

function M:CreateTextPage(tab)
    local p=self:PageRoot(tab); pageHeader(p,tab,TAB_LABELS[tab],"Live recommendations and tools from the existing ESO Adventurer Suite backend.")
    p.left=flatPanel("EAS_ModernTextLeft02895_"..tab,p,8,90,566,526,SURFACE,EDGE_SOFT)
    p.right=flatPanel("EAS_ModernTextRight02895_"..tab,p,590,90,568,526,SURFACE,EDGE_SOFT)
    p.leftHead=label("EAS_ModernTextLeftHead02895_"..tab,p.left,"OVERVIEW",22,18,522,22,"ZoFontGameBold",ACCENT)
    p.rightHead=label("EAS_ModernTextRightHead02895_"..tab,p.right,"DETAILS",22,18,524,22,"ZoFontGameBold",ACCENT)
    p.leftText=label("EAS_ModernTextLeftLabel02895_"..tab,p.left,"",22,50,522,330,"ZoFontGame",MUTED)
    p.rightText=label("EAS_ModernTextRightLabel02895_"..tab,p.right,"",22,50,524,286,"ZoFontGame",MUTED)
    -- Skills page 2 renders Champion Point information with one control per
    -- visible row. ESO labels can occasionally collapse adjacent newline text
    -- when several CP stars are packed into one control, so each heading,
    -- planned total, and Champion star gets its own fixed row instead.
    if tab=="SKILLS" then
        p.cpRows={}
        for i=1,16 do
            local l=label("EAS_ModernSkillsCPRow02922_"..i,p.left,"",22,50,522,22,"ZoFontGame",MUTED)
            l:SetHidden(true)
            p.cpRows[i]=l
        end
    elseif tab=="STATS" then
        -- Character Stats uses one label per visible row. ESO can visually merge
        -- the last two newline-delimited entries when a long ledger fills a fixed
        -- label, so spending rows are rendered independently instead.
        p.statsLeftRows={}
        p.statsRightRows={}
        for i=1,22 do
            local leftRow=label("EAS_ModernStatsLeftRow02924_"..i,p.left,"",22,50,522,22,"ZoFontGame",MUTED)
            leftRow:SetHidden(true)
            p.statsLeftRows[i]=leftRow
            local rightRow=label("EAS_ModernStatsRightRow02924_"..i,p.right,"",22,50,524,22,"ZoFontGame",MUTED)
            rightRow:SetHidden(true)
            p.statsRightRows[i]=rightRow
        end
    end
    p.textPage=1
    p.prev=button("EAS_ModernTextPrev02895_"..tab,p.left,"< PREV",22,438,104,38,function()
        p.textPage=math.max(1,(tonumber(p.textPage) or 1)-1); self:RefreshTextPage(tab,p)
    end)
    p.pageLabel=label("EAS_ModernTextPage02895_"..tab,p.left,"PAGE 1 / 1",136,447,286,20,"ZoFontGameSmall",MUTED); p.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    p.next=button("EAS_ModernTextNext02895_"..tab,p.left,"NEXT >",432,438,104,38,function()
        p.textPage=(tonumber(p.textPage) or 1)+1; self:RefreshTextPage(tab,p)
    end)
    p.actionsHead=label("EAS_ModernTextActionsHead02895_"..tab,p.right,"AVAILABLE ACTIONS",22,342,524,22,"ZoFontGameBold",ACCENT)
    p.actions={}
    for i=1,8 do
        local col=(i-1)%2; local row=math.floor((i-1)/2)
        local b=button("EAS_ModernTextAction02895_"..tab.."_"..i,p.right,"",22+col*263,372+row*36,252,32,function() self:RunTextAction(tab,i) end,i==1)
        b:SetHidden(true); p.actions[i]=b
    end
    return p
end

function M:TextActions(tab)
    if tab=="ACHIEVEMENTS" then return {"MASTER TRACKER","REFRESH"} end
    if tab=="COMBAT" then return {"FULL COMBAT REPORT","REFRESH"} end
    if tab=="SKILLS" then return {"MAX POWER BUILD","MAX POWER CP","MAX POWER ATTRIBUTES","SKILL POINT FINDER","REFRESH"} end
    if tab=="TOOLS" then
        local mode=EPC.UtilitySuite and EPC.UtilitySuite:GetMode() or "OVERVIEW"
        if mode=="RETICLE" then return {"MODE","ON / OFF","STYLE","COLOR","SIZE -","SIZE +","OPACITY -","OPACITY +"} end
        if mode=="SELL" then return {"MODE","< ITEM","ITEM >","SELL ITEM","SELL JUNK","REFRESH"} end
        return {"MODE","REFRESH"}
    end
    return {"REFRESH"}
end

function M:RunTextAction(tab,index)
    if tab=="ACHIEVEMENTS" and index==1 then
        if EPC.MasterAchievementTracker and type(EPC.MasterAchievementTracker.Show)=="function" then
            self:Hide()
            EPC.MasterAchievementTracker:Show()
            return
        end
    elseif tab=="ACHIEVEMENTS" and index==2 then
        if EPC.MasterAchievementTracker and type(EPC.MasterAchievementTracker.Refresh)=="function" then
            EPC.MasterAchievementTracker:Refresh()
        end
    elseif tab=="SKILLS" and index==4 then
        if EPC.SkillPointFinder and type(EPC.SkillPointFinder.Show)=="function" then
            self:Hide()
            EPC.SkillPointFinder:Show()
            return
        end
    elseif tab=="SKILLS" and index==5 then
        if EPC.RefreshNow then EPC:RefreshNow("modern-skills") end
    elseif tab=="COMBAT" and index==1 then
        if EPC.GameModeReport and type(EPC.GameModeReport.Show) == "function" then
            self:Hide()
            EPC.GameModeReport:Show()
            return
        end
    elseif tab=="COMBAT" and index==2 then
        if EPC.RefreshNow then EPC:RefreshNow("modern-combat") end
    elseif tab=="TOOLS" and index==2 and EPC.UtilitySuite and EPC.UtilitySuite:GetMode()~="RETICLE" and EPC.UtilitySuite:GetMode()~="SELL" then
        if EPC.RefreshNow then EPC:RefreshNow("modern-tools") end
    else
        J:RunSuiteAction(tab,index)
    end
    self:RefreshCurrent()
end

function M:RefreshSkillsStructured02916(p)
    local v = EPC.GearOptimizer and EPC.GearOptimizer.BuildBestAbilityView and EPC.GearOptimizer:BuildBestAbilityView() or {}
    local c = v.context or {}
    local meta = v.meta
    local page = math.max(1, math.min(3, tonumber(p.textPage) or 1))
    local pages = 3

    if p.cpRows then
        for _,l in ipairs(p.cpRows) do l:SetHidden(true) end
    end
    p.leftText:SetHidden(false)

    if page == 1 then
        p.leftHead:SetText("PRIMARY BAR")
        p.rightHead:SetText("BACKUP BAR")

        local primaryProfile = {
            string.format("Build: %s", tostring(c.profile and c.profile.label or "Detected build")),
            string.format("Role: %s", tostring(c.role or "DAMAGE")),
            string.format("Weapon: %s", tostring(c.frontWeapon or "Weapon")),
        }
        if meta and EPC.SkillMeta then
            primaryProfile[#primaryProfile + 1] = string.format("Preset: %s", tostring(meta.preset or "TRIAL"))
            primaryProfile[#primaryProfile + 1] = string.format("Profile: %s", tostring(meta.label or "Current build"))
        end

        local primarySlots = {}
        for i = 1, 5 do
            local a = v.abilities and v.abilities[i]
            primarySlots[#primarySlots + 1] = string.format("%d. %s", i, tostring(a and a.name or "Empty"))
        end
        primarySlots[#primarySlots + 1] = "ULT. " .. tostring(v.ultimate and v.ultimate.name or "No purchased Ultimate")

        local backupProfile = {
            string.format("Weapon: %s", tostring(c.backWeapon or "Weapon")),
        }
        local backupSlots = {}
        for i = 1, 5 do
            local a = v.backAbilities and v.backAbilities[i]
            backupSlots[#backupSlots + 1] = string.format("%d. %s", i, tostring(a and a.name or "Empty"))
        end
        backupSlots[#backupSlots + 1] = "ULT. " .. tostring(v.backUltimate and v.backUltimate.name or "No purchased Ultimate")

        p.leftText:SetText(wrapTextWords(infoSections({
            {"PROFILE", primaryProfile},
            {"SLOTS", primarySlots},
        }), 58))
        p.rightText:SetText(wrapTextWords(infoSections({
            {"PROFILE", backupProfile},
            {"SLOTS", backupSlots},
        }), 58))
    elseif page == 2 then
        p.leftHead:SetText("CHAMPION POINTS")
        p.rightHead:SetText("ATTRIBUTES")

        local cpSections = {}
        if EPC.ChampionOptimizer and EPC.ChampionOptimizer.BuildView then
            local cpv = EPC.ChampionOptimizer:BuildView() or {}
            cpSections[#cpSections + 1] = {"REDISTRIBUTION", {string.format("Cost: %d gold", tonumber(cpv.cost) or 0)}}
            local byPool={}
            for _, pool in ipairs(cpv.pools or {}) do
                local items = {string.format("Planned: %d / %d", tonumber(pool.spent) or 0, tonumber(pool.budget) or 0)}
                for i, star in ipairs(pool.top or {}) do
                    if i > 2 then break end
                    items[#items + 1] = string.format("%s: %d%s", tostring(star.name or "Star"), tonumber(star.points) or 0, star.slottable and " [SLOT]" or "")
                end
                byPool[string.upper(tostring(pool.label or "POOL"))]={tostring(pool.label or "POOL"),items}
            end
            for _,name in ipairs({"CRAFT","WARFARE","FITNESS"}) do
                cpSections[#cpSections + 1]=byPool[name] or {name,{"No planned Champion Points."}}
            end
        else
            cpSections[#cpSections + 1] = {"STATUS", {"Champion optimizer unavailable."}}
        end

        local attrSections = {}
        local av = EPC.AttributeOptimizer and EPC.AttributeOptimizer.BuildView and EPC.AttributeOptimizer:BuildView() or nil
        if av then
            attrSections[#attrSections + 1] = {"CURRENT", {
                string.format("Role: %s", tostring(av.role or "DAMAGE")),
                string.format("Build: %s", tostring(av.build or "Current build")),
                string.format("%d Health / %d Magicka / %d Stamina", tonumber(av.current and av.current.health) or 0, tonumber(av.current and av.current.magicka) or 0, tonumber(av.current and av.current.stamina) or 0),
            }}
            attrSections[#attrSections + 1] = {"RECOMMENDED", {
                string.format("%d Health / %d Magicka / %d Stamina", tonumber(av.target and av.target.health) or 0, tonumber(av.target and av.target.magicka) or 0, tonumber(av.target and av.target.stamina) or 0),
            }}
            attrSections[#attrSections + 1] = {"REDISTRIBUTION", {
                string.format("Cost: %d gold", tonumber(av.cost) or 0),
                "Paid changes require confirmation.",
            }}
        else
            attrSections[#attrSections + 1] = {"STATUS", {"Attribute optimizer unavailable."}}
        end

        if p.cpRows and #cpSections>=1 then
            p.leftText:SetHidden(true)
            local rowIndex=1
            local y=50
            local function addCPRow(text,isHeading,extraGap)
                local l=p.cpRows[rowIndex]
                if not l then return end
                if extraGap then y=y+extraGap end
                l:ClearAnchors()
                l:SetAnchor(TOPLEFT,p.left,TOPLEFT,22,y)
                l:SetDimensions(522,22)
                l:SetText(tostring(text or ""))
                l:SetFont(isHeading and "ZoFontGameBold" or "ZoFontGame")
                if isHeading then l:SetColor(unpack(TEXT)) else l:SetColor(unpack(MUTED)) end
                l:SetHidden(false)
                rowIndex=rowIndex+1
                y=y+(isHeading and 22 or 20)
            end

            for sectionIndex,section in ipairs(cpSections) do
                if sectionIndex>1 then y=y+8 end
                addCPRow(string.upper(tostring(section[1] or "")),true)
                for _,item in ipairs(section[2] or {}) do
                    addCPRow("• "..tostring(item or ""),false)
                end
            end
            for i=rowIndex,#p.cpRows do p.cpRows[i]:SetHidden(true) end
        else
            p.leftText:SetText(wrapTextWords(infoSections(cpSections), 58))
        end
        p.rightText:SetText(wrapTextWords(infoSections(attrSections), 58))
    else
        p.leftHead:SetText("SCRYING OPTIMIZER")
        p.rightHead:SetText("EXCAVATION OPTIMIZER")
        local scryingText, excavationText
        if EPC.AntiquityAssistant and type(EPC.AntiquityAssistant.BuildOptimizerView) == "function" then
            scryingText, excavationText = EPC.AntiquityAssistant:BuildOptimizerView()
        else
            scryingText = "Antiquity optimizer unavailable."
            excavationText = "Antiquity optimizer unavailable."
        end
        p.leftText:SetText(wrapTextWords(tostring(scryingText or ""), 56))
        p.rightText:SetText(wrapTextWords(tostring(excavationText or ""), 56))
    end

    p.textPage = page
    p.pageLabel:SetText(string.format("PAGE %d / %d", page, pages))
    p.prev:SetHidden(false); p.next:SetHidden(false)
    setEnabled(p.prev, page > 1); setEnabled(p.next, page < pages)
end

local function formatGold02923(value)
    local n=math.floor((tonumber(value) or 0)+0.5)
    local sign=n<0 and "-" or ""
    local digits=tostring(math.abs(n))
    local out={}
    while #digits>3 do
        table.insert(out,1,string.sub(digits,-3))
        digits=string.sub(digits,1,-4)
    end
    table.insert(out,1,digits)
    return sign..table.concat(out,",")
end

local function renderStatsRows02924(rows, sections, width, maxChars)
    if type(rows)~="table" then return end
    local rowIndex=1
    local y=50
    width=tonumber(width) or 522
    maxChars=tonumber(maxChars) or 44

    local function addRow(text,isHeading)
        local l=rows[rowIndex]
        if not l then return false end
        l:ClearAnchors()
        l:SetAnchor(TOPLEFT,l:GetParent(),TOPLEFT,22,y)
        l:SetDimensions(width,isHeading and 22 or 20)
        l:SetFont(isHeading and "ZoFontGameBold" or "ZoFontGame")
        if isHeading then l:SetColor(unpack(ACCENT)) else l:SetColor(unpack(MUTED)) end
        if l.SetMaxLineCount then l:SetMaxLineCount(1) end
        l:SetText(tostring(text or ""))
        l:SetHidden(false)
        rowIndex=rowIndex+1
        y=y+(isHeading and 24 or 20)
        return true
    end

    for sectionIndex,section in ipairs(sections or {}) do
        if sectionIndex>1 then y=y+8 end
        local head=trimLine(section[1])
        if head~="" then addRow(string.upper(head),true) end
        for _,item in ipairs(section[2] or {}) do
            item=trimLine(clean(item))
            if item~="" then
                local wrapped=wrapTextWords("• "..item,maxChars)
                for _,line in ipairs(textLines(wrapped)) do
                    if not addRow(line,false) then break end
                end
            end
        end
    end
    for i=rowIndex,#rows do rows[i]:SetHidden(true) end
end

function M:RefreshStatsStructured02924(p)
    local page=math.max(1,math.min(3,tonumber(p.textPage) or 1))
    local pages=3
    p.leftText:SetHidden(true)
    p.rightText:SetHidden(true)

    local spending=EPC.Activities and EPC.Activities.GetGoldSpendingView and EPC.Activities:GetGoldSpendingView() or {total=0,rows={}}
    local byKey={}
    for _,row in ipairs(spending.rows or {}) do byKey[tostring(row.key or "")]=row end
    local function spend(key)
        local row=byKey[key]
        local labelText=row and tostring(row.label or key) or tostring(key)
        local amount=row and (tonumber(row.amount) or 0) or 0
        return string.format("%s: %s gold",labelText,formatGold02923(amount))
    end

    local leftSections,rightSections
    if page==1 then
        p.leftHead:SetText("CHARACTER")
        p.rightHead:SetText("RIDING & WEALTH")

        local name=clean(safe(GetUnitName,"Player","player"))
        local account=clean(safe(GetDisplayName,""))
        local level=tonumber(safe(GetUnitLevel,0,"player")) or 0
        local cp=tonumber(safe(GetUnitChampionPoints,0,"player")) or 0
        local zone=clean(safe(GetUnitZone,"","player"))
        local bagUsed=tonumber(safe(GetNumBagUsedSlots,0,BAG_BACKPACK)) or 0
        local bagSize=tonumber(safe(GetBagSize,0,BAG_BACKPACK)) or 0
        local money=tonumber(safe(GetCurrentMoney,0)) or 0
        local inv,maxInv,stam,maxStam,speed,maxSpeed=safe(GetRidingStats,0)

        local identity={"Name: "..(name~="" and name or "Player")}
        if account~="" then identity[#identity+1]="Account: "..account end
        leftSections={
            {"IDENTITY",identity},
            {"PROGRESSION",{
                string.format("Level: %d",level),
                string.format("Champion Points: %d",cp),
            }},
            {"LOCATION",{zone~="" and ("Zone: "..zone) or "Zone: Unknown"}},
        }
        rightSections={
            {"INVENTORY & WEALTH",{
                string.format("Backpack: %d / %d",bagUsed,bagSize),
                "Current Gold: "..formatGold02923(money),
            }},
            {"RIDING TRAINING",{
                string.format("Speed: %d / %d",tonumber(speed) or 0,tonumber(maxSpeed) or 0),
                string.format("Stamina: %d / %d",tonumber(stam) or 0,tonumber(maxStam) or 0),
                string.format("Carry Capacity: %d / %d",tonumber(inv) or 0,tonumber(maxInv) or 0),
            }},
            {"GOLD TRACKING",{
                "Total tracked: "..formatGold02923(spending.total).." gold",
                "NEXT shows the full spending breakdown.",
            }},
        }
    elseif page==2 then
        p.leftHead:SetText("VENDORS")
        p.rightHead:SetText("SERVICES & UPGRADES")
        leftSections={
            {"CRAFTING & MAGIC",{
                spend("blacksmith"),spend("clothier"),spend("woodworker"),
                spend("jeweler"),spend("alchemist"),spend("enchanter"),
            }},
            {"GENERAL & FOOD",{
                spend("grocer"),spend("brewer"),spend("chef"),
                spend("armsman"),spend("armorer"),spend("merchant"),
            }},
        }
        rightSections={
            {"UPGRADES",{
                spend("stable"),spend("bagSpace"),spend("bankSpace"),spend("bankFees"),spend("buyback"),
            }},
            {"SERVICES",{
                spend("repairs"),spend("respec"),spend("travel"),
            }},
            {"JUSTICE",{
                spend("laundering"),spend("bounty"),
            }},
        }
    else
        p.leftHead:SetText("MARKET & SOCIAL")
        p.rightHead:SetText("OTHER GOLD OUTFLOW")
        leftSections={
            {"MARKET",{
                spend("guildStore"),spend("guildStoreFees"),spend("cashOnDelivery"),
            }},
            {"SOCIAL",{
                spend("playerTrade"),spend("mail"),
            }},
            {"CRAFTING SYSTEMS",{spend("crafting")}},
        }
        rightSections={
            {"GUILD & PVP",{
                spend("guildCosts"),spend("pvpCosts"),spend("tribute"),
            }},
            {"OTHER",{
                spend("other"),spend("unclassified"),
            }},
            {"TOTAL TRACKED",{
                formatGold02923(spending.total).." gold",
            }},
        }
    end

    renderStatsRows02924(p.statsLeftRows,leftSections,522,44)
    renderStatsRows02924(p.statsRightRows,rightSections,524,44)

    p.textPage=page
    p.pageLabel:SetText(string.format("PAGE %d / %d",page,pages))
    p.prev:SetHidden(false); p.next:SetHidden(false)
    setEnabled(p.prev,page>1); setEnabled(p.next,page<pages)
end

function M:RefreshTextPage(tab,p)
    if tab=="SKILLS" then
        self:RefreshSkillsStructured02916(p)
    elseif tab=="STATS" then
        self:RefreshStatsStructured02924(p)
    else
        local text=""
        if tab=="STATS" then text=J:BuildStatsText()
        elseif tab=="ACHIEVEMENTS" then text=J:BuildAchievementText()
        else text=J:BuildSuiteText(tab) end
        text=wrapTextWords(organizeInfoText(text),68)
        local l,r,page,pages=paginateColumns(text,p.textPage,12)
        p.textPage=page
        p.leftHead:SetText("OVERVIEW"); p.rightHead:SetText("DETAILS")
        p.leftText:SetText(l); p.rightText:SetText(r)
        p.pageLabel:SetText(string.format("PAGE %d / %d",page,pages))
        p.prev:SetHidden(pages<=1); p.next:SetHidden(pages<=1)
        setEnabled(p.prev,page>1); setEnabled(p.next,page<pages)
    end
    local actions=self:TextActions(tab)
    for i,b in ipairs(p.actions) do
        local t=actions[i]
        if t then b:SetHidden(false); setButtonText(b,t); b._primary=i==1; styleButton(b,false,b._primary) else b:SetHidden(true) end
    end
end

function M:CreatePursuits()
    local p=self:PageRoot("PURSUITS"); pageHeader(p,"PURSUITS","Golden Pursuits","Track campaign tasks, progress and linked quest travel from a modern card list.")
    p.list=flatPanel("EAS_ModernPursuitList02895",p,8,90,744,526,SURFACE,EDGE_SOFT); p.detail=flatPanel("EAS_ModernPursuitDetail02895",p,768,90,390,526,SURFACE,EDGE_SOFT)
    label("EAS_ModernPursuitListHead02895",p.list,"PURSUITS",14,12,300,20,"ZoFontGameBold",ACCENT)
    p.rows={}
    for i=1,9 do
        local b=wm:CreateControl("EAS_ModernPursuitRow02895_"..i,p.list,CT_BUTTON)
        b:SetAnchor(TOPLEFT,p.list,TOPLEFT,14,40+(i-1)*42); b:SetDimensions(716,36)
        local bg=flatPanel("EAS_ModernPursuitRowBG02895_"..i,b,0,0,nil,nil,SURFACE_2,{EDGE_SOFT[1],EDGE_SOFT[2],EDGE_SOFT[3],0.68}); bg:ClearAnchors(); bg:SetAnchorFill(b); bg:SetDrawLevel(0); setPanelVisual(bg,SURFACE_2,{EDGE_SOFT[1],EDGE_SOFT[2],EDGE_SOFT[3],0.68})
        local t=label("EAS_ModernPursuitRowTitle02895_"..i,b,"",12,2,690,17,"ZoFontGameBold"); constrainLabel(t,1,false)
        local d=label("EAS_ModernPursuitRowDetail02895_"..i,b,"",12,19,690,14,"ZoFontGameSmall",MUTED); constrainLabel(d,1,false)
        b.bg,b.title,b.detail=bg,t,d
        b:SetHandler("OnClicked",function(c) if c.pursuitIndex then self.selectedPursuit02880=c.pursuitIndex; self:RefreshCurrent() end end)
        p.rows[i]=b
    end
    p.pursuitPage=1
    p.prev=button("EAS_ModernPursuitPrev02895",p.list,"< PREV",14,438,94,36,function() p.pursuitPage=math.max(1,(tonumber(p.pursuitPage) or 1)-1); self.selectedPursuit02880=nil; self:RefreshPursuits(p) end)
    p.pageLabel=label("EAS_ModernPursuitPage02895",p.list,"PAGE 1 / 1",118,446,508,20,"ZoFontGameSmall",MUTED); p.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    p.next=button("EAS_ModernPursuitNext02895",p.list,"NEXT >",636,438,94,36,function() p.pursuitPage=(tonumber(p.pursuitPage) or 1)+1; self.selectedPursuit02880=nil; self:RefreshPursuits(p) end)
    p.detailTitle=label("EAS_ModernPursuitDetailTitle02895",p.detail,"Golden Pursuits",20,22,350,42,"ZoFontWinH2")
    p.detailBody=label("EAS_ModernPursuitDetailBody02895",p.detail,"",20,72,350,336,"ZoFontGame",MUTED)
    p.track=button("EAS_ModernPursuitTrack02895",p.detail,"TRACK / TRAVEL",20,446,350,42,function() self:ActivatePursuit(self.selectedPursuit02880 or 1) end,true)
    return p
end

function M:ActivatePursuit(index)
    local view=J.BuildGoldenPursuitsView2494 and J:BuildGoldenPursuitsView2494() or nil
    local row=view and view.rows and view.rows[index] or nil
    if not row then if EPC.Print then EPC:Print("Select a Golden Pursuit first.") end return false end
    if row.complete then if EPC.Print then EPC:Print("That Golden Pursuit is already complete.") end return true end

    if J.TrackGoldenPursuit2497 then pcall(J.TrackGoldenPursuit2497,J,row) end
    local questIndex,questName=nil,nil
    if J.FindJournalQuestForPursuit2497 then
        local ok,a,b=pcall(J.FindJournalQuestForPursuit2497,J,row); if ok then questIndex,questName=a,b end
    end
    if EPC.GoldenPursuits and EPC.GoldenPursuits.SetSelectedPursuitQuest2504 then
        pcall(EPC.GoldenPursuits.SetSelectedPursuitQuest2504,EPC.GoldenPursuits,row.name,questIndex and questName or nil,row.campaignKey,row.activityIndex)
    end
    if questIndex and EPC.ActiveQuest and EPC.ActiveQuest.SetSelectedQuest2512 then
        local questId=0
        if type(GetJournalQuestId)=="function" then local ok,v=pcall(GetJournalQuestId,questIndex); if ok then questId=tonumber(v) or 0 end end
        pcall(EPC.ActiveQuest.SetSelectedQuest2512,EPC.ActiveQuest,questIndex,questId,questName,"GOLDEN_PURSUIT")
    end
    if questIndex and J.TravelTrackedPursuitQuest2497 then
        if type(SetMapToQuestZone)=="function" then pcall(SetMapToQuestZone,questIndex) end
        if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then EPC.Travel:InvalidateQuestPositionCache() end
        pcall(J.TravelTrackedPursuitQuest2497,J,row,questIndex,questName,1)
    elseif J.FindPursuitTextWayshrine2497 and EPC.Travel and EPC.Travel.TravelToWayshrineNode then
        local ok,shrine=pcall(J.FindPursuitTextWayshrine2497,J,row)
        if ok and shrine then pcall(EPC.Travel.TravelToWayshrineNode,EPC.Travel,shrine.nodeIndex,shrine.name) end
    end
    if EPC.ActiveQuest and EPC.ActiveQuest.ApplySelectedSourceToESO2516 then pcall(EPC.ActiveQuest.ApplySelectedSourceToESO2516,EPC.ActiveQuest) end
    self:RefreshCurrent()
    return true
end

function M:RefreshPursuits(p)
    local v=J.BuildGoldenPursuitsView2494 and J:BuildGoldenPursuitsView2494() or {rows={}}
    local rows=v.rows or {}
    local pageSize=#p.rows
    local pages=math.max(1,math.ceil(#rows/pageSize))
    p.pursuitPage=math.max(1,math.min(pages,tonumber(p.pursuitPage) or 1))
    local first=(p.pursuitPage-1)*pageSize+1
    if not self.selectedPursuit02880 and rows[first] then self.selectedPursuit02880=first end
    for i,b in ipairs(p.rows) do
        local actual=first+i-1
        local r=rows[actual]
        if r then
            b:SetHidden(false); b.pursuitIndex=actual; b.title:SetText(clean(r.name))
            local pct=(tonumber(r.goal) or 0)>0 and math.floor(((tonumber(r.progress) or 0)/(tonumber(r.goal) or 1))*100+0.5) or 0
            b.detail:SetText("• "..string.format("%d / %d  •  %d%%",tonumber(r.progress) or 0,tonumber(r.goal) or 0,pct))
            local sel=(self.selectedPursuit02880 or first)==actual
            setPanelVisual(b.bg,sel and {ACCENT[1]*0.40,ACCENT[2]*0.40,ACCENT[3]*0.40,0.99} or {SURFACE_2[1],SURFACE_2[2],SURFACE_2[3],0.98},sel and {ACCENT[1],ACCENT[2],ACCENT[3],1} or {EDGE[1],EDGE[2],EDGE[3],0.40})
        else
            b:SetHidden(true); b.pursuitIndex=nil
        end
    end
    p.pageLabel:SetText(string.format("PAGE %d / %d  •  %d PURSUITS",p.pursuitPage,pages,#rows))
    p.prev:SetHidden(pages<=1); p.next:SetHidden(pages<=1); setEnabled(p.prev,p.pursuitPage>1); setEnabled(p.next,p.pursuitPage<pages)
    local r=rows[self.selectedPursuit02880 or first]
    if r then
        local pct=(tonumber(r.goal) or 0)>0 and math.floor(((tonumber(r.progress) or 0)/(tonumber(r.goal) or 1))*100+0.5) or 0
        p.detailTitle:SetText(clean(r.name))
        p.detailBody:SetText(infoSections({
            {"CAMPAIGN",{clean(r.campaignName)}},
            {"PROGRESS",{string.format("%d / %d (%d%%)",tonumber(r.progress) or 0,tonumber(r.goal) or 0,pct)}},
            {"CAMPAIGN PROGRESS",{string.format("%d / %d",tonumber(r.campaignCompleted) or 0,tonumber(r.campaignThreshold) or 0)}},
            {"TIME REMAINING",{tostring(r.secondsRemaining or "")}}
        }))
    else
        p.detailTitle:SetText("Golden Pursuits")
        p.detailBody:SetText(infoSections({{"STATUS",{v.status or "No active pursuits found."}}}))
    end
end

function M:CreateNotes()
    local p=self:PageRoot("NOTES"); pageHeader(p,"NOTES","Notes","A clean note library and editor. Your existing saved notes are preserved.")
    p.list=flatPanel("EAS_ModernNotesList02895",p,8,90,350,526,SURFACE,EDGE_SOFT); p.editor=flatPanel("EAS_ModernNotesEditor02895",p,374,90,784,526,SURFACE,EDGE_SOFT)
    label("EAS_ModernNotesListHead02895",p.list,"SAVED NOTES",14,14,322,22,"ZoFontGameBold",ACCENT)
    p.notePage=1; p.rows={}
    for i=1,8 do
        local b=button("EAS_ModernNoteRow02895_"..i,p.list,"",14,46+(i-1)*43,322,38,function(c) if c.entryId then J:SelectEntry(c.entryId); self:RefreshNotes() end end)
        setButtonAlignment(b,TEXT_ALIGN_LEFT); p.rows[i]=b
    end
    p.prev=button("EAS_ModernNotePrev02895",p.list,"< PREV",14,400,78,36,function() p.notePage=math.max(1,(tonumber(p.notePage) or 1)-1); self:RefreshNotes() end)
    p.pageLabel=label("EAS_ModernNotePage02895",p.list,"PAGE 1 / 1",98,408,154,20,"ZoFontGameSmall",MUTED); p.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    p.next=button("EAS_ModernNoteNext02895",p.list,"NEXT >",258,400,78,36,function() p.notePage=(tonumber(p.notePage) or 1)+1; self:RefreshNotes() end)
    p.new=button("EAS_ModernNoteNew02895",p.list,"NEW NOTE",14,456,154,38,function() J:NewEntry(); p.notePage=1; self:RefreshNotes() end,true)
    p.delete=button("EAS_ModernNoteDelete02895",p.list,"DELETE",182,456,154,38,function() J:DeleteEntry(); self:RefreshNotes() end)
    label("EAS_ModernNoteTitleHead02895",p.editor,"TITLE",18,14,748,20,"ZoFontGameBold",ACCENT)
    p.titleEdit=editBox("EAS_ModernNoteTitleEdit02895",p.editor,18,40,748,44,false)
    label("EAS_ModernNoteBodyHead02895",p.editor,"NOTE",18,96,748,20,"ZoFontGameBold",ACCENT)
    p.bodyEdit=editBox("EAS_ModernNoteBodyEdit02895",p.editor,18,122,748,330,true)
    p.save=button("EAS_ModernNoteSave02895",p.editor,"SAVE NOTE",18,466,190,40,function() J:SaveCurrentEntry(); self:RefreshNotes() end,true)
    J.noteTitleEdit=p.titleEdit; J.noteBodyEdit=p.bodyEdit; J.noteRows=p.rows; J.notePage=p; J.currentEntryId=J.currentEntryId or nil
    return p
end

function M:RefreshNotes()
    local p=self.pages.NOTES; if not p then return end
    local list=J:GetFilteredEntries() or {}
    local pageSize=#p.rows; local pages=math.max(1,math.ceil(#list/pageSize))
    p.notePage=math.max(1,math.min(pages,tonumber(p.notePage) or 1))
    local first=(p.notePage-1)*pageSize+1
    for i,b in ipairs(p.rows) do
        local e=list[first+i-1]
        if e then
            b:SetHidden(false); b.entryId=e.id; setButtonText(b,(e.id==J.currentEntryId and "• " or "")..tostring(e.title or "Untitled")); b._selected=e.id==J.currentEntryId; styleButton(b,b._selected,false)
        else
            b:SetHidden(true); b.entryId=nil
        end
    end
    p.pageLabel:SetText(string.format("PAGE %d / %d",p.notePage,pages)); p.prev:SetHidden(pages<=1); p.next:SetHidden(pages<=1); setEnabled(p.prev,p.notePage>1); setEnabled(p.next,p.notePage<pages)
    if J.currentEntryId then
        local e=J:FindEntry(J.currentEntryId)
        if e then
            if p.titleEdit:GetText()~=tostring(e.title or "") then p.titleEdit:SetText(e.title or "") end
            if p.bodyEdit:GetText()~=tostring(e.body or "") then p.bodyEdit:SetText(e.body or "") end
        end
    elseif list[1] then
        J.currentEntryId=list[1].id; p.titleEdit:SetText(list[1].title or ""); p.bodyEdit:SetText(list[1].body or "")
    else
        p.titleEdit:SetText(""); p.bodyEdit:SetText("")
    end
end

function M:CreatePins()
    local p=self:PageRoot("PINS"); pageHeader(p,"PINS","Checkpoints","Save named locations, set waypoints and travel toward the nearest discovered wayshrine.")
    p.list=flatPanel("EAS_ModernPinsList02880",p,8,90,458,526,SURFACE,EDGE_SOFT); p.detail=flatPanel("EAS_ModernPinsDetail02880",p,482,90,676,526,SURFACE,EDGE_SOFT)
    label("EAS_ModernPinNameHead02895",p.list,"CHECKPOINT NAME",14,12,430,20,"ZoFontGameBold",ACCENT)
    p.nameEdit,p.nameHost=editBox("EAS_ModernPinNameEdit02895",p.list,14,36,430,40,false); p.rows={}
    for i=1,8 do
        local b=button("EAS_ModernPinRow02895_"..i,p.list,"",14,84+(i-1)*40,430,36,function(c)
            if c.pinId then
                J.selectedPinId=c.pinId
                local selected=J:GetPinById(c.pinId)
                if selected and p.nameEdit then p.nameEdit:SetText(selected.name or "") end
                self:RefreshPins()
            end
        end)
        setButtonAlignment(b,TEXT_ALIGN_LEFT); p.rows[i]=b
    end
    -- v0.29.44: separate creation from editing so selecting one checkpoint
    -- never prevents the player from saving another checkpoint in the same zone.
    p.saveNew=button("EAS_ModernPinSaveNew02944",p.list,"SAVE NEW HERE",14,416,134,38,function()
        J:SaveCurrentLocation(p.nameEdit:GetText(),"new"); self:RefreshPins()
    end,true)
    p.update=button("EAS_ModernPinUpdate02944",p.list,"UPDATE SELECTED",156,416,158,38,function()
        J:SaveCurrentLocation(p.nameEdit:GetText(),"update"); self:RefreshPins()
    end)
    p.delete=button("EAS_ModernPinDelete02880",p.list,"DELETE",322,416,122,38,function() J:DeletePin(); self:RefreshPins() end)
    p.detailTitle=label("EAS_ModernPinDetailTitle02880",p.detail,"Checkpoint",22,22,630,36,"ZoFontWinH2")
    p.info=label("EAS_ModernPinInfo02880",p.detail,"Select a checkpoint.",22,72,630,300,"ZoFontGame",MUTED)
    p.waypoint=button("EAS_ModernPinWaypoint02880",p.detail,"SET WAYPOINT",22,420,200,40,function() J:SetPinWaypoint(); self:RefreshPins() end,true)
    p.travel=button("EAS_ModernPinTravel02880",p.detail,"TRAVEL TO WAYSHRINE",236,420,220,40,function() J:TravelToNearestCheckpointWayshrine(); self:RefreshPins() end)
    p.prev=button("EAS_ModernPinPrev02880",p.detail,"< PREV",470,420,84,40,function() J:ChangeCheckpointPage(-1); self:RefreshPins() end)
    p.next=button("EAS_ModernPinNext02880",p.detail,"NEXT >",566,420,84,40,function() J:ChangeCheckpointPage(1); self:RefreshPins() end)
    p.pageLabel=label("EAS_ModernPinPageLabel02880",p.detail,"",22,474,628,20,"ZoFontGameSmall",MUTED); p.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    J.checkpointNameEdit=p.nameEdit; J.pinRows=p.rows; J.pinInfo=p.info; J.pinWayshrine=p.travel; J.checkpointPageLabel=p.pageLabel; J.checkpointPrev=p.prev; J.checkpointNext=p.next
    return p
end

function M:RefreshPins()
    local p=self.pages.PINS; if not p then return end
    local pins=J:GetSortedCheckpoints(); local pageSize=#p.rows; local pages=math.max(1,math.ceil(#pins/pageSize)); J.checkpointPage=math.max(1,math.min(pages,tonumber(J.checkpointPage) or 1)); local first=(J.checkpointPage-1)*pageSize+1
    for i,b in ipairs(p.rows) do local pin=pins[first+i-1]; if pin then b:SetHidden(false); b.pinId=pin.id; setButtonText(b,tostring(pin.name or "Checkpoint").."  •  "..tostring(pin.zone or pin.mapName or "Map")); b._selected=pin.id==J.selectedPinId; styleButton(b,b._selected,false) else b:SetHidden(true); b.pinId=nil end end
    p.pageLabel:SetText(string.format("PAGE %d / %d  •  %d SAVED",J.checkpointPage,pages,#pins))
    local pin=J:GetPinById(J.selectedPinId)
    if pin then
        setEnabled(p.update,true)
        setEnabled(p.delete,true)
        p.detailTitle:SetText(pin.name or "Checkpoint")
        local shrine=J:GetNearestWayshrineForCheckpoint(pin,false)
        p.info:SetText(infoSections({
            {"LOCATION",{tostring(pin.zone or pin.mapName or "Unknown")}},
            {"COORDINATES",{string.format("%.2f, %.2f",(tonumber(pin.x) or 0)*100,(tonumber(pin.y) or 0)*100)}},
            {"NEAREST WAYSHRINE",{shrine and tostring(shrine.name or "Wayshrine") or "No discovered match"}}
        }))
        setEnabled(p.travel,shrine~=nil)
    else
        setEnabled(p.update,false)
        setEnabled(p.delete,false)
        p.detailTitle:SetText("Checkpoint")
        p.info:SetText(infoSections({{"HOW TO USE",{
            "Enter a name and choose SAVE NEW HERE to create another checkpoint anywhere, including the same zone.",
            "Select an existing checkpoint and choose UPDATE SELECTED only when you want to rename or move that saved checkpoint."
        }}}))
        setEnabled(p.travel,false)
    end
end

function M:CreateCodex()
    local p=self:PageRoot("CODEX"); pageHeader(p,"CODEX","Crafting Codex","Quick reference cards for Alchemy, Enchanting and provisioning/crafting notes.")
    p.modes={}; local modes={{"ALCHEMY","ALCHEMY"},{"RUNES","ENCHANTING"},{"MATERIALS","MATERIALS"}}
    for i,e in ipairs(modes) do
        p.modes[e[1]]=button("EAS_ModernCodexMode02895_"..e[1],p,e[2],8+(i-1)*170,88,158,36,function()
            J.codexMode=e[1]; p.codexPage=1; self:RefreshCodex()
        end)
    end
    p.card=flatPanel("EAS_ModernCodexCard02895",p,8,142,1150,474,SURFACE,EDGE_SOFT)
    p.text=label("EAS_ModernCodexText02895",p.card,"",24,24,1102,356,"ZoFontGame",MUTED)
    local codexFontSize = tonumber(EPC.saved and EPC.saved.codexModernFontSize029363) or 18
    codexFontSize = math.max(14, math.min(28, math.floor(codexFontSize + 0.5)))
    p.text:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thick", codexFontSize))
    p.codexPage=1
    p.prev=button("EAS_ModernCodexPrev02895",p.card,"< PREV",24,408,110,38,function() p.codexPage=math.max(1,(tonumber(p.codexPage) or 1)-1); self:RefreshCodex() end)
    p.pageLabel=label("EAS_ModernCodexPage02895",p.card,"PAGE 1 / 1",148,417,854,20,"ZoFontGameSmall",MUTED); p.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    p.next=button("EAS_ModernCodexNext02895",p.card,"NEXT >",1016,408,110,38,function() p.codexPage=(tonumber(p.codexPage) or 1)+1; self:RefreshCodex() end)
    J.codexBody=p.text; J.codexButtons=p.modes; J.codexMode=J.codexMode or "ALCHEMY"
    return p
end

function M:RefreshCodex()
    local p=self.pages.CODEX; if not p then return end
    local raw=J.GetCodexText and J:GetCodexText() or ""
    local fontSize = tonumber(EPC.saved and EPC.saved.codexModernFontSize029363) or 18
    fontSize = math.max(14, math.min(28, math.floor(fontSize + 0.5)))
    if p.text.SetFont then p.text:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thick", fontSize)) end
    -- Larger fonts need fewer characters per wrapped line and fewer lines per
    -- page. Recompute both so text remains readable rather than clipping.
    local maxChars = math.max(72, math.min(172, math.floor(145 * 18 / fontSize)))
    local linesPerPage = math.max(8, math.min(18, math.floor(350 / (fontSize + 6))))
    local formatted=wrapTextWords(organizeInfoText(raw),maxChars)
    local body,page,pages=paginateSingle(formatted,p.codexPage,linesPerPage)
    p.codexPage=page; p.text:SetText(body)
    p.pageLabel:SetText(string.format("PAGE %d / %d",page,pages))
    p.prev:SetHidden(pages<=1); p.next:SetHidden(pages<=1); setEnabled(p.prev,page>1); setEnabled(p.next,page<pages)
    for mode,b in pairs(p.modes or {}) do styleButton(b,mode==(J.codexMode or "ALCHEMY"),false) end
end

function M:CreateSettings()
    local p=self:PageRoot("SETTINGS")
    pageHeader(p,"SETTINGS","Suite Settings","Every existing gameplay/HUD/system setting remains available. Open the full ESO Adventurer Suite settings panel without losing any legacy logic.")
    p.card=flatPanel("EAS_ModernSettingsCard02883",p,8,96,1150,490,SURFACE,EDGE_SOFT)
    p.title=label("EAS_ModernSettingsTitle02883",p.card,"FULL SETTINGS & LOGIC",26,28,520,32,"ZoFontWinH2")
    -- v0.29.63: keep the preserved-systems copy, full-settings explanation,
    -- action button, and support panel in separate vertical bands.  The old
    -- combined body label extended behind the button at minimum window size.
    p.body=label("EAS_ModernSettingsBody02895",p.card,infoSections({
        {"PRESERVED SYSTEMS",{"SavedVariables and existing gameplay logic","HUD controls, role logic and difficulty rules","Overlays, chest finder, group glow and reticle","Vendor tools, queue behavior, optimizers and compatibility settings"}}
    }),26,82,1098,102,"ZoFontGame",MUTED)
    p.fullSettingsLabel=label("EAS_ModernSettingsFullLabel02960",p.card,"FULL SETTINGS",26,184,300,20,"ZoFontGameBold",TEXT)
    p.fullSettingsText=label("EAS_ModernSettingsFullText02960",p.card,
        "Open the complete addon settings panel. The Suite closes automatically so the settings remain fully interactive.",26,204,1098,20,"ZoFontGame",MUTED)
    p.open=button("EAS_ModernSettingsOpen02883",p.card,"OPEN FULL SETTINGS",26,232,270,46,function()
        local LAM=LibAddonMenu2
        local panelObj=EPC.Settings and EPC.Settings.panelObject
        if LAM and LAM.OpenToPanel and panelObj then
            -- v0.29.43: close the Suite before opening LibAddonMenu, but keep
            -- a hidden inherited keybind layer alive so the normal Suite hotkey
            -- can close the settings scene and reopen the Suite.
            self:Hide()
            self:ActivateSettingsHotkeyBridge02943()
            LAM:OpenToPanel(panelObj)
            self:RefreshSettingsHotkeyBridge02943()
        elseif type(SLASH_COMMANDS) == "table" and SLASH_COMMANDS["/esosuite"] then
            self:Hide()
            self:ActivateSettingsHotkeyBridge02943()
            SLASH_COMMANDS["/esosuite"]("settings")
            self:RefreshSettingsHotkeyBridge02943()
        elseif EPC.Print then EPC:Print("Open Settings > Addons > ESO Adventurer Suite.") end
    end,true)

    -- v0.29.63: make Creator/Support/Community use the available lower-page
    -- space instead of compressing everything into a tight disclaimer block.
    -- Identity and Discord details get distinct rows, while the invite is large
    -- and high-contrast.  Compliance text is reduced to two widely spaced rows.
    p.supportCard=flatPanel("EAS_ModernSettingsSupportCard02960",p.card,26,282,1098,200,SURFACE_2,{0.28,0.43,0.59,0.78})
    setPanelVisual(p.supportCard,{0.026,0.041,0.058,0.995},{0.28,0.43,0.59,0.78})

    p.supportTitle=label("EAS_ModernSettingsSupportTitle02960",p.supportCard,"CREATOR, SUPPORT & COMMUNITY",18,12,1060,24,"ZoFontGameBold",ACCENT)

    -- Left column: creator identity.
    p.supportCreatorLabel=label("EAS_ModernSettingsSupportCreatorLabel02960",p.supportCard,"ADDON",18,42,220,18,"ZoFontGameBold",ACCENT)
    p.supportCreatorValue=label("EAS_ModernSettingsSupportCreatorValue02960",p.supportCard,"HoZayyBadazz",18,62,430,26,"ZoFontWinH3",TEXT)

    p.supportUserLabel=label("EAS_ModernSettingsSupportUserLabel02960",p.supportCard,"IN GAME USER ID",18,94,220,18,"ZoFontGameBold",ACCENT)
    p.supportUserValue=label("EAS_ModernSettingsSupportUserValue02960",p.supportCard,"@ShadowOps187",18,114,430,26,"ZoFontWinH3",ESO_GOLD)

    -- Right column: community details.  The invite gets its own large value row
    -- so it is easy to read and copy manually from the game UI.
    p.supportDiscordLabel=label("EAS_ModernSettingsSupportDiscordLabel02960",p.supportCard,"DISCORD COMMUNITY",552,42,260,18,"ZoFontGameBold",ACCENT)
    p.supportDiscordValue=label("EAS_ModernSettingsSupportDiscordValue02960",p.supportCard,"The Legends Den",552,62,508,26,"ZoFontWinH3",TEXT)

    p.supportInviteLabel=label("EAS_ModernSettingsSupportInviteLabel02960",p.supportCard,"DISCORD INVITE",552,94,260,18,"ZoFontGameBold",ACCENT)
    p.supportInviteValue=label("EAS_ModernSettingsSupportInviteValue02960",p.supportCard,"discord.gg/Tj72TAEqat",552,114,508,28,"ZoFontWinH3",ESO_GOLD)

    p.supportOptionalLabel=label("EAS_ModernSettingsSupportOptionalLabel02960",p.supportCard,"OPTIONAL SUPPORT",18,142,220,18,"ZoFontGameBold",ACCENT)
    p.supportDisclaimer1=label("EAS_ModernSettingsSupportDisclaimer1_02960",p.supportCard,
        "Gold and Crown Store gifts are optional. The Suite and community support are free.",18,162,1060,18,"ZoFontGame",MUTED)
    p.supportDisclaimer2=label("EAS_ModernSettingsSupportDisclaimer2_02960",p.supportCard,
        "No feature, update, access, or support is sold or required. The Legends Den is not affiliated with or sponsored by ZeniMax.",18,182,1060,18,"ZoFontGame",MUTED)
    return p
end

function M:CreateDice()
    local p=self:PageRoot("DICE"); pageHeader(p,"DICE","Dice & Coin","Compact roleplay tools with no overflow outside the app window.")
    p.launch=flatPanel("EAS_ModernDiceLaunch02895",p,8,90,684,526,SURFACE,EDGE_SOFT); p.result=flatPanel("EAS_ModernDiceResult02895",p,708,90,450,526,SURFACE,EDGE_SOFT)
    local values={4,6,8,10,12,20,100}
    for i,sides in ipairs(values) do
        local col=(i-1)%4; local row=math.floor((i-1)/4)
        button("EAS_ModernDiceBtn02895_"..sides,p.launch,"D"..sides,24+col*158,32+row*74,142,56,function() J:Roll(sides); p.historyPage=1; self:RefreshDice() end,i==5)
    end
    button("EAS_ModernCoinBtn02895",p.launch,"COIN",24+3*158,106,142,56,function() J:TossCoin(); p.historyPage=1; self:RefreshDice() end)
    label("EAS_ModernDiceRecentHead02895",p.launch,"RECENT ROLLS",24,196,300,24,"ZoFontGameBold",ACCENT)
    p.history=label("EAS_ModernDiceHistory02895",p.launch,"",24,230,640,188,"ZoFontGame",MUTED)
    p.historyPage=1
    p.prev=button("EAS_ModernDicePrev02895",p.launch,"< PREV",24,446,104,38,function() p.historyPage=math.max(1,(tonumber(p.historyPage) or 1)-1); self:RefreshDice() end)
    p.pageLabel=label("EAS_ModernDicePage02895",p.launch,"PAGE 1 / 1",142,455,400,20,"ZoFontGameSmall",MUTED); p.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    p.next=button("EAS_ModernDiceNext02895",p.launch,"NEXT >",556,446,104,38,function() p.historyPage=(tonumber(p.historyPage) or 1)+1; self:RefreshDice() end)
    p.resultTitle=label("EAS_ModernDiceResultHead02895",p.result,"LUCK OF THE DRAW",24,28,400,24,"ZoFontGameBold",ACCENT)
    p.resultValue=label("EAS_ModernDiceResultValue02895",p.result,"READY",24,90,400,70,"ZoFontWinH1",ACCENT); p.resultValue:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    p.resultSub=label("EAS_ModernDiceResultSub02895",p.result,"Choose a die or toss a coin.",24,178,400,100,"ZoFontGame",MUTED); p.resultSub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    J.diceHistoryOutput=p.history; J.diceOutput=p.history; J.diceResultTitle=p.resultTitle; J.diceResultValue=p.resultValue; J.diceResultSub=p.resultSub
    return p
end

function M:RefreshDice()
    local p=self.pages.DICE; if not p then return end
    local history=J.diceHistory or {}
    local historyText=""
    if #history>0 then
        local lines={}; for _,v in ipairs(history) do lines[#lines+1]="• "..clean(v) end; historyText=table.concat(lines,"\n")
    else
        historyText="• No rolls yet."
    end
    local body,page,pages=paginateSingle(historyText,p.historyPage,10)
    p.historyPage=page; p.history:SetText(body); p.pageLabel:SetText(string.format("PAGE %d / %d",page,pages))
    p.prev:SetHidden(pages<=1); p.next:SetHidden(pages<=1); setEnabled(p.prev,page>1); setEnabled(p.next,page<pages)
    if J.lastChanceKind=="COIN" then
        p.resultTitle:SetText("COIN TOSS"); p.resultValue:SetText(J.lastChanceResult or "-"); p.resultSub:SetText("A quick decision using the same Suite dice backend.")
    elseif J.lastChanceKind=="DICE" then
        p.resultTitle:SetText("D"..tostring(J.lastChanceSides or 20).." ROLL"); p.resultValue:SetText(tostring(J.lastChanceResult or "-")); p.resultSub:SetText("Latest die result.")
    else
        p.resultTitle:SetText("LUCK OF THE DRAW"); p.resultValue:SetText("READY"); p.resultSub:SetText("Choose a die or toss a coin.")
    end
end

function M:EnsurePage(tab)
    if self.pages[tab] then return self.pages[tab] end
    if tab=="INDEX" then return self:CreateHome() end
    if tab=="CHARACTER" then return self:CreateCardGallery("CHARACTER",CLASS_CARDS,"Character","Class identity and build access. Your live class is highlighted.") end
    if tab=="COMPANIONS" then return self:CreateCardGallery("COMPANIONS",COMPANION_CARDS,"Companions","Available companion cards with your active companion highlighted.") end
    if INTERACTIVE[tab] then return self:CreateInteractive(tab) end
    if tab=="PURSUITS" then return self:CreatePursuits() end
    if tab=="NOTES" then return self:CreateNotes() end
    if tab=="PINS" then return self:CreatePins() end
    if tab=="CODEX" then return self:CreateCodex() end
    if tab=="DICE" then return self:CreateDice() end
    if tab=="SETTINGS" then return self:CreateSettings() end
    return self:CreateTextPage(tab)
end

local function EAS_RefreshCurrentCore(self)
    if not self.window or self.window:IsHidden() then return end
    local tab=self.activeTab or "INDEX"; local p=self:EnsurePage(tab)
    if tab=="INDEX" then self:RefreshHome(p)
    elseif tab=="CHARACTER" or tab=="COMPANIONS" then self:RefreshGallery(tab,p)
    elseif INTERACTIVE[tab] then self:RefreshInteractive(tab,p)
    elseif tab=="PURSUITS" then self:RefreshPursuits(p)
    elseif tab=="NOTES" then self:RefreshNotes()
    elseif tab=="PINS" then self:RefreshPins()
    elseif tab=="CODEX" then self:RefreshCodex()
    elseif tab=="DICE" then self:RefreshDice()
    elseif tab=="SETTINGS" then -- static page; settings logic lives in LAM
    else self:RefreshTextPage(tab,p) end
    self:UpdateTopNavigation()
end

local SetTabImplArch

function M:SetTab(...)
    return SetTabImplArch(self, ...)
end

SetTabImplArch = function(self, tab)
    tab=tostring(tab or "INDEX"); if not TAB_LABELS[tab] then tab="INDEX" end
    local previousTab=self.activeTab
    if tab~="TRAVEL" and J.HideGuildLeaderHomeDropdown then J:HideGuildLeaderHomeDropdown() end
    if self.activeTab=="NOTES" and self.pages.NOTES then J:SaveCurrentEntry() end
    for _,p in pairs(self.pages) do p:SetHidden(true) end
    self.activeTab=tab; J.activeTab=tab; local sv=J:EnsureSaved(); sv.activeTab=tab; if EPC.saved then EPC.saved.activeTab=tab end

    -- v0.29.63: treat Group Finder searching as a page lifecycle action, not a
    -- render action. This prevents every RefreshCurrent() call from restarting
    -- the search before returned groups can be displayed.
    if EPC.DungeonFinder then
        if previousTab=="GROUPFINDER" and tab~="GROUPFINDER" then
            EPC.DungeonFinder:SetViewMode("DUNGEONS")
        elseif tab=="GROUPFINDER" and previousTab~="GROUPFINDER" then
            EPC.DungeonFinder:SetViewMode("LIVE")
        end
    end

    local p=self:EnsurePage(tab); p:SetHidden(false)
    if EPC.GearLoadoutOverlay and EPC.GearLoadoutOverlay.OnGearTabChanged then EPC.GearLoadoutOverlay:OnGearTabChanged(tab=="GEAR") end
    if EPC.RefreshNow and (tab=="BUILD" or tab=="SKILLS" or tab=="COMBAT" or tab=="QUESTS" or tab=="TRAVEL" or tab=="ACTIVITY" or tab=="GEAR") then pcall(EPC.RefreshNow,EPC,"modern-tab") end
    self:RefreshCurrent()
end

function M:PushSettingsHotkeyLayer02943()
    if type(PushActionLayerByName) ~= "function" then return false end
    if type(RemoveActionLayerByName) == "function" then
        pcall(RemoveActionLayerByName, "ESOAdventurerSuiteSettingsLayer")
    end
    local ok = pcall(PushActionLayerByName, "ESOAdventurerSuiteSettingsLayer")
    self.settingsHotkeyLayer02943 = ok == true
    return self.settingsHotkeyLayer02943
end

function M:ActivateSettingsHotkeyBridge02943()
    self.fullSettingsBridge02943 = true
    self:PushSettingsHotkeyLayer02943()
end

function M:RefreshSettingsHotkeyBridge02943()
    if type(zo_callLater) ~= "function" then return end
    zo_callLater(function()
        if self.fullSettingsBridge02943 then self:PushSettingsHotkeyLayer02943() end
    end, 100)
    zo_callLater(function()
        if self.fullSettingsBridge02943 then self:PushSettingsHotkeyLayer02943() end
    end, 350)
end

function M:DeactivateSettingsHotkeyBridge02943()
    self.fullSettingsBridge02943 = false
    if type(RemoveActionLayerByName) == "function" then
        pcall(RemoveActionLayerByName, "ESOAdventurerSuiteSettingsLayer")
    end
    self.settingsHotkeyLayer02943 = false
end

local function easSettingsSceneShowing02943()
    if not SCENE_MANAGER or type(SCENE_MANAGER.IsShowing) ~= "function" then return false end
    local names = { "gameMenuInGame", "settings", "gameMenu" }
    for i = 1, #names do
        local ok, showing = pcall(SCENE_MANAGER.IsShowing, SCENE_MANAGER, names[i])
        if ok and showing == true then return true end
    end
    return false
end

function M:CloseSettingsSceneForSuite02943()
    local showing = easSettingsSceneShowing02943()
    self:DeactivateSettingsHotkeyBridge02943()
    if not showing or not SCENE_MANAGER then return false end

    if type(SCENE_MANAGER.HideCurrentScene) == "function" then
        local ok = pcall(SCENE_MANAGER.HideCurrentScene, SCENE_MANAGER)
        if ok then return true end
    end
    if type(SCENE_MANAGER.Hide) == "function" then
        pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, "settings")
        pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, "gameMenuInGame")
        pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, "gameMenu")
        return true
    end
    return false
end

-- v0.29.363: Settings.lua historically targeted EPC.UI.root, which is the
-- retired legacy shell. Keep modern window appearance in one live method so
-- Window Scale/Opacity affect the UI the player actually sees.
local function EAS_ApplyWindowAppearanceCore029363(self)
    if not self.window then return end
    local alpha = tonumber(EPC.saved and EPC.saved.alpha) or 0.96
    local scale = tonumber(EPC.saved and EPC.saved.scale) or 1.0
    alpha = math.max(0.35, math.min(1.0, alpha))
    scale = math.max(0.70, math.min(1.40, scale))
    self.window:SetAlpha(alpha)
    self.window:SetScale(scale)
end

function M:ApplyCodexTextSize029363()
    local p = self.pages and self.pages.CODEX
    if not p or not p.text then return end
    local size = tonumber(EPC.saved and EPC.saved.codexModernFontSize029363) or 18
    size = math.max(14, math.min(28, math.floor(size + 0.5)))
    p.text:SetFont(string.format("$(MEDIUM_FONT)|%d|soft-shadow-thick", size))
    self:RefreshCodex()
end

local function EAS_ShowCore(self)
    if not self.window then self:CreateShell() end
    if self.fullSettingsBridge02943 or self.settingsHotkeyLayer02943 then
        self:DeactivateSettingsHotkeyBridge02943()
    end
    if EPC.LoadoutManager and EPC.LoadoutManager.window and not EPC.LoadoutManager.window:IsHidden() and EPC.LoadoutManager.Hide then EPC.LoadoutManager:Hide(true) end
    local already=safe(IsGameCameraUIModeActive,false)==true; J.ownsUIMode=not already
    if not already then if type(SetGameCameraUIMode)=="function" then pcall(SetGameCameraUIMode,true) elseif SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then pcall(SCENE_MANAGER.SetInUIMode,SCENE_MANAGER,true) end end
    self.window:SetHidden(false)
    self:ApplyWindowAppearance029363()
    if self.shell then
        self.shell:SetHidden(false)
        setPanelVisual(self.shell, BG, {0,0,0,0})
    end
    if self.glassBackdrop02899 then
        self.glassBackdrop02899:SetHidden(false)
        self.glassBackdrop02899:SetCenterColor(GLASS_BG[1],GLASS_BG[2],GLASS_BG[3],GLASS_BG[4])
    end
    if J.ActivateCodexActionLayer then pcall(J.ActivateCodexActionLayer,J) end
    if EPC.GearLoadoutOverlay and EPC.GearLoadoutOverlay.SetJournalVisible then EPC.GearLoadoutOverlay:SetJournalVisible(true) end
    self:SetTab(self.activeTab or J:EnsureSaved().activeTab or "INDEX")
end

local function EAS_HideCore(self)
    if not self.window then return end
    if J.HideGuildLeaderHomeDropdown then J:HideGuildLeaderHomeDropdown() end
    if self.activeTab=="NOTES" then J:SaveCurrentEntry() end
    if self.activeTab=="GROUPFINDER" and EPC.DungeonFinder then EPC.DungeonFinder:SetViewMode("DUNGEONS") end
    self.window:SetHidden(true)
    if J.codexActionLayerPushed and type(RemoveActionLayerByName)=="function" then pcall(RemoveActionLayerByName,"ESOAdventurerSuiteCodexLayer"); J.codexActionLayerPushed=false end
    if EPC.GearLoadoutOverlay and EPC.GearLoadoutOverlay.SetJournalVisible then EPC.GearLoadoutOverlay:SetJournalVisible(false) end
    if J.ownsUIMode then if type(SetGameCameraUIMode)=="function" then pcall(SetGameCameraUIMode,false) elseif SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then pcall(SCENE_MANAGER.SetInUIMode,SCENE_MANAGER,false) end end
    J.ownsUIMode=false
end

function M:Toggle()
    if not self.window then self:CreateShell() end
    if self.window:IsHidden() then
        if self.fullSettingsBridge02943 then
            local closedSettings = self:CloseSettingsSceneForSuite02943()
            if closedSettings and type(zo_callLater) == "function" then
                zo_callLater(function() self:Show() end, 50)
            else
                self:Show()
            end
            return
        end
        self:Show()
    else
        self:Hide()
    end
end

-- Replace Journal.lua's old visible shell at the module boundary. Journal.lua remains
-- the data/action provider, but its Create() function is deliberately never called.
local legacyRefreshMapPins = J.RefreshMapPins
function J:Initialize()
    self:EnsureSaved()
    M:CreateShell()
    self.window=M.window
    self.pages=M.pages
    self.activeTab=self:EnsureSaved().activeTab or "INDEX"
    M.activeTab=self.activeTab
    EVENT_MANAGER:RegisterForEvent(EPC.name.."_JournalMap",EVENT_PLAYER_ACTIVATED,function() if legacyRefreshMapPins then pcall(legacyRefreshMapPins,self) end; if M.window and not M.window:IsHidden() then M:RefreshCurrent() end end)
end

function J:SetTab(tab) M:SetTab(tab) end
function J:Show() M:Show() end
function J:Hide() M:Hide() end
function J:Toggle() M:Toggle() end
function J:RefreshSuitePage(tab) if tab and tab~=M.activeTab then return end; M:RefreshCurrent() end
function J:RefreshDocumentPage() M:RefreshCurrent() end
function J:ApplyTheme() if M.window and not M.window:IsHidden() then M:UpdateTopNavigation() end end
function J:RefreshNotes() M:RefreshNotes() end
function J:RefreshPinsPage() M:RefreshPins() end
function J:RefreshDice() M:RefreshDice() end


-- Golden Pursuit backend helpers sometimes request the old page refresh after an
-- async routing step. Redirect that refresh to the modern card page instead.
function J:RefreshGoldenPursuitsPage2494()
    if M.pages and M.pages.PURSUITS then M:RefreshPursuits(M.pages.PURSUITS) end
end

if type(SLASH_COMMANDS)=="table" then
    SLASH_COMMANDS["/easui"] = function()
        local msg="UI: Modern Application active."
        if EPC and EPC.Print then EPC:Print(msg) elseif type(d)=="function" then d("[ESO Adventurer Suite] "..msg) end
    end
end

-- ============================================================================
-- v0.29.376 - safe modern-window scaling across tab changes.
-- Reflow the logical viewport after changing top-level scale and never compound
-- the scale onto page controls. All pages stay anchored to the same unscaled
-- body, so changing CODEX/other tabs cannot inherit stale scaled anchors.
-- ============================================================================
local function EAS_ApplyWindowAppearanceScale029376(self)
    EAS_ApplyWindowAppearanceCore029363(self)
    if self.window and self.window.SetClampedToScreen then self.window:SetClampedToScreen(true) end
    if self.Reflow then self:Reflow() end
end


-- ============================================================================
-- v0.29.381 - Codex scale/tab geometry hardening.
-- Page controls always remain at logical scale 1. The saved Window Scale is
-- applied only to the top-level window after each tab has been laid out.
-- ============================================================================
local EAS_ModernSetTabBase029381 = SetTabImplArch
SetTabImplArch = function(self, tab)
    if self.window then self.window:SetScale(1) end
    if self.body then self.body:SetScale(1) end
    for _, page in pairs(self.pages or {}) do
        if page and page.SetScale then page:SetScale(1) end
    end
    local result = EAS_ModernSetTabBase029381(self, tab)
    if self.Reflow then self:Reflow() end
    for _, page in pairs(self.pages or {}) do
        if page and page.SetScale then page:SetScale(1) end
    end
    local scale = tonumber(EPC.saved and EPC.saved.scale) or 1.0
    scale = math.max(0.70, math.min(1.40, scale))
    if self.window then self.window:SetScale(scale) end
    return result
end


-- ============================================================================
-- v0.29.384 - stable Codex scaling while switching tabs.
-- Keep the user-selected scale on the top-level window continuously.  Previous
-- code briefly forced the window to scale 1 during SetTab/Reflow, which could
-- make child anchors/layout calculations jump and accumulate bad geometry.
-- ============================================================================
local EAS_ModernSetTabLogicalBase029384 = EAS_ModernSetTabBase029381 or M.SetTab
SetTabImplArch = function(self, tab)
    local scale = tonumber(EPC.saved and EPC.saved.scale) or 1.0
    scale = math.max(0.70, math.min(1.40, scale))
    if self.window and self.window.SetScale then self.window:SetScale(scale) end
    if self.body and self.body.SetScale then self.body:SetScale(1) end
    for _, page in pairs(self.pages or {}) do
        if page and page.SetScale then page:SetScale(1) end
    end
    local result = EAS_ModernSetTabLogicalBase029384(self, tab)
    if self.body and self.body.SetScale then self.body:SetScale(1) end
    for _, page in pairs(self.pages or {}) do
        if page and page.SetScale then page:SetScale(1) end
    end
    if self.Reflow then self:Reflow() end
    if self.window and self.window.SetScale then self.window:SetScale(scale) end
    return result
end


-- BEGIN ABSORBED: ModernAppUIRoundedFix.lua
-- ESO Adventurer Suite
-- Modern UI rounded shell + rounded controls visibility fix.
-- Keeps the shell/window hit area intact for dragging and resizing while
-- suppressing rectangular native backdrop art behind rounded DDS surfaces.

local EPC = ESOProgressionCoach
if not EPC or not EPC.ModernAppUI then return end

local M = EPC.ModernAppUI
local FALLBACK_NAME = "EAS_ModernShell02890_NativeFallback029116"

local function HideSquareShellFallback029476()
    local fallback = nil

    if M.shell and M.shell.nativeFallback029116 then
        fallback = M.shell.nativeFallback029116
    end

    if not fallback and _G then
        fallback = _G[FALLBACK_NAME]
    end

    if fallback then
        if fallback.SetHidden then fallback:SetHidden(true) end
        if fallback.SetAlpha then fallback:SetAlpha(0) end
        if fallback.SetCenterColor then fallback:SetCenterColor(0, 0, 0, 0) end
        if fallback.SetEdgeColor then fallback:SetEdgeColor(0, 0, 0, 0) end
        return true
    end

    return false
end

local function ClearRoundedBackdrop029478(bg)
    if not bg or not bg.roundTex02890 then return end

    -- Mark this surface like the shell so ModernAppUI's normal painter does not
    -- restore a rectangular native center behind the rounded DDS.
    bg._shellSurface02890 = true
    if bg.SetCenterColor then bg:SetCenterColor(0, 0, 0, 0) end
    if bg.SetEdgeColor then bg:SetEdgeColor(0, 0, 0, 0) end
end

local function MakeButtonRoundedOnly029478(button)
    if not button or not button.bg then return end
    ClearRoundedBackdrop029478(button.bg)

    if button._roundedHandlers029478 then return end
    button._roundedHandlers029478 = true

    -- The normal hover/exit handlers still choose the correct selected, hover,
    -- alliance-accent and disabled colors on the rounded texture. Clear only the
    -- rectangular CT_BACKDROP after those handlers run.
    if button.GetHandler and button.SetHandler then
        local oldEnter = button:GetHandler("OnMouseEnter")
        local oldExit = button:GetHandler("OnMouseExit")

        button:SetHandler("OnMouseEnter", function(control, ...)
            if oldEnter then oldEnter(control, ...) end
            if control then ClearRoundedBackdrop029478(control.bg) end
        end)

        button:SetHandler("OnMouseExit", function(control, ...)
            if oldExit then oldExit(control, ...) end
            if control then ClearRoundedBackdrop029478(control.bg) end
        end)
    end
end

local function WalkRoundedButtons029478(control)
    if not control then return end

    -- Every ModernAppUI button() creates a child background named *_BG and
    -- attaches it back to the CT_BUTTON as button.bg. This catches top tabs,
    -- side/rail tabs, page-mode tabs, PREV/NEXT controls and all action buttons
    -- without changing flat content cards or edit-box hosts.
    if control.bg and control.bg.roundTex02890 then
        MakeButtonRoundedOnly029478(control)
    end

    if control.GetNumChildren and control.GetChild then
        local okCount, count = pcall(control.GetNumChildren, control)
        count = okCount and tonumber(count) or 0
        for i = 1, count do
            local okChild, child = pcall(control.GetChild, control, i)
            if okChild and child then WalkRoundedButtons029478(child) end
        end
    end
end

local function ForceRoundedModernControls029478()
    for _, button in pairs(M.groupButtons or {}) do
        MakeButtonRoundedOnly029478(button)
    end
    if M.window then WalkRoundedButtons029478(M.window) end
end

local function EAS_CreateShellRounded029476(self, ...)
    local result = EAS_CreateShellCore(self, ...)
    HideSquareShellFallback029476()
    ForceRoundedModernControls029478()
    return result
end
M._roundedShellFix029476 = true

HideSquareShellFallback029476()
ForceRoundedModernControls029478()

function M:ApplyWindowAppearance029363(...)
    local result = EAS_ApplyWindowAppearanceScale029376(self, ...)
    HideSquareShellFallback029476()
    ForceRoundedModernControls029478()
    return result
end
M._roundedAppearanceFix029476 = true

function M:UpdateTopNavigation(...)
    local result = EAS_UpdateTopNavigationCore(self, ...)
    ForceRoundedModernControls029478()
    return result
end
M._roundedTopTabsFix029477 = true

-- SetTab is important because many inner page buttons/tabs are created lazily
-- or repainted when switching pages. Re-sweep after the page is active.
if type(M.SetTab) == "function" and not M._roundedInnerControlsFix029478 then
    local SetTabBase029478 = SetTabImplArch
    SetTabImplArch = function(self, ...)
        local result = SetTabBase029478(self, ...)
        ForceRoundedModernControls029478()
        return result
    end
    M._roundedInnerControlsFix029478 = true
end

local function EAS_RefreshCurrentRounded029478(self, ...)
    local result = EAS_RefreshCurrentCore(self, ...)
    ForceRoundedModernControls029478()
    return result
end
M._roundedRefreshFix029478 = true

local function EAS_ShowRounded029476(self, ...)
    local result = EAS_ShowCore(self, ...)
    HideSquareShellFallback029476()
    ForceRoundedModernControls029478()
    return result
end
M._roundedShowFix029476 = true

-- END ABSORBED: ModernAppUIRoundedFix.lua


-- BEGIN ABSORBED: ModernAppUIGalleryImageFix.lua
-- ESO Adventurer Suite
-- v0.29.548 - Modern UI Character/Companion gallery image visibility repair.
-- Rebind packaged DDS portraits with an explicit addon-root path after gallery
-- creation/refresh so class and companion artwork cannot remain transparent.

local EPC = ESOProgressionCoach
if not EPC or not EPC.ModernAppUI then return end
local M = EPC.ModernAppUI

local function normalizePath029548(path)
    path = tostring(path or "")
    if path == "" then return "" end
    path = path:gsub("\\", "/")
    if string.sub(path, 1, 1) ~= "/" then path = "/" .. path end
    return path
end

local function forceArt029548(page)
    if type(page) ~= "table" then return end
    for _, entry in ipairs(page.cardEntries or {}) do
        local art = entry.art
        if art then
            local path = normalizePath029548(entry.path)
            if path ~= "" then
                if type(PreloadTexture) == "function" then pcall(PreloadTexture, path) end
                if type(art.SetTexture) == "function" then pcall(art.SetTexture, art, path) end
            end
            if type(art.SetHidden) == "function" then pcall(art.SetHidden, art, false) end
            if type(art.SetAlpha) == "function" then pcall(art.SetAlpha, art, 1) end
            if type(art.SetColor) == "function" then pcall(art.SetColor, art, 1, 1, 1, 1) end
            if type(art.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") ~= nil then
                pcall(art.SetDrawTier, art, DT_HIGH)
            end
            if type(art.SetDrawLayer) == "function" and rawget(_G, "DL_CONTROLS") ~= nil then
                pcall(art.SetDrawLayer, art, DL_CONTROLS)
            end
            if type(art.SetDrawLevel) == "function" then pcall(art.SetDrawLevel, art, 24) end
        end

        -- Some older gallery builds created a fallback texture above the portrait.
        -- Once the packaged portrait is rebound, keep that fallback from covering it.
        local fallback = entry.fallback
        if fallback and fallback ~= art then
            if type(fallback.SetHidden) == "function" then pcall(fallback.SetHidden, fallback, true) end
            if type(fallback.SetAlpha) == "function" then pcall(fallback.SetAlpha, fallback, 0) end
        end
    end
end

function M:CreateCardGallery(tab, cards, titleText, subText)
    local page = EAS_CreateCardGalleryCore(self, tab, cards, titleText, subText)
    if tab == "CHARACTER" or tab == "COMPANIONS" then forceArt029548(page) end
    return page
end
M._galleryImageCreateFix029548 = true

function M:RefreshGallery(tab, page, ...)
    local result = EAS_RefreshGalleryCore(self, tab, page, ...)
    if tab == "CHARACTER" or tab == "COMPANIONS" then forceArt029548(page) end
    return result
end
M._galleryImageRefreshFix029548 = true

-- Repair already-created pages immediately when this patch loads.
if type(M.pages) == "table" then
    forceArt029548(M.pages.CHARACTER)
    forceArt029548(M.pages.COMPANIONS)
end

-- END ABSORBED: ModernAppUIGalleryImageFix.lua


-- BEGIN ABSORBED: ModernAppUIForegroundFix.lua
-- ESO Adventurer Suite
-- v0.29.551 - Modern UI foreground ownership.
-- The Modern application is a menu-level surface, so persistent gameplay HUD
-- overlays must never draw over it. Keep the app at the highest Suite draw
-- level and suppress gameplay overlays only while the app is open.

local EPC = ESOProgressionCoach
if not EPC or not EPC.ModernAppUI then return end

local M = EPC.ModernAppUI

local function ForceModernForeground029551()
    local window = M.window
    if not window then return end

    if type(window.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") ~= nil then
        pcall(window.SetDrawTier, window, DT_HIGH)
    end
    if type(window.SetDrawLayer) == "function" and rawget(_G, "DL_OVERLAY") ~= nil then
        pcall(window.SetDrawLayer, window, DL_OVERLAY)
    end
    if type(window.SetDrawLevel) == "function" then
        pcall(window.SetDrawLevel, window, 100000)
    end
end

-- Treat the Suite application like a real menu for persistent HUD visibility.
-- This keeps player/target/group frames, minimap, combat cards, timers, quest
-- trackers and similar HUD readouts behind/hidden while Modern UI is open.
if type(EPC.IsGameplayHudSuppressed) == "function" and not EPC._modernAppHudSuppression029551 then
    local baseSuppressed = EPC.IsGameplayHudSuppressed
    function EPC:IsGameplayHudSuppressed(...)
        if self.modernAppUiOpen029551 == true then return true end
        return baseSuppressed(self, ...)
    end
    EPC._modernAppHudSuppression029551 = true
end

function M:CreateShell(...)
    local result = EAS_CreateShellRounded029476(self, ...)
    ForceModernForeground029551()
    return result
end
M._foregroundCreate029551 = true

function M:Show(...)
    EPC.modernAppUiOpen029551 = true
    local result = EAS_ShowRounded029476(self, ...)
    ForceModernForeground029551()
    if type(EPC.RefreshGameplayOverlays) == "function" then pcall(EPC.RefreshGameplayOverlays, EPC) end
    return result
end
M._foregroundShow029551 = true

function M:Hide(...)
    local result = EAS_HideCore(self, ...)
    EPC.modernAppUiOpen029551 = false
    if type(EPC.RefreshGameplayOverlays) == "function" then pcall(EPC.RefreshGameplayOverlays, EPC) end
    return result
end
M._foregroundHide029551 = true

-- SetTab/RefreshCurrent can repaint or lazily create content. Reassert the
-- top-level foreground level after those operations without changing child
-- ordering inside the Modern UI itself.
if type(M.SetTab) == "function" and not M._foregroundTab029551 then
    local baseSetTab = SetTabImplArch
    SetTabImplArch = function(self, ...)
        local result = baseSetTab(self, ...)
        ForceModernForeground029551()
        return result
    end
    M._foregroundTab029551 = true
end

function M:RefreshCurrent(...)
    local result = EAS_RefreshCurrentRounded029478(self, ...)
    ForceModernForeground029551()
    return result
end
M._foregroundRefresh029551 = true

ForceModernForeground029551()

-- END ABSORBED: ModernAppUIForegroundFix.lua
