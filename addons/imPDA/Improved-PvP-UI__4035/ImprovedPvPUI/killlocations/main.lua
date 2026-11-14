-- local Log = IMP_PVP_UI_Logger('KillLocations')
local EVENT_NAMESPACE = 'EVENT_NAMESPACE_IMP_PVP_UI_KillLocations'

local sqrt = math.sqrt
local pow = math.pow
local atan2 = math.atan2
local floor = math.floor
local insert = table.insert
local remove = table.remove

local PI = math.pi
local PI_8 = PI / 8
local PI_3 = PI / 3

local ZONE_ID_CYRODIIL = 181
local ZONE_ID_IC = 584


local SMALL_KILL_LOCATION_SIZE  = 18 * 2 / 3
local MEDIUM_KILL_LOCATION_SIZE = 22 * 2 / 3
local LARGE_KILL_LOCATION_SIZE  = 28 * 2 / 3

-- ----------------------------------------------------------------------------

local function _cantorPairing(n_x, n_z)
    return (n_x + n_z) * (n_x + n_z + 1) / 2 + n_z
end

local function _stringHash(n_x, n_z)
	return n_z..','..n_z
end

local _hash_function = _cantorPairing


local function _getHeading(startX, startY, endX, endY)
	local angle = atan2(-(endY - startY), (endX - startX))

	-- df('Angle: %.2f', angle)

	if (angle > -PI_8 and angle <= PI_8) then
		return 'E'
	elseif (angle > PI_8 and angle <= 3 * PI_8) then
		return 'NE'
	elseif (angle > 3 * PI_8 and angle <= 5 * PI_8) then
		return 'N'
	elseif (angle > 5 * PI_8 and angle <= 7 * PI_8) then
		return 'NW'
	elseif (angle > 7 * PI_8 and angle <= PI) then
		return 'W'
	elseif (angle > -PI and angle <= -7 * PI_8) then
		return 'W'
	elseif (angle > -7 * PI_8 and angle <= -5 * PI_8) then
		return 'SW'
	elseif (angle > -5 * PI_8 and angle <= -3 * PI_8) then
		return 'S'
	elseif (angle > -3 * PI_8 and angle <= -PI_8) then
		return 'SE'
	-- elseif (angle > -PI_8 and angle <= 0) then
	-- 	return 'E'
	end
end

local function _getDistrict(startX, startY, endX, endY)
	local angle = atan2(-(endY - startY), (endX - startX))

	-- df('Angle: %.2f', angle)

	if (angle > 0 and angle <= PI_3) then
		return 'Arena'
	elseif (angle > PI_3 and angle <= 2 * PI_3) then
		return 'Memorial'
	elseif (angle > 2 * PI_3 and angle <= 3 * PI_3) then
		return 'Elven Gardens'
	elseif (angle > - 3* PI_3 and angle <= -2 * PI_3) then
		return 'Nobles'
	elseif (angle > -2 * PI_3 and angle <= -PI_3) then
		return 'Temple'
	elseif (angle > -PI_3 and angle <= 0) then
		return 'Arboretum'
	end
end

-- TODO: ideally, this function will be in separate addon soon
local function _getCalibration(zoneId, E)
	E = E or 1000000

    local  b_x,  b_z = GetRawNormalizedWorldPosition(zoneId, 0, 0, 0)
    local n1_x, n1_z = GetRawNormalizedWorldPosition(zoneId, E, 0, 0)
    local n2_x, n2_z = GetRawNormalizedWorldPosition(zoneId, 0, 0, E)

    local n_x, n_z = n1_x - b_x, n2_z - b_z

    if b_x ~= n2_x or b_z ~= n1_z then error('Weird calibration') end

    return n_x, b_x, n_z, b_z, E
end

local function _formatKills(kills)
	local t = {}

	for alliance, allianceKills in pairs(kills) do
		if allianceKills > 0 then
			local allianceColor = GetAllianceColor(alliance)
			t[#t+1] = string.format(
				'%s %s',
				allianceColor:Colorize(zo_iconFormatInheritColor(ZO_GetAllianceIcon(alliance), 16, 32)),
				allianceColor:Colorize(allianceKills)
			)
		end
	end

	return table.concat(t, '  / ')
