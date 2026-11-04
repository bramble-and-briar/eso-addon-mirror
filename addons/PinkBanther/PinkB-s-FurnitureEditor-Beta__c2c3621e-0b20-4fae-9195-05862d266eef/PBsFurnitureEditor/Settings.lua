-- PB's FurnitureEditor -- the settings panel
--
-- Where a console player can reach "forget what you are holding" without typing a command. LibHarvensAddonSettings
-- is an optional dependency (the same one the other PBs add-ons use): without it there is no panel, and
-- everything is still there as /pbfe reset.
--
-- First, the saved link sets: save the copy under a name, and bring one back later. Then the progress bar, then
-- buttons to forget what the add-on holds. There is no row that shows the current state: the library builds its rows
-- once and cannot rewrite one afterwards, so such a row would show the state at the time the panel was built for ever.
-- "Show what is held" prints it to chat instead, and every button says in chat what it did.
--
-- The saved sets are the one thing that does change while the panel is open or between openings, so their rows are a
-- run that is taken out and put in again (RemoveSettings / AddSettings, which PBsKillLog uses for its day rows) when
-- the panel is opened, and after every save, load or delete. Only row types known to work are in that run. The one
-- that may not (a text box, ST_EDIT) is added beside it, if this copy of the library has it, and does not matter:
-- a set is named for you when the box is empty, and /pbfe save <name> takes any name.
--
-- The buttons call State.lua. A cut that has not been pasted is asked twice (press again within a few seconds).

local addon = PBS_FURNITURE_EDITOR

local Try1 = addon.Try1
local Print = addon.Print

-- The name the settings menu lists. It is written with the TYPOGRAPHIC apostrophe (U+2019), as the character
-- itself and not as "\u{2019}" (that escape is Lua 5.3 and the client is 5.1). With an ASCII ' the settings
-- library's panel eats the whole "PB's " and lists "FurnitureEditor" (found in PBsDiceExtension, which keeps the
-- ASCII form in its manifest for the add-on list and the store, as this one does).
local DISPLAY_NAME = "PB’s FurnitureEditor"

local TEXT = {
	en = {
		title = DISPLAY_NAME,
		savedSection = "Saved link sets",
		savedExplanation = "Copy a group, then save it here under a name. A saved set stays after you log out. Loading one "
			.. "puts it on the clipboard, and the quickslot wheel offers Paste in any house of yours.",
		savedName = "Name for the next save",
		savedNameTooltip = "Type a name, then press Save. Left empty, the set is named for you (the first furnishing and how many).",
		save = "Save the copy",
		saveTooltip = "Keeps what you last copied or cut, under the name above.",
		saveButton = "Save",
		savedNone = "Nothing is saved yet.",
		savedList = "Saved sets",
		savedListTooltip = "Newest first. The number is how many furnishings the set holds.",
		load = "Load the selected set",
		loadTooltip = "Puts the selected set on the clipboard.",
		loadButton = "Load",
		drop = "Delete the selected set",
		dropTooltip = "Forgets the selected set. Press again within a few seconds to confirm.",
		dropButton = "Delete",
		progressSection = "Progress bar",
		progress = "Show the progress bar",
		progressTooltip = "A bar with how far a cut, move or paste has got, over everything else on the screen.",
		progressTest = "Show a test bar",
		progressTestTooltip = "Fills a bar over a few seconds, to see where it is and how it reads.",
		progressTestButton = "Test",
		section = "Copy / cut state",
		explanation = "What you copied or cut is kept until it is pasted, with a record of the last paste (for undo) and any "
			.. "reservations. These rows forget that. They never touch furnishings in a house or in your bag, or your "
			.. "saved clipboards.",
		show = "Show what is held",
		showTooltip = "Prints, in chat, what the clipboard, the undo record and the reservations hold.",
		showButton = "Show",
		stop = "Stop what is running",
		stopTooltip = "Stops a paste, cut or undo that is in progress, after the furnishing it is working on.",
		stopButton = "Stop",
		clear = "Clear copy / cut",
		clearTooltip = "Empties the clipboard. A cut that has not been pasted asks you to press again: the clipboard is "
			.. "the only record of where its furnishings go.",
		clearButton = "Clear",
		clearAll = "Clear everything",
		clearAllTooltip = "The clipboard, the undo record, the reservations and a trip that has been started. Saved "
			.. "clipboards (/pbfe saved) are kept. A cut that has not been pasted asks you to press again.",
		clearAllButton = "Clear all",
	},
	jp = {
		title = DISPLAY_NAME,
		savedSection = "保存したリンクセット",
		savedExplanation = "コピーしたリンクセットに名前をつけて保存できます。保存したものはログアウトしても残ります。"
			.. "「読み込む」でクリップボードに戻すと、自分の家のクイックスロットホイールに「ペースト」が出ます。",
		savedName = "次に保存する名前",
		savedNameTooltip = "名前を入力して「保存」を押します。空のままなら、最初の家具の名前と個数で自動的に名前をつけます。",
		save = "コピーしたものを保存",
		saveTooltip = "直前にコピー（またはカット）したものを、上の名前で保存します。",
		saveButton = "保存",
		savedNone = "保存したものはまだありません。",
		savedList = "保存したセット",
		savedListTooltip = "新しい順です。かっこの数字は、セットに含まれる家具の数です。",
		load = "選んだセットを読み込む",
		loadTooltip = "選んだセットをクリップボードに載せます。",
		loadButton = "読み込む",
		drop = "選んだセットを削除",
		dropTooltip = "選んだセットを忘れます。確認のため、数秒以内にもう一度押してください。",
		dropButton = "削除",
		progressSection = "進捗バー",
		progress = "進捗バーを表示する",
		progressTooltip = "カット・ムーブ・ペーストがどこまで進んだかを、画面の前面にバーで表示します。",
		progressTest = "テスト用のバーを表示",
		progressTestTooltip = "数秒かけてバーを満たし、表示位置と見え方を確認できます。",
		progressTestButton = "テスト",
		section = "コピー／カットの状態",
		explanation = "コピーまたはカットした内容は、貼り付けるまで保持されます。ほかに、直前の貼り付けの記録（取り消し用）と"
			.. "予約も保持します。ここの項目は、それらを忘れさせます。家やバッグの家具、保存したクリップボードには"
			.. "触れません。",
		show = "保持している内容を表示",
		showTooltip = "クリップボード・取り消し用の記録・予約の内容を、チャットに表示します。",
		showButton = "表示",
		stop = "実行中の処理を止める",
		stopTooltip = "実行中の貼り付け・カット・取り消しを、作業中の家具のあとで止めます。",
		stopButton = "停止",
		clear = "コピー／カットをクリア",
		clearTooltip = "クリップボードを空にします。まだ貼り付けていないカットは、もう一度押す必要があります"
			.. "（家具の行き先の記録が、クリップボードだけだからです）。",
		clearButton = "クリア",
		clearAll = "すべての状態をクリア",
		clearAllTooltip = "クリップボード・取り消し用の記録・予約・開始済みの移動を忘れます。保存したクリップボード"
			.. "（/pbfe saved）は残します。まだ貼り付けていないカットは、もう一度押す必要があります。",
		clearAllButton = "すべてクリア",
	},
}

