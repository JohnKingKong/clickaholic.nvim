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

  local function feed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
  end

  before_each(function()
    package.loaded["clickaholic.manage_ui"] = nil
    package.loaded["clickaholic.store"] = nil
    package.loaded["clickaholic.winbar"] = nil
    package.loaded["clickaholic.icon_picker"] = nil
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
    -- Stubbed like every other describe block here: winbar.apply() now
    -- manages a real persistent floating window as a side effect, which
    -- these tests (about the add/edit form, not about winbar rendering)
    -- have no reason to exercise.
    package.loaded["clickaholic.winbar"] = {
      apply = function() end,
    }

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

  it("submits correctly when the store already has an entry (regression: form_start_line off-by-one)", function()
    -- Pre-populate the store so the list occupies >0 lines before the form
    -- is appended below it. This is the realistic case (adding a 2nd
    -- button, or editing any button once one already exists) that the
    -- off-by-one in `enter_form_mode`'s `state.form_start_line` broke:
    -- nvim_buf_set_lines silently clamps out-of-range writes on a 1-line
    -- buffer, masking the bug for the initial form-lines write, but the
    -- subsequent read in `_submit_form` has no such rescue and reads one
    -- line too late, dropping "Label: ..." and crashing on a nil field.
    store.add(path, { label = "Existing", icon = "📌", action_type = "cmd", action = ":X" })

    manage_ui.open()
    manage_ui._start_add()

    -- Edit the form lines in place, the way a real user typing into the
    -- buffer would -- NOT via a second `_set_form_lines` call, which would
    -- exercise the same (masked) write path as `enter_form_mode` itself
    -- rather than proving the read path in `_submit_form` is correct.
    local buf = vim.api.nvim_win_get_buf(manage_ui._last_win)
    local function set_field(prefix, new_line)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      for i, line in ipairs(lines) do
        if line:sub(1, #prefix) == prefix then
          vim.bo[buf].modifiable = true
          vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { new_line })
          vim.bo[buf].modifiable = false
          return
        end
      end
      error("field not found for prefix: " .. prefix)
    end
    set_field("Label: ", "Label: Second")
    set_field("Icon: ", "Icon: 🧪")
    set_field("Type: ", "Type: shell")
    set_field("Action: ", "Action: npm run second")

    manage_ui._submit_form()

    local stored = store.load(path)
    assert.are.equal(2, #stored)
    assert.are.equal("Existing", stored[1].label)
    assert.are.equal("Second", stored[2].label)
  end)

  it("end-to-end: pressing 'a' opens a real editable form, typing and <CR> persists the button", function()
    -- Drives the actual registered keymap callbacks (not the internal
    -- _set_form_lines/_submit_form helpers) to prove the interactive path a
    -- real user takes -- press 'a', type into the buffer, press <CR> --
    -- actually works. This is the path the Critical finding showed was
    -- broken: the buffer was left non-modifiable and the cursor was never
    -- moved into the form.
    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)

    feed("a")
    vim.wait(50)

    local buf = vim.api.nvim_win_get_buf(win)
    assert.is_true(vim.bo[buf].modifiable, "buffer must be modifiable once the form is open")
    local cursor = vim.api.nvim_win_get_cursor(win)
    -- The store is empty here, so the buffer is: 1 separator line (row 1),
    -- then the 4 form lines starting at row 2. The form line is exactly
    -- "Label: " (7 chars, no value yet) in add mode, so nvim clamps the
    -- requested column (7, one past the last char) to the last valid column
    -- (6) in Normal mode -- landing the cursor right on/after the "Label: "
    -- prefix, ready to type.
    assert.are.equal(2, cursor[1], "cursor must land on the first form line")
    assert.are.equal(#"Label: " - 1, cursor[2], "cursor must land right after the 'Label: ' prefix")

    -- Simulate the user typing into each field via real buffer line
    -- replacement (headless feedkeys()-driven insert mode is unreliable in
    -- tests, but this exercises the same buffer-state path real typing
    -- leaves behind, and only works at all because the buffer is
    -- modifiable -- which is exactly what's under test). The form starts at
    -- the 0-indexed line the cursor just landed on (cursor[1] - 1), right
    -- after the separator -- not hardcoded to 0, since a separator line now
    -- precedes the form.
    local form_start = cursor[1] - 1
    vim.api.nvim_buf_set_lines(buf, form_start, form_start + 1, false, { "Label: Typed" })
    vim.api.nvim_buf_set_lines(buf, form_start + 1, form_start + 2, false, { "Icon: 🐙" })
    vim.api.nvim_buf_set_lines(buf, form_start + 2, form_start + 3, false, { "Type: shell" })
    vim.api.nvim_buf_set_lines(buf, form_start + 3, form_start + 4, false, { "Action: echo typed" })

    feed("<CR>")
    vim.wait(50)

    local stored = store.load(path)
    assert.are.equal(1, #stored)
    assert.are.equal("Typed", stored[1].label)
    assert.are.equal("🐙", stored[1].icon)
    assert.are.equal("shell", stored[1].action_type)
    assert.are.equal("echo typed", stored[1].action)
  end)

  it("<Esc> while a form is open cancels the form without closing the window", function()
    store.add(path, { label = "Existing", icon = "📌", action_type = "cmd", action = ":X" })

    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)

    feed("a")
    vim.wait(50)
    local buf = vim.api.nvim_win_get_buf(win)
    -- 1 list line + 1 separator + 4 form lines + 1 blank spacer + 1 condensed footer line.
    assert.are.equal(8, vim.api.nvim_buf_line_count(buf))

    feed("<Esc>")
    vim.wait(50)

    assert.is_true(vim.api.nvim_win_is_valid(win), "<Esc> must cancel the form, not close the window")
    -- 1 list line + 1 blank spacer + 1 condensed footer line, form/separator gone.
    assert.are.equal(3, vim.api.nvim_buf_line_count(buf), "form lines must be gone, list-only view restored")
    assert.is_false(vim.bo[buf].modifiable, "buffer must go back to read-only in list mode")
    assert.are.equal(1, #store.load(path), "cancelling must not persist anything")
  end)

  it("'d' while a form is open does not trigger a delete", function()
    store.add(path, { label = "Existing", icon = "📌", action_type = "cmd", action = ":X" })

    -- Safety net: if the mode gate regresses, a fired 'd' would call
    -- vim.fn.confirm() and hang headless nvim waiting on a prompt. Stub it
    -- to auto-decline so a regression fails the assertions below instead of
    -- hanging the test run.
    local orig_confirm = vim.fn.confirm
    vim.fn.confirm = function()
      return 2
    end

    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)

    feed("a")
    vim.wait(50)

    feed("d")
    vim.wait(50)

    vim.fn.confirm = orig_confirm

    local stored = store.load(path)
    assert.are.equal(1, #stored)
    assert.are.equal("Existing", stored[1].label)
  end)

  it("a separator line sits between the list and the form", function()
    store.add(path, { label = "Existing", icon = "📌", action_type = "cmd", action = ":X" })

    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)

    feed("a")
    vim.wait(50)

    local buf = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Row 1: the list ("Existing"); row 2: the separator; rows 3-6: the form.
    -- "─" is multi-byte UTF-8, so Lua patterns can't quantify it directly
    -- (`─+` only repeats its last raw byte) -- stripping every occurrence
    -- and checking the line is now empty confirms it's made of nothing else.
    assert.is_true(lines[1]:find("Existing") ~= nil)
    assert.are.equal("", (lines[2]:gsub("─", "")), "row 2 must be a separator line, got: " .. lines[2])
    assert.are.equal("Label: ", lines[3])
  end)

  it("<C-e> in the form opens the icon picker and writes the chosen icon into the Icon field", function()
    package.loaded["clickaholic.icon_picker"] = {
      open = function(on_select)
        on_select("🚀")
      end,
    }
    package.loaded["clickaholic.manage_ui"] = nil
    manage_ui = require("clickaholic.manage_ui")

    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)

    feed("a")
    vim.wait(50)
    feed("<C-e>")
    vim.wait(50)

    local buf = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local found_icon_line = false
    for _, line in ipairs(lines) do
      if line == "Icon: 🚀" then
        found_icon_line = true
      end
    end
    assert.is_true(found_icon_line, "Icon field must be updated to the picked icon")

    -- Fill in the rest and submit, to prove the picked icon actually
    -- persists (not just visible in the buffer).
    feed("<CR>")
    vim.wait(50)
    -- Label/Action are still empty, so submission should fail validation
    -- rather than silently succeed -- confirming the icon write didn't
    -- accidentally shift or corrupt the other form fields.
    assert.are.equal(0, #store.load(path))
  end)

  it("<C-e> in list mode warns instead of opening the icon picker", function()
    local opened = false
    package.loaded["clickaholic.icon_picker"] = {
      open = function()
        opened = true
      end,
    }
    package.loaded["clickaholic.manage_ui"] = nil
    manage_ui = require("clickaholic.manage_ui")

    local notified
    local original_notify = vim.notify
    vim.notify = function(msg, level)
      notified = { msg = msg, level = level }
    end

    manage_ui.open()
    vim.api.nvim_set_current_win(manage_ui._last_win)
    feed("<C-e>")
    vim.wait(50)

    vim.notify = original_notify

    assert.is_false(opened, "icon picker must not open outside the form")
    assert.is_not_nil(notified)
    assert.are.equal(vim.log.levels.WARN, notified.level)
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

  it("shows a condensed keybind footer at the bottom, lazygit-style", function()
    manage_ui.open()
    local buf = vim.api.nvim_win_get_buf(manage_ui._last_win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local footer = lines[#lines]
    assert.is_true(footer:find("q") ~= nil and footer:find("close") ~= nil, "footer must mention 'q close'")
    assert.is_true(footer:find("%?") ~= nil, "footer must mention the '?' help key")
  end)

  local function feed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
  end

  it("'?' toggles the footer to an expanded multi-line legend and back", function()
    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)
    local buf = vim.api.nvim_win_get_buf(win)

    local condensed_count = vim.api.nvim_buf_line_count(buf)

    feed("?")
    vim.wait(50)
    local expanded_count = vim.api.nvim_buf_line_count(buf)
    assert.is_true(expanded_count > condensed_count, "expanded legend must add more lines")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local joined = table.concat(lines, "\n")
    assert.is_true(joined:find("add button") ~= nil, "expanded legend must describe each key")

    feed("?")
    vim.wait(50)
    assert.are.equal(condensed_count, vim.api.nvim_buf_line_count(buf), "second '?' must collapse back")
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
    -- The list (3 rows) is still on top, followed by a separator (row 4),
    -- then the form (rows 5-8: Label/Icon/Type/Action). Move the cursor onto
    -- a form line (row 6, "Icon: ...") and fire CursorMoved the same way a
    -- user's cursor movement would.
    move_cursor_to(win, 6)

    -- While the form is open, list-only keymaps like "d" are mode-gated and
    -- must not fire at all (see the dedicated gating tests). Cancel back to
    -- list mode first, then confirm "d" still targets row 3 ("Second"): if
    -- the cursor-driven selection had been clamped to the whole buffer
    -- (pre-form-mode behavior) instead of ignoring form-line movement,
    -- state.selected would have become 5, which doesn't map to any stored
    -- button and "d" would just warn instead of removing idx 2.
    feed("<Esc>")
    vim.wait(50)
    feed("d")
    vim.wait(50)
    assert.are.same({ { op = "remove", idx = 2 } }, store_calls)
  end)

  it("mode-gates 'd', 'a', 'e', 'K', 'J' while a form is open: they warn instead of acting", function()
    manage_ui.open()
    local win = manage_ui._last_win
    vim.api.nvim_set_current_win(win)
    move_cursor_to(win, 3)

    manage_ui._start_add()

    for _, key in ipairs({ "d", "a", "e", "K", "J" }) do
      notifications = {}
      feed(key)
      vim.wait(50)
      assert.are.same({}, store_calls, key .. " must not touch the store while a form is open")
      assert.are.equal(1, #notifications, key .. " must warn while a form is open")
      assert.is_true(notifications[1].msg:find("form") ~= nil)
      assert.are.equal(vim.log.levels.WARN, notifications[1].level)
    end
  end)
end)
