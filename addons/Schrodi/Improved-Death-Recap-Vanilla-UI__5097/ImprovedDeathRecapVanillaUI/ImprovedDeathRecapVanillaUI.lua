local LRU = {}
LRU.__index = LRU

local function normalizeKey(key)
    if not key then return nil end

    -- ESO formatting cleanup
    key = zo_strformat(SI_PLAYER_NAME, key)

    -- lowercase
    key = zo_strlower(key)

    -- strip whitespace
    key = key:gsub("%s+", "")

    -- strip control characters
    key = key:gsub("[%z\1-\31\127]", "")

    return key
end

function LRU.new(capacity)
    return setmetatable({
        capacity = capacity,
        map = {},   -- normalizedKey -> node
        head = nil,
        tail = nil,
        size = 0,
    }, LRU)
end

local function remove(self, node)
    if node.prev then node.prev.next = node.next end
    if node.next then node.next.prev = node.prev end
    if self.head == node then self.head = node.next end
    if self.tail == node then self.tail = node.prev end
end

local function insert_front(self, node)
    node.prev = nil
    node.next = self.head
    if self.head then self.head.prev = node end
    self.head = node
    if not self.tail then self.tail = node end
end

function LRU:get(key)
    local nKey = normalizeKey(key)
    local node = self.map[nKey]
    if not node then return nil end

    remove(self, node)
    insert_front(self, node)

    return node.value
end

function LRU:set(key, value)
    local nKey = normalizeKey(key)
    if not nKey then return end

    local node = self.map[nKey]

    if node then
        node.value = value
        remove(self, node)
        insert_front(self, node)
        return
    end

    node = { key = nKey, value = value }
    self.map[nKey] = node
    insert_front(self, node)

    if self.size == self.capacity then
        local old = self.tail
        remove(self, old)
        self.map[old.key] = nil
    else
        self.size = self.size + 1
    end
end

local nameCache = LRU.new(256)

-- Puts what we know about a player into the name cache. The death recap always
-- shows the @name, but IDR only records character names, so @names come from
-- whatever saw the player: the reticle, the battleground scoreboard, the group,
-- or the game's own killing attack list. Fields a source doesn't have (nil) keep
-- the cached value - the scoreboard, for example, knows the team but not the
-- alliance or the AvA rank.
local function RememberPlayer(characterName, displayName, team, alliance, rank)
	if not characterName or characterName == "" or not displayName or displayName == "" then return end
	local cached = nameCache:get(characterName)
	nameCache:set(characterName, {
		name = displayName,
		team = team or (cached and cached.team),
		alliance = alliance or (cached and cached.alliance),
		rank = rank or (cached and cached.rank),
	})
end

-- Called when the death recap is built, so attackers that were never under the
-- reticle still get their @name where the game knows it.
local function RememberPlayersAtDeath()
	-- The game's own (short) list of killing attacks has the @name of every
	-- player in it, the killing blow included.
	for i = 1, GetNumKillingAttacks() do
		if DoesKillingAttackHaveAttacker(i) then
			local rawName, _, _, avaRank, isPlayer, _, alliance, _, displayName = GetKillingAttackerInfo(i)
			if isPlayer then
				RememberPlayer(rawName, displayName, GetKillingAttackerBattlegroundTeam(i), alliance, avaRank)
			end
		end
	end

	-- Group members.
	for i = 1, GetGroupSize() do
		local unitTag = GetGroupUnitTagByIndex(i)
		if unitTag and DoesUnitExist(unitTag) then
			RememberPlayer(GetUnitName(unitTag), GetUnitDisplayName(unitTag), GetUnitBattlegroundTeam(unitTag), GetUnitAlliance(unitTag), GetUnitAvARank(unitTag))
		end
	end

	-- Everyone in the battleground. The scoreboard data is there even if the
	-- scoreboard was never opened.
	if IsActiveWorldBattleground() then
		local roundIndex = GetCurrentBattlegroundRoundIndex()
		for entryIndex = 1, GetNumScoreboardEntries(roundIndex) do
			local characterName, displayName, battlegroundTeam = GetScoreboardEntryInfo(entryIndex, roundIndex)
			RememberPlayer(characterName, displayName, battlegroundTeam)
		end
	end
end

-- Hit-type icon shown right before the damage number (see control.hitTypeIcon
-- in the row factory override, and its placement/texture logic in the render
-- loop below). Placeholder vanilla icons for now (armory build icons - not
-- thematically "correct" but readable at this size) - swap the paths below
-- once better ones turn up.
local HIT_TYPE_ICON_SIZE = 32
-- Placeholder icons - not thematically "correct" yet, swap the paths below
-- once better ones turn up. (Turned out the earlier "these aren't rendering"
-- issue wasn't about this icon set at all - the window was hardcoded too
-- narrow and clipping this whole area off-screen; see the SetDimensions
-- widening below.)
local HIT_TYPE_ICON_FILE = {
	healed = "/esoui/art/armory/buildicons/buildicon_2.dds",
	normal = "/esoui/art/armory/buildicons/buildicon_54.dds",
	blocked = "/esoui/art/armory/buildicons/buildicon_3.dds",
	overtime = "/esoui/art/armory/buildicons/buildicon_12.dds",
	-- Oblivion damage (unblockable/unshieldable) - shown instead of
	-- blocked/overtime/normal when the hit's damage type is oblivion, since
	-- that's the more informative distinction for this particular hit.
	oblivion = "/esoui/art/armory/buildicons/buildicon_48.dds",
	-- Shield (absorbed damage).
	absorbed = "/esoui/art/armory/buildicons/buildicon_34.dds",
}

