-- tests/winbar_spec.lua
describe("clickaholic.winbar", function()
  local winbar

  before_each(function()
    package.loaded["clickaholic.winbar"] = nil
    package.loaded["clickaholic.actions"] = nil
    winbar = require("clickaholic.winbar")
  end)

  describe("render", function()
    it("builds one clickable segment per button with icon and label", function()
      local rendered = winbar.render({
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      })
      assert.is_true(rendered:find("🔭") ~= nil)
      assert.is_true(rendered:find("Search") ~= nil)
      assert.is_true(rendered:find("🧪") ~= nil)
      assert.is_true(rendered:find("Test") ~= nil)
      assert.is_true(rendered:find("%%1@") ~= nil)
      assert.is_true(rendered:find("%%2@") ~= nil)
    end)

    it("returns an empty string for no buttons", function()
      assert.are.equal("", winbar.render({}))
    end)
  end)

  describe("click", function()
    it("runs the action for the button at the given id", function()
      local ran
      package.loaded["clickaholic.actions"] = { run = function(b)
        ran = b
      end }
      package.loaded["clickaholic.winbar"] = nil
      winbar = require("clickaholic.winbar")

      local buttons = {
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      }
      winbar.set_buttons(buttons)
      winbar.click(2)

      assert.are.equal("Test", ran.label)
    end)
  end)

  describe("apply", function()
    after_each(function()
      if winbar._bar_win and vim.api.nvim_win_is_valid(winbar._bar_win) then
        vim.api.nvim_win_close(winbar._bar_win, true)
      end
    end)

    it("renders into a dedicated floating window's winbar, not vim.o.winbar", function()
      local buttons = { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } }
      winbar.apply(buttons)
      assert.is_true(vim.api.nvim_win_is_valid(winbar._bar_win))
      assert.are.equal(winbar.render(buttons), vim.wo[winbar._bar_win].winbar)
      assert.are_not.equal(winbar.render(buttons), vim.o.winbar)
    end)

    it("reuses the same floating window across repeated calls (no duplication)", function()
      winbar.apply({ { label = "One", icon = "1", action_type = "cmd", action = ":X" } })
      local first_win = winbar._bar_win
      winbar.apply({ { label = "Two", icon = "2", action_type = "cmd", action = ":Y" } })
      assert.are.equal(first_win, winbar._bar_win)
    end)

    it("spans the full editor width at the top", function()
      local buttons = { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } }
      winbar.apply(buttons)
      local config = vim.api.nvim_win_get_config(winbar._bar_win)
      assert.are.equal(vim.o.columns, config.width)
      assert.are.equal(0, config.col)
    end)
  end)
end)
