local A, C, S = DeskUI, DeskUI.Core, DeskUI.Style
local P = S.palette

function A.BuildMapPage()
    local page = {tiles = {}}
    local root = WINDOW_MANAGER:CreateControl(nil, A.root, CT_CONTROL)
    page.root = root
    root:SetAnchor(TOPLEFT, A.root, TOPLEFT, 420, 238); root:SetDimensions(1404, 734)
    S.Panel(root, 0, 0, 1404, 734, nil, true)
    page.title = S.Label(root, 24, 10, 1356, 38, "MAP", P.text, 30, true)
    S.Rule(root, 24, 57, 1356)
    page.canvas = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
    page.canvas:SetAnchor(TOPLEFT, root, TOPLEFT, 24, 74); page.canvas:SetDimensions(640, 640)
    page.marker = S.Icon(page.canvas, 0, 0, 24, "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds")
    page.marker:SetHidden(true)
    page.info = S.Label(root, 704, 90, 670, 520, "", P.accent, 21)
    S.Button(root, 704, 655, 220, 38, "Refresh map", A.RefreshMap)
    A.MakeMovable(root, "map", A.root, 420, 238, 1404)
    return page
end

function A.RefreshMap()
    local page = A.pages.Map
    for _, tile in ipairs(page.tiles) do tile:SetHidden(true) end
    page.marker:SetHidden(true)
    local width, height = C.Try("GetMapNumTiles")
    page.title:SetText(C.Try("GetMapName") or "MAP")
    if type(width) ~= "number" or type(height) ~= "number" or width < 1 or height < 1
        or width * height > 64 or type(GetMapTileTexture) ~= "function" then
        page.info:SetText("Map tiles are unavailable on this client. Other DeskUI menus remain available.")
        return
    end
    local tw, th = 640 / width, 640 / height
    for index = 1, width * height do
        local tile = page.tiles[index]
        if not tile then
            tile = S.Texture(page.canvas, 0, 0, tw, th, "")
            -- Keep terrain behind the player marker, including tiles acquired later.
            tile:SetDrawLayer(DL_BACKGROUND)
            page.tiles[index] = tile
        end
        tile:ClearAnchors()
        tile:SetAnchor(TOPLEFT, page.canvas, TOPLEFT, ((index - 1) % width) * tw, math.floor((index - 1) / width) * th)
        tile:SetDimensions(tw, th); tile:SetTexture(C.Try("GetMapTileTexture", index) or ""); tile:SetHidden(false)
    end
    local x, y, heading, shown = C.Try("GetMapPlayerPosition", "player")
    if shown and type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        page.marker:ClearAnchors(); page.marker:SetAnchor(TOPLEFT, page.canvas, TOPLEFT, x * 640 - 12, y * 640 - 12)
        page.marker:SetTextureRotation(heading or 0); page.marker:SetHidden(false)
    end
    page.info:SetText("CURRENT MAP\n\n" .. (C.Try("GetMapName") or "Unnamed map")
        .. "\n\n" .. (shown and "Your position is marked on this map." or "Your position is outside the displayed map.")
        .. "\n\nThis viewer uses ESO's currently selected map without changing the shared map state."
        .. "\n\nZoom, panning, map selection, quest/POI pins, waypoints and fast travel remain in ESO's map interface.")
end
