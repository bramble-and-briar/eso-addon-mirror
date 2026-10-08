--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.ShowDialogChained(dialogId, title, body, buttons, delayMs, onClosed)
	local dialog = ESO_Dialogs[dialogId]
	if not dialog then
		dialog = { canQueue = true, gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC } }
		ESO_Dialogs[dialogId] = dialog
	end
	dialog.title = { text = title }
	dialog.mainText = { text = body }
	dialog.buttons = buttons
	dialog.finishedCallback = onClosed
	zo_callLater(function()
		if IsConsoleUI() or IsInGamepadPreferredMode() then
			ZO_Dialogs_ShowGamepadDialog(dialogId)
		else
			ZO_Dialogs_ShowDialog(dialogId)
		end
	end, delayMs or 50)
end

local function Resolve(entry)
	if type(entry) == "function" then return entry() end
	return entry
end

local dialog_holds = setmetatable({}, { __mode = "k" })

function LibAPH.ShowDialogHidingWindows(windows, dialogId, title, body, buttons, delayMs, onClosed)
	local held = {}
	for _, entry in ipairs(windows or {}) do
		local win = Resolve(entry)
		if win and type(win.IsHidden) == "function" then
			if (dialog_holds[win] or 0) > 0 then
				dialog_holds[win] = dialog_holds[win] + 1
				held[#held + 1] = win
			elseif not win:IsHidden() then
				win:SetHidden(true)
				dialog_holds[win] = 1
				held[#held + 1] = win
			end
		end
	end
	LibAPH.ShowDialogChained(dialogId, title, body, buttons, delayMs, function(...)
		for _, win in ipairs(held) do
			dialog_holds[win] = (dialog_holds[win] or 1) - 1
			if dialog_holds[win] <= 0 then
				dialog_holds[win] = nil
				win:SetHidden(false)
			end
		end
		if onClosed then onClosed(...) end
	end)
	return #held
end

function LibAPH.SafeCSA(enabled, title, body, lifespanMs)
	if not enabled then return end
	if body == nil then
		body = title
		title = nil
	end

	local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.NONE)
	if title then
		params:SetText(title, body)
	else
		params:SetText(body)
	end
	params:SetLifespanMS(lifespanMs or 4000)
	CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

function LibAPH.CreateChatLogger(shortTag, colorHex)
	local logger = {}
	function logger:Print(message, colorOverride)
		local tagged = "|c" .. (colorOverride or colorHex) .. "[" .. shortTag .. "]|r " .. message
		LibAPH.SendRawChatLine(tagged)
	end
	return logger
end

local function ShowGamepadChatHud()
	local chat = GAMEPAD_CHAT_SYSTEM
	if type(chat) ~= "table" or not chat.IsMinimized or not chat:IsMinimized() then return end
	pcall(chat.Maximize, chat)
end

function LibAPH.SendRawChatLine(msg)
	if IsConsoleUI() then
		d(msg)
		ShowGamepadChatHud()
	elseif CHAT_SYSTEM then
		CHAT_SYSTEM:AddMessage(msg)
	end
end

local stored_slash_handlers = {}
local CHAT_SYSTEM_NAMES = { "CHAT_SYSTEM", "KEYBOARD_CHAT_SYSTEM", "GAMEPAD_CHAT_SYSTEM" }

local function ClearSlashAutoComplete()
	for _, name in ipairs(CHAT_SYSTEM_NAMES) do
		local system = rawget(_G, name)
		local entry = type(system) == "table" and system.textEntry
		local auto = type(entry) == "table" and entry.slashCommandAutoComplete
		if type(auto) == "table" and type(auto.ClearPossibleCommandMatches) == "function" then
			auto:ClearPossibleCommandMatches()
		end
	end
end

function LibAPH.SetSlashCommandsShown(names, shown)
	local changed = false
	for _, name in ipairs(names) do
		local current = SLASH_COMMANDS[name]
		if current then stored_slash_handlers[name] = current end
		local wanted = shown and stored_slash_handlers[name] or nil
		if current ~= wanted then
			SLASH_COMMANDS[name] = wanted
			changed = true
		end
	end
	if changed then ClearSlashAutoComplete() end
	return changed
end

local RELOAD_DELAY_MS = 1500

function LibAPH.IsSafeToReloadUI()
	return IsPlayerActivated() and not IsUnitInCombat("player") and not IsUnitDead("player")
end

function LibAPH.ReloadUIWhenSafe(namespace, opts)
	opts = opts or {}
	local logger = opts.logger
	local function DoReload()
		if opts.stillWanted and opts.stillWanted() == false then return end
		if logger and opts.reloadingMessage then logger:Print(opts.reloadingMessage) end
		zo_callLater(function() ReloadUI("ingame") end, opts.delayMs or RELOAD_DELAY_MS)
	end

	if LibAPH.IsSafeToReloadUI() then
		DoReload()
		return true
	end
	if logger and opts.waitingMessage then logger:Print(opts.waitingMessage) end
	local function TryNow()
		if not LibAPH.IsSafeToReloadUI() then return end
		EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_PLAYER_COMBAT_STATE)
		EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_PLAYER_ALIVE)
		DoReload()
	end
	EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_COMBAT_STATE, TryNow)
	EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ALIVE, TryNow)
	return false
end
