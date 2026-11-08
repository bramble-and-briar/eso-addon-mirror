-- Per-addon framework support. Loaded before this addon's runtime files.
-- Existing SavedVariables paths and schema versions are preserved.
local F = {
    id = "CallToArm", savedPrefix = "CallToArm", displayName = "CallToArm", version = "1.2.2",
    accountOnly = true, defaultAccountWide = true,
    nativeProfile = false, standalone = false,
    toggleEnabled = false,
    scopeReason = "Guild lock-in, home-campaign selection and CTA coordination are account-wide.",
    scopedNames = nil,
}
_G["CallToArm_Framework"] = F

local function Copy(value)
    if type(value) ~= "table" then return value end
    -- ESO exposes saved data through __index; pairs(interface) sees methods,
    -- not the saved settings. Copy the underlying data, never its methods.
    local meta = getmetatable(value)
    if meta and type(meta.__index) == "table" then value = meta.__index end
    local result = {}
    for key, item in pairs(value) do
        if type(item) ~= "function" then result[key] = Copy(item) end
    end
    return result
end

function F:ReadScope()
    if self.accountOnly or self.nativeProfile then return nil end
    if not self.scope then
        self.scope = ZO_SavedVars:NewCharacterIdSettings(
            self.savedPrefix .. "_FrameworkScopeSV", 1, nil,
            { accountWide = self.defaultAccountWide }
        )
        -- Keep the active profile fixed until reload, even after menu changes.
        self.activeAccountWide = self.scope.accountWide ~= false
    end
    return self.scope
end

function F:NewAccountWide(name, version, namespace, defaults, ...)
    if self.accountOnly or (self.scopedNames and not self.scopedNames[name]) then
        return ZO_SavedVars:NewAccountWide(name, version, namespace, defaults, ...)
    end
    self:ReadScope()
    local account = ZO_SavedVars:NewAccountWide(name, version, namespace, defaults, ...)
    if self.activeAccountWide then return account end
    return ZO_SavedVars:NewCharacterIdSettings(name, version, namespace, Copy(account), ...)
end

function F:NewCharacterIdSettings(name, version, namespace, defaults, ...)
    self:ReadScope()
    local character = ZO_SavedVars:NewCharacterIdSettings(name, version, namespace, defaults, ...)
    if not self.activeAccountWide then return character end
    return ZO_SavedVars:NewAccountWide(name, version, namespace, Copy(character), ...)
end

function F:IsEnabled()
    if not self.preferences then
        self.preferences = self:NewAccountWide(self.savedPrefix .. "_FrameworkPreferencesSV", 1, nil, { enabled = true })
    end
    return self.preferences.enabled ~= false
end

function F:AddProfileControls(menu, forceAccountOnly)
    local L = LibHarvensAddonSettings
    if not L or not menu or menu._frameworkProfileAdded then return end
    menu._frameworkProfileAdded = true
    menu:AddSetting({ type = L.ST_SECTION, subMenu = false, label = "Settings Profile" })
    menu:AddSetting({ type = L.ST_LABEL, label = self.displayName .. " " .. self.version })
    if forceAccountOnly or self.accountOnly then
        menu:AddSetting({ type = L.ST_LABEL, label = "Account-wide settings", tooltip = self.scopeReason })
    elseif not self.nativeProfile then
        self:ReadScope()
        menu:AddSetting({
            type = L.ST_CHECKBOX,
            label = "Use Account-wide Settings",
            tooltip = "On shares settings across characters; off uses this character's profile. New profiles copy current settings. Existing profiles are preserved. Choose Apply Settings Profile to reload and activate the selection. Shared records remain account-wide where specified.",
            getFunction = function() return self.scope.accountWide ~= false end,
            setFunction = function(value) self.scope.accountWide = value == true end,
            default = self.scope.accountWide ~= false,
        })
        menu:AddSetting({ type = L.ST_LABEL, label = function()
            return self.activeAccountWide == (self.scope.accountWide ~= false)
                and "Settings profile is active."
                or "Profile change pending: apply or reload to activate."
        end })
    end
    if self.toggleEnabled then
        self:IsEnabled()
        menu:AddSetting({
            type = L.ST_CHECKBOX, label = "Enable Addon After Reload",
            tooltip = "Change this preference, then apply or reload. The settings menu remains available when disabled.",
            getFunction = function() return self.preferences.enabled ~= false end,
            setFunction = function(value) self.preferences.enabled = value == true end,
            default = true,
        })
    end
    if not forceAccountOnly and not self.accountOnly and not self.nativeProfile then
        menu:AddSetting({ type = L.ST_BUTTON, label = "Apply Settings Profile (Reload UI)",
            buttonText = "Apply and Reload", clickHandler = function() if ReloadUI then ReloadUI("ingame") end end })
    end
end

function F:RemoveFooter(menu)
    if not menu or type(menu.settings) ~= "table" then return end
    for index = #menu.settings, 1, -1 do
        local setting = menu.settings[index]
        -- LHAS converts params.label/tooltip to labelText/tooltipText.
        -- Never compare missing labels with an uninitialised signature: nil
        -- equals nil and would remove every ordinary control on first use.
        local label = setting.labelText or setting.label
        local tooltip = setting.tooltipText or setting.tooltip
        local isSignature = self.signature ~= nil and label == self.signature
        local isContact = self.contact ~= nil and label == "Contact" and tooltip == self.contact
        if isSignature or isContact then
            if menu.RemoveSettings then
                menu:RemoveSettings(index, 1)
            else
                table.remove(menu.settings, index)
            end
        end
    end
end

function F:AddFooter(menu)
    local L = LibHarvensAddonSettings
    if not L or not menu then return end
    self:RemoveFooter(menu)
    self.signature = "|cFFD700Built on tea, toast and ADHD – tested live on PS5.|r\n" ..
        "|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r"
    self.contact = "Found an error or need to contact me about " .. self.displayName ..
        "?\n\nPlayStation User / PSN: SugaComa\nEmail: eso.addons@rik-sprint.co.uk or use the contact form at www.rik-sprint.co.uk/contact"
    menu:AddSetting({ type = L.ST_SECTION, subMenu = false, label = self.signature, _frameworkFooter = true })
    menu:AddSetting({ type = L.ST_LABEL, label = "Contact", tooltip = self.contact, _frameworkFooter = true })
end

if F.standalone then
    EVENT_MANAGER:RegisterForEvent(F.id .. "_FrameworkMenu", EVENT_ADD_ON_LOADED, function(_, name)
        if name ~= F.id then return end
        EVENT_MANAGER:UnregisterForEvent(F.id .. "_FrameworkMenu", EVENT_ADD_ON_LOADED)
        zo_callLater(function()
            if not LibHarvensAddonSettings then return end
            local menu = LibHarvensAddonSettings:AddAddon(F.displayName, { allowDefaults = false, allowRefresh = true })
            if not menu then return end
            menu:AddSetting({ type = LibHarvensAddonSettings.ST_LABEL, label = "Open CallToArm settings. Select your guild and home campaign, review lock status, then use the arm/confirm controls deliberately. Configure CTA alerts, activity filters and intervals. Settings intentionally remain account-wide." })
            F:AddProfileControls(menu)
            F:AddFooter(menu)
        end, 1000)
    end)
end
