--[[
Generic Tooltip Hook Snippet (Non-Proprietary)
=============================================
Purpose:
	Standalone, dependency-free example showing how to SAFELY append custom lines to
	antiquity-related tooltips (or any ZO_Tooltip layout) without relying on any private
	addon data structures. All domain logic has been replaced with placeholder output.

Included Concepts:
	* SecurePostHook usage on ZO_Tooltip layout methods.
	* Adding a new section (AcquireSection/AddSection) instead of modifying existing lines.
	* Duplicate suppression (signature + short time window) to prevent spam.
	* Defensive nil checks & pcall to avoid interfering with other addons.

Intentionally EXCLUDED (You fill these in):
	* Real antiquity/set data lookups.
	* Quality / difficulty logic (placeholder colors only).
	* Fragment enumeration & location specifics.

Customize:
	Replace the bodies of buildLeadLines() / buildSetLines() with your own domain logic.
	Return either:
			- An array (table) of strings (each string becomes a line), OR
			- An empty table {} to skip adding a block.

Integration:
	1. Ensure global table `AC` (or rename everywhere safely) exists before this file loads.
	2. Call AC.TooltipHooks.Install() after EVENT_ADD_ON_LOADED.
	3. Toggle verbose debug with: AC.debugTooltip = true

Quick Test:
	/script if AC and AC.TooltipHooks then d(AC.TooltipHooks.Install()) end

Removal:
	Only post-hooks are registered; a simple reloadui after removing the file clears them.

--]]

if not AC then AC = {} end

AC.TooltipHooks = AC.TooltipHooks or {}

-- =========================================================================
-- Local helpers (kept intentionally small & self-contained)
-- =========================================================================
local function dbg(msg)
	if AC.debugTooltip and type(d)=="function" then d("[AC TT] "..tostring(msg)) end
end

-- Placeholder line builders -------------------------------------------------
-- Replace these with real lookups. They intentionally DO NOT reference any
-- addon data to remain 100% generic / redistributable.

local function buildLeadLines(leadId)
    leadId = tonumber(leadId)
    if not leadId then return {} end
    -- Return a minimal sample block (two lines)
    return {
        zo_strformat("Lead ID: <<1>>", leadId),
        "(Add your custom lead details here)"
    }
end

local function buildSetLines(setId)
    setId = tonumber(setId)
    if not setId or setId <= 0 then return {} end
    -- Return a minimal sample set block (two lines)
    return {
        zo_strformat("Set ID: <<1>>", setId),
        "(Add your custom set summary here)"
    }
end

-- Append lines as a new body section (shared with both lead + set hooks)
local function appendSection(tip, lines)
	if not tip or not lines or #lines == 0 then return end
	-- Duplicate suppression: build signature
	local sig = table.concat(lines, '\31')
	local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
	if tip.__ac_lastSig == sig and now ~= 0 and tip.__ac_lastTime and (now - tip.__ac_lastTime) < 150 then return end
	local bodySectionStyle = tip.GetStyle and tip:GetStyle('bodySection')
	local bodyDescStyle = tip.GetStyle and tip:GetStyle('bodyDescription')
	local dividerStyle = tip.GetStyle and tip:GetStyle('dividerLine')
	if not (bodySectionStyle and bodyDescStyle and dividerStyle) then return end
	local section = tip:AcquireSection(bodySectionStyle)
	section:AddTexture(ZO_GAMEPAD_HEADER_DIVIDER_TEXTURE, dividerStyle)
	for _, line in ipairs(lines) do section:AddLine(line, bodyDescStyle) end
	local ok, err = pcall(function() tip:AddSection(section) end)
	if not ok then dbg('AddSection error: '..tostring(err)) end
	tip.__ac_lastSig = sig
	tip.__ac_lastTime = now
end

-- =========================================================================
-- Installation (post-hooks)
-- =========================================================================
function AC.TooltipHooks.Install()
	if AC.TooltipHooks._installed then return 'already-installed' end
	if not (ZO_Tooltip and SecurePostHook) then return 'missing-toolkit' end

	local hooked = 0

	local function safeHook(name, fn)
		if type(ZO_Tooltip[name]) == 'function' then
			local ok, err = pcall(function()
				SecurePostHook(ZO_Tooltip, name, fn)
			end)
			if ok then hooked = hooked + 1 else dbg('SecurePostHook '..name..' failed: '..tostring(err)) end
		end
	end

	-- Antiquity Lead
	safeHook('LayoutAntiquityLead', function(self, leadId)
		leadId = tonumber(leadId)
		if not leadId then return end
		appendSection(self, buildLeadLines(leadId))
	end)

	-- Antiquity Set Fragment (treated same as lead here)
	safeHook('LayoutAntiquitySetFragment', function(self, fragId)
		fragId = tonumber(fragId)
		if not fragId then return end
		appendSection(self, buildLeadLines(fragId))
	end)

	-- Antiquity Reward (individual reward -> still show its lead data if available)
	safeHook('LayoutAntiquityReward', function(self, rewardLeadId)
		rewardLeadId = tonumber(rewardLeadId)
		if not rewardLeadId then return end
		appendSection(self, buildLeadLines(rewardLeadId))
	end)

	-- Antiquity Set Reward (summary of fragments)
	safeHook('LayoutAntiquitySetReward', function(self, setId)
		setId = tonumber(setId)
		if not setId or setId <= 0 then return end
		appendSection(self, buildSetLines(setId))
	end)

	AC.TooltipHooks._installed = true
	dbg('Tooltip hooks installed count='..tostring(hooked))
	return 'installed-'..tostring(hooked)
end

return AC.TooltipHooks