end

-- ----------------------------------------------------------------------------

local addon = {
    name = 'CyrodiilKillHistory'
}

local MAIN_CALIBRATIONS = {
	[ZONE_ID_CYRODIIL]  = {1000000, 0, 1000000, 0},
	[ZONE_ID_IC] 		= {1000000 / 9.3602281808853, -0.84188234806061, 1000000 / 9.360228061676, -0.90677213668823}
}

function addon:Initialize(sv)
	self.sv = sv

	self.buffer = {}
	self.historyBuffer = {}

	self.listening = false

	self.onWorldMapChangedCallback = function()
		-- Log\('OnWorldMapChangedCallback')
		self:UpdateCalibration()
		self:UpdateMap()
	end

	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
		-- Log\('Player initialized')
		local zoneId = GetZoneId(GetUnitZoneIndex('player'))
		local zoneChanged = self.currentZoneId ~= zoneId
		self.currentZoneId = zoneId

		self.mainCalibration = MAIN_CALIBRATIONS[self.currentZoneId]

		if self:IsCampaignChanged() or zoneChanged then
			-- Log\('Campaign/zone changed')

			ZO_ClearTable(self.buffer)
			ZO_ClearTable(self.historyBuffer)
			self:UpdateMap()
		end

		if not self:ShouldListen() then  -- tp to different location
			-- Log('Should not listen, stopping')
			self:StopListening()
			return
		end

		self.onWorldMapChangedCallback()  -- TODO: it might be not necessery, refactor later

		if not self.listening then
			-- Log('Should be listening, starting')
			self:StartListening()
		end
	end)

	-- EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_DEACTIVATED, function()
	-- 	df('Player deactivated!')
	-- 	-- self:StopListening()
	-- end)

	self:InitializeTooltip()

	local map = LibSurfaceTools.Tools.FlexRect(ZO_WorldMapContainer, nil, self.OnMouseEnter, self.OnMouseExit)
		:SetTexture(self.sv.pinTexture)

	local composite = map.composite
	composite:SetDrawTier(DT_HIGH)
	-- control:SetDrawLayer(DL_CONTROLS)
	composite:SetDrawLevel(99)
	-- control:SetDesaturation(1)


	self.onCompositeShown = function()
		self:OnCompositeShown()
	end

	-- local perfMeter = CreateControlFromVirtual('$(parent)PerformanceMeter', composite, 'IMP_KillLocations_PerformanceMeterTemplate')
	-- self.perfMeter = perfMeter

	self.map = map

	--[[
	local original = self.GetKillLocations
	self.GetKillLocations = function(...)
		local start = GetGameTimeSeconds()
		local result = {original(...)}
		local executionTime = GetGameTimeSeconds() - start
		df('Execution time for GetKillLocations: %.3f us, #=%d', executionTime * 1000000, NonContiguousCount(result[1]))
		return unpack(result)
	end
	--]]

	self.onWorldMapSceneShown = function(oldState, newState)
        if newState == SCENE_SHOWING then
            self:OnWorldMapSceneShown()
        end
	end

	self.MIN_KILLS_TO_DISPLAY = 3

	local pvpFilters = WORLD_MAP_FILTERS.pvpPanel
	local checkBox = pvpFilters.checkBoxPool:AcquireObject()
	ZO_CheckButton_SetLabelText(checkBox, "Kill Locations History Pins")
	ZO_CheckButton_SetToggleFunction(checkBox, function(button, checked)
		self.map.composite:SetHidden(not checked)
    end)
	pvpFilters:AnchorControl(checkBox)
	ZO_CheckButton_SetChecked(checkBox, true)
end

