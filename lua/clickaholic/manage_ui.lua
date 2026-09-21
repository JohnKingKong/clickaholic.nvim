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
state.mode = "list" -- "list" | "add" | "edit"
state.edit_index = nil -- stored-list index, only set in "edit" mode
state.form_start_line = nil

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

function M._set_form_lines(lines)
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, state.form_start_line, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

local function enter_form_mode(mode, existing_button)
  state.mode = mode
  local buttons = require("clickaholic").get_buttons()
  local list_lines = M.render_list_lines(buttons)
  state.form_start_line = #list_lines

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, list_lines)
  vim.bo[state.buf].modifiable = false
  M._set_form_lines(M.render_form_lines(existing_button))

  -- Leave the buffer modifiable and the cursor inside the form so the user
  -- can actually type into it; `_set_form_lines` always leaves the buffer
  -- non-modifiable when it's done writing, which is correct for every other
  -- caller (redraw/list rendering) but wrong here since form mode is the one
  -- state where the user is meant to edit the buffer directly.
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_win_set_cursor(state.win, { state.form_start_line + 1, #"Label: " })
end

function M._start_add()
  state.edit_index = nil
  enter_form_mode("add", nil)
end

function M._start_edit()
  local buttons = require("clickaholic").get_buttons()
  local idx = stored_index_for(state.selected, buttons)
  if not idx then
    vim.notify("clickaholic: only stored buttons can be edited", vim.log.levels.WARN)
    return
  end
  state.edit_index = idx
  enter_form_mode("edit", buttons[state.selected])
end

function M._submit_form()
  local lines = vim.api.nvim_buf_get_lines(state.buf, state.form_start_line, state.form_start_line + 4, false)
  local button, err = M.parse_form(lines)
  if not button then
    vim.notify("clickaholic: " .. err, vim.log.levels.ERROR)
    return
  end

  if state.mode == "edit" then
    store.update(store.default_path(), state.edit_index, button)
  else
    store.add(store.default_path(), button)
  end

  state.mode = "list"
  refresh_and_redraw()
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
  state.mode, state.edit_index, state.form_start_line = "list", nil, nil
  M._last_win = win

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      -- Once a form is open, the buffer also contains form lines below the
      -- list; those aren't selectable list rows, so cursor movement must
      -- not update state.selected while a form is active.
      if state.mode ~= "list" then
        return
      end
      local cursor = vim.api.nvim_win_get_cursor(win)
      local line_count = vim.api.nvim_buf_line_count(buf)
      state.selected = math.max(1, math.min(cursor[1], line_count))
    end,
  })

  local opts = { buffer = buf, nowait = true, silent = true }

  local function require_list_mode()
    if state.mode ~= "list" then
      vim.notify("clickaholic: finish or cancel the form first (<CR> to submit, <Esc> to cancel)", vim.log.levels.WARN)
      return false
    end
    return true
  end

  vim.keymap.set("n", "d", function()
    if not require_list_mode() then
      return
    end
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
    if not require_list_mode() then
      return
    end
    local buttons = require("clickaholic").get_buttons()
    local idx = stored_index_for(state.selected, buttons)
    if not idx then
      vim.notify("clickaholic: only stored buttons can be reordered", vim.log.levels.WARN)
      return
    end
    store.move(store.default_path(), idx, "up")
    refresh_and_redraw()
  end, opts)

  vim.keymap.set("n", "J", function()
    if not require_list_mode() then
      return
    end
    local buttons = require("clickaholic").get_buttons()
    local idx = stored_index_for(state.selected, buttons)
    if not idx then
      vim.notify("clickaholic: only stored buttons can be reordered", vim.log.levels.WARN)
      return
    end
    store.move(store.default_path(), idx, "down")
    refresh_and_redraw()
  end, opts)

  vim.keymap.set("n", "a", function()
    if not require_list_mode() then
      return
    end
    M._start_add()
  end, opts)

  vim.keymap.set("n", "e", function()
    if not require_list_mode() then
      return
    end
    M._start_edit()
  end, opts)

  vim.keymap.set("n", "<CR>", function()
    if state.mode == "list" then
      M._start_edit()
    else
      M._submit_form()
    end
  end, opts)

  for _, lhs in ipairs({ "<Esc>", "q" }) do
    vim.keymap.set("n", lhs, function()
      if state.mode == "list" then
        pcall(vim.api.nvim_win_close, win, true)
        return
      end
      -- A form is open: back out to the list instead of closing the whole
      -- window, so the user doesn't lose their place after a mistaken
      -- add/edit.
      state.mode = "list"
      state.edit_index = nil
      state.form_start_line = nil
      redraw()
    end, opts)
  end

  redraw()
end

return M
