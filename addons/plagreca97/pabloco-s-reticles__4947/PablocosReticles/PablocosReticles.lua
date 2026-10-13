local ADDON = "PablocosReticles"
local TITLE = "pabloco's reticles"
local VERSION = "1.0.0"
PablocosReticles = PablocosReticles or {}
PablocosReticles.name = ADDON

local SV_NAME = "PablocosReticlesSavedVars"
local defaults = {
    enabled = true,
    reticle = "dragonknight",
    colorway = "classic",
    scale = 100,        -- percent
    opacity = 100,      -- percent; fades the whole reticle
    offsetX = 0,        -- px, + right
    offsetY = 0,        -- px, + down
    hideStock = true,
    animate = true,
    flipRot = false,    -- flip the direction every rotation turns, if pieces spin the wrong way
    padAttackPulse = true, -- gamepad: play the left-click animation as a short pulse on each light or heavy attack
}

local acctSv, charSv, sv    -- sv is whichever of the two is in use
local root
local sets = {}               -- reticle id -> its built parts, created once and reused on a switch back
local active                  -- parts of the active reticle
local current                 -- the active reticle definition
local panel
-- pl / pr: 0 rest .. 1 fully in the left / right state; tl / tr: where each is heading
local pl, pr, tl, tr = 0, 0, 0, 0
local debugMouse = false
local colorway   -- the active colourway definition

local function Hex(h)
    return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

-- Colourways ------------------------------------------------------------------------------------------------------
local function ToHSL(r, g, b)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local l, h, sat = (mx + mn) / 2, 0, 0
    local c = mx - mn
    if c > 0 then
        sat = c / (1 - math.abs(2 * l - 1))
        if mx == r then h = ((g - b) / c) % 6
        elseif mx == g then h = (b - r) / c + 2
        else h = (r - g) / c + 4 end
        h = h * 60
    end
    return h, sat, l, c
end

local function FromHSL(h, sat, l)
    local c = (1 - math.abs(2 * l - 1)) * sat
    local hp = (h % 360) / 60
    local x = c * (1 - math.abs(hp % 2 - 1))
    local r, g, b = 0, 0, 0
    if hp < 1 then r, g = c, x elseif hp < 2 then r, g = x, c elseif hp < 3 then g, b = c, x
    elseif hp < 4 then g, b = x, c elseif hp < 5 then r, b = x, c else r, b = c, x end
    local m = l - c / 2
    return r + m, g + m, b + m
end

-- Moves a colour to the active colourway. Neutral whites and near-black outlines never change.
local function Recolor(r, g, b)
    if not colorway or colorway.id == "classic" or (current and current.fixedColors) then return r, g, b end
    local h, sat, l, c = ToHSL(r, g, b)
    if c < 0.04 then
        -- a neutral white: normally left alone, but a design that asks for it (the Plain Dot) becomes the colourway colour
        if current and current.recolorNeutral and not colorway.white then return FromHSL(colorway.hue, 0.9, 0.62) end
        return r, g, b
    end
    if l < 0.12 then return r, g, b end
    if colorway.white then return FromHSL(h, sat * 0.08, math.min(1, l + 0.1)) end
    local base = (current and current.baseHue) or h
    local d = h - base
    if d > 180 then d = d - 360 elseif d < -180 then d = d + 360 end
    return FromHSL(colorway.hue + ((current and current.hueSpread) or 0.4) * d, sat, l)
end

local EASE = {
    linear = function(t) return t end,
    ["in"] = function(t) return t * t end,
    out = function(t) return 1 - (1 - t) * (1 - t) end,
    inout = function(t) if t < 0.5 then return 2 * t * t end return 1 - (2 - 2 * t) * (2 - 2 * t) / 2 end,
    sinein = function(t) return 1 - math.cos(t * math.pi / 2) end,
}

local function Ease(name, t) return (EASE[name] or EASE.linear)(t) end

local function Tex(name) return ADDON .. "/tex/" .. name .. ".dds" end

local function Val(v, s)
    if type(v) == "function" then return v(s) end
    return v
end

