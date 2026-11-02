local LMP = LibMapPins
local GPTF = LibGamepadTooltipFilters
local AddonName="FishingMap"
local VisualName="Fishing Map"
local Localization={
	en={Lake="Lake",Foul="Foul",River="River",Salt="Salt",Oily="Oily",Mystic="Mystic",Running="Running",},
	ru={Lake="озерная вода",Foul="сточная вода",River="речная вода",Salt="морская вода",Oily="маслянистая вода",Mystic="мистическая вода",Running="речная вода",},
	de={Lake="Seewasser",Foul="Brackwasser",River="Flusswasser",Salt="Salzwasser",Oily="Ölwasser",Mystic="Mythenwasser",Running="Fließgewässer",},
	fr={Lake="Lac",Foul="Sale",River="Rivière",Salt="Mer",Oily="Huile",Mystic="Mystique",Running="courante",},
	br={Lake="Lake",Foul="Foul",River="River",Salt="Salt",Oily="Oily",Mystic="Mystic",Running="Running",},
	ua={
		--Lake="озерна вода",Foul="брудна вода",River="річкова вода",Salt="солона вода",Oily="масляниста вода",Mystic="містична вода",Running="проточна вода",
		Lake="Lake",Foul="Foul",River="River",Salt="Salt",Oily="Oily",Mystic="Mystic",Running="Running",},
	it={Lake="Lago",Foul="Acqua Sporca",River="Fiume",Salt="Mare",Oily="Oleosa",Mystic="Mistico",Running="Fluente",},
	es={Lake = "Lago", Foul = "Sucia", River = "Río", Salt = "Salada", Oily = "Aceitosa", Mystic = "Mística", Running = "Corriente",},
	zh={Lake="湖泊",Foul="脏水",River="河流",Salt="咸水",Oily="油污",Mystic="神秘",Running="Running",},
	}
local LocalizationFishingHole={	
	en={Salt="Saltwater Fishing Hole",Lake="Lake Fishing Hole",River="River Fishing Hole",Foul="Foul Fishing Hole",NewLife="New Life Fishing Hole",Oily="Oily Fishing Hole",Mystic="Mystic Fishing Hole",AbysFoul="Foul Abyssal Fishing Hole",},
	de={Salt="Fischgrund (Salzwasser)^m",Lake="Fischgrund (Seewasser)^m",River="Fischgrund (Flusswasser)^m",Foul="Fischgrund (Brackwasser)^m",NewLife="Neujahrsfest-Fischgrund^m",Oily="Fischgrund (Ölwasser)^m",Mystic="Fischgrund (Mythenwasser)^m",AbysFoul="abgründiger Fischgrund (Brackwasser)^m",},
	es={Salt="lugar de pesca de agua salada^m",Lake="lugar de pesca de lago^m",River="lugar de pesca de río^m",Foul="lugar de pesca de agua sucia^m",NewLife="lugar de pesca de la Nueva Vida^m",Oily="lugar de pesca aceitoso^m",Mystic="lugar de pesca místico^m",AbysFoul="lugar de pesca abisal de agua sucia^m",},
	fr={Salt="trou de pêche d'eau de mer^m",Lake="trou de pêche lacustre^m",River="trou de pêche de rivière^m",Foul="trou de pêche sale^m",NewLife="trou de pêche de la Nouvelle vie^m",Oily="trou de pêche huileux^m",Mystic="trou de pêche mystique^m",AbysFoul="trou de pêche sale abyssal",},
	jp={Salt="塩水の釣り穴",Lake="湖の釣り穴",River="川の釣り穴",Foul="汚水の釣り穴",NewLife="ニュー・ライフの釣り穴",Oily="油の釣り穴",Mystic="秘術の釣り穴",AbysFoul="深淵の汚水の釣り穴",},
	ru={Salt="Место для рыбалки на море",Lake="Место для рыбалки на озере",River="Место для рыбалки на реке",Foul="Место для рыбалки в сточной воде",NewLife="Место для рыбалки на Празднике Новой жизни",Oily="Место для рыбалки (маслянистая вода)",Mystic="Место для рыбалки (мистическая вода)",AbysFoul="Место для рыбалки в сточной воде (бездонное море)",},
	zh={Salt="咸水钓鱼点",Lake="湖泊钓鱼点",River="河流钓鱼点",Foul="脏水钓鱼点",NewLife="新生钓鱼点",Oily="油污钓鱼点",Mystic="神秘商人钓鱼点",AbysFoul="污秽深渊钓鱼点",},
}
local lang=GetCVar("language.2") if not Localization[lang] then lang="en" end
local function Loc(string)
	return Localization[lang][string] or Localization[lang]["en"] or string
end

local SavedVars, SavedGlobal
local DefaultVars = 
{	
	["AllFish"] = false,
    ["ForceShowFish"]={[1]=0,[2]=0,[3]=0,[4]=0,},
	["FishingMap_Nodes"]=true,
	["fishIconSelected"]={[1]=1,[2]=1,[3]=1,[4]=1,[5]=1,},
	["pinsize"] = 20,
	["useCharacterSettings"] = false,
	["newlife"] = false,
}
local DefaultGlobal = {
	["accountWideProfile"] = DefaultVars,
}

