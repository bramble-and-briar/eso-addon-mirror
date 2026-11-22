TBUG = {}
local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

--Version and name of the AddOn
tbug.version =  "1.75"
tbug.name =     "merTorchbug"
tbug.author =   "merlight, current: Baertram"


------------------------------------------------------------------------------------------------------------------------
-- TODOs, planned features and known bugs
------------------------------------------------------------------------------------------------------------------------
--
-- [Cursors]
--[[
/esoui/art/cursors/cursor_champbasic.dds
/esoui/art/cursors/cursor_champmage.dds
/esoui/art/cursors/cursor_champsubcon.dds
/esoui/art/cursors/cursor_champthief.dds
/esoui/art/cursors/cursor_champwarrior.dds
/esoui/art/cursors/cursor_default.dds
/esoui/art/cursors/cursor_erase.dds
/esoui/art/cursors/cursor_fill.dds
/esoui/art/cursors/cursor_hand.dds
/esoui/art/cursors/cursor_iconoverlay.dds
/esoui/art/cursors/cursor_nextleft.dds
/esoui/art/cursors/cursor_nextright.dds
/esoui/art/cursors/cursor_paint.dds
/esoui/art/cursors/cursor_pan.dds
/esoui/art/cursors/cursor_preview.dds
/esoui/art/cursors/cursor_resizeew.dds
/esoui/art/cursors/cursor_resizenesw.dds
/esoui/art/cursors/cursor_resizens.dds
/esoui/art/cursors/cursor_resizenwse.dds
/esoui/art/cursors/cursor_rotate.dds
/esoui/art/cursors/cursor_sample.dds
/esoui/art/cursors/cursor_setfill.dds
]]

-- [Known bugs]
--Global inspector Fonts tab does not show the fonts in correct size until scrolled
--New opened inspector get their icons top right changed in size if font size at global inspector context menu is changed, but it does not always change back (at all opened inspector windows!) to new font size if changed later
--20250107 Warning: tbugGlobalInspectorTabsContainerTab2 has a set height but has resizeToFitDescendents enabled. If this is intended, use resizeToFitConstrains="X".|r
--20250330 Entering in chat editbox: GetItemRewardItemLink('|H1:item:119704:5:1:0:0:0:199:13:23:2:0:0:0:0:0:0:0:0:0:0:50000|h|h') raises an error Checking type on argument rewardId failed in GetItemRewardItemLink_lua

-- [Planned features]


-- [Working on]
--EVENT_DISPLAY_ACTIVE_COMBAT_TIP 131531 shows as EVENT_TUTORIAL_TRIGGER_COMPLETED 131535 in the (saved) events data? _eventName is wrong, _eventId is correct. Name and id do not match?
--->local lookupEventName = tbug.Events.eventList


--------------------------------------- Version 1.75 - Baertram (last updated 2025-01-12)
---- [Added]
--Libraries detection via "lib" prefix
--Added context menu enties to the events e/E char at the title bar (and at the event inspector rows):
---Start/Stop event tracking
---Setting to automatically start the event tracking as addon loads (button to enable that and reload the UI now)
---Save and load events tracked. Load shows them in an extra inspector using the eventviewer layout so you can compare them to current event viewer's tracked events
--Objects, class & libs detection at context menu so one can send <object or lib>:<functionName> or <.variableName> to scripts tab
--ScriptsViewer inspector: Created new ScriptsViewer inspector(s) able to run scripts in a separate window
--Added ScriptsViewer contextmenu to saved script history to open it in a new ScriptsViewer inspector


---- [Fixed]
--Some XML fixed height and width values versus resizeToFitDescendents ESO log errors
--Show chat output only if TBUG.doDebug == true
--Scrolling tabs won't resize to invisibly small anymore if window size is changed to very small (or below 0), or if many tabs added
--Fixed delayed calls to slash commands to accept negative values

--
------------------------------------------------------------------------------------------------------------------------

local stringType = "string"
local numberType = "number"
local functionType = "function"
local tableType = "table"
local userDataType = "userdata"
local structType = "struct"
tbug.types = {}
local types = tbug.types
types.string = stringType
types.number = numberType
types.func = functionType
types.table = tableType
types.userdata = userDataType
types.struct = structType


--Global inspector default and min/max width/height values
tbug.defaultInspectorWindowWidth        = 760
tbug.defaultInspectorWindowHeight       = 800

