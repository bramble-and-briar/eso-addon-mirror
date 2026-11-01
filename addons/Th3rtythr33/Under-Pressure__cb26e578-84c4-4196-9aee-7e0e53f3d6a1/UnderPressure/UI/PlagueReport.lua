-- =============================================================================
-- Under Pressure -- UI/PlagueReport.lua
-- =============================================================================
-- The Plaguebreak explosion report's "Death recap callout" display (0.5.9).
--
-- The report itself is built by Engine/PlagueTracker.lua and always recorded
-- in History; the Explosion report setting decides where it is SHOWN: chat,
-- here, or nowhere. This module owns "here": a box with the Plague Carrier
-- icon and the report text, a CHILD of ZO_DeathRecap so the recap's fragment
-- decides when it is on screen (see UI/PlagueReport.xml and, for the full
-- reasoning, Deathnote/UI/Layout.lua). Consequence worth stating: in this
-- mode a report is only seen when the player DIES. An explosion the player
-- survives is still recorded and can be read under Plague Indicator >
-- History in the settings menu.
--
-- WHEN IT SHOWS. Show(text) is called by the tracker when a report is
-- finalised, about two seconds after the explosion. If the recap is already
-- up (the explosion killed us), the box appears beside it then. If we die
-- within RECENT_MS of a report (the explosion left us low and something else
-- finished the job), the recap's SHOWING callback puts the box up with that
-- report. Older than that, the report belongs to an earlier fight and is not
-- shown against this death.
-- =============================================================================

UP = UP or {}
UP.PlagueReport = {}
local R = UP.PlagueReport

local callout, title, body
local lastText  = nil
local lastAtMs  = 0

local RECENT_MS      = 10000  -- a report this fresh is shown against a death that follows it
local GAP            = 16     -- between the recap art's right edge and the box
local WIDTH          = 420
local MIN_WIDTH      = 220
local SCREEN_MARGIN  = 40     -- keep the box this far inside the screen edge
local PAD            = 12
local ICON_SIZE      = 64
local TITLE_FONT_SIZE = 27    -- snapped to the gamepad bold ladder
local BODY_FONT_SIZE  = 22    -- snapped to the gamepad medium ladder

-- Fallback overhang of the recap's background to the right of the recap
-- control, from deathrecap.xml: GamepadBackground is 836 wide at offsetX -40
-- on a 752-wide recap (44 past its right edge); KeyboardBackground 964 at
-- -106 (106 past). Used only if the background child cannot be resolved.
local RECAP_OVERHANG_RIGHT_GAMEPAD  = 44
local RECAP_OVERHANG_RIGHT_KEYBOARD = 106

local function mode()
    if UP.Plague and UP.Plague.ReportMode then return UP.Plague.ReportMode() end
    return "chat"
end

-- Same lookup as UI/PlagueTint.lua: whichever of the recap's two backgrounds
-- is on screen carries the visible art.
local function recapBackground(recap)
    if not (recap and recap.GetNamedChild) then return nil end
    local ok, bg = pcall(recap.GetNamedChild, recap, "Bg")
    if not ok or not bg or not bg.GetNamedChild then return nil end
    local okGp, gp = pcall(bg.GetNamedChild, bg, "GamepadBackground")
    local okKb, kb = pcall(bg.GetNamedChild, bg, "KeyboardBackground")
    if okGp and gp and gp.IsControlHidden and not gp:IsControlHidden() then return gp end
    if okKb and kb and kb.IsControlHidden and not kb:IsControlHidden() then return kb end
    if IsInGamepadPreferredMode and IsInGamepadPreferredMode() and okGp and gp then return gp end
    if okKb and kb then return kb end
    return nil
end

local function layout()
    if not (callout and title and body) then return end
    local okT, th = pcall(title.GetTextHeight, title)
    local okB, bh = pcall(body.GetTextHeight, body)
    th = (okT and type(th) == "number") and th or 30
    bh = (okB and type(bh) == "number") and bh or 60
    local textHeight = th + 6 + bh
    local inner = textHeight > ICON_SIZE and textHeight or ICON_SIZE
    callout:SetHeight(PAD * 2 + inner)
end