-- Stock reticle -----------------------------------------------------------------------------------------------------
-- ESO re-shows the reticle on target changes, so SetHidden is shadowed on the control (the trick Dryzler's Reticle uses).
local function ApplyStockReticle()
    local stock = ZO_ReticleContainerReticle
    if not stock then return end
    stock.SetHidden = nil
    if sv.enabled and sv.hideStock then
        stock:SetHidden(true)
        stock.SetHidden = function() end
    else
        stock:SetHidden(false)
    end
end

-- Drawing -----------------------------------------------------------------------------------------------------------
local function State()
    return {
        l = Ease(current.left.ease, pl),
        r = Ease(current.right.ease, pr),
        t = GetGameTimeMilliseconds() / 1000,
    }
end

local function RenderPart(P, s, rotSign, opacity)
    local d, c = P.def, P.control
    local a = Val(d.alpha, s)
    if a == nil then a = 1 end
    a = a * opacity
    if a <= 0.004 then
        if not P.hidden then c:SetHidden(true); P.hidden = true end
        return
    end
    if P.hidden then c:SetHidden(false); P.hidden = false end
    local w, h
    if d.size then
        w = Val(d.size, s); h = w
    else
        w = Val(d.w, s) or P.base[1]
        h = Val(d.h, s) or P.base[2]
    end
    local sc = Val(d.scale, s) or 1
    c:SetDimensions(w * sc, h * sc)
    if d.x or d.y then
        c:ClearAnchors()
        c:SetAnchor(CENTER, root, CENTER, Val(d.x, s) or 0, Val(d.y, s) or 0)
    end
    if d.rot then c:SetTextureRotation(Val(d.rot, s) * math.pi / 180 * rotSign, 0.5, 0.5) end
    local r, g, b
    if type(d.color) == "function" then r, g, b = d.color(s) else r, g, b = P.r, P.g, P.b end
    r, g, b = Recolor(r, g, b)
    c:SetColor(r, g, b, a)
    if d.atlas then
        local f = math.floor(Val(d.frame, s) + 0.5)
        local cols = d.atlas.cols
        local row, col = math.floor(f / cols), f % cols
        local u, v = col / cols, row / cols
        c:SetTextureCoords(u, u + 1 / cols, v, v + 1 / cols)
    end
end

local function Render()
    if not root or not current then return end
    local s = State()
    local rotSign = sv.flipRot and 1 or -1     -- ESO's positive texture rotation turns counter-clockwise
    local opacity = (sv.opacity or 100) / 100
    for _, P in ipairs(active) do RenderPart(P, s, rotSign, opacity) end
end

local function AtRest()
    return pl == 0 and pr == 0 and tl == 0 and tr == 0 and not (current and current.idle)
end

local function OnUpdate()
    local dt = GetFrameDeltaTimeSeconds()
    local sl, sr = dt / current.left.dur, dt / current.right.dur
    if pl < tl then pl = math.min(tl, pl + sl) else pl = math.max(tl, pl - sl) end
    if pr < tr then pr = math.min(tr, pr + sr) else pr = math.max(tr, pr - sr) end
    Render()
    if AtRest() then root:SetHandler("OnUpdate", nil) end
end

local function Kick()
    if root and not AtRest() then root:SetHandler("OnUpdate", OnUpdate) end
end

local function SetLeft(t)
    if not root or not current then return end
    if not sv.animate then t = 0 end
    tl = t
    Kick()
end

local function SetRight(t)
    if not root or not current then return end
    if not sv.animate then t = 0 end
    tr = t
    Kick()
end

local function Rest()
    tl, tr = 0, 0
    Kick()
end

local function Layout()
    if not root or not current then return end
    root:ClearAnchors()
    root:SetAnchor(CENTER, GuiRoot, CENTER, sv.offsetX, sv.offsetY)
    root:SetScale(sv.scale / 100 * (current.scale or 1))
end

local function BuildSet(def)
    local set = {}
    for i, d in ipairs(def.parts) do
        local c = WINDOW_MANAGER:CreateControl(ADDON .. def.id .. i, root, CT_TEXTURE)
        c:SetAnchor(CENTER, root, CENTER, 0, 0)
        c:SetTexture(Tex(d.tex))
        c:SetMouseEnabled(false)
        c:SetDrawLayer(DL_OVERLAY)
        c:SetDrawLevel(i)
        local P = { def = d, control = c, base = (PablocosReticles.texSize and PablocosReticles.texSize[d.tex]) or { 64, 64 }, hidden = false }
        if type(d.color) ~= "function" then P.r, P.g, P.b = Hex(d.color or "ffffff") end
        set[i] = P
    end
    return set
end

local function HideAll(set, hidden)
    if not set then return end
    for _, P in ipairs(set) do P.control:SetHidden(hidden); P.hidden = hidden end
end

-- Armory builds: ESO never says which build is active, only fires an event when one is loaded, so the last build
-- loaded on this character is remembered (like Group Activity Finder Extensions does).
local function MappedReticle()
    local id = charSv and charSv.buildReticles and charSv.buildReticles[charSv.lastBuild or 0]
    if id and id ~= "" and PablocosReticles.reticles[id] then return id end
end

local function MappedColorway()
    local id = charSv and charSv.buildColors and charSv.buildColors[charSv.lastBuild or 0]
    if id and id ~= "" and PablocosReticles.colorwayById[id] then return id end
end

local function Build()
    if not root then
        root = WINDOW_MANAGER:CreateControl(ADDON .. "Root", ZO_ReticleContainer, CT_CONTROL)
        root:SetDimensions(1, 1)
        root:SetMouseEnabled(false)
    end
    HideAll(active, true)
    current = PablocosReticles.reticles[MappedReticle() or sv.reticle] or PablocosReticles.reticles[PablocosReticles.reticleOrder[1]]
    colorway = PablocosReticles.colorwayById[MappedColorway() or sv.colorway] or PablocosReticles.colorwayById.classic
    if not sets[current.id] then sets[current.id] = BuildSet(current) end
    active = sets[current.id]
    pl, pr, tl, tr = 0, 0, 0, 0
    root:SetHandler("OnUpdate", nil)
    for _, P in ipairs(active) do P.hidden = true end
    Layout()
    Render()
    Kick()
end

local function Refresh()
    if not root then return end
    root:SetHidden(not sv.enabled)
    ApplyStockReticle()
    Layout()
end

-- Settings storage: account-wide by default; a character can opt into its own copy ------------------------------
local function UseSettings()
    sv = (charSv and charSv.useOwn) and charSv or acctSv
end

-- Input -------------------------------------------------------------------------------------------------------------
local function InUIMode()
    return SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode()
end

local function OnMouseDown(_, button)
    if debugMouse then d(ADDON .. ": mouse down button=" .. tostring(button) .. " uiMode=" .. tostring(InUIMode())) end
    if not sv.enabled or InUIMode() then return end
    if button == MOUSE_BUTTON_INDEX_LEFT then SetLeft(1)
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then SetRight(1) end
end

local function OnMouseUp(_, button)
    if debugMouse then d(ADDON .. ": mouse up button=" .. tostring(button)) end
    if button == MOUSE_BUTTON_INDEX_LEFT then SetLeft(0)
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then SetRight(0) end
end

-- Gamepad -----------------------------------------------------------------------------------------------------------
-- Gamepad triggers never raise the mouse events above, and ESO marks IsKeyDown (and so any direct trigger read)
-- private, so an addon cannot see a trigger pull. What it can see, in gamepad mode only:
--   * block: IsBlockActive() is polled every frame (every call is wrapped; if ESO refuses it the poll switches itself
--     off for the session instead of throwing), and drives the right-click / block animation.
--   * attack: the game reports each of the player's light and heavy attacks as they land, which plays the left-click
--     animation as a short pulse. It follows the hit, not the button, so a swing that misses does not animate.
local trig = { block = false }
local blockApi = true            -- false once IsBlockActive has been refused or is missing
local pulseId = 0
local PULSE_MS = 260

local function BlockActive()
    if not blockApi then return nil end
    local ok, v = pcall(function() return IsBlockActive() end)
    if not ok or v == nil then blockApi = false; return nil end
    return v and true or false
end

local function InGamepad()
    return IsInGamepadPreferredMode and IsInGamepadPreferredMode() and true or false
end

local function PollBlock()
    if not sv or not current then return end
    if not InGamepad() or not sv.enabled or InUIMode() then
        if trig.block then trig.block = false; SetRight(0) end
        return
    end
    local b = BlockActive()
    if b ~= nil and b ~= trig.block then
        trig.block = b
        if debugMouse then d(ADDON .. ": gamepad block " .. (b and "down" or "up")) end
        SetRight(b and 1 or 0)
    end
end

-- Attack input. Found with /pabloco diag on a real controller: EVENT_ACTION_SLOT_ABILITY_USED fires for the two hidden
-- weapon slots even when the swing hits nothing: slot 1 once per light attack, slot 2 when a heavy attack starts
-- charging and again when it is released. So: slot 1 pulses the animation, slot 2 holds it until the second slot 2
-- (with a safety timeout in case a heavy attack is interrupted and the release never comes). Combat events are only
-- logged for /pabloco debug now, because they arrive only for landed hits.
local holding = false
local lastLogged = ""
local HOLD_TIMEOUT_MS = 3500
local LIGHT_SLOT, HEAVY_SLOT = 1, 2

local function Release(delayMs)
    pulseId = pulseId + 1
    local mine = pulseId
    if delayMs and delayMs > 0 then
        zo_callLater(function() if mine == pulseId then SetLeft(0); holding = false end end, delayMs)
    else
        SetLeft(0); holding = false
    end
end

local function PadAttackOk()
    return sv and sv.enabled and sv.padAttackPulse and InGamepad() and not InUIMode()
end

local function OnSlotUsed(_, slot)
    if debugMouse and InGamepad() then d(ADDON .. ": gamepad slot used " .. tostring(slot)) end
    if not PadAttackOk() then return end
    if slot == LIGHT_SLOT then
        if holding then return end
        SetLeft(1)
        Release(PULSE_MS)
    elseif slot == HEAVY_SLOT then
        if holding then
            SetLeft(1)
            Release(160)                          -- second use = released: let go
        else
            holding = true                        -- first use = started charging: hold
            SetLeft(1)
            Release(HOLD_TIMEOUT_MS)
        end
    end
end

local function OnPlayerCombat(_, result, isError, abilityName, _, slotType, _, _, targetName, _, _, _, _, _, _, _, abilityId)
    if not debugMouse or not InGamepad() then return end
    local line = string.format("combat result=%s slot=%s ability=%s (%s) target=%s err=%s", tostring(result), tostring(slotType),
        tostring(abilityId), tostring(abilityName), tostring(targetName), tostring(isError))
    if line ~= lastLogged then lastLogged = line; d(ADDON .. ": " .. line) end
end

local function ReportGamepad()
    local ok = pcall(function() return IsBlockActive() end)
    d(string.format("%s: gamepad mode=%s, IsBlockActive usable=%s. Attacks: slot 1 = light, slot 2 = heavy start/release.",
        ADDON, tostring(InGamepad()), tostring(ok and blockApi)))
end

local poller
local function StartPolling()
    if poller then return end
    poller = WINDOW_MANAGER:CreateControl(ADDON .. "Poll", GuiRoot, CT_CONTROL)
    poller:SetDimensions(1, 1)
    poller:SetMouseEnabled(false)
    poller:SetHandler("OnUpdate", PollBlock)
    EVENT_MANAGER:RegisterForEvent(ADDON .. "SlotUsed", EVENT_ACTION_SLOT_ABILITY_USED, OnSlotUsed)
    local name = ADDON .. "Combat"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, OnPlayerCombat)
    if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
        EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
