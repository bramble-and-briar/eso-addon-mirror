-- ESO Adventurer Suite
-- Unified settings integration for newer group features.
-- Keeps the Suite on one LibAddonMenu registration so existing settings cannot
-- be replaced by a second RegisterOptionControls call.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Settings then return end
local S = EPC.Settings
local GF = EPC.GroupFinderPlus
if not GF then return end

if S._easUnifiedGroupSettings029678 then return end
S._easUnifiedGroupSettings029678 = true

local selectedBlacklist = ""

local function refreshGF()
    if GF and GF.RefreshVisibility then GF:RefreshVisibility() end
    if GF and GF.RefreshRows and GF.IsOverlayAllowed and GF:IsOverlayAllowed() then GF:RefreshRows() end
end

local function categoryOption(sv, id, label)
    return {
        type = "checkbox", name = label,
        getFunc = function() return sv.categoriesEnabled[id] ~= false end,
        setFunc = function(v) sv.categoriesEnabled[id] = v == true refreshGF() end,
        default = true,
        width = "half",
    }
end

local function trialOption(sv, short, label)
    return {
        type = "checkbox", name = short .. " — " .. label,
        getFunc = function() return sv.trialsEnabled[short] ~= false end,
        setFunc = function(v) sv.trialsEnabled[short] = v == true refreshGF() end,
        default = true,
        width = "half",
    }
end

