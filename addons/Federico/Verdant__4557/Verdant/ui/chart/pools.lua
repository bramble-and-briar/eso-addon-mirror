Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ChartPools = {}
local M = Verdant.ChartPools

local zc         = Verdant.zenimax.constants
local CT_TEXTURE = zc.CT_TEXTURE
local Pool       = Verdant.lib.plot.Pool

local FILL_TEXTURE   = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local FILL_T, FILL_B = 0, 0.53125

local controls

function M.bind(shared)
  controls = shared.controls
end

local function fill_factory(c)
  c:SetTexture(FILL_TEXTURE)
  c:SetTextureCoords(0, 1, FILL_T, FILL_B)
  c:SetPixelRoundingEnabled(false)
end

local function fill_reset(c)
  c:SetHidden(true)
end

local function make_fill_pool(name_prefix, draw_level)
  return Pool.new(name_prefix, controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(draw_level or 2)
    end,
    fill_reset)
end

local function release_all_pools()
  if controls.pool_marker_icon then
    controls.pool_marker_icon:ReleaseAllObjects()
  end
  if controls.pool_buff_seg then
    controls.pool_buff_seg:ReleaseAllObjects()
    controls.pool_buff_rim:ReleaseAllObjects()
    controls.pool_buff_icon:ReleaseAllObjects()
    controls.pool_buff_lbl:ReleaseAllObjects()
  end
  if controls.pool_ult then
    controls.pool_ult:ReleaseAllObjects()
    controls.pool_ult_icon:ReleaseAllObjects()
  end
  controls.pool_ehps:ReleaseAllObjects()
  controls.pool_mps:ReleaseAllObjects()
  controls.pool_dmg_fill:ReleaseAllObjects()
  controls.pool_dead:ReleaseAllObjects()
  controls.dmg_label:SetHidden(true)
  controls.pool_skill:ReleaseAllObjects()
  controls.pool_legend_sw:ReleaseAllObjects()
  controls.pool_legend_lbl:ReleaseAllObjects()
  controls.pool_sustain_bar:ReleaseAllObjects()
  controls.pool_sustain_lbl:ReleaseAllObjects()
  controls.pool_sustain_icon:ReleaseAllObjects()
  Verdant.ChartGrid.hide(controls.grid_skill)
end

M.FILL_TEXTURE         = FILL_TEXTURE
M.fill_factory         = fill_factory
M.fill_reset           = fill_reset
M.make_fill_pool       = make_fill_pool
M.release_all          = release_all_pools
