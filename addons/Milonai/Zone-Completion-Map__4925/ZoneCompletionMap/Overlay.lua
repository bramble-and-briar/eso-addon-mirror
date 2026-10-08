ZoneCompletionMap = ZoneCompletionMap or {}

local Overlay = {}
ZoneCompletionMap.Overlay = Overlay

-- Map tiles draw at level 0, the native mouseover blob at level 2.
local DRAW_LEVEL = 1

local root
local textures = {}
local shownBlobs = {}
local lastWidth, lastHeight

local function LayoutTexture(texture, blob, width, height)
    texture:SetDimensions(blob.w * width, blob.h * height)
    texture:ClearAnchors()
    texture:SetAnchor(TOPLEFT, root, TOPLEFT, blob.x * width, blob.y * height)
end

local function GetRoot()
    if not root then
        root = WINDOW_MANAGER:CreateControl("ZoneCompletionMapOverlay", ZO_WorldMapContainer, CT_CONTROL)
        root:SetAnchorFill(ZO_WorldMapContainer)
        root:SetHandler("OnUpdate", function()
            local width, height = ZO_WorldMap_GetMapDimensions()
            if width ~= lastWidth or height ~= lastHeight then
                Overlay.Relayout()
            end
        end)
    end
    return root
end

local function GetTexture(index)
    local texture = textures[index]
    if not texture then
        texture = WINDOW_MANAGER:CreateControl(nil, GetRoot(), CT_TEXTURE)
        texture:SetDrawLevel(DRAW_LEVEL)
        texture:SetBlendMode(TEX_BLEND_MODE_ALPHA)
        texture:SetPixelRoundingEnabled(false)
        textures[index] = texture
    end
    return texture
end

function Overlay.Show(blobs, color)
    GetRoot():SetHidden(false)
    shownBlobs = blobs
    local width, height = ZO_WorldMap_GetMapDimensions()
    lastWidth, lastHeight = width, height
    for i, blob in ipairs(blobs) do
        local texture = GetTexture(i)
        texture:SetTexture(blob.texture)
        texture:SetColor(color.r, color.g, color.b, color.a)
        LayoutTexture(texture, blob, width, height)
        texture:SetHidden(false)
    end
    for i = #blobs + 1, #textures do
        textures[i]:SetHidden(true)
    end
end

function Overlay.Hide()
    shownBlobs = {}
    if root then
        root:SetHidden(true)
    end
end

function Overlay.Relayout()
    local width, height = ZO_WorldMap_GetMapDimensions()
    lastWidth, lastHeight = width, height
    for i, blob in ipairs(shownBlobs) do
        LayoutTexture(textures[i], blob, width, height)
    end
end
