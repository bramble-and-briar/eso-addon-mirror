Verdant = Verdant or {}
local Verdant = Verdant
Verdant.Visibility = {}
local M = Verdant.Visibility

local Scene = Verdant.zenimax.scene
local SCENE_SHOWN = Scene.SCENE_SHOWN
local log = Verdant.Log.for_module("visibility")
local in_hud = true
local user_visible = { graph = false }
local restore = {}
local AUX_WINDOWS = { "VerdantSettingsPanel", "VerdantLibrary", "VerdantAssignPanel", "VerdantWatchOverlay" }


local graph_shown = false
local listeners = {}
local hud_watchers = {}

local function apply()
  if VerdantGraphWindow then
    local show = in_hud and user_visible.graph
    VerdantGraphWindow:SetHidden(not show)
    if not show and Verdant.Graph and Verdant.Graph.record_panel_close then Verdant.Graph.record_panel_close() end
    if show and not graph_shown and Verdant.Graph and Verdant.Graph.on_shown then
      Verdant.Graph.on_shown()
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
  if Verdant.Logo then
    Verdant.Logo.sync(in_hud and not user_visible.graph)
  end
  for i = 1, #hud_watchers do hud_watchers[i](in_hud) end
end

function M.watch_hud(fn)
  hud_watchers[#hud_watchers + 1] = fn
  fn(in_hud)
end

local function persist()
  local sv = Verdant.SavedVars
  if not sv then return end
  sv.temporal = sv.temporal or {} ; sv.temporal.visible = user_visible.graph
end

function M.set(key, visible)
  if user_visible[key] == visible then return end
  log:info("set", key, "->", visible and "visible" or "hidden")
  user_visible[key] = visible
  apply()
  persist()
  for i = 1, #listeners do listeners[i](key, visible) end
end

function M.on_set(fn) listeners[#listeners + 1] = fn end

function M.get(key) return user_visible[key] or false end

function M.init()
  local sv = Verdant.SavedVars
  if sv then
    user_visible.graph = (sv.temporal and sv.temporal.visible) or false
  end

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