function addon:InitializeTooltip()
	local g_tooltipOrder = ZO_WORLD_MAP_TOOLTIP_ORDER
	local function anchorTooltip()
		-- if IsInGamepadPreferredMode() then return end

		local prevControl = nil
		local placeAbove = GuiMouse:GetTop() > (GuiRoot:GetHeight() / 2)
		local placeLeft = GuiMouse:GetLeft() > (GuiRoot:GetWidth() / 2)

		for i = #g_tooltipOrder, 1, -1 do
			local tooltip = g_tooltipOrder[i]
			local tooltipControl = ZO_WorldMap_GetTooltipForMode(tooltip)
			if not tooltipControl:IsHidden() then
				prevControl = tooltipControl
				break
			end
		end

		local tooltipControl = KillLocationsTooltip
		tooltipControl:ClearAnchors()

		if prevControl then
			if placeLeft then
				if placeAbove then
					tooltipControl:SetAnchor(BOTTOMRIGHT, prevControl, TOPRIGHT, 0, -5)
				else
					tooltipControl:SetAnchor(TOPRIGHT, prevControl, BOTTOMRIGHT, 0, 5)
				end
			else
				if placeAbove then
					tooltipControl:SetAnchor(BOTTOMLEFT, prevControl, TOPLEFT, 0, -5)
				else
					tooltipControl:SetAnchor(TOPLEFT, prevControl, BOTTOMLEFT, 0, 5)
				end
			end
		else
			if placeLeft then
				tooltipControl:SetAnchor(RIGHT, GuiMouse, LEFT, -32, 0)
			else
				tooltipControl:SetAnchor(LEFT, GuiMouse, RIGHT, 32, 0)
			end
		end
	end

	local historyPinsMouseOver = {}

	local function LATEST_FIRST(l, r)
		return l[5] > r[5]
	end

	local function UpdateTooltip()
		if next(historyPinsMouseOver) then
			InitializeTooltip(KillLocationsTooltip)
			-- ZO_Tooltips_SetupDynamicTooltipAnchors(KillLocationTooltip, self.map.control)
			anchorTooltip()

			local now = os.time()

			local temp = {}
			for k, v in pairs(historyPinsMouseOver) do
				temp[#temp+1] = v
			end
			table.sort(temp, LATEST_FIRST)

			for i = 1, #temp do
				local v = temp[i]
				KillLocationsTooltip:AddLine(_formatKills(v[3]) .. (' (%s ago)'):format(IMP_PVP_UI_SHARED.SecondsToTime(now - v[5])), '', 1, 1, 1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT)
			end
		else
			ClearTooltip(KillLocationsTooltip)
		end
	end

	ZO_PostHook(WORLD_MAP_MANAGER, 'UpdateMouseoverTooltips', anchorTooltip)

	self.OnMouseEnter = function(tag, surface)
		-- local tag = self.map.surfaces[surface].tag  -- TODO: a mess...
		historyPinsMouseOver[tag] = self.historyBuffer[tag]
		-- TODO: this makes tooltip be updated several times
		-- because in composite update loop this function called for every new mouse over pin
		-- 2 new mouse over pins -> two UpdateTooltip calls, not ideal
		UpdateTooltip()
		self.map:AnimateScale(surface, 1, 1.3, 150)
	end

	self.OnMouseExit = function(tag, surface)
		-- local tag = self.map.surfaces[surface].tag
		historyPinsMouseOver[tag] = nil
		UpdateTooltip()
		self.map:AnimateScale(surface, 1.3, 1, 150)
	end
end

function addon:ShouldListen()
	return IsInImperialCity() and GetCurrentMapId() == 660 or IsInCyrodiil()
end

function addon:StartListening()
	self.listening = true
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_KILL_LOCATIONS_UPDATED, function() self:OnKillLocationsUpdate() end)

	CALLBACK_MANAGER:RegisterCallback('OnWorldMapChanged', self.onWorldMapChangedCallback)
	WORLD_MAP_SCENE:RegisterCallback('StateChange', self.onWorldMapSceneShown)

	ZO_PostHookHandler(self.map.composite, 'OnEffectivelyShown', self.onCompositeShown)
	self.map.composite:SetHidden(false)

	self:OnKillLocationsUpdate()
end