tbug.minInspectorWindowWidth            = 250
tbug.minInspectorWindowHeight           = 50

tbug.maxInspectorTexturePreviewWidth    = 400
tbug.maxInspectorTexturePreviewHeight   = 400

tbug.maxScriptKeybinds = 5

--Shows that the rightKey shows the name for the leftKey, and not for the value
local prefixForLeftKey = "<- "
tbug.prefixForLeftKey = prefixForLeftKey


tbug.unitConstants = {
    player = "player"
}

--The megasevers and the testserver
tbug.servers = {
    "EU Megaserver",
    "NA Megaserver",
    "PTS",
}
tbug.serversShort = {
    ["EU Megaserver"] = "EU",
    ["NA Megaserver"] = "NA",
    ["PTS"] = "PTS",
}

--Global SavedVariable table suffix to test for existance
local svSuffix = {
    "SavedVariables",
    "SavedVariables2",
    "SavedVars",
    "SavedVars2",
    "SV",
    "SV2",
    "Settings",
    "_Data",
    "_SV",
    "_SV2",
    "_SavedVariables",
    "_SavedVariables2",
    "_SavedVars",
    "_SavedVars2",
    "_Settings",
    "_Settings2",
    "_Opts",
    "_Opts2",
    "_Options",
    "_Options2",
}
tbug.svSuffix = svSuffix

--Comparison string for libraries name "start"
local libraryPrefixComparisonVar = "lib"
tbug.libraryPrefixComparisonVar = libraryPrefixComparisonVar

--Table of library names (key) to _G variable (value)
local specialLibraryGlobalVarNames = {
    ["CustomCompassPins"]           = "COMPASS_PINS",
    ["libCommonInventoryFilters"]   = "LibCIF",
    ["LibBinaryEncode"]             = "LBE",
    ["LibNotification"]             = "LibNotifications",
    ["LibScootworksFunctions"]      = "LIB_SCOOTWORKS_FUNCTIONS",
    ["NodeDetection"]               = "LibNodeDetection",
    ["LibGPS"]                      = "LibGPS2",
}
tbug.specialLibraryGlobalVarNames = specialLibraryGlobalVarNames


--SavedVariables table names that do not match the standard suffix
tbug.svSpecialTableNames = {
    "AddonProfiles_SavedVariables2",    --AddonProfiles
    "ADRSV",                            --ActionDurationReminder
}

--Patterns for a string.match to find supported inventory rows (for their dataEntry.data subtables), or other controls
--like the e.g. character equipment button controls
local inventoryRowPatterns = {
    "^ZO_%a+Backpack%dRow%d%d*",                                            --Inventory backpack
    "^ZO_%a+InventoryList%dRow%d%d*",                                       --Inventory backpack
    "^ZO_CharacterEquipmentSlots.+$",                                       --Character
    "^ZO_CraftBagList%dRow%d%d*",                                           --CraftBag
    "^ZO_Smithing%aRefinementPanelInventoryBackpack%dRow%d%d*",             --Smithing refinement
    "^ZO_RetraitStation_%a+RetraitPanelInventoryBackpack%dRow%d%d*",        --Retrait
    "^ZO_QuickSlotList%dRow%d%d*",                                          --Quickslot
    "^ZO_RepairWindowList%dRow%d%d*",                                       --Repair at vendor
    "^ZO_ListDialog1List%dRow%d%d*",                                        --List dialog (Repair, Recharge, Enchant, Research, ...)
    "^ZO_CompanionEquipment_Panel_.+List%dRow%d%d*",                        --Companion Inventory backpack
    "^ZO_CompanionCharacterWindow_.+_TopLevelEquipmentSlots.+$",            --Companion character
    "^ZO_UniversalDeconstructionTopLevel_%a+PanelInventoryBackpack%dRow%d%d*",--Universal deconstruction
}
tbug.inventoryRowPatterns = inventoryRowPatterns

--Special keys at the inspector list, which add special contextmenu entries
local specialEntriesAtInspectorLists = {
    ["bagId"]       = true,
    ["slotIndex"]   = true,
}
tbug.specialEntriesAtInspectorLists = specialEntriesAtInspectorLists

