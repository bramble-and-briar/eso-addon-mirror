------------------------------------------------------------
-- FrankGrinder PA Integration (Final Drop‑in Replacement)
------------------------------------------------------------

FrankGrinder.PAOverride = {
    installed = false,
    original = {},
    cache = {
        crafterAccount = nil,
        crafterName    = nil,
        crafterId      = nil,
        traderAccount  = nil,
        traderName     = nil,
        traderId       = nil,
    },
}

------------------------------------------------------------
-- Character ID Cache
------------------------------------------------------------

function FrankGrinder:PA_ClearCaches()
    local c = self.PAOverride.cache
    c.crafterAccount, c.crafterName, c.crafterId = nil, nil, nil
    c.traderAccount,  c.traderName,  c.traderId  = nil, nil, nil
end

function FrankGrinder:PA_GetCharacterIdCached(name, slot)
    if not name or name == "" then return nil, nil end

    -- LibCharacterKnowledge is an optional dependency
    local LCK = LibCharacterKnowledge
    if not LCK or not LCK.GetCharacterList then return nil, nil end

    local c = self.PAOverride.cache
    if slot == "crafter" and name == c.crafterName then return c.crafterId, c.crafterAccount end
    if slot == "trader"  and name == c.traderName  then return c.traderId, c.traderAccount end

    for _, v in ipairs(LCK.GetCharacterList()) do
        if v.name == name then
            if slot == "crafter" then
                c.crafterName, c.crafterId, c.crafterAccount = name, v.id, v.account
            elseif slot == "trader" then
                c.traderName, c.traderId, c.traderAccount = name, v.id, v.account
            end
            return v.id, v.account
        end
    end

    return nil, nil
end

------------------------------------------------------------
-- Routing Helpers
------------------------------------------------------------

function FrankGrinder:IsItemUnknownByAnyCharacter(itemLink)
    local LCK = LibCharacterKnowledge
    if not LCK then return false end

    local list = LCK.GetItemKnowledgeList(itemLink)
    if not list then return false end

    for _, entry in ipairs(list) do
        if entry.knowledge == LCK.KNOWLEDGE_UNKNOWN then
            return true
        end
    end

    return false
end

function FrankGrinder:IsItemKnownByAllCharacters(itemLink)
    local LCK = LibCharacterKnowledge
    if not LCK then return false end

    local list = LCK.GetItemKnowledgeList(itemLink)
    if not list or #list == 0 then return false end

    for _, entry in ipairs(list) do
        if entry.knowledge ~= LCK.KNOWLEDGE_KNOWN then
            return false
        end
    end

    return true
end

------------------------------------------------------------
-- Price Helper
------------------------------------------------------------

local function GetItemSaleValue(itemLink)
    local LP = LibPrice
    if not LP then return 0 end

    local spread = LP.ItemLinkToBidAskSpread(itemLink)
    if not spread or not spread.gold or not spread.gold.sale then
        return 0
    end

    return spread.gold.sale.value or 0
end

