-- Scrollkeeper Provision Member: Commands, LAM controls, and init

-- Local references
local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework
local SF_Set = Scrollkeeper.Settings

if type(SF) ~= "table" or type(SF_Set) ~= "table" then
  d(SF.func._L("ScrollkeeperProvisionMember", "ERROR_FRAMEWORK_MISSING"))
  return
end

-- Initialize module (shared with Core/UI files)
Scrollkeeper.ProvisionMember = Scrollkeeper.ProvisionMember or { Name = "ScrollkeeperProvisionMember", Version = "1" }
local _addon = Scrollkeeper.ProvisionMember

SF.ProvisionMember = SF.ProvisionMember or {}
local PM = SF.ProvisionMember
PM.Internal = PM.Internal or {}

-- Slash command and keybind registration
local function registerCommands()
  SLASH_COMMANDS["/sgtprovision"] = function()
  local settings = PM.Internal.getSettings()
  if not settings or not settings.enabled then
    d(SF.func._L("ScrollkeeperProvisionMember", "STATUS_DISABLED"))
    return
  end

  local window = GetControl("ScrollkeeperProvision_Window")
  if not window then
    window = PM.Internal.CreateWindow()
    if not window then
      d("[ScrollkeeperProvisionMember] ERROR: Failed to create provision window")
      return
    end
  end

  -- Simple toggle - OnShow handler will display the message
  window:SetHidden(not window:IsHidden())
end

  -- Debug command to check specific member's donations
  SLASH_COMMANDS["/sgtcheckpm"] = function(args)
    -- Expected format: GuildName|@DisplayName
    local parts = {}
    for part in string.gmatch(args, "[^|]+") do
      table.insert(parts, part)
    end

    if #parts < 2 then
      d("Usage: /sgtcheckpm GuildName|@DisplayName")
      d("Example: /sgtcheckpm Dragon's Nest Thievery Co|@YourName")
      return
    end

    local guildName = parts[1]
    local displayName = parts[2]

    -- Find guild ID
    local guildId = nil
    for i = 1, GetNumGuilds() do
      if GetGuildName(GetGuildId(i)) == guildName then
        guildId = GetGuildId(i)
        break
      end
    end

    if not guildId then
      d(string.format("Could not find guild: %s", guildName))
      return
    end

    local guildSettings = PM.Internal.getGuildSettings(guildName)
    if not guildSettings or not guildSettings.goldDonationFilter or not guildSettings.goldDonationFilter.enabled then
      d(string.format("Gold donation filter not enabled for %s", guildName))
      return
    end

    d("=== Checking " .. displayName .. " in " .. guildName .. " ===")
    d(string.format("Settings: %d gold required in last %d days",
      guildSettings.goldDonationFilter.requiredAmount,
      guildSettings.goldDonationFilter.timePeriodDays))

    -- This will trigger the debug output we added
    local meetsRequirement, totalDonated = PM.Internal.checkMemberDonations(
      guildId,
      guildName,
      displayName,
      guildSettings.goldDonationFilter.requiredAmount,
      guildSettings.goldDonationFilter.timePeriodDays,
      true  -- Enable debug output for manual command
    )

    d("=== End Check ===")
  end

  -- Test specific member inactivity
  SLASH_COMMANDS["/sgtcheckinactive"] = function(args)
    if not args or args == "" then
      d("[PM Debug] Usage: /sgtcheckinactive <guild index> <displayName>")
      d("[PM Debug] Example: /sgtcheckinactive 1 @YourName")
      d("[PM Debug] Your guilds:")
      for i = 1, GetNumGuilds() do
        local guildName = GetGuildName(GetGuildId(i))
        d(string.format("[PM Debug]   %d: %s", i, guildName))
      end
      return
    end

    -- Parse: "1 @DisplayName" or "2 @Name"
    local guildIndex, displayName = string.match(args, "^(%d+)%s+(@?.+)$")

    if not guildIndex or not displayName then
      d("[PM Debug] ERROR: Could not parse arguments")
      d("[PM Debug] Usage: /sgtcheckinactive <guild index> <displayName>")
      return
    end

    guildIndex = tonumber(guildIndex)
    if not guildIndex or guildIndex < 1 or guildIndex > GetNumGuilds() then
      d(string.format("[PM Debug] ERROR: Invalid guild index %s (you have %d guilds)",
        tostring(guildIndex), GetNumGuilds()))
      return
    end

    local guildId = GetGuildId(guildIndex)
    local guildName = GetGuildName(guildId)

    d("========================================")
    d(string.format("[PM Inactive Debug] Guild: %s", guildName))
    d(string.format("[PM Inactive Debug] Member: %s", displayName))
    d("========================================")

    local guildSettings = PM.Internal.getGuildSettings(guildName)
    if guildSettings and guildSettings.inactivityFilter and guildSettings.inactivityFilter.enabled then
      d(string.format("[PM Inactive Debug] Filter: ENABLED (threshold: %d days)",
        guildSettings.inactivityFilter.inactiveDays))
    else
      d("[PM Inactive Debug] Filter: DISABLED")
      d("[PM Inactive Debug] Using default threshold: 30 days")
    end

    local threshold = (guildSettings and guildSettings.inactivityFilter and
                      guildSettings.inactivityFilter.inactiveDays) or 30

    -- Check with debug enabled
    local isInactive, daysSince = PM.Internal.checkMemberInactivity(guildId, displayName, threshold, true)

    d("========================================")
    d(string.format("[PM Inactive Debug] Final Result: %s",
      isInactive and "INACTIVE (would be tracked)" or "ACTIVE (would be skipped)"))
    d("========================================")
  end

  -- Register keybind
  ZO_CreateStringId("SI_BINDING_NAME_SCROLLKEEPER_PROVISION", "Open Provisional Member Window")
