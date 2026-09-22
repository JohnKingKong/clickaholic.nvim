-- lua/clickaholic/init.lua
local M = {}

local store = require("clickaholic.store")

local RENDERERS = {
  winbar = "clickaholic.winbar",
  tabline = "clickaholic.tabline",
  lualine = "clickaholic.lualine",
  none = nil,
}

local config_buttons = {}
local merged_buttons = {}
local renderer = require("clickaholic.winbar")

local function validate(button)
  if button.action_type == "lua" then
    if type(button.action) ~= "function" then
      return false, "action must be a function when action_type is 'lua'"
    end
  elseif button.action_type == "cmd" or button.action_type == "shell" then
    if type(button.action) ~= "string" or button.action == "" then
      return false, "action must be a non-empty string when action_type is '" .. button.action_type .. "'"
    end
  else
    return false, "unknown action_type '" .. tostring(button.action_type) .. "'"
  end
  return true
end

local function merge()
  local stored = store.load(store.default_path())
  merged_buttons = {}
  for _, button in ipairs(config_buttons) do
    table.insert(merged_buttons, button)
  end
  for _, button in ipairs(stored) do
    table.insert(merged_buttons, button)
  end
end

function M.setup(opts)
  opts = opts or {}
  config_buttons = {}
  for _, button in ipairs(opts.buttons or {}) do
    local ok, err = validate(button)
    if ok then
      button.source = "config"
      table.insert(config_buttons, button)
    else
      vim.notify("clickaholic: invalid button '" .. tostring(button.label) .. "': " .. err, vim.log.levels.ERROR)
    end
  end

  local renderer_name = opts.renderer or "winbar"
  if not RENDERERS[renderer_name] and renderer_name ~= "none" then
    vim.notify(
      "clickaholic: unknown renderer '" .. tostring(renderer_name) .. "', falling back to 'winbar'",
      vim.log.levels.ERROR
    )
    renderer_name = "winbar"
  end
  renderer = RENDERERS[renderer_name] and require(RENDERERS[renderer_name]) or nil

  merge()
  M.apply_renderer()
end

function M.get_buttons()
  return merged_buttons
end

function M.refresh()
  merge()
end

-- The button manager UI calls this after every add/edit/delete/reorder
-- instead of requiring a specific renderer module itself, so it works the
-- same regardless of which renderer (or none) setup() selected.
function M.apply_renderer()
  if renderer then
    renderer.apply(merged_buttons)
  end
end

return M