end

-- Settings ----------------------------------------------------------------------------------------------------------
local function Preview(setter)
    local saved = sv.animate
    sv.animate = true
    setter(1)
    zo_callLater(function() setter(0); sv.animate = saved end, 700)
end

local function ArmoryBuildCount()
    local n = GetNumUnlockedArmoryBuilds and GetNumUnlockedArmoryBuilds() or 0
    return n or 0
end

local function ArmoryBuildName(i)
    local name = GetArmoryBuildName and GetArmoryBuildName(i) or ""
    if name == nil or name == "" then name = "(unnamed)" end
    return string.format("Build %d: %s", i, name)
end

local function BuildSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    panel = LAM:RegisterAddonPanel(ADDON .. "Panel", {
        type = "panel", name = TITLE, displayName = TITLE,
        author = "pabloco825", version = VERSION,
        registerForRefresh = true, registerForDefaults = true,
    })
    local names, values = {}, {}
    for _, cls in ipairs(PablocosReticles.classOrder) do
        for _, id in ipairs(PablocosReticles.reticleOrder) do
            if PablocosReticles.reticles[id].class == cls then
                table.insert(names, PablocosReticles.reticles[id].name)
                table.insert(values, id)
            end
        end
    end
    local cwNames, cwValues = {}, {}
    for _, c in ipairs(PablocosReticles.colorways) do table.insert(cwNames, c.name); table.insert(cwValues, c.id) end
    local choices, choiceValues = { "(use the default reticle)" }, { "" }
    for i, n in ipairs(names) do table.insert(choices, n); table.insert(choiceValues, values[i]) end
    local cwChoices, cwChoiceValues = { "(use the default colorway)" }, { "" }
    for i, n in ipairs(cwNames) do table.insert(cwChoices, n); table.insert(cwChoiceValues, cwValues[i]) end
    local armory = {}
    local nBuilds = ArmoryBuildCount()
    if nBuilds > 0 then
        local controls = {
            { type = "description", title = "Detected build",
              text = function()
                  local b = charSv.lastBuild or 0
                  if b == 0 then return "None yet. Load a build from the Armory once and it will be remembered." end
                  return ArmoryBuildName(b)
              end },
        }
        for i = 1, nBuilds do
            table.insert(controls, {
                type = "dropdown", name = function() return ArmoryBuildName(i) .. ": reticle" end,
                choices = choices, choicesValues = choiceValues, default = "",
                getFunc = function() return charSv.buildReticles[i] or "" end,
                setFunc = function(v)
                    charSv.buildReticles[i] = v
                    if (charSv.lastBuild or 0) == i then Build(); Refresh() end
                end,
            })
            table.insert(controls, {
                type = "dropdown", name = function() return ArmoryBuildName(i) .. ": colorway" end,
                choices = cwChoices, choicesValues = cwChoiceValues, default = "",
                getFunc = function() return charSv.buildColors[i] or "" end,
                setFunc = function(v)
                    charSv.buildColors[i] = v
                    if (charSv.lastBuild or 0) == i then Build(); Refresh() end
                end,
            })
        end
        armory = { { type = "submenu", name = "Reticle per Armory build (this character)", controls = controls } }
    end
    local options = {
        { type = "checkbox", name = "Separate settings for this character",
          tooltip = "On: this character keeps its own reticle, scale and offsets. Off: every character shares the account-wide ones. Turning it on starts from the current settings.",
          default = false,
          getFunc = function() return charSv.useOwn end,
          setFunc = function(v)
              if v and not charSv.seeded then
                  for k in pairs(defaults) do charSv[k] = acctSv[k] end
                  charSv.seeded = true
              end
              charSv.useOwn = v
              UseSettings()
              Build()
              Refresh()
              if panel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end
          end },
        { type = "checkbox", name = "Enabled", default = defaults.enabled,
          getFunc = function() return sv.enabled end,
          setFunc = function(v) sv.enabled = v; Refresh() end },
        { type = "dropdown", name = "Class and design", choices = names, choicesValues = values, default = defaults.reticle,
          tooltip = "Each class has one or more designs. This is the default for the character; Armory builds below can override it.",
          getFunc = function() return sv.reticle end,
          setFunc = function(v) sv.reticle = v; Build(); Refresh() end },
        { type = "dropdown", name = "Colorway", choices = cwNames, choicesValues = cwValues, default = defaults.colorway,
          tooltip = "Classic keeps each class's own colours. The others recolor any design: red, orange, yellow, green, cyan, blue, purple, pink or white. Cyan or blue on the Warden gives a frost-only version.",
          getFunc = function() return sv.colorway end,
          setFunc = function(v) sv.colorway = v; Build(); Refresh() end },
        { type = "slider", name = "Scale (%)", min = 25, max = 300, step = 5, default = defaults.scale,
          getFunc = function() return sv.scale end,
          setFunc = function(v) sv.scale = v; Layout() end },
        { type = "slider", name = "Opacity (%)", min = 0, max = 100, step = 5, default = defaults.opacity,
          tooltip = "Fades the whole reticle, whichever design and colorway you pick.",
          getFunc = function() return sv.opacity end,
          setFunc = function(v) sv.opacity = v; Render() end },
        { type = "slider", name = "X offset (px, + right)", min = -600, max = 600, step = 1, default = defaults.offsetX,
          getFunc = function() return sv.offsetX end,
          setFunc = function(v) sv.offsetX = v; Layout() end },
        { type = "slider", name = "Y offset (px, + down)", min = -600, max = 600, step = 1, default = defaults.offsetY,
          getFunc = function() return sv.offsetY end,
          setFunc = function(v) sv.offsetY = v; Layout() end },
        { type = "checkbox", name = "Animate on click", tooltip = "Left click (light attack) and right click (block).",
          default = defaults.animate,
          getFunc = function() return sv.animate end,
          setFunc = function(v) sv.animate = v; if not v then Rest() end end },
        { type = "checkbox", name = "Hide the stock reticle", default = defaults.hideStock,
          tooltip = "Turn off to see both reticles at once, e.g. while lining up the X/Y offsets.",
          getFunc = function() return sv.hideStock end,
          setFunc = function(v) sv.hideStock = v; ApplyStockReticle() end },
        { type = "checkbox", name = "Flip rotation direction", default = defaults.flipRot,
          tooltip = "If pieces turn or slide the wrong way during a click, turn this on.",
          getFunc = function() return sv.flipRot end,
          setFunc = function(v) sv.flipRot = v end },
        { type = "checkbox", name = "Gamepad: animate attacks", default = defaults.padAttackPulse,
          tooltip = "Gamepad only. ESO does not let addons see a trigger pull, so the attack animation follows the game's own attack events instead: a pulse for each light attack, held while a heavy attack charges. Block (left trigger) follows the real block state. Turn this off to stop the attack animation.",
          getFunc = function() return sv.padAttackPulse end,
          setFunc = function(v) sv.padAttackPulse = v end },
        { type = "button", name = "Preview left click", tooltip = "Plays one left-click state. Close the menu to see it.",
          func = function() Preview(SetLeft) end },
        { type = "button", name = "Preview right click (block)", tooltip = "Plays one right-click state. Close the menu to see it.",
          func = function() Preview(SetRight) end },
    }
    for _, o in ipairs(armory) do table.insert(options, o) end
    LAM:RegisterOptionControls(ADDON .. "Panel", options)