local function GetFMSettings()
	if SavedVars.useCharacterSettings then
		return SavedVars
	else
		return SavedGlobal.accountWideProfile
	end
end

--Data base
local PinManager
local cordsDump = ""
local UpdatingMapPin=false
local lastLoc = ""
local devMode=false

local FishIcon={
	[1]={--Foul
		"/esoui/art/icons/crafting_slaughterfish.dds",
		"/esoui/art/icons/crafting_fishing_caliginousbristleworm.dds",
		"/esoui/art/icons/crafting_fishing_illuminatedhalosaur.dds",
		},
	[2]={--River
		"/esoui/art/icons/crafting_fishing_river_betty.dds",	
		"/esoui/art/icons/crafting_fishing_salmon.dds",
		},
	[3]={--Lake
		"/esoui/art/icons/crafting_fishing_perch.dds",
		"/esoui/art/icons/crafting_fishing_shad.dds",
		},
	[4]={--Salt
		"/esoui/art/icons/crafting_fishing_merringar.dds",	
		"/esoui/art/icons/crafting_fishing_longfin.dds",		
		},
	[5]={--NewLife
		"/esoui/art/icons/achievement_newlifefestival_005.dds",	
		},
	}
local FishTypeToID = {
	Foul=1,
	River=2,
	Lake=3,
	Salt=4,
	Oily=1,--clockwork_base
	Mystic=4,--artaeum_base
	Running=2,--? no idea
	AbysFoul=1,
	NewLife=5,
}
local NumToFish={
    [1]="Foul",
	[2]="River",
	[3]="Lake",
	[4]="Salt",
}

local function FishNameToId(name)
	-- gets globalName
	local failed = true
	for globalName,locName in pairs(LocalizationFishingHole[lang]) do 
		if zo_strformat(SI_INTERACT_PROMPT_FORMAT_INTERACTABLE_NAME, locName) == name then
			name = globalName
			failed = false
			break
		end
	end	
	if failed then return "?" end
	return FishTypeToID[name]
end

