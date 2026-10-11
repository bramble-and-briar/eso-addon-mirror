-- CallToArm_UI.lua (LHAS main menu)
local CallToArm = _G.CallToArm or {}
_G.CallToArm = CallToArm
CallToArm.UI = CallToArm.UI or {}

local UI = CallToArm.UI
local LHAS = LibHarvensAddonSettings

UI._initDone = UI._initDone or false
UI._built = UI._built or { main = false }

--------------------------------------------------------------
-- Center message helper
--------------------------------------------------------------
function UI.ShowCenter(msg, durationSeconds)
    local text = tostring(msg)
    local sound = (SOUNDS and SOUNDS.ACHIEVEMENT_AWARDED) or nil

    if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams and CENTER_SCREEN_ANNOUNCE.DisplayMessage and sound then
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound)
        if params.SetLifespanMS and durationSeconds then
            params:SetLifespanMS(tonumber(durationSeconds) * 1000)
        end
        params:SetText(text)
        CENTER_SCREEN_ANNOUNCE:DisplayMessage(params)
        return
    end

    if ZO_Alert and UI_ALERT_CATEGORY_ALERT and sound then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound, text)
        return
    end

    d(text)
end

--------------------------------------------------------------
-- Helpers
--------------------------------------------------------------
local function BuildGuildItems()
    local items = {}
    for i = 1, GetNumGuilds() do
        local gid = GetGuildId(i)
        if gid and gid ~= 0 then
            items[#items + 1] = { name = GetGuildName(gid), data = gid }
        end
    end
    table.sort(items, function(a, b) return (a.name or "") < (b.name or "") end)
    return items
end

local function BuildCampaignItems()
    local items = {}
    items[#items + 1] = { name = "(none)", data = 0 }

    if GetNumSelectionCampaigns and GetSelectionCampaignId and GetCampaignName then
        for i = 1, GetNumSelectionCampaigns() do
            local campaignId = GetSelectionCampaignId(i)
            if campaignId and campaignId ~= 0 then
                items[#items + 1] = { name = GetCampaignName(campaignId), data = campaignId }
            end
        end
    end

    local gid = CallToArm.Guild.GetSelectedGuildId()
    if gid and gid ~= 0 then
        local savedId = CallToArm.Guild.GetHomeCampaignId(gid)
        if savedId and savedId ~= 0 then
            local found = false
            for i = 1, #items do
                if items[i].data == savedId then
                    found = true
                    break
                end
            end
            if not found then
                local name = GetCampaignName and GetCampaignName(savedId) or ("Campaign " .. tostring(savedId))
                items[#items + 1] = { name = name .. " (saved)", data = savedId }
            end
        end
    end

    table.sort(items, function(a, b) return (a.name or "") < (b.name or "") end)
    return items
end

local function ActiveGuildId()
    return CallToArm.Guild.GetSelectedGuildId()
end

local function IsLockEnabled()
    local lock = CallToArm.Guild and CallToArm.Guild.GetLockState and CallToArm.Guild.GetLockState()
    return lock and lock.enabled == true
end

local function IsLockArming()
    return CallToArm.Guild and CallToArm.Guild.IsLockArming and CallToArm.Guild.IsLockArming() == true
end

local function IsHardLocked()
    return CallToArm.Guild and CallToArm.Guild.IsLocked and CallToArm.Guild.IsLocked() == true
end

local function GetScopeGuildId()
    local lockActive = CallToArm.Guild.IsLockActive and CallToArm.Guild.IsLockActive() == true
    local gid = lockActive and CallToArm.Guild.GetLockedGuildId and CallToArm.Guild.GetLockedGuildId() or 0
    if gid == 0 then
        gid = ActiveGuildId()
    end
    return gid
end

local function IsConfiguredForSettings()
    -- The campaign lock protects identity only (guild + campaign).  All other
    -- preferences must remain editable before, during and after a campaign.
    return GetScopeGuildId() ~= 0
end

local function GetAutoDetectedCampaignId()
    if CallToArm.Guild and CallToArm.Guild.FindDefaultHomeCampaignId then
        return tonumber(CallToArm.Guild.FindDefaultHomeCampaignId()) or 0
    end
    return 0
end

local function GetAutoDetectedCampaignName()
    local cid = GetAutoDetectedCampaignId()
    if cid == 0 then return "(none detected)" end
    return (GetCampaignName and GetCampaignName(cid)) or ("Campaign " .. tostring(cid))
end

local function GuildSelectTooltip()
    return "Selects the guild context for CallToArm lock-in and all related options."
end

local function CampaignSelectTooltip()
    return "Choose from all available campaigns. Auto-detected home campaign: " .. GetAutoDetectedCampaignName()
end

local function HighlightTooltip()
    local gid = GetScopeGuildId()
    local guildName = gid ~= 0 and GetGuildName(gid) or "your guild"
    local campaignId = gid ~= 0 and CallToArm.Guild.GetHomeCampaignId(gid) or 0
    local campaignName = campaignId ~= 0 and (GetCampaignName(campaignId) or "your campaign") or "your campaign"
    return string.format("After leaving CallToArm, names from %s will be highlighted on leaderboards matching %s.", guildName, campaignName)
end

local function FormatDuration(seconds)
    local total = math.max(0, tonumber(seconds) or 0)
    local mins = math.floor(total / 60)
    local secs = total % 60
    return string.format("%dm %02ds", mins, secs)
end

local function GetLockStatusText()
    if CallToArm.Guild and CallToArm.Guild.UpdateLockState then
        CallToArm.Guild.UpdateLockState()
    end

    local lock = CallToArm.Guild and CallToArm.Guild.GetLockState and CallToArm.Guild.GetLockState()
    if not lock or lock.enabled ~= true then
        return "|cff5555LOCK: OFF|r\n|caaaaaaPick guild + campaign, then arm lock-in.|r"
    end

    local now = GetTimeStamp and GetTimeStamp() or 0
    local gid = tonumber(lock.guildId) or 0
    local cid = tonumber(lock.campaignId) or 0
    local gname = (gid ~= 0 and GetGuildName(gid)) or "(none)"
    local cname = (cid ~= 0 and GetCampaignName and GetCampaignName(cid)) or ("Campaign " .. tostring(cid))

    if (tonumber(lock.armingUntil) or 0) > now then
        local left = (tonumber(lock.armingUntil) or 0) - now
        return string.format("|cFFD700LOCK ARMING|r\n|c88ccffGuild:|r %s\n|c88ccffCampaign:|r %s\n|cff5555Auto-lock in: %s|r", tostring(gname), tostring(cname), FormatDuration(left))
    end

    if (tonumber(lock.lockedUntil) or 0) > now then
        local left = (tonumber(lock.lockedUntil) or 0) - now
        return string.format("|c00ff00LOCKED UNTIL CAMPAIGN END|r\n|c88ccffGuild:|r %s\n|c88ccffCampaign:|r %s\n|cff5555Unlocks in: %s|r", tostring(gname), tostring(cname), FormatDuration(left))
    end

    return "|cff5555LOCK: OFF|r"
end

local function GetScopeCtaSettings()
    local gid = GetScopeGuildId()
    if gid == 0 then return nil end
    if CallToArm.CTA and CallToArm.CTA.GetGuildSettings then
        return CallToArm.CTA.GetGuildSettings(gid)
    end
    return nil
end

--------------------------------------------------------------
-- Main menu
--------------------------------------------------------------
local function CreateMainMenu()
    if UI._built.main then return end

    local settings = LHAS:AddAddon("CallToArm", {
        allowDefaults = true,
        allowRefresh = true,
        -- Reset the saved-variable tree as one operation.  Letting LHAS reset
        -- controls individually makes some console builds index the dynamic
        -- campaign-dropdown item provider as if it were a table.
        defaultsFunction = function()
            if CallToArm.ResetSavedVars then
                CallToArm.ResetSavedVars()
            end
        end,
    })
    if not settings then return end

    UI._built.main = true
    UI.menu = settings
    settings.onRefresh = nil

    settings:AddSetting({
        type = LHAS.ST_LABEL,
        label = "|c88ccffCallToArm|r by SugaComa",
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Lock In" })
    settings:AddSetting({
        type = LHAS.ST_LABEL,
        label = "Lock Status",
        tooltip = GetLockStatusText,
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Select Guild",
        tooltip = GuildSelectTooltip,
        items = BuildGuildItems(),
        getFunction = function()
            local gid = ActiveGuildId()
            if gid ~= 0 then return GetGuildName(gid) end
            return "(none)"
        end,
        setFunction = function(combobox, name, item)
            if item and item.data and (not IsHardLocked()) then
                CallToArm.Guild.SetSelectedGuildId(item.data)
                CallToArm.Guild.RefreshSelectedGuildAllianceCache()
                if UI.menu and UI.menu.RefreshSettings then UI.menu:RefreshSettings() end
            end
        end,
        disable = function() return IsHardLocked() end,
    })

    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Auto Detect Home Campaign",
        tooltip = "Detected campaign: " .. GetAutoDetectedCampaignName(),
        buttonText = "Detect",
        clickHandler = function()
            if IsHardLocked() then return end
            local gid = ActiveGuildId()
            if gid == 0 then UI.ShowCenter("CALLTOARM: Select a guild first.") return end
            local cid = GetAutoDetectedCampaignId()
            if cid == 0 then UI.ShowCenter("CALLTOARM: Could not detect a campaign.") return end
            CallToArm.Guild.SetHomeCampaignId(gid, cid)
            UI.ShowCenter("CALLTOARM: Home campaign detected.")
            if UI.menu and UI.menu.RefreshSettings then UI.menu:RefreshSettings() end
        end,
        disable = function() return IsHardLocked() end,
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Select Home Campaign",
        tooltip = CampaignSelectTooltip,
        items = BuildCampaignItems,
        -- The custom panel reset above owns this value.  This also protects
        -- newer LHAS builds that support selective default-reset exclusion.
        ignoreDefault = true,
        getFunction = function()
            local gid = ActiveGuildId()
            if gid == 0 then return "(none)" end
            local cid = CallToArm.Guild.GetHomeCampaignId(gid) or 0
            if cid == 0 then return "(none)" end
            return GetCampaignName(cid) or "(unknown campaign)"
        end,
        setFunction = function(combobox, name, item)
            if item and item.data ~= nil and (not IsHardLocked()) then
                local gid = ActiveGuildId()
                if gid ~= 0 then CallToArm.Guild.SetHomeCampaignId(gid, item.data) end
            end
        end,
        disable = function() return IsHardLocked() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Arm Lock-In (5 min)",
        tooltip = "Arms lock-in countdown. Use Confirm Lock-In below to lock immediately.",
        default = false,
        getFunction = function() return IsLockEnabled() end,
        setFunction = function(state)
            if state ~= true then
                return
            end

            local gid = ActiveGuildId()
            if gid == 0 then UI.ShowCenter("CALLTOARM: Select a guild first.") return end
            local cid = CallToArm.Guild.GetHomeCampaignId(gid)
            if not cid or cid == 0 then UI.ShowCenter("CALLTOARM: Select a home campaign first.") return end

            CallToArm.Guild.StartLockArming(gid, cid, 300)
            if CallToArm.CTA and CallToArm.CTA.SetRepresentedGuild then CallToArm.CTA.SetRepresentedGuild(gid) end
            UI.ShowCenter("CALLTOARM: Lock arming started (5 minutes).")
            if UI.menu and UI.menu.RefreshSettings then UI.menu:RefreshSettings() end
        end,
        disable = function() return IsHardLocked() end,
    })

    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Confirm Lock-In Now",
        tooltip = "Final step: hard lock now. Cannot be undone until campaign end.",
        buttonText = "Confirm",
        clickHandler = function()
            local lock = CallToArm.Guild.GetLockState and CallToArm.Guild.GetLockState() or nil
            if not lock or lock.enabled ~= true then
                UI.ShowCenter("CALLTOARM: Arm lock-in first.")
                return
            end
            if CallToArm.Guild.ConfirmLockNow and CallToArm.Guild.ConfirmLockNow(lock.guildId, lock.campaignId) then
                UI.ShowCenter("CALLTOARM: Lock confirmed until campaign end.")
            else
                UI.ShowCenter("CALLTOARM: Lock confirm failed.")
            end
            if UI.menu and UI.menu.RefreshSettings then UI.menu:RefreshSettings() end
        end,
        disable = function() return not IsLockEnabled() or IsHardLocked() end,
    })

    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Cancel Pending Lock",
        tooltip = "Cancels arming only. Disabled after hard lock is active.",
        buttonText = "Cancel",
        clickHandler = function()
            if IsHardLocked() then
                UI.ShowCenter("CALLTOARM: Already hard-locked until campaign end.")
                return
            end
            if IsLockEnabled() then
                CallToArm.Guild.CancelLock()
                if CallToArm.CTA and CallToArm.CTA.SetRepresentedGuild then CallToArm.CTA.SetRepresentedGuild(0) end
                UI.ShowCenter("CALLTOARM: Pending lock cancelled.")
                if UI.menu and UI.menu.RefreshSettings then UI.menu:RefreshSettings() end
            end
        end,
        disable = function() return (not IsLockArming()) end,
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Main Settings" })
    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Highlight Guildies",
        tooltip = HighlightTooltip,
        default = true,
        getFunction = function() return CallToArm.SV.ui.highlightGuildies == true end,
        setFunction = function(state) CallToArm.SV.ui.highlightGuildies = (state == true) end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Show Guild Leaderboard In Journal",
        tooltip = "Adds a Guild Leaderboard entry to Journal > Leaderboards > Campaign.",
        default = true,
        getFunction = function() return CallToArm.SV.ui.guildLeaderboardEnabled == true end,
        setFunction = function(state) CallToArm.SV.ui.guildLeaderboardEnabled = (state == true) end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Open Journal Leaderboards",
        tooltip = "Opens Journal > Leaderboards > Campaign.",
        buttonText = "Open",
        clickHandler = function()
            if SCENE_MANAGER and SCENE_MANAGER.Show then SCENE_MANAGER:Show("gamepad_leaderboards") end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "CTA" })
    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Campaign Briefing: Run Now",
        tooltip = "Requests a briefing for your represented guild's campaign. Does not change automatic alerts, activity filters or lock-in.",
        buttonText = "Run Now",
        clickHandler = function() CallToArm.CTA.RunNow() end,
    })
    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Automatic Campaign Check Interval",
        tooltip = "Time between automatic checks. Population reminder interval is separate.",
        items = { {name="15 minutes",data=900}, {name="30 minutes",data=1800}, {name="60 minutes",data=3600} },
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return tostring(math.floor((cta and cta.polling.intervalSeconds or 1800) / 60)) .. " minutes"
        end,
        setFunction = function(_, _, item)
            local cta = GetScopeCtaSettings()
            if cta and item then cta.polling.intervalSeconds = item.data; CallToArm.CTA._nextPollAt = GetTimeStamp() + item.data end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Campaign Alerts on Zone Change",
        tooltip = "Also check Emperor Push, Throne Defense, War Begins and War Rages after changing zones. Alert Filters 1-5 and normal cooldowns still apply.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.polling and cta.polling.onZoneChange == true
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.polling then cta.polling.onZoneChange = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable CTA Alerts",
        tooltip = "CTA is bound to the lock scope guild and campaign.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.enabled == true
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta then cta.enabled = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "CTA Alerts: Emperor Push",
        tooltip = "Alert when your alliance owns 4 emperor keeps and leaderboard rank 1 is a guild member.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.alerts and cta.alerts.empPush == true
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.alerts then cta.alerts.empPush = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "CTA Alerts: Throne Defense",
        tooltip = "Alert when emperor keep threshold is reached.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.alerts and cta.alerts.dethrone == true
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.alerts then cta.alerts.dethrone = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "CTA Alerts: War Begins",
        tooltip = "Alert when any alliance population rises from empty to low.",
        default = false,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.alerts and cta.alerts.warBegins == true
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.alerts then cta.alerts.warBegins = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "CTA Alerts: War Rages",
        tooltip = "Alert when at least two alliances reach medium population or higher.",
        default = false,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.alerts and cta.alerts.warRages == true
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.alerts then cta.alerts.warRages = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_EDIT,
        label = "CTA Popup Seconds",
        tooltip = "How long CTA popups stay visible in seconds. Min 2, max 30.",
        default = "6",
        getFunction = function()
            local cta = GetScopeCtaSettings()
            local v = cta and cta.display and tonumber(cta.display.popupSeconds) or 6
            return tostring(v)
        end,
        setFunction = function(value)
            local cta = GetScopeCtaSettings()
            if not cta then return end
            local v = tonumber(value) or 6
            if v < 2 then v = 2 end
            if v > 30 then v = 30 end
            cta.display = cta.display or {}
            cta.display.popupSeconds = v
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Throne Defense Threshold",
        tooltip = "Trigger when emperor keeps owned drop to this value.",
        items = {
            { name = "3 keeps", data = 3 },
            { name = "2 keeps", data = 2 },
            { name = "1 keep", data = 1 },
        },
        getFunction = function()
            local cta = GetScopeCtaSettings()
            local v = cta and cta.rules and tonumber(cta.rules.dethroneKeepThreshold) or 3
            if v == 1 then return "1 keep" end
            if v == 2 then return "2 keeps" end
            return "3 keeps"
        end,
        setFunction = function(combobox, name, item)
            local cta = GetScopeCtaSettings()
            if cta and cta.rules and item then
                cta.rules.dethroneKeepThreshold = tonumber(item.data) or 3
            end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "CTA Alerts: Campaign Population",
        tooltip = "Scales urgency from campaign population and alerts at login + interval.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.alerts and cta.alerts.population == true
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.alerts then
                cta.alerts.population = (state == true)
            end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Population Alert Interval",
        tooltip = "How often to repeat population updates while conditions change.",
        items = {
            { name = "15 minutes", data = 900 },
            { name = "30 minutes", data = 1800 },
            { name = "60 minutes", data = 3600 },
        },
        getFunction = function()
            local cta = GetScopeCtaSettings()
            local v = cta and cta.population and tonumber(cta.population.intervalSeconds) or 1800
            if v <= 900 then return "15 minutes" end
            if v >= 3600 then return "60 minutes" end
            return "30 minutes"
        end,
        setFunction = function(combobox, name, item)
            local cta = GetScopeCtaSettings()
            if cta and cta.population and item then
                cta.population.intervalSeconds = tonumber(item.data) or 1800
            end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Population Alerts on Zone Change",
        tooltip = "Also check the Campaign Population alert after changing zones. Alert Filters 1-5, the population interval and normal alert conditions still apply.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.population and cta.population.onZoneChange == true
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.population then cta.population.onZoneChange = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_LABEL,
        label = "|c88ccffAlert Filters (1-5)|r",
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "1: Overland (incl. delves/public dungeons)",
        tooltip = "Allow CTA alerts while in open world zones, delves, and public dungeons.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.activity and cta.activity.overland ~= false
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.activity then cta.activity.overland = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "2: Group Dungeons",
        tooltip = "Allow CTA alerts while inside 4-player dungeon content.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.activity and cta.activity.groupDungeons ~= false
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.activity then cta.activity.groupDungeons = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "3: Trials",
        tooltip = "Allow CTA alerts while inside trial instances.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.activity and cta.activity.trials ~= false
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.activity then cta.activity.trials = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "4: Arenas and Infinite Archive",
        tooltip = "Allow CTA alerts in arenas (solo/group) and Infinite Archive.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.activity and cta.activity.arenasArchive ~= false
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.activity then cta.activity.arenasArchive = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "5: PvP (BG/IC/non-home campaign)",
        tooltip = "Allow CTA alerts in Battlegrounds, Imperial City, and campaigns other than your locked home campaign.",
        default = true,
        getFunction = function()
            local cta = GetScopeCtaSettings()
            return cta and cta.activity and cta.activity.pvpOther ~= false
        end,
        setFunction = function(state)
            local cta = GetScopeCtaSettings()
            if cta and cta.activity then cta.activity.pvpOther = (state == true) end
        end,
        disable = function() return not IsConfiguredForSettings() end,
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Debug" })
    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable Debug",
        default = false,
        getFunction = function() return CallToArm.SV.debug == true end,
        setFunction = function(state)
            CallToArm.SV.debug = (state == true)
            if UI.menu and UI.menu.RefreshSettings then UI.menu:RefreshSettings() end
        end,
    })

    settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Clear Lock",
        tooltip = "Clears any active/pending locks",
        buttonText = "Clear",
        clickHandler = function()
            CallToArm.Guild.CancelLock()
            if CallToArm.CTA and CallToArm.CTA.SetRepresentedGuild then CallToArm.CTA.SetRepresentedGuild(0) end
            UI.ShowCenter("CALLTOARM DEV: Lock cleared.")
            if UI.menu and UI.menu.RefreshSettings then UI.menu:RefreshSettings() end
        end,
        disable = function() return CallToArm.SV.debug ~= true end,
    })
    ----------------------------------------------------------
    -- Signature
    ----------------------------------------------------------
    settings:AddSetting({
        type = LHAS.ST_SECTION,
        subMenu = false,
        label = "|cFFD700Built on tea, toast and ADHD, tested live on PS5.|r\n" ..
                "|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r",
    })
end
--------------------------------------------------------------
-- Init
--------------------------------------------------------------
function UI.Init()
    if UI._initDone then
        if UI.menu and UI.menu.RefreshSettings then UI.menu:RefreshSettings() end
        return
    end
    UI._initDone = true

    if not LHAS then
        d("CallToArm: LibHarvensAddonSettings not found.")
        return
    end

    CreateMainMenu()

    if EM and EM.RegisterForUpdate then
        EM:RegisterForUpdate("CALLTOARM_UI_LOCK_REFRESH", 1000, function()
            if CallToArm.Guild and CallToArm.Guild.UpdateLockState then
                CallToArm.Guild.UpdateLockState()
            end
        end)
    end
end

