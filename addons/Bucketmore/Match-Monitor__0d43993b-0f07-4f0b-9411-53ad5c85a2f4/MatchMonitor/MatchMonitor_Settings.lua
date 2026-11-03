-- MatchMonitor settings (LibAddonMenu-2.0, optional dependency)
-- Position sliders + reset button. Controller operable through the standard
-- settings screen; no mouse dragging and no chat command needed.
-- If LibAddonMenu-2.0 is not present the add-on simply keeps the default/saved position.

local MM = MatchMonitor

function MM.RegisterSettings()
    local LAM = rawget(_G, "LibAddonMenu2")
    if type(LAM) ~= "table" then
        MM.settingsStatus = "LAM not found"
        return false
    end
    local T = MM.T
    local panelId = "MatchMonitorPanel"
    local panel = LAM:RegisterAddonPanel(panelId, {
        type = "panel",
        name = "MatchMonitor",
        displayName = "MatchMonitor",
        author = "Bucketmore",
        version = MM.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local controls = {}
    controls[#controls + 1] = { type = "header", name = T.setHeader }
    controls[#controls + 1] = { type = "description", text = T.setDesc }

    local multi = #MM.panelOrder > 1
    for _, id in ipairs(MM.panelOrder) do
        local prefix = ""
        if multi then prefix = (T.panelName[id] or id) .. " " end
        local defX, defY = MM.GetPanelDefaults(id)
        controls[#controls + 1] = {
            type = "slider",
            name = prefix .. T.setX,
            tooltip = T.setXTip,
            min = 0, max = 100, step = 1,
            getFunc = function()
                local x = MM.GetPos(id)
                return x or defX
            end,
            setFunc = function(value) MM.SetPos(id, value, nil) end,
            default = defX,
        }
        controls[#controls + 1] = {
            type = "slider",
            name = prefix .. T.setY,
            tooltip = T.setYTip,
            min = 0, max = 100, step = 1,
            getFunc = function()
                local _, y = MM.GetPos(id)
                return y or defY
            end,
            setFunc = function(value) MM.SetPos(id, nil, value) end,
            default = defY,
        }
        controls[#controls + 1] = {
            type = "button",
            name = prefix .. T.setReset,
            tooltip = T.setResetTip,
            func = function()
                MM.ResetPos(id)
                local cm = rawget(_G, "CALLBACK_MANAGER")
                if cm and panel then
                    pcall(function() cm:FireCallbacks("LAM-RefreshPanel", panel) end)
                end
            end,
            width = "full",
        }
    end
    LAM:RegisterOptionControls(panelId, controls)

    -- Show the (otherwise hidden) panel while the settings page is open.
    local cm = rawget(_G, "CALLBACK_MANAGER")
    if cm then
        pcall(function()
            cm:RegisterCallback("LAM-PanelOpened", function(p)
                if p == nil or p == panel then MM.PreviewShow(60000) end
            end)
            cm:RegisterCallback("LAM-PanelClosed", function(p)
                if p == nil or p == panel then MM.PreviewEnd() end
            end)
        end)
    end
    MM.settingsStatus = "registered"
    return true
end