end

-- 🎛️ Build enhanced controls with cascading per-guild settings and donation integration
local function buildControls()
  local settings = PM.Internal.getSettings()
  if not settings then
    return {{ type = "description", text = SF.func._L("ScrollkeeperProvisionMember", "ERROR_SETTINGS_UNAVAILABLE") }}
  end
  if not settings.guildSettings then
    settings.guildSettings = {}
  end

  if GetNumGuilds() == 0 then
    return {{
      type = "description",
      text = SF.func._L("ScrollkeeperProvisionMember", "ERROR_NO_GUILDS")
    }}
  end

  local controls = {
    {
      type = "submenu",
      name = SF.func._L("ScrollkeeperProvisionMember", "SUBMENU_NAME"),
      controls = {
        {
          type = "description",
          text = SF.func._L("ScrollkeeperProvisionMember", "DESCRIPTION")
        },
        {
          type    = "checkbox",
          name    = SF.func._L("ScrollkeeperProvisionMember", "MASTER_ENABLE"),
          tooltip = SF.func._L("ScrollkeeperProvisionMember", "MASTER_ENABLE_TIP"),
          getFunc = function() return settings.enabled end,
          setFunc = function(v)
            settings.enabled = v
            if v then
              _addon:EnableEvents()
              registerCommands()
            else
              _addon:DisableEvents()
            end
          end,
          default = PM.Internal.defaults.enabled,
        },
        {
          type = "button",
          name = SF.func._L("ScrollkeeperProvisionMember", "OPEN_ADMIN"),
          tooltip = SF.func._L("ScrollkeeperProvisionMember", "OPEN_ADMIN_TIP"),
          func = function()
            if SLASH_COMMANDS["/sgtprovision"] then
              SLASH_COMMANDS["/sgtprovision"]()
            end
          end,
          width = "half",
        },
        {
          type = "button",
          name = SF.func._L("ScrollkeeperProvisionMember", "CLEAR_SCAN"),
          tooltip = SF.func._L("ScrollkeeperProvisionMember", "CLEAR_SCAN_TIP"),
          func = function()
            PM.manualScan()
          end,
          width = "half",
        },
        {
          type = "button",
          name = SF.func._L("ScrollkeeperProvisionMember", "RESET_GOLD"),
          tooltip = SF.func._L("ScrollkeeperProvisionMember", "RESET_GOLD_TIP"),
          func = function()
            local count = PM.clearGoldProcessed()
            d(string.format(SF.func._L("ScrollkeeperProvisionMember", "SUCCESS_CLEARED_GOLD"), count))
          end,
          width = "half",
        },
        {
          type = "description",
          name = SF.func._L("ScrollkeeperProvisionMember", "MEMBER_COUNT_STATUS"),
          text = function()
            local count = 0
            if settings and settings.taggedMembers then
              for guildName, members in pairs(settings.taggedMembers) do
                if members and type(members) == "table" then
                  for memberName, data in pairs(members) do
                    if data and type(data) == "table" and data.status ~= SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROMOTED") then
                      count = count + 1
                    end
                  end
                end
              end
            end

            -- Count permanently removed members
            local rankRemoved = 0
            local goldRemoved = 0
            if settings and settings.processedMembers then
              for guildName, members in pairs(settings.processedMembers) do
                if members and type(members) == "table" then
                  for memberName, data in pairs(members) do
                    if type(data) == "table" then
                      if data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK") then
                        rankRemoved = rankRemoved + 1
                      elseif data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD") then
                        goldRemoved = goldRemoved + 1
                      end
                    else
                      rankRemoved = rankRemoved + 1 -- Legacy format
                    end
                  end
                end
              end
            end

            return string.format(SF.func._L("ScrollkeeperProvisionMember", "MEMBER_COUNT_FORMAT"),
              count, rankRemoved, goldRemoved)
          end,
        },
        {
          type = "header",
          name = SF.func._L("ScrollkeeperProvisionMember", "INTEGRATION_HEADER")
        },
        {
          type = "description",
          text = function()
            local statusText = SF.func._L("ScrollkeeperProvisionMember", "INTEGRATION_STATUS") .. "\n\n"

            -- AMT Status
            if PM.Internal.AMTAvailable then
              statusText = statusText .. "|c00FF00" .. SF.func._L("ScrollkeeperProvisionMember", "AMT_AVAILABLE") .. "|r\n"
            else
              statusText = statusText .. "|cFF0000" .. SF.func._L("ScrollkeeperProvisionMember", "AMT_UNAVAILABLE") .. "|r\n"
              statusText = statusText .. "   " .. SF.func._L("ScrollkeeperProvisionMember", "AMT_INSTALL") .. "\n"
              statusText = statusText .. "   " .. SF.func._L("ScrollkeeperProvisionMember", "AMT_DESC") .. "\n\n"
            end

            -- LibHistoire Status
            if LibHistoire then
              if PM.Internal.histoireReady then
                statusText = statusText .. "|c00FF00" .. SF.func._L("ScrollkeeperProvisionMember", "LH_READY") .. "|r\n\n"
              end
            else
              statusText = statusText .. "|cFF0000" .. SF.func._L("ScrollkeeperProvisionMember", "LH_MISSING") .. "|r\n\n"
            end

            -- Data Module Status
            if SF.Data then
              statusText = statusText .. "|c00FF00" .. SF.func._L("ScrollkeeperProvisionMember", "DATA_AVAILABLE") .. "|r\n\n"
            else
              statusText = statusText .. "|cFF0000" .. SF.func._L("ScrollkeeperProvisionMember", "DATA_UNAVAILABLE") .. "|r\n\n"
            end

            -- Symbol Legend
            statusText = statusText .. SF.func._L("ScrollkeeperProvisionMember", "SYMBOL_LEGEND") .. "\n"
            statusText = statusText .. "|c00FF00" .. SF.func._L("ScrollkeeperProvisionMember", "SYMBOL_AMT") .. "|r\n"
            statusText = statusText .. "|c88FF88" .. SF.func._L("ScrollkeeperProvisionMember", "SYMBOL_HISTOIRE") .. "|r\n"
            statusText = statusText .. "|cFFFF88" .. SF.func._L("ScrollkeeperProvisionMember", "SYMBOL_DONATION") .. "|r\n"
            statusText = statusText .. "|cFFAA88" .. SF.func._L("ScrollkeeperProvisionMember", "SYMBOL_TAGGED") .. "|r\n"
            statusText = statusText .. SF.func._L("ScrollkeeperProvisionMember", "SYMBOL_VALIDATED") .. "\n"
            statusText = statusText .. SF.func._L("ScrollkeeperProvisionMember", "SYMBOL_UNKNOWN") .. "\n\n"

            statusText = statusText .. SF.func._L("ScrollkeeperProvisionMember", "SYMBOL_FOOTER")

            return statusText
          end,
        },
      }
    }
  }

  -- Add per-guild settings
  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)

    if guildName and guildName ~= "" then
      local guildSubmenu = {
        type = "submenu",
        name = guildName,
        controls = {
          {
            type    = "checkbox",
            name    = string.format(SF.func._L("ScrollkeeperProvisionMember", "ENABLE_FOR_GUILD"), guildName),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "ENABLE_FOR_GUILD_TIP"),
            getFunc = function() return PM.Internal.getGuildSettings(guildName).enabled end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs then
                gs.enabled = v
                if not v then
                  -- Clear existing tracking when disabled
                  if settings and settings.taggedMembers then
                    settings.taggedMembers[guildName] = {}
                  end
                  if settings and settings.processedMembers then
                    settings.processedMembers[guildName] = {}
                  end
                  gs.autoTag = false
                  gs.notifyOnJoin = false
                  if gs.goldDonationFilter then gs.goldDonationFilter.enabled = false end
                  d(string.format(SF.func._L("ScrollkeeperProvisionMember", "SUCCESS_CLEARED_DATA"), guildName))
                end
              end
            end,
            default = true,
          },
          {
            type = "checkbox",
            name = SF.func._L("ScrollkeeperProvisionMember", "AUTO_TAG"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "AUTO_TAG_TIP"),
            getFunc = function() return PM.Internal.getGuildSettings(guildName).autoTag end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs then gs.autoTag = v end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled end,
            default = true,
          },
          {
            type    = "checkbox",
            name    = SF.func._L("ScrollkeeperProvisionMember", "NOTIFY_JOIN"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "NOTIFY_JOIN_TIP"),
            getFunc = function() return PM.Internal.getGuildSettings(guildName).notifyOnJoin end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs then gs.notifyOnJoin = v end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled end,
            default = true,
          },
          {
            type    = "slider",
            name    = SF.func._L("ScrollkeeperProvisionMember", "PROBATION_DAYS"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "PROBATION_DAYS_TIP"),
            min = 1, max = 90, step = 1,
            getFunc = function() return PM.Internal.getGuildSettings(guildName).trackingDays end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs then gs.trackingDays = v end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled end,
            default = 30,
          },
          {
            type = "header",
            name = SF.func._L("ScrollkeeperProvisionMember", "GOLD_HEADER"),
          },
          {
            type    = "checkbox",
            name    = SF.func._L("ScrollkeeperProvisionMember", "GOLD_ENABLE"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "GOLD_ENABLE_TIP"),
            getFunc = function() return PM.Internal.getGuildSettings(guildName).goldDonationFilter.enabled end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs and gs.goldDonationFilter then gs.goldDonationFilter.enabled = v end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled end,
            default = false,
          },
          {
            type    = "editbox",
            name    = SF.func._L("ScrollkeeperProvisionMember", "GOLD_AMOUNT"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "GOLD_AMOUNT_TIP"),
            getFunc = function() return tostring(PM.Internal.getGuildSettings(guildName).goldDonationFilter.requiredAmount) end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs and gs.goldDonationFilter then
                local amount = tonumber(v) or 5000
                gs.goldDonationFilter.requiredAmount = math.max(0, amount)
              end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled or not PM.Internal.getGuildSettings(guildName).goldDonationFilter.enabled end,
            default = "5000",
            width = "half",
          },
          {
            type    = "editbox",
            name    = SF.func._L("ScrollkeeperProvisionMember", "GOLD_PERIOD"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "GOLD_PERIOD_TIP"),
            getFunc = function() return tostring(PM.Internal.getGuildSettings(guildName).goldDonationFilter.timePeriodDays) end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs and gs.goldDonationFilter then
                local days = tonumber(v) or 30
                gs.goldDonationFilter.timePeriodDays = math.max(1, math.min(365, days))
              end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled or not PM.Internal.getGuildSettings(guildName).goldDonationFilter.enabled end,
            default = "30",
            width = "half",
          },
          {
            type = "header",
            name = SF.func._L("ScrollkeeperProvisionMember", "INACTIVITY_HEADER"),
          },
          {
            type    = "checkbox",
            name    = SF.func._L("ScrollkeeperProvisionMember", "INACTIVITY_ENABLE"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "INACTIVITY_ENABLE_TIP"),
            getFunc = function() return PM.Internal.getGuildSettings(guildName).inactivityFilter.enabled end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs and gs.inactivityFilter then gs.inactivityFilter.enabled = v end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled end,
            default = false,
          },
          {
            type    = "slider",
            name    = SF.func._L("ScrollkeeperProvisionMember", "INACTIVITY_DAYS"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "INACTIVITY_DAYS_TIP"),
            min = 7,
            max = 90,
            step = 1,
            getFunc = function() return PM.Internal.getGuildSettings(guildName).inactivityFilter.inactiveDays end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs and gs.inactivityFilter then gs.inactivityFilter.inactiveDays = v end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled or not PM.Internal.getGuildSettings(guildName).inactivityFilter.enabled end,
            default = 30,
          },
          {
            type = "header",
            name = SF.func._L("ScrollkeeperProvisionMember", "DONOR_HEADER"),
          },
          {
            type    = "checkbox",
            name    = SF.func._L("ScrollkeeperProvisionMember", "DONOR_ENABLE"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "DONOR_ENABLE_TIP"),
            getFunc = function() return PM.Internal.getGuildSettings(guildName).donorFilter.enabled end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs and gs.donorFilter then gs.donorFilter.enabled = v end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled end,
            default = false,
          },
          {
            type    = "editbox",
            name    = SF.func._L("ScrollkeeperProvisionMember", "DONOR_AMOUNT"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "DONOR_AMOUNT_TIP"),
            getFunc = function() return tostring(PM.Internal.getGuildSettings(guildName).donorFilter.minimumAmount) end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs and gs.donorFilter then
                local amount = tonumber(v) or 1000
                gs.donorFilter.minimumAmount = math.max(0, amount)
              end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled or not PM.Internal.getGuildSettings(guildName).donorFilter.enabled end,
            default = "1000",
            width = "half",
          },
          {
            type    = "editbox",
            name    = SF.func._L("ScrollkeeperProvisionMember", "DONOR_PERIOD"),
            tooltip = SF.func._L("ScrollkeeperProvisionMember", "DONOR_PERIOD_TIP"),
            getFunc = function() return tostring(PM.Internal.getGuildSettings(guildName).donorFilter.timePeriodDays) end,
            setFunc = function(v)
              local gs = PM.Internal.getGuildSettings(guildName)
              if gs and gs.donorFilter then
                local days = tonumber(v) or 30
                gs.donorFilter.timePeriodDays = math.max(1, math.min(365, days))
              end
            end,
            disabled = function() return not PM.Internal.getGuildSettings(guildName).enabled or not PM.Internal.getGuildSettings(guildName).donorFilter.enabled end,
            default = "30",
            width = "half",
          },
          {
            type = "description",
            name = SF.func._L("ScrollkeeperProvisionMember", "GUILD_STATS"),
            text = function()
              local report = PM.getProvisionalReport(guildName)
              if report.totalTracked == 0 then
                return SF.func._L("ScrollkeeperProvisionMember", "NO_MEMBERS")
              end
              local statusText = string.format(SF.func._L("ScrollkeeperProvisionMember", "STATS_FORMAT"),
                report.totalTracked, report.withinProbation, report.overdue, report.promoted)

              if #report.recent > 0 then
                statusText = statusText .. "\n" .. string.format(SF.func._L("ScrollkeeperProvisionMember", "RECENT_ADDITIONS"), #report.recent)
              end

              return statusText
            end,
          },
        }
      }

      table.insert(controls[1].controls, guildSubmenu)
    end
  end

  return controls