-- ------------------------------------------------------------
-- ResolveRoutingTarget (DROP-IN REPLACEMENT - Cross-account safe)
-- Core behaviour:
--   - If item cannot be moved cross-account (bound/non-tradable), only route to
--     learners on the CURRENT account, and never set viaId for mailing.
--   - High-value Sell shortcut only applies to items that are cross-account mailable.
-- ------------------------------------------------------------
function FrankGrinder:ResolveRoutingTarget(itemLink)
  local LCK = LibCharacterKnowledge
  if not LCK then return nil end

  local list = LCK.GetItemKnowledgeList(itemLink)
  if not list or #list == 0 then return nil end

  local myAccount = GetDisplayName()

  -- NOTE: PA_GetCharacterIdCached returns (id, account)
  local crafterId, crafterAccount = self:PA_GetCharacterIdCached(self:GetSettingCrafterCharacterName(), "crafter")
  local traderId, traderAccount   = self:PA_GetCharacterIdCached(self:GetSettingTraderCharacterName(), "trader")

  local itemAccount = self:GetSettingMailItemsAccount()

  local threshold = self:GetSettingSaleValueThreshold()
  local value = GetItemSaleValue(itemLink)

  -- ------------------------------------------------------------
  -- Determine whether cross-account mailing is valid for this item
  -- We treat anything that is not BIND_TYPE_NONE / BIND_TYPE_ON_EQUIP as "not cross-account mailable".
  -- Uses item link API: GetItemLinkBindType / IsItemLinkBound.
  -- ------------------------------------------------------------
  local bindType = nil
  if GetItemLinkBindType then
    bindType = GetItemLinkBindType(itemLink)
  end

  local crossAccountMailable = true
  if bindType ~= nil then
    -- Only "none" and "boe" are considered safely movable between accounts.
    if bindType ~= BIND_TYPE_NONE and bindType ~= BIND_TYPE_ON_EQUIP then
      crossAccountMailable = false
    end
  else
    -- Fallback if bindType API not available for some reason: use IsItemLinkBound
    if IsItemLinkBound and IsItemLinkBound(itemLink) then
      crossAccountMailable = false
    end
  end

  -- Helper: can we consider this learner entry?
  local function IsEligibleLearner(entry)
    if not entry or entry.knowledge ~= LCK.KNOWLEDGE_UNKNOWN then
      return false
    end
    -- If item is not cross-account mailable, ONLY consider learners on current account
    if not crossAccountMailable then
      return entry.account == myAccount
    end
    return true
  end

  -- Helper: build routing packet for a chosen learner
  local function MakeLearnerRoute(entry, reason)
    local bankToId = nil
    local mailToAccount = nil

    -- Only set viaId/mailToAccount if cross-account mailable AND learner is on another account
    if crossAccountMailable and myAccount ~= entry.account then
      bankToId = traderId
      mailToAccount = entry.account
    end

    return {
      learnerAccount = entry.account,
      learnerId      = entry.id,
      viaId          = bankToId,
      mailToAccount  = mailToAccount,
      reason         = reason,
    }
  end

  -- ------------------------------------------------------------
  -- 1) Crafter priority (only if eligible under cross-account rules)
  -- ------------------------------------------------------------
  if crafterId then
    for _, entry in ipairs(list) do
      if entry.id == crafterId and IsEligibleLearner(entry) then
        return MakeLearnerRoute(entry, "Crafter")
      end
    end
  end

  -- ------------------------------------------------------------
  -- 2) High value shortcut -> SELL (ONLY if cross-account mailable)
  -- If item cannot be moved cross-account (bound), do NOT short-circuit to Sell.
  -- ------------------------------------------------------------
  if crossAccountMailable and value > threshold then
    return {
      learnerAccount = nil,
      learnerId      = nil,
      viaId          = traderId,
      mailToAccount  = itemAccount,
      reason         = "Sell",
    }
  end

  -- ------------------------------------------------------------
  -- 3) Learning: if not known by all, route to first eligible UNKNOWN
  -- For bound/non-mailable items, this naturally means "first unknown on THIS account".
  -- ------------------------------------------------------------
  if not self:IsItemKnownByAllCharacters(itemLink) then
    for _, entry in ipairs(list) do
      if IsEligibleLearner(entry) then
        return MakeLearnerRoute(entry, "Unknown")
      end
    end
  end

  -- ------------------------------------------------------------
  -- 4) Known by all (or no eligible learners) -> SELL / Surplus to trader
  -- Note: For bound items, this is the only time they should ever get withdrawn on trader.
  -- ------------------------------------------------------------
  return {
    learnerAccount = nil,
    learnerId      = nil,
    viaId          = traderId,
    mailToAccount  = itemAccount,
    reason         = "Sell",
  }
end

------------------------------------------------------------
-- PA Override: IsKnown
--
-- PA uses this to decide:
--  - Should this character auto-learn?
--  - Should this item be deposited?
--  - Should this item be withdrawn?
--
-- Correct behaviour:
--  UNKNOWN + low value → return false (auto-learn)
--  UNKNOWN + high value → return true (do not learn)
--  SURPLUS → return true
--  KNOWN → return true
------------------------------------------------------------

