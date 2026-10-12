local Hermes = _G['Hermes']
local zo_strformat = zo_strformat

function Hermes:ToggleChangelog(visible)
    Hermes_Changelog:SetHidden(not visible)
end

local function initializeChangelogWindow(self)
    Hermes_Changelog:SetHandler("OnMoveStop", function()
        self.db.changelogX = zo_floor(Hermes_Changelog:GetLeft())
        self.db.changelogY = zo_floor(Hermes_Changelog:GetTop())
    end)

    if self.db.changelogX ~= nil and self.db.changelogY ~= nil then
        Hermes_Changelog:ClearAnchors()
        Hermes_Changelog:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.db.changelogX, self.db.changelogY)
    end

    self:CreateGuideHelp(Hermes_Changelog, Hermes_Changelog_Close, "START_UPDATES")
end

function Hermes:ChangelogScreen()
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

    Hermes_Changelog_Title:SetText(zo_strformat(self.GetDefaultLocaleString("CHANGELOG_TITLE"), self.addonName))
    Hermes_Changelog_About:SetText(zo_strformat(self.GetDefaultLocaleString("CHANGELOG_FROM"), self.version, self.author))
    Hermes_Changelog_Text:SetText(changelog)

    if not self.db.showChangelog then
        return
    end

    self:ToggleChangelog(self.db.welcomeVersion ~= self.version)
    self.db.welcomeVersion = self.version
end