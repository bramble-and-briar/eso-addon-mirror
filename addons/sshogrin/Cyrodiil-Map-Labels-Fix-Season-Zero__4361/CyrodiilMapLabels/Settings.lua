-- Dynamically generate the alphabetized choices array cleanly outside the table
local fontChoicesList = {}
if CyrodiilMapLabelsFonts then
    for displayName in pairs(CyrodiilMapLabelsFonts) do
        table.insert(fontChoicesList, displayName)
    end
    table.sort(fontChoicesList)
else
    fontChoicesList = {"Standard Bold"}
end

function CyrodiilMapLabelsAddon.CreateSettingsMenu()
    local lam = LibAddonMenu2
    if not lam then return end
    local db = CyrodiilMapLabelsAddon.db

    local prefix = "SI_CYRODIILMAPLABELS_"

    local panelData = {
        type = "panel",
        name = "CyrodiilMapLabels",
        displayName = GetString(_G[prefix .. "title"]),
        author = "Neurowise & |c2046e5sshogrin|r",
        version = CyrodiilMapLabelsDefaults.version,
        registerForRefresh = true,
    }

    local optionsData = {
        [1] = {
            type = "dropdown",
            name = GetString(_G[prefix .. "nameDropdown"]),
            tooltip = GetString(_G[prefix .. "descDropdown"]),
            choices = {GetString(_G[prefix .. "choiceLong"]), GetString(_G[prefix .. "choiceShort"])},
            getFunc = function() 
                if db.datasetChoice == "Short Names" then return GetString(_G[prefix .. "choiceShort"]) end
                return GetString(_G[prefix .. "choiceLong"])
            end,
            setFunc = function(value) 
                if value == GetString(_G[prefix .. "choiceShort"]) then db.datasetChoice = "Short Names" else db.datasetChoice = "Long Names" end
                CyrodiilMapLabelsAddon.UpdateLabels() 
            end,
            default = function()
                if CyrodiilMapLabelsDefaults.datasetChoice == "Short Names" then return GetString(_G[prefix .. "choiceShort"]) end
                return GetString(_G[prefix .. "choiceLong"])
            end,
        },
        [2] = {
            type = "checkbox",
            name = GetString(_G[prefix .. "nameCheckbox"]),
            tooltip = GetString(_G[prefix .. "descCheckbox"]),
            getFunc = function() if db.useAllianceColors == nil then return true end return db.useAllianceColors end,
            setFunc = function(value) db.useAllianceColors = value CyrodiilMapLabelsAddon.UpdateLabels() end,
            default = CyrodiilMapLabelsDefaults.useAllianceColors,
        },
        [3] = {
            type = "colorpicker",
            name = GetString(_G[prefix .. "nameColor"]),
            tooltip = Get_String and GetString(_G[prefix .. "descColor"]) or "Custom text color.",
            getFunc = function() return db.fallbackR, db.fallbackG, db.fallbackB end,
            setFunc = function(r, g, b) db.fallbackR, db.fallbackG, db.fallbackB = r, g, b CyrodiilMapLabelsAddon.UpdateLabels() end,
            default = { r = CyrodiilMapLabelsDefaults.fallbackR, g = CyrodiilMapLabelsDefaults.fallbackG, b = CyrodiilMapLabelsDefaults.fallbackB },
        },
        [4] = {
            type = "slider",
            name = GetString(_G[prefix .. "nameSlider"]),
            tooltip = GetString(_G[prefix .. "descSlider"]),
            min = 0.5, max = 2.0, step = 0.1, decimals = 1,
            getFunc = function() return db.fontScale or CyrodiilMapLabelsDefaults.fontScale end,
            setFunc = function(value) db.fontScale = value CyrodiilMapLabelsAddon.UpdateLabels() end,
            default = CyrodiilMapLabelsDefaults.fontScale,
        },
        [5] = {
            type = "dropdown",
            name = "Font Style",
            tooltip = "Choose the text style used for map labels.",
            choices = fontChoicesList,
            getFunc = function() 
                if CyrodiilMapLabelsFonts then
                    for displayName, internalName in pairs(CyrodiilMapLabelsFonts) do
                        if internalName == (db.fontStyle or CyrodiilMapLabelsDefaults.fontStyle) then
                            return displayName
                        end
                    end
                end
                return "Standard Sans-Serif (BOLD)"
            end,
            setFunc = function(value) 
                if CyrodiilMapLabelsFonts then
                    db.fontStyle = CyrodiilMapLabelsFonts[value] or "EsoUI/Common/Fonts/Univers67.slug|14|soft-shadow-thick"
                else
                    db.fontStyle = "EsoUI/Common/Fonts/Univers67.slug|14|soft-shadow-thick"
                end
                CyrodiilMapLabelsAddon.UpdateLabels() 
            end,
            default = "Standard Sans-Serif (BOLD)",
        },
    }

    lam:RegisterAddonPanel("CyrodiilMapLabelsOptionsPanel", panelData)
    lam:RegisterOptionControls("CyrodiilMapLabelsOptionsPanel", optionsData)
end
