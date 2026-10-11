-- kozy-eso BuildPort, (c) 2026 Kozy, all rights reserved (see LICENSE). Built with AI assistance (Claude).
-- kozy-eso BuildPort: reads the character and opens kozy-eso.com/build-editor/import#<payload>.
-- Payload format is documented in src/lib/addon-import.ts. Everything is wrapped in pcall so one
-- API mismatch only drops that field and is reported by "/export debug".
local ADDON = "KozyEsoBuildPort"
local VERSION = "0.10.2"
-- Single global namespace (Passives.lua creates it first); SavedVariables is the only other global.
KozyEsoBuildPort = KozyEsoBuildPort or {}
local KEBP = KozyEsoBuildPort
local URL = "https://kozy-eso.com/build-editor/import#"

local EQUIP = {
  { EQUIP_SLOT_HEAD, "head" }, { EQUIP_SLOT_CHEST, "chest" }, { EQUIP_SLOT_SHOULDERS, "shoulders" },
  { EQUIP_SLOT_HAND, "hands" }, { EQUIP_SLOT_WAIST, "waist" }, { EQUIP_SLOT_LEGS, "legs" },
  { EQUIP_SLOT_FEET, "feet" }, { EQUIP_SLOT_NECK, "necklace" },
  { EQUIP_SLOT_RING1, "ring1" }, { EQUIP_SLOT_RING2, "ring2" },
  { EQUIP_SLOT_MAIN_HAND, "b1m" }, { EQUIP_SLOT_OFF_HAND, "b1o" },
  { EQUIP_SLOT_BACKUP_MAIN, "b2m" }, { EQUIP_SLOT_BACKUP_OFF, "b2o" },
}

local errors = {}

