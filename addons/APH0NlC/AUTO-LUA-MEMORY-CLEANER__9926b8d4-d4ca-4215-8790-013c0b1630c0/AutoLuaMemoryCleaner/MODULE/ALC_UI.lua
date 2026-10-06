--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

if not ALC then return end
local ALC = ALC
local ALC_Console = ALC.Console
local ui_update_fn
local last_ui_update = 0
local ui_label

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
		ALC.ui_window:SetHandler("OnUpdate", ui_update_fn)
	else
		ALC.ui_window:SetHandler("OnUpdate", nil)
	end
	ALC.update_ui_scenes()
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
	ui_label:SetText(combat_str .. status_line)

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

	ui_update_fn = function(ctrl, frame_time)
		if not ALC.settings.show_ui then return end
		if frame_time - last_ui_update < 1.0 then return end
		last_ui_update = frame_time
		ALC.update_ui()
	end
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