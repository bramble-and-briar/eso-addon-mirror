--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

PMCore = PMCore or {}
local PM = PMCore
local PM_defaults = PM.defaults
local PM_modules = PM._modules
local PM_state = PM.state
local PM_ui_refs = PM.ui_refs

local function place_default(win)
	local is_pad = IsConsoleUI() or IsInGamepadPreferredMode()
	local x_offset = (_G["PP"] and not is_pad) and 0.5 or 0
	local search_box = ZO_CollectionsBook_TopLevelSearchBox
	if PM.settings.show_in_hud then
		local _, compass_y = ZO_Compass:GetCenter()
		win:SetAnchor(LEFT, GuiRoot, TOPLEFT, ZO_Compass:GetRight() + 15 + x_offset, compass_y)
	elseif is_pad then
		win:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -50, 50)
	elseif search_box and search_box:GetRight() > 0 then
		local _, search_y = search_box:GetCenter()
		win:SetAnchor(LEFT, GuiRoot, TOPLEFT, search_box:GetRight() + 10 + x_offset, search_y)
	else
		win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 100 + x_offset, 100)
	end
end

local function current_pos_tables()
	if PM.settings.show_in_hud then return PM.settings.ui, PM_defaults.ui end
	return PM.settings.ui_menu, PM_defaults.ui_menu
end

function PM.apply_ui_size()
	local win = PM_ui_refs.ui_window
	if not win or not PM.settings then return end
	local is_pad = IsConsoleUI() or IsInGamepadPreferredMode()
	local cur = PM.settings.show_in_hud and PM.settings.ui or PM.settings.ui_menu
	if PM.settings.show_in_hud then
		win:SetScale(cur.scale or 1.0)
	else
		win:SetScale(cur.scale or (is_pad and 1.2 or 1.0))
	end
	if cur.width and cur.height then
		win:SetDimensions(cur.width, cur.height)
	end
	if win.libaph_apply_font_scale then win.libaph_apply_font_scale() end
	if PM_ui_refs.force_resize then PM_ui_refs.force_resize() end
end

function PM.update_ui_anchor()
	local win = PM_ui_refs.ui_window
	if not win or not PM.settings then return end
	win:SetMovable(not PM.settings.ui.is_locked)
	PM.apply_ui_size()
	PM_ui_refs.ui_position:Apply()
end

function PM.reset_ui_position()
	if PM_ui_refs.ui_position then PM_ui_refs.ui_position:Reset() end
end

function PM.start_gamepad_move()
	if PM_ui_refs.ui_position then PM_ui_refs.ui_position:StartGamepadMove() end
end

function PM.update_ui_scenes()
	if not PM_ui_refs.hudFragment or not PM_ui_refs.menuFragment then return end
	local hud_arr = {"hud", "hudui", "interact"}
	local menu_arr = {"collectionsBook", "gamepad_collections_book", "gamepadCollectionsBook"}

	LibAPH.RemoveFragmentFromScenes(PM_ui_refs.hudFragment, hud_arr)
	LibAPH.RemoveFragmentFromScenes(PM_ui_refs.menuFragment, menu_arr)

	if not PM.settings.ui.is_hidden then
		if PM.settings.show_in_hud then
			if not PM.settings.is_ui_global then
				LibAPH.AddFragmentToScenes(PM_ui_refs.hudFragment, hud_arr)
			end
		else
			LibAPH.AddFragmentToScenes(PM_ui_refs.menuFragment, menu_arr)
		end
	end
	PM.update_ui_anchor()

	if PM_ui_refs.ui_window then
		if PM.settings.ui.is_hidden then
			PM_ui_refs.ui_window:SetHidden(true)
		else
			local cur_scene = SCENE_MANAGER:GetCurrentScene()
			local should_show = false
			if cur_scene then
				if PM.settings.show_in_hud then
					should_show = PM.settings.is_ui_global or cur_scene:HasFragment(PM_ui_refs.hudFragment)
				elseif cur_scene:HasFragment(PM_ui_refs.menuFragment) then
					should_show = true
				end
			end
			PM_ui_refs.ui_window:SetHidden(not should_show)
		end
	end
end

