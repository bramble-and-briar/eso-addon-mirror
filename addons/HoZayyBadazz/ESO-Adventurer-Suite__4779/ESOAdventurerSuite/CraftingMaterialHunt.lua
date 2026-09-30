-- ESO Adventurer Suite
-- Combined Crafting Material Hunt
-- Reuses the Resource Pins map + 3D routing engine for Alchemy, Provisioning,
-- and Enchanting without pretending unopened container contents are known.

local EPC = ESOProgressionCoach
if not EPC then return end

EPC.CraftingMaterialHunt = EPC.CraftingMaterialHunt or {}
local H = EPC.CraftingMaterialHunt

local PRESETS = {
    ALCHEMY = {
        label = "Alchemy",
        materials = {
            { name = "Alchemy Sources", kind = "ALCHEMY" },
            { name = "Water / Solvent Sources", kind = "WATER" },
        },
    },
    PROVISIONING = {
        label = "Provisioning",
        materials = {
            { name = "Provisioning Sources", kind = "PROVISIONING" },
        },
    },
    ENCHANTING = {
        label = "Enchanting",
        materials = {
            { name = "Runestones", kind = "ENCHANTING" },
        },
    },
    JEWELRY = {
        label = "Jewelry",
        materials = {
            { name = "Jewelry Seams / Ore Sources", kind = "ORE" },
        },
    },
    WOODWORKING = {
        label = "Woodworking",
        materials = {
            { name = "Wood Sources", kind = "WOOD" },
        },
    },
    BLACKSMITHING = {
        label = "Blacksmithing",
        materials = {
            { name = "Ore Sources", kind = "ORE" },
        },
    },
    CLOTHING = {
        label = "Clothing",
        materials = {
            { name = "Cloth / Fiber Sources", kind = "CLOTH" },
        },
    },
}

local function selectedType()
    local v = EPC.saved and tostring(EPC.saved.craftingMaterialHuntType029763 or "PROVISIONING") or "PROVISIONING"
    if not PRESETS[v] then v = "PROVISIONING" end
    return v
end

function H:GetPreset029763(kind)
    kind = tostring(kind or selectedType())
    return PRESETS[kind] or PRESETS.PROVISIONING
end

function H:GetStatus029763()
    local focus = EPC.ResourcePins and EPC.ResourcePins.missingAlchemyFocus
    if type(focus) ~= "table" then return "Inactive" end
    local label = tostring(focus.craftLabel or self.activeLabel029763 or "Crafting")
    local count = type(focus.locations) == "table" and #focus.locations or 0
    return string.format("%s hunt active • %d source pin%s", label, count, count == 1 and "" or "s")
end

function H:Start029763(kind, openMap)
    local pins = EPC.ResourcePins
    if not pins or type(pins.TrackMissingAlchemyMaterials) ~= "function" then
        if EPC.Print then EPC:Print("Crafting Material Hunt is unavailable because Resource Pins is not ready.") end
        return false
    end

    kind = tostring(kind or selectedType())
    local preset = self:GetPreset029763(kind)
    if EPC.saved then EPC.saved.craftingMaterialHuntType029763 = kind end

    -- Copy preset material tables so ResourcePins can safely attach runtime data.
    local materials = {}
    for i, row in ipairs(preset.materials or {}) do
        materials[i] = {
            name = row.name,
            kind = row.kind,
            key = row.key,
            dynamicHint = row.dynamicHint,
        }
    end

    local tracked, unsupported, destination = pins:TrackMissingAlchemyMaterials(materials)
    pins.missingAlchemyFocus = pins.missingAlchemyFocus or { materials = materials, locations = {} }
    pins.missingAlchemyFocus.craftType = kind
    pins.missingAlchemyFocus.craftLabel = preset.label
    pins.missingAlchemyFocus.summary = preset.label .. " Material Sources"
    self.activeType029763 = kind
    self.activeLabel029763 = preset.label

    if type(pins.RefreshMissingAlchemyMapPins) == "function" then pins:RefreshMissingAlchemyMapPins() end
    if type(pins.RefreshMarkers) == "function" then pins:RefreshMarkers() end

    if openMap ~= false and type(pins.ShowMissingAlchemyMap) == "function" then
        pins:ShowMissingAlchemyMap()
    end

    if EPC.Print then
        local routeText = destination and (" Route: " .. tostring(destination.zoneName or "known zone") .. ".") or ""
        EPC:Print(string.format("%s Material Hunt: %d possible source pin%s active.%s",
            preset.label, tonumber(tracked) or 0, tonumber(tracked) == 1 and "" or "s", routeText))
        if kind == "PROVISIONING" then
            EPC:Print("Provisioning pins mark possible sources only. The Suite learns containers that actually yield provisioning ingredients and reuses those locations later.")
        end
    end
    return true, tracked, unsupported, destination
