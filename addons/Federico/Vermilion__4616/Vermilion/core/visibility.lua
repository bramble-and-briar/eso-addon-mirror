Vermilion = Vermilion or {}
Vermilion.Visibility = {}
local M = Vermilion.Visibility

local Scene = Vermilion.zenimax.scene
local SCENE_SHOWN = Scene.SCENE_SHOWN
local log = Vermilion.Log.for_module("visibility")
local in_hud = true
local user_visible = { graph = false }
local restore = {}
local graph_shown = false
local AUX_WINDOWS = { "VermilionSettingsPanel", "VermilionLibrary", "VermilionAbout", "VermilionAssignPanel" }
local hud_watchers = {}

local function apply()
  if VermilionGraphWindow then
    local show = in_hud and user_visible.graph
    VermilionGraphWindow:SetHidden(not show)
    if not show and Vermilion.Graph and Vermilion.Graph.record_panel_close then Vermilion.Graph.record_panel_close() end
    if show and not graph_shown and Vermilion.Graph and Vermilion.Graph.on_shown then
      Vermilion.Graph.on_shown()
    end
    graph_shown = show
  end
  for _, name in ipairs(AUX_WINDOWS) do
    local win = _G[name]
    if win then
      if in_hud then
        if restore[name] then
          win:SetHidden(false)
          restore[name] = nil
        end
      elseif not win:IsHidden() then
        restore[name] = true
        win:SetHidden(true)
      end
    end
  end
  if Vermilion.Logo then
    Vermilion.Logo.sync(in_hud and not user_visible.graph)
  end
  for i = 1, #hud_watchers do hud_watchers[i](in_hud) end
end

function M.watch_hud(fn)
  hud_watchers[#hud_watchers + 1] = fn
  fn(in_hud)
end

function M.set(key, visible)
  if user_visible[key] == visible then return end
  log:info("set", key, "->", visible and "visible" or "hidden")
  user_visible[key] = visible
  apply()
end

function M.get(key) return user_visible[key] or false end

function M.master_toggle()
  M.set("graph", not user_visible.graph)
end

function M.init()
  user_visible.graph = false

  Scene.register_callback("SceneStateChanged",
    function(scene, oldState, newState)
      if newState ~= SCENE_SHOWN then return end
      local now = Scene.is_hud_scene(scene:GetName())
      if now == in_hud then return end
      in_hud = now
      apply()
    end)

  apply()
end