function FrankGrinder:IsKnown(itemLink)
    local target = self:ResolveRoutingTarget(itemLink)
    local currentId = GetCurrentCharacterId()

    -- No routing info → treat as known for safety
    if not target then
        return true
    end

    -- Surplus (all known or High value)
    if target.reason == "Sell" then
        if currentId == target.viaId then
            return false  -- trader character → treat as unknown to withdraw
        else
            return true
        end
    end

    -- Crafter priority → treat as unknown
    if target.reason == "Crafter" or target.reason == "Unknown" then
        if target.learnerId and target.learnerId == currentId then
            return false   -- crafter or first Unknown to learn.. on the account and character
        elseif target.viaId and target.viaId == currentId then
            return false   -- trader character → treat as unknown to withdraw.. on the trader for cross-account mailing
        else
            return true    -- others treat as known to bank it
        end
    end

    return true  -- fallback to bank it
end


------------------------------------------------------------
-- PA Override: DoesCharacterNeed
--
-- PA uses this to decide:
--  - Should this item be routed to a learner?
--  - Should this item be withdrawn by the trader?
--
-- Correct behaviour:
--  UNKNOWN + low value → return true (auto-learn)
--  UNKNOWN + high value → return true (route to trader)
--  SURPLUS → return false (trader handles it)
--  KNOWN → return false
------------------------------------------------------------

function FrankGrinder:DoesCharacterNeed(itemLink)
    local target = self:ResolveRoutingTarget(itemLink)

    if not target then  -- safety check
        return false
    end

    -- Surplus
    if target.reason == "Sell" then  -- dont need, trader handles it
        return true  -- need to set to true so PA withdraws it
    end

    -- Crafter priority
    if target.reason == "Crafter" or  target.reason == "Unknown" then
        return true
    end

    return false  -- fallback to not needed
end


------------------------------------------------------------
-- PA Hook Lifecycle
------------------------------------------------------------

function FrankGrinder:PA_Install()
    local PA = PersonalAssistant
    if not PA or not PA.Libs or not PA.Libs.CharacterKnowledge then return end

    local o = self.PAOverride.original
    if not o.IsKnown then
        o.IsKnown = PA.Libs.CharacterKnowledge.IsKnown
        o.DoesCharacterNeed = PA.Libs.CharacterKnowledge.DoesCharacterNeed
    end

    PA.Libs.CharacterKnowledge.IsKnown = function(itemLink)
        return self:IsKnown(itemLink)
    end

    PA.Libs.CharacterKnowledge.DoesCharacterNeed = function(itemLink)
        return self:DoesCharacterNeed(itemLink)
    end

    self.PAOverride.installed = true
end

function FrankGrinder:PA_Uninstall()
    local PA = PersonalAssistant
    if not PA or not PA.Libs or not PA.Libs.CharacterKnowledge then return end

    local o = self.PAOverride.original
    if o.IsKnown then
        PA.Libs.CharacterKnowledge.IsKnown = o.IsKnown
        PA.Libs.CharacterKnowledge.DoesCharacterNeed = o.DoesCharacterNeed
    end

    self.PAOverride.installed = false
end

------------------------------------------------------------
-- PA Hook Status
------------------------------------------------------------

function FrankGrinder:GetPAHookStatus()
    if not self:GetSettingOverridePAKnown() then
        return false, "Disabled in settings"
    end

    if not PersonalAssistant
       or not PersonalAssistant.Libs
       or not PersonalAssistant.Libs.CharacterKnowledge then
        return false, "Personal Assistant not installed"
    end

    if not LibCharacterKnowledge then
        return false, "LibCharacterKnowledge not installed"
    end

    if not LibPrice then
        return false, "LibPrice not installed"
    end

    if not self.PAOverride.installed then
        return false, "Hook not active (reload UI required)"
    end

    return true, "Active"
end

function FrankGrinder:DebugPAHookStatus()
    local active, reason = self:GetPAHookStatus()
    self:DebugMsg("PA Hook Status = " .. tostring(active) .. " (" .. reason .. ")")
end