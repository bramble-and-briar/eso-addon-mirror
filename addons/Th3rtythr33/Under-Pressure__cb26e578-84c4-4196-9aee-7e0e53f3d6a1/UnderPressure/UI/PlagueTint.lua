-- =============================================================================
-- Under Pressure -- UI/PlagueTint.lua (0.4.0)
-- =============================================================================
-- Draws the Plaguebreak screen tint: a smoky green vignette over the whole
-- screen with a slowly breathing haze layer, shown for exactly as long as a
-- Plaguebreak plague is on the player.
--
-- Owns drawing only. Whether the player IS plagued is Engine/PlagueTracker's
-- job, which calls SetActive() on transitions -- the same split as
-- SilenceTracker / SilenceRing.
--
-- VISIBILITY -- three inputs, one owner, same pattern as the other two UI
-- modules:
--   1. the HUD scene must be showing (never tint a menu)
--   2. the plague_tint setting must be on
--   3. the player must actually carry the plague (or the visual test is live)
--
-- Not gated on the Threat Indicator master toggle or combat state, for the
-- reasons given in UI/SilenceRing.lua: it is a separate indicator with its own
-- switch, and a stale combat flag must not be able to hide it.
--
-- STRENGTH is one number, sv.plague_tint_strength, applied as the root's
-- alpha. Child alpha inherits in ESO's control tree, so the vignette and the
-- animated haze scale together and the XML keeps its own relative levels.
-- =============================================================================

UP = UP or {}
UP.PlagueTint = {}

local root, vignette, haze
local hazeTimeline

local plagued = false

-- "You died with <plague>" label, a child of ZO_DeathRecap (0.4.2). nil when
-- the recap control could not be found; the feature then silently does not
-- exist, like the rest of this module when its root is missing.
local deathNote
local deathNoteText = nil

local DEATH_NOTE_GAP = 14          -- gap between the label's bottom and the recap art's top
local DEATH_NOTE_FONT_SIZE = 34    -- snapped to the gamepad bold ladder
-- Fallback overhang of the recap's background above the recap control itself,
-- from deathrecap.xml (GamepadBackground offsetY -35, KeyboardBackground -98),
-- used only if the background child cannot be resolved.
local RECAP_OVERHANG_GAMEPAD  = 35
local RECAP_OVERHANG_KEYBOARD = 98

local DEFAULT_STRENGTH = 0.6
local MIN_STRENGTH, MAX_STRENGTH = 0.2, 1.0

-- Preview override (Settings > Plague Indicator > Preview): a deadline
-- timestamp, independent of tracker state, for the reasons documented on
-- SilenceRing.RunPreview.
local PREVIEW_DURATION_MS = 10000
local previewUntilMs = 0

local function previewActive()
    return previewUntilMs > 0 and GetGameTimeMilliseconds() < previewUntilMs
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- ---------------------------------------------------------------------------
-- Death note: "You died with Plague Carrier"
-- ---------------------------------------------------------------------------
-- Which of the recap's two backgrounds carries the visible art. Same question,
-- same answer, as Deathnote/UI/Layout.lua's activeBackground(): ZOS switches
-- them in the recap's platform template, so asking which is un-hidden is more
-- truthful than asking the platform.
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

-- Anchor the label centred above the recap's visible art. Re-run whenever the
-- recap is about to show (DEATH_RECAP_FRAGMENT StateChange), which is the
-- safety net for the one thing not provable from source: that ZOS's
-- ApplyTemplateToControl leaves children it does not name alone. Deathnote
-- does exactly this, for the same reason.
local function anchorDeathNote()
    if not deathNote then return end
    local recap = ZO_DeathRecap
    if not recap then return end
    deathNote:ClearAnchors()
    local bg = recapBackground(recap)
    if bg then
        deathNote:SetAnchor(BOTTOM, bg, TOP, 0, -DEATH_NOTE_GAP)
        local ok, w = pcall(bg.GetWidth, bg)
        if ok and type(w) == "number" and w > 0 then deathNote:SetWidth(w) end
    else
        local overhang = (IsInGamepadPreferredMode and IsInGamepadPreferredMode())
            and RECAP_OVERHANG_GAMEPAD or RECAP_OVERHANG_KEYBOARD
        deathNote:SetAnchor(BOTTOM, recap, TOP, 0, -(DEATH_NOTE_GAP + overhang))
        local ok, w = pcall(recap.GetWidth, recap)
        if ok and type(w) == "number" and w > 0 then deathNote:SetWidth(w) end
    end
end

local function updateDeathNote()
    if not deathNote then return end
    local show = deathNoteText ~= nil
    if show then
        -- Setting is the Plague Indicator's own switch; the note is part of it.
        local sv = UP.sv or {}
        if sv.plague_tint == false then show = false end
    end
    if show then deathNote:SetText(deathNoteText) end
    -- Our own hidden flag says "did we die plagued". The recap's fragment
    -- decides everything else (fade, menus, the player closing the recap)
    -- because the label is its child.
    deathNote:SetHidden(not show)
end

-- Called by Engine/PlagueTracker's publish: the plague's display name while
-- the tint is held through death, nil otherwise.
function UP.PlagueTint.SetDeathNote(plagueName)
    if type(plagueName) == "string" and plagueName ~= "" then
        deathNoteText = ("You died with %s"):format(plagueName)
    else
        deathNoteText = nil
    end
    updateDeathNote()
end

function UP.PlagueTint.DeathNoteText()
    return deathNoteText
end

