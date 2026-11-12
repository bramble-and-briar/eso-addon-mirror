-- InventoryPulse is the addon's only global table, shared with the language files in lang/
InventoryPulse = InventoryPulse or {}
local IP = InventoryPulse
IP.name = "InventoryPulse"
IP.version = "1.0.2"
local L = IP.strings

local defaults = {
    enabled      = "all",              -- "all", "bag" (BagCount only), "stack" (StackCount only), "none"
    hudOnly      = true,               -- only show in HUD scenes, hide in menus
    bankMute     = true,               -- no messages while a bank or guild bank is open

    -- BagCount
    mode         = "used",             -- "used" or "free" slots
    showMax      = true,               -- append total capacity ("161/215")
    display      = "number",           -- "number", "percent" or "both" ("161/215 (75% full)")
    percentWord  = true,               -- "75% full" instead of "75%"
    minFill      = 0,                  -- only show from this backpack fill level (%)
    step         = 1,                  -- only show when the displayed number reaches a multiple of this
    sizeByFill   = false,              -- font size grows with the fill level up to fontSize
    minFontSize  = 24,                 -- font size of an empty backpack when sizeByFill is on

    -- StackCount
    stackDisplay = "both",             -- "both" (icon + name), "icon", "name"
    stackSound   = "NEW_NOTIFICATION", -- key from SOUNDS or "none"
    stackBackpack = true,              -- also watch backpack stacks (potions, soul gems ...); the craft bag is watched with ESO Plus

    -- Shared
    font         = "bold",             -- key from FONTS or a LibMediaProvider font name
    effect       = "soft-shadow-thick",
    fontSize     = 48,
    alpha        = 0.9,
    offsetY      = -80,                -- vertical offset of the start point from the screen center
    holdMs       = 500,                -- pause in the center before flying away
    flightWidth  = 180,                -- horizontal distance when back at start height (px)
    flightHeight = 70,                 -- apex height above the start height (px)
    flightMs     = 800,                -- time until back at start height
    flightLength = 100,                -- flight distance in %; 100 = fade out at start height
    shrink       = 0,                  -- shrink during flight in % (0 = off), gives a 3D effect

    colorNormal  = { 1, 1, 1 },        -- more than 15 free slots
    color15      = { 1, 0.85, 0.3 },   -- up to 15 free slots
    color5       = { 1, 0.45, 0.2 },   -- up to 5 free slots
    color0       = { 1, 0.2, 0.2 },    -- inventory full
    colorP80     = { 1, 0.85, 0.3 },   -- percent display: from 80 % fill level
    colorP90     = { 1, 0.45, 0.2 },   -- percent display: from 90 %
    colorP95     = { 1, 0.3, 0.3 },    -- percent display: from 95 %
    stackColor   = { 0.4, 0.9, 1 },
}

local STACK_SIZE = 200 -- maximum quantity per guild store listing
local FADE_IN_MS = 350

-- Scenes in which messages are shown when "HUD only" is active
local HUD_SCENES = { hud = true, hudui = true, loot = true, lootGamepad = true }

-- Built-in ESO fonts; LibMediaProvider adds more
local FONTS = {
    { key = "bold",        path = "$(BOLD_FONT)",           name = L.FONT_BOLD },
    { key = "medium",      path = "$(MEDIUM_FONT)",         name = L.FONT_MEDIUM },
    { key = "chat",        path = "$(CHAT_FONT)",           name = L.FONT_CHAT },
    { key = "gpbold",      path = "$(GAMEPAD_BOLD_FONT)",   name = L.FONT_GP_BOLD },
    { key = "gpmedium",    path = "$(GAMEPAD_MEDIUM_FONT)", name = L.FONT_GP_MEDIUM },
    { key = "antique",     path = "$(ANTIQUE_FONT)",        name = L.FONT_ANTIQUE },
    { key = "handwritten", path = "$(HANDWRITTEN_FONT)",    name = L.FONT_HANDWRITTEN },
    { key = "stone",       path = "$(STONE_TABLET_FONT)",   name = L.FONT_STONE },
}

local EFFECTS = {
    { key = "none",              name = L.EFFECT_NONE },
    { key = "shadow",            name = L.EFFECT_SHADOW },
    { key = "outline",           name = L.EFFECT_OUTLINE },
    { key = "thick-outline",     name = L.EFFECT_THICK },
    { key = "soft-shadow-thin",  name = L.EFFECT_SOFT_THIN },
    { key = "soft-shadow-thick", name = L.EFFECT_SOFT_THICK },
}

-- Sounds for StackCount (keys from the global SOUNDS table)
local SOUND_OPTIONS = {
    { key = "none",                      name = L.SOUND_NONE },
    { key = "NEW_NOTIFICATION",          name = L.SOUND_PING },
    { key = "QUEST_OBJECTIVE_INCREMENT", name = L.SOUND_SHORT },
    { key = "LOCKPICKING_UNLOCKED",      name = L.SOUND_CLICK },
    { key = "BOOK_ACQUIRED",             name = L.SOUND_BOOK },
    { key = "CHAMPION_POINT_GAINED",     name = L.SOUND_BELL },
    { key = "ACHIEVEMENT_AWARDED",       name = L.SOUND_FANFARE },
}

local window
local labels, freeLabels = {}, {}
local active = {}
local lastFree
local bankOpen = false
local nextDirection = 1

