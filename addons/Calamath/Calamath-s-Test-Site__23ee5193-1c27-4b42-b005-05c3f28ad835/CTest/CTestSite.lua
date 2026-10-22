--
-- Calamath's Test Site [CTEST]
--
-- Copyright (c) 2026 Calamath
--
-- This software is released under the Artistic License 2.0
-- https://opensource.org/licenses/Artistic-2.0
--

-- ---------------------------------------------------------------------------------------
-- CT_MinimalAddonFramework: Minimal Add-on Framework Template Class            rel.1.1.12
-- ---------------------------------------------------------------------------------------
local CT_MinimalAddonFramework = ZO_Object:Subclass()
function CT_MinimalAddonFramework:New(...)
	local newObject = setmetatable({}, self)
	newObject:Initialize(...)
	newObject:ConfigDebug()
	newObject:OnInitialized(...)
	return newObject
end
function CT_MinimalAddonFramework:Initialize(name, attributes)
	if type(name) ~= "string" or name == "" then return end
	self._name = name
	self._isInitialized = false
	if type(attributes) == "table" then
		for k, v in pairs(attributes) do
			if self[k] == nil then
				self[k] = v
			end
		end
	end
	self._external = {
		name = self.name or self._name, 
		version = self.version, 
		author = self.author, 
	}
	assert(not _G[name], name .. " is already loaded.")
	_G[name] = self._external
	EVENT_MANAGER:RegisterForEvent(self._name, EVENT_ADD_ON_LOADED, function(event, addonName)
		if addonName ~= self._name then return end
		EVENT_MANAGER:UnregisterForEvent(self._name, EVENT_ADD_ON_LOADED)
		self:OnAddOnLoaded(event, addonName)
		self._isInitialized = true
	end)
end
function CT_MinimalAddonFramework:ConfigDebug()
	local Dummy = function() end
	self.LDL = { Verbose = Dummy, Debug = Dummy, Info = Dummy, Warn = Dummy, Error = Dummy, }
	self._isDebugMode = false
end
function CT_MinimalAddonFramework:OnInitialized(name, attributes)
--  Available when overridden in an inherited class
end
function CT_MinimalAddonFramework:OnAddOnLoaded(event, addonName)
--  Should be Overridden
end

-- ---------------------------------------------------------------------------------------
-- CTestSite
-- ---------------------------------------------------------------------------------------
local CTEST = CT_MinimalAddonFramework:New("CTest", {
	name = "CTest", 
	version = "260627.2", 
	author = "Calamath", 
})
local L = GetString