local function createDeathNote()
    local recap = ZO_DeathRecap
    if not recap then
        UP.Note("ZO_DeathRecap missing; the 'You died with' note is disabled.")
        return
    end
    if not (WINDOW_MANAGER and WINDOW_MANAGER.CreateControlFromVirtual) then return end
    local ok, ctrl = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER,
                           "UP_PlagueDeathNoteLabel", recap, "UP_PlagueDeathNote")
    if not ok or not ctrl then
        UP.Note("Could not create the 'You died with' note control.")
        return
    end
    deathNote = ctrl
    if deathNote.SetMouseEnabled then deathNote:SetMouseEnabled(false) end
    -- ZO_DeathRecap does not resize to its descendants today; this is free
    -- insurance against a patch that makes it do so (Deathnote does the same).
    if deathNote.SetExcludeFromResizeToFitExtents then
        pcall(deathNote.SetExcludeFromResizeToFitExtents, deathNote, true)
    end
    -- Smoky green, the tint's own hue at full opacity so it reads as text.
    if deathNote.SetColor then deathNote:SetColor(0.56, 0.84, 0.42, 1) end
    if UP.Fonts and UP.Fonts.Apply then UP.Fonts.Apply(deathNote, DEATH_NOTE_FONT_SIZE, true) end
    deathNote:SetHidden(true)
    anchorDeathNote()

    -- Re-anchor each time the recap is about to show (see anchorDeathNote).
    if DEATH_RECAP_FRAGMENT and DEATH_RECAP_FRAGMENT.RegisterCallback then
        pcall(DEATH_RECAP_FRAGMENT.RegisterCallback, DEATH_RECAP_FRAGMENT, "StateChange",
              function(oldState, newState)
                  if newState == SCENE_FRAGMENT_SHOWING or newState == SCENE_FRAGMENT_SHOWN then
                      anchorDeathNote()
                  end
              end)
    end
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------
local function shouldShow()
    local forced = previewActive()
    if not (plagued or forced) then return false end
    if not forced then
        local sv = UP.sv or {}
        if sv.plague_tint == false then return false end
        -- Shares Indicator.lua's HUD-scene answer; fails open if unavailable.
        -- The preview bypasses it: the button is in the settings menu, so the
        -- HUD is hidden at the moment it is pressed. See SilenceRing.lua.
        if UP.UI and UP.UI.IsHudShown and not UP.UI.IsHudShown() then return false end
    end
    return true
end

function UP.PlagueTint.UpdateVisibility()
    if not root then return end
    local show = shouldShow()
    root:SetHidden(not show)
    updateDeathNote()   -- the plague_tint toggle also governs the note
    if hazeTimeline then
        if show then
            if not hazeTimeline:IsPlaying() then
                pcall(hazeTimeline.PlayFromStart, hazeTimeline)
            end
        else
            pcall(hazeTimeline.Stop, hazeTimeline)
            if haze then haze:SetAlpha(0) end
        end
    end
end

-- Called by Engine/PlagueTracker on a transition.
function UP.PlagueTint.SetActive(isPlagued)
    plagued = isPlagued == true
    UP.PlagueTint.UpdateVisibility()
end

function UP.PlagueTint.IsPreviewActive()
    return previewActive()
end

-- Settings panel hook. Clamped to the slider's own range so a stray saved
-- value cannot black out the screen.
function UP.PlagueTint.ApplyStrength(strength)
    if not root then return end
    local s = clamp(tonumber(strength) or DEFAULT_STRENGTH, MIN_STRENGTH, MAX_STRENGTH)
    root:SetAlpha(s)
end

UP.PlagueTint.DEFAULT_STRENGTH = DEFAULT_STRENGTH
UP.PlagueTint.MIN_STRENGTH     = MIN_STRENGTH
UP.PlagueTint.MAX_STRENGTH     = MAX_STRENGTH

-- ---------------------------------------------------------------------------
-- Preview (Settings > Plague Indicator > Preview)
-- ---------------------------------------------------------------------------
-- Same contract as SilenceRing.RunPreview: extends rather than stacks,
-- tolerates surplus zo_callLater callbacks, +50 ms guards an early callback.
function UP.PlagueTint.RunPreview()
    if not root then return false end
    previewUntilMs = GetGameTimeMilliseconds() + PREVIEW_DURATION_MS
    UP.PlagueTint.UpdateVisibility()
    zo_callLater(function()
        if GetGameTimeMilliseconds() >= previewUntilMs then
            previewUntilMs = 0
        end
        UP.PlagueTint.UpdateVisibility()
    end, PREVIEW_DURATION_MS + 50)
    return true
end

function UP.PlagueTint.PreviewDurationMs()
    return PREVIEW_DURATION_MS
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
-- Not fatal to the add-on if the control is missing: disables itself and
-- records why, like SilenceRing.
function UP.PlagueTint.Init()
    root = UP_PlagueTintRoot
    if not root then
        UP.Note("Plague tint control missing; Plaguebreak tint disabled.")
        return false
    end
    vignette = root:GetNamedChild("Vignette")
    haze     = root:GetNamedChild("Haze")

    if haze then haze:SetAlpha(0) end

    if haze and ANIMATION_MANAGER then
        local ok, timeline = pcall(ANIMATION_MANAGER.CreateTimelineFromVirtual,
                                   ANIMATION_MANAGER, "UP_PlagueHazePulse", haze)
        if ok then
            hazeTimeline = timeline
        else
            UP.Note("Plague haze animation unavailable; tint will be static.")
        end
    end

    local sv = UP.sv or {}
    UP.PlagueTint.ApplyStrength(sv.plague_tint_strength or DEFAULT_STRENGTH)

    -- Not fatal if the recap is missing: the tint works without the note.
    createDeathNote()

    root:SetHidden(true)
    return true
end
