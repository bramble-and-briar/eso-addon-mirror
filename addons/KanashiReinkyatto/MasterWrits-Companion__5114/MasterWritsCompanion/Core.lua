MWC = {
  name = "MasterWritsCompanion",
  -- Shown in both window titles; keep in step with Version in the manifest.
  VERSION = "0.4.7b",
  -- The dev build keeps the log (MWC.Log, MWC.Timed); the release build keeps nothing, so playing with the
  -- addon enabled saves no data. The release zip is built with this set to false.
  DEV = false,
  -- Bag slots withdrawing from the bank leaves free (crafting and opening containers may fill the bag).
  BAG_RESERVE = 4,
  COLOR = { RED = "FF5555", GREEN = "55FF55", GREY = "999999", YELLOW = "FFDD44", BLUE = "5AAEFF", ORANGE = "F0B44C", PURPLE = "B48CFF" },
}

local SV_DEFAULTS = {
  includeBag = true,
  includeBank = true,
  showCompleted = true,
  sealedChoices = {},
  keepItems = {},
  keyTab = "alchemy",
  tab = "all",
  windowOpen = false,
}

function MWC.Print(fmt, ...)
  CHAT_ROUTER:AddSystemMessage("[MWC] " .. string.format(fmt, ...))
end

-- The addon's log, kept in SavedVariables (MasterWritsCompanion.lua, "log") and never printed: what crafting,
-- banking and turning in did and why they skipped something, to be sent when something goes wrong.
-- Only the newest LOG_LIMIT lines are kept.
local LOG_LIMIT = 3000

function MWC.Log(fmt, ...)
  if not MWC.DEV or not MWC.sv then return end
  local log = MWC.sv.log or {}
  MWC.sv.log = log
  local ok, text = pcall(string.format, fmt, ...)
  table.insert(log, string.format("%s %s", os.date("%Y-%m-%d %H:%M:%S"), ok and text or tostring(fmt)))
  while #log > LOG_LIMIT do
    table.remove(log, 1)
  end
end

-- Runs fn and logs how long it took when that is noticeable (PERF_LOG_MS or more): finds what makes the game
-- stutter. Returns what fn returns.
local PERF_LOG_MS = 20
function MWC.Timed(label, fn, ...)
  if not MWC.DEV then return fn(...) end
  local started = GetGameTimeMilliseconds()
  local a, b, c = fn(...)
  local took = GetGameTimeMilliseconds() - started
  if took >= PERF_LOG_MS then
    MWC.Log("Perf: %s %d ms", label, took)
  end
  return a, b, c
end

function MWC.Colorize(hex, text)
  return string.format("|c%s%s|r", hex, text)
end

function MWC.ItemName(link)
  return zo_strformat("<<C:1>>", GetItemLinkName(link))
end

-- Puts an item link into the chat input the way the game does it: style "brackets", default text.
function MWC.LinkInChat(link)
  local data = link:match("^|H%d:(.-)|h")
  ZO_LinkHandler_InsertLink(data and string.format("|H%d:%s|h|h", LINK_STYLE_BRACKETS, data) or link)
end

-- What a crafting passive does, as the number the game itself uses (GetNonCombatBonus), so no skill name or
-- client language is involved. Nil when the constant doesn't exist in this game version.
function MWC.SkillBonus(constantName)
  local bonus = _G[constantName]
  if bonus == nil then return nil end
  return GetNonCombatBonus(bonus)
end

-- The filled slots of these bags holding an item of one of these types (any type when itemTypes is nil), as
-- { bag, slot } pairs. Read from the game's own inventory cache (what the inventory and guild store filters
-- use): no call per slot and no empty slots. A bag whose cache doesn't hold as many items as the bag (not built
-- yet) is read slot by slot instead, so nothing is ever missed.
function MWC.ItemSlots(bags, itemTypes)
  local result = {}
  for _, bag in ipairs(bags) do
    local cache = SHARED_INVENTORY and SHARED_INVENTORY:GetOrCreateBagCache(bag)
    local cached = 0
    if cache then
      for _ in pairs(cache) do
        cached = cached + 1
      end
    end
    if cache and cached == GetNumBagUsedSlots(bag) then
      for slot, data in pairs(cache) do
        if not itemTypes or itemTypes[data.itemType] then
          table.insert(result, { bag, slot })
        end
      end
    else
      for slot = 0, GetBagSize(bag) - 1 do
        local itemType = GetItemType(bag, slot)
        if itemType ~= ITEMTYPE_NONE and (not itemTypes or itemTypes[itemType]) then
          table.insert(result, { bag, slot })
        end
      end
    end
  end
  return result
end

-- A writ's quest takes only items the turning-in character crafted (seen with gear, and with a holiday writ's
-- item crafted by another character): items made by anyone else, or by no one, never count as ready.
function MWC.IsMine(bag, slot)
  return zo_strformat("<<1>>", GetItemCreatorName(bag, slot)) == zo_strformat("<<1>>", GetUnitName("player"))
end