function PM.toggle_ui_update()
	if not PM_ui_refs.ui_window then
		if PM.settings.ui.is_hidden then return end
		PM.create_ui()
	end
	if PM.settings.ui.is_hidden then
		PM_ui_refs.ui_window:SetHandler("OnUpdate", nil)
	else
		PM_ui_refs.ui_window:SetHandler("OnUpdate", PM_ui_refs.ui_update_fn)
	end
	PM.update_ui_scenes()
end

function PM.create_ui()
	local is_pad = IsConsoleUI() or IsInGamepadPreferredMode()

	local win, text_lbl = LibAPH.CreateStatusWindow({
		name = "PermMementoUI",
		movable = not PM.settings.ui.is_locked,
		isGamepad = is_pad,
		onResizeStop = function(width, height)
			if not PM.settings then return end
			local cur = PM.settings.show_in_hud and PM.settings.ui or PM.settings.ui_menu
			cur.width, cur.height = width, height
			PM_ui_refs.ui_position:Save()
		end,
	})

	PM_ui_refs.ui_window = win
	PM_ui_refs.ui_mover = PM.call_optional(PM.create_gamepad_mover, "Console UI module (create_gamepad_mover)", win)
	PM_ui_refs.ui_position = LibAPH.CreateWindowPosition(win, {
		get = function()
			local cur, def = current_pos_tables()
			if cur.left == def.left and cur.top == def.top then return nil, nil, nil end
			return cur.left, cur.top, cur.point
		end,
		set = function(x, y, point)
			local cur, def = current_pos_tables()
			cur.left, cur.top, cur.point = x or def.left, y or def.top, point
		end,
		point = LEFT,
		placeDefault = place_default,
		follow = { ZO_Compass, ZO_CollectionsBook_TopLevelSearchBox },
		mover = PM_ui_refs.ui_mover,
	})
	PM.update_ui_anchor()

	local function force_resize()
		local cur = PM.settings.show_in_hud and PM.settings.ui or PM.settings.ui_menu
		local needed_width = text_lbl:GetTextWidth() + 20
		local needed_height = text_lbl:GetTextHeight() + 10
		local target_width = math.max(cur.width or 0, needed_width)
		local target_height = math.max(cur.height or 0, needed_height)
		if target_width ~= win:GetWidth() or target_height ~= win:GetHeight() then
			win:SetDimensions(target_width, target_height)
			if win.libaph_apply_font_scale then win.libaph_apply_font_scale() end
		end
	end
	PM_ui_refs.force_resize = force_resize
	local resize_opts = { onResize = force_resize }
	local last_tick = 0

	PM_ui_refs.ui_update_fn = function(ctrl, f_time)
		if PM_modules.loop then PM.update_movement_state() end
		if not PM.settings then return end
		local r_rate = 1.0
		if (f_time - last_tick < r_rate) then return end
		last_tick = f_time

		local md = PM.get_data(PM.settings.active_id)
		if not LibAPH.SetWindowActive(win, text_lbl, PM.settings.active_id and md, resize_opts) then
			return
		end

		if PM.settings.is_paused then
			text_lbl:SetText(string.format("%s |cFF0000(%s)|r", md.name, PM.L("LABEL_PAUSED")))
			force_resize(); return
		end

		local cd_txt
		local cd_rem, _ = GetCollectibleCooldownAndDuration(PM.settings.active_id)

		if cd_rem > 0 then cd_txt = string.format(" |cFFA500(%.1fs)|r", cd_rem / 1000)
		else
			local tick_ms = GetGameTimeMilliseconds()
			if tick_ms < PM_state.next_fire_time then
				local d_sec = (PM_state.next_fire_time - tick_ms) / 1000
				local reason = PM_state.delay_reason or PM.L("LABEL_DELAYING")
				cd_txt = string.format(" |cFF69B4(%s... %.1fs)|r", reason, d_sec)
			else cd_txt = " |c00FF00(Ready)|r" end
		end

		text_lbl:SetText(md.name .. cd_txt); force_resize()
	end

	PM_ui_refs.uiLabel = text_lbl
	PM_ui_refs.hudFragment = ZO_HUDFadeSceneFragment:New(win)
	PM_ui_refs.menuFragment = ZO_FadeSceneFragment:New(win)
end

PM_modules.ui = true
