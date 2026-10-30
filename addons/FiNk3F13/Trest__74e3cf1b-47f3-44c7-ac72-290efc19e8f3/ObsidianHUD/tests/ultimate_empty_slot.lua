local active,dual,points=1,true,100
local ids,costs={[1]=101,[2]=202},{[1]=100,[2]=200}
local allocations,costQueries=0,0
COMBAT_MECHANIC_FLAGS_ULTIMATE=10
TOPLEFT,BOTTOMRIGHT,CT_CONTROL,CT_LINE,DT_HIGH,DL_OVERLAY=1,2,3,4,5,6
ObsidianHUD={}
local O=ObsidianHUD
local function control()
    local c={hidden=true}
    function c:SetHidden(value) self.hidden=value end
    function c:SetAnchor(...) self.anchor={...} end
    function c:ClearAnchors() end
    function c:SetAnchorFill(target) self.outline=target end
    function c:GetWidth() return self.outline and self.outline:GetWidth() or self.width or 61 end
    function c:GetHeight() return self.outline and self.outline:GetHeight() or self.height or 61 end
    function c:SetText(value) self.text=value end
    for _,name in ipairs({"SetMouseEnabled","SetDrawTier","SetDrawLayer","SetDrawLevel",
        "SetTexture","SetPixelRoundingEnabled","SetColor","SetThickness"}) do c[name]=function() end end
    return c
end
WINDOW_MANAGER={CreateControl=function() allocations=allocations+1; return control() end}
function GetActiveHotbarCategory() return active end
function GetSlotBoundId(slot,bar) assert(slot==8); return ids[bar] end
function GetSlotAbilityCost(_,_,bar)
    costQueries=costQueries+1
    assert((ids[bar] or 0)>0, "empty slots must not reuse stale ultimate costs")
    return costs[bar]
end
-- ESO returns current, maximum and effective maximum. Passing this call
-- directly to tonumber treats maximum as its numeric-base argument.
function GetUnitPower() return points,500,500 end
function O.OtherBar(bar) return bar==1 and 2 or bar==2 and 1 or nil end
function O.DualUltimateView() return dual end
function O.SurfaceTexture() return "surface.dds" end
function O.UpdateSkillProcHighlight() end
function O.NoSkillAnimationsView() return false end
function O.FinishFixedUltimateSwap() end
local bindingUpdates=0
function O.UpdateFixedSkillBindings() bindingUpdates=bindingUpdates+1 end
function O.SuppressNativeSkillText() end
dofile("UltimateCharge.lua")
dofile("SkillText.lua")
local function skin()
    return {activeTextVisible=true,activeTextBar=active,activeTextSlot=8,
        activeTimer=control(),activeStacks=control(),button={slot=control(),icon=control()},
        art=control(),backMetal=control(),back=control(),backIcon=control(),timerVisible=true,timerBar=O.OtherBar(active),previewWidth=73,previewHeight=73}
end
local s=skin()
O.UpdateUltimateCharge(s)
assert(s.chargeFront.ratio==1 and s.chargeBack.ratio==0.5)
assert(s.chargeFront.root.outline==s.art and s.chargeBack.root.outline==s.backMetal)
s.art.width=84; s.art.height=80; s.backMetal.width=72; s.backMetal.height=70
O.UpdateUltimateCharge(s)
assert(s.chargeFront.width==84 and s.chargeFront.height==80)
assert(s.chargeBack.width==72 and s.chargeBack.height==70)
s.art.width=0
O.UpdateUltimateCharge(s)
assert(s.chargeFront.root.hidden and not s.chargeBack.root.hidden,"transient empty geometry hides only its own frame")
s.art.width=84
O.UpdateUltimateCharge(s)
assert(not s.chargeFront.root.hidden,"frame recovers when geometry returns")
ids[2]=0
O.UpdateUltimateCharge(s)
assert(not s.chargeFront.root.hidden and s.chargeBack.root.hidden,
    "removing the back-bar ultimate hides only its frame")
assert(O.UltimateChargeRatio(2)==0)
for i=1,20 do
    active=i%2+1; s.activeTextBar=active; s.timerBar=O.OtherBar(active)
    O.UpdateUltimateCharge(s)
    if active==2 then
        assert(s.chargeFront.root.hidden and not s.chargeBack.root.hidden,
            "empty active back bar has no ghost frame; valid front-bar preview remains")
    else assert(not s.chargeFront.root.hidden and s.chargeBack.root.hidden) end
end
active=1; s.activeTextBar=1; s.timerBar=2
ids[2]=303; costs[2]=400
O.UpdateUltimateCharge(s)
assert(s.chargeBack.ratio==0.25 and not s.chargeBack.root.hidden,
    "re-equipped ultimate rebuilds the frame using its new cost")
ids[1]=0
O.UpdateActiveSkillText(s)
assert(bindingUpdates==1, "empty active ultimate refreshes its native binding anchors")
assert(s.chargeFront.root.hidden and not s.chargeBack.root.hidden,
    "per-frame text update clears an emptied active slot without waiting for the HUD tick")
ids[2]=0
O.UpdateUltimateCharge(s)
assert(s.chargeFront.root.hidden and s.chargeBack.root.hidden)
local before=allocations
O.UpdateUltimateCharge(skin())
assert(allocations==before, "two empty slots allocate no charge controls")
ids[1]=101; costs[1]=0
assert(O.UltimateChargeRatio(1)==0)
costs[1]=100; points=50
O.UpdateUltimateCharge(s)
assert(s.chargeFront.ratio==0.5)
active=2
O.UpdateUltimateCharge(s)
assert(s.chargeFront.root.hidden and s.chargeBack.root.hidden,
    "mismatched bar identity during swap cannot show a displaced stale frame")
active=1; s.activeTextVisible=false
O.UpdateUltimateCharge(s)
assert(s.chargeFront.root.hidden and s.chargeBack.root.hidden)
-- A normal HUD tick must reach the potion frame and position update after
-- the real ultimate calculation, rather than aborting midway through skills.
O.name="ObsidianHUD"
O.vars={enabled=true}
O.root=control(); O.materialReady=true
for _,name in ipairs({"UpdateSkillScale","UpdateMaterials","UpdateClassIcon",
    "ResetResourceAnimations","SyncNativeResources"}) do O[name]=function() end end
local potionUpdates,positionUpdates=0,0
function O.UpdateQuickslot() potionUpdates=potionUpdates+1 end
function O.UpdateNativePositions() positionUpdates=positionUpdates+1 end
function O.UpdateSkills()
    s.activeTextVisible=true
    O.UpdateUltimateCharge(s)
end
EVENT_MANAGER={RegisterForEvent=function() end}
dofile("ObsidianHUD.lua")
O.Tick()
assert(potionUpdates==1 and positionUpdates==1,
    "multi-return ultimate power cannot interrupt later HUD updates")
print("PASS: empty ultimates, stale costs, repeated swaps, independent previews, re-equip and immediate cleanup")