local customKeysForInspectorRows = {
    ["object"] =        "__Object",
    ["usedInScenes"] =  "__usedInScenes",
    ["__isClass"] =     "__isClass",
    ["__isObject"] =    "__isObject",
}
tbug.customKeysForInspectorRows = customKeysForInspectorRows

--Special colors for some entries in the object inspector (key)
-->See file savedvars.lua, table defaults.typeColors
local specialKeyToColorType = {
    ["LibStub"] = "obsolete",
    [customKeysForInspectorRows.object] = "object",
    [customKeysForInspectorRows.usedInScenes] = "sceneName",
    [customKeysForInspectorRows.__isClass] = "__isClass",
    [customKeysForInspectorRows.__isObject] = "__isObject",
}
tbug.specialKeyToColorType = specialKeyToColorType

--Keys of entries in tables which normally are used for a GetString() value
local getStringKeys = {
    ["text"]        = true,
    ["defaultText"] = true,
}
tbug.getStringKeys = getStringKeys

--For the __Object/Control: Do not use :GetName() function on controls/tables which got these entries/Attributes
local doNotGetParentInvokerNameAttributes = {
    ["sceneManager"] = true,
}
tbug.doNotGetParentInvokerNameAttributes = doNotGetParentInvokerNameAttributes

local dummy = {}
--Special master list types used to get another class for the inspector
--e.g. ["ScriptsViewer"] = ScriptsInspector,
tbug.specialMasterListType2InspectorClass = {
    ["ScriptsViewer"] = dummy, --Will be updated with ScriptsInspector once that class exists -> see scriptsinspector.lua
}

--The possible panel class names for the different inspectorTabs. Each panelClassName (key of this table) will be assigned to
--one value (later on in folder classes, file basicinspector.lua/tableinspector.lua/controlinspector.lua/objectinspector.lua
--etc. at the top of the files) -> The here assigned "dummy" table will be overwritten there with the actual "class" table reference
--This table key and value will be used in function GlobalInspector:makePanel!
--The default class, if non was provided in function GlobalInspector:makePanel, will be "GlobalInspectorPanel"
tbug.panelClassNames = {
    --Default tabs at global inspector
    ["basicInspector"] = dummy,
    ["globalInspector"] = dummy,
    ["tableInspector"] = dummy,
    ["controlInspector"] = dummy,
    ["objectInspector"] = dummy,
    --Custom tabs at global inspector
    ["scriptInspector"] = dummy, --Used for the GlobalInspector -> "Scripts" tab -> Updated with ScriptsInspectorPanel
    ["savedInspectors"] = dummy, --Used for the GlobalInspector -> "SavedInsp" tab
}

