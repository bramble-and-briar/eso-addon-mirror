local Chronos = _G['Chronos']
local zo_strformat = zo_strformat

function Chronos:ToggleChangelog(visible)
    Chronos_Changelog:SetHidden(not visible)
end

local function initializeChangelogWindow(self)
    Chronos_Changelog:SetHandler("OnMoveStop", function()
        self.db.changelogX = zo_floor(Chronos_Changelog:GetLeft())
        self.db.changelogY = zo_floor(Chronos_Changelog:GetTop())
    end)

    if self.db.changelogX ~= nil and self.db.changelogY ~= nil then
        Chronos_Changelog:ClearAnchors()
        Chronos_Changelog:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.db.changelogX, self.db.changelogY)
    end

    self:CreateGuideHelp(Chronos_Changelog, Chronos_Changelog_Close, "START_UPDATES")
end

function Chronos:ChangelogScreen()
    initializeChangelogWindow(self)

    local messages = self.GetDefaultLocaleString("changelog_message") or {}
    local changelog = table.concat(messages, "\n")

    local replacements = {
        ["%[%*%]"] = "|t12:12:esoui/art/miscellaneous/bullet.dds|t",
        ["%[%+%]"] = "|t12:12:esoui/art/miscellaneous/spinnerplus_up.dds|t",
        ["%[%-%]"] = "|t12:12:esoui/art/miscellaneous/spinnerminus_up.dds|t",
        ["%[%=%]"] = "|t12:12:esoui/art/miscellaneous/check.dds|t",
    }

    for pattern, replacement in pairs(replacements) do
        changelog = string.gsub(changelog, pattern, replacement)
    end

    Chronos_Changelog_Title:SetText(zo_strformat(self.GetDefaultLocaleString("CHANGELOG_TITLE"), self.name))
    Chronos_Changelog_About:SetText(zo_strformat(self.GetDefaultLocaleString("CHANGELOG_FROM"), self.version, self.author))
    Chronos_Changelog_Text:SetText(changelog)

    if not self.db.showChangelog then
        return
    end

    self:ToggleChangelog(self.db.welcomeVersion ~= self.version)
    self.db.welcomeVersion = self.version
end