-- Direct-hit damage number color, by damage type - matches
-- ImprovedDeathRecap.lua's own dmgColors table (used for its chat log line
-- coloring) exactly (converted from its hex strings to 0-1 floats).
-- CombatMetrics uses this same palette too (via LibCombat.GetDamageColor,
-- byte-for-byte identical to IDR's table) - so this keeps colors consistent
-- across all three addons rather than using our own custom hues. DoT ticks
-- of the same type reuse these, darkened (see Darken below) rather than
-- needing a second hand-picked set. healed/absorbed/oblivion stay their own
-- fixed colors regardless of damage type (see the render loop) - blocked no
-- longer does (dropped the yellow override - only the block icon marks it
-- now, color follows damage type like a normal hit) - this table only
-- applies to direct hits, blocked hits, and DoT ticks.
local DMG_TYPE_COLOR = {
	[DAMAGE_TYPE_NONE]     = {0.902, 0.902, 0.902}, -- E6E6E6
	[DAMAGE_TYPE_GENERIC]  = {0.902, 0.902, 0.902}, -- E6E6E6
	[DAMAGE_TYPE_PHYSICAL] = {0.957, 0.949, 0.910}, -- f4f2e8
	[DAMAGE_TYPE_FIRE]     = {1.000, 0.400, 0.000}, -- ff6600
	[DAMAGE_TYPE_SHOCK]    = {1.000, 1.000, 0.400}, -- ffff66
	[DAMAGE_TYPE_OBLIVION] = {0.835, 0.502, 1.000}, -- d580ff
	[DAMAGE_TYPE_COLD]     = {0.702, 0.855, 1.000}, -- b3daff
	[DAMAGE_TYPE_EARTH]    = {0.749, 0.647, 0.490}, -- bfa57d
	[DAMAGE_TYPE_MAGIC]    = {0.600, 0.600, 1.000}, -- 9999ff
	[DAMAGE_TYPE_DROWN]    = {0.800, 0.800, 0.800}, -- cccccc
	[DAMAGE_TYPE_DISEASE]  = {0.769, 0.541, 0.624}, -- c48a9f
	[DAMAGE_TYPE_POISON]   = {0.624, 0.694, 0.129}, -- 9fb121
	[DAMAGE_TYPE_BLEED]    = {0.761, 0.039, 0.220}, -- c20a38
}

-- Scales a color down (no desaturation) - used to derive a DoT's color from
-- its direct-hit color instead of hand-picking a second color per damage
-- type. Plain darkening (rather than also blending toward gray) keeps the
-- hue clearly readable, just dimmer - a fire DoT still reads as orange.
local function Darken(color, factor)
	factor = factor or 0.55
	return color[1] * factor, color[2] * factor, color[3] * factor
end

-- Settings: the minimum |damage|/|healing| an event needs to show up in the
-- recap at all. Populated from LibAddonMenu once the addon's saved vars are
-- ready (see the EVENT_ADD_ON_LOADED handler near the bottom); the constant
-- here is both the shipped default and the fallback if that hasn't run yet.
local DEFAULT_MIN_AMOUNT = 0
local savedVars

-- Colors the "(x/y HP)" text after each attack name green-to-red by remaining
-- health. ImprovedDeathRecap.lua colors its own chat log line the same way
-- conceptually (floor(current/max * 31) + 1 into GetHealthColor, the game's
-- own 32-step health bar gradient) - but GetHealthColor isn't actually an
-- addon-accessible API function ("function expected instead of nil" at
-- runtime), so this interpolates the same green-at-full/red-at-empty look
-- directly instead: green->yellow from 100% to 50%, yellow->red from 50% to 0%.
local function GetHPColorHex(currenthp, maxhp)
	if not maxhp or maxhp <= 0 then return "FFFFFF" end
	local t = zo_clamp(currenthp / maxhp, 0, 1)
	local r = t > 0.5 and (1 - t) * 2 or 1
	local g = t < 0.5 and t * 2 or 1
	return string.format("%02X%02X00", zo_floor(r * 255 + 0.5), zo_floor(g * 255 + 0.5))
end

-- Colors a player's id by their battleground team, if we're in one - plain default
-- (white) text everywhere else (Cyrodiil, duels, etc). Separately, an AW rank icon
-- tinted by the player's alliance is always shown next to the name, in every context,
-- the same way the floating nameplate above a reticle-targeted player looks
-- (ZO_UnitFrameObject:UpdateRank in the base game's unitframes.lua uses the same
-- GetAvARankIcon + GetAllianceColor:UnpackRGBA()/SetColor tinting approach). Team,
-- alliance and rank are captured opportunistically whenever we see the player via
-- their nameplate or the battleground scoreboard (see the hooks near the bottom of
-- this file) and cached alongside their name, since by the time a death recap is
-- shown the attacker may no longer be nearby to query live.
local function ToHex(r, g, b)
	if not r then return nil end
	return string.format("%02X%02X%02X", zo_floor(r * 255 + 0.5), zo_floor(g * 255 + 0.5), zo_floor(b * 255 + 0.5))
end

local function GetAttackerColorHex(cacheEntry)
	if not cacheEntry then return nil end

	local team = cacheEntry.team
	if team and team ~= 0 and team ~= BATTLEGROUND_TEAM_INVALID then
		local hex = ToHex(GetInterfaceColor(INTERFACE_COLOR_TYPE_BATTLEGROUND_TEAM, team))
		if hex then return hex end
	end

	return nil
end

-- The rank icon is always shown (regardless of battleground/team status) whenever we
-- have a cached alliance for the attacker, tinted to that alliance's color - mirrors
-- ZO_UnitFrameObject:UpdateRank's showRank = rank ~= 0 or IsUnitPlayer(unitTag) (death
-- recap attackers we have a cache entry for are always players).
local function GetAttackerRankIconInfo(cacheEntry)
	if not cacheEntry then return nil end

	local alliance = cacheEntry.alliance
	if not alliance or alliance == ALLIANCE_NONE then return nil end

	local rankIconFile = GetAvARankIcon(cacheEntry.rank or 0)
	if not rankIconFile or rankIconFile == "" then return nil end

	return rankIconFile, alliance
end

local origOPD = DEATH_RECAP.OnPlayerDead
DEATH_RECAP.OnPlayerDead = function(self)
    self.isPlayerDead = true
    if not self.waitingToShowPrompt then
        self.waitingToShowPrompt = true
        EVENT_MANAGER:RegisterForUpdate("DeathRecapUpdate", 500, function()
            self.waitingToShowPrompt = false
            EVENT_MANAGER:UnregisterForUpdate("DeathRecapUpdate")
            self.animateOnShow = true
            self:SetupDeathRecap()
        end)
    end
end

local ICON_ANIMATION_START_INDEX = 1
local ICON_ANIMATION_END_INDEX = 3
local STYLE_ANIMATION_START_INDEX = 4
local STYLE_ANIMATION_END_INDEX = 6
local TEXT_ANIMATION_INDEX = 7
local COUNT_ANIMATION_START_INDEX = 8
local COUNT_ANIMATION_END_INDEX = 10
local HEALTH_ANIMATION_START_INDEX = 11
local HEALTH_ANIMATION_END_INDEX = 13

