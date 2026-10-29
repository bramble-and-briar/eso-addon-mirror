-- =============================================================================
-- CasualClean -- UI/PvPUA.lua
-- =============================================================================
-- Hides the credit line ("DC, the BEST Alliance! - user562", animated) at the
-- top of the PvP UA! add-on's under-attack list, and closes the gap it leaves.
-- Inert when PvP UA! is not installed. The add-on's own folder/manifest name
-- is PvPUA (package pvp_ua__5.1 read 2026-10-17).
--
-- WHAT PvP UA! DOES, from its shipped PvPUA.lua (5.1):
--
--   * Its namespace is `local PvPUA = {}` -- nothing of it is reachable as a
--     global except the controls it names. The window is
--     wm:CreateTopLevelWindow("PvPUA_TLW"); every child is created with a nil
--     name, so the credit label has no global of its own.
--   * The credit label is a CT_LABEL child of PvPUA_TLW, anchored TOPLEFT at
--     (0, 0), 20 units tall, and everything else in the header sits at
--     baseY >= 20 (ApplyHeaderLayout re-anchors from those baseY fields, plus
--     a shift in Imperial City). So the line costs exactly its own height of
--     window space, above everything.
--   * Its text cycles through 27 animated states on the list's update timer,
--     and EVERY state contains the literal "the BEST" (the colour markup is
--     around it, not inside it). OnUiUpdate calls creditLabel:SetHidden(false)
--     and SetText(...) on every tick, and the list-hide path calls
--     SetHidden(true). It never calls SetAlpha on the label and never calls
--     SetTransformOffset on the window.
--
-- SO THE HIDE IS TWO THINGS THE ADD-ON NEVER TOUCHES:
--
--   1. label:SetAlpha(0). A plain SetHidden(true) would be undone on the next
--      update tick; alpha is not.
--   2. PvPUA_TLW:SetTransformOffset(0, -labelHeight, 0). A render-space nudge
--      that moves the whole window up by the hidden line's height, so the
--      info row draws where the credit line used to start. It is independent
--      of anchors, so the add-on's ApplyPosition / ApplyHeaderLayout /
--      OnUiUpdate re-anchoring cannot undo it, and SetClampedToScreen (anchor
--      based) is unaffected.
--
-- Both are restored exactly (alpha 1, offset 0) when the setting is off.
--
-- FINDING THE LABEL. Direct children of PvPUA_TLW are scanned
-- (GetNumChildren / GetChild) for a CT_LABEL whose GetText() contains
-- "the BEST". The other labels directly under the window (rank number, AP
-- text, K/D) never contain it. If the author changes the text, nothing
-- matches and this module does nothing, which is the right failure.
--
-- TIMING. PvP UA! builds its window in its own EVENT_ADD_ON_LOADED, and load
-- order between add-ons is not something to rely on, so this resolves from
-- Refresh (RefreshState: EVENT_PLAYER_ACTIVATED and friends) with a short
-- retry, the same shape as the companion-frame and attribute-bar retries.
--
-- IN-GAME CHECK STILL OWED: whether SetTransformOffset's units are the
-- window's own (pre-scale) space. PvP UA! applies SetScale to the window from
-- its uiScale setting; if the offset turns out to be post-scale, the shift
-- should be labelHeight * scale. `/casualclean pvpua` prints both numbers.
-- =============================================================================

CasualClean = CasualClean or {}
local CC = CasualClean
CC.PvPUA = {}
local P = CC.PvPUA

-- On by default: this only ever acts when PvP UA! is installed, and hiding
-- the line is the whole reason the feature exists.
P.DEFAULT_ENABLED = true

local WINDOW_NAME = "PvPUA_TLW"
local LABEL_MATCH = "the BEST"
local RETRY_MS, RETRY_ATTEMPTS = 250, 8

local window, label = nil, nil
local applied = false          -- our alpha/offset are currently in place
local appliedShift = 0         -- the offset we set, so Refresh never doubles it
local retryPending = false
local missing = nil            -- report line when the add-on is absent