local FishingZones={
	[2]=471,--Glenumbra
	[4]=472,--Stormhaven
	[5]=473,--Rivenspire
	[8]=4766,--Jerall
	[9]=477,--Stonefalls
	[10]=478,--Deshaan
	[11]=486,--Malabal Tor
	[14]=475,--Bangkorai
	[15]=480,--Eastmarch
	[16]=481,--Rift
	[17]=474,--Alik'r Desert
	[18]=485,--Greenshade
	[19]=479,--Shadowfen
	[38]=489,--Cyrodiil
	[154]=490,--Coldhabour
	[178]=483,--Auridon
	[179]=487,--Reaper's March
	[180]=484,--Grahtwood
	[501]=916,--Carglorn
	[109]=493,--Bleakrock
	[305]=491,--Stros M'Kai
	[306]=491,--Betnikh
	[307]=492,--Khenarthi's Roost
	--DLC
	[347]=1186,--Imperial City
	[380]=1340,--Wrothgar
	[443]=1351,--Hew's Bane
	[449]=1431,--Gold Coast
	[468]=1882,--Vvardenfell
	[590]=2027,--Clockwork City
	[617]=2191,--Summerset
	[633]=2240,--Arteum
	[408]=2295,--Murkmire
	[682]=2412,--Northern Elsweyr
	[721]=2566,--Southern Elsweyr
	[744]=2655,--Greymoor: Western Skyrim
	[745]=2655,--Greymoor: Blackreach: Greymoor Caverns
	[784]=2861,--Markarth: The Reach
	[785]=2861,--Markarth: Blackreach: Arkthzand Cavern
	[835]=2981,--Blackwood
	[858]=3144,--Deadlands
	[884]=3269,--High Isle
	[931]=3500,--Firesong
	[960]=3636,--Necrom
	[959]=3636,--Apocrypha
	[983]=3948,--Gold Road
	[1034]=4404,--West/East Solstice
	--[1034]=4460,--East Solstice
	u48_overland_base_west=4404,
	u48_overland_base_east=4460,
}
local ZoneIndexToParentIndex={
[2]=2,[3]=3,[4]=4,[5]=5,[6]=6,[7]=7,[8]=8,[9]=9,[10]=10,[11]=11,[12]=12,[13]=13,[14]=14,[15]=15,[16]=16,[17]=17,[18]=18,[19]=19,[20]=20,[21]=21,[22]=22,[23]=23,[24]=24,[25]=25,[26]=26,[27]=27,[28]=28,[29]=29,[30]=30,[31]=31,[32]=32,[33]=33,[34]=34,[35]=35,[36]=36,[38]=38,[39]=39,[42]=42,[43]=43,[44]=44,[47]=47,[48]=48,[49]=49,[50]=50,[52]=52,[53]=11,[54]=20,[55]=20,[57]=57,[58]=58,[59]=59,[60]=60,[61]=2,[62]=2,[63]=5,[64]=15,[66]=15,[68]=20,[69]=20,[70]=20,[71]=20,[72]=20,[73]=18,[74]=18,[75]=18,[76]=10,[77]=10,[78]=10,[79]=10,[82]=11,[83]=11,[85]=11,[86]=11,[87]=11,[88]=11,[89]=2,[90]=17,[92]=17,[93]=16,[94]=16,[95]=16,[96]=16,[97]=16,[98]=16,[99]=16,[100]=100,[101]=12,[102]=12,[103]=20,[104]=20,[105]=20,[106]=20,[107]=20,[108]=20,[110]=110,[111]=111,[112]=10,[113]=2,[114]=10,[115]=10,[116]=10,[117]=10,[118]=10,[119]=10,[120]=11,[121]=18,[122]=2,[123]=2,[124]=2,[125]=2,[126]=2,
[127]=2,[128]=4,[129]=4,[130]=4,[131]=4,[132]=4,[133]=4,[134]=5,[135]=5,[136]=5,[137]=5,[138]=5,[139]=5,[140]=18,[141]=18,[142]=18,[143]=18,[144]=18,[145]=18,[146]=15,[147]=15,[148]=148,[149]=15,[150]=15,[151]=15,[152]=16,[153]=153,[155]=155,[156]=16,[158]=16,[159]=16,[160]=16,[161]=16,[162]=16,[163]=16,[164]=155,[166]=155,[168]=155,[169]=155,[170]=155,[171]=155,[172]=155,[176]=12,[177]=12,[178]=179,[179]=179,[180]=683,[181]=181,[182]=182,[183]=10,[185]=179,[186]=181,[187]=179,[188]=179,[189]=179,[190]=179,[191]=179,[192]=179,[193]=179,[194]=179,[195]=179,[196]=179,[197]=179,[198]=17,[199]=17,[200]=17,[201]=11,[202]=11,[203]=11,[204]=11,[205]=11,[206]=11,[207]=12,[208]=17,[209]=17,[210]=17,[211]=17,[212]=179,[213]=155,[214]=155,[215]=155,[216]=155,[217]=155,[218]=155,[219]=219,[221]=2,[223]=4,[224]=17,[226]=181,[227]=181,[230]=181,[231]=181,[232]=181,[233]=181,[234]=181,[235]=181,
[236]=16,[237]=180,[239]=180,[240]=180,[241]=180,[242]=180,[243]=180,[244]=180,[246]=180,[247]=180,[248]=180,[249]=180,[250]=180,[251]=180,[252]=180,[253]=180,[254]=12,[255]=12,[256]=12,[257]=12,[258]=12,[259]=12,[260]=181,[261]=181,[262]=181,[263]=17,[264]=17,[265]=17,[266]=17,[267]=17,[268]=179,[269]=180,[270]=10,[271]=39,[272]=39,[273]=39,[274]=39,[275]=39,[277]=39,[278]=39,[279]=39,[280]=39,[281]=39,[282]=39,[283]=39,[284]=39,[285]=39,[286]=469,[287]=469,[288]=469,[289]=39,[290]=290,[291]=291,[292]=292,[293]=293,[294]=469,[295]=409,[296]=409,[297]=836,[298]=39,[299]=180,[300]=300,[303]=39,[304]=39,[305]=39,[306]=306,[307]=307,[308]=308,[309]=307,[311]=179,[316]=19,[317]=19,[318]=181,[320]=19,[321]=19,[322]=19,[323]=19,[324]=19,[325]=155,[327]=19,[328]=17,[329]=19,[330]=180,[331]=180,[333]=333,[334]=18,[337]=337,[338]=338,[339]=339,[340]=19,[341]=19,[342]=19,[343]=19,[344]=19,
[345]=19,[348]=39,[351]=5,[355]=5,[356]=5,[358]=15,[359]=359,[360]=360,[365]=5,[367]=502,[368]=502,[369]=11,[370]=502,[371]=502,[372]=4,[373]=2,[374]=374,[375]=39,[377]=444,[378]=378,[379]=39,[380]=380,[381]=381,[382]=382,[383]=381,[384]=381,[385]=381,[386]=381,[387]=381,[388]=381,[389]=381,[390]=381,[391]=381,[392]=381,[393]=381,[394]=381,[395]=381,[396]=381,[397]=381,[398]=381,[399]=381,[400]=381,[401]=381,[402]=381,[403]=381,[404]=381,[405]=405,[407]=381,[408]=408,[409]=409,[410]=10,[411]=179,[412]=181,[413]=19,[414]=12,[415]=180,[416]=502,[417]=4,[418]=2,[419]=15,[420]=5,[421]=18,[422]=10,[423]=16,[424]=20,[425]=11,[426]=17,[427]=427,[428]=428,[429]=450,[430]=450,[431]=431,[432]=450,[433]=433,[434]=434,[435]=20,[437]=381,[438]=745,[439]=439,[440]=179,[441]=307,[444]=444,[445]=444,[449]=444,[450]=450,[451]=450,[452]=450,[453]=450,[454]=450,[455]=450,[456]=450,[457]=450,[458]=450,
[459]=450,[460]=460,[461]=450,[462]=450,[463]=463,[464]=464,[465]=20,[466]=444,[467]=444,[468]=20,[469]=469,[500]=181,[501]=502,[502]=502,[503]=502,[504]=502,[505]=502,[506]=502,[507]=502,[508]=502,[509]=502,[510]=502,[511]=502,[512]=502,[513]=502,[514]=514,[515]=515,[516]=502,[517]=502,[518]=502,[519]=502,[520]=502,[521]=521,[522]=502,[523]=502,[524]=502,[525]=502,[526]=502,[527]=502,[528]=502,[529]=502,[531]=469,[532]=469,[533]=469,[534]=469,[535]=469,[536]=469,[537]=469,[538]=469,[539]=469,[540]=469,[541]=469,[542]=469,[543]=11,[544]=181,[545]=5,[546]=4,[547]=10,[548]=179,[549]=2,[559]=469,[560]=469,[561]=469,[562]=469,[563]=469,[564]=469,[565]=469,[566]=469,[568]=469,[569]=469,[570]=469,[571]=469,[572]=469,[573]=469,[574]=469,[575]=469,[576]=469,[577]=469,[578]=469,[579]=469,[581]=469,[582]=469,[583]=469,[584]=469,[585]=469,[586]=502,[587]=587,[588]=469,[589]=589,[591]=591,
[592]=591,[593]=591,[594]=591,[596]=591,[597]=591,[599]=591,[601]=591,[602]=591,[603]=591,[606]=606,[609]=609,[610]=591,[614]=502,[616]=15,[617]=4,[618]=618,[619]=179,[620]=618,[621]=618,[622]=618,[623]=634,[624]=618,[625]=625,[626]=618,[627]=618,[628]=618,[630]=618,[632]=618,[633]=618,[634]=634,[636]=618,[637]=618,[639]=618,[642]=642,[643]=618,[644]=618,[645]=618,[647]=634,[650]=450,[652]=618,[653]=618,[655]=618,[656]=180,[657]=19,[661]=661,[662]=17,[664]=409,[665]=409,[667]=409,[669]=409,[670]=670,[671]=409,[672]=10,[673]=179,[674]=2,[675]=409,[677]=409,[678]=16,[679]=450,[680]=409,[681]=409,[683]=683,[684]=683,[685]=683,[686]=683,[687]=683,[688]=683,[689]=683,[690]=683,[691]=683,[699]=683,[701]=409,[702]=16,[704]=683,[705]=683,[712]=683,[714]=714,[715]=683,[716]=181,[717]=16,[722]=722,[723]=722,[724]=722,[726]=722,[727]=727,[728]=722,[735]=722,[737]=722,[741]=381,[742]=15,
[743]=683,[744]=5,[745]=745,[746]=746,[747]=747,[748]=745,[750]=745,[751]=746,[752]=745,[759]=745,[760]=745,[761]=745,[768]=745,[769]=746,[773]=773,[775]=722,[776]=745,[777]=777,[778]=746,[781]=781,[785]=785,[786]=786,[787]=785,[788]=788,[798]=746,[799]=745,[805]=785,[806]=450,[807]=11,[813]=836,[814]=836,[821]=836,[823]=836,[828]=836,[829]=836,[830]=836,[831]=836,[832]=832,[833]=836,[834]=834,[835]=836,[836]=836,[837]=4,[838]=838,[840]=745,[842]=2,[843]=836,[845]=450,[846]=836,[848]=836,[849]=836,[850]=836,[853]=19,[855]=855,[856]=856,[857]=856,[858]=859,[859]=859,[861]=861,[862]=859,[863]=863,[865]=856,[866]=859,[867]=859,[868]=836,[869]=859,[870]=859,[871]=871,[872]=618,[873]=873,[874]=856,[875]=12,[876]=836,[878]=469,[879]=469,[880]=885,[881]=881,[883]=885,[884]=885,[885]=885,[886]=885,[887]=885,[888]=885,[889]=885,[890]=885,[891]=983,[892]=885,[893]=885,[894]=885,[895]=885,
[896]=885,[897]=885,[898]=885,[899]=885,[900]=885,[901]=885,[902]=885,[903]=885,[904]=885,[905]=856,[906]=906,[907]=885,[908]=307,[909]=885,[910]=885,[912]=885,[915]=931,[916]=931,[917]=931,[918]=931,[919]=919,[921]=931,[922]=931,[923]=931,[924]=931,[925]=931,[926]=885,[927]=931,[929]=931,[930]=885,[931]=931,[932]=931,[934]=931,[935]=10,[936]=17,[937]=937,[938]=180,[939]=959,[940]=959,[941]=959,[942]=960,[943]=960,[944]=959,[945]=959,[946]=959,[947]=959,[948]=960,[949]=960,[950]=960,[951]=960,[952]=960,[953]=960,[954]=960,[955]=959,[956]=959,[957]=959,[958]=960,[959]=959,[960]=960,[961]=960,[962]=959,[963]=959,[964]=959,[965]=959,[966]=960,[967]=960,[968]=959,[969]=960,[970]=960,[971]=179,[972]=885,[974]=960,[975]=975,[976]=959,[977]=977,[979]=979,[980]=983,[981]=959,[982]=983,[983]=983,[984]=983,[985]=983,[986]=983,[987]=983,[988]=983,[989]=983,[993]=983,[994]=983,[995]=983,
[996]=983,[997]=618,[998]=959,[999]=983,[1000]=983,[1002]=983,[1003]=100,[1004]=983,[1005]=983,[1006]=983,[1007]=983,[1009]=1009,[1010]=381,[1011]=931,[1013]=959,[1014]=1014,[1015]=983,[1017]=409,[1018]=983,[1019]=885,[1020]=18,[1021]=885,[1022]=722,[1023]=745,[-2147483648]=4294967296,[1089]=450,[1090]=2,[1027]=983,[1028]=983,[1029]=444,[1030]=618,[1031]=683,[1032]=1032,[1033]=1033,[1034]=1034,[1035]=39,[1036]=5,[1037]=5,[1102]=836,[1039]=1039,[1040]=1034,[1041]=1041,[1042]=1034,[1043]=1034,[1044]=1034,[1045]=1034,[1047]=1034,[1097]=180,[1049]=1034,[1050]=1034,[1051]=1034,[1052]=1034,[1096]=19,[1054]=1034,[1055]=1034,[1056]=1034,[1057]=1034,[1058]=1034,[1059]=1034,[1060]=1034,[1061]=1034,[1062]=1062,[1100]=785,[1088]=306,[1065]=2,[1066]=1034,[1067]=4,[1094]=1094,[1069]=983,[1070]=1034,[1071]=1034,[1072]=1034,[1073]=1034,[1074]=1074,[1075]=1075,[1095]=1095,[1077]=502,[1078]=1078,
[1092]=2,[1080]=983,[1081]=856,[1082]=856,[1083]=856,[1084]=856,[1091]=2,[1093]=2,[1087]=856,
}
                
