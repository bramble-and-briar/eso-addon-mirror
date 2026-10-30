local WH = WizardsHelper

function WH:RunWardrobeCommand(command, index)
    local ready, reason = self:CheckWardrobe()
    if not ready then self:Message(reason); return end
    local ww = WizardsWardrobe
    local selection = ww.selection
    local zone = selection and selection.zone
    local pageId = selection and selection.pageId
    local setups = zone and ww.setups[zone.tag] and ww.setups[zone.tag][pageId]
    if command == "window" then
        self:OpenWardrobe()
        return
    end
    if not zone or type(setups) ~= "table" or type(setups[1]) ~= "table" then
        self:Message("Select a non-empty page in Wizard's Wardrobe first.")
        return
    end
    if command == "setup" then
        if type(setups[index]) ~= "table" then self:Message("This WW page has no setup " .. tostring(index) .. "."); return end
        ww.LoadSetupCurrent(index, false)
    elseif command == "previous" or command == "next" or command == "current" then
        if command == "current" and (not ww.currentIndex or not setups[ww.currentIndex]) then
            self:Message("Equip a WW setup before reloading the current setup."); return
        end
        ww.LoadSetupAdjacent(command == "previous" and -1 or command == "next" and 1 or 0)
    elseif command == "deposit" or command == "withdraw" then
        if not IsBankOpen() then self:Message("Open a bank before using this WW command."); return end
        local method = ww.banking and ww.banking[command == "deposit" and "DepositPage" or "WithdrawPage"]
        if type(method) ~= "function" then self:Message("This WW version does not expose the banking command."); return end
        method(zone, pageId)
    end
end

function WH:RegisterRadial()
    local radial = LibRadialMenu
    if type(radial) ~= "table" or type(radial.RegisterAddon) ~= "function" or type(radial.RegisterEntry) ~= "function" then return end
    radial:RegisterAddon(self.name, self.title)
    local icon = "/WizardsWardrobe/assets/icon64.dds"
    local function register(id, name, description, callback)
        radial:RegisterEntry(WH.name, name, id, icon, function()
            local ok, reason = pcall(callback)
            if not ok then WH:Message("WW command failed: " .. tostring(reason)) end
        end, description)
    end
    register("helper", "Open Wizard's Helper", "Browse another character's WW setups and copy them to this character.", function() self:Toggle() end)
    register("wardrobe", "Open Wizard's Wardrobe", "Open Wizard's Wardrobe controls.", function() self:RunWardrobeCommand("window") end)
    for _, command in ipairs({ "previous", "current", "next" }) do
        local selectedCommand = command
        register(command, "WW: " .. command .. " setup", "Use the " .. command .. " setup on the page currently selected in WW.",
            function() self:RunWardrobeCommand(selectedCommand) end)
    end
    for index = 1, 12 do
        local setupIndex = index
        register("setup" .. index, "WW: equip setup " .. index, "Equip setup " .. index .. " on the page currently selected in WW. This is a page slot, not a fixed build.",
            function() self:RunWardrobeCommand("setup", setupIndex) end)
    end
    register("deposit", "WW: deposit page gear", "Ask WW to deposit the selected page's gear. Requires an open bank.", function() self:RunWardrobeCommand("deposit") end)
    register("withdraw", "WW: withdraw page gear", "Ask WW to withdraw the selected page's gear. Requires an open bank.", function() self:RunWardrobeCommand("withdraw") end)
end
