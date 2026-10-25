-- Cosmetic HUD presentation only. Map selection, zoom and pin positions remain native.
local addon = PBS_MINIMAP
if not addon then return end

-- Where the texture actually is.
--
-- "PBsMiniMap/assets/compass-frame.dds" is the folder name on a PC install, and it is not
-- necessarily the folder the console put the add-on in, so the frame came up empty on PS5
-- while the circular clip worked. The add-on manager knows the real directory; PBsJanken hit
-- exactly this and settled on trying both, which is what this does.
--
-- Textures also load asynchronously: a control that has just been pointed at a file reports
-- nothing useful for a few frames, so a candidate cannot be judged on the frame it is set.
-- PollCompassTexture gives each one a moment before moving to the next, and stops for good
-- once one loads at the size the file really is.
local TEXTURE_FILE = "assets/compass-frame.dds"
local TEXTURE_SIZE = 512
local RETRY_TICKS = 10

local function TextureRoots()
    local roots = { "PBsMiniMap/" }
    local manager = GetAddOnManager and GetAddOnManager()
    if not manager or not manager.GetAddOnRootDirectoryPath then
        return roots
    end
    for index = 1, manager:GetNumAddOns() do
        local name = manager:GetAddOnInfo(index)
        if name == "PBsMiniMap" then
            local root = manager:GetAddOnRootDirectoryPath(index)
            if type(root) == "string" and root ~= "" then
                root = root:gsub("\\", "/"):gsub("/*$", "/")
                if root ~= roots[1] then
                    roots[#roots + 1] = root
                end
            end
            break
        end
    end
    return roots
end

function addon:ApplyCompassTexture(frame, rootIndex)
    self.compassRoots = self.compassRoots or TextureRoots()
    self.compassRootIndex = rootIndex
    self.compassTextureWait = 0
    self.compassTextureSettled = false
    frame:SetTexture((self.compassRoots[rootIndex] or self.compassRoots[1]) .. TEXTURE_FILE)
end

-- Called from the 50ms watch, and only until a candidate has loaded.
function addon:PollCompassTexture()
    local frame = self.compassFrame
    if self.compassTextureSettled or not frame or frame:IsHidden() then
        return
    end
    if frame.IsTextureLoaded and frame:IsTextureLoaded() then
        local width, height = frame:GetTextureFileDimensions()
        if width == TEXTURE_SIZE and height == TEXTURE_SIZE then
            self.compassTextureSettled = true
            return
        end
    end
    local roots = self.compassRoots or { "PBsMiniMap/" }
    if #roots < 2 then
        return
    end
    self.compassTextureWait = (self.compassTextureWait or 0) + 1
    if self.compassTextureWait < RETRY_TICKS then
        return
    end
    self:ApplyCompassTexture(frame, (self.compassRootIndex or 1) % #roots + 1)
end

-- One line for the existing troubleshooting report.
function addon:CompassTextureStatus()
    local frame = self.compassFrame
    if not frame then
        return "compass frame not built"
    end
    local loaded = frame.IsTextureLoaded and frame:IsTextureLoaded()
    local width, height = frame:GetTextureFileDimensions()
    return string.format("compass texture=%s loaded=%s file=%dx%d hidden=%s settled=%s blackout=%s",
        tostring(frame.GetTextureFileName and frame:GetTextureFileName() or "?"),
        tostring(loaded), width or -1, height or -1,
        tostring(frame:IsHidden()), tostring(self.compassTextureSettled),
        ZO_WorldMapMapBlackOut and tostring(ZO_WorldMapMapBlackOut:IsHidden()) or "missing")
end

-- The black square behind the map.
--
-- ZO_WorldMapMapBlackOut is a plain 000000 texture anchored across ZO_WorldMapScroll
-- (worldmap.xml), and it is a *sibling* of that scroll rather than a child, so the circular
-- clip never touched it: the map came up correctly round with a black square around it.
-- Nothing in the client's Lua refers to it, so it is simply the backing the map is drawn on.
--
-- Hidden while the circle is up and put back exactly as it was afterwards -- the standard map
-- wants it, and so does the rectangular style.
local function SetBlackOutHidden(self, hidden)
    local blackOut = ZO_WorldMapMapBlackOut
    if not blackOut then return end
    if hidden then
        if self.compassBlackOutWas == nil then
            self.compassBlackOutWas = blackOut:IsHidden()
        end
        if not blackOut:IsHidden() then
            blackOut:SetHidden(true)
        end
    elseif self.compassBlackOutWas ~= nil then
        blackOut:SetHidden(self.compassBlackOutWas)
        self.compassBlackOutWas = nil
    end
end

function addon:ApplyLiteMapStyle()
    local scroll = ZO_WorldMapScroll
    if not scroll then return end
    local active = self.account and self.account.enableMap and not self.dormant
        and (self.initLevel or 0) < 3
        and not self.IsWorldMapInFront()
        and not self.IsWorldMapShownElsewhere()
    local circular = active and self.account.mapStyle == "compass"
    if not circular then
        if self.compassClipApplied then
            scroll:ClearCircularClip()
            self.compassClipApplied = false
        end
        if self.compassFrame then self.compassFrame:SetHidden(true) end
        SetBlackOutHidden(self, false)
        return
    end
    SetBlackOutHidden(self, true)

    if not self.compassFrame then
        local frame = WINDOW_MANAGER:CreateControl("PBsMiniMapCompassFrame", ZO_WorldMap, CT_TEXTURE)
        frame:SetMouseEnabled(false)
        frame:SetDrawTier(DT_HIGH)
        frame:SetDrawLayer(DL_OVERLAY)
        frame:SetDrawLevel(200)
        frame:SetAnchor(CENTER, scroll, CENTER)
        self.compassFrame = frame
        self:ApplyCompassTexture(frame, 1)
    end
    local width, height = scroll:GetDimensions()
    local diameter = math.min(width, height)
    local x, y = scroll:GetCenter()
    -- Clip coordinates are screen UI units (as in ESO's ZO_RevealingControl).
    -- The cut lies beneath the opaque metal annulus, not in the transparent aperture.
    scroll:SetCircularClip(x, y, diameter * (self.account.showBorder and 0.42 or 0.49))
    self.compassClipApplied = true
    self.compassFrame:SetDimensions(diameter, diameter)
    self.compassFrame:SetHidden(not self.account.showBorder)
end

-- Nothing is hooked on the game's own controls.
--
-- The first version post-hooked ZO_WorldMapScroll's OnRectChanged handler. This add-on keeps
-- every hook it installs in one registry (HookHotPath / SwapHook) and swaps them out while the
-- standard map is in front, because writing a shared slot that does not belong to us is how
-- HarvestMap's pins were silently broken in 2.0.13. That handler sat outside the registry and
-- was never removed, so another add-on setting the same handler would stop the clip updating
-- without a trace.
--
-- It is not needed: the only things that resize the viewport are ApplyLiteMinimapLayout, which
-- now re-cuts the circle itself, and the standard map coming forward, which runs ApplyLiteBorder
-- on the way into dormancy. ApplyLiteBorder calls this too, so settings changes are covered.
