--Name Space
PsijicWay = PsijicWay or {}
local BOT = PsijicWay
local LMP = BOT.internal and BOT.internal.mapPins

BOT.Name = "PsijicWay"
BOT.addOnName = "PsijicWay"
BOT.addOnDisplayName = "The Psijic Way"
BOT.author = "@XBUTCH"
BOT.version = "1.51.01"
BOT.defaults = {
   filters = true,
   pinSize = 32,
   found = {},
}

-- Keyed by quest ID, then by zone map name.
local pinData = {

   [6172] = { -- The Psijics' Calling
      ["summerset/summerset_base"] = {
         { x = 0.587, y = 0.543 }, { x = 0.226, y = 0.599 }, { x = 0.292, y = 0.373 },
         { x = 0.621, y = 0.322 }, { x = 0.561, y = 0.432 }, { x = 0.676, y = 0.620 },
         { x = 0.479, y = 0.743 }, { x = 0.339, y = 0.424 }, { x = 0.738, y = 0.713 },
      },
   },

   [6181] = { -- Breaches On the Bay
      ["glenumbra/glenumbra_base"] = {
         { x = 0.735, y = 0.199 }, { x = 0.336, y = 0.509 }, { x = 0.436, y = 0.807 },
      },
      ["stormhaven/stormhaven_base"] = {
         { x = 0.516, y = 0.343 }, { x = 0.634, y = 0.361 }, { x = 0.130, y = 0.533 },
      },
      ["alikr/alikr_base"] = {
         { x = 0.436, y = 0.472 }, { x = 0.717, y = 0.579 }, { x = 0.249, y = 0.632 },
      },
   },

   [6185] = { -- Breaches of Frost and Fire
      ["stonefalls/stonefalls_base"] = {
         { x = 0.410, y = 0.523 }, { x = 0.520, y = 0.636 }, { x = 0.777, y = 0.504 },
      },
      ["eastmarch/eastmarch_base"] = {
         { x = 0.500, y = 0.530 }, { x = 0.332, y = 0.482 }, { x = 0.327, y = 0.687 },
      },
      ["therift/therift_base"] = {
         { x = 0.737, y = 0.367 }, { x = 0.078, y = 0.259 }, { x = 0.318, y = 0.230 },
      },
   },

   [6197] = { -- The Shattered Staff
      ["alikr/alikr_base"] = {
         { x = 0.611, y = 0.469 },
      },
      ["bangkorai/bangkorai_base"] = {
         { x = 0.369, y = 0.46 },
      },
      ["deshaan/deshaan_base"] = {
         { x = 0.734, y = 0.616 },
      },
      ["shadowfen/shadowfen_base"] = {
         { x = 0.534, y = 0.522 },
      },
   },

   [6194] = { -- A Breach Amid the Trees
      ["grahtwood/grahtwood_base"] = {
         { x = 0.291, y = 0.506 }, { x = 0.682, y = 0.463 }, { x = 0.230, y = 0.219 },
      },
      ["greenshade/greenshade_base"] = {
         { x = 0.127, y = 0.505 }, { x = 0.274, y = 0.100 }, { x = 0.584, y = 0.780 },
      },
      ["malabaltor/malabaltor_base"] = {
         { x = 0.492, y = 0.346 }, { x = 0.647, y = 0.727 }, { x = 0.810, y = 0.242 },
      },
   },

   [6190] = { -- A Time for Mud and Mushrooms
      ["deshaan/deshaan_base"] = {
         { x = 0.338, y = 0.572 }, { x = 0.100, y = 0.580 }, { x = 0.594, y = 0.440 },
         { x = 0.780, y = 0.396 }, { x = 0.790, y = 0.570 },
      },
      ["shadowfen/shadowfen_base"] = {
         { x = 0.748, y = 0.724 }, { x = 0.291, y = 0.777 },
         { x = 0.552, y = 0.361 }, { x = 0.256, y = 0.236 },
      },
   },

   [6198] = { -- The Towers' Remains
      ["craglorn/craglorn_base"] = {
         { x = 0.641, y = 0.569 },
      },
      ["greenshade/greenshade_base"] = {
         { x = 0.537, y = 0.81 },
      },
      ["stonefalls/stonefalls_base"] = {
         { x = 0.541, y = 0.627 },
      },
      ["stormhaven/stormhaven_base"] = {
         { x = 0.84, y = 0.448 },
      },
   },

   [6195] = { -- Time in Doomcrag's Shadow
      ["rivenspire/rivenspire_base"] = {
         { x = 0.157, y = 0.645 }, { x = 0.658, y = 0.626 }, { x = 0.823, y = 0.311 },
         { x = 0.713, y = 0.471 }, { x = 0.610, y = 0.417 }, { x = 0.810, y = 0.117 },
         { x = 0.216, y = 0.686 }, { x = 0.500, y = 0.677 }, { x = 0.201, y = 0.541 },
      },
   },

   [6196] = { -- A Breach Beyond the Crags
      ["craglorn/craglorn_base"] = {
         { x = 0.177, y = 0.222 }, { x = 0.394, y = 0.383 }, { x = 0.242, y = 0.579 },
         { x = 0.770, y = 0.687 }, { x = 0.654, y = 0.604 }, { x = 0.383, y = 0.700 },
      },
   },
}

