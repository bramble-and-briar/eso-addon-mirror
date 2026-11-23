-- Optional integration with code65536's LibExtendedJournal public tab API.
-- No library code is bundled or modified. Standalone /surveys still works.
local S = SurveySidekick
local Journal = LibExtendedJournal
local available = type(Journal)=="table" and type(Journal.RegisterTab)=="function"
    and type(Journal.Show)=="function"
-- The library requires this flag during file loading, before ADD_ON_LOADED.
if available then Journal.Used=true end
local descriptor="SurveySidekick"
local mounted, previousVisible=false, false
local baseMode, baseRender, baseVisible, baseSave, baseMinimize, baseOpen
local utilityKeys={"appearanceWindow","detourWindow","accountantWindow","export"}
local currentUtility

local function ShowUtility(key)
    local window=S[key]
    if not mounted or not window or window:IsHidden() then return end
    currentUtility=window
    for _,other in ipairs(utilityKeys)do
        if S[other] and S[other]~=window then S[other]:SetHidden(true)end
    end
    window:SetScale(1)
    S.LayoutJournalUtility(window,true)
    window:ClearAnchors();window:SetAnchor(TOPLEFT,S.journalHost,TOPLEFT,0,0)
    window:SetScale(math.min(S.journalHost:GetWidth()/920,S.journalHost:GetHeight()/700))
    window:SetMovable(false)
    window:SetHandler("OnHide",function(self)
        if mounted and currentUtility==self then
            currentUtility=nil;S.canvas:SetHidden(false);S.Render()
        end
    end)
    S.canvas:SetHidden(true)
    S.ApplyAppearance()
end

local function Fit()
    if not mounted then return end
    local width,height=S.journalHost:GetWidth(),S.journalHost:GetHeight()
    if width>0 and height>0 then
        S.canvas:SetScale(math.min(width/920,height/700))
    end
    S.minimizeButton:SetHidden(true)
    S.ApplyJournalStyle(true)
    if currentUtility then ShowUtility(currentUtility==S.appearanceWindow and "appearanceWindow"
        or currentUtility==S.detourWindow and "detourWindow"
        or currentUtility==S.accountantWindow and "accountantWindow" or "export")end
end

local function Leave()
    if not mounted then return end
    mounted=false
    currentUtility=nil;S.journalUtilityMode=false
    for _,key in ipairs(utilityKeys)do
        local window=S[key]
        if window then
            S.LayoutJournalUtility(window,false)
            window:SetHidden(true);window:ClearAnchors();window:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
            window:SetScale(S.character.scale or .8);window:SetMovable(true)
        end
    end
    S.canvas:SetHidden(false);S.ApplyAppearance()
    S.ApplyJournalStyle(false)
    S.canvas:SetParent(S.ui);S.canvas:ClearAnchors()
    S.canvas:SetAnchor(TOPLEFT,S.ui,TOPLEFT,0,0)
    S.ui:SetMouseEnabled(true)
    S.minimizeButton:SetHidden(false)
    baseMode()
    baseVisible(previousVisible)
end

local function CloseJournal()
    SCENE_MANAGER:ShowBaseScene()
    -- Also restore immediately if the scene is in a transition.
    Leave()
end

function S.OpenJournal()
    if not S.journalRegistered then
        S.Say("Extended Journal is unavailable. Enable LibExtendedJournal, then reload the UI. /surveys opens the standalone window.")
        return
    end
    Journal.Show(descriptor)
end

function S.RegisterJournal()
    if not available or S.journalRegistered then return end
    local host=WINDOW_MANAGER:CreateControl("SurveySidekickJournalHost",GuiRoot,CT_CONTROL)
    host:SetHidden(true);S.journalHost=host
    baseMode,baseRender,baseVisible=S.ApplyWindowMode,S.Render,S.SetWindowVisible
    baseSave,baseMinimize,baseOpen=S.SaveWindowState,S.SetMinimized,S.OpenMapItem
    for _,entry in ipairs({{"ShowAppearance","appearanceWindow"},{"ShowDetours","detourWindow"},
        {"ShowAccountant","accountantWindow"},{"ShowExport","export"}})do
        local original,key=S[entry[1]],entry[2]
        S[entry[1]]=function(...)
            if mounted and key=="appearanceWindow" then return end
            original(...);ShowUtility(key)
        end
    end
    -- Expand only during rendering. Never overwrite the saved tracker preference.
    S.ApplyWindowMode=function()
        local minimized=S.character.minimized
        if mounted then S.character.minimized=false end
        baseMode()
        S.character.minimized=minimized
        Fit()
    end
    S.Render=function()
        local minimized=S.character.minimized
        if mounted then S.character.minimized=false end
        baseRender()
        S.character.minimized=minimized
        Fit()
    end
    S.SetWindowVisible=function(visible)
        if mounted and visible then S.Render();return end
        if mounted then CloseJournal() end
        baseVisible(visible)
    end
    S.SaveWindowState=function()
        if mounted then return end
        baseSave()
    end
    S.SetMinimized=function(value)
        if mounted then CloseJournal() end
        baseMinimize(value)
    end
    S.OpenMapItem=function(id)
        -- The native book reader needs its own scene and unobstructed picture.
        if mounted then CloseJournal() end
        baseOpen(id)
    end
    host:SetHandler("OnRectChanged",Fit)
    Journal.RegisterTab(descriptor,{
        order=900,title="Survey Sidekick",
        iconPrefix="EsoUI/Art/MainMenu/menuBar_map_",control=host,
        callbackShow=function()
            if mounted then return end
            previousVisible=not S.ui:IsHidden()
            S.SaveWindowPosition()
            S.RestoreWindowPosition()
            mounted=true
            S.journalUtilityMode=true;S.ApplyAppearance()
            S.canvas:SetParent(host);S.canvas:ClearAnchors()
            S.canvas:SetAnchor(TOPLEFT,host,TOPLEFT,0,0)
            -- The existing renderer uses this window's visibility as its gate.
            S.ui:SetMouseEnabled(false);S.ui:SetHidden(false)
            S.ApplyWindowMode();S.Scan();S.Render()
        end,
        callbackHide=Leave,
    })
    S.journalRegistered=true
end