-- Instead of SetCustomFactoryBehavior, override the main factory
local originalFactory = DEATH_RECAP.attackPool.m_Factory
DEATH_RECAP.attackPool:SetFactory(function(objectKey)
    -- Create the control using original factory - PASS THE POOL!
    local control = originalFactory(DEATH_RECAP.attackPool, objectKey)
    
    -- Only create timeline if control was created successfully
    if control then
        -- Alliance-tinted AW rank icon shown next to the attacker's name (see
        -- GetAttackerRankIconInfo/the render loop in SetupAttacks below). Created once
        -- per pooled row control here, positioned/tinted/shown-or-hidden per attack.
        if not control.rankIcon then
            control.rankIcon = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
            control.rankIcon:SetDimensions(26, 26)
            control.rankIcon:SetHidden(true)
        end

        -- Hit-type icon (blocked/dot/heal/direct) shown just before the damage
        -- number - positioned/textured/shown-or-hidden per attack below.
        if not control.hitTypeIcon then
            control.hitTypeIcon = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
            control.hitTypeIcon:SetDimensions(HIT_TYPE_ICON_SIZE, HIT_TYPE_ICON_SIZE)
            control.hitTypeIcon:SetHidden(true)
        end

        control.timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ImprovedDeathRecapVanillaUIAttackAnimation")
        local animationSpeed = 2 -- total length is 75ms, so the desired playback rate is desiredMS/75


        if control.timeline then
            local nestedTimeline = control.timeline:GetAnimationTimeline(1)
            if nestedTimeline then
                local iconTexture = control:GetNamedChild("Icon")
                local styleContainer = control:GetNamedChild("SkillStyle")
                local textContainer = control:GetNamedChild("Text")

                for i = ICON_ANIMATION_START_INDEX, ICON_ANIMATION_END_INDEX do
                    local animation = nestedTimeline:GetAnimation(i)
                    if animation then
                    	animation:SetDuration(animation:GetDuration()*animationSpeed)
                        animation:SetAnimatedControl(iconTexture)
                    end
                end
                for i = STYLE_ANIMATION_START_INDEX, STYLE_ANIMATION_END_INDEX do
                    local animation = nestedTimeline:GetAnimation(i)
                    if animation then
                    	animation:SetDuration(animation:GetDuration()*animationSpeed)
                        animation:SetAnimatedControl(styleContainer)
                    end
                end
                local textAnimation = nestedTimeline:GetAnimation(TEXT_ANIMATION_INDEX)
                if textAnimation then
                	textAnimation:SetDuration(textAnimation:GetDuration()*animationSpeed)
                    textAnimation:SetAnimatedControl(textContainer)
                end
                if not nestedTimeline.isKillingBlow then
                    local numAttackHitsContainer = control:GetNamedChild("NumAttackHits")
                    for i = COUNT_ANIMATION_START_INDEX, COUNT_ANIMATION_END_INDEX do
                        local animation = nestedTimeline:GetAnimation(i)
                        if animation then
                        	animation:SetDuration(animation:GetDuration()*animationSpeed)
                            animation:SetAnimatedControl(numAttackHitsContainer)
                        end
                    end
                end
            end
        end
    end
    
    return control
end)

DEATH_RECAP.attackPool:SetCustomFactoryBehavior(function() end)

--

