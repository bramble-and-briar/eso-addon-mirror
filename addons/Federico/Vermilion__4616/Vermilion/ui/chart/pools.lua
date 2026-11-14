Vermilion = Vermilion or {}
Vermilion.ChartPools = {}
local M = Vermilion.ChartPools

local zc         = Vermilion.zenimax.constants
local CT_TEXTURE = zc.CT_TEXTURE
local Pool       = Vermilion.lib.plot.Pool

local FILL_TEXTURE   = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local FILL_T, FILL_B = 0, 0.53125
local LINE_THICKNESS = 2

local controls

function M.bind(c) controls = c end

local function fill_factory(c)
  c:SetTexture(FILL_TEXTURE)
  c:SetTextureCoords(0, 1, FILL_T, FILL_B)
  c:SetPixelRoundingEnabled(false)
end

local function fill_reset(c) c:SetHidden(true) end

local function line_factory(line) line:SetThickness(LINE_THICKNESS) end

local function line_reset(line)
  line:SetHidden(true)
  line:ClearAnchors()
end

local function make_fill_pool(name_prefix)
  return Pool.new(name_prefix, controls.canvas, CT_TEXTURE, fill_factory, fill_reset)
end

local function make_line_pool(name_prefix)
  return Pool.new_virtual(name_prefix, controls.canvas, "VermilionGraphLineTemplate", line_factory, line_reset)
end

local function release_all_pools()
  controls.pool_eos_segments:ReleaseAllObjects()
  controls.pool_edps:ReleaseAllObjects()
  controls.pool_shdps:ReleaseAllObjects()
  if controls.pool_shield then
    controls.pool_shield:ReleaseAllObjects()
    controls.pool_shield_icon:ReleaseAllObjects()
    controls.pool_ult:ReleaseAllObjects()
    controls.pool_ult_icon:ReleaseAllObjects()
    controls.pool_kill:ReleaseAllObjects()
    controls.pool_dead:ReleaseAllObjects()
    controls.pool_res:ReleaseAllObjects()
    controls.pool_res_lbl:ReleaseAllObjects()
  end
  if controls.pool_c_seg then
    controls.pool_c_seg:ReleaseAllObjects()
    controls.pool_c_rim:ReleaseAllObjects()
    controls.pool_c_icon:ReleaseAllObjects()
    controls.pool_panel:ReleaseAllObjects()
    controls.pool_c_lbl:ReleaseAllObjects()
  end
  if controls.pool_d_seg then
    controls.pool_d_seg:ReleaseAllObjects()
    controls.pool_d_rim:ReleaseAllObjects()
    controls.pool_d_icon:ReleaseAllObjects()
    controls.pool_d_lbl:ReleaseAllObjects()
  end
  if controls.pool_t_seg then
    controls.pool_t_seg:ReleaseAllObjects()
    controls.pool_t_rim:ReleaseAllObjects()
    controls.pool_t_lbl:ReleaseAllObjects()
    controls.pool_t_sub:ReleaseAllObjects()
  end
  if controls.pool_viz_cd then controls.pool_viz_cd:ReleaseAllObjects() end
  if controls.pool_viz_line then controls.pool_viz_line:ReleaseAllObjects() end
end

M.FILL_TEXTURE = FILL_TEXTURE
M.fill_factory, M.fill_reset = fill_factory, fill_reset
M.fill, M.line, M.release_all = make_fill_pool, make_line_pool, release_all_pools
