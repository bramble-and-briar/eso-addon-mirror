local active,timer,stacks=1,"",0
ObsidianHUD={vars={accent={1,0.5,0.2}},textRevision=0}
local O=ObsidianHUD
function GetActiveHotbarCategory() return active end
function O.OtherBar(bar) return bar==1 and 2 or bar==2 and 1 or nil end
dofile("Native.lua")
function O.BackBarTimerText() return timer end
function O.UpdateStackText(label) label:SetText(stacks>0 and tostring(stacks) or "") end
local function control()
    local c={alpha=1,color={1,0.85,0.25,1}}
    function c:SetText(value) self.text=value end
    function c:SetDesaturation(value) self.desaturation=value end
    function c:SetColor(...) self.color={...} end
    function c:SetAlpha(value) self.alpha=value end
    return c
end
local cases={{"",0},{"14.0",0},{"8.0",3},{"",5}}
for _,bar in ipairs({1,2}) do
    active=bar
    for slot=3,8 do
        local skin={timerVisible=true,timerBar=O.OtherBar(bar),timerSlot=slot,
            timer=control(),backStacks=control(),backIcon=control(),backMetal=control(),
            back=control(),activeIcon=control()}
        skin.back.edges={control(),control(),control(),control()}
        for _,case in ipairs(cases) do
            timer,stacks=case[1],case[2]
            O.UpdateBackBarTimer(skin)
            assert(skin.backIcon.desaturation==1 and skin.backIcon.color[1]==0.7,
                "inactive icon stays grayscale even with a timer or stacks")
            assert(skin.backMetal.desaturation==1 and skin.back.edges[1].color[1]==0.55)
            assert(skin.timer.text==timer and skin.timer.alpha==1 and skin.timer.color[2]==0.85,
                "timer content, color and opacity stay unchanged")
            assert(skin.backStacks.text==(stacks>0 and tostring(stacks) or "")
                and skin.backStacks.alpha==1 and skin.backStacks.color[2]==0.85)
            assert(skin.back.alpha==1 and skin.activeIcon.desaturation==nil,
                "neither the text parent nor active icons are dimmed")
        end
        O.textRevision=O.textRevision+1
        O.UpdateBackBarTimer(skin)
        assert(skin.backIcon.desaturation==1, "settings refresh cannot recolor inactive skills")
        skin.timerBar=active
        timer="wrong bar"
        O.UpdateBackBarTimer(skin)
        assert(skin.timer.text~="wrong bar", "old preview cannot update the active bar during a swap")
    end
end
print("PASS: front/back inactive skills and ultimates stay gray; timers/stacks and active icons remain untouched")