-- Vanilla staggers each row's reveal one after another (see the reference
-- copy this replaced, kept as a comment further down in git history) by
-- incrementing "delay" per row and offsetting each row's timeline by it.
-- Show everything at once instead: every row (and the killing blow/telvar
-- loss/hint timelines) starts at offset 0, so nothing waits on a per-row
-- delay. This also sidesteps the vanilla zo_max(0, delay - lastRowDuration)
-- call entirely (the crash fixed earlier when the attack pool ended up with
-- zero active rows) since delay/lastRowDuration are no longer computed here.
local origAnimate = DEATH_RECAP.Animate
DEATH_RECAP.Animate = function(self)
    local activeObjects = self.attackPool:GetActiveObjects()
    for attackRowIndex, attackControl in ipairs(activeObjects) do
        local timeline = attackControl.timeline
        if timeline then
            local nestedTimeline = timeline:GetAnimationTimeline(1)
            if nestedTimeline then
                nestedTimeline.isKillingBlow = (attackRowIndex == #activeObjects)
                timeline:SetAnimationTimelineOffset(nestedTimeline, 0)
                timeline:PlayFromStart()
            end
        end
    end

    local nestedKBTimeline = self.killingBlowTimeline:GetAnimationTimeline(1)
    self.killingBlowTimeline:SetAnimationTimelineOffset(nestedKBTimeline, 0)
    self.killingBlowTimeline:PlayFromStart()

    if GetNumTelvarStonesLost() > 0 then
        local nestedTelvarLossTimeline = self.telvarLossTimeline:GetAnimationTimeline(1)
        self.telvarLossTimeline:SetAnimationTimelineOffset(nestedTelvarLossTimeline, 0)
        self.telvarLossTimeline:PlayFromStart()
    end

    local nestedHintTimeline = self.hintTimeline:GetAnimationTimeline(1)
    self.hintTimeline:SetAnimationTimelineOffset(nestedHintTimeline, 0)
    self.hintTimeline:PlayFromStart()
end

--

-- Window layout / scrolling.
--
-- Vanilla's window is a fixed 752x726 (deathrecap.xml) whose whole content
-- (title, attacks, tel var loss, hints) sits in one gamepad-only scroll
-- container. We used to grow that window by a fixed amount per row (capped at
-- 12 rows), which ran off the bottom of smaller screens. Instead:
--   * the Attacks container (parent of every attack row) is moved into its own
--     keyboard scroll container (mouse wheel + scrollbar, fade at the edges),
--     sitting where Attacks used to be - title/header above and tel var/hints
--     below stay fixed,
--   * that list is as tall as its rows, but never taller than what's left of
--     GuiRoot's height after the window's top offset, the bottom reserve for
--     the death screen's revive buttons, and the fixed parts above/below it,
--   * the window (and its background art) is sized to exactly that content,
--   * the list starts scrolled to the bottom (newest hit / killing blow).
-- Everything is recomputed on every recap setup, on every show, and on
-- screen/UI-scale resize - and once more a frame later, in case any
-- resizeToFitDescendents heights we read weren't updated yet.
local WINDOW_WIDTH = 860            -- widened from vanilla 752 for the DamageLabel shift + hit-type icon (see render loop)
local WINDOW_TOP_OFFSET = 105       -- vanilla: TOP of GuiRoot, offsetY 105
local BOTTOM_RESERVE = 165          -- death screen revive buttons: ZO_Death* containers are 155 tall at the bottom of GuiRoot
local BOTTOM_PADDING = 10
local BG_EXTRA_WIDTH = 212          -- background art vs window size - same deltas as before (vanilla: 964/900 vs 752)
local BG_LEFT_EXTRA_WIDTH = 148
local BG_EXTRA_HEIGHT = 298
local LIST_WIDTH = 840              -- incl. the 16px scrollbar; rows end at ~790 (hit-type icon)
local ATTACKS_INSET_X = 18          -- vanilla Attacks offsetX
local TELVAR_OFFSET_X = 38          -- keeps tel var loss where vanilla put it (Attacks center + 55)
local ROW_MIN_HEIGHT = 64           -- ZO_DeathRecapAttack DimensionConstraints minY
local ROW_GAP = 10                  -- row anchor spacing in the render loop
local FALLBACK_ABOVE_HEIGHT = 76    -- header bottom: offsetY 50 + ZoFontWinH3
local MIN_WINDOW_TOP_OFFSET = 60    -- how far up the window may move when rows don't fit
local TELVAR_MIN_HEIGHT = 32        -- ZO_DeathRecapTelvarStoneLoss minY
local HINTS_OFFSET_X = 18           -- keyboard template: HintsContainer TOP to TelvarStoneLoss BOTTOM, offsetX 18
local HINTS_OFFSET_Y = 6
local HINTS_HEADER_OFFSET_Y = 6     -- HintsHeader TOPLEFT offsetY 6
local HINTS_HEADER_FALLBACK_HEIGHT = 26
local HINTS_LIST_OFFSET_Y = 3       -- Hints TOPLEFT to HintsHeader BOTTOMLEFT, offsetY 3
local HINTS_WIDTH = 700
local HINT_GAP = 10                 -- DeathRecap:AddHint anchor spacing
local KEYBIND_SCROLL_STEP = 2 * (ROW_MIN_HEIGHT + ROW_GAP)
local LAYOUT_UPDATE_NAME = "ImprovedDeathRecapVanillaUILayout"

local recapScrollChild = DEATH_RECAP.scrollControl
local attacksContainer = recapScrollChild:GetNamedChild("Attacks")
local attacksHeader = recapScrollChild:GetNamedChild("AttacksHeader")
local telvarLossControl = recapScrollChild:GetNamedChild("TelvarStoneLoss")
local hintsContainer = recapScrollChild:GetNamedChild("HintsContainer")
local hintsHeader = hintsContainer:GetNamedChild("HintsHeader")
local hintsControl = hintsContainer:GetNamedChild("Hints")

local attackList = WINDOW_MANAGER:CreateControlFromVirtual("ImprovedDeathRecapVanillaUIAttackList", recapScrollChild, "ZO_ScrollContainer")
local attackListChild = attackList:GetNamedChild("ScrollChild")
-- ZO_ScrollContainer puts its child on DL_BACKGROUND, which the rows would
-- inherit - below the recap's own background art. Keep them on the same
-- layer they had in vanilla's container.
attackListChild:SetDrawLayer(DL_CONTROLS)
-- Our list clips its own overflow; keep that overflow out of the outer
-- container's extents so the outer one never thinks it has to scroll.
attackList:SetExcludeFromResizeToFitExtents(true)

attacksContainer:SetParent(attackListChild)
attacksContainer:SetDrawLayer(DL_CONTROLS)
attacksContainer:ClearAnchors()
attacksContainer:SetAnchor(TOPLEFT, attackListChild, TOPLEFT, ATTACKS_INSET_X, 0)

-- Default fade is up to 128px - on a list only a few rows tall that hid most
-- of the top rows. Keep just a hint of it at the edges.
ZO_Scroll_SetMaxFadeDistance(attackList, 24)

-- The outer (vanilla) container is sized to fit now, but in case a measured
-- height is a few px short, don't let its fade gradient dim the hints.
DEATH_RECAP.scrollContainer.useFadeGradient = false
ZO_UpdateScrollFade(false, DEATH_RECAP.scrollContainer.scroll, ZO_SCROLL_DIRECTION_VERTICAL)

-- True from recap setup / show until the player scrolls the list themselves.
local pendingScrollToBottom = false

local function ScrollAttackListToBottom()
	ZO_Scroll_UpdateScrollBar(attackList)
	local _, verticalExtents = attackList.scroll:GetScrollExtents()
	if verticalExtents > 0 then
		ZO_Scroll_ScrollAbsoluteInstantly(attackList, verticalExtents)
	end
end

ZO_Scroll_SetOnInteractWithScrollbarCallback(attackList, function()
	pendingScrollToBottom = false
end)
-- Extents only settle once the rows have been laid out - scroll again then.
ZO_PostHookHandler(attackList.scroll, "OnScrollExtentsChanged", function()
	if pendingScrollToBottom then
		ScrollAttackListToBottom()
	end
end)

local function GetAttackRowsHeight()
	local pool = DEATH_RECAP.attackPool
	local numRows = pool:GetActiveObjectCount()
	if numRows == 0 then return 0 end
	local height = (numRows - 1) * ROW_GAP
	for _, row in pairs(pool:GetActiveObjects()) do
		height = height + zo_max(row:GetHeight(), ROW_MIN_HEIGHT)
	end
	return height
end

-- Vanilla's Hints box is a fixed 700x200 no matter how many tips it holds
-- (usually 1-3 lines) - size it to its tips instead.
local function GetHintsHeight()
	local height = 0
	local numHints = 0
	for _, hint in pairs(DEATH_RECAP.hintPool:GetActiveObjects()) do
		local text = hint:GetNamedChild("Text")
		local textHeight = text and text:GetTextHeight() or 0
		height = height + zo_max(textHeight, hint:GetHeight())
		numHints = numHints + 1
	end
	if numHints > 1 then
		height = height + (numHints - 1) * HINT_GAP
	end
	return height
end

local function LayoutDeathRecap()
	-- Re-applied every time: DEATH_RECAP:ApplyStyle (platform style change)
	-- re-applies vanilla's template, which re-anchors tel var loss / hints and
	-- restores Attacks' minY 360 (which would leave a gap under few rows).
	-- Only the minimum height is touched - the max values are kept as they
	-- are, so whatever "unconstrained" is stays unconstrained (setting them to
	-- 0 collapsed Attacks to 0 height in 2.19 -> no scroll extents).
	-- minY is set to the rows' height below, so the list's scroll extents
	-- never depend on Attacks' own resizeToFit height being up to date.
	local rowsHeight = GetAttackRowsHeight()
	local minX, _, maxX, maxY = attacksContainer:GetDimensionConstraints()
	attacksContainer:SetDimensionConstraints(minX, rowsHeight, maxX, maxY)

	attackList:ClearAnchors()
	attackList:SetAnchor(LEFT, recapScrollChild, LEFT, 0, 0, ANCHOR_CONSTRAINS_X)
	attackList:SetAnchor(TOP, attacksHeader, BOTTOM, 0, 0, ANCHOR_CONSTRAINS_Y)

	-- Tel var loss row only takes space when there's a loss to show.
	local showTelvar = GetNumTelvarStonesLost() > 0
	local showTips = not savedVars or savedVars.showTips ~= false
	telvarLossControl:SetHidden(not showTelvar)
	hintsContainer:SetHidden(not showTips)
	telvarLossControl:ClearAnchors()
	telvarLossControl:SetAnchor(TOP, attackList, BOTTOM, TELVAR_OFFSET_X, 0)
	hintsContainer:ClearAnchors()
	if showTelvar then
		hintsContainer:SetAnchor(TOP, telvarLossControl, BOTTOM, HINTS_OFFSET_X, HINTS_OFFSET_Y)
	else
		hintsContainer:SetAnchor(TOP, attackList, BOTTOM, TELVAR_OFFSET_X + HINTS_OFFSET_X, HINTS_OFFSET_Y)
	end

	-- From the header's anchor offset + its label height rather than screen
	-- rects, which may be stale while the window is hidden.
	local _, _, _, _, _, headerOffsetY = attacksHeader:GetAnchor(0)
	local aboveHeight = (headerOffsetY or 0) + attacksHeader:GetHeight()
	if not (aboveHeight > 0 and aboveHeight < 300) then
		aboveHeight = FALLBACK_ABOVE_HEIGHT
	end

	-- Computed from the parts rather than read off HintsContainer, whose
	-- resizeToFit height may not reflect the Hints resize below yet.
	local belowHeight = 0
	if showTelvar then
		belowHeight = belowHeight + zo_max(telvarLossControl:GetHeight(), TELVAR_MIN_HEIGHT)
	end
	if showTips then
		local hintsHeight = GetHintsHeight()
		hintsControl:SetDimensions(HINTS_WIDTH, hintsHeight)
		local headerHeight = hintsHeader:GetHeight()
		if headerHeight <= 0 then headerHeight = HINTS_HEADER_FALLBACK_HEIGHT end
		belowHeight = belowHeight + HINTS_OFFSET_Y + HINTS_HEADER_OFFSET_Y + headerHeight + HINTS_LIST_OFFSET_Y + hintsHeight
	end

	local guiHeight = GuiRoot:GetHeight()
	local fixedHeight = aboveHeight + belowHeight + BOTTOM_PADDING

	-- Move the window up (down to MIN_WINDOW_TOP_OFFSET) only as far as
	-- needed to fit every row; past that the list scrolls.
	local topOffset = zo_clamp(guiHeight - BOTTOM_RESERVE - fixedHeight - rowsHeight, MIN_WINDOW_TOP_OFFSET, WINDOW_TOP_OFFSET)
	ZO_DeathRecap:ClearAnchors()
	ZO_DeathRecap:SetAnchor(TOP, GuiRoot, TOP, 0, topOffset)

	local maxListHeight = zo_max(guiHeight - topOffset - BOTTOM_RESERVE - fixedHeight, ROW_MIN_HEIGHT)
	local listHeight = zo_max(zo_min(rowsHeight, maxListHeight), ROW_MIN_HEIGHT)
	attackList:SetDimensions(LIST_WIDTH, listHeight)

	local windowHeight = fixedHeight + listHeight
	ZO_DeathRecap:SetDimensions(WINDOW_WIDTH, windowHeight)
	ZO_DeathRecapBgKeyboardBackground:SetDimensions(WINDOW_WIDTH + BG_EXTRA_WIDTH, windowHeight + BG_EXTRA_HEIGHT)
	ZO_DeathRecapBgKeyboardBackgroundBGLeft:SetDimensions(WINDOW_WIDTH + BG_LEFT_EXTRA_WIDTH, windowHeight + BG_EXTRA_HEIGHT)

	if pendingScrollToBottom then
		ScrollAttackListToBottom()
	end
end

-- Same layout again on the next frame, once resizeToFitDescendents controls
-- (rows, hints) have definitely picked up their new contents.
local function QueueLayout()
	EVENT_MANAGER:UnregisterForUpdate(LAYOUT_UPDATE_NAME)
	EVENT_MANAGER:RegisterForUpdate(LAYOUT_UPDATE_NAME, 0, function()
		EVENT_MANAGER:UnregisterForUpdate(LAYOUT_UPDATE_NAME)
		LayoutDeathRecap()
	end)
end

local function RelayoutAndScrollToBottom()
	pendingScrollToBottom = true
	LayoutDeathRecap()
	QueueLayout()
end

-- After SetupDeathRecap rather than SetupAttacks: hints are (re)built after
-- the attacks, and the vanilla fallback path (orig SetupAttacks below) needs
-- the same layout too.
ZO_PostHook(DEATH_RECAP, "SetupDeathRecap", RelayoutAndScrollToBottom)
DEATH_RECAP_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
	if newState == SCENE_FRAGMENT_SHOWING then
		RelayoutAndScrollToBottom()
	end
end)
EVENT_MANAGER:RegisterForEvent(LAYOUT_UPDATE_NAME, EVENT_SCREEN_RESIZED, function() QueueLayout() end)
EVENT_MANAGER:RegisterForEvent(LAYOUT_UPDATE_NAME, EVENT_ALL_GUI_SCREENS_RESIZED, function() QueueLayout() end)

