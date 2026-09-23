-- lua/clickaholic/init.lua
local M = {}

local store = require("clickaholic.store")
local cwd_match = require("clickaholic.cwd_match")

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

  -- tabline.lua/lualine.lua re-pull get_visible_buttons() fresh on their
  -- own redraw cycle, so a cwd change (e.g. switching fireplaces) already
  -- shows/hides scoped buttons correctly for them without this. winbar.lua
  -- sets a static vim.o.winbar string at apply() time, though, so without
  -- an explicit re-apply here a directory-scoped button would only
  -- show/hide the next time some unrelated button edit happened to
  -- trigger apply_renderer() again.
  vim.api.nvim_create_autocmd({ "DirChanged", "TabEnter" }, {
    callback = M.apply_renderer,
  })
end

function M.get_buttons()
  return merged_buttons
end

-- Buttons filtered to the ones visible from the current directory: a
-- button with no cwd is global (always visible); one with a cwd only
-- shows there or in a subdirectory of it. This is what renderers should
-- draw -- get_buttons() stays the full raw list (config + stored,
-- unfiltered) for the manager UI, which needs to list every button
-- regardless of where you currently are so you can still edit one scoped
-- elsewhere.
function M.get_visible_buttons()
  local cwd = vim.fn.getcwd()
  local visible = {}
  for _, button in ipairs(merged_buttons) do
    if cwd_match.matches(button.cwd, cwd) then
      table.insert(visible, button)
    end
  end
  return visible
end

function M.refresh()
  merge()
end

-- The button manager UI calls this after every add/edit/delete/reorder
-- instead of requiring a specific renderer module itself, so it works the
-- same regardless of which renderer (or none) setup() selected.
function M.apply_renderer()
  if renderer then
    renderer.apply(M.get_visible_buttons())
  end
end

return M