do
	local TEST_FONT_FACE = {
		"EsoUI/Common/Fonts/ESO_FWNTLGUDC70-DB.slug", 
		"EsoUI/Common/Fonts/ESO_FWUDC_70-M.slug", 
		"EsoUI/Common/Fonts/ESO_KafuPenji-M.slug", 
		"EsoUI/Common/Fonts/MYingHeiPRC-W5.slug", 
		"EsoUI/Common/Fonts/MYoyoPRC-Medium.slug", 
	}
	function CTEST:OverrideGetBookMediumFontInfoAPI()
		local orgGetBookMediumFontInfo = GetBookMediumFontInfo
		_G["GetBookMediumFontInfo"] = function(mediumId, isGamepad, ...)
			if self.bookFontTestMode then
				local returns = { orgGetBookMediumFontInfo(mediumId, isGamepad, ...) }
				local testFontFace = self.bookFontTestIndex == 0 and TEST_FONT_FACE[math.random(#TEST_FONT_FACE)] or TEST_FONT_FACE[self.bookFontTestIndex] or TEST_FONT_FACE[1]
				returns[1] = testFontFace	-- *string* _titleFontName_
				returns[4] = testFontFace	-- *string* _bodyFontName_
				return unpack(returns)
			else
				return orgGetBookMediumFontInfo(mediumId, isGamepad, ...)
			end
		end
	end
end

do
	local testBookTitle = "ポラーノの広場"
	local testBookBody = "　そのころわたくしは、モリーオ市の博物局に勤めて居りました。\n　十八等官でしたから役所のなかでも、ずうっと下の方でしたし俸給もほんのわずかでしたが、受持ちが標本の採集や整理で生れ付き好きなことでしたから、わたくしは毎日ずいぶん愉快にはたらきました。殊にそのころ、モリーオ市では競馬場を植物園に拵え直すというので、その景色のいいまわりにアカシヤを植え込んだ広い地面が、切符売場や信号所の建物のついたまま、わたくしどもの役所の方へまわって来たものですから、わたくしはすぐ宿直という名前で月賦で買った小さな蓄音器と二十枚ばかりのレコードをもって、その番小屋にひとり住むことになりました。わたくしはそこの馬を置く場所に板で小さなしきいをつけて一疋の山羊を飼いました。毎朝その乳をしぼってつめたいパンをひたしてたべ、それから黒い革のかばんへすこしの書類や雑誌を入れ、靴もきれいにみがき、並木のポプラの影法師を大股にわたって市の役所へ出て行くのでした。\n　あのイーハトーヴォのすきとおった風、夏でも底に冷たさをもつ青いそら、うつくしい森で飾られたモリーオ市、郊外のぎらぎらひかる草の波。\n　またそのなかでいっしょになったたくさんのひとたち、ファゼーロとロザーロ、羊飼のミーロや、顔の赤いこどもたち、地主のテーモ、山猫博士のボーガント・デストゥパーゴなど、いまこの暗い巨きな石の建物のなかで考えていると、みんなむかし風のなつかしい青い幻燈のように思われます。では、わたくしはいつかの小さなみだしをつけながら、しずかにあの年のイーハトーヴォの五月から十月までを書きつけましょう。\n\n　一、遁げた山羊\n\n五月のしまいの日曜でした。わたくしは賑やかな市の教会の鐘の音で眼をさましました。もう日はよほど登って、まわりはみんなきらきらしていました。時計を見るとちょうど六時でした。わたくしはすぐチョッキだけ着て山羊を見に行きました。すると小屋のなかはしんとして藁が凹んでいるだけで、あのみじかい角も白い髯も見えませんでした。\n「あんまりいい天気なもんだから大将ひとりででかけたな。」\nわたくしは半分わらうように半分つぶやくようにしながら、向うの信号所からいつも放して遊ばせる輪道の内側の野原、ポプラの中から顔をだしている市はずれの白い教会の塔までぐるっと見まわしました。けれどもどこにもあの白い頭もせなかも見えていませんでした。うまやを一まわりしてみましたがやっぱりどこにも居ませんでした。\n"
	function CTEST:RegisterBookFontTestShortcut()
		SLASH_COMMANDS["/ctest.showbook"] = function(arg)
			if not self.overrideGetBookMediumFontInfo then
				self:OverrideGetBookMediumFontInfoAPI()
				self.overrideGetBookMediumFontInfo = true
			end
			local loreReaderDefaultScene = IsInGamepadPreferredMode() and GAMEPAD_LORE_READER_DEFAULT_SCENE or LORE_READER_DEFAULT_SCENE
			if loreReaderDefaultScene then
				self.bookFontTestIndex = tonumber(arg) or 0
				self.bookFontTestMode = true
				SCENE_MANAGER:CallWhen(loreReaderDefaultScene:GetName(), SCENE_HIDDEN, function()
					self.bookFontTestIndex = 0
					self.bookFontTestMode = false
				end)
			end
			LORE_READER:Show(testBookTitle, testBookBody, BOOK_MEDIUM_YELLOWED_PAPER, true)
		end
	end
end

function CTEST:OnAddOnLoaded(event, addonName)
	self.bookFontTestIndex = 0
	self.bookFontTestMode = false
	self.overrideGetBookMediumFontInfo = false
	self:RegisterBookFontTestShortcut()
end