-- Keybinds (bindings.xml, unbound by default) - while dead the mouse usually
-- steers the camera, so the wheel only reaches the list in cursor mode.
ZO_CreateStringId("SI_BINDING_NAME_IIDR_SCROLL_UP", "Scroll death recap up")
ZO_CreateStringId("SI_BINDING_NAME_IIDR_SCROLL_DOWN", "Scroll death recap down")
-- The addon's only global: the keybinds call ImprovedDeathRecapVanillaUI.Scroll.
ImprovedDeathRecapVanillaUI = {}
function ImprovedDeathRecapVanillaUI.Scroll(direction)
	if ZO_DeathRecap:IsHidden() then return end
	pendingScrollToBottom = false
	ZO_Scroll_ScrollRelative(attackList, direction * KEYBIND_SCROLL_STEP)
end

local orig = DEATH_RECAP.SetupAttacks
DEATH_RECAP.SetupAttacks = function(self)
	-- Fallbacks to vanilla rows still get our layout (SetupDeathRecap post-hook).
	local deathHistory = IDR.GetLatestDeath()
	if not deathHistory then
		return orig(self)
	end
	RememberPlayersAtDeath()

    local startAlpha = self:GetStartAlpha()
    self.attackPool:ReleaseAllObjects()
    self.killingBlowIcon:SetAlpha(startAlpha)
    -- Vanilla's own single-hit-death rendering shows this as a big standalone
    -- icon (see the commented-out "else" branch further down) - our per-row
    -- numAttackHitsKillIcon replaces that, so this should always stay hidden.
    -- Force it here on every call: if an earlier recap fell through to the
    -- vanilla orig(self) fallback below (e.g. IDR had no history yet, right
    -- after a reloadui) and that vanilla pass showed+anchored it for a
    -- single-hit death, this control's hidden state otherwise carries over
    -- as-is into our own render below and can be left visible/misplaced
    -- against our differently-sized window - which is likely what shows up
    -- as a stray icon, especially on a near-empty ("almost empty") recap.
    self.killingBlowIcon:SetHidden(true)

    --local attacks = {}
    --for i = 1, GetNumKillingAttacks() do
    --    local attackName, attackDamage, attackIcon, wasKillingBlow, castTimeAgoMS, durationMS, numAttackHits, _, abilityFxIcon = GetKillingAttackInfo(i)
    --    local attackInfo =
    --    {
    --        index = i,
    --        attackName = attackName,
    --        attackDamage = 123,
    --        attackIcon = attackIcon,
    --        wasKillingBlow = wasKillingBlow,
    --        lastUpdateAgoMS = castTimeAgoMS - durationMS,
    --        numAttackHits = 456,
    --        abilityFxIcon = abilityFxIcon,
    --    }
	--
    --    table.insert(attacks, attackInfo)
    --end

	local events = deathHistory.events or deathHistory.data or {}
	local deathtime = deathHistory.deathtimems
	-- No row cap anymore - every event IDR kept is shown, the list scrolls.
	local attacks = {}
	for i = events.first or 1, events.last or #events do
		local event = events[i]
		if event.timems > (deathtime + 1000) then break end
		local result = event.result
		local attackerCacheEntry = nameCache:get(event.source)
		local attackerName = (attackerCacheEntry and attackerCacheEntry.name) or event.source
		local attackerColorHex = GetAttackerColorHex(attackerCacheEntry)
		local attackerRankIconFile, attackerRankIconAlliance = GetAttackerRankIconInfo(attackerCacheEntry)
		local fall = result == ACTION_RESULT_FALL_DAMAGE
		local blocked = result == ACTION_RESULT_BLOCKED or result == ACTION_RESULT_BLOCKED_DAMAGE
		local normal = result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE
		local overtime = result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL
		local absorbed = result == ACTION_RESULT_ABSORBED or result == ACTION_RESULT_DAMAGE_SHIELDED
		local healed = result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL
		local overhealed = healed and event.value == 0 and event.currenthp == event.maxhp
		-- Critical damage (direct or dot) - marked with a trailing "!" on the
		-- number instead of its own color, so it layers on top of whichever
		-- color the hit already got from blocked/oblivion/overtime/normal etc.
		local critical = result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DOT_TICK_CRITICAL
		-- Oblivion damage type (unblockable/unshieldable) - independent of the
		-- result-based categorization above, since it's a property of the damage
		-- itself rather than how the hit landed. event.dmgtype is captured by
		-- ImprovedDeathRecap.lua's IDR.CombatEvent (data.dmgtype = damageType).
		-- Anything we can't otherwise categorize (in practice just fall/
		-- environmental damage - the only ACTION_RESULT that isn't blocked/
		-- overtime/healed/normal/absorbed) is displayed as oblivion too, since
		-- there's no dedicated icon/color for "unknown".
		local recognized = blocked or overtime or healed or normal or absorbed
		local oblivion = event.dmgtype == DAMAGE_TYPE_OBLIVION or not recognized

		local attackName = fall and "Fall damage" or ZO_CachedStrFormat("<<!aC:1>>", GetAbilityName(event.ability))
		
		local attackTime = (event.timems - deathtime) / 1000
		local attackIcon = GetAbilityIcon(event.ability)
		local attackDamage = event.value
		local hpLeft = event.currenthp
		local stamLeft = event.currentstam
		
		local attackInfo =
		{
			-- Every category (including uncategorized/environmental, folded into
			-- oblivion above) now gets an icon next to the damage number instead
			-- (see control.hitTypeIcon below), so no text suffix is needed here.
			attackerName = attackerName,
			attackerColorHex = attackerColorHex,
			attackerRankIconFile = attackerRankIconFile,
			attackerRankIconAlliance = attackerRankIconAlliance,
			attackName = string.format("%s%s (|c%s%s/%s HP|r)", attackName, event.hits == 1 and "" or string.format(" %dx", event.hits), GetHPColorHex(event.currenthp, event.maxhp), event.currenthp, event.maxhp),
			-- Absorbed (shield) shown with a leading "-" too, same as healing,
			-- since it's also damage that didn't actually land.
			attackDamage = (healed or absorbed) and -attackDamage or attackDamage,
			attackIcon = attackIcon,
			wasKillingBlow = event.currenthp == 0,
			lastUpdateAgoMS = attackTime * 1000,
			numAttackHits = attackTime,
			abilityFxIcon = nil,
			absorbed = absorbed,
			blocked = blocked,
			healed = healed,
			overtime = overtime,
			normal = normal,
			oblivion = oblivion,
			critical = critical,
			dmgtype = event.dmgtype,
		}
		
		-- Below the configured threshold, hide it - applies to healing the same
		-- as damage (previously only damage was filtered; a negative/healing
		-- value always passed regardless of size, which meant tiny heals never
		-- got hidden at all). The killing blow itself is always kept regardless
		-- of size: if every event in a death gets filtered out, the attackPool
		-- ends up with zero active rows and the base game's own DeathRecap:Animate
		-- (EsoUI/Ingame/DeathRecap/DeathRecap.lua) throws trying to compute
		-- zo_max(0, delay - lastRowDuration) with lastRowDuration still nil -
		-- keeping at least the killing blow guarantees there's always a row.
		local minAmount = (savedVars and savedVars.minAmount) or DEFAULT_MIN_AMOUNT
		-- Overheal ticks (a HOT ticking while already at full HP) always have
		-- 0 effective value, so they'd otherwise show up as a pointless "0"
		-- heal row - drop them outright rather than just filtering by amount.
		if not overhealed and (attackInfo.wasKillingBlow or math.abs(attackInfo.attackDamage) >= minAmount) then
			table.insert(attacks, attackInfo)
		end
	end

	-- Belt-and-suspenders for the same zero-rows crash the killing-blow-always-
	-- kept rule above guards against: if IDR simply has no events at all for
	-- this death (so there was never a killing blow to keep), fall back to the
	-- vanilla recap instead of leaving the attackPool with zero active rows.
	if #attacks == 0 then
		return orig(self)
	end

    --table.sort(attacks, SortAttacks)

    --Cert requires that we show the display name if there's no way other way to get it from character name
    --But it's not the desire of design to show so much name so we only show the double name if we absolutely must
    local showBothPlayerNames = IsConsoleUI() and tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_PRIMARY_PLAYER_NAME_GAMEPAD)) == PRIMARY_PLAYER_NAME_SETTING_PREFER_CHARACTER

    local prevAttackControl
    for i, attackInfo in ipairs(attacks) do
        local attackControl = self.attackPool:AcquireObject(i)
        local iconControl = attackControl:GetNamedChild("Icon")
        local attackTextControl = attackControl:GetNamedChild("AttackText")
        local attackNameControl = attackTextControl:GetNamedChild("AttackName")
        local damageControl = attackControl:GetNamedChild("Damage")
        local damageLabelControl = attackControl:GetNamedChild("DamageLabel")
        local skillStyleControl = attackControl:GetNamedChild("SkillStyle")
        local skillStyleIconControl = skillStyleControl:GetNamedChild("Icon")
        local numAttackHitsContainer = attackControl:GetNamedChild("NumAttackHits")

        iconControl:SetTexture(attackInfo.attackIcon)
        attackNameControl:SetText(zo_strformat(SI_DEATH_RECAP_ATTACK_NAME, attackInfo.attackName))
		-- Critical hits get a trailing "!" on the number itself rather than a
		-- distinct color, so it layers on top of whichever color below applies.
		damageControl:SetText(zo_strformat(SI_NUMBER_FORMAT, attackInfo.attackDamage) .. (attackInfo.critical and "!" or ""))
		if attackInfo.healed then
			damageControl:SetColor(0.5, 0.9, 0.5, 1) -- soft green, matches IDR's RESULT_COLOR_HEAL
		elseif attackInfo.absorbed then
			damageControl:SetColor(0.7, 0.5, 0.7, 1) -- soft purple/mauve, matches IDR's RESULT_COLOR_ABSORBED (not blue)
		elseif attackInfo.oblivion then
			damageControl:SetColor(0.39, 0.17, 0.30, 1) -- same as disease's DoT color before today's disease/oblivion recolors
		else
			-- Plain direct hits, blocked hits, and DoT ticks are all colored by
			-- damage type instead (fire orange, poison green, etc. - see
			-- DMG_TYPE_COLOR above; blocked no longer gets its own yellow - the
			-- block icon already marks it, so it colors like a normal hit here).
			-- DoTs get a darkened (not desaturated) version of the same type's
			-- color, so e.g. a fire DoT still reads as orange, just dimmer.
			local dmgColor = DMG_TYPE_COLOR[attackInfo.dmgtype] or DMG_TYPE_COLOR[DAMAGE_TYPE_NONE]
			if attackInfo.overtime then
				local r, g, b = Darken(dmgColor)
				damageControl:SetColor(r, g, b, 1)
			else
				damageControl:SetColor(dmgColor[1], dmgColor[2], dmgColor[3], 1)
			end
		end

		-- Oblivion takes priority over blocked/overtime/absorbed/normal when both
		-- apply - it's the more informative fact about a hit that (by definition)
		-- wasn't actually blocked or shielded despite what the base result says.
		local hitTypeIconFile = attackInfo.oblivion and HIT_TYPE_ICON_FILE.oblivion
			or attackInfo.absorbed and HIT_TYPE_ICON_FILE.absorbed
			or attackInfo.blocked and HIT_TYPE_ICON_FILE.blocked
			or attackInfo.overtime and HIT_TYPE_ICON_FILE.overtime
			or attackInfo.healed and HIT_TYPE_ICON_FILE.healed
			or attackInfo.normal and HIT_TYPE_ICON_FILE.normal
			or nil
		local hitTypeIcon = attackControl.hitTypeIcon
		if hitTypeIcon then
			if hitTypeIconFile and damageLabelControl then
				hitTypeIcon:SetTexture(hitTypeIconFile)
				hitTypeIcon:ClearAnchors()
				-- Anchored off DamageLabel ("DAMAGE"), not the number itself - the
				-- label sits at a fixed position every row (see the reanchor below),
				-- while the number's own left edge shifts with its digit count. Going
				-- off the label instead keeps every row's icon lined up in a column.
				-- The label and number are baseline-aligned but the number's font is
				-- much bigger, so its vertical center sits higher than the label's -
				-- nudge the icon up a few px to match the number instead (estimate,
				-- tell me if it needs more).
				hitTypeIcon:SetAnchor(LEFT, damageLabelControl, RIGHT, 6, -4)
				hitTypeIcon:SetHidden(false)
			else
				hitTypeIcon:SetHidden(true)
			end
		end

		-- The vanilla number+"DAMAGE" label pair is right-anchored (DamageLabel
		-- pinned at a fixed offset, Damage glued immediately to its left), so
		-- big hits with more digits grow further LEFT - past where the "RECENT
		-- DAMAGE" header above the whole list actually starts. Nudge the fixed
		-- anchor point right to close that gap (485 -> 535, estimated from the
		-- base game's own row/header offsets - tell me if it still looks off
		-- and I'll adjust the number).
		if damageLabelControl then
			local textContainer = attackControl:GetNamedChild("Text")
			damageLabelControl:ClearAnchors()
			damageLabelControl:SetAnchor(RIGHT, textContainer, LEFT, 535, 0)
		end

        local killingBlowOffsetX = 72
        if attackInfo.abilityFxIcon then
            skillStyleIconControl:SetTexture(attackInfo.abilityFxIcon)
            skillStyleControl:SetAlpha(startAlpha)
            skillStyleControl:SetHidden(false)
            killingBlowOffsetX = 32
        else
            skillStyleControl:SetHidden(true)
        end

        iconControl:SetAlpha(startAlpha)
        attackControl:GetNamedChild("Text"):SetAlpha(startAlpha)

        --if attackInfo.numAttackHits > 1 then
            local numAttackHitsCountLabel = numAttackHitsContainer:GetNamedChild("Count")
            local numAttackHitsHitIcon = numAttackHitsContainer:GetNamedChild("HitIcon")
            local numAttackHitsKillIcon = numAttackHitsContainer:GetNamedChild("KillIcon")
            numAttackHitsContainer:SetAlpha(startAlpha)
            numAttackHitsContainer:SetHidden(false)
            numAttackHitsCountLabel:SetText(string.format("%.2fs", attackInfo.numAttackHits))
            if attackInfo.wasKillingBlow then
                numAttackHitsHitIcon:SetHidden(true)
                numAttackHitsKillIcon:SetHidden(false)
                self.killingBlowIcon:SetHidden(true)
            else
                numAttackHitsHitIcon:SetHidden(false)
                numAttackHitsKillIcon:SetHidden(true)
            end

            local anchorControl = iconControl
            if attackInfo.abilityFxIcon then
                anchorControl = skillStyleControl
            end
            numAttackHitsContainer:ClearAnchors()
            numAttackHitsContainer:SetAnchor(RIGHT, anchorControl, LEFT, -15)
        --else
        --    numAttackHitsContainer:SetHidden(true)
        --    if attackInfo.wasKillingBlow then
        --        self.killingBlowIcon:SetHidden(false)
        --        self.killingBlowIcon:SetAnchor(CENTER, attackControl, TOPLEFT, killingBlowOffsetX, 32)
        --    end
        --end

		local attackerNameControl = attackTextControl:GetNamedChild("AttackerName")
		local frameControl
		if attackInfo.attackerColorHex then
			attackerNameControl:SetText(string.format("|c%s%s|r", attackInfo.attackerColorHex, attackInfo.attackerName))
		else
			attackerNameControl:SetText(attackInfo.attackerName)
		end
		attackerNameControl:SetHidden(false)

		local rankIcon = attackControl.rankIcon
		if rankIcon then
			if attackInfo.attackerRankIconFile then
				rankIcon:SetTexture(attackInfo.attackerRankIconFile)
				rankIcon:SetColor(GetAllianceColor(attackInfo.attackerRankIconAlliance):UnpackRGBA())
				rankIcon:ClearAnchors()
				-- attackerNameControl's own box is anchored TOPLEFT+TOPRIGHT of its
				-- parent (see ZO_DeathRecapAttack in deathrecap.xml) - it's stretched
				-- to fill the whole name column up to the damage number, not sized to
				-- the text itself. Anchoring off its RIGHT edge (as before) lands out
				-- near the damage number instead of next to the visible @name. Use the
				-- actual rendered text width instead, so the icon sits right after the
				-- name (or after the "..." if it got truncated) regardless of box width.
				rankIcon:SetAnchor(LEFT, attackerNameControl, LEFT, attackerNameControl:GetTextWidth() + 4, 0)
				rankIcon:SetHidden(false)
			else
				rankIcon:SetHidden(true)
			end
		end

		attackNameControl:ClearAnchors()
		attackNameControl:SetAnchor(TOPLEFT, attackerNameControl, BOTTOMLEFT, 0, 2)
		attackNameControl:SetAnchor(TOPRIGHT, attackerNameControl, BOTTOMRIGHT, 0, 2)
		frameControl = isBoss and iconControl:GetNamedChild("BossBorder") or iconControl:GetNamedChild("Border")
        frameControl:SetHidden(false)
		-- (Window sizing moved to LayoutDeathRecap, run after SetupDeathRecap.)

        --local attackerNameControl = attackTextControl:GetNamedChild("AttackerName")
        --local frameControl
        --if DoesKillingAttackHaveAttacker(attackInfo.index) then
        --    local attackerRawName, attackerChampionPoints, attackerLevel, attackerAvARank, isPlayer, isBoss, alliance, minionName, attackerDisplayName = GetKillingAttackerInfo(attackInfo.index)
        --    local battlegroundTeam = GetKillingAttackerBattlegroundTeam(attackInfo.index)
		--
        --    local attackerNameLine
        --    if isPlayer then
        --        local nameToShow
        --        if showBothPlayerNames then
        --            nameToShow = ZO_GetPrimaryPlayerNameWithSecondary(attackerDisplayName, attackerRawName)
        --        else
        --            nameToShow = ZO_GetPrimaryPlayerName(attackerDisplayName, attackerRawName)
        --        end
		--
        --        if battlegroundTeam == BATTLEGROUND_TEAM_INVALID then
        --            local coloredRankIconMarkup = ZO_GetColoredAvARankIconMarkup(attackerAvARank, alliance, 32)
        --            if minionName == "" then
        --                attackerNameLine = zo_strformat(SI_DEATH_RECAP_RANK_ATTACKER_NAME, coloredRankIconMarkup, attackerAvARank, nameToShow)
        --            else
        --                attackerNameLine = zo_strformat(SI_DEATH_RECAP_RANK_ATTACKER_NAME_MINION, coloredRankIconMarkup, attackerAvARank, nameToShow, minionName)
        --            end
        --        else
        --            local battlegroundTeamIconMarkup = ZO_GetBattlegroundIconMarkup(battlegroundTeam, 32)
        --            if minionName == "" then
        --                attackerNameLine = zo_strformat(SI_DEATH_RECAP_BATTLEGROUND_ALLIANCE_ATTACKER_NAME, battlegroundTeamIconMarkup, nameToShow)
        --            else
        --                attackerNameLine = zo_strformat(SI_DEATH_RECAP_BATTLEGROUND_ALLIANCE_ATTACKER_NAME_MINION, battlegroundTeamIconMarkup, nameToShow, minionName)
        --            end
        --        end
        --    else
        --        if minionName == "" then
        --            attackerNameLine = zo_strformat(SI_DEATH_RECAP_ATTACKER_NAME, attackerRawName)
        --        else
        --            attackerNameLine = zo_strformat(SI_DEATH_RECAP_ATTACKER_NAME_MINION, attackerRawName, minionName)
        --        end
        --    end
		--
        --    attackerNameControl:SetText(attackerNameLine)
        --    attackerNameControl:SetHidden(false)
		--
        --    attackNameControl:ClearAnchors()
        --    attackNameControl:SetAnchor(TOPLEFT, attackerNameControl, BOTTOMLEFT, 0, 2)
        --    attackNameControl:SetAnchor(TOPRIGHT, attackerNameControl, BOTTOMRIGHT, 0, 2)
		--
        --    frameControl = isBoss and iconControl:GetNamedChild("BossBorder") or iconControl:GetNamedChild("Border")
        --    frameControl:SetHidden(false)
        --else
        --    attackerNameControl:SetHidden(true)
		--
        --    attackNameControl:ClearAnchors()
        --    attackNameControl:SetAnchor(TOPLEFT)
        --    attackNameControl:SetAnchor(TOPRIGHT)
        --    
        --    frameControl = iconControl:GetNamedChild("Border")
        --    frameControl:SetHidden(false)
        --end

        if prevAttackControl then
            attackControl:SetAnchor(TOPLEFT, prevAttackControl, BOTTOMLEFT, 0, 10)
        else
            attackControl:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)
        end

        prevAttackControl = attackControl
    end