end

-- 🚀 Initialize
local function initialize()
  if _addon._initialized then
    return
  end

  -- Check framework availability
  if not SF_Set or not SF_Set.RegisterModuleOptions then
    d(SF.func._L("ScrollkeeperProvisionMember", "ERROR_FRAMEWORK_MISSING"))
    return
  end

  -- Single consolidated startup message with all integration info
  local integrations = {}

  -- Check AMT once at startup
  if AMT and AMT.savedData and AMT.GetAmountDonated then
    PM.Internal.AMTAvailable = true
    table.insert(integrations, "AMT: yes")
  else
    table.insert(integrations, "AMT: no")
  end

  -- Check LibHistoire
  if LibHistoire then
    if PM.Internal.histoireReady then
      table.insert(integrations, "LH: yes")
    end
  else
    table.insert(integrations, "LH: no")
  end

  -- Check Data module
  if SF.Data then
    table.insert(integrations, "Data: yes")
  else
    table.insert(integrations, "Data: no")
  end

  d(string.format(SF.func._L("ScrollkeeperProvisionMember", "LOG_INITIALIZING"), table.concat(integrations, " ")))

  -- Register controls
  local controls = buildControls()
  if controls then
    SF_Set.RegisterModuleOptions(_addon.Name, controls)
  end

  -- Register commands
  registerCommands()

  -- Enable event handlers (for real-time join detection only)
  local settings = PM.Internal.getSettings()
  if settings and settings.enabled then
    _addon:EnableEvents()
  end

  _addon._initialized = true
end

-- Register for proper initialization
EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED, function(_, initial)
  if not initial then return end
  EVENT_MANAGER:UnregisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED)

  zo_callLater(function()
    initialize()
  end, 1000)
end)

-- Register callback
CALLBACK_MANAGER:RegisterCallback("Scrollkeeper_Initialized", function()
  if not _addon._initialized then
    initialize()
  end
end)