local FishingAchievements={[471]=true,[472]=true,[473]=true,[474]=true,[475]=true,[477]=true,[478]=true,[479]=true,[480]=true,[481]=true,[483]=true,[484]=true,[485]=true,[486]=true,[487]=true,[489]=true,[490]=true,[491]=true,[492]=true,[493]=true,[916]=true,[1186]=true,[1339]=true,[1340]=true,[1351]=true,[1431]=true,[1882]=true,[2191]=true,[2240]=true,[2295]=true,[2412]=true,[2566]=true,[2655]=true,[2861]=true,[2981]=true,[3144]=true,[3269]=true,[3500]=true,[3636]=true,[3948]=true,[4404]=true,[4460]=true,[4691]=true,[4766]=true}
local FishingPinData={name="FishingMap_Nodes",done=false,pin={},maxDistance=0.05,level=101,texture="/esoui/art/icons/achievements_indexicon_fishing_up.dds",k=1.25,}
local function GetFishingAchievement(subzone)
	if GetFMSettings().AllFish then return {[1]=true,[2]=true,[3]=true,[4]=true,[5]=true} end
	local id=FishingZones[subzone] or FishingZones[GetCurrentMapZoneIndex()] or FishingZones[ZoneIndexToParentIndex[GetCurrentMapZoneIndex()]]
	if id then
		local total={
			Foul=GetFMSettings().ForceShowFish[1],
			River=GetFMSettings().ForceShowFish[2],
			Lake=GetFMSettings().ForceShowFish[3],
			Salt=GetFMSettings().ForceShowFish[4],
			Oily=0,Mystic=0,Running=0}
		for i=1,GetAchievementNumCriteria(id) do
			local AchName,a,b=GetAchievementCriterion(id,i)
			for water in pairs(total) do
				if string.match(AchName,"("..Loc(water)..")")~=nil then
					total[water]=total[water]+b-a
				end
			end
		end
		total.Salt=total.Salt+total.Mystic total.Foul=total.Foul+total.Oily total.River=total.River+total.Running		
		return {[1]=total.Foul>0,[2]=total.River>0,[3]=total.Lake>0,[4]=total.Salt>0,[5]=GetFMSettings().newlife}
	end
	return false
