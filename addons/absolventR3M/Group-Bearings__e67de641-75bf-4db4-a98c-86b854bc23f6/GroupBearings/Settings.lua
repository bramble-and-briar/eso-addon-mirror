-- Group Bearings: Settings > Add-Ons > Group Bearings (LibHarvensAddonSettings).
-- On console every section opens as its own sub-menu.

local GB = GroupBearings
local Settings = {}
GB.Settings = Settings

local TIPS = {
    enabled = "Turns everything in Group Bearings on or off.",
    preview = "Places test symbols and group members (with a crown) around you for 30 seconds so you can see the compass text, colours, arrows and beams. Close the menu to watch. You can also type /groupbearings preview in Text Chat.",
    markerDistances = "Shows how far away each marked symbol is, under its icon on the compass. Symbols on group members show all the time. A marked NPC shows while your crosshair is on it, and anything else you mark (including players outside your group) shows while you face it, because the game only shares those positions that way. When two symbols overlap, the closer one keeps the text.",
    groupDistances = "Shows each group member's distance under their pin on your compass. The pins are the game's own, left exactly as they are. When pins overlap, only the closest member's distance shows, and symbol distances always win.",
    memberBeams = "A column of light over each group member who has no symbol on them, so you can spot your group from far away. Members with a symbol get the symbol's beam instead (Symbols at your feet), and the leader gets the crown beam while that is on. Look and distances are set under Arrows and beams.",
    memberBeamColor = "Colour of the beams over group members. By role colours tanks blue, healers green and damage dealers red. Custom uses Custom member beam color below.",
    memberBeamCustomColor = "Your own beam colour for group members, used when Member beam color is set to Custom.",
    crownAsSymbol = "Shows the group leader's distance under the crown on your compass (the game's own crown stays). Also turns on the crown beam and arrow below. Nothing shows while you lead the group yourself.",
    crownBeam = "A column of light over the group leader, like Artaeum Group Tool's crown beam. Works on its own, without Symbols at your feet. Look and distances are set under Arrows and beams.",
    crownArrow = "An arrow at your feet pointing to the group leader, with the crown and its distance. Works on its own, without Symbols at your feet.",
    keepCrown = "The crown always stays visible on your compass: it draws over every compass marker it overlaps, such as symbols (a symbol on the leader too), quest and map pins, and other group members. Crown always on top does this too.",
    crownOnTop = "The crown wins every overlap, on the compass and at your feet, no matter how far away it is: it draws over every compass marker, its distance always shows, and arrows that would cover it step aside. Turning this on also tracks the crown.",
    crownColor = "Colour of the crown's beam and of its arrow at your feet. Game default is light blue. Custom uses Custom crown color below. The crown on your compass always keeps the game's look.",
    crownCustomColor = "Your own crown colour, used when Crown color is set to Custom.",
    pointers = "Shows an arrow at your feet for every marked symbol, pointing toward it, with the symbol and its distance. Works for marked group members all the time, and for a marked NPC while your crosshair is on it. The game may not draw these inside dungeons and trials.",
    pointerArrows = "The arrows on the ground for symbols. Turn off to keep only the symbol and distance markers.",
    beam = "Puts a column of light over each marked symbol so you can spot it from far away. For a marked NPC, the beam stays on the spot you last saw it for 10 seconds after your crosshair leaves it, fading out.",
    pointerSize = "Size of the arrows and the symbol and distance markers at your feet (symbols and crown).",
    pointerSpacing = "When arrows at your feet point in nearly the same direction, only the closest target's arrow shows (the crown's first with Crown always on top). Arrows closer together than this angle count as overlapping. Raise it if arrows still crowd each other. 0 shows every arrow.",
    beamTransparency = "0% is a solid beam. Higher values make beams fainter. Applies to every beam: symbols, the crown and group members.",
    beamMinDistance = "A beam only appears when its target is at least this far from you. 0 shows it at any distance.",
    beamMaxDistance = "A beam disappears when its target is farther than this. 0 means no limit.",
    beamThroughWalls = "Off: hills and walls hide the bottom of a beam while the top still shows over them. On: the whole beam shows through everything.",
    compassFov = "How many degrees the compass spans, used to line the distance text up under each symbol. Leave at 108 unless the text drifts away from symbols near the ends of the compass.",
    labelOffset = "Moves all distance text on the compass down (higher) or up (lower).",
    status = "Prints what Group Bearings sees right now in your chat window: every group member and their distance (or why they can't be tracked), the crown, tracked symbols and which features are on. Handy when something does not show. You can also type /groupbearings status.",
    accountWide = "Group Bearings saves its settings for your whole account, so every character uses the same ones. The game still switches add-ons on per character: to turn Group Bearings on for every character at once, open Add-Ons from the character select screen (before you log in), where All Characters is selected, and enable Group Bearings and LibHarvensAddonSettings there.",
}
Settings.TIPS = TIPS

