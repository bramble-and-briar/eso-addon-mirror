-- RealisticNeedsAndDiseases.lua
-- Core state machine: meters, SavedVariables, the main update loop, food/
-- drink/harvest detection, and slash commands.

RealisticNeeds = RealisticNeeds or {}
local RN = RealisticNeeds

RN.NAME    = "RealisticNeedsAndDiseases"
RN.VERSION = "0.19.32"

-- Keybind display name. Must run at file-parse time (not inside
-- OnAddOnLoaded) — see bindings.xml for the matching Action definition and
-- RN.CheckNeeds() below for the actual handler.
ZO_CreateStringId("SI_BINDING_NAME_RND_CHECK_NEEDS", "Check Needs (RND)")

local SV_DEFAULTS = {
    version = 1,
    needs = { hunger = 100, thirst = 100, fatigue = 100, drunkenness = 0 },
    diseaseState = {},
    -- Per-disease cooldown tracking for tier-1 ("cheap") cure ingredients —
    -- { [diseaseId] = unixTimestampCooldownEndsAt }. Kept separate from
    -- diseaseState since it needs to persist a short while AFTER a disease
    -- is cured (to actually prevent re-cure spam), whereas diseaseState gets
    -- deleted the moment a cure lands. See Disease.TIER1_CURE_COOLDOWN_SECONDS.
    tier1CureCooldowns = {},
    settings = {
        -- Three-tier toggle structure (decoupled — each is independent):
        --   masterEnabled        — true kill switch for the ENTIRE addon
        --                          simulation: needs decay, disease system,
        --                          AND all consumption crediting (food/
        --                          drink/water restoring needs, ingredients
        --                          curing disease). Nothing in sv.needs/
        --                          sv.diseaseState changes while this is
        --                          off, regardless of the two toggles below.
        --   needsSystemEnabled   — independent of diseaseSystemEnabled.
        --                          When off (but masterEnabled stays on):
        --                          hunger/thirst/fatigue/drunkenness decay
        --                          stops AND food/drink/water consumption
        --                          no longer restores them either — needs
        --                          are fully frozen at whatever they were.
        --                          Disease processing (contraction,
        --                          progression, self-cure, curing) is
        --                          entirely unaffected by this toggle.
        --   diseaseSystemEnabled — independent of needsSystemEnabled. When
        --                          off (but masterEnabled stays on): no new
        --                          disease is rolled (exposure-based or
        --                          combat-triggered) via RollContraction in
        --                          Disease.lua (the single choke point both
        --                          contraction paths funnel through), and no
        --                          already-contracted disease can escalate
        --                          in severity or self-cure via OnTick.
        --                          Curing an existing disease with an
        --                          ingredient still works either way — this
        --                          toggle only stops new contraction/
        --                          progression, not treatment. Needs decay/
        --                          restoration is entirely unaffected by
        --                          this toggle. Existing disease state is
        --                          neither deleted nor auto-cured by turning
        --                          this off; see Settings.lua's setFunc for
        --                          the overlay clear/restore that goes with it.
        masterEnabled         = true,
        needsSystemEnabled    = true,
        diseaseSystemEnabled  = true,
        showStatusBar     = true,
        -- Icon-based status display (StatusIconsTransparency.lua) — opt-in
        -- and off by default, runs ALONGSIDE showStatusBar above, not
        -- instead of it. Transparency (not color/pips) indicates severity.
        statusIconsTransparencyEnabled = false,
        statusIconsTransparencyScale = 1.0,       -- Settings slider: overall display size, 0.5-2.0
        statusIconsTransparencyMaxOpacity = 1.0,  -- Settings slider: opacity cap, multiplies with per-icon severity alpha, 0.2-1.0
        -- Bar-based status display (StatusBars.lua) — opt-in and off by
        -- default, mini health-bar-style bars per need/disease. Independent
        -- toggle; can run alongside either of the above.
        statusBarsEnabled = false,
        statusBarsScale = 1.0,    -- Settings slider: overall display size, 0.5-2.0
        statusBarsOpacity = 1.0,  -- Settings slider: overall window opacity, 0.2-1.0
        -- Disease screen-tint overlay (RN.Overlay.lua) — a proportional
        -- multiplier on top of Overlay.MAX_ALPHA_BY_SEVERITY's existing
        -- per-severity ceilings (0.25/0.45/0.75 for Mild/Moderate/Severe),
        -- not a replacement for them. 1.0 = unscaled (matches pre-existing
        -- behavior exactly). Mirrors the same "max opacity" slider pattern
        -- added to Frostfall's hot/cold screen overlay.
        diseaseOverlayMaxOpacity = 1.0,
        showNativeNotifications = true,
        -- Chat logging of notifications is opt-in, separate from the
        -- top-right popups (showNativeNotifications above). Default false —
        -- most feedback is meant to be the popup; chat is an extra someone
        -- turns on deliberately if they want a scrollback log of it too.
        showChatMessages = false,
        coupleToFrostfall = true,
        decayMinutes      = { hunger = 60, thirst = 45, fatigue = 90 },
        restoreAmounts    = { food = 30, drink = 30, harvest = 15, coffeeFatigue = 25 },
        -- frostbite/heatstroke: first roll at the 300s (5-minute) exposure
        -- threshold, then re-rolled every 60s after that for as long as
        -- exposure continues (see Disease.lua's CheckSustainedExposure).
        -- mageBane/fightersBane/thiefsBane: "VERY small chance"
        -- per spec — these four roll PER HIT (not on a timer), so 0.01
        -- there is already meaningfully rarer in practice than
        -- frostbite/heatstroke's once-every-60s-while-exposed 0.10.
        diseaseChances    = { frostbite = 0.10, heatstroke = 0.10, mageBane = 0.01, fightersBane = 0.01, thiefsBane = 0.01 },
        careCureWellFedThreshold = 70,
        careCureDosesRequired    = 5,
        -- emoteChoiceId: resolved real emoteIds (via PLAYER_EMOTE_MANAGER),
        -- not slash-command strings — see Feedback.lua's ResolveEmoteDefaults.
        -- 0 = unresolved; filled in at first load.
        emoteChoiceId = { hunger = 0, thirst = 0, fatigue = 0, disease = 0, drunkenness = 0 },
        enableEmotes = true,
        restStationaryThresholdSeconds = 180,  -- "a few minutes"
        restStationaryRegenPerSecond   = 100 / (15 * 60),  -- full fatigue over 15 min of standing still
        restSeatedThresholdSeconds     = 60,   -- "a minute"
        restSeatedRegenPerSecond       = 100 / (8 * 60),   -- full fatigue over 8 min seated — faster than standing
        restSleepThresholdSeconds      = 60,   -- "for a bit"
        drunkennessPerDrink            = 15,
        drunkennessBaselineDecayPerSecond = 100 / (2 * 3600),  -- sobers up over ~2 hours unaided
        drunkennessRestMultiplier      = 4,  -- resting (any of the 3 mechanics) sobers you up 4x faster
    },
}

local TICK_INTERVAL_MS = 5000

-- ─────────────────────────────────────────────────────────────────────────────
-- Shared trade-window state (used by this file and Disease.lua)
-- ─────────────────────────────────────────────────────────────────────────────
local _isMerchantOpen, _isCraftingStationOpen, _isBankOpen = false, false, false

function RN.IsTradeWindowOpen()
    return _isMerchantOpen or _isCraftingStationOpen or _isBankOpen
end

-- Registered inside OnAddOnLoaded below (see "INITIALIZATION" section) —
-- not here at file scope, so RN.SavedVars is guaranteed to exist before any
-- of these can fire.

local function ClampNeed(value)
    return math.max(0, math.min(100, value))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Food/drink consumption → restore hunger/thirst (amounts now player-adjustable)
-- ─────────────────────────────────────────────────────────────────────────────
local function MatchesKeyword(name, keywordList)
    local lower = name:lower()
    for _, keyword in ipairs(keywordList) do
        if lower:find(keyword, 1, true) then return true end
    end
    return false
end

-- Stack-size SNAPSHOT comparison, not the stackCountChange parameter. The
-- previous design trusted stackCountChange < 0 to mean "consumed," but
-- real-world testing showed consumption never registered at all — strongly
-- suggesting that parameter doesn't behave the way it was assumed to here.
--
-- Buff-gained CONFIRMATION gate, layered on top of the inventory stack
-- tracking below — this is the actual fix, ported from a real working
-- pattern (not guessed): listening for EVENT_EFFECT_CHANGED and checking
-- LibFoodDrinkBuff:IsAbilityAFoodOrDrinkBuff(abilityId) tells you reliably
-- that the player just ACTUALLY ATE/DRANK something (ESO grants a real buff
-- effect for it), as opposed to an inventory change from selling, trading,
-- depositing, or some other non-consumption removal. The inventory-slot
-- tracking below still does the job of identifying WHICH item was consumed
-- (the buff event alone doesn't say that) — but is only trusted as a real
-- consumption when it happens within BUFF_APPLICATION_WINDOW ms of a
-- confirmed buff-gain. This is why LibFoodDrinkBuff is now a REQUIRED
-- dependency rather than optional — there's no reliable fallback for this
-- specific confirmation signal.
--
-- BIDIRECTIONAL: ESO does not guarantee EVENT_EFFECT_CHANGED (buff granted)
-- and EVENT_INVENTORY_SINGLE_SLOT_UPDATE (stack shrinks) fire in a fixed
-- order relative to each other. The original check only looked BACKWARD
-- (was a buff granted recently, as of the inventory event?), so whenever
-- the inventory event happened to be processed first, the buff timestamp
-- wasn't set yet, the gate rejected a genuine consumption, and that
-- restore was silently lost — no error, no trace, just a drink that
-- "didn't work." The _pendingConsumptions queue below covers the other
-- direction: if the inventory shrink arrives with no recent buff, it's held
-- (not dropped) for BUFF_APPLICATION_WINDOW_MS so a buff event that arrives
-- shortly AFTER can still credit it retroactively. It's a queue rather than
-- a single value so that eating a food and a drink back-to-back — a very
-- common combo in ESO — queues two independent pending entries instead of
-- the second silently overwriting and losing the first.
--
-- LibFoodDrinkBuff:IsAbilityAFoodOrDrinkBuff(abilityId) — real, confirmed method.
-- EVENT_EFFECT_CHANGED parameter order and EFFECT_RESULT_GAINED/UPDATED — real, confirmed constants.
local BUFF_APPLICATION_WINDOW_MS = 500
local _lastFoodDrinkBuffTimeMs = 0

-- Forward-declared: OnFoodDrinkBuffChanged (below) can credit a pending
-- consumption before HandleConsumedItem's actual definition is reached
-- further down this file; the assignment there fills this in.
local HandleConsumedItem

-- Holds one entry per { itemType, specializedItemType, itemName, timeMs }
-- inventory shrink that looked like food/drink consumption but hadn't yet
-- seen a confirming buff event when it was detected. This is a QUEUE, not a
-- single slot — a player very commonly eats a food AND a drink back-to-back
-- (to get the combined buff), which produces two pending shrinks within
-- milliseconds of each other. A single-value "pending" would have the second
-- shrink silently clobber the first before it could be confirmed, permanently
-- losing that consumption (or worse, getting it wrongly credited to the other
-- item's buff confirmation). Entries are removed once credited, and stale
-- entries (older than BUFF_APPLICATION_WINDOW_MS with no matching buff ever
-- seen) are pruned so the queue can't grow unbounded.
local _pendingConsumptions = {}

local function PruneStalePendingConsumptions()
    local now = GetGameTimeMilliseconds()
    for i = #_pendingConsumptions, 1, -1 do
        if now - _pendingConsumptions[i].timeMs > BUFF_APPLICATION_WINDOW_MS then
            table.remove(_pendingConsumptions, i)
        end
    end
end

local function OnFoodDrinkBuffChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime,
                                       stackCount, iconName, buffType, effectType, abilityType, statusEffectType,
                                       unitName, unitId, abilityId, sourceType)
    if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED then return end
    if LibFoodDrinkBuff:IsAbilityAFoodOrDrinkBuff(abilityId) then
        _lastFoodDrinkBuffTimeMs = GetGameTimeMilliseconds()

        -- Forward direction: one or more pending inventory shrinks were
        -- waiting on a confirmation. Each real food/drink buff-gained event
        -- corresponds to exactly one real consumption, so credit the OLDEST
        -- still-valid pending entry (FIFO) — this pairs buff events to
        -- pending shrinks 1:1 even when several were consumed in quick
        -- succession, regardless of which buff happens to arrive first.
        PruneStalePendingConsumptions()
        local entry = table.remove(_pendingConsumptions, 1)
        if entry then
            HandleConsumedItem(entry.itemType, entry.specializedItemType, entry.itemName, RN.SavedVars)
        end
    end
end

-- Registered inside OnAddOnLoaded below, not here at file scope.

local function RecentlyGrantedFoodDrinkBuff()
    return (GetGameTimeMilliseconds() - _lastFoodDrinkBuffTimeMs) <= BUFF_APPLICATION_WINDOW_MS
end

-- Tracks { itemId, itemType, specializedItemType, itemName, size } per slot
-- (not just a raw link/count) so we can tell the difference between "this
-- slot's stack shrank" (consumption) and "a different item now occupies
-- this slot" (items can shift slots). Also explicitly handles the "slot is
-- now completely empty" case — the last unit of a stack being consumed
-- doesn't leave a link behind to read a type from, so the PREVIOUS cached
-- state (not the current empty slot) is what tells us what was consumed.
local _lastSlotState = {}

HandleConsumedItem = function(itemType, specializedItemType, itemName, sv)
    -- Consumption crediting follows the same masterEnabled/needsSystemEnabled
    -- gating as decay in OnTick — if needs are frozen (either toggle off),
    -- eating/drinking shouldn't silently move a number nobody's tracking.
    if sv.settings.masterEnabled == false or sv.settings.needsSystemEnabled == false then return end

    if itemType == ITEMTYPE_FOOD then
        sv.needs.hunger = ClampNeed(sv.needs.hunger + sv.settings.restoreAmounts.food)
        RN.Feedback.CheckBandTransition(sv, "hunger", sv.needs.hunger)
    elseif itemType == ITEMTYPE_DRINK then
        sv.needs.thirst = ClampNeed(sv.needs.thirst + sv.settings.restoreAmounts.drink)
        RN.Feedback.CheckBandTransition(sv, "thirst", sv.needs.thirst)

        -- Drunkenness mechanic: alcoholic prepared drinks build up drunkenness.
        -- Name-keyword match sourced from Spoilage's DrinkAlcohol list (see Data.lua).
        -- Raw provisioning ingredients (ITEMTYPE_INGREDIENT) are intentionally excluded —
        -- they are used at a crafting station, not consumed directly by the player.
        if MatchesKeyword(itemName, RN.ALCOHOL_KEYWORDS) then
            sv.needs.drunkenness = math.min(100, sv.needs.drunkenness + sv.settings.drunkennessPerDrink)
            RN.Feedback.Notify(string.format("The %s goes straight to your head.", itemName), { chatOnly = true })
            RN.Feedback.CheckBandTransition(sv, "drunkenness", sv.needs.drunkenness)
        end

        -- Coffee mechanic: coffee additionally restores fatigue.
        if MatchesKeyword(itemName, RN.COFFEE_KEYWORDS) then
            sv.needs.fatigue = ClampNeed(sv.needs.fatigue + sv.settings.restoreAmounts.coffeeFatigue)
            RN.Feedback.Notify(string.format("The %s perks you right up.", itemName), { chatOnly = true })
            RN.Feedback.CheckBandTransition(sv, "fatigue", sv.needs.fatigue)
        end
    end
end

local function OnFoodDrinkInventoryChange(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    if bagId ~= BAG_BACKPACK then return end

    -- Trade-window gating suppresses CREDITING only — it must NOT skip the
    -- _lastSlotState refresh further down. Before 0.19.32 this was an early
    -- `return`, so any stack change made while a merchant, crafting station,
    -- or bank was open (buying food, CRAFTING food/drink at a provisioning
    -- station, withdrawing from the bank) never reached the cache. The cache
    -- was left stale (old, smaller size) or empty (new slot), so the first
    -- food/drink eaten from that stack afterward compared against bad data —
    -- newSize was not < the stale size, or prevState was nil — and was
    -- silently dropped; the second one worked because the first event had
    -- refreshed the cache. Disease.OnRemedyInventoryChange already updates
    -- its own cache before its trade-window check; this now matches it.
    local suppressCrediting = RN.IsTradeWindowOpen()

    local sv = RN.SavedVars
    local key = bagId .. ":" .. slotId
    local currentLink = GetItemLink(bagId, slotId)
    local prevState = _lastSlotState[key]

    local function MaybeHandleConsumption(itemType, specializedItemType, itemName)
        if suppressCrediting then return end
        local isFoodOrDrink = (itemType == ITEMTYPE_FOOD) or (itemType == ITEMTYPE_DRINK)
        if not isFoodOrDrink then return end
        -- Only trust the inventory-shrink signal if a real food/drink buff was JUST
        -- granted — this rules out selling, banking, or stack splits which also fire
        -- EVENT_INVENTORY_SINGLE_SLOT_UPDATE with a decreased count. The trade-window
        -- guard above already handles the common cases; the buff gate is a
        -- belt-and-suspenders check for edge cases.
        --
        -- BACKWARD direction: a buff already arrived before this inventory
        -- event, so credit immediately, same as before. This does NOT touch
        -- the pending queue — any other in-flight consumption still waiting
        -- on its own buff confirmation is left alone.
        if RecentlyGrantedFoodDrinkBuff() then
            HandleConsumedItem(itemType, specializedItemType, itemName, sv)
            return
        end
        -- FORWARD direction: no recent buff yet, but ESO doesn't guarantee
        -- the buff event arrives first — queue this shrink as pending so
        -- OnFoodDrinkBuffChanged can still credit it once its buff shows up,
        -- within BUFF_APPLICATION_WINDOW_MS. Appended (not overwritten), so
        -- consuming a food and a drink back-to-back queues two independent
        -- entries instead of the second wiping out the first.
        PruneStalePendingConsumptions()
        table.insert(_pendingConsumptions, {
            itemType             = itemType,
            specializedItemType  = specializedItemType,
            itemName             = itemName,
            timeMs               = GetGameTimeMilliseconds(),
        })
    end

    if currentLink and currentLink ~= "" then
        local currentItemId = GetItemLinkItemId(currentLink)
        local newSize = GetSlotStackSize(bagId, slotId) or 0

        if prevState and prevState.itemId == currentItemId and newSize < prevState.size then
            MaybeHandleConsumption(prevState.itemType, prevState.specializedItemType, prevState.itemName)
        end

        local itemType, specializedItemType = GetItemLinkItemType(currentLink)
        _lastSlotState[key] = {
            itemId              = currentItemId,
            itemType            = itemType,
            specializedItemType = specializedItemType,
            itemName            = GetItemLinkName(currentLink) or "",
            size                = newSize,
        }
    else
        if prevState and prevState.size and prevState.size > 0 then
            MaybeHandleConsumption(prevState.itemType, prevState.specializedItemType, prevState.itemName)
        end
        _lastSlotState[key] = nil
    end
end

-- Registered inside OnAddOnLoaded below, not here at file scope.

-- Pre-populate _lastSlotState for every occupied backpack slot when the player
-- enters the world. Without this seed pass, the snapshot comparison in
-- OnFoodDrinkInventoryChange falls through on the FIRST consumption in a session
-- for any given slot (prevState is nil → the "stack shrank" branch is never
-- entered → the drink is silently ignored). RolePlayNeeds uses the same fix:
-- ForceInventoryScan() called from EVENT_PLAYER_ACTIVATED seeds their
-- lastInventoryState table before any inventory event can fire.
--
-- EVENT_PLAYER_ACTIVATED fires after SavedVariables are ready and after the
-- player's inventory is fully populated, making it the right moment for this.
-- One-shot: unregister immediately after the first activation so the seed pass
-- doesn't re-run on zone transitions (which would reset prevState and create
-- false "stack shrank" comparisons for any item picked up mid-zone).
local function SeedLastSlotState()
    for slotId = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if HasItemInSlot(BAG_BACKPACK, slotId) then
            local link = GetItemLink(BAG_BACKPACK, slotId)
            if link and link ~= "" then
                local key = BAG_BACKPACK .. ":" .. slotId
                local itemType, specializedItemType = GetItemLinkItemType(link)
                _lastSlotState[key] = {
                    itemId              = GetItemLinkItemId(link),
                    itemType            = itemType,
                    specializedItemType = specializedItemType,
                    itemName            = GetItemLinkName(link) or "",
                    size                = GetSlotStackSize(BAG_BACKPACK, slotId) or 0,
                }
            end
        end
    end
end

-- Registered inside OnAddOnLoaded below, not here at file scope.

-- ─────────────────────────────────────────────────────────────────────────────
-- LibFoodDrinkBuff status check (now a required dependency — see manifest)
-- ─────────────────────────────────────────────────────────────────────────────
function RN.IsLibFoodDrinkBuffAvailable()
    return LibFoodDrinkBuff ~= nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Harvesting alchemy water nodes → restore thirst directly (amount adjustable)
--
-- Parameter order confirmed against the official ESOUIDocumentation.txt
-- (API 101050): EVENT_LOOT_RECEIVED(eventId, receivedBy, itemName,
-- quantity, soundCategory, lootType, isSelf, isPickpocketLoot,
-- questItemIcon, itemId, isStolen). Position 3 is the item's plain display
-- name (a string), not a formatted item link -- an earlier version of this
-- handler mislabeled it "itemLink" and passed it to GetItemLinkName(),
-- which expects an actual link string and would have failed to parse a
-- bare name, silently falling back to the generic "water source" text
-- every time. It's used directly now.
--
-- CORRECTED: a previous version of this comment claimed "project history
-- (RolePlayNeeds 0.7.7→0.7.8) needed a two-stage EVENT_LOOT_RECEIVED +
-- inventory-update confirmation to reliably detect water-node harvesting."
-- RolePlayNeeds' actual published source (checked directly against the
-- official v0.7 BETA release) uses a single EVENT_LOOT_RECEIVED handler
-- with no second inventory-update confirmation stage at all — this
-- two-stage approach was never in the published addon. It was an idea
-- from a local, personally-modified copy of RolePlayNeeds, not something
-- that actually shipped, so the attribution was incorrect. This is a
-- simpler single-stage v1; add a second-stage confirmation if testing
-- turns up false positives/negatives.
-- ─────────────────────────────────────────────────────────────────────────────
local function OnLootReceived(eventCode, receivedBy, itemName, stackCount, soundCategory, lootType,
                               lootedBySelf, isPickpocketLoot, questItemIcon, itemId)
    if not lootedBySelf then return end
    if not itemId or not RN.ALCHEMY_WATER_SOLVENT_IDS[itemId] then return end

    local sv = RN.SavedVars
    -- Same needs-frozen gating as HandleConsumedItem — see the comment there.
    if sv.settings.masterEnabled == false or sv.settings.needsSystemEnabled == false then return end

    -- A restore amount of 0 (the slider's new floor) means the player has
    -- deliberately disabled this mechanic entirely — skip both the (now
    -- zero, no-op) restore and the chat message, rather than announcing an
    -- effect that didn't actually happen.
    local restoreAmount = sv.settings.restoreAmounts.harvest
    if restoreAmount <= 0 then return end

    sv.needs.thirst = ClampNeed(sv.needs.thirst + restoreAmount)
    RN.Feedback.CheckBandTransition(sv, "thirst", sv.needs.thirst)
    RN.Feedback.Notify(string.format(
        "You drink from the %s, easing your thirst.",
        itemName or "water source"
    ), { chatOnly = true })  -- chat-only: harvesting can be frequent, a toast every time would be noisy
end

-- Registered inside OnAddOnLoaded below, not here at file scope.

-- ─────────────────────────────────────────────────────────────────────────────
-- Main update loop
-- ─────────────────────────────────────────────────────────────────────────────
local function OnTick()
    local sv = RN.SavedVars

    -- True kill switch (Settings panel): when disabled, skip needs decay,
    -- disease processing, and the status bar entirely — nothing in
    -- sv.needs/sv.diseaseState changes while this is off, regardless of
    -- the two independent toggles below. See Settings.lua's setFunc for
    -- the toggle that also hides the status bar and clears any visible
    -- disease overlays the moment this is switched off.
    if sv.settings.masterEnabled == false then return end

    local tickSeconds = TICK_INTERVAL_MS / 1000

    -- Independent of diseaseSystemEnabled below — see the settings default
    -- comment block for the full three-tier breakdown.
    if sv.settings.needsSystemEnabled ~= false then
        local hungerRate  = RN.Calculator.GetBaseRatePerSecond(sv, "hunger")
        local thirstRate  = RN.Calculator.GetBaseRatePerSecond(sv, "thirst")
        local fatigueRate = RN.Calculator.GetBaseRatePerSecond(sv, "fatigue")

        if sv.settings.coupleToFrostfall then
            hungerRate  = RN.Calculator.GetHungerDecayRate(hungerRate)
            thirstRate  = RN.Calculator.GetThirstDecayRate(thirstRate)
            fatigueRate = RN.Calculator.GetFatigueDecayRate(fatigueRate)
        end

        sv.needs.hunger  = ClampNeed(sv.needs.hunger  - hungerRate  * tickSeconds)
        sv.needs.thirst  = ClampNeed(sv.needs.thirst  - thirstRate  * tickSeconds)
        sv.needs.fatigue = ClampNeed(sv.needs.fatigue - fatigueRate * tickSeconds)

        -- Drunkenness (#1): baseline decay always applies; RN.Rest accelerates
        -- this further while the player is resting (any of its 3 mechanics) —
        -- see RealisticNeedsAndDiseases_Rest.lua's drunkenness handling.
        local drunkDecay = sv.settings.drunkennessBaselineDecayPerSecond * tickSeconds
        sv.needs.drunkenness = math.max(0, sv.needs.drunkenness - drunkDecay)

        RN.Feedback.CheckBandTransition(sv, "hunger", sv.needs.hunger)
        RN.Feedback.CheckBandTransition(sv, "thirst", sv.needs.thirst)
        RN.Feedback.CheckBandTransition(sv, "fatigue", sv.needs.fatigue)
        RN.Feedback.CheckBandTransition(sv, "drunkenness", sv.needs.drunkenness)
        RN.Feedback.EmoteTick(sv)

        -- Purely a needs mechanic (resting restores fatigue, accelerates
        -- drunkenness decay) — never touches sv.diseaseState, so it belongs
        -- under this toggle, not diseaseSystemEnabled.
        RN.Rest.OnTick(sv, tickSeconds)
    end

    -- Independent of needsSystemEnabled above. RN.Disease.OnTick drives
    -- sustained cold/heat exposure contraction, untreated-disease stage
    -- progression, and frostbite/heatstroke self-cure — all gated on this
    -- toggle alone now, rather than being silently skipped whenever needs
    -- decay happened to be off.
    if sv.settings.diseaseSystemEnabled ~= false then
        RN.Disease.OnTick(sv, tickSeconds)
    end

    if RN.StatusBar and RN.StatusBar.Refresh then
        RN.StatusBar.Refresh(sv)
    end
    if RN.StatusIconsTransparency and RN.StatusIconsTransparency.Refresh then
        RN.StatusIconsTransparency.Refresh(sv)
    end
    if RN.StatusBars and RN.StatusBars.Refresh then
        RN.StatusBars.Refresh(sv)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Slash commands — unified under /rnd.
-- ─────────────────────────────────────────────────────────────────────────────
local function PrintCheckNeeds()
    local sv = RN.SavedVars
    if sv.settings.masterEnabled == false then
        CHAT_SYSTEM:AddMessage("|c88CCFF[Realistic Needs and Diseases]|r The addon is currently turned off (Settings > Realistic Needs and Diseases). Values shown below are frozen from when it was last active.")
    else
        if sv.settings.needsSystemEnabled == false then
            CHAT_SYSTEM:AddMessage("|c88CCFF[Realistic Needs and Diseases]|r Needs tracking is currently turned off (Settings > Realistic Needs and Diseases). Values shown below are frozen from when it was last active; the disease system below is unaffected.")
        end
        if sv.settings.diseaseSystemEnabled == false then
            CHAT_SYSTEM:AddMessage("|c88CCFF[Realistic Needs and Diseases]|r The disease system is currently turned off (Settings > Realistic Needs and Diseases). No new diseases can be contracted and existing ones won't worsen or self-cure, but curing one with an ingredient still works; needs tracking above is unaffected.")
        end
    end
    CHAT_SYSTEM:AddMessage(string.format(
        "|c88CCFF[Realistic Needs and Diseases]|r Hunger: %d (%s)",
        math.floor(sv.needs.hunger), RN.Feedback.GetBandMessage("hunger", sv.needs.hunger)
    ))
    CHAT_SYSTEM:AddMessage(string.format(
        "  Thirst: %d (%s)", math.floor(sv.needs.thirst), RN.Feedback.GetBandMessage("thirst", sv.needs.thirst)
    ))
    CHAT_SYSTEM:AddMessage(string.format(
        "  Fatigue: %d (%s)", math.floor(sv.needs.fatigue), RN.Feedback.GetBandMessage("fatigue", sv.needs.fatigue)
    ))
    CHAT_SYSTEM:AddMessage(string.format(
        "  Drunkenness: %d (%s)", math.floor(sv.needs.drunkenness), RN.Feedback.GetBandMessage("drunkenness", sv.needs.drunkenness)
    ))
    local temp, source = RN.Calculator.GetCurrentTemperature()
    if temp then
        CHAT_SYSTEM:AddMessage(string.format("  Temperature source: %s (%.1f°C)", source, temp))
    else
        CHAT_SYSTEM:AddMessage("  Temperature source: none (flat baseline rates only)")
    end
    local any = false
    for diseaseId, state in pairs(sv.diseaseState) do
        any = true
        local def = RN.Diseases[diseaseId]
        local severityName = ({ "Mild", "Moderate", "Severe" })[state.severity] or "?"
        local tier1Entries = def and def.remedyIngredients[1]
        local tier1Name = (tier1Entries and tier1Entries[1] and tier1Entries[1].name) or "?"
        CHAT_SYSTEM:AddMessage(string.format(
            "  Disease: %s (%s) — care-cure progress: %d/%d doses of %s",
            def and def.name or diseaseId, severityName,
            state.careCureProgress or 0, sv.settings.careCureDosesRequired, tier1Name
        ))
    end
    if not any then
        CHAT_SYSTEM:AddMessage("  No active diseases.")
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Toast-style status check — same underlying data as PrintCheckNeeds, but
-- fires one top-right ZO_Alert popup per need category and per active
-- disease, with NO chat output at all (Feedback.NotifyAlertOnly, not
-- Feedback.Notify), and NO category label prefix — just the band message /
-- disease name + severity directly. This is what the bare "/checkneeds"
-- command and the keybind (RealisticNeeds.CheckNeeds, see bindings.xml) trigger.
-- Drunkenness is only included when the player isn't completely sober
-- (needs.drunkenness > 0) — no point alerting "stone sober" every time.
-- ─────────────────────────────────────────────────────────────────────────────
local function NotifyCurrentStatus()
    local sv = RN.SavedVars
    if sv.settings.masterEnabled == false then
        RN.Feedback.NotifyAlertOnly("The addon is currently turned off (Settings > Realistic Needs and Diseases).")
        return
    end

    if sv.settings.needsSystemEnabled ~= false then
        RN.Feedback.NotifyAlertOnly(RN.Feedback.GetBandMessage("hunger", sv.needs.hunger))
        RN.Feedback.NotifyAlertOnly(RN.Feedback.GetBandMessage("thirst", sv.needs.thirst))
        RN.Feedback.NotifyAlertOnly(RN.Feedback.GetBandMessage("fatigue", sv.needs.fatigue))
        if sv.needs.drunkenness > 0 then
            RN.Feedback.NotifyAlertOnly(RN.Feedback.GetBandMessage("drunkenness", sv.needs.drunkenness))
        end
    end

    local any = false
    for diseaseId, state in pairs(sv.diseaseState) do
        any = true
        local def = RN.Diseases[diseaseId]
        local severityName = ({ "Mild", "Moderate", "Severe" })[state.severity] or "?"
        local hint = RN.Feedback.GetCureHintText(diseaseId, state.severity)
        RN.Feedback.NotifyAlertOnly(string.format(
            "%s (%s)%s", def and def.name or diseaseId, severityName, hint and (" — " .. hint) or ""
        ))
    end
    if not any then
        RN.Feedback.NotifyAlertOnly("No active diseases.")
    end
end

local function BuildDiseaseDebugUsageLine()
    -- Built dynamically from RN.DISEASE_ORDER/RN.Diseases rather than a
    -- hardcoded string, so this can't drift out of sync with Data.lua again
    -- (an earlier hardcoded version of this line went stale after a disease
    -- rename and had to be caught and fixed manually).
    local parts = {}
    for index, diseaseId in ipairs(RN.DISEASE_ORDER) do
        local def = RN.Diseases[diseaseId]
        table.insert(parts, string.format("%d=%s", index, def and def.name or diseaseId))
    end
    return string.format("/rnd debug disease <1-%d> <1-3> — directly set a disease's severity (%s). severity 0 clears it.",
        #RN.DISEASE_ORDER, table.concat(parts, ", "))
end

local function PrintDebugUsage()
    CHAT_SYSTEM:AddMessage("|c88CCFF[Realistic Needs and Diseases]|r /rnd debug usage:")
    CHAT_SYSTEM:AddMessage("  /rnd debug checkneeds      — print exact numeric hunger/thirst/fatigue/drunkenness/disease values and care-cure progress to chat. For a quick glance without numbers, use the bare /checkneeds command or its keybind instead.")
    CHAT_SYSTEM:AddMessage("  " .. BuildDiseaseDebugUsageLine())
    CHAT_SYSTEM:AddMessage("  /rnd debug frostbiteTimer  — print how long until Frostbite's next contraction roll (or whether you're even currently exposed)")
    CHAT_SYSTEM:AddMessage("  /rnd debug heatstrokeTimer — same as frostbiteTimer, for Heatstroke")
    CHAT_SYSTEM:AddMessage("  /rnd debug curedisease     — clears all active diseases (does not touch needs)")
    CHAT_SYSTEM:AddMessage(string.format(
        "  /rnd debug skipprogression <1-%d> — fast-forwards that disease's untreated-stage progression timer to one tick (~5s) before both its 30-minute threshold and its 5-minute reroll interval, so the very next tick rolls its escalation chance immediately instead of waiting up to 35 minutes. Disease must already be active and below Severe.",
        #RN.DISEASE_ORDER))
    CHAT_SYSTEM:AddMessage("  /rnd debug resetneeds      — resets hunger/thirst/fatigue/drunkenness to their full/sober defaults (does not touch diseases)")
    CHAT_SYSTEM:AddMessage("  /rnd debug emptyNeeds      — drops hunger/thirst/fatigue/drunkenness to their worst values, for quickly testing recovery mechanisms (does not touch diseases)")
end

-- Shared by the frostbiteTimer/heatstrokeTimer debug commands below. kind is
-- "cold" or "heat"; label/diseaseId/unitDescription are just for the printed
-- text. Pulls from Disease.GetSustainedExposureStatus, which reads the SAME
-- exposureSeconds counter CheckSustainedCold/CheckSustainedHeat themselves
-- use — this is a read-only view of the real state, not a separate/parallel
-- estimate that could drift out of sync with it.
local function PrintExposureTimer(kind, diseaseId, label)
    local sv = RN.SavedVars
    local status = RN.Disease.GetSustainedExposureStatus(kind, sv)
    local def = RN.Diseases[diseaseId]
    local chance = sv.settings.diseaseChances[diseaseId]
    local chancePercentText = chance and string.format("%.1f%%", chance * 100) or "unknown"

    if not status.temp then
        CHAT_SYSTEM:AddMessage(string.format(
            "|c88CCFF[Realistic Needs and Diseases]|r %s timer: couldn't read current temperature right now.", label))
        return
    end

    if not status.exposed then
        CHAT_SYSTEM:AddMessage(string.format(
            "|c88CCFF[Realistic Needs and Diseases]|r %s timer: not currently exposed (current temp %.1f°C). No countdown is running — the exposure timer resets to 0 the moment you're outside the trigger range, so it only starts counting again once you re-enter it.",
            label, status.temp))
        return
    end

    if status.contracted then
        CHAT_SYSTEM:AddMessage(string.format(
            "|c88CCFF[Realistic Needs and Diseases]|r %s timer: currently exposed (temp %.1f°C), but you already have %s — the re-roll has stopped per design (it only resumes after this case is cured, and starts a fresh %ds wait from there).",
            label, status.temp, def and def.name or diseaseId, status.thresholdSeconds))
        return
    end

    if not status.pastThreshold then
        CHAT_SYSTEM:AddMessage(string.format(
            "|c88CCFF[Realistic Needs and Diseases]|r %s timer: currently exposed (temp %.1f°C), in the initial waiting period. %.0fs elapsed / %ds threshold — %.0fs until the FIRST contraction roll. After that, it will re-roll every %ds for as long as you stay exposed, until you either contract %s or leave the trigger range.",
            label, status.temp, status.elapsedSeconds, status.thresholdSeconds, status.remainingSeconds,
            status.rerollIntervalSeconds, def and def.name or diseaseId))
        return
    end

    CHAT_SYSTEM:AddMessage(string.format(
        "|c88CCFF[Realistic Needs and Diseases]|r %s timer: currently exposed (temp %.1f°C), past the initial threshold and now re-rolling repeatedly. %.0fs since last roll attempt — %.0fs until next roll (%s chance of actually contracting %s each time it fires). This keeps repeating every %ds until you either contract it or leave the trigger range.",
        label, status.temp, status.rollTimerSeconds, status.remainingSeconds,
        chancePercentText, def and def.name or diseaseId, status.rerollIntervalSeconds))
end

local function HandleDebugCommand(arg2, arg3, arg4)
    if arg2 == "checkneeds" then
        PrintCheckNeeds()
    elseif arg2 == "disease" then
        local index = tonumber(arg3)
        local severity = tonumber(arg4)
        local diseaseId = index and RN.DISEASE_ORDER[index]
        if not diseaseId then
            CHAT_SYSTEM:AddMessage("|c88CCFF[Realistic Needs and Diseases]|r Invalid disease index. Use 1-6 (see /rnd debug for the list).")
            return
        end
        RN.Disease.SetSeverityDirect(RN.SavedVars, diseaseId, severity)
    elseif arg2 == "frostbitetimer" then
        PrintExposureTimer("cold", "frostbite", "Frostbite")
    elseif arg2 == "heatstroketimer" then
        PrintExposureTimer("heat", "heatstroke", "Heatstroke")
    elseif arg2 == "curedisease" then
        local sv = RN.SavedVars
        for diseaseId in pairs(sv.diseaseState) do
            RN.Disease.SetSeverityDirect(sv, diseaseId, 0)
        end
        RN.Feedback.Notify("[debug] All diseases cleared.")
    elseif arg2 == "skipprogression" then
        local index = tonumber(arg3)
        local diseaseId = index and RN.DISEASE_ORDER[index]
        local def = diseaseId and RN.Diseases[diseaseId]
        if not diseaseId then
            CHAT_SYSTEM:AddMessage(string.format(
                "|c88CCFF[Realistic Needs and Diseases]|r Invalid disease index. Use 1-%d (see /rnd debug for the list).",
                #RN.DISEASE_ORDER))
            return
        end

        local sv = RN.SavedVars
        local state = sv.diseaseState[diseaseId]
        if not state then
            CHAT_SYSTEM:AddMessage(string.format(
                "|c88CCFF[Realistic Needs and Diseases]|r %s isn't currently active — use /rnd debug disease first to give yourself a case to test progression on.",
                def and def.name or diseaseId))
            return
        end
        if state.severity >= RN.SEVERITY_SEVERE then
            CHAT_SYSTEM:AddMessage(string.format(
                "|c88CCFF[Realistic Needs and Diseases]|r %s is already Severe — there's no higher stage for it to progress to.",
                def and def.name or diseaseId))
            return
        end

        -- Set both counters to one tick short of their own threshold. On the
        -- very next OnTick (~5s away), CheckProgression's own tickSeconds
        -- increment pushes progressionSeconds over PROGRESSION_THRESHOLD_SECONDS
        -- AND, in that same pass, pushes progressionRollSeconds over
        -- PROGRESSION_REROLL_INTERVAL_SECONDS — so the escalation roll fires
        -- immediately instead of only starting its 5-minute reroll clock.
        -- Real play never has both timers this close together at once (the
        -- reroll clock doesn't even start accumulating until AFTER the
        -- threshold is crossed) — this is purely a test shortcut.
        local tickSeconds = TICK_INTERVAL_MS / 1000
        state.progressionSeconds = RN.Disease.PROGRESSION_THRESHOLD_SECONDS - tickSeconds
        state.progressionRollSeconds = RN.Disease.PROGRESSION_REROLL_INTERVAL_SECONDS - tickSeconds
        RN.Feedback.Notify(string.format(
            "[debug] %s's progression timer skipped to just before threshold — next tick (~%.0fs) rolls a %.0f%% chance to worsen.",
            def and def.name or diseaseId, tickSeconds, RN.Disease.PROGRESSION_CHANCE * 100))
    elseif arg2 == "resetneeds" then
        local sv = RN.SavedVars
        sv.needs.hunger, sv.needs.thirst, sv.needs.fatigue, sv.needs.drunkenness = 100, 100, 100, 0
        RN.Feedback.Notify("[debug] Needs reset to full/sober.")
    elseif arg2 == "emptyneeds" then
        -- Inverse of resetneeds — drops hunger/thirst/fatigue to their worst
        -- value (0) and drunkenness to its worst value (100, since high
        -- drunkenness is the bad state — see Feedback.GetBand). Intended for
        -- quickly reaching the point where the fatigue-recovery mechanics
        -- (standing still, sitting, sleeping) and the other need-recovery
        -- mechanics actually have something to recover, without waiting for
        -- real decay. Does not touch diseases — use /rnd debug disease or
        -- /rnd debug curedisease for those.
        local sv = RN.SavedVars
        sv.needs.hunger, sv.needs.thirst, sv.needs.fatigue, sv.needs.drunkenness = 0, 0, 0, 100
        RN.Feedback.Notify("[debug] Needs dropped to their worst values.")
    else
        PrintDebugUsage()
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Keybind support — lets the bare /checkneeds notification flow be bound to
-- a hotkey via
-- Controls > Keybindings > Realistic Needs and Diseases. The actual keybind
-- definition lives in bindings.xml, which calls RealisticNeeds.CheckNeeds()
-- (the actual global table, not the local RN alias below — bindings.xml's
-- <Down> expression has no access to a Lua file's local variables, only to
-- whatever's actually in _G) from its <Down> handler.
-- ─────────────────────────────────────────────────────────────────────────────
function RN.CheckNeeds()
    NotifyCurrentStatus()
end

SLASH_COMMANDS["/checkneeds"] = function()
    NotifyCurrentStatus()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- /healersguide — opens the addon's settings panel directly to the Healer's
-- Guide submenu. Uses LAM2's OpenToPanel to navigate straight there so the
-- player doesn't have to hunt through the full settings list.
-- ─────────────────────────────────────────────────────────────────────────────
SLASH_COMMANDS["/healersguide"] = function()
    local LAM = LibAddonMenu2
    if not LAM then
        CHAT_SYSTEM:AddMessage("|c88CCFF[Realistic Needs and Diseases]|r LibAddonMenu-2.0 is not loaded — cannot open settings panel.")
        return
    end
    LAM:OpenToPanel(RN.Settings.panelData)
end

SLASH_COMMANDS["/rnd"] = function(args)
    local words = {}
    for word in tostring(args or ""):gmatch("%S+") do
        table.insert(words, word:lower())
    end
    local sub = words[1]

    if sub == "debug" then
        HandleDebugCommand(words[2], words[3], words[4])
    else
        CHAT_SYSTEM:AddMessage("|c88CCFF[Realistic Needs and Diseases]|r Usage: /checkneeds | /healersguide | /rnd debug ... — to rest, just sit or sleep normally (any native /sit-/sleep-family emote, or a real chair/bench) and fatigue recovery kicks in automatically.")
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Initialization
-- ─────────────────────────────────────────────────────────────────────────────
-- Recursively fills any keys missing from `target` using values from `defaults`,
-- without ever overwriting a key that already exists in `target`. This is the
-- defensive complement to ZO_SavedVars:NewAccountWide.
--
-- Why this is necessary:
-- ZO_SavedVars performs only a SHALLOW merge at the top level — it checks whether
-- a top-level key is present in the loaded data and fills it from defaults if
-- absent, but for TABLE values it treats the key as atomic: if `sv.needs` exists
-- on disk, the entire `defaults.needs` sub-table is left alone, meaning any new
-- fields added to `needs` across rapid iteration (e.g. `drunkenness`) are never
-- back-filled into an existing save. Worse, if `sv.needs` is somehow absent or
-- nil in the on-disk data, ZO_SavedVars replaces it with the entire defaults
-- sub-table object — resetting hunger/thirst/fatigue to 100 — which is exactly
-- the bug that caused needs to reset to full on every login.
--
-- This recursive fill runs AFTER NewAccountWide so the live sv table already
-- exists and any values ZO_SavedVars did load are already in place. It only
-- touches keys that are genuinely missing (nil), never overwriting saved values.
local function DeepFillDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do
        if target[key] == nil then
            -- Key is completely absent: insert the default directly.
            -- For table values ZO_SavedVars would have inserted the same object,
            -- so we do the same — a missing sub-table means no saved data for it.
            target[key] = defaultValue
        elseif type(target[key]) == "table" and type(defaultValue) == "table" then
            -- Key exists as a table on both sides: recurse to fill any missing
            -- nested keys without disturbing the ones that are already there.
            DeepFillDefaults(target[key], defaultValue)
        end
        -- Scalar key already present in target: leave it alone.
    end
end

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= RN.NAME then return end

    -- IMPORTANT: ZO_SavedVars:New/NewAccountWide does NOT return the raw saved
    -- data table — it returns a separate wrapper/interface object (with its
    -- own real fields like `default` and exposed methods like
    -- `ResetToDefaults`/`GetInterfaceForCharacter`) that proxies reads/writes
    -- to the real data via a metatable. The raw data itself lives under the
    -- global name given as the FIRST ARGUMENT ("RealisticNeedsAndDiseasesSavedVars"
    -- below), managed internally by the engine — that string must keep
    -- matching the `## SavedVariables:` line in the manifest.
    --
    -- The interface object this call returns must be stored under a DIFFERENT
    -- name (RN.SavedVars), never reassigned back onto the same global the
    -- manifest declares. Doing that previously (assigning straight into
    -- `RealisticNeedsAndDiseasesSavedVars`) silently clobbered the global the
    -- engine actually serializes at logout/reloadui with this wrapper object
    -- instead of the real data — reads/writes still worked all session via
    -- the wrapper's metatable, but the file written to disk was the wrapper
    -- itself (hence `default`/`ResetToDefaults`/`GetInterfaceForCharacter`
    -- showing up in SavedVariables/RealisticNeedsAndDiseasesSavedVars.lua,
    -- with the methods nil'd out as "invalid value type [function] used"),
    -- which is exactly why nothing persisted across a real logout.
    -- Namespaced by GetWorldName() ("EU Megaserver" / "NA Megaserver" / "PTS")
    -- so each server keeps its own saved data instead of all three sharing
    -- (and overwriting) one account-wide table.
    RN.SavedVars = ZO_SavedVars:NewAccountWide(
        "RealisticNeedsAndDiseasesSavedVars", SV_DEFAULTS.version, GetWorldName(), SV_DEFAULTS)
    local sv = RN.SavedVars

    -- Defensive deep-fill: guarantee every key defined in SV_DEFAULTS exists in
    -- sv, recursing into nested tables so new fields added across iterations are
    -- always back-filled. This never overwrites a value ZO_SavedVars already loaded.
    DeepFillDefaults(sv, SV_DEFAULTS)

    -- Each display module's window starts hidden by default at its own
    -- Initialize() (see e.g. RealisticNeedsAndDiseases_StatusBar.lua) - but
    -- SetShown()/RefreshAll() below were previously called unconditionally
    -- from each sub-setting alone, ignoring sv.settings.masterEnabled
    -- entirely. Loading in with the master toggle off but a display's own
    -- sub-setting on would eagerly show that display before the tick loop
    -- (gated on masterEnabled) had run even once to populate it - the same
    -- "shown with no/stale data" bug fixed in Frostfall v3.4.26's
    -- HUD:Initialize(). Every SetShown()/RefreshAll() call below now also
    -- requires sv.settings.masterEnabled ~= false, matching the exact
    -- check already used by the checkbox setFuncs in
    -- RealisticNeedsAndDiseases_Settings.lua (e.g. the icon-display
    -- checkbox). The master-toggle checkbox's OWN setFunc already
    -- correctly handles the mid-session case - this only affects loading
    -- in with the toggle already off.
    if RN.Overlay and RN.Overlay.Initialize then
        RN.Overlay.Initialize()
        if sv.settings.masterEnabled ~= false then
            RN.Overlay.RefreshAll(sv)
        end
    end

    if RN.StatusBar and RN.StatusBar.Initialize then
        RN.StatusBar.Initialize()
        RN.StatusBar.SetShown(sv.settings.showStatusBar and sv.settings.masterEnabled ~= false)
        RN.StatusBar.Refresh(sv)
    end

    if RN.StatusIconsTransparency and RN.StatusIconsTransparency.Initialize then
        RN.StatusIconsTransparency.Initialize()
        RN.StatusIconsTransparency.SetShown(sv.settings.statusIconsTransparencyEnabled and sv.settings.masterEnabled ~= false)
        RN.StatusIconsTransparency.Refresh(sv)
    end

    if RN.StatusBars and RN.StatusBars.Initialize then
        RN.StatusBars.Initialize()
        RN.StatusBars.SetShown(sv.settings.statusBarsEnabled and sv.settings.masterEnabled ~= false)
        RN.StatusBars.Refresh(sv)
    end

    if RN.Feedback and RN.Feedback.ResolveEmoteDefaults then
        RN.Feedback.ResolveEmoteDefaults(sv)
        RN.Feedback.Initialize()
    end

    if RN.Rest and RN.Rest.Initialize then
        RN.Rest.Initialize()
    end

    if RN.Disease and RN.Disease.Initialize then
        RN.Disease.Initialize()
    end

    if RN.Calculator and RN.Calculator.Initialize then
        RN.Calculator.Initialize()
    end

    if RN.Settings and RN.Settings.Initialize then
        RN.Settings.Initialize(sv)
    end

    EVENT_MANAGER:RegisterForUpdate(RN.NAME .. "_Tick", TICK_INTERVAL_MS, OnTick)

    -- ── Merchant / crafting-station / bank gating ───────────────────────────
    -- Buying/selling, refining, or withdrawing/depositing an item fires the
    -- same EVENT_INVENTORY_SINGLE_SLOT_UPDATE as actually consuming one, so
    -- all three windows are tracked here and checked by
    -- OnFoodDrinkInventoryChange via RN.IsTradeWindowOpen().
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_StoreOpen", EVENT_OPEN_STORE, function() _isMerchantOpen = true end)
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_StoreClose", EVENT_CLOSE_STORE, function() _isMerchantOpen = false end)
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_CraftOpen", EVENT_CRAFTING_STATION_INTERACT, function() _isCraftingStationOpen = true end)
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_CraftClose", EVENT_END_CRAFTING_STATION_INTERACT, function() _isCraftingStationOpen = false end)
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_BankOpen", EVENT_OPEN_BANK, function() _isBankOpen = true end)
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_BankClose", EVENT_CLOSE_BANK, function() _isBankOpen = false end)
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_GuildBankOpen", EVENT_OPEN_GUILD_BANK, function() _isBankOpen = true end)
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_GuildBankClose", EVENT_CLOSE_GUILD_BANK, function() _isBankOpen = false end)

    -- ── Food/drink consumption tracking ─────────────────────────────────────
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_FoodDrinkBuffTracker", EVENT_EFFECT_CHANGED, OnFoodDrinkBuffChanged)
    EVENT_MANAGER:AddFilterForEvent(RN.NAME .. "_FoodDrinkBuffTracker", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    -- Filtered to BAG_BACKPACK (food/drink is eaten from the carried backpack,
    -- never the bank or worn-equipment bags) AND to
    -- INVENTORY_UPDATE_REASON_DEFAULT (an item actually moved into or out of
    -- the inventory -- excluding INVENTORY_UPDATE_REASON_DURABILITY_CHANGE
    -- and similar non-consumption reasons this event also fires for). Both
    -- filters stop the event from reaching Lua at all for updates that can't
    -- possibly be food/drink being eaten. See https://wiki.esoui.com/AddFilterForEvent.
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_FoodDrinkInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        OnFoodDrinkInventoryChange)
    EVENT_MANAGER:AddFilterForEvent(RN.NAME .. "_FoodDrinkInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_BACKPACK,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

    -- ── Seed inventory-slot state on first activation ───────────────────────
    -- One-shot: unregisters itself immediately after the first activation so
    -- the seed pass doesn't re-run on zone transitions.
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_SeedSlots", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(RN.NAME .. "_SeedSlots", EVENT_PLAYER_ACTIVATED)
        SeedLastSlotState()
    end)

    -- ── Water ingredient loot → thirst restore ──────────────────────────────
    EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_LootReceived", EVENT_LOOT_RECEIVED, OnLootReceived)

    CHAT_SYSTEM:AddMessage(string.format(
        "|c88CCFF[Realistic Needs and Diseases]|r v%s loaded. Hunger:%d Thirst:%d Fatigue:%d Drunkenness:%d",
        RN.VERSION, math.floor(sv.needs.hunger), math.floor(sv.needs.thirst), math.floor(sv.needs.fatigue), math.floor(sv.needs.drunkenness)
    ))
end

EVENT_MANAGER:RegisterForEvent(RN.NAME .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
