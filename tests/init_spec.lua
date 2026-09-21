-- tests/init_spec.lua
describe("clickaholic.init", function()
  local clickaholic
  local store

  before_each(function()
    package.loaded["clickaholic"] = nil
    package.loaded["clickaholic.store"] = nil
    package.loaded["clickaholic.winbar"] = nil
    store = require("clickaholic.store")
    clickaholic = require("clickaholic")
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
    store.add(store.default_path(), { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" })
    clickaholic.setup({
      buttons = {
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
      },
    })
    local buttons = clickaholic.get_buttons()
    assert.are.equal(2, #buttons)
    assert.are.equal("config", buttons[1].source)
    assert.are.equal("stored", buttons[2].source)
    vim.fn.delete(store.default_path())
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
    store.add(store.default_path(), { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" })
    clickaholic.refresh()
    assert.are.equal(1, #clickaholic.get_buttons())
    vim.fn.delete(store.default_path())
  end)
end)