local function try(label, fn, ...)
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
  errors[#errors + 1] = label .. ": " .. tostring(a)
  return nil
end

-- Strip ESO grammar markers ("Name^F"), colour codes and apostrophes; every other run of
-- non-alphanumerics becomes "-". Output is URL-safe as is and the site normalises names the same way.
local function clean(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
  s = try("strformat", zo_strformat, "<<1>>", s) or s
  s = s:gsub("\226\128\153", ""):gsub("'", "")
  s = s:gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
  return s
end

-- Same rules as the site: only armor/jewelry/shield glyphs change the stat sheet, so we send a
-- short code (see ENCHANT_CODE in src/lib/addon-import.ts) instead of the description.
local JEWELRY = { necklace = true, ring1 = true, ring2 = true }
local function enchantCode(desc, key, weaponType)
  desc = tostring(desc or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
  local function has(w) return desc:find(w, 1, true) ~= nil end
  if JEWELRY[key] then
    if has("Weapon and Spell Damage") then return has("Stamina Recovery") and "ip" or "im" end
    if has("Physical Resistance") then return "dp" end
    if has("Spell Resistance") then return "ds" end
    local m, st, h = has("Magicka Recovery"), has("Stamina Recovery"), has("Health Recovery")
    if m and st and h then return "rp" end
    if m and not st and not h then return "rm" end
    if st and not m and not h then return "rs" end
    if h and not m and not st then return "rh" end
    return ""
  end
  if key:sub(1, 1) == "b" and weaponType ~= WEAPONTYPE_SHIELD then
    -- Weapon glyphs: matched on the damage / effect words of the description (English client).
    local low = desc:lower()
    local function lhas(w) return low:find(w, 1, true) ~= nil end
    if lhas("reduce") and lhas("resistance") then return "wcr" end
    if lhas("reduce") and lhas("damage") then return "wwk" end
    if lhas("increase") and (lhas("weapon and spell damage") or lhas("weapon damage and spell damage")) then return "wwd" end
    if lhas("damage shield") then return "wha" end
    if lhas("fire damage") or lhas("flame damage") then return "wfl" end
    if lhas("frost damage") then return "wfr" end
    if lhas("shock damage") then return "wsh" end
    if lhas("poison damage") then return "wpo" end
    if lhas("disease damage") then return "wfo" end
    if lhas("oblivion damage") then return "wob" end
    if lhas("magic damage") then
      if lhas("health") and lhas("magicka") then return "wpr" end
      if lhas("health") then return "whe" end
      if lhas("magicka") then return "wma" end
    end
    if lhas("physical damage") and lhas("stamina") then return "wst" end
    return ""
  end
  local m, st, h = has("Magicka"), has("Stamina"), has("Health")
  if m and st and h then return "p" end
  if m and not st and not h then return "m" end
  if st and not m and not h then return "s" end
  if h and not m and not st then return "h" end
  return ""
end

local function gearLine(slot, key)
  local link = GetItemLink(BAG_WORN, slot)
  if not link or link == "" then return nil end
  local _, setName = GetItemLinkSetInfo(link)
  local traitType = GetItemLinkTraitType(link)
  local trait = ""
  if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then trait = GetString("SI_ITEMTRAITTYPE", traitType) end
  local _, _, enchantDesc = GetItemLinkEnchantInfo(link)
  local weaponType = GetItemLinkWeaponType(link) or 0
  local code = enchantCode(enchantDesc, key, weaponType)
  local quality = GetItemLinkDisplayQuality and GetItemLinkDisplayQuality(link) or GetItemLinkQuality(link)
  return table.concat({
    "G", key, clean(setName), clean(trait), code, tostring(quality or 0),
    tostring(GetItemLinkArmorType(link) or 0), tostring(weaponType),
  }, "_")
end

-- Scribed skills: the bar gets "$<n>" and an S_ line lists grimoire + its 3 active scripts.
local scribed, scribedIdx = {}, {}
local function scribeRef(crafted)
  if not crafted or crafted == 0 then return nil end
  if scribedIdx[crafted] == nil then
    if #scribed >= 3 then return nil end
    local parts = { clean(GetCraftedAbilityDisplayName(crafted)) }
    local ids = { GetCraftedAbilityActiveScriptIds(crafted) }
    for i = 1, 3 do
      local id = ids[i]
      parts[#parts + 1] = (id and id > 0) and clean(GetCraftedAbilityScriptDisplayName(id)) or ""
    end
    scribed[#scribed + 1] = table.concat(parts, ".")
    scribedIdx[crafted] = #scribed - 1
  end
  return "$" .. scribedIdx[crafted]
end

-- A scribed skill on the bar is its own action type: the "bound id" is then the crafted ability id,
-- not an ability id (GetAbilityName returns nothing for it).
local rawSlots = {}
local function slotValue(slot, hotbar)
  local id = try("GetSlotBoundId", GetSlotBoundId, slot, hotbar)
  if not id or id <= 0 then return "" end
  local slotType = GetSlotType and try("GetSlotType", GetSlotType, slot, hotbar) or nil
  local name = clean(GetAbilityName(id))
  rawSlots[#rawSlots + 1] = string.format("hotbar %s slot %d: type %s id %d name '%s'", tostring(hotbar), slot, tostring(slotType), id, name)
  local crafted = nil
  if ACTION_TYPE_CRAFTED_ABILITY and slotType == ACTION_TYPE_CRAFTED_ABILITY then
    crafted = id
  elseif name == "" then
    crafted = id -- fallback: unnamed "ability" is most likely a crafted ability id
  else
    crafted = try("GetAbilityCraftedAbilityId", GetAbilityCraftedAbilityId, id)
  end
  local ref = try("scribing", scribeRef, crafted)
  return ref or name
end

local function barLine(bar, hotbar)
  local f = { "B", tostring(bar) }
  for slot = 3, 8 do -- 3..7 skills, 8 ultimate
    f[#f + 1] = slotValue(slot, hotbar)
  end
  return table.concat(f, "_")
end

-- Names (cleaned, lowercase) of the purchased passive abilities of the character.
local function ownedAbilities()
  local owned = {}
  for st = 1, GetNumSkillTypes() do
    for sl = 1, GetNumSkillLines(st) do
      for ab = 1, GetNumSkillAbilities(st, sl) do
        local name, _, _, passive, _, purchased = GetSkillAbilityInfo(st, sl, ab)
        if passive and purchased then owned[clean(name):lower()] = true end
      end
    end
  end
  return owned
end

-- Bitmask over KEBP.PASSIVES (Passives.lua, same order as passiveOrder() on the site).
local function passiveMask(owned)
  local list, hex = KEBP.PASSIVES or {}, {}
  for n = 1, #list, 4 do
    local v = 0
    for b = 0, 3 do v = v * 2 + ((list[n + b] and owned[list[n + b]]) and 1 or 0) end
    hex[#hex + 1] = string.format("%x", v)
  end
  return #list .. "_" .. table.concat(hex)
end

-- Class masteries (U51): assumed to show up as purchased abilities; /export debug reports what the
-- game says per class skill line so this can be corrected if they live elsewhere.
local function masteryLine(owned)
  local found = {}
  for _, name in ipairs(KEBP.MASTERIES or {}) do
    if owned[name] then found[#found + 1] = name end
  end
  for sl = 1, (GetNumSkillLines(SKILL_TYPE_CLASS) or 0) do
    local lineId = try("GetSkillLineId", GetSkillLineId, SKILL_TYPE_CLASS, sl)
    if lineId then
      local pts = try("masteryPoints", GetNumClassMasteryPointsBySkillLineId, lineId)
      local isMastery = try("IsClassMasterySkillLine", IsClassMasterySkillLine, lineId)
      rawSlots[#rawSlots + 1] = string.format("class line %d: id %s mastery-line %s points %s", sl, tostring(lineId), tostring(isMastery), tostring(pts))
    end
  end
  return "Q_" .. table.concat(found, ".")
end

-- Mundus: the game tells us the buff indices (GetUnitActiveMundusStoneBuffIndices); fallback is a buff
-- named "Boon...". Other long buffs (>= 15 min total or >= 10 min left) are food/drink candidates.
local function buffLines()
  local isMundus = {}
  local ok, i1, i2 = pcall(GetUnitActiveMundusStoneBuffIndices, "player")
  if ok then
    if type(i1) == "number" then isMundus[i1] = true end
    if type(i2) == "number" then isMundus[i2] = true end
  end
  local mundus, foods = nil, {}
  for i = 1, GetNumBuffs("player") do
    local name, started, ending = GetUnitBuffInfo("player", i)
    local c = clean(name)
    local remaining = (ending or 0) - GetFrameTimeSeconds()
    rawSlots[#rawSlots + 1] = string.format("buff %d: '%s' started %.0f ending %.0f remaining %.0f", i, c, started or 0, ending or 0, remaining)
    if isMundus[i] or c:lower():find("^boon") then
      mundus = mundus or c
    elseif ending and ending > 0 and #foods < 4 and ((ending - (started or ending)) >= 900 or remaining >= 600) then
      foods[#foods + 1] = c
    end
  end
  return "M_" .. (mundus or ""), "F_" .. table.concat(foods, ".")
end

-- Slotted champion stars (the site finds the tree from the star name).
local function championLine()
  local names = {}
  for slot = 1, 12 do
    local id = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION)
    if id and id > 0 then names[#names + 1] = clean(GetChampionSkillName(id)) end
  end
  return "K_" .. table.concat(names, ".")
end

-- The character's class skill lines (U51 subclasses). The game lists every class line (all classes,
-- "Vengeance-" variants, "Class-Mastery"), so only lines with at least one purchased ability count.
local function classLinesLine()
  local names = {}
  for sl = 1, (GetNumSkillLines(SKILL_TYPE_CLASS) or 0) do
    local name = clean(GetSkillLineInfo(SKILL_TYPE_CLASS, sl))
    local purchased = 0
    for ab = 1, GetNumSkillAbilities(SKILL_TYPE_CLASS, sl) do
      local _, _, _, _, _, isPurchased = GetSkillAbilityInfo(SKILL_TYPE_CLASS, sl, ab)
      if isPurchased then purchased = purchased + 1 end
    end
    rawSlots[#rawSlots + 1] = string.format("class skill line %d: %s (purchased %d)", sl, name, purchased)
    if purchased > 0 and not name:find("^Vengeance") and not name:find("^Class%-Mastery") then
      names[#names + 1] = name
    end
  end
  return "L_" .. table.concat(names, ".")
end

-- /export dump: writes the game's own scribing catalogue and skill lines to SavedVariables
-- (after /reloadui, file SavedVariables/KozyEsoBuildPort.lua) so the site can use real names and ids.
local function dumpCatalog()
  local out = { api = GetAPIVersion(), crafted = {}, lines = {}, errors = {} }
  local function t(label, fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then return a end
    out.errors[#out.errors + 1] = label .. ": " .. tostring(a)
  end
  for i = 0, 60 do
    local id = t("GetCraftedAbilityIdAtIndex", GetCraftedAbilityIdAtIndex, i)
    if id and id > 0 then
      local entry = {
        id = id,
        name = t("name", GetCraftedAbilityDisplayName, id),
        description = t("description", GetCraftedAbilityDescription, id),
        slots = {},
      }
      -- Where the grimoire lives (skill type, line, ability index) and the name of that line.
      local skillType, lineIndex, abilityIndex = t("GetSkillAbilityIndicesFromCraftedAbilityId", GetSkillAbilityIndicesFromCraftedAbilityId, id)
      entry.skillType, entry.lineIndex, entry.abilityIndex = skillType, lineIndex, abilityIndex
      if skillType and lineIndex then entry.lineName = t("line name", GetSkillLineInfo, skillType, lineIndex) end
      for slot = 1, 3 do
        local list = {}
        local n = t("GetNumScriptsInSlotForCraftedAbility", GetNumScriptsInSlotForCraftedAbility, id, slot) or 0
        for k = 1, n do
          local sid = t("GetScriptIdAtSlotIndexForCraftedAbility", GetScriptIdAtSlotIndexForCraftedAbility, id, slot, k)
          if sid then
            list[#list + 1] = {
              id = sid,
              name = t("script name", GetCraftedAbilityScriptDisplayName, sid),
              description = t("script description", GetCraftedAbilityScriptDescription, sid),
              general = t("script general description", GetCraftedAbilityScriptGeneralDescription, sid),
              descriptionForAbility = t("script description for ability", GetCraftedAbilityScriptDescription, id, sid),
            }
          end
        end
        entry.slots[slot] = list
      end
      out.crafted[#out.crafted + 1] = entry
    end
  end
  for st = 1, GetNumSkillTypes() do
    for sl = 1, GetNumSkillLines(st) do
      out.lines[#out.lines + 1] = { skillType = st, index = sl, name = t("line", GetSkillLineInfo, st, sl), id = t("line id", GetSkillLineId, st, sl) }
    end
  end
  return out
end

local function build()
  errors = {}
  scribed, scribedIdx, rawSlots = {}, {}, {}
  local lines = { "KBE2" }
  lines[#lines + 1] = table.concat({ "C", clean(GetUnitClass("player")), clean(GetUnitRace("player")) }, "_")
  lines[#lines + 1] = try("class lines", classLinesLine)
  lines[#lines + 1] = table.concat({
    "T", tostring(GetAttributeSpentPoints(ATTRIBUTE_HEALTH)),
    tostring(GetAttributeSpentPoints(ATTRIBUTE_MAGICKA)), tostring(GetAttributeSpentPoints(ATTRIBUTE_STAMINA)),
  }, "_")
  local mundusLine, foodLine = try("buffs", buffLines)
  lines[#lines + 1] = mundusLine
  lines[#lines + 1] = foodLine
  lines[#lines + 1] = try("champion", championLine)
  local known = {}
  for _, e in ipairs(EQUIP) do
    known[e[1] or -1] = true
    local link = e[1] and GetItemLink(BAG_WORN, e[1]) or ""
    rawSlots[#rawSlots + 1] = string.format("equip %s: slot %s %s", e[2], tostring(e[1]), link ~= "" and "worn" or "EMPTY")
    local line = try("gear " .. e[2], gearLine, e[1], e[2])
    if line then lines[#lines + 1] = line end
  end
  -- Debug: worn items in slots we do not know about (helps find where a missing piece lives).
  for slot = 0, 25 do
    local link = GetItemLink(BAG_WORN, slot)
    if not known[slot] and link and link ~= "" then
      rawSlots[#rawSlots + 1] = "extra worn slot " .. slot .. ": " .. clean(GetItemLinkName(link))
    end
  end
  lines[#lines + 1] = try("bar1", barLine, 1, HOTBAR_CATEGORY_PRIMARY)
  lines[#lines + 1] = try("bar2", barLine, 2, HOTBAR_CATEGORY_BACKUP)
  for _, entry in ipairs(scribed) do lines[#lines + 1] = "S_" .. entry end
  local owned = try("abilities", ownedAbilities) or {}
  lines[#lines + 1] = try("masteries", masteryLine, owned)
  lines[#lines + 1] = "P_" .. (try("passives", passiveMask, owned) or "0_")
  return table.concat(lines, "~")
end

-- SavedVariables are kept per server so NA, EU and PTS do not overwrite each other.
local function sv()
  local world = GetWorldName()
  KozyEsoBuildPort_SV[world] = KozyEsoBuildPort_SV[world] or {}
  return KozyEsoBuildPort_SV[world]
end

local function say(msg) d("|c8b5cf6kozy-eso|r BuildPort " .. msg) end

-- Hidden command "/export decap": shows the payload in a window so it can be copied (Ctrl+A, Ctrl+C) and pasted
-- on the site's admin import page, which turns it into a build file. Not in the help text or the README on purpose.
local codeWindow
local function showCode(text)
  if not codeWindow then
    local wm = WINDOW_MANAGER
    local w = wm:CreateTopLevelWindow("KozyEsoBuildPortCode")
    w:SetDimensions(680, 320)
    w:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    w:SetMouseEnabled(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    w:SetHidden(true)
    wm:CreateControlFromVirtual("KozyEsoBuildPortCodeBg", w, "ZO_DefaultBackdrop"):SetAnchorFill()
    local title = wm:CreateControl("KozyEsoBuildPortCodeTitle", w, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetText("kozy-eso BuildPort: select all (Ctrl+A) and copy (Ctrl+C)")
    title:SetAnchor(TOP, w, TOP, 0, 14)
    local boxBg = wm:CreateControlFromVirtual("KozyEsoBuildPortCodeBox", w, "ZO_EditBackdrop")
    boxBg:SetAnchor(TOPLEFT, w, TOPLEFT, 16, 46)
    boxBg:SetAnchor(BOTTOMRIGHT, w, BOTTOMRIGHT, -16, -56)
    local edit = wm:CreateControlFromVirtual("KozyEsoBuildPortCodeEdit", boxBg, "ZO_DefaultEditMultiLineForBackdrop")
    edit:SetAnchor(TOPLEFT, boxBg, TOPLEFT, 6, 4)
    edit:SetAnchor(BOTTOMRIGHT, boxBg, BOTTOMRIGHT, -6, -4)
    edit:SetMaxInputChars(60000)
    local close = wm:CreateControlFromVirtual("KozyEsoBuildPortCodeClose", w, "ZO_DefaultButton")
    close:SetAnchor(BOTTOM, w, BOTTOM, 0, -14)
    close:SetText("Close")
    close:SetHandler("OnClicked", function() w:SetHidden(true) end)
    codeWindow = { window = w, edit = edit }
  end
  codeWindow.edit:SetText(text)
  codeWindow.window:SetHidden(false)
  codeWindow.edit:TakeFocus()
  pcall(function() codeWindow.edit:SelectAll() end)
end

local function onCommand(arg)
  -- "/kozyexport api scrib" lists global API functions whose name contains the text (to find unknown calls).
  local query = arg and arg:match("^api%s+(%S+)")
  if query then
    local found = {}
    local ok, err = pcall(function()
      -- zo_insecurePairs is ESO's way to walk _G; plain pairs can fail on the protected table.
      for name, v in (zo_insecurePairs or pairs)(_G) do
        if type(name) == "string" and type(v) == "function" and name:lower():find(query:lower(), 1, true) then
          found[#found + 1] = name
        end
      end
    end)
    if not ok then say("scan error: " .. tostring(err)) end
    table.sort(found)
    say(#found .. " functions match '" .. query .. "'")
    for n = 1, math.min(#found, 60) do say(found[n]) end
    return
  end
  if arg == "dump" then
    local catalog = dumpCatalog()
    sv().catalog = catalog
    say(#catalog.crafted .. " scribing grimoires, " .. #catalog.lines .. " skill lines saved, " .. #catalog.errors .. " errors. Type /reloadui to write the file.")
    for _, e in ipairs(catalog.errors) do say("error " .. e) end
    return
  end
  local payload = build()
  sv().last = payload -- fallback: copy it from the SavedVariables file
  -- Everything /export debug prints is also saved, so it can be read from the file after /reloadui.
  sv().debug = { version = VERSION, api = GetAPIVersion(), errors = errors, slots = rawSlots }
  if arg == "debug" then
    say("version " .. VERSION .. ", API " .. tostring(GetAPIVersion()))
    say("payload length " .. #payload .. ", URL length " .. (#URL + #payload))
    for _, e in ipairs(errors) do say("error " .. e) end
    for _, r in ipairs(rawSlots) do say(r) end
    for line in payload:gmatch("[^~]+") do say(line:sub(1, 160)) end
    return
  end
  if arg == "decap" then
    for _, e in ipairs(errors) do say("warning " .. e) end
    local ok, err = pcall(showCode, payload)
    if not ok then say("window error: " .. tostring(err) .. " (the code is saved in the SavedVariables file after /reloadui)") end
    say("code ready (" .. #payload .. " characters)")
    return
  end
  for _, e in ipairs(errors) do say("warning " .. e) end
  say("opening the Build Editor (" .. (#URL + #payload) .. " characters)")
  RequestOpenUnsafeURL(URL .. payload)
end

SLASH_COMMANDS["/kozyexport"] = onCommand
-- Short alias; "/export" is generic, so another addon may take it and the one loaded last wins.
SLASH_COMMANDS["/export"] = onCommand

-- Key binding (Controls > Add-ons): Bindings.xml calls this global.
ZO_CreateStringId("SI_BINDING_NAME_KOZY_ESO_BUILDPORT_EXPORT", "Open build in kozy-eso")
function KEBP.Export() onCommand("") end

-- Settings panel (LibAddonMenu-2.0 is a required dependency in the manifest).
local settingsRegistered = false
local function registerSettings()
  local LAM = LibAddonMenu2
  if settingsRegistered or not LAM then return end
  settingsRegistered = true
  local panelId = ADDON .. "Panel"
  LAM:RegisterAddonPanel(panelId, {
    type = "panel",
    name = "kozy-eso BuildPort",
    displayName = "|c8b5cf6kozy-eso|r BuildPort",
    author = "|c8b5cf6Kozy|r",
    version = VERSION,
  })
  LAM:RegisterOptionControls(panelId, {
    { type = "description", title = "Open your build online",
      text = "Type /kozyexport in the chat. To use a key instead: Esc > Settings > Controls > Add-Ons > kozy-eso BuildPort, then bind \"Open build in kozy-eso\". "
        .. "Your browser opens the kozy-eso.com Build Editor with your current gear, skills and passives." },
    { type = "button", name = "Export now", tooltip = "Same as /kozyexport", func = function() onCommand("") end, width = "half" },
    { type = "description", text = "/kozyexport debug prints the raw data in the chat if something looks wrong." },
  })
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, name)
  if name ~= ADDON then return end
  KozyEsoBuildPort_SV = KozyEsoBuildPort_SV or {}
  registerSettings()
  EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
end)

-- Safety net: if the library was not ready at load time, register once the player is in the world.
EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, function()
  registerSettings()
  EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED)
end)