local function Text()
	return TEXT[Try1(GetCVar, "language.2")] or TEXT.en
end

-- ---------------------------------------------------------------------------------------
-- The saved sets
-- ---------------------------------------------------------------------------------------

-- What a set is called in the dropdown: its name and how many furnishings it holds. A name is unique among the
-- sets, so this is too.
local function ItemText(entry)
	return string.format("%s  (%d)", entry.name, entry.count)
end

function addon:AddSavedRows(settings, library, text)
	local state = { selected = nil, name = "" }
	self.savedState = state

	settings:AddSetting({ type = library.ST_SECTION or library.ST_LABEL, label = text.savedSection })
	settings:AddSetting({ type = library.ST_LABEL, label = text.savedExplanation })

	-- A text box, if this copy of the library has one. Beside the run below, never in it: whether the row wants
	-- more than this is not something that can be checked from here, and a panel that fails to build is worse
	-- than a panel without a name box.
	if library.ST_EDIT then
		pcall(function()
			settings:AddSetting({
				type = library.ST_EDIT,
				label = text.savedName,
				tooltip = text.savedNameTooltip,
				default = "",
				getFunction = function()
					return state.name
				end,
				setFunction = function(value)
					state.name = tostring(value or "")
				end,
			})
		end)
	end

	-- the rows that follow the list of sets, and are built again as it changes
	local function Rows()
		local rows = {}
		local sets = self:SavedSets()

		rows[#rows + 1] = {
			type = library.ST_BUTTON,
			label = text.save,
			tooltip = text.saveTooltip,
			buttonText = text.saveButton,
			clickHandler = function()
				local name, how, other = self:SaveClip(state.name, false)
				if not name then
					if how == "empty" then
						Print("the clipboard is empty: copy a group first")
						addon.Alert("Nothing to save: copy a group first")
					elseif how == "exists" then
						Print("%s is already saved. Another name, or /pbfe save %s force", other, other)
						addon.Alert("%s is already saved. Use another name", other)
					else
						Print("there are already %d saved sets: delete one first", addon.MAX_SAVED)
						addon.Alert("Too many saved sets (%d): delete one first", addon.MAX_SAVED)
					end
					return
				end

				state.name = ""
				state.selected = name
				Print("saved as %s (%d furnishings)", name, #self.sv.library[name].nodes)
				addon.Alert("Saved: %s", name)
				self:RebuildSavedRows()
			end,
		}

		if #sets == 0 then
			rows[#rows + 1] = { type = library.ST_LABEL, label = text.savedNone }
			return rows
		end

		local items, selected = {}, nil
		for _, entry in ipairs(sets) do
			local item = { name = ItemText(entry), data = entry.name }
			items[#items + 1] = item
			if entry.name == state.selected then
				selected = item
			end
		end
		selected = selected or items[1]
		state.selected = selected.data

		rows[#rows + 1] = {
			type = library.ST_DROPDOWN,
			label = text.savedList,
			tooltip = text.savedListTooltip,
			items = items,
			default = items[1].name,
			ignoreDefault = true,
			-- never nil: a dropdown handed nil shows its first item, which reads as the choice resetting itself
			getFunction = function()
				for _, item in ipairs(items) do
					if item.data == state.selected then
						return item.name
					end
				end
				return items[1].name
			end,
			setFunction = function(_, _, item)
				state.selected = item.data
			end,
		}

		rows[#rows + 1] = {
			type = library.ST_BUTTON,
			label = text.load,
			tooltip = text.loadTooltip,
			buttonText = text.loadButton,
			clickHandler = function()
				local entry = self:LoadSaved(state.selected, false)
				if entry then
					addon.Alert("Loaded: %s. Pick Paste on the quickslot wheel in a house of yours", entry.name)
				end
			end,
		}

		rows[#rows + 1] = {
			type = library.ST_BUTTON,
			label = text.drop,
			tooltip = text.dropTooltip,
			buttonText = text.dropButton,
			clickHandler = function()
				local entry = self:FindSaved(state.selected)
				if not entry then
					return
				end
				-- a saved set cannot be got back: asked twice
				if not self:AskedTwice("drop:" .. entry.name) then
					Print("%s will be forgotten. Do it again within %d s to delete it", entry.name, addon.CONFIRM_SECONDS)
					addon.Alert("Press again within %d s to delete %s", addon.CONFIRM_SECONDS, entry.name)
					return
				end
				self:DropSaved(entry.name)
				state.selected = nil
				addon.Alert("Deleted: %s", entry.name)
				self:RebuildSavedRows()
			end,
		}
		return rows
	end

	-- where the run starts, and how long it is
	local block = { start = #(settings.settings or {}) + 1, count = 0, rows = Rows }
	self.savedBlock = block

	local rows = Rows()
	settings:AddSettings(rows)
	block.count = #rows

	-- taken out and put in again when the panel is opened: the sets may have changed by command since
	if CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback then
		pcall(function()
			CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, addonSettings)
				if addonSettings == settings then
					self:RebuildSavedRows()
				end
			end)
		end)
	end
end

function addon:RebuildSavedRows()
	local panel, block = self.settingsPanel, self.savedBlock
	if not (panel and block and panel.RemoveSettings and panel.AddSettings) then
		return
	end

	local ok, why = pcall(function()
		panel:RemoveSettings(block.start, block.count)
		local rows = block.rows()
		panel:AddSettings(rows, block.start)
		block.count = #rows
		if panel.selected and panel.UpdateControls then
			panel:UpdateControls()
		end
	end)
	if not ok then
		Print("the saved sets could not be redrawn in the settings panel: %s", tostring(why))
	end
end

function addon:InitSettings()
	local library = LibHarvensAddonSettings
	if not library then
		return
	end

	local text = Text()
	local settings = library:AddAddon(text.title)
	if not settings then
		return
	end
	self.settingsPanel = settings

	self:AddSavedRows(settings, library, text)

	settings:AddSetting({
		type = library.ST_SECTION or library.ST_LABEL,
		label = text.progressSection,
	})

	settings:AddSetting({
		type = library.ST_CHECKBOX,
		label = text.progress,
		tooltip = text.progressTooltip,
		default = true,
		getFunction = function()
			return self.sv.progress ~= false
		end,
		setFunction = function(value)
			self.sv.progress = value and true or false
			if not value and self.progress then
				self.progress:HideNow()
			end
		end,
	})

	settings:AddSetting({
		type = library.ST_BUTTON,
		label = text.progressTest,
		tooltip = text.progressTestTooltip,
		buttonText = text.progressTestButton,
		clickHandler = function()
			self.progress:Test()
		end,
	})

	settings:AddSetting({
		-- a real divider with a heading where the library has one; older copies only have a label
		type = library.ST_SECTION or library.ST_LABEL,
		label = text.section,
	})

	settings:AddSetting({
		type = library.ST_LABEL,
		label = text.explanation,
	})

	settings:AddSetting({
		type = library.ST_BUTTON,
		label = text.show,
		tooltip = text.showTooltip,
		buttonText = text.showButton,
		clickHandler = function()
			self:PrintHeldState()
		end,
	})

	settings:AddSetting({
		type = library.ST_BUTTON,
		label = text.stop,
		tooltip = text.stopTooltip,
		buttonText = text.stopButton,
		clickHandler = function()
			self:HandleCommand("stop")
		end,
	})

	settings:AddSetting({
		type = library.ST_BUTTON,
		label = text.clear,
		tooltip = text.clearTooltip,
		buttonText = text.clearButton,
		clickHandler = function()
			self:ClearCopyCut(false)
		end,
	})

	settings:AddSetting({
		type = library.ST_BUTTON,
		label = text.clearAll,
		tooltip = text.clearAllTooltip,
		buttonText = text.clearAllButton,
		clickHandler = function()
			self:ClearAllState(false)
		end,
	})
end
