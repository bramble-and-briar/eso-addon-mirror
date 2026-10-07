--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

if not ALC then return end
local ALC = ALC
local ALC_Console = ALC.Console
local ui_label
local ui_ticking = false
local last_width_key
local UI_UPDATE_NAME = "ALC_StatusWindow"
local UI_UPDATE_MS = 1000

local function UiTick()
	ALC.update_ui()
end

local function StartUiTicks()
	if ui_ticking then return end
	ui_ticking = true
	EVENT_MANAGER:RegisterForUpdate(UI_UPDATE_NAME, UI_UPDATE_MS, UiTick)
	ALC.update_ui()
end

local function StopUiTicks()
	if not ui_ticking then return end
	ui_ticking = false
	EVENT_MANAGER:UnregisterForUpdate(UI_UPDATE_NAME)
end

function ALC.get_gamepad_mover(target)
	if ALC_Console.create_gamepad_mover then
		return ALC_Console.create_gamepad_mover(target)
	end
	return nil
end

function ALC.toggle_ui_update()
	if not ALC.ui_window then
		if not ALC.settings.show_ui then return end
		ALC.create_ui()
	end
	if ALC.settings.show_ui then
		ALC.ui_window:SetHandler("OnEffectivelyShown", StartUiTicks)
		ALC.ui_window:SetHandler("OnEffectivelyHidden", StopUiTicks)
	else
		ALC.ui_window:SetHandler("OnEffectivelyShown", nil)
		ALC.ui_window:SetHandler("OnEffectivelyHidden", nil)
		StopUiTicks()
	end
	ALC.update_ui_scenes()
	if ALC.settings.show_ui and not ALC.ui_window:IsHidden() then StartUiTicks() end
end

local function place_default(win)
	local _, compass_y = ZO_CompassFrame:GetCenter()
	win:SetAnchor(RIGHT, GuiRoot, TOPLEFT, ZO_CompassFrame:GetLeft() - 15, compass_y)
end

function ALC.apply_ui_size()
	local win = ALC.ui_window
	if not win then return end
	win:SetScale(ALC.settings.ui_scale or 1.0)
	win:SetDimensions(ALC.settings.ui_width or 150, ALC.settings.ui_height or 40)
	if win.libaph_apply_font_scale then win.libaph_apply_font_scale() end
	win.alc_resized = true
	ALC.update_ui()
end

function ALC.update_ui_anchor()
	if not ALC.ui_window then return end
	ALC.apply_ui_size()
	ALC.ui_position:Apply()
end

function ALC.reset_ui_position()
	if ALC.ui_position then ALC.ui_position:Reset() end
end

function ALC.start_gamepad_move()
	if ALC.ui_position then ALC.ui_position:StartGamepadMove() end
end

function ALC.update_ui()
	if not ALC.settings.show_ui or not ui_label then return end
	local current_lua = ALC.get_hybrid_memory_data()
	local pool_mb = ALC.get_console_pool_mb()
	local combat_str = IsUnitInCombat("player") and ("|cFF0000" .. ALC.L("LABEL_COMBAT") .. "|r ") or ""
	local status_line = ALC.build_memory_status_line(
		current_lua, ALC.session_mb_freed, pool_mb, ALC.session_pool_mb_freed
	)
	local pick = ALC.last_auto_pick
	local pick_str = pick and ("|c888888" .. pick.text .. "|r  ") or ""
	local text = combat_str .. pick_str .. status_line
	if text ~= ui_label.alc_text then
		ui_label.alc_text = text
		ui_label:SetText(text)
	end

	local width_key = string.gsub(text, "%d", "0")
	if width_key == last_width_key and not ALC.ui_window.alc_resized then return end
	last_width_key = width_key
	ALC.ui_window.alc_resized = nil

	local needed_width = ui_label:GetTextWidth() + 20
	local target_width = math.max(ALC.settings.ui_width or 0, needed_width)
	local target_height = ALC.settings.ui_height or 40
	if target_width ~= ALC.ui_window:GetWidth() or target_height ~= ALC.ui_window:GetHeight() then
		ALC.ui_window:SetDimensions(target_width, target_height)
		if ALC.ui_window.libaph_apply_font_scale then ALC.ui_window.libaph_apply_font_scale() end
	end
end

function ALC.create_ui()
	local is_pad = IsInGamepadPreferredMode()

	local win, text_lbl = LibAPH.CreateStatusWindow({
		name = "AutoLuaCleanerUI",
		movable = not ALC.settings.is_ui_locked,
		isGamepad = is_pad,
		onResizeStop = function(width, height)
			ALC.settings.ui_width = width
			ALC.settings.ui_height = height
			if ALC.ui_window then ALC.ui_window.alc_resized = true end
			ALC.ui_position:Save()
		end,
	})

	ALC.ui_window = win
	ALC.ui_mover = ALC.get_gamepad_mover(win)
	ALC.ui_position = LibAPH.CreateWindowPosition(win, {
		get = function() return ALC.settings.ui_x, ALC.settings.ui_y, ALC.settings.ui_point end,
		set = function(x, y, point) ALC.settings.ui_x, ALC.settings.ui_y, ALC.settings.ui_point = x, y, point end,
		point = RIGHT,
		placeDefault = place_default,
		follow = { ZO_CompassFrame },
		mover = ALC.ui_mover,
	})
	ALC.update_ui_anchor()

	ui_label = text_lbl
	EVENT_MANAGER:RegisterForEvent(UI_UPDATE_NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
		if ALC.ui_window then ALC.ui_window.alc_resized = true end
	end)

	ALC.hud_fragment = ZO_HUDFadeSceneFragment:New(win)
end

function ALC.update_ui_scenes()
	if not ALC.hud_fragment then return end
	local valid_scenes = {"hud", "hudui"}

	LibAPH.RemoveFragmentFromScenes(ALC.hud_fragment, valid_scenes)

	if ALC.settings.show_ui and not ALC.settings.is_ui_global then
		LibAPH.AddFragmentToScenes(ALC.hud_fragment, valid_scenes)
	end

	local cur_scene = SCENE_MANAGER:GetCurrentScene()

	if ALC.ui_window then
		if not ALC.settings.show_ui then
			ALC.ui_window:SetHidden(true)
		else
			local should_show = ALC.settings.is_ui_global or (cur_scene and cur_scene:HasFragment(ALC.hud_fragment))
			ALC.ui_window:SetHidden(not should_show)
		end
	end
end

ALC._modules.ui = true