function Settings.Initialize()
    local lib = LibHarvensAddonSettings
    if not (lib and lib.AddAddon and lib.ST_CHECKBOX and lib.ST_SLIDER and lib.ST_SECTION) then
        return false
    end
    local sv, D = GB.sv, GB.DEFAULTS
    local CHECKBOX, SLIDER, COLOR, SECTION = lib.ST_CHECKBOX, lib.ST_SLIDER, lib.ST_COLOR, lib.ST_SECTION
    local BUTTON, DROPDOWN, LABEL = lib.ST_BUTTON, lib.ST_DROPDOWN, lib.ST_LABEL

    local panel = lib:AddAddon(GB.DISPLAY_NAME, { allowDefaults = true, allowRefresh = true })
    panel.version = GB.VERSION
    panel.author = GB.AUTHOR

    local function Get(key)
        return function() return sv[key] end
    end
    local function Set(key, after)
        return function(value)
            sv[key] = value
            GB.Refresh()
            if after then after(value) end
        end
    end
    local function Tracked() return GB.IsCrownTracked() end
    local function Off() return not sv.enabled end
    local function MemberBeamsOff() return not (sv.enabled and sv.memberBeams) end
    local function MemberBeamCustomOff() return MemberBeamsOff() or sv.memberBeamColor ~= "Custom" end
    local function CrownOff() return not (sv.enabled and Tracked()) end
    local function CrownCustomOff() return CrownOff() or sv.crownColor ~= "Custom" end
    local function PointersOff() return not (sv.enabled and sv.pointers) end
    local function ArrowsOff() return not (sv.enabled and (sv.pointers or (Tracked() and sv.crownArrow))) end
    local function BeamsOff()
        return not (sv.enabled and ((sv.pointers and sv.beam) or (Tracked() and sv.crownBeam) or sv.memberBeams))
    end
    local function HintWhenOn(value) if value then GB.CrownHint() end end

    local function Checkbox(key, label, disable, after)
        return { type = CHECKBOX, label = label, tooltip = TIPS[key], default = D[key],
                 getFunction = Get(key), setFunction = Set(key, after), disable = disable }
    end
    local function Slider(key, label, min, max, step, unit, disable)
        return { type = SLIDER, label = label, tooltip = TIPS[key], default = D[key],
                 min = min, max = max, step = step, format = "%d", unit = unit,
                 getFunction = Get(key), setFunction = Set(key), disable = disable }
    end
    local function Button(label, buttonText, tip, handler, disable)
        if not BUTTON then return nil end
        return { type = BUTTON, label = label, buttonText = buttonText, tooltip = tip,
                 clickHandler = handler, disable = disable }
    end
    -- Colour choice list (the library calls the setter with control, name, item).
    local function ColorList(key, label, choices, disable)
        if not DROPDOWN then return nil end
        local items = {}
        for i, name in ipairs(choices) do items[i] = { name = name } end
        return {
            type = DROPDOWN, label = label, tooltip = TIPS[key], default = D[key], items = items,
            getFunction = function() return sv[key] end,
            setFunction = function(_, name)
                sv[key] = name
                GB.Refresh()
            end,
            disable = disable,
        }
    end
    local function ColorPicker(key, label, disable)
        if not COLOR then return nil end
        return {
            type = COLOR, label = label, tooltip = TIPS[key], default = D[key],
            getFunction = function()
                local c = sv[key]
                return c[1], c[2], c[3], c[4] or 1
            end,
            setFunction = function(r, g, b, a)
                sv[key] = { r, g, b, a or 1 }
                GB.Refresh()
            end,
            disable = disable,
        }
    end

    local settings = {}
    local function Add(s) if s then settings[#settings + 1] = s end end

    Add(Checkbox("enabled", "Group Bearings on"))
    Add(Button("Preview (30 seconds)", "Preview", TIPS.preview, function() GB.StartPreview() end, Off))

    Add({ type = SECTION, label = "Compass" })
    Add(Checkbox("markerDistances", "Distance under symbols", Off))

    Add({ type = SECTION, label = "Group members" })
    Add(Checkbox("groupDistances", "Group member distances", Off))
    Add(Checkbox("memberBeams", "Beam over group members", Off))
    Add(ColorList("memberBeamColor", "Member beam color", GB.MEMBER_BEAM_COLOR_CHOICES, MemberBeamsOff))
    Add(ColorPicker("memberBeamCustomColor", "Custom member beam color", MemberBeamCustomOff))

    Add({ type = SECTION, label = "Crown" })
    Add(Checkbox("crownAsSymbol", "Track the crown", Off, HintWhenOn))
    Add(Checkbox("crownBeam", "Beam over the crown", CrownOff))
    Add(Checkbox("crownArrow", "Arrow at your feet", CrownOff))
    Add(Checkbox("keepCrown", "Keep the crown when overlapping", Off, HintWhenOn))
    Add(Checkbox("crownOnTop", "Crown always on top", Off, HintWhenOn))
    Add(ColorList("crownColor", "Crown color", GB.CROWN_COLOR_CHOICES, CrownOff))
    Add(ColorPicker("crownCustomColor", "Custom crown color", CrownCustomOff))

    Add({ type = SECTION, label = "Symbols at your feet" })
    Add(Checkbox("pointers", "Show symbols at your feet", Off))
    Add(Checkbox("pointerArrows", "Arrows on the ground", PointersOff))
    Add(Checkbox("beam", "Light beam over symbols", PointersOff))

    Add({ type = SECTION, label = "Arrows and beams" })
    Add(Slider("pointerSize", "Arrow size", 50, 200, 10, "%", ArrowsOff))
    Add(Slider("pointerSpacing", "Arrow spacing", 0, 90, 5, " deg", ArrowsOff))
    Add(Slider("beamTransparency", "Beam transparency", 0, 90, 5, "%", BeamsOff))
    Add(Slider("beamMinDistance", "Beam shows beyond", 0, 200, 5, "m", BeamsOff))
    Add(Slider("beamMaxDistance", "Beam hides beyond (0 = never)", 0, 1000, 25, "m", BeamsOff))
    Add(Checkbox("beamThroughWalls", "Beam shows through walls", BeamsOff))

    Add({ type = SECTION, label = "Advanced" })
    Add(Slider("compassFov", "Compass width", 80, 140, 1, " deg", Off))
    Add(Slider("labelOffset", "Distance text height", -20, 40, 2, "px", Off))
    Add(Button("Show status in chat", "Show", TIPS.status, function() GB.PrintStatus() end))
    if LABEL then
        Add({ type = LABEL, label = "Settings are account-wide", tooltip = TIPS.accountWide })
    end

    panel:AddSettings(settings)
    Settings.panel = panel
    return true
end
