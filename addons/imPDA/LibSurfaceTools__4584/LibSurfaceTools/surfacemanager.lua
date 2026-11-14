local floor = math.floor
local class = IMP_LibSurfaceTools__class

-- ----------------------------------------------------------------------------


local function __surfaceProxy(compositeManager, stableId)
    local compositeControl = compositeManager.composite
    local proxy = {}

    local mt = {
        __index = function(t, methodName)
            local method = compositeControl[methodName]
            -- does not check is correct method called btw
            if method then
                local f = function(_, ...)
                    method(compositeControl, stableId, ...)
                    return t
                end
                t[methodName] = f
                return f
            end
            return nil
        end
    }

    function proxy:RemoveSurface()
        compositeManager:RemoveSurface(stableId)
    end

    function proxy:SetInsets(iL, iR, iT, iB)
        compositeControl:SetInsets(stableId, iL, iR, iT, iB)
        return proxy
    end

    -- TODO: it seems to work incorrectly when called via proxy?
    -- can't reproduce because I don't need this function anymore
    -- function proxy:GetInsets()
    --     return compositeControl:GetInsets(stableId)
    -- end

    setmetatable(proxy, mt)
    return proxy
end


local SurfaceManager = class()

function SurfaceManager:__init(composite)
    self.composite = composite
    self.vacancies = {}
end

function SurfaceManager:AddSurface(l, r, t, b)
    local surfaceIndex = next(self.vacancies)
    local composite = self.composite

    if surfaceIndex then
        self.vacancies[surfaceIndex] = nil

        composite:SetTextureCoords(surfaceIndex, l, r, t, b)
        composite:SetInsets(surfaceIndex, 0, 0, 0, 0)
        composite:SetSurfaceTextureRotation(surfaceIndex, 0, 0, 0)
        -- composite:SetSurfaceScale(surfaceIndex, 1)  -- ?
        composite:SetSurfaceAlpha(surfaceIndex, 1)
        composite:SetColor(surfaceIndex, 1, 1, 1, 1)  -- includes alpha or it is different?

        composite:SetSurfaceHidden(surfaceIndex, false)
        return __surfaceProxy(self, surfaceIndex)
    end

    surfaceIndex = composite:AddSurface(l, r, t, b)
    return __surfaceProxy(self, surfaceIndex)
end

function SurfaceManager:RemoveSurface(stableId)
    self.composite:SetSurfaceHidden(stableId, true)
    self.vacancies[stableId] = true
end

-- local function _atlasIndexToAtlasXY(atlasIndex, atlasSizeX, atlasSizeY)
--     atlasIndex = atlasIndex - 1
--     return atlasIndex % atlasSizeX + 1, floor(atlasIndex / atlasSizeY) + 1
-- end

-- function SurfaceManager:GetTextureInsets(atlasIndex)
--     if atlasIndex == nil then
--         return 0, 1, 0, 1
--     else
--         -- TODO: can store as precomputed values
--         local atlasStepX, atlasStepY = 1 / self.atlasSizeX, 1 / self.atlasSizeY

--         local atlasX, atlasY = _atlasIndexToAtlasXY(atlasIndex, self.atlasSizeX, self.atlasSizeY)

--         local tiR = atlasX * atlasStepX
--         local tiL = tiR - atlasStepX
--         local tiB = atlasY * atlasStepY
--         local tiT = tiB - atlasStepY

--         return tiL, tiR, tiT, tiB
--     end
-- end


IMP_LibSurfaceTools__SurfaceManager = SurfaceManager


-- RemoveSurface(*luaindex* _surfaceIndex_)
-- SetInsets(*luaindex* _surfaceIndex_, *number* _left_, *number* _right_, *number* _top_, *number* _bottom_)
-- SetColor(*luaindex* _surfaceIndex_, *number* _r_, *number* _g_, *number* _b_, *number* _a_)
-- SetSurfaceAlpha(*luaindex* _surfaceIndex_, *number* _a_)
-- SetSurfaceHidden(*luaindex* _surfaceIndex_, *bool* _hidden_)
-- SetSurfaceScale(*luaindex* _surfaceIndex_, *number* _scale_)
-- SetSurfaceTextureRotation(*luaindex* _surfaceIndex_, *number* _angleInRadians_, *number* _normalizedRotationPointX_, *number* _normalizedRotationPointY_)
-- SetTextureCoords(*luaindex* _surfaceIndex_, *number* _left_, *number* _right_, *number* _top_, *number* _bottom_)

-- GetColor(*luaindex* _surfaceIndex_)
-- GetInsets(*luaindex* _surfaceIndex_)
-- GetSurfaceAlpha(*luaindex* _surfaceIndex_)
-- GetTextureCoords(*luaindex* _surfaceIndex_)
-- IsSurfaceHidden(*luaindex* _surfaceIndex_)

-- AddSurface(*number* _left_, *number* _right_, *number* _top_, *number* _bottom_)
-- SetTexture(*string* _filename_)
-- GetNumSurfaces()
-- ClearAllSurfaces()
-- GetBlendMode()
-- GetDesaturation()
-- GetTextureFileDimensions()
-- GetTextureFileName()
-- IsPixelRoundingEnabled()
-- IsTextureLoaded()
-- SetBlendMode(*[TextureBlendMode|#TextureBlendMode]* _blendMode_)
-- SetDesaturation(*number* _desaturation_)
-- SetPixelRoundingEnabled(*bool* _pixelRoundingEnabled_)
-- SetTextureReleaseOption(*[ReleaseReferenceOptions|#ReleaseReferenceOptions]* _releaseOption_)
