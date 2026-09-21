-- tests/icon_picker_spec.lua
describe("clickaholic.icon_picker", function()
  local icon_picker

  local function feed(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
  end

  before_each(function()
    package.loaded["clickaholic.icon_picker"] = nil
    icon_picker = require("clickaholic.icon_picker")
  end)

  describe("render_lines", function()
    it("renders one 'icon  name' line per curated icon", function()
      local lines = icon_picker.render_lines()
      assert.are.equal(#icon_picker.ICONS, #lines)
      assert.are.equal(icon_picker.ICONS[1].icon .. "  " .. icon_picker.ICONS[1].name, lines[1])
    end)

    it("includes recognizable common icons", function()
      local lines = icon_picker.render_lines()
      local joined = table.concat(lines, "\n")
      assert.is_true(joined:find("rocket") ~= nil)
      assert.is_true(joined:find("folder") ~= nil)
    end)
  end)

  describe("parse_line", function()
    it("extracts the icon glyph from a rendered line", function()
      assert.are.equal("🚀", icon_picker.parse_line("🚀  rocket"))
    end)
  end)

  describe("open", function()
    it("opens a floating window listing the icons", function()
      local win = icon_picker.open(function() end)
      assert.is_true(vim.api.nvim_win_is_valid(win))
      local buf = vim.api.nvim_win_get_buf(win)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.are.equal(#icon_picker.ICONS, #lines)
      pcall(vim.api.nvim_win_close, win, true)
    end)

    it("pressing <CR> on a line calls on_select with that icon and closes the window", function()
      local selected
      local win = icon_picker.open(function(icon)
        selected = icon
      end)
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { 2, 0 })

      feed("<CR>")
      vim.wait(50)

      assert.are.equal(icon_picker.ICONS[2].icon, selected)
      assert.is_false(vim.api.nvim_win_is_valid(win))
    end)

    it("pressing <Esc> closes the window without calling on_select", function()
      local called = false
      local win = icon_picker.open(function()
        called = true
      end)
      vim.api.nvim_set_current_win(win)

      feed("<Esc>")
      vim.wait(50)

      assert.is_false(called)
      assert.is_false(vim.api.nvim_win_is_valid(win))
    end)
  end)
end)
