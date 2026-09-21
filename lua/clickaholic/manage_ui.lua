local M = {}

function M.render_list_lines(buttons)
  local lines = {}
  for _, button in ipairs(buttons) do
    local prefix = button.source == "config" and "[config] " or ""
    table.insert(lines, string.format("%s%s %s", prefix, button.icon, button.label))
  end
  return lines
end

function M.render_form_lines(button)
  button = button or {}
  return {
    "Label: " .. (button.label or ""),
    "Icon: " .. (button.icon or ""),
    "Type: " .. (button.action_type or "cmd"),
    "Action: " .. (button.action or ""),
  }
end

local function field_value(line, prefix)
  return line:sub(#prefix + 1)
end

function M.parse_form(lines)
  local label = field_value(lines[1], "Label: ")
  local icon = field_value(lines[2], "Icon: ")
  local action_type = field_value(lines[3], "Type: ")
  local action = field_value(lines[4], "Action: ")

  if label == "" then
    return nil, "Label cannot be empty"
  end
  if action_type ~= "cmd" and action_type ~= "shell" then
    return nil, "Type must be 'cmd' or 'shell'"
  end
  if action == "" then
    return nil, "Action cannot be empty"
  end

  return {
    label = label,
    icon = icon,
    action_type = action_type,
    action = action,
  }, nil
end

local store = require("clickaholic.store")
local winbar = require("clickaholic.winbar")

M._last_win = nil
local state = { buf = nil, win = nil, selected = 1 }

local function stored_index_for(selected, buttons)
  -- Maps a selected line (over the full merged list) to its index within
  -- just the stored buttons, since store CRUD operates on that array only.
  local stored_seen = 0
  for i, button in ipairs(buttons) do
    if button.source == "stored" then
      stored_seen = stored_seen + 1
    end
    if i == selected then
      if button.source == "stored" then
        return stored_seen
      end
      return nil
    end
  end
  return nil
end

local function redraw()
  local buttons = require("clickaholic").get_buttons()
  local lines = M.render_list_lines(buttons)
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

local function refresh_and_redraw()
  require("clickaholic").refresh()
  winbar.apply(require("clickaholic").get_buttons())
  redraw()
end

function M.open()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false

  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.5)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    border = "rounded",
    title = " clickaholic ",
  })

  state.buf, state.win, state.selected = buf, win, 1
  M._last_win = win

  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "d", function()
    local buttons = require("clickaholic").get_buttons()
    local idx = stored_index_for(state.selected, buttons)
    if not idx then
      vim.notify("clickaholic: only stored buttons can be deleted", vim.log.levels.WARN)
      return
    end
    if vim.fn.confirm("Delete this button?", "&Yes\n&No", 2) ~= 1 then
      return
    end
    store.remove(store.default_path(), idx)
    refresh_and_redraw()
  end, opts)

  vim.keymap.set("n", "K", function()
    local buttons = require("clickaholic").get_buttons()
    local idx = stored_index_for(state.selected, buttons)
    if not idx then
      return
    end
    store.move(store.default_path(), idx, "up")
    refresh_and_redraw()
  end, opts)

  vim.keymap.set("n", "J", function()
    local buttons = require("clickaholic").get_buttons()
    local idx = stored_index_for(state.selected, buttons)
    if not idx then
      return
    end
    store.move(store.default_path(), idx, "down")
    refresh_and_redraw()
  end, opts)

  for _, lhs in ipairs({ "<Esc>", "q" }) do
    vim.keymap.set("n", lhs, function()
      pcall(vim.api.nvim_win_close, win, true)
    end, opts)
  end

  redraw()
end

return M