--The panel names for the global inspector tabs: Used at "GlobalInspector:makePanel"
--Index of the table = tab's index
--Key:  the tab's internal key value
--Name: the tab's name shown at the label to select the tab and used to find the tab via tbug.inspectorSelectTabByName
--slashCommand: A table with valid slash commands used in the chat edit box to show the tab, e.g /tb events -> show the "events" tab, or /tb fragm show the Fragments tab
-->Additional slashCommands like /tbe (events) might exists to open those same panesls! See file modules/main.lua
--lookup:   Used to map the entered slashcommand (1st character will be turned to uppercase) to the tab's name (if they do not match by default)
-->         e.g. slash command /tbs -> uses "sv" as search string, 1st char turned to upper -> Sv, but the tab's anem is SV (both upper) -> lookup fixes this
--comboBoxFilters:  If true this tab will provide a multi select combobox filter. The entries are defined at the globalinspector.lua->function selectTab,
-->                 and the values will defined there, e.g. CT_* control types at teh controls tab
--panelClassName: The panelClass name that should be used for that panel. The class is a lua OO class (metatables table object) defined in folder "classes".
-->If left nil the default panel class "GlobalInspectorPanel" will be used. If you specify a name you must use one of the keys provided in table tbug.panelClassNames!
-->The panel class name defines the XML virtual template name used to create the panel control via "GlobalInspector:makePanel", at the file e.g. classes/scriptsinspectorpanel.lua
-->attribute ScriptsInspectorPanel.TEMPLATE_NAME
--async:    Boolean to control if the panel's scroll list should be build with LibAsync (if enabled) or not (e.g. classes, constants, conrols got so many entries that the client lags
-->if the tab gets activated)
--
--Usage: See function GlobalInspector:refresh()
local panelNames = {
    [1]  = { key="addons",         name="AddOns",          slashCommand={"addons"},                            lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false, },
    [2]  = { key="classes",        name="Classes",         slashCommand={"classes"},                           lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false, },
    [3]  = { key="objects",        name="Objects",         slashCommand={"objects"},                           lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [4]  = { key="controls",       name="Controls",        slashCommand={"controls"},                          lookup=nil,      comboBoxFilters=true,   panelClassName=nil, async=false,  },
    [5]  = { key="fonts",          name="Fonts",           slashCommand={"fonts"},                             lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [6]  = { key="functions",      name="Functions",       slashCommand={"functions"},                         lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [7]  = { key="constants",      name="Constants",       slashCommand={"constants"},                         lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [8]  = { key="strings",        name="Strings",         slashCommand={"strings"},                           lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [9]  = { key="sounds",         name="Sounds",          slashCommand={"sounds"},                            lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [10] = { key="dialogs",        name="Dialogs",         slashCommand={"dialogs"},                           lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [11] = { key="scenes",         name="Scenes",          slashCommand={"scenes"},                            lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [12] = { key="fragments",      name="Fragm.",          slashCommand={"fragments", "fragm.", "fragm"},      lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [13] = { key="libs",           name="Libs",            slashCommand={"libs"},                              lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false,  },
    [14] = { key="scriptHistory",  name="Scripts",         slashCommand={"scripts"},                           lookup=nil,      comboBoxFilters=nil,    panelClassName = "scriptInspector", async=false, },
    [15] = { key="events",         name="Events",          slashCommand={"events"},                            lookup=nil,      comboBoxFilters=nil,    panelClassName=nil, async=false, },
    [16] = { key="sv",             name="SV",              slashCommand={"sv"},                                lookup= "Sv",    comboBoxFilters=nil,    panelClassName=nil, async=false, },
    [17] = { key="savedInsp",      name="SavedInsp",       slashCommand={"savedinsp"},                         lookup= nil,     comboBoxFilters=nil,    panelClassName= "savedInspectors", async=false, },
}
tbug.panelNames = panelNames
tbug.panelCount = NonContiguousCount(panelNames)
tbug.filterComboboxFilterTypesPerPanel = {} --for the filter comboBox dropdown entries, see file glookup.lua function doRefresh for the fill

--The string prefix for special /tb <specialInspectTabTitle> calls
local specialInspectTabTitles = {
    ["listtlc"] = { --Calls function ListTLC()
        tabTitle =          "TLCs of GuiRoot",
        functionToCall =    "TBUG_ListTLC()",
    }
}
tbug.specialInspectTabTitles = specialInspectTabTitles


--The possible search modes at teh global inspector
local filterModes = { "str", "pat", "val", "con", "key" }
tbug.filterModes = filterModes

--The rowTypes ->  the ZO_SortFilterScrollList DataTypes
-->Make sure to add this to TableInspectorPanel:initScrollList(control) at the bottom, self:addDataType
-->and to TableInspectorPanel:buildMasterListSpecial(),
-->and to GlobalInspector:refresh()
local rt = {}
rt.GENERIC = 1
rt.FONT_OBJECT = 2
rt.LOCAL_STRING = 3
rt.SOUND_STRING = 4
rt.LIB_TABLE = 5
rt.SCRIPTHISTORY_TABLE = 6
rt.ADDONS_TABLE = 7
rt.EVENTS_TABLE = 8
rt.SAVEDVARIABLES_TABLE = 9
rt.SCENES_TABLE = 10
rt.FRAGMENTS_TABLE = 11
rt.SAVEDINSPECTORS_TABLE = 12
tbug.RT = rt

--The rowTypes that need to return another value than the key via "raw copy" context menu, and which need to use another
--dataEntry or value attribute for the string search
local rtSpecialReturnValues = {}
rtSpecialReturnValues[rt.ADDONS_TABLE] = {replaceName="value.name"}
rtSpecialReturnValues[rt.EVENTS_TABLE] = {replaceName="value._timeStamp", replaceFunc=function() return tbug.formatTimestamp end} --"value._eventName"
rtSpecialReturnValues[rt.LOCAL_STRING] = {replaceName="keyText"}
tbug.RTSpecialReturnValues = rtSpecialReturnValues

--The enumeration prefixes which should be skipped
tbug.nonEnumPrefixes = {
    ["ABILITY_"] = true,
    ["ACTION_"] = true,
    ["ACTIVE_"] = "_SETTING_ID$",
    ["COLLECTIBLE_"] = true,
    ["GAMEPAD_"] = true,
    ["GROUP_"] = true,
    ["INFAMY_"] = true,
    ["MAIL_"] = true,
    ["QUEST_"] = true,
    ["RAID_"] = true,
    ["STAT_"] = "^STAT_STATE_",
    ["TRADE_"] = true,
    ["TUTORIAL_"] = true,
    ["UI_"] = true,
    ["VOICE_"] = "^VOICE_CHAT_REQUEST_DELAY$",
}

--Texture string entries in the inspectors for the OnMouseEnter, see basicinspector -> BasicInspectorPanel:onRowMouseEnter
tbug.textureNamesSupported = {
    ["textureFileName"] = true,
    ["iconFile"] = true,
}

--Table inspector row key's string which relate to timestamps -> Should show the timestamp value as cKeyRight date formatted then
tbug.timeStampKeyPatterns = {
    [1] = "timestamp",
    --[2] = "gametime",
    --[3] = "frametime",
}

--The inspector title constants/patterns
tbug.titlePatterns = {
    --Inspector title templates
    normalTemplate          =  "%s",
    mouseOverTemplate       = "[MOC_%s]",

    --For title string to chat cleanUp
    --removes e.g. .__index
    title2ChatCleanUpIndex =            '%.__index',
    --removes e.g. »Child:
    title2ChatCleanUpChild =            '%»Child%:%s*',
    --removes e.g. --Remove suffix "colored table or userdata" like " <|c86bff9table: 0000020E4A8004F0|r|r>"
    title2ChatCleanUpTableAndColor =    '%s?%<?%|?c?%w*%:%s?%w*%|?r?|?r?%>?'
}



--The list controls (ZO_ScrollList) of the inspector panels. Will be added upon creation of the panels
--and removed as the panel is destroyed
tbug.inspectorScrollLists = {}

--Inspector row keys that should enable a number slider if you right click the row value to change it
--e.g. "condition"
--Table key = "key of the row e.g. condition" / value = table {min=0, max=1, step=0.1} of the slider
tbug.isSliderEnabledByRowKey = {
    ["condition"] = {min=1, max=100, step=1},
}

--Table with itemLink function names
tbug.functionsItemLink = {}
tbug.functionsItemLinkSorted = {}

--URL patterns for online searches
tbug.searchURLs = {
    ["github"] = "https://github.com/search?q=repo:esoui/esoui %s&type=code",
}


--Enumerations setup for the glookup.lua which reads global table _G and prepares the tbug enumrations so that they
--can show real strings like BAG_BACKPACK instead of value 1
local keyToEnums = {
    ["actorCategories"]         = "GameplayActorCategories",
    ["anchorConstrains"]        = "AnchorConstrains",
    ["addressMode"]             = "TEX_MODE",
    ["blendMode"]               = "TEX_BLEND_MODE",
    ["bag"]                     = "Bags",
    ["bagId"]                   = "Bags",
    ["buttonState"]             = "BSTATE",
    ["horizontalAlignment"]     = "TEXT_ALIGN_horizontal",
    ["layer"]                   = "DL_names",
    ["modifyTextType"]          = "MODIFY_TEXT_TYPE",
    ["parent"]                  = "CT_names",
    ["point"]                   = "AnchorPosition",
    ["relativePoint"]           = "AnchorPosition",
    ["relativeTo"]              = "CT_names",
    ["tier"]                    = "DT_names",
    ["type"]                    = "CT_names",
    ["verticalAlignment"]       = "TEXT_ALIGN_vertical",
--    ["wrapMode"]                = "TEXT_WRAP_MODE", --there is no GetWrapMode function at CT_LABEL :-(
}
tbug.keyToEnums = keyToEnums

local keyToSpecialEnumTmpGroupKey = {
    ["bagId"]                   = "BAG_",
    ["functionalQuality"]       = "ITEM_",
    ["displayQuality"]          = "ITEM_",
    ["equipType"]               = "EQUIP_",
    ["itemType"]                = "ITEMTYPE_",
    ["quality"]                 = "ITEM_",
    ["specializedItemType"]     = "SPECIALIZED_",
    ["traitInformation"]        = "ITEM_",
    ["traitType"]               = "ITEM_",
}
tbug.keyToSpecialEnumTmpGroupKey = keyToSpecialEnumTmpGroupKey

local keyToSpecialEnumExclude = {
    ["traitInformation"]        = {"ITEM_TRAIT_TYPE_CATEGORY_"},
}
tbug.keyToSpecialEnumExclude = keyToSpecialEnumExclude

--These entries will "record" all created subTables in function makeEnum so that one can combine them later on in
--g_enums["SPECIALIZED_ITEMTYPE"] again for 1 consistent table with all entries
local keyToSpecialEnumNoSubtablesInEnum = {
    ["SPECIALIZED_ITEMTYPE_"]        = true,
}
tbug.keyToSpecialEnumNoSubtablesInEnum = keyToSpecialEnumNoSubtablesInEnum

local keyToSpecialEnum = {
    --Special key entries at tableInspector
    ["actorCategory"]           = keyToEnums["actorCategories"],
    ["bagId"]                   = keyToEnums["bagId"],
    ["functionalQuality"]       = "ITEM_FUNCTIONAL_QUALITY_",
    ["displayQuality"]          = "ITEM_DISPLAY_QUALITY_",
    ["equipType"]               = "EQUIP_TYPE_",
    ["itemType"]                = "ITEMTYPE_",
    ["quality"]                 = "ITEM_QUALITY_",
    ["specializedItemType"]     = "SPECIALIZED_ITEMTYPE_",
    ["traitInformation"]        = "ITEM_TRAIT_INFORMATION_",
    ["traitType"]               = "ITEM_TRAIT_TYPE_",
}
tbug.keyToSpecialEnum = keyToSpecialEnum

local keyToSpecialRightKeyFunc = {
    --Special key entries at tableInspector: Value is a fucntion which returns the value for the right key
    ["uniqueId"]                = zo_getSafeId64Key,
}
tbug.keyToSpecialRightKeyFunc = keyToSpecialRightKeyFunc

local isSpecialInspectorKey = {}
for k,_ in pairs(keyToSpecialEnum) do
    isSpecialInspectorKey[k] = true
end
for k,_ in pairs(keyToSpecialRightKeyFunc) do
    isSpecialInspectorKey[k] = true
end
tbug.isSpecialInspectorKey = isSpecialInspectorKey

--Special tab titles (clean) which control if the key at teh insepctor should show someting in addition at the keyRight
-->key must be a number/index so you define the order of the checked patterns! Table entry must have "pattern" and "enum":
-->pattern is the lua pattern to find the key's name in the inspector / ENUM name from table TBUG.ENUMS that will be used to show the ckeyRight

local specialTabTitleCleanAtInspectorLists = {
    [1] = {
        pattern = "bagTo(.*)", enum = "Bags",  --e.g. bagToInventory
    },
    [2] = {
        pattern = "bag2(.*)", enum = "Bags",  --e.g. bag2*
    },
    [3] = {
        pattern = "bagIdTo(.*)", enum = "Bags",  --e.g. bagIdTo*
    },
    [4] = {
        pattern = "bagId2(.*)", enum = "Bags",  --e.g. bagId2*
    },
    [5] = {
        pattern = "(.*)Bags", enum = "Bags",  --e.g. backingBags
    },
    [6] = {
        pattern = "[sS][pP][eE][cC][iI][aA][lL][iI][zZ][eE][dD][iI][tT][eE][mM][tT][yY][pP][eE]", enum = "SPECIALIZED_ITEMTYPE",  --e.g. specializedItemType
    },
    [7] = {
        pattern = "[iI][tT][eE][mM][tT][yY][pP][eE]", enum = "ITEMTYPE",  --e.g. itemType
    },
}
tbug.specialTabTitleCleanAtInspectorLists = specialTabTitleCleanAtInspectorLists

--The possible keys used for basicinspector function isTranslationTextRow() -> checking for ESOStrings or descriptor entries of ZO_MainMenu buttons etc.
local possibleTranslationTextKeys = {
    ["descriptor"] = true,
}
tbug.possibleTranslationTextKeys = possibleTranslationTextKeys

local classIdentifierKeys = {
    ["__isClass"] = true, -- added by tbug in global inspector buildMasterList
    ["__isAbstractClass"] = true,
    ["__parentClasses"] = true,
}
tbug.classIdentifierKeys = classIdentifierKeys

--Lookup tables for different types
tbug.LookupTabs = {}
tbug.LookupTabs["_G"] = {}      --> See file glookup.lua, g_objects
tbug.LookupTabs["class"] = {}
tbug.LookupTabs["object"] = {}
tbug.LookupTabs["library"] = {}


--LibScrollableMenu context menu default options
tbug.defaultScrollableContextMenuOptions = {
    visibleRowsDropdown =   15,
    visibleRowsSubmenu =    15,
    sortEntries =           false,
    enableFilter =          true,
    headerCollapsible =     true,
}

--tbug.realESOEventNames = realESOEventNames

--EVENT_' eventIds which have been blacklisted and should not be added to the event tracking
local blacklistedEventIds = {
    [EVENT_GLOBAL_MOUSE_UP] = true,
    [EVENT_GLOBAL_MOUSE_DOWN] = true,
}
tbug.blacklistedEventIds = blacklistedEventIds

--ESO eventIds which have been renamed
local realESOEventNames = {
    [EVENT_GUILD_MEMBER_CHARACTER_VETERAN_RANK_CHANGED] = "EVENT_GUILD_MEMBER_CHARACTER_CHAMPION_POINTS_CHANGED",
    --[VETERAN_POINTS_UPDATE] = "EVENT_CHAMPION_POINT_UPDATE", --VETERAN_POINTS_UPDATE = CHAMPION_POINT_UPDATE in addon comp, but CHAMPION_POINT_UPDATE is nil
    [EVENT_RESURRECT_FAILURE] = "EVENT_RESURRECT_RESULT",
    [EVENT_DIFFICULTY_LEVEL_CHANGED] = "EVENT_CADWELL_PROGRESSION_LEVEL_CHANGED",
    [EVENT_FRIEND_CHARACTER_VETERAN_RANK_CHANGED] = "EVENT_FRIEND_CHARACTER_CHAMPION_POINTS_CHANGED",
    [VETERAN_POINTS_GAIN] = "EVENT_EXPERIENCE_GAIN",
    [EVENT_COLLECTIBLE_ON_COOLDOWN] = "EVENT_COLLECTIBLE_USE_RESULT",
    [EVENT_COLLECTIBLE_USE_BLOCKED] = "EVENT_COLLECTIBLE_USE_RESULT",
    [EVENT_CLAIM_LEVEL_UP_REWARD_RESULT] = "EVENT_CLAIM_REWARD_RESULT",
    [EVENT_SKILL_ABILITY_PROGRESSIONS_UPDATED] = "EVENT_SKILLS_FULL_UPDATE",
    [EVENT_ACTION_SLOTS_FULL_UPDATE] = "EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED",
    [EVENT_ACTION_BAR_SLOTTING_ALLOWED_STATE_CHANGED] = "EVENT_ACTION_BAR_IS_RESPECCABLE_BAR_STATE_CHANGED",
    [EVENT_HELP_SHOW_SPECIFIC_PAGE] = "EVENT_SHOW_SPECIFIC_HELP_PAGE",
}
tbug.realESOEventNames = realESOEventNames

--Template data for the UI controls, e.g. list font and rowHeight (via virtual XML template names)
--Used in function basicinspector:addDataType (to add the row datatypes for the ZO_ScrollLists)
-->Switched in global inspector context menu at tbug icon -> font & size
tbug.UITemplates = {
	{ -- font 13
		name = "default",
		font = "ZoFontGameSmall",
		height = 23,
	},
	{ -- font 18
		name = "ZoFontGameLarge",
		font = "ZoFontGameLarge",
		height = 28,
	},
	{
		name = "ZoFontGamepadBold18",
		font = "ZoFontGamepadBold18",
		height = 28,
	},
	{ -- font 25
		name = "ZoFontGamepadBold20",
		font = "ZoFontGamepadBold20",
		height = 30,
	},
	{ -- font 25
		name = "ZoFontGamepadBold22",
		font = "ZoFontGamepadBold22",
		height = 32,
	},
	{ -- font 25
		name = "ZoFontGamepadBold25",
		font = "ZoFontGamepadBold25",
		height = 35,
	},
	{ -- font 25
		name = "ZoFontGamepadBold27",
		font = "ZoFontGamepadBold27",
		height = 37,
	}
}