-- -----------------------------------------------------------------------------
-- Catching the label at creation
-- -----------------------------------------------------------------------------
-- The third console report (2026-10-17) showed GetNumChildren() == 10 for the
-- window while GetChild(i) returned nil for every index 0..10. ZOS's own code
-- iterates children exactly that way, so this is a console difference for
-- add-on code (or for anonymous children); either way enumeration is useless
-- there, and the label has no name and no global.
--
-- What the source does give us is the exact call that creates it:
--     wm:CreateControl(nil, self.controls.TLW, CT_LABEL)
-- in PvPUA:CreateUI, where wm is `local wm = WINDOW_MANAGER` (the same
-- object), and it is the FIRST CT_LABEL created with that window as parent
-- (the entry rows are created under rootControl, not the window). So this
-- file wraps WINDOW_MANAGER.CreateControl at parse time -- the earliest point
-- CasualClean has -- and keeps the first label created under PvPUA_TLW.
--
-- Two things can defeat it, and both are reported rather than hidden:
--   * load order: PvP UA! must load after CasualClean. Its own dependency
--     AAAConsoleUIShim is named to sort first, which says load order on
--     console is alphabetical, and "CasualClean" sorts before "PvPUA".
--     If the window already exists when this file runs, the wrapper is too
--     late and says so.
--   * the field write: WINDOW_MANAGER is a userdata. Controls accept Lua
--     fields (PvP UA! itself stores TLW.rootControl), so the write should
--     take, and the method lookup should see the field. It is done under
--     pcall and verified by reading the field back.
local captured = nil           -- the label, once CreateControl hands it to us
local hookState = "not attempted"

local function InstallCreateHook()
    local wm = _G["WINDOW_MANAGER"]
    if not (wm and wm.CreateControl) then
        hookState = "no WINDOW_MANAGER.CreateControl"
        return
    end
    if _G[WINDOW_NAME] ~= nil then
        hookState = "too late: " .. WINDOW_NAME .. " already existed (PvP UA! loaded first)"
        return
    end
    local original = wm.CreateControl
    local function wrapped(self, name, parent, controlType, ...)
        local control = original(self, name, parent, controlType, ...)
        if captured == nil and control ~= nil and controlType == CT_LABEL and parent ~= nil
           and parent.GetName and parent:GetName() == WINDOW_NAME then
            captured = control
        end
        return control
    end
    local ok, err = pcall(function() wm.CreateControl = wrapped end)
    if not ok then
        hookState = "field write failed: " .. tostring(err)
        return
    end
    if wm.CreateControl ~= wrapped then
        hookState = "field write ignored: method lookup does not see the field"
        return
    end
    hookState = "installed before " .. WINDOW_NAME .. " existed"
end

InstallCreateHook()

local function sv()
    return CC.sv
end

function P.GetEnabled()
    local s = sv()
    if s and s.hidePvpuaCredit ~= nil then
        return s.hidePvpuaCredit
    end
    return P.DEFAULT_ENABLED
end

-- -----------------------------------------------------------------------------
-- Resolution
-- -----------------------------------------------------------------------------
-- A label is recognised by EITHER its control type OR its methods: GetType()
-- == CT_LABEL is how ZOS tests it, but duck typing on GetText +
-- SetHorizontalAlignment (which textures, backdrops and plain controls lack)
-- costs nothing and removes one assumption from a console we cannot debug on.
local function IsLabelLike(child)
    if child.GetType and child:GetType() == CT_LABEL then
        return true
    end
    return type(child.GetText) == "function" and type(child.SetHorizontalAlignment) == "function"
end

-- Vertical position of a child relative to the window's top, in the window's
-- own units. Screen space (GetTop) first, divided by the window's scale,
-- because it needs no anchor to be valid; the first anchor's offsetY second.
local function RelativeTop(tlw, child)
    if child.GetTop and tlw.GetTop then
        local ct, wt = child:GetTop(), tlw:GetTop()
        if type(ct) == "number" and type(wt) == "number" then
            local scale = tlw.GetScale and tlw:GetScale() or 1
            if type(scale) ~= "number" or scale <= 0 then scale = 1 end
            return (ct - wt) / scale, "top"
        end
    end
    if child.GetAnchor then
        local valid, _, _, _, _, oy = child:GetAnchor(0)   -- anchor index is 0-based
        if valid and type(oy) == "number" then
            return oy, "anchor"
        end
    end
    return nil, "none"
