local SDC = SimpleDailyCraft
local LAM = LibAddonMenu2

---------------------
----Tool function----
---------------------

--Turn ItemId to Link
local function TableToLink(Table)
  local Tep = {}
  if Table[1] == "%/" then return {GetString(SI_AMBIENTOCCLUSIONTYPE0)} end
  for i = 1, #Table do
    table.insert(Tep, "|H0:item:"..Table[i]..":30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  end
  return Tep
end

--Alchemy Banlist part
local Select = ""
local function BanList(Link, Table)
  local ItemId = GetItemLinkItemId(Link)
  if ItemId == 0 or ItemId == nil then return Table end
  if Table[1] == "%/" then Table = {} end
  for i = 1, #Table do
    if ItemId == Table[i] then
      table.remove(Table, i)
      if #Table == 0 then return {"%/"} end
      return Table 
    end
  end
  table.insert(Table, ItemId)
  return Table
end

--Display ItemLink to banlist window
local function Desc(Table)
  local Tep = TableToLink(Table)
  local String = ""
  for i = 1, #Tep do
    String = String..Tep[i].."\r\n"
  end
  return String
end

--Style list part
local Select2 = 0
local function SytleMaterials()
  local Index = {}
  local Name= {}
  for i = 1, 3000 do
    local Style = GetItemStyleName(i):gsub("%^.+", "")
    local String = GetItemStyleMaterialLink(i, 0)
    local Count = GetCurrentSmithingStyleItemCount(i)
    if String ~= "" then
      table.insert(Index, i)
      table.insert(Name, Style..": "..String.." x "..Count)
    end
  end
  return Name, Index
end

local function Desc2(Table)
  local Tep = {}
  local TepCount = {}
  for i = 1, 2000 do
    if Table[i] ~= nil then
      table.insert(Tep, Table[i])
      table.insert(TepCount, GetCurrentSmithingStyleItemCount(i))
    end
  end
  Tep = TableToLink(Tep)
  local String = ""
  for i = 1, #Tep do
    String = String..Tep[i].." x "..TepCount[i].."\r\n"
  end
  return String
end

------------
----Menu----
------------

local Icon = {
  [1] = "|t25:25:esoui/art/inventory/inventory_tabicon_craftbag_blacksmithing_up.dds:inheritColor|t",   --BlackSmith
  [2] = "|t25:25:esoui/art/inventory/inventory_tabicon_craftbag_clothing_up.dds:inheritColor|t",        --Cloth
  [3] = "|t25:25:esoui/art/inventory/inventory_tabicon_craftbag_enchanting_up.dds:inheritColor|t",      --Enchat
  [4] = "|t25:25:esoui/art/inventory/inventory_tabicon_craftbag_alchemy_up.dds:inheritColor|t",         --Alchmy
  [5] = "|t25:25:esoui/art/inventory/inventory_tabicon_craftbag_provisioning_up.dds:inheritColor|t",    --Cook
  [6] = "|t25:25:esoui/art/inventory/inventory_tabicon_craftbag_woodworking_up.dds:inheritColor|t",     --Wood
  [7] = "|t25:25:esoui/art/tutorial/tutorial_idexicon_jewelry_up.dds:inheritColor|t",                   --Jewelry
}

function SDC.BuildMenu()
  local panelData = {
    type = "panel",
    name = SDC.name,
    displayName = SDC.title,
    author = SDC.author,
    version = SDC.version,
    registerForRefresh = true,
	}
	LAM:RegisterAddonPanel(SDC.name.."_Options", panelData)

	local options = {
    { --Account/Character setting
		type = "checkbox",
		name = GetString(SI_ADDON_MANAGER_CHARACTER_SELECT_LABEL)..GetString(SI_CURRENCYLOCATION3).." / "..GetString(SI_CURRENCYLOCATION0),
    tooltip = GetString(SI_CHECK_BUTTON_OFF)..": "..GetString(SI_CURRENCYLOCATION3).."\r\n"..GetString(SI_CHECK_BUTTON_ON)..": "..GetString(SI_CURRENCYLOCATION0),
		getFunc = function() return SDC.SV2.CV end,
		setFunc = function(var)
      SDC.SV2.CV = var
      SDC.SwitchSV()
      --Reset
      SDCTopLevel:ClearAnchors()
      SDCTopLevel:SetAnchor(
      SDC.SV.Window_Point,
      GuiRoot,
      SDC.SV.Window_rPoint,
      SDC.SV.Window_OffsetX,
      SDC.SV.Window_OffsetY
      )
      SDC.QuestUpdate()
      --Reset describe
      SDC_LAM_Desc1.data.text = Desc(SDC.SV.DailyRestrict)
      SDC_LAM_Desc2.data.text = Desc(SDC.SV.DailyRawRestrict)
      SDC_LAM_Desc3.data.text = Desc(SDC.SV.MasterRestrict)
      SDC_LAM_Desc4.data.text = Desc2(SDC.SV.StyleList)
      SDC_LAM_Desc1:UpdateValue()
      SDC_LAM_Desc2:UpdateValue()
      SDC_LAM_Desc3:UpdateValue()
      SDC_LAM_Desc4:UpdateValue()
    end,
    width = "full",
    },
    
    { --Prompt
    type = "submenu", 
		name = GetString(SI_INTERFACE_OPTIONS_TOOLTIPS).." / "..GetString(SI_SETTINGSYSTEMPANEL3),
    reference = "SDC_Prompt",
		controls = {
        { --Bar
        type = "checkbox",
        name = GetString(SI_SETTINGSYSTEMPANEL3)..": "..table.concat(Icon),
        tooltip = GetString(SI_BINDING_NAME_TOGGLE_SHOW_INGAME_GUI),
        width = "full",
        getFunc = function() return SDC.SV.Window_Show end,
        setFunc = function(var) 
          SDC.SV.Window_Show = var
          SDC.QuestUpdate()
        end,
        },
        { --Alchemy Cost
        type = "checkbox",
        name = GetString(SI_TRADESKILLTYPE4).." -> "..zo_strformat(GetString(SI_MONEY_FORMAT), "? "),
        tooltip = GetString(SI_GUILDKEEPNOTICESSETTINGCHOICE1),
        width = "full",
        getFunc = function() return SDC.SV.DD_AlchemyCost end,
        setFunc = function(var) SDC.SV.DD_AlchemyCost = var end,
        },
        { --Material Left
        type = "slider",
        name = GetString(SI_HOOK_POINT_STORE_REMAINING).."["..GetString(SI_SMITHING_HEADER_MATERIAL).."] x ?", 
        tooltip = GetString(SI_GUILDKEEPNOTICESSETTINGCHOICE1),
        getFunc = function() return SDC.SV.DD_SmithMaterialLeft end,
        setFunc = function(var) SDC.SV.DD_SmithMaterialLeft = var end,
        min = 0,
        max = 50000,
        warning = "0 = "..GetString(SI_DIALOG_CLOSE),
        },
        { --Bank Take
        type = "checkbox", 
        name = GetString(SI_CURRENCYLOCATION1).." -> "..GetString(SI_CRAFTING_MISSING_ITEMS).." -> ...",
        tooltip = GetString(SI_GUILDKEEPNOTICESSETTINGCHOICE1),
        width = "full",
        getFunc = function() return SDC.SV.DD_Bank end,
        setFunc = function(var) SDC.SV.DD_Bank = var end,
        },
        { --Announce
        type = "checkbox",
        name = GetString(SI_MAIN_MENU_ANNOUNCEMENTS).." -> "..GetString(SI_BINDING_NAME_TOGGLE_JOURNAL),
        tooltip = GetString(SI_QUEST_TRACKER_MENU_SHOW_IN_JOURNAL),
        width = "full",
        getFunc = function() return SDC.SV.DD_Announce end,
        setFunc = function(var) SDC.SV.DD_Announce = var end,
        },
        { --ResearchHelper
        type = "checkbox", 
        name = GetString(SI_SPECIALIZEDITEMTYPE101).." -> "..GetString(SI_GAMEPAD_GROUP_FINDER_SEARCH_RESULTS_REFRESH_KEYBIND),  
        tooltip = GetString(SI_GUILDKEEPNOTICESSETTINGCHOICE1),
        width = "full",
        getFunc = function() return SDC.SV.DD_Research end,
        setFunc = function(var) SDC.SV.DD_Research = var end,
        },
      },
    },
    
    { --Quest
    type = "submenu", 
		name = GetString(SI_COLLECTIBLE_ACTION_ACCEPT_QUEST).." / "..GetString(SI_QUEST_COMPLETE_CONFIRM_TITLE),
    reference = "SDC_Quest",
		controls = {
        { --QuestDelay
        type = "slider",
        name = GetString(SI_KEYBINDINGS_CATEGORY_INTERACTION).." (ms)", 
        getFunc = function() return SDC.SV.QuestDelay end,
        setFunc = function(var) SDC.SV.QuestDelay = var end,
        width = "full",
        min = 50,
        max = 800,
        step = 10,
        warning = GetString(SI_INTERFACE_OPTIONS_FADE_RATE_FAST).." <- 200ms -> "..GetString(SI_INTERFACE_OPTIONS_FADE_RATE_SLOW),
        },
        {
        type = "header",
        name = GetString(SI_TIMEDACTIVITYTYPE0).." / "..GetString(SI_ITEMTYPE60),
        },
        { --Daily craft or Master Quest Auto
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t|t25:25:esoui/art/icons/master_writ_alchemy.dds|t "..GetString(SI_BINDING_NAME_AUTORUN),
        width = "full",
        getFunc = function() return SDC.SV.QuestAuto end,
        setFunc = function(var) SDC.SV.QuestAuto = var end,
        },
        {
        type = "divider",
        alpha = 0.2,
        },
        { --Black
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t"..GetString(SI_TRADESKILLTYPE1),  
        width = "half",
        getFunc = function() return SDC.SV.BQ end,
        setFunc = function(var) SDC.SV.BQ = var end,
        },
        { --Cloth
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t"..GetString(SI_TRADESKILLTYPE2),  
        width = "half",
        getFunc = function() return SDC.SV.CQ end,
        setFunc = function(var) SDC.SV.CQ = var end,
        },
        { --Wood
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t"..GetString(SI_TRADESKILLTYPE6),
        width = "half",
        getFunc = function() return SDC.SV.WQ end,
        setFunc = function(var) SDC.SV.WQ = var end,
        },
        { --Jewelry
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t"..GetString(SI_TRADESKILLTYPE7),
        width = "half",
        getFunc = function() return SDC.SV.JQ end,
        setFunc = function(var) SDC.SV.JQ = var end,
        },
        { --Cook
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t"..GetString(SI_TRADESKILLTYPE5),  
        width = "half",
        getFunc = function() return SDC.SV.PQ end,
        setFunc = function(var) SDC.SV.PQ = var end,
        },
        { --Enchant
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t"..GetString(SI_TRADESKILLTYPE3),  
        width = "half",
        getFunc = function() return SDC.SV.EQ end,
        setFunc = function(var) SDC.SV.EQ = var end,
        },
        { --Alchemy
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t"..GetString(SI_TRADESKILLTYPE4),  
        width = "half",
        getFunc = function() return SDC.SV.AQ end,
        setFunc = function(var) SDC.SV.AQ = var end,
        },
        {
        type = "header",
        name = GetString(SI_CHAPTER9),
        },
        { --Solstice Daily
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t "..GetString(SI_BINDING_NAME_AUTORUN),
        width = "full",
        getFunc = function() return SDC.SV.SolsticeAuto end,
        setFunc = function(var) SDC.SV.SolsticeAuto = var end,
        },
        { --Solstice Rapid Switch
        type = "checkbox",
        name = "["..GetString(SI_BINDING_NAME_SPECIAL_MOVE_BLOCK).."] -> "..GetString(SI_PROMPT_TITLE_ABANDON_QUEST),
        tooltip = GetString(SI_CHECK_BUTTON_ON)..": "..GetString(SI_COLLECTIBLE_ACTION_ACCEPT_QUEST).." -> "..GetString(SI_DIALOG_EXIT).."\r\n  ( -> "..
                  GetString(SI_BINDING_NAME_SPECIAL_MOVE_BLOCK).." -> "..GetString(SI_PROMPT_TITLE_ABANDON_QUEST).." ) \r\n  -> "..
                  GetString(SI_GAMECAMERAACTIONTYPE2).." -> "..GetString(SI_QUEST_COMPLETE_CONFIRM_TITLE).."\r\n\r\n"..
                  GetString(SI_CHECK_BUTTON_OFF)..": "..GetString(SI_COLLECTIBLE_ACTION_ACCEPT_QUEST).." -> "..GetString(SI_QUEST_COMPLETE_CONFIRM_TITLE),
        width = "full",
        getFunc = function() return SDC.SV.SolsticeRapid end,
        setFunc = function(var) SDC.SV.SolsticeRapid = var end,
        },
      },
    },
  
    { --Craft
    type = "submenu", 
		name = GetString(SI_SMITHING_TAB_CREATION),
    reference = "SDC_Craft",
		controls = {
        { --DailyCraft
        type = "checkbox",
        name = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t"..GetString(SI_BINDING_NAME_AUTORUN),  
        tooltip = GetString(SI_TIMEDACTIVITYTYPE0),
        width = "half",
        getFunc = function() return SDC.SV.DailyCraft end,
        setFunc = function(var) 
          SDC.SV.DailyCraft = var
          SDC_Craft_Smith.data.disabled = not SDC.SV.DailyCraft
          SDC_Craft_Cook.data.disabled = not SDC.SV.DailyCraft
          SDC_Craft_Enchant.data.disabled = not SDC.SV.DailyCraft
          SDC_Craft_Alchemy.data.disabled = not SDC.SV.DailyCraft
          SDC_Craft_Smith:UpdateDisabled()
          SDC_Craft_Cook:UpdateDisabled()
          SDC_Craft_Enchant:UpdateDisabled()
          SDC_Craft_Alchemy:UpdateDisabled()
        end,
        },
        { --MasterCraft
        type = "checkbox",
        name = "|t25:25:esoui/art/icons/master_writ_alchemy.dds|t "..GetString(SI_BINDING_NAME_AUTORUN),  
        tooltip = GetString(SI_ITEMTYPE60),
        width = "half",
        getFunc = function() return SDC.SV.MasterCraft end,
        setFunc = function(var) SDC.SV.MasterCraft = var end,
        },
        { --Not Close
        type = "checkbox",
        name = GetString(SI_DIALOG_BUTTON_TEXT_QUIT_FORCE),
        width = "full",
        getFunc = function() return not SDC.SV.NotClose end,
        setFunc = function(var) SDC.SV.NotClose = not var end,
        },
        {
        type = "divider",
        alpha = 0.2,
        },
        { --SmithCraft
        type = "checkbox",
        name = GetString(SI_ARMORY_EQUIPMENT_LABEL),  
        width = "half",
        disabled = function() return not SDC.SV.DailyCraft end,
        getFunc = function() return SDC.SV.SmithCraft end,
        setFunc = function(var) SDC.SV.SmithCraft = var end,
        reference = "SDC_Craft_Smith",
        },
        { --CookCraft
        type = "checkbox",
        name = GetString(SI_ITEMTYPEDISPLAYCATEGORY16),  
        width = "half",
        disabled = function() return not SDC.SV.DailyCraft end,
        getFunc = function() return SDC.SV.CookCraft end,
        setFunc = function(var) SDC.SV.CookCraft = var end,
        reference = "SDC_Craft_Cook",
        },
        { --EnchantCraft
        type = "checkbox",
        name = GetString(SI_ITEMTYPEDISPLAYCATEGORY15),  
        width = "half",
        disabled = function() return not SDC.SV.DailyCraft end,
        getFunc = function() return SDC.SV.EnchantCraft end,
        setFunc = function(var) SDC.SV.EnchantCraft = var end,
        reference = "SDC_Craft_Enchant",
        },
        { --AlchemyCraft
        type = "checkbox",
        name = GetString(SI_ITEMTYPEDISPLAYCATEGORY14),  
        width = "half",
        disabled = function() return not SDC.SV.DailyCraft end,
        getFunc = function() return SDC.SV.AlchemyCraft end,
        setFunc = function(var) SDC.SV.AlchemyCraft = var end,
        reference = "SDC_Craft_Alchemy",
        },
      },
    },

    { --Unbox
    type = "submenu", 
		name = GetString(SI_ITEMTYPE18),
    reference = "SDC_Unbox",
    controls = {
        { --Open box
        type = "checkbox",
        name = GetString(SI_INTERFACE_OPTIONS_LOOT_USE_AUTOLOOT),  
        width = "half",
        getFunc = function() return SDC.SV.OpenBox end,
        setFunc = function(var) 
          SDC.SV.OpenBox = var
        end,
        },
        {
        type = "button",
        name = GetString(SI_LEVEL_UP_REWARDS_OPEN_CLAIM_SCREEN_TEXT),
        func = function() EVENT_MANAGER:RegisterForUpdate("SDCWait", 50, SDC.OpenWait) end,
        width = "half",
        reference = "SDC_LAM_BOX_CLAIM",
        },
        { --Add
        type = "dropdown",
        name = GetString(SI_GRAPHICSPRESETS7).." ("..GetString(SI_ITEM_ACTION_ADD_TO_CRAFT)..")", 
        choices = SDC.TF.BagBoxList(),
        tooltip = GetString(SI_PROMPT_TITLE_REMOVE_ITEMS_FROM_CRAFT_BAG).." ("..GetString(SI_GAMEPAD_INVENTORY_STACK_COUNT_BAG_BACKPACK)..")",
        scrollable = true,
        getFunc = function() 
          SDC_LAM_CUSTOM_ADD.data.choices = SDC.TF.BagBoxList()
          SDC_LAM_CUSTOM_ADD:UpdateChoices()
          return "/"
        end,
        setFunc = function(var)
          if var ~= "/" then
            SDC.TF.TableUpsert(SDC.SV.CustomBoxLinks, var)
            SDC.BoxNameDict = SDC.TF.ItemLinksToNameDicts(SDC.BoxLinks, SDC.SV.CustomBoxLinks)
            SDC_LAM_CUSTOM_BOX:UpdateValue()
            SDC_LAM_CUSTOM_REMOVE.data.choices = SDC.TF.CustomBoxList()
            SDC_LAM_CUSTOM_REMOVE:UpdateChoices()
          end
        end,
        width = "half",
        reference = "SDC_LAM_CUSTOM_ADD",
        },
        { --Remove
        type = "dropdown",
        name = GetString(SI_GRAPHICSPRESETS7).." ("..GetString(SI_ITEM_ACTION_REMOVE_FROM_CRAFT)..")", 
        choices = SDC.TF.CustomBoxList(),
        scrollable = true,
        getFunc = function() return "/" end,
        setFunc = function(var)
          if var ~= "/" then
            SDC.TF.TableDelete(SDC.SV.CustomBoxLinks, var)
            SDC.BoxNameDict = SDC.TF.ItemLinksToNameDicts(SDC.BoxLinks, SDC.SV.CustomBoxLinks)
            SDC_LAM_CUSTOM_BOX:UpdateValue()
            SDC_LAM_CUSTOM_REMOVE.data.choices = SDC.TF.CustomBoxList()
            SDC_LAM_CUSTOM_REMOVE:UpdateChoices()
          end
        end,
        width = "half",
        reference = "SDC_LAM_CUSTOM_REMOVE",
        },
        {
          type = "divider",
        },
        { --Custom Box Lists
          type = "description",
          title = GetString(SI_ITEMTYPE18).." ("..GetString(SI_GRAPHICSPRESETS7)..")",
          text = function() return table.concat(SDC.SV.CustomBoxLinks, ", ") end,
          width = "full",
          enableLinks = true,
          reference = "SDC_LAM_CUSTOM_BOX",
        },
        {
          type = "divider",
        },
        {
          type = "description",
          title = GetString(SI_ITEMTYPE18).." ("..GetString(SI_AUDIO_OPTIONS_INTRO_MUSIC_DEFAULT)..")",
          text = function() return table.concat(SDC.BoxLinks, ", ") end,
          width = "full",
          enableLinks = true,
        },
      },
    },

    { --Bank
    type = "submenu", 
		name = GetString(SI_CURRENCYLOCATION1),
    reference = "SDC_Bank",
		controls = {
        { --Bank for comsuble
        type = "checkbox",
        name = GetString(SI_CURRENCYLOCATION1).." -> ".."|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t"..GetString(SI_GAMEPADITEMCATEGORY8),
        tooltip = GetString(SI_TIMEDACTIVITYTYPE0),
        width = "full",
        getFunc = function() return SDC.SV.Bank end,
        setFunc = function(var) SDC.SV.Bank = var end,
        },
        { --Assistant
          type = "checkbox",
          name = GetString(SI_ENTER_CODE_CONFIRM_BUTTON).." ("..GetString(SI_COLLECTIBLECATEGORYTYPE8)..")",
          tooltip = GetString(SI_ACTIONBARSETTINGCHOICE2),
          width = "half",
          getFunc = function() return SDC.SV.OpenBankAssistant end,
          setFunc = function(var) SDC.SV.OpenBankAssistant = var end,
        },
        { --Npc
          type = "checkbox",
          name = GetString(SI_ENTER_CODE_CONFIRM_BUTTON).." ("..GetString(SI_CHAT_CHANNEL_NAME_NPC)..")",
          tooltip = GetString(SI_ACTIONBARSETTINGCHOICE2),
          width = "half",
          getFunc = function() return SDC.SV.OpenBank end,
          setFunc = function(var) SDC.SV.OpenBank = var end,
        },
        { --Close
          type = "checkbox",
          name = GetString(SI_DIALOG_BUTTON_TEXT_QUIT_FORCE),
          tooltip = GetString(SI_ACTIONBARSETTINGCHOICE2),
          width = "full",
          getFunc = function() return SDC.SV.CloseBank end,
          setFunc = function(var) SDC.SV.CloseBank = var end,
        },
      },
    },

    { --Alchemy
    type = "submenu", 
		name = GetString(SI_TRADESKILLRESULT106),
    reference = "SDC_Alchemy",
		controls = {
        { --Which reagent
        type = "dropdown",
        name = GetString(SI_ALCHEMY_REAGENTS_HEADER), 
        choices = TableToLink(SDC.Alchemy["Reagents"]),
        scrollable = true,
        getFunc = function() return "" end,
        setFunc = function(var) Select = var end,
        },
        { --Daily craft banlist
        type = "button",
        name = "|t15:15:esoui/art/castbar/forbiddenaction.dds|t|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t  "..GetString(SI_ALCHEMY_CREATION),
        tooltip = GetString(SI_TIMEDACTIVITYTYPE0),
        func = function()
          SDC.SV.DailyRestrict = BanList(Select, SDC.SV.DailyRestrict)
          SDC_LAM_Desc1.data.text = Desc(SDC.SV.DailyRestrict)
          SDC_LAM_Desc2.data.text = Desc(SDC.SV.DailyRawRestrict)
          SDC_LAM_Desc3.data.text = Desc(SDC.SV.MasterRestrict)
          SDC_LAM_Desc1:UpdateValue()
          SDC_LAM_Desc2:UpdateValue()
          SDC_LAM_Desc3:UpdateValue()
        end,
        width = "half",	
        },
        { --Daily commit banlist
        type = "button",
        name = "|t15:15:esoui/art/castbar/forbiddenaction.dds|t|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t  "..GetString(SI_GAMEPAD_TRADE_SUBMIT),
        tooltip = GetString(SI_TIMEDACTIVITYTYPE0),
        func = function()
          SDC.SV.DailyRawRestrict = BanList(Select, SDC.SV.DailyRawRestrict)
          SDC_LAM_Desc1.data.text = Desc(SDC.SV.DailyRestrict)
          SDC_LAM_Desc2.data.text = Desc(SDC.SV.DailyRawRestrict)
          SDC_LAM_Desc3.data.text = Desc(SDC.SV.MasterRestrict)
          SDC_LAM_Desc1:UpdateValue()
          SDC_LAM_Desc2:UpdateValue()
          SDC_LAM_Desc3:UpdateValue()
        end,
        width = "half",	
        },
        { --Daily craft Banlist
        type = "description",
        title = "|t15:15:esoui/art/castbar/forbiddenaction.dds|t|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t  "..GetString(SI_ALCHEMY_CREATION),
        text = Desc(SDC.SV.DailyRestrict),
        width = "half",
        enableLinks = true,
        reference = "SDC_LAM_Desc1",
        },
        { --Daily raw Banlist
        type = "description",
        title = "|t15:15:esoui/art/castbar/forbiddenaction.dds|t|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t  "..GetString(SI_GAMEPAD_TRADE_SUBMIT),
        text = Desc(SDC.SV.DailyRawRestrict),
        width = "half",
        enableLinks = true,
        reference = "SDC_LAM_Desc2",
        },
        { --Master craft banlist
        type = "button",
        name = "|t15:15:esoui/art/castbar/forbiddenaction.dds|t|t25:25:esoui/art/icons/master_writ_alchemy.dds|t  "..GetString(SI_ALCHEMY_CREATION),
        tooltip = GetString(SI_ITEMTYPE60),
        func = function() 
          SDC.SV.MasterRestrict = BanList(Select, SDC.SV.MasterRestrict)
          SDC_LAM_Desc1.data.text = Desc(SDC.SV.DailyRestrict)
          SDC_LAM_Desc2.data.text = Desc(SDC.SV.DailyRawRestrict)
          SDC_LAM_Desc3.data.text = Desc(SDC.SV.MasterRestrict)
          SDC_LAM_Desc1:UpdateValue()
          SDC_LAM_Desc2:UpdateValue()
          SDC_LAM_Desc3:UpdateValue()
        end,
        width = "half",	
        },
        { --Master Banlist
        type = "description",
        title = "|t15:15:esoui/art/castbar/forbiddenaction.dds|t|t25:25:esoui/art/icons/master_writ_alchemy.dds|t  "..GetString(SI_ALCHEMY_CREATION),
        text = Desc(SDC.SV.MasterRestrict),
        width = "half",
        enableLinks = true,
        reference = "SDC_LAM_Desc3",
        },
      },
    },
    
    { --Style
    type = "submenu", 
		name = GetString(SI_ITEMFILTERTYPE19),
    reference = "SDC_Style",
		controls = {
        { --Which reagent
        type = "dropdown",
        name = GetString(SI_ITEMFILTERTYPE19), 
        choices = SytleMaterials(),
        choicesValues = select(2, SytleMaterials()),
        scrollable = true,
        getFunc = function() return "" end,
        setFunc = function(var) Select2 = var end,
        width = "half",
        },
        { --Add/Delete
        type = "button",
        name = GetString(SI_GAMEPAD_MAIL_SEND_ATTACH_ITEM).." / "..GetString(SI_GAMEPAD_MAIL_SEND_CLEAR),
        tooltip = GetString(SI_TIMEDACTIVITYTYPE0),
        func = function() 
          if SDC.SV.StyleList[Select2] then
            SDC.SV.StyleList[Select2] = nil
          else
            SDC.SV.StyleList[Select2] = GetItemLinkItemId(GetItemStyleMaterialLink(Select2))
          end
          SDC_LAM_Desc4.data.text = Desc2(SDC.SV.StyleList)
          SDC_LAM_Desc4:UpdateValue()
        end,
        width = "half",	
        },
        { --Style List
        type = "description",
        title = "|t25:25:esoui/art/journal/gamepad/gp_questtypeicon_repeatable.dds|t "..GetString(SI_SMITHING_TAB_CREATION),
        text = Desc2(SDC.SV.StyleList),
        width = "full",
        enableLinks = true,
        reference = "SDC_LAM_Desc4",
        },
      },
    },
	}
	LAM:RegisterOptionControls(SDC.name.."_Options", options)
end