local MCH = MonsterCofferHelper

local UI = {}
MCH.UI = UI

local WINDOW_WIDTH   = 440
local SIDE_PADDING   = 18
local HEADER_HEIGHT  = 46
local BOTTOM_PADDING = 16

local window, titleLabel, bodyLabel

-- True while the window is up because a vendor store opened, as opposed to the
-- player having asked for it. Only the former closes itself again.
local shownAutomatically = false
local currentVendorId

--------------------------------------------------------------------------------

local function ApplyPosition()
    local saved = MCH.db.panel
    window:ClearAnchors()
    window:SetAnchor(saved.point, GuiRoot, saved.relPoint, saved.x, saved.y)
end

local function Render(result, vendorId)
    titleLabel:SetText(MCH.Model.GetVendorName(vendorId))
    bodyLabel:SetText(MCH.Format.PanelBody(result))

    -- The body is a single wrapping label, so the window is sized to whatever
    -- the text ends up needing rather than to a guessed line count.
    --
    -- The label's own height is never set: it sizes itself to its text. Fixing
    -- it made GetTextHeight measure the text clipped to the previous height, so
    -- after one short body (a finished vendor, "no data") every later one was
    -- cut off with an ellipsis at that same height.
    local bodyHeight = bodyLabel:GetTextHeight()
    window:SetHeight(HEADER_HEIGHT + bodyHeight + BOTTOM_PADDING)
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function UI.Initialize()
    window     = MonsterCofferHelperWindow
    titleLabel = MonsterCofferHelperWindowTitle
    bodyLabel  = MonsterCofferHelperWindowBody

    window:SetWidth(WINDOW_WIDTH)
    window:SetMovable(not MCH.db.lockPanel)
    bodyLabel:SetWidth(WINDOW_WIDTH - SIDE_PADDING * 2)
    bodyLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    ApplyPosition()
end

-- `vendorId` is passed separately rather than read off the result, because the
-- result is nil when a vendor has no usable data and the window still has to
-- name the vendor it is reporting nothing about.
function UI.Show(result, vendorId, manual)
    if not window then return end

    currentVendorId = vendorId or (result and result.vendorId) or currentVendorId
    if not currentVendorId then return end

    -- Shown before rendering: GetTextHeight only measures a visible control, and
    -- the window is sized from that measurement.
    window:SetHidden(false)
    Render(result, currentVendorId)
    shownAutomatically = not manual
end

function UI.ShowVendor(vendorId, manual)
    UI.Show(MCH.Advisor.ForVendor(vendorId), vendorId, manual)
end

function UI.Hide()
    if window then window:SetHidden(true) end
    shownAutomatically = false
end

-- The close button: shut it now, and do not re-open it for this store visit.
function UI.Dismiss()
    UI.Hide()
end

function UI.HideIfAuto()
    if shownAutomatically then UI.Hide() end
end

function UI.IsShown()
    return window and not window:IsHidden()
end

-- The vendor worth looking at when the player asks out of the blue: whichever
-- one has the most shoulders left to collect.
local function MostRelevantVendor()
    local best, bestMissing = MCH.VENDOR_IDS[1], -1
    for _, vendorId in ipairs(MCH.VENDOR_IDS) do
        local pool = MCH.Model.GetPool(vendorId)
        if pool.missing > bestMissing then
            best, bestMissing = vendorId, pool.missing
        end
    end
    return best
end

function UI.Toggle()
    if UI.IsShown() then
        UI.Hide()
        return
    end

    local vendorId = MCH.Store.current and MCH.Store.current.vendorId
        or currentVendorId
        or MostRelevantVendor()
    UI.ShowVendor(vendorId, true)
end

-- Re-draw with fresh numbers after a setting changed or a shoulder was unlocked.
function UI.Refresh()
    if not UI.IsShown() or not currentVendorId then return end
    Render(MCH.Advisor.ForVendor(currentVendorId), currentVendorId)
end

function UI.OnMoveStop()
    local saved = MCH.db.panel
    saved.point, saved.relPoint = TOPLEFT, TOPLEFT
    saved.x, saved.y = window:GetLeft(), window:GetTop()
end

function UI.ResetPosition()
    local saved = MCH.db.panel
    saved.point, saved.relPoint, saved.x, saved.y = CENTER, CENTER, 0, 0
    ApplyPosition()
end

function UI.SetLocked(locked)
    if window then window:SetMovable(not locked) end
end