end

function H:Stop029763()
    self.activeType029763 = nil
    self.activeLabel029763 = nil
    local pins = EPC.ResourcePins
    if pins and type(pins.ClearMissingAlchemyFocus) == "function" then
        pins:ClearMissingAlchemyFocus()
    end
    if EPC.Print then EPC:Print("Crafting Material Hunt stopped.") end
end

function H:StartAlchemy029763(openMap)
    return self:Start029763("ALCHEMY", openMap)
end

function H:StartProvisioning029763(openMap)
    return self:Start029763("PROVISIONING", openMap)
end

function H:StartEnchanting029763(openMap)
    return self:Start029763("ENCHANTING", openMap)
end

function H:StartJewelry029763(openMap)
    return self:Start029763("JEWELRY", openMap)
end

function H:StartWoodworking029763(openMap)
    return self:Start029763("WOODWORKING", openMap)
end

function H:StartBlacksmithing029763(openMap)
    return self:Start029763("BLACKSMITHING", openMap)
end

function H:StartClothing029763(openMap)
    return self:Start029763("CLOTHING", openMap)
end


-- v0.29.765: shared in-window / station hunt bar
local HUNT_ORDER_029765 = { "ALCHEMY", "PROVISIONING", "ENCHANTING", "JEWELRY", "WOODWORKING", "BLACKSMITHING", "CLOTHING" }
local HUNT_LABELS_029765 = {
    ALCHEMY="Alchemy", PROVISIONING="Provisioning", ENCHANTING="Enchanting",
    JEWELRY="Jewelry", WOODWORKING="Woodworking", BLACKSMITHING="Blacksmithing", CLOTHING="Clothing",
}

local function huntTypeFromCraftingType029765(craftingType)
    local map = {}
    local function add(globalName, value)
        local id = rawget(_G, globalName)
        if id ~= nil then map[id] = value end
    end
    add("CRAFTING_TYPE_ALCHEMY", "ALCHEMY")
    add("CRAFTING_TYPE_PROVISIONING", "PROVISIONING")
    add("CRAFTING_TYPE_ENCHANTING", "ENCHANTING")
    add("CRAFTING_TYPE_JEWELRYCRAFTING", "JEWELRY")
    add("CRAFTING_TYPE_WOODWORKING", "WOODWORKING")
    add("CRAFTING_TYPE_BLACKSMITHING", "BLACKSMITHING")
    add("CRAFTING_TYPE_CLOTHIER", "CLOTHING")
    return map[craftingType]
end

function H:GetSelectedType029765()
    local value = EPC.saved and tostring(EPC.saved.craftingMaterialHuntType029763 or "PROVISIONING") or "PROVISIONING"
    return PRESETS[value] and value or "PROVISIONING"
end

function H:SetSelectedType029765(value)
    value = tostring(value or "PROVISIONING")
    if not PRESETS[value] then value = "PROVISIONING" end
    if EPC.saved then EPC.saved.craftingMaterialHuntType029763 = value end
    self:RefreshBars029765()
end

function H:CycleType029765(direction)
    local current = self:GetSelectedType029765()
    local idx = 1
    for i, value in ipairs(HUNT_ORDER_029765) do
        if value == current then idx = i break end
    end
    idx = idx + (tonumber(direction) or 1)
    if idx > #HUNT_ORDER_029765 then idx = 1 end
    if idx < 1 then idx = #HUNT_ORDER_029765 end
    self:SetSelectedType029765(HUNT_ORDER_029765[idx])
end