end

local currentLoadingCoroutine = nil
local currentLoadingMap = ""

-- Helper to stop any existing loading process
local function AbortPinLoading()
    EVENT_MANAGER:UnregisterForUpdate(AddonName .. "_PinLoader")
    currentLoadingCoroutine = nil
end
-- Cheap to Run Create Pin that does only what I need
local function customCreatePin(pinType, pinTag, xLoc, yLoc)
    local pin, pinKey = PinManager:AcquireObject()
    pin:SetData(pinType, pinTag)
    pin:SetOriginalPosition(xLoc, yLoc)
    pin:SetLocation(xLoc, yLoc)
        
    local customPinData = PinManager.customPins[pinType]
    if customPinData then
        PinManager:MapPinLookupToPinKey(customPinData.pinTypeString, pinType, pinTag, pinKey)
    end
end
--Callbacks
local function MapPinAddCallback()
    if GetMapType() > MAPTYPE_ZONE or not PinManager:IsCustomPinEnabled(FishingPinData.id) then return end
    local subzone = GetMapTileTexture():match("[^\\/]+$"):lower():gsub("%.dds$", ""):gsub("_[0-9]+$", "")
    -- check if were adding pins, if same map exit, othewise stop loading old pins so we can add new
    if currentLoadingCoroutine ~= nil then
        if currentLoadingMap == subzone then return end
        AbortPinLoading()
    end
    currentLoadingMap = subzone

	local workQueue = {}
    local subzonesToProcess = {}

	--Add the map we want target 
    if subzone == "u48_overland_base" then
        table.insert(subzonesToProcess, "u48_overland_base_east")
        table.insert(subzonesToProcess, "u48_overland_base_west")
    else
        table.insert(subzonesToProcess, subzone)
    end

	-- Process's Subzones
	-- Get data from FishingMap_Nodes and checks if we need to show the data
	-- Add data(pins) to workQueue so we have 1 big table to process
    for _, name in ipairs(subzonesToProcess) do
        local mapData = FishingMapNodes[name]
        local achStatus = GetFishingAchievement(name)
        if mapData and achStatus then
			for i = 1, #mapData do
				local pinData = mapData[i]
				if achStatus[pinData[3]] then
					workQueue[#workQueue+1] = pinData
				end
			end
        end
    end
	local pinIndex = 1
	local frameBudget = 0.005

    currentLoadingCoroutine = function()
        local startTime = GetGameTimeSeconds()
        while pinIndex <= #workQueue do
			local pinData = workQueue[pinIndex]
			FishingPinData.texture = FishIcon[pinData[3]][GetFMSettings().fishIconSelected[pinData[3]]]
			customCreatePin(FishingPinData.id, {[1]=pinData[3]}, pinData[1], pinData[2])
			pinIndex = pinIndex + 1
			if pinIndex % 10 == 0 then
				if (GetGameTimeSeconds() - startTime) > frameBudget then
					return
				end
			end
		end
        AbortPinLoading()
    end

    -- Start Coroutine
    EVENT_MANAGER:RegisterForUpdate(AddonName .. "_PinLoader", 0, function()
        if currentLoadingCoroutine then
            currentLoadingCoroutine()
        else
            AbortPinLoading()
        end
    end)
end

local function GetToolTipText()
return zo_iconFormat(FishIcon[1][GetFMSettings().fishIconSelected[1]],35,35).." "..Loc("Foul").."\n"
	 ..zo_iconFormat(FishIcon[2][GetFMSettings().fishIconSelected[2]],35,35).." "..Loc("River").."\n"
	 ..zo_iconFormat(FishIcon[3][GetFMSettings().fishIconSelected[3]],35,35).." "..Loc("Lake").."\n"
	 ..zo_iconFormat(FishIcon[4][GetFMSettings().fishIconSelected[4]],35,35).." "..Loc("Salt").."\n"
	 ..zo_iconFormat(FishIcon[5][GetFMSettings().fishIconSelected[5]],35,35).." "..Loc("NewLife")
end
local function updatePinSize(n)
	GetFMSettings().pinsize=n
	if ZO_MapPin.PIN_DATA[FishingPinData.id] and FishingPinData.k then ZO_MapPin.PIN_DATA[FishingPinData.id].size=n*FishingPinData.k end
	PinManager:RefreshCustomPins(FishingPinData.id)
end

local PinTooltipCreator={
	tooltip=1,
	creator=function(pin)
		local _, pinTag=pin:GetPinTypeAndTag()
		local name,icon
		icon=FishIcon[pinTag[1]][GetFMSettings().fishIconSelected[pinTag[1]]]
		name="X: "..pin.normalizedX.." Y: "..pin.normalizedY.." ID: "..pinTag[1]
		if IsInGamepadPreferredMode() or IsConsoleUI() then
			ZO_MapLocationTooltip_Gamepad:LayoutIconStringLine(ZO_MapLocationTooltip_Gamepad.tooltip, icon, zo_strformat("<<1>>", name), ZO_MapLocationTooltip_Gamepad.tooltip:GetStyle("mapLocationTooltipWayshrineHeader"))
		else
			InformationTooltip:AddLine(zo_strformat("<<1>> <<2>>",zo_iconFormat(icon,24,24), name), "ZoFontGameOutline", ZO_SELECTED_TEXT:UnpackRGB())
		end
	end
}

local function logCords(n,subzone,cords)
		if n == "?" then 
			CHAT_ROUTER:AddSystemMessage("No Fishing hole detected")
			return
		end
		if lastLoc ~= subzone then
			if lastLoc ~= "" then cordsDump = cordsDump .. "},"end
			cordsDump = cordsDump.. subzone .. "={"
			lastLoc = subzone				
		end
		cordsDump = cordsDump .. "{"..cords..","..n.."},"		
		CHAT_ROUTER:AddSystemMessage("Logged")
	end
	local function SolsticeCheck(x,y)
		local pointA = {["x"]=.466,["y"]=.270}
		local pointB = {["x"]=.666,["y"]=.793}
		local dire = (x-pointA.x)*(pointB.y-pointA.y)-(y-pointA.y)*(pointB.x-pointA.x)
		if dire<0 then return "u48_overland_base_west" else return "u48_overland_base_east" end
	end
	local function getFishingHoleInfo(x,y)
		local subzone = GetMapTileTexture():match("[^\\/]+$"):lower():gsub("%.dds$", ""):gsub("_[0-9]+$", "")		
		local xStr = string.gsub(math.floor(x*1000)/1000, "^0%.", ".")
		local yStr = string.gsub(math.floor(y*1000)/1000, "^0%.", ".")
		local cords = xStr..","..yStr
		if subzone == "u48_overland_base" then subzone = SolsticeCheck(xStr,yStr) end
	return subzone, cords
	end

local function SettingsMenu()
	local LHAS = LibHarvensAddonSettings
	if LHAS == nil then return end
   local options = {
        allowDefaults = false, 
        allowRefresh = true, 
       -- defaultsFunction = function() 
        --    CHAT_ROUTER:AddSystemMessage("Fishing Map settign have been reset to Default")
       -- end,
    }
    local settings = LHAS:AddAddon(VisualName,options)
    if not settings then return end
	
	settings:AddSetting({
        type = LHAS.ST_LABEL,
        label = "Go To \n Map -> Options -> Filters \n To Turn On & Off",
    })

	--Slider to Adjust Pin Size
    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Pin Size \n Small <- -> Large",
		tooltip = "Default: "..DefaultVars.pinsize,
		default = DefaultVars.pinsize, 
        setFunction = function(value)
           updatePinSize(value)
        end,
        getFunction = function()
            return GetFMSettings().pinsize
        end,
        min = 16,
        max = 40,
        step = 1
    })	
	local section = {
        type = LHAS.ST_SECTION,
        label = "Icon Change",
    }
    settings:AddSetting(section)
	for i = 1, 4 do	
		settings:AddSetting({
			type = LHAS.ST_ICONPICKER,
			label = Loc(NumToFish[i]),
			items = FishIcon[i],		
			getFunction = function()
				return GetFMSettings().fishIconSelected[i]
			end,
			setFunction = function(combobox, index, item)
				GetFMSettings().fishIconSelected[i]=index
				PinManager:RefreshCustomPins(FishingPinData.id)
			end,
			default = DefaultVars.fishIconSelected[i],
		})
	end
	settings:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Force Show Fish",
    })
	settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Show All Fish", 
		tooltip = "When Off will only show fish you need to collect.",
		default = DefaultVars.AllFish, 
        setFunction = function(value)
           GetFMSettings().AllFish = value
		   PinManager:RefreshCustomPins(FishingPinData.id)
        end,
        getFunction = function()
            return GetFMSettings().AllFish
        end,
    })
	
	for i = 1, 4 do
		local function boolToNumber(bool)
			 if bool then return 1 else return 0 end
		end
		settings:AddSetting({
			type = LHAS.ST_CHECKBOX,
			label = "Force Show "..Loc(NumToFish[i]), 
			tooltip = "Turn on when you want to see the fish on the map even if you have it done",
			default = false, 
			setFunction = function(value)	
			   GetFMSettings().ForceShowFish[i] = boolToNumber(value)
			   PinManager:RefreshCustomPins(FishingPinData.id)
			end,
			getFunction = function()
				return GetFMSettings().ForceShowFish[i]==1
			end,
			disable = function() return GetFMSettings().AllFish end,
		})
	end
	settings:AddSetting({
			type = LHAS.ST_CHECKBOX,
			label = "Show "..LocalizationFishingHole[lang].NewLife, 
			default = DefaultVars.newlife, 
			setFunction = function(value)	
			   GetFMSettings().newlife = value
			   PinManager:RefreshCustomPins(FishingPinData.id)
			end,
			getFunction = function()
				return GetFMSettings().newlife
			end,
	})
	settings:AddSetting({
        type = LHAS.ST_SECTION,
        label = "Logging / Report",
    })
	settings:AddSetting({
            type = LHAS.ST_BUTTON,
            label = "LOG Fishing Hole",
            tooltip = "Log Hole",
            buttonText = "LOG",
            clickHandler = function(control, button)
				local action, interactableName = GetGameCameraInteractableActionInfo()
				interactableName = FishNameToId(interactableName)
				local x,y=GetMapPlayerPosition("player")
				local subzone, cords = getFishingHoleInfo(x,y)
				CHAT_ROUTER:AddSystemMessage(subzone .. "={{"..cords..","..interactableName.."}},")
				logCords(interactableName,subzone,cords)
			end,
        })
	settings:AddSetting({
        type = LHAS.ST_LABEL,
        label = "Found a Missing Fishing Hole? \nStand in the Middle of it \n and type '/fmloc 1' in chat to Log it.",
    })

	settings:AddSetting({
            type = LHAS.ST_BUTTON,
            label = "Submit Logged",
            tooltip = "Open link then click submit \n Type '/fmclear' in chat to clear logged holes",
            buttonText = "Open URL",
            clickHandler = function(control, button)
                RequestOpenUnsafeURL("https://docs.google.com/forms/d/e/1FAIpQLSczE1-xzjbFgRrXSMdMBxZuQgM2eGnBUpiOFvqB8Hve-MfEfA/viewform?usp=pp_url&entry.550722213=" ..cordsDump.."},")
            end,
        })
	
	settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Submit Feedback / Request",
		tooltip = "link to a form where you can leave feedback or even leave a request",
		buttonText = "Open URL",
		clickHandler = function(control, button)
			RequestOpenUnsafeURL("https://docs.google.com/forms/d/e/1FAIpQLScYWtcIJmjn0ZUrjsvpB5rwA5AlsLvasHUIcKqzIYcogo9vjQ/viewform?usp=pp_url&entry.550722213="..VisualName)
		end,
	})
	
