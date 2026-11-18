-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: CombatMetronome.lua. See third-party/UPSTREAM.md for modifications.

local Util = WeavePulse.Util
local StackTracker = WeavePulse.StackTracker
local LATracker = WeavePulse.LATracker

function WeavePulse:RegisterCollectiblesTracker()
    EVENT_MANAGER:RegisterForEvent(
        self.name.."CollectibleUsed",
        EVENT_COLLECTIBLE_UPDATED,
        function(_, id)
            if WeavePulse.SV.Progressbar.trackGCD then
                local name,_,icon,_,_,_,_,type,_ = GetCollectibleInfo(id)
                if (type == COLLECTIBLE_CATEGORY_TYPE_ASSISTANT or type == COLLECTIBLE_CATEGORY_TYPE_COMPANION) and self.gcdEvent.finished <= GetFrameTimeMilliseconds() then
                    WeavePulse:SetIconsAndNamesNil()
                    self.Progressbar.collectibleInUse = {}
                    self.Progressbar.collectibleInUse.name = Util.Text.CropZOSString(name, "collectible")
                    self.Progressbar.collectibleInUse.icon = icon
                end
                if type == COLLECTIBLE_CATEGORY_TYPE_MOUNT then
                    self.Progressbar.activeMount.name = Util.Text.CropZOSString(GetCollectibleNickname(id), "collectible")
                    self.Progressbar.activeMount.icon = icon
                    if WeavePulse.menu.icons[2] then
                        WeavePulse.menu.icons[2]:SetTexture(icon)
                    end
                end
            end
        end
    )

    self.collectiblesTrackerRegistered = true
end

function WeavePulse:RegisterCombatEvents()
    EVENT_MANAGER:RegisterForEvent(
        self.name.."CombatEvents",
        EVENT_COMBAT_EVENT,

        function (_,   res,  err, aName, aGraphic, aSlotType, sName, sType, tName,
                tType, hVal, pType, dType, _, 		sUId, 	 tUId,  aId,   _     )
            if WeavePulse.SV.Progressbar.trackGCD and self.gcdEvent.finished <= GetFrameTimeMilliseconds() then
                aName = Util.Text.CropZOSString(aName, "ability")
                if aId == 16565 then

                    WeavePulse:SetIconsAndNamesNil()
                    self.Progressbar.breakingFree = {}
                    self.Progressbar.breakingFree.name = aName
                    self.Progressbar.breakingFree.icon = "/esoui/art/icons/ability_rogue_050.dds"
                elseif not self.Progressbar.synergy.wasUsed and self.Progressbar.synergy.name == Util.Text.CropZOSString(aName, "synergy") then
                    self.Progressbar.synergy.wasUsed = true

                elseif self.currentEvent or self.inCombat then return

                elseif res == ACTION_RESULT_EFFECT_GAINED and aId == 36432 then
                    WeavePulse:SetIconsAndNamesNil()
                    self.Progressbar.activeMount.action = aName

                elseif res == ACTION_RESULT_BEGIN and aId == 37059 then
                    WeavePulse:SetIconsAndNamesNil()
                    self.Progressbar.activeMount.action = aName

                elseif WeavePulse.FESTIVAL_IDS[aId] then
                    WeavePulse:SetIconsAndNamesNil()
                    self.Progressbar.festivalGCD = aId
                end
            end
        end
    )
    EVENT_MANAGER:AddFilterForEvent(
        self.name.."CombatEvents",
        EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,
        COMBAT_UNIT_TYPE_PLAYER
    )

    self.combatEventsRegistered = true
end

function WeavePulse:RegisterSynergyChanged()
    EVENT_MANAGER:RegisterForEvent(
        self.name.."SynergyChanged",
        EVENT_SYNERGY_ABILITY_CHANGED,
        function()
            if WeavePulse.SV.Progressbar.trackGCD and self.gcdEvent.finished <= GetFrameTimeMilliseconds() then
                local hasSynergy, name, icon, _, _ = GetCurrentSynergyInfo()
                if hasSynergy then

                    self.Progressbar.synergy.name = Util.Text.CropZOSString(name, "synergy")
                    self.Progressbar.synergy.icon = icon

                end
            end
        end
    )
end

function StackTracker:Register(skill)

    if self:CheckIfRegistered(skill) then
        return
    end

    local aId

    if type(self.SKILL_ATTRIBUTES[skill].id) == "number" then
        aId = self.SKILL_ATTRIBUTES[skill].id
    elseif self.SKILL_ATTRIBUTES[skill].id.buff then
        aId = self.SKILL_ATTRIBUTES[skill].id.buff
    elseif skill == "GF" or skill == "FS" then
        aId = self.SKILL_ATTRIBUTES[skill].id[Util.Stacks.morphs[skill]].buff
    end
    self.trackedIds[aId] = skill

    local eventName = self.name..skill.."Stacks"

    self:RegisterEffectChanged(eventName, aId)

    self.stacks[skill] = self:GetCurrentStacks(skill)
    self:InitializeUI(skill)

    StackTracker:ChangeStackCount(skill, self.stacks[skill])

end

function StackTracker:RegisterEffectChanged(name, aId)
    EVENT_MANAGER:RegisterForEvent(
        name,
        EVENT_EFFECT_CHANGED,
        function(...) self:HandleEffectChanged(...) end
    )
    EVENT_MANAGER:AddFilterForEvent(
        name,
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID,
        aId
    )
    EVENT_MANAGER:AddFilterForEvent(
        name,
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE ,
        COMBAT_UNIT_TYPE_PLAYER
    )
end
