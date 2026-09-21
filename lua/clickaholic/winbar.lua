local M = {}

local current_buttons = {}

function M.set_buttons(buttons)
  current_buttons = buttons
end

function M.click(id)
  local button = current_buttons[id]
  if button then
    require("clickaholic.actions").run(button)
  end
end

function M.render(buttons)
  if #buttons == 0 then
    return ""
  end
  local parts = { "%<" }
  for i, button in ipairs(buttons) do
    table.insert(
      parts,
      string.format("%%%d@v:lua.require'clickaholic.winbar'.click@ %s %s %%X", i, button.icon, button.label)
    )
  end
  return table.concat(parts)
end

-- The button bar lives in one dedicated floating window rather than
-- `vim.o.winbar`, so it appears exactly once (never duplicated per split)
-- and doesn't fight `vim.o.tabline` for ownership (bufferline.nvim already
-- owns that). Floating windows can't have zero body rows, so this costs one
-- blank spacer row beneath the winbar row that actually renders the
-- buttons; that's a Neovim limitation on floating windows, not a bug here.
M._bar_win = nil
local bar_buf = nil
local autocmds_registered = false

-- Number of rows Neovim's own tabline is currently occupying (0 or 1),
-- mirroring the exact conditions from `:help showtabline` so the bar sits
-- immediately below it rather than overlapping.
local function tabline_offset()
  if vim.o.showtabline == 2 then
    return 1
  end
  if vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1 then
    return 1
  end
  return 0
end

local function bar_win_config()
  return {
    relative = "editor",
    row = tabline_offset(),
    col = 0,
    width = vim.o.columns,
    height = 1,
  }
end

local function reposition_bar_win()
  if M._bar_win and vim.api.nvim_win_is_valid(M._bar_win) then
    vim.api.nvim_win_set_config(M._bar_win, bar_win_config())
  end
end

-- Floating windows belong to the tabpage they were created in, so a bar
-- created in tab 1 wouldn't be visible after switching to tab 2. Recreating
-- (not duplicating) it on every TabEnter keeps exactly one bar visible no
-- matter which tab is active, restoring whatever was last rendered.
local function ensure_bar_win()
  if M._bar_win and vim.api.nvim_win_is_valid(M._bar_win) then
    return M._bar_win
  end

  bar_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[bar_buf].buftype = "nofile"
  vim.bo[bar_buf].bufhidden = "hide"
  vim.api.nvim_buf_set_lines(bar_buf, 0, -1, false, { "" })
  vim.bo[bar_buf].modifiable = false

  local config = bar_win_config()
  config.focusable = false
  config.style = "minimal"
  config.border = "none"
  config.zindex = 50
  M._bar_win = vim.api.nvim_open_win(bar_buf, false, config)

  if not autocmds_registered then
    autocmds_registered = true
    vim.api.nvim_create_autocmd({ "VimResized", "TabEnter" }, {
      callback = function()
        if M._bar_win and vim.api.nvim_win_is_valid(M._bar_win) then
          reposition_bar_win()
        else
          ensure_bar_win()
        end
        if M._bar_win and vim.api.nvim_win_is_valid(M._bar_win) then
          vim.wo[M._bar_win].winbar = M.render(current_buttons)
        end
      end,
    })
  end

  return M._bar_win
end

function M.apply(buttons)
  M.set_buttons(buttons)
  local win = ensure_bar_win()
  vim.wo[win].winbar = M.render(buttons)
end

return M
