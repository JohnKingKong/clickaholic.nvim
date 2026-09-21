-- tests/manage_ui_spec.lua
describe("clickaholic.manage_ui", function()
  local manage_ui

  before_each(function()
    package.loaded["clickaholic.manage_ui"] = nil
    manage_ui = require("clickaholic.manage_ui")
  end)

  describe("render_list_lines", function()
    it("tags config buttons and lists stored ones plainly", function()
      local lines = manage_ui.render_list_lines({
        { label = "Search", icon = "🔭", source = "config" },
        { label = "Test", icon = "🧪", source = "stored" },
      })
      assert.are.equal(2, #lines)
      assert.is_true(lines[1]:find("%[config%]") ~= nil)
      assert.is_true(lines[1]:find("Search") ~= nil)
      assert.is_nil(lines[2]:find("%[config%]"))
      assert.is_true(lines[2]:find("Test") ~= nil)
    end)
  end)

  describe("render_form_lines", function()
    it("returns empty fields for add mode (nil button)", function()
      local lines = manage_ui.render_form_lines(nil)
      assert.are.same({
        "Label: ",
        "Icon: ",
        "Type: cmd",
        "Action: ",
      }, lines)
    end)

    it("pre-fills fields for edit mode", function()
      local lines = manage_ui.render_form_lines({
        label = "Test",
        icon = "🧪",
        action_type = "shell",
        action = "npm test",
      })
      assert.are.same({
        "Label: Test",
        "Icon: 🧪",
        "Type: shell",
        "Action: npm test",
      }, lines)
    end)
  end)

  describe("parse_form", function()
    it("parses valid form lines into a button", function()
      local button, err = manage_ui.parse_form({
        "Label: Test",
        "Icon: 🧪",
        "Type: shell",
        "Action: npm test",
      })
      assert.is_nil(err)
      assert.are.same({
        label = "Test",
        icon = "🧪",
        action_type = "shell",
        action = "npm test",
      }, button)
    end)

    it("rejects an empty label", function()
      local button, err = manage_ui.parse_form({
        "Label: ",
        "Icon: 🧪",
        "Type: shell",
        "Action: npm test",
      })
      assert.is_nil(button)
      assert.is_true(err:find("[Ll]abel") ~= nil)
    end)

    it("rejects an empty action", function()
      local button, err = manage_ui.parse_form({
        "Label: Test",
        "Icon: 🧪",
        "Type: shell",
        "Action: ",
      })
      assert.is_nil(button)
      assert.is_true(err:find("[Aa]ction") ~= nil)
    end)

    it("rejects an invalid action type", function()
      local button, err = manage_ui.parse_form({
        "Label: Test",
        "Icon: 🧪",
        "Type: lua",
        "Action: npm test",
      })
      assert.is_nil(button)
      assert.is_true(err:find("[Tt]ype") ~= nil)
    end)
  end)
end)

describe("clickaholic.manage_ui add/edit", function()
  local manage_ui
  local store
  local path

  before_each(function()
    package.loaded["clickaholic.manage_ui"] = nil
    package.loaded["clickaholic.store"] = nil
    package.loaded["clickaholic.winbar"] = nil
    package.loaded["clickaholic"] = nil

    path = vim.fn.tempname() .. ".json"
    store = require("clickaholic.store")

    package.loaded["clickaholic"] = {
      get_buttons = function()
        return store.load(path)
      end,
      refresh = function() end,
    }
    package.loaded["clickaholic.store"].default_path = function()
      return path
    end

    manage_ui = require("clickaholic.manage_ui")
  end)

  after_each(function()
    vim.fn.delete(path)
    pcall(vim.api.nvim_win_close, manage_ui._last_win, true)
  end)

  it("adding a button via the form persists it to the store", function()
    manage_ui.open()
    manage_ui._start_add()
    manage_ui._set_form_lines({
      "Label: Test",
      "Icon: 🧪",
      "Type: shell",
      "Action: npm test",
    })
    manage_ui._submit_form()

    local stored = store.load(path)
    assert.are.equal(1, #stored)
    assert.are.equal("Test", stored[1].label)
  end)

  it("shows an error and keeps the form open on invalid input", function()
    local notified
    local original_notify = vim.notify
    vim.notify = function(msg, level)
      notified = { msg = msg, level = level }
    end

    manage_ui.open()
    manage_ui._start_add()
    manage_ui._set_form_lines({
      "Label: ",
      "Icon: 🧪",
      "Type: shell",
      "Action: npm test",
    })
    manage_ui._submit_form()

    vim.notify = original_notify

    assert.is_not_nil(notified)
    assert.are.equal(vim.log.levels.ERROR, notified.level)
    assert.are.equal(0, #store.load(path))
  end)
end)

describe("clickaholic.manage_ui.open", function()
  local manage_ui
  local path

  before_each(function()
    package.loaded["clickaholic.manage_ui"] = nil
    package.loaded["clickaholic.store"] = nil
    package.loaded["clickaholic.winbar"] = nil
    package.loaded["clickaholic"] = nil

    path = vim.fn.tempname() .. ".json"
    package.loaded["clickaholic"] = {
      get_buttons = function()
        return { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope", source = "config" } }
      end,
    }

    manage_ui = require("clickaholic.manage_ui")
  end)

  after_each(function()
    vim.fn.delete(path)
    pcall(vim.api.nvim_win_close, manage_ui._last_win, true)
  end)

  it("opens a floating window showing the button list", function()
    manage_ui.open()
    assert.is_true(vim.api.nvim_win_is_valid(manage_ui._last_win))
    local buf = vim.api.nvim_win_get_buf(manage_ui._last_win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local found = false
    for _, line in ipairs(lines) do
      if line:find("Search") then
        found = true
      end
    end
    assert.is_true(found)
  end)
end)

describe("clickaholic.manage_ui.open keymaps", function()
  local manage_ui
  local store_calls
  local notifications
  local orig_notify
  local orig_confirm

  local function feed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
  end

  -- Headless Nvim doesn't run a real redraw/idle loop, so CursorMoved isn't
  -- reliably auto-fired by nvim_win_set_cursor()/feedkeys() the way it would
  -- be during interactive use. Move the cursor via the real API (exercising
  -- the same path a user's cursor movement would take) and then fire the
  -- autocmd explicitly, so the test still exercises manage_ui's own
  -- CursorMoved callback rather than bypassing it.
  local function move_cursor_to(win, row)
    vim.api.nvim_win_set_cursor(win, { row, 0 })
    vim.cmd("doautocmd CursorMoved")
  end

  before_each(function()
    package.loaded["clickaholic.manage_ui"] = nil
    package.loaded["clickaholic.store"] = nil
    package.loaded["clickaholic.winbar"] = nil
    package.loaded["clickaholic"] = nil

    store_calls = {}
    package.loaded["clickaholic.store"] = {
      default_path = function()
        return "fake/path.json"
      end,
      remove = function(_, idx)
        table.insert(store_calls, { op = "remove", idx = idx })
      end,
      move = function(_, idx, direction)
        table.insert(store_calls, { op = "move", idx = idx, direction = direction })
      end,
    }
    package.loaded["clickaholic.winbar"] = {
      apply = function() end,
    }
    -- Merged list: row 1 is config-sourced, rows 2-3 are the 1st/2nd stored
    -- buttons respectively, so we can prove the keymaps act on whatever row
    -- the cursor is on (not just the first row).
    package.loaded["clickaholic"] = {
      get_buttons = function()
        return {
          { label = "Config", icon = "⚙", action_type = "cmd", action = ":X", source = "config" },
          { label = "First", icon = "1", action_type = "cmd", action = ":A", source = "stored" },
          { label = "Second", icon = "2", action_type = "cmd", action = ":B", source = "stored" },
        }
      end,
      refresh = function() end,
    }

    notifications = {}
    orig_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end
    orig_confirm = vim.fn.confirm
    vim.fn.confirm = function()
      return 1
    end

    manage_ui = require("clickaholic.manage_ui")
  end)

  after_each(function()
    pcall(vim.api.nvim_win_close, manage_ui._last_win, true)
    vim.notify = orig_notify
    vim.fn.confirm = orig_confirm
  end)

  it("tracks the cursor: deletes the stored button under the cursor, not row 1", function()
    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)
    move_cursor_to(win, 3) -- row 3: "Second", the 2nd stored button
    feed("d")
    vim.wait(50)
    assert.are.same({ { op = "remove", idx = 2 } }, store_calls)
  end)

  it("tracks the cursor: reorders the stored button under the cursor, not row 1", function()
    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)
    move_cursor_to(win, 3) -- row 3: "Second", the 2nd stored button
    feed("K")
    vim.wait(50)
    assert.are.same({ { op = "move", idx = 2, direction = "up" } }, store_calls)
  end)

  it("warns instead of reordering when the cursor is on a config-sourced row", function()
    manage_ui.open()
    vim.api.nvim_set_current_win(manage_ui._last_win)
    -- cursor starts on row 1, the config-sourced button
    feed("K")
    feed("J")
    vim.wait(50)
    assert.are.same({}, store_calls)
    assert.are.equal(2, #notifications)
    for _, note in ipairs(notifications) do
      assert.is_true(note.msg:find("reordered") ~= nil)
      assert.are.equal(vim.log.levels.WARN, note.level)
    end
  end)

  it("ignores cursor movement onto form lines while in form mode, keeping the last list selection", function()
    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)
    -- Select row 3 ("Second", the 2nd stored button) before entering form mode.
    move_cursor_to(win, 3)

    manage_ui._start_add()
    -- The list (3 rows) is still on top; form lines now occupy rows 4-7.
    -- Move the cursor onto a form line (row 5, "Icon: ...") and fire
    -- CursorMoved the same way a user's cursor movement would.
    move_cursor_to(win, 5)

    -- If the cursor-driven selection were still being clamped to the whole
    -- buffer (pre-form-mode behavior), state.selected would become 5, which
    -- doesn't map to any stored button and "d" would just warn. Instead it
    -- must keep pointing at row 3 ("Second"), proving form lines aren't
    -- treated as selectable list rows.
    feed("d")
    vim.wait(50)
    assert.are.same({ { op = "remove", idx = 2 } }, store_calls)
  end)
end)