local function Print(text)
    d("|c66CCFFInventoryPulse:|r " .. text)
end

-- ---------------------------------------------------------------------------
-- Fonts
-- ---------------------------------------------------------------------------

local function GetFontPath(key)
    for _, font in ipairs(FONTS) do
        if font.key == key then return font.path end
    end
    local LMP = LibMediaProvider
    if LMP and LMP:IsValid("font", key) then
        return LMP:Fetch("font", key)
    end
    return FONTS[1].path
end

local function GetFontString(size)
    local font = GetFontPath(IP.sv.font) .. "|" .. (size or IP.sv.fontSize)
    if IP.sv.effect ~= "none" then
        font = font .. "|" .. IP.sv.effect
    end
    return font
end

-- Returns display names and keys of all available fonts
local function GetFontChoices()
    local names, keys = {}, {}
    for _, font in ipairs(FONTS) do
        names[#names + 1] = font.name
        keys[#keys + 1] = font.key
    end
    local LMP = LibMediaProvider
    if LMP then
        local lmpFonts = {}
        for _, name in ipairs(LMP:List("font")) do
            lmpFonts[#lmpFonts + 1] = name
        end
        table.sort(lmpFonts)
        for _, name in ipairs(lmpFonts) do
            names[#names + 1] = name
            keys[#keys + 1] = name
        end
    end
    return names, keys
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local function BagCountEnabled()
    return IP.sv.enabled == "all" or IP.sv.enabled == "bag"
end

-- With ESO Plus StackCount also watches the craft bag
local function UsesCraftBag()
    return HasCraftBagAccess()
end

local function StackCountEnabled()
    return IP.sv.enabled == "all" or IP.sv.enabled == "stack"
end

local function IsHudScene()
    local scene = SCENE_MANAGER:GetCurrentScene()
    return scene ~= nil and HUD_SCENES[scene:GetName()] == true
end

local function IsMuted()
    return (IP.sv.hudOnly and not IsHudScene()) or (IP.sv.bankMute and bankOpen)
end

local function UpdateVisibility()
    if not window then return end
    -- Running animations (e.g. a test from the settings menu) stay visible
    window:SetHidden(IP.sv.hudOnly and not IsHudScene() and #active == 0)
end

-- ---------------------------------------------------------------------------
-- Label pool
-- ---------------------------------------------------------------------------

-- Scale without changing the layout; older clients fall back to SetScale
local function SetLabelScale(label, scale)
    if label.SetTransformScale then
        label:SetTransformScale(scale)
    else
        label:SetScale(scale)
    end
end

local function AcquireLabel(size)
    local label = table.remove(freeLabels)
    if not label then
        label = WINDOW_MANAGER:CreateControl("InventoryPulseLabel" .. (#labels + 1), window, CT_LABEL)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        labels[#labels + 1] = label
    end
    label:SetFont(GetFontString(size))
    SetLabelScale(label, 1)
    label:SetAlpha(0)
    label:SetHidden(false)
    return label
end

local function ReleaseLabel(label)
    label:SetHidden(true)
    freeLabels[#freeLabels + 1] = label
end

-- ---------------------------------------------------------------------------
-- Animation
-- ---------------------------------------------------------------------------

local function Place(label, x, y)
    label:ClearAnchors()
    label:SetAnchor(CENTER, window, CENTER, x, IP.sv.offsetY + y)
end

local function OnUpdate()
    local now = GetFrameTimeMilliseconds()
    local maxAlpha = IP.sv.alpha
    local holdMs = IP.sv.holdMs
    local flightTotal = IP.sv.flightMs * IP.sv.flightLength / 100

    for i = #active, 1, -1 do
        local a = active[i]
        local elapsed = now - a.start

        if elapsed < FADE_IN_MS then
            -- fade in slowly at the center
            local p = elapsed / FADE_IN_MS
            a.label:SetAlpha(maxAlpha * p * p)
            Place(a.label, 0, 0)
        elseif elapsed < FADE_IN_MS + holdMs then
            a.label:SetAlpha(maxAlpha)
            Place(a.label, 0, 0)
        elseif elapsed < FADE_IN_MS + holdMs + flightTotal then
            -- Flight along a parabola. arc = 1: opens downward (up first, then down),
            -- arc = -1: opens upward (down first, then up).
            -- u = 1 is the moment the message is back at its start height.
            local flightElapsed = elapsed - FADE_IN_MS - holdMs
            local u = flightElapsed / IP.sv.flightMs
            local height = a.arc * IP.sv.flightHeight * 4 * u * (1 - u)
            local x = a.direction * IP.sv.flightWidth * u
            local progress = flightElapsed / flightTotal
            a.label:SetAlpha(maxAlpha * (1 - progress))
            -- shrinking makes the message look like it flies into the distance
            SetLabelScale(a.label, 1 - IP.sv.shrink / 100 * progress)
            Place(a.label, x, -height)
        else
            ReleaseLabel(a.label)
            table.remove(active, i)
        end
    end

    if #active == 0 then
        EVENT_MANAGER:UnregisterForUpdate(IP.name .. "Anim")
        UpdateVisibility()
    end
end

local function Spawn(text, color, arc, size)
    local label = AcquireLabel(size)
    label:SetText(text)
    label:SetColor(unpack(color))
    Place(label, 0, 0)

    active[#active + 1] = {
        label = label,
        start = GetFrameTimeMilliseconds(),
        direction = nextDirection,
        arc = arc,
    }
    nextDirection = -nextDirection

    window:SetHidden(false)
    EVENT_MANAGER:RegisterForUpdate(IP.name .. "Anim", 0, OnUpdate)
end

-- ---------------------------------------------------------------------------
-- BagCount
-- ---------------------------------------------------------------------------

-- Number display: colors by free slots; percent display: colors by fill level
local function ColorFor(free, size)
    if free == 0 then return IP.sv.color0 end
    if IP.sv.display == "number" then
        if free <= 5 then return IP.sv.color5 end
        if free <= 15 then return IP.sv.color15 end
    else
        local fill = (size - free) / size * 100
        if fill >= 95 then return IP.sv.colorP95 end
        if fill >= 90 then return IP.sv.colorP90 end
        if fill >= 80 then return IP.sv.colorP80 end
    end
    return IP.sv.colorNormal
end

local function PercentText(used, free, size)
    local percent
    if IP.sv.mode == "free" then
        percent = zo_max(1, zo_round(free / size * 100))   -- never "0% free" while slots are left
    else
        percent = zo_min(99, zo_round(used / size * 100))  -- never "100% full" while slots are left
    end
    if not IP.sv.percentWord then
        return string.format("%d%%", percent)
    end
    return string.format(IP.sv.mode == "free" and L.PERCENT_FREE or L.PERCENT_FULL, percent)
end

function IP.ShowBagCount()
    local used = GetNumBagUsedSlots(BAG_BACKPACK)
    local size = GetBagSize(BAG_BACKPACK)
    local free = size - used

    local text
    if free == 0 then
        text = L.INVENTORY_FULL
    else
        local number = tostring(IP.sv.mode == "free" and free or used)
        if IP.sv.showMax then
            number = number .. "/" .. size
        end
        if IP.sv.display == "percent" then
            text = PercentText(used, free, size)
        elseif IP.sv.display == "both" then
            text = number .. " (" .. PercentText(used, free, size) .. ")"
        else
            text = number
        end
    end

    -- Optionally the font grows with the fill level, so the fill level is visible at a glance
    local fontSize
    if IP.sv.sizeByFill then
        local minSize = zo_min(IP.sv.minFontSize, IP.sv.fontSize)
        fontSize = zo_round(minSize + (IP.sv.fontSize - minSize) * used / size)
    end

    Spawn(text, ColorFor(free, size), 1, fontSize)
end

local function CheckFreeSlots()
    EVENT_MANAGER:UnregisterForUpdate(IP.name .. "Check")
    local free = GetNumBagFreeSlots(BAG_BACKPACK)
    if lastFree ~= nil and free ~= lastFree and not IsMuted() then
        local size = GetBagSize(BAG_BACKPACK)
        local fillPercent = (size - free) / size * 100
        -- The step refers to the displayed number (used or free);
        -- a message appears as soon as a multiple is reached or crossed
        local now, before = free, lastFree
        if IP.sv.mode ~= "free" then
            now, before = size - free, size - lastFree
        end
        local step = IP.sv.step
        local stepReached
        if now > before then
            stepReached = zo_floor(now / step) > zo_floor(before / step) -- multiple in (before, now]
        else
            stepReached = zo_ceil(now / step) < zo_ceil(before / step)   -- multiple in [now, before)
        end
        if fillPercent >= IP.sv.minFill and (stepReached or free == 0) then
            IP.ShowBagCount()
        end
    end
    lastFree = free
end

-- Combine several slot updates at once (moving stacks, looting) into one message
local function ScheduleCheck()
    EVENT_MANAGER:RegisterForUpdate(IP.name .. "Check", 100, CheckFreeSlots)
end

-- ---------------------------------------------------------------------------
-- StackCount
-- ---------------------------------------------------------------------------

function IP.ShowStackCount(bagId, slotIndex, fullStacks)
    local icon = GetItemInfo(bagId, slotIndex)
    local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bagId, slotIndex))
    local iconText = zo_iconFormat(icon, IP.sv.fontSize, IP.sv.fontSize)
    local stacks = string.format("%d×%d", fullStacks, STACK_SIZE)

    local text
    if IP.sv.stackDisplay == "icon" then
        text = iconText .. " " .. stacks
    elseif IP.sv.stackDisplay == "name" then
        text = name .. ": " .. stacks
    else
        text = iconText .. " " .. name .. ": " .. stacks
    end

    Spawn(text, IP.sv.stackColor, -1)

    local sound = SOUNDS[IP.sv.stackSound]
    if sound then
        PlaySound(sound)
    end
end

-- In the craft bag the slotId is the itemId and the stack size is the total quantity
local function OnCraftBagUpdate(_, _, slotId, _, _, _, stackCountChange)
    if not stackCountChange or stackCountChange <= 0 or IsMuted() then return end
    local count = GetSlotStackSize(BAG_VIRTUAL, slotId)
    local before = count - stackCountChange
    if zo_floor(count / STACK_SIZE) > zo_floor(before / STACK_SIZE) then
        IP.ShowStackCount(BAG_VIRTUAL, slotId, zo_floor(count / STACK_SIZE))
    end
end

-- Number of full 200 stacks of an item in the backpack
local function CountFullStacks(itemId)
    local fullStacks = 0
    local slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK)
    while slotIndex do
        if GetItemId(BAG_BACKPACK, slotIndex) == itemId and GetSlotStackSize(BAG_BACKPACK, slotIndex) >= STACK_SIZE then
            fullStacks = fullStacks + 1
        end
        slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slotIndex)
    end
    return fullStacks
end

-- A message when a backpack stack reaches 200 (items that never go into the craft bag, or no ESO Plus)
local function OnBackpackStackUpdate(_, _, slotIndex, _, _, _, stackCountChange)
    if not stackCountChange or stackCountChange <= 0 or IsMuted() then return end
    local count, maxStack = GetSlotStackSize(BAG_BACKPACK, slotIndex)
    if maxStack >= STACK_SIZE and count >= STACK_SIZE and count - stackCountChange < STACK_SIZE then
        IP.ShowStackCount(BAG_BACKPACK, slotIndex, CountFullStacks(GetItemId(BAG_BACKPACK, slotIndex)))
    end
end

function IP.TestStackCount()
    -- craft bag first, otherwise the first backpack item that can be stacked to 200
    local craftSlot = UsesCraftBag() and ZO_GetNextBagSlotIndex(BAG_VIRTUAL)
    if craftSlot then
        local count = GetSlotStackSize(BAG_VIRTUAL, craftSlot)
        IP.ShowStackCount(BAG_VIRTUAL, craftSlot, zo_max(1, zo_floor(count / STACK_SIZE)))
        return
    end

    local slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK)
    while slotIndex do
        local _, maxStack = GetSlotStackSize(BAG_BACKPACK, slotIndex)
        if maxStack >= STACK_SIZE then
            local fullStacks = CountFullStacks(GetItemId(BAG_BACKPACK, slotIndex))
            IP.ShowStackCount(BAG_BACKPACK, slotIndex, zo_max(1, fullStacks))
            return
        end
        slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slotIndex)
    end
    Print(L.NO_STACKABLE)
end

-- ---------------------------------------------------------------------------
-- Event registration: only what the current settings need
-- ---------------------------------------------------------------------------

local EVENT_BAG   = IP.name .. "Bag"
local EVENT_CRAFT = IP.name .. "Craft"
local EVENT_STACK = IP.name .. "Stack"
local EVENT_BANK  = IP.name .. "Bank"
local BANK_EVENTS = {
    [EVENT_OPEN_BANK] = true, [EVENT_CLOSE_BANK] = false,
    [EVENT_OPEN_GUILD_BANK] = true, [EVENT_CLOSE_GUILD_BANK] = false,
}
local sceneCallbackRegistered = false

local function OnSceneStateChanged(_, _, newState)
    if newState == SCENE_SHOWN then UpdateVisibility() end
end

-- Slot updates of one bag; only real item changes (no durability, dye or charge updates)
local function RegisterSlotUpdate(namespace, bagId, callback)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, callback)
    EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, bagId,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
end

-- Unregisters everything, then registers only the events the settings need.
-- Called on load, once after login and whenever a relevant setting changes.
local function CheckEvents()
    local em = EVENT_MANAGER

    em:UnregisterForEvent(EVENT_BAG, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    em:UnregisterForEvent(EVENT_BAG, EVENT_INVENTORY_FULL_UPDATE)
    em:UnregisterForEvent(EVENT_BAG, EVENT_INVENTORY_BAG_CAPACITY_CHANGED)
    em:UnregisterForUpdate(IP.name .. "Check")
    em:UnregisterForEvent(EVENT_CRAFT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    em:UnregisterForEvent(EVENT_STACK, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    for event in pairs(BANK_EVENTS) do
        em:UnregisterForEvent(EVENT_BANK, event)
    end
    if sceneCallbackRegistered then
        SCENE_MANAGER:UnregisterCallback("SceneStateChanged", OnSceneStateChanged)
        sceneCallbackRegistered = false
    end

    local bagOn = BagCountEnabled()
    local craftOn = StackCountEnabled() and UsesCraftBag()
    local stackBagOn = StackCountEnabled() and IP.sv.stackBackpack
    local anyOn = bagOn or craftOn or stackBagOn

    if bagOn then
        lastFree = GetNumBagFreeSlots(BAG_BACKPACK) -- starting value without a message
        RegisterSlotUpdate(EVENT_BAG, BAG_BACKPACK, ScheduleCheck)
        em:RegisterForEvent(EVENT_BAG, EVENT_INVENTORY_FULL_UPDATE, ScheduleCheck)
        em:RegisterForEvent(EVENT_BAG, EVENT_INVENTORY_BAG_CAPACITY_CHANGED, ScheduleCheck)
    end
    if craftOn then
        RegisterSlotUpdate(EVENT_CRAFT, BAG_VIRTUAL, OnCraftBagUpdate)
    end
    if stackBagOn then
        RegisterSlotUpdate(EVENT_STACK, BAG_BACKPACK, OnBackpackStackUpdate)
    end

    if anyOn and IP.sv.bankMute then
        for event, open in pairs(BANK_EVENTS) do
            em:RegisterForEvent(EVENT_BANK, event, function() bankOpen = open end)
        end
    else
        bankOpen = false
    end

    if anyOn and IP.sv.hudOnly then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
        sceneCallbackRegistered = true
    end
    UpdateVisibility()
end

-- ---------------------------------------------------------------------------
-- Settings menu (LibAddonMenu-2.0, optional)
-- ---------------------------------------------------------------------------

local function ColorOption(name, key)
    local def = defaults[key]
    return {
        type = "colorpicker", name = name,
        getFunc = function() return unpack(IP.sv[key]) end,
        setFunc = function(r, g, b) IP.sv[key] = { r, g, b } end,
        default = { r = def[1], g = def[2], b = def[3] },
    }
end

local function CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    LAM:RegisterAddonPanel(IP.name .. "Panel", {
        type = "panel",
        name = "InventoryPulse",
        author = "cudddel",
        version = IP.version,
        slashCommand = "/ipulsemenu",
        registerForDefaults = true,
    })

    local bagOff = function() return not BagCountEnabled() end
    local stackOff = function() return not StackCountEnabled() end
    local fontNames, fontKeys = GetFontChoices()
    local effectNames, effectKeys = {}, {}
    for i, effect in ipairs(EFFECTS) do
        effectNames[i] = effect.name
        effectKeys[i] = effect.key
    end
    local soundNames, soundKeys = {}, {}
    for _, sound in ipairs(SOUND_OPTIONS) do
        if sound.key == "none" or SOUNDS[sound.key] then
            soundNames[#soundNames + 1] = sound.name
            soundKeys[#soundKeys + 1] = sound.key
        end
    end

    LAM:RegisterOptionControls(IP.name .. "Panel", {
        {
            type = "dropdown", name = L.ENABLED,
            choices = { L.ENABLED_NONE, L.ENABLED_BAG, L.ENABLED_STACK, L.ENABLED_ALL },
            choicesValues = { "none", "bag", "stack", "all" },
            getFunc = function() return IP.sv.enabled end,
            setFunc = function(v) IP.sv.enabled = v; CheckEvents() end,
            default = defaults.enabled,
        },
        {
            type = "checkbox", name = L.HUD_ONLY, tooltip = L.HUD_ONLY_TT,
            getFunc = function() return IP.sv.hudOnly end,
            setFunc = function(v) IP.sv.hudOnly = v; CheckEvents() end,
            default = defaults.hudOnly,
        },
        {
            type = "checkbox", name = L.BANK_MUTE, tooltip = L.BANK_MUTE_TT,
            getFunc = function() return IP.sv.bankMute end,
            setFunc = function(v) IP.sv.bankMute = v; CheckEvents() end,
            default = defaults.bankMute,
        },

        -- BagCount ----------------------------------------------------------
        { type = "header", name = L.BAG_HEADER },
        { type = "description", text = L.BAG_DESC },
        {
            type = "dropdown", name = L.MODE,
            choices = { L.MODE_USED, L.MODE_FREE },
            choicesValues = { "used", "free" },
            getFunc = function() return IP.sv.mode end,
            setFunc = function(v) IP.sv.mode = v end,
            disabled = bagOff,
            default = defaults.mode,
        },
        {
            type = "dropdown", name = L.DISPLAY, tooltip = L.DISPLAY_TT,
            choices = { L.DISPLAY_NUMBER, L.DISPLAY_PERCENT, L.DISPLAY_BOTH },
            choicesValues = { "number", "percent", "both" },
            getFunc = function() return IP.sv.display end,
            setFunc = function(v) IP.sv.display = v end,
            disabled = bagOff,
            default = defaults.display,
        },
        {
            type = "checkbox", name = L.SHOW_MAX,
            getFunc = function() return IP.sv.showMax end,
            setFunc = function(v) IP.sv.showMax = v end,
            disabled = function() return not BagCountEnabled() or IP.sv.display == "percent" end,
            default = defaults.showMax,
        },
        {
            type = "checkbox", name = L.PERCENT_WORD, tooltip = L.PERCENT_WORD_TT,
            getFunc = function() return IP.sv.percentWord end,
            setFunc = function(v) IP.sv.percentWord = v end,
            disabled = function() return not BagCountEnabled() or IP.sv.display == "number" end,
            default = defaults.percentWord,
        },
        {
            type = "slider", name = L.MIN_FILL, tooltip = L.MIN_FILL_TT, min = 0, max = 100, step = 10,
            getFunc = function() return IP.sv.minFill end,
            setFunc = function(v) IP.sv.minFill = v end,
            disabled = bagOff,
            default = defaults.minFill,
        },
        {
            type = "slider", name = L.STEP, tooltip = L.STEP_TT, min = 1, max = 20, step = 1,
            getFunc = function() return IP.sv.step end,
            setFunc = function(v) IP.sv.step = v end,
            disabled = bagOff,
            default = defaults.step,
        },
        {
            type = "checkbox", name = L.SIZE_BY_FILL, tooltip = L.SIZE_BY_FILL_TT,
            getFunc = function() return IP.sv.sizeByFill end,
            setFunc = function(v) IP.sv.sizeByFill = v end,
            disabled = bagOff,
            default = defaults.sizeByFill,
        },
        {
            type = "slider", name = L.MIN_FONT_SIZE, tooltip = L.MIN_FONT_SIZE_TT, min = 8, max = 150, step = 2,
            getFunc = function() return IP.sv.minFontSize end,
            setFunc = function(v) IP.sv.minFontSize = v end,
            disabled = function() return not BagCountEnabled() or not IP.sv.sizeByFill end,
            default = defaults.minFontSize,
        },
        {
            type = "button", name = L.TEST_BAG,
            func = function() IP.ShowBagCount() end,
        },

        -- StackCount --------------------------------------------------------
        { type = "header", name = L.STACK_HEADER },
        {
            type = "description",
            text = L.STACK_DESC .. "\n" .. (UsesCraftBag() and L.STACK_MODE_CRAFTBAG or L.STACK_MODE_BACKPACK),
        },
        {
            type = "checkbox", name = L.STACK_BACKPACK, tooltip = L.STACK_BACKPACK_TT,
            getFunc = function() return IP.sv.stackBackpack end,
            setFunc = function(v) IP.sv.stackBackpack = v; CheckEvents() end,
            disabled = stackOff,
            default = defaults.stackBackpack,
        },
        {
            type = "dropdown", name = L.STACK_DISPLAY,
            choices = { L.STACK_BOTH, L.STACK_ICON, L.STACK_NAME },
            choicesValues = { "both", "icon", "name" },
            getFunc = function() return IP.sv.stackDisplay end,
            setFunc = function(v) IP.sv.stackDisplay = v end,
            disabled = stackOff,
            default = defaults.stackDisplay,
        },
        {
            type = "dropdown", name = L.STACK_SOUND,
            choices = soundNames, choicesValues = soundKeys,
            getFunc = function() return IP.sv.stackSound end,
            setFunc = function(v)
                IP.sv.stackSound = v
                if SOUNDS[v] then PlaySound(SOUNDS[v]) end -- preview
            end,
            disabled = stackOff,
            default = defaults.stackSound,
        },
        {
            type = "button", name = L.TEST_STACK,
            func = function() IP.TestStackCount() end,
        },

        -- Shared ------------------------------------------------------------
        { type = "header", name = L.SHARED_HEADER },
        { type = "description", text = L.SHARED_DESC },
        {
            type = "dropdown", name = L.FONT,
            choices = fontNames, choicesValues = fontKeys,
            scrollable = true,
            getFunc = function() return IP.sv.font end,
            setFunc = function(v) IP.sv.font = v end,
            default = defaults.font,
        },
        {
            type = "dropdown", name = L.EFFECT,
            choices = effectNames, choicesValues = effectKeys,
            getFunc = function() return IP.sv.effect end,
            setFunc = function(v) IP.sv.effect = v end,
            default = defaults.effect,
        },
        {
            type = "slider", name = L.FONT_SIZE, min = 16, max = 150, step = 2,
            getFunc = function() return IP.sv.fontSize end,
            setFunc = function(v) IP.sv.fontSize = v end,
            default = defaults.fontSize,
        },
        {
            type = "slider", name = L.ALPHA, min = 10, max = 100, step = 5,
            getFunc = function() return zo_round(IP.sv.alpha * 100) end,
            setFunc = function(v) IP.sv.alpha = v / 100 end,
            default = defaults.alpha * 100,
        },
        {
            type = "slider", name = L.OFFSET, min = -400, max = 400, step = 10,
            getFunc = function() return IP.sv.offsetY end,
            setFunc = function(v) IP.sv.offsetY = v end,
            default = defaults.offsetY,
        },
        {
            type = "slider", name = L.HOLD, min = 0, max = 3000, step = 50,
            getFunc = function() return IP.sv.holdMs end,
            setFunc = function(v) IP.sv.holdMs = v end,
            default = defaults.holdMs,
        },
        { type = "divider" },
        {
            type = "slider", name = L.WIDTH, tooltip = L.WIDTH_TT, min = 0, max = 1000, step = 10,
            getFunc = function() return IP.sv.flightWidth end,
            setFunc = function(v) IP.sv.flightWidth = v end,
            default = defaults.flightWidth,
        },
        {
            type = "slider", name = L.HEIGHT, min = 0, max = 500, step = 10,
            getFunc = function() return IP.sv.flightHeight end,
            setFunc = function(v) IP.sv.flightHeight = v end,
            default = defaults.flightHeight,
        },
        {
            type = "slider", name = L.SPEED, tooltip = L.SPEED_TT, min = 200, max = 5000, step = 50,
            getFunc = function() return IP.sv.flightMs end,
            setFunc = function(v) IP.sv.flightMs = v end,
            default = defaults.flightMs,
        },
        {
            type = "slider", name = L.LENGTH, tooltip = L.LENGTH_TT, min = 10, max = 300, step = 10,
            getFunc = function() return IP.sv.flightLength end,
            setFunc = function(v) IP.sv.flightLength = v end,
            default = defaults.flightLength,
        },
        {
            type = "slider", name = L.SHRINK, tooltip = L.SHRINK_TT, min = 0, max = 90, step = 5,
            getFunc = function() return IP.sv.shrink end,
            setFunc = function(v) IP.sv.shrink = v end,
            default = defaults.shrink,
        },
        { type = "divider" },
        ColorOption(L.COLOR_NORMAL, "colorNormal"),
        ColorOption(L.COLOR_15, "color15"),
        ColorOption(L.COLOR_5, "color5"),
        ColorOption(L.COLOR_P80, "colorP80"),
        ColorOption(L.COLOR_P90, "colorP90"),
        ColorOption(L.COLOR_P95, "colorP95"),
        ColorOption(L.COLOR_FULL, "color0"),
        ColorOption(L.COLOR_STACK, "stackColor"),
    })
end

-- ---------------------------------------------------------------------------
-- Slash commands (work without LibAddonMenu as well)
-- ---------------------------------------------------------------------------

local COLOR_KEYS = {
    normal = "colorNormal", ["15"] = "color15", ["5"] = "color5",
    p80 = "colorP80", p90 = "colorP90", p95 = "colorP95",
    full = "color0", stack = "stackColor",
}

local function ToHex(color)
    return string.format("%02X%02X%02X", zo_round(color[1] * 255), zo_round(color[2] * 255), zo_round(color[3] * 255))
end

local function FromHex(hex)
    hex = hex and hex:gsub("^#", "")
    if not hex or not hex:match("^%x%x%x%x%x%x$") then return nil end
    return {
        tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
    }
end

local function OnOff(value)
    return value and "on" or "off"
end

local function ShowHelp()
    local sv = IP.sv
    local soundKeysForHelp = {}
    for _, sound in ipairs(SOUND_OPTIONS) do
        if sound.key ~= "none" then
            soundKeysForHelp[#soundKeysForHelp + 1] = sound.key:lower()
        end
    end
    local lines = {
        { "show <all|bag|stack|none>", sv.enabled, L.HELP_SHOW },
        { "hudonly <on|off>", OnOff(sv.hudOnly), L.HELP_HUDONLY },
        { "bankmute <on|off>", OnOff(sv.bankMute), L.HELP_BANKMUTE },
        { "mode <used|free>", sv.mode, L.HELP_MODE },
        { "display <number|percent|both>", sv.display, L.HELP_DISPLAY },
        { "max <on|off>", OnOff(sv.showMax), L.HELP_MAX },
        { "pctword <on|off>", OnOff(sv.percentWord), L.HELP_PCTWORD },
        { "fill <0-100>", sv.minFill, L.HELP_FILL },
        { "step <1-20>", sv.step, L.HELP_STEP },
        { "sizebyfill <on|off>", OnOff(sv.sizeByFill), L.HELP_SIZEBYFILL },
        { "minsize <8-150>", sv.minFontSize, L.HELP_MINSIZE },
        { "stackdisplay <both|icon|name>", sv.stackDisplay, L.HELP_STACKDISPLAY },
        { "stackbag <on|off>", OnOff(sv.stackBackpack), L.HELP_STACKBACKPACK },
        { "sound <none|" .. table.concat(soundKeysForHelp, "|") .. ">", sv.stackSound, L.HELP_SOUND },
        { "font <name>", sv.font, L.HELP_FONT },
        { "effect <none|shadow|outline|thick-outline|soft-shadow-thin|soft-shadow-thick>", sv.effect, L.HELP_EFFECT },
        { "size <16-150>", sv.fontSize, L.HELP_SIZE },
        { "alpha <10-100>", zo_round(sv.alpha * 100), L.HELP_ALPHA },
        { "offset <-400-400>", sv.offsetY, L.HELP_OFFSET },
        { "hold <0-3000>", sv.holdMs, L.HELP_HOLD },
        { "width <0-1000>", sv.flightWidth, L.HELP_WIDTH },
        { "height <0-500>", sv.flightHeight, L.HELP_HEIGHT },
        { "speed <200-5000>", sv.flightMs, L.HELP_SPEED },
        { "length <10-300>", sv.flightLength, L.HELP_LENGTH },
        { "shrink <0-90>", sv.shrink, L.HELP_SHRINK },
        { "color <normal|15|5|p80|p90|p95|full|stack> <RRGGBB>", string.format("%s, %s, %s, %s, %s, %s, %s, %s",
            ToHex(sv.colorNormal), ToHex(sv.color15), ToHex(sv.color5), ToHex(sv.colorP80), ToHex(sv.colorP90),
            ToHex(sv.colorP95), ToHex(sv.color0), ToHex(sv.stackColor)), L.HELP_COLOR },
        { "test | stacktest", nil, L.HELP_TEST },
        { "reset", nil, L.HELP_RESET },
    }
    Print(L.HELP_TITLE)
    for _, line in ipairs(lines) do
        local current = line[2] ~= nil and (" |cAAAAAA[" .. tostring(line[2]) .. "]|r") or ""
        d(string.format("  /ipulse %s%s – %s", line[1], current, line[3]))
    end
end

local function ResetSettings()
    for key, value in pairs(defaults) do
        IP.sv[key] = type(value) == "table" and ZO_ShallowTableCopy(value) or value
    end
    CheckEvents()
    Print(L.RESET_DONE)
end

local function SetNumber(key, value, min, max)
    if not value then return false end
    IP.sv[key] = zo_clamp(zo_round(value), min, max)
    return true
end

local function SlashCommand(args)
    local cmd, arg = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local value = tonumber(arg)
    local sv = IP.sv
    local ok = true

    if cmd == "" or cmd == "help" then
        ShowHelp()
        return
    elseif cmd == "test" then
        IP.ShowBagCount()
        return
    elseif cmd == "stacktest" then
        IP.TestStackCount()
        return
    elseif cmd == "reset" then
        ResetSettings()
        return
    elseif cmd == "fonts" then
        local names, keys = GetFontChoices()
        Print(L.FONTS_TITLE)
        for i, key in ipairs(keys) do
            d(string.format("  %s (%s)", key, names[i]))
        end
        return
    elseif cmd == "show" and (arg == "all" or arg == "bag" or arg == "stack" or arg == "none") then
        sv.enabled = arg
        CheckEvents()
    elseif cmd == "hudonly" and (arg == "on" or arg == "off") then
        sv.hudOnly = arg == "on"
        CheckEvents()
    elseif cmd == "bankmute" and (arg == "on" or arg == "off") then
        sv.bankMute = arg == "on"
        CheckEvents()
    elseif cmd == "mode" and (arg == "used" or arg == "free") then
        sv.mode = arg
    elseif cmd == "max" and (arg == "on" or arg == "off") then
        sv.showMax = arg == "on"
    elseif cmd == "display" and (arg == "number" or arg == "percent" or arg == "both") then
        sv.display = arg
    elseif cmd == "pctword" and (arg == "on" or arg == "off") then
        sv.percentWord = arg == "on"
    elseif cmd == "fill" and value then
        sv.minFill = zo_clamp(zo_round(value / 10) * 10, 0, 100)
    elseif cmd == "step" then
        ok = SetNumber("step", value, 1, 20)
    elseif cmd == "sizebyfill" and (arg == "on" or arg == "off") then
        sv.sizeByFill = arg == "on"
    elseif cmd == "minsize" then
        ok = SetNumber("minFontSize", value, 8, 150)
    elseif cmd == "shrink" then
        ok = SetNumber("shrink", value, 0, 90)
    elseif cmd == "sound" then
        ok = false
        for _, sound in ipairs(SOUND_OPTIONS) do
            if sound.key:lower() == arg:lower() then
                sv.stackSound = sound.key
                if SOUNDS[sound.key] then PlaySound(SOUNDS[sound.key]) end
                ok = true
            end
        end
    elseif cmd == "stackdisplay" and (arg == "both" or arg == "icon" or arg == "name") then
        sv.stackDisplay = arg
    elseif cmd == "stackbag" and (arg == "on" or arg == "off") then
        sv.stackBackpack = arg == "on"
        CheckEvents()
    elseif cmd == "font" and arg ~= "" then
        local _, keys = GetFontChoices()
        ok = false
        for _, key in ipairs(keys) do
            if key:lower() == arg:lower() then
                sv.font = key
                ok = true
            end
        end
    elseif cmd == "effect" then
        ok = false
        for _, effect in ipairs(EFFECTS) do
            if effect.key == arg then
                sv.effect = arg
                ok = true
            end
        end
    elseif cmd == "size" then
        ok = SetNumber("fontSize", value, 16, 150)
    elseif cmd == "alpha" and value then
        sv.alpha = zo_clamp(value, 10, 100) / 100
    elseif cmd == "offset" then
        ok = SetNumber("offsetY", value, -400, 400)
    elseif cmd == "hold" then
        ok = SetNumber("holdMs", value, 0, 3000)
    elseif cmd == "width" then
        ok = SetNumber("flightWidth", value, 0, 1000)
    elseif cmd == "height" then
        ok = SetNumber("flightHeight", value, 0, 500)
    elseif cmd == "speed" then
        ok = SetNumber("flightMs", value, 200, 5000)
    elseif cmd == "length" then
        ok = SetNumber("flightLength", value, 10, 300)
    elseif cmd == "color" then
        local which, hex = arg:match("^(%S+)%s+(%S+)$")
        local color = FromHex(hex)
        if COLOR_KEYS[which] and color then
            sv[COLOR_KEYS[which]] = color
        else
            ok = false
        end
    else
        ok = false
    end

    Print(ok and L.SAVED or L.UNKNOWN_COMMAND)
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

-- Up to 1.0.1 the settings were shared by all servers (profile "Default").
-- They are copied once to every server that has no settings yet.
local function MigrateToServerProfile(world)
    local raw = InventoryPulse_SV
    local account = GetDisplayName()
    local old = raw and raw.Default and raw.Default[account]
    if old and not (raw[world] and raw[world][account]) then
        raw[world] = raw[world] or {}
        raw[world][account] = ZO_DeepTableCopy(old)
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= IP.name then return end
    EVENT_MANAGER:UnregisterForEvent(IP.name, EVENT_ADD_ON_LOADED)

    -- Settings are saved per server (EU, NA, PTS)
    local world = GetWorldName()
    MigrateToServerProfile(world)
    IP.sv = ZO_SavedVars:NewAccountWide("InventoryPulse_SV", 1, nil, defaults, world)

    window = WINDOW_MANAGER:CreateTopLevelWindow("InventoryPulseWindow")
    window:SetAnchorFill(GuiRoot)
    window:SetMouseEnabled(false)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawTier(DT_HIGH)

    CheckEvents()

    -- Once after login: build the menu (the ESO Plus status is only reliable then)
    -- and check the events again, as the craft bag access may differ from load time
    EVENT_MANAGER:RegisterForEvent(IP.name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(IP.name, EVENT_PLAYER_ACTIVATED)
        CheckEvents()
        CreateSettingsMenu()
    end)

    SLASH_COMMANDS["/ipulse"] = SlashCommand
end

EVENT_MANAGER:RegisterForEvent(IP.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
