LazyLearner = LazyLearner or {}
local Utils = LazyLearner.Utils
local EnchantingLearner = LazyLearner.EnchantingLearner
local AlchemyLearner = LazyLearner.AlchemyLearner

-- The default for the account-wide settings
LazyLearner.defaults = {
    extensiveReporting = false,
    msgcolor = {
        r = 0,
        g = 1,
        b = 0
    },
    warningColor = {
        r = 1,
        g = 0,
        b = 0
    }
}

--- The starting point of queuing enchanting items to learn unknown traits.
--- @param includeDLC Boolean indicating whether to include the DLC runes Hakeijo and Indeko
--- @param includeKuta Boolean indicating whether to include the Kuta rune
function LazyLearner.enchantingLearner(includeDLC, includeKuta)
  local somethingQueued = EnchantingLearner.queueLearningEnchanting(includeDLC, includeKuta)
  if somethingQueued then
      local msg = LazyLearner.L("LL_VISIT_ENCHANTING_STATION")
      Utils.announceMessage(msg)
      Utils.sendChatMessage(msg)
  end
end

--- The starting point of queuing alchemy items to learn unknown traits.
--- @param includeAll Boolean indicating whether to include DLC reagents.
function LazyLearner.alchemyLearner(includeAll)
  local somethingQueued = AlchemyLearner.queueLearningAlchemy(includeAll)
  if somethingQueued then
      local msg = LazyLearner.L("LL_VISIT_ALCHEMY_STATION")
      Utils.announceMessage(msg)
      Utils.sendChatMessage(msg)
  else
      Utils.sendChatMessage(LazyLearner.L("LL_NOTHING_QUEUED_ALCHEMY"))
  end
end

--- Handles the /lazylearn slash commands
--- @param args The arguments passed to the slash command
local function genericSlashCommand(args)
    local searchResult = {string.match(args, "^(%S*)%s*(.-)$")}
    if searchResult[1] == 'alchemy' then
        LazyLearner.alchemyLearner(searchResult[2] == 'all')
    elseif searchResult[1] == 'enchant' then
        LazyLearner.enchantingLearner(
            searchResult[2] == 'all' or searchResult[2] == 'withdlc',
            searchResult[2] == 'all' or searchResult[2] == 'withkuta')
    elseif searchResult[1] == 'both'  then 
        if searchResult[2] == 'all' then
            LazyLearner.alchemyLearner(true)
            LazyLearner.enchantingLearner(true, true)
            return
        else
            LazyLearner.alchemyLearner(false)
            LazyLearner.enchantingLearner(false, false)
            return
        end
    else
        Utils.sendChatMessage("Possible commands:")
        Utils.sendChatMessage("/lazylearn alchemy --> " .. LazyLearner.L("LL_COMMANDS_ALCHEMY_BASEGAME"))
        Utils.sendChatMessage("/lazylearn alchemy all --> " .. LazyLearner.L("LL_COMMANDS_ALCHEMY_ALL"))
        Utils.sendChatMessage(string.format(
            "/lazylearn enchant --> " .. LazyLearner.L("LL_COMMANDS_ENCHANT_BASEGAME"),
            Utils.getItemLinkFromItemId(45854), Utils.getItemLinkFromItemId(68342), Utils.getItemLinkFromItemId(166045)))
        Utils.sendChatMessage(string.format(
            "/lazylearn enchant withdlc --> " .. LazyLearner.L("LL_COMMANDS_ENCHANT_WITHDLC"),
            Utils.getItemLinkFromItemId(68342), Utils.getItemLinkFromItemId(166045), Utils.getItemLinkFromItemId(45854)))
        Utils.sendChatMessage(string.format(
            "/lazylearn enchant withkuta --> " .. LazyLearner.L("LL_COMMANDS_ENCHANT_WITHKUTA"),
            Utils.getItemLinkFromItemId(45854), Utils.getItemLinkFromItemId(68342), Utils.getItemLinkFromItemId(166045)))
        Utils.sendChatMessage(string.format(
            "/lazylearn enchant all --> " .. LazyLearner.L("LL_COMMANDS_ENCHANT_ALL"),
            Utils.getItemLinkFromItemId(45854), Utils.getItemLinkFromItemId(68342), Utils.getItemLinkFromItemId(166045)))
        Utils.sendChatMessage(string.format(
            "/lazylearn both --> " .. LazyLearner.L("LL_COMMANDS_BOTH"),
            Utils.getItemLinkFromItemId(45854), Utils.getItemLinkFromItemId(68342), Utils.getItemLinkFromItemId(166045)))
        Utils.sendChatMessage(string.format(
            "/lazylearn both all --> " .. LazyLearner.L("LL_COMMANDS_BOTH_ALL"),
            Utils.getItemLinkFromItemId(45854), Utils.getItemLinkFromItemId(68342), Utils.getItemLinkFromItemId(166045)))
    end
end

--- Initializes the LazyLearner addon.
function LazyLearner.Initialize()
    LazyLearner.savedVars = ZO_SavedVars:NewAccountWide("LazyLearnerSavedVars", 1, nil, LazyLearner.defaults)
    LazyLearner.setupPanel()
    LazyLearner.LLC = LibLazyCrafting:AddRequestingAddon(LazyLearner.name, true, function()
    end)
    SLASH_COMMANDS['/lazylearn'] = genericSlashCommand
end

--- Event handler for when the addon is loaded.
function LazyLearner.OnAddOnLoaded(event, addonName)
    if addonName == LazyLearner.name then
        EVENT_MANAGER:UnregisterForEvent(LazyLearner.name .. "_Loaded", EVENT_ADD_ON_LOADED)
        LazyLearner.Initialize()
    end
end

--- Register the event handler so that the add-on will be loaded by ESO
EVENT_MANAGER:RegisterForEvent(LazyLearner.name .. "_Loaded", EVENT_ADD_ON_LOADED, LazyLearner.OnAddOnLoaded)
