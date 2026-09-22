-- tests/statusbar_spec.lua
describe("clickaholic.statusbar", function()
  local statusbar

  before_each(function()
    package.loaded["clickaholic.statusbar"] = nil
    package.loaded["clickaholic.actions"] = nil
    statusbar = require("clickaholic.statusbar")
  end)

  describe("render", function()
    it("builds one clickable segment per button with icon and label", function()
      local rendered = statusbar.render({
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
      assert.are.equal("", statusbar.render({}))
    end)

    it("renders an icon-only button without a stray double space", function()
      local rendered = statusbar.render({
        { label = "", icon = "🚀", action_type = "cmd", action = ":X" },
      })
      assert.is_true(rendered:find("🚀 %%X") ~= nil, "expected a single space before %%X, got: " .. rendered)
    end)

    it("renders a label-only button without a stray leading space", function()
      local rendered = statusbar.render({
        { label = "Deploy", icon = "", action_type = "cmd", action = ":X" },
      })
      assert.is_true(rendered:find("@ Deploy %%X") ~= nil, "expected a single space after @, got: " .. rendered)
    end)
  end)

  describe("click", function()
    it("runs the action for the button at the given id", function()
      local ran
      package.loaded["clickaholic.actions"] = {
        run = function(b)
          ran = b
        end,
      }
      package.loaded["clickaholic.statusbar"] = nil
      statusbar = require("clickaholic.statusbar")

      local buttons = {
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      }
      statusbar.set_buttons(buttons)
      statusbar.click(2)

      assert.are.equal("Test", ran.label)
    end)
  end)

  describe("apply", function()
    local original_laststatus, original_statusline

    before_each(function()
      original_laststatus = vim.o.laststatus
      original_statusline = vim.o.statusline
    end)

    after_each(function()
      vim.o.laststatus = original_laststatus
      vim.o.statusline = original_statusline
    end)

    it("sets laststatus=3 (global statusline) and renders into vim.o.statusline", function()
      local buttons = { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } }
      statusbar.apply(buttons)
      assert.are.equal(3, vim.o.laststatus)
      assert.are.equal(statusbar.render(buttons), vim.o.statusline)
    end)

    it("does not touch vim.o.winbar", function()
      local buttons = { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } }
      local before = vim.o.winbar
      statusbar.apply(buttons)
      assert.are.equal(before, vim.o.winbar)
    end)

    it("stays correctly set across tab creation/switching, with no per-tab management needed", function()
      local start_tab = vim.api.nvim_get_current_tabpage()
      local buttons = { { label = "One", icon = "1", action_type = "cmd", action = ":X" } }
      statusbar.apply(buttons)
      local expected = vim.o.statusline

      vim.cmd("tabnew")
      local new_tab = vim.api.nvim_get_current_tabpage()
      vim.cmd("tabprevious")
      vim.cmd("tabnext")

      assert.are.equal(expected, vim.o.statusline, "statusline must remain correctly set across tab operations")

      vim.api.nvim_set_current_tabpage(new_tab)
      pcall(vim.cmd, "tabclose")
      vim.api.nvim_set_current_tabpage(start_tab)
    end)
  end)
end)