end

-- Discovery tools ---------------------------------------------------------------------------------------------------
-- ESO tells an addon nothing when a swing hits nothing, and the trigger itself is private. These two commands are
-- for finding out whether any usable signal exists, instead of guessing.
--   /pabloco scan <word>   lists the ESO globals (functions and constants) whose names contain the word
--   /pabloco probe         logs candidate signals (power, action bar, combat state, input layers) while you swing
local function Diag(section, text)
    if not acctSv then return end
    acctSv.diag = acctSv.diag or {}
    local list = acctSv.diag[section]
    if not list then list = {}; acctSv.diag[section] = list end
    while #text > 1800 do
        if #list < 600 then list[#list + 1] = text:sub(1, 1800) .. " ..." end
        text = text:sub(1801)
    end
    if #list < 600 then list[#list + 1] = text end
end

local function Scan(word)
    word = (word or ""):lower()
    if word == "" then d(ADDON .. ": /pabloco scan <word>, for example /pabloco scan attack"); return end
    local names = {}
    local ok, err = pcall(function()
        local nextf, t, k = zo_insecurePairs(_G)
        while true do
            local key = nextf(t, k)
            if key == nil then break end
            k = key
            if type(key) == "string" and key:lower():find(word, 1, true) then names[#names + 1] = key end
        end
    end)
    table.sort(names)
    if not ok then d(ADDON .. ": scan stopped early: " .. tostring(err)) end
    Diag("scan", string.format("[%s] %d: %s", word, #names, table.concat(names, " ")))
    d(string.format("%s: %d globals contain '%s'", ADDON, #names, word))
    local line = {}
    for i, n in ipairs(names) do
        if i > 90 then d(ADDON .. ": ... more not shown, use a longer word"); break end
        line[#line + 1] = n
        if #line == 4 then d("  " .. table.concat(line, "  ")); line = {} end
    end
    if #line > 0 then d("  " .. table.concat(line, "  ")) end
end

local probing, probeLines, probeLast = false, 0, ""
local PROBE_EVENTS = {
    { "EVENT_POWER_UPDATE", function(_, unitTag, _, powerType, value, max)
        if unitTag ~= "player" then return end
        return "power type=" .. tostring(powerType) .. " " .. tostring(value) .. "/" .. tostring(max) end },
    { "EVENT_ACTION_SLOT_ABILITY_USED", function(_, slot) return "slot used " .. tostring(slot) end },
    { "EVENT_ACTION_UPDATE_COOLDOWNS", function() return "action cooldowns updated" end },
    { "EVENT_ACTION_SLOT_STATE_UPDATED", function(_, slot) return "slot state " .. tostring(slot) end },
    { "EVENT_ACTION_LAYER_PUSHED", function(_, layer, active) return "input layer pushed " .. tostring(layer) .. " active=" .. tostring(active) end },
    { "EVENT_ACTION_LAYER_POPPED", function(_, layer, active) return "input layer popped " .. tostring(layer) .. " active=" .. tostring(active) end },
    { "EVENT_PLAYER_COMBAT_STATE", function(_, inCombat) return "combat state " .. tostring(inCombat) end },
    { "EVENT_GLOBAL_MOUSE_DOWN", function(_, b) return "global mouse down " .. tostring(b) end },
    { "EVENT_GLOBAL_MOUSE_UP", function(_, b) return "global mouse up " .. tostring(b) end },
    { "EVENT_RETICLE_TARGET_CHANGED", function() return "reticle target changed" end },
    { "EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED", function(_, unitTag) if unitTag == "player" then return "attribute visual added" end end },
}
local probeRegistered = {}

local function ProbeLog(text)
    if not probing or not text then return end
    local line = ADDON .. ": probe " .. text
    if line == probeLast then return end
    probeLast = line
    probeLines = probeLines + 1
    Diag("probe", string.format("%d %s", GetGameTimeMilliseconds(), text))
    if probeLines > 250 then
        probing = false
        d(ADDON .. ": probe stopped after 250 lines (/pabloco probe to start again)")
        return
    end
    d(line)
end

local function Probe()
    probing = not probing
    probeLines, probeLast = 0, ""
    if probing then
        for i, e in ipairs(PROBE_EVENTS) do
            local evName, fn = e[1], e[2]
            if fn and not probeRegistered[evName] then
                local ok, ev = pcall(function() return _G[evName] end)
                if ok and ev then
                    probeRegistered[evName] = true
                    EVENT_MANAGER:RegisterForEvent(ADDON .. "Probe" .. i, ev, function(...) ProbeLog(fn(...)) end)
                end
            end
        end
        d(ADDON .. ": probe ON. Swing at nothing with the right trigger, then hold a heavy attack, and watch for lines. /pabloco probe again to stop.")
    else
        d(ADDON .. ": probe off")
    end
end

local DIAG_WORDS = { "attack", "swing", "heavy", "light", "charge", "weapon", "trigger", "gamepad", "block", "strike",
    "interrupt", "combat", "animation" }
local DIAG_SECONDS = 20

local function RunDiag()
    acctSv.diag = {}
    for _, w in ipairs(DIAG_WORDS) do Scan(w) end
    -- every player-sourced combat event during the window, hit or not
    local name = ADDON .. "DiagCombat"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, function(_, result, isError, abilityName, _, slotType, _, _, targetName, _, hitValue, _, _, _, _, _, abilityId)
        Diag("combat", string.format("%d result=%s slot=%s ability=%s (%s) target=%s err=%s", GetGameTimeMilliseconds(), tostring(result),
            tostring(slotType), tostring(abilityId), tostring(abilityName), tostring(targetName), tostring(isError)))
    end)
    if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
        EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
    probing = false
    Probe()                                              -- turns the probe on and registers its events
    Diag("probe", string.format("%d window started", GetGameTimeMilliseconds()))
    d(string.format("%s: DIAGNOSTICS for %d seconds. Swing at EMPTY AIR with the right trigger a few times, hold one heavy attack, then block once. Do not touch the chat.", ADDON, DIAG_SECONDS))
    zo_callLater(function()
        EVENT_MANAGER:UnregisterForEvent(name, EVENT_COMBAT_EVENT)
        if probing then Probe() end
        Diag("probe", string.format("%d window ended", GetGameTimeMilliseconds()))
        d(ADDON .. ": diagnostics finished. Type /reloadui now so the results are saved, then tell Claude it is done.")
    end, DIAG_SECONDS * 1000)
end

-- Slash command -----------------------------------------------------------------------------------------------------
local function Slash(arg)
    arg = (arg or ""):lower()
    if arg == "" or arg == "settings" then
        if LibAddonMenu2 and panel and pcall(function() LibAddonMenu2:OpenToPanel(panel) end) then return end
        d(ADDON .. ": open Settings > Add-Ons > " .. TITLE)
    elseif arg == "test" then
        Preview(SetLeft)
    elseif arg == "block" then
        Preview(SetRight)
    elseif arg == "flip" then
        sv.flipRot = not sv.flipRot
        d(ADDON .. ": rotation direction flipped " .. (sv.flipRot and "ON" or "off"))
    elseif arg == "debug" then
        debugMouse = not debugMouse
        d(ADDON .. ": input debug " .. (debugMouse and "ON, click or pull a trigger in game and watch chat" or "off"))
        if debugMouse then ReportGamepad() end
    elseif arg:sub(1, 4) == "scan" then
        Scan(arg:sub(6))
    elseif arg == "probe" then
        Probe()
    elseif arg == "diag" then
        RunDiag()
    else
        d(ADDON .. ": /reticle (or /pabloco) opens the settings. test plays the left-click animation, block the right-click one, "
            .. "flip reverses the direction pieces turn. Troubleshooting: debug, diag (saves a report to disk), scan <word>, probe. "
            .. "Example: /pabloco test")
    end
end

-- /pabloco always works. /reticle is the friendlier name, but plenty of addons could want it, so it is only taken if
-- nobody else has by the time every addon has loaded (never overwriting another addon's command).
SLASH_COMMANDS["/pabloco"] = Slash
local function ClaimShortCommand()
    if SLASH_COMMANDS["/reticle"] == nil then SLASH_COMMANDS["/reticle"] = Slash end
end

-- Load --------------------------------------------------------------------------------------------------------------
local function OnAddOnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    acctSv = ZO_SavedVars:NewAccountWide(SV_NAME, 1, nil, defaults)
    acctSv.diag = nil              -- /pabloco diag reports are one-off; the file on disk keeps the last one until the next save
    local charDefaults = { useOwn = false, seeded = false, lastBuild = 0, buildReticles = {}, buildColors = {} }
    for k, v in pairs(defaults) do charDefaults[k] = v end
    charSv = ZO_SavedVars:NewCharacterIdSettings(SV_NAME, 1, "Character", charDefaults)
    UseSettings()
    EVENT_MANAGER:RegisterForEvent(ADDON .. "Start", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON .. "Start", EVENT_PLAYER_ACTIVATED)
        BuildSettings()      -- needs the Armory build count, which is only known once the character is in the world
        StartPolling()
        ClaimShortCommand()
        Build()
        Refresh()
    end)
    local function OnBuildLoaded(_, result, buildIndex)
        if result == ARMORY_BUILD_RESTORE_RESULT_SUCCESS or result == ARMORY_BUILD_SAVE_RESULT_SUCCESS then
            charSv.lastBuild = buildIndex
            if root then Build(); Refresh() end
        end
    end
    EVENT_MANAGER:RegisterForEvent(ADDON .. "ArmoryRestore", EVENT_ARMORY_BUILD_RESTORE_RESPONSE, OnBuildLoaded)
    EVENT_MANAGER:RegisterForEvent(ADDON .. "ArmorySave", EVENT_ARMORY_BUILD_SAVE_RESPONSE, OnBuildLoaded)
    EVENT_MANAGER:RegisterForEvent(ADDON .. "Down", EVENT_GLOBAL_MOUSE_DOWN, OnMouseDown)
    EVENT_MANAGER:RegisterForEvent(ADDON .. "Up", EVENT_GLOBAL_MOUSE_UP, OnMouseUp)
    -- Opening a menu mid-click would swallow the mouse-up, so always settle back to rest.
    EVENT_MANAGER:RegisterForEvent(ADDON .. "Ui", EVENT_GAME_CAMERA_UI_MODE_CHANGED, Rest)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
