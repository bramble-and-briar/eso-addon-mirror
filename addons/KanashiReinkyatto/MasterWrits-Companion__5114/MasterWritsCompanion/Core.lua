MWC = {
  name = "MasterWritsCompanion",
  -- Shown in both window titles; keep in step with Version in the manifest.
  VERSION = "0.4.6b",
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

-- The keybinding keeps its first name (MWB_TOGGLE): the game stores the key a player bound under it.
ZO_CreateStringId("SI_BINDING_NAME_MWB_TOGGLE", "Toggle window")

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
    MWC.Print("This build keeps no log.")
  elseif cmd == "log" then
    MWC.Print("Log: %d lines, saved in SavedVariables/MasterWritsCompanion.lua after /reloadui or logout. /mwc log clear empties it.",
      #(MWC.sv.log or {}))
  elseif cmd == "log clear" then
    MWC.sv.log = {}
    MWC.Print("Log cleared.")
  else
    MWC.Print("Commands: /mwc (window), /mwc report, /mwc craft, /mwc stop, /mwc log, /mwc log clear")
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
      "alchemyChoice", "autoHandIn", "minimized", "potionItems" }) do
    MWC.sv[key] = nil
  end
  SLASH_COMMANDS["/mwc"] = OnSlash
  EVENT_MANAGER:RegisterForEvent(MWC.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(MWC.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
