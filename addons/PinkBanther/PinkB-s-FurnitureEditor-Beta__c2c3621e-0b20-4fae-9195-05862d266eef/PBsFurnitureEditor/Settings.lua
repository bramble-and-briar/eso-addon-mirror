-- PB's FurnitureEditor -- the settings panel
--
-- Where a console player can reach "forget what you are holding" without typing a command. LibHarvensAddonSettings
-- is an optional dependency (the same one the other PBs add-ons use): without it there is no panel, and
-- everything is still there as /pbfe reset.
--
-- Four buttons and an explanation. There is no row that shows the current state: the library builds its rows once
-- and cannot rewrite one afterwards, so such a row would show the state at the time the panel was built for ever.
-- "Show what is held" prints it to chat instead, and every button says in chat what it did.
--
-- The buttons call State.lua. A cut that has not been pasted is asked twice (press again within a few seconds).

local addon = PBS_FURNITURE_EDITOR

local Try1 = addon.Try1

-- The name the settings menu lists. It is written with the TYPOGRAPHIC apostrophe (U+2019), as the character
-- itself and not as "\u{2019}" (that escape is Lua 5.3 and the client is 5.1). With an ASCII ' the settings
-- library's panel eats the whole "PB's " and lists "FurnitureEditor" (found in PBsDiceExtension, which keeps the
-- ASCII form in its manifest for the add-on list and the store, as this one does).
local DISPLAY_NAME = "PB’s FurnitureEditor"

local TEXT = {
	en = {
		title = DISPLAY_NAME,
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
