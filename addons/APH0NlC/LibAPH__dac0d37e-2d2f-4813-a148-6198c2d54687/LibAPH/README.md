<div align="center">

# LibAPH

*Helper library for my addons.*

![Version](https://img.shields.io/badge/version-2026.10.07.17.24-9CD04C?style=flat-square)
![ESO API](https://img.shields.io/badge/ESO%20API-101051%20%7C%20101052-00FFFF?style=flat-square)
![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-fa9c1b?style=flat-square)
![Platform](https://img.shields.io/badge/platform-PC%20%7C%20Xbox%20%7C%20PlayStation-FF69B4?style=flat-square)

</div>

Everyday helper code my add-ons share, kept in one place so none of them has to carry its own copy. Any functions are subject to change.

## Features

- **Window & Theme** - resizable status/scroll-list windows with a shared flat theme
- **Console Support** - right-stick window drag/resize, console text-entry and picker dialogs
- **Context Menu & Search Bar** - multi-level context menu, movable expanding search bar, key-hint icons
- **Module Manager** - soft-disables individual add-on files and rebuilds the Client Info file list
- **Wizard Helper** - schedules a first-run setup wizard, auto-unloads once completed
- **Messaging & Dialogs** - chained/window-hiding dialogs, safe CSAs, a chat logger
- **Player State** - crafting/interacting/menu busy checks, movement and teleport trackers
- **SavedVariables** - disk-usage reporting, throttled priority saves, unused-SV cleanup
- **Library & Version Checks** - checks an optional library's version and builds a shared warning message
- **Bug Reporting** - a shared `/xxxbugreport` popup format used by every add-on
- **Activity Triggers** - a shared table of "is the player doing X" checks
- **Scheduler** - spreads work across frames within a time budget, staged add-on init
- **Memory Cleanup** - the Auto Lua Memory Cleaner cleanup methods for any add-on, shown in Auto Lua Memory Cleaner when it is installed

## Installation

Extract `LibAPH` into your `AddOns` directory, then declare it as a dependency in your add-on manifest:

```
## DependsOn: LibAPH>=<version>
```

It loads as a global table; no `require` or manual initialization needed:

```lua
LibAPH.GetPlatformString()
```

## Usage

LibAPH's functions hang off the single global `LibAPH` table, organized internally by folder (`UI/`, `UTILS/`, `MODULES/`, `MENU/`, `HELPERS/`, `DATA/`). Call whatever you need directly:

```lua
local status = LibAPH.CreateStatusWindow({ name = "MyAddonUI", title = "My Addon" })
LibAPH.RegisterAddonDependencies("MyAddon", { "LibAPH" }, { "LibAddonMenu-2.0" })
LibAPH.Schedule("MyAddon_Cleanup", function() --[[ heavy work, one chunk per frame ]] end)
```

## API Reference

<details>
<summary><b>Window & Theme</b> (<code>UI/Window.lua</code>, <code>UI/Theme.lua</code>, <code>UI/Position.lua</code>)</summary>

- `MakeWindowResizable(control, opts)`: adds corner-drag resizing to a window
- `CreateStatusWindow(opts)`: builds a movable, resizable status window with the shared theme
- `CreateRowList(parent, opts)`: builds a themed scroll list of rows
- `CreateScrollListWindow(opts)`: builds a full window wrapping a themed scroll list
- `CreateCopyTextBox(opts)`: builds a read-only, selectable copy-text box (used by every bug report popup)
- `OpenPastebin()` / `ConfirmOpenPastebin(win)`: opens (or confirms opening) an external pastebin link
- `StepActiveSearch(direction)`: cycles a search box's matches forward/backward
- `AddButtonHoverEffects(control, baseColor)`: adds the shared hover/press color states to a button
- `AddGhostText(editBox, ghostText)`: shows greyed-out placeholder text in an empty edit box
- `HandleKeybindButtonKey(keybind)` / `RegisterKeybindDefaults(namespace, store, defaults, modifiers)` / `CreateKeybindLabelButton(parent, opts)`: shared keybind-button handling and default-binding registration
- `SetWindowActive(window, label, isActive, opts)`: shows/hides a window based on whether it has anything to display
- `AddFragmentToScenes(fragment, sceneNames)` / `RemoveFragmentFromScenes(fragment, sceneNames)`: batch scene-fragment registration
- `CreateCogwheelButton(parent, name, onClicked, tooltipText)`: builds the shared settings-cogwheel button
- `IsScrollableMenuAvailable()` / `ShowScrollableMenu(control, entries, opts)` / `CloseScrollableMenu()` / `RefreshScrollableMenu()`: LibScrollableMenu integration with a safe fallback when it's missing
- `CreateToggleArrowButton(parent, name, onToggle, tooltipText)` / `SetToggleArrowOpen(button, open)`: an expand/collapse arrow control
- `DockWindowBeside(win, other, gap, prefer)`: anchors one window beside another
- `PixelSize()`: returns the current UI pixel scale
- `AddPixelBorder(control, name, color)`: adds the shared one-pixel border
- `ApplyPanelBackdrop(win, name, fill)`: applies the shared flat panel background
- `CreateHeaderStrip(win, name, height)`: builds the shared header strip
- `CreateThemedCloseButton(win, name, onClick, right, top)`: builds the themed X close button
- `StyleRowBackground(texture, index, is_section)` / `StyleScrollList(list, name)`: shared row striping and scrollbar styling
- `UseGreenSelection(combo)`: colors a dropdown's selected entry green
- `UseTextSelection(combo)`: shows a dropdown's selected entries as colored text with no background, as in the bug report windows
- `CreateStickyFragment(control, scenes)`: keeps a window's own close state sticky across scene changes
- `CreateWindowPosition(win, opts)`: saves and restores a movable window's spot, resets it to a default, and runs the console right-stick move
  - optional `opts.onMoving(win)` runs every `opts.watchMs` (default 50 ms) while the window is dragged with the mouse or moved with the right stick; `opts.onMoveStop(win)` runs after the new spot is saved; `opts.onMoveEnd(win)` runs whenever a right-stick move ends, moved or not
  - `pos:WatchMove()` starts the `onMoving` loop by hand (returns false without `onMoving`); `pos:StopWatch()` stops it
- `GetScreenThirdAlign(control)` / `GetScreenThirdAlignAt(centerX, screenWidth)`: returns `TEXT_ALIGN_LEFT`, `TEXT_ALIGN_CENTER` or `TEXT_ALIGN_RIGHT` for whichever third of the screen a control's center sits in, so text can hug the nearest edge
- `EnableUndoRedo(edit, opts)`: keeps an undo and redo history for an edit box, with typing grouped into steps; call `:Undo()` and `:Redo()` from your own buttons

<details>
<summary>Show a full Window & Theme example</summary>

```lua
local DemoWindow = { saved = {} }
local PAD = 12

local function Font(size)
	return string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", size)
end

local function MakeLabel(parent, text, size, color)
	local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
	label:SetFont(Font(size or 14))
	label:SetColor(unpack(color or LibAPH.THEME.TEXT))
	label:SetText(text)
	return label
end

local function MakeButton(name, parent, text, width, onClick)
	local button = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
	button:SetDimensions(width, 26)
	button:SetText(text)
	button:SetHandler("OnClicked", onClick)
	return button
end

local function MakeTipLabel(parent, text, onEnter, onExit)
	local label = MakeLabel(parent, text, 14, LibAPH.THEME.ACCENT)
	label:SetMouseEnabled(true)
	label:SetHandler("OnMouseEnter", onEnter)
	label:SetHandler("OnMouseExit", onExit)
	return label
end

local function BuildDemoWindow()
	local win = WINDOW_MANAGER:CreateTopLevelWindow("LibAPHDemoWindow")
	win:SetDimensions(460, 520)
	win:SetClampedToScreen(true)
	win:SetMouseEnabled(true)
	win:SetMovable(true)
	win:SetDrawTier(DT_MEDIUM)
	win:SetDrawLayer(DL_OVERLAY)
	win:SetDrawLevel(9100)
	DemoWindow.window = win

	LibAPH.ApplyPanelBackdrop(win, "LibAPHDemoWindowBG", LibAPH.THEME.BG)
	LibAPH.CreateHeaderStrip(win, "LibAPHDemoWindowHeader", 30)
	LibAPH.CreateThemedCloseButton(win, "LibAPHDemoWindowClose", function() win:SetHidden(true) end, 12, 10)
	LibAPH.MakeWindowResizable(win, { minWidth = 440, minHeight = 500 })

	DemoWindow.position = LibAPH.CreateWindowPosition(win, {
		get = function() return DemoWindow.saved.left, DemoWindow.saved.top end,
		set = function(x, y) DemoWindow.saved.left, DemoWindow.saved.top = x, y end,
		placeDefault = function(control) control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0) end,
		mover = LibAPH.CreateGamepadMover(win),
	})
	DemoWindow.position:Apply()

	local title = MakeLabel(win, "LibAPH Demo", 16)
	title:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 7)

	local gear = LibAPH.CreateCogwheelButton(win, "LibAPHDemoGear", function()
		d("LibAPH Demo: gear clicked")
	end, "Cogwheel tooltip, built into the button")
	gear:SetAnchor(TOPRIGHT, win, TOPRIGHT, -40, 1)

	local y = 42
	local function Place(control, height)
		control:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, y)
		y = y + height + 8
	end
	local function Section(text)
		Place(MakeLabel(win, text, 13, LibAPH.THEME.MUTED), 16)
	end

	Section("Buttons")
	local hover = MakeLabel(win, "Hover Me", 14, LibAPH.THEME.ACCENT)
	hover:SetDimensions(90, 26)
	hover:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	hover:SetMouseEnabled(true)
	hover.libaph_click_action = function() d("LibAPH Demo: hover label clicked") end
	LibAPH.AddButtonHoverEffects(hover, LibAPH.THEME.ACCENT)
	Place(hover, 26)

	local copy_box = LibAPH.CreateCopyTextBox({ name = "LibAPHDemoCopyBox", titleText = "Demo Copy Box" })
	local copy_button = MakeButton("LibAPHDemoCopyButton", win, "Copy Box", 100, function()
		copy_box:Show("Select-and-copy text lives here.")
	end)
	copy_button:SetAnchor(LEFT, hover, RIGHT, 8, 0)
	local pastebin_button = MakeButton("LibAPHDemoPastebinButton", win, "Pastebin", 100, function()
		LibAPH.ConfirmOpenPastebin(win) -- LibAPH.OpenPastebin() skips the confirm dialog
	end)
	pastebin_button:SetAnchor(LEFT, copy_button, RIGHT, 8, 0)

	Section("Checkbox")
	local check = WINDOW_MANAGER:CreateControlFromVirtual("LibAPHDemoCheck", win, "ZO_CheckButton")
	ZO_CheckButton_SetLabelText(check, "Show the row list")
	ZO_CheckButton_SetCheckState(check, true)
	Place(check, 20)

	Section("Dropdowns")
	local combo_container = WINDOW_MANAGER:CreateControlFromVirtual("LibAPHDemoCombo", win, "ZO_ComboBox")
	combo_container:SetDimensions(180, 26)
	Place(combo_container, 26)
	local combo = ZO_ComboBox_ObjectFromContainer(combo_container)
	combo:SetSortsItems(false)
	for _, size_name in ipairs({ "Small", "Medium", "Large" }) do
		combo:AddItem(combo:CreateItemEntry(size_name, function(_, choice)
			d("LibAPH Demo: picked " .. choice)
		end))
	end
	combo:SelectFirstItem(true)
	LibAPH.UseGreenSelection(combo)

	local menu_combo_container = WINDOW_MANAGER:CreateControlFromVirtual("LibAPHDemoMenuCombo", win, "ZO_ComboBox")
	menu_combo_container:SetDimensions(180, 26)
	menu_combo_container:SetAnchor(LEFT, combo_container, RIGHT, 12, 0)
	local menu_combo = ZO_ComboBox_ObjectFromContainer(menu_combo_container)
	menu_combo:SetSelectedItemText("Opens a context menu")
	LibAPH.UseContextMenuForCombo(menu_combo_container, function()
		return {
			{ text = "Option A", onClick = function() menu_combo:SetSelectedItemText("Option A") end },
			{ text = "Option B", onClick = function() menu_combo:SetSelectedItemText("Option B") end },
		}
	end)

	Section("Context menu: right-click anywhere in this window")
	local show_hints = true
	win:SetHandler("OnMouseUp", function(control, button, upInside)
		if not upInside or button ~= MOUSE_BUTTON_INDEX_RIGHT then return end
		LibAPH.ShowContextMenu(control, {
			{ header = true, text = "LibAPH Demo" },
			{ text = "Say hello", hint = show_hints and "d()" or nil, onClick = function() d("LibAPH Demo: hello") end },
			{ text = "Show hints", checkbox = true, checked = show_hints, onToggle = function(on) show_hints = on end },
			{ divider = true },
			{ text = "More", submenu = function()
				return {
					{ text = "Sub item", onClick = function() d("LibAPH Demo: sub item") end },
					{ text = "Disabled item", enabled = false },
				}
			end },
		})
	end)
	y = y + 4

	Section("Tooltips: hover each word")
	local text_tip = MakeTipLabel(win, "Text", function(self)
		InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
		SetTooltipText(InformationTooltip, "InformationTooltip with plain text")
	end, function() ClearTooltip(InformationTooltip) end)
	Place(text_tip, 20)

	local side_tip = MakeTipLabel(win, "Side", function(self)
		ZO_Tooltips_ShowTextTooltip(self, RIGHT, "ZO_Tooltips_ShowTextTooltip, anchored to one side")
	end, function() ZO_Tooltips_HideTextTooltip() end)
	side_tip:SetAnchor(LEFT, text_tip, RIGHT, 24, 0)

	local item_tip = MakeTipLabel(win, "Item", function(self)
		local link = GetItemLink(BAG_WORN, EQUIP_SLOT_CHEST)
		InitializeTooltip(ItemTooltip, self, BOTTOM, 0, -4)
		if link ~= "" then
			ItemTooltip:SetLink(link)
		else
			SetTooltipText(ItemTooltip, "No chest piece equipped")
		end
	end, function() ClearTooltip(ItemTooltip) end)
	item_tip:SetAnchor(LEFT, side_tip, RIGHT, 24, 0)

	local ability_tip = MakeTipLabel(win, "Ability", function(self)
		local ability_id = GetSlotBoundId(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, HOTBAR_CATEGORY_PRIMARY)
		InitializeTooltip(AbilityTooltip, self, BOTTOM, 0, -4)
		if ability_id ~= 0 then
			AbilityTooltip:SetAbilityId(ability_id)
		else
			SetTooltipText(AbilityTooltip, "First front-bar slot is empty")
		end
	end, function() ClearTooltip(AbilityTooltip) end)
	ability_tip:SetAnchor(LEFT, item_tip, RIGHT, 24, 0)

	Section("Search box")
	local search_bg = WINDOW_MANAGER:CreateControlFromVirtual("LibAPHDemoSearchBG", win, "ZO_EditBackdrop")
	search_bg:SetDimensions(220, 26)
	Place(search_bg, 26)
	local search_box = WINDOW_MANAGER:CreateControlFromVirtual("LibAPHDemoSearch", search_bg, "ZO_DefaultEditForBackdrop")
	LibAPH.AddGhostText(search_box, "Search rows...")
	search_box:SetHandler("OnEnter", function()
		LibAPH.StepActiveSearch(1) -- -1 steps to the previous match instead
	end)

	Section("Row list")
	local row_area = WINDOW_MANAGER:CreateControl("LibAPHDemoRowArea", win, CT_CONTROL)
	row_area:SetDimensions(200, 66)
	Place(row_area, 66)
	LibAPH.CreateRowList(row_area, { spacing = 2 }):SetRows({ "Row one", "Row two", "Row three" })
	ZO_CheckButton_SetToggleFunction(check, function(_, checked)
		row_area:SetHidden(not checked)
	end)

	LibAPH.RegisterKeybindDefaults("LibAPHDemo", DemoWindow.saved, { LibAPHDemo_Toggle = KEY_F5 })
	local keybind_button = LibAPH.CreateKeybindLabelButton(win, {
		action = "LibAPHDemo_Toggle",
		name = "Toggle Demo",
		callback = function() win:SetHidden(not win:IsHidden()) end,
	})
	keybind_button:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PAD, -PAD)

	local arrow, list_sticky
	local list_api = LibAPH.CreateScrollListWindow({
		name = "LibAPHDemoListWindow",
		titleText = "Demo List Window",
		rowHeight = 20,
		onClose = function()
			list_sticky:Close()
			LibAPH.SetToggleArrowOpen(arrow, false)
		end,
	})
	list_api:SetRows({ { text = "Row one", tooltip = "Rows can carry their own tooltip" }, { text = "Row two" } })
	list_api:Hide()
	LibAPH.MakeWindowResizable(list_api.window, { minWidth = 150, minHeight = 100 })

	list_sticky = LibAPH.CreateStickyFragment(list_api.window, { "hud", "hudui" })
	arrow = LibAPH.CreateToggleArrowButton(win, "LibAPHDemoArrow", function(wants_open)
		if wants_open then
			LibAPH.DockWindowBeside(list_api.window, win, 6)
			list_sticky:Open()
		else
			list_sticky:Close()
		end
		return wants_open
	end, "Show/hide the list window")
	arrow:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -8, -8)
	LibAPH.SetToggleArrowOpen(arrow, false)

	local demo_fragment = ZO_SimpleSceneFragment:New(win)
	LibAPH.AddFragmentToScenes(demo_fragment, { "hud", "hudui" })

	d(string.format("LibAPH Demo: UI pixel scale is %.3f", LibAPH.PixelSize()))
end

SLASH_COMMANDS["/demowindow"] = function()
	if not DemoWindow.window then
		BuildDemoWindow()
	else
		DemoWindow.window:SetHidden(not DemoWindow.window:IsHidden())
	end
end
```

</details>

</details>

<details>
<summary><b>Console</b> (<code>UI/Gamepad.lua</code>, <code>UI/GamepadDialogs.lua</code>)</summary>

- `CreateGamepadMover(target)`: right-analog-stick window dragging
- `CreateGamepadResizer(target, opts)`: right-analog-stick window resizing
- `ForceControllerKeybindIcons()`: forces controller-button icons instead of keyboard keys
- `ShowGamepadTextEntry(opts)` / `ShowGamepadPicker(opts)`: console text entry and picker dialogs

</details>

<details>
<summary><b>Context Menu</b> (<code>UI/ContextMenu.lua</code>)</summary>

- `ShowContextMenu(control, entries, opts)` / `CloseContextMenu()` / `CloseContextMenuLevel()`: opens/closes the multi-level menu
- `IsContextMenuOpen()` / `GetContextMenuDepth()` / `GetContextMenuRowCount(level)` / `GetContextMenuPlacement(level)`: menu-state queries
- `RefreshContextMenu()`: rebuilds the currently open menu in place
- `ContextMenuRowClicked(row)` / `ContextMenuRowEntered(row)` / `MoveContextMenuFocus(direction)` / `ActivateContextMenuFocus()`: row interaction and console focus movement
- `UseContextMenuForCombo(container, build, opts)`: adapts a combo box to open through this context menu
- `GroupedChoiceEntries(groups, opts)` / `ShowGroupedChoiceMenu(control, groups, opts)`: a long list of choices split into one scrollable submenu per group (e.g. Default Categories / User Categories), with the current choice ticked and its group colored

</details>

<details>
<summary><b>Search Bar & Key Hints</b> (<code>UI/SearchBar.lua</code>, <code>UI/KeyHints.lua</code>)</summary>

- `CreateSearchBar(opts)`: a movable search bar that expands into a match palette, with a console route
- `CreateKeyHints(parent, name, hints)`: shows the game's key icons, drawn key caps, or controller button hints

</details>

<details>
<summary><b>Status Icons</b> (<code>UI/StatusIcons.lua</code>)</summary>

- `CreateStatusIconStrip(parentControl, selfHandled, slots, size)`: builds a colored status-icon strip for a row
- `UpdateStatusIconStrip(icons, anchorControl, statusIcons, growLeftward, offsetX, relativePoint)`: repositions/refreshes an icon strip
- `SetStatusIconFocused(icon, focused, focusScale)`: highlights an icon on console focus

</details>

<details>
<summary><b>Module Manager</b> (<code>MODULES/ModuleManager.lua</code>)</summary>

- `ToggleModuleDisabled(store, moduleFileFuncs, modKey, notifyFn, silent)`: soft-disables/re-enables one module
- `ApplyModuleDisableOverrides(store, moduleFileFuncs, modulesTable, nilOutFn, getFn)`: nils out a disabled module's functions at load
- `RegisterModuleLifecycle(modKey, hooks)` / `HasModuleLifecycle(modKey)` / `SyncModuleLifecycle(modulesTable, modKey, isDisabled)`: onLoad/onUnload hooks for modules that can apply live
- `StashFunc(modKey, fname, fn)` / `GetStashedFunc(modKey, fname)`: keeps a disabled module's function retrievable without re-enabling it
- `CallOptional(warnedTable, tag, unavailableNote, fn, label, ...)`: calls a possibly-nil (module-disabled) function, warning once if it's missing
- `BuildModuleFileList(moduleOrder, moduleFiles, getState, labels, sep)` / `FormatModuleFileLine(filename, state, labels)`: builds the Client Info "Files" list
- `BuildModuleLoadButton(opts)`: builds the settings-menu unload/reload button for one module

</details>

<details>
<summary><b>Wizard</b> (<code>MODULES/Wizard.lua</code>)</summary>

- `ScheduleWizardIfNeeded(isCompleted, runFn, delayMs)`: runs the first-time setup wizard once, after a short delay
- `AutoUnloadWizardModule(settings, toggleFn)`: soft-disables the wizard module once it's been completed

</details>

<details>
<summary><b>Menu State</b> (<code>MENU/MenuState.lua</code>, <code>MENU/MenuRefresh.lua</code>)</summary>

- `TrackSubmenuOpenState(savedTable, reference)` / `RestoreSubmenuOpenState(savedTable, reference)` / `PersistSubmenuOpenState(savedTable, reference)`: remembers a LAM2 submenu's open/closed state, PC only
- `CreateMenuLabelRefresher(addonPrefix, panelGetter)`: forces a settings panel's labels to redraw on language change

</details>

<details>
<summary><b>Messaging & Dialogs</b> (<code>HELPERS/Messaging.lua</code>)</summary>

- `ShowDialogChained(dialogId, title, body, buttons, delayMs, onClosed)`: shows one dialog after another in sequence
- `ShowDialogHidingWindows(windows, dialogId, title, body, buttons, delayMs, onClosed)`: hides given windows while a dialog is up, restores them after, ref-counted across chained steps
- `SafeCSA(enabled, title, body, lifespanMs)`: shows a center-screen announcement only if the setting allows it
- `CreateChatLogger(shortTag, colorHex)`: builds a tagged, colored chat print function
- `SendRawChatLine(msg)`: prints a raw line to chat, working on console where `CHAT_SYSTEM:AddMessage` doesn't
- `SetSlashCommandsShown(names, shown)`: adds or removes slash commands and clears the chat autocomplete, so a command only exists while it can act
- `IsSafeToReloadUI()` / `ReloadUIWhenSafe(namespace, opts)`: defers a `ReloadUI()` until it's safe to do (not mid-combat, etc.)

</details>

<details>
<summary><b>Player State</b> (<code>HELPERS/PlayerState.lua</code>)</summary>

- `IsPlayerCrafting()` / `IsPlayerInteracting()` / `IsPlayerInMenu()`: quick busy-state checks
- `CheckBusyReason(checks)`: runs a list of busy checks and returns which one (if any) is true
- `CreateMovementTracker(opts)` / `CreateTeleportTracker(opts)`: tracks player movement/teleport state over time
- `RunWhenPlayerActivated(namespace, fn)`: defers a function until `EVENT_PLAYER_ACTIVATED`
- `GetClientStartTime()` / `IsSameClientSession(recordedStart, toleranceSec)`: detects whether the client has restarted since a saved timestamp

</details>

<details>
<summary><b>SavedVariables</b> (<code>HELPERS/SavedVariables.lua</code>)</summary>

- `IsPrioritySaveSupported()` / `RequestPrioritySave(addonName)` / `RequestPrioritySaveForRunningAddons(onSaved)`: forces an early SavedVariables write
- `RequestThrottledPrioritySave(namespace, addonName, throttleMs, force)` / `RequestThrottledPrioritySaveSweep(namespace, throttleMs, force, onSaved)`: same, rate-limited
- `GetSavedVariablesDiskCapacityMB()` / `GetSavedVariablesDiskUsageMB(addonIndex)` / `GetTotalSavedVariablesDiskUsageMB()` / `GetUnusedSavedVariablesDiskUsageMB()`: disk-usage reporting
- `ClearUnusedSavedVariables()` / `DeleteSavedVariablesForAddon(addonIndex)`: frees disk space from disabled/removed add-ons

</details>

<details>
<summary><b>Library & Self Version Checks</b> (<code>UTILS/LibraryVersion.lua</code>, <code>UTILS/SelfVersion.lua</code>)</summary>

- `CheckLibraryVersion(addonName)`: returns an optional library's installed version and whether it's enabled
- `GetLibraryDriftColor(installedVer, tableVer)` / `FormatLibraryVersion(ver, enabled, requiredVer, formatters)`: colors/formats a version for display
- `BuildLibraryWarning(templates, fullName, shortName, ver, enabled, requiredVer, consequence)` / `BuildLibraryWarningFromData(...)`: builds the shared missing/disabled/outdated-library warning text (dialog + CSA + chat)
- `CheckSelfVersion(store, currentVersion, opts)`: detects if this add-on's own AddOnVersion changed since last load
- `CheckAddonVersions(knownVersions, warnedTable, onMismatch)`: compares known dependent add-ons' versions against a reference table

</details>

<details>
<summary><b>Bug Reporting</b> (<code>UTILS/BugReport.lua</code>)</summary>

- `SetAddonMetadataProvider(provider)`: registers how to fetch an add-on's own metadata for reports
- `CreateAddonBugReporter(opts)`: builds a ready-to-use `/xxxbugreport` popup for one add-on
- `/libaphbugreport`: opens LibAPH's own bug report popup (PC)
- `GetLiveApiLine()`: the current live API version, formatted
- `BuildEnabledAddonsReport()` / `BuildEnvironmentReport()`: lists every enabled add-on/library with Version, AddOnVersion, API
- `DefaultBugReportSections(hasErrors)` / `BuildBugReportSections(opts)` / `BuildBugReportText(opts)` / `RenderBugReport(sections, enabled)`: assembles the final report text
- `FitBugReportText(text)`: trims a report to fit the SavedVariables character limit

</details>

<details>
<summary><b>Dependency Registration</b> (<code>UTILS/DependencyRegistry.lua</code>)</summary>

- `RegisterAddonDependencies(addonName, requiredLibs, optionalLibs)`: declares an add-on's real dependencies for the Client Info panel

</details>

<details>
<summary><b>Activity Triggers</b> (<code>HELPERS/ActivityTriggers.lua</code>)</summary>

- `GetActivityTriggers()` / `GetActivityTriggerGroups()` / `GetActivityTriggersInGroup(group_id)` / `GetActivityTrigger(id)`: reads the shared trigger table
- `RegisterActivityTrigger(definition)`: adds a new "is the player doing X" trigger
- `IsActivityTriggerActive(id, context)` / `CountActiveActivityTriggers(ids, context)`: evaluates triggers
- `RegisterActivityTriggerWatcher(namespace, callback, delayMs)` / `UnregisterActivityTriggerWatcher(namespace)`: watches for trigger state changes
- `GetPlayerStatusIcon(playerStatus)` / `GetFriendList()` / `GetIgnoredList()` / `GetGroupDisplayNames()` / `GetLootWindowSeconds()`: related player/social lookups

</details>

<details>
<summary><b>Add-on Manager Helpers</b> (<code>HELPERS/AddonManager.lua</code>, <code>UTILS/Platform.lua</code>)</summary>

- `EnableRequiredDependencies(index, setEnabled, onEnabled)` / `EnableAddonWithDependencies(index, setEnabled, onEnabled)`: enables an add-on along with its dependencies
- `GetPlatformString()` / `GetPlatformServiceName()`: platform and storefront detection
- `GetKeybindMarkup(action)`: the bound key for an action as inline icon markup, or an empty string when nothing is bound
- `IsGameScreenShown()`: true only while the base game scene is fully shown (no menu, no transition)
- `ShowMenuScene(scene)`: opens a main-menu scene through the keyboard main menu when it knows the scene, otherwise through `SCENE_MANAGER`
- `AfterSceneShown(scene, fn)`: runs `fn` once `scene` is shown, checking every 100 ms for up to a second
- `IsAddonActiveAndRunning(addonName)` / `IsLibraryAddonByName(am, addonName)`: add-on state queries

</details>

<details>
<summary><b>Error Capture</b> (<code>HELPERS/ErrorCapture.lua</code>)</summary>

- `HookErrorCapture(addonName, onCaptured)`: hooks Lua errors for one add-on
- `RecordCapturedBug(bugList, text, maxTracked)`: records a captured error, capped
- `FormatCapturedBugBlocks(title, bugs)` / `FormatCapturedBugsSection(bugLines, promptText, noneCapturedText, describeInsteadText)`: formats captured errors for a bug report

</details>

<details>
<summary><b>Format Helpers</b> (<code>UTILS/Format.lua</code>)</summary>

- `FormatVersionParen(version)` / `FormatVersionBare(version)` / `FormatVersionHistory(history, currentVersion, sep)`: version-string formatting
- `StripColors(text, fallback)`: strips ESO color markup from a string
- `PickDiskUnit(usageMB)` / `FormatSizeMB(sizeMB, decimals, subMegabyteUnit)` / `FormatDiskUsageMB(usageMB, short)` / `FormatDiskUsageRangeMB(usedMB, capacityMB)` / `FormatMemoryMB(sizeMB)`: disk/memory-size formatting
- `FormatInstallDateLine(installedDate, todayStr)` / `GetTodayDateString()`: install-date formatting

</details>

<details>
<summary><b>Profile Store</b> (<code>UTILS/ProfileStore.lua</code>)</summary>

- `CreateProfileStore(opts)`: a saved-profile manager (create/switch/delete named settings profiles); opts.perCharacter keeps a separate active profile for each character while the profiles stay account-wide
- `CopyMap(source)` / `CopyList(source)`: shallow-copy helpers for saved tables
- `CaptureAddonEnabledState()`: snapshots which add-ons are currently enabled

</details>

<details>
<summary><b>Packed Tables</b> (<code>DATA/PackedTable.lua</code>)</summary>

- `CreatePackedTable(rows, parseRow)` / `CreatePackedConsoleTable(rows)` / `CreatePackedListTable(rows)` / `CreatePackedValueTable(rows)`: unpacks a compact static data table into a lookup table
- `GetPackedTableNames(packed)`: lists the keys of a packed table

</details>

<details>
<summary><b>Scheduler</b> (<code>UTILS/Scheduler.lua</code>)</summary>

- `Schedule(name, step, opts)` / `RunOrSchedule(name, step, opts)`: spreads a function's work across frames within a time budget
- `ScheduleLoop(name, items, body, opts)`: schedules a per-item loop across frames
- `ScheduleWait(name, condition, onDone, opts)`: waits for a condition across frames before continuing
- `RunInitStages(name, stages)`: runs a list of init functions one per frame (staged add-on load)
- `InitOnFirstShow(sceneObject, fn)`: defers init until a scene is first shown
- `GetScheduledJob(name)` / `IsScheduled(name)` / `GetScheduledCount()`: scheduler-state queries
- `GetSchedulerBudgetMs()` / `SetSchedulerBudgetMs(ms)`: reads/sets the per-frame time budget
- `StepCleanup(passes, onDone)` / `IsStepCleanupRunning()`: the shared stepped garbage-collection job every add-on's cleanup routes through

</details>

<details>
<summary><b>Memory Cleanup</b> (<code>UTILS/MemoryCleanup.lua</code>)</summary>

- `RunCleanup(opts)`: runs one garbage collection with the Auto Lua Memory Cleaner methods: `opts.method` is `"automatic"` (default), `"background"`, `"aggressive"`, `"deep"` or `"vanilla"` (runs only with `opts.force`), `opts.source` names your add-on and `opts.onDone(result)` gets the result. A call while another add-on's cleanup is running joins it instead of cleaning twice. Returns `true, method` or `false, reason`
- `GetCleanupMethods()` / `PickCleanupMethod(force, reason)`: the method names, and what Automatic would pick right now
- `RegisterCleanupListener(name, fn)` / `UnregisterCleanupListener(name)`: calls `fn(result)` after every cleanup from any add-on; `result` has `source`, `method`, `picked` and `beforeLua`/`afterLua`/`freedLua`, `beforePool`/`afterPool`/`freedPool` in MB
- `IsCleanupRunning()` / `GetLastCleanup()` / `GetMemoryUsageMB()`: state queries; the last returns Lua and add-on pool MB

When Auto Lua Memory Cleaner is installed, every cleanup run through `RunCleanup` shows in its window, chat logs and announcements.

<details>
<summary>Show a full Memory Cleanup example</summary>

`/democlean` shows the status; `/democlean automatic`, `background`, `aggressive`, `deep` or `vanilla` runs that method. Every other add-on's cleanup shows in chat too.

```lua
local DemoCleanup = { name = "DemoCleanup" }
local LUA_LIMIT_MB = 300
local CHECK_EVERY_MS = 2000
local chat = LibAPH.CreateChatLogger("DemoCleanup", "00FFFF")

local function Describe(result)
	local how = result.picked and ("automatic, picked " .. result.picked) or result.method
	return string.format("%s by %s: Lua %.1f MB (-%.1f), pool %.1f MB (-%.1f)",
		how, result.source, result.afterLua, result.freedLua, result.afterPool, result.freedPool)
end

local function BusyChecks()
	return {
		{ reasonKey = "in combat", delayMs = 5000, check = function() return IsUnitInCombat("player") end },
		{ reasonKey = "dead", delayMs = 5000, check = function() return IsUnitDead("player") end },
		{ reasonKey = "crafting", delayMs = 3000, check = LibAPH.IsPlayerCrafting },
		{ reasonKey = "talking to an NPC", delayMs = 3000, check = LibAPH.IsPlayerInteracting },
		{ reasonKey = "travelling", delayMs = 3000, check = function() return DemoCleanup.teleport:IsTeleporting() end },
	}
end

function DemoCleanup.PickMethod(lua_mb)
	if LibAPH.IsPlayerInMenu() then return "deep" end
	if DemoCleanup.movement:IsMoving() then return "background" end
	if lua_mb >= LUA_LIMIT_MB * 1.5 then return "aggressive" end
	return "automatic"
end

function DemoCleanup.Run(method, force)
	local started, how = LibAPH.RunCleanup({
		method = method,
		source = DemoCleanup.name,
		force = force,
		onDone = function(result)
			DemoCleanup.saved.freedMB = DemoCleanup.saved.freedMB + result.freedLua
		end,
	})
	if not started and how == "vanilla" then
		chat:Print("Vanilla: nothing to clean yet, the game handles it.")
	elseif not started then
		chat:Print("Unknown method. Use one of: " .. table.concat(LibAPH.GetCleanupMethods(), ", "))
	elseif how == "joined" then
		chat:Print("Another add-on is already cleaning; joined it.")
	end
	return started
end

function DemoCleanup.Check()
	DemoCleanup.movement:Update()
	if GetGameTimeMilliseconds() < DemoCleanup.waitUntil or LibAPH.IsCleanupRunning() then return end
	local lua_mb = LibAPH.GetMemoryUsageMB()
	if lua_mb < LUA_LIMIT_MB then return end
	local busy, reason, delay_ms = LibAPH.CheckBusyReason(DemoCleanup.busy)
	if busy then
		DemoCleanup.waitReason = reason
		DemoCleanup.waitUntil = GetGameTimeMilliseconds() + delay_ms
		return
	end
	DemoCleanup.waitReason = nil
	DemoCleanup.Run(DemoCleanup.PickMethod(lua_mb))
end

function DemoCleanup.Status()
	local lua_mb, pool_mb = LibAPH.GetMemoryUsageMB()
	chat:Print(string.format("Lua %.1f MB, pool %.1f MB, freed this game session %.1f MB", lua_mb, pool_mb, DemoCleanup.saved.freedMB))
	chat:Print("Automatic would pick: " .. LibAPH.PickCleanupMethod(true))
	if DemoCleanup.waitReason then chat:Print("Waiting: " .. DemoCleanup.waitReason) end
	local last = LibAPH.GetLastCleanup()
	if last then chat:Print("Last cleanup: " .. Describe(last)) end
end

local function Init()
	DemoCleanup.saved = ZO_SavedVars:NewAccountWide("DemoCleanupSaved", 1, nil, { freedMB = 0, clientStart = 0 })
	if not LibAPH.IsSameClientSession(DemoCleanup.saved.clientStart) then
		DemoCleanup.saved.freedMB = 0
		DemoCleanup.saved.clientStart = LibAPH.GetClientStartTime()
	end
	DemoCleanup.movement = LibAPH.CreateMovementTracker({ throttleMs = 500, threshold = 0.5 })
	DemoCleanup.teleport = LibAPH.CreateTeleportTracker({ staleMs = 5000 })
	DemoCleanup.busy = BusyChecks()
	DemoCleanup.waitUntil = 0

	LibAPH.RegisterCleanupListener(DemoCleanup.name, function(result)
		chat:Print(Describe(result))
	end)

	SLASH_COMMANDS["/democlean"] = function(args)
		local method = zo_strlower(zo_strtrim(args or ""))
		if method == "" then return DemoCleanup.Status() end
		DemoCleanup.Run(method, true)
	end

	LibAPH.RunWhenPlayerActivated(DemoCleanup.name .. "_Start", function()
		EVENT_MANAGER:RegisterForUpdate(DemoCleanup.name .. "_Watch", CHECK_EVERY_MS, DemoCleanup.Check)
	end)
end

EVENT_MANAGER:RegisterForEvent(DemoCleanup.name, EVENT_ADD_ON_LOADED, function(_, addon_name)
	if addon_name ~= DemoCleanup.name then return end
	EVENT_MANAGER:UnregisterForEvent(DemoCleanup.name, EVENT_ADD_ON_LOADED)
	Init()
end)
```

</details>

</details>

<details>
<summary><b>Settings Helpers</b> (<code>HELPERS/Settings.lua</code>)</summary>

- `FormatSettingsSnapshot(settings, fields, onLabel, offLabel)`: formats a settings table for display (Client Info, etc.)
- `ResetToDefaults(settings, defaults, excludeKeys, postFn)`: the shared reset-to-defaults loop every add-on's Reset button calls

</details>

> [!WARNING]
> **Console Testing Notes:** This addon was developed and tested on **PC / Steam Deck** *(using Force Console Flow for console testing)*.

## License

Copyright © 2026 @APHONlC. All rights reserved. See LICENSE.md

> [!NOTE]
> This add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

For permissions or inquiries, contact @APHONlC on ESOUI.

## Credits

I would like to thank the following, for providing resources and their awesome projects:

- [ESOUI Wiki](https://wiki.esoui.com/Main_Page)
- [ESO Forums](https://forums.elderscrollsonline.com/en/discussion/689370/libharvensaddonsettings-to-libvotan-change-guide)
- [@sirinsidiator](https://github.com/esoui/esoui)
- [@Flat-Badger-1971](https://www.esoui.com/downloads/info4074-ESOluaAPIintellisenseforVisualStudioCode.html)
- [@sirinsidiator & @Seerah](https://www.esoui.com/downloads/info7.html) <sub>*(LibAddonMenu-2.0)*</sub>
- [@Harven & @votan](https://www.esoui.com/downloads/info584.html) <sub>*(LibHarvensAddonSettings)*</sub>
- [@SinusPi, @merlight, @Rhyono, @Dolgubon](https://www.esoui.com/downloads/info1624.html) <sub>*(Zgoo High Isle)*</sub>
- [@Baertram](https://www.esoui.com/downloads/info2601.html) <sub>*(Mer Torchbug - Fixed and Improved "Variable inspector/Scripts/Events/and more")*</sub>
- [@Baertram, @IceHeart, @Masteroshi430](https://www.esoui.com/downloads/info970-CirconiansTextureIt.html) <sub>*(Circonians TextureIt)*</sub>

**Testers & Suggestions:**

<!-- TESTERS:START -->
- @phlupp89
- @Drakius192
<!-- TESTERS:END -->

**Check out my other addons/projects:**

- [Auto Lua Memory Cleaner](https://www.esoui.com/downloads/fileinfo.php?id=4388#info)
- [Permanent Memento](https://www.esoui.com/downloads/fileinfo.php?id=4116#info)
- [Tamriel Trade Center, HarvestMap, ESO-Hub, ESOUI Auto-Updater](https://www.esoui.com/downloads/fileinfo.php?id=3249#info) <sub>*(Linux, macOS, SteamDeck, & Windows)*</sub>

If you like the addon and are considering donating, here's a link. Thank you!

[![Buy Me A Coffee](https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-FFDD00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/aph0nlc)

### Bug Reports

If you encounter any issues, please submit a report here
