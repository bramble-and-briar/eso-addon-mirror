InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

---------------------------------------------------------------------------
-- AUTOMATE > REPAIRING: worn pieces repaired on their own below a threshold
---------------------------------------------------------------------------

-- Off unless switched on (repairEnabled). Three ways, each with a switch of its own, tried in
-- this order:
--   1. gold at a merchant that repairs (only while one is open; saves the kits)
--   2. ordinary repair kits from the backpack, the smallest one that is enough
--   3. a Crown Repair Kit, last of all and off by default (bought with real money)
-- Group repair kits are never used.
--
-- Sources (ESOUIDocumentation.txt, API 101048; PersonalAssistant is PARepair / HelperFunctions):
--   DoesItemHaveDurability, GetItemCondition, GetItemRepairCost      doc 18700-18706
--   IsItemRepairKit, IsItemNonCrownRepairKit, IsItemNonGroupRepairKit doc 18715-18721
--   GetRepairKitTier, GetAmountRepairKitWouldRepairItem              doc 18724-18727
--   RepairItemWithRepairKit (not protected)                          doc 18730, PARepairKit.lua:119
--   RepairItem, CanStoreRepair (not protected)                       doc 14430/14437, PARepair.lua:122/352
--   UseItem *protected* -> CallSecureProtected                       doc 18612, HelperFunctions.lua:514-525
--   GetCurrencyAmount                                                doc 18550
--   EVENT_INVENTORY_SINGLE_SLOT_UPDATE, EVENT_PLAYER_COMBAT_STATE    doc 24134/24251
--   EVENT_OPEN_STORE, EVENT_CLOSE_STORE                              doc 24237/23859
--   Bound Crown Repair Kit item id 135113                            PARepairKit.lua:42
-- Weapon recharging (rechargeEnabled), same sessions, one weapon per step before any repair:
--   IsItemChargeable, GetChargeInfoForItem                           doc 18686/18697, PARepairCharge.lua:64/67
--   GetAmountSoulGemWouldChargeItem                                  doc 18689, PARepairCharge.lua:74
--   ChargeItemWithSoulGem (not protected)                            doc 18692, PARepairCharge.lua:83
--   IsItemSoulGem(SOUL_GEM_TYPE_FILLED), GetSoulGemItemInfo -> tier  doc 18694/18804, PARepairCharge.lua:26-27
--   Crown soul gems are tier 0, ordinary ones tier 1                 PARepairCharge.lua:46-50 (PA's comment)
--   INVENTORY_UPDATE_REASON_ITEM_CHARGE                              doc 4656, PARepairCharge.lua:69
--   EQUIP_SLOT_MAIN_HAND/OFF_HAND/BACKUP_MAIN/BACKUP_OFF             doc 4519-4534

local REPAIR_EVENT = "InventoryGroupingRepair"
local REPAIR_UPDATE = "InventoryGroupingRepairStep"
local REPAIR_DEBOUNCE = "InventoryGroupingRepairDebounce"
local REPAIR_RETRY = "InventoryGroupingRepairRetry"
local REPAIR_RETRY_MS = 2000   -- while dead or in combat, look again this often
local REPAIR_INTERVAL = 400     -- ms between two repairs, like auto-sell's spacing
local REPAIR_DEBOUNCE_MS = 1500 -- durability ticks come in bursts; wait for the last one
local REPAIR_TRIES = 3          -- repairs one piece may take in one session before giving up
local BOUND_CROWN_KIT_ID = 135113
-- Crown kits by item id (PARepairKit.lua:20-23). IsItemNonCrownRepairKit cannot tell them
-- apart: when it is false for the plain Equipment Repair Kit (44879, suspected since Update 41)
-- every ordinary kit went to the Crown list (off by default) and nothing was left to repair with.
local CROWN_KIT_IDS = { [BOUND_CROWN_KIT_ID] = true, [61079] = true }

local DEFAULTS = {
    repairEnabled = false,
    repairGold = false,
    repairKits = false,
    repairCrown = false,
    repairThreshold = 25,
    rechargeEnabled = false,
    rechargeThreshold = 25,
    rechargeCrown = 0, -- CROWN_GEMS_NEVER
}

-- rechargeCrown answers
local CROWN_GEMS_NEVER, CROWN_GEMS_LAST, CROWN_GEMS_FIRST = 0, 1, 2
local WEAPON_SLOTS = { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF }

function IG.RepairGet(key)
    local value = IG.sv and IG.sv[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

function IG.RepairSet(key, value)
    if not IG.sv then return end
    IG.sv[key] = value
    if IG.RepairCheck then IG.RepairCheck() end
end

-- The lines both pages draw (Drawer.lua's AUTOMATE page, Settings.lua's AUTOMATE category).
IG.AUTOMATE_REPAIR = {
    { key = "repairEnabled", name = "Repair Worn Items",
      description = "Repairs worn gear out of combat when it drops below the threshold." },
    { key = "repairThreshold", name = "Repair Below",
      description = "Durability that triggers a repair.",
      pick = { values = { 10, 25, 50, 75 }, labels = { "10%", "25%", "50%", "75%" } } },
    { key = "repairGold", name = "With Gold At Merchants",
      description = "Pays gold at repair merchants, saving your kits." },
    { key = "repairKits", name = "With Repair Kits",
      description = "Uses the smallest kit that is enough. Never group kits." },
    { key = "repairCrown", name = "With Crown Repair Kits",
      description = "Last resort only. Crown kits cost real money." },
    { key = "rechargeEnabled", name = "Recharge Weapons",
      description = "Recharges both weapon bars with soul gems when charge drops below the threshold." },
    { key = "rechargeThreshold", name = "Recharge Below",
      description = "Charge that triggers a recharge.",
      pick = { values = { 10, 25, 50, 75 }, labels = { "10%", "25%", "50%", "75%" } } },
    { key = "rechargeCrown", name = "Crown Soul Gems",
      description = "When to use Crown soul gems instead of ordinary ones.",
      pick = { values = { CROWN_GEMS_NEVER, CROWN_GEMS_LAST, CROWN_GEMS_FIRST },
               labels = { "Never", "Last", "First" } } },
}

local storeOpen = false
local running = false
local warned = false
local gemWarned = false
local session -- { pieces = {}, kits = 0, gold = 0, crown = 0, tries = {} }

local function Busy()
    return IsUnitInCombat("player") or IsUnitDeadOrReincarnating("player")
end

local function Commas(amount)
    if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(amount) end
    return tostring(amount)
end

-- Worn pieces below the threshold, lowest first.
local function WornBelow()
    if not IG.RepairGet("repairEnabled") then return {} end
    local threshold = tonumber(IG.RepairGet("repairThreshold")) or 25
    local list = {}
    for slot = 0, GetBagSize(BAG_WORN) - 1 do
        if GetItemId(BAG_WORN, slot) ~= 0 and DoesItemHaveDurability(BAG_WORN, slot) then
            local condition = GetItemCondition(BAG_WORN, slot)
            if condition < threshold then list[#list + 1] = { slot = slot, condition = condition } end
        end
    end
    table.sort(list, function(a, b) return a.condition < b.condition end)
    return list
end

-- Ordinary kits and Crown kits in the backpack; group kits are left out altogether.
local function Kits()
    local normal, crown = {}, {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local id = GetItemId(BAG_BACKPACK, slot)
        if id ~= 0 then
            if CROWN_KIT_IDS[id] then
                crown[#crown + 1] = slot
            elseif IsItemRepairKit(BAG_BACKPACK, slot) and IsItemNonGroupRepairKit(BAG_BACKPACK, slot) then
                normal[#normal + 1] = slot
            end
        end
    end
    return normal, crown
end

-- Charge of a worn weapon in percent, or nil when it holds no charge (unenchanted, empty slot).
local function ChargePercent(slot)
    if GetItemId(BAG_WORN, slot) == 0 or not IsItemChargeable(BAG_WORN, slot) then return nil end
    local charges, maxCharges = GetChargeInfoForItem(BAG_WORN, slot)
    if not maxCharges or maxCharges <= 0 then return nil end
    return zo_floor(100 * charges / maxCharges)
end

-- Worn weapons (both bars) below the recharge threshold, lowest first; none while it is off.
local function WeaponsBelow()
    local list = {}
    if not IG.RepairGet("rechargeEnabled") then return list end
    local threshold = tonumber(IG.RepairGet("rechargeThreshold")) or 25
    for _, slot in ipairs(WEAPON_SLOTS) do
        local percent = ChargePercent(slot)
        if percent and percent < threshold then list[#list + 1] = { slot = slot, condition = percent } end
    end
    table.sort(list, function(a, b) return a.condition < b.condition end)
    return list
end

-- Filled soul gems in the backpack: ordinary (tier > 0) and Crown (tier 0).
local function SoulGems()
    local normal, crown = {}, {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetItemId(BAG_BACKPACK, slot) ~= 0 and IsItemSoulGem(SOUL_GEM_TYPE_FILLED, BAG_BACKPACK, slot) then
            local tier = GetSoulGemItemInfo(BAG_BACKPACK, slot)
            if tier == 0 then crown[#crown + 1] = slot else normal[#normal + 1] = slot end
        end
    end
    return normal, crown
end

-- The gem to use by the Crown Soul Gems pick, or nil.
local function PickGem()
    local normal, crown = SoulGems()
    local mode = tonumber(IG.RepairGet("rechargeCrown")) or CROWN_GEMS_NEVER
    if mode == CROWN_GEMS_FIRST and crown[1] then return crown[1] end
    if normal[1] then return normal[1] end
    if mode == CROWN_GEMS_LAST then return crown[1] end
    return nil
end

-- The smallest kit that brings the piece back to full; if none does, the biggest there is
-- (the next step takes another if it is still below). Ties go to the lower tier.
local function BestKit(wornSlot, kits)
    local need = 100 - GetItemCondition(BAG_WORN, wornSlot)
    local enough, enoughAmount, enoughTier
    local biggest, biggestAmount = nil, 0
    for _, kit in ipairs(kits) do
        local amount = GetAmountRepairKitWouldRepairItem(BAG_WORN, wornSlot, BAG_BACKPACK, kit) or 0
        local tier = GetRepairKitTier(BAG_BACKPACK, kit) or 0
        if amount >= need then
            if not enough or amount < enoughAmount or (amount == enoughAmount and tier < enoughTier) then
                enough, enoughAmount, enoughTier = kit, amount, tier
            end
        elseif amount > biggestAmount then
            biggest, biggestAmount = kit, amount
        end
    end
    return enough or biggest
end

local function UseCrownKit(slot)
    local usable, onlyFromActionSlot = IsItemUsable(BAG_BACKPACK, slot)
    if not usable or onlyFromActionSlot then return false end
    if IsProtectedFunction("UseItem") then
        CallSecureProtected("UseItem", BAG_BACKPACK, slot)
    else
        UseItem(BAG_BACKPACK, slot)
    end
    return true
end

-- What a session used, as one line: "Grand Repair Kit (tier 5) x2, 1,250 gold, Crown Repair Kit".
local function MethodText(s)
    local parts = {}
    for _, name in ipairs(s.kitOrder) do
        local count = s.kitNames[name]
        parts[#parts + 1] = count > 1 and (name .. " x" .. count) or name
    end
    if s.gold > 0 then parts[#parts + 1] = Commas(s.gold) .. " gold" end
    if s.crownName then parts[#parts + 1] = s.crownName end
    return table.concat(parts, ", ")
end

local function NoteKit(s, name)
    if not s.kitNames[name] then
        s.kitNames[name] = 0
        s.kitOrder[#s.kitOrder + 1] = name
    end
    s.kitNames[name] = s.kitNames[name] + 1
end

---------------------------------------------------------------------------
-- The countdown panel: shown at the first repair of a session, centred on screen. The repairs
-- themselves run as before (one per REPAIR_INTERVAL from the start); the panel only tells what
-- is happening, so a UI hiccup cannot hold a repair back. Its bar fills over PANEL_FILL_MS; once
-- full and the session done it reads "Repaired" for PANEL_DONE_MS and fades out.
-- Never takes the mouse, closes at once when combat starts, and a second session while it is up
-- only updates its text (one panel at a time). PANEL_TIMEOUT_MS is the last guard: whatever
-- happens, it goes away.
-- Art: the drawer's frame (worldmap_frame_edge.dds, Drawer.lua FRAME_EDGE) and the game's
-- ZO_ArrowStatusBarWithBG (esoui/libraries/zo_templates/statusbartemplates.xml:109-141,
-- progressbar_genericFill.dds).
---------------------------------------------------------------------------

local PANEL_NAME = "InventoryGroupingRepairPanel"
local PANEL_WIDTH, PANEL_HEIGHT = 220, 42
local PANEL_FILL_MS = 3000
local PANEL_DONE_MS = 300  -- hold after completion (was 800)
local PANEL_FADE_MS = 300
local PANEL_TIMEOUT_MS = 15000
local PANEL_EDGE = "EsoUI/Art/WorldMap/worldmap_frame_edge.dds"
local REPAIR_ACCENT = "FF9F43"  -- warm orange: the anvil's colour, apart from AUTOMATE's coral
local DONE_COLOR = "2CFF3C"
local panel

local function HidePanel()
    if not panel then return end
    panel.window:SetHandler("OnUpdate", nil)
    panel.window:SetHidden(true)
end

local function PanelTick()
    local p = panel
    local now = GetFrameTimeMilliseconds()
    if now - p.startMs > PANEL_TIMEOUT_MS or Busy() then return HidePanel() end
    local fill = zo_min(1, (now - p.startMs) / PANEL_FILL_MS)
    p.bar:SetValue(fill)
    if fill < 1 or not p.done then return end
    if not p.doneMs then
        p.doneMs = now
        p.title:SetText("Done")
        p.bar:SetColor(IG.HexToRGB(DONE_COLOR))
    end
    local after = now - p.doneMs - PANEL_DONE_MS
    if after > 0 then
        local alpha = 1 - after / PANEL_FADE_MS
        if alpha <= 0 then return HidePanel() end
        p.window:SetAlpha(alpha)
    end
end

local function BuildPanel()
    local window = WINDOW_MANAGER:CreateTopLevelWindow(PANEL_NAME)
    if not window then return nil end
    window:SetDimensions(PANEL_WIDTH, PANEL_HEIGHT)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, -220)
    window:SetMouseEnabled(false)
    window:SetClampedToScreen(true)
    window:SetHidden(true)

    local bg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    bg:SetAnchorFill(window)
    bg:SetEdgeTexture(PANEL_EDGE, 128, 16, 6, 0)
    bg:SetCenterColor(0, 0, 0, 0.88)
    bg:SetMouseEnabled(false)

    -- A thin accent line along the top, the drawers' way of saying whose panel it is.
    local stripe = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    stripe:SetHeight(1)
    stripe:SetAnchor(TOPLEFT, window, TOPLEFT, 6, 3)
    stripe:SetAnchor(TOPRIGHT, window, TOPRIGHT, -6, 3)
    stripe:SetColor(IG.HexToRGB(REPAIR_ACCENT))
    stripe:SetAlpha(0.8)  -- untextured texture: alpha by SetAlpha, not SetColor

    local title = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    title:SetFont("$(BOLD_FONT)|12|soft-shadow-thin")
    title:SetColor(IG.HexToRGB(REPAIR_ACCENT))
    title:SetAnchor(TOP, window, TOP, 0, 5)

    local method = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    method:SetFont("$(MEDIUM_FONT)|10|soft-shadow-thin")
    method:SetColor(IG.HexToRGB("F2F2F2"))
    method:SetAnchor(TOP, title, BOTTOM, 0, 1)
    method:SetDimensionConstraints(0, 0, PANEL_WIDTH - 20, 0)
    method:SetMaxLineCount(1)

    -- One anchor and its own size: the template carries an explicit width.
    local bar = WINDOW_MANAGER:CreateControlFromVirtual(PANEL_NAME .. "Bar", window, "ZO_ArrowStatusBarWithBG")
    if bar then
        bar:SetDimensions(PANEL_WIDTH - 24, 4)
        bar:SetAnchor(BOTTOM, window, BOTTOM, 0, -3)
        bar:SetMinMax(0, 1)
    end
    return { window = window, title = title, method = method, bar = bar }
end

-- Shown (or, while up, told the new method) at each repair of a session.
local function ShowPanel(methodText)
    if Busy() then return end
    panel = panel or BuildPanel()
    if not panel or not panel.bar then return end
    panel.method:SetText("Using: " .. methodText)
    if not panel.window:IsHidden() and not panel.doneMs then
        panel.done = false
        return
    end
    panel.startMs = GetFrameTimeMilliseconds()
    panel.done, panel.doneMs = false, nil
    panel.title:SetText((session and session.kits + session.gold + session.crown == 0 and session.gems > 0)
        and "Recharging your weapons" or "Repairing your equipped items")
    panel.bar:SetColor(IG.HexToRGB(REPAIR_ACCENT))
    panel.bar:SetValue(0)
    panel.window:SetAlpha(1)
    panel.window:SetHidden(false)
    panel.window:SetHandler("OnUpdate", PanelTick)
end

local function PanelDone()
    if panel then panel.done = true end
end

local function Finish()
    EVENT_MANAGER:UnregisterForUpdate(REPAIR_UPDATE)
    running = false
    local s = session
    session = nil
    PanelDone()
    if not s then return end
    local count = 0
    for _ in pairs(s.pieces) do count = count + 1 end
    if s.weapons > 0 then
        d(string.format("Inventory 2.0: Recharged %d %s (%d soul %s).", s.weapons,
            s.weapons == 1 and "weapon" or "weapons", s.gems, s.gems == 1 and "gem" or "gems"))
        gemWarned = false
    end
    if count > 0 then
        local parts = {}
        if s.gold > 0 then parts[#parts + 1] = Commas(s.gold) .. " gold" end
        if s.kits > 0 then parts[#parts + 1] = s.kits .. (s.kits == 1 and " kit" or " kits") end
        if s.crown > 0 then parts[#parts + 1] = s.crown .. " Crown kit" end
        d(string.format("Inventory 2.0: Repaired %d %s (%s).", count, count == 1 and "item" or "items",
            table.concat(parts, ", ")))
        warned = false
    end
end

-- One repair per step; the next step looks again, since conditions change a moment later.
local function Step()
    if not IG.sv or Busy() then return Finish() end
    local s = session
    -- 0. Weapons first, one per step: a gem each; one still low gets another next session.
    for _, weapon in ipairs(WeaponsBelow()) do
        if not s.charged[weapon.slot] then
            s.charged[weapon.slot] = true
            local gem = PickGem()
            if gem then
                local gemName = zo_strformat("<<1>>", GetItemName(BAG_BACKPACK, gem))
                ChargeItemWithSoulGem(BAG_WORN, weapon.slot, BAG_BACKPACK, gem)
                NoteKit(s, gemName)
                s.gems, s.weapons = s.gems + 1, s.weapons + 1
                ShowPanel(MethodText(s))
                return
            end
            if not gemWarned then
                gemWarned = true
                d(string.format("Inventory 2.0: %s is below %d%% charge and there is no soul gem to recharge it with.",
                    GetItemLink(BAG_WORN, weapon.slot), tonumber(IG.RepairGet("rechargeThreshold")) or 25))
            end
        end
    end
    local below = WornBelow()
    local target
    for _, piece in ipairs(below) do
        -- A piece repaired in this session is not asked again: its condition shows a moment
        -- later, and the durability event that follows starts a new session if still needed.
        if not s.pieces[piece.slot] and (s.tries[piece.slot] or 0) < REPAIR_TRIES then
            target = piece
            break
        end
    end
    if not target then
        if #below == 0 then warned = false end
        return Finish()
    end
    local slot = target.slot
    s.tries[slot] = (s.tries[slot] or 0) + 1

    -- 1. Gold, while a merchant who repairs is open.
    if storeOpen and IG.RepairGet("repairGold") and CanStoreRepair() then
        local cost = GetItemRepairCost(BAG_WORN, slot)
        if cost > 0 and cost <= GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) then
            RepairItem(BAG_WORN, slot)
            s.gold, s.pieces[slot] = s.gold + cost, true
            ShowPanel(MethodText(s))
            return
        end
    end
    local normal, crown = Kits()
    -- 2. Ordinary kits.
    if IG.RepairGet("repairKits") and #normal > 0 then
        local kit = BestKit(slot, normal)
        if not kit then
            -- A kit that reports no amount for one piece but is not a per-piece kit repairs
            -- everything worn when used (the PA path for non-NonCrown kits, PARepairKit.lua:128).
            for _, k in ipairs(normal) do
                if not IsItemNonCrownRepairKit(BAG_BACKPACK, k) then
                    local kitName = zo_strformat("<<1>>", GetItemName(BAG_BACKPACK, k))
                    if UseCrownKit(k) then
                        for _, piece in ipairs(below) do
                            s.pieces[piece.slot] = true
                        end
                        NoteKit(s, kitName)
                        s.kits = s.kits + 1
                        ShowPanel(MethodText(s))
                        return Finish()
                    end
                    break
                end
            end
        end
        if kit then
            local kitName = zo_strformat("<<1>>", GetItemName(BAG_BACKPACK, kit))
            local tier = GetRepairKitTier(BAG_BACKPACK, kit) or 0
            RepairItemWithRepairKit(BAG_WORN, slot, BAG_BACKPACK, kit)
            NoteKit(s, tier > 0 and string.format("%s (tier %d)", kitName, tier) or kitName)
            s.kits, s.pieces[slot] = s.kits + 1, true
            ShowPanel(MethodText(s))
            return
        end
    end
    -- 3. A Crown kit repairs everything worn; one per session is plenty.
    if IG.RepairGet("repairCrown") and #crown > 0 and s.crown == 0 then
        local crownName = zo_strformat("<<1>>", GetItemName(BAG_BACKPACK, crown[1]))
        if UseCrownKit(crown[1]) then
            s.crown, s.crownName = 1, crownName
            for _, piece in ipairs(below) do
                s.pieces[piece.slot] = true
            end
            ShowPanel(MethodText(s))
            return Finish()
        end
    end
    -- Nothing left for this piece; say so once until something changes.
    s.tries[slot] = REPAIR_TRIES
    if not warned then
        warned = true
        d(string.format("Inventory 2.0: %s is below %d%% and there is nothing to repair it with.",
            GetItemLink(BAG_WORN, slot), tonumber(IG.RepairGet("repairThreshold")) or 25))
    end
end

-- Armour breaks on death, and every trigger that comes with it (durability ticks, leaving
-- combat) arrives while the player is still dead, where Start has to refuse. So a refusal for
-- Busy() keeps looking every REPAIR_RETRY_MS until the player is up and out of combat; the
-- EVENT_PLAYER_ALIVE / EVENT_PLAYER_REINCARNATED handlers below are the second guard.
local function RetryWhenFree()
    EVENT_MANAGER:UnregisterForUpdate(REPAIR_RETRY)
    EVENT_MANAGER:RegisterForUpdate(REPAIR_RETRY, REPAIR_RETRY_MS, function()
        if Busy() then return end
        EVENT_MANAGER:UnregisterForUpdate(REPAIR_RETRY)
        IG.RepairCheck()
    end)
end

local function Start()
    if running or not IG.sv then return end
    if not IG.RepairGet("repairEnabled") and not IG.RepairGet("rechargeEnabled") then return end
    if IG.IsEnabled and not IG.IsEnabled() then return end
    local weapons = #WeaponsBelow()
    if weapons == 0 then gemWarned = false end
    if #WornBelow() == 0 then warned = false if weapons == 0 then return end end
    if Busy() then return RetryWhenFree() end
    running = true
    session = { pieces = {}, kits = 0, gold = 0, crown = 0, tries = {}, kitNames = {}, kitOrder = {},
        charged = {}, gems = 0, weapons = 0 }
    Step()
    if running then EVENT_MANAGER:RegisterForUpdate(REPAIR_UPDATE, REPAIR_INTERVAL, Step) end
end

-- Durability ticks, leaving combat and switches all come here; the last one within the
-- debounce window starts a session.
function IG.RepairCheck()
    EVENT_MANAGER:UnregisterForUpdate(REPAIR_DEBOUNCE)
    EVENT_MANAGER:RegisterForUpdate(REPAIR_DEBOUNCE, REPAIR_DEBOUNCE_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(REPAIR_DEBOUNCE)
        Start()
    end)
end

EVENT_MANAGER:RegisterForEvent(REPAIR_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
    IG.RepairCheck()
end)
EVENT_MANAGER:AddFilterForEvent(REPAIR_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
    REGISTER_FILTER_BAG_ID, BAG_WORN,
    REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DURABILITY_CHANGE)
-- Charge ticks on a worn weapon: a registration of its own, since the filter is per name.
EVENT_MANAGER:RegisterForEvent(REPAIR_EVENT .. "Charge", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
    IG.RepairCheck()
end)
EVENT_MANAGER:AddFilterForEvent(REPAIR_EVENT .. "Charge", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
    REGISTER_FILTER_BAG_ID, BAG_WORN,
    REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_ITEM_CHARGE)
EVENT_MANAGER:RegisterForEvent(REPAIR_EVENT, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
    if inCombat then HidePanel() end
    if not inCombat then IG.RepairCheck() end
end)
EVENT_MANAGER:RegisterForEvent(REPAIR_EVENT, EVENT_OPEN_STORE, function()
    storeOpen = true
    -- A session already running on kits would not look at gold; start again.
    if running then Finish() end
    IG.RepairCheck()
end)
EVENT_MANAGER:RegisterForEvent(REPAIR_EVENT, EVENT_CLOSE_STORE, function()
    storeOpen = false
end)
EVENT_MANAGER:RegisterForEvent(REPAIR_EVENT, EVENT_PLAYER_ACTIVATED, function()
    IG.RepairCheck()
end)
-- Back on your feet after a death: the moment armour most needs it (doc 24250/24259).
EVENT_MANAGER:RegisterForEvent(REPAIR_EVENT, EVENT_PLAYER_ALIVE, function()
    IG.RepairCheck()
end)
EVENT_MANAGER:RegisterForEvent(REPAIR_EVENT, EVENT_PLAYER_REINCARNATED, function()
    IG.RepairCheck()
end)