function addon:StopListening()
	EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_KILL_LOCATIONS_UPDATED)
	self.listening = false

	CALLBACK_MANAGER:UnregisterCallback('OnWorldMapChanged', self.onWorldMapChangedCallback)
	WORLD_MAP_SCENE:UnregisterCallback('StateChange', self.onWorldMapSceneShown)
	-- self.campaignId = nil

	self.map.composite:SetHidden(true)
	self.map:Clear()
end

function addon:IsCampaignChanged()
    local currentCampaignId = GetCurrentCampaignId()

	if self.campaignId == currentCampaignId then
        return false
    end

    self.campaignId = currentCampaignId
	return true
end

local function _getKills(killLocationIndex)
	local kills = {}

	for alliance = ALLIANCE_ITERATION_BEGIN, ALLIANCE_ITERATION_END do
		local numKills = GetNumKillLocationAllianceKills(killLocationIndex, alliance)
		kills[alliance] = numKills
	end

	return kills
end

local X, Z = 1, 2
local KILLS = 3
local PIN_TYPE = 4
local TIMESTAMP = 5

function addon:OnKillLocationsUpdate()
	-- Log\('OnKillLocationsUpdate')
	local start = GetGameTimeSeconds()

	local killLocations = self:GetKillLocations()
	self.buffer, killLocations = killLocations, self.buffer  -- killLocations now previous kill locations

	local historyBuffer = self.historyBuffer

	-- for hash, data in pairs(self.buffer) do
	-- 	if not killLocations[hash] then
	-- 		-- df('New kill location at %.1f, %.1f', data[1], data[2])
	-- 	end
	-- end

	for hash, data in pairs(killLocations) do
		if not self.buffer[hash] then
			-- df('Kill location at %.1f %.1f disappeared %d with (%d, %d, %d) result', data[X], data[Z], data[TIMESTAMP] data[KILLS][1], data[KILLS][2], data[KILLS][3])
			data[TIMESTAMP] = os.time()
			historyBuffer[#historyBuffer+1] = data

			self.mapIsDirty = true  -- buffer changed, so need to change pins on map

			if self.sv.chatNotifications then
				self:Notify(data)
			end
		end
	end

	local now = os.time()
	while #historyBuffer > 0 do
		if historyBuffer[1][TIMESTAMP] + self.sv.retention < now then
			remove(historyBuffer, 1)
			self.mapIsDirty = true  -- buffer changed, so need to change pins on map
		else
			break
		end
	end

	local duraion = GetGameTimeSeconds() - start
	-- self.perfMeter:SetText(('Kill locations update ~%.1f us'):format(duraion * 1000000))
	GLOBAL_IMP_METRIC_KILL_LOCATIONS_UPDATE_TIME = duraion

	self:UpdateMap()
end

local function _findCollisionHash(tbl, x, z)
	for dx = -1, 1 do
		for dz = -1, 1 do
			if dx ~= 0 or dz ~= 0 then  -- TODO: is it actually required?
				local h = _hash_function(x + dx, z + dz)
				if tbl[h] then return h, dx, dz end
			end
		end
	end
end

function addon:GetKillLocations()
	local ik_x, b_x, ik_z, b_z = unpack(self.calibration)

	local buffer = self.buffer

	local killLocations = {}
	local timestamp = os.time()
	for i = 1, GetNumKillLocations() do
		local pinType, n_x, n_z = GetKillLocationPinInfo(i)  -- TODO: utilize pin type?
		local w_x, w_z = (n_x - b_x) * ik_x, (n_z - b_z) * ik_z
		local data = {w_x, w_z , _getKills(i), pinType, timestamp}
		local _w_x_, _w_z_ = floor(w_x), floor(w_z)
		local hash = _hash_function(_w_x_, _w_z_)
		killLocations[hash] = data

		-- TODO: basically, can move all logic to find new and old kill locations here
		-- because it already does part of it (if buffer[hash] is basically check for new
		-- kill locations, and then check if it is collision because on map change or not)
		-- so only part to check for expired kill locations is missing
		if not buffer[hash] then
			local collisionHash = _findCollisionHash(buffer, _w_x_, _w_z_)
			if collisionHash then
				buffer[hash], buffer[collisionHash] = buffer[collisionHash], nil
				-- df('Found collision at (%.2f, %.2f), dx, dy: %d, %d', data[1] / 10000, data[2] / 10000, dx, dy)
			end
		end
		-- TODO: also have to check if kill locations appear in the same order every time
		-- TODO: it misses actual check if this is collision or not (difference in coordinates for example)
		-- TODO: there can be something more simple...
	end

	return killLocations
end

function addon:UpdateCalibration()
	local mapId = GetCurrentMapId()
	if self.mapId == mapId then return end
	self.mapId = mapId

	local k_x, b_x, k_z, b_z, e = _getCalibration(self.currentZoneId)
	-- df('Calibration updated (%f)', k_x)
	self.calibration = {e / k_x, b_x, e / k_z, b_z}

	self.mapIsDirty = true
end

local function _sum3(tbl)
	return tbl[1] + tbl[2] + tbl[3]
end

function addon:OnWorldMapSceneShown()
	-- Log\('World map is showing')
	self:UpdateMap()
end

function addon:OnCompositeShown()
	-- Log('Composite is showing')
	self:UpdateMap()
end

local function _getKillLocationSize(kills)
	local totalKills = _sum3(kills)

	if totalKills > 32 then
		return LARGE_KILL_LOCATION_SIZE
	elseif totalKills > 8 then
		return MEDIUM_KILL_LOCATION_SIZE
	else
		-- technically >2, for simplicity - everything else
		return SMALL_KILL_LOCATION_SIZE
	end
end

function addon:UpdateMap()
	-- Log('UpdateMap called')
	if WORLD_MAP_SCENE:IsHiding() then
		self.mapIsDirty = true
		-- Log\('Map is hidden, don\'t update mapd')
		return
	end

	if self.map.composite:IsHidden() then
		self.mapIsDirty = true
		-- Log\('Map is hidden by filter, don\'t update map')
		return
	end

	if not self.mapIsDirty then
		-- Log\('Map isn\'t  dirty, don\'t update map')
		return
	end

	-- Log\('Map is going to be updated')

	local map = self.map
	local historyBuffer = self.historyBuffer

	local ik_x, b_x, ik_z, b_z = unpack(self.calibration)

	map:Clear()
	local now = os.time()
	for i = 1, #historyBuffer do
		local data = historyBuffer[i]
		local n_x, n_z = data[X], data[Z]

		if _sum3(data[KILLS]) >= self.MIN_KILLS_TO_DISPLAY then
			local size = _getKillLocationSize(data[KILLS]) * self.sv.pinScale
			-- local alpha = sqrt(1 - 0.7 * (now - data[TIMESTAMP]) / self.sv.retention)

			local fraction = 0.7 * (now - data[TIMESTAMP]) / self.sv.retention
			local alpha = zo_sqrt(1 - fraction)

			map:Add(n_x / ik_x + b_x, n_z / ik_z + b_z, 0, 0, size, size, nil, i)
				:SetColor(unpack(self.sv.pinColor))
				:SetSurfaceAlpha(alpha)
		end
	end

	self.mapIsDirty = false
end

local CYRODIIL_KEEPS = {{[3]=233304.44097519,[4]=172706.66360855,[5]=274751.09696388,[6]=333055.55582047,[7]=411775.55918694,[8]=493939.99576569,[9]=578973.35290909,[10]=702386.67726517,[11]=727419.97241974,[12]=839937.80612946,[13]=660986.66191101,[14]=775444.44799423,[15]=567548.87104034,[16]=492311.12003326,[17]=416622.22146988,[18]=225117.77281761,[19]=408531.09955788,[20]=574197.76916504,[22]=568893.31340790,[23]=551077.78310776,[24]=610086.67945862,[34]=384046.67377472,[35]=440899.99794960,[36]=432657.77826309,[37]=829197.76439667,[38]=857153.35607529,[39]=808362.24555969,[40]=250884.44352150,[41]=261684.44752693,[42]=205955.55007458,[43]=472035.55703163,[44]=518495.55969238,[45]=524386.64436349,[46]=711120.00942230,[47]=676633.35800171,[48]=724293.35117340,[49]=284286.67783737,[50]=310306.66828156,[51]=253768.89109612,[52]=709366.67919159,[53]=710097.78976440,[54]=763795.55463791,[55]=198346.65954113,[56]=165402.21869946,[57]=195904.44862843,[61]=308335.54267883,[62]=354088.90247345,[63]=316688.89522552,[64]=396093.33872795,[65]=387008.87560844,[66]=435628.89099121,[67]=532748.87800217,[68]=473326.65324211,[69]=476980.00073433,[70]=556237.75720596,[71]=583133.33988190,[72]=614264.42861557,[73]=685506.64186478,[74]=653748.86989594,[75]=628248.87037277,[76]=766431.09321594,[77]=787728.90567780,[78]=739648.87857437,[79]=582197.78537750,[80]=542488.87300491,[81]=555155.57527542,[82]=399313.33065033,[83]=438186.67531013,[84]=408902.22787857,[85]=205993.33941936,[86]=205793.33603382,[87]=252944.43964958,[105]=383513.33141327,[106]=603839.99347687,[107]=928304.43382263,[108]=837613.34419250,[109]=68335.555493832,[110]=159280.00211716,[118]=429199.99361038,[119]=568508.86344910,[120]=880224.46632385,[121]=812319.99397278,[122]=176217.77951717,[123]=119740.00185728,[124]=384308.87460709,[125]=602308.86936188,[126]=870722.23424911,[127]=772991.12081528,[128]=226133.33165646,[129]=111960.00128984,[132]=359382.21216202,[133]=644602.23913193,[134]=495682.20973015,[149]=305539.99543190,[151]=477328.89652252,[152]=686460.01815796,[154]=588526.66616440,[155]=360000.01430511,[156]=612848.87790680,[157]=664939.99958038,[158]=242464.43808079,[159]=163859.99321938,[160]=669931.11371994,[161]=618322.19362259,[162]=540133.35704803,[163]=579942.22640991,[164]=221306.66673183,[165]=794517.75550842,},{[3]=175693.33314896,[4]=323000.01382828,[5]=274735.56995392,[6]=421124.45831299,[7]=275657.77301788,[8]=107748.88843298,[9]=279742.21110344,[10]=322262.22753525,[11]=178804.44228649,[12]=328713.32764626,[13]=422695.54734230,[14]=575806.67734146,[15]=565571.12932205,[16]=682362.19882965,[17]=572642.20714569,[18]=571466.68434143,[19]=776951.13420486,[20]=774351.11999512,[22]=729080.02138138,[23]=781851.11284256,[24]=759997.78509140,[34]=775039.97087479,[35]=791051.08976364,[36]=757268.90563965,[37]=352331.10189438,[38]=308699.99527931,[39]=323833.34636688,[40]=208599.99954700,[41]=166846.66275978,[42]=176228.89578342,[43]=661631.10733032,[44]=693608.88004303,[45]=656562.20912933,[46]=290108.88934135,[47]=319359.98797417,[48]=318351.11975670,[49]=318602.23412514,[50]=279548.88343811,[51]=276531.10027313,[52]=211726.66549683,[53]=169482.21623898,[54]=194384.44077969,[55]=339920.01414299,[56]=346080.00516891,[57]=288811.11741066,[61]=404915.54141045,[62]=396713.34624290,[63]=438868.88027191,[64]=254099.99489784,[65]=308268.87488365,[66]=276817.76881218,[67]=124737.77681589,[68]=93688.890337944,[69]=132035.55345535,[70]=269348.88958931,[71]=319853.33561897,[72]=272482.21635818,[73]=432220.01194954,[74]=396091.10355377,[75]=430777.78816223,[76]=609579.98037338,[77]=557553.35092545,[78]=563340.00825882,[79]=587637.78209686,[80]=544482.23114014,[81]=589760.00547409,[82]=589579.99944687,[83]=580388.90361786,[84]=543937.80231476,[85]=546948.90975952,[86]=583253.32403183,[87]=580280.00593185,[105]=891786.69452667,[106]=882848.91843796,[107]=306422.23358154,[108]=115024.44744110,[109]=285299.98660088,[110]=101599.99877214,[118]=840908.88500214,[119]=838073.31323624,[120]=282873.33250046,[121]=180077.77631283,[122]=168855.56280613,[123]=271591.09711647,[124]=806624.47214127,[125]=811253.30924988,[126]=354597.77712822,[127]=144548.89297485,[128]=135075.55425167,[129]=320060.01472473,[132]=510986.68575287,[133]=501813.35210800,[134]=267668.90287399,[149]=661235.57090759,[151]=172295.55547237,[152]=631448.86493683,[154]=532911.12184525,[155]=461004.43601608,[156]=639997.78032303,[157]=719851.13620758,[158]=417653.32221985,[159]=417704.43320274,[160]=137588.88840675,[161]=215144.44053173,[162]=294193.32742691,[163]=162595.55518627,[164]=494551.12218857,[165]=461771.10075951,}}

local function _getNearestKeepTo(x_w, z_w)
	local closestKeepId, minDistance = nil, math.huge

	for keepId, kx_w in pairs(CYRODIIL_KEEPS[1]) do
		local kz_w = CYRODIIL_KEEPS[2][keepId]

		local distance = (kx_w - x_w)^2 + (kz_w - z_w)^2

		if distance < minDistance then
			minDistance = distance
			closestKeepId = keepId
		end
	end

	return closestKeepId, CYRODIIL_KEEPS[1][closestKeepId], CYRODIIL_KEEPS[2][closestKeepId], minDistance
end

local MAX_DISTANCE_TO_NOTIFY_KEEP_M = 250  -- meters
function addon:Notify(data)
	local x_w, z_w, kills = data[X], data[Z], data[KILLS]

	if _sum3(kills) < self.MIN_KILLS_TO_DISPLAY then return end

	local ik_x, b_x, ik_z, b_z = unpack(self.mainCalibration)

	local x_n, z_n = x_w / ik_x + b_x, z_w / ik_z + b_z
	-- df('Normalized coordinates of kill on IC map: %.2f, %.2f', x_n * 100, z_n * 100)

	local text  -- TODO: add icon of swords to prettify a bit?

	-- IC
	if self.currentZoneId == ZONE_ID_IC then
		local district = _getDistrict(0.5, 0.5, x_n, z_n)
		text = string.format('(%.1f, %.1f) %s - %s', x_n * 100, z_n * 100, district, _formatKills(kills))
	-- Cyrodiil
	elseif self.currentZoneId == ZONE_ID_CYRODIIL then
		local closestKeepId, kx_w, kz_w, distanceSq = _getNearestKeepTo(x_w, z_w)

		-- df('Kill location world coordinates: %d, %d', x_w, z_w)
		-- df('Keep world coordinates: %d, %d', kx_w, kz_w)

		local distance_m = sqrt(distanceSq) / 100
		-- df('Distance: %.2f', distance / 100)

		if distance_m <= MAX_DISTANCE_TO_NOTIFY_KEEP_M then
			local keepName = GetKeepName(closestKeepId)
			local heading = _getHeading(kx_w, kz_w, x_w, z_w)
			text = string.format('(%.1f, %.1f) %s (%s, %dm) - %s', x_n * 100, z_n * 100, keepName, heading, distance_m, _formatKills(kills))
		else
			text = string.format('(%.1f, %.1f) - %s', x_n * 100, z_n * 100, _formatKills(kills))
		end
	else
		error('Notification in not intended zone')
	end

	IMP_PVP_UI_SHARED.SendMessageToChat(text, self.sv.chatTab or 1)
end
-- ----------------------------------------------------------------------------


function IMP_KLH_Initialize(sv)
	addon:Initialize(sv)
	IMP_PVP_UI_KillLocationsHistory = addon
end

function IMP_KLH_UpdateMap()
	addon:UpdateMap()
end

function IMP_KLH_SetTexture(texture)
	addon.map:SetTexture(texture)
end
