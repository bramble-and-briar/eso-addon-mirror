--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local TIP_NAME = "APHProfilerTip"
local TIP_W = 400
local TIP_PAD = 10
local TIP_GAP = 8
local DRAW_LEVEL = 9200
local TOP_FUNCS = 5
local GOLD = "|cFFD700"
local GREY = "|c888888"

local tip
local tip_lbl
local tip_anchor, tip_owner
local held
local hooked = setmetatable({}, { __mode = "k" })

local function MenuOpen()
	return LibAPH.GetContextMenuDepth ~= nil and LibAPH.GetContextMenuDepth() > 0
end

local function Build()
	tip = WINDOW_MANAGER:CreateTopLevelWindow(TIP_NAME)
	tip:SetClampedToScreen(true)
	tip:SetMouseEnabled(false)
	tip:SetDrawTier(DT_HIGH)
	tip:SetDrawLayer(DL_OVERLAY)
	tip:SetDrawLevel(DRAW_LEVEL)
	tip:SetHidden(true)

	LibAPH.ApplyPanelBackdrop(tip, TIP_NAME .. "BG", LibAPH.THEME.BG)

	tip_lbl = WINDOW_MANAGER:CreateControl(TIP_NAME .. "Text", tip, CT_LABEL)
	tip_lbl:SetFont(IsConsoleUI() and "ZoFontGamepad18" or "$(MEDIUM_FONT)|14|soft-shadow-thin")
	tip_lbl:SetColor(0.88, 0.88, 0.88, 1)
	tip_lbl:SetAnchor(TOPLEFT, tip, TOPLEFT, TIP_PAD, TIP_PAD)
	tip_lbl:SetDimensions(TIP_W - TIP_PAD * 2, 0)
end

function APHP.ShowTip(anchor, text, beside)
	if type(text) ~= "string" or text == "" or not anchor then return false end
	beside = beside or anchor
	if MenuOpen() then
		held = { anchor = anchor, text = text, beside = beside }
		if tip then tip:SetHidden(true) end
		return false
	end
	held = nil
	if not tip then Build() end
	if ZO_PostHookHandler and not hooked[beside] then
		hooked[beside] = true
		ZO_PostHookHandler(beside, "OnEffectivelyHidden", function() APHP.HideTip() end)
	end
	tip_lbl:SetText(text)
	tip_lbl:SetDimensions(TIP_W - TIP_PAD * 2, 0)
	local text_h = tip_lbl:GetTextHeight()
	tip:SetDimensions(TIP_W, (text_h or 0) + TIP_PAD * 2)

	local y = (anchor:GetTop() or 0) - (beside:GetTop() or 0)
	tip:ClearAnchors()
	if (beside:GetLeft() or 0) >= TIP_W + TIP_GAP * 2 then
		tip:SetAnchor(TOPRIGHT, beside, TOPLEFT, -TIP_GAP, y)
	else
		tip:SetAnchor(TOPLEFT, beside, TOPRIGHT, TIP_GAP, y)
	end
	tip_anchor, tip_owner = anchor, beside
	tip:SetHidden(false)
	return true
end

function APHP.HideTip(owner)
	if owner ~= nil and owner ~= tip_owner then return end
	held = nil
	if tip then tip:SetHidden(true) end
end

function APHP.HoldTip()
	if not tip or tip:IsHidden() then return false end
	held = { anchor = tip_anchor, text = tip_lbl:GetText(), beside = tip_owner }
	tip:SetHidden(true)
	return true
end

function APHP.ReleaseTip()
	local back = held
	held = nil
	if not back or back.beside:IsHidden() or back.anchor:IsHidden() then return false end
	return APHP.ShowTip(back.anchor, back.text, back.beside)
end

function APHP.GetTipText()
	return tip and not tip:IsHidden() and tip_lbl:GetText() or nil
end

local function PerFrame(value, frames)
	if not frames or frames <= 0 then return nil end
	return value / frames
end

