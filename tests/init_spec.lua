-- tests/init_spec.lua
describe("clickaholic.init", function()
  local clickaholic
  local store
  local path

  before_each(function()
    package.loaded["clickaholic"] = nil
    package.loaded["clickaholic.store"] = nil
    package.loaded["clickaholic.winbar"] = nil
    package.loaded["clickaholic.tabline"] = nil
    package.loaded["clickaholic.lualine"] = nil
    store = require("clickaholic.store")
    -- Use a temp file, not the real stdpath('data') path -- these tests
    -- assume the store starts empty, which is never a safe assumption
    -- against a real user's actual saved buttons.
    path = vim.fn.tempname() .. ".json"
    package.loaded["clickaholic.store"].default_path = function()
      return path
    end
    clickaholic = require("clickaholic")
  end)

  after_each(function()
    vim.fn.delete(path)
  end)

  it("uses only config buttons when the store is empty", function()
    clickaholic.setup({
      buttons = {
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
      },
    })
    local buttons = clickaholic.get_buttons()
    assert.are.equal(1, #buttons)
    assert.are.equal("config", buttons[1].source)
  end)

  it("merges config buttons with stored ones, config first", function()
    store.add(path, { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" })
    clickaholic.setup({
      buttons = {
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
      },
    })
    local buttons = clickaholic.get_buttons()
    assert.are.equal(2, #buttons)
    assert.are.equal("config", buttons[1].source)
    assert.are.equal("stored", buttons[2].source)
  end)

  it("rejects a config button with action_type lua and a non-function action", function()
    local notified
    local original_notify = vim.notify
    vim.notify = function(msg, level)
      notified = { msg = msg, level = level }
    end
    clickaholic.setup({
      buttons = {
        { label = "Bad", icon = "x", action_type = "lua", action = "not a function" },
      },
    })
    vim.notify = original_notify
    assert.is_not_nil(notified)
    assert.are.equal(vim.log.levels.ERROR, notified.level)
    assert.are.equal(0, #clickaholic.get_buttons())
  end)

  it("refresh() picks up store changes made after setup", function()
    clickaholic.setup({ buttons = {} })
    assert.are.equal(0, #clickaholic.get_buttons())
    store.add(path, { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" })
    clickaholic.refresh()
    assert.are.equal(1, #clickaholic.get_buttons())
  end)

  describe("renderer selection", function()
    it("defaults to winbar when opts.renderer is unset", function()
      clickaholic.setup({
        buttons = { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } },
      })
      assert.is_true(vim.o.winbar:find("Search") ~= nil)
    end)

    it("applies the tabline renderer when opts.renderer = 'tabline'", function()
      local tabline = require("clickaholic.tabline")
      clickaholic.setup({
        renderer = "tabline",
        buttons = { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } },
      })
      assert.is_true(tabline.render(clickaholic.get_buttons()):find("Search") ~= nil)
    end)

    it("applies no renderer when opts.renderer = 'none'", function()
      local before = vim.o.winbar
      clickaholic.setup({
        renderer = "none",
        buttons = { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } },
      })
      assert.are.equal(before, vim.o.winbar)
    end)

    it("falls back to winbar and notifies on an unknown renderer name", function()
      local notified
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        notified = { msg = msg, level = level }
      end
      clickaholic.setup({
        renderer = "bogus",
        buttons = { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } },
      })
      vim.notify = original_notify
      assert.is_not_nil(notified)
      assert.are.equal(vim.log.levels.ERROR, notified.level)
      assert.is_true(vim.o.winbar:find("Search") ~= nil)
    end)

    it("apply_renderer() re-applies the currently selected renderer", function()
      clickaholic.setup({ renderer = "tabline", buttons = {} })
      store.add(path, { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" })
      clickaholic.refresh()
      clickaholic.apply_renderer()
      local tabline = require("clickaholic.tabline")
      assert.is_true(tabline.render(clickaholic.get_buttons()):find("Test") ~= nil)
    end)
  end)
end)