local SAVED_VARS_NAME = "PW_Vars"
local LEGACY_SAVED_VARS_NAME = "PW_SavedVars"
local SAVED_VARS_VERSION = 2

local function MergeSavedVars(target, source, overwrite)
   if type(target) ~= "table" or type(source) ~= "table" then return end

   if (overwrite or rawget(target, "filters") == nil) and type(source.filters) == "boolean" then
      target.filters = source.filters
   end
   if (overwrite or rawget(target, "pinSize") == nil) and type(source.pinSize) == "number" then
      target.pinSize = source.pinSize
   end

   local targetFound = rawget(target, "found")
   if type(targetFound) ~= "table" then
      targetFound = {}
      target.found = targetFound
   end

   local sourceFound = rawget(source, "found")
   if type(sourceFound) == "table" then
      for key, value in pairs(sourceFound) do
         if overwrite or targetFound[key] == nil then
            targetFound[key] = value
         end
      end
   end
end

local QUEST_NAMES = {
   [6172] = "Psijic Order: The Psijics' Calling",
   [6181] = "Psijic Order: Breaches On the Bay",
   [6185] = "Psijic Order: Breaches of Frost and Fire",
   [6197] = "Psijic Order: The Shattered Staff",
   [6194] = "Psijic Order: A Breach Amid the Trees",
   [6190] = "Psijic Order: A Time for Mud and Mushrooms",
   [6198] = "Psijic Order: The Towers' Remains",
   [6195] = "Psijic Order: Time in Doomcrag's Shadow",
   [6196] = "Psijic Order: A Breach Beyond the Crags",
}

local PIN_TYPE = "PW_Pin"
local pinTypeId1

local function legacyPinKey(x, y)
   return string.format("%.6f,%.6f", x, y)
end

local function pinKey(questId, mapName, x, y)
   return string.format("%d|%s|%.6f,%.6f", questId, mapName, x, y)
end

local function MigrateFoundKeys()
   if BOT.SV.foundKeyVersion == 2 then return end

   local found = rawget(BOT.SV, "found")
   if type(found) ~= "table" then
      found = {}
      BOT.SV.found = found
   end

   local migratedLegacyKeys = {}
   for questId, zoneMaps in pairs(pinData) do
      for mapName, pins in pairs(zoneMaps) do
         for _, pinInfo in ipairs(pins) do
            local oldKey = legacyPinKey(pinInfo.x, pinInfo.y)
            local oldValue = found[oldKey]
            if oldValue ~= nil then
               local newKey = pinKey(questId, mapName, pinInfo.x, pinInfo.y)
               if found[newKey] == nil then
                  found[newKey] = oldValue
               end
               migratedLegacyKeys[oldKey] = true
            end
         end
      end
   end

   for oldKey in pairs(migratedLegacyKeys) do
      found[oldKey] = nil
   end

   BOT.SV.foundKeyVersion = 2
end

local function InitializeSavedVars()
   BOT.SV = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, BOT.defaults)

   -- The manifest historically declared PW_SavedVars while the code used PW_Vars.
   -- Load both names for one-way, idempotent migration so no legacy values are lost.
   if not BOT.SV.legacySavedVarsMigrated then
      local legacySV = ZO_SavedVars:NewAccountWide(LEGACY_SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, {})
      MergeSavedVars(BOT.SV, legacySV, false)
      BOT.SV.legacySavedVarsMigrated = true
   end

   -- Older code also created character-specific branches. They were effectively
   -- unused in the current UI, but preserve a branch explicitly selected via CV=true
   -- if one exists in an older installation.
   if not BOT.SV.characterSavedVarsMigrated then
      local legacyCharacterSV = ZO_SavedVars:NewCharacterIdSettings(LEGACY_SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, {})
      if legacyCharacterSV.CV then
         MergeSavedVars(BOT.SV, legacyCharacterSV, true)
      end

      local characterSV = ZO_SavedVars:NewCharacterIdSettings(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, {})
      if characterSV.CV then
         MergeSavedVars(BOT.SV, characterSV, true)
      end

      BOT.SV.characterSavedVarsMigrated = true
   end

   BOT.savedVars = BOT.SV
   MigrateFoundKeys()
end

local PSIJIC_QUEST_ID_SET = {
   [6172] = true, [6181] = true, [6185] = true, [6197] = true, [6194] = true,
   [6190] = true, [6198] = true, [6195] = true, [6196] = true,
}