local function Avg(total, calls)
	if not calls or calls <= 0 then return 0 end
	return total / calls
end

function APHP.FunctionStats(entry)
	if not entry.wall then return "" end
	return string.format(APHP.L("WALL_MIN_MAX"), APHP.Format(entry.wall), APHP.Format(entry.min or 0),
		APHP.Format(math.max(entry.max or 0, 0)))
end

function APHP.FunctionTooltipText(entry, owner, frames)
	local lines = { GOLD .. entry.label .. "|r", "in " .. LibAPH.StripColors(owner or "?"), "" }
	if entry.wall then
		lines[#lines + 1] = string.format(APHP.L("WALL_TIME_AVG"), APHP.Format(entry.wall), APHP.Format(Avg(entry.wall, entry.calls)))
	end
	lines[#lines + 1] = string.format(APHP.L("SELF_TIME_AVG"), APHP.Format(entry.own), APHP.Format(Avg(entry.own, entry.calls)))
	if entry.max and entry.max >= 0 then
		lines[#lines + 1] = string.format(APHP.L("SLOWEST_FASTEST"), APHP.Format(entry.max), APHP.Format(entry.min or 0))
	end
	local per_frame = PerFrame(entry.calls, frames)
	lines[#lines + 1] = per_frame and string.format(APHP.L("CALLS_PER_FRAME"), entry.calls, per_frame)
		or string.format(APHP.L("CALLS"), entry.calls)

	if entry.subcalls and #entry.subcalls > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = GOLD .. APHP.L("EXPENSIVE_SUB_CALLS")
		for _, sub in ipairs(entry.subcalls) do
			lines[#lines + 1] = string.format("  %s  %s", APHP.Format(sub.wall), sub.label)
		end
	end
	if entry.stack and #entry.stack > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = GOLD .. APHP.L("SLOWEST_RUN_CALLSTACK")
		for index, frame in ipairs(entry.stack) do
			lines[#lines + 1] = index == 1 and ("  " .. frame) or ("  " .. GREY .. frame .. "|r")
		end
	elseif entry.saved then
		lines[#lines + 1] = ""
		lines[#lines + 1] = GREY .. APHP.L("SAVED_SCAN_SUB_CALLS_AND_THE")
	end
	return table.concat(lines, "\n")
end

function APHP.OwnerTooltipText(row, detail)
	local frames = detail and detail.frames or 0
	local measured = detail and detail.measured_ms or 0
	local lines = { GOLD .. LibAPH.StripColors(row.owner) .. "|r", "" }
	local share = measured > 0 and string.format(APHP.L("OF_ADD_ON_LUA"), row.own / measured * 100) or ""
	lines[#lines + 1] = string.format(APHP.L("SELF_TIME"), APHP.Format(row.own), share)
	if row.total then
		lines[#lines + 1] = string.format(APHP.L("WALL_TIME_WITH_WHAT_IT_CALLED"), APHP.Format(row.total))
	end
	local per_frame = PerFrame(row.own, frames)
	if per_frame then lines[#lines + 1] = string.format(APHP.L("PER_FRAME"), APHP.Format(per_frame)) end
	if row.peak then lines[#lines + 1] = string.format(APHP.L("SLOWEST_SINGLE_CALL"), APHP.Format(row.peak)) end
	if row.calls then
		local calls_per_frame = PerFrame(row.calls, frames)
		lines[#lines + 1] = calls_per_frame and string.format(APHP.L("CALLS_PER_FRAME_2"), row.calls, calls_per_frame)
			or string.format(APHP.L("CALLS"), row.calls)
	end

	local funcs = row.funcs or {}
	if #funcs > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = GOLD .. APHP.L("TOP_FUNCTIONS")
		for index = 1, math.min(#funcs, TOP_FUNCS) do
			local entry = funcs[index]
			lines[#lines + 1] = string.format("  %s  %s", APHP.Format(entry.own), entry.label)
		end
	end
	return table.concat(lines, "\n")
end