function H:Travel029765()
    local pins = EPC.ResourcePins
    local focus = pins and pins.missingAlchemyFocus or nil
    local materials = focus and focus.materials or nil
    if type(materials) ~= "table" or #materials == 0 then
        local preset = self:GetPreset029763(self:GetSelectedType029765())
        materials = preset and preset.materials or nil
    end
    if pins and type(pins.TravelToMissingAlchemyMaterials) == "function" and type(materials) == "table" then
        return pins:TravelToMissingAlchemyMaterials(materials)
    end
    if EPC.Print then EPC:Print("Crafting Material Hunt has no travel route yet. Start the hunt first.") end
    return false
end

function H:ShowMap029765()
    local pins = EPC.ResourcePins
    if pins and type(pins.ShowMissingAlchemyMap) == "function" then
        return pins:ShowMissingAlchemyMap()
    end
    return false
end

local function makeHuntButton029765(parent, width, text)
    local wm = WINDOW_MANAGER
    local button = wm:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(width, 30)
    button:SetFont("ZoFontGameBold")
    button:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    button:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    button:SetText(text or "")
    local bg = wm:CreateControl(nil, button, CT_BACKDROP)
    bg:SetAnchorFill(button)
    bg:SetCenterColor(0.035, 0.050, 0.070, 0.96)
    bg:SetEdgeColor(0.22, 0.34, 0.44, 0.95)
    bg:SetEdgeTexture(nil, 1, 1, 1)
    button.easHuntBg029765 = bg
    button:SetHandler("OnMouseEnter", function(control)
        if control.easHuntBg029765 then control.easHuntBg029765:SetCenterColor(0.06, 0.09, 0.12, 0.98) end
    end)
    button:SetHandler("OnMouseExit", function(control)
        if control.easHuntBg029765 then control.easHuntBg029765:SetCenterColor(0.035, 0.050, 0.070, 0.96) end
    end)
    return button
end

