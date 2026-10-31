HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,EFFECT_RESULT_FADED=1,2,3
WEAPONTYPE_FIRE_STAFF,WEAPONTYPE_LIGHTNING_STAFF,WEAPONTYPE_FROST_STAFF=1,2,3
BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_BACKUP_MAIN,LINK_STYLE_DEFAULT=1,4,20,0
local now,active,raw=100,1,39011
local weapons={[4]=1,[20]=3}
function GetSlotBoundId(slot,bar) return slot==4 and bar==1 and raw or 0 end
function GetActiveHotbarCategory() return active end
function GetFrameTimeSeconds() return now end
function GetItemLink(bag,slot) assert(bag==BAG_WORN); return slot end
function GetItemLinkWeaponType(slot) return weapons[slot] end
function GetAbilityDuration(id) return id==28858 and 10000 or 15000 end
function GetAbilityCastInfo() return false,0,0 end
function IsAbilityDurationToggled() return false end
function GetActionSlotEffectTimeRemaining() return 0 end
function GetActionSlotEffectStackCount() return 0 end
function GetNumBuffs() return 0 end
function GetSlotTexture() return "unmorphed-wall.dds" end
function GetAbilityIcon(id) return "ability"..id..".dds" end
function ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(seconds) return string.format("%.1f",seconds) end
ZO_ONE_MINUTE_IN_SECONDS,ZO_EFFECT_EXPIRATION_IMMINENCE_THRESHOLD_S,TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT=60,2,1
ObsidianHUD={}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
dofile("SkillTracking.lua"); dofile("TimerSources.lua"); dofile("TimerRules.lua")
dofile("SkillTimers.lua"); dofile("Native.lua")
local function effect(change,id,began,ending,source)
    O.OnTimerEffectChanged(nil,change,8,"","reticleover",began,ending,0,"",0,0,0,0,"",42,id,source or 1)
end
for _,family in ipairs({{28858,28807,28854,28849},{39052,39053,39073,39067},{39011,39012,39018,39028}}) do
    for weapon=1,3 do
        now,active,raw=100,1,family[1]; weapons[20]=weapon; O.ResetSkillTimers()
        local variant=family[weapon+1]
        assert(O.GetSkillAbilityId(4,1)==variant,"inactive staff skills must resolve using THEIR equipped staff and preserve the morph")
        assert(O.SkillPreviewTexture(4,1)=="ability"..variant..".dds","generic native texture must not replace the equipped wall morph")
        O.OnTimerAbilityUsed(nil,4)
        assert(O.GetSkillTimerRemaining(4,1)>0,"wall starts on use without waiting for a target event")
        now=102; active=0
        assert(O.GetSkillTimerRemaining(4,1)==13000 and O.BackBarTimerText(4,1)=="13.0","wall timer continues on the front bar with no inactive native timer")
        -- The inactive slot may return its generic morph or any staff variant.
        for _,id in ipairs(family) do
            raw=id
            assert(O.GetSkillAbilityId(4,1)==variant)
            assert(O.GetSkillTimerRemaining(4,1)==13000)
            assert(O.SkillPreviewTexture(4,1)=="ability"..variant..".dds")
        end
        effect(1,variant,100,115)
        assert(O.GetSkillTimerRemaining(4,1)==13000)
        now=104; active=1; raw=variant; O.OnTimerAbilityUsed(nil,4)
        effect(1,variant,104,119); effect(3,variant,100,115)
        active=0; now=105; raw=family[1]
        assert(O.GetSkillTimerRemaining(4,1)==14000,"recast survives the previous wall fade")
        effect(3,variant,104,119)
        assert(O.GetSkillTimerRemaining(4,1)==0,"own wall ending still clears its timer")
        O.ResetSkillTimers(); effect(1,variant,105,120,9)
        assert(O.GetSkillTimerRemaining(4,1)==0,"another player's wall cannot start our timer")
        raw=0; assert(O.SkillPreviewTexture(4,1)==nil,"empty slots never keep a wall icon")
    end
end
raw=39011; weapons[20]=0
assert(O.GetSkillAbilityId(4,1)==39011,"missing/non-destruction staff does not invent an element")
GetItemLink=nil; raw=39028
assert(O.GetSkillAbilityId(4,1)==39028,"without inventory APIs retain the known variant")
print("PASS: all wall morphs/elements keep their own bar identity/icon and timer through swaps, generic IDs, recasts and expiry")