local function buildGroupFinderControls()
    local sv = GF:GetSV()
    if not sv then return {} end

    local opts = {
        { type = "header", name = "Group Finder Plus" },
        {
            type = "description",
            title = "Group Finder Plus",
            text = "Adds listing filters, colored listing creation text, recreate-last-listing, blacklist tools, and an optional compact HUD listing browser. The HUD browser can remain off while the native Group Finder enhancements stay enabled.",
            width = "full",
        },
        {
            type = "checkbox", name = "Enable Group Finder Plus",
            getFunc = function() return sv.enabled ~= false end,
            setFunc = function(v) sv.enabled = v == true refreshGF() end,
            default = true,
        },
        {
            type = "checkbox", name = "Show Group Finder HUD overlay",
            tooltip = "Optional compact live listing browser on the gameplay HUD. When disabled, the Suite does not run background Group Finder searches for this overlay.",
            getFunc = function() return sv.showHudOverlay == true end,
            setFunc = function(v) sv.showHudOverlay = v == true refreshGF() end,
            default = false,
        },
        {
            type = "button", name = "Group Finder HUD position", buttonText = "Reset Position",
            func = function()
                sv.windowLeft, sv.windowTop = 20, 180
                if GF.window then GF.window:ClearAnchors() GF.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 20, 180) end
            end,
            width = "half",
        },
        {
            type = "button", name = "Refresh Group Finder overlay", buttonText = "Search Now",
            func = function() if GF.RequestSearch then GF:RequestSearch(true) end end,
            width = "half",
        },
        {
            type = "checkbox", name = "Allow all roles when searching",
            tooltip = "Keeps Enforce Roles off by default for Group Finder searches.",
            getFunc = function() return sv.allowAllRoles ~= false end,
            setFunc = function(v) sv.allowAllRoles = v == true end,
            default = true,
        },
        {
            type = "checkbox", name = "Hide WTS listings",
            tooltip = "Hides Want-To-Sell listings outside the Custom category.",
            getFunc = function() return sv.hideWTS ~= false end,
            setFunc = function(v) sv.hideWTS = v == true refreshGF() end,
            default = true,
        },
        {
            type = "checkbox", name = "Hide listings above my CP",
            getFunc = function() return sv.hideInsufficientCP == true end,
            setFunc = function(v) sv.hideInsufficientCP = v == true refreshGF() end,
            default = false,
        },
        {
            type = "checkbox", name = "Highlight last-boss listings",
            tooltip = "Uses a purple row highlight for listings that mention last/final boss.",
            getFunc = function() return sv.lastBossHighlight ~= false end,
            setFunc = function(v) sv.lastBossHighlight = v == true refreshGF() end,
            default = true,
        },
        {
            type = "checkbox", name = "Show Normal / Veteran HUD button",
            getFunc = function() return sv.showModeButton ~= false end,
            setFunc = function(v) sv.showModeButton = v == true if GF.UpdateHeader then GF:UpdateHeader() end end,
            default = true,
        },
        {
            type = "checkbox", name = "Hide Group Finder HUD in dungeons/trials",
            getFunc = function() return sv.hideInInstances == true end,
            setFunc = function(v) sv.hideInInstances = v == true refreshGF() end,
            default = false,
        },
        {
            type = "colorpicker", name = "Listing title color",
            tooltip = "Color used by the small color swatch beside the native Group Finder listing title field.",
            getFunc = function() local c = ZO_ColorDef:New(sv.titleColor or "A020F0") return c:UnpackRGBA() end,
            setFunc = function(r,g,b) sv.titleColor = ZO_ColorDef:New(r,g,b):ToHex():upper():sub(1,6) sv.titleColor = GF:GetSV().titleColor end,
            default = {0.63,0.13,0.94,1},
        },
        {
            type = "button", name = "Apply title color now", buttonText = "Color Title",
            func = function() if GF.ApplyColorToField then GF:ApplyColorToField("title") end end,
            width = "half",
        },
        {
            type = "colorpicker", name = "Listing description color",
            getFunc = function() local c = ZO_ColorDef:New(sv.descriptionColor or "8A2BE2") return c:UnpackRGBA() end,
            setFunc = function(r,g,b) sv.descriptionColor = ZO_ColorDef:New(r,g,b):ToHex():upper():sub(1,6) sv.descriptionColor = GF:GetSV().descriptionColor end,
            default = {0.54,0.17,0.89,1},
        },
        {
            type = "button", name = "Apply description color now", buttonText = "Color Description",
            func = function() if GF.ApplyColorToField then GF:ApplyColorToField("description") end end,
            width = "half",
        },
        {
            type = "button", name = "Recreate last listing", buttonText = "Recreate Listing",
            tooltip = "Recreates the last Group Finder listing the Suite saved after a successful create/update.",
            func = function() if GF.RestoreSavedListing then GF:RestoreSavedListing() end end,
        },
        { type = "header", name = "Group Finder Categories" },
    }

    for _, cat in ipairs(GF:GetCategories()) do opts[#opts + 1] = categoryOption(sv, cat.id, cat.name) end

    opts[#opts + 1] = { type = "header", name = "Trial Filters" }
    local names = {AA="Aetherian Archive",AS="Asylum Sanctorium",CR="Cloudrest",HoF="Halls of Fabrication",HRC="Hel Ra Citadel",SO="Sanctum Ophidia",MoL="Maw of Lorkhaj",SS="Sunspire",KA="Kyne's Aegis",RG="Rockgrove",DSR="Dreadsail Reef",SE="Sanity's Edge",LC="Lucent Citadel",OC="Ossein Cage"}
    local order = {"AA","AS","CR","HoF","HRC","SO","MoL","SS","KA","RG","DSR","SE","LC","OC"}
    for _, short in ipairs(order) do opts[#opts + 1] = trialOption(sv, short, names[short] or short) end

    opts[#opts + 1] = { type = "header", name = "Group Finder Blacklist" }
    opts[#opts + 1] = {
        type = "dropdown", name = "Blacklisted leaders",
        choices = GF:GetBlacklistChoices(),
        getFunc = function() return selectedBlacklist end,
        setFunc = function(v) selectedBlacklist = v or "" end,
        scrollable = 12,
        reference = "EAS_GROUPFINDERPLUS_BLACKLIST_DROPDOWN",
    }
    opts[#opts + 1] = {
        type = "button", name = "Remove selected blacklist entry", buttonText = "Unblacklist",
        func = function()
            if selectedBlacklist ~= "" then GF:Unblacklist(selectedBlacklist) selectedBlacklist = "" end
            local d = rawget(_G, "EAS_GROUPFINDERPLUS_BLACKLIST_DROPDOWN")
            if d and d.UpdateChoices then d:UpdateChoices(GF:GetBlacklistChoices()) d:UpdateValue() end
        end,
    }
    return opts
end

local function appendControlsToSubmenu(options, submenuName, controls)
    if type(options) ~= "table" or type(controls) ~= "table" or #controls == 0 then return false end
    for _, option in ipairs(options) do
        if option and option.type == "submenu" and option.name == submenuName and type(option.controls) == "table" then
            for _, control in ipairs(controls) do
                if control.type == "description" then control.width = "full" end
                option.controls[#option.controls + 1] = control
            end
            return true
        end
    end
    return false
end

local function appendControlsToNestedSubmenu(options, categoryName, featureName, controls)
    if type(options) ~= "table" or type(controls) ~= "table" or #controls == 0 then return false end
    for _, category in ipairs(options) do
        if category and category.type == "submenu" and category.name == categoryName and type(category.controls) == "table" then
            for _, feature in ipairs(category.controls) do
                if feature and feature.type == "submenu" and feature.name == featureName and type(feature.controls) == "table" then
                    for _, control in ipairs(controls) do
                        if control.type == "description" then control.width = "full" end
                        feature.controls[#feature.controls + 1] = control
                    end
                    return true
                end
            end
        end
    end
    return false
end

S:RegisterOptionsExtension("GroupFinderPlus", function(options)
    local loot = EPC.GroupLootNotifier
    if loot then loot.settingsInjected = true end

    appendControlsToNestedSubmenu(options, "Activities & Group Finder", "Dungeon / Group Finder", buildGroupFinderControls())

    if loot and type(loot.GetSettingsOptions) == "function" then
        local lootControls = loot:GetSettingsOptions() or {}
        -- GetSettingsOptions historically returned its own header because the
        -- feature was appended directly into a flat category. The feature tree
        -- now owns the section title, so drop that legacy header and place every
        -- Group Loot control inside one dedicated submenu.
        if lootControls[1] and lootControls[1].type == "header" and lootControls[1].name == "Group Loot Notifier" then
            table.remove(lootControls, 1)
        end
        for _, option in ipairs(options) do
            if option and option.type == "submenu" and option.name == "Group, Team & Loot" and type(option.controls) == "table" then
                option.controls[#option.controls + 1] = {
                    type = "submenu",
                    name = "Group Loot Notifier",
                    tooltip = "Group loot chat alerts, notable-item filters, display formatting, and session loot history.",
                    reference = "EAS_SettingsFeature029788_GroupLootNotifier",
                    controls = lootControls,
                }
                break
            end
        end
    end
end, 100)

EPC.unifiedSettingsIntegration029678 = true
