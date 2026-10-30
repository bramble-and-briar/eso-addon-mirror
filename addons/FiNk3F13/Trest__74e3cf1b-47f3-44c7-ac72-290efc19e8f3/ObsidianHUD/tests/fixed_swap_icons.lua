HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
local active=0
ObsidianHUD={vars={enabled=true,backBar=true,skillHudView="fixed"}}
local O=ObsidianHUD
function GetActiveHotbarCategory() return active end
function GetSlotBoundId() return 100 end
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
dofile("NativeMove.lua"); dofile("Native.lua"); dofile("SkillText.lua")
local buttons={}
local function animation()
    return {playing=true,calls=0,IsPlaying=function(self) return self.playing end,
        PlayInstantlyToEnd=function(self,skip)
            assert(skip==false); self.playing=false; self.calls=self.calls+1
        end}
end
for slot=3,8 do
    local b={slot={hotbarCategory=0,GetWidth=function() return 64 end,GetHeight=function() return 64 end}}
    for _,key in ipairs({"hotbarSwapAnimation","timerSwapAnimation","stackCountSwapAnimation",
        "bounceAnimation","iconBounceAnimation"}) do b[key]=animation() end
    buttons[slot]=b
end
function ZO_ActionBar_GetButton(slot) return buttons[slot] end
function O.UpdateFixedSkillBindings() end
function O.UpdateSkillProcHighlight() end
function O.UpdateStackText() end
function O.UpdateSkillPreview() end
function O.BackBarTimerText() return "timer" end
for _,view in ipairs({"fixed","fixed_dual"}) do
    O.vars.skillHudView=view
    for _,b in pairs(buttons) do b.slot.hotbarCategory=0 end
    for _,key in ipairs({"hotbarSwapAnimation","timerSwapAnimation","stackCountSwapAnimation"}) do
        buttons[8][key].playing=true
    end
    active=0
    local oldOffset=O.SkillRowOffset("skills")
    active=1
    O.FinishFixedUltimateSwap()
    assert(O.SkillRowOffset("skills")==oldOffset,"old icons stay on the old row while collapsing")
    for slot=3,7 do
        local b=buttons[slot]
        assert(O.SkillDisplayBar(b)==0)
        for _,key in ipairs({"hotbarSwapAnimation","timerSwapAnimation","stackCountSwapAnimation",
            "bounceAnimation","iconBounceAnimation"}) do
            assert(b[key].playing and b[key].calls==0,"animated views must not fast-forward any timeline")
        end
    end
    for _,key in ipairs({"hotbarSwapAnimation","timerSwapAnimation","stackCountSwapAnimation"}) do
        assert(not buttons[8][key].playing,"only ultimate skips weapon-swap animation")
    end
    assert(buttons[8].bounceAnimation.playing and buttons[8].iconBounceAnimation.playing,
        "ultimate activation animations remain unchanged")
    local label={SetText=function(self,v) self.text=v end}
    local s={button=buttons[4],activeTextVisible=true,activeTextBar=1,activeTextSlot=4,
        activeTimer=label,activeStacks={SetText=function() end}}
    O.UpdateActiveSkillText(s)
    assert(label.text=="","new-bar timer is withheld while the old icon is still collapsing")
    -- Native HandleSlotChanged replaces icon and category at the midpoint.
    for _,b in pairs(buttons) do b.slot.hotbarCategory=1 end
    assert(O.SkillRowOffset("skills")==0)
    O.UpdateActiveSkillText(s)
    assert(O.SkillDisplayBar(buttons[4])==1 and label.text=="timer")
    assert(buttons[4].hotbarSwapAnimation.playing and buttons[4].hotbarSwapAnimation.calls==0)
end
for _,view in ipairs({"fixed_static","fixed_dual_static"}) do
    O.vars.skillHudView=view
    O.FinishFixedUltimateSwap()
    for _,b in pairs(buttons) do
        assert(not b.hotbarSwapAnimation.playing and not b.timerSwapAnimation.playing and not b.stackCountSwapAnimation.playing,
            "static modes finish only weapon-swap timelines")
        assert(b.bounceAnimation.playing and b.iconBounceAnimation.playing
            and b.bounceAnimation.calls==0 and b.iconBounceAnimation.calls==0,
            "press animations remain active in static modes too")
    end
end
print("PASS: normal skill flips retained; only ultimate swap skipped; midpoint rows and explicit static modes preserved")
