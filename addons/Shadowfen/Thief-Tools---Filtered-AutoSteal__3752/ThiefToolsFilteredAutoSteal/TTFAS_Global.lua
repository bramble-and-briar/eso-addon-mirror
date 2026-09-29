local SF = LibSFUtils

TTFAS = ZO_Object:Subclass()

TTFAS.version = "1.3.10"
TTFAS.name = "TTFAS"
TTFAS.settingName = "ThiefTools - Filtered Auto Steal"
TTFAS.settingDisplayName = "ThiefTools - Filtered Auto Steal"
TTFAS.author = "Shadowfen"

TTFAS.settingDisplayName = SF.colors.gold(TTFAS.settingDisplayName)
TTFAS.version = SF.colors.gold(TTFAS.version)
TTFAS.author = SF.colors.purple(TTFAS.author)

TTFAS.StartupInfo = false

TTFAS.currentProfile = {}

-- load in localization strings
SF.LoadLanguage(TTFAS_localization_strings, "en")

-- Create the delayed instantiation logger functor and utility functions for ThiefTools.
TTFASLogger, TTFAS.logDebug, TTFAS.logWouldDebug = 
            SF.InitSafeLogger(TTFAS, "logger", "TTFAS")

--[[ The following SetDebug() call is commented out because it severely slows down 
    addon operation. Turning it on does however provide lots and lots of debug logging.
    Never leave this uncommented when releasing!!
--]]
TTFASLogger():SetDebug(true)

-- Create a lookup table for dropdown values
FAS_NEVER = 1
FAS_ALWAYS = 2
FAS_TAKE_ALL = 3
FAS_JUST_OPEN = 4
FAS_FOLLOW = 5
FAS_UNKNOWN = 6
FAS_UNKNOWN_BY_ANY = 7
FAS_MIN_QUALITY = 8
FAS_MIN_VALUE = 9
FAS_TTC_MIN_VALUE = 10
FAS_UNCOLLECTED = 11
FAS_COLLECTED = 12
FAS_TYPE_BASED = 13
FAS_NON_BASE_ZONE = 14
FAS_NON_RACIAL = 15
FAS_FILLED = 16
FAS_UNFILLED = 17
FAS_NORMAL_POTIONS = 18
FAS_POTENT_POTIONS = 19

FASFV = SF.DDValueTable:New()
FASFV:add(FAS_NEVER, "never take", TTFAS_NEVER_TAKE)
FASFV:add(FAS_ALWAYS, "always take", TTFAS_ALWAYS_TAKE)
FASFV:add(FAS_TAKE_ALL, "take all items", TTFAS_TAKE_ALL)
FASFV:add(FAS_JUST_OPEN, "just open", TTFAS_JUST_OPEN)
FASFV:add(FAS_FOLLOW, "follow rules", TTFAS_FOLLOW)
FASFV:add(FAS_UNKNOWN, "unknown by me", TTFAS_UNKNOWN_BY_ME)
FASFV:add(FAS_UNKNOWN_BY_ANY, "unknown by any", TTFAS_UNKNOWN_BY_ANY)
FASFV:add(FAS_MIN_QUALITY, "min quality", TTFAS_MIN_QUALITY)
FASFV:add(FAS_MIN_VALUE, "min value", TTFAS_MIN_VALUE)
FASFV:add(FAS_TTC_MIN_VALUE, "min TTC value", TTFAS_TTC_MIN_VALUE)
FASFV:add(FAS_UNCOLLECTED, "uncollected", TTFAS_UNCOLLECTED)
FASFV:add(FAS_COLLECTED, "collected", TTFAS_COLLECTED)
FASFV:add(FAS_TYPE_BASED, "type based", TTFAS_TYPE_BASED)
FASFV:add(FAS_NON_BASE_ZONE, "dlc zone", TTFAS_DLC_ZONE)
FASFV:add(FAS_NON_RACIAL, "non-racial", TTFAS_ONLY_NON_RACIAL)
FASFV:add(FAS_FILLED, "filled", TTFAS_ONLY_FILLED)
FASFV:add(FAS_UNFILLED, "unfilled", TTFAS_ONLY_UNFILLED)
FASFV:add(FAS_NORMAL_POTIONS, "normal potions", TTFAS_ONLY_NORMAL_POTIONS)
FASFV:add(FAS_POTENT_POTIONS, "potent potions", TTFAS_ONLY_POTENT_POTIONS)


-- checks the versions of libraries (where possible) and warn in
-- debug logger if we detect out of date libraries.
function TTFAS.checkLibraryVersions()
    if not LibDebugLogger then return end
    
    local addonName = TTFAS.name    
    local vc = SF.VersionChecker(addonName)
    local logger = LibDebugLogger.Create(addonName)
    vc:Enable(logger)
    vc:CheckVersion("LibAddonMenu-2.0", 35)
    vc:CheckVersion("LibDebugLogger",263)
    vc:CheckVersion("LibSFUtils",77)
    
    if ThiefTools then
        vc:CheckVersion("ThiefTools",48)
    end
    if UnknownTracker then
        vc:CheckVersion("UnknownTracker",71)
    end
	-- Tamriel Trade Centre does not define an addon version
end

---------------------
-- send debug messages to chat if enabled
local TTFASmsg = SF.addonChatter:New(TTFAS.name)
local debugmode=false
TTFASmsg:disableDebug()

function TTFAS.dbg(...)	-- mostly because I hate to type
	TTFASmsg:debugMsg(...)
end

function TTFAS.SystemMessage(...) 
    TTFASmsg:systemMessage(...)
end

local function slashToggleDebug()
	-- have a local debugmode variable instead of just using TTFASmsg:toggleDebug()
	-- (the addonChatter keeps track of its own state without outside assistance)
	-- just so that I can print to chat that I am enabling or disabling debug mode.
	if debugmode == false then
		debugmode = true
		TTFASmsg:enableDebug()
		TTFASmsg:systemMessage("Enabling debug")

	else
		TTFASmsg:systemMessage("Disabling debug")
		debugmode = false
		TTFASmsg:disableDebug()
	end
end

function TTFAS.toggleDebug(mode)
	if mode ~= nil then
		debugmode = mode
	else
		debugmode = not debugmode
	end
	
	if debugmode == true then
        TTFASLogger():SetDebug(true)
		TTFASmsg:enableDebug()
		TTFASmsg:systemMessage("Enabling debug")

	else
        TTFASLogger():SetDebug(false)
		TTFASmsg:systemMessage("Disabling debug")
		TTFASmsg:disableDebug()
	end
end

---------------------
