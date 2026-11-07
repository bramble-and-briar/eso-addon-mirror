local A = OneMap

function A:CreateSettings()
    local panelName = "OneMapSettings"
    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = "panel", name = "OneMap", displayName = "OneMap", author = "oneDOK",
        version = self.version, registerForRefresh = true, registerForDefaults = true,
    })
    local options = {}
    local function Header(key) options[#options + 1] = { type = "header", name = self:Text(key) } end
    local function Description(key) options[#options + 1] = { type = "description", text = self:Text(key) } end
    local function Checkbox(key)
        options[#options + 1] = {
            type = "checkbox", name = self:Text(key), width = "full", default = self.defaults[key],
            tooltip = self.strings[key .. "Tooltip"],
            getFunc = function() return self.saved[key] end,
            setFunc = function(value)
                self.saved[key] = value
                self:CancelPendingTravel()
                self:CancelSmoothScroll()
                self.quote = nil
                WORLD_MAP_MANAGER:ResizeAndReanchorMap()
                self:ApplyMapSettings()
                self:RefreshHouseRows()
                WORLD_MAP_INFO.modeBar:UpdateButtons()

            end,
        }
    end
    Description("scope")
    Header("map")
    for _, key in ipairs({ "enlargeMap", "hideCompletion", "playerPulse", "smoothScroll" }) do Checkbox(key) end
    Checkbox("skipPaidConfirmation")
    LibAddonMenu2:RegisterOptionControls(panelName, options)
end
