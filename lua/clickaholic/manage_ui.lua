local M = {}

-- Icon and label are both optional (validated in parse_form as "at least
-- one"), so joining them always with a space would leave a stray leading or
-- trailing space when only one is set.
local function icon_and_label(icon, label)
  if icon ~= "" and label ~= "" then
    return icon .. " " .. label
  end
  return icon .. label
end

-- Add/edit form is Label, Icon, Type, Action, Cwd, in that fixed order --
-- every offset below is relative to this.
local FORM_LINE_COUNT = 5

function M.render_list_lines(buttons)
  local lines = {}
  for _, button in ipairs(buttons) do
    local prefix = button.source == "config" and "[config] " or ""
    local scope = (button.cwd and button.cwd ~= "") and (" (scoped: " .. vim.fn.fnamemodify(button.cwd, ":t") .. ")")
      or ""
    table.insert(lines, prefix .. icon_and_label(button.icon, button.label) .. scope)
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
    "Cwd: " .. (button.cwd or ""),
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
  local cwd = field_value(lines[5], "Cwd: ")

  if label == "" and icon == "" then
    return nil, "Provide a label, an icon, or both"
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
    cwd = cwd,
  },
    nil
end

local store = require("clickaholic.store")
local icon_picker = require("clickaholic.icon_picker")

M._last_win = nil
local state = { buf = nil, win = nil, selected = 1 }
state.mode = "list" -- "list" | "add" | "edit"
state.edit_index = nil -- stored-list index, only set in "edit" mode
state.form_start_line = nil -- 0-indexed buffer line where the form's 4 lines start
state.list_count = 0 -- number of list rows currently rendered (cursor-selectable in list mode)
state.help_win = nil -- the separate full-keybind popup opened by '?', nil when closed

-- lazygit-style: a permanent hint lives in the window's own bottom border
-- (see M.open()'s `footer` config), and '?' opens a separate popup with the
-- full legend -- there's no in-buffer footer to keep in sync with the list
-- or form, so this is the only place either piece of text is defined.
local FOOTER_CONDENSED = " a add  e edit  d delete  K/J move  ? all keys  q close "
local HELP_LINES = {
  "a           add button",
  "e / <CR>    edit selected button",
  "d           delete button",
  "K / J       move button up / down",
  "<C-e>       pick icon (in the Icon field)",
  "<C-l>       link the Cwd field to the current directory",
  "<CR>        submit form",
  "<Esc> / q   cancel form / close window",
  "?           toggle this help",
}

local function separator_line()
  local width = vim.api.nvim_win_get_width(state.win)
  return string.rep("─", width)
end

-- Single source of truth for the buffer's line layout: list rows, then
-- always a separator, then (in form mode) the form's 4 lines. Returns the
-- full line array plus the 0-indexed line where the form content starts
-- (nil when not in form mode). Every caller that (re)draws the buffer goes
-- through this, so there is exactly one place that computes these offsets.
local function build_lines(list_lines, form_content_lines)
  local lines = {}
  for _, line in ipairs(list_lines) do
    table.insert(lines, line)
  end
  table.insert(lines, separator_line())

  local form_start_line = nil
  if form_content_lines then
    form_start_line = #lines
    for _, line in ipairs(form_content_lines) do
      table.insert(lines, line)
    end
  end

  return lines, form_start_line
end

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
  local list_lines = M.render_list_lines(buttons)
  state.list_count = #list_lines
  state.form_start_line = nil
  local lines = build_lines(list_lines, nil)
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

local function refresh_and_redraw()
  require("clickaholic").refresh()
  require("clickaholic").apply_renderer()
  redraw()
end

-- Overwrites just the form's FORM_LINE_COUNT lines (never the
-- list/separator/footer around them, which is why this uses an exact
-- range rather than writing to the end of the buffer).
function M._set_form_lines(lines)
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, state.form_start_line, state.form_start_line + FORM_LINE_COUNT, false, lines)
  vim.bo[state.buf].modifiable = true
