--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local SS = APHSearchCore

local bar = LibAPH.CreateSearchBar({
	name = "APHSearchBar",
	title = "APH-Search",
	placeholder = SS.L("SEARCH"),
	scopeLabel = function(scope) return SS.ScopeName(scope) end,
	store = function() return SS.saved end,
	scopes = function() return SS.GetScopes() end,
	allScope = SS.SCOPE_ALL,
	search = function(text, scope, limit) return SS.Search(text, scope, limit) end,
	searchAsync = function(text, scope, limit, done)
		return SS.SearchAsync(text, scope, limit, done, function(partial)
			if SS.search_bar and SS.search_bar:IsShown() then SS.search_bar:SetSuggestions(partial) end
		end)
	end,
	onQuery = function(text) SS.SetLastQuery(text) end,
	recent = function() return SS.saved and SS.saved.recent end,
	clearRecent = function() if SS.saved then SS.saved.recent = {} end end,
	scopeToggles = {
		all = function() return SS.GetAllScopes() end,
		isOn = function(scope) return SS.IsScopeEnabled(scope) end,
		set = function(scope, on) SS.SetScopeEnabled(scope, on) end,
		groups = function() return SS.GetScopeGroups() end,
	},
	onAccept = function(entry, query)
		SS.RememberSearch(query)
		return SS.GoTo(entry)
	end,
})
SS.search_bar = bar

function SS.GetScope() return bar:GetScope() end
function SS.CycleScope(direction) return bar:CycleScope(direction) end
function SS.SetScope(scope) return bar:SetScope(scope) end
function SS.RefreshScope() return bar:RefreshScopes() end
function SS.ShowScopePicker() return bar:ShowScopePicker() end
function SS.GetSuggestions() return bar:GetSuggestions() end
function SS.GetHighlight() return bar:GetHighlight() end
function SS.SetSuggestions(results) return bar:SetSuggestions(results) end
function SS.MoveHighlight(direction) return bar:MoveHighlight(direction) end
function SS.AcceptHighlight() return bar:AcceptHighlight() end
function SS.RunSearch(text) return bar:RunSearch(text) end
function SS.ApplyBarPosition() return bar:ApplyPosition() end
function SS.ResetBarPosition() return bar:ResetPosition() end
function SS.SetBarOpacity(alpha) return bar:SetOpacity(alpha) end
function SS.ShouldDismissOnFocusLost() return bar:ShouldDismissOnFocusLost() end
function SS.ShowBar(seed)
	if SS.OnSearchOpened then SS.OnSearchOpened() end
	return bar:Show(seed)
end
function SS.HideBar(keep_ui_mode)
	local hidden = bar:Hide(keep_ui_mode)
	LibAPH.StepCleanup(1)
	return hidden
end
function SS.ToggleBar()
	if IsConsoleUI() and IsUnitInCombat("player") and not bar:IsShown() then return false end
	if SS.OnSearchOpened then SS.OnSearchOpened() end
	return bar:Toggle()
end