end

local function SetUpSlashCommands()
	SLASH_COMMANDS["/fmpinsize"]=function(n)	
		n=tonumber(n)		
		if n and n>=16 and n<=40 then
			updatePinSize(n)
		else
			CHAT_ROUTER:AddSystemMessage("/fmpinsize {Number} \n Number = 16 to 40")
		end
	end
	
	SLASH_COMMANDS["/fmclear"]=function()
		cordsDump = ""
		lastLoc = ""
		CHAT_ROUTER:AddSystemMessage("logged fishingSpots cleared")
	end
	--saves the cord it given by "/fmloc #" and "/fmwploc #"
	
	SLASH_COMMANDS["/fmloc"]=function(n)
		local action, interactableName = GetGameCameraInteractableActionInfo()
		interactableName = FishNameToId(interactableName)
		local x,y=GetMapPlayerPosition("player")
	    local subzone, cords = getFishingHoleInfo(x,y)
		CHAT_ROUTER:AddSystemMessage(subzone .. "={{"..cords..","..interactableName.."}},")
		n=tonumber(n)	
		if n then
			logCords(interactableName,subzone,cords)
		end
	end
		
	SLASH_COMMANDS["/fmwploc"]=function(n)
		local x, y = GetMapPlayerWaypoint()
		local subzone, cords = getFishingHoleInfo(x,y)
		if not n then n="" end
		CHAT_ROUTER:AddSystemMessage(subzone .. "={{" .. cords .. ","..n.."},}")
		n=tonumber(n)	
		if n and n>=1 and n<=4 then
			logCords(n,subzone,cords)
		end
	end
	SLASH_COMMANDS["/fmnewlife"]=function(n)
		GetFMSettings().newlife = not GetFMSettings().newlife
		 PinManager:RefreshCustomPins(FishingPinData.id)
		
	end
	SLASH_COMMANDS["/fmsubmit"]=function()
		RequestOpenUnsafeURL("https://docs.google.com/forms/d/e/1FAIpQLSczE1-xzjbFgRrXSMdMBxZuQgM2eGnBUpiOFvqB8Hve-MfEfA/viewform?usp=pp_url&entry.550722213=" ..cordsDump.."},")
	end
	SLASH_COMMANDS["/fmreport"]=function()
		RequestOpenUnsafeURL("https://docs.google.com/forms/d/e/1FAIpQLScYWtcIJmjn0ZUrjsvpB5rwA5AlsLvasHUIcKqzIYcogo9vjQ/viewform?usp=pp_url&entry.550722213="..VisualName)
	end
	SLASH_COMMANDS["/fmdev"]=function(n)
		if devMode==false then
			ZO_MapPin.TOOLTIP_CREATORS[FishingPinData.id]=PinTooltipCreator
			devMode = true
		end
	end