local function anchor()
    if not callout then return end
    local recap = ZO_DeathRecap
    if not recap then return end
    callout:ClearAnchors()
    local bg = recapBackground(recap)
    local target = bg or recap
    local overhang = 0
    if not bg then
        overhang = (IsInGamepadPreferredMode and IsInGamepadPreferredMode())
            and RECAP_OVERHANG_RIGHT_GAMEPAD or RECAP_OVERHANG_RIGHT_KEYBOARD
    end
    callout:SetAnchor(TOPLEFT, target, TOPRIGHT, GAP + overhang, 0)

    -- Fit on screen: shrink the box rather than run off the right edge.
    local width = WIDTH
    local rootWidth = (GuiRoot and GuiRoot.GetWidth) and GuiRoot:GetWidth() or 1920
    local okR, right = pcall(target.GetRight, target)
    if okR and type(right) == "number" then
        local available = rootWidth - (right + overhang) - GAP - SCREEN_MARGIN
        if available < width then width = available end
    end
    if width < MIN_WIDTH then width = MIN_WIDTH end
    callout:SetWidth(width)
    layout()
end

local function refresh()
    if not callout then return end
    local show = (lastText ~= nil) and (mode() == "recap")
    if show then
        body:SetText(lastText)
        layout()
    end
    callout:SetHidden(not show)
    -- 0.5.10: the callout's icon is our own DDS too; verify it loaded once
    -- the box is up and fall back to the game's icon if not (TextureGuard).
    if show and UP.TextureGuard and UP.TextureGuard.Check then UP.TextureGuard.Check() end
end

-- Called by Engine/PlagueTracker.Emit when the setting is "recap". The box is
-- a child of the recap, so unhiding it while we are alive draws nothing; it
-- is simply ready for the recap, should one follow within RECENT_MS.
function R.Show(text, nowMs)
    if type(text) ~= "string" or text == "" then return end
    lastText = text
    lastAtMs = nowMs or GetGameTimeMilliseconds()
    refresh()
end

-- Settings change (the Explosion report dropdown).
function R.UpdateVisibility() refresh() end

function R.Text() return lastText end
function R.IsShown() return callout ~= nil and not callout:IsHidden() end

function R.Clear()
    lastText = nil
    refresh()
end

local function onRecapStateChange(oldState, newState)
    if newState ~= SCENE_FRAGMENT_SHOWING and newState ~= SCENE_FRAGMENT_SHOWN then return end
    anchor()
    -- A report older than RECENT_MS belongs to an earlier fight, not to the
    -- death this recap is about.
    if lastText and (GetGameTimeMilliseconds() - lastAtMs) > RECENT_MS then
        lastText = nil
    end
    refresh()
end

function R.Init()
    local recap = ZO_DeathRecap
    if not recap then
        UP.Note("ZO_DeathRecap missing; the explosion report callout is disabled.")
        return false
    end
    if not (WINDOW_MANAGER and WINDOW_MANAGER.CreateControlFromVirtual) then return false end
    local ok, ctrl = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER,
                           "UP_PlagueReportCalloutBox", recap, "UP_PlagueReportCallout")
    if not ok or not ctrl then
        UP.Note("Could not create the explosion report callout.")
        return false
    end
    title = ctrl.GetNamedChild and ctrl:GetNamedChild("Title")
    body  = ctrl.GetNamedChild and ctrl:GetNamedChild("Body")
    if not (title and body) then
        UP.Note("Explosion report callout is missing its labels; disabled.")
        return false
    end
    callout = ctrl
    if UP.TextureGuard then
        UP.TextureGuard.Watch(ctrl:GetNamedChild("Icon"), "callout", "plague")
    end
    if callout.SetMouseEnabled then callout:SetMouseEnabled(false) end
    -- ZO_DeathRecap does not resize to its descendants today; free insurance
    -- against a patch that makes it do so (PlagueTint and Deathnote do the same).
    if callout.SetExcludeFromResizeToFitExtents then
        pcall(callout.SetExcludeFromResizeToFitExtents, callout, true)
    end
    if UP.Fonts and UP.Fonts.Apply then
        UP.Fonts.Apply(title, TITLE_FONT_SIZE, true)
        UP.Fonts.Apply(body, BODY_FONT_SIZE, false)
    end
    callout:SetHidden(true)
    anchor()

    -- Re-anchor and re-evaluate each time the recap is about to show.
    if DEATH_RECAP_FRAGMENT and DEATH_RECAP_FRAGMENT.RegisterCallback then
        pcall(DEATH_RECAP_FRAGMENT.RegisterCallback, DEATH_RECAP_FRAGMENT, "StateChange", onRecapStateChange)
    end
    return true
end

-- Harness hook: the recap fragment callback, so a test can drive it.
function R._OnRecapStateChange(oldState, newState) onRecapStateChange(oldState, newState) end
