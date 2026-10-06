-- MSI.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']
MSI.Name	= "MSI"
MSI.Author 	= "Metu Liber"
MSI.Version = "2.7dev"
MSI.DevAcc 	= "Metu-_-Liber"
MSI.panel 	= nil
MSI.playerActivated = false
MSI.activeDuration = 0

--*****************--
-- InitSavedVariables
function MSI.InitSavedVariables()
    local defaultSavedVariables = {
		-- Allgemeine Einstellung
        IsMSIActive 			= true,
        IsAccountWide 			= false,
        IsMSIUseLAM 			= true,
		-- Essentielle Komponenten
        IsBookInhibit 			= true, -- dissatisfied unzufrieden
		IsLawfulBehave 			= false,
		-- Komfortable Assistenz
        IsLycanStatus 			= true,
		IsVampireGrade 			= true,
        IsDisputeReticle 		= true,
        redReticleFade          = true,
        redReticleHit           = true,
        IsLockcrackClue 		= true, --/msi
        ShowChamberResolvedIcon = true,
        ChamberResolvedIcon     = 1,
		ChamberResolveIconColor = {0.92, 0.78, 0, 1},
        UseSpringResolveColor 	= true,
		SpringResolveColor 		= {0, 1, 0, 1},
		ChamberStressedSound 	= 2, --"LOCKPICKING_CHAMBER_STRESS",
        --Beansruchbar Forderung
        IsClaimTomePoints       = true, --/msi
        IsCaimPursuitPts 		= true, --/msi
        IsHirelingMail 			= false,
		IsHorseInstruct 		= false,
        --Bequemes | Unbequemes
        IsSkipDialogs 			= false, --/msi
        IsSkipImportant         = false,
		KeyWordBlackList 		= {},
        IsCostDetection         = true,
        IsHardModeDetect        = true,
        IsDetectWrit            = true,
        --Praktische Helferlein
        IsSellALLJunk           = false,
        IsSellOrnJewel          = false,
        IsSellPoison            = false,
        IsSellStolenJunk        = false,
        IsLaunderStolen         = false,
        --Hilfreiche Routinen
        IsFilletFish            = true,
        IsLearnCllctbl          = true,

        IsBindSetParts          = false,
        IsUnrollTrsrMap         = false,

        IsOpenContainer         = true,
        IsOpenBoundConti        = true,
        IsOpenUnopened          = true,
		--IsMapZoneIcons 			= true,
        --Zweckmäßge Aspekte
        IsChatLog               = false,
        IsDebugLog              = false,

        ValNameSliderOne		= 3,
        ValNameSliderTwo       	= 0.07,
        ValNameWhiteList        = "",
        ValNameBlackList        = "",
        ValNameTextField        = "Buchstaben, Zahlen & Symbole",
    }

	MSI.SVarsAccount = ZO_SavedVars:NewAccountWide("MSI_SavedVariables_AccountPath", 0.23, "SVarsAccount", defaultSavedVariables, GetWorldName(), nil)
	MSI.SVarsCharacter = ZO_SavedVars:New("MSI_SavedVariables_CharacterPath", 0.23, "SVarsCharacter", defaultSavedVariables, GetWorldName())

    if MSI.SVarsAccount.IsAccountWide == true then
        MSI.SVars = MSI.SVarsAccount
    else
        MSI.SVars = MSI.SVarsCharacter
    end
end

function MSI.SwitchSavedVars(useAccountWide)
	MSI.SVarsAccount.IsAccountWide = useAccountWide
    if useAccountWide == true then
        MSI.SVars = MSI.SVarsAccount
    else
        MSI.SVars = MSI.SVarsCharacter
    end
end

function MSI.InitLibraries()
	-- Init Menu Panel LAM or LHS
	if not MSI.SVars.IsMSIUseLAM then
		if MSI.InitLHSLibrary then MSI.InitLHSLibrary() end
		if MSI.InitLHSMenuPanel then MSI.InitLHSMenuPanel() end
	else
		if MSI.InitLAMLibrary then MSI.InitLAMLibrary() end
		if MSI.InitLAMMenuPanel then MSI.InitLAMMenuPanel() end
	end-- Init Slash Chat Cmd
    if MSI.InitSlashCmdLibrary then MSI.InitSlashCmdLibrary() end
    if MSI.InitSlashChatCmnds then MSI.InitSlashChatCmnds() end
	-- Init Zone GeoLoc
	if MSI.InitZoneGeoLocLibrary then MSI.InitZoneGeoLocLibrary() end
	-- Init Skill Blocker
	if MSI.InitSkillBlockLibrary then MSI.InitSkillBlockLibrary() end
	-- Init GetText Dict
	if MSI.InitGetTextLibrary then MSI.InitGetTextLibrary() end
end
function MSI.InitModuleEvents()
    -- Init Module Events
	if MSI.InitModBookInhibit then MSI.InitModBookInhibit() end
	if MSI.InitModLawfulBehave then MSI.InitModLawfulBehave() end
	if MSI.InitModLycanStatus then MSI.InitModLycanStatus() end
	if MSI.InitModDisputeReticle then MSI.InitModDisputeReticle() end
	if MSI.InitModLockcrackClue then MSI.InitModLockcrackClue() end
	if MSI.InitModCaimPursuitPoints then MSI.InitModCaimPursuitPoints() end
	if MSI.InitModHirelingMail then MSI.InitModHirelingMail() end
	if MSI.InitModSkipDialogs then MSI.InitModSkipDialogs() end
	if MSI.InitModTraderThing then MSI.InitModTraderThing() end
	if MSI.InitModClaimTomePoints then MSI.InitModClaimTomePoints() end
	--if MSI.InitModMapZoneIcons then MSI.InitModMapZoneIcons() end
end
-- Init MSI AddOn
local function AddOnLoaded(eventCode, addOnNameOfEachAddonLoaded)
	if addOnNameOfEachAddonLoaded ~= MSI.Name then return end --Is this addon found?
    -- Init SavedVariables
	MSI.InitSavedVariables()
	-- First Status before Everything
	df(string.format("%s |cEFEBBEv%s|r |cD0D172%s|r", GetString(MSI_GAME_MENU_PANEL_NAME), MSI.Version,
        (MSI.SVars.IsMSIActive and GetString(MSI_ADDON_ENABLED) or GetString(MSI_ADDON_DISABLED))))
    -- Init PlayerReady
    MSI.InitPlayerReady()
	-- Init Libraries
	MSI.InitLibraries()
	-- Init ModuleEvents
--	MSI.InitModuleEvents()
    -- Close StartUp
    EVENT_MANAGER:UnregisterForEvent(MSI.Name, EVENT_ADD_ON_LOADED)
end
-- 'main()' Function
EVENT_MANAGER:RegisterForEvent(MSI.Name, EVENT_ADD_ON_LOADED, AddOnLoaded)
--eof