function H:CreateBar029765(parent, width, stationLocked)
    if not parent or not WINDOW_MANAGER then return nil end
    local bar = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    bar:SetDimensions(math.max(720, tonumber(width) or 820), 74)
    bar:SetCenterColor(0.020, 0.030, 0.045, 0.97)
    bar:SetEdgeColor(0.55, 0.40, 0.14, 0.95)
    bar:SetEdgeTexture(nil, 1, 1, 1)
    bar.stationLocked029765 = stationLocked == true

    local title = WINDOW_MANAGER:CreateControl(nil, bar, CT_LABEL)
    title:SetAnchor(LEFT, bar, LEFT, 10, 0)
    title:SetDimensions(150, 32)
    title:SetFont("ZoFontGameBold")
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetColor(0.94, 0.84, 0.38, 1)
    title:SetText("MATERIAL HUNT")
    bar.title029765 = title

    local typeButton = makeHuntButton029765(bar, 150, "")
    typeButton:SetAnchor(TOPLEFT, title, TOPRIGHT, 8, 2)
    typeButton:SetHandler("OnClicked", function(_, button)
        if bar.stationLocked029765 then return end
        if button == MOUSE_BUTTON_INDEX_RIGHT then H:CycleType029765(-1) else H:CycleType029765(1) end
    end)
    bar.typeButton029765 = typeButton

    local startButton = makeHuntButton029765(bar, 92, "START")
    startButton:SetAnchor(LEFT, typeButton, RIGHT, 8, 0)
    startButton:SetHandler("OnClicked", function()
        H:StartCurrent029767(false)
        H:RefreshBars029765()
    end)
    bar.startButton029765 = startButton

    local mapButton = makeHuntButton029765(bar, 104, "MAP + 3D")
    mapButton:SetAnchor(LEFT, startButton, RIGHT, 8, 0)
    mapButton:SetHandler("OnClicked", function()
        H:StartCurrent029767(false)
        H:ShowMap029765()
    end)
    bar.mapButton029765 = mapButton

    local travelButton = makeHuntButton029765(bar, 92, "TRAVEL")
    travelButton:SetAnchor(LEFT, mapButton, RIGHT, 8, 0)
    travelButton:SetHandler("OnClicked", function() H:Travel029765() end)
    bar.travelButton029765 = travelButton

    local stopButton = makeHuntButton029765(bar, 82, "STOP")
    stopButton:SetAnchor(LEFT, travelButton, RIGHT, 8, 0)
    stopButton:SetHandler("OnClicked", function()
        H:Stop029763()
        H:RefreshBars029765()
    end)
    bar.stopButton029765 = stopButton

    local status = WINDOW_MANAGER:CreateControl(nil, bar, CT_LABEL)
    status:SetAnchor(TOPLEFT, bar, TOPLEFT, 12, 40)
    status:SetAnchor(TOPRIGHT, bar, TOPRIGHT, -12, 40)
    status:SetHeight(26)
    status:SetFont("ZoFontGameSmall")
    status:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    status:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    status:SetColor(0.68, 0.78, 0.88, 1)
    status:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    bar.status029765 = status

    self.bars029765 = self.bars029765 or {}
    self.bars029765[#self.bars029765 + 1] = bar
    self:RefreshBar029765(bar)
    return bar
end

function H:RefreshBar029765(bar)
    if not bar then return end
    local selected = self:GetSelectedType029765()
    if bar.typeButton029765 then
        local label = HUNT_LABELS_029765[selected] or selected
        bar.typeButton029765:SetText(label .. (bar.stationLocked029765 and "" or "  ▸"))
    end
    local focus = EPC.ResourcePins and EPC.ResourcePins.missingAlchemyFocus or nil
    local activeType = focus and focus.craftType or self.activeType029763
    local active = type(focus) == "table" and type(focus.materials) == "table" and #focus.materials > 0
    if bar.status029765 then
        if active then
            local count = type(focus.locations) == "table" and #focus.locations or 0
            bar.status029765:SetText(string.format("%s active • %d source%s",
                tostring(focus.craftLabel or HUNT_LABELS_029765[activeType] or "Hunt"),
                count, count == 1 and "" or "s"))
        elseif selected == "PROVISIONING" and type(self.selectedProvisioningRecipe029767) == "table" then
            local recipe = self.selectedProvisioningRecipe029767
            local names = {}
            for _, material in ipairs(recipe.missing or {}) do names[#names + 1] = tostring(material.name or "ingredient") end
            if #names > 0 then
                bar.status029765:SetText((recipe.recipeName ~= "" and recipe.recipeName or "Selected recipe") .. " • Missing: " .. table.concat(names, ", "))
            else
                bar.status029765:SetText((recipe.recipeName ~= "" and recipe.recipeName or "Selected recipe") .. " • All ingredients available")
            end
        else
            bar.status029765:SetText("Select a source hunt")
        end
    end
end

function H:RefreshBars029765()
    for _, bar in ipairs(self.bars029765 or {}) do
        self:RefreshBar029765(bar)
    end
end

function H:AttachPotionMaker029765(window)
    if not window or window.easCraftingHuntBar029765 then return window and window.easCraftingHuntBar029765 end
    local bar = self:CreateBar029765(window, 856, false)
    if not bar then return nil end
    bar:SetAnchor(TOPLEFT, window, TOPLEFT, 22, 228)
    window.easCraftingHuntBar029765 = bar
    self.potionMakerBar029765 = bar
    return bar
end

function H:EnsureStationBar029765()
    if self.stationBar029765 or not GuiRoot or not WINDOW_MANAGER then return self.stationBar029765 end
    local root = WINDOW_MANAGER:CreateTopLevelWindow("EAS_CraftingMaterialHuntStationBar029765")
    root:SetDimensions(860, 74)
    root:SetAnchor(TOP, GuiRoot, TOP, 0, 118)
    root:SetDrawTier(rawget(_G, "DT_HIGH") or 2)
    root:SetHidden(true)
    root:SetMouseEnabled(true)
    root:SetClampedToScreen(true)
    local bar = self:CreateBar029765(root, 860, true)
    bar:SetAnchorFill(root)
    root.bar029765 = bar
    self.stationBar029765 = root
    return root
end

function H:OnCraftingStationInteract029765(craftingType)
    if EPC.saved and EPC.saved.craftingMaterialHuntBarEnabled029765 == false then
        if self.stationBar029765 then self.stationBar029765:SetHidden(true) end
        return
    end
    local huntType = huntTypeFromCraftingType029765(craftingType)
    if not huntType then
        if self.stationBar029765 then self.stationBar029765:SetHidden(true) end
        return
    end
    self.stationCraftType029765 = huntType
    self:SetSelectedType029765(huntType)
    if huntType == "PROVISIONING" then
        if not self:InstallProvisionerHook029767() and type(zo_callLater) == "function" then
            zo_callLater(function()
                if H:InstallProvisionerHook029767() then
                    local p = rawget(_G, "PROVISIONER")
                    if p then H:CaptureProvisioningRecipe029767(p) end
                end
            end, 100)
        else
            local p = rawget(_G, "PROVISIONER")
            if p then self:CaptureProvisioningRecipe029767(p) end
        end
    end
    local root = self:EnsureStationBar029765()
    if root and root.bar029765 then
        root.bar029765.stationLocked029765 = true
        self:RefreshBar029765(root.bar029765)
        root:SetHidden(false)
    end
end

function H:OnEndCraftingStationInteract029765()
    self.stationCraftType029765 = nil
    if self.stationBar029765 then self.stationBar029765:SetHidden(true) end
end

function H:InitializeStationBar029765()
    if self._stationInitialized029765 or not EVENT_MANAGER then return end
    self._stationInitialized029765 = true
    local prefix = (EPC.name or "EAS") .. "_CraftingHuntBar029765"
    if rawget(_G, "EVENT_CRAFTING_STATION_INTERACT") then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_Start", EVENT_CRAFTING_STATION_INTERACT, function(_, craftingType)
            H:OnCraftingStationInteract029765(craftingType)
        end)
    end
    if rawget(_G, "EVENT_END_CRAFTING_STATION_INTERACT") then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_End", EVENT_END_CRAFTING_STATION_INTERACT, function()
            H:OnEndCraftingStationInteract029765()
        end)
    end
