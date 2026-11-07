local A = OneDungeon

function A:SetSortOrder(value)
    if value ~= "standard" and value ~= "alphabetical" then return end
    self.saved.sortOrder = value
    -- Rebuilding rows only changes presentation; native activity selections
    -- remain owned by ESO, even while a queue search is in progress.
    if self.panel and not self.panel:IsHidden() and not self.failed then
        self:Guard(function() self:BuildList() end)
    end
end

function A:InstallSettings()
    local LAM = LibAddonMenu2
    self.settingsPanel = LAM:RegisterAddonPanel("OneDungeonSettings", {
        type = "panel", name = self.name, displayName = self.name,
        author = "oneDOK", version = self.version,
        registerForRefresh = true, registerForDefaults = true,
    })
    LAM:RegisterOptionControls("OneDungeonSettings", {
        { type = "description", text = GetString(ONEDUNGEON_SETTINGS_DESCRIPTION) },
        {
            type = "dropdown", name = GetString(ONEDUNGEON_SORT_ORDER),
            tooltip = GetString(ONEDUNGEON_SORT_ORDER_TIP),
            choices = { GetString(ONEDUNGEON_SORT_STANDARD), GetString(ONEDUNGEON_SORT_ALPHABETICAL) },
            choicesValues = { "standard", "alphabetical" },
            getFunc = function() return A.saved.sortOrder end,
            setFunc = function(value) A:SetSortOrder(value) end,
            default = "standard", width = "full",
        },
    })
end