-- Upper case first letter only (the game's <<C:1>> capitalizes every word, wrong in German and Russian).
-- Latin, common accented letters and Cyrillic (UTF-8); anything else is left as it is.
local UPPER_FIRST = {
  ["ä"] = "Ä", ["ö"] = "Ö", ["ü"] = "Ü", ["à"] = "À", ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ё"] = "Ё",
}
function MWC.CapitalFirst(text)
  if not text or text == "" then return text or "" end
  local first, second = text:byte(1), text:byte(2) or 0
  if first >= 97 and first <= 122 then return string.char(first - 32) .. text:sub(2) end
  local two = text:sub(1, 2)
  if UPPER_FIRST[two] then return UPPER_FIRST[two] .. text:sub(3) end
  if first == 0xD0 and second >= 0xB0 and second <= 0xBF then -- а..п
    return string.char(0xD0, second - 0x20) .. text:sub(3)
  elseif first == 0xD1 and second >= 0x80 and second <= 0x8F then -- р..я
    return string.char(0xD0, second + 0x20) .. text:sub(3)
  end
  return text
end

-- The item a writ asks for, from the writ's text: by the language file's pattern, else the text in the first
-- parentheses, else the task line up to its first ";" or "." (any client language). First letter upper case.
local function MatchItemName(text, pattern)
  -- A line break at the end, so patterns ending in "[;\n]" also find the last line.
  local name = pattern and (text .. "\n"):match(pattern)
  if name and name ~= "" then return name end
  -- Other client languages: the item usually stands in parentheses ("... предмета (платиновое ожерелье) ...").
  name = text:match("%(([^()\n]+)%)")
  if name and name ~= "" then return name end
  -- Many languages put a "Consume to start quest:" line first; the task is on the next line.
  local task = text:match("^[^\n]*:%s*\n%s*([^\n]+)") or text
  task = (task:match("^[^;]*") or task):match("^%s*(.-)%s*$")
  return task:match("^(.-)%.$") or task
end

function MWC.WritItemName(text, pattern)
  return MWC.CapitalFirst(MatchItemName(text or "", pattern))
end

-- Gear names: English writ texts lowercase some words ("platinum Necklace"), so every word is capitalized
-- there; other languages keep their own case (German nouns already are, Russian ones mustn't be).
function MWC.GearDisplayName(name)
  if GetCVar("language.2") == "en" then return zo_strformat("<<C:1>>", name) end
  return MWC.CapitalFirst(name)
end

function MWC.LinkFromItemId(itemId)
  return string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId or 0)
end

local function OnSlash(args)
  local cmd = zo_strlower(zo_strtrim(args or ""))
  if cmd == "" then
    MWC.UI.Toggle()
  elseif cmd == "report" then
    MWC.Report.Summary()
  elseif cmd == "craft" then
    MWC.Craft.Start()
  elseif cmd == "stop" then
    MWC.Activity.Stop()
  elseif (cmd == "log" or cmd == "log clear") and not MWC.DEV then
    MWC.Print(MWC.L.LOG_NONE)
  elseif cmd == "log" then
    MWC.Print(MWC.L.LOG_INFO,
      #(MWC.sv.log or {}))
  elseif cmd == "log clear" then
    MWC.sv.log = {}
    MWC.Print(MWC.L.LOG_CLEARED)
  else
    MWC.Print("%s", MWC.L.COMMANDS)
  end
end

local function OnPlayerActivated()
  EVENT_MANAGER:UnregisterForEvent(MWC.name, EVENT_PLAYER_ACTIVATED)
  -- The quest journal is loaded by now: settle quests that changed while the addon couldn't see them.
  MWC.Journal.Reconcile()
  MWC.Log("Login: v%s dev, %s, API %d, LibCharacterKnowledge %s, LibSets %s", MWC.VERSION, GetUnitName("player"),
    GetAPIVersion(), LibCharacterKnowledge and "yes" or "no", LibSets and "yes" or "no")
  -- The window comes back if it was open when the game was left.
  if MWC.sv.windowOpen then
    MWC.UI.Show()
  end
end

local function OnAddOnLoaded(_, addonName)
  if addonName ~= MWC.name then return end
  EVENT_MANAGER:UnregisterForEvent(MWC.name, EVENT_ADD_ON_LOADED)
  MWC.sv = ZO_SavedVars:NewAccountWide("MasterWritsCompanionSV", 1, nil, SV_DEFAULTS)
  -- "Hide skipped" became "Skipped" (checked = shown).
  if MWC.sv.showSkipped == nil then
    MWC.sv.showSkipped = not MWC.sv.hideSkipped
  end
  MWC.sv.hideSkipped = nil
  -- keyItems meant "show in Materials Used"; Keep materials (keepItems) starts fresh with its own defaults.
  MWC.sv.keyItems = nil
  -- Potion names and quest names are kept as the game wrote them, in the client's language: after a change of
  -- language they would never match again, so they are dropped and learned anew (previews at the alchemy
  -- station, the next quests). Holiday quest and mediator names are kept: a name of another language does no harm.
  local language = GetCVar("language.2")
  if MWC.sv.language and MWC.sv.language ~= language then
    for _, key in ipairs({ "potionNames", "potionIcons", "alchemyResults", "questCrafts" }) do
      MWC.sv[key] = nil
    end
  end
  MWC.sv.language = language
  -- A log left by a dev build isn't kept by the release build.
  if not MWC.DEV then
    MWC.sv.log = nil
  end
  MWC.Session.Init()
  MWC.Journal.Compact()
  MWC.Marks.Init()
  MWC.Bank.Init()
  MWC.UI.Init()
  MWC.KeyWindow.Init()
  MWC.TurnIn.Init()
  -- Data of the development probes and logs, no longer used.
  -- alchemyNames held previews by name only (now alchemyResults: effects and name); alchemyChoice was
  -- recorded under the old cancel rule (now alchemyCrafted).
  for _, key in ipairs({ "probe", "probeGear", "alchemyDump", "turnInLog", "alchemyLearnLog", "alchemyNames",
      "alchemyChoice", "autoHandIn", "minimized", "potionItems", "pinned" }) do
    MWC.sv[key] = nil
  end
  SLASH_COMMANDS["/mwc"] = OnSlash
  EVENT_MANAGER:RegisterForEvent(MWC.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(MWC.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