end

H:InitializeStationBar029765()


function H:SetBarsEnabled029765(enabled)
    enabled = enabled ~= false
    if EPC.saved then EPC.saved.craftingMaterialHuntBarEnabled029765 = enabled end

    if self.stationBar029765 then
        if not enabled then
            self.stationBar029765:SetHidden(true)
        elseif self.stationCraftType029765 then
            self.stationBar029765:SetHidden(false)
        end
    end

    local maker = EPC.AlchemyPotionMaker
    local window = maker and maker.window or nil
    if window then
        local bar = window.easCraftingHuntBar029765
        if enabled then
            if not bar then bar = self:AttachPotionMaker029765(window) end
            if bar then bar:SetHidden(false) end
        elseif bar then
            bar:SetHidden(true)
        end
    end
end


-- v0.29.767: item-specific Provisioning hunts
local function cleanItemName029767(value)
    value = tostring(value or "")
    if type(zo_strformat) == "function" and rawget(_G, "SI_TOOLTIP_ITEM_NAME") then
        local ok, formatted = pcall(zo_strformat, SI_TOOLTIP_ITEM_NAME, value)
        if ok and formatted and formatted ~= "" then value = tostring(formatted) end
    end
    return value
end

function H:CaptureProvisioningRecipe029767(provisioner)
    if not provisioner or type(provisioner.GetSelectedRecipeListIndex) ~= "function"
        or type(provisioner.GetSelectedRecipeIndex) ~= "function" then
        return false
    end

    local okList, recipeListIndex = pcall(provisioner.GetSelectedRecipeListIndex, provisioner)
    local okRecipe, recipeIndex = pcall(provisioner.GetSelectedRecipeIndex, provisioner)
    recipeListIndex = okList and tonumber(recipeListIndex) or nil
    recipeIndex = okRecipe and tonumber(recipeIndex) or nil
    if not recipeListIndex or not recipeIndex then
        self.selectedProvisioningRecipe029767 = nil
        self:RefreshBars029765()
        return false
    end

    local recipeName, numIngredients = "", 0
    if type(GetRecipeInfo) == "function" then
        local ok, _, name, count = pcall(GetRecipeInfo, recipeListIndex, recipeIndex)
        if ok then
            recipeName = tostring(name or "")
            numIngredients = tonumber(count) or 0
        end
    end

    local missing, all = {}, {}
    if numIngredients > 0 and type(GetRecipeIngredientItemInfo) == "function" then
        for ingredientIndex = 1, numIngredients do
            local ok, name, _, requiredQuantity = pcall(GetRecipeIngredientItemInfo, recipeListIndex, recipeIndex, ingredientIndex)
            if ok and tostring(name or "") ~= "" then
                name = cleanItemName029767(name)
                requiredQuantity = tonumber(requiredQuantity) or 1
                local current = 0
                if type(GetCurrentRecipeIngredientCount) == "function" then
                    local okCount, value = pcall(GetCurrentRecipeIngredientCount, recipeListIndex, recipeIndex, ingredientIndex)
                    if okCount then current = tonumber(value) or 0 end
                end
                local row = {
                    name = name,
                    key = name,
                    kind = "PROVISIONING",
                    required = requiredQuantity,
                    current = current,
                    ingredientIndex = ingredientIndex,
                }
                all[#all + 1] = row
                if current < requiredQuantity then missing[#missing + 1] = row end
            end
        end
    end

    self.selectedProvisioningRecipe029767 = {
        recipeListIndex = recipeListIndex,
        recipeIndex = recipeIndex,
        recipeName = recipeName,
        missing = missing,
        all = all,
    }
    self:SetSelectedType029765("PROVISIONING")
    self:RefreshBars029765()
    return true
end

function H:GetActiveProvisioningMaterials029767()
    local selected = self.selectedProvisioningRecipe029767
    if type(selected) ~= "table" then return nil end
    if type(selected.missing) == "table" and #selected.missing > 0 then
        return selected.missing
    end
    return {}
end

function H:StartCurrent029767(openMap)
    local kind = self:GetSelectedType029765()
    if kind == "PROVISIONING" then
        local selected = self.selectedProvisioningRecipe029767
        if type(selected) == "table" then
            local materials = self:GetActiveProvisioningMaterials029767()
            if type(materials) == "table" then
                if #materials == 0 then
                    if EPC.Print then
                        EPC:Print((selected.recipeName ~= "" and selected.recipeName or "Selected recipe") .. ": all ingredients are already available.")
                    end
                    return false
                end

                local pins = EPC.ResourcePins
                if pins and type(pins.TrackMissingAlchemyMaterials) == "function" then
                    local tracked, unsupported, destination = pins:TrackMissingAlchemyMaterials(materials)
                    pins.missingAlchemyFocus = pins.missingAlchemyFocus or { materials = materials, locations = {} }
                    pins.missingAlchemyFocus.craftType = "PROVISIONING"
                    pins.missingAlchemyFocus.craftLabel = selected.recipeName ~= "" and selected.recipeName or "Provisioning"
                    pins.missingAlchemyFocus.recipeSpecific = true
                    pins.missingAlchemyFocus.recipeName = selected.recipeName
                    pins.missingAlchemyFocus.summary = selected.recipeName ~= "" and selected.recipeName or "Provisioning Recipe"
                    self.activeType029763 = "PROVISIONING"
                    self.activeLabel029763 = pins.missingAlchemyFocus.craftLabel
                    if type(pins.RefreshMissingAlchemyMapPins) == "function" then pins:RefreshMissingAlchemyMapPins() end
                    if type(pins.RefreshMarkers) == "function" then pins:RefreshMarkers() end
                    if openMap ~= false and type(pins.ShowMissingAlchemyMap) == "function" then pins:ShowMissingAlchemyMap() end
                    self:RefreshBars029765()
                    if EPC.Print then
                        local names = {}
                        for _, material in ipairs(materials) do names[#names + 1] = tostring(material.name or "ingredient") end
                        EPC:Print(string.format("%s hunt: %s", selected.recipeName ~= "" and selected.recipeName or "Provisioning", table.concat(names, ", ")))
                    end
                    return true, tracked, unsupported, destination
                end
            end
        end
    end
    return self:Start029763(kind, openMap)
end

function H:InstallProvisionerHook029767()
    if self._provisionerHook029767 then return true end
    local provisioner = rawget(_G, "PROVISIONER")
    if not provisioner or type(provisioner.RefreshRecipeDetails) ~= "function" or type(ZO_PostHook) ~= "function" then
        return false
    end
    self._provisionerHook029767 = true
    ZO_PostHook(provisioner, "RefreshRecipeDetails", function(owner)
        if H.stationCraftType029765 == "PROVISIONING" or H:GetSelectedType029765() == "PROVISIONING" then
            H:CaptureProvisioningRecipe029767(owner)
            local focus = EPC.ResourcePins and EPC.ResourcePins.missingAlchemyFocus or nil
            if type(focus) == "table" and focus.recipeSpecific == true and H.stationCraftType029765 == "PROVISIONING" then
                H:StartCurrent029767(false)
            end
        end
    end)
    return true
end