end

local function enter_form_mode(mode, existing_button)
  state.mode = mode
  local buttons = require("clickaholic").get_buttons()
  local list_lines = M.render_list_lines(buttons)
  state.list_count = #list_lines

  local lines, form_start_line = build_lines(list_lines, M.render_form_lines(existing_button))
  state.form_start_line = form_start_line

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  -- Leave the buffer modifiable (form mode is the one state where the user
  -- is meant to edit the buffer directly) and place the cursor right after
  -- the "Label: " prefix on the first form line, ready to type.
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
  local lines =
    vim.api.nvim_buf_get_lines(state.buf, state.form_start_line, state.form_start_line + FORM_LINE_COUNT, false)
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
    footer = FOOTER_CONDENSED,
    footer_pos = "left",
  })

  state.buf, state.win, state.selected = buf, win, 1
  state.mode, state.edit_index, state.form_start_line = "list", nil, nil
  state.list_count = 0
  if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then
    vim.api.nvim_win_close(state.help_win, true)
  end
  state.help_win = nil
  M._last_help_win = nil
  M._last_win = win

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then
        vim.api.nvim_win_close(state.help_win, true)
        state.help_win = nil
        M._last_help_win = nil
      end
    end,
  })

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
      state.selected = math.max(1, math.min(cursor[1], state.list_count))
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

  vim.keymap.set({ "n", "i" }, "<C-e>", function()
    if state.mode == "list" then
      vim.notify("clickaholic: open the add/edit form first ('a' or 'e')", vim.log.levels.WARN)
      return
    end
    -- Form lines are Label/Icon/Type/Action/Cwd in that order, so the Icon
    -- field is always one line after where the form starts.
    local icon_line = state.form_start_line + 1
    icon_picker.open(function(icon)
      local new_line = "Icon: " .. icon
      vim.bo[state.buf].modifiable = true
      vim.api.nvim_buf_set_lines(state.buf, icon_line, icon_line + 1, false, { new_line })
      vim.api.nvim_set_current_win(state.win)
      vim.api.nvim_win_set_cursor(state.win, { icon_line + 1, #new_line })
    end)
  end, opts)

  vim.keymap.set({ "n", "i" }, "<C-l>", function()
    if state.mode == "list" then
      vim.notify("clickaholic: open the add/edit form first ('a' or 'e')", vim.log.levels.WARN)
      return
    end
    -- Cwd is the 5th form field (Label/Icon/Type/Action/Cwd), so it's
    -- always four lines after where the form starts.
    local cwd_line = state.form_start_line + 4
    local new_line = "Cwd: " .. vim.fn.getcwd()
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, cwd_line, cwd_line + 1, false, { new_line })
    vim.api.nvim_win_set_cursor(state.win, { cwd_line + 1, #new_line })
  end, opts)

  vim.keymap.set("n", "?", function()
    if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then
      vim.api.nvim_win_close(state.help_win, true)
      state.help_win = nil
      M._last_help_win = nil
      return
    end

    local help_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[help_buf].buftype = "nofile"
    vim.bo[help_buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, HELP_LINES)
    vim.bo[help_buf].modifiable = false

    local help_width = 0
    for _, line in ipairs(HELP_LINES) do
      help_width = math.max(help_width, #line)
    end
    help_width = help_width + 2

    state.help_win = vim.api.nvim_open_win(help_buf, false, {
      relative = "win",
      win = win,
      row = 1,
      col = math.floor((vim.api.nvim_win_get_width(win) - help_width) / 2),
      width = help_width,
      height = #HELP_LINES,
      border = "rounded",
      title = " keybindings ",
      focusable = false,
      zindex = 60,
    })
    M._last_help_win = state.help_win
  end, opts)

  for _, lhs in ipairs({ "<Esc>", "q" }) do
    vim.keymap.set("n", lhs, function()
      if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then
        vim.api.nvim_win_close(state.help_win, true)
        state.help_win = nil
        M._last_help_win = nil
        return
      end
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
