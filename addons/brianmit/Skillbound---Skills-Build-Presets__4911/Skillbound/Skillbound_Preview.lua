-- Skillbound_Preview.lua : "Preview on my character" (experiment, 2026-10-01).
-- Addons can't draw the 3D character inside a window, so this uses the game's own
-- character preview, the same way the Daily Login Rewards screen does it
-- (esoui keyboardingamescenes.lua): a scene with the item preview fragment, the
-- "frame the player" camera and the right-panel framing. Your real character stands on
-- the left of the screen, the Skillbound window on the right; drag on the character to
-- turn it around (the game's own rotation area, ITEM_PREVIEW_KEYBOARD).
-- The build's pieces that you aren't wearing are put on the preview with
-- PreviewInventoryItem (like "Preview" in the inventory), then shown together with
-- ApplyChangesToPreviewCollectionShown. The outfit is taken off in the preview (unless
-- the build has one), so the real armor shows.
-- Unverified: whether several pieces stay on the preview together (the "preview
-- collection" suggests so); if only the last one shows, the preview needs another way.

local B = Skillbound
local L = B.L
local Items = B.Items
local Preview = {}
B.Preview = Preview

local SCENE_NAME = "skillboundPreview"
local scene, winFragment
local active, reopen, pendingBuild

local ACTOR = GAMEPLAY_ACTOR_CATEGORY_PLAYER

local function Create()
    if scene then return true end
    local ok, err = pcall(function()
        scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
        scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
        scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)
        scene:AddFragment(RIGHT_BG_FORCE_PREPARE_ITEM_PREVIEW_OPTIONS_FRAGMENT)
        scene:AddFragment(ITEM_PREVIEW_KEYBOARD:GetFragment())
        scene:AddFragment(FRAME_PLAYER_FRAGMENT)
        if FRAME_EMOTE_FRAGMENT_CROWN_STORE then scene:AddFragment(FRAME_EMOTE_FRAGMENT_CROWN_STORE) end
        winFragment = ZO_SimpleSceneFragment:New(B.UI.Window())
        scene:AddFragment(winFragment)
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWN then
                Preview.OnShown()
            elseif newState == SCENE_HIDDEN then
                Preview.OnHidden()
            end
        end)
    end)
    if not ok then
        scene = nil
        B.Print(L("PREVIEW_UNAVAILABLE", tostring(err)))
        return false
    end
    return true
end

function Preview.IsActive() return active == true end

-- put the build's pieces on the preview character
local function ShowBuild(build)
    if not build or not (GetPreviewModeEnabled and GetPreviewModeEnabled()) then return false end
    pcall(ClearCurrentItemPreviewCollection)
    local o = build.parts and build.parts.outfit and build.outfit
    if o and (o.index or 0) > 0 and SetPreviewingOutfitIndexInPreviewCollection then
        pcall(SetPreviewingOutfitIndexInPreviewCollection, ACTOR, o.index)
    elseif SetPreviewingUnequippedOutfitInPreviewCollection then
        pcall(SetPreviewingUnequippedOutfitInPreviewCollection, ACTOR)
    end
    local shown, notShown = 0, 0
    local used = {}
    for _, slot in ipairs(Items.SLOTS) do
        local p = build.gear and build.gear[slot]
        if p and not Items.POISON[slot] then
            local f = Items.Find(p, used)
            local e = f and f.e
            if e and e.uid then used[e.uid] = true end
            if e and not (e.bag == BAG_WORN and e.slot == slot) then
                local can = not CanInventoryItemBePreviewed or CanInventoryItemBePreviewed(e.bag, e.slot)
                if can and pcall(PreviewInventoryItem, e.bag, e.slot, 1) then
                    shown = shown + 1
                else
                    notShown = notShown + 1
                end
            elseif not e then
                notShown = notShown + 1
            end
        end
    end
    pcall(ApplyChangesToPreviewCollectionShown)
    if notShown > 0 then B.Print(L("PREVIEW_SOME_MISSING", notShown)) end
    return true
end

-- the preview mode needs a moment to start: try again until it's ready (max ~3 s).
-- If the game still says previewing isn't possible here, leave the preview again.
local function ShowWhenReady(build, tries)
    tries = tries or 0
    if not active then return end
    local ready = GetPreviewModeEnabled and GetPreviewModeEnabled()
    local available = not IsCharacterPreviewingAvailable or IsCharacterPreviewingAvailable()
    if ready and available then
        ShowBuild(build)
        return
    end
    if tries > 30 then
        B.Print(L(ready and "PREVIEW_NOT_NOW" or "PREVIEW_NOT_READY"))
        Preview.Stop(true)
        return
    end
    B.Later(function() ShowWhenReady(build, tries + 1) end, 100)
end

function Preview.ShowBuild(build)
    pendingBuild = build
    if active then ShowWhenReady(build) end
end

function Preview.OnShown()
    active = true
    B.callbacks:FireCallbacks("PreviewChanged", true)
    ShowWhenReady(pendingBuild)
end

function Preview.OnHidden()
    if not active then return end
    active = false
    pcall(ClearCurrentItemPreviewCollection)
    B.callbacks:FireCallbacks("PreviewChanged", false)
    B.UI.AfterPreview(reopen)
end

-- Start: the window moves to the right, the camera turns to your character
function Preview.Start(build)
    if active then
        Preview.ShowBuild(build)
        return
    end
    -- (no "is previewing available" check here: the game only says yes once its preview
    -- screen is running, so it's checked in ShowWhenReady instead)
    if IsUnitInCombat("player") then
        B.Print(L("PREVIEW_NOT_NOW"))
        return
    end
    if not Create() then return end
    pendingBuild = build
    reopen = true
    B.UI.BeforePreview()
    SCENE_MANAGER:Show(SCENE_NAME)
end

-- Stop: back to the game; reopenWindow = show the normal window again
function Preview.Stop(reopenWindow)
    if not active then return end
    reopen = reopenWindow ~= false
    SCENE_MANAGER:ShowBaseScene()
end

function Preview.Init() end