end


EVENT_MANAGER:RegisterForEvent("ImprovedDeathRecapVanillaUI", EVENT_ADD_ON_LOADED, function(eventCode, addOnName)
    if addOnName ~= "ImprovedDeathRecapVanillaUI" then return end
    EVENT_MANAGER:UnregisterForEvent("ImprovedDeathRecapVanillaUI", EVENT_ADD_ON_LOADED)

	-- This addon used to be called ImprovedImprovedDeathRecap; both at once would hook everything twice.
	local addOnManager = GetAddOnManager()
	for i = 1, addOnManager:GetNumAddOns() do
		local name, _, _, _, isEnabled = addOnManager:GetAddOnInfo(i)
		if name == "ImprovedImprovedDeathRecap" and isEnabled then
			EVENT_MANAGER:RegisterForEvent("ImprovedDeathRecapVanillaUIWarn", EVENT_PLAYER_ACTIVATED, function()
				EVENT_MANAGER:UnregisterForEvent("ImprovedDeathRecapVanillaUIWarn", EVENT_PLAYER_ACTIVATED)
				CHAT_ROUTER:AddSystemMessage("|cFFAA33Improved Death Recap: Vanilla UI:|r the old ImprovedImprovedDeathRecap is still enabled. Please disable it in the AddOns menu.")
			end)
		end
	end

	savedVars = ZO_SavedVars:NewAccountWide("ImprovedDeathRecapVanillaUI_SV", 1, nil, { minAmount = DEFAULT_MIN_AMOUNT, showTips = true })

	local LAM = LibAddonMenu2
	local panelData = {
		type = "panel",
		name = "Improved Death Recap: Vanilla UI",
		displayName = "Improved Death Recap: Vanilla UI",
		author = "Schrodi",
		version = "3.1.1",
		registerForRefresh = true,
		registerForDefaults = true,
	}
	LAM:RegisterAddonPanel("ImprovedDeathRecapVanillaUIOptions", panelData)

	local optionsData = {
		{
			type = "slider",
			name = "Minimum damage/healing to show",
			tooltip = "Attacks and heals below this amount won't be shown in the death recap.",
			min = 0,
			max = 10000,
			step = 50,
			default = DEFAULT_MIN_AMOUNT,
			getFunc = function() return savedVars.minAmount end,
			setFunc = function(value) savedVars.minAmount = value end,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Show tips section",
			tooltip = "The vanilla \"tips\" list under the attacks. Hiding it leaves more room for attack rows on small screens.",
			default = true,
			getFunc = function() return savedVars.showTips ~= false end,
			setFunc = function(value)
				savedVars.showTips = value
				LayoutDeathRecap()
			end,
			width = "full",
		},
	}
	LAM:RegisterOptionControls("ImprovedDeathRecapVanillaUIOptions", optionsData)

	local frame = UNIT_FRAMES:GetFrame("reticleover")
	ZO_PostHook(frame, "RefreshControls", function(self)
			if IsUnitPlayer(self.unitTag) then
				local unitTag = self.unitTag
				RememberPlayer(GetUnitName(unitTag), GetUnitDisplayName(unitTag), GetUnitBattlegroundTeam(unitTag), GetUnitAlliance(unitTag), GetUnitAvARank(unitTag))
				--d(GetRawUnitName(self.unitTag) .. " -> " .. ZO_GetSecondaryPlayerNameFromUnitTag(self.unitTag))
			end
		end)
end)

-- Battleground scoreboard rows. RememberPlayersAtDeath reads the same data when
-- the recap is built; this keeps the cache fresh while the board is open.
SecurePostHook(ZO_Battleground_Scoreboard_Player_Row_Object, "UpdateRow", function(row)
	local data = row.data
	if data then
		RememberPlayer(data.characterName, data.displayName, data.battlegroundTeam)
	end
end)