end

local function OnAchievementUpdate(achievementId,link)
	local function RefreshPins(name)
		EVENT_MANAGER:RegisterForUpdate("CallLater_"..name, 1000,
		function()
			EVENT_MANAGER:UnregisterForUpdate("CallLater_"..name)
			PinManager:RefreshCustomPins(name)
		end)
	end
	if FishingAchievements[achievementId] and GetFMSettings().FishingMap_Nodes then
		RefreshPins(FishingPinData.id)
	end
end
local function RegisterEvents()
	EVENT_MANAGER:RegisterForEvent(AddonName,EVENT_ACHIEVEMENT_UPDATED,function(_,achievementId,link) OnAchievementUpdate(achievementId)end)
	EVENT_MANAGER:RegisterForEvent(AddonName,EVENT_ACHIEVEMENT_AWARDED,function(_,_,_,achievementId,link) OnAchievementUpdate(achievementId)end)
end

local function OnLoad(eventCode,addonName)
	if addonName ~= AddonName then return end
	EVENT_MANAGER:UnregisterForEvent(AddonName,EVENT_ADD_ON_LOADED)
	local serverName = GetWorldName()
	SavedGlobal = ZO_SavedVars:NewAccountWide("FishingMapSavedVariables", 1, serverName, DefaultGlobal)
	SavedVars = ZO_SavedVars:NewCharacterIdSettings("FishingMapSavedVariables",1, serverName, SavedGlobal.accountWideProfile) 	
	PinManager=ZO_WorldMap_GetPinManager()
	SettingsMenu()
	RegisterEvents()
	
	FishingPinData.size = FishingPinData.size or GetFMSettings().pinsize*FishingPinData.k
	FishingPinData.id = LMP:AddPinType(FishingPinData.name,function() MapPinAddCallback() end,nil,FishingPinData)
	--pin filter--
	local icon = zo_iconFormat(FishingPinData.def_texture or FishingPinData.texture or "", 24, 24)
    local label = icon .. " Fishing Holes"
	LMP:AddPinFilter(FishingPinData.id, label, false, GetFMSettings())	
	
	if GPTF then GPTF:AddTooltip(FishingPinData.id,GetToolTipText()) end	
	SetUpSlashCommands()
	
end
EVENT_MANAGER:RegisterForEvent(AddonName,EVENT_ADD_ON_LOADED,OnLoad)