local function GetCurrentQuestId()
   for i = 1, GetNumJournalQuests() do
      local id = GetJournalQuestId(i)
      if PSIJIC_QUEST_ID_SET[id] then return id end
   end
   return nil
end

local COLOR_FOUND    = ZO_ColorDef:New(1, 1, 1, 1)
local COLOR_NOTFOUND = ZO_ColorDef:New(0.5, 0.5, 0.5, 1)

local function GetPinTag(pin)
   local _, tag = pin:GetPinTypeAndTag()
   return tag
end

local pinLayoutData = {
   level = 80,
   texture = "/esoui/art/tribute/patrons/tot_icon_psijic.dds",
   tint = function(pin)
      local tag = GetPinTag(pin)
      if tag and tag.key and BOT.SV.found[tag.key] then
         return COLOR_FOUND
      else
         return COLOR_NOTFOUND
      end
   end,
}

local clickHandler = {
   [1] = {
      name = "Toggle Time Breach",
      gamepadName = "Toggle Time Breach",
      show = function(pin) return true end,
      callback = function(pin)
         local tag = GetPinTag(pin)
         if not tag or not tag.key then return end

         if BOT.SV.found[tag.key] then
            BOT.SV.found[tag.key] = nil
         else
            BOT.SV.found[tag.key] = true
         end
         LMP:RefreshPins(pinTypeId1)
      end,
   },
}

local pinTooltipCreator = {
   creator = function(pin)
      local tag = GetPinTag(pin)
      local text = tag and tag.questName or "Time Breach"
      if IsInGamepadPreferredMode() then
         local gpTooltip = ZO_MapLocationTooltip_Gamepad
         local baseSection = gpTooltip.tooltip
         gpTooltip:LayoutIconStringLine(baseSection, nil, text, baseSection:GetStyle("mapLocationTooltipContentName"))
      else
         SetTooltipText(InformationTooltip, text)
      end
   end,
   tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
}

local pinTypeAddCallback = function(pinManager)
   if not LMP:IsEnabled(PIN_TYPE) then return end
   if GetMapType() > MAPTYPE_ZONE then return end

   local questId = GetCurrentQuestId()
   if not questId then return end

   local mapname = LMP:GetZoneAndSubzone(true)
   local zoneMap = pinData[questId]
   local pins = zoneMap and zoneMap[mapname]
   if pins then
      for _, pinInfo in ipairs(pins) do
         local key = pinKey(questId, mapname, pinInfo.x, pinInfo.y)
         LMP:CreatePin(PIN_TYPE, {
            x = pinInfo.x,
            y = pinInfo.y,
            questId = questId,
            mapName = mapname,
            key = key,
            questName = QUEST_NAMES[questId],
         }, pinInfo.x, pinInfo.y)
      end
   end
end

local pinTypeOnResizeCallback = nil

local lastQuestId
local questRefreshPending = false

local function ScheduleQuestRefresh()
   if questRefreshPending then return end
   questRefreshPending = true

   zo_callLater(function()
      questRefreshPending = false
      local questId = GetCurrentQuestId()
      if questId ~= lastQuestId then
         lastQuestId = questId
         LMP:RefreshPins(PIN_TYPE)
      end
   end, 50)
end

local function OnLoad(eventCode, addonName)
   if addonName ~= BOT.Name then return end
   EVENT_MANAGER:UnregisterForEvent(BOT.Name, EVENT_ADD_ON_LOADED)

   InitializeSavedVars()

   pinLayoutData.size = BOT.savedVars.pinSize
   pinTypeId1 = LMP:AddPinType(PIN_TYPE, pinTypeAddCallback, pinTypeOnResizeCallback, pinLayoutData, pinTooltipCreator)
   BOT.pinType = pinTypeId1
   LMP:AddPinFilter(pinTypeId1, "The Psijic Way", nil, BOT.SV, "filters")
   LMP:SetClickHandlers(PIN_TYPE, clickHandler)
   LMP:SetPinFilterHidden(pinTypeId1, "pvp", true)
   LMP:SetPinFilterHidden(pinTypeId1, "imperialPvP", true)
   LMP:SetPinFilterHidden(pinTypeId1, "battleground", true)
   LMP:RefreshPins(PIN_TYPE)

   lastQuestId = GetCurrentQuestId()
   EVENT_MANAGER:RegisterForEvent(BOT.Name .. "_QuestAdded", EVENT_QUEST_ADDED, ScheduleQuestRefresh)
   EVENT_MANAGER:RegisterForEvent(BOT.Name .. "_QuestRemoved", EVENT_QUEST_REMOVED, ScheduleQuestRefresh)

   BOT:CreateOptions()
end

EVENT_MANAGER:RegisterForEvent(BOT.Name, EVENT_ADD_ON_LOADED, OnLoad)