end

-- Every direct child of the window, in creation order, with what the finder
-- and the report need to know about it.
local function Children(tlw)
    local list = {}
    local n = tlw:GetNumChildren()
    for i = 1, n do
        local child = tlw:GetChild(i)
        if child then
            local y, how = RelativeTop(tlw, child)
            local text = child.GetText and child:GetText() or nil
            list[#list + 1] = {
                control = child, index = i, isLabel = IsLabelLike(child),
                ctype = child.GetType and child:GetType() or nil,
                name = child.GetName and child:GetName() or nil,
                y = y, yHow = how,
                text = type(text) == "string" and text or "",
                height = child.GetHeight and child:GetHeight() or nil,
            }
        end
    end
    return list
end

local function LabelChildren(tlw)
    local labels = {}
    for _, entry in ipairs(Children(tlw)) do
        if entry.isLabel then
            entry.offsetY = entry.y
            labels[#labels + 1] = entry
        end
    end
    return labels
end

-- Two identifications, in order:
--   1. by text: the label whose text contains "the BEST" (true from creation
--      in the 5.1 package, where CreateUI sets CREDIT_STATES[0] at once);
--   2. by geometry: the credit label is the only header label whose anchor
--      sits at the window's top (baseY 0; the rank, AP and K/D labels are at
--      baseY >= 20). So, failing a text match, take the CT_LABEL child with
--      the smallest anchor Y, provided the next label is at least
--      MIN_GAP_BELOW lower, so a window with a different layout matches
--      nothing rather than something wrong.
-- Added 2026-10-17 after the console build reported "no label containing
-- 'the BEST'": its credit text evidently is not set until the list first
-- updates, which is after every point this module resolves.
local MIN_GAP_BELOW = 12

local function FindLabel(tlw)
    local labels = LabelChildren(tlw)
    for _, entry in ipairs(labels) do
        if entry.text:find(LABEL_MATCH, 1, true) then
            return entry.control, "text"
        end
    end
    local top, second = nil, nil
    for _, entry in ipairs(labels) do
        if entry.offsetY then
            if not top or entry.offsetY < top.offsetY then
                second = top
                top = entry
            elseif not second or entry.offsetY < second.offsetY then
                second = entry
            end
        end
    end
    if top and second and (second.offsetY - top.offsetY) >= MIN_GAP_BELOW then
        return top.control, "geometry"
    end
    return nil
end

local function Resolve()
    if window and label then
        return true
    end
    local tlw = _G[WINDOW_NAME]
    if type(tlw) ~= "userdata" and type(tlw) ~= "table" then
        missing = WINDOW_NAME .. " (PvP UA! not installed or not loaded yet)"
        return false
    end
    if not (tlw.GetNumChildren and tlw.GetChild and tlw.SetTransformOffset) then
        missing = WINDOW_NAME .. " lacks the expected control methods"
        return false
    end
    local found, how = FindLabel(tlw)
    if not found and captured ~= nil then
        found, how = captured, "creation hook"
    end
    if not found then
        missing = "no label under " .. WINDOW_NAME .. " containing '" .. LABEL_MATCH
            .. "' and no topmost label with a clear gap below it"
        return false
    end
    window, label, missing = tlw, found, nil
    P.foundBy = how
    return true
end

-- -----------------------------------------------------------------------------
-- Apply / restore
-- -----------------------------------------------------------------------------
local function Apply()
    local shift = label:GetHeight() or 0
    label:SetAlpha(0)
    window:SetTransformOffset(0, -shift, 0)
    applied, appliedShift = true, shift
end

local function Restore()
    if not applied then
        return
    end
    if label and label.SetAlpha then
        label:SetAlpha(1)
    end
    if window and window.SetTransformOffset then
        window:SetTransformOffset(0, 0, 0)
    end
    applied, appliedShift = false, 0
end

local function RefreshWithRetry(attemptsLeft)
    retryPending = false
    if not P.GetEnabled() then
        Restore()
        return
    end
    if Resolve() then
        -- Idempotent: re-applying sets the same alpha and the same absolute
        -- offset, never an accumulated one.
        Apply()
        return
    end
    if attemptsLeft > 0 and type(zo_callLater) == "function" then
        retryPending = true
        zo_callLater(function() RefreshWithRetry(attemptsLeft - 1) end, RETRY_MS)
    end
