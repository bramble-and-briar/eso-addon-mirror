local GF = GroupFinderPlus

function GF.AllowAllRoles()
	if not GF.SV.AllowAllRoles then return end

	ZO_PreHook(GROUP_FINDER_SEARCH_MANAGER, 'ExecuteSearch', function()
		SetGroupFinderFilterEnforceRoles(false)
	end)
end

function GF.FixAchievements()
	if not GF.SV.FullAchievements then return end

	ZO_PreHook(Achievement, 'ApplyCollapsedDescriptionConstraints', function(self)
		if self.IsInstanceOf and self:IsInstanceOf(PopupAchievement) then
			return true
		end
		return false
	end)

	ZO_PostHook(PopupAchievement, 'Show', function(self, id, progress, timestamp)
		self.collapsed = false

		self:RemoveCollapsedDescriptionConstraints()

		self:RefreshExpandedView()

		local container = self.parentControl
		if container then
			container:SetHeight(self.control:GetHeight())
		end
	end)

	ZO_PreHook(PopupAchievement, 'Collapse', function(self)
		return true
	end)

end

function GF.RegisterBlacklistDialog()
	ZO_CreateStringId("GF_BLACKLIST_DIALOG_HEADER", "Blacklist Confirmation")

	ESO_Dialogs["GF_BLACKLIST_CONFIRMATION_DIALOG"] = {
		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.BASIC,
		},
		title = {
			text = "Blacklist Player",
		},
		mainText = {
			text = function(dialog)
				return dialog.data.mainText
			end,
		},
		mustChoose = true,
		buttons = {
			[1] = {
				text = SI_DIALOG_ACCEPT,
				callback = function(dialog)
					if dialog.data.callback then
						dialog.data.callback()
					end
				end,
			},
			[2] = {
				text = SI_DIALOG_CANCEL,
			},
		},
		finishedCallback = function(dialog)
			if dialog.data.finishingCallback then
				dialog.data.finishingCallback()
			end
		end,
	}
end

local LAST_BOSS_DESC_PATTERNS = {
	"last",
	"final",
	"last[%s%-]*boss",
	"final[%s%-]*boss",
	"boss[%s%-]*last",
	"boss[%s%-]*final",
	"end[%s%-]*boss",
	"boss[%s%-]*end",
}

function GF.stripColors(text)
	if not text then return "" end
	text = text:gsub("|c%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	return text
end

function GF.IsLastBossListing(title, desc, short)
	local t = GF.stripColors(title or ""):lower()
	local d = GF.stripColors(desc or ""):lower()
	local s = (short or ""):lower():gsub("[%[%]]", "")

	-- =========================
	-- TITLE: strong match
	-- =========================
	if t:find("last[%s%-]*boss")
		or t:find("final[%s%-]*boss")
		or t:find("boss[%s%-]*last")
		or t:find("boss[%s%-]*final")
		or t:find("end[%s%-]*boss")
		or t:find("boss[%s%-]*end")
	then
		return true
	end

	-- =========================
	-- TITLE: "last/final" with only shortcode
	-- =========================
	if t:find("last") or t:find("final") then
		local cleaned = t
		cleaned = cleaned:gsub("%[" .. s .. "%]", "")
		cleaned = cleaned:gsub("v" .. s, "")
		cleaned = cleaned:gsub("n" .. s, "")
		cleaned = cleaned:gsub(s, "")
		cleaned = cleaned:gsub("%s+", " "):match("^%s*(.-)%s*$")

		if cleaned == "last" or cleaned == "final" then
			return true
		end
	end

	-- =========================
	-- DESCRIPTION strict
	-- =========================
	if d ~= "" then
		local trimmed = GF.stripColors(d):gsub("%s+", " "):match("^%s*(.-)%s*$")

		for _, pat in ipairs(LAST_BOSS_DESC_PATTERNS) do
			if trimmed:match("^" .. pat .. "$") then
				return true
			end
		end
	end

	return false
end

function GF.StartRainbow(row)
	if row.rainbowActive then return end
	row.rainbowActive = true

	if not row.rainbowStartTime then
		row.rainbowStartTime = GetFrameTimeSeconds()
	end

	local SPEED = 6

	row.bg:SetHandler("OnUpdate", function(_, frameTimeSeconds)
		local elapsed = frameTimeSeconds - row.rainbowStartTime

		local r = 0.5 + 0.5 * math.sin(elapsed * SPEED)
		local g = 0.5 + 0.5 * math.sin(elapsed * SPEED + 2.094)
		local b = 0.5 + 0.5 * math.sin(elapsed * SPEED + 4.188)

		row.bg:SetCenterColor(r, g, b, 0.45)
	end)
end


function GF.StopRainbow(row)
	if not row.rainbowActive then return end
	row.rainbowActive = false

	row.bg:SetHandler("OnUpdate", nil)

	if row.desiredBgColor then
		row.bg:SetCenterColor(unpack(row.desiredBgColor))
	end

	row.rainbowStartTime = nil
end