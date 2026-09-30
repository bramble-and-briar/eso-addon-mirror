local PBE = PacketByteExporter

local function QueueStatus()
    local queue = PBE.GetSettings().queue
    if not queue then
        return "No snapshot queued."
    end
    local attempted = math.min((queue.next or 1) - 1, queue.total or 0)
    return string.format(
        "%s (%s): %d/%d chunks attempted. Next chunk: %d.",
        queue.exportId,
        queue.profile,
        attempted,
        queue.total,
        queue.next or 1
    )
end

local function RegisterPanel()
    if not LibAddonMenu2 then
        PBE.Print("LibAddonMenu-2.0 is optional; install it for a controller-friendly settings panel.")
        return
    end

    local panelId = "PacketByteExporterPanel"
    LibAddonMenu2:RegisterAddonPanel(panelId, {
        type = "panel",
        name = "PacketByte Exporter",
        displayName = "PacketByte Exporter",
        author = "PacketByte",
        version = PBE.version,
        slashCommand = "/pbe_settings",
        registerForRefresh = true,
        registerForDefaults = false,
    })

    LibAddonMenu2:RegisterOptionControls(panelId, {
        {
            type = "description",
            text = "Capture live character data and submit it to your receiver in player-approved URL chunks.",
        },
        {
            type = "editbox",
            name = "Receiver address",
            tooltip = "Enter only the PC IP, such as 192.168.1.25. PacketByte adds the port and path. A full custom URL is also accepted.",
            getFunc = function()
                return PBE.GetSettings().endpoint or ""
            end,
            setFunc = function(value)
                local normalized, errorMessage = PBE.NormalizeEndpoint(value)
                if not normalized then
                    PBE.Print(errorMessage)
                    return
                end
                PBE.GetSettings().endpoint = normalized
                if normalized == "" then
                    PBE.Print("Receiver cleared.")
                else
                    PBE.Print("Receiver saved: " .. normalized)
                end
            end,
            isMultiline = false,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Include account display name",
            tooltip = "Off by default. Character name and character ID are always included.",
            getFunc = function()
                return PBE.GetSettings().includeAccountName == true
            end,
            setFunc = function(value)
                PBE.GetSettings().includeAccountName = value == true
            end,
            default = false,
            width = "full",
        },
        {
            type = "button",
            name = "Capture quick snapshot",
            tooltip = "Smaller everyday export: identity, attributes, stats, Mundus, equipped gear, bars, unspent skill points, spent Champion Points, and active companion. Omits the full skill list, crafting, quests, and extended account data.",
            func = function()
                PBE.Transport.Capture("quick")
            end,
            width = "half",
        },
        {
            type = "description",
            title = "Focused details",
            text = "Need more than the quick snapshot? Capture one complete category at a time. Each creates a separate export; it does not update an earlier snapshot.",
        },
        {
            type = "button",
            name = "Capture skills",
            tooltip = "All purchased skills, passives, morphs, and active scribing scripts. Separate export; approval count depends on your character.",
            func = function()
                PBE.Transport.Capture("skills")
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Capture crafting research",
            tooltip = "Complete current trait-research status for blacksmithing, clothing, woodworking, and jewelry. Separate export.",
            func = function()
                PBE.Transport.Capture("crafting")
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Capture quest journal",
            tooltip = "All quests currently in your journal. Separate export; not a history of completed quests.",
            func = function()
                PBE.Transport.Capture("quests")
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Capture full build snapshot",
            tooltip = "All purchased skills, points, bars, gear, stats, effects, crafting, currencies, riding, and quests. This can require many approvals.",
            func = function()
                PBE.Transport.Capture("build")
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Capture extended snapshot",
            tooltip = "Also scans backpack items, collectibles, achievements, and locked skills. Preparation can take time and produce many chunks.",
            func = function()
                PBE.Transport.Capture("all")
            end,
            width = "half",
            warning = "Extended capture can be large. Use the quick snapshot for routine checks.",
        },
        {
            type = "description",
            title = "Queue status",
            text = QueueStatus,
        },
        {
            type = "button",
            name = "Submit next chunk",
            tooltip = "Opens the next receiver URL through ESO's confirmation prompt.",
            func = function()
                PBE.Transport.SubmitNext()
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Retry last chunk",
            tooltip = "Resubmits the last attempted chunk. Duplicate chunks are safe.",
            func = function()
                PBE.Transport.RetryLast()
            end,
            width = "half",
        },
    })
end

EVENT_MANAGER:RegisterForEvent(PBE.name .. "Panel", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= PBE.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(PBE.name .. "Panel", EVENT_ADD_ON_LOADED)
    zo_callLater(RegisterPanel, 0)
end)