end

-- -----------------------------------------------------------------------------
-- Public surface
-- -----------------------------------------------------------------------------
function P.Refresh()
    if retryPending then
        return   -- a retry chain is already running; it re-reads the setting
    end
    RefreshWithRetry(RETRY_ATTEMPTS)
end

function P.SetEnabled(value)
    local s = sv()
    if s then
        s.hidePvpuaCredit = value and true or false
    end
    if not value then
        Restore()
    end
    P.Refresh()
end

function P.Init()
    P.Refresh()
end

-- For `/casualclean pvpua`.
function P.GetReport()
    local out = {}
    out[#out + 1] = string.format("enabled=%s resolved=%s applied=%s shift=%s retryPending=%s",
        tostring(P.GetEnabled()), tostring(window ~= nil and label ~= nil), tostring(applied),
        tostring(appliedShift), tostring(retryPending))
    out[#out + 1] = string.format("creation hook: %s; captured=%s", hookState, tostring(captured ~= nil))
    if missing then
        out[#out + 1] = "missing: " .. missing
        -- The window exists but nothing matched: list what IS there, so the
        -- next report settles it without another upload round.
        local tlw = _G[WINDOW_NAME]
        if (type(tlw) == "userdata" or type(tlw) == "table") and tlw.GetNumChildren then
            out[#out + 1] = string.format("children of %s: %d (CT_LABEL=%s, window top=%s scale=%s)",
                WINDOW_NAME, tlw:GetNumChildren(), tostring(CT_LABEL),
                tostring(tlw.GetTop and tlw:GetTop()), tostring(tlw.GetScale and tlw:GetScale()))
            -- EVERY child, whatever its type, so a report can never be empty
            -- below this line while the window has children.
            local entries = Children(tlw)
            for _, entry in ipairs(entries) do
                local text = entry.text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
                out[#out + 1] = string.format("  child #%d type=%s label=%s y=%s(%s) h=%s name=%s text=%q",
                    entry.index, tostring(entry.ctype), tostring(entry.isLabel),
                    tostring(entry.y), entry.yHow, tostring(entry.height),
                    tostring(entry.name), text:sub(1, 40))
            end
            -- Third console report (2026-10-17): the count said 10, the loop
            -- above printed nothing, i.e. GetChild returned nothing for every
            -- index although ZOS's own code iterates it 1..n. Probe the call
            -- itself so the next report shows what it actually returns.
            if #entries == 0 then
                -- Plain field access only: rawget on a userdata control raises
                -- in Lua 5.1, which would kill the whole report unseen.
                out[#out + 1] = string.format("  probe: window is %s, rootControl field=%s, GetNumChildren=%s",
                    type(tlw), tostring(tlw.rootControl ~= nil), tostring(tlw:GetNumChildren()))
                local n = tlw:GetNumChildren()
                for i = 0, n do
                    local ok, res = pcall(tlw.GetChild, tlw, i)
                    local desc
                    if not ok then
                        desc = "error " .. tostring(res)
                    elseif res == nil then
                        desc = "nil"
                    else
                        local name = (type(res) == "userdata" or type(res) == "table") and res.GetName and res:GetName() or "?"
                        desc = string.format("%s name=%s", type(res), tostring(name))
                    end
                    out[#out + 1] = string.format("  probe GetChild(%d): %s", i, desc)
                end
            end
        end
    end
    if window and label then
        out[#out + 1] = "found by: " .. tostring(P.foundBy)
        local ox, oy, oz = 0, 0, 0
        if window.GetTransformOffset then ox, oy, oz = window:GetTransformOffset() end
        out[#out + 1] = string.format("label alpha=%s height=%s hidden=%s | window scale=%s offset=(%s, %s, %s)",
            tostring(label.GetAlpha and label:GetAlpha()), tostring(label:GetHeight()),
            tostring(label.IsControlHidden and label:IsControlHidden()),
            tostring(window.GetScale and window:GetScale()), tostring(ox), tostring(oy), tostring(oz))
    end
    return out
end
